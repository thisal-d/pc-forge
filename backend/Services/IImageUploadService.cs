using PCForge.Api.DTOs;

namespace PCForge.Api.Services;

public interface IImageUploadService
{
    Task<ImageUploadResultDto> UploadImageAsync(IFormFile file, string folder = "pc-forge/products");
    CloudinaryStatusDto GetStatus();
}
