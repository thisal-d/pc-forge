using System.ComponentModel.DataAnnotations;

namespace PCForge.Api.DTOs;

public class CreateOrderItemDto
{
    [Required]
    public int ProductId { get; set; }

    [Required]
    [Range(1, 100)]
    public int Quantity { get; set; }
}

public class CreateOrderDto
{
    [Required]
    public string ShippingAddress { get; set; } = string.Empty;

    public string PaymentMethod { get; set; } = "Credit / Debit Card";

    [Required]
    [MinLength(1, ErrorMessage = "Order must contain at least one item.")]
    public List<CreateOrderItemDto> Items { get; set; } = new();
}

public class OrderItemDetailDto
{
    public int OrderItemId { get; set; }
    public int ProductId { get; set; }
    public string ProductName { get; set; } = string.Empty;
    public string Brand { get; set; } = string.Empty;
    public string? Model { get; set; }
    public string? ImageUrl { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal Subtotal => UnitPrice * Quantity;
}

public class OrderDetailDto
{
    public int OrderId { get; set; }
    public int UserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = "Pending";
    public string ShippingAddress { get; set; } = string.Empty;
    public string? PaymentMethod { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public List<OrderItemDetailDto> Items { get; set; } = new();
}

public class OrderSummaryDto
{
    public int OrderId { get; set; }
    public int UserId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerEmail { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = "Pending";
    public string ShippingAddress { get; set; } = string.Empty;
    public string? PaymentMethod { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public int ItemCount { get; set; }
}

public class UpdateOrderStatusDto
{
    [Required]
    public string Status { get; set; } = string.Empty;

    public string? Notes { get; set; }
}
