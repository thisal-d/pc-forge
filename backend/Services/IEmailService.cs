namespace PCForge.Api.Services;

public interface IEmailService
{
    /// <summary>
    /// Sends a customer notification email regarding a custom PC build review (Approved or Changes Requested).
    /// </summary>
    Task<bool> SendBuildReviewNotificationAsync(
        string customerEmail,
        string customerName,
        int buildId,
        string buildName,
        string newStatus,
        string? technicianNotes,
        decimal totalPrice);
}
