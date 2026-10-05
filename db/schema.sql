-- ============================================================================
-- PCForge Relational Database Schema
-- Architecture: PostgreSQL (with Dynamic Admin-Manageable Faceted Filters)
-- ============================================================================

-- 1. ROLES TABLE
-- Defines the permission levels (Customer, Admin, Staff)
CREATE TABLE Roles (
    RoleId SERIAL PRIMARY KEY,
    RoleName VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'Customer', 'Admin', 'Staff'
    Description TEXT,
    CreatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- Seed data for Roles
INSERT INTO Roles (RoleName, Description) VALUES 
('Customer', 'Can browse products, manage cart, and place orders.'),
('Admin', 'Full access to inventory, orders, and system settings.'),
('Staff', 'Can review builds, manage inventory, and handle support tickets.');


-- 2. USERS TABLE
-- Handles authentication (Identity layer)
CREATE TABLE Users (
    UserId SERIAL PRIMARY KEY,
    Email VARCHAR(255) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    RoleId INT REFERENCES Roles(RoleId),
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
    IsActive BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_email ON Users(Email);


-- 2b. STAFF TABLE (Technician & Employee Profiles - Option 2)
-- Stores operational profile and technician details exclusively for internal staff/technicians
CREATE TABLE Staff (
    StaffId SERIAL PRIMARY KEY,
    UserId INT UNIQUE NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
    Department VARCHAR(100) NOT NULL,            -- e.g., 'Hardware Diagnostics & Repair', 'Custom PC Assembly'
    Phone VARCHAR(30),
    Specialization TEXT,                          -- e.g., 'Liquid cooling loops, GPU thermal profiling, RMA'
    Status VARCHAR(20) NOT NULL DEFAULT 'Active', -- 'Active', 'Inactive', 'On Leave'
    Notes TEXT,
    JoinedDate DATE DEFAULT CURRENT_DATE,
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_staff_user ON Staff(UserId);
CREATE INDEX idx_staff_status ON Staff(Status);


-- 3. CATEGORIES TABLE
-- Top-level catalog classification (e.g., 'CPU', 'Motherboard', 'RAM', 'GPU', 'PSU')
CREATE TABLE Categories (
    CategoryId SERIAL PRIMARY KEY,
    Name VARCHAR(100) UNIQUE NOT NULL,
    Description TEXT,
    CreatedAt TIMESTAMPTZ DEFAULT NOW()
);


-- 4. PRODUCTS TABLE (Core Inventory Management)
CREATE TABLE Products (
    ProductId SERIAL PRIMARY KEY,
    CategoryId INT REFERENCES Categories(CategoryId),
    
    -- Standard E-Commerce Fields
    Name VARCHAR(255) NOT NULL,
    Brand VARCHAR(100) NOT NULL, -- e.g., 'ASUS', 'NVIDIA', 'AMD', 'Corsair'
    Model VARCHAR(100),          -- e.g., 'RTX 4070 Ti', 'Ryzen 9 7950X'
    Price DECIMAL(12, 2) NOT NULL,
    StockQuantity INT NOT NULL DEFAULT 0,
    ImageUrl VARCHAR(500),
    Description TEXT,
    WarrantyMonths INT NOT NULL DEFAULT 36,
    
    -- Extensible Hardware Specifications (JSONB with GIN index)
    -- Allows arbitrary attributes without altering the table structure
    Specifications JSONB DEFAULT '{}'::jsonb,

    -- Legacy Compatibility Columns (Kept for quick scalar joins)
    Socket VARCHAR(50),       -- e.g., 'AM5', 'LGA1700'
    MemoryType VARCHAR(20),   -- e.g., 'DDR5', 'DDR4'
    PowerWattage INT,         -- e.g., 65, 300, 850
    FormFactor VARCHAR(50),   -- e.g., 'ATX', 'mATX', 'ITX'
    
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_products_category ON Products(CategoryId);
CREATE INDEX idx_products_brand ON Products(Brand);
CREATE INDEX idx_products_stock ON Products(StockQuantity);
CREATE INDEX idx_products_specifications ON Products USING GIN (Specifications);


-- ============================================================================
-- DYNAMIC CATEGORY-SPECIFIC FACETED FILTER ARCHITECTURE (Nanotek.lk Style)
-- Allows Admins to add/edit filters and selectable options at runtime.
-- ============================================================================

-- 4b. MASTER FILTERS TABLE
-- Master repository of technical specifications and filters managed by Admins
CREATE TABLE Filters (
    FilterId SERIAL PRIMARY KEY,
    FilterKey VARCHAR(50) UNIQUE NOT NULL,
    DisplayName VARCHAR(100) NOT NULL,
    FilterType VARCHAR(30) DEFAULT 'multiselect',
    Unit VARCHAR(20),
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

-- 4c. MASTER FILTER OPTIONS TABLE
CREATE TABLE MasterFilterOptions (
    OptionId SERIAL PRIMARY KEY,
    FilterId INT REFERENCES Filters(FilterId) ON DELETE CASCADE,
    OptionValue VARCHAR(100) NOT NULL,
    DisplayOrder INT DEFAULT 0,

    CONSTRAINT UQ_MasterFilter_OptionValue UNIQUE(FilterId, OptionValue)
);

-- 5. CATEGORY FILTERS TABLE
-- Defines which filter types belong to which category (e.g. Motherboard -> Chipset, Socket)
CREATE TABLE CategoryFilters (
    FilterId SERIAL PRIMARY KEY,
    CategoryId INT REFERENCES Categories(CategoryId) ON DELETE CASCADE,
    MasterFilterId INT REFERENCES Filters(FilterId) ON DELETE SET NULL,
    FilterKey VARCHAR(50) NOT NULL,       -- e.g., 'chipset', 'socket', 'ddr_type', 'speed', 'vram'
    DisplayName VARCHAR(100) NOT NULL,     -- e.g., 'Chipset', 'Socket Type', 'DDR Type', 'Memory Speed / Bus'
    FilterType VARCHAR(30) DEFAULT 'multiselect', -- 'multiselect', 'singleselect', 'range', 'boolean'
    Unit VARCHAR(20),                      -- e.g., 'MHz', 'GB', 'W' (nullable)
    DisplayOrder INT DEFAULT 0,
    IsFilterable BOOLEAN DEFAULT TRUE,
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT UQ_Category_FilterKey UNIQUE(CategoryId, FilterKey)
);

CREATE INDEX idx_categoryfilters_category ON CategoryFilters(CategoryId);


-- 6. FILTER OPTIONS TABLE
-- Selectable values/chips for each category filter (e.g. Chipset -> B650, X670E, Z790)
CREATE TABLE FilterOptions (
    OptionId SERIAL PRIMARY KEY,
    FilterId INT REFERENCES CategoryFilters(FilterId) ON DELETE CASCADE,
    OptionValue VARCHAR(100) NOT NULL,     -- e.g., 'B650', 'X670E', 'DDR5', '6000 MHz', '12GB'
    DisplayOrder INT DEFAULT 0,

    CONSTRAINT UQ_Filter_OptionValue UNIQUE(FilterId, OptionValue)
);

CREATE INDEX idx_filteroptions_filter ON FilterOptions(FilterId);


-- 7. PRODUCT FILTER VALUES TABLE
-- Connects a product to its assigned category filter options
CREATE TABLE ProductFilterValues (
    ProductFilterValueId SERIAL PRIMARY KEY,
    ProductId INT REFERENCES Products(ProductId) ON DELETE CASCADE,
    FilterId INT REFERENCES CategoryFilters(FilterId) ON DELETE CASCADE,
    OptionId INT REFERENCES FilterOptions(OptionId) ON DELETE SET NULL,
    RawValue VARCHAR(255),                 -- Human-readable value snapshot (e.g., 'B650', '6000 MHz')

    CONSTRAINT UQ_Product_Filter_Option UNIQUE(ProductId, FilterId, OptionId)
);

CREATE INDEX idx_productfiltervalues_product ON ProductFilterValues(ProductId);
CREATE INDEX idx_productfiltervalues_filter_option ON ProductFilterValues(FilterId, OptionId);


-- ============================================================================
-- TRANSACTIONS & E-COMMERCE
-- ============================================================================

-- 8. CARTS TABLE
CREATE TABLE Carts (
    CartId SERIAL PRIMARY KEY,
    UserId INT REFERENCES Users(UserId),
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT UQ_User_Cart UNIQUE(UserId)
);


-- 9. CART ITEMS TABLE
CREATE TABLE CartItems (
    CartItemId SERIAL PRIMARY KEY,
    CartId INT REFERENCES Carts(CartId) ON DELETE CASCADE,
    ProductId INT REFERENCES Products(ProductId),
    Quantity INT NOT NULL CHECK (Quantity > 0),
    
    UNIQUE(CartId, ProductId)
);


-- 10. ORDERS TABLE
CREATE TABLE Orders (
    OrderId SERIAL PRIMARY KEY,
    UserId INT REFERENCES Users(UserId),
    TotalAmount DECIMAL(12, 2) NOT NULL,
    Status VARCHAR(50) NOT NULL DEFAULT 'Pending', -- Pending, Paid, Processing, Shipped, Cancelled
    ShippingAddress TEXT NOT NULL,
    PaymentMethod VARCHAR(50),                     -- e.g., 'Credit Card', 'Cash on Delivery'
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON Orders(UserId);
CREATE INDEX idx_orders_status ON Orders(Status);


-- 11. ORDER ITEMS TABLE
CREATE TABLE OrderItems (
    OrderItemId SERIAL PRIMARY KEY,
    OrderId INT REFERENCES Orders(OrderId) ON DELETE CASCADE,
    ProductId INT REFERENCES Products(ProductId),
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(12, 2) NOT NULL
);


-- ============================================================================
-- 12. SERVICE REQUESTS TABLE (Member 05: After-Sales Service & Warranty)
-- ============================================================================
CREATE TABLE IF NOT EXISTS ServiceRequests (
    ServiceRequestId SERIAL PRIMARY KEY,
    ServiceRequestNumber VARCHAR(30) UNIQUE NOT NULL,
    UserId INT NOT NULL REFERENCES Users(UserId) ON DELETE CASCADE,
    OrderId INT REFERENCES Orders(OrderId) ON DELETE SET NULL,
    ProductId INT REFERENCES Products(ProductId) ON DELETE SET NULL,
    ProblemDescription TEXT NOT NULL,
    ProblemCategory VARCHAR(100) NOT NULL DEFAULT 'General',
    TroubleshootingSummary TEXT,
    AttemptCount INT NOT NULL DEFAULT 0,
    WarrantyStatus VARCHAR(50) NOT NULL DEFAULT 'Active',
    WarrantyExpiryDate TIMESTAMPTZ,
    PreferredDate DATE,
    PreferredTime VARCHAR(50),
    Status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
    Priority VARCHAR(20) NOT NULL DEFAULT 'Normal',
    AssignedStaffId INT REFERENCES Staff(StaffId) ON DELETE SET NULL,
    TechnicianNotes TEXT,
    Resolution TEXT,
    AttachmentUrl VARCHAR(500),
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_servicerequests_user ON ServiceRequests(UserId);
CREATE INDEX IF NOT EXISTS idx_servicerequests_order ON ServiceRequests(OrderId);
CREATE INDEX IF NOT EXISTS idx_servicerequests_status ON ServiceRequests(Status);
CREATE INDEX IF NOT EXISTS idx_servicerequests_staff ON ServiceRequests(AssignedStaffId);
CREATE INDEX IF NOT EXISTS idx_servicerequests_number ON ServiceRequests(ServiceRequestNumber);

-- Legacy SupportTickets (Preserved for compatibility)
CREATE TABLE IF NOT EXISTS SupportTickets (
    TicketId SERIAL PRIMARY KEY,
    UserId INT REFERENCES Users(UserId) ON DELETE CASCADE,
    OrderId INT REFERENCES Orders(OrderId) ON DELETE SET NULL,
    ProductId INT REFERENCES Products(ProductId) ON DELETE SET NULL,
    IssueType VARCHAR(50) NOT NULL,
    Subject VARCHAR(200) NOT NULL,
    Description TEXT NOT NULL,
    AttachmentUrl VARCHAR(500),
    Status VARCHAR(50) NOT NULL DEFAULT 'Open',
    Priority VARCHAR(20) NOT NULL DEFAULT 'Normal',
    ResolutionNotes TEXT,
    AssignedStaffId INT REFERENCES Staff(StaffId) ON DELETE SET NULL,
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_supporttickets_user ON SupportTickets(UserId);
CREATE INDEX IF NOT EXISTS idx_supporttickets_order ON SupportTickets(OrderId);
CREATE INDEX IF NOT EXISTS idx_supporttickets_status ON SupportTickets(Status);
CREATE INDEX IF NOT EXISTS idx_supporttickets_assigned_staff ON SupportTickets(AssignedStaffId);



-- ============================================================================
-- CONVENIENCE VIEWS FOR BACKEND & MOBILE API
-- ============================================================================

-- View: v_category_filters
-- Returns all active filters and their selectable options bundled as JSON
CREATE OR REPLACE VIEW v_category_filters AS
SELECT 
    cf.CategoryId,
    c.Name AS CategoryName,
    cf.FilterId,
    cf.FilterKey,
    cf.DisplayName,
    cf.FilterType,
    cf.Unit,
    cf.DisplayOrder,
    COALESCE(
        json_agg(
            json_build_object(
                'optionId', fo.OptionId,
                'value', fo.OptionValue,
                'displayOrder', fo.DisplayOrder
            ) ORDER BY fo.DisplayOrder, fo.OptionValue
        ) FILTER (WHERE fo.OptionId IS NOT NULL),
        '[]'::json
    ) AS Options
FROM CategoryFilters cf
JOIN Categories c ON cf.CategoryId = c.CategoryId
LEFT JOIN FilterOptions fo ON cf.FilterId = fo.FilterId
WHERE cf.IsFilterable = TRUE
GROUP BY cf.CategoryId, c.Name, cf.FilterId, cf.FilterKey, cf.DisplayName, cf.FilterType, cf.Unit, cf.DisplayOrder
ORDER BY cf.CategoryId, cf.DisplayOrder;


-- View: v_product_details
-- Returns products along with category name and structured active filter specifications
CREATE OR REPLACE VIEW v_product_details AS
SELECT 
    p.ProductId,
    p.CategoryId,
    c.Name AS CategoryName,
    p.Name,
    p.Brand,
    p.Model,
    p.Price,
    p.StockQuantity,
    p.ImageUrl,
    p.Description,
    p.Specifications,
    p.Socket,
    p.MemoryType,
    p.PowerWattage,
    p.FormFactor,
    COALESCE(
        json_agg(
            json_build_object(
                'filterKey', cf.FilterKey,
                'displayName', cf.DisplayName,
                'value', COALESCE(fo.OptionValue, pfv.RawValue)
            ) ORDER BY cf.DisplayOrder
        ) FILTER (WHERE cf.FilterId IS NOT NULL),
        '[]'::json
    ) AS ActiveFilterAttributes
FROM Products p
JOIN Categories c ON p.CategoryId = c.CategoryId
LEFT JOIN ProductFilterValues pfv ON p.ProductId = pfv.ProductId
LEFT JOIN CategoryFilters cf ON pfv.FilterId = cf.FilterId
LEFT JOIN FilterOptions fo ON pfv.OptionId = fo.OptionId
GROUP BY p.ProductId, p.CategoryId, c.Name, p.Name, p.Brand, p.Model, p.Price, p.StockQuantity, p.ImageUrl, p.Description, p.Specifications, p.Socket, p.MemoryType, p.PowerWattage, p.FormFactor;


-- ============================================================================
-- 13. CUSTOM PC BUILDS & STORE STAFF REVIEWS
-- ============================================================================
CREATE TABLE CustomBuilds (
    BuildId SERIAL PRIMARY KEY,
    UserId INT REFERENCES Users(UserId) ON DELETE CASCADE,
    BuildName VARCHAR(200) NOT NULL,
    TotalPrice DECIMAL(12, 2) NOT NULL,
    EstimatedWattage INT NOT NULL DEFAULT 0,
    Status VARCHAR(50) NOT NULL DEFAULT 'Pending Staff Review', -- 'Pending Staff Review', 'In Review by Staff', 'Approved by Staff', 'Changes Requested', 'Ordered'
    CustomerNotes TEXT,
    StaffNotes TEXT,
    AssignedStaffId INT REFERENCES Staff(StaffId) ON DELETE SET NULL,
    CreatedAt TIMESTAMPTZ DEFAULT NOW(),
    UpdatedAt TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_custombuilds_user ON CustomBuilds(UserId);
CREATE INDEX idx_custombuilds_status ON CustomBuilds(Status);
CREATE INDEX idx_custombuilds_assigned_staff ON CustomBuilds(AssignedStaffId);

CREATE TABLE CustomBuildItems (
    BuildItemId SERIAL PRIMARY KEY,
    BuildId INT REFERENCES CustomBuilds(BuildId) ON DELETE CASCADE,
    ProductId INT REFERENCES Products(ProductId) ON DELETE RESTRICT,
    SlotType VARCHAR(50) NOT NULL, -- 'cpu', 'motherboard', 'ram', 'gpu', 'psu', 'storage', 'pcCase'
    UnitPrice DECIMAL(12, 2) NOT NULL
);

CREATE INDEX idx_custombuilditems_build ON CustomBuildItems(BuildId);
CREATE INDEX idx_custombuilditems_product ON CustomBuildItems(ProductId);