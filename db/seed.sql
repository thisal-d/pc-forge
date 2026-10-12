-- ============================================================================
-- PCForge Database Seed Data
-- ============================================================================

-- 1. CATEGORIES
INSERT INTO Categories (Name, Description) VALUES 
('CPU', 'Processors'),
('GPU', 'Graphics Cards'),
('Motherboard', 'Main Circuit Boards'),
('RAM', 'Memory Modules'),
('PSU', 'Power Supply Units');


-- 2. CATEGORY FILTERS (Dynamic Facets per Category)
-- CPU Filters (Category 1)
INSERT INTO CategoryFilters (CategoryId, FilterKey, DisplayName, FilterType, Unit, DisplayOrder) VALUES
(1, 'socket', 'Socket Type', 'multiselect', NULL, 1);

-- GPU Filters (Category 2)
INSERT INTO CategoryFilters (CategoryId, FilterKey, DisplayName, FilterType, Unit, DisplayOrder) VALUES
(2, 'vram', 'VRAM Capacity', 'multiselect', 'GB', 1);

-- Motherboard Filters (Category 3: Nanotek style Socket & Chipset)
INSERT INTO CategoryFilters (CategoryId, FilterKey, DisplayName, FilterType, Unit, DisplayOrder) VALUES
(3, 'socket', 'Socket Type', 'multiselect', NULL, 1),
(3, 'chipset', 'Chipset', 'multiselect', NULL, 2),
(3, 'form_factor', 'Form Factor', 'multiselect', NULL, 3);

-- RAM Filters (Category 4: Nanotek style DDR Type, Speed, Capacity)
INSERT INTO CategoryFilters (CategoryId, FilterKey, DisplayName, FilterType, Unit, DisplayOrder) VALUES
(4, 'ddr_type', 'DDR Type', 'multiselect', NULL, 1),
(4, 'speed', 'Memory Speed / Bus', 'multiselect', 'MHz', 2),
(4, 'capacity', 'Capacity', 'multiselect', 'GB', 3);

-- PSU Filters (Category 5)
INSERT INTO CategoryFilters (CategoryId, FilterKey, DisplayName, FilterType, Unit, DisplayOrder) VALUES
(5, 'efficiency', 'Efficiency Rating', 'multiselect', NULL, 1),
(5, 'wattage', 'Power Wattage', 'singleselect', 'W', 2);


-- 3. FILTER OPTIONS (Selectable Chips / Dropdowns)
-- Socket options for CPU (FilterId 1) and Motherboard (FilterId 3)
INSERT INTO FilterOptions (FilterId, OptionValue, DisplayOrder) VALUES
(1, 'AM5', 1),
(1, 'LGA1700', 2);

-- VRAM options for GPU (FilterId 2)
INSERT INTO FilterOptions (FilterId, OptionValue, DisplayOrder) VALUES
(2, '8GB', 1),
(2, '12GB', 2),
(2, '16GB', 3),
(2, '24GB', 4);

-- Motherboard Socket (FilterId 3), Chipset (FilterId 4), Form Factor (FilterId 5)
INSERT INTO FilterOptions (FilterId, OptionValue, DisplayOrder) VALUES
(3, 'AM5', 1),
(3, 'LGA1700', 2),
(4, 'X670E', 1),
(4, 'B650', 2),
(4, 'Z790', 3),
(4, 'B760', 4),
(5, 'ATX', 1),
(5, 'Micro-ATX', 2),
(5, 'Mini-ITX', 3);

-- RAM DDR Type (FilterId 6), Speed (FilterId 7), Capacity (FilterId 8)
INSERT INTO FilterOptions (FilterId, OptionValue, DisplayOrder) VALUES
(6, 'DDR4', 1),
(6, 'DDR5', 2),
(7, '3200 MHz', 1),
(7, '5600 MHz', 2),
(7, '6000 MHz', 3),
(8, '16GB', 1),
(8, '32GB', 2),
(8, '64GB', 3);

-- PSU Efficiency (FilterId 9), Wattage (FilterId 10)
INSERT INTO FilterOptions (FilterId, OptionValue, DisplayOrder) VALUES
(9, '80+ Bronze', 1),
(9, '80+ Gold', 2),
(9, '80+ Platinum', 3),
(10, '650W', 1),
(10, '750W', 2),
(10, '850W', 3),
(10, '1000W', 4);


