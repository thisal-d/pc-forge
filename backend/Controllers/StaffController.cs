using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[Authorize(Policy = "StaffOnly")]
[ApiController]
[Route("api/[controller]")]
public class StaffController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<StaffController> _logger;

    public StaffController(AppDbContext context, ILogger<StaffController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Helper to parse staff ID from either pure integer (e.g. "1") or prefixed format (e.g. "STF-1").
    /// </summary>
    private static int? ParseId(string rawId)
    {
        if (string.IsNullOrWhiteSpace(rawId)) return null;
        var clean = rawId.Trim();
        if (clean.StartsWith("STF-", StringComparison.OrdinalIgnoreCase))
        {
            clean = clean[4..];
        }

        return int.TryParse(clean, out int parsed) ? parsed : null;
    }

    private static StaffResponseDto MapToDto(Staff staff)
    {
        var user = staff.User;
        return new StaffResponseDto
        {
            StaffId = staff.StaffId,
            UserId = staff.UserId,
            FirstName = user?.FirstName ?? "Staff",
            LastName = user?.LastName ?? "Member",
            Email = user?.Email ?? string.Empty,
            Phone = staff.Phone ?? string.Empty,
            Role = user?.Role?.RoleName ?? "Staff",
            Department = staff.Department,
            Specialization = staff.Specialization,
            Status = staff.Status,
            Notes = staff.Notes,
            JoinedDate = staff.JoinedDate.ToString("yyyy-MM-dd"),
            CreatedDate = staff.CreatedAt.ToString("yyyy-MM-dd"),
            LastLogin = "Never",
            CreatedAt = staff.CreatedAt,
            UpdatedAt = staff.UpdatedAt
        };
    }

    /// <summary>
    /// Get all staff members with joined User credentials & role details.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<StaffResponseDto>>> GetAllStaff()
    {
        var staffList = await _context.Staff
            .Include(s => s.User)
            .ThenInclude(u => u!.Role)
            .OrderBy(s => s.StaffId)
            .ToListAsync();

        var result = staffList.Select(MapToDto).ToList();
        return Ok(result);
    }

    /// <summary>
    /// Get a single staff member by ID (supports '1' or 'STF-1').
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<StaffResponseDto>> GetStaffById(string id)
    {
        var parsedId = ParseId(id);
        if (!parsedId.HasValue)
        {
            return BadRequest(new { message = $"Invalid staff ID format: {id}" });
        }

        var staff = await _context.Staff
            .Include(s => s.User)
            .ThenInclude(u => u!.Role)
            .FirstOrDefaultAsync(s => s.StaffId == parsedId.Value || s.UserId == parsedId.Value);

        if (staff == null)
        {
            return NotFound(new { message = $"Staff member with ID {id} not found." });
        }

        return Ok(MapToDto(staff));
    }

    /// <summary>
    /// Add a new technician staff account and profile.
    /// Inserts into both 'Users' and 'Staff' tables.
    /// </summary>
    [Authorize(Policy = "AdminOnly")]
    [HttpPost]
    public async Task<ActionResult<StaffResponseDto>> CreateStaff([FromBody] CreateStaffDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var normalizedEmail = dto.Email.Trim().ToLowerInvariant();

        // 1. Check if email already registered
        var existingUser = await _context.Users
            .Include(u => u.StaffProfile)
            .FirstOrDefaultAsync(u => u.Email.ToLower() == normalizedEmail);

        if (existingUser != null && existingUser.StaffProfile != null)
        {
            return BadRequest(new { message = $"A staff member with email '{dto.Email}' already exists." });
        }

        // 2. Resolve Staff role (RoleId 3, RoleName 'Staff')
        var staffRole = await _context.Roles.FirstOrDefaultAsync(r => r.RoleName == "Staff");
        var staffRoleId = staffRole?.RoleId ?? 3;

        // 3. Resolve or create user with Staff role
        User user;
        if (existingUser != null)
        {
            user = existingUser;
            user.RoleId = staffRoleId; // Ensure user is elevated from Customer to Staff
            user.FirstName = dto.FirstName.Trim();
            user.LastName = dto.LastName.Trim();
            user.IsActive = dto.Status.Equals("Active", StringComparison.OrdinalIgnoreCase);
            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
        else
        {
            var password = !string.IsNullOrWhiteSpace(dto.Password) ? dto.Password : "Staff123!";
            user = new User
            {
                Email = normalizedEmail,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
                RoleId = staffRoleId,
                FirstName = dto.FirstName.Trim(),
                LastName = dto.LastName.Trim(),
                IsActive = dto.Status.Equals("Active", StringComparison.OrdinalIgnoreCase),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            await _context.Users.AddAsync(user);
            await _context.SaveChangesAsync();
        }

        // 4. Create Staff profile
        var staff = new Staff
        {
            UserId = user.UserId,
            Department = dto.Department.Trim(),
            Phone = dto.Phone?.Trim() ?? "+94 77 000 0000",
            Specialization = dto.Specialization?.Trim() ?? dto.Notes?.Trim(),
            Status = string.IsNullOrWhiteSpace(dto.Status) ? "Active" : dto.Status.Trim(),
            Notes = dto.Notes?.Trim(),
            JoinedDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await _context.Staff.AddAsync(staff);
        await _context.SaveChangesAsync();

        // Reload with relationships
        staff.User = user;
        _logger.LogInformation("Successfully registered new staff member: {Email} (StaffId: {StaffId})", user.Email, staff.StaffId);

        return CreatedAtAction(nameof(GetStaffById), new { id = staff.StaffId }, MapToDto(staff));
    }

    /// <summary>
    /// Update existing staff profile and user details.
    /// </summary>
    [Authorize(Policy = "AdminOnly")]
    [HttpPut("{id}")]
    public async Task<ActionResult<StaffResponseDto>> UpdateStaff(string id, [FromBody] UpdateStaffDto dto)
    {
        var parsedId = ParseId(id);
        if (!parsedId.HasValue)
        {
            return BadRequest(new { message = $"Invalid staff ID format: {id}" });
        }

        var staff = await _context.Staff
            .Include(s => s.User)
            .ThenInclude(u => u!.Role)
            .FirstOrDefaultAsync(s => s.StaffId == parsedId.Value);

        if (staff == null)
        {
            return NotFound(new { message = $"Staff member with ID {id} not found." });
        }

        if (!string.IsNullOrWhiteSpace(dto.Department)) staff.Department = dto.Department.Trim();
        if (dto.Phone != null) staff.Phone = dto.Phone.Trim();
        if (dto.Specialization != null) staff.Specialization = dto.Specialization.Trim();
        if (!string.IsNullOrWhiteSpace(dto.Status)) staff.Status = dto.Status.Trim();
        if (dto.Notes != null) staff.Notes = dto.Notes.Trim();
        staff.UpdatedAt = DateTime.UtcNow;

        if (staff.User != null)
        {
            if (!string.IsNullOrWhiteSpace(dto.FirstName)) staff.User.FirstName = dto.FirstName.Trim();
            if (!string.IsNullOrWhiteSpace(dto.LastName)) staff.User.LastName = dto.LastName.Trim();
            if (!string.IsNullOrWhiteSpace(dto.Status))
            {
                staff.User.IsActive = staff.Status.Equals("Active", StringComparison.OrdinalIgnoreCase);
            }
            staff.User.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return Ok(MapToDto(staff));
    }

    /// <summary>
    /// Toggle staff status between Active and Inactive.
    /// </summary>
    [Authorize(Policy = "AdminOnly")]
    [HttpPatch("{id}/status")]
    public async Task<ActionResult<StaffResponseDto>> ToggleStatus(string id)
    {
        var parsedId = ParseId(id);
        if (!parsedId.HasValue)
        {
            return BadRequest(new { message = $"Invalid staff ID format: {id}" });
        }

        var staff = await _context.Staff
            .Include(s => s.User)
            .ThenInclude(u => u!.Role)
            .FirstOrDefaultAsync(s => s.StaffId == parsedId.Value);

        if (staff == null)
        {
            return NotFound(new { message = $"Staff member with ID {id} not found." });
        }

        staff.Status = staff.Status.Equals("Active", StringComparison.OrdinalIgnoreCase) ? "Inactive" : "Active";
        staff.UpdatedAt = DateTime.UtcNow;

        if (staff.User != null)
        {
            staff.User.IsActive = staff.Status.Equals("Active", StringComparison.OrdinalIgnoreCase);
            staff.User.UpdatedAt = DateTime.UtcNow;
        }

        await _context.SaveChangesAsync();
        return Ok(MapToDto(staff));
    }

    /// <summary>
    /// Reset technician staff password.
    /// </summary>
    [Authorize(Policy = "AdminOnly")]
    [HttpPost("{id}/reset-password")]
    public async Task<IActionResult> ResetPassword(string id, [FromBody] ResetStaffPasswordDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var parsedId = ParseId(id);
        if (!parsedId.HasValue)
        {
            return BadRequest(new { message = $"Invalid staff ID format: {id}" });
        }

        var staff = await _context.Staff
            .Include(s => s.User)
            .FirstOrDefaultAsync(s => s.StaffId == parsedId.Value);

        if (staff == null || staff.User == null)
        {
            return NotFound(new { message = $"Staff member with ID {id} not found." });
        }

        staff.User.PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.NewPassword);
        staff.User.UpdatedAt = DateTime.UtcNow;
        staff.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return Ok(new { message = "Staff member password was updated successfully." });
    }

    /// <summary>
    /// Delete a staff record.
    /// </summary>
    [Authorize(Policy = "AdminOnly")]
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteStaff(string id)
    {
        var parsedId = ParseId(id);
        if (!parsedId.HasValue)
        {
            return BadRequest(new { message = $"Invalid staff ID format: {id}" });
        }

        var staff = await _context.Staff
            .Include(s => s.User)
            .FirstOrDefaultAsync(s => s.StaffId == parsedId.Value);

        if (staff == null)
        {
            return NotFound(new { message = $"Staff member with ID {id} not found." });
        }

        _context.Staff.Remove(staff);
        if (staff.User != null)
        {
            staff.User.IsActive = false;
        }

        await _context.SaveChangesAsync();
        return NoContent();
    }
}
