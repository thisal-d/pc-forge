namespace PCForge.Api.Models;

public class ServiceTimeSlotOverride
{
    public int OverrideId { get; set; }
    public int SlotId { get; set; }
    public DateTime Date { get; set; }
    public int? CustomCapacity { get; set; }
    public bool IsClosed { get; set; } = false;
    public string? Reason { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ServiceTimeSlot? Slot { get; set; }
}
