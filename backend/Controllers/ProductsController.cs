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
        [FromQuery] string? efficiency = null)
    {
        // 1. Relational database query for core fields
        IQueryable<Product> query = _context.Products
            .AsNoTracking()
            .Include(p => p.Category);

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
            Specifications = ParseJsonSpecifications(product.Specifications),
            Socket = product.Socket,
            MemoryType = product.MemoryType,
            PowerWattage = product.PowerWattage,
            FormFactor = product.FormFactor
        });
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
