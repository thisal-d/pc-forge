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
            Priority = "Normal",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.SupportTickets.Add(ticket);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Support ticket #{TicketId} created by user {UserId}: '{Subject}'",
            ticket.TicketId, userId, ticket.Subject);

        // 4. Return detailed DTO
        var user = await _context.Users.FindAsync(userId);
        return CreatedAtAction(nameof(GetTicketById), new { id = ticket.TicketId }, new SupportTicketDetailDto
        {
            TicketId = ticket.TicketId,
            UserId = ticket.UserId,
            CustomerName = user != null ? $"{user.FirstName} {user.LastName}".Trim() : null,
            CustomerEmail = user?.Email,
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
        });
    }

    /// <summary>
    /// Retrieve ticket list: filtered to current user if customer, full list if staff.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<SupportTicketSummaryDto>>> GetTickets(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null,
        [FromQuery] string? priority = null)
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
    /// Retrieve single ticket details by ID.
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
        var isStaff = User.IsInRole("Admin") || User.IsInRole("Staff");
        if (!isStaff && ticket.UserId != currentUserId)
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
