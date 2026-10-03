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
    // Fixed key shared by token generation and JWT validation.
    // Must be >= 256 bits (32 chars) for HMAC-SHA256.
    internal const string TestJwtKey = "PCForgeSuperSecretKeyForJwtAuthentication2026!";

    private readonly string _dbName = "PCForge_TestDb_" + Guid.NewGuid().ToString("N");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        // Override Jwt config BEFORE services build so middleware accepts test tokens.
        builder.UseSetting("Jwt:Key",      TestJwtKey);
        builder.UseSetting("Jwt:Issuer",   "PCForgeApi");
        builder.UseSetting("Jwt:Audience", "PCForgeClients");

        builder.ConfigureServices(services =>
        {
            // Swap real AppDbContext for isolated InMemory instance
            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>));
            if (descriptor != null) services.Remove(descriptor);

            services.AddDbContext<AppDbContext>(options => options.UseInMemoryDatabase(_dbName));

            // Swap AI service
            var aiDescriptor = services.SingleOrDefault(d => d.ServiceType == typeof(PCForge.Api.Services.IAiAgentService));
            if (aiDescriptor != null) services.Remove(aiDescriptor);
            services.AddSingleton<PCForge.Api.Services.IAiAgentService, MockAiAgentService>();

            // Swap Email service
            var emailDescriptor = services.SingleOrDefault(d => d.ServiceType == typeof(PCForge.Api.Services.IEmailService));
            if (emailDescriptor != null) services.Remove(emailDescriptor);
            services.AddSingleton<PCForge.Api.Services.IEmailService, MockEmailService>();

            // Seed test data
            var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.EnsureCreated();
            SeedTestData(db);
        });
    }

    private static void SeedTestData(AppDbContext db)
    {
        if (!db.Roles.Any())
        {
            // RoleId: Customer=1, Admin=2, Staff=3
            db.Roles.AddRange(
                new Role { RoleId = 1, RoleName = "Customer", Description = "Customer role" },
                new Role { RoleId = 2, RoleName = "Admin",    Description = "Admin role" },
                new Role { RoleId = 3, RoleName = "Staff",    Description = "Staff role" });
            db.SaveChanges();
        }

        if (!db.Users.Any())
        {
            db.Users.AddRange(
                new User { UserId = 1, Email = "admin@pcforge.com",  PasswordHash = BCrypt.Net.BCrypt.HashPassword("Admin123!"), RoleId = 2, FirstName = "Store",  LastName = "Admin",      IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
                new User { UserId = 2, Email = "sarah@pcforge.com",  PasswordHash = BCrypt.Net.BCrypt.HashPassword("Staff123!"), RoleId = 3, FirstName = "Sarah",  LastName = "Technician", IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
                new User { UserId = 3, Email = "alex@example.com",   PasswordHash = BCrypt.Net.BCrypt.HashPassword("Cust123!"),  RoleId = 1, FirstName = "Alex",   LastName = "Mercer",     IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
                new User { UserId = 4, Email = "bob@example.com",    PasswordHash = BCrypt.Net.BCrypt.HashPassword("Cust123!"),  RoleId = 1, FirstName = "Bob",    LastName = "Builder",    IsActive = true, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow });
            db.SaveChanges();

            db.Staff.Add(new Staff
            {
                StaffId = 1, UserId = 2, Department = "Hardware Diagnostics",
                Phone = "+94 77 123 4567", Specialization = "GPU and thermal bench testing",
                Status = "Active", Notes = "Primary tech", JoinedDate = new DateOnly(2025, 1, 1),
                CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow
            });
            db.SaveChanges();
        }
    }

    /// <summary>Generate a signed JWT accepted by the test server.</summary>
    public static string GenerateToken(int userId, string email, string role,
        string firstName = "Test", string lastName = "User")
    {
        var key         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(TestJwtKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(ClaimTypes.Email,          email),
            new(ClaimTypes.Role,           role),
            new("userId",                  userId.ToString()),
            new("role",                    role),
            new(ClaimTypes.GivenName,      firstName),
            new("firstName",               firstName),
            new(ClaimTypes.Surname,        lastName),
            new("lastName",                lastName)
        };

        var descriptor = new SecurityTokenDescriptor
        {
            Subject            = new ClaimsIdentity(claims),
            Expires            = DateTime.UtcNow.AddHours(2),
            Issuer             = "PCForgeApi",
            Audience           = "PCForgeClients",
            SigningCredentials = credentials
        };

        var handler = new JwtSecurityTokenHandler();
        return handler.WriteToken(handler.CreateToken(descriptor));
    }
}

// ---------------------------------------------------------------------------
// Mock services (testing only)
// ---------------------------------------------------------------------------

public class MockAiAgentService : PCForge.Api.Services.IAiAgentService
{
    private readonly Dictionary<string, RequirementChatResponseDto> _sessions = new();

    public Task<RequirementChatResponseDto> SendRequirementChatMessageAsync(string sessionId, string message)
    {
        if (!_sessions.TryGetValue(sessionId, out var current))
            current = new RequirementChatResponseDto { SessionId = sessionId, Profile = new RequirementProfileDto() };

        var complete = message.Contains("1440p", StringComparison.OrdinalIgnoreCase);
        if (message.Contains("gaming",  StringComparison.OrdinalIgnoreCase)) current.Profile.Purpose          = "Gaming";
        if (message.Contains("400,000") || message.Contains("400000"))        current.Profile.BudgetAmount     = 400000m;
        if (message.Contains("1440p",   StringComparison.OrdinalIgnoreCase)) current.Profile.TargetResolution = "1440p";
        if (message.Contains("monitor", StringComparison.OrdinalIgnoreCase)) current.Profile.MonitorNeeded    = false;

        current.IsComplete = complete;
        current.Status     = complete ? "completed" : "gathering";
        current.Reply      = complete ? "Your gaming configuration is ready for proposal." : "Tell me about your preferred resolution.";
        _sessions[sessionId] = current;
        return Task.FromResult(current);
    }

    public Task<RequirementChatResponseDto?> GetRequirementSessionAsync(string sessionId)
    {
        _sessions.TryGetValue(sessionId, out var s);
        return Task.FromResult(s);
    }

    public Task<BuildGenerationResponseDto>  GenerateBuildAsync(BuildGenerationRequestDto request)     => Task.FromResult(new BuildGenerationResponseDto { Success = true });
    public Task<StockVerificationResponseDto> VerifyBuildStockAsync(StockVerificationRequestDto request) => Task.FromResult(new StockVerificationResponseDto { AllInStock = true });
    public Task<OrderProposalResponseDto>    CreateOrderProposalAsync(OrderPlanningRequestDto request)  => Task.FromResult(new OrderProposalResponseDto { Success = true, Proposal = new OrderProposalDto { Status = "WAITING_FOR_APPROVAL" } });
    public Task<AfterSalesChatResponseDto>   SendAfterSalesChatMessageAsync(AfterSalesChatRequestDto r) => Task.FromResult(new AfterSalesChatResponseDto { Success = true, Reply = "How can I help with your order?" });
}

public class MockEmailService : IEmailService
{
    public List<(string Email, string Name, int BuildId, string Status)> SentEmails { get; } = new();

    public Task<bool> SendBuildReviewNotificationAsync(
        string customerEmail, string customerName, int buildId,
        string buildName, string newStatus, string? technicianNotes, decimal totalPrice)
    {
        SentEmails.Add((customerEmail, customerName, buildId, newStatus));
        return Task.FromResult(true);
    }
}
