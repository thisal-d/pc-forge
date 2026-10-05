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
    /// Executes Member 05 AI After-Sales Service Agent for troubleshooting and service requests.
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

        var targetDate = date.Value.Date;
        var count = await _context.ServiceRequests.CountAsync(sr =>
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value.Date == targetDate &&
            sr.Status.ToLower() != "cancelled" &&
            sr.Status.ToLower() != "canceled");

        return Ok(new ServiceAvailabilityDto
        {
            Date = targetDate.ToString("yyyy-MM-dd"),
            BookedCount = count,
            MaxCapacity = 10,
            RemainingSlots = Math.Max(0, 10 - count),
            IsAvailable = count < 10
        });
    }

    /// <summary>
    /// Retrieve customer's service requests or storewide list for staff/admin with optional status and date range filters.
    /// </summary>
    [AllowAnonymous]
    [HttpGet]
    public async Task<ActionResult<List<ServiceRequestSummaryDto>>> GetServiceRequests(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null,
        [FromQuery] string? priority = null,
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null)
    {
        var currentUserId = GetCurrentUserId() ?? 1;
        var isStaffOrAdmin = User.Identity?.IsAuthenticated == true && (User.IsInRole("Admin") || User.IsInRole("Staff"));
        var query = _context.ServiceRequests
            .AsNoTracking()
            .Include(sr => sr.Product)
            .Include(sr => sr.User)
            .Include(sr => sr.AssignedStaff)
                .ThenInclude(s => s!.User)
            .AsQueryable();

        if (!isStaffOrAdmin)
        {
            query = query.Where(sr => sr.UserId == currentUserId);
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

        if (!string.IsNullOrWhiteSpace(priority) && priority.ToLower() != "all")
        {
            var cleanPriority = priority.Trim();
            query = query.Where(sr => sr.Priority.ToLower() == cleanPriority.ToLower());
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(sr =>
                sr.ServiceRequestNumber.ToLower().Contains(term) ||
                (sr.Title != null && sr.Title.ToLower().Contains(term)) ||
                sr.ProblemDescription.ToLower().Contains(term) ||
                (sr.Product != null && sr.Product.Name.ToLower().Contains(term)) ||
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
                OrderId = sr.OrderId,
                ProductId = sr.ProductId,
                ProductName = sr.Product != null ? sr.Product.Name : null,
                Title = !string.IsNullOrEmpty(sr.Title) ? sr.Title : (!string.IsNullOrEmpty(sr.TroubleshootingSummary) ? sr.TroubleshootingSummary : sr.ProblemDescription),
                Description = !string.IsNullOrEmpty(sr.Description) ? sr.Description : sr.ProblemDescription,
                ProblemDescription = sr.ProblemDescription,
                ProblemCategory = sr.ProblemCategory,
                TroubleshootingSummary = sr.TroubleshootingSummary,
                AttemptCount = sr.AttemptCount,
                WarrantyStatus = sr.WarrantyStatus,
                WarrantyExpiryDate = sr.WarrantyExpiryDate,
                PreferredDate = sr.PreferredDate,
                PreferredTime = sr.PreferredTime,
                Status = sr.Status,
                Priority = sr.Priority,
                AssignedStaffId = sr.AssignedStaffId,
                AssignedStaffName = sr.AssignedStaff != null && sr.AssignedStaff.User != null
                    ? $"{sr.AssignedStaff.User.FirstName} {sr.AssignedStaff.User.LastName}".Trim()
                    : null,
                InternalNotes = isStaffOrAdmin ? sr.InternalNotes : null,
                AttachmentUrl = sr.AttachmentUrl,
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
                .Include(sr => sr.Product)
                .Include(sr => sr.User)
                .Include(sr => sr.Order)
                .Include(sr => sr.AssignedStaff)
                    .ThenInclude(s => s!.User)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var cleanSrNumber = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .AsNoTracking()
                .Include(sr => sr.Product)
                .Include(sr => sr.User)
                .Include(sr => sr.Order)
                .Include(sr => sr.AssignedStaff)
                    .ThenInclude(s => s!.User)
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
            OrderId = request.OrderId,
            OrderDate = request.Order?.CreatedAt,
            ProductId = request.ProductId,
            ProductName = request.Product?.Name,
            Title = !string.IsNullOrEmpty(request.Title) ? request.Title : (!string.IsNullOrEmpty(request.TroubleshootingSummary) ? request.TroubleshootingSummary : request.ProblemDescription),
            Description = !string.IsNullOrEmpty(request.Description) ? request.Description : request.ProblemDescription,
            ProblemDescription = request.ProblemDescription,
            ProblemCategory = request.ProblemCategory,
            TroubleshootingSummary = request.TroubleshootingSummary,
            AttemptCount = request.AttemptCount,
            WarrantyStatus = request.WarrantyStatus,
            WarrantyExpiryDate = request.WarrantyExpiryDate,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            Priority = request.Priority,
            AssignedStaffId = request.AssignedStaffId,
            AssignedStaffName = request.AssignedStaff != null && request.AssignedStaff.User != null
                ? $"{request.AssignedStaff.User.FirstName} {request.AssignedStaff.User.LastName}".Trim()
                : null,
            TechnicianNotes = request.TechnicianNotes,
            Resolution = request.Resolution,
            InternalNotes = isStaffOrAdmin ? request.InternalNotes : null,
            AttachmentUrl = request.AttachmentUrl,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Create a new Service Request (Customer or Staff).
    /// </summary>
    [AllowAnonymous]
    [HttpPost]
    public async Task<ActionResult<ServiceRequestDetailDto>> CreateServiceRequest([FromBody] CreateServiceRequestDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var currentUserId = GetCurrentUserId() ?? 1;
        int userId = currentUserId;

        // Resolve Title and Description
        var resolvedTitle = !string.IsNullOrWhiteSpace(dto.Title)
            ? dto.Title.Trim()
            : (!string.IsNullOrWhiteSpace(dto.ProblemDescription)
                ? dto.ProblemDescription.Trim()
                : (!string.IsNullOrWhiteSpace(dto.TroubleshootingSummary) ? dto.TroubleshootingSummary.Trim() : "Hardware Service Request"));

        var resolvedDescription = !string.IsNullOrWhiteSpace(dto.Description)
            ? dto.Description.Trim()
            : (!string.IsNullOrWhiteSpace(dto.ProblemDescription) ? dto.ProblemDescription.Trim() : null);

        if (string.IsNullOrWhiteSpace(resolvedTitle))
        {
            return BadRequest(new { message = "Title is required for service request." });
        }

        // Validate appointment time (9 AM to 6 PM)
        if (!ValidateAppointmentTime(dto.PreferredTime, out var timeError))
        {
            return BadRequest(new { message = timeError });
        }

        // Validate capacity limit (Max 10 service appointments per date for all customers)
        if (dto.PreferredDate.HasValue)
        {
            if (dto.PreferredDate.Value.Date < DateTime.UtcNow.Date)
            {
                return BadRequest(new { message = "Appointment date cannot be in the past. Please select a future date." });
            }
            if (await IsDateOverCapacityAsync(dto.PreferredDate.Value))
            {
                return BadRequest(new { message = $"The selected date ({dto.PreferredDate.Value:yyyy-MM-dd}) has reached its maximum capacity of 10 service appointments. Please choose another date." });
            }
        }

        // Verify linked order & product if provided
        Product? linkedProduct = null;
        DateTime? verifiedExpiryDate = dto.WarrantyExpiryDate;
        string calculatedWarrantyStatus = dto.WarrantyStatus;

        if (dto.OrderId.HasValue && dto.OrderId.Value > 0)
        {
            var order = await _context.Orders
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                    .ThenInclude(p => p!.Category)
                .FirstOrDefaultAsync(o => o.OrderId == dto.OrderId.Value);

            if (order != null)
            {
                if (dto.ProductId.HasValue && dto.ProductId.Value > 0)
                {
                    linkedProduct = order.Items.FirstOrDefault(i => i.ProductId == dto.ProductId.Value)?.Product;
                }
                else if (order.Items.Count > 0)
                {
                    linkedProduct = order.Items.First().Product;
                }

                if (linkedProduct != null)
                {
                    var warrantyMonths = linkedProduct.WarrantyMonths > 0 
                        ? linkedProduct.WarrantyMonths 
                        : GetWarrantyMonths(linkedProduct.Category?.Name, linkedProduct.Specifications);
                    verifiedExpiryDate = order.CreatedAt.AddMonths(warrantyMonths);
                    calculatedWarrantyStatus = verifiedExpiryDate >= DateTime.UtcNow ? "Active" : "Expired";
                }
            }
        }
        else if (dto.ProductId.HasValue && dto.ProductId.Value > 0)
        {
            linkedProduct = await _context.Products.Include(p => p.Category).FirstOrDefaultAsync(p => p.ProductId == dto.ProductId.Value);
        }

        // Generate next Service Request Number
        var maxId = await _context.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 100;
        var srNumber = $"SR-{(maxId + 1):D6}";

        var request = new ServiceRequest
        {
            ServiceRequestNumber = srNumber,
            UserId = userId,
            OrderId = dto.OrderId,
            ProductId = linkedProduct?.ProductId ?? dto.ProductId,
            Title = resolvedTitle,
            Description = resolvedDescription,
            ProblemDescription = !string.IsNullOrWhiteSpace(resolvedDescription) ? resolvedDescription : resolvedTitle,
            ProblemCategory = string.IsNullOrWhiteSpace(dto.ProblemCategory) ? "General" : dto.ProblemCategory.Trim(),
            TroubleshootingSummary = dto.TroubleshootingSummary ?? resolvedTitle,
            AttemptCount = dto.AttemptCount,
            WarrantyStatus = calculatedWarrantyStatus,
            WarrantyExpiryDate = verifiedExpiryDate,
            PreferredDate = dto.PreferredDate,
            PreferredTime = dto.PreferredTime,
            Status = "Pending",
            Priority = !string.IsNullOrWhiteSpace(dto.Priority) ? dto.Priority : "Normal",
            AttachmentUrl = dto.AttachmentUrl,
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
            OrderId = request.OrderId,
            ProductId = request.ProductId,
            ProductName = linkedProduct?.Name,
            Title = request.Title,
            Description = request.Description,
            ProblemDescription = request.ProblemDescription,
            ProblemCategory = request.ProblemCategory,
            TroubleshootingSummary = request.TroubleshootingSummary,
            AttemptCount = request.AttemptCount,
            WarrantyStatus = request.WarrantyStatus,
            WarrantyExpiryDate = request.WarrantyExpiryDate,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            Priority = request.Priority,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Cancel a service request (Customer can cancel their own request, staff/admin can cancel any).
    /// </summary>
    [AllowAnonymous]
    [HttpPost("{id}/cancel")]
    public async Task<ActionResult<ServiceRequestDetailDto>> CancelServiceRequest(string id)
    {
        var currentUserId = GetCurrentUserId() ?? 1;
        var isStaffOrAdmin = User.Identity?.IsAuthenticated == true && (User.IsInRole("Admin") || User.IsInRole("Staff"));

        ServiceRequest? request = null;
        if (int.TryParse(id, out int numericId))
        {
            request = await _context.ServiceRequests
                .Include(sr => sr.Product)
                .Include(sr => sr.User)
                .Include(sr => sr.Order)
                .Include(sr => sr.AssignedStaff)
                    .ThenInclude(s => s!.User)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var cleanSrNumber = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .Include(sr => sr.Product)
                .Include(sr => sr.User)
                .Include(sr => sr.Order)
                .Include(sr => sr.AssignedStaff)
                    .ThenInclude(s => s!.User)
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
            OrderId = request.OrderId,
            OrderDate = request.Order?.CreatedAt,
            ProductId = request.ProductId,
            ProductName = request.Product?.Name,
            Title = !string.IsNullOrEmpty(request.Title) ? request.Title : (!string.IsNullOrEmpty(request.TroubleshootingSummary) ? request.TroubleshootingSummary : request.ProblemDescription),
            Description = !string.IsNullOrEmpty(request.Description) ? request.Description : request.ProblemDescription,
            ProblemDescription = request.ProblemDescription,
            ProblemCategory = request.ProblemCategory,
            TroubleshootingSummary = request.TroubleshootingSummary,
            AttemptCount = request.AttemptCount,
            WarrantyStatus = request.WarrantyStatus,
            WarrantyExpiryDate = request.WarrantyExpiryDate,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            Priority = request.Priority,
            AssignedStaffId = request.AssignedStaffId,
            AssignedStaffName = request.AssignedStaff != null && request.AssignedStaff.User != null
                ? $"{request.AssignedStaff.User.FirstName} {request.AssignedStaff.User.LastName}".Trim()
                : null,
            TechnicianNotes = request.TechnicianNotes,
            Resolution = request.Resolution,
            InternalNotes = isStaffOrAdmin ? request.InternalNotes : null,
            AttachmentUrl = request.AttachmentUrl,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Update service request status, diagnosis, internal notes, or assigned technician (Technician/Staff only).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id}")]
    public async Task<ActionResult<ServiceRequestDetailDto>> UpdateServiceRequest(string id, [FromBody] UpdateServiceRequestDto dto)
    {
        ServiceRequest? request = null;
        if (int.TryParse(id, out int numericId))
        {
            request = await _context.ServiceRequests
                .Include(sr => sr.Product)
                .Include(sr => sr.User)
                .Include(sr => sr.Order)
                .Include(sr => sr.AssignedStaff)
                    .ThenInclude(s => s!.User)
                .FirstOrDefaultAsync(sr => sr.ServiceRequestId == numericId);
        }
        else
        {
            var clean = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .Include(sr => sr.Product)
                .Include(sr => sr.User)
                .Include(sr => sr.Order)
                .Include(sr => sr.AssignedStaff)
                    .ThenInclude(s => s!.User)
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

        if (!string.IsNullOrWhiteSpace(dto.Priority))
        {
            request.Priority = dto.Priority.Trim();
        }

        if (dto.AssignedStaffId.HasValue)
        {
            request.AssignedStaffId = dto.AssignedStaffId.Value > 0 ? dto.AssignedStaffId.Value : null;
        }

        if (dto.TechnicianNotes != null)
        {
            request.TechnicianNotes = dto.TechnicianNotes.Trim();
        }

        if (dto.Resolution != null)
        {
            request.Resolution = dto.Resolution.Trim();
        }

        if (dto.InternalNotes != null)
        {
            request.InternalNotes = dto.InternalNotes.Trim();
        }

        if (dto.PreferredDate.HasValue && dto.PreferredDate.Value.Date != request.PreferredDate?.Date)
        {
            if (await IsDateOverCapacityAsync(dto.PreferredDate.Value, request.ServiceRequestId))
            {
                return BadRequest(new { message = $"The selected date ({dto.PreferredDate.Value:yyyy-MM-dd}) has reached its maximum capacity of 10 service appointments. Please choose another date." });
            }
            request.PreferredDate = dto.PreferredDate;
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

        _logger.LogInformation("Service Request {SrNumber} updated by staff: Status={Status}, Priority={Priority}",
            request.ServiceRequestNumber, request.Status, request.Priority);

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            CustomerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : null,
            CustomerEmail = request.User != null ? request.User.Email : null,
            OrderId = request.OrderId,
            OrderDate = request.Order?.CreatedAt,
            ProductId = request.ProductId,
            ProductName = request.Product?.Name,
            Title = !string.IsNullOrEmpty(request.Title) ? request.Title : (!string.IsNullOrEmpty(request.TroubleshootingSummary) ? request.TroubleshootingSummary : request.ProblemDescription),
            Description = !string.IsNullOrEmpty(request.Description) ? request.Description : request.ProblemDescription,
            ProblemDescription = request.ProblemDescription,
            ProblemCategory = request.ProblemCategory,
            TroubleshootingSummary = request.TroubleshootingSummary,
            AttemptCount = request.AttemptCount,
            WarrantyStatus = request.WarrantyStatus,
            WarrantyExpiryDate = request.WarrantyExpiryDate,
            PreferredDate = request.PreferredDate,
            PreferredTime = request.PreferredTime,
            Status = request.Status,
            Priority = request.Priority,
            AssignedStaffId = request.AssignedStaffId,
            AssignedStaffName = request.AssignedStaff != null && request.AssignedStaff.User != null
                ? $"{request.AssignedStaff.User.FirstName} {request.AssignedStaff.User.LastName}".Trim()
                : null,
            TechnicianNotes = request.TechnicianNotes,
            Resolution = request.Resolution,
            InternalNotes = request.InternalNotes,
            AttachmentUrl = request.AttachmentUrl,
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
        var dateOnly = targetDate.Date;
        var query = _context.ServiceRequests.Where(sr =>
            sr.PreferredDate.HasValue &&
            sr.PreferredDate.Value.Date == dateOnly &&
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
