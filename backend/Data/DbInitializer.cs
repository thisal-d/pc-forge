using Microsoft.EntityFrameworkCore;
using PCForge.Api.Models;

namespace PCForge.Api.Data;

public static class DbInitializer
{
    public static async Task SeedAsync(IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<AppDbContext>>();

        try
        {
            // Ensure database is created
            await context.Database.EnsureCreatedAsync();

            // 1. Seed Roles if missing
            if (!await context.Roles.AnyAsync())
            {
                var roles = new List<Role>
                {
                    new() { RoleName = "Customer", Description = "Can browse products, manage cart, and place orders." },
                    new() { RoleName = "Admin", Description = "Full access to inventory, orders, and system settings." },
                    new() { RoleName = "Staff", Description = "Can review builds, manage inventory, and handle support tickets." }
                };

                await context.Roles.AddRangeAsync(roles);
                await context.SaveChangesAsync();
                logger.LogInformation("Database seeded with default roles.");
            }

            // Retrieve role lookup
            var roleMap = await context.Roles.ToDictionaryAsync(r => r.RoleName, r => r.RoleId);

            // 2. Seed Default Users if missing
            var defaultUsers = new List<(string Email, string Password, string Role, string FirstName, string LastName)>
            {
                ("admin@pcforge.com", "Admin123!", "Admin", "Store", "Admin"),
                ("staff@pcforge.com", "Staff123!", "Staff", "Store", "Staff"),
                ("customer@pcforge.com", "Cust123!", "Customer", "Demo", "Customer")
            };

            foreach (var defUser in defaultUsers)
            {
                if (!await context.Users.AnyAsync(u => u.Email == defUser.Email))
                {
                    if (roleMap.TryGetValue(defUser.Role, out int roleId))
                    {
                        var user = new User
                        {
                            Email = defUser.Email,
                            PasswordHash = BCrypt.Net.BCrypt.HashPassword(defUser.Password),
                            RoleId = roleId,
                            FirstName = defUser.FirstName,
                            LastName = defUser.LastName,
                            IsActive = true,
                            CreatedAt = DateTime.UtcNow,
                            UpdatedAt = DateTime.UtcNow
                        };

                        await context.Users.AddAsync(user);
                        logger.LogInformation("Seeded default user: {Email} ({Role})", defUser.Email, defUser.Role);
                    }
                }
            }

            await context.SaveChangesAsync();

            // 3. Seed Default Staff Profile if missing
            var techUser = await context.Users.FirstOrDefaultAsync(u => u.Email == "tech@pcforge.com");
            if (techUser != null && !await context.Staff.AnyAsync(s => s.UserId == techUser.UserId))
            {
                var staffProfile = new Staff
                {
                    UserId = techUser.UserId,
                    Department = "Hardware Diagnostics & Repair",
                    Phone = "+94 77 123 4567",
                    Specialization = "Lead RMA technician for custom build diagnostics and thermal profiling.",
                    Status = "Active",
                    Notes = "Primary technician for RMA validation.",
                    JoinedDate = new DateOnly(2025, 1, 15),
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow
                };

                await context.Staff.AddAsync(staffProfile);
                await context.SaveChangesAsync();
                logger.LogInformation("Seeded default staff profile for: {Email}", techUser.Email);
            }

            // 4. Seed Default Categories & Filters if missing
            if (!await context.Categories.AnyAsync())
            {
                var cpu = new Category
                {
                    Name = "CPU",
                    Description = "Central processing units and desktop processors",
                    CreatedAt = DateTime.UtcNow,
                    Filters = new List<CategoryFilter>
                    {
                        new()
                        {
                            FilterKey = "socket",
                            DisplayName = "Socket Type",
                            FilterType = "multiselect",
                            DisplayOrder = 1,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "AM5", DisplayOrder = 1 },
                                new() { OptionValue = "LGA1700", DisplayOrder = 2 }
                            }
                        }
                    }
                };

                var gpu = new Category
                {
                    Name = "GPU",
                    Description = "Graphics processing units and video cards",
                    CreatedAt = DateTime.UtcNow,
                    Filters = new List<CategoryFilter>
                    {
                        new()
                        {
                            FilterKey = "vram",
                            DisplayName = "VRAM Capacity",
                            FilterType = "multiselect",
                            Unit = "GB",
                            DisplayOrder = 1,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "8GB", DisplayOrder = 1 },
                                new() { OptionValue = "12GB", DisplayOrder = 2 },
                                new() { OptionValue = "16GB", DisplayOrder = 3 },
                                new() { OptionValue = "24GB", DisplayOrder = 4 }
                            }
                        }
                    }
                };

                var motherboard = new Category
                {
                    Name = "Motherboard",
                    Description = "Main circuit boards and system motherboards",
                    CreatedAt = DateTime.UtcNow,
                    Filters = new List<CategoryFilter>
                    {
                        new()
                        {
                            FilterKey = "socket",
                            DisplayName = "Socket Type",
                            FilterType = "multiselect",
                            DisplayOrder = 1,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "AM5", DisplayOrder = 1 },
                                new() { OptionValue = "LGA1700", DisplayOrder = 2 }
                            }
                        },
                        new()
                        {
                            FilterKey = "chipset",
                            DisplayName = "Chipset",
                            FilterType = "multiselect",
                            DisplayOrder = 2,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "X670E", DisplayOrder = 1 },
                                new() { OptionValue = "B650", DisplayOrder = 2 },
                                new() { OptionValue = "Z790", DisplayOrder = 3 },
                                new() { OptionValue = "B760", DisplayOrder = 4 }
                            }
                        },
                        new()
                        {
                            FilterKey = "form_factor",
                            DisplayName = "Form Factor",
                            FilterType = "multiselect",
                            DisplayOrder = 3,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "ATX", DisplayOrder = 1 },
                                new() { OptionValue = "Micro-ATX", DisplayOrder = 2 },
                                new() { OptionValue = "Mini-ITX", DisplayOrder = 3 }
                            }
                        }
                    }
                };

                var ram = new Category
                {
                    Name = "RAM",
                    Description = "DDR4 and DDR5 desktop memory modules",
                    CreatedAt = DateTime.UtcNow,
                    Filters = new List<CategoryFilter>
                    {
                        new()
                        {
                            FilterKey = "ddr_type",
                            DisplayName = "DDR Type",
                            FilterType = "multiselect",
                            DisplayOrder = 1,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "DDR4", DisplayOrder = 1 },
                                new() { OptionValue = "DDR5", DisplayOrder = 2 }
                            }
                        },
                        new()
                        {
                            FilterKey = "speed",
                            DisplayName = "Memory Speed / Bus",
                            FilterType = "multiselect",
                            Unit = "MHz",
                            DisplayOrder = 2,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "3200 MHz", DisplayOrder = 1 },
                                new() { OptionValue = "5600 MHz", DisplayOrder = 2 },
                                new() { OptionValue = "6000 MHz", DisplayOrder = 3 }
                            }
                        },
                        new()
                        {
                            FilterKey = "capacity",
                            DisplayName = "Capacity",
                            FilterType = "multiselect",
                            Unit = "GB",
                            DisplayOrder = 3,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "16GB", DisplayOrder = 1 },
                                new() { OptionValue = "32GB", DisplayOrder = 2 },
                                new() { OptionValue = "64GB", DisplayOrder = 3 }
                            }
                        }
                    }
                };

                var psu = new Category
                {
                    Name = "PSU",
                    Description = "Power supply units and modular power blocks",
                    CreatedAt = DateTime.UtcNow,
                    Filters = new List<CategoryFilter>
                    {
                        new()
                        {
                            FilterKey = "efficiency",
                            DisplayName = "Efficiency Rating",
                            FilterType = "multiselect",
                            DisplayOrder = 1,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "80+ Bronze", DisplayOrder = 1 },
                                new() { OptionValue = "80+ Gold", DisplayOrder = 2 },
                                new() { OptionValue = "80+ Platinum", DisplayOrder = 3 }
                            }
                        },
                        new()
                        {
                            FilterKey = "wattage",
                            DisplayName = "Power Wattage",
                            FilterType = "singleselect",
                            Unit = "W",
                            DisplayOrder = 2,
                            IsFilterable = true,
                            CreatedAt = DateTime.UtcNow,
                            Options = new List<FilterOption>
                            {
                                new() { OptionValue = "650W", DisplayOrder = 1 },
                                new() { OptionValue = "750W", DisplayOrder = 2 },
                                new() { OptionValue = "850W", DisplayOrder = 3 },
                                new() { OptionValue = "1000W", DisplayOrder = 4 }
                            }
                        }
                    }
                };

                await context.Categories.AddRangeAsync(cpu, gpu, motherboard, ram, psu);
                await context.SaveChangesAsync();
                logger.LogInformation("Database seeded with default categories and filters.");
            }
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "An error occurred while seeding the database.");
        }
    }
}
