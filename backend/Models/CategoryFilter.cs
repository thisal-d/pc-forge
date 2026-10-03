namespace PCForge.Api.Models;

public class CategoryFilter
{
    public int FilterId { get; set; }
    public int CategoryId { get; set; }
    public string FilterKey { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FilterType { get; set; } = "multiselect";
    public string? Unit { get; set; }
    public int DisplayOrder { get; set; } = 0;
    public bool IsFilterable { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Category? Category { get; set; }
    public ICollection<FilterOption> Options { get; set; } = new List<FilterOption>();
}
