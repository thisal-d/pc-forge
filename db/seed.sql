-- ============================================================================
-- PCForge Database Clean Seed Data
-- Real-world products, essential categories, dynamic filters, and clean users.
-- All fake orders, fake custom builds, and fake service requests removed.
-- ============================================================================

BEGIN;

-- 1. CLEANUP ALL EXISTING TRANSACTIONAL & FAKE DATA
DELETE FROM OrderItems;
DELETE FROM Orders;
DELETE FROM CustomBuildItems;
DELETE FROM CustomBuilds;
DELETE FROM ServiceRequests;
DO $$ 
BEGIN 
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'supporttickets') THEN
        DELETE FROM SupportTickets;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'cartitems') THEN
        DELETE FROM CartItems;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'carts') THEN
        DELETE FROM Carts;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'requirement_sessions') THEN
        DELETE FROM requirement_sessions;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'coupons') THEN
        DELETE FROM coupons;
    END IF;
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'productfiltervalues') THEN
        DELETE FROM ProductFilterValues;
    END IF;
END $$;

DELETE FROM Products;
DELETE FROM FilterOptions;
DELETE FROM CategoryFilters;
DELETE FROM Categories;
DELETE FROM Staff;
DELETE FROM Users;
DELETE FROM Roles;

-- Reset Sequences
ALTER SEQUENCE IF EXISTS roles_roleid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS users_userid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS staff_staffid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS categories_categoryid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS products_productid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS categoryfilters_filterid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS filteroptions_optionid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS orders_orderid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS orderitems_orderitemid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS custombuilds_buildid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS custombuilditems_builditemid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS servicerequests_servicerequestid_seq RESTART WITH 1;


-- 2. ROLES (1: Customer, 2: Admin, 3: Staff)
INSERT INTO Roles (RoleId, RoleName, Description) VALUES 
(1, 'Customer', 'Can browse products, create custom builds, and place orders.'),
(2, 'Admin', 'Full administrative control over catalog, inventory, orders, and system settings.'),
(3, 'Staff', 'Can review custom builds, manage stock levels, and service customer requests.');

SELECT setval('roles_roleid_seq', 3);


-- 3. USERS (Exactly 1 Admin, 1 Staff, 1 Customer)
-- Passwords:
-- Admin:    Admin123!
-- Staff:    Staff123!
-- Customer: Cust123!
INSERT INTO Users (UserId, Email, PasswordHash, RoleId, FirstName, LastName, IsActive, CreatedAt, UpdatedAt) VALUES 
(1, 'admin@pcforge.com', '$2a$11$y07hPBpnumthsEP7hMpTheAjvmF4VV9eJO6GB8xWW3qSrhN/O4VN2', 2, 'Store', 'Admin', TRUE, NOW(), NOW()),
(2, 'staff@pcforge.com', '$2a$11$6Cgz1jo8SxaFDOkqF79P6uh7HsgiYH.vO3O0Glul/kvsmwou/CYdG', 3, 'Store', 'Staff', TRUE, NOW(), NOW()),
(3, 'customer@pcforge.com', '$2a$11$VTiQ/daNDOaxA4qPCsFoCu7cjqv0rA/fbpo.gPN9uAx1SbNuKUO2q', 1, 'Demo', 'Customer', TRUE, NOW(), NOW());

SELECT setval('users_userid_seq', 3);


-- 4. STAFF PROFILE (Linked to Staff User 2)
INSERT INTO Staff (StaffId, UserId, Department, Phone, Specialization, Status, Notes, JoinedDate, CreatedAt, UpdatedAt) VALUES 
(1, 2, 'Hardware Diagnostics & Repair', '+94 77 123 4567', 'Lead technician for custom PC assembly, thermal profiling, and RMA diagnostics.', 'Active', 'Primary store technician.', '2025-01-15', NOW(), NOW());

SELECT setval('staff_staffid_seq', 1);


-- 5. REAL-WORLD CATEGORIES
INSERT INTO Categories (CategoryId, Name, Description, CreatedAt) VALUES 
(1, 'CPU', 'Desktop Processors & Central Processing Units', NOW()),
(2, 'GPU', 'Dedicated Graphics Cards & Video Processing Units', NOW()),
(3, 'Motherboard', 'Desktop Motherboards & Main Circuit Boards', NOW()),
(4, 'RAM', 'High-Speed DDR4 & DDR5 System Memory Modules', NOW()),
(5, 'PSU', 'High-Efficiency Desktop Power Supply Units', NOW()),
(6, 'Storage', 'High-Speed PCIe NVMe Solid State Drives', NOW()),
(7, 'Case', 'Premium Desktop PC Cases & Airflow Enclosures', NOW()),
(8, 'Cooler', 'AIO Liquid Coolers & High-Performance Air Coolers', NOW());

SELECT setval('categories_categoryid_seq', 8);


-- 6. CATEGORY FILTERS (Dynamic Facets per Category)
INSERT INTO CategoryFilters (FilterId, CategoryId, FilterKey, DisplayName, FilterType, Unit, DisplayOrder, IsFilterable, CreatedAt) VALUES
-- CPU Filters (Category 1)
(1, 1, 'socket', 'Socket Type', 'multiselect', NULL, 1, TRUE, NOW()),
(2, 1, 'series', 'Processor Series', 'multiselect', NULL, 2, TRUE, NOW()),

-- GPU Filters (Category 2)
(3, 2, 'vram', 'VRAM Capacity', 'multiselect', 'GB', 1, TRUE, NOW()),
(4, 2, 'chipset', 'GPU Series / Chipset', 'multiselect', NULL, 2, TRUE, NOW()),

-- Motherboard Filters (Category 3)
(5, 3, 'socket', 'Socket Type', 'multiselect', NULL, 1, TRUE, NOW()),
(6, 3, 'chipset', 'Chipset', 'multiselect', NULL, 2, TRUE, NOW()),
(7, 3, 'form_factor', 'Form Factor', 'multiselect', NULL, 3, TRUE, NOW()),

-- RAM Filters (Category 4)
(8, 4, 'ddr_type', 'DDR Type', 'multiselect', NULL, 1, TRUE, NOW()),
(9, 4, 'speed', 'Memory Speed / Bus', 'multiselect', 'MHz', 2, TRUE, NOW()),
(10, 4, 'capacity', 'Kit Capacity', 'multiselect', 'GB', 3, TRUE, NOW()),

-- PSU Filters (Category 5)
(11, 5, 'wattage', 'Power Wattage', 'singleselect', 'W', 1, TRUE, NOW()),
(12, 5, 'efficiency', 'Efficiency Rating', 'multiselect', NULL, 2, TRUE, NOW()),

-- Storage Filters (Category 6)
(13, 6, 'capacity', 'Storage Capacity', 'multiselect', 'TB', 1, TRUE, NOW()),
(14, 6, 'interface', 'Interface Standard', 'multiselect', NULL, 2, TRUE, NOW()),

-- Case Filters (Category 7)
(15, 7, 'form_factor', 'Form Factor', 'multiselect', NULL, 1, TRUE, NOW()),
(16, 7, 'color', 'Chassis Color', 'multiselect', NULL, 2, TRUE, NOW()),

-- Cooler Filters (Category 8)
(17, 8, 'cooler_type', 'Cooler Type', 'multiselect', NULL, 1, TRUE, NOW()),
(18, 8, 'socket', 'Socket Compatibility', 'multiselect', NULL, 2, TRUE, NOW());

