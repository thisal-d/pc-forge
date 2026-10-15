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
                        FormFactor = p.FormFactor,
                        StockQuantity = p.StockQuantity
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
                        FormFactor = p.FormFactor,
                        StockQuantity = p.StockQuantity
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



            if ((request.ServiceRequests == null || request.ServiceRequests.Count == 0) && request.UserId > 0)
            {
                var userSrs = await db.ServiceRequests
                    .AsNoTracking()
                    .Include(sr => sr.Slot)
                    .Where(sr => sr.UserId == request.UserId)
                    .OrderByDescending(sr => sr.CreatedAt)
                    .ToListAsync();

                request.ServiceRequests = userSrs.Select(sr => new ServiceRequestContextDto
                {
                    ServiceRequestId = sr.ServiceRequestId,
                    ServiceRequestNumber = sr.ServiceRequestNumber,
                    Title = sr.Title,
                    Description = sr.Description,
                    PreferredDate = sr.PreferredDate?.ToString("yyyy-MM-dd"),
                    PreferredTime = sr.PreferredTime,
                    SlotId = sr.SlotId,
                    SlotLabel = sr.Slot?.Label ?? sr.PreferredTime,
                    Status = sr.Status,
                    CreatedAt = sr.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
                }).ToList();
            }

            if (request.TimeSlots == null || request.TimeSlots.Count == 0)
            {
                var activeSlots = await db.ServiceTimeSlots
                    .AsNoTracking()
                    .Where(s => s.IsActive)
                    .OrderBy(s => s.StartTime)
                    .ThenBy(s => s.EndTime)
                    .Select(s => new TimeSlotContextDto
                    {
                        SlotId = s.SlotId,
                        StartTime = s.StartTime,
                        EndTime = s.EndTime,
                        Label = s.Label ?? $"{s.StartTime} - {s.EndTime}",
                        DefaultCapacity = s.DefaultCapacity,
                        IsActive = s.IsActive,
                        DisplayOrder = s.DisplayOrder
                    })
                    .ToListAsync();

                request.TimeSlots = activeSlots;
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
                // Intelligent fallback when AI microservice is offline:
                // Enables agentic intake of Service Requests directly via chat
                var msg = (request.Message ?? "").Trim();
                var lower = msg.ToLowerInvariant();

                bool isSrIntent = lower.Contains("service request") || lower.Contains("book") || lower.Contains("appointment") || lower.Contains("repair");

                if (isSrIntent)
                {
                    DateTime? extractedDate = null;
                    var dateMatch = Regex.Match(msg, @"\b(\d{4}-\d{2}-\d{2})\b");
                    if (dateMatch.Success && DateTime.TryParse(dateMatch.Groups[1].Value, out var dt))
                    {
                        extractedDate = DateTime.SpecifyKind(dt.Date, DateTimeKind.Utc);
                    }
                    else if (lower.Contains("tomorrow"))
                    {
                        extractedDate = DateTime.SpecifyKind(DateTime.UtcNow.Date.AddDays(1), DateTimeKind.Utc);
                        if (extractedDate.Value.DayOfWeek == DayOfWeek.Sunday) extractedDate = extractedDate.Value.AddDays(1);
                    }

                    string? extractedTime = null;
                    var timeMatch = Regex.Match(msg, @"\b(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm))\b");
                    if (timeMatch.Success)
                    {
                        extractedTime = timeMatch.Groups[1].Value.ToUpperInvariant();
                    }

                    if (extractedDate.HasValue && !string.IsNullOrEmpty(extractedTime))
                    {
                        var valErrors = new List<string>();
                        if (extractedDate.Value.Date < DateTime.UtcNow.Date)
                            valErrors.Add("The selected date has already passed. Please select a future date (Monday to Saturday).");
                        if (extractedDate.Value.DayOfWeek == DayOfWeek.Sunday)
                            valErrors.Add("The service center is closed on Sundays. Please select Monday through Saturday.");

                        var count = await db.ServiceRequests.CountAsync(sr =>
                            sr.PreferredDate.HasValue &&
                            sr.PreferredDate.Value.Date == extractedDate.Value.Date &&
                            sr.Status.ToLower() != "cancelled" &&
                            sr.Status.ToLower() != "canceled");
                        if (count >= 10)
                            valErrors.Add($"The selected date ({extractedDate.Value:yyyy-MM-dd}) already has 10 requests booked. Please choose another date.");

                        var tMatch = Regex.Match(extractedTime, @"^(\d{1,2})(?::(\d{2}))?\s*([APap][Mm])$");
                        if (tMatch.Success)
                        {
                            var h = int.Parse(tMatch.Groups[1].Value);
                            var m = string.IsNullOrEmpty(tMatch.Groups[2].Value) ? 0 : int.Parse(tMatch.Groups[2].Value);
                            var ampm = tMatch.Groups[3].Value.ToUpperInvariant();
                            if (ampm == "PM" && h < 12) h += 12;
                            if (ampm == "AM" && h == 12) h = 0;
                            if (h < 9 || h > 18 || (h == 18 && m > 0))
                                valErrors.Add("The service time must be between 9:00 AM and 6:00 PM. Please choose another time.");
                        }

                        if (valErrors.Count == 0)
                        {
                            var isExplicitCreation = lower.Contains("please create") || lower.Contains("confirm") || lower.Contains("submit") || lower.Contains("proceed") || lower.Contains("yes");

                            var generatedTitle = !string.IsNullOrWhiteSpace(request.ProblemCategory) && request.ProblemCategory != "General"
                                ? $"{request.ProblemCategory} Issue"
                                : (msg.Length > 50 ? msg[..47] + "..." : msg);
                            var generatedDescription = $"Customer symptom: {msg}. Troubleshooting steps attempted prior to service booking.";

                            if (!isExplicitCreation)
                            {
                                return new AfterSalesChatResponseDto
                                {
                                    Success = true,
                                    Reply = $"I have generated your Service Request details based on our conversation:\n\nTitle: {generatedTitle}\nDescription: {generatedDescription}\nPreferred Date: {extractedDate.Value:yyyy-MM-dd}\nPreferred Time: {extractedTime}\n\nPlease review the title and description above. You can confirm to submit, or let me know if you would like to edit them.",
                                    ServiceRequestMode = true,
                                    ServiceRequestRequired = true,
                                    ServiceRequest = new ServiceRequestInfoDto
                                    {
                                        Title = generatedTitle,
                                        Description = generatedDescription,
                                        ProblemDescription = generatedDescription,
                                        ProblemCategory = request.ProblemCategory ?? "General",
                                        PreferredDate = extractedDate.Value.ToString("yyyy-MM-dd"),
                                        PreferredTime = extractedTime,
                                        Status = "Draft",
                                        Priority = "Normal"
                                    }
                                };
                            }

                            ServiceTimeSlot? fallbackSlot = null;
                            var cleanFallbackTime = (extractedTime ?? "").ToLowerInvariant();
                            fallbackSlot = await db.ServiceTimeSlots.FirstOrDefaultAsync(s =>
                                s.IsActive &&
                                ((s.Label != null && s.Label.ToLower().Contains(cleanFallbackTime)) ||
                                 s.StartTime.ToLower() == cleanFallbackTime ||
                                 (s.StartTime + " - " + s.EndTime).ToLower() == cleanFallbackTime));
                            if (fallbackSlot == null)
                            {
                                fallbackSlot = await db.ServiceTimeSlots.Where(s => s.IsActive).OrderBy(s => s.DisplayOrder).FirstOrDefaultAsync();
                            }

                            var maxId = await db.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 100;
                            var srNumber = $"SR-{(maxId + 1):D6}";
                            var newSr = new ServiceRequest
                            {
                                ServiceRequestNumber = srNumber,
                                UserId = request.UserId > 0 ? request.UserId : 1,
                                SlotId = fallbackSlot?.SlotId,
                                Title = generatedTitle,
                                Description = generatedDescription,
                                PreferredDate = extractedDate,
                                PreferredTime = fallbackSlot?.Label ?? extractedTime,
                                Status = "Booked",
                                CreatedAt = DateTime.UtcNow,
                                UpdatedAt = DateTime.UtcNow
                            };
                            db.ServiceRequests.Add(newSr);
                            await db.SaveChangesAsync();

                            return new AfterSalesChatResponseDto
                            {
                                Success = true,
                                Reply = $"Your Service Request has been created successfully.\n\nService Request ID: {srNumber}\nTitle: {newSr.Title}\nDescription: {newSr.Description}\nPreferred Date: {extractedDate.Value:yyyy-MM-dd}\nTime Slot: {newSr.PreferredTime}\nStatus: Booked\n\nPlease bring your PC or affected component to our service center for technician inspection.",
                                ServiceRequestMode = true,
                                ServiceRequestRequired = true,
                                ServiceRequest = new ServiceRequestInfoDto
                                {
                                    Id = newSr.ServiceRequestId,
                                    ServiceRequestId = newSr.ServiceRequestId,
                                    ServiceRequestNumber = newSr.ServiceRequestNumber,
                                    Title = newSr.Title,
                                    Description = newSr.Description,
                                    SlotId = newSr.SlotId,
                                    SlotLabel = fallbackSlot?.Label ?? newSr.PreferredTime,
                                    PreferredDate = newSr.PreferredDate?.ToString("yyyy-MM-dd"),
                                    PreferredTime = newSr.PreferredTime,
                                    Status = newSr.Status,
                                    CreatedAt = newSr.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
                                }
                            };
                        }
                        else
                        {
                            return new AfterSalesChatResponseDto
                            {
                                Success = true,
                                Reply = $"We could not schedule your service appointment: {string.Join(" ", valErrors)} Please provide a valid date (Monday - Saturday) and time between 9:00 AM and 6:00 PM.",
                                ServiceRequestMode = true,
                                ServiceRequestRequired = true
                            };
                        }
                    }
                    else if (extractedDate.HasValue && string.IsNullOrEmpty(extractedTime))
                    {
                        return new AfterSalesChatResponseDto
                        {
                            Success = true,
                            Reply = "What time would you prefer?",
                            ServiceRequestMode = true,
                            ServiceRequestRequired = true
                        };
                    }
                    else if (!extractedDate.HasValue && !string.IsNullOrEmpty(extractedTime))
                    {
                        return new AfterSalesChatResponseDto
                        {
                            Success = true,
                            Reply = "What date would you prefer?",
                            ServiceRequestMode = true,
                            ServiceRequestRequired = true
                        };
                    }
                    else
                    {
                        return new AfterSalesChatResponseDto
                        {
                            Success = true,
                            Reply = "What date and time would you prefer for the service?",
                            ServiceRequestMode = true,
                            ServiceRequestRequired = true
                        };
                    }
                }

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
                var action = (srDto.Action ?? "").Trim().ToLowerInvariant();
                bool isUpdate = action == "update" 
                             || action == "update_appointment" 
                             || action.Contains("update") 
                             || action.Contains("reschedule");
                bool isCreate = action == "create" 
                             || action == "create_service_request" 
                             || action.Contains("create") 
                             || (!isUpdate && (!string.IsNullOrWhiteSpace(srDto.ProblemDescription) || !string.IsNullOrWhiteSpace(srDto.Title)));

                if (isCreate)
                {
                    // Deterministic Validation Rules
                    var validationErrors = new List<string>();

                    var problemDesc = !string.IsNullOrWhiteSpace(srDto.ProblemDescription)
                        ? srDto.ProblemDescription.Trim()
                        : (!string.IsNullOrWhiteSpace(srDto.Description)
                            ? srDto.Description.Trim()
                            : (!string.IsNullOrWhiteSpace(srDto.Title)
                                ? srDto.Title.Trim()
                                : (!string.IsNullOrWhiteSpace(request.Message) ? request.Message.Trim() : "Customer reported hardware issue")));

                    if (string.IsNullOrWhiteSpace(problemDesc))
                    {
                        validationErrors.Add("Problem description is required.");
                    }

                    DateTime? parsedPreferredDate = null;
                    if (!string.IsNullOrWhiteSpace(srDto.PreferredDate))
                    {
                        var rawDate = srDto.PreferredDate.Trim();
                        var lowerDate = rawDate.ToLowerInvariant();
                        if (lowerDate.Contains("tomorrow"))
                        {
                            var cand = DateTime.UtcNow.Date.AddDays(1);
                            if (cand.DayOfWeek == DayOfWeek.Sunday) cand = cand.AddDays(1);
                            parsedPreferredDate = DateTime.SpecifyKind(cand, DateTimeKind.Utc);
                        }
                        else if (lowerDate.Contains("today"))
                        {
                            parsedPreferredDate = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Utc);
                        }
                        else if (DateTime.TryParse(rawDate, out var dt))
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
                            string[] formats = { "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy", "dd-MM-yyyy", "yyyy/MM/dd" };
                            if (DateTime.TryParseExact(rawDate, formats, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out var dtExact))
                            {
                                if (dtExact.Date < DateTime.UtcNow.Date)
                                {
                                    validationErrors.Add("Preferred appointment date cannot be in the past.");
                                }
                                if (dtExact.DayOfWeek == DayOfWeek.Sunday)
                                {
                                    validationErrors.Add("Service center is closed on Sundays. Please select Monday - Saturday.");
                                }
                                parsedPreferredDate = DateTime.SpecifyKind(dtExact.Date, DateTimeKind.Utc);
                            }
                            else
                            {
                                validationErrors.Add($"Invalid preferred date format: '{srDto.PreferredDate}'");
                            }
                        }

                        if (parsedPreferredDate.HasValue)
                        {
                            // Storewide maximum capacity check: Max 10 appointments per date
                            var dateCount = await db.ServiceRequests.CountAsync(sr =>
                                sr.PreferredDate.HasValue &&
                                sr.PreferredDate.Value.Date == parsedPreferredDate.Value.Date &&
                                sr.Status.ToLower() != "cancelled" &&
                                sr.Status.ToLower() != "canceled");

                            if (dateCount >= 10)
                            {
                                validationErrors.Add($"The selected date ({parsedPreferredDate.Value:yyyy-MM-dd}) has reached its maximum capacity of 10 service appointments. Please select another date.");
                            }
                        }
                    }
                    else
                    {
                        var cand = DateTime.UtcNow.Date.AddDays(2);
                        if (cand.DayOfWeek == DayOfWeek.Sunday) cand = cand.AddDays(1);
                        parsedPreferredDate = DateTime.SpecifyKind(cand, DateTimeKind.Utc);
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



                    if (validationErrors.Count > 0)
                    {
                        _logger.LogWarning("Deterministic validation failed on AI Service Request: {Errors}", string.Join("; ", validationErrors));
                        result.AgentTrace.Add($"[ASP.NET Core Validation Warning] {string.Join("; ", validationErrors)}");
                        var errorMsg = string.Join(" ", validationErrors);
                        if (!result.Reply.Contains(errorMsg))
                        {
                            result.Reply += $"\n\n[Notice: We could not schedule this appointment: {errorMsg}]";
                        }
                        result.ServiceRequest = null;
                        result.ServiceRequestRequired = true;
                        result.ServiceRequestMode = true;
                    }
                    else
                    {
                        // Assign authoritative Service Request Number
                        var maxId = await db.ServiceRequests.MaxAsync(sr => (int?)sr.ServiceRequestId) ?? 100;
                        var authoritativeSrNumber = $"SR-{(maxId + 1):D6}";
                        var provisionalSrNumber = srDto.ServiceRequestNumber;

                        var resolvedTitle = !string.IsNullOrWhiteSpace(srDto.Title)
                            ? srDto.Title.Trim()
                            : (!string.IsNullOrWhiteSpace(problemDesc)
                                ? (problemDesc.Length > 50 ? problemDesc[..47] + "..." : problemDesc)
                                : "Service Request");

                        var resolvedDesc = !string.IsNullOrWhiteSpace(srDto.Description)
                            ? srDto.Description.Trim()
                            : problemDesc;

                        ServiceTimeSlot? matchedSlot = null;
                        if (srDto.SlotId.HasValue && srDto.SlotId.Value > 0)
                        {
                            matchedSlot = await db.ServiceTimeSlots.FirstOrDefaultAsync(s => s.SlotId == srDto.SlotId.Value);
                        }
                        if (matchedSlot == null && !string.IsNullOrWhiteSpace(srDto.PreferredTime))
                        {
                            var cleanTime = srDto.PreferredTime.Trim().ToLowerInvariant();
                            matchedSlot = await db.ServiceTimeSlots.FirstOrDefaultAsync(s =>
                                s.IsActive &&
                                ((s.Label != null && s.Label.ToLower().Contains(cleanTime)) ||
                                 s.StartTime.ToLower() == cleanTime ||
                                 (s.StartTime + " - " + s.EndTime).ToLower() == cleanTime));
                        }
                        if (matchedSlot == null)
                        {
                            matchedSlot = await db.ServiceTimeSlots.Where(s => s.IsActive).OrderBy(s => s.DisplayOrder).FirstOrDefaultAsync();
                        }

                        var targetUserId = request.UserId > 0 ? request.UserId : 1;
                        var userExists = await db.Users.AnyAsync(u => u.UserId == targetUserId);
                        if (!userExists)
                        {
                            var fallbackUser = await db.Users.Select(u => u.UserId).FirstOrDefaultAsync();
                            targetUserId = fallbackUser > 0 ? fallbackUser : 1;
                        }

                        var newServiceRequest = new ServiceRequest
                        {
                            ServiceRequestNumber = authoritativeSrNumber,
                            UserId = targetUserId,
                            SlotId = matchedSlot?.SlotId,
                            Title = resolvedTitle,
                            Description = resolvedDesc,
                            PreferredDate = parsedPreferredDate,
                            PreferredTime = matchedSlot?.Label ?? srDto.PreferredTime,
                            Status = "Booked",
                            CreatedAt = DateTime.UtcNow,
                            UpdatedAt = DateTime.UtcNow
                        };

                        db.ServiceRequests.Add(newServiceRequest);
                        await db.SaveChangesAsync();

                        _logger.LogInformation("ASP.NET Core successfully persisted ServiceRequest #{Id} ({SrNumber}) with Slot #{SlotId} for User {UserId}",
                            newServiceRequest.ServiceRequestId, newServiceRequest.ServiceRequestNumber, newServiceRequest.SlotId, newServiceRequest.UserId);

                        // Update AI DTO response with authoritative DB identifiers
                        srDto.Id = newServiceRequest.ServiceRequestId;
                        srDto.ServiceRequestId = newServiceRequest.ServiceRequestId;
                        srDto.ServiceRequestNumber = newServiceRequest.ServiceRequestNumber;
                        srDto.SlotId = newServiceRequest.SlotId;
                        srDto.SlotLabel = matchedSlot?.Label ?? newServiceRequest.PreferredTime;
                        srDto.Title = newServiceRequest.Title;
                        srDto.Description = newServiceRequest.Description;
                        srDto.Status = newServiceRequest.Status;
                        srDto.CreatedAt = newServiceRequest.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ");

                        if (result.Ticket != null)
                        {
                            result.Ticket.TicketId = newServiceRequest.ServiceRequestId;
                            result.Ticket.RmaNumber = newServiceRequest.ServiceRequestNumber;
                            result.Ticket.Status = "Booked";
                            result.Ticket.CreatedAt = newServiceRequest.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ssZ");
                        }

                        // Replace any provisional AI number in the reply text with the real authoritative number
                        if (!string.IsNullOrEmpty(provisionalSrNumber) && !string.IsNullOrEmpty(result.Reply))
                        {
                            result.Reply = result.Reply.Replace(provisionalSrNumber, authoritativeSrNumber);
                        }
                    }
                }
                else if (isUpdate)
                {
                    // Find existing Service Request by ID or SR-Number
                    var existing = await db.ServiceRequests.FirstOrDefaultAsync(sr =>
                        (srDto.ServiceRequestId.HasValue && sr.ServiceRequestId == srDto.ServiceRequestId.Value) ||
                        (!string.IsNullOrEmpty(srDto.ServiceRequestNumber) && sr.ServiceRequestNumber.ToUpper() == srDto.ServiceRequestNumber.ToUpper()));

                    if (existing != null)
                    {
                        if (!string.IsNullOrWhiteSpace(srDto.PreferredDate))
                        {
                            var rawDate = srDto.PreferredDate.Trim();
                            var lowerDate = rawDate.ToLowerInvariant();
                            if (lowerDate.Contains("tomorrow"))
                            {
                                var cand = DateTime.UtcNow.Date.AddDays(1);
                                if (cand.DayOfWeek == DayOfWeek.Sunday) cand = cand.AddDays(1);
                                existing.PreferredDate = DateTime.SpecifyKind(cand, DateTimeKind.Utc);
                            }
                            else if (lowerDate.Contains("today"))
                            {
                                existing.PreferredDate = DateTime.SpecifyKind(DateTime.UtcNow.Date, DateTimeKind.Utc);
                            }
                            else if (DateTime.TryParse(rawDate, out var dt))
                            {
                                existing.PreferredDate = DateTime.SpecifyKind(dt.Date, DateTimeKind.Utc);
                            }
                        }

                        if (!string.IsNullOrWhiteSpace(srDto.PreferredTime) || srDto.SlotId.HasValue)
                        {
                            ServiceTimeSlot? updateSlot = null;
                            if (srDto.SlotId.HasValue && srDto.SlotId.Value > 0)
                            {
                                updateSlot = await db.ServiceTimeSlots.FirstOrDefaultAsync(s => s.SlotId == srDto.SlotId.Value);
                            }
                            if (updateSlot == null && !string.IsNullOrWhiteSpace(srDto.PreferredTime))
                            {
                                var cleanTime = srDto.PreferredTime.Trim().ToLowerInvariant();
                                updateSlot = await db.ServiceTimeSlots.FirstOrDefaultAsync(s =>
                                    s.IsActive &&
                                    ((s.Label != null && s.Label.ToLower().Contains(cleanTime)) ||
                                     s.StartTime.ToLower() == cleanTime ||
                                     (s.StartTime + " - " + s.EndTime).ToLower() == cleanTime));
                            }
                            if (updateSlot != null)
                            {
                                existing.SlotId = updateSlot.SlotId;
                                existing.PreferredTime = updateSlot.Label ?? srDto.PreferredTime.Trim();
                            }
                            else if (!string.IsNullOrWhiteSpace(srDto.PreferredTime))
                            {
                                existing.PreferredTime = srDto.PreferredTime.Trim();
                            }
                        }

                        existing.Status = "SCHEDULED";
                        existing.UpdatedAt = DateTime.UtcNow;
                        await db.SaveChangesAsync();

                        _logger.LogInformation("ASP.NET Core successfully updated appointment for ServiceRequest {SrNumber} to Slot #{SlotId}", existing.ServiceRequestNumber, existing.SlotId);

                        srDto.ServiceRequestId = existing.ServiceRequestId;
                        srDto.ServiceRequestNumber = existing.ServiceRequestNumber;
                        srDto.SlotId = existing.SlotId;
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