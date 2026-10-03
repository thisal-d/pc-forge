using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;
using PCForge.Api.Services;

namespace PCForge.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class SupportTicketsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IAiAgentService _aiAgentService;
    private readonly ILogger<SupportTicketsController> _logger;

    public SupportTicketsController(AppDbContext context, IAiAgentService aiAgentService, ILogger<SupportTicketsController> logger)
    {
        _context = context;
        _aiAgentService = aiAgentService;
        _logger = logger;
    }

    /// <summary>
    /// Executes Member 05 After-Sales Agent to answer warranty/order inquiries and open RMA tickets (UI 8).
    /// </summary>
    [AllowAnonymous]
    [HttpPost("ai-chat")]
    public async Task<ActionResult<AfterSalesChatResponseDto>> AfterSalesChat([FromBody] AfterSalesChatRequestDto request)
    {
        var currentUserId = GetCurrentUserId() ?? 1;
        request.UserId = currentUserId;

        var result = await _aiAgentService.SendAfterSalesChatMessageAsync(request);
        if (!result.Success)
        {
            return StatusCode(500, result);
        }

        return Ok(result);
    }

    /// <summary>
    /// Open a new manual Support / RMA Ticket (Scenario 3 in the project story).
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<SupportTicketDetailDto>> CreateTicket([FromBody] CreateSupportTicketDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        // 1. Resolve User ID
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized(new { message = "Authentication required to create a support ticket." });
        }
        int userId = currentUserId.Value;

        // 2. Validate linked Order (if provided)
        Product? linkedProduct = null;
        if (dto.OrderId.HasValue && dto.OrderId.Value > 0)
        {
            var order = await _context.Orders
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                .FirstOrDefaultAsync(o => o.OrderId == dto.OrderId.Value);

            if (order != null)
            {
                if (dto.ProductId.HasValue && dto.ProductId.Value > 0)
                {
                    linkedProduct = order.Items.FirstOrDefault(i => i.ProductId == dto.ProductId.Value)?.Product;
                }
                else if (order.Items.Count > 0)
                {
                    linkedProduct = order.Items.First().Product;
                }
            }
        }
        else if (dto.ProductId.HasValue && dto.ProductId.Value > 0)
        {
            linkedProduct = await _context.Products.FindAsync(dto.ProductId.Value);
        }

        // 3. Create Ticket record
        var ticket = new SupportTicket
        {
            UserId = userId,
            OrderId = dto.OrderId,
            ProductId = linkedProduct?.ProductId ?? dto.ProductId,
            IssueType = dto.IssueType.Trim(),
            Subject = dto.Subject.Trim(),
            Description = dto.Description.Trim(),
            AttachmentUrl = dto.AttachmentUrl,
            Status = "Open",
            Priority = dto.IssueType.Contains("Overheating") || dto.IssueType.Contains("Failure") ? "High" : "Normal",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.SupportTickets.Add(ticket);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Support Ticket #{TicketId} opened for User {UserId}: '{Subject}'",
            ticket.TicketId, userId, ticket.Subject);

        var response = new SupportTicketDetailDto
        {
            TicketId = ticket.TicketId,
            UserId = ticket.UserId,
            OrderId = ticket.OrderId,
            ProductId = ticket.ProductId,
            ProductName = linkedProduct?.Name,
            IssueType = ticket.IssueType,
            Subject = ticket.Subject,
            Description = ticket.Description,
            AttachmentUrl = ticket.AttachmentUrl,
            Status = ticket.Status,
            Priority = ticket.Priority,
            ResolutionNotes = ticket.ResolutionNotes,
            CreatedAt = ticket.CreatedAt,
            UpdatedAt = ticket.UpdatedAt
        };

        return CreatedAtAction(nameof(GetTicketById), new { id = ticket.TicketId }, response);
    }

    /// <summary>
    /// Retrieve customer's support tickets.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<SupportTicketSummaryDto>>> GetTickets()
    {
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized();
        }

        var isStaffOrAdmin = User.IsInRole("Admin") || User.IsInRole("Staff");
        var query = _context.SupportTickets
            .AsNoTracking()
            .Include(t => t.Product)
            .Include(t => t.User)
            .Include(t => t.AssignedStaff)
            .ThenInclude(s => s!.User);

        IQueryable<SupportTicket> filtered = query;
        if (!isStaffOrAdmin)
        {
            filtered = filtered.Where(t => t.UserId == currentUserId.Value);
        }

        var tickets = await filtered
            .OrderByDescending(t => t.CreatedAt)
            .Select(t => new SupportTicketSummaryDto
            {
                TicketId = t.TicketId,
                UserId = t.UserId,
                CustomerName = t.User != null ? $"{t.User.FirstName} {t.User.LastName}".Trim() : null,
                CustomerEmail = t.User != null ? t.User.Email : null,
                OrderId = t.OrderId,
                ProductName = t.Product != null ? t.Product.Name : null,
                IssueType = t.IssueType,
                Subject = t.Subject,
                Status = t.Status,
                Priority = t.Priority,
                AssignedStaffId = t.AssignedStaffId,
                AssignedStaffName = t.AssignedStaff != null && t.AssignedStaff.User != null
                    ? $"{t.AssignedStaff.User.FirstName} {t.AssignedStaff.User.LastName}".Trim()
                    : null,
                CreatedAt = t.CreatedAt
            })
            .ToListAsync();

        return Ok(tickets);
    }

    /// <summary>
    /// Retrieve specific ticket details.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<SupportTicketDetailDto>> GetTicketById(int id)
    {
        var ticket = await _context.SupportTickets
            .AsNoTracking()
            .Include(t => t.Product)
            .Include(t => t.User)
            .Include(t => t.AssignedStaff)
            .ThenInclude(s => s!.User)
            .FirstOrDefaultAsync(t => t.TicketId == id);

        if (ticket == null)
        {
            return NotFound(new { message = $"Support Ticket #{id} not found." });
        }

        var currentUserId = GetCurrentUserId();
        var isStaffOrAdmin = User.IsInRole("Admin") || User.IsInRole("Staff");
        if (!isStaffOrAdmin && ticket.UserId != currentUserId)
        {
            return Forbid();
        }

        return Ok(new SupportTicketDetailDto
        {
            TicketId = ticket.TicketId,
            UserId = ticket.UserId,
            CustomerName = ticket.User != null ? $"{ticket.User.FirstName} {ticket.User.LastName}".Trim() : null,
            CustomerEmail = ticket.User != null ? ticket.User.Email : null,
            OrderId = ticket.OrderId,
            ProductId = ticket.ProductId,
            ProductName = ticket.Product?.Name,
            IssueType = ticket.IssueType,
            Subject = ticket.Subject,
            Description = ticket.Description,
            AttachmentUrl = ticket.AttachmentUrl,
            Status = ticket.Status,
            Priority = ticket.Priority,
            ResolutionNotes = ticket.ResolutionNotes,
            AssignedStaffId = ticket.AssignedStaffId,
            AssignedStaffName = ticket.AssignedStaff != null && ticket.AssignedStaff.User != null
                ? $"{ticket.AssignedStaff.User.FirstName} {ticket.AssignedStaff.User.LastName}".Trim()
                : null,
            CreatedAt = ticket.CreatedAt,
            UpdatedAt = ticket.UpdatedAt
        });
    }

    /// <summary>
    /// Update support ticket status, priority, resolution notes, or assigned staff.
    /// </summary>
    [Authorize(Policy = "StaffOnly")]
    [HttpPut("{id:int}")]
    public async Task<ActionResult<SupportTicketDetailDto>> UpdateTicket(int id, [FromBody] UpdateSupportTicketDto dto)
    {
        var ticket = await _context.SupportTickets
            .Include(t => t.Product)
            .Include(t => t.User)
            .Include(t => t.AssignedStaff)
            .ThenInclude(s => s!.User)
            .FirstOrDefaultAsync(t => t.TicketId == id);

        if (ticket == null)
        {
            return NotFound(new { message = $"Support Ticket #{id} not found." });
        }

        if (!string.IsNullOrWhiteSpace(dto.Status)) ticket.Status = dto.Status.Trim();
        if (!string.IsNullOrWhiteSpace(dto.Priority)) ticket.Priority = dto.Priority.Trim();
        if (dto.ResolutionNotes != null) ticket.ResolutionNotes = dto.ResolutionNotes.Trim();
        if (dto.AssignedStaffId.HasValue) ticket.AssignedStaffId = dto.AssignedStaffId.Value;
        ticket.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Support ticket #{TicketId} updated by staff: Status={Status}, Priority={Priority}",
            ticket.TicketId, ticket.Status, ticket.Priority);

        return Ok(new SupportTicketDetailDto
        {
            TicketId = ticket.TicketId,
            UserId = ticket.UserId,
            CustomerName = ticket.User != null ? $"{ticket.User.FirstName} {ticket.User.LastName}".Trim() : null,
            CustomerEmail = ticket.User != null ? ticket.User.Email : null,
            OrderId = ticket.OrderId,
            ProductId = ticket.ProductId,
            ProductName = ticket.Product?.Name,
            IssueType = ticket.IssueType,
            Subject = ticket.Subject,
            Description = ticket.Description,
            AttachmentUrl = ticket.AttachmentUrl,
            Status = ticket.Status,
            Priority = ticket.Priority,
            ResolutionNotes = ticket.ResolutionNotes,
            AssignedStaffId = ticket.AssignedStaffId,
            AssignedStaffName = ticket.AssignedStaff != null && ticket.AssignedStaff.User != null
                ? $"{ticket.AssignedStaff.User.FirstName} {ticket.AssignedStaff.User.LastName}".Trim()
                : null,
            CreatedAt = ticket.CreatedAt,
            UpdatedAt = ticket.UpdatedAt
        });
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier) ?? User.FindFirst("sub") ?? User.FindFirst("userId");
        if (claim != null && int.TryParse(claim.Value, out int id))
        {
            return id;
        }
        return null;
    }
}
