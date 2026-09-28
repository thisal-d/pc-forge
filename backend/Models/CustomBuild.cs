namespace PCForge.Api.Models;

public class CustomBuild
{
    public int BuildId { get; set; }
    public int UserId { get; set; }
    public string BuildName { get; set; } = string.Empty;
    public decimal TotalPrice { get; set; }
    public int EstimatedWattage { get; set; }
    public string Status { get; set; } = "Pending Staff Review";
    public string? CustomerNotes { get; set; }
    public string? StaffNotes { get; set; }
    public int? AssignedStaffId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
    public Staff? AssignedStaff { get; set; }
    public List<CustomBuildItem> Items { get; set; } = new();
}

public class CustomBuildItem
{
    public int BuildItemId { get; set; }
    public int BuildId { get; set; }
    public int ProductId { get; set; }
    public string SlotType { get; set; } = string.Empty; // 'cpu', 'motherboard', 'ram', 'gpu', 'psu', 'storage', 'pcCase'
    public decimal UnitPrice { get; set; }

    public CustomBuild? Build { get; set; }
    public Product? Product { get; set; }
}
