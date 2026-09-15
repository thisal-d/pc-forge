namespace PCForge.Api.Models;

public class RequirementSession
{
    public string SessionId { get; set; } = Guid.NewGuid().ToString();
    public int? UserId { get; set; }
    public string? Purpose { get; set; }
    public decimal? BudgetAmount { get; set; }
    public string? BudgetRaw { get; set; }
    public string Currency { get; set; } = "LKR";
    public string? TargetResolution { get; set; }
    public bool? MonitorNeeded { get; set; }
    public string? PreferencesJson { get; set; }
    public bool IsComplete { get; set; } = false;
    public string Status { get; set; } = "Gathering"; // 'Gathering', 'ReadyForBuild', 'BuildGenerated'
    public string? RawAnswersJson { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
}
