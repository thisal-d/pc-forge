// PCForge Backend API
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using PCForge.Api.Data;
using PCForge.Api.Services;

LoadDotEnvFiles();

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.AddEnvironmentVariables();

// Configure Kestrel port explicitly using ListenAnyIP to prevent Linux duplicate-socket collision.
// UseUrls("http://0.0.0.0:x") + ASPNETCORE_URLS on Render can still trigger LocalhostListenOptions;
// builder.WebHost.ConfigureKestrel is the definitive override that bypasses that path entirely.
if (!builder.Environment.IsEnvironment("Testing"))
{
    var listenPort = int.TryParse(Environment.GetEnvironmentVariable("PORT"), out var p) ? p : 5000;
    builder.WebHost.ConfigureKestrel(options =>
    {
        options.ListenAnyIP(listenPort);
    });
    // Also clear ASPNETCORE_URLS so Kestrel does not attempt a second binding pass
    Environment.SetEnvironmentVariable("ASPNETCORE_URLS", "");
}

// 1. Add Database Context (PostgreSQL via Npgsql)
var rawConnectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? Environment.GetEnvironmentVariable("DATABASE_URL");
var connectionString = NormalizePostgresConnectionString(rawConnectionString);

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

// 2. Register Application Services
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IImageUploadService, CloudinaryImageUploadService>();
builder.Services.AddHttpClient<IAiAgentService, AiAgentService>();
builder.Services.AddHttpClient<IEmailService, EmailService>();

// 3. Configure JWT Authentication
var jwtSettings = builder.Configuration.GetSection("Jwt");
var secretKey = jwtSettings["Key"] ?? "PCForgeSuperSecretKeyForJwtAuthentication2026!";
var issuer = jwtSettings["Issuer"] ?? "PCForgeApi";
var audience = jwtSettings["Audience"] ?? "PCForgeClients";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = issuer,
        ValidAudience = audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
        ClockSkew = TimeSpan.Zero
    };
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"));
    options.AddPolicy("StaffOnly", policy => policy.RequireRole("Admin", "Staff"));
    options.AddPolicy("CustomerOnly", policy => policy.RequireRole("Customer"));
});

// 4. Configure CORS for React client & deployed frontends
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowReactApp", policy =>
    {
        var originsEnv = Environment.GetEnvironmentVariable("CORS_ORIGINS");
        var configuredOrigins = !string.IsNullOrWhiteSpace(originsEnv)
            ? originsEnv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            : builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>();

        var origins = (configuredOrigins != null && configuredOrigins.Length > 0)
            ? configuredOrigins
            : new[] { "http://localhost:5173", "http://localhost:3000" };

        policy.WithOrigins(origins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

// 5. Add Controllers and OpenAPI/Swagger
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "PCForge API", Version = "v1" });

    // Handle any schema ID collisions and conflicting actions gracefully (never return null)
    c.CustomSchemaIds(type => (type.FullName ?? type.Name).Replace("+", ".").Replace("`", "_"));
    c.ResolveConflictingActions(apiDescriptions => apiDescriptions.First());

    // Map IFormFile to binary string so multipart form uploads do not crash Swagger reflection
    c.MapType<IFormFile>(() => new OpenApiSchema { Type = "string", Format = "binary" });

    // Add JWT Bearer definition to Swagger
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

