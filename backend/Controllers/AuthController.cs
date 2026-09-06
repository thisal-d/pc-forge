using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PCForge.Api.DTOs;
using PCForge.Api.Services;

namespace PCForge.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(IAuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
        _logger = logger;
    }

    /// <summary>
    /// Register a new user account.
    /// </summary>
    [HttpPost("register")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new AuthResponseDto
            {
                Success = false,
                Message = "Invalid registration data provided."
            });
        }

        try
        {
            var result = await _authService.RegisterAsync(dto);
            if (!result.Success)
            {
                return BadRequest(result);
            }

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error occurred during registration.");
            return StatusCode(StatusCodes.Status500InternalServerError, new AuthResponseDto
            {
                Success = false,
                Message = $"Server error during registration: {ex.Message}"
            });
        }
    }

    /// <summary>
    /// Authenticate credentials and receive a JWT token.
    /// </summary>
    [HttpPost("login")]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(AuthResponseDto), StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new AuthResponseDto
            {
                Success = false,
                Message = "Invalid credentials format."
            });
        }

        try
        {
            var result = await _authService.LoginAsync(dto);
            if (!result.Success)
            {
                return Unauthorized(result);
            }

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error occurred during login.");
            return StatusCode(StatusCodes.Status500InternalServerError, new AuthResponseDto
            {
                Success = false,
                Message = $"Server error during login: {ex.Message}"
            });
        }
    }

    /// <summary>
    /// Retrieve currently authenticated user's claims.
    /// </summary>
    [Authorize]
    [HttpGet("me")]
    public IActionResult GetCurrentUser()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        var email = User.FindFirstValue(ClaimTypes.Email);
        var role = User.FindFirstValue(ClaimTypes.Role) ?? User.FindFirstValue("role");
        var firstName = User.FindFirstValue(ClaimTypes.GivenName) ?? User.FindFirstValue("firstName");
        var lastName = User.FindFirstValue(ClaimTypes.Surname) ?? User.FindFirstValue("lastName");

        return Ok(new
        {
            UserId = userId,
            Email = email,
            Role = role,
            FirstName = firstName,
            LastName = lastName
        });
    }

    /// <summary>
    /// Update authenticated user's profile details (Member 01).
    /// </summary>
    [Authorize]
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(new AuthResponseDto
            {
                Success = false,
                Message = "Invalid profile data provided."
            });
        }

        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("userId");
        if (!int.TryParse(userIdStr, out int userId))
        {
            return Unauthorized(new AuthResponseDto
            {
                Success = false,
                Message = "Invalid or missing user authentication claims."
            });
        }

        try
        {
            var result = await _authService.UpdateProfileAsync(userId, dto);
            if (!result.Success)
            {
                return BadRequest(result);
            }

            return Ok(result);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error occurred during profile update.");
            return StatusCode(StatusCodes.Status500InternalServerError, new AuthResponseDto
            {
                Success = false,
                Message = $"Server error during profile update: {ex.Message}"
            });
        }
    }
}
