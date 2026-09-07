using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CustomBuildSummaryDto
{
    public int BuildId { get; set; }
    public int UserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string BuildName { get; set; } = string.Empty;
    public decimal TotalPrice { get; set; }
    public int EstimatedWattage { get; set; }
    public string Status { get; set; } = "Pending Staff Review";
    public string? CustomerNotes { get; set; }
    public string? StaffNotes { get; set; }
    public int? AssignedStaffId { get; set; }
    public string? AssignedStaffName { get; set; }
    public int ItemCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<CustomBuildComponentDto> Components { get; set; } = new();
}

public class CustomBuildComponentDto
{
    public int ProductId { get; set; }
    public string SlotType { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string? Model { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string? Socket { get; set; }
    public string? MemoryType { get; set; }
    public int? PowerWattage { get; set; }
    public string? Vram { get; set; }
    public string? Chipset { get; set; }
    public string? EfficiencyRating { get; set; }
}

public class CustomBuildDetailDto
{
    public int BuildId { get; set; }
    public int UserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public string BuildName { get; set; } = string.Empty;
    public decimal TotalPrice { get; set; }
    public int EstimatedWattage { get; set; }
    public string Status { get; set; } = "Pending Staff Review";
    public string? CustomerNotes { get; set; }
    public string? StaffNotes { get; set; }
    public int? AssignedStaffId { get; set; }
    public string? AssignedStaffName { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Feasibility calculation indicators
    public bool IsSocketCompatible { get; set; } = true;
    public bool IsMemoryCompatible { get; set; } = true;
    public int? PsuCapacityWatts { get; set; }
    public int? PsuHeadroomWatts { get; set; }
    public int? PsuHeadroomPercentage { get; set; }

    public List<CustomBuildComponentDto> Components { get; set; } = new();
}

public class CreateCustomBuildItemDto
{
    [Required]
    public int ProductId { get; set; }

    [Required]
    public string SlotType { get; set; } = string.Empty;
}

public class CreateCustomBuildDto
{
    [Required]
    [MaxLength(200)]
    public string BuildName { get; set; } = string.Empty;

    public string? CustomerNotes { get; set; }

    [Required]
    [MinLength(1)]
    public List<CreateCustomBuildItemDto> Components { get; set; } = new();
}

public class UpdateBuildReviewStatusDto
{
    [Required]
    public string Status { get; set; } = string.Empty; // 'In Review by Staff', 'Approved by Staff', 'Changes Requested'

    public string? StaffNotes { get; set; }

    public int? AssignedStaffId { get; set; }
}
