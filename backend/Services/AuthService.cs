using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Services;

public class AuthService : IAuthService
{
    private readonly AppDbContext _context;
    private readonly IConfiguration _configuration;

    public AuthService(AppDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
    {
        // 1. Check if user already exists
        var normalizedEmail = dto.Email.Trim().ToLowerInvariant();
        if (await _context.Users.AnyAsync(u => u.Email.ToLower() == normalizedEmail))
        {
            return new AuthResponseDto
            {
                Success = false,
                Message = "A user with this email already exists."
            };
        }

        // 2. Resolve role - public registration is strictly Customer
        var role = await _context.Roles.FirstOrDefaultAsync(r => r.RoleName == "Customer");
        if (role == null)
        {
            return new AuthResponseDto
            {
                Success = false,
                Message = "Default Customer role could not be resolved."
            };
        }

        // 3. Hash password using BCrypt
        var passwordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password);

        // 4. Create and save User
        var user = new User
        {
            Email = normalizedEmail,
            PasswordHash = passwordHash,
            RoleId = role.RoleId,
            FirstName = dto.FirstName?.Trim(),
            LastName = dto.LastName?.Trim(),
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await _context.Users.AddAsync(user);
        await _context.SaveChangesAsync();

        // 5. Generate JWT token
        var token = GenerateJwtToken(user, role.RoleName);

        return new AuthResponseDto
        {
            Success = true,
            Message = "Registration successful.",
            Token = token,
            UserId = user.UserId,
            Email = user.Email,
            Role = role.RoleName,
            FirstName = user.FirstName,
            LastName = user.LastName
        };
    }
}