if (!app.Environment.IsEnvironment("Testing"))
{
    // Ensure requirement_sessions table exists in PostgreSQL
    using (var scope = app.Services.CreateScope())
    {
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        try
        {
            db.Database.ExecuteSqlRaw(@"
                CREATE TABLE IF NOT EXISTS requirement_sessions (
                    sessionid VARCHAR(100) PRIMARY KEY,
                    userid INT NULL REFERENCES users(userid) ON DELETE SET NULL,
                    purpose VARCHAR(100),
                    budgetamount DECIMAL(12,2),
                    budgetraw VARCHAR(100),
                    currency VARCHAR(10) DEFAULT 'LKR',
                    targetresolution VARCHAR(50),
                    monitorneeded BOOLEAN,
                    preferencesjson TEXT,
                    iscomplete BOOLEAN DEFAULT FALSE,
                    status VARCHAR(50) DEFAULT 'Gathering',
                    rawanswersjson TEXT,
                    createdat TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    updatedat TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );

                ALTER TABLE products ADD COLUMN IF NOT EXISTS warrantymonths INT NOT NULL DEFAULT 36;
                ALTER TABLE products ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'Active';

                -- 1. RAM / Desktop Memory Modules: 120 Months (10-Year / Limited Lifetime)
                UPDATE products SET warrantymonths = 120 
                WHERE categoryid = 4 
                   OR LOWER(name) LIKE '%ram%' 
                   OR LOWER(name) LIKE '%ddr5%' 
                   OR LOWER(name) LIKE '%ddr4%' 
                   OR LOWER(name) LIKE '%fury%' 
                   OR LOWER(name) LIKE '%trident%' 
                   OR LOWER(name) LIKE '%ripjaws%' 
                   OR LOWER(name) LIKE '%vengeance%';

                -- 2. Storage / NVMe PCIe 4.0 SSDs: 60 Months (5-Year Manufacturer Warranty)
                UPDATE products SET warrantymonths = 60 
                WHERE categoryid = 6 
                   OR LOWER(name) LIKE '%ssd%' 
                   OR LOWER(name) LIKE '%nvme%' 
                   OR LOWER(name) LIKE '%990 pro%' 
                   OR LOWER(name) LIKE '%p3 plus%';

                -- 3. Power Supply Units (PSUs): Tiered warranties (Flagship RMx: 10-Yr, RMe: 7-Yr, Bronze: 5-Yr)
                UPDATE products SET warrantymonths = 120 WHERE LOWER(name) LIKE '%rm850x%' OR LOWER(name) LIKE '%rm1000x%';
                UPDATE products SET warrantymonths = 84 WHERE LOWER(name) LIKE '%rm750e%' OR LOWER(name) LIKE '%rm850e%';
                UPDATE products SET warrantymonths = 60 WHERE categoryid = 5 AND warrantymonths NOT IN (120, 84);

                -- 4. Coolers: 360mm Liquid AIO (60 Months / 5-Yr), Air Coolers (36 Months / 3-Yr)
                UPDATE products SET warrantymonths = 60 WHERE LOWER(name) LIKE '%liquid%' OR LOWER(name) LIKE '%lt720%' OR LOWER(name) LIKE '%aio%';
                UPDATE products SET warrantymonths = 36 WHERE categoryid = 8 AND warrantymonths != 60;

                -- 5. Cases / Chassis: 24 Months (2-Year Manufacturer Warranty)
                UPDATE products SET warrantymonths = 24 WHERE categoryid = 7 OR LOWER(name) LIKE '%case%' OR LOWER(name) LIKE '%tower%' OR LOWER(name) LIKE '%chassis%' OR LOWER(name) LIKE '%dynamic%';

                -- 6. Gaming Mice / Peripherals: 24 Months (Logitech) / 12 Months (Generic)
                UPDATE products SET warrantymonths = 24 WHERE LOWER(name) LIKE '%logitech%' OR LOWER(name) LIKE '%g102%';
                UPDATE products SET warrantymonths = 12 WHERE categoryid = 9 AND LOWER(name) NOT LIKE '%logitech%';

                -- 7. CPUs, Motherboards & Retail GPUs: 36 Months (3-Year Retail Warranty)
                UPDATE products SET warrantymonths = 36 WHERE categoryid IN (1, 2, 3) AND LOWER(name) NOT LIKE '%gtx 660%' AND LOWER(name) NOT LIKE '%navid%';

                -- 8. Entry / Refurbished / Legacy parts: 12 Months (1-Year Warranty)
                UPDATE products SET warrantymonths = 12 WHERE LOWER(name) LIKE '%gtx 660%' OR LOWER(name) = 'navid';

                -- Ensure any staff users previously saved with Customer role are elevated to Staff role
                UPDATE users 
                SET roleid = (SELECT roleid FROM roles WHERE rolename = 'Staff' LIMIT 1)
                WHERE userid IN (SELECT userid FROM staff) 
                  AND roleid != (SELECT roleid FROM roles WHERE rolename = 'Admin' LIMIT 1);

                -- Ensure master filters and options tables exist
                CREATE TABLE IF NOT EXISTS filters (
                    filterid SERIAL PRIMARY KEY,
                    filterkey VARCHAR(50) UNIQUE NOT NULL,
                    displayname VARCHAR(100) NOT NULL,
                    filtertype VARCHAR(30) NOT NULL DEFAULT 'multiselect',
                    unit VARCHAR(20) NULL,
                    createdat TIMESTAMPTZ DEFAULT NOW(),
                    updatedat TIMESTAMPTZ DEFAULT NOW()
                );

                CREATE TABLE IF NOT EXISTS master_filter_options (
                    optionid SERIAL PRIMARY KEY,
                    filterid INT NOT NULL REFERENCES filters(filterid) ON DELETE CASCADE,
                    optionvalue VARCHAR(100) NOT NULL,
                    displayorder INT DEFAULT 0,
                    CONSTRAINT uq_master_filter_option UNIQUE(filterid, optionvalue)
                );

                ALTER TABLE categoryfilters ADD COLUMN IF NOT EXISTS masterfilterid INT NULL REFERENCES filters(filterid) ON DELETE SET NULL;

                -- Populate filters from existing categoryfilters if filters is empty
                INSERT INTO filters (filterkey, displayname, filtertype, unit, createdat)
                SELECT DISTINCT ON (LOWER(filterkey))
                    LOWER(filterkey), displayname, filtertype, unit, NOW()
                FROM categoryfilters
                WHERE NOT EXISTS (SELECT 1 FROM filters WHERE LOWER(filters.filterkey) = LOWER(categoryfilters.filterkey));

                -- Populate master_filter_options from existing filteroptions if empty
                INSERT INTO master_filter_options (filterid, optionvalue, displayorder)
                SELECT DISTINCT f.filterid, fo.optionvalue, fo.displayorder
                FROM filteroptions fo
                JOIN categoryfilters cf ON fo.filterid = cf.filterid
                JOIN filters f ON LOWER(f.filterkey) = LOWER(cf.filterkey)
                ON CONFLICT (filterid, optionvalue) DO NOTHING;

                -- Automatically format existing numeric options with unit if filter has unit defined
                UPDATE master_filter_options mfo
                SET optionvalue = mfo.optionvalue || f.unit
                FROM filters f
                WHERE mfo.filterid = f.filterid
                  AND f.unit IS NOT NULL AND TRIM(f.unit) <> ''
                  AND mfo.optionvalue ~ '^[0-9]+$'
                  AND NOT EXISTS (
                      SELECT 1 FROM master_filter_options m2 
                      WHERE m2.filterid = mfo.filterid AND m2.optionvalue = mfo.optionvalue || f.unit
                  );

                UPDATE filteroptions fo
                SET optionvalue = fo.optionvalue || cf.unit
                FROM categoryfilters cf
                WHERE fo.filterid = cf.filterid
                  AND cf.unit IS NOT NULL AND TRIM(cf.unit) <> ''
                  AND fo.optionvalue ~ '^[0-9]+$'
                  AND NOT EXISTS (
                      SELECT 1 FROM filteroptions fo2 
                      WHERE fo2.filterid = fo.filterid AND fo2.optionvalue = fo.optionvalue || cf.unit
                  );

                -- Keep category filter options in sync with master filter options
                INSERT INTO filteroptions (filterid, optionvalue, displayorder)
                SELECT cf.filterid, mfo.optionvalue, mfo.displayorder
                FROM master_filter_options mfo
                JOIN categoryfilters cf ON (cf.masterfilterid = mfo.filterid OR LOWER(cf.filterkey) = (SELECT LOWER(f.filterkey) FROM filters f WHERE f.filterid = mfo.filterid))
                WHERE NOT EXISTS (
                    SELECT 1 FROM filteroptions fo 
                    WHERE fo.filterid = cf.filterid AND LOWER(fo.optionvalue) = LOWER(mfo.optionvalue)
                );

                -- Ensure servicerequests columns for Title and Description exist, and drop obsolete columns
                ALTER TABLE servicerequests ADD COLUMN IF NOT EXISTS title VARCHAR(200);
                ALTER TABLE servicerequests ADD COLUMN IF NOT EXISTS description TEXT;
                DO $$
                BEGIN
                    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'servicerequests' AND column_name = 'problemdescription') THEN
                        UPDATE servicerequests 
                        SET title = COALESCE(title, 'Service Request') 
                        WHERE title IS NULL OR title = '';
                    END IF;
                END $$;

                DROP TABLE IF EXISTS supporttickets CASCADE;
                ALTER TABLE servicerequests DROP CONSTRAINT IF EXISTS servicerequests_productid_fkey;
                ALTER TABLE servicerequests DROP CONSTRAINT IF EXISTS servicerequests_assignedstaffid_fkey;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS productid;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS assignedstaffid;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS problemcategory;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS troubleshootingsummary;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS attemptcount;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS internalnotes;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS warrantystatus;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS warrantyexpirydate;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS priority;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS techniciannotes;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS resolution;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS attachmenturl;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS problemdescription;
                ALTER TABLE servicerequests DROP CONSTRAINT IF EXISTS servicerequests_orderid_fkey;
                ALTER TABLE servicerequests DROP COLUMN IF EXISTS orderid;

                -- Remove staff assignment from custombuilds
                ALTER TABLE custombuilds DROP CONSTRAINT IF EXISTS custombuilds_assignedstaffid_fkey;
                ALTER TABLE custombuilds DROP COLUMN IF EXISTS assignedstaffid;

                -- Synchronize primary key sequences with MAX(id) to prevent duplicate key constraint violations
                DO $$
                BEGIN
                    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'categories_categoryid_seq') THEN
                        PERFORM setval('categories_categoryid_seq', (SELECT GREATEST(COALESCE(MAX(categoryid), 1), 1) FROM categories));
                    END IF;
                    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'products_productid_seq') THEN
                        PERFORM setval('products_productid_seq', (SELECT GREATEST(COALESCE(MAX(productid), 1), 1) FROM products));
                    END IF;
                    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'categoryfilters_filterid_seq') THEN
                        PERFORM setval('categoryfilters_filterid_seq', (SELECT GREATEST(COALESCE(MAX(filterid), 1), 1) FROM categoryfilters));
                    END IF;
                    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'filteroptions_optionid_seq') THEN
                        PERFORM setval('filteroptions_optionid_seq', (SELECT GREATEST(COALESCE(MAX(optionid), 1), 1) FROM filteroptions));
                    END IF;
                    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'filters_filterid_seq') THEN
                        PERFORM setval('filters_filterid_seq', (SELECT GREATEST(COALESCE(MAX(filterid), 1), 1) FROM filters));
                    END IF;
                    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'master_filter_options_optionid_seq') THEN
                        PERFORM setval('master_filter_options_optionid_seq', (SELECT GREATEST(COALESCE(MAX(optionid), 1), 1) FROM master_filter_options));
                    END IF;
                END $$;
            ");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Startup] Database migration note: {ex.Message}");
        }
    }

    // 6. Seed Database on startup (Roles + 3 Default Users)
    using (var scope = app.Services.CreateScope())
    {
        try
        {
            await DbInitializer.SeedAsync(scope.ServiceProvider);
        }
        catch (Exception ex)
        {
            app.Logger.LogWarning(ex, "Database seeding skipped or database not reachable during startup.");
        }
    }
}

