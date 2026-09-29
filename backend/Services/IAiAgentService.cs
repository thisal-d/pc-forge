using PCForge.Api.DTOs;

namespace PCForge.Api.Services;

public interface IAiAgentService
{
    Task<RequirementChatResponseDto> SendRequirementChatMessageAsync(string sessionId, string message);
    Task<RequirementChatResponseDto?> GetRequirementSessionAsync(string sessionId);
    Task<BuildGenerationResponseDto> GenerateBuildAsync(BuildGenerationRequestDto request);
    Task<StockVerificationResponseDto> VerifyBuildStockAsync(StockVerificationRequestDto request);
    Task<OrderProposalResponseDto> CreateOrderProposalAsync(OrderPlanningRequestDto request);
    Task<AfterSalesChatResponseDto> SendAfterSalesChatMessageAsync(AfterSalesChatRequestDto request);
}

