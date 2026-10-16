using System.Collections.Concurrent;
using System.Net.Http.Json;
using System.Text.RegularExpressions;

namespace PCForge.Api.Services;

public class EmailService : IEmailService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    // In-memory sliding cache to prevent duplicate email transmissions (5 minute debounce window)
    private static readonly ConcurrentDictionary<string, DateTime> _dispatchedCache = new();
    private static readonly TimeSpan DuplicateDebounceWindow = TimeSpan.FromMinutes(5);

    // Official store & support constants
    public const string OfficialLogoUrl = "https://pc-forge-admin.pages.dev/logo.png";
    public const string OfficialSupportEmail = "support@pcforge.com";
    public const string VerifiedPickupStoreName = "PCForge Store & Technical Support Hub";
    public const string VerifiedPickupAddress = "100 Innovation Drive, Colombo 03, Sri Lanka";
    public const string VerifiedPickupHours = "Monday – Saturday: 09:00 AM – 06:00 PM (Closed Sundays & Public Holidays)";
    public const string VerifiedPickupInstructions = "Please present your Order ID and a valid government-issued photo ID (NIC, Driving License, or Passport) at the main support counter.";

    public EmailService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<EmailService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    /// <summary>
    /// Legacy method for custom PC build review notifications. Delegates to SendBuildNotificationAsync.
    /// </summary>
    public Task<bool> SendBuildReviewNotificationAsync(
        string customerEmail,
        string customerName,
        int buildId,
        string buildName,
        string newStatus,
        string? technicianNotes,
        decimal totalPrice)
    {
        return SendBuildNotificationAsync(
            customerEmail,
            customerName,
            buildId,
            buildName,
            newStatus,
            technicianNotes,
            totalPrice);
    }

    /// <summary>
    /// Sends custom build notifications for all lifecycle events:
    /// - Submitted ("Pending Staff Review")
    /// - In Review ("In Review by Staff")
    /// - Approved ("Approved by Staff")
    /// - Modifications Requested ("Changes Requested")
    /// - Cancelled ("Cancelled")
    /// </summary>
    public async Task<bool> SendBuildNotificationAsync(
        string customerEmail,
        string customerName,
        int buildId,
        string buildName,
        string eventType,
        string? technicianNotes = null,
        decimal totalPrice = 0)
    {
        if (!IsValidEmail(customerEmail))
        {
            _logger.LogWarning("[EmailService] Custom build email skipped: invalid customer email '{Email}'.", customerEmail);
            return false;
        }

        // Prevent duplicate dispatches within 5 minutes for the same build and event
        var cacheKey = $"build:{buildId}:{eventType.Trim().ToLowerInvariant()}";
        if (IsDuplicateDispatch(cacheKey))
        {
            _logger.LogInformation("[EmailService] Suppressed duplicate email dispatch for key {CacheKey}", cacheKey);
            return true;
        }

        var webUrl = GetWebBaseUrl();
        var normalizedStatus = eventType.Trim();
        var isApproved = normalizedStatus.Equals("Approved by Staff", StringComparison.OrdinalIgnoreCase) ||
                         normalizedStatus.Equals("Approved", StringComparison.OrdinalIgnoreCase);
        var isChangesRequested = normalizedStatus.Equals("Changes Requested", StringComparison.OrdinalIgnoreCase) ||
                                normalizedStatus.Equals("Rejected", StringComparison.OrdinalIgnoreCase);
        var isInReview = normalizedStatus.Equals("In Review by Staff", StringComparison.OrdinalIgnoreCase) ||
                         normalizedStatus.Equals("In Review", StringComparison.OrdinalIgnoreCase);
        var isSubmitted = normalizedStatus.Equals("Pending Staff Review", StringComparison.OrdinalIgnoreCase) ||
                          normalizedStatus.Equals("Submitted", StringComparison.OrdinalIgnoreCase);
        var isCancelled = normalizedStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) ||
                          normalizedStatus.Equals("Canceled", StringComparison.OrdinalIgnoreCase);

        string subject;
        string statusBadge;
        string headline;
        string summaryText;
        string defaultNotes;

        if (isApproved)
        {
            subject = $"PCForge: Your Custom PC Build #{buildId} has been Approved!";
            statusBadge = "APPROVED";
            headline = "Build Approved & Cleared for Assembly";
            summaryText = $"Great news! Our certified hardware technicians have reviewed your custom PC configuration \"{buildName}\" (Build #{buildId}). Component clearances, thermal margins, and power budgets have all passed verification.";
            defaultNotes = "All hardware compatibility checks passed. Power envelopes and PCIe lane allocations verified. Cleared for assembly.";
        }
        else if (isChangesRequested)
        {
            subject = $"PCForge: Modifications Requested for Custom Build #{buildId}";
            statusBadge = "CHANGES REQUESTED";
            headline = "Modifications Needed for Build Clearance";
            summaryText = $"Our technicians evaluated your custom PC configuration \"{buildName}\" (Build #{buildId}) and identified compatibility or clearance adjustments that need your attention before we can proceed.";
            defaultNotes = "Component conflict or thermal constraint detected. Please review the technician feedback below and update your configuration in the PCForge app.";
        }
        else if (isInReview)
        {
            subject = $"PCForge: Compatibility Review Started for Build #{buildId}";
            statusBadge = "IN REVIEW";
            headline = "Technician Review Underway";
            summaryText = $"A certified PCForge systems technician has begun checking the physical clearances, socket compatibility, and thermal requirements of your build \"{buildName}\" (Build #{buildId}).";
            defaultNotes = "Hardware validation in progress. You will receive an update once physical checks and wattage verification are concluded.";
        }
        else if (isCancelled)
        {
            subject = $"PCForge: Custom Build Request #{buildId} Cancelled";
            statusBadge = "CANCELLED";
            headline = "Build Request Cancelled";
            summaryText = $"Custom build configuration \"{buildName}\" (Build #{buildId}) has been cancelled. If this was done by mistake, you can recreate your configuration anytime on PCForge.";
            defaultNotes = "Build configuration removed from review queue.";
        }
        else // Submitted / Pending Staff Review
        {
            subject = $"PCForge: Custom Build Request #{buildId} Received";
            statusBadge = "SUBMITTED";
            headline = "Build Configuration Submitted for Review";
            summaryText = $"Thank you for configuring your dream rig \"{buildName}\" (Build #{buildId}) with PCForge! We have queued your component list for comprehensive engineering and compatibility review.";
            defaultNotes = "Queued for technician clearance and power budget verification.";
        }

        var notes = !string.IsNullOrWhiteSpace(technicianNotes) ? technicianNotes : defaultNotes;
        var formattedPrice = totalPrice > 0 ? $"LKR {totalPrice:N2}" : "Pending calculation";

        var templateParams = new Dictionary<string, string>
        {
            ["to_name"] = customerName,
            ["to_email"] = customerEmail,
            ["customer_name"] = customerName,
            ["customer_email"] = customerEmail,
            ["email"] = customerEmail,
            ["user_email"] = customerEmail,
            ["recipient_email"] = customerEmail,
            ["reply_to"] = customerEmail,
            ["subject"] = subject,
            ["headline"] = headline,
            ["status_badge"] = statusBadge,
            ["build_id"] = buildId.ToString(),
            ["build_name"] = buildName,
            ["status"] = normalizedStatus,
            ["review_status"] = statusBadge,
            ["technician_notes"] = notes,
            ["staff_notes"] = notes,
            ["total_price"] = formattedPrice,
            ["message"] = summaryText,
            ["summary_text"] = summaryText,
            ["action_url"] = $"{webUrl}/builds",
            ["action_label"] = "View My Custom Builds",
            ["support_email"] = OfficialSupportEmail,
            ["current_year"] = DateTime.UtcNow.Year.ToString(),
            ["logo_url"] = OfficialLogoUrl
        };

        // Resolve template ID with cascading fallbacks
        var templateId = ResolveBuildTemplateId(normalizedStatus);

        return await DispatchEmailAsync(
            customerEmail,
            customerName,
            subject,
            templateId,
            templateParams,
            cacheKey);
    }

    /// <summary>
    /// Sends customer notifications for order lifecycle transitions:
    /// - Order Confirmed ("Order placed")
    /// - Processing & PC Assembly Started ("Processing")
    /// - Ready for Delivery ("Ready for delivery")
    /// - Out for Delivery ("Out for delivery")
    /// - Ready for Pickup with verified store details ("Ready for pickup")
    /// - Paid & Completed ("Paid & Completed")
    /// - Cancelled ("Cancelled")
    /// </summary>
    public async Task<bool> SendOrderNotificationAsync(
        string customerEmail,
        string customerName,
        int orderId,
        string eventType,
        string paymentMethod,
        string shippingAddress,
        decimal totalAmount,
        int itemCount = 0,
        string? notes = null)
    {
        if (!IsValidEmail(customerEmail))
        {
            _logger.LogWarning("[EmailService] Order email skipped: invalid customer email '{Email}'.", customerEmail);
            return false;
        }

        var cacheKey = $"order:{orderId}:{eventType.Trim().ToLowerInvariant()}";
        if (IsDuplicateDispatch(cacheKey))
        {
            _logger.LogInformation("[EmailService] Suppressed duplicate email dispatch for key {CacheKey}", cacheKey);
            return true;
        }

        var webUrl = GetWebBaseUrl();
        var normalizedStatus = eventType.Trim();
        var isPlaced = normalizedStatus.Equals("Order placed", StringComparison.OrdinalIgnoreCase);
        var isProcessing = normalizedStatus.Equals("Processing", StringComparison.OrdinalIgnoreCase);
        var isReadyForPickup = normalizedStatus.Equals("Ready for pickup", StringComparison.OrdinalIgnoreCase);
        var isReadyForDelivery = normalizedStatus.Equals("Ready for delivery", StringComparison.OrdinalIgnoreCase);
        var isOutForDelivery = normalizedStatus.Equals("Out for delivery", StringComparison.OrdinalIgnoreCase);
        var isCompleted = normalizedStatus.Equals("Paid & Completed", StringComparison.OrdinalIgnoreCase) ||
                          normalizedStatus.Equals("Completed", StringComparison.OrdinalIgnoreCase);
        var isCancelled = normalizedStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) ||
                          normalizedStatus.Equals("Canceled", StringComparison.OrdinalIgnoreCase);

        string subject;
        string statusBadge;
        string headline;
        string summaryText;
        string deliveryOrPickupNotes;

        if (isPlaced)
        {
            subject = $"PCForge: Order #{orderId} Confirmed!";
            statusBadge = "CONFIRMED";
            headline = "Order Placed Successfully";
            summaryText = $"Thank you for your purchase! We have received your order #{orderId} and scheduled inventory verification. We will notify you as soon as assembly or fulfillment starts.";
            deliveryOrPickupNotes = $"Payment Method: {paymentMethod}. Standard delivery address: {shippingAddress}.";
        }
        else if (isProcessing)
        {
            subject = $"PCForge: Order #{orderId} Processing & PC Assembly Started";
            statusBadge = "PROCESSING";
            headline = "Assembly & Component Staging Underway";
            summaryText = $"Your order #{orderId} is currently in active processing! Our technicians are staging components, commencing PC assembly, cable management, and stress-testing benchmarks.";
            deliveryOrPickupNotes = "Hardware bench-testing and OS deployment in progress.";
        }
        else if (isReadyForPickup)
        {
            subject = $"PCForge: Order #{orderId} is Ready for Pickup!";
            statusBadge = "READY FOR PICKUP";
            headline = "Your Hardware is Ready for Collection";
            summaryText = $"Great news! Your order #{orderId} has completed assembly and quality inspection, and is now securely packaged and awaiting your arrival at our central pickup hub.";
            deliveryOrPickupNotes = $"{VerifiedPickupStoreName} ({VerifiedPickupAddress}). Hours: {VerifiedPickupHours}. {VerifiedPickupInstructions}";
        }
        else if (isOutForDelivery)
        {
            subject = $"PCForge: Order #{orderId} is Out for Delivery!";
            statusBadge = "OUT FOR DELIVERY";
            headline = "Dispatched with Courier Partner";
            summaryText = $"Your package for order #{orderId} has been handed over to our verified delivery logistics courier and is on its way to your destination address.";
            deliveryOrPickupNotes = $"Delivering to: {shippingAddress}. Please have the exact payment amount ready if paying via Cash on Delivery.";
        }
        else if (isReadyForDelivery)
        {
            subject = $"PCForge: Order #{orderId} Packed & Ready for Delivery";
            statusBadge = "PACKED";
            headline = "Packed & Awaiting Courier Dispatch";
            summaryText = $"Your order #{orderId} has passed final quality audits and has been securely packed in anti-static shipping materials, ready for courier pickup.";
            deliveryOrPickupNotes = $"Delivery address: {shippingAddress}.";
        }
        else if (isCompleted)
        {
            subject = $"PCForge: Order #{orderId} Completed — Thank You!";
            statusBadge = "PAID & COMPLETED";
            headline = "Order Successfully Fulfilled";
            summaryText = $"Your order #{orderId} has been successfully completed and settled. Thank you for choosing PCForge for your high-performance computing hardware!";
            deliveryOrPickupNotes = "All warranties and invoice records are registered under your account.";
        }
        else if (isCancelled)
        {
            subject = $"PCForge: Order #{orderId} has been Cancelled";
            statusBadge = "CANCELLED";
            headline = "Order Cancellation Confirmed";
            summaryText = $"Order #{orderId} has been cancelled and any reserved inventory has been released. If a refund or query applies, our support team will assist you.";
            deliveryOrPickupNotes = "Cancellation executed successfully.";
        }
        else
        {
            subject = $"PCForge: Order #{orderId} Status Update: {normalizedStatus}";
            statusBadge = normalizedStatus.ToUpperInvariant();
            headline = $"Order Update: {normalizedStatus}";
            summaryText = $"Your order #{orderId} has transitioned to status '{normalizedStatus}'.";
            deliveryOrPickupNotes = notes ?? "No additional notes provided.";
        }

        var templateParams = new Dictionary<string, string>
        {
            ["to_name"] = customerName,
            ["to_email"] = customerEmail,
            ["customer_name"] = customerName,
            ["customer_email"] = customerEmail,
            ["email"] = customerEmail,
            ["user_email"] = customerEmail,
            ["recipient_email"] = customerEmail,
            ["reply_to"] = customerEmail,
            ["subject"] = subject,
            ["headline"] = headline,
            ["status_badge"] = statusBadge,
            ["order_id"] = orderId.ToString(),
            ["status"] = normalizedStatus,
            ["payment_method"] = paymentMethod,
            ["shipping_address"] = shippingAddress,
            ["total_amount"] = $"LKR {totalAmount:N2}",
            ["item_count"] = itemCount > 0 ? itemCount.ToString() : "1",
            ["message"] = summaryText,
            ["summary_text"] = summaryText,
            ["order_notes"] = notes ?? deliveryOrPickupNotes,
            ["pickup_store_name"] = VerifiedPickupStoreName,
            ["pickup_address"] = VerifiedPickupAddress,
            ["pickup_hours"] = VerifiedPickupHours,
            ["pickup_instructions"] = VerifiedPickupInstructions,
            ["action_url"] = $"{webUrl}/orders/{orderId}",
            ["action_label"] = "Track Order Details",
            ["support_email"] = OfficialSupportEmail,
            ["current_year"] = DateTime.UtcNow.Year.ToString(),
            ["logo_url"] = OfficialLogoUrl
        };

        var templateId = ResolveOrderTemplateId(normalizedStatus);

        return await DispatchEmailAsync(
            customerEmail,
            customerName,
            subject,
            templateId,
            templateParams,
            cacheKey);
    }

    /// <summary>
    /// Sends customer notifications for after-sales service request transitions:
    /// - Request Received ("Pending")
    /// - In Progress / Assigned ("In Progress")
    /// - Completed / Repaired ("Completed")
    /// - Rejected ("Rejected")
    /// - Cancelled ("Cancelled")
    /// </summary>
    public async Task<bool> SendServiceRequestNotificationAsync(
        string customerEmail,
        string customerName,
        string serviceRequestNumber,
        string eventType,
        string? title = null,
        DateTime? appointmentDate = null,
        string? appointmentTime = null,
        string? notes = null)
    {
        if (!IsValidEmail(customerEmail))
        {
            _logger.LogWarning("[EmailService] Service request email skipped: invalid customer email '{Email}'.", customerEmail);
            return false;
        }

        var cacheKey = $"service:{serviceRequestNumber.Trim().ToLowerInvariant()}:{eventType.Trim().ToLowerInvariant()}";
        if (IsDuplicateDispatch(cacheKey))
        {
            _logger.LogInformation("[EmailService] Suppressed duplicate email dispatch for key {CacheKey}", cacheKey);
            return true;
        }

        var webUrl = GetWebBaseUrl();
        var normalizedStatus = eventType.Trim();
        var isReceived = normalizedStatus.Equals("Booked", StringComparison.OrdinalIgnoreCase) ||
                         normalizedStatus.Equals("Pending", StringComparison.OrdinalIgnoreCase) ||
                         normalizedStatus.Equals("Received", StringComparison.OrdinalIgnoreCase);
        var isInProgress = normalizedStatus.Equals("In Progress", StringComparison.OrdinalIgnoreCase) ||
                           normalizedStatus.Equals("Assigned", StringComparison.OrdinalIgnoreCase);
        var isCompleted = normalizedStatus.Equals("Completed", StringComparison.OrdinalIgnoreCase) ||
                          normalizedStatus.Equals("Resolved", StringComparison.OrdinalIgnoreCase);
        var isRejected = normalizedStatus.Equals("Rejected", StringComparison.OrdinalIgnoreCase);
        var isCancelled = normalizedStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) ||
                          normalizedStatus.Equals("Canceled", StringComparison.OrdinalIgnoreCase);

        string subject;
        string statusBadge;
        string headline;
        string summaryText;

        var displayDate = appointmentDate.HasValue ? appointmentDate.Value.ToString("dddd, MMMM dd, yyyy") : "Date Pending Confirmation";
        var displayTime = !string.IsNullOrWhiteSpace(appointmentTime) ? appointmentTime : "Standard Operating Window (09:00 AM - 06:00 PM)";

        if (isReceived)
        {
            subject = $"PCForge: Service Request #{serviceRequestNumber} Booked";
            statusBadge = "BOOKED";
            headline = "Service Booking Confirmed";
            summaryText = $"We have successfully booked your after-sales service appointment #{serviceRequestNumber} (\"{title ?? "Technical Assistance"}\"). Our technical support desk has reserved your diagnostic appointment slot.";
        }
        else if (isInProgress)
        {
            subject = $"PCForge: Service Request #{serviceRequestNumber} In Progress";
            statusBadge = "IN PROGRESS";
            headline = "Technician Assigned & Service Underway";
            summaryText = $"Your service ticket #{serviceRequestNumber} has been assigned to a PCForge hardware specialist. Diagnostics, component inspections, and RMA verifications are currently underway.";
        }
        else if (isCompleted)
        {
            subject = $"PCForge: Service Request #{serviceRequestNumber} Completed";
            statusBadge = "COMPLETED";
            headline = "Service & Diagnostics Successfully Completed";
            summaryText = $"Good news! Your service request #{serviceRequestNumber} has been resolved. Your hardware is tested, certified, and ready for pickup or handover.";
        }
        else if (isRejected)
        {
            subject = $"PCForge: Update on Service Request #{serviceRequestNumber}";
            statusBadge = "REJECTED";
            headline = "Service Request Could Not Be Approved";
            summaryText = $"Our technical desk reviewed your service request #{serviceRequestNumber} and was unable to accept it under standard manufacturer warranty / coverage terms.";
        }
        else if (isCancelled)
        {
            subject = $"PCForge: Service Request #{serviceRequestNumber} Cancelled";
            statusBadge = "CANCELLED";
            headline = "Service Booking Cancelled";
            summaryText = $"Service appointment #{serviceRequestNumber} has been cancelled and the scheduled time slot has been released.";
        }
        else
        {
            subject = $"PCForge: Service Request #{serviceRequestNumber} - {normalizedStatus}";
            statusBadge = normalizedStatus.ToUpperInvariant();
            headline = $"Service Update: {normalizedStatus}";
            summaryText = $"Service request #{serviceRequestNumber} has been updated to '{normalizedStatus}'.";
        }

        var templateParams = new Dictionary<string, string>
        {
            ["to_name"] = customerName,
            ["to_email"] = customerEmail,
            ["customer_name"] = customerName,
            ["customer_email"] = customerEmail,
            ["email"] = customerEmail,
            ["user_email"] = customerEmail,
            ["recipient_email"] = customerEmail,
            ["reply_to"] = customerEmail,
            ["subject"] = subject,
            ["headline"] = headline,
            ["status_badge"] = statusBadge,
            ["service_request_number"] = serviceRequestNumber,
            ["service_id"] = serviceRequestNumber,
            ["title"] = title ?? "Hardware Maintenance / Diagnostic Service",
            ["status"] = normalizedStatus,
            ["appointment_date"] = displayDate,
            ["appointment_time"] = displayTime,
            ["service_notes"] = notes ?? summaryText,
            ["message"] = summaryText,
            ["summary_text"] = summaryText,
            ["action_url"] = $"{webUrl}/services",
            ["action_label"] = "View Service Status",
            ["support_email"] = OfficialSupportEmail,
            ["current_year"] = DateTime.UtcNow.Year.ToString(),
            ["logo_url"] = OfficialLogoUrl,
            // Fallback aliases in case service requests use the master builds or orders template
            ["build_name"] = title ?? $"Service #{serviceRequestNumber}",
            ["technician_notes"] = notes ?? summaryText,
            ["total_price"] = "Service Ticket",
            ["order_id"] = serviceRequestNumber,
            ["order_notes"] = notes ?? summaryText,
            ["payment_method"] = "Service Center",
            ["shipping_address"] = "PCForge Technical Support Hub",
            ["total_amount"] = "Diagnostic / Warranty"
        };

        var templateId = ResolveServiceTemplateId(normalizedStatus);

        return await DispatchEmailAsync(
            customerEmail,
            customerName,
            subject,
            templateId,
            templateParams,
            cacheKey);
    }

    /// <summary>
    /// Dispatches the prepared email payload to the EmailJS REST API or logs simulated delivery.
    /// </summary>
    private async Task<bool> DispatchEmailAsync(
        string customerEmail,
        string customerName,
        string subject,
        string? templateId,
        Dictionary<string, string> templateParams,
        string cacheKey)
    {
        var serviceId = _configuration["EMAILJS_SERVICE_ID"]
            ?? _configuration["EmailJs:ServiceId"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_SERVICE_ID");

        var publicKey = _configuration["EMAILJS_PUBLIC_KEY"]
            ?? _configuration["EmailJs:PublicKey"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_PUBLIC_KEY");

        var privateKey = _configuration["EMAILJS_PRIVATE_KEY"]
            ?? _configuration["EmailJs:PrivateKey"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_PRIVATE_KEY");

        var isConfigured = IsConfigured(serviceId, templateId, publicKey);
        if (!isConfigured)
        {
            _logger.LogInformation(
                "[EmailService] (Simulated Mode - Active: Configure EMAILJS_* in backend/.env to transmit live)\n" +
                "To: {CustomerEmail} ({CustomerName})\nSubject: {Subject}\nTemplate ID: {TemplateId}\nKey: {CacheKey}",
                customerEmail, customerName, subject, templateId ?? "Default", cacheKey);

            // Record into debounce cache
            _dispatchedCache[cacheKey] = DateTime.UtcNow;
            return true;
        }

        try
        {
            var payload = new Dictionary<string, object?>
            {
                ["service_id"] = serviceId,
                ["template_id"] = templateId,
                ["user_id"] = publicKey,
                ["template_params"] = templateParams
            };

            if (!string.IsNullOrWhiteSpace(privateKey) && !privateKey.Contains("optional", StringComparison.OrdinalIgnoreCase))
            {
                payload["accessToken"] = privateKey;
            }

            _logger.LogInformation("[EmailService] Dispatching email to {CustomerEmail} using Template: '{TemplateId}' (Subject: '{Subject}')",
                customerEmail, templateId ?? "Default", subject);

            var response = await _httpClient.PostAsJsonAsync("https://api.emailjs.com/api/v1.0/email/send", payload);
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("[EmailService] Notification successfully transmitted via EmailJS to {CustomerEmail} (Subject: '{Subject}')",
                    customerEmail, subject);
                _dispatchedCache[cacheKey] = DateTime.UtcNow;
                return true;
            }

            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("[EmailService] Failed to dispatch email via EmailJS (Status: {StatusCode}): {Error}",
                response.StatusCode, errorBody);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "[EmailService] Exception occurred while dispatching email to {CustomerEmail}", customerEmail);
            return false;
        }
    }

    #region Template Resolution

    private string? ResolveBuildTemplateId(string status)
    {
        // 1. Check granular event overrides
        if (status.Contains("Approve", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_BUILD_APPROVED_TEMPLATE_ID") ?? FallbackBuildWorkflowTemplateId();
        if (status.Contains("Change", StringComparison.OrdinalIgnoreCase) || status.Contains("Reject", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_BUILD_CHANGES_REQUESTED_TEMPLATE_ID") ?? FallbackBuildWorkflowTemplateId();
        if (status.Contains("Review", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_BUILD_IN_REVIEW_TEMPLATE_ID") ?? FallbackBuildWorkflowTemplateId();
        if (status.Contains("Cancel", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_BUILD_CANCELLED_TEMPLATE_ID") ?? FallbackBuildWorkflowTemplateId();
        if (status.Contains("Pending", StringComparison.OrdinalIgnoreCase) || status.Contains("Submit", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_BUILD_SUBMITTED_TEMPLATE_ID") ?? FallbackBuildWorkflowTemplateId();

        return FallbackBuildWorkflowTemplateId();
    }

    private string? FallbackBuildWorkflowTemplateId()
    {
        return GetConfigValue("EMAILJS_PC_BUILD_REVIEW_TEMPLATE_ID")
            ?? GetConfigValue("EMAILJS_BUILD_STATUS_TEMPLATE_ID")
            ?? GetConfigValue("EMAILJS_TEMPLATE_ID");
    }

    private string? ResolveOrderTemplateId(string status)
    {
        // 1. Check granular event overrides
        if (status.Equals("Order placed", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_ORDER_PLACED_TEMPLATE_ID") ?? FallbackOrderWorkflowTemplateId();
        if (status.Equals("Processing", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_ORDER_PROCESSING_TEMPLATE_ID") ?? FallbackOrderWorkflowTemplateId();
        if (status.Equals("Ready for pickup", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_ORDER_READY_PICKUP_TEMPLATE_ID") ?? FallbackOrderWorkflowTemplateId();
        if (status.Equals("Ready for delivery", StringComparison.OrdinalIgnoreCase) || status.Equals("Out for delivery", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_ORDER_OUT_FOR_DELIVERY_TEMPLATE_ID") ?? FallbackOrderWorkflowTemplateId();
        if (status.Contains("Completed", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_ORDER_COMPLETED_TEMPLATE_ID") ?? FallbackOrderWorkflowTemplateId();
        if (status.Contains("Cancel", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_ORDER_CANCELLED_TEMPLATE_ID") ?? FallbackOrderWorkflowTemplateId();

        return FallbackOrderWorkflowTemplateId();
    }

    private string? FallbackOrderWorkflowTemplateId()
    {
        return GetConfigValue("EMAILJS_ORDER_STATUS_TEMPLATE_ID")
            ?? GetConfigValue("EMAILJS_PC_BUILD_REVIEW_TEMPLATE_ID")
            ?? GetConfigValue("EMAILJS_TEMPLATE_ID");
    }

    private string? ResolveServiceTemplateId(string status)
    {
        // 1. Check granular event overrides
        if (status.Equals("Booked", StringComparison.OrdinalIgnoreCase) || status.Equals("Pending", StringComparison.OrdinalIgnoreCase) || status.Equals("Received", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_SERVICE_RECEIVED_TEMPLATE_ID") ?? FallbackServiceWorkflowTemplateId();
        if (status.Equals("In Progress", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_SERVICE_IN_PROGRESS_TEMPLATE_ID") ?? FallbackServiceWorkflowTemplateId();
        if (status.Equals("Completed", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_SERVICE_COMPLETED_TEMPLATE_ID") ?? FallbackServiceWorkflowTemplateId();
        if (status.Equals("Rejected", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_SERVICE_REJECTED_TEMPLATE_ID") ?? FallbackServiceWorkflowTemplateId();
        if (status.Contains("Cancel", StringComparison.OrdinalIgnoreCase))
            return GetConfigValue("EMAILJS_SERVICE_CANCELLED_TEMPLATE_ID") ?? FallbackServiceWorkflowTemplateId();

        return FallbackServiceWorkflowTemplateId();
    }

    private string? FallbackServiceWorkflowTemplateId()
    {
        var configured = GetConfigValue("EMAILJS_SERVICE_REQUEST_TEMPLATE_ID");
        if (!string.IsNullOrWhiteSpace(configured) && !configured.Equals("template_service_request", StringComparison.OrdinalIgnoreCase))
        {
            return configured;
        }

        return GetConfigValue("EMAILJS_PC_BUILD_REVIEW_TEMPLATE_ID")
            ?? GetConfigValue("EMAILJS_ORDER_STATUS_TEMPLATE_ID")
            ?? GetConfigValue("EMAILJS_TEMPLATE_ID");
    }

    private string? GetConfigValue(string key)
    {
        return _configuration[key]
            ?? _configuration[$"EmailJs:{key}"]
            ?? Environment.GetEnvironmentVariable(key);
    }

    #endregion

    #region Helpers

    private string GetWebBaseUrl()
    {
        return _configuration["WEB_URL"]
            ?? Environment.GetEnvironmentVariable("WEB_URL")
            ?? "https://pc-forge-admin.pages.dev";
    }

    private static bool IsDuplicateDispatch(string cacheKey)
    {
        var now = DateTime.UtcNow;

        // Clean stale entries occasionally
        if (_dispatchedCache.Count > 200)
        {
            foreach (var kvp in _dispatchedCache)
            {
                if (now - kvp.Value > DuplicateDebounceWindow)
                {
                    _dispatchedCache.TryRemove(kvp.Key, out _);
                }
            }
        }

        if (_dispatchedCache.TryGetValue(cacheKey, out var lastSent))
        {
            if (now - lastSent < DuplicateDebounceWindow)
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsValidEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email)) return false;
        var trimmed = email.Trim();
        if (trimmed.Length < 5 || !trimmed.Contains('@') || !trimmed.Contains('.')) return false;

        return Regex.IsMatch(trimmed, @"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.IgnoreCase);
    }

    private static bool IsConfigured(string? serviceId, string? templateId, string? publicKey)
    {
        if (string.IsNullOrWhiteSpace(serviceId) ||
            string.IsNullOrWhiteSpace(templateId) ||
            string.IsNullOrWhiteSpace(publicKey))
        {
            return false;
        }

        var dummyPatterns = new[] { "your_", "placeholder", "dummy", "change_me", "xxx" };
        if (dummyPatterns.Any(p => serviceId.Contains(p, StringComparison.OrdinalIgnoreCase) ||
                                   templateId.Contains(p, StringComparison.OrdinalIgnoreCase) ||
                                   publicKey.Contains(p, StringComparison.OrdinalIgnoreCase)))
        {
            return false;
        }

        return true;
    }

    #endregion
}
