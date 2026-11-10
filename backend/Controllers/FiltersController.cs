using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FiltersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<FiltersController> _logger;

    public FiltersController(AppDbContext context, ILogger<FiltersController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Retrieve all master filters and their options.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<MasterFilterDto>>> GetFilters()
    {
        var filters = await _context.Filters
            .AsNoTracking()
            .Include(f => f.Options)
            .OrderBy(f => f.DisplayName)
            .ToListAsync();

        // Get category assignments map
        var categoryAssignments = await _context.CategoryFilters
            .AsNoTracking()
            .Include(cf => cf.Category)
            .ToListAsync();

        var result = filters.Select(f =>
        {
            var matchedCategories = categoryAssignments
                .Where(cf => (cf.MasterFilterId == f.FilterId) || cf.FilterKey.Equals(f.FilterKey, StringComparison.OrdinalIgnoreCase))
                .Select(cf => cf.Category?.Name ?? "Unknown")
                .Distinct()
                .OrderBy(name => name)
                .ToList();

            return new MasterFilterDto
            {
                FilterId = f.FilterId,
                FilterKey = f.FilterKey,
                DisplayName = f.DisplayName,
                FilterType = f.FilterType,
                Unit = f.Unit,
                CreatedAt = f.CreatedAt,
                UpdatedAt = f.UpdatedAt,
                AssignedCategoriesCount = matchedCategories.Count,
                AssignedCategoryNames = matchedCategories,
                Options = f.Options
                    .OrderBy(o => o.DisplayOrder)
                    .Select(o => new FilterOptionDto
                    {
                        OptionId = o.OptionId,
                        Value = o.OptionValue,
                        DisplayOrder = o.DisplayOrder
                    })
                    .ToList()
            };
        }).ToList();

        return Ok(result);
    }

    /// <summary>
    /// Retrieve a single master filter by ID.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<MasterFilterDto>> GetFilterById(int id)
    {
        var filter = await _context.Filters
            .AsNoTracking()
            .Include(f => f.Options)
            .FirstOrDefaultAsync(f => f.FilterId == id);

        if (filter == null)
        {
            return NotFound(new { message = $"Filter with ID {id} not found." });
        }

        var matchedCategories = await _context.CategoryFilters
            .AsNoTracking()
            .Where(cf => cf.MasterFilterId == id || cf.FilterKey.ToLower() == filter.FilterKey.ToLower())
            .Include(cf => cf.Category)
            .Select(cf => cf.Category != null ? cf.Category.Name : "Unknown")
            .Distinct()
            .ToListAsync();

        return Ok(new MasterFilterDto
        {
            FilterId = filter.FilterId,
            FilterKey = filter.FilterKey,
            DisplayName = filter.DisplayName,
            FilterType = filter.FilterType,
            Unit = filter.Unit,
            CreatedAt = filter.CreatedAt,
            UpdatedAt = filter.UpdatedAt,
            AssignedCategoriesCount = matchedCategories.Count,
            AssignedCategoryNames = matchedCategories,
            Options = filter.Options
                .OrderBy(o => o.DisplayOrder)
                .Select(o => new FilterOptionDto
                {
                    OptionId = o.OptionId,
                    Value = o.OptionValue,
                    DisplayOrder = o.DisplayOrder
                })
                .ToList()
        });
    }

    /// <summary>
    /// Create a new master filter in the database.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPost]
    public async Task<ActionResult<MasterFilterDto>> CreateFilter([FromBody] CreateMasterFilterDto dto)
    {
        if (string.IsNullOrWhiteSpace(dto.FilterKey) || string.IsNullOrWhiteSpace(dto.DisplayName))
        {
            return BadRequest(new { message = "Filter key and display name are required." });
        }

        var cleanKey = dto.FilterKey.Trim().ToLower().Replace(" ", "_");
        var cleanName = dto.DisplayName.Trim();

        var exists = await _context.Filters.AnyAsync(f => f.FilterKey.ToLower() == cleanKey);
        if (exists)
        {
            return BadRequest(new { message = $"Filter key '{cleanKey}' already exists in the database." });
        }

        var filter = new Filter
        {
            FilterKey = cleanKey,
            DisplayName = cleanName,
            FilterType = string.IsNullOrWhiteSpace(dto.FilterType) ? "multiselect" : dto.FilterType.Trim(),
            Unit = string.IsNullOrWhiteSpace(dto.Unit) ? null : dto.Unit.Trim(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        if (dto.Options != null && dto.Options.Any())
        {
            int order = 1;
            foreach (var opt in dto.Options.Where(o => !string.IsNullOrWhiteSpace(o)))
            {
                var trimmed = opt.Trim();
                if (!string.IsNullOrWhiteSpace(filter.Unit) && !trimmed.EndsWith(filter.Unit, StringComparison.OrdinalIgnoreCase) && double.TryParse(trimmed, out _))
                {
                    trimmed = $"{trimmed}{filter.Unit}";
                }

                if (!filter.Options.Any(o => o.OptionValue.Equals(trimmed, StringComparison.OrdinalIgnoreCase)))
                {
                    filter.Options.Add(new MasterFilterOption
                    {
                        OptionValue = trimmed,
                        DisplayOrder = order++
                    });
                }
            }
        }

        _context.Filters.Add(filter);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Master filter created: {Key} ({Name}) with {Count} options", filter.FilterKey, filter.DisplayName, filter.Options.Count);

        return CreatedAtAction(nameof(GetFilterById), new { id = filter.FilterId }, new MasterFilterDto
        {
            FilterId = filter.FilterId,
            FilterKey = filter.FilterKey,
            DisplayName = filter.DisplayName,
            FilterType = filter.FilterType,
            Unit = filter.Unit,
            CreatedAt = filter.CreatedAt,
            UpdatedAt = filter.UpdatedAt,
            AssignedCategoriesCount = 0,
            AssignedCategoryNames = new List<string>(),
            Options = filter.Options
                .OrderBy(o => o.DisplayOrder)
                .Select(o => new FilterOptionDto
                {
                    OptionId = o.OptionId,
                    Value = o.OptionValue,
                    DisplayOrder = o.DisplayOrder
                })
                .ToList()
        });
    }

    /// <summary>
    /// Update an existing master filter and its options.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<MasterFilterDto>> UpdateFilter(int id, [FromBody] UpdateMasterFilterDto dto)
    {
        var filter = await _context.Filters
            .Include(f => f.Options)
            .FirstOrDefaultAsync(f => f.FilterId == id);

        if (filter == null)
        {
            return NotFound(new { message = $"Filter with ID {id} not found." });
        }

        if (string.IsNullOrWhiteSpace(dto.DisplayName))
        {
            return BadRequest(new { message = "Display name is required." });
        }

        filter.DisplayName = dto.DisplayName.Trim();
        if (!string.IsNullOrWhiteSpace(dto.FilterType))
        {
            filter.FilterType = dto.FilterType.Trim();
        }
        filter.Unit = string.IsNullOrWhiteSpace(dto.Unit) ? null : dto.Unit.Trim();
        filter.UpdatedAt = DateTime.UtcNow;

        if (dto.Options != null)
        {
            // Update options
            _context.MasterFilterOptions.RemoveRange(filter.Options);
            filter.Options.Clear();

            int order = 1;
            foreach (var opt in dto.Options.Where(o => !string.IsNullOrWhiteSpace(o)))
            {
                var trimmed = opt.Trim();
                if (!string.IsNullOrWhiteSpace(filter.Unit) && !trimmed.EndsWith(filter.Unit, StringComparison.OrdinalIgnoreCase) && double.TryParse(trimmed, out _))
                {
                    trimmed = $"{trimmed}{filter.Unit}";
                }

                if (!filter.Options.Any(o => o.OptionValue.Equals(trimmed, StringComparison.OrdinalIgnoreCase)))
                {
                    filter.Options.Add(new MasterFilterOption
                    {
                        FilterId = filter.FilterId,
                        OptionValue = trimmed,
                        DisplayOrder = order++
                    });
                }
            }
        }

        // Keep assigned CategoryFilters in sync with updated display metadata and options
        var linkedCategoryFilters = await _context.CategoryFilters
            .Include(cf => cf.Options)
            .Where(cf => cf.MasterFilterId == id || cf.FilterKey.ToLower() == filter.FilterKey.ToLower())
            .ToListAsync();

        foreach (var cf in linkedCategoryFilters)
        {
            cf.DisplayName = filter.DisplayName;
            cf.FilterType = filter.FilterType;
            cf.Unit = filter.Unit;
            if (cf.MasterFilterId == null)
            {
                cf.MasterFilterId = filter.FilterId;
            }

            if (dto.Options != null)
            {
                _context.FilterOptions.RemoveRange(cf.Options);
                cf.Options.Clear();

                int catOptOrder = 1;
                foreach (var opt in filter.Options.OrderBy(o => o.DisplayOrder))
                {
                    cf.Options.Add(new FilterOption
                    {
                        FilterId = cf.FilterId,
                        OptionValue = opt.OptionValue,
                        DisplayOrder = catOptOrder++
                    });
                }
            }
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("Master filter {Id} ({Key}) updated", filter.FilterId, filter.FilterKey);

        var matchedCategories = linkedCategoryFilters
            .Select(cf => cf.Category?.Name ?? "Unknown")
            .Distinct()
            .ToList();

        return Ok(new MasterFilterDto
        {
            FilterId = filter.FilterId,
            FilterKey = filter.FilterKey,
            DisplayName = filter.DisplayName,
            FilterType = filter.FilterType,
            Unit = filter.Unit,
            CreatedAt = filter.CreatedAt,
            UpdatedAt = filter.UpdatedAt,
            AssignedCategoriesCount = matchedCategories.Count,
            AssignedCategoryNames = matchedCategories,
            Options = filter.Options
                .OrderBy(o => o.DisplayOrder)
                .Select(o => new FilterOptionDto
                {
                    OptionId = o.OptionId,
                    Value = o.OptionValue,
                    DisplayOrder = o.DisplayOrder
                })
                .ToList()
        });
    }

    /// <summary>
    /// Delete a master filter from the database.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpDelete("{id:int}")]
    public async Task<ActionResult> DeleteFilter(int id)
    {
        var filter = await _context.Filters
            .Include(f => f.Options)
            .FirstOrDefaultAsync(f => f.FilterId == id);

        if (filter == null)
        {
            return NotFound(new { message = $"Filter with ID {id} not found." });
        }

        // Check if filter is currently assigned to any categories
        var assignedCategories = await _context.CategoryFilters
            .Where(cf => cf.MasterFilterId == id || cf.FilterKey.ToLower() == filter.FilterKey.ToLower())
            .Include(cf => cf.Category)
            .ToListAsync();

        if (assignedCategories.Any())
        {
            var catNames = string.Join(", ", assignedCategories.Select(cf => cf.Category?.Name ?? "Category #" + cf.CategoryId).Distinct());
            return BadRequest(new
            {
                message = $"Cannot delete filter '{filter.DisplayName}' because it is currently assigned to {assignedCategories.Count} category/categories: {catNames}. Please remove this filter from all categories before deleting it from the database."
            });
        }

        _context.Filters.Remove(filter);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Master filter {Id} ({Key}) deleted", filter.FilterId, filter.FilterKey);
        return Ok(new { message = $"Filter '{filter.DisplayName}' was successfully deleted." });
    }
}