SELECT setval('categoryfilters_filterid_seq', 18);


-- 7. FILTER OPTIONS (Selectable Facets)
INSERT INTO FilterOptions (OptionId, FilterId, OptionValue, DisplayOrder) VALUES
-- CPU Sockets (Filter 1) & Series (Filter 2)
(1, 1, 'AM5', 1),
(2, 1, 'LGA1700', 2),
(3, 1, 'AM4', 3),
(4, 2, 'Ryzen 7', 1),
(5, 2, 'Ryzen 9', 2),
(6, 2, 'Ryzen 5', 3),
(7, 2, 'Core i7', 4),
(8, 2, 'Core i9', 5),
(9, 2, 'Core i5', 6),

-- GPU VRAM (Filter 3) & Chipsets (Filter 4)
(10, 3, '8GB', 1),
(11, 3, '12GB', 2),
(12, 3, '16GB', 3),
(13, 3, '24GB', 4),
(14, 4, 'GeForce RTX 4090', 1),
(15, 4, 'GeForce RTX 4080 Super', 2),
(16, 4, 'GeForce RTX 4070 Ti Super', 3),
(17, 4, 'GeForce RTX 4060 Ti', 4),
(18, 4, 'Radeon RX 7900 XTX', 5),

-- Motherboard Sockets (Filter 5), Chipsets (Filter 6), Form Factor (Filter 7)
(19, 5, 'AM5', 1),
(20, 5, 'LGA1700', 2),
(21, 6, 'X670E', 1),
(22, 6, 'B650', 2),
(23, 6, 'Z790', 3),
(24, 6, 'B760', 4),
(25, 7, 'ATX', 1),
(26, 7, 'Micro-ATX', 2),
(27, 7, 'Mini-ITX', 3),

-- RAM DDR (Filter 8), Speed (Filter 9), Capacity (Filter 10)
(28, 8, 'DDR5', 1),
(29, 8, 'DDR4', 2),
(30, 9, '3200 MHz', 1),
(31, 9, '5600 MHz', 2),
(32, 9, '6000 MHz', 3),
(33, 9, '6400 MHz', 4),
(34, 10, '16GB', 1),
(35, 10, '32GB', 2),
(36, 10, '64GB', 3),

-- PSU Wattage (Filter 11), Efficiency (Filter 12)
(37, 11, '650W', 1),
(38, 11, '750W', 2),
(39, 11, '850W', 3),
(40, 11, '1000W', 4),
(41, 12, '80+ Bronze', 1),
(42, 12, '80+ Gold', 2),
(43, 12, '80+ Platinum', 3),

-- Storage Capacity (Filter 13), Interface (Filter 14)
(44, 13, '1TB', 1),
(45, 13, '2TB', 2),
(46, 13, '4TB', 3),
(47, 14, 'PCIe 4.0 NVMe', 1),
(48, 14, 'PCIe 5.0 NVMe', 2),

-- Case Form Factor (Filter 15), Color (Filter 16)
(49, 15, 'ATX Mid Tower', 1),
(50, 15, 'ATX Full Tower', 2),
(51, 15, 'Mini-ITX', 3),
(52, 16, 'Black', 1),
(53, 16, 'White', 2),

-- Cooler Type (Filter 17), Socket (Filter 18)
(54, 17, '360mm AIO Liquid', 1),
(55, 17, '240mm AIO Liquid', 2),
(56, 17, 'Dual-Tower Air', 3),
(57, 18, 'AM5', 1),
(58, 18, 'LGA1700', 2),

-- Additional Facets (GPU, Motherboard, PSU, Case, Cooler)
(59, 4, 'GeForce RTX 4070 Super', 6),
(60, 4, 'GeForce RTX 4060', 7),
(61, 4, 'GeForce RTX 3060', 8),
(62, 4, 'Radeon RX 7800 XT', 9),
(63, 4, 'Radeon RX 7600', 10),
(64, 5, 'AM4', 3),
(65, 6, 'B550', 5),
(66, 11, '1200W', 5),
(67, 15, 'Micro-ATX', 4),
(68, 17, 'Single-Tower Air', 4),
(69, 18, 'AM4', 3);

SELECT setval('filteroptions_optionid_seq', 69);


-- 8. REAL-WORLD PRODUCTS (Full Hardware Catalog with Real Market Specs)
INSERT INTO Products (ProductId, CategoryId, Name, Brand, Model, Price, StockQuantity, Socket, MemoryType, PowerWattage, FormFactor, WarrantyMonths, Status, ImageUrl, Description, Specifications) VALUES
-- CPUs (Category 1)
(1, 1, 'AMD Ryzen 7 7800X3D', 'AMD', '100-100000910WOF', 145000.00, 25, 'AM5', 'DDR5', 120, NULL, 36, 'Active', 
 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=600&auto=format&fit=crop&q=80',
 'The undisputed king of gaming processors featuring AMD 3D V-Cache technology for unmatched gaming frame rates and thermal efficiency on socket AM5.',
 '{"socket": "AM5", "cores": 8, "threads": 16, "baseClock": "4.2 GHz", "boostClock": "5.0 GHz", "cache": "104MB 3D V-Cache", "tdp": 120, "series": "Ryzen 7"}'::jsonb),

(2, 1, 'AMD Ryzen 9 7950X', 'AMD', '100-100000514WOF', 175000.00, 15, 'AM5', 'DDR5', 170, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=600&auto=format&fit=crop&q=80',
 '16-core flagship workstation processor engineered for heavy multi-threaded rendering, code compilation, and extreme content creation workloads.',
 '{"socket": "AM5", "cores": 16, "threads": 32, "baseClock": "4.5 GHz", "boostClock": "5.7 GHz", "cache": "80MB", "tdp": 170, "series": "Ryzen 9"}'::jsonb),

(3, 1, 'AMD Ryzen 5 7600X', 'AMD', '100-100000593WOF', 69000.00, 30, 'AM5', 'DDR5', 105, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=600&auto=format&fit=crop&q=80',
 'High-value 6-core powerhouse delivering exceptional 1080p and 1440p gaming performance on modern AM5 DDR5 platforms.',
 '{"socket": "AM5", "cores": 6, "threads": 12, "baseClock": "4.7 GHz", "boostClock": "5.3 GHz", "cache": "38MB", "tdp": 105, "series": "Ryzen 5"}'::jsonb),

(4, 1, 'Intel Core i7-14700K', 'Intel', 'BX8071514700K', 128000.00, 20, 'LGA1700', 'DDR5', 253, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=600&auto=format&fit=crop&q=80',
 '20-core Raptor Lake Refresh hybrid architecture CPU optimized for seamless high-FPS gaming and heavy multitasking.',
 '{"socket": "LGA1700", "cores": 20, "performanceCores": 8, "efficientCores": 12, "threads": 28, "baseClock": "3.4 GHz", "boostClock": "5.6 GHz", "tdp": 253, "series": "Core i7"}'::jsonb),

(5, 1, 'Intel Core i9-14900K', 'Intel', 'BX8071514900K', 185000.00, 12, 'LGA1700', 'DDR5', 253, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=600&auto=format&fit=crop&q=80',
 'Enthusiast-grade flagship hitting up to 6.0 GHz right out of the box with 24 cores for unmatched computing horsepower.',
 '{"socket": "LGA1700", "cores": 24, "performanceCores": 8, "efficientCores": 16, "threads": 32, "baseClock": "3.2 GHz", "boostClock": "6.0 GHz", "tdp": 253, "series": "Core i9"}'::jsonb),

