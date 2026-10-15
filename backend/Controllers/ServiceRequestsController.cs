using System.Collections.Concurrent;
using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;
using PCForge.Api.Services;

namespace PCForge.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ServiceRequestsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IAiAgentService _aiAgentService;
    private readonly IEmailService _emailService;
    private readonly ILogger<ServiceRequestsController> _logger;

    // Concurrency lock dictionary to synchronize bookings per slot and date
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> _slotLocks = new();

    public ServiceRequestsController(
        AppDbContext context,
        IAiAgentService aiAgentService,
        IEmailService emailService,
        ILogger<ServiceRequestsController> logger)
    {
        _context = context;
        _aiAgentService = aiAgentService;
        _emailService = emailService;
        _logger = logger;
    }

    /// <summary>
    /// Executes AI After-Sales Service Agent for troubleshooting and service requests.
    /// </summary>
    [AllowAnonymous]
    [HttpPost("ai-chat")]
    public async Task<ActionResult<AfterSalesChatResponseDto>> AfterSalesChat([FromBody] AfterSalesChatRequestDto request)
    {
        var currentUserId = GetCurrentUserId() ?? (request.UserId > 0 ? request.UserId : 1);
        request.UserId = currentUserId;

        var result = await _aiAgentService.SendAfterSalesChatMessageAsync(request);
        if (!result.Success && string.IsNullOrEmpty(result.Reply))
        {
            return StatusCode(500, result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Checks availability and remaining slots for a service appointment date.
    /// Aggregates all active time slots and any date overrides.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("availability")]
    public async Task<ActionResult<ServiceAvailabilityDto>> CheckAvailability([FromQuery] DateTime? date)
    {
        if (!date.HasValue)
        {
            return BadRequest(new { message = "Date parameter is required." });
        }

        var targetDateUtc = DateTime.SpecifyKind(date.Value.Date, DateTimeKind.Utc);
        var slots = await GetSlotAvailabilityListAsync(targetDateUtc);

        var totalCapacity = slots.Sum(s => s.MaxCapacity);
        var totalBooked = slots.Sum(s => s.BookedCount);
        var totalRemaining = slots.Sum(s => s.RemainingSlots);
        var isAvailable = slots.Any(s => s.IsAvailable);

        return Ok(new ServiceAvailabilityDto
        {
            Date = targetDateUtc.ToString("yyyy-MM-dd"),
            BookedCount = totalBooked,
            MaxCapacity = totalCapacity,
            RemainingSlots = totalRemaining,
            IsAvailable = isAvailable,
            Slots = slots
        });
    }

    /// <summary>
    /// Returns time slots with availability details for a given appointment date.
    /// Full or closed slots are indicated with remainingSlots = 0 and isAvailable = false.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("slots")]
    public async Task<ActionResult<List<SlotAvailabilityDto>>> GetSlotsForDate([FromQuery] DateTime? date)
    {
        if (!date.HasValue)
        {
            return BadRequest(new { message = "Date parameter is required." });
        }

        var targetDateUtc = DateTime.SpecifyKind(date.Value.Date, DateTimeKind.Utc);
        var slots = await GetSlotAvailabilityListAsync(targetDateUtc);
        return Ok(slots);
    }

    /// <summary>
    /// Retrieve all configured time slots (Staff/Admin).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpGet("admin/slots")]
    public async Task<ActionResult<List<ServiceTimeSlotDto>>> GetAllSlotsAdmin()
    {
        var slots = await _context.ServiceTimeSlots
            .AsNoTracking()
            .OrderBy(s => s.StartTime)
            .ThenBy(s => s.EndTime)
            .Select(s => new ServiceTimeSlotDto
            {
                SlotId = s.SlotId,
                StartTime = s.StartTime,
                EndTime = s.EndTime,
                Label = s.Label ?? $"{s.StartTime} - {s.EndTime}",
                DefaultCapacity = s.DefaultCapacity,
                IsActive = s.IsActive,
                DisplayOrder = s.DisplayOrder,
                CreatedAt = s.CreatedAt,
                UpdatedAt = s.UpdatedAt
            })
            .ToListAsync();

        return Ok(slots);
    }

    /// <summary>
    /// Retrieve single time slot by ID (Staff/Admin).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpGet("admin/slots/{id:int}")]
    public async Task<ActionResult<ServiceTimeSlotDto>> GetSlotById(int id)
    {
        var slot = await _context.ServiceTimeSlots.FindAsync(id);
        if (slot == null)
        {
            return NotFound(new { message = $"Time slot #{id} not found." });
        }

        return Ok(new ServiceTimeSlotDto
        {
            SlotId = slot.SlotId,
            StartTime = slot.StartTime,
            EndTime = slot.EndTime,
            Label = slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
            DefaultCapacity = slot.DefaultCapacity,
            IsActive = slot.IsActive,
            DisplayOrder = slot.DisplayOrder,
            CreatedAt = slot.CreatedAt,
            UpdatedAt = slot.UpdatedAt
        });
    }

    /// <summary>
    /// Create a new time slot (Staff/Admin).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost("admin/slots")]
    public async Task<ActionResult<ServiceTimeSlotDto>> CreateSlotAdmin([FromBody] CreateServiceTimeSlotDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.StartTime) || string.IsNullOrWhiteSpace(dto.EndTime))
        {
            return BadRequest(new { message = "Start time and end time are required." });
        }

        if (!System.Text.RegularExpressions.Regex.IsMatch(dto.StartTime.Trim(), @"^([01]\d|2[0-3]):[0-5]\d$") ||
            !System.Text.RegularExpressions.Regex.IsMatch(dto.EndTime.Trim(), @"^([01]\d|2[0-3]):[0-5]\d$"))
        {
            return BadRequest(new { message = "Start time and end time must be in valid 24-hour format HH:mm (e.g. 09:00, 11:00)." });
        }

        if (string.Compare(dto.StartTime.Trim(), dto.EndTime.Trim(), StringComparison.Ordinal) >= 0)
        {
            return BadRequest(new { message = "End time must be after start time." });
        }

        if (dto.DefaultCapacity <= 0)
        {
            return BadRequest(new { message = "Default capacity must be at least 1." });
        }

        var label = !string.IsNullOrWhiteSpace(dto.Label)
            ? dto.Label.Trim()
            : $"{dto.StartTime.Trim()} - {dto.EndTime.Trim()}";

        var slot = new ServiceTimeSlot
        {
            StartTime = dto.StartTime.Trim(),
            EndTime = dto.EndTime.Trim(),
            Label = label,
            DefaultCapacity = dto.DefaultCapacity,
            IsActive = dto.IsActive,
            DisplayOrder = dto.DisplayOrder,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.ServiceTimeSlots.Add(slot);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Time Slot #{SlotId} created: {Label} (Capacity: {Cap})",
            slot.SlotId, slot.Label, slot.DefaultCapacity);

        return CreatedAtAction(nameof(GetSlotById), new { id = slot.SlotId }, new ServiceTimeSlotDto
        {
            SlotId = slot.SlotId,
            StartTime = slot.StartTime,
            EndTime = slot.EndTime,
            Label = slot.Label,
            DefaultCapacity = slot.DefaultCapacity,
            IsActive = slot.IsActive,
            DisplayOrder = slot.DisplayOrder,
            CreatedAt = slot.CreatedAt,
            UpdatedAt = slot.UpdatedAt
        });
    }

    /// <summary>
    /// Update a time slot (Staff/Admin).
    /// Rule: Cannot reduce capacity below the number already booked.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("admin/slots/{id:int}")]
    public async Task<ActionResult<ServiceTimeSlotDto>> UpdateSlotAdmin(int id, [FromBody] UpdateServiceTimeSlotDto dto)
    {
        var slot = await _context.ServiceTimeSlots.FindAsync(id);
        if (slot == null)
        {
            return NotFound(new { message = $"Time slot #{id} not found." });
        }

        if (dto.DefaultCapacity.HasValue)
        {
            if (dto.DefaultCapacity.Value <= 0)
            {
                return BadRequest(new { message = "Default capacity must be at least 1." });
            }

            if (dto.DefaultCapacity.Value < slot.DefaultCapacity)
            {
                // Check if any date from today onwards has active bookings exceeding new capacity
                var todayUtc = DateTime.UtcNow.Date;
                var activeBookings = await _context.ServiceRequests
                    .Where(sr => sr.SlotId == id &&
                                 sr.PreferredDate.HasValue &&
                                 sr.PreferredDate.Value.Date >= todayUtc &&
                                 sr.Status.ToLower() != "cancelled" &&
                                 sr.Status.ToLower() != "canceled" &&
                                 sr.Status.ToLower() != "rejected")
                    .GroupBy(sr => sr.PreferredDate.Value.Date)
                    .Select(g => new { Date = g.Key, Count = g.Count() })
                    .ToListAsync();

                var dateOverrides = await _context.ServiceTimeSlotOverrides
                    .Where(o => o.SlotId == id && o.Date >= todayUtc)
                    .ToDictionaryAsync(o => o.Date.Date, o => o);

                foreach (var b in activeBookings)
                {
                    if (dateOverrides.TryGetValue(b.Date, out var ov) && ov.CustomCapacity.HasValue)
                    {
                        continue; // Date has its own custom capacity override
                    }

                    if (dto.DefaultCapacity.Value < b.Count)
                    {
                        return BadRequest(new { message = $"Cannot reduce capacity to {dto.DefaultCapacity.Value} because {b.Date:yyyy-MM-dd} already has {b.Count} active booking(s)." });
                    }
                }
            }

            slot.DefaultCapacity = dto.DefaultCapacity.Value;
        }

        var newStart = !string.IsNullOrWhiteSpace(dto.StartTime) ? dto.StartTime.Trim() : slot.StartTime;
        var newEnd = !string.IsNullOrWhiteSpace(dto.EndTime) ? dto.EndTime.Trim() : slot.EndTime;

        if (!System.Text.RegularExpressions.Regex.IsMatch(newStart, @"^([01]\d|2[0-3]):[0-5]\d$") ||
            !System.Text.RegularExpressions.Regex.IsMatch(newEnd, @"^([01]\d|2[0-3]):[0-5]\d$"))
        {
            return BadRequest(new { message = "Start time and end time must be in valid 24-hour format HH:mm (e.g. 09:00, 11:00)." });
        }

        if (string.Compare(newStart, newEnd, StringComparison.Ordinal) >= 0)
        {
            return BadRequest(new { message = "End time must be after start time." });
        }

        slot.StartTime = newStart;
        slot.EndTime = newEnd;
        if (dto.Label != null) slot.Label = string.IsNullOrWhiteSpace(dto.Label) ? $"{slot.StartTime} - {slot.EndTime}" : dto.Label.Trim();
        if (dto.IsActive.HasValue) slot.IsActive = dto.IsActive.Value;
        if (dto.DisplayOrder.HasValue) slot.DisplayOrder = dto.DisplayOrder.Value;

        slot.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Time Slot #{SlotId} updated: {Label} (Capacity: {Cap}, Active: {IsActive})",
            slot.SlotId, slot.Label, slot.DefaultCapacity, slot.IsActive);

        return Ok(new ServiceTimeSlotDto
        {
            SlotId = slot.SlotId,
            StartTime = slot.StartTime,
            EndTime = slot.EndTime,
            Label = slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
            DefaultCapacity = slot.DefaultCapacity,
            IsActive = slot.IsActive,
            DisplayOrder = slot.DisplayOrder,
            CreatedAt = slot.CreatedAt,
            UpdatedAt = slot.UpdatedAt
        });
    }

    /// <summary>
    /// Delete a time slot (Staff/Admin).
    /// Rule: Cannot delete a slot that has bookings (deactivate instead).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("admin/slots/{id:int}")]
    public async Task<IActionResult> DeleteSlotAdmin(int id)
    {
        var slot = await _context.ServiceTimeSlots.FindAsync(id);
        if (slot == null)
        {
            return NotFound(new { message = $"Time slot #{id} not found." });
        }

        var hasBookings = await _context.ServiceRequests.AnyAsync(sr => sr.SlotId == id);
        if (hasBookings)
        {
            return BadRequest(new { message = "Cannot delete a time slot that has existing bookings. Please deactivate it instead." });
        }

        _context.ServiceTimeSlots.Remove(slot);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Time Slot #{SlotId} was deleted", id);
        return NoContent();
    }

    /// <summary>
    /// Toggle active status of a time slot (Staff/Admin).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPatch("admin/slots/{id:int}/toggle-active")]
    public async Task<ActionResult<ServiceTimeSlotDto>> ToggleSlotActiveAdmin(int id)
    {
        var slot = await _context.ServiceTimeSlots.FindAsync(id);
        if (slot == null)
        {
            return NotFound(new { message = $"Time slot #{id} not found." });
        }

        slot.IsActive = !slot.IsActive;
        slot.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Time Slot #{SlotId} active toggled to {IsActive}", id, slot.IsActive);

        return Ok(new ServiceTimeSlotDto
        {
            SlotId = slot.SlotId,
            StartTime = slot.StartTime,
            EndTime = slot.EndTime,
            Label = slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
            DefaultCapacity = slot.DefaultCapacity,
            IsActive = slot.IsActive,
            DisplayOrder = slot.DisplayOrder,
            CreatedAt = slot.CreatedAt,
            UpdatedAt = slot.UpdatedAt
        });
    }

    /// <summary>
    /// Override max capacity for a slot on a specific date, or close it for that date (Staff/Admin).
    /// Rule: Cannot reduce capacity below the number already booked.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost("admin/slots/{id:int}/override")]
    public async Task<ActionResult<SlotAvailabilityDto>> SetSlotOverrideAdmin(int id, [FromBody] SetTimeSlotOverrideDto dto)
    {
        var slot = await _context.ServiceTimeSlots.FindAsync(id);
        if (slot == null)
        {
            return NotFound(new { message = $"Time slot #{id} not found." });
        }

        var targetDateUtc = DateTime.SpecifyKind(dto.Date.Date, DateTimeKind.Utc);

        var bookedCount = await _context.ServiceRequests.CountAsync(sr =>
            sr.SlotId == id &&
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value.Date == targetDateUtc.Date &&
            sr.Status.ToLower() != "cancelled" &&
            sr.Status.ToLower() != "canceled" &&
            sr.Status.ToLower() != "rejected");

        if (dto.CustomCapacity.HasValue && dto.CustomCapacity.Value < bookedCount)
        {
            return BadRequest(new { message = $"Cannot reduce capacity to {dto.CustomCapacity.Value} because this slot already has {bookedCount} active booking(s) on {targetDateUtc:yyyy-MM-dd}." });
        }

        var overrideRecord = await _context.ServiceTimeSlotOverrides
            .FirstOrDefaultAsync(o => o.SlotId == id && o.Date.Date == targetDateUtc.Date);

        if (overrideRecord == null)
        {
            overrideRecord = new ServiceTimeSlotOverride
            {
                SlotId = id,
                Date = targetDateUtc.Date,
                CustomCapacity = dto.CustomCapacity,
                IsClosed = dto.IsClosed,
                Reason = dto.Reason,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.ServiceTimeSlotOverrides.Add(overrideRecord);
        }
        else
        {
            overrideRecord.CustomCapacity = dto.CustomCapacity;
            overrideRecord.IsClosed = dto.IsClosed;
            overrideRecord.Reason = dto.Reason;
            overrideRecord.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();

        var maxCap = overrideRecord.IsClosed ? 0 : (overrideRecord.CustomCapacity ?? slot.DefaultCapacity);
        var remaining = Math.Max(0, maxCap - bookedCount);

        return Ok(new SlotAvailabilityDto
        {
            SlotId = slot.SlotId,
            StartTime = slot.StartTime,
            EndTime = slot.EndTime,
            Label = slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
            DefaultCapacity = slot.DefaultCapacity,
            MaxCapacity = maxCap,
            BookedCount = bookedCount,
            RemainingSlots = remaining,
            IsAvailable = slot.IsActive && !overrideRecord.IsClosed && remaining > 0,
            IsClosed = overrideRecord.IsClosed,
            Reason = overrideRecord.Reason,
            IsActive = slot.IsActive,
            IsOverridden = true
        });
    }

    /// <summary>
    /// Remove override for a slot on a date, returning to default capacity (Staff/Admin).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("admin/slots/{id:int}/override")]
    public async Task<IActionResult> RemoveSlotOverrideAdmin(int id, [FromQuery] DateTime date)
    {
        var slot = await _context.ServiceTimeSlots.FindAsync(id);
        if (slot == null)
        {
            return NotFound(new { message = $"Time slot #{id} not found." });
        }

        var targetDateUtc = DateTime.SpecifyKind(date.Date, DateTimeKind.Utc);
        var overrideRecord = await _context.ServiceTimeSlotOverrides
            .FirstOrDefaultAsync(o => o.SlotId == id && o.Date.Date == targetDateUtc.Date);

        if (overrideRecord == null)
        {
            return NotFound(new { message = $"No override found for slot #{id} on {targetDateUtc:yyyy-MM-dd}." });
        }

        var bookedCount = await _context.ServiceRequests.CountAsync(sr =>
            sr.SlotId == id &&
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value.Date == targetDateUtc.Date &&
            sr.Status.ToLower() != "cancelled" &&
            sr.Status.ToLower() != "canceled" &&
            sr.Status.ToLower() != "rejected");

        if (slot.DefaultCapacity < bookedCount)
        {
            return BadRequest(new { message = $"Cannot reset override because default capacity ({slot.DefaultCapacity}) is less than current active bookings ({bookedCount}) on {targetDateUtc:yyyy-MM-dd}." });
        }

        _context.ServiceTimeSlotOverrides.Remove(overrideRecord);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Retrieve customer's service requests or storewide list for staff/admin with optional status, search, and date range filters.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<ServiceRequestSummaryDto>>> GetServiceRequests(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null,
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null)
    {
        var currentUserId = GetCurrentUserId();
        var isStaffOrAdmin = User.Identity?.IsAuthenticated == true && (User.IsInRole("Admin") || User.IsInRole("Staff"));
        var query = _context.ServiceRequests
            .AsNoTracking()
            .Include(sr => sr.User)
            .Include(sr => sr.Slot)
            .AsQueryable();

        if (!isStaffOrAdmin)
        {
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "You must be logged in to view your service requests." });
            }
            query = query.Where(sr => sr.UserId == currentUserId.Value);
        }

        if (!string.IsNullOrWhiteSpace(status) && status.ToLower() != "all")
        {
            var clean = status.Trim().ToLower().Replace("_", " ");
            if (clean == "in progress" || clean == "in service")
            {
                query = query.Where(sr => sr.Status.ToLower() == "in progress" || sr.Status.ToLower() == "in_progress" || sr.Status.ToLower() == "in_service" || sr.Status.ToLower() == "scheduled" || sr.Status.ToLower() == "under review" || sr.Status.ToLower() == "under_review");
            }
            else if (clean == "completed" || clean == "resolved")
            {
                query = query.Where(sr => sr.Status.ToLower() == "completed" || sr.Status.ToLower() == "resolved");
            }
            else if (clean == "no show" || clean == "noshow")
            {
                query = query.Where(sr => sr.Status.ToLower() == "no show" || sr.Status.ToLower() == "no_show" || sr.Status.ToLower() == "noshow");
            }
            else if (clean == "cancelled" || clean == "canceled")
            {
                query = query.Where(sr => sr.Status.ToLower() == "cancelled" || sr.Status.ToLower() == "canceled");
            }
            else
            {
                query = query.Where(sr => sr.Status.ToLower() == clean);
            }
        }

        if (startDate.HasValue)
        {
            var start = startDate.Value.Date;
            query = query.Where(sr => (sr.PreferredDate.HasValue && sr.PreferredDate.Value.Date >= start) || (!sr.PreferredDate.HasValue && sr.CreatedAt >= start));
        }

        if (endDate.HasValue)
        {
            var end = endDate.Value.Date.AddDays(1).AddTicks(-1);
            query = query.Where(sr => (sr.PreferredDate.HasValue && sr.PreferredDate.Value.Date <= endDate.Value.Date) || (!sr.PreferredDate.HasValue && sr.CreatedAt <= end));
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(sr =>
                sr.ServiceRequestNumber.ToLower().Contains(term) ||
                (sr.Title != null && sr.Title.ToLower().Contains(term)) ||
                (sr.Description != null && sr.Description.ToLower().Contains(term)) ||
                (sr.User != null && ((sr.User.FirstName != null && sr.User.FirstName.ToLower().Contains(term)) || (sr.User.LastName != null && sr.User.LastName.ToLower().Contains(term)) || sr.User.Email.ToLower().Contains(term))));
        }

        var list = await query
            .OrderByDescending(sr => sr.CreatedAt)
            .Select(sr => new ServiceRequestSummaryDto
            {
                ServiceRequestId = sr.ServiceRequestId,
                ServiceRequestNumber = sr.ServiceRequestNumber,
                UserId = sr.UserId,
                SlotId = sr.SlotId,
                TimeSlotLabel = sr.Slot != null ? sr.Slot.Label : sr.PreferredTime,
                CustomerName = sr.User != null ? $"{sr.User.FirstName} {sr.User.LastName}".Trim() : null,
                CustomerEmail = sr.User != null ? sr.User.Email : null,
                Title = !string.IsNullOrWhiteSpace(sr.Title) ? sr.Title : "Service Request",
                Description = sr.Description,
                PreferredDate = sr.PreferredDate,
                PreferredTime = sr.PreferredTime,
                Status = sr.Status,
                CreatedAt = sr.CreatedAt
            })
            .ToListAsync();

        return Ok(list);
    }

    /// <summary>
    /// Retrieve single Service Request by ID or SR-Number.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("{id}")]
    public async Task<ActionResult<ServiceRequestDetailDto>> GetServiceRequestById(string id)
    {
        var currentUserId = GetCurrentUserId() ?? 1;
        var isStaffOrAdmin = User.Identity?.IsAuthenticated == true && (User.IsInRole("Admin") || User.IsInRole("Staff"));

        ServiceRequest? request = null;
        if (int.TryParse(id, out int numericId))
        {
            request = await _context.ServiceRequests
                .AsNoTracking()
                .Include(sr => sr.User)
                .Include(sr => sr.Slot)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var cleanSrNumber = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .AsNoTracking()
                .Include(sr => sr.User)
                .Include(sr => sr.Slot)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestNumber.ToUpper() == cleanSrNumber);
        }

        if (request == null)
        {
            return NotFound(new { message = $"Service Request '{id}' not found." });
        }

        if (!isStaffOrAdmin && request.UserId != currentUserId)
        {
            return Forbid();
        }

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            SlotId = request.SlotId,
            TimeSlotLabel = request.Slot != null ? request.Slot.Label : request.PreferredTime,
            CustomerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : null,
            CustomerEmail = request.User != null ? request.User.Email : null,
            CustomerPhone = null,
            Title = !string.IsNullOrWhiteSpace(request.Title) ? request.Title : "Service Request",
            Description = request.Description,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Create a new Service Request (Customer or Staff).
    /// Enforces date and time slot validation with concurrency transaction locks.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<ServiceRequestDetailDto>> CreateServiceRequest([FromBody] CreateServiceRequestDto dto)
    {
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized(new { message = "You must be logged in to create a service request." });
        }
        int userId = currentUserId.Value;

        // Resolve Title and Description (graceful defaults)
        var resolvedTitle = !string.IsNullOrWhiteSpace(dto.Title)
            ? dto.Title.Trim()
            : (!string.IsNullOrWhiteSpace(dto.Description) 
                ? (dto.Description.Length > 50 ? dto.Description.Substring(0, 50) + "..." : dto.Description.Trim())
                : "Service Request");

        var resolvedDescription = !string.IsNullOrWhiteSpace(dto.Description)
            ? dto.Description.Trim()
            : null;

        // Enforce required appointment date
        if (!dto.PreferredDate.HasValue)
        {
            return BadRequest(new { message = "Appointment date is required. Please select a date." });
        }

        var prefDateUtc = DateTime.SpecifyKind(dto.PreferredDate.Value.Date, DateTimeKind.Utc);
        dto.PreferredDate = prefDateUtc;
        if (prefDateUtc < DateTime.UtcNow.Date)
        {
            return BadRequest(new { message = "Appointment date cannot be in the past. Please select a future date." });
        }

        // Resolve Slot
        ServiceTimeSlot? slot = null;
        if (dto.SlotId.HasValue && dto.SlotId.Value > 0)
        {
            slot = await _context.ServiceTimeSlots.FirstOrDefaultAsync(s => s.SlotId == dto.SlotId.Value);
        }
        else if (!string.IsNullOrWhiteSpace(dto.PreferredTime))
        {
            var cleanTime = dto.PreferredTime.Trim().ToLower();
            slot = await _context.ServiceTimeSlots.FirstOrDefaultAsync(s =>
                s.IsActive &&
                ((s.Label != null && s.Label.ToLower().Contains(cleanTime)) ||
                 s.StartTime.ToLower() == cleanTime ||
                 (s.StartTime + " - " + s.EndTime).ToLower() == cleanTime));

            if (slot == null)
            {
                // Fallback: pick the first active slot for backward compatibility
                slot = await _context.ServiceTimeSlots
                    .Where(s => s.IsActive)
                    .OrderBy(s => s.DisplayOrder)
                    .FirstOrDefaultAsync();
            }
        }

        if (slot == null)
        {
            return BadRequest(new { message = "Time slot is required. Please select a valid time slot." });
        }

        if (!slot.IsActive)
        {
            return BadRequest(new { message = "The selected time slot is currently inactive. Please choose an active time slot." });
        }

        // Intra-process lock per slot and date to serialize concurrent bookings
        var lockKey = $"{slot.SlotId}_{prefDateUtc:yyyyMMdd}";
        var sem = _slotLocks.GetOrAdd(lockKey, _ => new SemaphoreSlim(1, 1));
        await sem.WaitAsync();

        try
        {
            var strategy = _context.Database.CreateExecutionStrategy();
            return await strategy.ExecuteAsync<ActionResult<ServiceRequestDetailDto>>(async () =>
            {
                IDbContextTransaction? transaction = null;
                if (_context.Database.IsRelational())
                {
                    transaction = await _context.Database.BeginTransactionAsync(IsolationLevel.Serializable);
                }

                try
                {
                    // Check date override for this slot
                    var overrideRecord = await _context.ServiceTimeSlotOverrides
                        .FirstOrDefaultAsync(o => o.SlotId == slot.SlotId && o.Date.Date == prefDateUtc.Date);

                    if (overrideRecord != null && overrideRecord.IsClosed)
                    {
                        return BadRequest(new { message = $"The selected time slot ({slot.Label ?? slot.StartTime}) is closed on {prefDateUtc:yyyy-MM-dd}. Please choose another time slot." });
                    }

                    var effectiveCapacity = overrideRecord?.CustomCapacity ?? slot.DefaultCapacity;

                    // Count bookings: Cancelled or rejected requests don't count as booked
                    var bookedCount = await _context.ServiceRequests.CountAsync(sr =>
                        sr.SlotId == slot.SlotId &&
                        sr.PreferredDate.HasValue &&
                        sr.PreferredDate.Value.Date == prefDateUtc.Date &&
                        sr.Status.ToLower() != "cancelled" &&
                        sr.Status.ToLower() != "canceled" &&
                        sr.Status.ToLower() != "rejected");

                    if (bookedCount >= effectiveCapacity)
                    {
                        return BadRequest(new { message = $"The selected time slot ({slot.Label ?? slot.StartTime}) is full for {prefDateUtc:yyyy-MM-dd} ({bookedCount}/{effectiveCapacity} booked). Please choose another time slot." });
                    }

                    // Generate next Service Request Number
                    var maxId = await _context.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 100;
                    var nextId = maxId + 1;
                    var srNumber = $"SR-{nextId:D6}";

                    var preferredTime = !string.IsNullOrWhiteSpace(dto.PreferredTime)
                        ? dto.PreferredTime.Trim()
                        : (slot.Label ?? $"{slot.StartTime} - {slot.EndTime}");

                    var request = new ServiceRequest
                    {
                        ServiceRequestId = _context.Database.IsRelational() ? 0 : nextId,
                        ServiceRequestNumber = srNumber,
                        UserId = userId,
                        SlotId = slot.SlotId,
                        Title = resolvedTitle,
                        Description = resolvedDescription,
                        PreferredDate = dto.PreferredDate,
                        PreferredTime = preferredTime,
                        Status = "Booked",
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };

                    _context.ServiceRequests.Add(request);
                    await _context.SaveChangesAsync();

                    if (transaction != null)
                    {
                        await transaction.CommitAsync();
                    }

                    _logger.LogInformation("Service Request {SrNumber} created for User {UserId} in Slot #{SlotId} on {Date}",
                        request.ServiceRequestNumber, userId, slot.SlotId, prefDateUtc.ToString("yyyy-MM-dd"));

                    // Dispatch confirmation email
                    try
                    {
                        var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserId == userId);
                        if (!string.IsNullOrWhiteSpace(user?.Email))
                        {
                            var customerName = string.Join(" ", new[] { user.FirstName, user.LastName }.Where(s => !string.IsNullOrWhiteSpace(s)));
                            if (string.IsNullOrWhiteSpace(customerName)) customerName = "Valued Customer";

                            _ = _emailService.SendServiceRequestNotificationAsync(
                                user.Email,
                                customerName,
                                request.ServiceRequestNumber,
                                request.Status,
                                request.Title,
                                request.PreferredDate,
                                slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
                                request.Description);
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to dispatch service request received email for {SrNumber}", request.ServiceRequestNumber);
                    }

                    return CreatedAtAction(nameof(GetServiceRequestById), new { id = request.ServiceRequestId }, new ServiceRequestDetailDto
                    {
                        ServiceRequestId = request.ServiceRequestId,
                        ServiceRequestNumber = request.ServiceRequestNumber,
                        UserId = request.UserId,
                        SlotId = slot.SlotId,
                        TimeSlotLabel = slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
                        CustomerName = null,
                        CustomerEmail = null,
                        Title = request.Title,
                        Description = request.Description,
                        PreferredDate = request.PreferredDate,
                        PreferredTime = request.PreferredTime,
                        Status = request.Status,
                        CreatedAt = request.CreatedAt,
                        UpdatedAt = request.UpdatedAt
                    });
                }
                catch
                {
                    if (transaction != null)
                    {
                        await transaction.RollbackAsync();
                    }
                    throw;
                }
            });
        }
        finally
        {
            sem.Release();
        }
    }

    /// <summary>
    /// Cancel a service request (Customer can cancel their own request, staff/admin can cancel any).
    /// Frees up the slot capacity for other customers.
    /// </summary>
    [HttpPost("{id}/cancel")]
    public async Task<ActionResult<ServiceRequestDetailDto>> CancelServiceRequest(string id)
    {
        var currentUserId = GetCurrentUserId();
        var isStaffOrAdmin = User.Identity?.IsAuthenticated == true && (User.IsInRole("Admin") || User.IsInRole("Staff"));

        if (!isStaffOrAdmin && !currentUserId.HasValue)
        {
            return Unauthorized(new { message = "You must be logged in to cancel a service request." });
        }

        ServiceRequest? request = null;
        if (int.TryParse(id, out int numericId))
        {
            request = await _context.ServiceRequests
                .Include(sr => sr.User)
                .Include(sr => sr.Slot)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var cleanSrNumber = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .Include(sr => sr.User)
                .Include(sr => sr.Slot)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestNumber.ToUpper() == cleanSrNumber);
        }

        if (request == null)
        {
            return NotFound(new { message = $"Service Request '{id}' not found." });
        }

        if (!isStaffOrAdmin && request.UserId != currentUserId.Value)
        {
            return Forbid();
        }

        var normalizedStatus = NormalizeStatus(request.Status);
        if (!isStaffOrAdmin && normalizedStatus != "Booked" && normalizedStatus != "Pending")
        {
            return BadRequest(new { message = "Customers can only cancel a Service Request while it is in Booked status." });
        }

        if (normalizedStatus == "Completed" || normalizedStatus == "Cancelled" || normalizedStatus == "No Show" || normalizedStatus == "Rejected")
        {
            return BadRequest(new { message = $"Cannot cancel a service request that is already '{request.Status}'." });
        }

        request.Status = "Cancelled";
        request.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Service Request {SrNumber} was cancelled by User {UserId}", request.ServiceRequestNumber, currentUserId);

        // Dispatch cancellation email
        var customerEmail = request.User?.Email;
        var customerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : "";
        if (string.IsNullOrWhiteSpace(customerName)) customerName = request.User?.Email ?? "Valued Customer";

        if (!string.IsNullOrWhiteSpace(customerEmail))
        {
            try
            {
                _ = _emailService.SendServiceRequestNotificationAsync(
                    customerEmail,
                    customerName,
                    request.ServiceRequestNumber,
                    "Cancelled",
                    request.Title,
                    request.PreferredDate,
                    request.PreferredTime,
                    "Service appointment cancelled and time slot released.");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to dispatch service request cancellation email for {SrNumber}", request.ServiceRequestNumber);
            }
        }

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            SlotId = request.SlotId,
            TimeSlotLabel = request.Slot != null ? request.Slot.Label : request.PreferredTime,
            CustomerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : null,
            CustomerEmail = request.User != null ? request.User.Email : null,
            Title = !string.IsNullOrWhiteSpace(request.Title) ? request.Title : "Service Request",
            Description = request.Description,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Update service request status and appointment date/time/slot (Technician/Staff only).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id}")]
    public async Task<ActionResult<ServiceRequestDetailDto>> UpdateServiceRequest(string id, [FromBody] UpdateServiceRequestDto dto)
    {
        ServiceRequest? request = null;
        if (int.TryParse(id, out int numericId))
        {
            request = await _context.ServiceRequests
                .Include(sr => sr.User)
                .Include(sr => sr.Slot)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var clean = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .Include(sr => sr.User)
                .Include(sr => sr.Slot)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestNumber.ToUpper() == clean);
        }

        if (request == null)
        {
            return NotFound(new { message = $"Service Request '{id}' not found." });
        }

        if (!string.IsNullOrWhiteSpace(dto.Status))
        {
            request.Status = NormalizeStatus(dto.Status);
        }

        var willCountAsBooked = request.Status.ToLower() != "cancelled" &&
                                request.Status.ToLower() != "canceled" &&
                                request.Status.ToLower() != "rejected";

        if (willCountAsBooked && (dto.SlotId.HasValue || dto.PreferredDate.HasValue))
        {
            var targetSlotId = dto.SlotId ?? request.SlotId;
            var targetDate = dto.PreferredDate.HasValue
                ? DateTime.SpecifyKind(dto.PreferredDate.Value.Date, DateTimeKind.Utc)
                : request.PreferredDate?.Date;

            if (targetSlotId.HasValue && targetDate.HasValue)
            {
                if (await IsSlotOverCapacityAsync(targetSlotId.Value, targetDate.Value, request.ServiceRequestId))
                {
                    return BadRequest(new { message = $"The selected time slot is full or unavailable on {targetDate.Value:yyyy-MM-dd}." });
                }
                request.SlotId = targetSlotId.Value;
                request.PreferredDate = targetDate.Value;
            }
        }
        else if (dto.PreferredDate.HasValue)
        {
            request.PreferredDate = DateTime.SpecifyKind(dto.PreferredDate.Value.Date, DateTimeKind.Utc);
        }

        if (!string.IsNullOrWhiteSpace(dto.PreferredTime))
        {
            request.PreferredTime = dto.PreferredTime.Trim();
        }

        request.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Service Request {SrNumber} updated: Status={Status}",
            request.ServiceRequestNumber, request.Status);

        // Dispatch status update email
        var updateEmail = request.User?.Email;
        var updateCustomerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : "";
        if (string.IsNullOrWhiteSpace(updateCustomerName)) updateCustomerName = request.User?.Email ?? "Valued Customer";

        if (!string.IsNullOrWhiteSpace(updateEmail))
        {
            try
            {
                _ = _emailService.SendServiceRequestNotificationAsync(
                    updateEmail,
                    updateCustomerName,
                    request.ServiceRequestNumber,
                    request.Status,
                    request.Title,
                    request.PreferredDate,
                    request.PreferredTime,
                    request.Description);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to dispatch service request update email for {SrNumber} ({Status})",
                    request.ServiceRequestNumber, request.Status);
            }
        }

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            SlotId = request.SlotId,
            TimeSlotLabel = request.Slot != null ? request.Slot.Label : request.PreferredTime,
            CustomerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : null,
            CustomerEmail = request.User != null ? request.User.Email : null,
            Title = !string.IsNullOrWhiteSpace(request.Title) ? request.Title : "Service Request",
            Description = request.Description,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Retrieve verified order purchase and warranty data from live database for an order ID.
    /// </summary>
    [HttpGet("orders/{orderId:int}/warranty")]
    public async Task<ActionResult<OrderWarrantyInfoDto>> GetOrderWarrantyInfo(int orderId)
    {
        var order = await _context.Orders
            .AsNoTracking()
            .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                    .ThenInclude(p => p!.Category)
            .FirstOrDefaultAsync(o => o.OrderId == orderId);

        if (order == null)
        {
            return NotFound(new { message = $"Order #{orderId} not found." });
        }

        var currentUserId = GetCurrentUserId();
        var isStaffOrAdmin = User.IsInRole("Admin") || User.IsInRole("Staff");
        if (!isStaffOrAdmin && order.UserId != currentUserId)
        {
            return Forbid();
        }

        var result = new OrderWarrantyInfoDto
        {
            OrderId = order.OrderId,
            OrderNumber = $"PCF-10{order.OrderId:03d}",
            OrderDate = order.CreatedAt,
            Status = order.Status,
            Items = order.Items.Select(item =>
            {
                var catName = item.Product?.Category?.Name ?? "Hardware";
                var months = (item.Product != null && item.Product.WarrantyMonths > 0)
                    ? item.Product.WarrantyMonths 
                    : GetWarrantyMonths(catName, item.Product?.Specifications);
                var expiry = order.CreatedAt.AddMonths(months);
                return new OrderWarrantyItemDto
                {
                    ProductId = item.ProductId,
                    ProductName = item.Product?.Name ?? $"Product #{item.ProductId}",
                    CategoryName = catName,
                    UnitPrice = item.UnitPrice,
                    Quantity = item.Quantity,
                    WarrantyPeriod = FormatWarrantyPeriod(months),
                    WarrantyExpiryDate = expiry,
                    IsActive = expiry >= DateTime.UtcNow
                };
            }).ToList()
        };

        return Ok(result);
    }

    // Helper: Build slot availability list for a given date
    private async Task<List<SlotAvailabilityDto>> GetSlotAvailabilityListAsync(DateTime targetDateUtc)
    {
        var slots = await _context.ServiceTimeSlots
            .AsNoTracking()
            .Where(s => s.IsActive)
            .OrderBy(s => s.StartTime)
            .ThenBy(s => s.EndTime)
            .ToListAsync();

        var overrides = await _context.ServiceTimeSlotOverrides
            .AsNoTracking()
            .Where(o => o.Date.Date == targetDateUtc.Date)
            .ToDictionaryAsync(o => o.SlotId, o => o);

        var bookings = await _context.ServiceRequests
            .AsNoTracking()
            .Where(sr => sr.PreferredDate.HasValue &&
                         sr.PreferredDate.Value.Date == targetDateUtc.Date &&
                         sr.Status.ToLower() != "cancelled" &&
                         sr.Status.ToLower() != "canceled" &&
                         sr.Status.ToLower() != "rejected" &&
                         sr.SlotId.HasValue)
            .GroupBy(sr => sr.SlotId!.Value)
            .Select(g => new { SlotId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.SlotId, g => g.Count);

        var result = new List<SlotAvailabilityDto>();
        foreach (var slot in slots)
        {
            overrides.TryGetValue(slot.SlotId, out var ov);
            var isClosed = ov?.IsClosed ?? false;
            var maxCap = isClosed ? 0 : (ov?.CustomCapacity ?? slot.DefaultCapacity);
            var booked = bookings.TryGetValue(slot.SlotId, out var count) ? count : 0;
            var remaining = Math.Max(0, maxCap - booked);
            var isAvail = slot.IsActive && !isClosed && (booked < maxCap);

            result.Add(new SlotAvailabilityDto
            {
                SlotId = slot.SlotId,
                StartTime = slot.StartTime,
                EndTime = slot.EndTime,
                Label = slot.Label ?? $"{slot.StartTime} - {slot.EndTime}",
                DefaultCapacity = slot.DefaultCapacity,
                MaxCapacity = maxCap,
                BookedCount = booked,
                RemainingSlots = remaining,
                IsAvailable = isAvail,
                IsClosed = isClosed,
                Reason = ov?.Reason,
                IsActive = slot.IsActive,
                IsOverridden = ov != null
            });
        }

        return result;
    }

    // Helper: Check if a slot is over capacity for a date
    private async Task<bool> IsSlotOverCapacityAsync(int slotId, DateTime targetDate, int? currentSrId = null)
    {
        var slot = await _context.ServiceTimeSlots.FirstOrDefaultAsync(s => s.SlotId == slotId);
        if (slot == null || !slot.IsActive) return true;

        var overrideRecord = await _context.ServiceTimeSlotOverrides
            .FirstOrDefaultAsync(o => o.SlotId == slotId && o.Date.Date == targetDate.Date);

        if (overrideRecord != null && overrideRecord.IsClosed) return true;

        var effectiveCapacity = overrideRecord?.CustomCapacity ?? slot.DefaultCapacity;

        var query = _context.ServiceRequests.Where(sr =>
            sr.SlotId == slotId &&
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value.Date == targetDate.Date &&
            sr.Status.ToLower() != "cancelled" &&
            sr.Status.ToLower() != "canceled" &&
            sr.Status.ToLower() != "rejected");

        if (currentSrId.HasValue)
        {
            query = query.Where(sr => sr.ServiceRequestId != currentSrId.Value);
        }

        var count = await query.CountAsync();
        return count >= effectiveCapacity;
    }

    private static string NormalizeStatus(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
            return "Booked";

        var s = status.Trim();
        var lower = s.ToLower().Replace("_", " ");

        if (lower == "booked") return "Booked";
        if (lower == "pending") return "Booked";
        if (lower == "in progress" || lower == "in_progress" || lower == "in service" || lower == "in_service" || lower == "scheduled" || lower == "under review" || lower == "under_review")
            return "In Progress";
        if (lower == "completed" || lower == "resolved") return "Completed";
        if (lower == "no show" || lower == "no_show" || lower == "noshow") return "No Show";
        if (lower == "cancelled" || lower == "canceled") return "Cancelled";
        if (lower == "rejected") return "Rejected";

        return s;
    }

    private static int GetWarrantyMonths(string? categoryName, string? specificationsJson = null)
    {
        if (!string.IsNullOrWhiteSpace(specificationsJson))
        {
            try
            {
                using var doc = System.Text.Json.JsonDocument.Parse(specificationsJson);
                var root = doc.RootElement;
                if (root.TryGetProperty("warranty_months", out var wmProp) && wmProp.TryGetInt32(out int wm) && wm > 0)
                    return wm;
                if (root.TryGetProperty("warrantyMonths", out var wmProp2) && wmProp2.TryGetInt32(out int wm2) && wm2 > 0)
                    return wm2;
                if (root.TryGetProperty("warranty", out var wProp) && wProp.ValueKind == System.Text.Json.JsonValueKind.String)
                {
                    var text = wProp.GetString()?.ToLower() ?? "";
                    double years = 0;
                    int months = 0;
                    var yMatch = System.Text.RegularExpressions.Regex.Match(text, @"(\d+(?:\.\d+)?)\s*(?:year|yr)");
                    if (yMatch.Success && double.TryParse(yMatch.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture, out double y))
                        years = y;
                    var mMatch = System.Text.RegularExpressions.Regex.Match(text, @"(\d+)\s*(?:month|mo)");
                    if (mMatch.Success && int.TryParse(mMatch.Groups[1].Value, out int m))
                        months = m;
                    var total = (int)(years * 12 + months);
                    if (total > 0) return total;
                }
            }
            catch { }
        }

        var cat = (categoryName ?? "").ToLower();
        if (cat.Contains("gpu") || cat.Contains("graphics") || cat.Contains("video")) return 36;
        if (cat.Contains("cpu") || cat.Contains("processor")) return 36;
        if (cat.Contains("motherboard")) return 36;
        if (cat.Contains("ram") || cat.Contains("memory")) return 120;
        if (cat.Contains("storage") || cat.Contains("ssd") || cat.Contains("nvme")) return 60;
        if (cat.Contains("power") || cat.Contains("psu")) return 60;
        if (cat.Contains("case") || cat.Contains("cooler")) return 24;
        return 36;
    }

    private static string FormatWarrantyPeriod(int months)
    {
        var years = months / 12;
        var rem = months % 12;
        if (years > 0 && rem > 0)
            return $"{years} Year{(years > 1 ? "s" : "")} {rem} Month{(rem > 1 ? "s" : "")} Manufacturer Warranty";
        if (years > 0)
            return $"{years} Year{(years > 1 ? "s" : "")} Manufacturer Warranty";
        if (rem > 0)
            return $"{rem} Month{(rem > 1 ? "s" : "")} Manufacturer Warranty";
        return "Standard Manufacturer Warranty";
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub") ?? User.FindFirst("userId");
        if (claim != null && int.TryParse(claim.Value, out int id))
        {
            return id;
        }
        return null;
    }
}
