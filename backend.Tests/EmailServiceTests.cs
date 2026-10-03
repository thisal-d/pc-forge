using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using PCForge.Api.Services;
using Xunit;

namespace backend.Tests;

public class EmailServiceTests
{
    [Fact]
    public async Task SendBuildReviewNotificationAsync_ReturnsFalse_WhenEmailIsEmpty()
    {
        using var httpClient = new HttpClient();
        var configuration = new ConfigurationBuilder().Build();
        var service = new EmailService(httpClient, configuration, NullLogger<EmailService>.Instance);

        var result = await service.SendBuildReviewNotificationAsync(
            string.Empty,
            "Alex Mercer",
            1,
            "Gaming Beast",
            "Approved by Staff",
            "Looks good",
            1500m);

        Assert.False(result);
    }

    [Fact]
    public async Task SendBuildReviewNotificationAsync_RunsSimulatedMode_WhenUnconfigured()
    {
        using var httpClient = new HttpClient();
        var inMemorySettings = new Dictionary<string, string?>
        {
            { "EMAILJS_SERVICE_ID", "your_emailjs_service_id" },
            { "EMAILJS_TEMPLATE_ID", "your_emailjs_template_id" },
            { "EMAILJS_PUBLIC_KEY", "your_emailjs_public_key" }
        };
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(inMemorySettings)
            .Build();

        var service = new EmailService(httpClient, configuration, NullLogger<EmailService>.Instance);

        var result = await service.SendBuildReviewNotificationAsync(
            "customer@example.com",
            "Alex Mercer",
            7,
            "Creator Studio Beast",
            "Approved by Staff",
            "Clearances checked",
            2499m);

        Assert.True(result);
    }

    [Fact]
    public async Task ReviewBuild_TriggersEmailNotification_WhenStaffApproves()
    {
        var factory = new CustomWebApplicationFactory();
        var client = factory.CreateClient();

        int buildId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<PCForge.Api.Data.AppDbContext>();
            var build = new PCForge.Api.Models.CustomBuild
            {
                UserId = 3, // Alex Mercer (alex@example.com)
                BuildName = "Test Stealth Rig",
                Status = "Pending Staff Review",
                TotalPrice = 3200m,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.CustomBuilds.Add(build);
            await db.SaveChangesAsync();
            buildId = build.BuildId;
        }

        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", staffToken);

        var reviewDto = new PCForge.Api.DTOs.UpdateBuildReviewStatusDto
        {
            Status = "Approved by Staff",
            StaffNotes = "Thermal envelope and power budget verified."
        };

        var response = await client.PatchAsJsonAsync($"/api/custombuilds/{buildId}/review", reviewDto);
        response.EnsureSuccessStatusCode();

        var mockEmail = factory.Services.GetRequiredService<PCForge.Api.Services.IEmailService>() as MockEmailService;
        Assert.NotNull(mockEmail);
        Assert.Contains(mockEmail.SentEmails, e => e.Email == "alex@example.com" && e.Status == "Approved by Staff");
    }
}

