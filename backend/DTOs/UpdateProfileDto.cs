using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class UpdateProfileDto
{
    [MaxLength(100)]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    public string? LastName { get; set; }

    [EmailAddress]
    [MaxLength(255)]
    public string? Email { get; set; }

    public string? CurrentPassword { get; set; }

    [MinLength(6, ErrorMessage = "New password must be at least 6 characters long.")]
    public string? NewPassword { get; set; }
}