-- 4. PRODUCTS (Hardware Components with JSONB Specifications)
INSERT INTO Products (CategoryId, Name, Brand, Model, Price, StockQuantity, Socket, MemoryType, PowerWattage, FormFactor, WarrantyMonths, Specifications) VALUES
-- CPU (Category 1) - 3 Years (36 Months)
(1, 'AMD Ryzen 9 7950X', 'AMD', '7950X', 699.00, 10, 'AM5', 'DDR5', 170, NULL, 36, '{"socket": "AM5", "cores": 16, "threads": 32, "baseClock": "4.5 GHz", "warranty_months": 36}'::jsonb),
(1, 'Intel Core i9-13900K', 'Intel', '13900K', 589.00, 8, 'LGA1700', 'DDR5', 253, NULL, 36, '{"socket": "LGA1700", "cores": 24, "threads": 32, "baseClock": "3.0 GHz", "warranty_months": 36}'::jsonb),

-- GPU (Category 2) - 3 Years (36 Months)
(2, 'ASUS ROG Strix RTX 4090 24GB', 'ASUS', 'RTX 4090', 1599.00, 5, NULL, NULL, 450, NULL, 36, '{"vram": "24GB", "interface": "PCIe 4.0", "length": "357mm", "warranty_months": 36}'::jsonb),
(2, 'GeForce RTX 4070 Ti 12GB', 'NVIDIA', 'RTX 4070 Ti', 749.00, 12, NULL, NULL, 240, NULL, 36, '{"vram": "12GB", "interface": "PCIe 4.0", "length": "285mm", "warranty_months": 36}'::jsonb),
(2, 'AMD Radeon RX 7900 XTX 24GB', 'AMD', 'RX 7900 XTX', 999.00, 7, NULL, NULL, 355, NULL, 36, '{"vram": "24GB", "interface": "PCIe 4.0", "length": "287mm", "warranty_months": 36}'::jsonb),

-- Motherboard (Category 3: Socket + Chipset + FormFactor) - 3 Years (36 Months)
(3, 'ASUS ROG Crosshair X670E Hero', 'ASUS', 'X670E Hero', 699.00, 4, 'AM5', 'DDR5', NULL, 'ATX', 36, '{"socket": "AM5", "chipset": "X670E", "formFactor": "ATX", "memorySlots": 4, "warranty_months": 36}'::jsonb),
(3, 'MSI MAG B650 Tomahawk WiFi', 'MSI', 'B650 Tomahawk', 219.00, 8, 'AM5', 'DDR5', NULL, 'ATX', 36, '{"socket": "AM5", "chipset": "B650", "formFactor": "ATX", "memorySlots": 4, "warranty_months": 36}'::jsonb),

-- RAM (Category 4: DDR Type + Speed + Capacity) - 10 Years / Limited Lifetime (120 Months)
(4, 'G.Skill Trident Z5 RGB 32GB (2x16GB) DDR5 6000MHz', 'G.Skill', 'F5-6000J3636F16G2', 149.00, 20, NULL, 'DDR5', NULL, NULL, 120, '{"ddrType": "DDR5", "speed": "6000 MHz", "capacity": "32GB", "latency": "CL36", "warranty_months": 120}'::jsonb),
(4, 'Corsair Vengeance RGB 32GB (2x16GB) DDR5 5600MHz', 'Corsair', 'CMH32GX5M2B5600C36', 129.00, 15, NULL, 'DDR5', NULL, NULL, 120, '{"ddrType": "DDR5", "speed": "5600 MHz", "capacity": "32GB", "latency": "CL36", "warranty_months": 120}'::jsonb),

-- PSU (Category 5: Efficiency + Wattage) - 5 Years (60 Months)
(5, 'Corsair RM850x 850W 80+ Gold Fully Modular', 'Corsair', 'RM850x', 139.00, 15, NULL, NULL, 850, 'ATX', 60, '{"efficiency": "80+ Gold", "wattage": "850W", "modular": "Full", "warranty_months": 60}'::jsonb);


-- 5. PRODUCT FILTER VALUES (Relational Linkage for Dynamic Faceted Filtering)
-- CPU 1: Ryzen 9 7950X (Socket AM5)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(1, 1, 1, 'AM5');

-- CPU 2: Core i9-13900K (Socket LGA1700)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(2, 1, 2, 'LGA1700');

