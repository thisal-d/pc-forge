using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<ProductsController> _logger;

    public ProductsController(AppDbContext context, ILogger<ProductsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Search and filter products with dynamic Nanotek-style faceted filtering.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<ProductDto>>> GetProducts(
        [FromQuery] int? categoryId,
        [FromQuery] string? brand,
        [FromQuery] string? search,
        [FromQuery] decimal? minPrice,
        [FromQuery] decimal? maxPrice,
        [FromQuery] bool inStockOnly = false,
        [FromQuery] string sortBy = "name_asc",
        [FromQuery] string? socket = null,
        [FromQuery] string? chipset = null,
        [FromQuery] string? memoryType = null,
        [FromQuery] string? speed = null,
        [FromQuery] string? capacity = null,
        [FromQuery] string? vram = null,
        [FromQuery] string? efficiency = null,
        [FromQuery] string? status = null)
    {
        // 1. Relational database query for core fields
        IQueryable<Product> query = _context.Products
            .AsNoTracking()
            .Include(p => p.Category);

        // Security & Storefront Status Filter:
        // Customers and unauthenticated public visitors only see Active products.
        // Admins and Staff can see all products or filter by specific status (e.g. ?status=Inactive, ?status=Active, ?status=all).
        bool isStaffOrAdmin = User.Identity?.IsAuthenticated == true && (User.IsInRole("Admin") || User.IsInRole("Staff"));

        if (!isStaffOrAdmin)
        {
            query = query.Where(p => p.Status == "Active");
        }
        else if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            var s = status.Trim().ToLower();
            query = query.Where(p => p.Status.ToLower() == s);
        }

        if (categoryId.HasValue && categoryId.Value > 0)
        {
            query = query.Where(p => p.CategoryId == categoryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(brand))
        {
            var brandLower = brand.Trim().ToLower();
            query = query.Where(p => p.Brand.ToLower() == brandLower);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(p =>
                p.Name.ToLower().Contains(s) ||
                p.Brand.ToLower().Contains(s) ||
                (p.Model != null && p.Model.ToLower().Contains(s)) ||
                (p.Description != null && p.Description.ToLower().Contains(s)));
        }

        if (minPrice.HasValue)
        {
            query = query.Where(p => p.Price >= minPrice.Value);
        }

        if (maxPrice.HasValue)
        {
            query = query.Where(p => p.Price <= maxPrice.Value);
        }

        if (inStockOnly)
        {
            query = query.Where(p => p.StockQuantity > 0);
        }

        var products = await query.ToListAsync();

        // 2. Dynamic Hardware Facets filtering (evaluated in C# on JSON specifications string)
        if (!string.IsNullOrWhiteSpace(socket))
        {
            var sock = socket.Trim().ToLower();
            products = products.Where(p =>
                (p.Socket != null && p.Socket.ToLower() == sock) ||
                (p.Specifications != null && p.Specifications.ToLower().Contains(sock))).ToList();
        }

        if (!string.IsNullOrWhiteSpace(chipset))
        {
            var chip = chipset.Trim().ToLower();
            products = products.Where(p =>
                (p.Specifications != null && p.Specifications.ToLower().Contains(chip)) ||
                p.Name.ToLower().Contains(chip) ||
                (p.Model != null && p.Model.ToLower().Contains(chip))).ToList();
        }

        if (!string.IsNullOrWhiteSpace(memoryType))
        {
            var mem = memoryType.Trim().ToLower();
            products = products.Where(p =>
                (p.MemoryType != null && p.MemoryType.ToLower() == mem) ||
                (p.Specifications != null && p.Specifications.ToLower().Contains(mem)) ||
                p.Name.ToLower().Contains(mem)).ToList();
        }

        if (!string.IsNullOrWhiteSpace(speed))
        {
            var spd = speed.Trim().ToLower();
            products = products.Where(p =>
                (p.Specifications != null && p.Specifications.ToLower().Contains(spd)) ||
                p.Name.ToLower().Contains(spd)).ToList();
        }

        if (!string.IsNullOrWhiteSpace(capacity))
        {
            var cap = capacity.Trim().ToLower();
            products = products.Where(p =>
                (p.Specifications != null && p.Specifications.ToLower().Contains(cap)) ||
                p.Name.ToLower().Contains(cap)).ToList();
        }

        if (!string.IsNullOrWhiteSpace(vram))
        {
            var vr = vram.Trim().ToLower();
            products = products.Where(p =>
                (p.Specifications != null && p.Specifications.ToLower().Contains(vr)) ||
                p.Name.ToLower().Contains(vr)).ToList();
        }

        if (!string.IsNullOrWhiteSpace(efficiency))
        {
            var eff = efficiency.Trim().ToLower();
            products = products.Where(p =>
                (p.Specifications != null && p.Specifications.ToLower().Contains(eff)) ||
                p.Name.ToLower().Contains(eff)).ToList();
        }

        // Dynamic Filtering for any additional query parameters (e.g. cuda_cores, wattage, etc.)
        var standardParams = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "categoryid", "brand", "search", "minprice", "maxprice", "instockonly", "sortby",
            "socket", "chipset", "memorytype", "speed", "capacity", "vram", "efficiency", "status"
        };

        foreach (var queryParam in Request.Query)
        {
            if (standardParams.Contains(queryParam.Key)) continue;

            var filterKey = queryParam.Key.Trim().ToLower().Replace(" ", "_");
            var filterVal = queryParam.Value.ToString().Trim().ToLower();
            if (string.IsNullOrWhiteSpace(filterVal)) continue;

            products = products.Where(p =>
            {
                // Check direct matching columns
                if (filterKey == "form_factor" && p.FormFactor != null && p.FormFactor.ToLower() == filterVal)
                    return true;
                if (filterKey == "power_wattage" && p.PowerWattage.HasValue && p.PowerWattage.Value.ToString() == filterVal)
                    return true;

                // Check JSON specifications
                if (!string.IsNullOrWhiteSpace(p.Specifications))
                {
                    try
                    {
                        using var doc = JsonDocument.Parse(p.Specifications);
                        foreach (var prop in doc.RootElement.EnumerateObject())
                        {
                            var normName = prop.Name.Trim().ToLower().Replace(" ", "_");
                            if (normName == filterKey)
                            {
                                var valStr = prop.Value.ToString().Trim().ToLower();
                                if (valStr.Contains(filterVal) || filterVal.Contains(valStr))
                                {
                                    return true;
                                }
                            }
                        }
                    }
                    catch
                    {
                        if (p.Specifications.ToLower().Contains(filterVal))
                            return true;
                    }
                }

                if (p.Model != null && p.Model.ToLower().Contains(filterVal)) return true;
                if (p.Description != null && p.Description.ToLower().Contains(filterVal)) return true;

                return false;
            }).ToList();
        }

        // 3. Sorting
        var ordered = sortBy switch
        {
            "price_asc" => products.OrderBy(p => p.Price),
            "price_desc" => products.OrderByDescending(p => p.Price),
            "name_desc" => products.OrderByDescending(p => p.Name),
            "stock_desc" => products.OrderByDescending(p => p.StockQuantity),
            _ => products.OrderBy(p => p.Name)
        };

        var result = ordered.Select(p => new ProductDto
        {
            ProductId = p.ProductId,
            CategoryId = p.CategoryId,
            CategoryName = p.Category?.Name ?? "General",
            Name = p.Name,
            Brand = p.Brand,
            Model = p.Model,
            Price = p.Price,
            StockQuantity = p.StockQuantity,
            ImageUrl = p.ImageUrl,
            Description = p.Description,
            WarrantyMonths = p.WarrantyMonths,
            Status = p.Status ?? "Active",
            Specifications = ParseJsonSpecifications(p.Specifications),
            Socket = p.Socket,
            MemoryType = p.MemoryType,
            PowerWattage = p.PowerWattage,
            FormFactor = p.FormFactor
        }).ToList();

        return Ok(result);
    }

    /// <summary>
    /// Retrieve a single product by ID.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ProductDto>> GetProductById(int id)
    {
        var product = await _context.Products
            .AsNoTracking()
            .Include(p => p.Category)
            .FirstOrDefaultAsync(p => p.ProductId == id);

        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} not found." });
        }

        return Ok(new ProductDto
        {
            ProductId = product.ProductId,
            CategoryId = product.CategoryId,
            CategoryName = product.Category?.Name ?? "General",
            Name = product.Name,
            Brand = product.Brand,
            Model = product.Model,
            Price = product.Price,
            StockQuantity = product.StockQuantity,
            ImageUrl = product.ImageUrl,
            Description = product.Description,
            WarrantyMonths = product.WarrantyMonths,
            Status = product.Status ?? "Active",
            Specifications = ParseJsonSpecifications(product.Specifications),
            Socket = product.Socket,
            MemoryType = product.MemoryType,
            PowerWattage = product.PowerWattage,
            FormFactor = product.FormFactor
        });
    }

    /// <summary>
    /// Update stock quantity for a product (Option B: Inventory Management).
    /// Supports setting absolute stock or applying a relative delta.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPatch("{id:int}/stock")]
    public async Task<ActionResult> UpdateStock(int id, [FromBody] UpdateStockDto dto)
    {
        var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductId == id);
        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} not found." });
        }

        int newStock = product.StockQuantity;
        if (dto.StockQuantity.HasValue)
        {
            newStock = dto.StockQuantity.Value;
        }
        else if (dto.Delta.HasValue)
        {
            newStock += dto.Delta.Value;
        }
        else
        {
            return BadRequest(new { message = "Either StockQuantity or Delta must be provided." });
        }

        if (newStock < 0)
        {
            return BadRequest(new { message = "Stock quantity cannot be negative." });
        }

        int previousStock = product.StockQuantity;
        product.StockQuantity = newStock;
        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Stock updated for Product #{ProductId} ({Name}): {Prev} -> {New}. Reason: {Reason}",
            product.ProductId, product.Name, previousStock, newStock, dto.Reason ?? "Not specified");

        return Ok(new
        {
            productId = product.ProductId,
            name = product.Name,
            stockQuantity = product.StockQuantity,
            previousStock = previousStock,
            reason = dto.Reason,
            updatedAt = product.UpdatedAt,
            message = $"Stock updated successfully to {product.StockQuantity} units."
        });
    }

    /// <summary>
    /// Create a new product component (Option B: Product Management).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost]
    public async Task<ActionResult<ProductDto>> CreateProduct([FromBody] CreateProductDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var category = await _context.Categories.FirstOrDefaultAsync(c => c.CategoryId == dto.CategoryId);
        if (category == null)
        {
            return BadRequest(new { message = $"Category with ID {dto.CategoryId} does not exist." });
        }

        if (!IsValidImageUrl(dto.ImageUrl, out var imageError))
        {
            return BadRequest(new { message = imageError });
        }

        var product = new Product
        {
            CategoryId = dto.CategoryId,
            Name = dto.Name.Trim(),
            Brand = dto.Brand.Trim(),
            Model = string.IsNullOrWhiteSpace(dto.Model) ? null : dto.Model.Trim(),
            Price = dto.Price,
            StockQuantity = dto.StockQuantity,
            ImageUrl = string.IsNullOrWhiteSpace(dto.ImageUrl) ? null : dto.ImageUrl.Trim(),
            Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim(),
            WarrantyMonths = dto.WarrantyMonths > 0 ? dto.WarrantyMonths : 36,
            Status = string.IsNullOrWhiteSpace(dto.Status) ? "Active" : dto.Status.Trim(),
            Specifications = string.IsNullOrWhiteSpace(dto.Specifications) ? null : dto.Specifications.Trim(),
            Socket = string.IsNullOrWhiteSpace(dto.Socket) ? null : dto.Socket.Trim(),
            MemoryType = string.IsNullOrWhiteSpace(dto.MemoryType) ? null : dto.MemoryType.Trim(),
            PowerWattage = dto.PowerWattage,
            FormFactor = string.IsNullOrWhiteSpace(dto.FormFactor) ? null : dto.FormFactor.Trim(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Products.Add(product);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Created new Product #{ProductId}: {Name}", product.ProductId, product.Name);

        var resultDto = new ProductDto
        {
            ProductId = product.ProductId,
            CategoryId = product.CategoryId,
            CategoryName = category.Name,
            Name = product.Name,
            Brand = product.Brand,
            Model = product.Model,
            Price = product.Price,
            StockQuantity = product.StockQuantity,
            ImageUrl = product.ImageUrl,
            Description = product.Description,
            WarrantyMonths = product.WarrantyMonths,
            Status = product.Status,
            Specifications = ParseJsonSpecifications(product.Specifications),
            Socket = product.Socket,
            MemoryType = product.MemoryType,
            PowerWattage = product.PowerWattage,
            FormFactor = product.FormFactor
        };

        return CreatedAtAction(nameof(GetProductById), new { id = product.ProductId }, resultDto);
    }

    /// <summary>
    /// Update existing product details (Option B: Product Management).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<ProductDto>> UpdateProduct(int id, [FromBody] UpdateProductDto dto)
    {
        var product = await _context.Products
            .Include(p => p.Category)
            .FirstOrDefaultAsync(p => p.ProductId == id);

        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} not found." });
        }

        if (dto.CategoryId.HasValue && dto.CategoryId.Value != product.CategoryId)
        {
            var categoryExists = await _context.Categories.AnyAsync(c => c.CategoryId == dto.CategoryId.Value);
            if (!categoryExists)
            {
                return BadRequest(new { message = $"Category with ID {dto.CategoryId.Value} does not exist." });
            }
            product.CategoryId = dto.CategoryId.Value;
        }

        if (!string.IsNullOrWhiteSpace(dto.Name)) product.Name = dto.Name.Trim();
        if (!string.IsNullOrWhiteSpace(dto.Brand)) product.Brand = dto.Brand.Trim();
        if (dto.Model != null) product.Model = string.IsNullOrWhiteSpace(dto.Model) ? null : dto.Model.Trim();
        if (dto.Price.HasValue) product.Price = dto.Price.Value;
        if (dto.StockQuantity.HasValue && dto.StockQuantity.Value >= 0) product.StockQuantity = dto.StockQuantity.Value;
        if (dto.WarrantyMonths.HasValue && dto.WarrantyMonths.Value > 0) product.WarrantyMonths = dto.WarrantyMonths.Value;
        if (!string.IsNullOrWhiteSpace(dto.Status)) product.Status = dto.Status.Trim();
        if (dto.ImageUrl != null)
        {
            if (!IsValidImageUrl(dto.ImageUrl, out var updateImageError))
            {
                return BadRequest(new { message = updateImageError });
            }
            product.ImageUrl = string.IsNullOrWhiteSpace(dto.ImageUrl) ? null : dto.ImageUrl.Trim();
        }
        if (dto.Description != null) product.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();
        if (dto.Specifications != null) product.Specifications = string.IsNullOrWhiteSpace(dto.Specifications) ? null : dto.Specifications.Trim();
        if (dto.Socket != null) product.Socket = string.IsNullOrWhiteSpace(dto.Socket) ? null : dto.Socket.Trim();
        if (dto.MemoryType != null) product.MemoryType = string.IsNullOrWhiteSpace(dto.MemoryType) ? null : dto.MemoryType.Trim();
        if (dto.PowerWattage.HasValue) product.PowerWattage = dto.PowerWattage.Value;
        if (dto.FormFactor != null) product.FormFactor = string.IsNullOrWhiteSpace(dto.FormFactor) ? null : dto.FormFactor.Trim();

        product.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        // Reload category navigation property if changed
        await _context.Entry(product).Reference(p => p.Category).LoadAsync();

        return Ok(new ProductDto
        {
            ProductId = product.ProductId,
            CategoryId = product.CategoryId,
            CategoryName = product.Category?.Name ?? "General",
            Name = product.Name,
            Brand = product.Brand,
            Model = product.Model,
            Price = product.Price,
            StockQuantity = product.StockQuantity,
            ImageUrl = product.ImageUrl,
            Description = product.Description,
            WarrantyMonths = product.WarrantyMonths,
            Status = product.Status ?? "Active",
            Specifications = ParseJsonSpecifications(product.Specifications),
            Socket = product.Socket,
            MemoryType = product.MemoryType,
            PowerWattage = product.PowerWattage,
            FormFactor = product.FormFactor
        });
    }

    /// <summary>
    /// Toggle or update product active/inactive status (Option B: Product Management).
    /// Supports PATCH /api/products/{id}/status and PATCH /api/products/{id}/toggle-status.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPatch("{id:int}/status")]
    [HttpPatch("{id:int}/toggle-status")]
    public async Task<ActionResult<ProductDto>> ToggleProductStatus(int id, [FromBody] UpdateProductStatusDto? dto = null)
    {
        var product = await _context.Products
            .Include(p => p.Category)
            .FirstOrDefaultAsync(p => p.ProductId == id);

        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} not found." });
        }

        if (dto != null && !string.IsNullOrWhiteSpace(dto.Status))
        {
            product.Status = dto.Status.Trim();
        }
        else
        {
            product.Status = string.Equals(product.Status, "Active", StringComparison.OrdinalIgnoreCase)
                ? "Inactive"
                : "Active";
        }

        product.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        _logger.LogInformation("Product #{ProductId} ({Name}) status updated to '{Status}' by staff/admin.",
            product.ProductId, product.Name, product.Status);

        return Ok(new ProductDto
        {
            ProductId = product.ProductId,
            CategoryId = product.CategoryId,
            CategoryName = product.Category?.Name ?? "General",
            Name = product.Name,
            Brand = product.Brand,
            Model = product.Model,
            Price = product.Price,
            StockQuantity = product.StockQuantity,
            ImageUrl = product.ImageUrl,
            Description = product.Description,
            WarrantyMonths = product.WarrantyMonths,
            Status = product.Status ?? "Active",
            Specifications = ParseJsonSpecifications(product.Specifications),
            Socket = product.Socket,
            MemoryType = product.MemoryType,
            PowerWattage = product.PowerWattage,
            FormFactor = product.FormFactor
        });
    }

    /// <summary>
    /// Delete a product component from the database.
    /// Safely checks for references in existing orders or custom builds.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("{id:int}")]
    public async Task<ActionResult> DeleteProduct(int id)
    {
        var product = await _context.Products.FirstOrDefaultAsync(p => p.ProductId == id);
        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} not found." });
        }

        // Check if product is referenced in any existing order items
        var hasOrders = await _context.OrderItems.AnyAsync(oi => oi.ProductId == id);
        if (hasOrders)
        {
            return BadRequest(new { message = $"Cannot delete product '{product.Name}' because it is associated with existing customer orders. Consider updating stock to 0 instead." });
        }

        // Check if product is referenced in custom builds
        var hasBuilds = await _context.CustomBuildItems.AnyAsync(cbi => cbi.ProductId == id);
        if (hasBuilds)
        {
            return BadRequest(new { message = $"Cannot delete product '{product.Name}' because it is included in existing custom builds." });
        }

        _context.Products.Remove(product);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Product #{ProductId} ({Name}) was deleted by staff/admin.", id, product.Name);

        return Ok(new { message = $"Product '{product.Name}' deleted successfully." });
    }

    private static bool IsValidImageUrl(string? url, out string? errorMessage)
    {
        errorMessage = null;
        if (string.IsNullOrWhiteSpace(url)) return true;

        var trimmed = url.Trim();
        if (trimmed.StartsWith("blob:", StringComparison.OrdinalIgnoreCase))
        {
            errorMessage = "Temporary browser blob URLs cannot be stored as product images. Product images must be uploaded to Cloudinary.";
            return false;
        }

        if (trimmed.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
        {
            errorMessage = "Base64 data URLs cannot be stored as product images. Please upload the image file to Cloudinary.";
            return false;
        }

        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uriResult) ||
            (uriResult.Scheme != Uri.UriSchemeHttp && uriResult.Scheme != Uri.UriSchemeHttps))
        {
            errorMessage = "ImageUrl must be a valid HTTP or HTTPS URL (e.g. from Cloudinary CDN).";
            return false;
        }

        return true;
    }

    private static object? ParseJsonSpecifications(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return null;
        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, object>>(json);
        }
        catch
        {
            return json;
        }
    }
}
