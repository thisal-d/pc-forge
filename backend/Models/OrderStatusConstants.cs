namespace PCForge.Api.Models;

public static class OrderStatusConstants
{
    // Canonical Statuses
    public const string OrderPlaced = "Order placed";
    public const string Processing = "Processing";
    public const string ReadyForDelivery = "Ready for delivery";
    public const string OutForDelivery = "Out for delivery";
    public const string ReadyForPickup = "Ready for pickup";
    public const string PaidAndCompleted = "Paid & Completed";
    public const string Cancelled = "Cancelled";

    // Payment / Delivery Methods
    public const string CashOnDelivery = "Cash on Delivery";
    public const string StorePickup = "Store Pickup";

    public const decimal CodMaxLimit = 100000m;

    public static readonly IReadOnlyList<string> AllStatuses = new[]
    {
        OrderPlaced,
        Processing,
        ReadyForDelivery,
        OutForDelivery,
        ReadyForPickup,
        PaidAndCompleted,
        Cancelled
    };

    // Linear progression steps for COD
    public static readonly IReadOnlyList<string> CodSteps = new[]
    {
        OrderPlaced,
        Processing,
        ReadyForDelivery,
        OutForDelivery,
        PaidAndCompleted
    };

    // Linear progression steps for Store Pickup
    public static readonly IReadOnlyList<string> StorePickupSteps = new[]
    {
        OrderPlaced,
        Processing,
        ReadyForPickup,
        PaidAndCompleted
    };

    public static bool IsCod(string? paymentMethod)
    {
        if (string.IsNullOrWhiteSpace(paymentMethod)) return false;
        var p = paymentMethod.Trim().ToLowerInvariant();
        return p.Contains("cash") || p == "cod";
    }

    public static bool IsStorePickup(string? paymentMethod)
    {
        if (string.IsNullOrWhiteSpace(paymentMethod)) return false;
        var p = paymentMethod.Trim().ToLowerInvariant();
        return p.Contains("pickup") || p.Contains("store") || p.Contains("counter");
    }

    public static string NormalizePaymentMethod(string? paymentMethod)
    {
        if (IsCod(paymentMethod)) return CashOnDelivery;
        if (IsStorePickup(paymentMethod)) return StorePickup;
        // Default / fallback
        return paymentMethod?.Trim() ?? CashOnDelivery;
    }

    /// <summary>
    /// Checks if a customer or staff is permitted to cancel the order based on its current status.
    /// Cancellation is only allowed when status is 'Order placed' or 'Processing'.
    /// </summary>
    public static bool CanCancel(string? currentStatus)
    {
        if (string.IsNullOrWhiteSpace(currentStatus)) return false;
        return currentStatus.Equals(OrderPlaced, StringComparison.OrdinalIgnoreCase) ||
               currentStatus.Equals(Processing, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Validates if transition from currentStatus to targetStatus is valid:
    /// - Can only move forward exactly ONE step at a time.
    /// - No skipping, no moving backwards.
    /// - COD cannot use pickup statuses ('Ready for pickup').
    /// - Store pickup cannot use delivery statuses ('Ready for delivery', 'Out for delivery').
    /// - Transition to 'Cancelled' is allowed ONLY if current status is 'Order placed' or 'Processing'.
    /// </summary>
    public static bool IsValidTransition(string currentStatus, string targetStatus, string? paymentMethod, out string? errorMessage)
    {
        errorMessage = null;

        var normalizedTarget = AllStatuses.FirstOrDefault(s => s.Equals(targetStatus.Trim(), StringComparison.OrdinalIgnoreCase));
        if (normalizedTarget == null)
        {
            errorMessage = $"Invalid status '{targetStatus}'. Allowed statuses are: {string.Join(", ", AllStatuses)}";
            return false;
        }

        var normalizedCurrent = AllStatuses.FirstOrDefault(s => s.Equals(currentStatus.Trim(), StringComparison.OrdinalIgnoreCase)) ?? currentStatus.Trim();

        // No-op transition
        if (normalizedCurrent.Equals(normalizedTarget, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Terminal states cannot transition to anything
        if (normalizedCurrent.Equals(PaidAndCompleted, StringComparison.OrdinalIgnoreCase))
        {
            errorMessage = "Order is already Paid & Completed and cannot transition to any other status.";
            return false;
        }
        if (normalizedCurrent.Equals(Cancelled, StringComparison.OrdinalIgnoreCase))
        {
            errorMessage = "Order is already Cancelled and cannot transition to any other status.";
            return false;
        }

        // Cancellation transition
        if (normalizedTarget.Equals(Cancelled, StringComparison.OrdinalIgnoreCase))
        {
            if (!CanCancel(normalizedCurrent))
            {
                errorMessage = $"Order cannot be cancelled when in status '{normalizedCurrent}'. Cancellation is only allowed in 'Order placed' or 'Processing'.";
                return false;
            }
            return true;
        }

        // Forward step validation based on payment / delivery method
        var isCod = IsCod(paymentMethod);
        var steps = isCod ? CodSteps : StorePickupSteps;

        int currentIndex = -1;
        for (int i = 0; i < steps.Count; i++)
        {
            if (steps[i].Equals(normalizedCurrent, StringComparison.OrdinalIgnoreCase))
            {
                currentIndex = i;
                break;
            }
        }

        int targetIndex = -1;
        for (int i = 0; i < steps.Count; i++)
        {
            if (steps[i].Equals(normalizedTarget, StringComparison.OrdinalIgnoreCase))
            {
                targetIndex = i;
                break;
            }
        }

        if (targetIndex == -1)
        {
            var flowName = isCod ? "Cash on delivery (COD)" : "Store pickup";
            errorMessage = $"Status '{normalizedTarget}' is not applicable for {flowName} orders.";
            return false;
        }

        if (currentIndex == -1)
        {
            errorMessage = $"Current status '{normalizedCurrent}' is not recognized in the { (isCod ? "COD" : "Store pickup") } progression flow.";
            return false;
        }

        if (targetIndex <= currentIndex)
        {
            errorMessage = $"Status cannot go backwards from '{normalizedCurrent}' to '{normalizedTarget}'.";
            return false;
        }

        if (targetIndex > currentIndex + 1)
        {
            errorMessage = $"Cannot skip steps. Status must advance one step at a time from '{normalizedCurrent}' to '{steps[currentIndex + 1]}'.";
            return false;
        }

        return true;
    }
}
