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
    public async Task CreateServiceRequest_InitialStatusIsPending_AndSlotIsSaved()
    {
        var customerClient = CreateAuthenticatedClient(10, "customer10@pcforge.com", "Customer");

        var payload = new CreateServiceRequestDto
        {
            Title = "PC won't boot into BIOS",
            Description = "Pressing power button turns fans on for 2 seconds then shuts down.",
            PreferredDate = DateTime.UtcNow.Date.AddDays(2),
            SlotId = 1
        };

        var response = await customerClient.PostAsJsonAsync("/api/ServiceRequests", payload);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var detail = await response.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(detail);
        Assert.Equal("PC won't boot into BIOS", detail.Title);
        Assert.Equal("Booked", detail.Status);
        Assert.Equal(1, detail.SlotId);
        Assert.Equal("09:00 AM - 11:00 AM", detail.TimeSlotLabel);
    }

    [Fact]
    public async Task CreateServiceRequest_SlotCapacity_IsStrictlyEnforced_AndOld10LimitRemoved()
    {
        var targetDate = DateTime.UtcNow.Date.AddDays(15);
        int slotId = 1; // Default capacity = 5

        // 1. Pre-fill 5 service requests for Slot 1 on targetDate directly in database
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (int i = 1; i <= 5; i++)
            {
                db.ServiceRequests.Add(new ServiceRequest
                {
                    ServiceRequestNumber = $"SR-SLOTCAP1-{i}-{Guid.NewGuid().ToString("N")[..4]}",
                    UserId = 1,
                    SlotId = slotId,
                    Title = $"Slot 1 Booking {i}",
                    Description = "Issue",
                    PreferredDate = targetDate,
                    PreferredTime = "09:00 AM - 11:00 AM",
                    Status = "Pending"
                });
            }
            await db.SaveChangesAsync();
        }

        // 2. Check slots endpoint: Slot 1 is full, but Slot 2 is available
        var slotsRes = await _client.GetFromJsonAsync<List<SlotAvailabilityDto>>($"/api/ServiceRequests/slots?date={targetDate:yyyy-MM-dd}");
        Assert.NotNull(slotsRes);
        var s1 = slotsRes.FirstOrDefault(s => s.SlotId == 1);
        var s2 = slotsRes.FirstOrDefault(s => s.SlotId == 2);

        Assert.NotNull(s1);
        Assert.Equal(5, s1.BookedCount);
        Assert.Equal(0, s1.RemainingSlots);
        Assert.False(s1.IsAvailable);

        Assert.NotNull(s2);
        Assert.Equal(0, s2.BookedCount);
        Assert.Equal(5, s2.RemainingSlots);
        Assert.True(s2.IsAvailable);

        // 3. Customer attempts 6th booking on Slot 1 -> Must be rejected with 400
        var customerClient = CreateAuthenticatedClient(12, "customer12@pcforge.com", "Customer");
        var attemptSlot1 = new CreateServiceRequestDto
        {
            Title = "6th booking attempt for Slot 1",
            PreferredDate = targetDate,
            SlotId = 1
        };
        var resSlot1 = await customerClient.PostAsJsonAsync("/api/ServiceRequests", attemptSlot1);
        Assert.Equal(HttpStatusCode.BadRequest, resSlot1.StatusCode);
        var errSlot1 = await resSlot1.Content.ReadAsStringAsync();
        Assert.Contains("is full", errSlot1);

        // 4. Booking Slot 2 on the same date succeeds (proving per-slot limit)
        var attemptSlot2 = new CreateServiceRequestDto
        {
            Title = "Booking for Slot 2",
            PreferredDate = targetDate,
            SlotId = 2
        };
        var resSlot2 = await customerClient.PostAsJsonAsync("/api/ServiceRequests", attemptSlot2);
        Assert.Equal(HttpStatusCode.Created, resSlot2.StatusCode);
    }

    [Fact]
    public async Task Admin_CanOverrideSlotCapacity_AndCloseSlotForSpecificDate()
    {
        var adminClient = CreateAuthenticatedClient(1, "admin@pcforge.com", "Admin");
        var customerClient = CreateAuthenticatedClient(20, "customer20@pcforge.com", "Customer");
        var targetDate = DateTime.UtcNow.Date.AddDays(18);

        // 1. Admin overrides Slot 3: Increases capacity to 10 for targetDate
        var overrideCapPayload = new SetTimeSlotOverrideDto
        {
            Date = targetDate,
            CustomCapacity = 10,
            IsClosed = false
        };
        var overrideRes = await adminClient.PostAsJsonAsync("/api/ServiceRequests/admin/slots/3/override", overrideCapPayload);
        Assert.Equal(HttpStatusCode.OK, overrideRes.StatusCode);
        var overrideDto = await overrideRes.Content.ReadFromJsonAsync<SlotAvailabilityDto>();
        Assert.NotNull(overrideDto);
        Assert.Equal(10, overrideDto.MaxCapacity);
        Assert.Equal(10, overrideDto.RemainingSlots);
        Assert.True(overrideDto.IsOverridden);

        // 2. Admin overrides Slot 4: Closes slot 4 for targetDate (e.g., maintenance)
        var closePayload = new SetTimeSlotOverrideDto
        {
            Date = targetDate,
            IsClosed = true,
            Reason = "Facility maintenance"
        };
        var closeRes = await adminClient.PostAsJsonAsync("/api/ServiceRequests/admin/slots/4/override", closePayload);
        Assert.Equal(HttpStatusCode.OK, closeRes.StatusCode);
        var closedDto = await closeRes.Content.ReadFromJsonAsync<SlotAvailabilityDto>();
        Assert.NotNull(closedDto);
        Assert.True(closedDto.IsClosed);
        Assert.False(closedDto.IsAvailable);
        Assert.Equal(0, closedDto.RemainingSlots);

        // 3. Customer attempts to book closed Slot 4 -> Rejected with 400
        var attemptClosed = new CreateServiceRequestDto
        {
            Title = "Attempt booking closed slot",
            PreferredDate = targetDate,
            SlotId = 4
        };
        var resAttempt = await customerClient.PostAsJsonAsync("/api/ServiceRequests", attemptClosed);
        Assert.Equal(HttpStatusCode.BadRequest, resAttempt.StatusCode);
        var errAttempt = await resAttempt.Content.ReadAsStringAsync();
        Assert.Contains("closed", errAttempt);
    }

    [Fact]
    public async Task Admin_CannotReduceCapacityBelowExistingBookings()
    {
        var adminClient = CreateAuthenticatedClient(1, "admin@pcforge.com", "Admin");
        var targetDate = DateTime.UtcNow.Date.AddDays(22);
        int slotId = 2;

        // Pre-fill 3 bookings for Slot 2
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (int i = 1; i <= 3; i++)
            {
                db.ServiceRequests.Add(new ServiceRequest
                {
                    ServiceRequestNumber = $"SR-REDUCE-{i}-{Guid.NewGuid().ToString("N")[..4]}",
                    UserId = 1,
                    SlotId = slotId,
                    Title = $"Booking {i}",
                    PreferredDate = targetDate,
                    Status = "Pending"
                });
            }
            await db.SaveChangesAsync();
        }

        // Admin attempts date override with CustomCapacity = 2 (< 3 booked) -> Must fail
        var overridePayload = new SetTimeSlotOverrideDto
        {
            Date = targetDate,
            CustomCapacity = 2
        };
        var overrideRes = await adminClient.PostAsJsonAsync($"/api/ServiceRequests/admin/slots/{slotId}/override", overridePayload);
        Assert.Equal(HttpStatusCode.BadRequest, overrideRes.StatusCode);
        var err = await overrideRes.Content.ReadAsStringAsync();
        Assert.Contains("Cannot reduce capacity", err);

        // Admin attempts to reduce default capacity to 2 (< 3 active bookings) -> Must fail
        var updatePayload = new UpdateServiceTimeSlotDto
        {
            DefaultCapacity = 2
        };
        var updateRes = await adminClient.PutAsJsonAsync($"/api/ServiceRequests/admin/slots/{slotId}", updatePayload);
        Assert.Equal(HttpStatusCode.BadRequest, updateRes.StatusCode);
        var err2 = await updateRes.Content.ReadAsStringAsync();
        Assert.Contains("Cannot reduce capacity", err2);
    }

    [Fact]
    public async Task CannotDeleteSlotWithBookings_CanDeactivateInstead()
    {
        var adminClient = CreateAuthenticatedClient(1, "admin@pcforge.com", "Admin");
        var targetDate = DateTime.UtcNow.Date.AddDays(25);
        int slotId = 3;

        // Pre-fill a booking for Slot 3
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.ServiceRequests.Add(new ServiceRequest
            {
                ServiceRequestNumber = $"SR-NODELETE-{Guid.NewGuid().ToString("N")[..4]}",
                UserId = 1,
                SlotId = slotId,
                Title = "Booking preventing delete",
                PreferredDate = targetDate,
                Status = "Pending"
            });
            await db.SaveChangesAsync();
        }

        // Attempt DELETE -> Must be rejected with 400 instructing to deactivate
        var delRes = await adminClient.DeleteAsync($"/api/ServiceRequests/admin/slots/{slotId}");
        Assert.Equal(HttpStatusCode.BadRequest, delRes.StatusCode);
        var err = await delRes.Content.ReadAsStringAsync();
        Assert.Contains("deactivate", err.ToLower());

        // Deactivating the slot succeeds
        var patchRes = await adminClient.PatchAsync($"/api/ServiceRequests/admin/slots/{slotId}/toggle-active", null);
        Assert.Equal(HttpStatusCode.OK, patchRes.StatusCode);
        var toggled = await patchRes.Content.ReadFromJsonAsync<ServiceTimeSlotDto>();
        Assert.NotNull(toggled);
        Assert.False(toggled.IsActive);
    }

    [Fact]
    public async Task CancelledRequests_DoNotCountAsBooked_AndFreeUpCapacity()
    {
        var customerClient = CreateAuthenticatedClient(3, "alex@example.com", "Customer");
        var targetDate = DateTime.UtcNow.Date.AddDays(28);
        int slotId = 4; // Capacity 5

        // Create a booking
        var createPayload = new CreateServiceRequestDto
        {
            Title = "Will be cancelled",
            PreferredDate = targetDate,
            SlotId = slotId
        };
        var createRes = await customerClient.PostAsJsonAsync("/api/ServiceRequests", createPayload);
        Assert.Equal(HttpStatusCode.Created, createRes.StatusCode);
        var created = await createRes.Content.ReadFromJsonAsync<ServiceRequestDetailDto>();
        Assert.NotNull(created);

        // Pre-fill remaining 4 bookings to make it full (5 of 5)
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var maxId = await db.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 500;
            for (int i = 1; i <= 4; i++)
            {
                db.ServiceRequests.Add(new ServiceRequest
                {
                    ServiceRequestId = maxId + i,
                    ServiceRequestNumber = $"SR-FILL-{i}-{Guid.NewGuid().ToString("N")[..4]}",
                    UserId = 1,
                    SlotId = slotId,
                    Title = $"Filler {i}",
                    PreferredDate = targetDate,
                    Status = "Pending"
                });
            }
            await db.SaveChangesAsync();
        }

        // Slot is full
        var slotsRes1 = await _client.GetFromJsonAsync<List<SlotAvailabilityDto>>($"/api/ServiceRequests/slots?date={targetDate:yyyy-MM-dd}");
        Assert.NotNull(slotsRes1);
        var sBefore = slotsRes1.First(s => s.SlotId == slotId);
        Assert.Equal(0, sBefore.RemainingSlots);
        Assert.False(sBefore.IsAvailable);

        // Customer cancels their request
        var cancelRes = await customerClient.PostAsync($"/api/ServiceRequests/{created.ServiceRequestId}/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelRes.StatusCode);

        // Slot now has 1 available spot freed up!
        var slotsRes2 = await _client.GetFromJsonAsync<List<SlotAvailabilityDto>>($"/api/ServiceRequests/slots?date={targetDate:yyyy-MM-dd}");
        Assert.NotNull(slotsRes2);
        var sAfter = slotsRes2.First(s => s.SlotId == slotId);
        Assert.Equal(1, sAfter.RemainingSlots);
        Assert.True(sAfter.IsAvailable);

        // Another customer can now book the newly freed spot
        var newCustomerClient = CreateAuthenticatedClient(31, "customer31@pcforge.com", "Customer");
        var bookFreed = await newCustomerClient.PostAsJsonAsync("/api/ServiceRequests", new CreateServiceRequestDto
        {
            Title = "Booking freed spot",
            PreferredDate = targetDate,
            SlotId = slotId
        });
        Assert.Equal(HttpStatusCode.Created, bookFreed.StatusCode);
    }

    [Fact]
    public async Task ConcurrentBooking_PreventsOverbooking_WhenBookingLastSpot()
    {
        var targetDate = DateTime.UtcNow.Date.AddDays(35);
        int slotId = 1;

        // Clean any existing bookings for targetDate on slot 1, then pre-fill 4 bookings (capacity 5 -> 1 spot left)
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (int i = 1; i <= 4; i++)
            {
                db.ServiceRequests.Add(new ServiceRequest
                {
                    ServiceRequestNumber = $"SR-CONCURR-{i}-{Guid.NewGuid().ToString("N")[..4]}",
                    UserId = 1,
                    SlotId = slotId,
                    Title = $"Concurrent Setup {i}",
                    PreferredDate = targetDate,
                    Status = "Pending"
                });
            }
            await db.SaveChangesAsync();
        }

        // Two users attempt to book the single remaining spot at the exact same time
        var clientA = CreateAuthenticatedClient(50, "userA@pcforge.com", "Customer");
        var clientB = CreateAuthenticatedClient(51, "userB@pcforge.com", "Customer");

        var taskA = clientA.PostAsJsonAsync("/api/ServiceRequests", new CreateServiceRequestDto
        {
            Title = "User A Booking",
            PreferredDate = targetDate,
            SlotId = slotId
        });

        var taskB = clientB.PostAsJsonAsync("/api/ServiceRequests", new CreateServiceRequestDto
        {
            Title = "User B Booking",
            PreferredDate = targetDate,
            SlotId = slotId
        });

        var responses = await Task.WhenAll(taskA, taskB);

        var successCount = responses.Count(r => r.StatusCode == HttpStatusCode.Created);
        var fullCount = responses.Count(r => r.StatusCode == HttpStatusCode.BadRequest);

        // Exactly one user gets the last spot, and the other is rejected as full
        Assert.Equal(1, successCount);
        Assert.Equal(1, fullCount);
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
            SlotId = 2
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
            SlotId = 2
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
                ServiceRequestNumber = $"SR-FILTER-BOOKED-{Guid.NewGuid().ToString("N")[..4]}",
                UserId = 1,
                SlotId = 1,
                Title = "Filter Test Booked",
                Description = "Filter test",
                PreferredDate = baseDate,
                Status = "Booked"
            });
            db.ServiceRequests.Add(new ServiceRequest
            {
                ServiceRequestNumber = $"SR-FILTER-COMPLETED-{Guid.NewGuid().ToString("N")[..4]}",
                UserId = 1,
                SlotId = 2,
                Title = "Filter Test Completed",
                Description = "Filter test",
                PreferredDate = baseDate.AddDays(5),
                Status = "Completed"
            });
            await db.SaveChangesAsync();
        }

        // Filter by status = "Booked" and date range
        var filterUrl = $"/api/ServiceRequests?status=Booked&startDate={baseDate.AddDays(-1):yyyy-MM-dd}&endDate={baseDate.AddDays(1):yyyy-MM-dd}";
        var listRes = await adminClient.GetFromJsonAsync<List<ServiceRequestSummaryDto>>(filterUrl);
        Assert.NotNull(listRes);
        Assert.Contains(listRes, r => r.Title == "Filter Test Booked");
        Assert.DoesNotContain(listRes, r => r.Title == "Filter Test Completed");
    }
}