-- GPUs (Category 2)
(6, 2, 'ASUS ROG Strix GeForce RTX 4090 24GB OC', 'ASUS', 'ROG-STRIX-RTX4090-O24G-GAMING', 580000.00, 8, NULL, NULL, 450, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'The ultimate consumer GPU with 24GB of GDDR6X memory, custom vapor chamber, and monumental cooling for native 4K gaming and AI workloads.',
 '{"vram": "24GB", "memoryType": "GDDR6X", "interface": "PCIe 4.0", "length": "357mm", "recommendedPsu": "1000W", "chipset": "GeForce RTX 4090"}'::jsonb),

(7, 2, 'MSI Gaming X Slim GeForce RTX 4080 Super 16GB', 'MSI', 'RTX-4080-SUPER-16G-SLIM', 345000.00, 14, NULL, NULL, 320, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Top-tier 4K gaming powerhouse featuring full ray tracing capability, TRI FROZR 3 thermal design, and Ada Lovelace architecture.',
 '{"vram": "16GB", "memoryType": "GDDR6X", "interface": "PCIe 4.0", "length": "322mm", "recommendedPsu": "850W", "chipset": "GeForce RTX 4080 Super"}'::jsonb),

(8, 2, 'Gigabyte GeForce RTX 4070 Ti Super Windforce OC 16GB', 'Gigabyte', 'GV-N407TSWF3OC-16GD', 265000.00, 18, NULL, NULL, 285, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Upgraded 16GB VRAM buffer with 256-bit memory bus ideal for ultra-settings 1440p and entry 4K gaming with DLSS 3.',
 '{"vram": "16GB", "memoryType": "GDDR6X", "interface": "PCIe 4.0", "length": "261mm", "recommendedPsu": "750W", "chipset": "GeForce RTX 4070 Ti Super"}'::jsonb),

(9, 2, 'ASUS Dual GeForce RTX 4060 Ti 8GB EVO', 'ASUS', 'DUAL-RTX4060TI-8G-EVO', 129000.00, 25, NULL, NULL, 160, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Efficient compact dual-fan graphics card delivering high frame rates in 1080p competitive esports and 1440p gaming.',
 '{"vram": "8GB", "memoryType": "GDDR6", "interface": "PCIe 4.0", "length": "227mm", "recommendedPsu": "550W", "chipset": "GeForce RTX 4060 Ti"}'::jsonb),

(10, 2, 'Sapphire Nitro+ AMD Radeon RX 7900 XTX 24GB', 'Sapphire', '11322-01-20G', 325000.00, 10, NULL, NULL, 355, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Flagship RDNA 3 graphics with a massive 24GB frame buffer, vapor chamber cooling, and high raw rasterization power.',
 '{"vram": "24GB", "memoryType": "GDDR6", "interface": "PCIe 4.0", "length": "320mm", "recommendedPsu": "850W", "chipset": "Radeon RX 7900 XTX"}'::jsonb),

-- Motherboards (Category 3)
(11, 3, 'MSI MAG B650 Tomahawk WiFi', 'MSI', 'MAG-B650-TOMAHAWK', 68000.00, 20, 'AM5', 'DDR5', NULL, 'ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Rock-solid AM5 motherboard with 14+2+1 duet rail power system, extended heatsink design, and triple M.2 slots for high-end Ryzen builds.',
 '{"socket": "AM5", "chipset": "B650", "formFactor": "ATX", "memorySlots": 4, "maxMemory": "192GB", "m2Slots": "3x M.2 PCIe 4.0"}'::jsonb),

(12, 3, 'ASUS ROG Crosshair X670E Hero', 'ASUS', 'ROG-CROSSHAIR-X670E-HERO', 215000.00, 8, 'AM5', 'DDR5', NULL, 'ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Enthusiast motherboard built for extreme overclocking with dual PCIe 5.0 x16 slots, USB4 ports, and Polymo lighting.',
 '{"socket": "AM5", "chipset": "X670E", "formFactor": "ATX", "memorySlots": 4, "pcieSlots": "2x PCIe 5.0 x16", "m2Slots": "5x M.2"}'::jsonb),

(13, 3, 'ASUS TUF Gaming Z790-Plus WiFi', 'ASUS', 'TUF-GAMING-Z790-PLUS-WIFI', 79000.00, 15, 'LGA1700', 'DDR5', NULL, 'ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Military-spec components, 16+1 DrMOS power stages, PCIe 5.0 readiness, and four M.2 slots for 13th and 14th Gen Intel processors.',
 '{"socket": "LGA1700", "chipset": "Z790", "formFactor": "ATX", "memorySlots": 4, "m2Slots": "4x M.2 PCIe 4.0"}'::jsonb),

(14, 3, 'Gigabyte B650I AORUS Ultra Mini-ITX', 'Gigabyte', 'B650I-AORUS-ULTRA', 92000.00, 10, 'AM5', 'DDR5', NULL, 'Mini-ITX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Premium small form factor board with triple M.2 connectors, direct 8+2+1 phases, and active thermal cooling for compact ITX builds.',
 '{"socket": "AM5", "chipset": "B650", "formFactor": "Mini-ITX", "memorySlots": 2, "m2Slots": "3x M.2"}'::jsonb),

-- RAM (Category 4)
(15, 4, 'G.Skill Trident Z5 RGB 32GB (2x16GB) DDR5 6000MHz CL30', 'G.Skill', 'F5-6000J3038F16GX2-TZ5NR', 38000.00, 35, NULL, 'DDR5', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 'The gold standard for AM5 and Raptor Lake memory with ultra-low CL30 latency and addressable RGB heatspreaders.',
 '{"ddrType": "DDR5", "speed": "6000 MHz", "capacity": "32GB", "kit": "2x16GB", "latency": "CL30", "rgb": true}'::jsonb),

(16, 4, 'Corsair Vengeance RGB 32GB (2x16GB) DDR5 6000MHz CL36', 'Corsair', 'CMH32GX5M2B6000C36', 36000.00, 40, NULL, 'DDR5', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 'High-frequency DDR5 memory with ten-zone dynamic RGB lighting and onboard voltage regulation for fine-tuned overclocking.',
 '{"ddrType": "DDR5", "speed": "6000 MHz", "capacity": "32GB", "kit": "2x16GB", "latency": "CL36", "rgb": true}'::jsonb),

(17, 4, 'Corsair Vengeance LPX 32GB (2x16GB) DDR4 3200MHz CL16', 'Corsair', 'CMK32GX4M2E3200C16', 19000.00, 25, NULL, 'DDR4', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 'Pure aluminum heat spreader for faster heat dissipation and low-profile form factor designed for high-performance builds.',
 '{"ddrType": "DDR4", "speed": "3200 MHz", "capacity": "32GB", "kit": "2x16GB", "latency": "CL16", "rgb": false}'::jsonb),

-- PSUs (Category 5)
(18, 5, 'Corsair RM850x 850W 80+ Gold Fully Modular ATX 3.0', 'Corsair', 'CP-9020200-NA', 45000.00, 25, NULL, NULL, 850, 'ATX', 120, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Legendary quiet power supply with zero-RPM fan mode, Japanese industrial-grade capacitors, and 80 PLUS Gold efficiency.',
 '{"wattage": "850W", "efficiency": "80+ Gold", "modular": "Fully Modular", "formFactor": "ATX"}'::jsonb),

