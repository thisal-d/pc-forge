using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CreateServiceRequestDto
{
    public string? Title { get; set; }
    public string? Description { get; set; }

    public int? OrderId { get; set; }
    public int? ProductId { get; set; }

    public string? ProblemDescription { get; set; }

    public string ProblemCategory { get; set; } = "General";
    public string? TroubleshootingSummary { get; set; }
    public int AttemptCount { get; set; } = 0;
    public string WarrantyStatus { get; set; } = "Active";
    public DateTime? WarrantyExpiryDate { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Priority { get; set; } = "Normal";
    public string? AttachmentUrl { get; set; }
}

public class UpdateServiceRequestDto
{
    public string? Status { get; set; }
    public string? Priority { get; set; }
    public int? AssignedStaffId { get; set; }
    public string? TechnicianNotes { get; set; }
    public string? Resolution { get; set; }
    public string? InternalNotes { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
}

public class ServiceAvailabilityDto
{
    public string Date { get; set; } = string.Empty;
    public int BookedCount { get; set; }
    public int MaxCapacity { get; set; } = 10;
    public int RemainingSlots { get; set; }
    public bool IsAvailable { get; set; }
}

public class ServiceRequestDetailDto
{
    public int ServiceRequestId { get; set; }
    public string ServiceRequestNumber { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerEmail { get; set; }
    public string? CustomerPhone { get; set; }
    public int? OrderId { get; set; }
    public DateTime? OrderDate { get; set; }
    public int? ProductId { get; set; }
    public string? ProductName { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string ProblemDescription { get; set; } = string.Empty;
    public string ProblemCategory { get; set; } = "General";
    public string? TroubleshootingSummary { get; set; }
    public int AttemptCount { get; set; }
    public string WarrantyStatus { get; set; } = "Active";
    public DateTime? WarrantyExpiryDate { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Status { get; set; } = "Pending";
    public string Priority { get; set; } = "Normal";
    public int? AssignedStaffId { get; set; }
    public string? AssignedStaffName { get; set; }
    public string? TechnicianNotes { get; set; }
    public string? Resolution { get; set; }
    public string? InternalNotes { get; set; }
    public string? AttachmentUrl { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class ServiceRequestSummaryDto
{
    public int ServiceRequestId { get; set; }
    public string ServiceRequestNumber { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerEmail { get; set; }
    public int? OrderId { get; set; }
    public int? ProductId { get; set; }
    public string? ProductName { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string ProblemDescription { get; set; } = string.Empty;
    public string ProblemCategory { get; set; } = "General";
    public string WarrantyStatus { get; set; } = "Active";
    public DateTime? WarrantyExpiryDate { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Status { get; set; } = "Pending";
    public string Priority { get; set; } = "Normal";
    public string? TroubleshootingSummary { get; set; }
    public int AttemptCount { get; set; }
    public string? AttachmentUrl { get; set; }
    public int? AssignedStaffId { get; set; }
    public string? AssignedStaffName { get; set; }
    public string? InternalNotes { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class OrderWarrantyInfoDto
{
    public int OrderId { get; set; }
    public string OrderNumber { get; set; } = string.Empty;
    public DateTime OrderDate { get; set; }
    public string Status { get; set; } = string.Empty;
    public List<OrderWarrantyItemDto> Items { get; set; } = new();
}

public class OrderWarrantyItemDto
{
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string CategoryName { get; set; } = string.Empty;
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }
    public string WarrantyPeriod { get; set; } = string.Empty;
    public DateTime WarrantyExpiryDate { get; set; }
    public bool IsActive { get; set; }
}
