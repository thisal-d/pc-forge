using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CreateStaffDto
{
    [Required]
    [MaxLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string LastName { get; set; } = string.Empty;

    [Required]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [MinLength(6)]
    public string? Password { get; set; }

    [Required]
    [MaxLength(100)]
    public string Department { get; set; } = "Hardware Diagnostics & Repair";

    [MaxLength(30)]
    public string? Phone { get; set; }

    public string? Specialization { get; set; }

    [MaxLength(20)]
    public string Status { get; set; } = "Active";

    public string? Notes { get; set; }
}

public class UpdateStaffDto
{
    [MaxLength(100)]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    public string? LastName { get; set; }

    [MaxLength(100)]
    public string? Department { get; set; }

    [MaxLength(30)]
    public string? Phone { get; set; }

    public string? Specialization { get; set; }

    [MaxLength(20)]
    public string? Status { get; set; }

    public string? Notes { get; set; }
}

public class StaffResponseDto
{
    public string Id => $"STF-{StaffId}";
    public int StaffId { get; set; }
    public int UserId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string Role { get; set; } = "Technician Staff";
    public string Department { get; set; } = string.Empty;
    public string? Specialization { get; set; }
    public string Status { get; set; } = "Active";
    public string? Notes { get; set; }
    public string JoinedDate { get; set; } = string.Empty;
    public string CreatedDate { get; set; } = string.Empty;
    public string LastLogin { get; set; } = "Never";
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class ResetStaffPasswordDto
{
    [Required]
    [MinLength(6)]
    public string NewPassword { get; set; } = string.Empty;
}