(19, 5, 'Seasonic Focus GX-1000 1000W 80+ Gold ATX 3.0', 'Seasonic', 'FOCUS-GX-1000-ATX3', 58000.00, 15, NULL, NULL, 1000, 'ATX', 120, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Native PCIe Gen 5 12VHPWR cable support providing 1000 Watts of rock-solid power for modern RTX 4090 and 4080 systems.',
 '{"wattage": "1000W", "efficiency": "80+ Gold", "modular": "Fully Modular", "formFactor": "ATX"}'::jsonb),

(20, 5, 'be quiet! Pure Power 12 M 750W 80+ Gold ATX 3.0', 'be quiet!', 'BN504', 35000.00, 20, NULL, NULL, 750, 'ATX', 120, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Exceptionally quiet operation with two independent 12V rails and high operating stability for mid-to-high tier builds.',
 '{"wattage": "750W", "efficiency": "80+ Gold", "modular": "Fully Modular", "formFactor": "ATX"}'::jsonb),

-- Storage (Category 6)
(21, 6, 'Samsung 990 PRO 2TB PCIe 4.0 NVMe M.2 SSD', 'Samsung', 'MZ-V9P2T0B/AM', 55000.00, 30, NULL, NULL, 8, 'M.2 2280', 60, 'Active',
 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=600&auto=format&fit=crop&q=80',
 'Top-tier PCIe Gen 4 performance with blistering sequential speeds up to 7,450 MB/s, ideal for gaming load times and 4K editing.',
 '{"capacity": "2TB", "interface": "PCIe 4.0 NVMe", "seqRead": "7450 MB/s", "seqWrite": "6900 MB/s", "formFactor": "M.2 2280"}'::jsonb),

(22, 6, 'Crucial T500 1TB PCIe 4.0 NVMe M.2 SSD', 'Crucial', 'CT1000T500SSD8', 29000.00, 35, NULL, NULL, 6, 'M.2 2280', 60, 'Active',
 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=600&auto=format&fit=crop&q=80',
 'High-speed Gen4 NVMe drive engineered with Micron 232-layer TLC NAND and onboard Microsoft DirectStorage acceleration.',
 '{"capacity": "1TB", "interface": "PCIe 4.0 NVMe", "seqRead": "7300 MB/s", "seqWrite": "6800 MB/s", "formFactor": "M.2 2280"}'::jsonb),

-- Cases (Category 7)
(23, 7, 'Lian Li O11 Dynamic EVO Dual-Chamber ATX Case', 'Lian Li', 'O11DEW', 49000.00, 15, NULL, NULL, NULL, 'ATX Mid Tower', 24, 'Active',
 'https://images.unsplash.com/photo-1587202372574-63309a96e5b4?w=600&auto=format&fit=crop&q=80',
 'Iconic dual-chamber chassis with versatile reversible layout, multi-directional power button, and room for up to three 360mm radiators.',
 '{"formFactor": "ATX Mid Tower", "color": "White", "sidePanel": "Tempered Glass", "gpuLengthMax": "422mm"}'::jsonb),

(24, 7, 'Fractal Design North Charcoal Black Mid Tower Case', 'Fractal Design', 'FD-C-NOR1C-01', 46000.00, 12, NULL, NULL, NULL, 'ATX Mid Tower', 24, 'Active',
 'https://images.unsplash.com/photo-1587202372574-63309a96e5b4?w=600&auto=format&fit=crop&q=80',
 'Transforming gaming spaces with natural materials, genuine walnut front panel, open airflow engineering, and brass details.',
 '{"formFactor": "ATX Mid Tower", "color": "Black", "frontPanel": "Real Walnut Wood", "sidePanel": "Tinted Glass"}'::jsonb),

-- Coolers (Category 8)
(25, 8, 'NZXT Kraken 360 RGB 360mm AIO Liquid Cooler', 'NZXT', 'RL-KR360-B1', 65000.00, 16, 'AM5 / LGA1700', NULL, 15, NULL, 72, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'High-performance Asetek pump with customizable real-time LCD screen display for CPU temperatures or custom GIFs and triple F-Series RGB fans.',
 '{"coolerType": "360mm AIO Liquid", "radiatorSize": "360mm", "display": "1.54 inch LCD", "socket": "AM5 / LGA1700"}'::jsonb),

(26, 8, 'Thermalright Peerless Assassin 120 SE Dual-Tower Air Cooler', 'Thermalright', 'PA120-SE', 12000.00, 40, 'AM5 / LGA1700', NULL, NULL, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Legendary price-to-performance dual-tower air cooler featuring 6 copper heat pipes and dual high-static-pressure PWM fans.',
 '{"coolerType": "Dual-Tower Air", "heatpipes": "6x 6mm AGHP", "tdp": 245, "socket": "AM5 / LGA1700"}'::jsonb),

-- Additional CPUs (Category 1)
(27, 1, 'AMD Ryzen 5 5600', 'AMD', '100-100000927BOX', 38000.00, 35, 'AM4', 'DDR4', 65, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=600&auto=format&fit=crop&q=80',
 'High-value 6-core 12-thread gaming processor delivering outstanding 1080p gaming performance on mature AM4 motherboards.',
 '{"socket": "AM4", "cores": 6, "threads": 12, "baseClock": "3.5 GHz", "boostClock": "4.4 GHz", "cache": "35MB", "tdp": 65, "series": "Ryzen 5"}'::jsonb),

(28, 1, 'AMD Ryzen 7 5700X3D', 'AMD', '100-100001503WOF', 72000.00, 20, 'AM4', 'DDR4', 105, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=600&auto=format&fit=crop&q=80',
 '8-core gaming powerhouse with 96MB 3D V-Cache delivering flagship gaming FPS on socket AM4 platforms without full motherboard replacement.',
 '{"socket": "AM4", "cores": 8, "threads": 16, "baseClock": "3.0 GHz", "boostClock": "4.1 GHz", "cache": "100MB 3D V-Cache", "tdp": 105, "series": "Ryzen 7"}'::jsonb),

(29, 1, 'Intel Core i5-14600K', 'Intel', 'BX8071514600K', 95000.00, 25, 'LGA1700', 'DDR5', 181, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=600&auto=format&fit=crop&q=80',
 '14-core desktop processor with 6 Performance-cores and 8 Efficient-cores delivering elite frame rates and productivity performance.',
 '{"socket": "LGA1700", "cores": 14, "performanceCores": 6, "efficientCores": 8, "threads": 20, "baseClock": "3.5 GHz", "boostClock": "5.3 GHz", "tdp": 181, "series": "Core i5"}'::jsonb),

(30, 1, 'Intel Core i5-13400F', 'Intel', 'BX8071513400F', 62000.00, 30, 'LGA1700', 'DDR5', 148, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=600&auto=format&fit=crop&q=80',
 '10-core budget champion offering incredible price-to-performance for mid-tier gaming setups without integrated graphics.',
 '{"socket": "LGA1700", "cores": 10, "performanceCores": 6, "efficientCores": 4, "threads": 16, "baseClock": "2.5 GHz", "boostClock": "4.6 GHz", "tdp": 148, "series": "Core i5"}'::jsonb),

