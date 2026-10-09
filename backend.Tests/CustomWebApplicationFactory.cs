using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;
using PCForge.Api.Services;

namespace backend.Tests;

public class CustomWebApplicationFactory : WebApplicationFactory<Program>
{
    private readonly string _dbName = "PCForge_TestDb_" + Guid.NewGuid().ToString("N");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        builder.ConfigureServices(services =>
        {
            // Remove existing AppDbContext registration
            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null)
            {
                services.Remove(descriptor);
            }

            // Register InMemory database for fast and completely isolated testing
            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseInMemoryDatabase(_dbName);
            });

            // Replace IAiAgentService with MockAiAgentService for unit testing
            var aiDescriptor = services.SingleOrDefault(d => d.ServiceType == typeof(PCForge.Api.Services.IAiAgentService));
            if (aiDescriptor != null)
            {
                services.Remove(aiDescriptor);
            }
            services.AddSingleton<PCForge.Api.Services.IAiAgentService, MockAiAgentService>();

            // Build service provider and seed required test data
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var scopedServices = scope.ServiceProvider;
            var db = scopedServices.GetRequiredService<AppDbContext>();

            db.Database.EnsureCreated();
            SeedTestData(db);
        });
    }

    private static void SeedTestData(AppDbContext db)
    {
        if (!db.Roles.Any())
        {
            var customerRole = new Role { RoleId = 1, RoleName = "Customer", Description = "Customer role" };
            var adminRole = new Role { RoleId = 2, RoleName = "Admin", Description = "Admin role" };
            var staffRole = new Role { RoleId = 3, RoleName = "Staff", Description = "Staff role" };
            db.Roles.AddRange(customerRole, adminRole, staffRole);
            db.SaveChanges();
        }

        if (!db.Users.Any())
        {
            var adminUser = new User
            {
                UserId = 1,
                Email = "admin@pcforge.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin123!"),
                RoleId = 2,
                FirstName = "Store",
                LastName = "Admin",
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            var staffUser = new User
            {
                UserId = 2,
                Email = "sarah@pcforge.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Staff123!"),
                RoleId = 3,
                FirstName = "Sarah",
                LastName = "Technician",
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            var customer1 = new User
            {
                UserId = 3,
                Email = "alex@example.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Cust123!"),
                RoleId = 1,
                FirstName = "Alex",
                LastName = "Mercer",
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            var customer2 = new User
            {
                UserId = 4,
                Email = "bob@example.com",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("Cust123!"),
                RoleId = 1,
                FirstName = "Bob",
                LastName = "Builder",
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            db.Users.AddRange(adminUser, staffUser, customer1, customer2);
            db.SaveChanges();

            var staffProfile = new Staff
            {
                StaffId = 1,
                UserId = 2,
                Department = "Hardware Diagnostics",
                Phone = "+94 77 123 4567",
                Specialization = "GPU and thermal bench testing",
                Status = "Active",
                Notes = "Primary tech",
                JoinedDate = new DateOnly(2025, 1, 1),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.Staff.Add(staffProfile);
            db.SaveChanges();
        }
    }

    public static string GenerateToken(int userId, string email, string role, string firstName = "Test", string lastName = "User")
    {
        const string secretKey = "PCForgeSuperSecretKeyForJwtAuthentication2026!";
        const string issuer = "PCForgeApi";
        const string audience = "PCForgeClients";

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Email, email),
            new(ClaimTypes.Role, role),
            new("userId", userId.ToString()),
            new("role", role),
            new(ClaimTypes.GivenName, firstName),
            new("firstName", firstName),
            new(ClaimTypes.Surname, lastName),
            new("lastName", lastName)
        };

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddHours(2),
            Issuer = issuer,
            Audience = audience,
            SigningCredentials = credentials
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}

public class MockAiAgentService : PCForge.Api.Services.IAiAgentService
{
    private readonly Dictionary<string, RequirementChatResponseDto> _sessions = new();

    public Task<RequirementChatResponseDto> SendRequirementChatMessageAsync(string sessionId, string message)
    {
        if (!_sessions.TryGetValue(sessionId, out var current))
        {
            current = new RequirementChatResponseDto
            {
                SessionId = sessionId,
                Profile = new RequirementProfileDto()
            };
        }

        var isComplete = message.Contains("1440p", StringComparison.OrdinalIgnoreCase);
        if (message.Contains("gaming", StringComparison.OrdinalIgnoreCase))
        {
            current.Profile.Purpose = "Gaming";
        }
        if (message.Contains("400,000") || message.Contains("400000"))
        {
            current.Profile.BudgetAmount = 400000m;
        }
        if (message.Contains("1440p", StringComparison.OrdinalIgnoreCase))
        {
            current.Profile.TargetResolution = "1440p";
        }
        if (message.Contains("monitor", StringComparison.OrdinalIgnoreCase))
        {
            current.Profile.MonitorNeeded = false;
        }

        current.IsComplete = isComplete;
        current.Status = isComplete ? "completed" : "gathering";
        current.Reply = isComplete ? "Your gaming configuration is ready for proposal." : "Tell me about your preferred resolution.";
        _sessions[sessionId] = current;

        return Task.FromResult(current);
    }

    public Task<RequirementChatResponseDto?> GetRequirementSessionAsync(string sessionId)
    {
        _sessions.TryGetValue(sessionId, out var session);
        return Task.FromResult(session);
    }

    public Task<BuildGenerationResponseDto> GenerateBuildAsync(BuildGenerationRequestDto request)
    {
        return Task.FromResult(new BuildGenerationResponseDto
        {
            Success = true
        });
    }

    public Task<StockVerificationResponseDto> VerifyBuildStockAsync(StockVerificationRequestDto request)
    {
        return Task.FromResult(new StockVerificationResponseDto
        {
            AllInStock = true
        });
    }

    public Task<OrderProposalResponseDto> CreateOrderProposalAsync(OrderPlanningRequestDto request)
    {
        return Task.FromResult(new OrderProposalResponseDto
        {
            Success = true,
            Proposal = new OrderProposalDto { Status = "WAITING_FOR_APPROVAL" }
        });
    }

    public Task<AfterSalesChatResponseDto> SendAfterSalesChatMessageAsync(AfterSalesChatRequestDto request)
    {
        return Task.FromResult(new AfterSalesChatResponseDto
        {
            Success = true,
            Reply = "How can I help with your order?"
        });
    }
}

