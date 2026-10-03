using System.Text.Json.Serialization;

namespace PCForge.Api.DTOs;

public class StockVerificationRequestDto
{
    [JsonPropertyName("session_id")]
    public string? SessionId { get; set; }

    [JsonPropertyName("build_name")]
    public string BuildName { get; set; } = "PCForge Custom Build";

    [JsonPropertyName("target_resolution")]
    public string TargetResolution { get; set; } = "1440p";

    [JsonPropertyName("component_ids")]
    public Dictionary<string, int> ComponentIds { get; set; } = new();

    [JsonPropertyName("hold_minutes")]
    public int HoldMinutes { get; set; } = 15;

    [JsonPropertyName("catalog")]
    public List<ComponentItemDto>? Catalog { get; set; }
}

public class ComponentStockStatusDto
{
    [JsonPropertyName("slot_type")]
    public string SlotType { get; set; } = string.Empty;

    [JsonPropertyName("product_id")]
    public int ProductId { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("brand")]
    public string Brand { get; set; } = string.Empty;

    [JsonPropertyName("price")]
    public decimal Price { get; set; }

    [JsonPropertyName("stock_quantity")]
    public int StockQuantity { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "IN_STOCK";

    [JsonPropertyName("status_label")]
    public string StatusLabel { get; set; } = "In stock";

    [JsonPropertyName("was_substituted")]
    public bool WasSubstituted { get; set; }

    [JsonPropertyName("original_product_name")]
    public string? OriginalProductName { get; set; }
}

public class ReservationHoldDto
{
    [JsonPropertyName("reservation_id")]
    public string ReservationId { get; set; } = string.Empty;

    [JsonPropertyName("held_minutes")]
    public int HeldMinutes { get; set; } = 15;

    [JsonPropertyName("expires_at")]
    public string ExpiresAt { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Reserved";

    [JsonPropertyName("reserved_product_ids")]
    public List<int> ReservedProductIds { get; set; } = new();
}

public class StockVerificationResponseDto
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("all_in_stock")]
    public bool AllInStock { get; set; }

    [JsonPropertyName("total_price")]
    public decimal TotalPrice { get; set; }

    [JsonPropertyName("components")]
    public Dictionary<string, ComponentStockStatusDto> Components { get; set; } = new();

    [JsonPropertyName("reservation")]
    public ReservationHoldDto Reservation { get; set; } = new();

    [JsonPropertyName("substitutions_made")]
    public List<string> SubstitutionsMade { get; set; } = new();

    [JsonPropertyName("summary")]
    public string Summary { get; set; } = string.Empty;

    [JsonPropertyName("trace_steps")]
    public List<string> TraceSteps { get; set; } = new();

    [JsonPropertyName("error")]
    public string? Error { get; set; }
}
