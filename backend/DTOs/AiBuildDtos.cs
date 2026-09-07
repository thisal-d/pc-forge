using System.Text.Json.Serialization;

namespace PCForge.Api.DTOs;

public class RequirementProfileDto
{
    [JsonPropertyName("purpose")]
    public string? Purpose { get; set; }

    [JsonPropertyName("budget_raw")]
    public string? BudgetRaw { get; set; }

    [JsonPropertyName("budget_amount")]
    public decimal? BudgetAmount { get; set; }

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "LKR";

    [JsonPropertyName("target_resolution")]
    public string? TargetResolution { get; set; }

    [JsonPropertyName("monitor_needed")]
    public bool? MonitorNeeded { get; set; }

    [JsonPropertyName("preferences")]
    public List<string> Preferences { get; set; } = new();

    [JsonPropertyName("missing_fields")]
    public List<string> MissingFields { get; set; } = new();

    [JsonPropertyName("is_complete")]
    public bool IsComplete { get; set; }
}

public class RequirementChatRequestDto
{
    public string Message { get; set; } = string.Empty;
}

public class RequirementChatResponseDto
{
    [JsonPropertyName("session_id")]
    public string SessionId { get; set; } = string.Empty;

    [JsonPropertyName("reply")]
    public string Reply { get; set; } = string.Empty;

    [JsonPropertyName("profile")]
    public RequirementProfileDto Profile { get; set; } = new();

    [JsonPropertyName("is_complete")]
    public bool IsComplete { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "gathering";
}

public class RequirementSessionStartResponseDto
{
    public string SessionId { get; set; } = string.Empty;
    public string GreetingMessage { get; set; } = string.Empty;
    public RequirementProfileDto Profile { get; set; } = new();
}

public class ComponentItemDto
{
    [JsonPropertyName("product_id")]
    public int ProductId { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = string.Empty;

    [JsonPropertyName("brand")]
    public string Brand { get; set; } = string.Empty;

    [JsonPropertyName("model")]
    public string? Model { get; set; }

    [JsonPropertyName("price")]
    public decimal Price { get; set; }

    [JsonPropertyName("socket")]
    public string? Socket { get; set; }

    [JsonPropertyName("memory_type")]
    public string? MemoryType { get; set; }

    [JsonPropertyName("power_wattage")]
    public int? PowerWattage { get; set; }

    [JsonPropertyName("form_factor")]
    public string? FormFactor { get; set; }
}

public class CompatibilityChecklistDto
{
    [JsonPropertyName("socket_match")]
    public bool SocketMatch { get; set; }

    [JsonPropertyName("socket_details")]
    public string SocketDetails { get; set; } = string.Empty;

    [JsonPropertyName("memory_match")]
    public bool MemoryMatch { get; set; }

    [JsonPropertyName("memory_details")]
    public string MemoryDetails { get; set; } = string.Empty;

    [JsonPropertyName("wattage_ok")]
    public bool WattageOk { get; set; }

    [JsonPropertyName("estimated_wattage")]
    public int EstimatedWattage { get; set; }

    [JsonPropertyName("psu_wattage")]
    public int PsuWattage { get; set; }

    [JsonPropertyName("headroom_watts")]
    public int HeadroomWatts { get; set; }

    [JsonPropertyName("case_fit_ok")]
    public bool CaseFitOk { get; set; }

    [JsonPropertyName("case_fit_details")]
    public string CaseFitDetails { get; set; } = string.Empty;

    [JsonPropertyName("all_passed")]
    public bool AllPassed { get; set; }
}

public class ValidatedBuildDto
{
    [JsonPropertyName("build_name")]
    public string BuildName { get; set; } = string.Empty;

    [JsonPropertyName("purpose")]
    public string Purpose { get; set; } = string.Empty;

    [JsonPropertyName("target_resolution")]
    public string TargetResolution { get; set; } = string.Empty;

    [JsonPropertyName("components")]
    public Dictionary<string, ComponentItemDto> Components { get; set; } = new();

    [JsonPropertyName("total_price")]
    public decimal TotalPrice { get; set; }

    [JsonPropertyName("estimated_wattage")]
    public int EstimatedWattage { get; set; }

    [JsonPropertyName("compatibility")]
    public CompatibilityChecklistDto Compatibility { get; set; } = new();

    [JsonPropertyName("is_valid")]
    public bool IsValid { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "VALIDATED_PENDING_STOCK";
}

public class BuildGenerationRequestDto
{
    [JsonPropertyName("session_id")]
    public string? SessionId { get; set; }

    [JsonPropertyName("purpose")]
    public string Purpose { get; set; } = "Gaming";

    [JsonPropertyName("budget_amount")]
    public decimal BudgetAmount { get; set; } = 400000m;

    [JsonPropertyName("currency")]
    public string Currency { get; set; } = "LKR";

    [JsonPropertyName("target_resolution")]
    public string TargetResolution { get; set; } = "1440p";

    [JsonPropertyName("preferences")]
    public List<string> Preferences { get; set; } = new();

    [JsonPropertyName("catalog")]
    public List<ComponentItemDto>? Catalog { get; set; }
}

public class BuildGenerationResponseDto
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("build")]
    public ValidatedBuildDto? Build { get; set; }

    [JsonPropertyName("summary")]
    public string Summary { get; set; } = string.Empty;

    [JsonPropertyName("trace_steps")]
    public List<string> TraceSteps { get; set; } = new();

    [JsonPropertyName("error")]
    public string? Error { get; set; }
}

