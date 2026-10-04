using Microsoft.EntityFrameworkCore;
using PCForge.Api.Models;

namespace PCForge.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<CategoryFilter> CategoryFilters => Set<CategoryFilter>();
    public DbSet<FilterOption> FilterOptions => Set<FilterOption>();
    public DbSet<Filter> Filters => Set<Filter>();
    public DbSet<MasterFilterOption> MasterFilterOptions => Set<MasterFilterOption>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderItem> OrderItems => Set<OrderItem>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<ServiceRequest> ServiceRequests => Set<ServiceRequest>();
    public DbSet<Staff> Staff => Set<Staff>();
    public DbSet<CustomBuild> CustomBuilds => Set<CustomBuild>();
    public DbSet<CustomBuildItem> CustomBuildItems => Set<CustomBuildItem>();
    public DbSet<RequirementSession> RequirementSessions => Set<RequirementSession>();
    public DbSet<Coupon> Coupons => Set<Coupon>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // 1. Map Roles
        modelBuilder.Entity<Role>(entity =>
        {
            entity.ToTable("roles");
            entity.HasKey(r => r.RoleId);
            entity.Property(r => r.RoleId).HasColumnName("roleid");
            entity.Property(r => r.RoleName).HasColumnName("rolename").HasMaxLength(50).IsRequired();
            entity.HasIndex(r => r.RoleName).IsUnique();
            entity.Property(r => r.Description).HasColumnName("description");
            entity.Property(r => r.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
        });

        // 2. Map Users
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("users");
            entity.HasKey(u => u.UserId);
            entity.Property(u => u.UserId).HasColumnName("userid");
            entity.Property(u => u.Email).HasColumnName("email").HasMaxLength(255).IsRequired();
            entity.HasIndex(u => u.Email).IsUnique();
            entity.Property(u => u.PasswordHash).HasColumnName("passwordhash").HasMaxLength(255).IsRequired();
            entity.Property(u => u.RoleId).HasColumnName("roleid");
            entity.Property(u => u.FirstName).HasColumnName("firstname").HasMaxLength(100);
            entity.Property(u => u.LastName).HasColumnName("lastname").HasMaxLength(100);
            entity.Property(u => u.IsActive).HasColumnName("isactive").HasDefaultValue(true);
            entity.Property(u => u.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(u => u.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(u => u.Role)
                  .WithMany(r => r.Users)
                  .HasForeignKey(u => u.RoleId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // 3. Map Categories
        modelBuilder.Entity<Category>(entity =>
        {
            entity.ToTable("categories");
            entity.HasKey(c => c.CategoryId);
            entity.Property(c => c.CategoryId).HasColumnName("categoryid");
            entity.Property(c => c.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
            entity.HasIndex(c => c.Name).IsUnique();
            entity.Property(c => c.Description).HasColumnName("description");
            entity.Property(c => c.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
        });

        // 4. Map Products
        modelBuilder.Entity<Product>(entity =>
        {
            entity.ToTable("products");
            entity.HasKey(p => p.ProductId);
            entity.Property(p => p.ProductId).HasColumnName("productid");
            entity.Property(p => p.CategoryId).HasColumnName("categoryid");
            entity.Property(p => p.Name).HasColumnName("name").HasMaxLength(255).IsRequired();
            entity.Property(p => p.Brand).HasColumnName("brand").HasMaxLength(100).IsRequired();
            entity.Property(p => p.Model).HasColumnName("model").HasMaxLength(100);
            entity.Property(p => p.Price).HasColumnName("price").HasColumnType("decimal(12,2)").IsRequired();
            entity.Property(p => p.StockQuantity).HasColumnName("stockquantity").HasDefaultValue(0);
            entity.Property(p => p.ImageUrl).HasColumnName("imageurl").HasMaxLength(500);
            entity.Property(p => p.Description).HasColumnName("description");
            entity.Property(p => p.WarrantyMonths).HasColumnName("warrantymonths").HasDefaultValue(36);
            entity.Property(p => p.Specifications).HasColumnName("specifications").HasColumnType("jsonb");
            entity.Property(p => p.Socket).HasColumnName("socket").HasMaxLength(50);
            entity.Property(p => p.MemoryType).HasColumnName("memorytype").HasMaxLength(20);
            entity.Property(p => p.PowerWattage).HasColumnName("powerwattage");
            entity.Property(p => p.FormFactor).HasColumnName("formfactor").HasMaxLength(50);
            entity.Property(p => p.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(p => p.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(p => p.Category)
                  .WithMany(c => c.Products)
                  .HasForeignKey(p => p.CategoryId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // 5. Map CategoryFilters
        modelBuilder.Entity<CategoryFilter>(entity =>
        {
            entity.ToTable("categoryfilters");
            entity.HasKey(cf => cf.FilterId);
            entity.Property(cf => cf.FilterId).HasColumnName("filterid");
            entity.Property(cf => cf.CategoryId).HasColumnName("categoryid");
            entity.Property(cf => cf.MasterFilterId).HasColumnName("masterfilterid");
            entity.Property(cf => cf.FilterKey).HasColumnName("filterkey").HasMaxLength(50).IsRequired();
            entity.Property(cf => cf.DisplayName).HasColumnName("displayname").HasMaxLength(100).IsRequired();
            entity.Property(cf => cf.FilterType).HasColumnName("filtertype").HasMaxLength(30).HasDefaultValue("multiselect");
            entity.Property(cf => cf.Unit).HasColumnName("unit").HasMaxLength(20);
            entity.Property(cf => cf.DisplayOrder).HasColumnName("displayorder").HasDefaultValue(0);
            entity.Property(cf => cf.IsFilterable).HasColumnName("isfilterable").HasDefaultValue(true);
            entity.Property(cf => cf.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");

            entity.HasOne(cf => cf.Category)
                  .WithMany(c => c.Filters)
                  .HasForeignKey(cf => cf.CategoryId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(cf => cf.MasterFilter)
                  .WithMany(f => f.CategoryFilters)
                  .HasForeignKey(cf => cf.MasterFilterId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        // 6. Map FilterOptions
        modelBuilder.Entity<FilterOption>(entity =>
        {
            entity.ToTable("filteroptions");
            entity.HasKey(fo => fo.OptionId);
            entity.Property(fo => fo.OptionId).HasColumnName("optionid");
            entity.Property(fo => fo.FilterId).HasColumnName("filterid");
            entity.Property(fo => fo.OptionValue).HasColumnName("optionvalue").HasMaxLength(100).IsRequired();
            entity.Property(fo => fo.DisplayOrder).HasColumnName("displayorder").HasDefaultValue(0);

            entity.HasOne(fo => fo.Filter)
                  .WithMany(f => f.Options)
                  .HasForeignKey(fo => fo.FilterId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // 6b. Map Master Filters
        modelBuilder.Entity<Filter>(entity =>
        {
            entity.ToTable("filters");
            entity.HasKey(f => f.FilterId);
            entity.Property(f => f.FilterId).HasColumnName("filterid");
            entity.Property(f => f.FilterKey).HasColumnName("filterkey").HasMaxLength(50).IsRequired();
            entity.HasIndex(f => f.FilterKey).IsUnique();
            entity.Property(f => f.DisplayName).HasColumnName("displayname").HasMaxLength(100).IsRequired();
            entity.Property(f => f.FilterType).HasColumnName("filtertype").HasMaxLength(30).HasDefaultValue("multiselect");
            entity.Property(f => f.Unit).HasColumnName("unit").HasMaxLength(20);
            entity.Property(f => f.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(f => f.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");
        });

        // 6c. Map MasterFilterOptions
        modelBuilder.Entity<MasterFilterOption>(entity =>
        {
            entity.ToTable("master_filter_options");
            entity.HasKey(mfo => mfo.OptionId);
            entity.Property(mfo => mfo.OptionId).HasColumnName("optionid");
            entity.Property(mfo => mfo.FilterId).HasColumnName("filterid");
            entity.Property(mfo => mfo.OptionValue).HasColumnName("optionvalue").HasMaxLength(100).IsRequired();
            entity.Property(mfo => mfo.DisplayOrder).HasColumnName("displayorder").HasDefaultValue(0);

            entity.HasOne(mfo => mfo.Filter)
                  .WithMany(f => f.Options)
                  .HasForeignKey(mfo => mfo.FilterId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // 7. Map Orders
        modelBuilder.Entity<Order>(entity =>
        {
            entity.ToTable("orders");
            entity.HasKey(o => o.OrderId);
            entity.Property(o => o.OrderId).HasColumnName("orderid");
            entity.Property(o => o.UserId).HasColumnName("userid");
            entity.Property(o => o.TotalAmount).HasColumnName("totalamount").HasColumnType("decimal(12,2)").IsRequired();
            entity.Property(o => o.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("Order placed");
            entity.Property(o => o.ShippingAddress).HasColumnName("shippingaddress").IsRequired();
            entity.Property(o => o.PaymentMethod).HasColumnName("paymentmethod").HasMaxLength(50);
            entity.Property(o => o.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(o => o.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(o => o.User)
                  .WithMany()
                  .HasForeignKey(o => o.UserId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // 8. Map OrderItems
        modelBuilder.Entity<OrderItem>(entity =>
        {
            entity.ToTable("orderitems");
            entity.HasKey(oi => oi.OrderItemId);
            entity.Property(oi => oi.OrderItemId).HasColumnName("orderitemid");
            entity.Property(oi => oi.OrderId).HasColumnName("orderid");
            entity.Property(oi => oi.ProductId).HasColumnName("productid");
            entity.Property(oi => oi.Quantity).HasColumnName("quantity").IsRequired();
            entity.Property(oi => oi.UnitPrice).HasColumnName("unitprice").HasColumnType("decimal(12,2)").IsRequired();

            entity.HasOne(oi => oi.Order)
                  .WithMany(o => o.Items)
                  .HasForeignKey(oi => oi.OrderId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(oi => oi.Product)
                  .WithMany()
                  .HasForeignKey(oi => oi.ProductId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // 9. Map SupportTickets
        modelBuilder.Entity<SupportTicket>(entity =>
        {
            entity.ToTable("supporttickets");
            entity.HasKey(st => st.TicketId);
            entity.Property(st => st.TicketId).HasColumnName("ticketid");
            entity.Property(st => st.UserId).HasColumnName("userid");
            entity.Property(st => st.OrderId).HasColumnName("orderid");
            entity.Property(st => st.ProductId).HasColumnName("productid");
            entity.Property(st => st.IssueType).HasColumnName("issuetype").HasMaxLength(50).IsRequired();
            entity.Property(st => st.Subject).HasColumnName("subject").HasMaxLength(200).IsRequired();
            entity.Property(st => st.Description).HasColumnName("description").IsRequired();
            entity.Property(st => st.AttachmentUrl).HasColumnName("attachmenturl").HasMaxLength(500);
            entity.Property(st => st.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("Open");
            entity.Property(st => st.Priority).HasColumnName("priority").HasMaxLength(20).HasDefaultValue("Normal");
            entity.Property(st => st.ResolutionNotes).HasColumnName("resolutionnotes");
            entity.Property(st => st.AssignedStaffId).HasColumnName("assignedstaffid");
            entity.Property(st => st.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(st => st.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(st => st.User)
                  .WithMany()
                  .HasForeignKey(st => st.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(st => st.Order)
                  .WithMany()
                  .HasForeignKey(st => st.OrderId)
                  .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(st => st.Product)
                  .WithMany()
                  .HasForeignKey(st => st.ProductId)
                  .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(st => st.AssignedStaff)
                  .WithMany()
                  .HasForeignKey(st => st.AssignedStaffId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        // 9b. Map ServiceRequests
        modelBuilder.Entity<ServiceRequest>(entity =>
        {
            entity.ToTable("servicerequests");
            entity.HasKey(sr => sr.ServiceRequestId);
            entity.Property(sr => sr.ServiceRequestId).HasColumnName("servicerequestid");
            entity.Property(sr => sr.ServiceRequestNumber).HasColumnName("servicerequestnumber").HasMaxLength(30).IsRequired();
            entity.HasIndex(sr => sr.ServiceRequestNumber).IsUnique();
            entity.Property(sr => sr.UserId).HasColumnName("userid");
            entity.Property(sr => sr.OrderId).HasColumnName("orderid");
            entity.Property(sr => sr.ProductId).HasColumnName("productid");
            entity.Property(sr => sr.ProblemDescription).HasColumnName("problemdescription").IsRequired();
            entity.Property(sr => sr.ProblemCategory).HasColumnName("problemcategory").HasMaxLength(100).HasDefaultValue("General");
            entity.Property(sr => sr.TroubleshootingSummary).HasColumnName("troubleshootingsummary");
            entity.Property(sr => sr.AttemptCount).HasColumnName("attemptcount").HasDefaultValue(0);
            entity.Property(sr => sr.WarrantyStatus).HasColumnName("warrantystatus").HasMaxLength(50).HasDefaultValue("Active");
            entity.Property(sr => sr.WarrantyExpiryDate).HasColumnName("warrantyexpirydate");
            entity.Property(sr => sr.PreferredDate).HasColumnName("preferreddate");
            entity.Property(sr => sr.PreferredTime).HasColumnName("preferredtime").HasMaxLength(50);
            entity.Property(sr => sr.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("PENDING");
            entity.Property(sr => sr.Priority).HasColumnName("priority").HasMaxLength(20).HasDefaultValue("Normal");
            entity.Property(sr => sr.AssignedStaffId).HasColumnName("assignedstaffid");
            entity.Property(sr => sr.TechnicianNotes).HasColumnName("techniciannotes");
            entity.Property(sr => sr.Resolution).HasColumnName("resolution");
            entity.Property(sr => sr.AttachmentUrl).HasColumnName("attachmenturl").HasMaxLength(500);
            entity.Property(sr => sr.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(sr => sr.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(sr => sr.User)
                  .WithMany()
                  .HasForeignKey(sr => sr.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(sr => sr.Order)
                  .WithMany()
                  .HasForeignKey(sr => sr.OrderId)
                  .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(sr => sr.Product)
                  .WithMany()
                  .HasForeignKey(sr => sr.ProductId)
                  .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(sr => sr.AssignedStaff)
                  .WithMany()
                  .HasForeignKey(sr => sr.AssignedStaffId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        // 10. Map Staff (Option 2: Dedicated Staff Profile Table)
        modelBuilder.Entity<Staff>(entity =>
        {
            entity.ToTable("staff");
            entity.HasKey(s => s.StaffId);
            entity.Property(s => s.StaffId).HasColumnName("staffid");
            entity.Property(s => s.UserId).HasColumnName("userid");
            entity.HasIndex(s => s.UserId).IsUnique();
            entity.Property(s => s.Department).HasColumnName("department").HasMaxLength(100).IsRequired();
            entity.Property(s => s.Phone).HasColumnName("phone").HasMaxLength(30);
            entity.Property(s => s.Specialization).HasColumnName("specialization");
            entity.Property(s => s.Status).HasColumnName("status").HasMaxLength(20).HasDefaultValue("Active");
            entity.Property(s => s.Notes).HasColumnName("notes");
            entity.Property(s => s.JoinedDate).HasColumnName("joineddate");
            entity.Property(s => s.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(s => s.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(s => s.User)
                  .WithOne(u => u.StaffProfile)
                  .HasForeignKey<Staff>(s => s.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        // 11. Map Custom Builds & Reviews
        modelBuilder.Entity<CustomBuild>(entity =>
        {
            entity.ToTable("custombuilds");
            entity.HasKey(cb => cb.BuildId);
            entity.Property(cb => cb.BuildId).HasColumnName("buildid");
            entity.Property(cb => cb.UserId).HasColumnName("userid");
            entity.Property(cb => cb.BuildName).HasColumnName("buildname").HasMaxLength(200).IsRequired();
            entity.Property(cb => cb.TotalPrice).HasColumnName("totalprice").HasColumnType("decimal(12,2)").IsRequired();
            entity.Property(cb => cb.EstimatedWattage).HasColumnName("estimatedwattage").HasDefaultValue(0);
            entity.Property(cb => cb.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("Pending Staff Review");
            entity.Property(cb => cb.CustomerNotes).HasColumnName("customernotes");
            entity.Property(cb => cb.StaffNotes).HasColumnName("staffnotes");
            entity.Property(cb => cb.AssignedStaffId).HasColumnName("assignedstaffid");
            entity.Property(cb => cb.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(cb => cb.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(cb => cb.User)
                  .WithMany()
                  .HasForeignKey(cb => cb.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(cb => cb.AssignedStaff)
                  .WithMany()
                  .HasForeignKey(cb => cb.AssignedStaffId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<CustomBuildItem>(entity =>
        {
            entity.ToTable("custombuilditems");
            entity.HasKey(cbi => cbi.BuildItemId);
            entity.Property(cbi => cbi.BuildItemId).HasColumnName("builditemid");
            entity.Property(cbi => cbi.BuildId).HasColumnName("buildid");
            entity.Property(cbi => cbi.ProductId).HasColumnName("productid");
            entity.Property(cbi => cbi.SlotType).HasColumnName("slottype").HasMaxLength(50).IsRequired();
            entity.Property(cbi => cbi.UnitPrice).HasColumnName("unitprice").HasColumnType("decimal(12,2)").IsRequired();

            entity.HasOne(cbi => cbi.Build)
                  .WithMany(cb => cb.Items)
                  .HasForeignKey(cbi => cbi.BuildId)
                  .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(cbi => cbi.Product)
                  .WithMany()
                  .HasForeignKey(cbi => cbi.ProductId)
                  .OnDelete(DeleteBehavior.Restrict);
        });

        // 12. Map RequirementSessions
        modelBuilder.Entity<RequirementSession>(entity =>
        {
            entity.ToTable("requirement_sessions");
            entity.HasKey(rs => rs.SessionId);
            entity.Property(rs => rs.SessionId).HasColumnName("sessionid").HasMaxLength(100);
            entity.Property(rs => rs.UserId).HasColumnName("userid");
            entity.Property(rs => rs.Purpose).HasColumnName("purpose").HasMaxLength(100);
            entity.Property(rs => rs.BudgetAmount).HasColumnName("budgetamount").HasColumnType("decimal(12,2)");
            entity.Property(rs => rs.BudgetRaw).HasColumnName("budgetraw").HasMaxLength(100);
            entity.Property(rs => rs.Currency).HasColumnName("currency").HasMaxLength(10).HasDefaultValue("LKR");
            entity.Property(rs => rs.TargetResolution).HasColumnName("targetresolution").HasMaxLength(50);
            entity.Property(rs => rs.MonitorNeeded).HasColumnName("monitorneeded");
            entity.Property(rs => rs.PreferencesJson).HasColumnName("preferencesjson").HasColumnType("text");
            entity.Property(rs => rs.IsComplete).HasColumnName("iscomplete").HasDefaultValue(false);
            entity.Property(rs => rs.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("Gathering");
            entity.Property(rs => rs.RawAnswersJson).HasColumnName("rawanswersjson").HasColumnType("text");
            entity.Property(rs => rs.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
            entity.Property(rs => rs.UpdatedAt).HasColumnName("updatedat").HasDefaultValueSql("NOW()");

            entity.HasOne(rs => rs.User)
                  .WithMany()
                  .HasForeignKey(rs => rs.UserId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        // 14. Map Coupons
        modelBuilder.Entity<Coupon>(entity =>
        {
            entity.ToTable("coupons");
            entity.HasKey(c => c.CouponId);
            entity.Property(c => c.CouponId).HasColumnName("couponid");
            entity.Property(c => c.Code).HasColumnName("code").HasMaxLength(50).IsRequired();
            entity.HasIndex(c => c.Code).IsUnique();
            entity.Property(c => c.Description).HasColumnName("description").HasMaxLength(255).IsRequired();
            entity.Property(c => c.DiscountType).HasColumnName("discounttype").HasMaxLength(20).IsRequired();
            entity.Property(c => c.DiscountValue).HasColumnName("discountvalue").HasColumnType("decimal(10,2)");
            entity.Property(c => c.MinSubtotal).HasColumnName("minsubtotal").HasColumnType("decimal(10,2)");
            entity.Property(c => c.MaxDiscount).HasColumnName("maxdiscount").HasColumnType("decimal(10,2)");
            entity.Property(c => c.IsActive).HasColumnName("isactive").HasDefaultValue(true);
            entity.Property(c => c.CreatedAt).HasColumnName("createdat").HasDefaultValueSql("NOW()");
        });
    }
}
