using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PCForge.Api.DTOs;
using PCForge.Api.Services;

namespace PCForge.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UploadController : ControllerBase
{
    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".webp", ".gif"
    };

    private static readonly HashSet<string> AllowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg", "image/jpg", "image/pjpeg", "image/png", "image/x-png", "image/webp", "image/gif"
    };

    private const long MaxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

    private readonly IImageUploadService _imageUploadService;
    private readonly ILogger<UploadController> _logger;

    public UploadController(IImageUploadService imageUploadService, ILogger<UploadController> logger)
    {
        _imageUploadService = imageUploadService;
        _logger = logger;
    }

    /// <summary>
    /// Get the current Cloudinary configuration and connection status.
    /// </summary>
    [AllowAnonymous]
    [HttpGet("status")]
    [ProducesResponseType(typeof(CloudinaryStatusDto), StatusCodes.Status200OK)]
    public ActionResult<CloudinaryStatusDto> GetStatus()
    {
        var status = _imageUploadService.GetStatus();
        return Ok(status);
    }

    /// <summary>
    /// Upload a product image binary blob to Cloudinary.
    /// </summary>
    /// <param name="file">Image file blob (JPEG, PNG, WebP, GIF up to 5MB)</param>
    /// <param name="folder">Optional target folder name (default: pc-forge/products)</param>
    /// <returns>Secure Cloudinary URL and metadata</returns>
    [HttpPost("image")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(ImageUploadResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ImageUploadResultDto>> UploadImage(
        [FromForm] IFormFile file,
        [FromForm] string? folder = null)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "Please select a valid image file to upload." });
        }

        if (file.Length > MaxFileSizeBytes)
        {
            return BadRequest(new { message = $"File size exceeds the 5MB limit. Current size: {file.Length / 1024.0 / 1024.0:F2}MB." });
        }

        var extension = Path.GetExtension(file.FileName);
        if (string.IsNullOrEmpty(extension) || !AllowedExtensions.Contains(extension) ||
            string.IsNullOrEmpty(file.ContentType) || !AllowedContentTypes.Contains(file.ContentType))
        {
            return BadRequest(new { message = $"Invalid file type '{extension}'. Allowed image formats: .jpg, .jpeg, .png, .webp, .gif." });
        }

        try
        {
            var targetFolder = string.IsNullOrWhiteSpace(folder) ? "pc-forge/products" : folder.Trim();
            var result = await _imageUploadService.UploadImageAsync(file, targetFolder);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Cloudinary upload operation failed.");
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while uploading product image to Cloudinary.");
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                message = "An error occurred while uploading the image to Cloudinary: " + ex.Message
            });
        }
    }
}