-- Additional GPUs (Category 2)
(31, 2, 'ASUS Dual GeForce RTX 4070 Super 12GB EVO', 'ASUS', 'DUAL-RTX4070S-12G-EVO', 215000.00, 16, NULL, NULL, 220, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Exceptional 1440p gaming graphics card featuring Ada Lovelace architecture, DLSS 3 frame generation, and 12GB of high-speed GDDR6X.',
 '{"vram": "12GB", "memoryType": "GDDR6X", "interface": "PCIe 4.0", "length": "227mm", "recommendedPsu": "650W", "chipset": "GeForce RTX 4070 Super"}'::jsonb),

(32, 2, 'MSI GeForce RTX 4060 Ventus 2X Black 8GB OC', 'MSI', 'RTX-4060-VENTUS-2X-8G', 98000.00, 28, NULL, NULL, 115, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Highly efficient dual-fan graphics card built for maximum 1080p competitive esports framerates with low power consumption.',
 '{"vram": "8GB", "memoryType": "GDDR6", "interface": "PCIe 4.0", "length": "199mm", "recommendedPsu": "550W", "chipset": "GeForce RTX 4060"}'::jsonb),

(33, 2, 'Sapphire Pulse AMD Radeon RX 7800 XT 16GB', 'Sapphire', '11330-02-20G', 185000.00, 15, NULL, NULL, 263, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'High-performance 1440p gaming card with a generous 16GB VRAM buffer, RDNA 3 architecture, and dual-X cooling.',
 '{"vram": "16GB", "memoryType": "GDDR6", "interface": "PCIe 4.0", "length": "280mm", "recommendedPsu": "700W", "chipset": "Radeon RX 7800 XT"}'::jsonb),

(34, 2, 'Gigabyte GeForce RTX 3060 Windforce OC 12GB', 'Gigabyte', 'GV-N3060WF2OC-12GD', 88000.00, 25, NULL, NULL, 170, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Timeless budget king boasting a huge 12GB VRAM buffer for 1080p gaming, 3D modeling, and local AI image generation.',
 '{"vram": "12GB", "memoryType": "GDDR6", "interface": "PCIe 4.0", "length": "198mm", "recommendedPsu": "550W", "chipset": "GeForce RTX 3060"}'::jsonb),

(35, 2, 'XFX Speedster QICK 308 Radeon RX 7600 8GB', 'XFX', 'RX-76PQICKBY', 82000.00, 22, NULL, NULL, 165, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&auto=format&fit=crop&q=80',
 'Triple-fan cooling meets RDNA 3 compute for blazing 1080p gaming performance and AV1 hardware encoding.',
 '{"vram": "8GB", "memoryType": "GDDR6", "interface": "PCIe 4.0", "length": "274mm", "recommendedPsu": "550W", "chipset": "Radeon RX 7600"}'::jsonb),

-- Additional Motherboards (Category 3)
(36, 3, 'MSI B550-A PRO', 'MSI', 'B550-A-PRO', 42000.00, 25, 'AM4', 'DDR4', NULL, 'ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Reliable ATX motherboard featuring extended heatsink, Core Boost, DDR4 Boost, and PCIe 4.0 M.2 slot for Ryzen 5000 builds.',
 '{"socket": "AM4", "chipset": "B550", "formFactor": "ATX", "memorySlots": 4, "maxMemory": "128GB", "m2Slots": "2x M.2"}'::jsonb),

(37, 3, 'ASUS Prime B550M-A WiFi II', 'ASUS', 'PRIME-B550M-A-WIFI-II', 36000.00, 20, 'AM4', 'DDR4', NULL, 'Micro-ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Compact Micro-ATX board with onboard WiFi 6, dual M.2 slots, HDMI 2.1, and Addressable Gen 2 RGB headers.',
 '{"socket": "AM4", "chipset": "B550", "formFactor": "Micro-ATX", "memorySlots": 4, "maxMemory": "128GB", "m2Slots": "2x M.2"}'::jsonb),

(38, 3, 'MSI MAG B760 Tomahawk WiFi', 'MSI', 'MAG-B760-TOMAHAWK', 69000.00, 18, 'LGA1700', 'DDR5', NULL, 'ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'Solid 12+1+1 duet rail power system, triple M.2 Gen4 slots, and DDR5 7000+ MHz overclocking for Intel 13th & 14th Gen.',
 '{"socket": "LGA1700", "chipset": "B760", "formFactor": "ATX", "memorySlots": 4, "maxMemory": "192GB", "m2Slots": "3x M.2 PCIe 4.0"}'::jsonb),

(39, 3, 'ASRock B650M Pro RS WiFi', 'ASRock', 'B650M-PRO-RS-WIFI', 54000.00, 22, 'AM5', 'DDR5', NULL, 'Micro-ATX', 36, 'Active',
 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&auto=format&fit=crop&q=80',
 'High-value AM5 Micro-ATX board with Blazing M.2 (PCIe Gen5 x4), 8+2+1 power phase, and onboard WiFi 6E.',
 '{"socket": "AM5", "chipset": "B650", "formFactor": "Micro-ATX", "memorySlots": 4, "maxMemory": "192GB", "m2Slots": "3x M.2"}'::jsonb),

-- Additional RAM (Category 4)
(40, 4, 'Kingston FURY Beast 16GB (2x8GB) DDR4 3200MHz CL16', 'Kingston', 'KF432C16BBK2/16', 12000.00, 40, NULL, 'DDR4', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 'Low-profile heat spreader design offering cost-effective, high-performance upgrade for Intel and AMD AM4 systems.',
 '{"ddrType": "DDR4", "speed": "3200 MHz", "capacity": "16GB", "kit": "2x8GB", "latency": "CL16", "rgb": false}'::jsonb),

(41, 4, 'Corsair Vengeance 64GB (2x32GB) DDR5 6000MHz CL30', 'Corsair', 'CMK64GX5M2B6000C30', 68000.00, 15, NULL, 'DDR5', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 'Massive 64GB capacity kit with tight CL30 timings engineered for heavy video editing, CAD, and virtualized workloads.',
 '{"ddrType": "DDR5", "speed": "6000 MHz", "capacity": "64GB", "kit": "2x32GB", "latency": "CL30", "rgb": false}'::jsonb),

(42, 4, 'TeamGroup T-Force Delta RGB 32GB (2x16GB) DDR5 6000MHz White', 'TeamGroup', 'FF4D532G6000HC30DC01', 39000.00, 25, NULL, 'DDR5', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 '120-degree ultra-wide lighting angle with stealth-inspired white geometric aluminum heat spreader for modern white PC builds.',
 '{"ddrType": "DDR5", "speed": "6000 MHz", "capacity": "32GB", "kit": "2x16GB", "latency": "CL30", "rgb": true}'::jsonb),

(43, 4, 'Crucial 16GB (2x8GB) DDR5 5600MHz CL46', 'Crucial', 'CT2K8G56C46U5', 22000.00, 30, NULL, 'DDR5', NULL, NULL, 120, 'Active',
 'https://images.unsplash.com/photo-1562976540-1502c2145186?w=600&auto=format&fit=crop&q=80',
 'Standard DDR5 plug-and-play memory kit providing next-gen DDR5 speeds at budget-accessible pricing.',
 '{"ddrType": "DDR5", "speed": "5600 MHz", "capacity": "16GB", "kit": "2x8GB", "latency": "CL46", "rgb": false}'::jsonb),

-- Additional PSUs (Category 5)
(44, 5, 'Corsair CX650 650W 80+ Bronze Non-Modular', 'Corsair', 'CP-9020278-NA', 21000.00, 35, NULL, NULL, 650, 'ATX', 60, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Reliable, low-noise 80 PLUS Bronze power supply with 120mm thermally controlled fan for mainstream PC builds.',
 '{"wattage": "650W", "efficiency": "80+ Bronze", "modular": "Non-Modular", "formFactor": "ATX"}'::jsonb),

