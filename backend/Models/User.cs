using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace PCForge.Api.Models;

[Table("users")]
public class User
{
    [Key]
    [Column("userid")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(255)]
    [EmailAddress]
    [Column("email")]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    [Column("passwordhash")]
    public string PasswordHash { get; set; } = string.Empty;

    [Column("roleid")]
    public int RoleId { get; set; }

    [ForeignKey(nameof(RoleId))]
    public Role? Role { get; set; }

    [MaxLength(100)]
    [Column("firstname")]
    public string? FirstName { get; set; }

    [MaxLength(100)]
    [Column("lastname")]
    public string? LastName { get; set; }

    [Column("isactive")]
    public bool IsActive { get; set; } = true;

    [Column("createdat")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updatedat")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

}
