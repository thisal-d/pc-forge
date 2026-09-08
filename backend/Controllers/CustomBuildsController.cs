using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class CustomBuildsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<CustomBuildsController> _logger;

    public CustomBuildsController(AppDbContext context, ILogger<CustomBuildsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Retrieve all custom builds submitted for review (Staff / Admin review queue).
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<CustomBuildSummaryDto>>> GetBuilds(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null,
        [FromQuery] int? staffId = null)
    {
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized();
        }

        var isStaffOrAdmin = IsStaffOrAdmin();
        var query = _context.CustomBuilds
            .AsNoTracking()
            .Include(cb => cb.User)
            .Include(cb => cb.AssignedStaff)
                .ThenInclude(s => s!.User)
            .Include(cb => cb.Items)
                .ThenInclude(i => i.Product)
            .AsQueryable();

        if (!isStaffOrAdmin)
        {
            query = query.Where(cb => cb.UserId == currentUserId.Value);
        }

        // Optional status filter
        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(cb => cb.Status.ToLower() == status.ToLower());
        }

        // Optional staff filter (supports filtering by StaffId or UserId)
        if (staffId.HasValue && staffId.Value > 0)
        {
            query = query.Where(cb => cb.AssignedStaffId == staffId.Value ||
                                      (cb.AssignedStaff != null && cb.AssignedStaff.UserId == staffId.Value));
        }

        // Optional search filter
        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(cb =>
                cb.BuildName.ToLower().Contains(q) ||
                (cb.User != null && cb.User.Email.ToLower().Contains(q)) ||
                (cb.User != null && ((cb.User.FirstName ?? "") + " " + (cb.User.LastName ?? "")).ToLower().Contains(q)));
        }

        var list = await query
            .OrderByDescending(cb => cb.CreatedAt)
            .Select(cb => new CustomBuildSummaryDto
            {
                BuildId = cb.BuildId,
                UserId = cb.UserId,
                CustomerName = cb.User != null && (!string.IsNullOrEmpty(cb.User.FirstName) || !string.IsNullOrEmpty(cb.User.LastName))
                    ? $"{cb.User.FirstName} {cb.User.LastName}".Trim()
                    : cb.User != null ? cb.User.Email : "Customer",
                CustomerEmail = cb.User != null ? cb.User.Email : string.Empty,
                BuildName = cb.BuildName,
                TotalPrice = cb.TotalPrice,
                EstimatedWattage = cb.EstimatedWattage,
                Status = cb.Status,
                CustomerNotes = cb.CustomerNotes,
                StaffNotes = cb.StaffNotes,
                AssignedStaffId = cb.AssignedStaffId,
                AssignedStaffName = cb.AssignedStaff != null && cb.AssignedStaff.User != null
                    ? $"{cb.AssignedStaff.User.FirstName} {cb.AssignedStaff.User.LastName}".Trim()
                    : null,
                ItemCount = cb.Items.Count,
                CreatedAt = cb.CreatedAt,
                UpdatedAt = cb.UpdatedAt,
                Components = cb.Items.Select(i => new CustomBuildComponentDto
                {
                    ProductId = i.ProductId,
                    SlotType = i.SlotType,
                    ProductName = i.Product != null ? i.Product.Name : $"Component #{i.ProductId}",
                    Brand = i.Product != null ? i.Product.Brand : "Unknown",
                    Model = i.Product != null ? i.Product.Model : null,
                    Price = i.UnitPrice,
                    StockQuantity = i.Product != null ? i.Product.StockQuantity : 0,
                    Socket = i.Product != null ? i.Product.Socket : null,
                    MemoryType = i.Product != null ? i.Product.MemoryType : null,
                    PowerWattage = i.Product != null ? i.Product.PowerWattage : null,
                }).ToList()
            })
            .ToListAsync();

        return Ok(list);
    }

    /// <summary>
    /// Retrieve full details of a specific custom build with itemized components.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<CustomBuildDetailDto>> GetBuildById(int id)
    {
        var build = await _context.CustomBuilds
            .AsNoTracking()
            .Include(cb => cb.User)
            .Include(cb => cb.AssignedStaff)
                .ThenInclude(s => s!.User)
            .Include(cb => cb.Items)
                .ThenInclude(i => i.Product)
            .FirstOrDefaultAsync(cb => cb.BuildId == id);

        if (build == null)
        {
            return NotFound(new { message = $"Custom Build #{id} not found." });
        }

        var currentUserId = GetCurrentUserId();
        var isStaffOrAdmin = IsStaffOrAdmin();
        if (!isStaffOrAdmin && build.UserId != currentUserId)
        {
            return Forbid();
        }

        var components = build.Items.Select(i => new CustomBuildComponentDto
        {
            ProductId = i.ProductId,
            SlotType = i.SlotType,
            ProductName = i.Product?.Name ?? $"Component #{i.ProductId}",
            Brand = i.Product?.Brand ?? "Unknown",
            Model = i.Product?.Model,
            Price = i.UnitPrice,
            StockQuantity = i.Product?.StockQuantity ?? 0,
            Socket = i.Product?.Socket,
            MemoryType = i.Product?.MemoryType,
            PowerWattage = i.Product?.PowerWattage,
            Vram = GetSpecProperty(i.Product?.Specifications, "vram"),
            Chipset = GetSpecProperty(i.Product?.Specifications, "chipset"),
            EfficiencyRating = GetSpecProperty(i.Product?.Specifications, "efficiency"),
        }).ToList();

        // Technical clearance and feasibility calculations
        var cpu = components.FirstOrDefault(c => c.SlotType.Equals("cpu", StringComparison.OrdinalIgnoreCase));
        var mobo = components.FirstOrDefault(c => c.SlotType.Equals("motherboard", StringComparison.OrdinalIgnoreCase));
        var ram = components.FirstOrDefault(c => c.SlotType.Equals("ram", StringComparison.OrdinalIgnoreCase));
        var psu = components.FirstOrDefault(c => c.SlotType.Equals("psu", StringComparison.OrdinalIgnoreCase));

        bool socketMatch = true;
        if (cpu?.Socket != null && mobo?.Socket != null)
        {
            socketMatch = cpu.Socket.Equals(mobo.Socket, StringComparison.OrdinalIgnoreCase);
        }

        bool memoryMatch = true;
        if (mobo?.MemoryType != null && ram?.MemoryType != null)
        {
            memoryMatch = mobo.MemoryType.Equals(ram.MemoryType, StringComparison.OrdinalIgnoreCase);
        }

        int? psuWatts = psu?.PowerWattage;
        int? headroom = null;
        int? headroomPercent = null;
        if (psuWatts.HasValue && psuWatts.Value > 0 && build.EstimatedWattage > 0)
        {
            headroom = psuWatts.Value - build.EstimatedWattage;
            headroomPercent = (int)Math.Round((double)headroom.Value / build.EstimatedWattage * 100);
        }

        var detail = new CustomBuildDetailDto
        {
            BuildId = build.BuildId,
            UserId = build.UserId,
            CustomerName = build.User != null && (!string.IsNullOrEmpty(build.User.FirstName) || !string.IsNullOrEmpty(build.User.LastName))
                ? $"{build.User.FirstName} {build.User.LastName}".Trim()
                : build.User != null ? build.User.Email : "Customer",
            CustomerEmail = build.User?.Email ?? string.Empty,
            BuildName = build.BuildName,
            TotalPrice = build.TotalPrice,
            EstimatedWattage = build.EstimatedWattage,
            Status = build.Status,
            CustomerNotes = build.CustomerNotes,
            StaffNotes = build.StaffNotes,
            AssignedStaffId = build.AssignedStaffId,
            AssignedStaffName = build.AssignedStaff?.User != null
                ? $"{build.AssignedStaff.User.FirstName} {build.AssignedStaff.User.LastName}".Trim()
                : null,
            CreatedAt = build.CreatedAt,
            UpdatedAt = build.UpdatedAt,
            IsSocketCompatible = socketMatch,
            IsMemoryCompatible = memoryMatch,
            PsuCapacityWatts = psuWatts,
            PsuHeadroomWatts = headroom,
            PsuHeadroomPercentage = headroomPercent,
            Components = components
        };

        return Ok(detail);
    }

    private async Task<CustomBuildDetailDto?> GetBuildDetailInternal(int id)
    {
        var actionResult = await GetBuildById(id);
        return actionResult.Value ?? (actionResult.Result as OkObjectResult)?.Value as CustomBuildDetailDto;
    }

    private bool IsStaffOrAdmin()
    {
        var roleClaim = User.FindFirst(ClaimTypes.Role)?.Value ?? User.FindFirst("role")?.Value ?? string.Empty;
        return User.IsInRole("Admin") || User.IsInRole("Staff") ||
               roleClaim.Equals("Admin", StringComparison.OrdinalIgnoreCase) ||
               roleClaim.Equals("Staff", StringComparison.OrdinalIgnoreCase);
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

    private static string? GetSpecProperty(string? jsonSpec, string propName)
    {
        if (string.IsNullOrWhiteSpace(jsonSpec)) return null;
        try
        {
            using var doc = JsonDocument.Parse(jsonSpec);
            if (doc.RootElement.TryGetProperty(propName, out var elem))
            {
                return elem.GetString();
            }
        }
        catch
        {
            // Ignore invalid JSON
        }
        return null;
    }
}
