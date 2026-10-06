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

            if (!string.Equals(product.Status, "Active", StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { message = $"Product '{product.Name}' is currently inactive and not available for purchase." });
            }

            if (product.StockQuantity < itemDto.Quantity)
            {
                return BadRequest(new
                {
                    message = $"Insufficient stock for '{product.Name}'. Available: {product.StockQuantity}, Requested: {itemDto.Quantity}"
                });
            }

            totalAmount += product.Price * itemDto.Quantity;

            orderItems.Add(new OrderItem
            {
                ProductId = product.ProductId,
                Quantity = itemDto.Quantity,
                UnitPrice = product.Price
            });
        }

        // 4. Payment Method & Total Threshold Validation (Server-side from DB prices)
        var isCod = OrderStatusConstants.IsCod(dto.PaymentMethod);
        var isStorePickup = OrderStatusConstants.IsStorePickup(dto.PaymentMethod);

        if (totalAmount > OrderStatusConstants.CodMaxLimit)
        {
            if (isCod)
            {
                return BadRequest(new
                {
                    message = $"Cash on delivery (COD) is only allowed for orders up to LKR {OrderStatusConstants.CodMaxLimit:N0}. Your calculated order total is LKR {totalAmount:N2}. For orders over LKR {OrderStatusConstants.CodMaxLimit:N0}, Store pickup is the only option."
                });
            }
            else if (!isStorePickup)
            {
                return BadRequest(new
                {
                    message = $"For orders exceeding LKR {OrderStatusConstants.CodMaxLimit:N0}, Store pickup (pay at counter) is the only allowed option. Your calculated order total is LKR {totalAmount:N2}."
                });
            }
        }

        var normalizedPaymentMethod = isCod ? OrderStatusConstants.CashOnDelivery : OrderStatusConstants.StorePickup;

        // 5. Reserve & Deduct Inventory in Transaction
        var isInMemory = _context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory";
        using var transaction = isInMemory ? null : await _context.Database.BeginTransactionAsync();

        foreach (var itemDto in dto.Items)
        {
            var product = products[itemDto.ProductId];
            product.StockQuantity -= itemDto.Quantity;
            product.UpdatedAt = DateTime.UtcNow;
        }

        var order = new Order
        {
            UserId = userId,
            TotalAmount = totalAmount,
            Status = OrderStatusConstants.OrderPlaced, // Starts strictly at 'Order placed'
            ShippingAddress = dto.ShippingAddress.Trim(),
            PaymentMethod = normalizedPaymentMethod,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            Items = orderItems
        };

        _context.Orders.Add(order);
        await _context.SaveChangesAsync();

        if (transaction != null)
        {
            await transaction.CommitAsync();
        }

        _logger.LogInformation("Order #{OrderId} placed successfully for User {UserId}, Method: {PaymentMethod}, Total: {TotalAmount:C}",
            order.OrderId, userId, normalizedPaymentMethod, totalAmount);

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
    /// Enforces strict forward-only progression rules:
    /// - COD: Order placed -> Processing -> Ready for delivery -> Out for delivery -> Paid & Completed
    /// - Store pickup: Order placed -> Processing -> Ready for pickup -> Paid & Completed
    /// - Cancelled: only permitted from 'Order placed' or 'Processing'
    /// </summary>
    [HttpPatch("{id:int}/status")]
    [Authorize(Policy = "StaffOnly")]
    public async Task<ActionResult<OrderDetailDto>> UpdateOrderStatus(int id, [FromBody] UpdateOrderStatusDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var isInMemory = _context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory";
        using var transaction = isInMemory ? null : await _context.Database.BeginTransactionAsync();

        Order? order;
        if (!isInMemory)
        {
            order = await _context.Orders
                .FromSqlRaw("SELECT * FROM orders WHERE orderid = {0} FOR UPDATE", id)
                .Include(o => o.User)
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                .FirstOrDefaultAsync();
        }
        else
        {
            order = await _context.Orders
                .Include(o => o.User)
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                .FirstOrDefaultAsync(o => o.OrderId == id);
        }

        if (order == null)
        {
            return NotFound(new { message = $"Order #{id} not found." });
        }

        var targetCanonical = OrderStatusConstants.AllStatuses.FirstOrDefault(s => s.Equals(dto.Status.Trim(), StringComparison.OrdinalIgnoreCase));
        if (targetCanonical == null)
        {
            return BadRequest(new { message = $"Invalid status '{dto.Status}'. Allowed: {string.Join(", ", OrderStatusConstants.AllStatuses)}" });
        }

        if (!OrderStatusConstants.IsValidTransition(order.Status, targetCanonical, order.PaymentMethod, out var transitionError))
        {
            return BadRequest(new { message = transitionError });
        }

        var previousStatus = order.Status;

        // If status isn't changing, return current
        if (previousStatus.Equals(targetCanonical, StringComparison.OrdinalIgnoreCase))
        {
            return Ok(MapToDetailDto(order));
        }

        // Restock inventory if transitioning to Cancelled (idempotent)
        if (targetCanonical.Equals(OrderStatusConstants.Cancelled, StringComparison.OrdinalIgnoreCase) &&
            !previousStatus.Equals(OrderStatusConstants.Cancelled, StringComparison.OrdinalIgnoreCase))
        {
            foreach (var item in order.Items)
            {
                if (item.Product != null)
                {
                    item.Product.StockQuantity += item.Quantity;
                    item.Product.UpdatedAt = DateTime.UtcNow;
                }
            }
            _logger.LogInformation("Order #{OrderId} cancelled by staff. Restocked {Count} items.", order.OrderId, order.Items.Count);
        }

        order.Status = targetCanonical;
        order.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        if (transaction != null)
        {
            await transaction.CommitAsync();
        }

        _logger.LogInformation("Order #{OrderId} status changed from '{PreviousStatus}' to '{NewStatus}' by {User}",
            order.OrderId, previousStatus, targetCanonical, User.Identity?.Name ?? "Staff");

        return Ok(MapToDetailDto(order));
    }

    /// <summary>
    /// Customer cancellation endpoint.
    /// - Allowed only in 'Order placed' or 'Processing' statuses.
    /// - Not allowed in 'Ready for delivery', 'Out for delivery', 'Ready for pickup', or 'Paid & Completed'.
    /// - Restocks each item's inventory.
    /// - Uses an atomic DB transaction with a row-level lock (FOR UPDATE).
    /// - Fully idempotent: double-submitting does not double-restock inventory.
    /// </summary>
    [HttpPost("{id:int}/cancel")]
    public async Task<ActionResult<OrderDetailDto>> CancelOrder(int id)
    {
        return await CancelOrderInternal(id);
    }

    [HttpPatch("{id:int}/cancel")]
    [ApiExplorerSettings(IgnoreApi = true)]
    public async Task<ActionResult<OrderDetailDto>> CancelOrderPatch(int id)
    {
        return await CancelOrderInternal(id);
    }

    private async Task<ActionResult<OrderDetailDto>> CancelOrderInternal(int id)
    {
        var currentUserId = GetCurrentUserId();
        if (!currentUserId.HasValue)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var isStaffOrAdmin = IsStaffOrAdmin();

        var isInMemory = _context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory";
        using var transaction = isInMemory ? null : await _context.Database.BeginTransactionAsync();

        Order? order;
        if (!isInMemory)
        {
            // Acquire row lock to ensure idempotency and prevent concurrent double-cancels
            order = await _context.Orders
                .FromSqlRaw("SELECT * FROM orders WHERE orderid = {0} FOR UPDATE", id)
                .Include(o => o.User)
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                .FirstOrDefaultAsync();
        }
        else
        {
            order = await _context.Orders
                .Include(o => o.User)
                .Include(o => o.Items)
                .ThenInclude(i => i.Product)
                .FirstOrDefaultAsync(o => o.OrderId == id);
        }

        if (order == null)
        {
            return NotFound(new { message = $"Order #{id} was not found." });
        }

        // Verify customer owns this order (or is staff/admin)
        if (!isStaffOrAdmin && order.UserId != currentUserId.Value)
        {
            return Forbid();
        }

        // Idempotency: If already cancelled, return existing state without restocking again
        if (order.Status.Equals(OrderStatusConstants.Cancelled, StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation("Order #{OrderId} cancel requested, but already Cancelled (idempotent response).", id);
            return Ok(MapToDetailDto(order));
        }

        // Status rule validation: Only allowed in 'Order placed' or 'Processing'
        if (!OrderStatusConstants.CanCancel(order.Status))
        {
            return BadRequest(new
            {
                message = $"Order #{id} cannot be cancelled because it is in status '{order.Status}'. Cancellation is only allowed when status is 'Order placed' or 'Processing'."
            });
        }

        // Restock inventory for each item
        foreach (var item in order.Items)
        {
            if (item.Product != null)
            {
                item.Product.StockQuantity += item.Quantity;
                item.Product.UpdatedAt = DateTime.UtcNow;
            }
        }

        order.Status = OrderStatusConstants.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        if (transaction != null)
        {
            await transaction.CommitAsync();
        }

        _logger.LogInformation("Order #{OrderId} cancelled successfully by user #{UserId}. Restocked {ItemCount} items.",
            order.OrderId, currentUserId.Value, order.Items.Count);

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

