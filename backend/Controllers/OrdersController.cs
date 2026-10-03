using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(AppDbContext context, ILogger<OrdersController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Place a new order with stock validation and inventory deduction.
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<OrderDetailDto>> CreateOrder([FromBody] CreateOrderDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        if (dto.Items == null || dto.Items.Count == 0)
        {
            return BadRequest(new { message = "Order must contain at least one product." });
        }

        // 1. Resolve User ID from authenticated claim
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized(new { message = "Authentication required to place an order." });
        }
        int userId = currentUserId.Value;

        // 2. Load all requested products
        var productIds = dto.Items.Select(i => i.ProductId).Distinct().ToList();
        var products = await _context.Products
            .Where(p => productIds.Contains(p.ProductId))
            .ToDictionaryAsync(p => p.ProductId);

        // 3. Stock Validation & Total Calculation
        decimal totalAmount = 0;
        var orderItems = new List<OrderItem>();

        foreach (var itemDto in dto.Items)
        {
            if (!products.TryGetValue(itemDto.ProductId, out var product))
            {
                return BadRequest(new { message = $"Product with ID {itemDto.ProductId} was not found." });
            }

            if (product.StockQuantity < itemDto.Quantity)
            {
                return BadRequest(new
                {
                    message = $"Insufficient stock for '{product.Name}'. Available: {product.StockQuantity}, Requested: {itemDto.Quantity}"
                });
            }

            // Reserve & deduct inventory
            product.StockQuantity -= itemDto.Quantity;
            product.UpdatedAt = DateTime.UtcNow;

            totalAmount += product.Price * itemDto.Quantity;

            orderItems.Add(new OrderItem
            {
                ProductId = product.ProductId,
                Quantity = itemDto.Quantity,
                UnitPrice = product.Price
            });
        }

        // 4. Create and Save Order
        var order = new Order
        {
            UserId = userId,
            TotalAmount = totalAmount,
            Status = "Paid", // Simulated successful checkout
            ShippingAddress = dto.ShippingAddress.Trim(),
            PaymentMethod = dto.PaymentMethod,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Items = orderItems
        };

        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Order #{OrderId} placed successfully for User {UserId}, Total: {TotalAmount:C}",
            order.OrderId, userId, totalAmount);

        // 5. Load User info for response
        var user = await _context.Users.FindAsync(userId);
        var customerName = user != null ? $"{user.FirstName} {user.LastName}".Trim() : "";
        if (string.IsNullOrEmpty(customerName)) customerName = user?.Email ?? "";
        var customerEmail = user?.Email ?? "";

        var response = new OrderDetailDto
        {
            OrderId = order.OrderId,
            UserId = order.UserId,
            CustomerName = customerName,
            CustomerEmail = customerEmail,
            TotalAmount = order.TotalAmount,
            Status = order.Status,
            ShippingAddress = order.ShippingAddress,
            PaymentMethod = order.PaymentMethod,
            CreatedAt = order.CreatedAt,
            UpdatedAt = order.UpdatedAt,
            Items = order.Items.Select(oi =>
            {
                var prod = products[oi.ProductId];
                return new OrderItemDetailDto
                {
                    OrderItemId = oi.OrderItemId,
                    ProductId = oi.ProductId,
                    ProductName = prod.Name,
                    Brand = prod.Brand,
                    Model = prod.Model,
                    ImageUrl = prod.ImageUrl,
                    Quantity = oi.Quantity,
                    UnitPrice = oi.UnitPrice
                };
            }).ToList()
        };

        return CreatedAtAction(nameof(GetOrderById), new { id = order.OrderId }, response);
    }

    /// <summary>
    /// Retrieve order history with optional filtering and search (for Admin/Staff or Customer).
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<OrderSummaryDto>>> GetOrders(
        [FromQuery] string? status = null,
        [FromQuery] string? search = null)
    {
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized();
        }

        var isStaffOrAdmin = IsStaffOrAdmin();
        var query = _context.Orders.AsNoTracking().Include(o => o.User).AsQueryable();
        if (!isStaffOrAdmin)
        {
            query = query.Where(o => o.UserId == currentUserId.Value);
        }

        if (!string.IsNullOrWhiteSpace(status) && !status.Equals("all", StringComparison.OrdinalIgnoreCase))
        {
            var cleanStatus = status.Trim().ToLower();
            query = query.Where(o => o.Status.ToLower() == cleanStatus);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var q = search.Trim().ToLower();
            query = query.Where(o =>
                o.OrderId.ToString().Contains(q) ||
                (o.ShippingAddress != null && o.ShippingAddress.ToLower().Contains(q)) ||
                (o.User != null && (
                    o.User.Email.ToLower().Contains(q) ||
                    (o.User.FirstName != null && o.User.FirstName.ToLower().Contains(q)) ||
                    (o.User.LastName != null && o.User.LastName.ToLower().Contains(q))
                ))
            );
        }

        var orders = await query
            .OrderByDescending(o => o.CreatedAt)
            .Select(o => new OrderSummaryDto
            {
                OrderId = o.OrderId,
                UserId = o.UserId,
                CustomerName = o.User != null
                    ? (((o.User.FirstName ?? "") + " " + (o.User.LastName ?? "")).Trim().Length > 0
                        ? ((o.User.FirstName ?? "") + " " + (o.User.LastName ?? "")).Trim()
                        : o.User.Email)
                    : "",
                CustomerEmail = o.User != null ? o.User.Email : "",
                TotalAmount = o.TotalAmount,
                Status = o.Status,
                ShippingAddress = o.ShippingAddress,
                PaymentMethod = o.PaymentMethod,
                CreatedAt = o.CreatedAt,
                UpdatedAt = o.UpdatedAt,
                ItemCount = o.Items.Sum(i => i.Quantity)
            })
            .ToListAsync();

        return Ok(orders);
    }

    /// <summary>
    /// Retrieve specific order details by ID.
    /// </summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDetailDto>> GetOrderById(int id)
    {
        var order = await _context.Orders
            .AsNoTracking()
            .Include(o => o.User)
            .Include(o => o.Items)
            .ThenInclude(i => i.Product)
            .FirstOrDefaultAsync(o => o.OrderId == id);

        if (order == null)
        {
            return NotFound(new { message = $"Order #{id} not found." });
        }

        var currentUserId = GetCurrentUserId();
        var isStaffOrAdmin = IsStaffOrAdmin();
        if (!isStaffOrAdmin && order.UserId != currentUserId)
        {
            return Forbid();
        }

        return Ok(MapToDetailDto(order));
    }

    /// <summary>
    /// Update order fulfillment status (Admin / Staff only).
    /// Handles automatic inventory restocking when an order is cancelled.
    /// </summary>
    [HttpPatch("{id:int}/status")]
    [Authorize(Policy = "StaffOnly")]
    public async Task<ActionResult<OrderDetailDto>> UpdateOrderStatus(int id, [FromBody] UpdateOrderStatusDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var allowedStatuses = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "Pending", "Paid", "Processing", "Shipped", "Delivered", "Cancelled"
        };

        var normalizedStatus = dto.Status.Trim();
        var canonicalStatus = allowedStatuses.FirstOrDefault(s => s.Equals(normalizedStatus, StringComparison.OrdinalIgnoreCase));
        if (canonicalStatus == null)
        {
            return BadRequest(new { message = $"Invalid status '{dto.Status}'. Allowed: {string.Join(", ", allowedStatuses)}" });
        }

        var order = await _context.Orders
            .Include(o => o.User)
            .Include(o => o.Items)
            .ThenInclude(i => i.Product)
            .FirstOrDefaultAsync(o => o.OrderId == id);

        if (order == null)
        {
            return NotFound(new { message = $"Order #{id} not found." });
        }

        var previousStatus = order.Status;

        // If status isn't changing, return current
        if (previousStatus.Equals(canonicalStatus, StringComparison.OrdinalIgnoreCase))
        {
            return Ok(MapToDetailDto(order));
        }

        // 1. If transitioning TO "Cancelled" from another status -> Restock inventory
        if (canonicalStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) &&
            !previousStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var item in order.Items)
            {
                if (item.Product != null)
                {
                    item.Product.StockQuantity += item.Quantity;
                    item.Product.UpdatedAt = DateTime.UtcNow;
                }
            }
            _logger.LogInformation("Order #{OrderId} cancelled. Restocked {Count} items.", order.OrderId, order.Items.Count);
        }
        // 2. If transitioning FROM "Cancelled" to active -> Deduct inventory (with validation)
        else if (previousStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) &&
                 !canonicalStatus.Equals("Cancelled", StringComparison.OrdinalIgnoreCase))
        {
            // Validate stock for all items
            foreach (var item in order.Items)
            {
                if (item.Product != null && item.Product.StockQuantity < item.Quantity)
                {
                    return BadRequest(new
                    {
                        message = $"Cannot re-open order #{order.OrderId}. Insufficient stock for '{item.Product.Name}'. Available: {item.Product.StockQuantity}, Required: {item.Quantity}"
                    });
                }
            }

            // Deduct stock
            foreach (var item in order.Items)
            {
                if (item.Product != null)
                {
                    item.Product.StockQuantity -= item.Quantity;
                    item.Product.UpdatedAt = DateTime.UtcNow;
                }
            }
            _logger.LogInformation("Order #{OrderId} uncancelled. Deducted stock for {Count} items.", order.OrderId, order.Items.Count);
        }

        order.Status = canonicalStatus;
        order.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        _logger.LogInformation("Order #{OrderId} status changed from '{PreviousStatus}' to '{NewStatus}' by {User}",
            order.OrderId, previousStatus, canonicalStatus, User.Identity?.Name ?? "Staff");

        return Ok(MapToDetailDto(order));
    }

    private static OrderDetailDto MapToDetailDto(Order order)
    {
        var customerName = order.User != null ? $"{order.User.FirstName} {order.User.LastName}".Trim() : string.Empty;
        if (string.IsNullOrEmpty(customerName) && order.User != null)
        {
            customerName = order.User.Email;
        }

        return new OrderDetailDto
        {
            OrderId = order.OrderId,
            UserId = order.UserId,
            CustomerName = customerName,
            CustomerEmail = order.User?.Email ?? string.Empty,
            TotalAmount = order.TotalAmount,
            Status = order.Status,
            ShippingAddress = order.ShippingAddress,
            PaymentMethod = order.PaymentMethod,
            CreatedAt = order.CreatedAt,
            UpdatedAt = order.UpdatedAt,
            Items = order.Items.Select(oi => new OrderItemDetailDto
            {
                OrderItemId = oi.OrderItemId,
                ProductId = oi.ProductId,
                ProductName = oi.Product?.Name ?? "Hardware Component",
                Brand = oi.Product?.Brand ?? "",
                Model = oi.Product?.Model,
                ImageUrl = oi.Product?.ImageUrl,
                Quantity = oi.Quantity,
                UnitPrice = oi.UnitPrice
            }).ToList()
        };
    }

    private bool IsStaffOrAdmin()
    {
        var roleClaim = User.FindFirst(ClaimTypes.Role)?.Value ?? User.FindFirst("role")?.Value ?? string.Empty;
        return User.IsInRole("Admin") || User.IsInRole("Staff") ||
               roleClaim.Equals("Admin", StringComparison.OrdinalIgnoreCase) ||
               roleClaim.Equals("Staff", StringComparison.OrdinalIgnoreCase);
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

