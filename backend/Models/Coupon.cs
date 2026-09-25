namespace PCForge.Api.Models;

public class Coupon
{
    public int CouponId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string DiscountType { get; set; } = "PERCENTAGE"; // "PERCENTAGE" or "FLAT"
    public decimal DiscountValue { get; set; }
    public decimal? MinSubtotal { get; set; } = 0m;
    public decimal? MaxDiscount { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
