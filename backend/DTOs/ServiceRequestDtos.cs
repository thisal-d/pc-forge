using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CreateServiceRequestDto
{
    public string? Title { get; set; }
    public string? Description { get; set; }

    [Required(ErrorMessage = "Appointment date is required.")]
    public DateTime? PreferredDate { get; set; }

    public int? SlotId { get; set; }

    public string? PreferredTime { get; set; }
}

public class UpdateServiceRequestDto
{
    public string? Status { get; set; }
    public int? SlotId { get; set; }
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
    public List<SlotAvailabilityDto> Slots { get; set; } = new();
}

public class ServiceTimeSlotDto
{
    public int SlotId { get; set; }
    public string StartTime { get; set; } = string.Empty;
    public string EndTime { get; set; } = string.Empty;
    public string? Label { get; set; }
    public int DefaultCapacity { get; set; } = 5;
    public bool IsActive { get; set; } = true;
    public int DisplayOrder { get; set; } = 0;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class CreateServiceTimeSlotDto
{
    [Required(ErrorMessage = "Start time is required (e.g. 09:00).")]
    public string StartTime { get; set; } = string.Empty;

    [Required(ErrorMessage = "End time is required (e.g. 11:00).")]
    public string EndTime { get; set; } = string.Empty;

    public string? Label { get; set; }

    [Range(1, 200, ErrorMessage = "Default capacity must be at least 1.")]
    public int DefaultCapacity { get; set; } = 5;

    public bool IsActive { get; set; } = true;

    public int DisplayOrder { get; set; } = 0;
}

public class UpdateServiceTimeSlotDto
{
    public string? StartTime { get; set; }
    public string? EndTime { get; set; }
    public string? Label { get; set; }
    public int? DefaultCapacity { get; set; }
    public bool? IsActive { get; set; }
    public int? DisplayOrder { get; set; }
}

public class SlotAvailabilityDto
{
    public int SlotId { get; set; }
    public string StartTime { get; set; } = string.Empty;
    public string EndTime { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public int DefaultCapacity { get; set; }
    public int MaxCapacity { get; set; }
    public int BookedCount { get; set; }
    public int RemainingSlots { get; set; }
    public bool IsAvailable { get; set; }
    public bool IsClosed { get; set; }
    public string? Reason { get; set; }
    public bool IsActive { get; set; }
    public bool IsOverridden { get; set; }
}

public class SetTimeSlotOverrideDto
{
    [Required(ErrorMessage = "Date is required.")]
    public DateTime Date { get; set; }

    [Range(0, 500, ErrorMessage = "Custom capacity cannot be negative.")]
    public int? CustomCapacity { get; set; }

    public bool IsClosed { get; set; } = false;

    public string? Reason { get; set; }
}

public class ServiceTimeSlotOverrideDto
{
    public int OverrideId { get; set; }
    public int SlotId { get; set; }
    public string Date { get; set; } = string.Empty;
    public int? CustomCapacity { get; set; }
    public bool IsClosed { get; set; }
    public string? Reason { get; set; }
}

public class ServiceRequestDetailDto
{
    public int ServiceRequestId { get; set; }
    public string ServiceRequestNumber { get; set; } = string.Empty;
    public int UserId { get; set; }
    public int? SlotId { get; set; }
    public string? TimeSlotLabel { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerEmail { get; set; }
    public string? CustomerPhone { get; set; }
    public string? Title { get; set; }
    public string? Description { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Status { get; set; } = "Booked";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class ServiceRequestSummaryDto
{
    public int ServiceRequestId { get; set; }
    public string ServiceRequestNumber { get; set; } = string.Empty;
    public int UserId { get; set; }
    public int? SlotId { get; set; }
    public string? TimeSlotLabel { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerEmail { get; set; }
    public string? Title { get; set; }
    public string? Description { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Status { get; set; } = "Booked";
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
