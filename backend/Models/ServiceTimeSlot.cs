namespace PCForge.Api.Models;

public class ServiceTimeSlot
{
    public int SlotId { get; set; }
    public string StartTime { get; set; } = string.Empty;
    public string EndTime { get; set; } = string.Empty;
    public string? Label { get; set; }
    public int DefaultCapacity { get; set; } = 5;
    public bool IsActive { get; set; } = true;
    public int DisplayOrder { get; set; } = 0;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<ServiceTimeSlotOverride> Overrides { get; set; } = new List<ServiceTimeSlotOverride>();
    public ICollection<ServiceRequest> ServiceRequests { get; set; } = new List<ServiceRequest>();
}
