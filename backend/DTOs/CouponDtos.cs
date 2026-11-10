using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CouponDto
{
    public int CouponId { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string DiscountType { get; set; } = "PERCENTAGE";
    public decimal DiscountValue { get; set; }
    public decimal? MinSubtotal { get; set; }
    public decimal? MaxDiscount { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class CreateCouponDto
{
    [Required]
    [StringLength(50, MinimumLength = 2)]
    public string Code { get; set; } = string.Empty;

    [Required]
    [StringLength(255)]
    public string Description { get; set; } = string.Empty;

    [Required]
    [RegularExpression("^(PERCENTAGE|FLAT)$", ErrorMessage = "DiscountType must be either PERCENTAGE or FLAT")]
    public string DiscountType { get; set; } = "PERCENTAGE";

    [Required]
    [Range(0.01, 1000000.0, ErrorMessage = "DiscountValue must be greater than 0")]
    public decimal DiscountValue { get; set; }

    [Range(0, 10000000.0)]
    public decimal? MinSubtotal { get; set; } = 0m;

    [Range(0, 10000000.0)]
    public decimal? MaxDiscount { get; set; }

    public bool IsActive { get; set; } = true;
}

public class UpdateCouponDto
{
    [StringLength(255)]
    public string? Description { get; set; }

    [RegularExpression("^(PERCENTAGE|FLAT)$", ErrorMessage = "DiscountType must be either PERCENTAGE or FLAT")]
    public string? DiscountType { get; set; }

    [Range(0.01, 1000000.0)]
    public decimal? DiscountValue { get; set; }

    [Range(0, 10000000.0)]
    public decimal? MinSubtotal { get; set; }

    [Range(0, 10000000.0)]
    public decimal? MaxDiscount { get; set; }

    public bool? IsActive { get; set; }
}
