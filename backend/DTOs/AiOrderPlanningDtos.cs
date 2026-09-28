using System.Text.Json.Serialization;

namespace PCForge.Api.DTOs;

public class OrderPlanningRequestDto
{
    [JsonPropertyName("reservation_id")]
    public string ReservationId { get; set; } = string.Empty;

    [JsonPropertyName("build_name")]
    public string BuildName { get; set; } = "Custom PCForge Rig";

    [JsonPropertyName("components")]
    public Dictionary<string, object> Components { get; set; } = new();

    [JsonPropertyName("promo_code")]
    public string? PromoCode { get; set; } = "WELCOME5";

    [JsonPropertyName("shipping_method")]
    public string? ShippingMethod { get; set; } = "standard";

    [JsonPropertyName("shipping_address")]
    public string? ShippingAddress { get; set; } = "Colombo, Western Province";

    [JsonPropertyName("currency")]
    public string? Currency { get; set; } = "LKR";

    [JsonPropertyName("session_id")]
    public string? SessionId { get; set; }

    [JsonPropertyName("coupons")]
    public List<CouponContextDto>? Coupons { get; set; }
}

public class CouponContextDto
{
    [JsonPropertyName("code")]
    public string Code { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string? Description { get; set; }

    [JsonPropertyName("discount_type")]
    public string DiscountType { get; set; } = "PERCENTAGE";

    [JsonPropertyName("discount_value")]
    public decimal DiscountValue { get; set; }

    [JsonPropertyName("min_subtotal")]
    public decimal? MinSubtotal { get; set; }

    [JsonPropertyName("max_discount")]
    public decimal? MaxDiscount { get; set; }

    [JsonPropertyName("is_active")]
    public bool IsActive { get; set; } = true;
}

public class OrderPricingItemDto
{
    [JsonPropertyName("product_id")]
    public int ProductId { get; set; }

    [JsonPropertyName("slot")]
    public string Slot { get; set; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("unit_price")]
    public decimal UnitPrice { get; set; }

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; } = 1;

    [JsonPropertyName("total_price")]
    public decimal TotalPrice { get; set; }
}

public class PricingBreakdownDto
{
    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "LKR";

    [JsonPropertyName("subtotal")]
    public decimal Subtotal { get; set; }

    [JsonPropertyName("discount_code")]
    public string? DiscountCode { get; set; }

    [JsonPropertyName("discount_amount")]
    public decimal DiscountAmount { get; set; }

    [JsonPropertyName("discount_label")]
    public string? DiscountLabel { get; set; }

    [JsonPropertyName("delivery_method")]
    public string DeliveryMethod { get; set; } = "Standard Delivery";

    [JsonPropertyName("delivery_fee")]
    public decimal DeliveryFee { get; set; }

    [JsonPropertyName("total_price")]
    public decimal TotalPrice { get; set; }

    [JsonPropertyName("formatted_subtotal")]
    public string FormattedSubtotal { get; set; } = "Rs. 0";

    [JsonPropertyName("formatted_discount")]
    public string FormattedDiscount { get; set; } = "- Rs. 0";

    [JsonPropertyName("formatted_delivery")]
    public string FormattedDelivery { get; set; } = "Rs. 0";

    [JsonPropertyName("formatted_total")]
    public string FormattedTotal { get; set; } = "Rs. 0";
}

public class OrderProposalDto
{
    [JsonPropertyName("proposal_id")]
    public string ProposalId { get; set; } = string.Empty;

    [JsonPropertyName("order_number")]
    public string OrderNumber { get; set; } = "PCF-10492";

    [JsonPropertyName("build_name")]
    public string BuildName { get; set; } = "Custom PCForge Rig";

    [JsonPropertyName("reservation_id")]
    public string ReservationId { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "WAITING_FOR_APPROVAL";

    [JsonPropertyName("status_label")]
    public string StatusLabel { get; set; } = "Waiting for your approval";

    [JsonPropertyName("components_count")]
    public int ComponentsCount { get; set; } = 8;

    [JsonPropertyName("pricing")]
    public PricingBreakdownDto Pricing { get; set; } = new();

    [JsonPropertyName("components")]
    public List<OrderPricingItemDto> Components { get; set; } = new();

    [JsonPropertyName("estimated_delivery")]
    public string EstimatedDelivery { get; set; } = "3-5 business days";

    [JsonPropertyName("technician_notice")]
    public string TechnicianNotice { get; set; } = "We'll notify you once a technician has checked your build — usually within a few hours.";
}

public class OrderProposalResponseDto
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("proposal")]
    public OrderProposalDto? Proposal { get; set; }

    [JsonPropertyName("agent_trace")]
    public List<string> AgentTrace { get; set; } = new();

    [JsonPropertyName("error")]
    public string? Error { get; set; }
}

public class SubmitApprovedOrderRequestDto
{
    [JsonPropertyName("proposal_id")]
    public string ProposalId { get; set; } = string.Empty;

    [JsonPropertyName("order_number")]
    public string OrderNumber { get; set; } = string.Empty;

    [JsonPropertyName("reservation_id")]
    public string ReservationId { get; set; } = string.Empty;

    [JsonPropertyName("build_name")]
    public string BuildName { get; set; } = string.Empty;

    [JsonPropertyName("total_amount")]
    public decimal TotalAmount { get; set; }

    [JsonPropertyName("formatted_total")]
    public string FormattedTotal { get; set; } = string.Empty;

    [JsonPropertyName("shipping_address")]
    public string ShippingAddress { get; set; } = "Colombo, Western Province";

    [JsonPropertyName("components")]
    public List<OrderPricingItemDto> Components { get; set; } = new();
}

public class SubmitApprovedOrderResponseDto
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("order_number")]
    public string OrderNumber { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Pending technician review";

    [JsonPropertyName("formatted_total")]
    public string FormattedTotal { get; set; } = string.Empty;

    [JsonPropertyName("message")]
    public string Message { get; set; } = "We'll notify you once a technician has checked your build — usually within a few hours.";

    [JsonPropertyName("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