// 7. Configure HTTP request pipeline
var enableSwagger = app.Environment.IsDevelopment()
    || builder.Configuration.GetValue<bool>("EnableSwagger", false)
    || string.Equals(Environment.GetEnvironmentVariable("ENABLE_SWAGGER"), "true", StringComparison.OrdinalIgnoreCase);

if (enableSwagger)
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "PCForge API v1"));
}

app.UseCors("AllowReactApp");

app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

// Container liveness & readiness probe
app.MapGet("/health", () => Results.Ok(new
{
    status = "Healthy",
    service = "PCForge API",
    timestamp = DateTime.UtcNow
})).ExcludeFromDescription();

app.MapControllers();

app.Run();

static void LoadDotEnvFiles()
{
    string[] candidatePaths =
    [
        Path.Combine(Directory.GetCurrentDirectory(), "backend", ".env"),
        Path.Combine(Directory.GetCurrentDirectory(), ".env"),
        Path.Combine(AppContext.BaseDirectory, ".env"),
        Path.Combine(AppContext.BaseDirectory, "backend", ".env"),
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "backend", ".env"),
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".env"),
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "backend", ".env"),
        Path.Combine(Directory.GetCurrentDirectory(), "..", ".env")
    ];

    foreach (var path in candidatePaths)
    {
        if (File.Exists(path))
        {
            try
            {
                foreach (var rawLine in File.ReadAllLines(path))
                {
                    var line = rawLine.Trim();
                    if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#")) continue;

                    var eqIdx = line.IndexOf('=');
                    if (eqIdx > 0)
                    {
                        var key = line.Substring(0, eqIdx).Trim();
                        var val = line.Substring(eqIdx + 1).Trim().Trim('"', '\'');
                        if (string.IsNullOrEmpty(Environment.GetEnvironmentVariable(key)))
                        {
                            Environment.SetEnvironmentVariable(key, val);
                        }
                    }
                }
            }
            catch
            {
                // Gracefully ignore file access errors
            }
            break;
        }
    }
}

static string? NormalizePostgresConnectionString(string? connStr)
{
    if (string.IsNullOrWhiteSpace(connStr))
        return connStr;

    if (!connStr.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase) &&
        !connStr.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        return connStr;
    }

    try
    {
        var uri = new Uri(connStr);
        var userInfo = uri.UserInfo.Split(':');
        var user = userInfo.Length > 0 ? Uri.UnescapeDataString(userInfo[0]) : "";
        var pass = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "";
        var host = uri.Host;
        var port = uri.Port > 0 ? uri.Port : 5432;
        var database = uri.AbsolutePath.TrimStart('/');

        return $"Host={host};Port={port};Database={database};Username={user};Password={pass};SSL Mode=Require;Trust Server Certificate=true;";
    }
    catch
    {
        return connStr;
    }
}

public partial class Program { }
