-- ============================================================================
-- PCForge Database Backup & Data Cleanup Script
-- ============================================================================
-- IMPORTANT:
-- 1. Take a backup of your database BEFORE executing this script.
--    If using pg_dump:
--      pg_dump "postgresql://neondb_owner:npg_KwDO1JiBdWH2@ep-odd-sea-ae7yb03x-pooler.c-2.us-east-2.aws.neon.tech/pcforge_db?sslmode=require" -F p -f pcforge_backup.sql
--    Or create a branch/snapshot in your Neon Console.
--
-- 2. Run this script manually in your PostgreSQL query editor (psql, DBeaver, or Neon SQL Editor).
-- ============================================================================

BEGIN;

-- 1. Schema Migration: Update Orders status default & Ensure Master Filters tables exist
ALTER TABLE Orders ALTER COLUMN Status SET DEFAULT 'Order placed';
ALTER TABLE products ADD COLUMN IF NOT EXISTS warrantymonths INT NOT NULL DEFAULT 36;
ALTER TABLE products ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'Active';

CREATE TABLE IF NOT EXISTS filters (
    filterid SERIAL PRIMARY KEY,
    filterkey VARCHAR(50) UNIQUE NOT NULL,
    displayname VARCHAR(100) NOT NULL,
    filtertype VARCHAR(30) NOT NULL DEFAULT 'multiselect',
    unit VARCHAR(20) NULL,
    createdat TIMESTAMPTZ DEFAULT NOW(),
    updatedat TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS master_filter_options (
    optionid SERIAL PRIMARY KEY,
    filterid INT NOT NULL REFERENCES filters(filterid) ON DELETE CASCADE,
    optionvalue VARCHAR(100) NOT NULL,
    displayorder INT DEFAULT 0,
    CONSTRAINT uq_master_filter_option UNIQUE(filterid, optionvalue)
);

ALTER TABLE categoryfilters ADD COLUMN IF NOT EXISTS masterfilterid INT NULL REFERENCES filters(filterid) ON DELETE SET NULL;

-- Migrate existing categoryfilters into master filters
INSERT INTO filters (filterkey, displayname, filtertype, unit, createdat)
SELECT DISTINCT ON (LOWER(filterkey))
    LOWER(filterkey), displayname, filtertype, unit, NOW()
FROM categoryfilters
WHERE NOT EXISTS (SELECT 1 FROM filters WHERE LOWER(filters.filterkey) = LOWER(categoryfilters.filterkey));

-- Migrate existing options into master_filter_options
INSERT INTO master_filter_options (filterid, optionvalue, displayorder)
SELECT DISTINCT f.filterid, fo.optionvalue, fo.displayorder
FROM filteroptions fo
JOIN categoryfilters cf ON fo.filterid = cf.filterid
JOIN filters f ON LOWER(f.filterkey) = LOWER(cf.filterkey)
ON CONFLICT (filterid, optionvalue) DO NOTHING;

-- 2. Data Cleanup: Delete child rows first, then parent rows

-- Child rows of Orders
DELETE FROM OrderItems;

-- Service Requests and Support Tickets (referencing Orders and Products)
DELETE FROM ServiceRequests;
DELETE FROM SupportTickets;

-- Child rows of Custom Builds
DELETE FROM CustomBuildItems;

-- Parent rows
DELETE FROM CustomBuilds;
DELETE FROM Orders;

-- Optional: Reset auto-increment sequences for cleaned tables
ALTER SEQUENCE IF EXISTS orderitems_orderitemid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS orders_orderid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS custombuilditems_builditemid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS custombuilds_buildid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS servicerequests_servicerequestid_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS supporttickets_ticketid_seq RESTART WITH 1;

COMMIT;

-- Verification Queries
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM Orders
UNION ALL
SELECT 'orderitems', COUNT(*) FROM OrderItems
UNION ALL
SELECT 'custombuilds', COUNT(*) FROM CustomBuilds
UNION ALL
SELECT 'custombuilditems', COUNT(*) FROM CustomBuildItems
UNION ALL
SELECT 'servicerequests', COUNT(*) FROM ServiceRequests
UNION ALL
SELECT 'supporttickets', COUNT(*) FROM SupportTickets;
