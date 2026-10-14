using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class RegisterDto
{
    [Required(ErrorMessage = "Email address is required.")]
    [EmailAddress(ErrorMessage = "Please enter a valid email address.")]
    [MaxLength(100, ErrorMessage = "Email cannot exceed 100 characters.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Password is required.")]
    [MinLength(8, ErrorMessage = "Password must be at least 8 characters long.")]
    [MaxLength(100, ErrorMessage = "Password cannot exceed 100 characters.")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "First name is required.")]
    [MinLength(2, ErrorMessage = "First name must be at least 2 characters.")]
    [MaxLength(100, ErrorMessage = "First name cannot exceed 100 characters.")]
    public string? FirstName { get; set; }

    [Required(ErrorMessage = "Last name is required.")]
    [MinLength(2, ErrorMessage = "Last name must be at least 2 characters.")]
    [MaxLength(100, ErrorMessage = "Last name cannot exceed 100 characters.")]
    public string? LastName { get; set; }
}
