using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using PCForge.Api.DTOs;

namespace PCForge.Api.Services;

public class CloudinaryImageUploadService : IImageUploadService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<CloudinaryImageUploadService> _logger;

    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".webp", ".gif"
    };

    private const long MaxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

    public CloudinaryImageUploadService(
        IConfiguration configuration,
        ILogger<CloudinaryImageUploadService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    /// <summary>
    /// Checks if Cloudinary is configured via CLOUDINARY_URL, appsettings, or environment variables.
    /// </summary>
    public CloudinaryStatusDto GetStatus()
    {
        var (isConfigured, cloudName, _) = GetCloudinaryClient();
        return new CloudinaryStatusDto
        {
            IsConfigured = isConfigured,
            CloudName = cloudName,
            Provider = "Cloudinary",
            Message = isConfigured
                ? $"Cloudinary is connected and ready (Cloud Name: {cloudName})."
                : "Cloudinary credentials are not configured. Product images require Cloudinary. Please set CLOUDINARY_URL or Cloudinary credentials in .env / appsettings.json."
        };
    }

    /// <summary>
    /// Uploads an image file/blob to Cloudinary.
    /// Strictly enforces Cloudinary storage for product images.
    /// </summary>
    public async Task<ImageUploadResultDto> UploadImageAsync(IFormFile file, string folder = "pc-forge/products")
    {
        if (file == null || file.Length == 0)
        {
            throw new ArgumentException("No image file was provided or the file is empty.", nameof(file));
        }

        if (file.Length > MaxFileSizeBytes)
        {
            throw new ArgumentException($"File size exceeds the 5MB limit. Current size: {file.Length / 1024.0 / 1024.0:F2}MB.");
        }

        var extension = Path.GetExtension(file.FileName);
        if (string.IsNullOrEmpty(extension) || !AllowedExtensions.Contains(extension))
        {
            throw new ArgumentException($"Unsupported image extension '{extension}'. Allowed formats: .jpg, .jpeg, .png, .webp, .gif.");
        }

        var (isConfigured, cloudName, cloudinary) = GetCloudinaryClient();

        if (!isConfigured || cloudinary == null)
        {
            _logger.LogError("Upload failed: Cloudinary is not configured on the backend server.");
            throw new InvalidOperationException(
                "Cloudinary is not configured. Product images must use Cloudinary. " +
                "Please configure CLOUDINARY_URL or Cloudinary:CloudName, ApiKey, and ApiSecret in backend/.env or appsettings.json.");
        }

        try
        {
            await using var stream = file.OpenReadStream();
            var uploadParams = new ImageUploadParams
            {
                File = new FileDescription(file.FileName, stream),
                Folder = folder,
                Transformation = new Transformation().Quality("auto").FetchFormat("auto"),
                DisplayName = Path.GetFileNameWithoutExtension(file.FileName),
                UniqueFilename = true,
                Overwrite = false
            };

            var uploadResult = await cloudinary.UploadAsync(uploadParams);

            if (uploadResult.Error != null)
            {
                _logger.LogError("Cloudinary upload failed: {Message}", uploadResult.Error.Message);
                throw new InvalidOperationException($"Cloudinary upload failed: {uploadResult.Error.Message}");
            }

            var secureUrl = uploadResult.SecureUrl?.ToString() ?? uploadResult.Url?.ToString() ?? string.Empty;
            _logger.LogInformation("Image successfully uploaded to Cloudinary: {Url} (PublicId: {PublicId})",
                secureUrl, uploadResult.PublicId);

            return new ImageUploadResultDto
            {
                Url = secureUrl,
                PublicId = uploadResult.PublicId,
                FileName = file.FileName,
                FileSizeBytes = file.Length,
                StorageProvider = "Cloudinary"
            };
        }
        catch (Exception ex) when (ex is not ArgumentException && ex is not InvalidOperationException)
        {
            _logger.LogError(ex, "Unexpected error occurred during Cloudinary upload.");
            throw new InvalidOperationException($"Cloudinary upload failed: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Helper to resolve Cloudinary credentials and build the Cloudinary instance.
    /// Checks CLOUDINARY_URL, configuration sections, and environment variables.
    /// </summary>
    private (bool IsConfigured, string? CloudName, Cloudinary? Client) GetCloudinaryClient()
    {
        // 1. Check CLOUDINARY_URL (e.g. cloudinary://api_key:api_secret@cloud_name)
        var cloudinaryUrl = _configuration["CLOUDINARY_URL"]
            ?? Environment.GetEnvironmentVariable("CLOUDINARY_URL");

        if (!string.IsNullOrWhiteSpace(cloudinaryUrl) &&
            cloudinaryUrl.StartsWith("cloudinary://", StringComparison.OrdinalIgnoreCase))
        {
            try
            {
                var client = new Cloudinary(cloudinaryUrl)
                {
                    Api = { Secure = true }
                };

                var cloudName = client.Api.Account?.Cloud;
                return (true, cloudName, client);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to initialize Cloudinary with CLOUDINARY_URL.");
            }
        }

        // 2. Check individual credentials (skipping any placeholder strings)
        var cloudNameValue = GetFirstNonPlaceholder(
            Environment.GetEnvironmentVariable("CLOUDINARY_CLOUD_NAME"),
            _configuration["CLOUDINARY_CLOUD_NAME"],
            Environment.GetEnvironmentVariable("Cloudinary__CloudName"),
            _configuration["Cloudinary:CloudName"]);

        var apiKeyValue = GetFirstNonPlaceholder(
            Environment.GetEnvironmentVariable("CLOUDINARY_API_KEY"),
            _configuration["CLOUDINARY_API_KEY"],
            Environment.GetEnvironmentVariable("Cloudinary__ApiKey"),
            _configuration["Cloudinary:ApiKey"]);

        var apiSecretValue = GetFirstNonPlaceholder(
            Environment.GetEnvironmentVariable("CLOUDINARY_API_SECRET"),
            _configuration["CLOUDINARY_API_SECRET"],
            Environment.GetEnvironmentVariable("Cloudinary__ApiSecret"),
            _configuration["Cloudinary:ApiSecret"]);

        bool isConfigured = !string.IsNullOrWhiteSpace(cloudNameValue) &&
                            !string.IsNullOrWhiteSpace(apiKeyValue) &&
                            !string.IsNullOrWhiteSpace(apiSecretValue);

        if (isConfigured)
        {
            try
            {
                var account = new Account(cloudNameValue, apiKeyValue, apiSecretValue);
                var client = new Cloudinary(account)
                {
                    Api = { Secure = true }
                };
                return (true, cloudNameValue, client);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to initialize Cloudinary with discrete credentials.");
            }
        }

        return (false, cloudNameValue, null);
    }

    private static string? GetFirstNonPlaceholder(params string?[] values)
    {
        foreach (var val in values)
        {
            if (string.IsNullOrWhiteSpace(val)) continue;
            var trimmed = val.Trim();
            if (trimmed.Equals("YOUR_CLOUD_NAME", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("YOUR_API_KEY", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Equals("YOUR_API_SECRET", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Contains("your_cloud_name", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Contains("your_api_key", StringComparison.OrdinalIgnoreCase) ||
                trimmed.Contains("your_api_secret", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            return trimmed;
        }
        return null;
    }
}
