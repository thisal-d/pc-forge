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
    public async Task SendBuildNotificationAsync_RejectsInvalidEmailFormat()
    {
        using var httpClient = new HttpClient();
        var configuration = new ConfigurationBuilder().Build();
        var service = new EmailService(httpClient, configuration, NullLogger<EmailService>.Instance);

        var result = await service.SendBuildNotificationAsync(
            "not-an-email",
            "Alex Mercer",
            101,
            "Custom Beast",
            "Pending Staff Review");

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
    public async Task SendOrderNotificationAsync_RunsSimulatedMode_And_SuppressesDuplicate()
    {
        using var httpClient = new HttpClient();
        var configuration = new ConfigurationBuilder().Build();
        var service = new EmailService(httpClient, configuration, NullLogger<EmailService>.Instance);

        var first = await service.SendOrderNotificationAsync(
            "alex@example.com",
            "Alex Mercer",
            5001,
            "Ready for pickup",
            "Store Pickup",
            "PCForge Store Hub, Colombo 03",
            185000m,
            2);

        var duplicate = await service.SendOrderNotificationAsync(
            "alex@example.com",
            "Alex Mercer",
            5001,
            "Ready for pickup",
            "Store Pickup",
            "PCForge Store Hub, Colombo 03",
            185000m,
            2);

        Assert.True(first);
        Assert.True(duplicate);
    }

    [Fact]
    public async Task SendServiceRequestNotificationAsync_RunsSimulatedMode_ForReceivedAndCompleted()
    {
        using var httpClient = new HttpClient();
        var configuration = new ConfigurationBuilder().Build();
        var service = new EmailService(httpClient, configuration, NullLogger<EmailService>.Instance);

        var resultReceived = await service.SendServiceRequestNotificationAsync(
            "sarah@example.com",
            "Sarah Jenkins",
            "SR-9999",
            "Booked",
            "Thermal Paste Reapplication",
            DateTime.UtcNow.AddDays(2),
            "11:00 AM - 01:00 PM");

        var resultCompleted = await service.SendServiceRequestNotificationAsync(
            "sarah@example.com",
            "Sarah Jenkins",
            "SR-9999",
            "Completed",
            "Thermal Paste Reapplication",
            DateTime.UtcNow.AddDays(2),
            "11:00 AM - 01:00 PM",
            "Replaced thermal compound with Arctic MX-6.");

        Assert.True(resultReceived);
        Assert.True(resultCompleted);
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

    [Fact]
    public async Task UpdateOrderStatus_TriggersEmailNotification_WhenStaffAdvancesToProcessing()
    {
        var factory = new CustomWebApplicationFactory();
        var client = factory.CreateClient();

        int orderId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<PCForge.Api.Data.AppDbContext>();
            var order = new PCForge.Api.Models.Order
            {
                UserId = 3, // Alex Mercer (alex@example.com)
                TotalAmount = 45000m,
                Status = "Order placed",
                ShippingAddress = "No 12, Galle Road, Colombo 03",
                PaymentMethod = "Store Pickup",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.Orders.Add(order);
            await db.SaveChangesAsync();
            orderId = order.OrderId;
        }

        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", staffToken);

        var updateDto = new PCForge.Api.DTOs.UpdateOrderStatusDto
        {
            Status = "Processing"
        };

        var response = await client.PatchAsJsonAsync($"/api/orders/{orderId}/status", updateDto);
        response.EnsureSuccessStatusCode();

        var mockEmail = factory.Services.GetRequiredService<PCForge.Api.Services.IEmailService>() as MockEmailService;
        Assert.NotNull(mockEmail);
        Assert.Contains(mockEmail.SentOrderEmails, e => e.OrderId == orderId && e.Status == "Processing");
    }
}
