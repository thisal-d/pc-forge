using System.Net.Http.Json;

namespace PCForge.Api.Services;

public class EmailService : IEmailService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    public EmailService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<EmailService> logger)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<bool> SendBuildReviewNotificationAsync(
        string customerEmail,
        string customerName,
        int buildId,
        string buildName,
        string newStatus,
        string? technicianNotes,
        decimal totalPrice)
    {
        if (string.IsNullOrWhiteSpace(customerEmail))
        {
            _logger.LogWarning("[EmailService] Notification skipped: customer email is not provided.");
            return false;
        }

        var serviceId = _configuration["EMAILJS_SERVICE_ID"]
            ?? _configuration["EmailJs:ServiceId"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_SERVICE_ID");

        var templateId = _configuration["EMAILJS_TEMPLATE_ID"]
            ?? _configuration["EmailJs:TemplateId"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_TEMPLATE_ID");

        var publicKey = _configuration["EMAILJS_PUBLIC_KEY"]
            ?? _configuration["EmailJs:PublicKey"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_PUBLIC_KEY");

        var privateKey = _configuration["EMAILJS_PRIVATE_KEY"]
            ?? _configuration["EmailJs:PrivateKey"]
            ?? Environment.GetEnvironmentVariable("EMAILJS_PRIVATE_KEY");

        var isApproved = string.Equals(newStatus, "Approved by Staff", StringComparison.OrdinalIgnoreCase);
        var statusBadge = isApproved ? "APPROVED" : "CHANGES REQUESTED";
        var subject = isApproved
            ? $"PCForge: Your Custom PC Build #{buildId} has been Approved!"
            : $"PCForge: Modifications Requested for Build #{buildId}";

        var notes = !string.IsNullOrWhiteSpace(technicianNotes)
            ? technicianNotes
            : (isApproved ? "All checks passed. Cleared for assembly." : "Adjustments needed.");

        var message = isApproved
            ? $"Great news! Our certified technicians have reviewed and approved your custom PC build \"{buildName}\" (Build #{buildId}). All component clearances, power envelopes, and thermal metrics have passed verification. Your build is now cleared for assembly!"
            : $"Our technicians have reviewed your custom PC build \"{buildName}\" (Build #{buildId}) and requested some adjustments. Please check the technician feedback notes below and update your configuration in the PCForge app.";

        var webUrl = _configuration["WEB_URL"]
            ?? Environment.GetEnvironmentVariable("WEB_URL")
            ?? "http://localhost:5173";

        var templateParams = new Dictionary<string, string>
        {
            ["to_name"] = customerName,
            ["to_email"] = customerEmail,
            ["customer_name"] = customerName,
            ["customer_email"] = customerEmail,
            ["build_id"] = buildId.ToString(),
            ["build_name"] = buildName,
            ["status"] = newStatus,
            ["review_status"] = statusBadge,
            ["subject"] = subject,
            ["technician_notes"] = notes,
            ["staff_notes"] = notes,
            ["total_price"] = $"LKR {totalPrice:F2}",
            ["message"] = message,
            ["action_url"] = $"{webUrl}/builds"
        };

        var isConfigured = IsConfigured(serviceId, templateId, publicKey);
        if (!isConfigured)
        {
            _logger.LogInformation(
                "[EmailService] (Simulated Mode - Configure EMAILJS_* keys in backend/.env to transmit live)\n" +
                "To: {CustomerEmail} ({CustomerName})\nSubject: {Subject}\nStatus: {Status}\nNotes: {Notes}",
                customerEmail, customerName, subject, newStatus, notes);
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

            if (!string.IsNullOrWhiteSpace(privateKey))
            {
                payload["accessToken"] = privateKey;
            }

            var response = await _httpClient.PostAsJsonAsync("https://api.emailjs.com/api/v1.0/email/send", payload);
            if (response.IsSuccessStatusCode)
            {
                _logger.LogInformation("[EmailService] Notification successfully sent to {CustomerEmail} for Build #{BuildId}", customerEmail, buildId);
                return true;
            }

            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("[EmailService] Failed to dispatch email via EmailJS (Status: {StatusCode}): {Error}", response.StatusCode, errorBody);
            return false;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "[EmailService] Exception occurred while dispatching email to {CustomerEmail}", customerEmail);
            return false;
        }
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
}
