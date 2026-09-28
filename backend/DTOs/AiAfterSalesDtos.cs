using System.Text.Json.Serialization;

namespace PCForge.Api.DTOs;

public class CustomerContextDto
{
    [JsonPropertyName("user_id")]
    public int UserId { get; set; }

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;
}

public class OrderContextItemDto
{
    [JsonPropertyName("product_id")]
    public int ProductId { get; set; }

    [JsonPropertyName("product_name")]
    public string ProductName { get; set; } = string.Empty;

    [JsonPropertyName("category")]
    public string Category { get; set; } = "Hardware";

    [JsonPropertyName("unit_price")]
    public decimal UnitPrice { get; set; }

    [JsonPropertyName("quantity")]
    public int Quantity { get; set; } = 1;

    [JsonPropertyName("specifications")]
    public string? Specifications { get; set; }

    [JsonPropertyName("warranty_period")]
    public string? WarrantyPeriod { get; set; }

    [JsonPropertyName("warranty_months")]
    public int WarrantyMonths { get; set; } = 36;

    [JsonPropertyName("warranty_expiry_date")]
    public string? WarrantyExpiryDate { get; set; }

    [JsonPropertyName("is_under_warranty")]
    public bool IsUnderWarranty { get; set; } = true;
}

public class OrderContextDto
{
    [JsonPropertyName("order_id")]
    public int OrderId { get; set; }

    [JsonPropertyName("order_number")]
    public string OrderNumber { get; set; } = string.Empty;

    [JsonPropertyName("purchase_date")]
    public string PurchaseDate { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Delivered";

    [JsonPropertyName("total_amount")]
    public decimal TotalAmount { get; set; }

    [JsonPropertyName("items")]
    public List<OrderContextItemDto> Items { get; set; } = new();
}

public class ServiceRequestContextDto
{
    [JsonPropertyName("service_request_id")]
    public int ServiceRequestId { get; set; }

    [JsonPropertyName("service_request_number")]
    public string ServiceRequestNumber { get; set; } = string.Empty;

    [JsonPropertyName("order_id")]
    public int? OrderId { get; set; }

    [JsonPropertyName("product_id")]
    public int? ProductId { get; set; }

    [JsonPropertyName("problem_description")]
    public string ProblemDescription { get; set; } = string.Empty;

    [JsonPropertyName("problem_category")]
    public string ProblemCategory { get; set; } = "General";

    [JsonPropertyName("warranty_status")]
    public string WarrantyStatus { get; set; } = "Active";

    [JsonPropertyName("preferred_date")]
    public string? PreferredDate { get; set; }

    [JsonPropertyName("preferred_time")]
    public string? PreferredTime { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "PENDING";

    [JsonPropertyName("priority")]
    public string Priority { get; set; } = "Normal";

    [JsonPropertyName("created_at")]
    public string CreatedAt { get; set; } = string.Empty;
}

public class AfterSalesChatRequestDto
{
    [JsonPropertyName("user_id")]
    public int UserId { get; set; } = 1;

    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;

    [JsonPropertyName("session_id")]
    public string? SessionId { get; set; }

    [JsonPropertyName("order_id")]
    public int? OrderId { get; set; }

    [JsonPropertyName("customer")]
    public CustomerContextDto? Customer { get; set; }

    [JsonPropertyName("orders")]
    public List<OrderContextDto>? Orders { get; set; }

    [JsonPropertyName("service_requests")]
    public List<ServiceRequestContextDto>? ServiceRequests { get; set; }
}

public class ServiceRequestInfoDto
{
    [JsonPropertyName("action")]
    public string? Action { get; set; }

    [JsonPropertyName("id")]
    public int? Id { get; set; }

    [JsonPropertyName("service_request_id")]
    public int? ServiceRequestId { get; set; }

    [JsonPropertyName("service_request_number")]
    public string ServiceRequestNumber { get; set; } = string.Empty;

    [JsonPropertyName("order_id")]
    public int? OrderId { get; set; }

    [JsonPropertyName("order_number")]
    public string? OrderNumber { get; set; }

    [JsonPropertyName("product_id")]
    public int? ProductId { get; set; }

    [JsonPropertyName("product_name")]
    public string? ProductName { get; set; }

    [JsonPropertyName("problem_description")]
    public string ProblemDescription { get; set; } = string.Empty;

    [JsonPropertyName("problem_category")]
    public string ProblemCategory { get; set; } = "General";

    [JsonPropertyName("troubleshooting_summary")]
    public string? TroubleshootingSummary { get; set; }

    [JsonPropertyName("attempt_count")]
    public int AttemptCount { get; set; }

    [JsonPropertyName("warranty_status")]
    public string WarrantyStatus { get; set; } = "Active";

    [JsonPropertyName("warranty_expiry_date")]
    public string? WarrantyExpiryDate { get; set; }

    [JsonPropertyName("preferred_date")]
    public string? PreferredDate { get; set; }

    [JsonPropertyName("preferred_time")]
    public string? PreferredTime { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "PENDING";

    [JsonPropertyName("priority")]
    public string Priority { get; set; } = "Normal";

    [JsonPropertyName("created_at")]
    public string CreatedAt { get; set; } = string.Empty;
}

public class RmaTicketDetailsDto
{
    [JsonPropertyName("ticket_id")]
    public int TicketId { get; set; }

    [JsonPropertyName("rma_number")]
    public string RmaNumber { get; set; } = string.Empty;

    [JsonPropertyName("order_id")]
    public int? OrderId { get; set; }

    [JsonPropertyName("order_number")]
    public string? OrderNumber { get; set; } = "PCF-10492";

    [JsonPropertyName("product_id")]
    public int? ProductId { get; set; }

    [JsonPropertyName("component_name")]
    public string ComponentName { get; set; } = string.Empty;

    [JsonPropertyName("issue_type")]
    public string IssueType { get; set; } = "Hardware fault";

    [JsonPropertyName("status")]
    public string Status { get; set; } = "Escalated to Technician";

    [JsonPropertyName("priority")]
    public string Priority { get; set; } = "High";

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("attachment_url")]
    public string? AttachmentUrl { get; set; }

    [JsonPropertyName("created_at")]
    public string CreatedAt { get; set; } = string.Empty;
}

public class AfterSalesChatResponseDto
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }

    [JsonPropertyName("reply")]
    public string Reply { get; set; } = string.Empty;

    [JsonPropertyName("attempt_count")]
    public int AttemptCount { get; set; } = 0;

    [JsonPropertyName("attempted_steps")]
    public List<string> AttemptedSteps { get; set; } = new();

    [JsonPropertyName("problem_category")]
    public string? ProblemCategory { get; set; }

    [JsonPropertyName("is_resolved")]
    public bool IsResolved { get; set; } = false;

    [JsonPropertyName("service_request_required")]
    public bool ServiceRequestRequired { get; set; } = false;

    [JsonPropertyName("service_request_mode")]
    public bool ServiceRequestMode { get; set; } = false;

    [JsonPropertyName("service_request")]
    public ServiceRequestInfoDto? ServiceRequest { get; set; }

    [JsonPropertyName("ticket")]
    public RmaTicketDetailsDto? Ticket { get; set; }

    [JsonPropertyName("agent_trace")]
    public List<string> AgentTrace { get; set; } = new();

    [JsonPropertyName("error")]
    public string? Error { get; set; }
}