(45, 5, 'MSI MAG A650BN 650W 80+ Bronze', 'MSI', 'MAG-A650BN', 19500.00, 30, NULL, NULL, 650, 'ATX', 60, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'DC-DC circuit design with comprehensive OVP, OCP, OPP, and OTP protections delivering safe, stable power to budget rigs.',
 '{"wattage": "650W", "efficiency": "80+ Bronze", "modular": "Non-Modular", "formFactor": "ATX"}'::jsonb),

(46, 5, 'Corsair HX1200 1200W 80+ Platinum Fully Modular', 'Corsair', 'CP-9020140-NA', 78000.00, 10, NULL, NULL, 1200, 'ATX', 120, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Industrial-grade 80 PLUS Platinum certified power supply with zero-RPM fan mode and 100% Japanese 105C capacitors for flagship builds.',
 '{"wattage": "1200W", "efficiency": "80+ Platinum", "modular": "Fully Modular", "formFactor": "ATX"}'::jsonb),

-- Additional Storage (Category 6)
(47, 6, 'Kingston NV2 1TB PCIe 4.0 NVMe M.2 SSD', 'Kingston', 'SNV2S/1000G', 18500.00, 40, NULL, NULL, 5, 'M.2 2280', 36, 'Active',
 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=600&auto=format&fit=crop&q=80',
 'Compact single-sided M.2 2280 design offering Gen 4x4 NVMe read speeds up to 3500 MB/s for budget-conscious gamers.',
 '{"capacity": "1TB", "interface": "PCIe 4.0 NVMe", "seqRead": "3500 MB/s", "seqWrite": "2100 MB/s", "formFactor": "M.2 2280"}'::jsonb),

(48, 6, 'WD_BLACK SN850X 2TB PCIe 4.0 NVMe M.2 SSD with Heatsink', 'Western Digital', 'WDBB9G0020BNC-WRSN', 58000.00, 20, None, None, 8, 'M.2 2280', 60, 'Active',
 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=600&auto=format&fit=crop&q=80',
 'Elite top-tier gaming storage with integrated low-profile heatsink delivering blistering read speeds up to 7300 MB/s.',
 '{"capacity": "2TB", "interface": "PCIe 4.0 NVMe", "seqRead": "7300 MB/s", "seqWrite": "6600 MB/s", "formFactor": "M.2 2280"}'::jsonb),

(49, 6, 'Samsung 990 PRO 4TB PCIe 4.0 NVMe M.2 SSD', 'Samsung', 'MZ-V9P4T0B/AM', 115000.00, 10, None, None, 9, 'M.2 2280', 60, 'Active',
 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=600&auto=format&fit=crop&q=80',
 'Colossal 4TB capacity with Samsung in-house Pascal controller and thermal management for extreme content creation.',
 '{"capacity": "4TB", "interface": "PCIe 4.0 NVMe", "seqRead": "7450 MB/s", "seqWrite": "6900 MB/s", "formFactor": "M.2 2280"}'::jsonb),

(50, 6, 'Lexar NM790 1TB PCIe 4.0 NVMe M.2 SSD', 'Lexar', 'LNM790X001T-RNNNG', 24000.00, 30, None, None, 6, 'M.2 2280', 60, 'Active',
 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=600&auto=format&fit=crop&q=80',
 'High-speed DRAM-less Gen 4x4 SSD hitting up to 7400 MB/s read speed with HMB 3.0 technology.',
 '{"capacity": "1TB", "interface": "PCIe 4.0 NVMe", "seqRead": "7400 MB/s", "seqWrite": "6500 MB/s", "formFactor": "M.2 2280"}'::jsonb),

-- Additional Cases (Category 7)
(51, 7, 'NZXT H5 Flow Compact ATX Mid Tower Case Black', 'NZXT', 'CC-H51FB-01', 28000.00, 25, NULL, NULL, NULL, 'ATX Mid Tower', 24, 'Active',
 'https://images.unsplash.com/photo-1587202372574-63309a96e5b4?w=600&auto=format&fit=crop&q=80',
 'Perforated front panel for maximum airflow efficiency and dedicated bottom fan angled towards the GPU.',
 '{"formFactor": "ATX Mid Tower", "color": "Black", "sidePanel": "Tempered Glass", "gpuLengthMax": "365mm"}'::jsonb),

(52, 7, 'Corsair 4000D Airflow Tempered Glass Mid-Tower Case White', 'Corsair', 'CC-9011201-WW', 32000.00, 20, NULL, NULL, NULL, 'ATX Mid Tower', 24, 'Active',
 'https://images.unsplash.com/photo-1587202372574-63309a96e5b4?w=600&auto=format&fit=crop&q=80',
 'High-airflow front panel, Corsair RapidRoute cable routing system, and two included 120mm AirGuide fans in clean white.',
 '{"formFactor": "ATX Mid Tower", "color": "White", "sidePanel": "Tempered Glass", "gpuLengthMax": "360mm"}'::jsonb),

(53, 7, 'Montech AIR 903 MAX Black Mid Tower Case', 'Montech', 'AIR903MAX-B', 26000.00, 22, NULL, NULL, NULL, 'ATX Mid Tower', 24, 'Active',
 'https://images.unsplash.com/photo-1587202372574-63309a96e5b4?w=600&auto=format&fit=crop&q=80',
 'Ultra-cooling chassis with 51% porosity mesh front panel, 4x pre-installed 140mm PWM ARGB fans, and 360mm radiator support.',
 '{"formFactor": "ATX Mid Tower", "color": "Black", "sidePanel": "Tempered Glass", "gpuLengthMax": "400mm"}'::jsonb),

(54, 7, 'Cooler Master MasterBox Q300L Micro-ATX Case', 'Cooler Master', 'MCB-Q300L-KANN-S00', 16500.00, 30, NULL, NULL, NULL, 'Micro-ATX', 24, 'Active',
 'https://images.unsplash.com/photo-1587202372574-63309a96e5b4?w=600&auto=format&fit=crop&q=80',
 'Compact Micro-ATX chassis with patterned magnetic dust filters, movable I/O panel, and edge-to-edge transparent side panel.',
 '{"formFactor": "Micro-ATX", "color": "Black", "sidePanel": "Acrylic", "gpuLengthMax": "360mm"}'::jsonb),

-- Additional Coolers (Category 8)
(55, 8, 'DeepCool AK400 High-Performance Single-Tower Air Cooler', 'DeepCool', 'R-AK400-BKNNMN-G-1', 8500.00, 35, 'AM5 / AM4 / LGA1700', NULL, 4, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Matrix fin design with 4 direct-touch copper heat pipes and 120mm FDB fan delivering up to 220W of heat dissipation.',
 '{"coolerType": "Single-Tower Air", "heatpipes": "4x 6mm", "tdp": 220, "socket": "AM5 / AM4 / LGA1700"}'::jsonb),

(56, 8, 'ARCTIC Liquid Freezer III 360 A-RGB Liquid Cooler Black', 'ARCTIC', 'ACFRE00144A', 44000.00, 15, 'AM5 / AM4 / LGA1700', NULL, 15, NULL, 72, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Industry-leading 38mm thick radiator with dedicated VRM fan, integrated cable management, and high static pressure P12 PWM fans.',
 '{"coolerType": "360mm AIO Liquid", "radiatorSize": "360mm", "vrmFan": true, "socket": "AM5 / AM4 / LGA1700"}'::jsonb),

