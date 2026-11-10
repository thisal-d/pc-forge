namespace PCForge.Api.Models;

public class FilterOption
{
    public int OptionId { get; set; }
    public int FilterId { get; set; }
    public string OptionValue { get; set; } = string.Empty;
    public int DisplayOrder { get; set; } = 0;

    public CategoryFilter? Filter { get; set; }
}
