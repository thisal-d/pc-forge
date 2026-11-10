namespace PCForge.Api.Models;

public class Filter
{
    public int FilterId { get; set; }
    public string FilterKey { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FilterType { get; set; } = "multiselect";
    public string? Unit { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<MasterFilterOption> Options { get; set; } = new List<MasterFilterOption>();
    public ICollection<CategoryFilter> CategoryFilters { get; set; } = new List<CategoryFilter>();
}
