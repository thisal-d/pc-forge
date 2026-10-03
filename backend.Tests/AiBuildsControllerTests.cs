using System.Net;
using System.Net.Http.Json;
using PCForge.Api.DTOs;

namespace backend.Tests;

public class AiBuildsControllerTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly HttpClient _client;

    public AiBuildsControllerTests(CustomWebApplicationFactory factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task StartRequirementSession_ShouldReturnNewSessionIdAndGreeting()
    {
        var response = await _client.PostAsync("/api/aibuilds/requirement-session/start", null);
        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<RequirementSessionStartResponseDto>();
        Assert.NotNull(result);
        Assert.False(string.IsNullOrWhiteSpace(result.SessionId));
        Assert.Contains("PCForge AI Architect", result.GreetingMessage);
    }

    [Fact]
    public async Task SendRequirementMessage_ShouldUpdateSessionAndReturnExtractedProfile()
    {
        // 1. Start session
        var startResp = await _client.PostAsync("/api/aibuilds/requirement-session/start", null);
        startResp.EnsureSuccessStatusCode();
        var session = await startResp.Content.ReadFromJsonAsync<RequirementSessionStartResponseDto>();
        Assert.NotNull(session);

        // 2. Turn 1: "I want a gaming PC for Rs. 400,000"
        var chatResp1 = await _client.PostAsJsonAsync(
            $"/api/aibuilds/requirement-session/{session.SessionId}/message",
            new RequirementChatRequestDto { Message = "I want a gaming PC for Rs. 400,000" }
        );
        chatResp1.EnsureSuccessStatusCode();
        var chat1 = await chatResp1.Content.ReadFromJsonAsync<RequirementChatResponseDto>();
        Assert.NotNull(chat1);
        Assert.Equal("Gaming", chat1.Profile.Purpose);
        Assert.Equal(400000m, chat1.Profile.BudgetAmount);

        // 3. Turn 2: "1440p, and I already have a monitor"
        var chatResp2 = await _client.PostAsJsonAsync(
            $"/api/aibuilds/requirement-session/{session.SessionId}/message",
            new RequirementChatRequestDto { Message = "1440p, and I already have a monitor" }
        );
        chatResp2.EnsureSuccessStatusCode();
        var chat2 = await chatResp2.Content.ReadFromJsonAsync<RequirementChatResponseDto>();
        Assert.NotNull(chat2);
        Assert.True(chat2.IsComplete);
        Assert.Equal("1440p", chat2.Profile.TargetResolution);
        Assert.False(chat2.Profile.MonitorNeeded);

        // 4. Retrieve session by ID
        var getResp = await _client.GetAsync($"/api/aibuilds/requirement-session/{session.SessionId}");
        getResp.EnsureSuccessStatusCode();
        var getResult = await getResp.Content.ReadFromJsonAsync<RequirementChatResponseDto>();
        Assert.NotNull(getResult);
        Assert.True(getResult.IsComplete);
        Assert.Equal("Gaming", getResult.Profile.Purpose);
    }
}
