using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CreateSupportTicketDto
{
    public int? OrderId { get; set; }

    public int? ProductId { get; set; }

    [Required]
    [MaxLength(50)]
    public string IssueType { get; set; } = "Hardware Failure";

    [Required]
    [MaxLength(200)]
    public string Subject { get; set; } = string.Empty;

    [Required]
    public string Description { get; set; } = string.Empty;

    public string? AttachmentUrl { get; set; }
}

public class SupportTicketSummaryDto
{
    public int TicketId { get; set; }
    public int UserId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerEmail { get; set; }
    public int? OrderId { get; set; }
    public string? ProductName { get; set; }
    public string IssueType { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string Status { get; set; } = "Open";
    public string Priority { get; set; } = "Normal";
    public int? AssignedStaffId { get; set; }
    public string? AssignedStaffName { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class SupportTicketDetailDto
{
    public int TicketId { get; set; }
    public int UserId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerEmail { get; set; }
    public int? OrderId { get; set; }
    public int? ProductId { get; set; }
    public string? ProductName { get; set; }
    public string IssueType { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? AttachmentUrl { get; set; }
    public string Status { get; set; } = "Open";
    public string Priority { get; set; } = "Normal";
    public string? ResolutionNotes { get; set; }
    public int? AssignedStaffId { get; set; }
    public string? AssignedStaffName { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class UpdateSupportTicketDto
{
    public string? Status { get; set; }
    public string? Priority { get; set; }
    public string? ResolutionNotes { get; set; }
    public int? AssignedStaffId { get; set; }
}

