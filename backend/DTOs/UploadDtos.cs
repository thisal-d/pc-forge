namespace PCForge.Api.DTOs;

public class ImageUploadResultDto
{
    public string Url { get; set; } = string.Empty;
    public string? PublicId { get; set; }
    public string? FileName { get; set; }
    public long FileSizeBytes { get; set; }
    public string StorageProvider { get; set; } = "Cloudinary";
}

public class CloudinaryStatusDto
{
    public bool IsConfigured { get; set; }
    public string? CloudName { get; set; }
    public string Provider { get; set; } = "Cloudinary";
    public string Message { get; set; } = string.Empty;
}
