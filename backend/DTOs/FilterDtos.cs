using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class MasterFilterDto
{
    public int FilterId { get; set; }
    public string FilterKey { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FilterType { get; set; } = "multiselect";
    public string? Unit { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public int AssignedCategoriesCount { get; set; }
    public List<string> AssignedCategoryNames { get; set; } = new();
    public List<FilterOptionDto> Options { get; set; } = new();
}

public class CreateMasterFilterDto
{
    [Required]
    [MaxLength(50)]
    public string FilterKey { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string DisplayName { get; set; } = string.Empty;

    [MaxLength(30)]
    public string FilterType { get; set; } = "multiselect";

    [MaxLength(20)]
    public string? Unit { get; set; }

    public List<string>? Options { get; set; }
}

public class UpdateMasterFilterDto
{
    [Required]
    [MaxLength(100)]
    public string DisplayName { get; set; } = string.Empty;

    [MaxLength(30)]
    public string FilterType { get; set; } = "multiselect";

    [MaxLength(20)]
    public string? Unit { get; set; }

    public List<string>? Options { get; set; }
}
