using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CategoryDto
{
    public int CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public int FilterCount { get; set; }
    public int ProductCount { get; set; }
    public string Status { get; set; } = "Active";
}

public class CreateCategoryDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Status { get; set; }
}

public class UpdateCategoryDto
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Status { get; set; }
}

public class FilterOptionDto
{
    public int OptionId { get; set; }
    public string Value { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
}

public class CategoryFilterDto
{
    public int FilterId { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string FilterKey { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FilterType { get; set; } = "multiselect";
    public string? Unit { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsFilterable { get; set; } = true;
    public List<FilterOptionDto> Options { get; set; } = new();
}

public class CreateCategoryFilterDto
{
    public int? MasterFilterId { get; set; }
    public string FilterKey { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string FilterType { get; set; } = "multiselect";
    public string? Unit { get; set; }
    public int? DisplayOrder { get; set; }
    public bool IsFilterable { get; set; } = true;
    public List<string>? Options { get; set; }
}

public class UpdateCategoryFilterDto
{
    public string? DisplayName { get; set; }
    public int? DisplayOrder { get; set; }
    public bool? IsFilterable { get; set; }
}

public class ReorderCategoryFilterItemDto
{
    public int FilterId { get; set; }
    public int DisplayOrder { get; set; }
}

public class ReorderCategoryFiltersDto
{
    public List<ReorderCategoryFilterItemDto> Order { get; set; } = new();
}

public class ProductDto
{
    public int ProductId { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string? Model { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string? ImageUrl { get; set; }
    public string? Description { get; set; }
    public int WarrantyMonths { get; set; } = 36;
    public string Status { get; set; } = "Active";

    // Specifications & compatibility
    public object? Specifications { get; set; }
    public string? Socket { get; set; }
    public string? MemoryType { get; set; }
    public int? PowerWattage { get; set; }
    public string? FormFactor { get; set; }
}

public class UpdateStockDto
{
    [Range(0, int.MaxValue, ErrorMessage = "Stock quantity must be zero or greater.")]
    public int? StockQuantity { get; set; }

    public int? Delta { get; set; }

    public string? Reason { get; set; }
}

public class UpdateProductStatusDto
{
    public string? Status { get; set; }
}

public class CreateProductDto
{
    [Required]
    public int CategoryId { get; set; }

    [Required]
    [StringLength(255)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [StringLength(100)]
    public string Brand { get; set; } = string.Empty;

    [StringLength(100)]
    public string? Model { get; set; }

    [Range(0.01, 1000000.00)]
    public decimal Price { get; set; }

    [Range(0, int.MaxValue)]
    public int StockQuantity { get; set; } = 0;

    public int WarrantyMonths { get; set; } = 36;

    public string? Status { get; set; } = "Active";

    public string? ImageUrl { get; set; }
    public string? Description { get; set; }
    public string? Specifications { get; set; }
    public string? Socket { get; set; }
    public string? MemoryType { get; set; }
    public int? PowerWattage { get; set; }
    public string? FormFactor { get; set; }
}

public class UpdateProductDto
{
    public int? CategoryId { get; set; }
    public string? Name { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public decimal? Price { get; set; }
    public int? StockQuantity { get; set; }
    public int? WarrantyMonths { get; set; }
    public string? Status { get; set; }
    public string? ImageUrl { get; set; }
    public string? Description { get; set; }
    public string? Specifications { get; set; }
    public string? Socket { get; set; }
    public string? MemoryType { get; set; }
    public int? PowerWattage { get; set; }
    public string? FormFactor { get; set; }
}

