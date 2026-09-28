namespace PCForge.Api.Models;

public class ServiceRequest
{
    public int ServiceRequestId { get; set; }
    public string ServiceRequestNumber { get; set; } = string.Empty;
    public int UserId { get; set; }
    public int? OrderId { get; set; }
    public int? ProductId { get; set; }
    public string ProblemDescription { get; set; } = string.Empty;
    public string ProblemCategory { get; set; } = "General";
    public string? TroubleshootingSummary { get; set; }
    public int AttemptCount { get; set; } = 0;
    public string WarrantyStatus { get; set; } = "Active";
    public DateTime? WarrantyExpiryDate { get; set; }
    public DateTime? PreferredDate { get; set; }
    public string? PreferredTime { get; set; }
    public string Status { get; set; } = "PENDING";
    public string Priority { get; set; } = "Normal";
    public int? AssignedStaffId { get; set; }
    public string? TechnicianNotes { get; set; }
    public string? Resolution { get; set; }
    public string? AttachmentUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
    public Order? Order { get; set; }
    public Product? Product { get; set; }
    public Staff? AssignedStaff { get; set; }
}
