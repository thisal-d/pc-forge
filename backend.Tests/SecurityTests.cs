using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using PCForge.Api.Data;
using PCForge.Api.DTOs;
using PCForge.Api.Models;

namespace backend.Tests;

public class SecurityTests : IClassFixture<CustomWebApplicationFactory>
{
    private readonly CustomWebApplicationFactory _factory;
    private readonly HttpClient _client;

    public SecurityTests(CustomWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    private void SetBearerToken(string token)
    {
        _client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
    }

    private void ClearBearerToken()
    {
        _client.DefaultRequestHeaders.Authorization = null;
    }

    // =========================================================================
    // 1. REGISTRATION SECURITY TESTS
    // =========================================================================
    [Fact]
    public async Task Register_WithRoleAdmin_ShouldIgnoreRequestedRole_AndAssignCustomer()
    {
        ClearBearerToken();
        var payload = new
        {
            email = $"attacker_{Guid.NewGuid():N}@example.com",
            password = "Password123!",
            role = "Admin",
            firstName = "Attacker",
            lastName = "Admin"
        };

        var response = await _client.PostAsJsonAsync("/api/auth/register", payload);
        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadFromJsonAsync<AuthResponseDto>();
        Assert.NotNull(content);
        Assert.True(content.Success);
        // The user must NEVER be granted the Admin role via public registration
        Assert.Equal("Customer", content.Role);

        // Verify in database that RoleId is indeed Customer (RoleId 1)
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = db.Users.FirstOrDefault(u => u.Email == payload.email);
        Assert.NotNull(user);
        Assert.Equal(1, user.RoleId);
    }

    // =========================================================================
    // 2. PROFILE UPDATE & ACCOUNT TAKEOVER TESTS
    // =========================================================================
    [Fact]
    public async Task UpdateProfile_WithoutToken_MustReturnUnauthorized()
    {
        ClearBearerToken();
        var payload = new
        {
            firstName = "AnonymousHacker"
        };

        var response = await _client.PutAsJsonAsync("/api/auth/profile", payload);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UpdateProfile_ChangePasswordWithoutCurrentPassword_MustReturnBadRequest()
    {
        var token = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(token);

        var payload = new
        {
            newPassword = "NewSecretPassword123!"
            // Missing currentPassword
        };

        var response = await _client.PutAsJsonAsync("/api/auth/profile", payload);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UpdateProfile_ChangePasswordWithIncorrectCurrentPassword_MustReturnBadRequest()
    {
        var token = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(token);

        var payload = new
        {
            currentPassword = "WrongPassword!",
            newPassword = "NewSecretPassword123!"
        };

        var response = await _client.PutAsJsonAsync("/api/auth/profile", payload);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    // =========================================================================
    // 3. STAFF CONTROLLER RBAC TESTS
    // =========================================================================
    [Fact]
    public async Task StaffController_AnonymousAccess_MustReturnUnauthorized()
    {
        ClearBearerToken();
        var response = await _client.GetAsync("/api/staff");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);

        var resetResponse = await _client.PostAsJsonAsync("/api/staff/1/reset-password", new { newPassword = "Reset123!" });
        Assert.Equal(HttpStatusCode.Unauthorized, resetResponse.StatusCode);
    }

    [Fact]
    public async Task StaffController_CustomerAccess_MustReturnForbidden()
    {
        var token = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(token);

        var response = await _client.GetAsync("/api/staff");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task StaffController_AdminAccess_MustSucceed()
    {
        var token = CustomWebApplicationFactory.GenerateToken(1, "admin@pcforge.com", "Admin");
        SetBearerToken(token);

        var response = await _client.GetAsync("/api/staff");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task StaffController_StaffAccess_MustSucceed()
    {
        var token = CustomWebApplicationFactory.GenerateToken(2, "staff@pcforge.com", "Staff");
        SetBearerToken(token);

        var response = await _client.GetAsync("/api/staff");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task StaffController_StaffCreateStaff_MustReturnForbidden()
    {
        var token = CustomWebApplicationFactory.GenerateToken(2, "staff@pcforge.com", "Staff");
        SetBearerToken(token);

        var createDto = new CreateStaffDto
        {
            FirstName = "Unauthorized",
            LastName = "Creation",
            Email = "unauth.staff@pcforge.com",
            Department = "Custom PC Assembly",
            Phone = "+94 77 111 2222",
            Status = "Active"
        };

        var response = await _client.PostAsJsonAsync("/api/staff", createDto);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task StaffController_CreateStaff_MustAssignStaffRoleAndNotCustomer()
    {
        var token = CustomWebApplicationFactory.GenerateToken(1, "admin@pcforge.com", "Admin");
        SetBearerToken(token);

        var createDto = new CreateStaffDto
        {
            FirstName = "Marcus",
            LastName = "Vance",
            Email = "marcus.vance@pcforge.com",
            Department = "Custom PC Assembly",
            Phone = "+94 77 999 8888",
            Specialization = "Water-cooling & cable management",
            Status = "Active",
            Password = "StaffPassword123!"
        };

        var response = await _client.PostAsJsonAsync("/api/staff", createDto);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var staff = await response.Content.ReadFromJsonAsync<StaffResponseDto>();
        Assert.NotNull(staff);
        Assert.Equal("Staff", staff.Role);

        // Verify login with newly created credentials returns Staff role (NOT Customer)
        ClearBearerToken();
        var loginResp = await _client.PostAsJsonAsync("/api/auth/login", new LoginDto
        {
            Email = "marcus.vance@pcforge.com",
            Password = "StaffPassword123!"
        });
        Assert.Equal(HttpStatusCode.OK, loginResp.StatusCode);
        var loginResult = await loginResp.Content.ReadFromJsonAsync<AuthResponseDto>();
        Assert.NotNull(loginResult);
        Assert.Equal("Staff", loginResult.Role);
        Assert.NotEqual("Customer", loginResult.Role);
    }

    // =========================================================================
    // 4. CATEGORIES & PRODUCTS CONTROLLER RBAC TESTS
    // =========================================================================
    [Fact]
    public async Task CategoriesController_Mutations_RequireStaffOrAdminRole()
    {
        // 1. Anonymous create category -> 401
        ClearBearerToken();
        var responseAnon = await _client.PostAsJsonAsync("/api/categories", new { name = "NewCategory" });
        Assert.Equal(HttpStatusCode.Unauthorized, responseAnon.StatusCode);

        // 2. Customer create category -> 403
        var custToken = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(custToken);
        var responseCust = await _client.PostAsJsonAsync("/api/categories", new { name = "NewCategory" });
        Assert.Equal(HttpStatusCode.Forbidden, responseCust.StatusCode);

        // 3. Staff create category -> Allowed (Staff can manage categories)
        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "staff@pcforge.com", "Staff");
        SetBearerToken(staffToken);
        var responseStaff = await _client.PostAsJsonAsync("/api/categories", new { name = "StaffCat_" + Guid.NewGuid().ToString("N")[..6] });
        Assert.Equal(HttpStatusCode.Created, responseStaff.StatusCode);

        // 4. Admin create category -> Allowed
        var adminToken = CustomWebApplicationFactory.GenerateToken(1, "admin@pcforge.com", "Admin");
        SetBearerToken(adminToken);
        var responseAdmin = await _client.PostAsJsonAsync("/api/categories", new { name = "UniqueCat_" + Guid.NewGuid().ToString("N")[..6] });
        Assert.Equal(HttpStatusCode.Created, responseAdmin.StatusCode);
    }

    [Fact]
    public async Task ProductsController_MutationsWithoutStaffToken_MustBeRejected()
    {
        ClearBearerToken();
        var patchResponseAnon = await _client.PatchAsJsonAsync("/api/products/1/stock", new { stockQuantity = 50 });
        Assert.Equal(HttpStatusCode.Unauthorized, patchResponseAnon.StatusCode);

        var custToken = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(custToken);
        var patchResponseCust = await _client.PatchAsJsonAsync("/api/products/1/stock", new { stockQuantity = 50 });
        Assert.Equal(HttpStatusCode.Forbidden, patchResponseCust.StatusCode);
    }

    [Fact]
    public async Task ProductsController_DeleteProduct_Anonymous_MustReturnUnauthorized()
    {
        ClearBearerToken();
        var response = await _client.DeleteAsync("/api/products/1");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ProductsController_DeleteProduct_Customer_MustReturnForbidden()
    {
        var custToken = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(custToken);
        var response = await _client.DeleteAsync("/api/products/1");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ProductsController_DeleteProduct_Staff_MustSucceed()
    {
        int createdProductId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var category = new Category { Name = "Test Delete Cat", CreatedAt = DateTime.UtcNow };
            db.Categories.Add(category);
            db.SaveChanges();

            var product = new Product
            {
                CategoryId = category.CategoryId,
                Name = "Temporary Delete Test Product",
                Brand = "TestBrand",
                Price = 99.99m,
                StockQuantity = 5,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.Products.Add(product);
            db.SaveChanges();
            createdProductId = product.ProductId;
        }

        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        SetBearerToken(staffToken);

        var response = await _client.DeleteAsync($"/api/products/{createdProductId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // =========================================================================
    // 5. ORDERS & IDOR TESTS
    // =========================================================================
    [Fact]
    public async Task OrdersController_AnonymousAccess_MustReturnUnauthorized()
    {
        ClearBearerToken();
        var getOrdersResponse = await _client.GetAsync("/api/orders");
        Assert.Equal(HttpStatusCode.Unauthorized, getOrdersResponse.StatusCode);

        var getOrderByIdResponse = await _client.GetAsync("/api/orders/1");
        Assert.Equal(HttpStatusCode.Unauthorized, getOrderByIdResponse.StatusCode);

        var postOrderResponse = await _client.PostAsJsonAsync("/api/orders", new { shippingAddress = "123 St", items = new[] { new { productId = 1, quantity = 1 } } });
        Assert.Equal(HttpStatusCode.Unauthorized, postOrderResponse.StatusCode);
    }

    [Fact]
    public async Task OrdersController_CustomerViewingAnotherCustomersOrder_MustReturnForbidden()
    {
        // Seed an order belonging to User 4 (Bob)
        int bobsOrderId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var order = new Order
            {
                UserId = 4, // Bob
                TotalAmount = 299.00m,
                Status = "Paid",
                ShippingAddress = "Bob's House",
                PaymentMethod = "Credit Card",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.Orders.Add(order);
            db.SaveChanges();
            bobsOrderId = order.OrderId;
        }

        // Alex (User 3) attempts to view Bob's order
        var alexToken = CustomWebApplicationFactory.GenerateToken(3, "alex@example.com", "Customer");
        SetBearerToken(alexToken);

        var response = await _client.GetAsync($"/api/orders/{bobsOrderId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        // Staff (User 2) viewing Bob's order -> Should succeed
        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        SetBearerToken(staffToken);

        var staffResponse = await _client.GetAsync($"/api/orders/{bobsOrderId}");
        Assert.Equal(HttpStatusCode.OK, staffResponse.StatusCode);
    }

    // =========================================================================
    // 6. CUSTOM BUILD & SUPPORT TICKET FALLBACK REMOVAL TESTS
    // =========================================================================
    [Fact]
    public async Task SupportTickets_AnonymousCreate_MustReturnUnauthorized()
    {
        ClearBearerToken();
        var payload = new
        {
            subject = "Broken GPU",
            issueType = "Defective Item",
            description = "My GPU is not displaying video"
        };
        var response = await _client.PostAsJsonAsync("/api/supporttickets", payload);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task CustomBuilds_AnonymousCreate_MustReturnUnauthorized()
    {
        ClearBearerToken();
        var payload = new
        {
            buildName = "Anonymous Rig",
            components = new[]
            {
                new { productId = 1, slotType = "cpu" }
            }
        };
        var response = await _client.PostAsJsonAsync("/api/custombuilds", payload);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task CustomBuilds_ModifyAnotherUsersBuild_MustReturnForbidden()
    {
        int alexBuildId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var build = new CustomBuild
            {
                UserId = 3, // Alex
                BuildName = "Alex's Build",
                TotalPrice = 1500m,
                EstimatedWattage = 500,
                Status = "Changes Requested",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.CustomBuilds.Add(build);
            db.SaveChanges();
            alexBuildId = build.BuildId;
        }

        // Bob (User 4) attempts to modify and resubmit Alex's build
        var bobToken = CustomWebApplicationFactory.GenerateToken(4, "bob@example.com", "Customer");
        SetBearerToken(bobToken);

        var payload = new
        {
            buildName = "Bob Hacked Alex Rig",
            components = new[]
            {
                new { productId = 1, slotType = "cpu" }
            }
        };

        var response = await _client.PutAsJsonAsync($"/api/custombuilds/{alexBuildId}", payload);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CustomBuilds_CustomerViewingAnotherUsersBuild_MustReturnForbidden()
    {
        int alexBuildId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var build = new CustomBuild
            {
                UserId = 3, // Alex
                BuildName = "Alex's Secret Rig",
                TotalPrice = 2000m,
                EstimatedWattage = 650,
                Status = "Approved by Staff",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.CustomBuilds.Add(build);
            db.SaveChanges();
            alexBuildId = build.BuildId;
        }

        var bobToken = CustomWebApplicationFactory.GenerateToken(4, "bob@example.com", "Customer");
        SetBearerToken(bobToken);

        var response = await _client.GetAsync($"/api/custombuilds/{alexBuildId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        // Staff viewing Alex's build should succeed
        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        SetBearerToken(staffToken);
        var staffResponse = await _client.GetAsync($"/api/custombuilds/{alexBuildId}");
        Assert.Equal(HttpStatusCode.OK, staffResponse.StatusCode);
    }

    [Fact]
    public async Task SupportTickets_CustomerViewingAnotherCustomersTicket_MustReturnForbidden()
    {
        int alexTicketId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var ticket = new SupportTicket
            {
                UserId = 3, // Alex
                Subject = "Alex's Broken PSU",
                IssueType = "Hardware Failure",
                Description = "PSU sparks",
                Status = "Open",
                Priority = "High",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.SupportTickets.Add(ticket);
            db.SaveChanges();
            alexTicketId = ticket.TicketId;
        }

        var bobToken = CustomWebApplicationFactory.GenerateToken(4, "bob@example.com", "Customer");
        SetBearerToken(bobToken);

        var response = await _client.GetAsync($"/api/supporttickets/{alexTicketId}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        // Staff viewing Alex's ticket should succeed
        var staffToken = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        SetBearerToken(staffToken);
        var staffResponse = await _client.GetAsync($"/api/supporttickets/{alexTicketId}");
        Assert.Equal(HttpStatusCode.OK, staffResponse.StatusCode);
    }

    // =========================================================================
    // 7. UPLOAD CONTROLLER SECURITY TESTS
    // =========================================================================
    [Fact]
    public async Task UploadController_AnonymousUpload_MustReturnUnauthorized()
    {
        ClearBearerToken();
        using var content = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent(new byte[] { 1, 2, 3 });
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse("image/jpeg");
        content.Add(fileContent, "file", "test.jpg");

        var response = await _client.PostAsync("/api/upload/image", content);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UploadController_DisallowedFileType_MustReturnBadRequest()
    {
        var token = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        SetBearerToken(token);

        using var content = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent(new byte[] { 1, 2, 3 });
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse("application/x-msdownload");
        content.Add(fileContent, "file", "malware.exe");

        var response = await _client.PostAsync("/api/upload/image", content);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UploadController_OversizedFile_MustReturnBadRequest()
    {
        var token = CustomWebApplicationFactory.GenerateToken(2, "sarah@pcforge.com", "Staff");
        SetBearerToken(token);

        // 6 MB payload (exceeds 5 MB limit)
        var oversizedBytes = new byte[6 * 1024 * 1024];
        using var content = new MultipartFormDataContent();
        var fileContent = new ByteArrayContent(oversizedBytes);
        fileContent.Headers.ContentType = MediaTypeHeaderValue.Parse("image/jpeg");
        content.Add(fileContent, "file", "huge_photo.jpg");

        var response = await _client.PostAsync("/api/upload/image", content);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task UploadController_GetStatus_Anonymous_MustReturnOk()
    {
        ClearBearerToken();
        var response = await _client.GetAsync("/api/upload/status");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
