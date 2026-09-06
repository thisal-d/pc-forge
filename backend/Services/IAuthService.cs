using PCForge.Api.DTOs;

namespace PCForge.Api.Services;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(RegisterDto dto);
    Task<AuthResponseDto> LoginAsync(LoginDto dto);
    Task<AuthResponseDto> UpdateProfileAsync(int userId, UpdateProfileDto dto);
}