(57, 8, 'DeepCool LS520 SE 240mm AIO Liquid Cooler White', 'DeepCool', 'R-LS520-WHAMMM-G-1', 27000.00, 18, 'AM5 / AM4 / LGA1700', NULL, 12, NULL, 60, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'High-performance 4th generation water pump with narrow-frame infinity mirror pump cap and dual FE120 ARGB fans in all-white.',
 '{"coolerType": "240mm AIO Liquid", "radiatorSize": "240mm", "socket": "AM5 / AM4 / LGA1700"}'::jsonb),

(58, 8, 'Thermalright Assassin X 120 Refined SE ARGB Cooler', 'Thermalright', 'AX120-R-SE-ARGB', 6500.00, 40, 'AM5 / AM4 / LGA1700', NULL, 4, NULL, 36, 'Active',
 'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=600&auto=format&fit=crop&q=80',
 'Ultra-budget single-tower cooler with AGHP 4th generation anti-gravity heat pipes and addressable RGB 120mm fan.',
 '{"coolerType": "Single-Tower Air", "heatpipes": "4x 6mm AGHP", "tdp": 185, "socket": "AM5 / AM4 / LGA1700"}'::jsonb);

SELECT setval('products_productid_seq', 58);


-- 9. PRODUCT FILTER VALUES (Relational Linkage for Nanotek-Style Faceted Navigation)
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'productfiltervalues') THEN
        INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
        -- CPU 1: 7800X3D (AM5, Ryzen 7)
        (1, 1, 1, 'AM5'),
        (1, 2, 4, 'Ryzen 7'),
        -- CPU 2: 7950X (AM5, Ryzen 9)
        (2, 1, 1, 'AM5'),
        (2, 2, 5, 'Ryzen 9'),
        -- CPU 3: 7600X (AM5, Ryzen 5)
        (3, 1, 1, 'AM5'),
        (3, 2, 6, 'Ryzen 5'),
        -- CPU 4: i7-14700K (LGA1700, Core i7)
        (4, 1, 2, 'LGA1700'),
        (4, 2, 7, 'Core i7'),
        -- CPU 5: i9-14900K (LGA1700, Core i9)
        (5, 1, 2, 'LGA1700'),
        (5, 2, 8, 'Core i9'),

        -- GPU 6: RTX 4090 (24GB VRAM, RTX 4090)
        (6, 3, 13, '24GB'),
        (6, 4, 14, 'GeForce RTX 4090'),
        -- GPU 7: RTX 4080 Super (16GB VRAM, RTX 4080 Super)
        (7, 3, 12, '16GB'),
        (7, 4, 15, 'GeForce RTX 4080 Super'),
        -- GPU 8: RTX 4070 Ti Super (16GB VRAM, RTX 4070 Ti Super)
        (8, 3, 12, '16GB'),
        (8, 4, 16, 'GeForce RTX 4070 Ti Super'),
        -- GPU 9: RTX 4060 Ti (8GB VRAM, RTX 4060 Ti)
        (9, 3, 10, '8GB'),
        (9, 4, 17, 'GeForce RTX 4060 Ti'),
        -- GPU 10: RX 7900 XTX (24GB VRAM, RX 7900 XTX)
        (10, 3, 13, '24GB'),
        (10, 4, 18, 'Radeon RX 7900 XTX'),

        -- Motherboard 11: MSI B650 Tomahawk (AM5, B650, ATX)
        (11, 5, 19, 'AM5'),
        (11, 6, 22, 'B650'),
        (11, 7, 25, 'ATX'),
        -- Motherboard 12: Crosshair X670E Hero (AM5, X670E, ATX)
        (12, 5, 19, 'AM5'),
        (12, 6, 21, 'X670E'),
        (12, 7, 25, 'ATX'),
        -- Motherboard 13: TUF Z790-Plus (LGA1700, Z790, ATX)
        (13, 5, 20, 'LGA1700'),
        (13, 6, 23, 'Z790'),
        (13, 7, 25, 'ATX'),
        -- Motherboard 14: B650I AORUS Mini-ITX (AM5, B650, Mini-ITX)
        (14, 5, 19, 'AM5'),
        (14, 6, 22, 'B650'),
        (14, 7, 27, 'Mini-ITX'),

        -- RAM 15: Trident Z5 RGB 32GB (DDR5, 6000 MHz, 32GB)
        (15, 8, 28, 'DDR5'),
        (15, 9, 32, '6000 MHz'),
        (15, 10, 35, '32GB'),
        -- RAM 16: Vengeance RGB 32GB (DDR5, 6000 MHz, 32GB)
        (16, 8, 28, 'DDR5'),
        (16, 9, 32, '6000 MHz'),
        (16, 10, 35, '32GB'),
        -- RAM 17: Vengeance LPX 32GB (DDR4, 3200 MHz, 32GB)
        (17, 8, 29, 'DDR4'),
        (17, 9, 30, '3200 MHz'),
        (17, 10, 35, '32GB'),

        -- PSU 18: Corsair RM850x (850W, 80+ Gold)
        (18, 11, 39, '850W'),
        (18, 12, 42, '80+ Gold'),
        -- PSU 19: Seasonic Focus 1000W (1000W, 80+ Gold)
        (19, 11, 40, '1000W'),
        (19, 12, 42, '80+ Gold'),
        -- PSU 20: be quiet! 750W (750W, 80+ Gold)
        (20, 11, 38, '750W'),
        (20, 12, 42, '80+ Gold'),

        -- Storage 21: Samsung 990 Pro 2TB (2TB, PCIe 4.0 NVMe)
        (21, 13, 45, '2TB'),
        (21, 14, 47, 'PCIe 4.0 NVMe'),
        -- Storage 22: Crucial T500 1TB (1TB, PCIe 4.0 NVMe)
        (22, 13, 44, '1TB'),
        (22, 14, 47, 'PCIe 4.0 NVMe'),

        -- Case 23: Lian Li O11 Dynamic EVO (ATX Mid Tower, White)
        (23, 15, 49, 'ATX Mid Tower'),
        (23, 16, 53, 'White'),
        -- Case 24: Fractal Design North (ATX Mid Tower, Black)
        (24, 15, 49, 'ATX Mid Tower'),
        (24, 16, 52, 'Black'),

        -- Cooler 25: NZXT Kraken 360 (360mm AIO Liquid, AM5)
        (25, 17, 54, '360mm AIO Liquid'),
        (25, 18, 57, 'AM5'),
        -- Cooler 26: Thermalright Peerless Assassin 120 (Dual-Tower Air, AM5)
        (26, 17, 56, 'Dual-Tower Air'),
        (26, 18, 57, 'AM5'),

        -- CPU 27: Ryzen 5 5600 (AM4, Ryzen 5)
        (27, 1, 3, 'AM4'), (27, 2, 6, 'Ryzen 5'),
        -- CPU 28: Ryzen 7 5700X3D (AM4, Ryzen 7)
        (28, 1, 3, 'AM4'), (28, 2, 4, 'Ryzen 7'),
        -- CPU 29: Core i5-14600K (LGA1700, Core i5)
        (29, 1, 2, 'LGA1700'), (29, 2, 9, 'Core i5'),
        -- CPU 30: Core i5-13400F (LGA1700, Core i5)
        (30, 1, 2, 'LGA1700'), (30, 2, 9, 'Core i5'),

        -- GPU 31: RTX 4070 Super (12GB, RTX 4070 Super)
        (31, 3, 11, '12GB'), (31, 4, 59, 'GeForce RTX 4070 Super'),
        -- GPU 32: RTX 4060 (8GB, RTX 4060)
        (32, 3, 10, '8GB'), (32, 4, 60, 'GeForce RTX 4060'),
        -- GPU 33: RX 7800 XT (16GB, RX 7800 XT)
        (33, 3, 12, '16GB'), (33, 4, 62, 'Radeon RX 7800 XT'),
        -- GPU 34: RTX 3060 (12GB, RTX 3060)
        (34, 3, 11, '12GB'), (34, 4, 61, 'GeForce RTX 3060'),
        -- GPU 35: RX 7600 (8GB, RX 7600)
        (35, 3, 10, '8GB'), (35, 4, 63, 'Radeon RX 7600'),

        -- Motherboard 36: MSI B550-A PRO (AM4, B550, ATX)
        (36, 5, 64, 'AM4'), (36, 6, 65, 'B550'), (36, 7, 25, 'ATX'),
        -- Motherboard 37: ASUS Prime B550M-A (AM4, B550, Micro-ATX)
        (37, 5, 64, 'AM4'), (37, 6, 65, 'B550'), (37, 7, 26, 'Micro-ATX'),
        -- Motherboard 38: MSI MAG B760 Tomahawk (LGA1700, B760, ATX)
        (38, 5, 20, 'LGA1700'), (38, 6, 24, 'B760'), (38, 7, 25, 'ATX'),
        -- Motherboard 39: ASRock B650M Pro RS (AM5, B650, Micro-ATX)
        (39, 5, 19, 'AM5'), (39, 6, 22, 'B650'), (39, 7, 26, 'Micro-ATX'),

        -- RAM 40: Kingston FURY Beast 16GB DDR4 (DDR4, 3200 MHz, 16GB)
        (40, 8, 29, 'DDR4'), (40, 9, 30, '3200 MHz'), (40, 10, 34, '16GB'),
        -- RAM 41: Corsair Vengeance 64GB DDR5 (DDR5, 6000 MHz, 64GB)
        (41, 8, 28, 'DDR5'), (41, 9, 32, '6000 MHz'), (41, 10, 36, '64GB'),
        -- RAM 42: TeamGroup Delta RGB 32GB White (DDR5, 6000 MHz, 32GB)
        (42, 8, 28, 'DDR5'), (42, 9, 32, '6000 MHz'), (42, 10, 35, '32GB'),
        -- RAM 43: Crucial 16GB DDR5 (DDR5, 5600 MHz, 16GB)
        (43, 8, 28, 'DDR5'), (43, 9, 31, '5600 MHz'), (43, 10, 34, '16GB'),

        -- PSU 44: Corsair CX650 (650W, 80+ Bronze)
        (44, 11, 37, '650W'), (44, 12, 41, '80+ Bronze'),
        -- PSU 45: MSI MAG A650BN (650W, 80+ Bronze)
        (45, 11, 37, '650W'), (45, 12, 41, '80+ Bronze'),
        -- PSU 46: Corsair HX1200 (1200W, 80+ Platinum)
        (46, 11, 66, '1200W'), (46, 12, 43, '80+ Platinum'),

        -- Storage 47: Kingston NV2 1TB (1TB, PCIe 4.0 NVMe)
        (47, 13, 44, '1TB'), (47, 14, 47, 'PCIe 4.0 NVMe'),
        -- Storage 48: WD_BLACK SN850X 2TB (2TB, PCIe 4.0 NVMe)
        (48, 13, 45, '2TB'), (48, 14, 47, 'PCIe 4.0 NVMe'),
        -- Storage 49: Samsung 990 PRO 4TB (4TB, PCIe 4.0 NVMe)
        (49, 13, 46, '4TB'), (49, 14, 47, 'PCIe 4.0 NVMe'),
        -- Storage 50: Lexar NM790 1TB (1TB, PCIe 4.0 NVMe)
        (50, 13, 44, '1TB'), (50, 14, 47, 'PCIe 4.0 NVMe'),

        -- Case 51: NZXT H5 Flow (ATX Mid Tower, Black)
        (51, 15, 49, 'ATX Mid Tower'), (51, 16, 52, 'Black'),
        -- Case 52: Corsair 4000D Airflow (ATX Mid Tower, White)
        (52, 15, 49, 'ATX Mid Tower'), (52, 16, 53, 'White'),
        -- Case 53: Montech AIR 903 MAX (ATX Mid Tower, Black)
        (53, 15, 49, 'ATX Mid Tower'), (53, 16, 52, 'Black'),
        -- Case 54: Cooler Master Q300L (Micro-ATX, Black)
        (54, 15, 67, 'Micro-ATX'), (54, 16, 52, 'Black'),

        -- Cooler 55: DeepCool AK400 (Single-Tower Air, AM5/AM4/LGA1700)
        (55, 17, 68, 'Single-Tower Air'), (55, 18, 57, 'AM5'), (55, 18, 69, 'AM4'), (55, 18, 58, 'LGA1700'),
        -- Cooler 56: ARCTIC Liquid Freezer III 360 (360mm AIO Liquid, AM5/AM4/LGA1700)
        (56, 17, 54, '360mm AIO Liquid'), (56, 18, 57, 'AM5'), (56, 18, 69, 'AM4'), (56, 18, 58, 'LGA1700'),
        -- Cooler 57: DeepCool LS520 SE (240mm AIO Liquid, AM5/AM4/LGA1700)
        (57, 17, 55, '240mm AIO Liquid'), (57, 18, 57, 'AM5'), (57, 18, 69, 'AM4'), (57, 18, 58, 'LGA1700'),
        -- Cooler 58: Thermalright Assassin X 120 (Single-Tower Air, AM5/AM4/LGA1700)
        (58, 17, 68, 'Single-Tower Air'), (58, 18, 57, 'AM5'), (58, 18, 69, 'AM4'), (58, 18, 58, 'LGA1700');
    END IF;
