using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace backend.Tests;

public class OrdersAndFiltersTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly CustomWebApplicationFactory _factory;
    private readonly HttpClient _client;

    public OrdersAndFiltersTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private HttpClient CreateAuthenticatedClient(int userId, string email, string role)
    {
        var client = _factory.CreateClient();
        var token = CustomWebApplicationFactory.GenerateToken(userId, email, role);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    private async Task<Product> SeedProductAsync(string name, decimal price, int stockQuantity)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var category = await db.Categories.FirstOrDefaultAsync();
        if (category == null)
        {
            category = new Category
            {
                Name = "Components " + Guid.NewGuid().ToString("N")[..6],
                Description = "Test components category"
            };
            db.Categories.Add(category);
            await db.SaveChangesAsync();
        }

        var product = new Product
        {
            CategoryId = category.CategoryId,
            Name = name,
            Brand = "PCForge",
            Model = "TestModel",
            Price = price,
            StockQuantity = stockQuantity,
            WarrantyMonths = 24
        };

        db.Products.Add(product);
        await db.SaveChangesAsync();
        return product;
    }

    // -------------------------------------------------------------------------
    // TEST 1: COD over 100,000 rejected
    // -------------------------------------------------------------------------
    [Fact]
    public async Task CreateOrder_CodOver100000_ShouldBeRejectedWithBadRequest()
    {
        var product = await SeedProductAsync("High-End GPU " + Guid.NewGuid().ToString("N")[..4], 60000m, 10);
        var customerClient = CreateAuthenticatedClient(3, "alex@example.com", "Customer");

        var payload = new CreateOrderDto
        {
            ShippingAddress = "No. 12, Galle Road, Colombo",
            PaymentMethod = "Cash on Delivery",
            Items = new List<CreateOrderItemDto>
            {
                new() { ProductId = product.ProductId, Quantity = 2 } // Total = 120,000 > 100,000
            }
        };

        var response = await customerClient.PostAsJsonAsync("/api/Orders", payload);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains("Cash on delivery (COD) is only allowed for orders up to LKR 100,000", content);
    }

    // -------------------------------------------------------------------------
    // TEST 2: COD at exactly 100,000 accepted
    // -------------------------------------------------------------------------
    [Fact]
    public async Task CreateOrder_CodAtExactly100000_ShouldBeAcceptedWithOrderPlacedStatus()
    {
        var product = await SeedProductAsync("Mid-Range GPU " + Guid.NewGuid().ToString("N")[..4], 50000m, 10);
        var customerClient = CreateAuthenticatedClient(3, "alex@example.com", "Customer");

        var payload = new CreateOrderDto
        {
            ShippingAddress = "No. 12, Galle Road, Colombo",
            PaymentMethod = "Cash on Delivery",
            Items = new List<CreateOrderItemDto>
            {
                new() { ProductId = product.ProductId, Quantity = 2 } // Total = exactly 100,000
            }
        };

        var response = await customerClient.PostAsJsonAsync("/api/Orders", payload);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var order = await response.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.NotNull(order);
        Assert.Equal(100000m, order.TotalAmount);
        Assert.Equal("Order placed", order.Status);
    }

    // -------------------------------------------------------------------------
    // TEST 3: Invalid status jumps rejected
    // -------------------------------------------------------------------------
    [Fact]
    public async Task UpdateOrderStatus_InvalidStatusJumps_ShouldBeRejected()
    {
        var product = await SeedProductAsync("CPU " + Guid.NewGuid().ToString("N")[..4], 25000m, 10);
        var customerClient = CreateAuthenticatedClient(3, "alex@example.com", "Customer");
        var staffClient = CreateAuthenticatedClient(2, "sarah@pcforge.com", "Staff");

        // 1. Create order (Initial status: "Order placed", COD)
        var createResp = await customerClient.PostAsJsonAsync("/api/Orders", new CreateOrderDto
        {
            ShippingAddress = "No. 10, Colombo",
            PaymentMethod = "Cash on Delivery",
            Items = new List<CreateOrderItemDto> { new() { ProductId = product.ProductId, Quantity = 1 } }
        });
        createResp.EnsureSuccessStatusCode();
        var order = await createResp.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.NotNull(order);

        // 2. Invalid jump: "Order placed" -> "Paid & Completed" (skipping 3 steps)
        var jumpResp1 = await staffClient.PatchAsJsonAsync($"/api/Orders/{order.OrderId}/status", new UpdateOrderStatusDto
        {
            Status = "Paid & Completed"
        });
        Assert.Equal(HttpStatusCode.BadRequest, jumpResp1.StatusCode);

        // 3. Invalid jump: "Order placed" -> "Ready for delivery" (skipping Processing)
        var jumpResp2 = await staffClient.PatchAsJsonAsync($"/api/Orders/{order.OrderId}/status", new UpdateOrderStatusDto
        {
            Status = "Ready for delivery"
        });
        Assert.Equal(HttpStatusCode.BadRequest, jumpResp2.StatusCode);

        // 4. Invalid cross-method jump: COD order moving to Store Pickup status "Ready for pickup"
        var jumpResp3 = await staffClient.PatchAsJsonAsync($"/api/Orders/{order.OrderId}/status", new UpdateOrderStatusDto
        {
            Status = "Ready for pickup"
        });
        Assert.Equal(HttpStatusCode.BadRequest, jumpResp3.StatusCode);

        // 5. Valid forward step: "Order placed" -> "Processing"
        var validResp = await staffClient.PatchAsJsonAsync($"/api/Orders/{order.OrderId}/status", new UpdateOrderStatusDto
        {
            Status = "Processing"
        });
        Assert.Equal(HttpStatusCode.OK, validResp.StatusCode);

        // 6. Invalid backward step: "Processing" -> "Order placed"
        var backwardResp = await staffClient.PatchAsJsonAsync($"/api/Orders/{order.OrderId}/status", new UpdateOrderStatusDto
        {
            Status = "Order placed"
        });
        Assert.Equal(HttpStatusCode.BadRequest, backwardResp.StatusCode);
    }

    // -------------------------------------------------------------------------
    // TEST 4: Cancel allowed/blocked per status
    // -------------------------------------------------------------------------
    [Fact]
    public async Task CancelOrder_AllowedAndBlockedPerStatus_ShouldBeEnforced()
    {
        var product = await SeedProductAsync("RAM " + Guid.NewGuid().ToString("N")[..4], 15000m, 20);
        var customerClient = CreateAuthenticatedClient(3, "alex@example.com", "Customer");
        var staffClient = CreateAuthenticatedClient(2, "sarah@pcforge.com", "Staff");

        // Helper to place an order
        async Task<OrderDetailDto> PlaceTestOrder(string paymentMethod = "Cash on Delivery")
        {
            var res = await customerClient.PostAsJsonAsync("/api/Orders", new CreateOrderDto
            {
                ShippingAddress = "Colombo",
                PaymentMethod = paymentMethod,
                Items = new List<CreateOrderItemDto> { new() { ProductId = product.ProductId, Quantity = 1 } }
            });
            res.EnsureSuccessStatusCode();
            return (await res.Content.ReadFromJsonAsync<OrderDetailDto>())!;
        }

        // Case A: Cancel allowed in "Order placed"
        var orderA = await PlaceTestOrder();
        var cancelA = await customerClient.PostAsync($"/api/Orders/{orderA.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelA.StatusCode);
        var orderAResult = await cancelA.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.Equal("Cancelled", orderAResult!.Status);

        // Case B: Cancel allowed in "Processing"
        var orderB = await PlaceTestOrder();
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderB.OrderId}/status", new UpdateOrderStatusDto { Status = "Processing" });
        var cancelB = await customerClient.PostAsync($"/api/Orders/{orderB.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelB.StatusCode);
        var orderBResult = await cancelB.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.Equal("Cancelled", orderBResult!.Status);

        // Case C: Cancel blocked in "Ready for delivery" (COD)
        var orderC = await PlaceTestOrder("Cash on Delivery");
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderC.OrderId}/status", new UpdateOrderStatusDto { Status = "Processing" });
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderC.OrderId}/status", new UpdateOrderStatusDto { Status = "Ready for delivery" });
        var cancelC = await customerClient.PostAsync($"/api/Orders/{orderC.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.BadRequest, cancelC.StatusCode);

        // Case D: Cancel blocked in "Out for delivery" (COD)
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderC.OrderId}/status", new UpdateOrderStatusDto { Status = "Out for delivery" });
        var cancelD = await customerClient.PostAsync($"/api/Orders/{orderC.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.BadRequest, cancelD.StatusCode);

        // Case E: Cancel blocked in "Ready for pickup" (Store Pickup)
        var orderE = await PlaceTestOrder("Store Pickup");
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderE.OrderId}/status", new UpdateOrderStatusDto { Status = "Processing" });
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderE.OrderId}/status", new UpdateOrderStatusDto { Status = "Ready for pickup" });
        var cancelE = await customerClient.PostAsync($"/api/Orders/{orderE.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.BadRequest, cancelE.StatusCode);

        // Case F: Cancel blocked in "Paid & Completed"
        await staffClient.PatchAsJsonAsync($"/api/Orders/{orderE.OrderId}/status", new UpdateOrderStatusDto { Status = "Paid & Completed" });
        var cancelF = await customerClient.PostAsync($"/api/Orders/{orderE.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.BadRequest, cancelF.StatusCode);
    }

    // -------------------------------------------------------------------------
    // TEST 5: Double-cancel is idempotent and restocks only once
    // -------------------------------------------------------------------------
    [Fact]
    public async Task CancelOrder_DoubleCancel_ShouldBeIdempotentAndRestockOnlyOnce()
    {
        var product = await SeedProductAsync("SSD " + Guid.NewGuid().ToString("N")[..4], 12000m, 20);
        var customerClient = CreateAuthenticatedClient(3, "alex@example.com", "Customer");

        // 1. Place order for quantity 5
        var createResp = await customerClient.PostAsJsonAsync("/api/Orders", new CreateOrderDto
        {
            ShippingAddress = "Colombo",
            PaymentMethod = "Cash on Delivery",
            Items = new List<CreateOrderItemDto> { new() { ProductId = product.ProductId, Quantity = 5 } }
        });
        createResp.EnsureSuccessStatusCode();
        var order = await createResp.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.NotNull(order);

        // Verify stock is now 15 (20 - 5)
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var p = await db.Products.FindAsync(product.ProductId);
            Assert.Equal(15, p!.StockQuantity);
        }

        // 2. First cancellation
        var cancelResp1 = await customerClient.PostAsync($"/api/Orders/{order.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelResp1.StatusCode);
        var cancelledOrder = await cancelResp1.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.Equal("Cancelled", cancelledOrder!.Status);

        // Verify stock restored to 20
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var p = await db.Products.FindAsync(product.ProductId);
            Assert.Equal(20, p!.StockQuantity);
        }

        // 3. Second cancellation (idempotent tap / concurrent cancel)
        var cancelResp2 = await customerClient.PostAsync($"/api/Orders/{order.OrderId}/cancel", null);
        Assert.Equal(HttpStatusCode.OK, cancelResp2.StatusCode);
        var reCancelledOrder = await cancelResp2.Content.ReadFromJsonAsync<OrderDetailDto>();
        Assert.Equal("Cancelled", reCancelledOrder!.Status);

        // Verify stock is STILL 20, NOT 25!
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var p = await db.Products.FindAsync(product.ProductId);
            Assert.Equal(20, p!.StockQuantity);
        }
    }

    // -------------------------------------------------------------------------
    // TEST 6: Dynamic filter showing for a newly created category
    // -------------------------------------------------------------------------
    [Fact]
    public async Task CategoryFilters_NewlyCreatedCategoryAndFilter_ShouldBeRetrievable()
    {
        var staffClient = CreateAuthenticatedClient(2, "sarah@pcforge.com", "Staff");
        var publicClient = _factory.CreateClient();

        // 1. Staff creates new category "Custom GPU"
        var catName = "Custom GPU " + Guid.NewGuid().ToString("N")[..4];
        var createCatResp = await staffClient.PostAsJsonAsync("/api/Categories", new CreateCategoryDto
        {
            Name = catName,
            Description = "Custom enthusiast GPUs"
        });
        createCatResp.EnsureSuccessStatusCode();
        var category = await createCatResp.Content.ReadFromJsonAsync<CategoryDto>();
        Assert.NotNull(category);

        // 2. Staff adds filter "cuda_cores" with options
        var filterPayload = new CreateCategoryFilterDto
        {
            FilterKey = "cuda_cores",
            DisplayName = "CUDA Cores",
            FilterType = "multiselect",
            IsFilterable = true,
            Options = new List<string> { "2560", "4352", "5888", "16384" }
        };

        var addFilterResp = await staffClient.PostAsJsonAsync($"/api/Categories/{category.CategoryId}/filters", filterPayload);
        addFilterResp.EnsureSuccessStatusCode();
        var addedFilter = await addFilterResp.Content.ReadFromJsonAsync<CategoryFilterDto>();
        Assert.NotNull(addedFilter);
        Assert.Equal("cuda_cores", addedFilter.FilterKey);
        Assert.Equal("CUDA Cores", addedFilter.DisplayName);

        // 3. Client retrieves category filters
        var getFiltersResp = await publicClient.GetAsync($"/api/Categories/{category.CategoryId}/filters");
        getFiltersResp.EnsureSuccessStatusCode();
        var filters = await getFiltersResp.Content.ReadFromJsonAsync<List<CategoryFilterDto>>();
        Assert.NotNull(filters);

        var cudaFilter = filters.FirstOrDefault(f => f.FilterKey == "cuda_cores");
        Assert.NotNull(cudaFilter);
        Assert.Equal("CUDA Cores", cudaFilter.DisplayName);
        Assert.True(cudaFilter.Options.Count >= 4);
        Assert.Contains(cudaFilter.Options, o => o.Value == "16384");
    }

    // -------------------------------------------------------------------------
    // TEST 7: Master Filter lifecycle (Create, Update, Get, Delete)
    // -------------------------------------------------------------------------
    [Fact]
    public async Task MasterFilters_Create_Update_Get_Delete_Lifecycle()
    {
        var staffClient = CreateAuthenticatedClient(2, "sarah@pcforge.com", "Staff");
        var publicClient = _factory.CreateClient();

        // 1. Staff creates master filter "refresh_rate"
        var createPayload = new CreateMasterFilterDto
        {
            FilterKey = "refresh_rate",
            DisplayName = "Refresh Rate",
            FilterType = "multiselect",
            Unit = "Hz",
            Options = new List<string> { "144Hz", "165Hz", "240Hz" }
        };

        var createResp = await staffClient.PostAsJsonAsync("/api/Filters", createPayload);
        createResp.EnsureSuccessStatusCode();
        var created = await createResp.Content.ReadFromJsonAsync<MasterFilterDto>();
        Assert.NotNull(created);
        Assert.Equal("refresh_rate", created.FilterKey);
        Assert.Equal("Refresh Rate", created.DisplayName);
        Assert.Equal("Hz", created.Unit);
        Assert.Equal(3, created.Options.Count);

        // 2. Client retrieves all master filters
        var getResp = await publicClient.GetAsync("/api/Filters");
        getResp.EnsureSuccessStatusCode();
        var allFilters = await getResp.Content.ReadFromJsonAsync<List<MasterFilterDto>>();
        Assert.NotNull(allFilters);
        Assert.Contains(allFilters, f => f.FilterKey == "refresh_rate");

        // 3. Staff updates filter
        var updatePayload = new UpdateMasterFilterDto
        {
            DisplayName = "Display Refresh Rate",
            FilterType = "multiselect",
            Unit = "Hz",
            Options = new List<string> { "144Hz", "165Hz", "240Hz", "360Hz" }
        };

        var updateResp = await staffClient.PutAsJsonAsync($"/api/Filters/{created.FilterId}", updatePayload);
        updateResp.EnsureSuccessStatusCode();
        var updated = await updateResp.Content.ReadFromJsonAsync<MasterFilterDto>();
        Assert.NotNull(updated);
        Assert.Equal("Display Refresh Rate", updated.DisplayName);
        Assert.Equal(4, updated.Options.Count);
        Assert.Contains(updated.Options, o => o.Value == "360Hz");

        // 4. Staff deletes filter
        var deleteResp = await staffClient.DeleteAsync($"/api/Filters/{created.FilterId}");
        deleteResp.EnsureSuccessStatusCode();

        // 5. Verify 404 on get by id
        var getDeletedResp = await publicClient.GetAsync($"/api/Filters/{created.FilterId}");
        Assert.Equal(System.Net.HttpStatusCode.NotFound, getDeletedResp.StatusCode);
    }

    // -------------------------------------------------------------------------
    // TEST 8: Assign Master Filter to Category copies options from Database
    // -------------------------------------------------------------------------
    [Fact]
    public async Task CategoryFilters_AssignFromMasterFilter_CopiesOptionsFromDatabase()
    {
        var staffClient = CreateAuthenticatedClient(2, "sarah@pcforge.com", "Staff");
        var publicClient = _factory.CreateClient();

        // 1. Staff creates master filter in DB with options
        var masterPayload = new CreateMasterFilterDto
        {
            FilterKey = "vram_db_spec_" + Guid.NewGuid().ToString("N")[..4],
            DisplayName = "VRAM DB Spec",
            FilterType = "multiselect",
            Unit = "GB",
            Options = new List<string> { "8GB", "12GB", "16GB", "24GB" }
        };
        var masterResp = await staffClient.PostAsJsonAsync("/api/Filters", masterPayload);
        masterResp.EnsureSuccessStatusCode();
        var master = await masterResp.Content.ReadFromJsonAsync<MasterFilterDto>();
        Assert.NotNull(master);

        // 2. Staff creates a category
        var catResp = await staffClient.PostAsJsonAsync("/api/Categories", new CreateCategoryDto
        {
            Name = "Enthusiast GPUs " + Guid.NewGuid().ToString("N")[..4],
            Description = "Enthusiast GPUs"
        });
        catResp.EnsureSuccessStatusCode();
        var cat = await catResp.Content.ReadFromJsonAsync<CategoryDto>();
        Assert.NotNull(cat);

        // 3. Staff assigns master filter to category WITHOUT passing options (should copy from DB)
        var assignPayload = new CreateCategoryFilterDto
        {
            MasterFilterId = master.FilterId,
            FilterKey = master.FilterKey
        };
        var assignResp = await staffClient.PostAsJsonAsync($"/api/Categories/{cat.CategoryId}/filters", assignPayload);
        assignResp.EnsureSuccessStatusCode();
        var assigned = await assignResp.Content.ReadFromJsonAsync<CategoryFilterDto>();
        Assert.NotNull(assigned);
        Assert.Equal(master.FilterKey, assigned.FilterKey);
        Assert.Equal(master.DisplayName, assigned.DisplayName);
        Assert.Equal(4, assigned.Options.Count);
        Assert.Contains(assigned.Options, o => o.Value == "24GB");

        // 4. Verify deleting master filter is blocked while assigned to category
        var deleteResp = await staffClient.DeleteAsync($"/api/Filters/{master.FilterId}");
        Assert.Equal(System.Net.HttpStatusCode.BadRequest, deleteResp.StatusCode);

        // 5. Remove filter from category
        var removeResp = await staffClient.DeleteAsync($"/api/Categories/{cat.CategoryId}/filters/{assigned.FilterId}");
        removeResp.EnsureSuccessStatusCode();

        // 6. Now deleting master filter succeeds
        var deleteAfterResp = await staffClient.DeleteAsync($"/api/Filters/{master.FilterId}");
        deleteAfterResp.EnsureSuccessStatusCode();
    }
}
