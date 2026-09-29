namespace PCForge.Api.Models;

public class SupportTicket
{
    public int TicketId { get; set; }
    public int UserId { get; set; }
    public int? OrderId { get; set; }
    public int? ProductId { get; set; }
    public string IssueType { get; set; } = "General";
    public string Subject { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? AttachmentUrl { get; set; }
    public string Status { get; set; } = "Open";
    public string Priority { get; set; } = "Normal";
    public string? ResolutionNotes { get; set; }
    public int? AssignedStaffId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
    public Order? Order { get; set; }
    public Product? Product { get; set; }
    public Staff? AssignedStaff { get; set; }
}