END $$;


-- 9. STORE PROMOTIONAL COUPONS
DO $$
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'coupons') THEN
        INSERT INTO coupons (code, description, discounttype, discountvalue, minsubtotal, maxdiscount, isactive, createdat)
        VALUES 
        ('WELCOME5', '5% Welcome Discount on your first PC build', 'PERCENTAGE', 5.0, 0.0, 8000.0, TRUE, NOW()),
        ('FORGE10', '10% PCForge Season Discount', 'PERCENTAGE', 10.0, 50000.0, 50000.0, TRUE, NOW()),
        ('GAMER2026', '15% High-End Gaming Promotion', 'PERCENTAGE', 15.0, 100000.0, 75000.0, TRUE, NOW()),
        ('SLIITVIP', '20% SLIIT Academic Partner VIP Discount', 'PERCENTAGE', 20.0, 150000.0, 100000.0, TRUE, NOW()),
        ('BUILDMASTER', 'Flat Rs. 15,000 Discount on High-End Custom Builds', 'FLAT', 15000.0, 300000.0, 15000.0, TRUE, NOW()),
        ('SUMMER20', '20% Previous Summer Seasonal Promotion', 'PERCENTAGE', 20.0, 40000.0, 25000.0, FALSE, NOW())
        ON CONFLICT (code) DO NOTHING;
    END IF;
END $$;

COMMIT;