using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace PCForge.Api.Models;

[Table("roles")]
public class Role
{
    [Key]
    [Column("roleid")]
    public int RoleId { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("rolename")]
    public string RoleName { get; set; } = string.Empty;

    [Column("description")]
    public string? Description { get; set; }

    [Column("createdat")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<User> Users { get; set; } = new List<User>();
}