-- GPU 3: RTX 4090 (24GB VRAM)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(3, 2, 4, '24GB');

-- GPU 4: RTX 4070 Ti (12GB VRAM)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(4, 2, 2, '12GB');

-- GPU 5: RX 7900 XTX (24GB VRAM)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(5, 2, 4, '24GB');

-- Motherboard 6: ASUS ROG Crosshair X670E Hero (Socket AM5, Chipset X670E, Form Factor ATX)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(6, 3, 3, 'AM5'),
(6, 4, 5, 'X670E'),
(6, 5, 9, 'ATX');

-- Motherboard 7: MSI MAG B650 Tomahawk (Socket AM5, Chipset B650, Form Factor ATX)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(7, 3, 3, 'AM5'),
(7, 4, 6, 'B650'),
(7, 5, 9, 'ATX');

-- RAM 8: G.Skill Trident Z5 RGB 32GB 6000MHz (DDR5, 6000 MHz, 32GB)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(8, 6, 13, 'DDR5'),
(8, 7, 16, '6000 MHz'),
(8, 8, 18, '32GB');

-- RAM 9: Corsair Vengeance 32GB 5600MHz (DDR5, 5600 MHz, 32GB)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(9, 6, 13, 'DDR5'),
(9, 7, 15, '5600 MHz'),
(9, 8, 18, '32GB');

-- PSU 10: Corsair RM850x (80+ Gold, 850W)
INSERT INTO ProductFilterValues (ProductId, FilterId, OptionId, RawValue) VALUES
(10, 9, 21, '80+ Gold'),
(10, 10, 25, '850W');


-- 6. TEST USERS
INSERT INTO Users (Email, PasswordHash, RoleId, FirstName, LastName) VALUES 
('alex@example.com', '$2a$11$VTiQ/daNDOaxA4qPCsFoCu7cjqv0rA/fbpo.gPN9uAx1SbNuKUO2q', 1, 'Alex', 'Doe'),
('customer@pcforge.com', '$2a$11$VTiQ/daNDOaxA4qPCsFoCu7cjqv0rA/fbpo.gPN9uAx1SbNuKUO2q', 1, 'Demo', 'Customer'),
('admin@pcforge.com', '$2a$11$y07hPBpnumthsEP7hMpTheAjvmF4VV9eJO6GB8xWW3qSrhN/O4VN2', 2, 'Store', 'Admin'),
('staff@pcforge.com', '$2a$11$6Cgz1jo8SxaFDOkqF79P6uh7HsgiYH.vO3O0Glul/kvsmwou/CYdG', 3, 'Store', 'Staff'),
('sarah@pcforge.com', '$2a$11$6Cgz1jo8SxaFDOkqF79P6uh7HsgiYH.vO3O0Glul/kvsmwou/CYdG', 3, 'Sarah', 'Jenkins');

-- Sync sequence for auto-incrementing users
SELECT setval('users_userid_seq', (SELECT GREATEST(MAX(UserId), 5) FROM Users));


-- 6b. STAFF PROFILES (Option 2)
INSERT INTO Staff (StaffId, UserId, Department, Phone, Specialization, Status, Notes, JoinedDate) VALUES 
(1, 5, 'Hardware Diagnostics & Repair', '+94 77 123 4567', 'Lead RMA technician for custom build diagnostics and thermal profiling.', 'Active', 'Primary technician for RMA validation.', '2025-01-15');

-- Sync sequence for auto-incrementing staff
SELECT setval('staff_staffid_seq', (SELECT GREATEST(MAX(StaffId), 1) FROM Staff));


