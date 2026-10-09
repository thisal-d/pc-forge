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
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString));

// 2. Register Application Services
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IImageUploadService, CloudinaryImageUploadService>();
builder.Services.AddHttpClient<IAiAgentService, AiAgentService>();

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
            UPDATE products SET warrantymonths = 120 WHERE warrantymonths = 36 AND (LOWER(name) LIKE '%ram%' OR LOWER(name) LIKE '%trident%' OR LOWER(name) LIKE '%vengeance%');
            UPDATE products SET warrantymonths = 60 WHERE warrantymonths = 36 AND (LOWER(name) LIKE '%psu%' OR LOWER(name) LIKE '%rm850%' OR LOWER(name) LIKE '%ssd%' OR LOWER(name) LIKE '%nvme%');
            UPDATE products SET warrantymonths = 24 WHERE warrantymonths = 36 AND (LOWER(name) LIKE '%case%' OR LOWER(name) LIKE '%cooler%');

            -- Ensure any staff users previously saved with Customer role are elevated to Staff role
            UPDATE users 
            SET roleid = (SELECT roleid FROM roles WHERE rolename = 'Staff' LIMIT 1)
            WHERE userid IN (SELECT userid FROM staff) 
              AND roleid != (SELECT roleid FROM roles WHERE rolename = 'Admin' LIMIT 1);

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
}));

app.MapControllers();

app.Run();

static void LoadDotEnvFiles()
{
    string[] candidatePaths =
    [
        Path.Combine(Directory.GetCurrentDirectory(), ".env"),
        Path.Combine(Directory.GetCurrentDirectory(), "..", ".env"),
        Path.Combine(AppContext.BaseDirectory, ".env"),
        Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".env")
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

public partial class Program { }
