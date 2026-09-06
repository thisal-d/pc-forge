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

    public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
    {
        var normalizedEmail = dto.Email.Trim().ToLowerInvariant();

        // 1. Find user including Role navigation
        var user = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.Email.ToLower() == normalizedEmail);

        if (user == null || !user.IsActive)
        {
            return new AuthResponseDto
            {
                Success = false,
                Message = "Invalid email or password."
            };
        }

        // 2. Verify password with BCrypt
        bool isPasswordValid = BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash);
        if (!isPasswordValid)
        {
            return new AuthResponseDto
            {
                Success = false,
                Message = "Invalid email or password."
            };
        }

        // 3. Generate JWT token
        var roleName = user.Role?.RoleName ?? "Customer";
        var token = GenerateJwtToken(user, roleName);

        return new AuthResponseDto
        {
            Success = true,
            Message = "Login successful.",
            Token = token,
            UserId = user.UserId,
            Email = user.Email,
            Role = roleName,
            FirstName = user.FirstName,
            LastName = user.LastName
        };
    }

    private string GenerateJwtToken(User user, string roleName)
    {
        var jwtSettings = _configuration.GetSection("Jwt");
        var secretKey = jwtSettings["Key"] ?? "PCForgeSuperSecretKeyForJwtAuthentication2026!";
        var issuer = jwtSettings["Issuer"] ?? "PCForgeApi";
        var audience = jwtSettings["Audience"] ?? "PCForgeClients";

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, roleName),
            new("userId", user.UserId.ToString()),
            new("role", roleName)
        };

        if (!string.IsNullOrWhiteSpace(user.FirstName))
        {
            claims.Add(new Claim(ClaimTypes.GivenName, user.FirstName));
            claims.Add(new Claim("firstName", user.FirstName));
        }

        if (!string.IsNullOrWhiteSpace(user.LastName))
        {
            claims.Add(new Claim(ClaimTypes.Surname, user.LastName));
            claims.Add(new Claim("lastName", user.LastName));
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddDays(7),
            Issuer = issuer,
            Audience = audience,
            SigningCredentials = credentials
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}
}
