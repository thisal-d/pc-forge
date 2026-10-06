namespace PCForge.Api.Models;

public class ServiceRequest
{
    public int ServiceRequestId { get; set; }
    public string ServiceRequestNumber { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string? Title { get; set; }
    public string? Description { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
}
