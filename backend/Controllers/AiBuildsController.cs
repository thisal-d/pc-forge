using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;
using PCForge.Api.Services;

namespace PCForge.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AiBuildsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IAiAgentService _aiAgentService;
    private readonly ILogger<AiBuildsController> _logger;

    public AiBuildsController(AppDbContext context, IAiAgentService aiAgentService, ILogger<AiBuildsController> logger)
    {
        _context = context;
        _aiAgentService = aiAgentService;
        _logger = logger;
    }

    /// <summary>
    /// Starts a new AI requirement gathering session (Member 01 Agent).
    /// </summary>
    [HttpPost("requirement-session/start")]
    public async Task<ActionResult<RequirementSessionStartResponseDto>> StartRequirementSession()
    {
        var userId = GetCurrentUserId();
        var sessionId = Guid.NewGuid().ToString("N");

        var session = new RequirementSession
        {
            SessionId = sessionId,
            UserId = userId,
            Status = "Gathering",
            IsComplete = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.RequirementSessions.Add(session);
        await _context.SaveChangesAsync();

        return Ok(new RequirementSessionStartResponseDto
        {
            SessionId = sessionId,
            GreetingMessage = "Hi! I'm your PCForge AI Architect. Tell me what kind of PC you're looking for, your budget, and what games or applications you'll run.",
            Profile = new RequirementProfileDto()
        });
    }

    /// <summary>
    /// Sends a customer message to the Requirement Discovery Agent and receives updated profile & reply.
    /// </summary>
    [HttpPost("requirement-session/{sessionId}/message")]
    public async Task<ActionResult<RequirementChatResponseDto>> SendRequirementMessage(
        string sessionId,
        [FromBody] RequirementChatRequestDto request)
    {
        if (string.IsNullOrWhiteSpace(request.Message))
        {
            return BadRequest(new { message = "Message cannot be empty." });
        }

        var session = await _context.RequirementSessions.FirstOrDefaultAsync(s => s.SessionId == sessionId);
        if (session == null)
        {
            // Auto-create session if starting directly with an ID
            var userId = GetCurrentUserId();
            session = new RequirementSession
            {
                SessionId = sessionId,
                UserId = userId,
                Status = "Gathering",
                IsComplete = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.RequirementSessions.Add(session);
        }

        // Call the internal Agentic AI Service
        var agentResponse = await _aiAgentService.SendRequirementChatMessageAsync(sessionId, request.Message);

        if (agentResponse.Status == "error")
        {
            return Ok(agentResponse);
        }

        // Update stored requirement profile in DB
        session.Purpose = agentResponse.Profile.Purpose ?? session.Purpose;
        if (agentResponse.Profile.BudgetAmount.HasValue)
        {
            session.BudgetAmount = agentResponse.Profile.BudgetAmount.Value;
        }
        session.BudgetRaw = agentResponse.Profile.BudgetRaw ?? session.BudgetRaw;
        session.Currency = agentResponse.Profile.Currency ?? session.Currency;
        session.TargetResolution = agentResponse.Profile.TargetResolution ?? session.TargetResolution;
        if (agentResponse.Profile.MonitorNeeded.HasValue)
        {
            session.MonitorNeeded = agentResponse.Profile.MonitorNeeded.Value;
        }
        if (agentResponse.Profile.Preferences != null && agentResponse.Profile.Preferences.Count > 0)
        {
            session.PreferencesJson = JsonSerializer.Serialize(agentResponse.Profile.Preferences);
        }

        session.IsComplete = agentResponse.IsComplete || (!string.IsNullOrEmpty(session.Purpose) && session.BudgetAmount.HasValue && !string.IsNullOrEmpty(session.TargetResolution));
        session.Status = session.IsComplete ? "ReadyForBuild" : "Gathering";
        session.UpdatedAt = DateTime.UtcNow;

        // Ensure returned DTO reflects full aggregated DB state across conversation turns
        agentResponse.Profile.Purpose = session.Purpose;
        agentResponse.Profile.BudgetAmount = session.BudgetAmount;
        agentResponse.Profile.BudgetRaw = session.BudgetRaw;
        agentResponse.Profile.Currency = session.Currency ?? agentResponse.Profile.Currency;
        agentResponse.Profile.TargetResolution = session.TargetResolution;
        agentResponse.Profile.MonitorNeeded = session.MonitorNeeded;
        agentResponse.IsComplete = session.IsComplete;
        agentResponse.Status = session.Status;

        await _context.SaveChangesAsync();

        return Ok(agentResponse);
    }

    /// <summary>
    /// Retrieves current profile snapshot for a requirement session.
    /// </summary>
    [HttpGet("requirement-session/{sessionId}")]
    public async Task<ActionResult<RequirementChatResponseDto>> GetRequirementSession(string sessionId)
    {
        var session = await _context.RequirementSessions.FirstOrDefaultAsync(s => s.SessionId == sessionId);
        if (session == null)
        {
            return NotFound(new { message = "Session not found." });
        }

        var preferences = new List<string>();
        if (!string.IsNullOrEmpty(session.PreferencesJson))
        {
            try
            {
                preferences = JsonSerializer.Deserialize<List<string>>(session.PreferencesJson) ?? new();
            }
            catch { }
        }

        var profileDto = new RequirementProfileDto
        {
            Purpose = session.Purpose,
            BudgetAmount = session.BudgetAmount,
            BudgetRaw = session.BudgetRaw,
            Currency = session.Currency,
            TargetResolution = session.TargetResolution,
            MonitorNeeded = session.MonitorNeeded,
            Preferences = preferences,
            IsComplete = session.IsComplete
        };

        return Ok(new RequirementChatResponseDto
        {
            SessionId = session.SessionId,
            Reply = session.IsComplete ? "Requirement profile is ready." : "Requirement gathering in progress.",
            Profile = profileDto,
            IsComplete = session.IsComplete,
            Status = session.Status
        });
    }

    /// <summary>
    /// Executes Member 03's PC Build & Compatibility Agent.
    /// Can be invoked with an existing session_id (hydrating profile from DB) or direct parameters.
    /// </summary>
    [HttpPost("generate-build")]
    public async Task<ActionResult<BuildGenerationResponseDto>> GenerateBuild([FromBody] BuildGenerationRequestDto request)
    {
        // If sessionId is provided, hydrate missing fields from session
        if (!string.IsNullOrWhiteSpace(request.SessionId))
        {
            var session = await _context.RequirementSessions.FirstOrDefaultAsync(s => s.SessionId == request.SessionId);
            if (session != null)
            {
                if (!string.IsNullOrWhiteSpace(session.Purpose)) request.Purpose = session.Purpose;
                if (session.BudgetAmount.HasValue && session.BudgetAmount.Value > 0) request.BudgetAmount = session.BudgetAmount.Value;
                if (!string.IsNullOrWhiteSpace(session.Currency)) request.Currency = session.Currency;
                if (!string.IsNullOrWhiteSpace(session.TargetResolution)) request.TargetResolution = session.TargetResolution;
            }
        }

        var result = await _aiAgentService.GenerateBuildAsync(request);
        if (!result.Success)
        {
            return StatusCode(500, result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Executes Member 02's Inventory Agent.
    /// Verifies real shelf stock for all 8 components, applies substitutes if any are out of stock,
    /// and locks a 15-minute reservation hold.
    /// </summary>
    [HttpPost("verify-stock")]
    public async Task<ActionResult<StockVerificationResponseDto>> VerifyStock([FromBody] StockVerificationRequestDto request)
    {
        var result = await _aiAgentService.VerifyBuildStockAsync(request);
        if (!result.Success)
        {
            return StatusCode(500, result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Executes Member 04's Order Planning Agent to price the build and produce proposal (UI 4).
    /// </summary>
    [HttpPost("order-proposal")]
    public async Task<ActionResult<OrderProposalResponseDto>> CreateOrderProposal([FromBody] OrderPlanningRequestDto request)
    {
        var result = await _aiAgentService.CreateOrderProposalAsync(request);
        if (!result.Success)
        {
            return StatusCode(500, result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Saves customer-approved order proposal to backend database with status 'Pending Staff Review' (UI 5).
    /// Does NOT charge customer; awaits React staff technician sign-off.
    /// </summary>
    [HttpPost("submit-approved-order")]
    public async Task<ActionResult<SubmitApprovedOrderResponseDto>> SubmitApprovedOrder([FromBody] SubmitApprovedOrderRequestDto request)
    {
        var userId = GetCurrentUserId() ?? 1;

        // Create CustomBuild record so it appears on the Technician Review Workbench (/build-reviews)
        var customBuild = new CustomBuild
        {
            UserId = userId,
            BuildName = string.IsNullOrWhiteSpace(request.BuildName) ? $"AI Build #{request.OrderNumber}" : request.BuildName,
            TotalPrice = request.TotalAmount,
            EstimatedWattage = 450,
            Status = "Pending Staff Review",
            CustomerNotes = $"AI Order Proposal #{request.OrderNumber} approved by customer. Reservation ID: {request.ReservationId}. Destination: {request.ShippingAddress}",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        if (request.Components != null)
        {
            foreach (var comp in request.Components)
            {
                if (comp.ProductId > 0)
                {
                    customBuild.Items.Add(new CustomBuildItem
                    {
                        ProductId = comp.ProductId,
                        SlotType = string.IsNullOrWhiteSpace(comp.Slot) ? "component" : comp.Slot,
                        UnitPrice = comp.UnitPrice
                    });
                }
            }
        }

        _context.CustomBuilds.Add(customBuild);
        await _context.SaveChangesAsync();

        var response = new SubmitApprovedOrderResponseDto
        {
            Success = true,
            OrderNumber = request.OrderNumber,
            Status = "Pending technician review",
            FormattedTotal = request.FormattedTotal,
            Message = "We'll notify you once a technician has checked your build — usually within a few hours.",
            CreatedAt = DateTime.UtcNow
        };

        return Ok(response);
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return int.TryParse(claim, out var id) ? id : null;
    }
}

