namespace PCForge.Api.Models;

public class MasterFilterOption
{
    public int OptionId { get; set; }
    public int FilterId { get; set; }
    public string OptionValue { get; set; } = string.Empty;
    public int DisplayOrder { get; set; } = 0;

    public Filter? Filter { get; set; }
}
