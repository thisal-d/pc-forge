using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<CategoriesController> _logger;

    public CategoriesController(AppDbContext context, ILogger<CategoriesController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Retrieve all product categories with filter and product counts.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<CategoryDto>>> GetCategories()
    {
        var categories = await _context.Categories
            .AsNoTracking()
            .OrderBy(c => c.CategoryId)
            .Select(c => new CategoryDto
            {
                CategoryId = c.CategoryId,
                Name = c.Name,
                Description = c.Description,
                CreatedAt = c.CreatedAt,
                FilterCount = c.Filters.Count(),
                ProductCount = c.Products.Count(),
                Status = "Active"
            })
            .ToListAsync();

        return Ok(categories);
    }

    /// <summary>
    /// Retrieve single category by ID.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<CategoryDto>> GetCategoryById(int id)
    {
        var category = await _context.Categories
            .AsNoTracking()
            .Where(c => c.CategoryId == id)
            .Select(c => new CategoryDto
            {
                CategoryId = c.CategoryId,
                Name = c.Name,
                Description = c.Description,
                CreatedAt = c.CreatedAt,
                FilterCount = c.Filters.Count(),
                ProductCount = c.Products.Count(),
                Status = "Active"
            })
            .FirstOrDefaultAsync();

        if (category == null)
        {
            return NotFound(new { message = $"Category with ID {id} not found." });
        }

        return Ok(category);
    }

    /// <summary>
    /// Create a new category in the PostgreSQL categories table.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost]
    public async Task<ActionResult<CategoryDto>> CreateCategory([FromBody] CreateCategoryDto dto)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(dto.Name))
            {
                return BadRequest(new { message = "Category name is required." });
            }

            var cleanName = dto.Name.Trim();
            var nameExists = await _context.Categories
                .AnyAsync(c => c.Name.ToLower() == cleanName.ToLower());

            if (nameExists)
            {
                return BadRequest(new { message = $"Category with name '{cleanName}' already exists." });
            }

            var category = new Category
            {
                Name = cleanName,
                Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim(),
                CreatedAt = DateTime.UtcNow
            };

            _context.Categories.Add(category);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Staff/Admin created new category: {Name} (ID: {Id})", category.Name, category.CategoryId);

            var resultDto = new CategoryDto
            {
                CategoryId = category.CategoryId,
                Name = category.Name,
                Description = category.Description,
                CreatedAt = category.CreatedAt,
                FilterCount = 0,
                ProductCount = 0,
                Status = dto.Status ?? "Active"
            };

            try
            {
                return CreatedAtAction(nameof(GetCategoryById), new { id = category.CategoryId }, resultDto);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "CreatedAtAction route resolution fallback used for category ID: {Id}", category.CategoryId);
                return StatusCode(StatusCodes.Status201Created, resultDto);
            }
        }
        catch (DbUpdateException dbEx)
        {
            _logger.LogError(dbEx, "Database error creating category: {Message}", dbEx.InnerException?.Message ?? dbEx.Message);
            return StatusCode(500, new { message = "Database error while saving category. " + (dbEx.InnerException?.Message ?? dbEx.Message) });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error creating category: {Message}", ex.Message);
            return StatusCode(500, new { message = "Failed to create category: " + ex.Message });
        }
    }

    /// <summary>
    /// Update existing category details in the PostgreSQL categories table.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<CategoryDto>> UpdateCategory(int id, [FromBody] UpdateCategoryDto dto)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(dto.Name))
            {
                return BadRequest(new { message = "Category name is required." });
            }

            var category = await _context.Categories
                .Include(c => c.Filters)
                .Include(c => c.Products)
                .FirstOrDefaultAsync(c => c.CategoryId == id);

            if (category == null)
            {
                return NotFound(new { message = $"Category with ID {id} not found." });
            }

            var cleanName = dto.Name.Trim();
            var nameExists = await _context.Categories
                .AnyAsync(c => c.CategoryId != id && c.Name.ToLower() == cleanName.ToLower());

            if (nameExists)
            {
                return BadRequest(new { message = $"Another category with name '{cleanName}' already exists." });
            }

            category.Name = cleanName;
            category.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();

            await _context.SaveChangesAsync();

            _logger.LogInformation("Staff/Admin updated category ID {Id}: {Name}", id, category.Name);

            return Ok(new CategoryDto
            {
                CategoryId = category.CategoryId,
                Name = category.Name,
                Description = category.Description,
                CreatedAt = category.CreatedAt,
                FilterCount = category.Filters.Count,
                ProductCount = category.Products.Count,
                Status = dto.Status ?? "Active"
            });
        }
        catch (DbUpdateException dbEx)
        {
            _logger.LogError(dbEx, "Database error updating category ID {Id}: {Message}", id, dbEx.InnerException?.Message ?? dbEx.Message);
            return StatusCode(500, new { message = "Database error while updating category: " + (dbEx.InnerException?.Message ?? dbEx.Message) });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error updating category ID {Id}: {Message}", id, ex.Message);
            return StatusCode(500, new { message = "Failed to update category: " + ex.Message });
        }
    }

    /// <summary>
    /// Delete category from the PostgreSQL categories table (safely checks product bindings).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("{id:int}")]
    public async Task<ActionResult> DeleteCategory(int id)
    {
        try
        {
            var category = await _context.Categories
                .Include(c => c.Products)
                .FirstOrDefaultAsync(c => c.CategoryId == id);

            if (category == null)
            {
                return NotFound(new { message = $"Category with ID {id} not found." });
            }

            if (category.Products.Any())
            {
                return BadRequest(new { message = $"Cannot delete category '{category.Name}' because it currently has {category.Products.Count} product(s) associated with it. Please reassign or remove the products first." });
            }

            _context.Categories.Remove(category);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Staff/Admin deleted category ID {Id}: {Name}", id, category.Name);

            return Ok(new { message = $"Category '{category.Name}' deleted successfully." });
        }
        catch (DbUpdateException dbEx)
        {
            _logger.LogError(dbEx, "Database error deleting category ID {Id}: {Message}", id, dbEx.InnerException?.Message ?? dbEx.Message);
            return StatusCode(500, new { message = "Database error while deleting category: " + (dbEx.InnerException?.Message ?? dbEx.Message) });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error deleting category ID {Id}: {Message}", id, ex.Message);
            return StatusCode(500, new { message = "Failed to delete category: " + ex.Message });
        }
    }

    /// <summary>
    /// Retrieve dynamic filters for a specific category.
    /// </summary>
    [HttpGet("{categoryId:int}/filters")]
    public async Task<ActionResult<List<CategoryFilterDto>>> GetCategoryFilters(int categoryId, [FromQuery] bool onlyFilterable = false)
    {
        var category = await _context.Categories
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.CategoryId == categoryId);

        if (category == null)
        {
            return NotFound(new { message = $"Category with ID {categoryId} not found." });
        }

        var query = _context.CategoryFilters
            .AsNoTracking()
            .Where(cf => cf.CategoryId == categoryId);

        if (onlyFilterable)
        {
            query = query.Where(cf => cf.IsFilterable);
        }

        var filters = await query
            .OrderBy(cf => cf.DisplayOrder)
            .Include(cf => cf.Options.OrderBy(fo => fo.DisplayOrder))
            .Select(cf => new CategoryFilterDto
            {
                FilterId = cf.FilterId,
                CategoryId = cf.CategoryId,
                CategoryName = category.Name,
                FilterKey = cf.FilterKey,
                DisplayName = cf.DisplayName,
                FilterType = cf.FilterType,
                Unit = cf.Unit,
                DisplayOrder = cf.DisplayOrder,
                IsFilterable = cf.IsFilterable,
                Options = cf.Options.Select(fo => new FilterOptionDto
                {
                    OptionId = fo.OptionId,
                    Value = fo.OptionValue,
                    DisplayOrder = fo.DisplayOrder
                }).ToList()
            })
            .ToListAsync();

        return Ok(filters);
    }

    /// <summary>
    /// Assign an existing or new filter to a category.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost("{categoryId:int}/filters")]
    public async Task<ActionResult<CategoryFilterDto>> AddCategoryFilter(int categoryId, [FromBody] CreateCategoryFilterDto dto)
    {
        var category = await _context.Categories.FindAsync(categoryId);
        if (category == null)
        {
            return NotFound(new { message = $"Category with ID {categoryId} not found." });
        }

        if (string.IsNullOrWhiteSpace(dto.FilterKey) || string.IsNullOrWhiteSpace(dto.DisplayName))
        {
            return BadRequest(new { message = "Filter key and display name are required." });
        }

        var cleanKey = dto.FilterKey.Trim().ToLower().Replace(" ", "_");
        var cleanName = dto.DisplayName.Trim();

        var exists = await _context.CategoryFilters
            .AnyAsync(cf => cf.CategoryId == categoryId && cf.FilterKey.ToLower() == cleanKey);

        if (exists)
        {
            return BadRequest(new { message = $"Filter '{cleanName}' ({cleanKey}) is already assigned to category '{category.Name}'." });
        }

        var maxOrder = await _context.CategoryFilters
            .Where(cf => cf.CategoryId == categoryId)
            .MaxAsync(cf => (int?)cf.DisplayOrder) ?? 0;

        var filter = new CategoryFilter
        {
            CategoryId = categoryId,
            FilterKey = cleanKey,
            DisplayName = cleanName,
            FilterType = string.IsNullOrWhiteSpace(dto.FilterType) ? "multiselect" : dto.FilterType.Trim(),
            Unit = string.IsNullOrWhiteSpace(dto.Unit) ? null : dto.Unit.Trim(),
            DisplayOrder = dto.DisplayOrder ?? (maxOrder + 1),
            IsFilterable = dto.IsFilterable,
            CreatedAt = DateTime.UtcNow
        };

        _context.CategoryFilters.Add(filter);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Assigned filter {Key} to category {CatId}", cleanKey, categoryId);

        return Ok(new CategoryFilterDto
        {
            FilterId = filter.FilterId,
            CategoryId = filter.CategoryId,
            CategoryName = category.Name,
            FilterKey = filter.FilterKey,
            DisplayName = filter.DisplayName,
            FilterType = filter.FilterType,
            Unit = filter.Unit,
            DisplayOrder = filter.DisplayOrder,
            IsFilterable = filter.IsFilterable,
            Options = new List<FilterOptionDto>()
        });
    }

    /// <summary>
    /// Remove a filter from a category.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("{categoryId:int}/filters/{filterId:int}")]
    public async Task<ActionResult> RemoveCategoryFilter(int categoryId, int filterId)
    {
        var filter = await _context.CategoryFilters
            .FirstOrDefaultAsync(cf => cf.FilterId == filterId && cf.CategoryId == categoryId);

        if (filter == null)
        {
            return NotFound(new { message = $"Filter ID {filterId} not found in category {categoryId}." });
        }

        _context.CategoryFilters.Remove(filter);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Removed filter {FilterId} from category {CatId}", filterId, categoryId);

        return Ok(new { message = $"Filter '{filter.DisplayName}' removed from category." });
    }

    /// <summary>
    /// Update a category filter (e.g. toggle isFilterable or display name).
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{categoryId:int}/filters/{filterId:int}")]
    public async Task<ActionResult<CategoryFilterDto>> UpdateCategoryFilter(int categoryId, int filterId, [FromBody] UpdateCategoryFilterDto dto)
    {
        var filter = await _context.CategoryFilters
            .Include(cf => cf.Category)
            .FirstOrDefaultAsync(cf => cf.FilterId == filterId && cf.CategoryId == categoryId);

        if (filter == null)
        {
            return NotFound(new { message = $"Filter ID {filterId} not found in category {categoryId}." });
        }

        if (!string.IsNullOrWhiteSpace(dto.DisplayName))
        {
            filter.DisplayName = dto.DisplayName.Trim();
        }

        if (dto.DisplayOrder.HasValue)
        {
            filter.DisplayOrder = dto.DisplayOrder.Value;
        }

        if (dto.IsFilterable.HasValue)
        {
            filter.IsFilterable = dto.IsFilterable.Value;
        }

        await _context.SaveChangesAsync();

        return Ok(new CategoryFilterDto
        {
            FilterId = filter.FilterId,
            CategoryId = filter.CategoryId,
            CategoryName = filter.Category?.Name ?? string.Empty,
            FilterKey = filter.FilterKey,
            DisplayName = filter.DisplayName,
            FilterType = filter.FilterType,
            Unit = filter.Unit,
            DisplayOrder = filter.DisplayOrder,
            IsFilterable = filter.IsFilterable
        });
    }

    /// <summary>
    /// Reorder category filters.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{categoryId:int}/filters/reorder")]
    public async Task<ActionResult> ReorderCategoryFilters(int categoryId, [FromBody] ReorderCategoryFiltersDto dto)
    {
        if (dto.Order == null || !dto.Order.Any())
        {
            return BadRequest(new { message = "Order list cannot be empty." });
        }

        var filters = await _context.CategoryFilters
            .Where(cf => cf.CategoryId == categoryId)
            .ToListAsync();

        foreach (var item in dto.Order)
        {
            var target = filters.FirstOrDefault(f => f.FilterId == item.FilterId);
            if (target != null)
            {
                target.DisplayOrder = item.DisplayOrder;
            }
        }

        await _context.SaveChangesAsync();

        return Ok(new { message = "Filters reordered successfully." });
    }
}
