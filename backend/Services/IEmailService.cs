namespace PCForge.Api.Services;

public interface IEmailService
{
    /// <summary>
    /// Legacy method for custom PC build review notifications (Approved or Changes Requested).
    /// Kept for backwards compatibility.
    /// </summary>
    Task<bool> SendBuildReviewNotificationAsync(
        string customerEmail,
        string customerName,
        int buildId,
        string buildName,
        string newStatus,
        string? technicianNotes,
        decimal totalPrice);

    /// <summary>
    /// Sends custom build notifications for all lifecycle events:
    /// - Submitted ("Pending Staff Review")
    /// - In Review ("In Review by Staff")
    /// - Approved ("Approved by Staff")
    /// - Modifications Requested ("Changes Requested")
    /// - Cancelled ("Cancelled")
    /// </summary>
    Task<bool> SendBuildNotificationAsync(
        string customerEmail,
        string customerName,
        int buildId,
        string buildName,
        string eventType,
        string? technicianNotes = null,
        decimal totalPrice = 0);

    /// <summary>
    /// Sends customer notifications for order lifecycle transitions:
    /// - Order Confirmed / Placed ("Order placed")
    /// - Processing & PC Assembly Started ("Processing")
    /// - Ready for Delivery ("Ready for delivery")
    /// - Out for Delivery ("Out for delivery")
    /// - Ready for Pickup with verified store details ("Ready for pickup")
    /// - Completed / Settled ("Paid & Completed")
    /// - Cancelled ("Cancelled")
    /// </summary>
    Task<bool> SendOrderNotificationAsync(
        string customerEmail,
        string customerName,
        int orderId,
        string eventType,
        string paymentMethod,
        string shippingAddress,
        decimal totalAmount,
        int itemCount = 0,
        string? notes = null);

    /// <summary>
    /// Sends customer notifications for after-sales service request transitions:
    /// - Service Request Booked ("Booked")
    /// - In Progress / Assigned ("In Progress")
    /// - Completed / Repaired ("Completed")
    /// - Rejected ("Rejected")
    /// - Cancelled ("Cancelled")
    /// </summary>
    Task<bool> SendServiceRequestNotificationAsync(
        string customerEmail,
        string customerName,
        string serviceRequestNumber,
        string eventType,
        string? title = null,
        DateTime? appointmentDate = null,
        string? appointmentTime = null,
        string? notes = null);
}
