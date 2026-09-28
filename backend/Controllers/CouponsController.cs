using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CouponsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<CouponsController> _logger;

    public CouponsController(AppDbContext context, ILogger<CouponsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    private static CouponDto MapToDto(Coupon c) => new()
    {
        CouponId = c.CouponId,
        Code = c.Code,
        Description = c.Description,
        DiscountType = c.DiscountType,
        DiscountValue = c.DiscountValue,
        MinSubtotal = c.MinSubtotal,
        MaxDiscount = c.MaxDiscount,
        IsActive = c.IsActive,
        CreatedAt = c.CreatedAt
    };

    /// <summary>
    /// Retrieves coupons. Can be filtered by search query or active status.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<CouponDto>>> GetCoupons(
        [FromQuery] string? search = null,
        [FromQuery] bool? activeOnly = null)
    {
        var query = _context.Coupons.AsNoTracking().AsQueryable();

        if (activeOnly.HasValue && activeOnly.Value)
        {
            query = query.Where(c => c.IsActive);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(c => c.Code.ToLower().Contains(term) || c.Description.ToLower().Contains(term));
        }

        var coupons = await query
            .OrderByDescending(c => c.CreatedAt)
            .Select(c => MapToDto(c))
            .ToListAsync();

        return Ok(coupons);
    }

    /// <summary>
    /// Retrieves a single coupon by ID.
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<CouponDto>> GetCouponById(int id)
    {
        var coupon = await _context.Coupons.AsNoTracking().FirstOrDefaultAsync(c => c.CouponId == id);
        if (coupon == null)
        {
            return NotFound(new { message = $"Coupon #{id} not found." });
        }

        return Ok(MapToDto(coupon));
    }

    /// <summary>
    /// Creates a new promotional coupon (Staff/Admin only).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost]
    public async Task<ActionResult<CouponDto>> CreateCoupon([FromBody] CreateCouponDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var cleanCode = dto.Code.Trim().ToUpper();

        var existing = await _context.Coupons.AnyAsync(c => c.Code == cleanCode);
        if (existing)
        {
            return Conflict(new { message = $"Coupon code '{cleanCode}' already exists." });
        }

        var coupon = new Coupon
        {
            Code = cleanCode,
            Description = dto.Description.Trim(),
            DiscountType = dto.DiscountType.Trim().ToUpper(),
            DiscountValue = dto.DiscountValue,
            MinSubtotal = dto.MinSubtotal ?? 0m,
            MaxDiscount = dto.MaxDiscount,
            IsActive = dto.IsActive,
            CreatedAt = DateTime.UtcNow
        };

        _context.Coupons.Add(coupon);
        await _context.SaveChangesAsync();

        _logger.LogInformation("New coupon created: {Code} ({Type} {Value})", coupon.Code, coupon.DiscountType, coupon.DiscountValue);

        return CreatedAtAction(nameof(GetCouponById), new { id = coupon.CouponId }, MapToDto(coupon));
    }

    /// <summary>
    /// Updates an existing coupon (Staff/Admin only).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id}")]
    public async Task<ActionResult<CouponDto>> UpdateCoupon(int id, [FromBody] UpdateCouponDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var coupon = await _context.Coupons.FirstOrDefaultAsync(c => c.CouponId == id);
        if (coupon == null)
        {
            return NotFound(new { message = $"Coupon #{id} not found." });
        }

        if (!string.IsNullOrWhiteSpace(dto.Description))
            coupon.Description = dto.Description.Trim();

        if (!string.IsNullOrWhiteSpace(dto.DiscountType))
            coupon.DiscountType = dto.DiscountType.Trim().ToUpper();

        if (dto.DiscountValue.HasValue)
            coupon.DiscountValue = dto.DiscountValue.Value;

        if (dto.MinSubtotal.HasValue)
            coupon.MinSubtotal = dto.MinSubtotal.Value;

        if (dto.MaxDiscount.HasValue)
            coupon.MaxDiscount = dto.MaxDiscount.Value;

        if (dto.IsActive.HasValue)
            coupon.IsActive = dto.IsActive.Value;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Coupon #{Id} ({Code}) updated.", coupon.CouponId, coupon.Code);

        return Ok(MapToDto(coupon));
    }

    /// <summary>
    /// Quick toggles active/inactive status for a coupon (Staff/Admin only).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPatch("{id}/toggle-status")]
    public async Task<ActionResult<CouponDto>> ToggleStatus(int id)
    {
        var coupon = await _context.Coupons.FirstOrDefaultAsync(c => c.CouponId == id);
        if (coupon == null)
        {
            return NotFound(new { message = $"Coupon #{id} not found." });
        }

        coupon.IsActive = !coupon.IsActive;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Coupon #{Id} ({Code}) status changed to {Status}", coupon.CouponId, coupon.Code, coupon.IsActive ? "Active" : "Inactive");

        return Ok(MapToDto(coupon));
    }

    /// <summary>
    /// Deletes a coupon from the catalog (Staff/Admin only).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCoupon(int id)
    {
        var coupon = await _context.Coupons.FirstOrDefaultAsync(c => c.CouponId == id);
        if (coupon == null)
        {
            return NotFound(new { message = $"Coupon #{id} not found." });
        }

        _context.Coupons.Remove(coupon);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Coupon #{Id} ({Code}) deleted.", id, coupon.Code);

        return Ok(new { message = $"Coupon '{coupon.Code}' deleted successfully." });
    }
}
