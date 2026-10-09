using System.Net.Http.Json;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace PCForge.Api.Services;

public class AiAgentService : IAiAgentService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<AiAgentService> _logger;
    private readonly IServiceProvider _serviceProvider;
    private readonly string _aiServiceBaseUrl;

    public AiAgentService(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<AiAgentService> logger,
        IServiceProvider serviceProvider)
    {
        _httpClient = httpClient;
        _logger = logger;
        _serviceProvider = serviceProvider;
        _aiServiceBaseUrl = configuration["AiService:BaseUrl"] ?? "http://localhost:5050";
        _httpClient.BaseAddress = new Uri(_aiServiceBaseUrl);
        _httpClient.Timeout = TimeSpan.FromSeconds(90);
    }

    private (AppDbContext Context, IServiceScope? Scope) ResolveDbContext()
    {
        var directContext = _serviceProvider.GetService<AppDbContext>();
        if (directContext != null)
        {
            return (directContext, null);
        }

        var scope = _serviceProvider.CreateScope();
        return (scope.ServiceProvider.GetRequiredService<AppDbContext>(), scope);
    }

    public async Task<RequirementChatResponseDto> SendRequirementChatMessageAsync(string sessionId, string message)
    {
        try
        {
            var payload = new
            {
                session_id = sessionId,
                message = message
            };

            var response = await _httpClient.PostAsJsonAsync("/agent/requirements/chat", payload);
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<RequirementChatResponseDto>();
                if (result != null)
                {
                    return result;
                }
            }

            var errBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("AI microservice returned HTTP {StatusCode}: {ErrorBody}", response.StatusCode, errBody);
            return new RequirementChatResponseDto
            {
                SessionId = sessionId,
                Reply = $"AI microservice error (HTTP {(int)response.StatusCode}): {errBody}",
                Profile = new RequirementProfileDto(),
                IsComplete = false,
                Status = "error"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to communicate with AI microservice at {BaseUrl}", _aiServiceBaseUrl);
            return new RequirementChatResponseDto
            {
                SessionId = sessionId,
                Reply = $"Failed to communicate with AI Requirement Agent at {_aiServiceBaseUrl}: {ex.Message}",
                Profile = new RequirementProfileDto(),
                IsComplete = false,
                Status = "error"
            };
        }
    }

    public async Task<RequirementChatResponseDto?> GetRequirementSessionAsync(string sessionId)
    {
        try
        {
            var response = await _httpClient.GetAsync($"/agent/requirements/session/{sessionId}");
            if (response.IsSuccessStatusCode)
            {
                var jsonDoc = await response.Content.ReadFromJsonAsync<JsonElement>();
                if (jsonDoc.TryGetProperty("found", out var foundProp) && foundProp.GetBoolean())
                {
                    var profileElement = jsonDoc.GetProperty("profile");
                    var profile = JsonSerializer.Deserialize<RequirementProfileDto>(profileElement.GetRawText());
                    var isComplete = profile?.IsComplete ?? false;

                    return new RequirementChatResponseDto
                    {
                        SessionId = sessionId,
                        Reply = isComplete ? "Requirement profile is complete." : "Requirement gathering in progress.",
                        Profile = profile ?? new RequirementProfileDto(),
                        IsComplete = isComplete,
                        Status = isComplete ? "ready_for_build" : "gathering"
                    };
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not fetch AI session {SessionId} from microservice", sessionId);
        }

        return null;
    }

    public async Task<BuildGenerationResponseDto> GenerateBuildAsync(BuildGenerationRequestDto request)
    {
        try
        {
            // Hydrate product catalog from PostgreSQL via EF Core if not already supplied
            if (request.Catalog == null || request.Catalog.Count == 0)
            {
                var (db, scope) = ResolveDbContext();
                try
                {
                    var products = await db.Products
                        .AsNoTracking()
                        .Include(p => p.Category)
                        .ToListAsync();

                    request.Catalog = products.Select(p => new ComponentItemDto
                    {
                        ProductId = p.ProductId,
                        Name = p.Name,
                        Category = p.Category?.Name ?? "Component",
                        Brand = p.Brand,
                        Model = p.Model,
                        Price = p.Price,
                        Socket = p.Socket,
                        MemoryType = p.MemoryType,
                        PowerWattage = p.PowerWattage,
                        FormFactor = p.FormFactor
                    }).ToList();
                }
                finally
                {
                    scope?.Dispose();
                }
            }

            var response = await _httpClient.PostAsJsonAsync("/agent/build/generate", request);
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<BuildGenerationResponseDto>();
                if (result != null)
                {
                    return result;
                }
            }

            var errBody = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("AI build endpoint returned HTTP {StatusCode}: {ErrorBody}", response.StatusCode, errBody);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to call /agent/build/generate at {BaseUrl}", _aiServiceBaseUrl);
        }

        return new BuildGenerationResponseDto
        {
            Success = false,
            Build = null,
            Summary = "Failed to communicate with AI Build Agent microservice.",
            Error = "AI microservice unavailable at http://localhost:5050"
        };
    }

    public async Task<StockVerificationResponseDto> VerifyBuildStockAsync(StockVerificationRequestDto request)
    {
        try
        {
            // Hydrate product catalog from PostgreSQL via EF Core if not already supplied
            if (request.Catalog == null || request.Catalog.Count == 0)
            {
                var (db, scope) = ResolveDbContext();
                try
                {
                    var products = await db.Products
                        .AsNoTracking()
                        .Include(p => p.Category)
                        .ToListAsync();

                    request.Catalog = products.Select(p => new ComponentItemDto
                    {
                        ProductId = p.ProductId,
                        Name = p.Name,
                        Category = p.Category?.Name ?? "Component",
                        Brand = p.Brand,
                        Model = p.Model,
                        Price = p.Price,
                        Socket = p.Socket,
                        MemoryType = p.MemoryType,
                        PowerWattage = p.PowerWattage,
                        FormFactor = p.FormFactor
                    }).ToList();
                }
                finally
                {
                    scope?.Dispose();
                }
            }

            var response = await _httpClient.PostAsJsonAsync("/agent/inventory/verify-stock", request);
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<StockVerificationResponseDto>();
                if (result != null)
                {
                    return result;
                }
            }

            var errBody = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("AI inventory endpoint returned HTTP {StatusCode}: {ErrorBody}", response.StatusCode, errBody);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to call /agent/inventory/verify-stock at {BaseUrl}", _aiServiceBaseUrl);
        }

        return new StockVerificationResponseDto
        {
            Success = false,
            AllInStock = false,
            Summary = "Failed to communicate with AI Inventory Agent microservice.",
            Error = "AI microservice unavailable at http://localhost:5050"
        };
    }

    public async Task<OrderProposalResponseDto> CreateOrderProposalAsync(OrderPlanningRequestDto request)
    {
        try
        {
            // Hydrate active coupon campaigns from PostgreSQL via EF Core if not already supplied
            if (request.Coupons == null || request.Coupons.Count == 0)
            {
                var (db, scope) = ResolveDbContext();
                try
                {
                    var coupons = await db.Coupons
                        .AsNoTracking()
                        .Where(c => c.IsActive)
                        .ToListAsync();

                    request.Coupons = coupons.Select(c => new CouponContextDto
                    {
                        Code = c.Code,
                        Description = c.Description,
                        DiscountType = c.DiscountType,
                        DiscountValue = c.DiscountValue,
                        MinSubtotal = c.MinSubtotal,
                        MaxDiscount = c.MaxDiscount,
                        IsActive = c.IsActive
                    }).ToList();
                }
                finally
                {
                    scope?.Dispose();
                }
            }

            var response = await _httpClient.PostAsJsonAsync("/agent/order-planning/create-proposal", request);
            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<OrderProposalResponseDto>();
                if (result != null)
                {
                    return result;
                }
            }

            var errBody = await response.Content.ReadAsStringAsync();
            _logger.LogWarning("AI order planning endpoint returned HTTP {StatusCode}: {ErrorBody}", response.StatusCode, errBody);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to call /agent/order-planning/create-proposal at {BaseUrl}", _aiServiceBaseUrl);
        }

        return new OrderProposalResponseDto
        {
            Success = false,
            Error = "Failed to communicate with AI Order Planning Agent microservice at http://localhost:5050",
            AgentTrace = new List<string> { "[Backend Error] AI microservice unavailable." }
        };
    }

    public async Task<AfterSalesChatResponseDto> SendAfterSalesChatMessageAsync(AfterSalesChatRequestDto request)
    {
        var (db, scope) = ResolveDbContext();
        try
        {
            // 1. Authoritative context hydration from PostgreSQL via EF Core
            if (request.Customer == null && request.UserId > 0)
            {
                var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.UserId == request.UserId);
                if (user != null)
                {
                    request.Customer = new CustomerContextDto
                    {
                        UserId = user.UserId,
                        Name = $"{user.FirstName} {user.LastName}".Trim(),
                        Email = user.Email
                    };
                }
            }

            if ((request.Orders == null || request.Orders.Count == 0) && request.UserId > 0)
            {
                var userOrders = await db.Orders
                    .AsNoTracking()
                    .Include(o => o.Items)
                        .ThenInclude(i => i.Product)
                            .ThenInclude(p => p.Category)
                    .Where(o => o.UserId == request.UserId)
                    .OrderByDescending(o => o.CreatedAt)
                    .ToListAsync();

                request.Orders = userOrders.Select(o => new OrderContextDto
                {
                    OrderId = o.OrderId,
                    OrderNumber = $"PCF-10{o.OrderId:03d}",
                    PurchaseDate = o.CreatedAt.ToString("yyyy-MM-dd"),
                    Status = o.Status,
                    TotalAmount = o.TotalAmount,
                    Items = o.Items.Select(i =>
                    {
                        var catName = i.Product?.Category?.Name ?? "Hardware";
                        var months = (i.Product != null && i.Product.WarrantyMonths > 0)
                            ? i.Product.WarrantyMonths
                            : GetWarrantyMonths(catName, i.Product?.Specifications);
                        var expiry = o.CreatedAt.AddMonths(months);
                        return new OrderContextItemDto
                        {
                            ProductId = i.ProductId,
                            ProductName = i.Product?.Name ?? $"Product #{i.ProductId}",
                            Category = catName,
                            UnitPrice = i.UnitPrice,
                            Quantity = i.Quantity,
                            Specifications = i.Product?.Specifications,
                            WarrantyPeriod = FormatWarrantyPeriod(months),
                            WarrantyMonths = months,
                            WarrantyExpiryDate = expiry.ToString("yyyy-MM-dd"),
                            IsUnderWarranty = expiry >= DateTime.UtcNow
                        };
                    }).ToList()
                }).ToList();
            }

            if ((request.ServiceRequests == null || request.ServiceRequests.Count == 0) && request.UserId > 0)
            {
                var userSrs = await db.ServiceRequests
                    .AsNoTracking()
                    .Where(sr => sr.UserId == request.UserId)
                    .OrderByDescending(sr => sr.CreatedAt)
                    .ToListAsync();

                request.ServiceRequests = userSrs.Select(sr => new ServiceRequestContextDto
                {
                    ServiceRequestId = sr.ServiceRequestId,
                    ServiceRequestNumber = sr.ServiceRequestNumber,
                    OrderId = sr.OrderId,
                    ProductId = sr.ProductId,
                    ProblemDescription = sr.ProblemDescription,
                    ProblemCategory = sr.ProblemCategory,
                    WarrantyStatus = sr.WarrantyStatus,
                    PreferredDate = sr.PreferredDate?.ToString("yyyy-MM-dd"),
                    PreferredTime = sr.PreferredTime,
                    Status = sr.Status,
                    Priority = sr.Priority,
                    CreatedAt = sr.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
                }).ToList();
            }

            // 2. Call the stateless Python AI agent
            AfterSalesChatResponseDto? result = null;
            try
            {
                var response = await _httpClient.PostAsJsonAsync("/agent/after-sales/chat", request);
                if (response.IsSuccessStatusCode)
                {
                    result = await response.Content.ReadFromJsonAsync<AfterSalesChatResponseDto>();
                }
                else
                {
                    var errBody = await response.Content.ReadAsStringAsync();
                    _logger.LogWarning("AI after-sales endpoint returned HTTP {StatusCode}: {ErrorBody}", response.StatusCode, errBody);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to call /agent/after-sales/chat at {BaseUrl}", _aiServiceBaseUrl);
            }

            if (result == null)
            {
                return new AfterSalesChatResponseDto
                {
                    Success = false,
                    Reply = "Our After-Sales AI Assistant is currently offline. Please open a manual support ticket or retry shortly.",
                    Error = "Failed to communicate with AI After-Sales Agent microservice at http://localhost:5050",
                    AgentTrace = new List<string> { "[Backend Error] AI microservice unavailable." }
                };
            }

            // 3. Authoritative deterministic validation and EF Core persistence for Service Requests
            if (result.ServiceRequest != null)
            {
                var srDto = result.ServiceRequest;
                var action = srDto.Action?.ToLowerInvariant() ?? "";

                if (action == "create" || (srDto.ServiceRequestId == null && !string.IsNullOrWhiteSpace(srDto.ProblemDescription)))
                {
                    // Deterministic Validation Rules
                    var validationErrors = new List<string>();

                    if (string.IsNullOrWhiteSpace(srDto.ProblemDescription))
                    {
                        validationErrors.Add("Problem description is required.");
                    }

                    DateTime? parsedPreferredDate = null;
                    if (!string.IsNullOrWhiteSpace(srDto.PreferredDate))
                    {
                        if (DateTime.TryParse(srDto.PreferredDate, out var dt))
                        {
                            if (dt.Date < DateTime.UtcNow.Date)
                            {
                                validationErrors.Add("Preferred appointment date cannot be in the past.");
                            }
                            if (dt.DayOfWeek == DayOfWeek.Sunday)
                            {
                                validationErrors.Add("Service center is closed on Sundays. Please select Monday - Saturday.");
                            }
                            parsedPreferredDate = DateTime.SpecifyKind(dt.Date, DateTimeKind.Utc);
                        }
                        else
                        {
                            validationErrors.Add($"Invalid preferred date format: '{srDto.PreferredDate}'");
                        }
                    }

                    if (!string.IsNullOrWhiteSpace(srDto.PreferredTime))
                    {
                        var timeMatch = Regex.Match(srDto.PreferredTime.Trim(), @"^(\d{1,2}):(\d{2})(?:\s*([APap][Mm]))?$");
                        if (timeMatch.Success)
                        {
                            var hour = int.Parse(timeMatch.Groups[1].Value);
                            var min = int.Parse(timeMatch.Groups[2].Value);
                            var ampm = timeMatch.Groups[3].Value.ToUpperInvariant();
                            if (ampm == "PM" && hour < 12) hour += 12;
                            if (ampm == "AM" && hour == 12) hour = 0;

                            if (hour < 9 || hour > 18 || (hour == 18 && min > 0))
                            {
                                validationErrors.Add("Appointments can only be scheduled between 09:00 AM and 06:00 PM.");
                            }
                        }
                    }

                    // Deterministic warranty calculation from DB (never trust AI hallucination alone)
                    DateTime? verifiedExpiryDate = null;
                    string verifiedWarrantyStatus = "Expired";
                    if (srDto.OrderId.HasValue && srDto.OrderId.Value > 0)
                    {
                        var order = await db.Orders
                            .AsNoTracking()
                            .Include(o => o.Items)
                                .ThenInclude(i => i.Product)
                                    .ThenInclude(p => p.Category)
                            .FirstOrDefaultAsync(o => o.OrderId == srDto.OrderId.Value);

                        if (order != null)
                        {
                            var targetItem = srDto.ProductId.HasValue && srDto.ProductId.Value > 0
                                ? order.Items.FirstOrDefault(i => i.ProductId == srDto.ProductId.Value)
                                : order.Items.FirstOrDefault();

                            if (targetItem?.Product != null)
                            {
                                var months = targetItem.Product.WarrantyMonths > 0
                                    ? targetItem.Product.WarrantyMonths
                                    : GetWarrantyMonths(targetItem.Product.Category?.Name, targetItem.Product.Specifications);
                                verifiedExpiryDate = order.CreatedAt.AddMonths(months);
                                verifiedWarrantyStatus = verifiedExpiryDate >= DateTime.UtcNow ? "Active" : "Expired";
                            }
                        }
                    }

                    if (validationErrors.Count > 0)
                    {
                        _logger.LogWarning("Deterministic validation failed on AI Service Request: {Errors}", string.Join("; ", validationErrors));
                        result.AgentTrace.Add($"[ASP.NET Core Validation Warning] {string.Join("; ", validationErrors)}");
                    }
                    else
                    {
                        // Assign authoritative Service Request Number
                        var maxId = await db.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 100;
                        var authoritativeSrNumber = $"SR-{(maxId + 1):D6}";
                        var provisionalSrNumber = srDto.ServiceRequestNumber;

                        var newServiceRequest = new ServiceRequest
                        {
                            ServiceRequestNumber = authoritativeSrNumber,
                            UserId = request.UserId > 0 ? request.UserId : 1,
                            OrderId = srDto.OrderId,
                            ProductId = srDto.ProductId,
                            ProblemDescription = srDto.ProblemDescription.Trim(),
                            ProblemCategory = string.IsNullOrWhiteSpace(srDto.ProblemCategory) ? "General" : srDto.ProblemCategory.Trim(),
                            TroubleshootingSummary = srDto.TroubleshootingSummary,
                            AttemptCount = srDto.AttemptCount,
                            WarrantyStatus = verifiedWarrantyStatus,
                            WarrantyExpiryDate = verifiedExpiryDate,
                            PreferredDate = parsedPreferredDate,
                            PreferredTime = srDto.PreferredTime,
                            Status = "PENDING",
                            Priority = !string.IsNullOrWhiteSpace(srDto.Priority) ? srDto.Priority : "Normal",
                            CreatedAt = DateTime.UtcNow,
                            UpdatedAt = DateTime.UtcNow
                        };

                        db.ServiceRequests.Add(newServiceRequest);
                        await db.SaveChangesAsync();

                        _logger.LogInformation("ASP.NET Core successfully persisted ServiceRequest #{Id} ({SrNumber}) for User {UserId}",
                            newServiceRequest.ServiceRequestId, newServiceRequest.ServiceRequestNumber, newServiceRequest.UserId);

                        // Update AI DTO response with authoritative DB identifiers
                        srDto.Id = newServiceRequest.ServiceRequestId;
                        srDto.ServiceRequestId = newServiceRequest.ServiceRequestId;
                        srDto.ServiceRequestNumber = newServiceRequest.ServiceRequestNumber;
                        srDto.WarrantyStatus = newServiceRequest.WarrantyStatus;
                        srDto.WarrantyExpiryDate = newServiceRequest.WarrantyExpiryDate?.ToString("yyyy-MM-dd");
                        srDto.CreatedAt = newServiceRequest.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ");

                        if (result.Ticket != null)
                        {
                            result.Ticket.TicketId = newServiceRequest.ServiceRequestId;
                            result.Ticket.RmaNumber = newServiceRequest.ServiceRequestNumber;
                            result.Ticket.CreatedAt = newServiceRequest.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ");
                        }

                        // Replace any provisional AI number in the reply text with the real authoritative number
                        if (!string.IsNullOrEmpty(provisionalSrNumber) && !string.IsNullOrEmpty(result.Reply))
                        {
                            result.Reply = result.Reply.Replace(provisionalSrNumber, authoritativeSrNumber);
                        }
                    }
                }
                else if (action == "update")
                {
                    // Find existing Service Request by ID or SR-Number
                    var existing = await db.ServiceRequests.FirstOrDefaultAsync(sr =>
                        (srDto.ServiceRequestId.HasValue && sr.ServiceRequestId == srDto.ServiceRequestId.Value) ||
                        (!string.IsNullOrEmpty(srDto.ServiceRequestNumber) && sr.ServiceRequestNumber.ToUpper() == srDto.ServiceRequestNumber.ToUpper()));

                    if (existing != null)
                    {
                        if (!string.IsNullOrWhiteSpace(srDto.PreferredDate) && DateTime.TryParse(srDto.PreferredDate, out var dt))
                        {
                            existing.PreferredDate = DateTime.SpecifyKind(dt.Date, DateTimeKind.Utc);
                        }
                        if (!string.IsNullOrWhiteSpace(srDto.PreferredTime))
                        {
                            existing.PreferredTime = srDto.PreferredTime.Trim();
                        }

                        existing.Status = "SCHEDULED";
                        existing.UpdatedAt = DateTime.UtcNow;
                        await db.SaveChangesAsync();

                        _logger.LogInformation("ASP.NET Core successfully updated appointment for ServiceRequest {SrNumber}", existing.ServiceRequestNumber);

                        srDto.ServiceRequestId = existing.ServiceRequestId;
                        srDto.ServiceRequestNumber = existing.ServiceRequestNumber;
                        srDto.Status = existing.Status;
                    }
                }
            }

            return result;
        }
        finally
        {
            scope?.Dispose();
        }
    }

    private static int GetWarrantyMonths(string? categoryName, string? specificationsJson = null)
    {
        if (!string.IsNullOrWhiteSpace(specificationsJson))
        {
            try
            {
                using var doc = JsonDocument.Parse(specificationsJson);
                var root = doc.RootElement;
                if (root.TryGetProperty("warranty_months", out var wmProp) && wmProp.TryGetInt32(out int wm) && wm > 0)
                    return wm;
                if (root.TryGetProperty("warrantyMonths", out var wmProp2) && wmProp2.TryGetInt32(out int wm2) && wm2 > 0)
                    return wm2;
                if (root.TryGetProperty("warranty", out var wProp) && wProp.ValueKind == JsonValueKind.String)
                {
                    var text = wProp.GetString()?.ToLower() ?? "";
                    double years = 0;
                    int months = 0;
                    var yMatch = Regex.Match(text, @"(\d+(?:\.\d+)?)\s*(?:year|yr)");
                    if (yMatch.Success && double.TryParse(yMatch.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture, out double y))
                        years = y;
                    var mMatch = Regex.Match(text, @"(\d+)\s*(?:month|mo)");
                    if (mMatch.Success && int.TryParse(mMatch.Groups[1].Value, out int m))
                        months = m;
                    var total = (int)(years * 12 + months);
                    if (total > 0) return total;
                }
            }
            catch { }
        }

        var cat = (categoryName ?? "").ToLower();
        if (cat.Contains("gpu") || cat.Contains("graphics") || cat.Contains("video")) return 36;
        if (cat.Contains("cpu") || cat.Contains("processor")) return 36;
        if (cat.Contains("motherboard")) return 36;
        if (cat.Contains("ram") || cat.Contains("memory")) return 120; // 10 years / lifetime
        if (cat.Contains("storage") || cat.Contains("ssd") || cat.Contains("nvme")) return 60;
        if (cat.Contains("power") || cat.Contains("psu")) return 60;
        if (cat.Contains("case") || cat.Contains("cooler")) return 24;
        return 36;
    }

    private static string FormatWarrantyPeriod(int months)
    {
        var years = months / 12;
        var rem = months % 12;
        if (years > 0 && rem > 0)
            return $"{years} Year{(years > 1 ? "s" : "")} {rem} Month{(rem > 1 ? "s" : "")} Manufacturer Warranty";
        if (years > 0)
            return $"{years} Year{(years > 1 ? "s" : "")} Manufacturer Warranty";
        if (rem > 0)
            return $"{rem} Month{(rem > 1 ? "s" : "")} Manufacturer Warranty";
        return "Standard Manufacturer Warranty";
    }
}