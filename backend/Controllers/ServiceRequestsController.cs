using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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
    private readonly ILogger<ServiceRequestsController> _logger;

    public ServiceRequestsController(
        AppDbContext context,
        IAiAgentService aiAgentService,
        ILogger<ServiceRequestsController> logger)
    {
        _context = context;
        _aiAgentService = aiAgentService;
        _logger = logger;
    }

    /// <summary>
    /// Executes AI After-Sales Service Agent for troubleshooting and service requests.
    /// </summary>
    [AllowAnonymous]
    [HttpPost("ai-chat")]
    public async Task<ActionResult<AfterSalesChatResponseDto>> AfterSalesChat([FromBody] AfterSalesChatRequestDto request)
    {
        var currentUserId = GetCurrentUserId() ?? 1;
        request.UserId = currentUserId;

        var result = await _aiAgentService.SendAfterSalesChatMessageAsync(request);
        if (!result.Success && string.IsNullOrEmpty(result.Reply))
        {
            return StatusCode(500, result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Checks availability and remaining slots for a service appointment date (Max 10 per day storewide).
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
        var nextDateUtc = targetDateUtc.AddDays(1);
        var count = await _context.ServiceRequests.CountAsync(sr =>
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value >= targetDateUtc &&
            sr.PreferredDate.Value < nextDateUtc &&
            sr.Status.ToLower() != "cancelled" &&
            sr.Status.ToLower() != "canceled");

        return Ok(new ServiceAvailabilityDto
        {
            Date = targetDateUtc.ToString("yyyy-MM-dd"),
            BookedCount = count,
            MaxCapacity = 10,
            RemainingSlots = Math.Max(0, 10 - count),
            IsAvailable = count < 10
        });
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
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var cleanSrNumber = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .AsNoTracking()
                .Include(sr => sr.User)
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
    /// All form items are optional and simple.
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

        // Resolve Title and Description (optional, graceful defaults)
        var resolvedTitle = !string.IsNullOrWhiteSpace(dto.Title)
            ? dto.Title.Trim()
            : (!string.IsNullOrWhiteSpace(dto.Description) 
                ? (dto.Description.Length > 50 ? dto.Description.Substring(0, 50) + "..." : dto.Description.Trim())
                : "Service Request");

        var resolvedDescription = !string.IsNullOrWhiteSpace(dto.Description)
            ? dto.Description.Trim()
            : null;

        // Validate appointment time (9 AM to 6 PM) if provided
        if (!string.IsNullOrWhiteSpace(dto.PreferredTime) && !ValidateAppointmentTime(dto.PreferredTime, out var timeError))
        {
            return BadRequest(new { message = timeError });
        }

        // Validate capacity limit (Max 10 service appointments per date for all customers) if date provided
        if (dto.PreferredDate.HasValue)
        {
            var prefDateUtc = DateTime.SpecifyKind(dto.PreferredDate.Value.Date, DateTimeKind.Utc);
            dto.PreferredDate = prefDateUtc;
            if (prefDateUtc < DateTime.UtcNow.Date)
            {
                return BadRequest(new { message = "Appointment date cannot be in the past. Please select a future date." });
            }
            if (await IsDateOverCapacityAsync(prefDateUtc))
            {
                return BadRequest(new { message = $"The selected date ({prefDateUtc:yyyy-MM-dd}) has reached its maximum capacity of 10 service appointments. Please choose another date." });
            }
        }

        // Generate next Service Request Number
        var maxId = await _context.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 100;
        var srNumber = $"SR-{(maxId + 1):D6}";

        var request = new ServiceRequest
        {
            ServiceRequestNumber = srNumber,
            UserId = userId,
            Title = resolvedTitle,
            Description = resolvedDescription,
            PreferredDate = dto.PreferredDate,
            PreferredTime = dto.PreferredTime,
            Status = "Pending",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.ServiceRequests.Add(request);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Service Request {SrNumber} created for User {UserId}: '{Title}'",
            request.ServiceRequestNumber, userId, request.Title);

        return CreatedAtAction(nameof(GetServiceRequestById), new { id = request.ServiceRequestId }, new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            Title = request.Title,
            Description = request.Description,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Cancel a service request (Customer can cancel their own request, staff/admin can cancel any).
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
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var cleanSrNumber = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .Include(sr => sr.User)
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
        if (!isStaffOrAdmin && normalizedStatus != "Pending")
        {
            return BadRequest(new { message = "Customers can only cancel a Service Request while it is in Pending status." });
        }

        if (normalizedStatus == "Completed" || normalizedStatus == "Cancelled" || normalizedStatus == "No Show")
        {
            return BadRequest(new { message = $"Cannot cancel a service request that is already '{request.Status}'." });
        }

        request.Status = "Cancelled";
        request.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Service Request {SrNumber} was cancelled by User {UserId}", request.ServiceRequestNumber, currentUserId);

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
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
    /// Update service request status and appointment date/time (Technician/Staff only).
    /// No technician assignment or resolution notes.
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
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var clean = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .Include(sr => sr.User)
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

        if (dto.PreferredDate.HasValue)
        {
            var updateDateUtc = DateTime.SpecifyKind(dto.PreferredDate.Value.Date, DateTimeKind.Utc);
            if (updateDateUtc != request.PreferredDate?.Date)
            {
                if (await IsDateOverCapacityAsync(updateDateUtc, request.ServiceRequestId))
                {
                    return BadRequest(new { message = $"The selected date ({updateDateUtc:yyyy-MM-dd}) has reached its maximum capacity of 10 service appointments. Please choose another date." });
                }
                request.PreferredDate = updateDateUtc;
            }
        }

        if (!string.IsNullOrWhiteSpace(dto.PreferredTime))
        {
            if (!ValidateAppointmentTime(dto.PreferredTime, out var timeErr))
            {
                return BadRequest(new { message = timeErr });
            }
            request.PreferredTime = dto.PreferredTime;
        }

        request.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Service Request {SrNumber} updated: Status={Status}",
            request.ServiceRequestNumber, request.Status);

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
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

    private static bool ValidateAppointmentTime(string? timeStr, out string? errorMessage)
    {
        errorMessage = null;
        if (string.IsNullOrWhiteSpace(timeStr))
            return true;

        timeStr = timeStr.Trim();
        TimeSpan parsedTime;

        if (DateTime.TryParse(timeStr, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out var dt) ||
            DateTime.TryParse(timeStr, out dt))
        {
            parsedTime = dt.TimeOfDay;
        }
        else if (TimeSpan.TryParse(timeStr, System.Globalization.CultureInfo.InvariantCulture, out var ts) ||
                 TimeSpan.TryParse(timeStr, out ts))
        {
            parsedTime = ts;
        }
        else
        {
            errorMessage = "Invalid appointment time. Please pick a time between 9:00 AM and 6:00 PM.";
            return false;
        }

        var minTime = new TimeSpan(9, 0, 0);   // 9:00 AM
        var maxTime = new TimeSpan(18, 0, 0);  // 6:00 PM

        if (parsedTime < minTime || parsedTime > maxTime)
        {
            errorMessage = "Appointment time must be between 9:00 AM and 6:00 PM.";
            return false;
        }

        return true;
    }

    private async Task<bool> IsDateOverCapacityAsync(DateTime targetDate, int? currentSrId = null)
    {
        var targetDateUtc = DateTime.SpecifyKind(targetDate.Date, DateTimeKind.Utc);
        var nextDateUtc = targetDateUtc.AddDays(1);
        var query = _context.ServiceRequests.Where(sr =>
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value >= targetDateUtc &&
            sr.PreferredDate.Value < nextDateUtc &&
            sr.Status.ToLower() != "cancelled" &&
            sr.Status.ToLower() != "canceled");

        if (currentSrId.HasValue)
        {
            query = query.Where(sr => sr.ServiceRequestId != currentSrId.Value);
        }

        var count = await query.CountAsync();
        return count >= 10;
    }

    private static string NormalizeStatus(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
            return "Pending";

        var s = status.Trim();
        var lower = s.ToLower().Replace("_", " ");

        if (lower == "pending") return "Pending";
        if (lower == "in progress" || lower == "in_progress" || lower == "in service" || lower == "in_service" || lower == "scheduled" || lower == "under review" || lower == "under_review")
            return "In Progress";
        if (lower == "completed" || lower == "resolved") return "Completed";
        if (lower == "no show" || lower == "no_show" || lower == "noshow") return "No Show";
        if (lower == "cancelled" || lower == "canceled") return "Cancelled";

        return s;
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
        if (cat.Contains("ram") || cat.Contains("memory")) return 120; // 10 years / lifetime
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
