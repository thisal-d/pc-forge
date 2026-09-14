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
    /// Retrieve customer's service requests or storewide list for staff/admin.
    /// </summary>
    [AllowAnonymous]
    [HttpGet]
    public async Task<ActionResult<List<ServiceRequestSummaryDto>>> GetServiceRequests(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null,
        [FromQuery] string? priority = null)
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
            var cleanStatus = status.Trim().ToUpper();
            query = query.Where(sr => sr.Status.ToUpper() == cleanStatus);
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
                sr.ProblemDescription.ToLower().Contains(term) ||
                (sr.Product != null && sr.Product.Name.ToLower().Contains(term)) ||
                (sr.User != null && (sr.User.FirstName.ToLower().Contains(term) || sr.User.LastName.ToLower().Contains(term) || sr.User.Email.ToLower().Contains(term))));
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
                ProblemDescription = sr.ProblemDescription,
                ProblemCategory = sr.ProblemCategory,
                WarrantyStatus = sr.WarrantyStatus,
                WarrantyExpiryDate = sr.WarrantyExpiryDate,
                PreferredDate = sr.PreferredDate,
                PreferredTime = sr.PreferredTime,
                Status = sr.Status,
                Priority = sr.Priority,
                TroubleshootingSummary = sr.TroubleshootingSummary,
                AttemptCount = sr.AttemptCount,
                AttachmentUrl = sr.AttachmentUrl,
                AssignedStaffId = sr.AssignedStaffId,
                AssignedStaffName = sr.AssignedStaff != null && sr.AssignedStaff.User != null
                    ? $"{sr.AssignedStaff.User.FirstName} {sr.AssignedStaff.User.LastName}".Trim()
                    : null,
                CreatedAt = sr.CreatedAt
            })
            .ToListAsync();

        return Ok(list);
    }

    /// <summary>
    /// Retrieve single service request by ID or SR Number.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("{id}")]
    public async Task<ActionResult<ServiceRequestDetailDto>> GetServiceRequestById(string id)
    {
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
            var clean = id.Trim().ToUpper();
            request = await _context.ServiceRequests
                .AsNoTracking()
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

        return Ok(new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            CustomerName = request.User != null ? $"{request.User.FirstName} {request.User.LastName}".Trim() : null,
            CustomerEmail = request.User?.Email,
            OrderId = request.OrderId,
            ProductId = request.ProductId,
            ProductName = request.Product?.Name,
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
            AttachmentUrl = request.AttachmentUrl,
            CreatedAt = request.CreatedAt,
            UpdatedAt = request.UpdatedAt
        });
    }

    /// <summary>
    /// Create a new Service Request (Manual or System Created).
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

        // Verify linked order & product if provided
        Product? linkedProduct = null;
        DateTime? verifiedExpiryDate = dto.WarrantyExpiryDate;
        string calculatedWarrantyStatus = dto.WarrantyStatus;

        if (dto.OrderId.HasValue && dto.OrderId.Value > 0)
        {
            var order = await _context.Orders
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                    .ThenInclude(p => p.Category)
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
            ProblemDescription = dto.ProblemDescription.Trim(),
            ProblemCategory = string.IsNullOrWhiteSpace(dto.ProblemCategory) ? "General" : dto.ProblemCategory.Trim(),
            TroubleshootingSummary = dto.TroubleshootingSummary,
            AttemptCount = dto.AttemptCount,
            WarrantyStatus = calculatedWarrantyStatus,
            WarrantyExpiryDate = verifiedExpiryDate,
            PreferredDate = dto.PreferredDate,
            PreferredTime = dto.PreferredTime,
            Status = "PENDING",
            Priority = !string.IsNullOrWhiteSpace(dto.Priority) ? dto.Priority : "Normal",
            AttachmentUrl = dto.AttachmentUrl,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.ServiceRequests.Add(request);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Service Request {SrNumber} created for User {UserId}: '{Problem}'",
            request.ServiceRequestNumber, userId, request.ProblemDescription);

        return CreatedAtAction(nameof(GetServiceRequestById), new { id = request.ServiceRequestId }, new ServiceRequestDetailDto
        {
            ServiceRequestId = request.ServiceRequestId,
            ServiceRequestNumber = request.ServiceRequestNumber,
            UserId = request.UserId,
            OrderId = request.OrderId,
            ProductId = request.ProductId,
            ProductName = linkedProduct?.Name,
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

    private static int GetWarrantyMonths(string? categoryName, string? specificationsJson)
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
