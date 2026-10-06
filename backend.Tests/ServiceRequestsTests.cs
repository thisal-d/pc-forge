using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace backend.Tests;

public class ServiceRequestsTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly CustomWebApplicationFactory _factory;
    private readonly HttpClient _client;

    public ServiceRequestsTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private HttpClient CreateAuthenticatedClient(int userId, string email, string role)
    {
        var client = _factory.CreateClient();
        var token = CustomWebApplicationFactory.GenerateToken(userId, email, role);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    [Fact]
    public async Task CreateServiceRequest_InitialStatusIsPending_AndTitleIsSaved()
    {
        var customerClient = CreateAuthenticatedClient(10, "customer10@pcforge.com", "Customer");

        var payload = new CreateServiceRequestDto
        {
            Title = "PC won't boot into BIOS",
            Description = "Pressing power button turns fans on for 2 seconds then shuts down.",
            PreferredDate = DateTime.UtcNow.Date.AddDays(2),
            PreferredTime = "10:30 AM"
        };

        var response = await customerClient.PostAsJsonAsync("/api/ServiceRequests", payload);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var detail = await response.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(detail);
        Assert.Equal("PC won't boot into BIOS", detail.Title);
        Assert.Equal("Pending", detail.Status);
        Assert.Equal("10:30 AM", detail.PreferredTime);
    }

    [Fact]
    public async Task CreateServiceRequest_TimeOutside9AmTo6Pm_IsRejected()
    {
        var customerClient = CreateAuthenticatedClient(11, "customer11@pcforge.com", "Customer");

        // 8:00 AM is too early
        var earlyPayload = new CreateServiceRequestDto
        {
            Title = "Early appointment test",
            PreferredDate = DateTime.UtcNow.Date.AddDays(3),
            PreferredTime = "08:00 AM"
        };
        var earlyRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests", earlyPayload);
        Assert.Equal(HttpStatusCode.BadRequest, earlyRes.StatusCode);

        // 7:00 PM (19:00) is too late
        var latePayload = new CreateServiceRequestDto
        {
            Title = "Late appointment test",
            PreferredDate = DateTime.UtcNow.Date.AddDays(3),
            PreferredTime = "07:00 PM"
        };
        var lateRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests", latePayload);
        Assert.Equal(HttpStatusCode.BadRequest, lateRes.StatusCode);
    }

    [Fact]
    public async Task CreateServiceRequest_Max10CapacityPerDate_IsStrictlyEnforced()
    {
        var targetDate = DateTime.UtcNow.Date.AddDays(15);

        // Pre-fill 10 service requests on targetDate directly in database
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (int i = 1; i <= 10; i++)
            {
                db.ServiceRequests.Add(new ServiceRequest
                {
                    ServiceRequestNumber = $"SR-CAPTEST-{i}-{Guid.NewGuid().ToString("N")[..4]}",
                    UserId = 1,
                    Title = $"Existing Appointment {i}",
                    Description = "Issue",
                    PreferredDate = targetDate,
                    PreferredTime = "11:00 AM",
                    Status = "Pending"
                });
            }
            await db.SaveChangesAsync();
        }

        // Check availability endpoint returns 0 remaining slots
        var availRes = await _client.GetFromJsonAsync<ServiceAvailabilityDto>($"/api/ServiceRequests/availability?date={targetDate:yyyy-MM-dd}");
        Assert.NotNull(availRes);
        Assert.Equal(10, availRes.BookedCount);
        Assert.Equal(0, availRes.RemainingSlots);
        Assert.False(availRes.IsAvailable);

        // Customer attempts to create 11th request on targetDate -> Must be rejected with 400
        var customerClient = CreateAuthenticatedClient(12, "customer12@pcforge.com", "Customer");
        var attemptPayload = new CreateServiceRequestDto
        {
            Title = "11th Appointment Attempt",
            PreferredDate = targetDate,
            PreferredTime = "02:00 PM"
        };

        var response = await customerClient.PostAsJsonAsync("/api/ServiceRequests", attemptPayload);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var errContent = await response.Content.ReadAsStringAsync();
        Assert.Contains("maximum capacity of 10", errContent);
    }

    [Fact]
    public async Task CustomerCanCancelOwnRequest_AndCannotCancelCompletedRequest()
    {
        var customerId = 3; // Seeded customer: alex@example.com
        var customerClient = CreateAuthenticatedClient(customerId, "alex@example.com", "Customer");

        // Create a new request
        var createPayload = new CreateServiceRequestDto
        {
            Title = "Request to cancel",
            PreferredDate = DateTime.UtcNow.Date.AddDays(4),
            PreferredTime = "01:00 PM"
        };
        var createRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests", createPayload);
        Assert.Equal(HttpStatusCode.Created, createRes.StatusCode);
        var created = await createRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(created);

        // Cancel it
        var cancelRes = await customerClient.PostAsync($"/api/ServiceRequests/{created.ServiceRequestId}/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelRes.StatusCode);
        var cancelled = await cancelRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(cancelled);
        Assert.Equal("Cancelled", cancelled.Status);

        // Attempting to cancel again should fail because it's already cancelled
        var secondCancelRes = await customerClient.PostAsync($"/api/ServiceRequests/{created.ServiceRequestId}/cancel", null);
        Assert.Equal(HttpStatusCode.BadRequest, secondCancelRes.StatusCode);
    }

    [Fact]
    public async Task AdminCanUpdateStatus_LifecycleTransitionsWork()
    {
        var customerId = 4; // Seeded customer: bob@example.com
        var customerClient = CreateAuthenticatedClient(customerId, "bob@example.com", "Customer");
        var adminClient = CreateAuthenticatedClient(1, "admin@pcforge.com", "Admin");

        // 1. Customer creates request
        var createPayload = new CreateServiceRequestDto
        {
            Title = "GPU artifacting under load",
            Description = "Green lines on display during FurMark benchmark",
            PreferredDate = DateTime.UtcNow.Date.AddDays(5),
            PreferredTime = "03:00 PM"
        };
        var createRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests", createPayload);
        var created = await createRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(created);

        // 2. Admin updates status to "In Progress"
        var updatePayload = new UpdateServiceRequestDto
        {
            Status = "In Progress"
        };
        var updateRes = await adminClient.PutAsJsonAsync($"/api/ServiceRequests/{created.ServiceRequestId}", updatePayload);
        Assert.Equal(HttpStatusCode.OK, updateRes.StatusCode);
        var adminView = await updateRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(adminView);
        Assert.Equal("In Progress", adminView.Status);

        // 3. Customer views request
        var customerViewRes = await customerClient.GetAsync($"/api/ServiceRequests/{created.ServiceRequestId}");
        Assert.Equal(HttpStatusCode.OK, customerViewRes.StatusCode);
        var customerView = await customerViewRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(customerView);
        Assert.Equal("In Progress", customerView.Status);

        // 4. Admin updates status to "No Show"
        var noShowPayload = new UpdateServiceRequestDto { Status = "No Show" };
        var noShowRes = await adminClient.PutAsJsonAsync($"/api/ServiceRequests/{created.ServiceRequestId}", noShowPayload);
        Assert.Equal(HttpStatusCode.OK, noShowRes.StatusCode);
        var noShowView = await noShowRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(noShowView);
        Assert.Equal("No Show", noShowView.Status);

        // 5. Admin updates status to "Completed"
        var completedPayload = new UpdateServiceRequestDto
        {
            Status = "Completed"
        };
        var completedRes = await adminClient.PutAsJsonAsync($"/api/ServiceRequests/{created.ServiceRequestId}", completedPayload);
        Assert.Equal(HttpStatusCode.OK, completedRes.StatusCode);
        var completedView = await completedRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(completedView);
        Assert.Equal("Completed", completedView.Status);
    }

    [Fact]
    public async Task FilteringByStatusAndDateRange_WorksCorrectly()
    {
        var adminClient = CreateAuthenticatedClient(2, "admin@pcforge.com", "Admin");
        var baseDate = DateTime.UtcNow.Date.AddDays(20);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.ServiceRequests.Add(new ServiceRequest
            {
                ServiceRequestNumber = $"SR-FILTER-PENDING-{Guid.NewGuid().ToString("N")[..4]}",
                UserId = 1,
                Title = "Filter Test Pending",
                Description = "Filter test",
                PreferredDate = baseDate,
                PreferredTime = "10:00 AM",
                Status = "Pending"
            });
            db.ServiceRequests.Add(new ServiceRequest
            {
                ServiceRequestNumber = $"SR-FILTER-COMPLETED-{Guid.NewGuid().ToString("N")[..4]}",
                UserId = 1,
                Title = "Filter Test Completed",
                Description = "Filter test",
                PreferredDate = baseDate.AddDays(5),
                PreferredTime = "11:00 AM",
                Status = "Completed"
            });
            await db.SaveChangesAsync();
        }

        // Filter by status = "Pending" and date range
        var filterUrl = $"/api/ServiceRequests?status=Pending&startDate={baseDate.AddDays(-1):yyyy-MM-dd}&endDate={baseDate.AddDays(1):yyyy-MM-dd}";
        var listRes = await adminClient.GetFromJsonAsync<List<ServiceRequestSummaryDto>>(filterUrl);
        Assert.NotNull(listRes);
        Assert.Contains(listRes, r => r.Title == "Filter Test Pending");
        Assert.DoesNotContain(listRes, r => r.Title == "Filter Test Completed");
    }

    [Fact]
    public async Task AgenticServiceRequestCreation_ViaAiChat_CreatesPendingRequestAndChecksCapacity()
    {
        var customerId = 15;
        var customerClient = CreateAuthenticatedClient(customerId, "customer15@pcforge.com", "Customer");

        // Target weekday date
        var targetDate = DateTime.UtcNow.Date.AddDays(30);
        while (targetDate.DayOfWeek == DayOfWeek.Sunday)
        {
            targetDate = targetDate.AddDays(1);
        }

        // 1. Customer messages the AI assistant requesting a service appointment
        var chatPayload = new AfterSalesChatRequestDto
        {
            UserId = customerId,
            Message = $"Please create a service request for my computer. Date {targetDate:yyyy-MM-dd} at 10:30 AM. Title: Display freezes during benchmarks."
        };

        var chatRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests/ai-chat", chatPayload);
        Assert.Equal(HttpStatusCode.OK, chatRes.StatusCode);

        var chatResult = await chatRes.Content.ReadFromJsonAsync<AfterSalesChatResponseDto>();
        Assert.NotNull(chatResult);
        Assert.True(chatResult.Success);
        Assert.NotNull(chatResult.ServiceRequest);
        Assert.Equal("Pending", chatResult.ServiceRequest.Status);
        Assert.Equal("10:30 AM", chatResult.ServiceRequest.PreferredTime);
        Assert.Contains(targetDate.ToString("yyyy-MM-dd"), chatResult.ServiceRequest.PreferredDate);
        Assert.StartsWith("SR-", chatResult.ServiceRequest.ServiceRequestNumber);

        // Verify in database that it was persisted authoritatively
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var savedSr = await db.ServiceRequests.FirstOrDefaultAsync(sr => sr.ServiceRequestId == chatResult.ServiceRequest.ServiceRequestId);
            Assert.NotNull(savedSr);
            Assert.Equal("Pending", savedSr.Status);
            Assert.Equal(customerId, savedSr.UserId);
        }

        // 2. Pre-fill remaining slots up to 10 on targetDate
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var currentCount = await db.ServiceRequests.CountAsync(sr =>
                sr.PreferredDate.HasValue && sr.PreferredDate.Value.Date == targetDate &&
                sr.Status.ToLower() != "cancelled" && sr.Status.ToLower() != "canceled");

            for (int i = currentCount + 1; i <= 10; i++)
            {
                db.ServiceRequests.Add(new ServiceRequest
                {
                    ServiceRequestNumber = $"SR-AGENTICCAP-{i}-{Guid.NewGuid().ToString("N")[..4]}",
                    UserId = 1,
                    Title = $"Filler Appointment {i}",
                    Description = "Issue",
                    PreferredDate = targetDate,
                    PreferredTime = "11:00 AM",
                    Status = "Pending"
                });
            }
            await db.SaveChangesAsync();
        }

        // 3. Customer tries to book an 11th request on the same date via chat -> Must decline slot due to capacity limit
        var fullChatPayload = new AfterSalesChatRequestDto
        {
            UserId = customerId,
            Message = $"I want to book an appointment for service on {targetDate:yyyy-MM-dd} at 02:00 PM."
        };
        var fullChatRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests/ai-chat", fullChatPayload);
        Assert.Equal(HttpStatusCode.OK, fullChatRes.StatusCode);
        var fullResult = await fullChatRes.Content.ReadFromJsonAsync<AfterSalesChatResponseDto>();
        Assert.NotNull(fullResult);
        Assert.Null(fullResult.ServiceRequest); // Request NOT created because date is at max 10 capacity
        Assert.Contains("maximum capacity of 10", fullResult.Reply);
    }
}

