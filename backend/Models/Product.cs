namespace PCForge.Api.Models;

public class Product
{
    public int ProductId { get; set; }
    public int CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string? Model { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string? ImageUrl { get; set; }
    public string? Description { get; set; }
    public int WarrantyMonths { get; set; } = 36;

    /// <summary>
    /// Extensible JSONB specifications.
    /// </summary>
    public string? Specifications { get; set; }

    // Hardware attributes for compatibility joins
    public string? Socket { get; set; }
    public string? MemoryType { get; set; }
    public int? PowerWattage { get; set; }
    public string? FormFactor { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public Category? Category { get; set; }
}
