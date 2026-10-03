using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace PCForge.Api.Models;

[Table("staff")]
public class Staff
{
    [Key]
    [Column("staffid")]
    public int StaffId { get; set; }

    [Required]
    [Column("userid")]
    public int UserId { get; set; }

    [ForeignKey(nameof(UserId))]
    public User? User { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("department")]
    public string Department { get; set; } = string.Empty;

    [MaxLength(30)]
    [Column("phone")]
    public string? Phone { get; set; }

    [Column("specialization")]
    public string? Specialization { get; set; }

    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "Active";

    [Column("notes")]
    public string? Notes { get; set; }

    [Column("joineddate")]
    public DateOnly JoinedDate { get; set; } = DateOnly.FromDateTime(DateTime.UtcNow);

    [Column("createdat")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updatedat")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