-- 7. INITIAL ORDERS (Alex's Purchase from Scenario 2A)
INSERT INTO Orders (OrderId, UserId, TotalAmount, Status, ShippingAddress, PaymentMethod) VALUES
(1001, 1, 749.00, 'Shipped', '42 Palm Grove Ave, Colombo 03', 'Credit Card');

INSERT INTO OrderItems (OrderId, ProductId, Quantity, UnitPrice) VALUES
(1001, 4, 1, 749.00); -- GeForce RTX 4070 Ti 12GB

-- Sync sequence for auto-incrementing orders
SELECT setval('orders_orderid_seq', (SELECT GREATEST(MAX(OrderId), 1001) FROM Orders));


-- 8. INITIAL SUPPORT TICKET (Scenario 3: Alex reports GPU overheating - Ticket #505)
INSERT INTO SupportTickets (TicketId, UserId, OrderId, ProductId, IssueType, Subject, Description, AttachmentUrl, Status, Priority, AssignedStaffId) VALUES
(505, 1, 1001, 4, 'Overheating', 'GPU is overheating', 'The RTX 4070 Ti reaches 95C under load and causes thermal throttling and black screen during gaming.', 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600', 'Open', 'High', 1);

-- Sync sequence for auto-incrementing support tickets
SELECT setval('supporttickets_ticketid_seq', (SELECT GREATEST(MAX(TicketId), 505) FROM SupportTickets));


-- 9. INITIAL CUSTOM PC BUILDS & REVIEWS
INSERT INTO CustomBuilds (BuildId, UserId, BuildName, TotalPrice, EstimatedWattage, Status, CustomerNotes, StaffNotes, AssignedStaffId, CreatedAt) VALUES
(1, 1, 'Alex''s Esports 1440p Battlestation', 1816.00, 490, 'Pending Staff Review', 'Please verify if the 750W PSU has adequate headroom for RTX 4070 Ti transient spikes, and check if the B650 motherboard will require a BIOS update.', NULL, NULL, NOW() - INTERVAL '2 hours'),
(2, 1, 'AM5 Liquid Cooled Workstation', 2846.00, 620, 'In Review by Staff', 'Need high memory bandwidth for 3D simulation rendering. Please confirm top mount 360mm AIO clearance.', 'Under physical inspection by Kasun. Checking radiator clearances in Lian Li chassis.', 1, NOW() - INTERVAL '1 day'),
(3, 1, 'Creator Pro 7950X / RTX 4090', 3895.00, 720, 'Approved by Staff', 'Will be used for 8K video editing and DaVinci Resolve.', 'Thermal profiling passed. 1000W PSU verified with +280W headroom. Cleared for checkout and workshop assembly.', 1, NOW() - INTERVAL '3 days'),
(4, 1, 'Compact ITX Gaming Beast', 1450.00, 480, 'Changes Requested', 'Looking for quiet gaming operation.', 'The chosen 450W power supply is below the 650W manufacturer recommendation for the RTX 4070 Ti. Please adjust PSU to Corsair RM750e.', 1, NOW() - INTERVAL '4 days');

INSERT INTO CustomBuildItems (BuildId, ProductId, SlotType, UnitPrice) VALUES
(1, 6, 'cpu', 449.00),         -- Ryzen 7 7800X3D
(1, 102, 'motherboard', 219.00), -- TUF Gaming B650-Plus WiFi
(1, 201, 'ram', 149.00),         -- Trident Z5 RGB 32GB 6000MHz
(1, 1, 'gpu', 749.00),           -- GeForce RTX 4070 Ti 12GB
(1, 8, 'psu', 99.00),            -- Corsair RM750e 750W
(1, 9, 'storage', 150.00),       -- Samsung 990 PRO 2TB

(2, 5, 'cpu', 699.00),           -- Ryzen 9 7950X
(2, 101, 'motherboard', 699.00), -- ROG Crosshair X670E Hero
(2, 201, 'ram', 149.00),         -- Trident Z5 RGB 32GB
(2, 3, 'gpu', 999.00),           -- Radeon RX 7900 XTX 24GB
(2, 8, 'psu', 150.00),           -- 850W PSU
(2, 9, 'storage', 150.00),

(3, 5, 'cpu', 699.00),           -- Ryzen 9 7950X
(3, 101, 'motherboard', 699.00), -- ROG Crosshair
(3, 201, 'ram', 149.00),         -- Trident Z5
(3, 2, 'gpu', 1599.00),          -- GeForce RTX 4090 24GB
(3, 8, 'psu', 249.00),           -- Seasonic 1000W
(3, 9, 'storage', 499.00),

(4, 7, 'cpu', 589.00),           -- Core i9-13900K
(4, 103, 'motherboard', 199.00), -- MSI MAG B760
(4, 203, 'ram', 49.00),          -- Corsair 16GB
(4, 1, 'gpu', 749.00);           -- RTX 4070 Ti

-- Sync sequence for auto-incrementing custom builds
SELECT setval('custombuilds_buildid_seq', (SELECT GREATEST(MAX(BuildId), 4) FROM CustomBuilds));