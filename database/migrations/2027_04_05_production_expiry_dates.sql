-- =====================================================================
--  G-SMaRT Distribution System - migration: Production and Expiry Dates (v5)
--
--  What it changes
--    1. One page, Inventory > Production and Expiry Dates: the check of the
--       production and expiry dates of the stock, site by site (what has no
--       dates and which documents brought it in, and whether each date group
--       holds what its crates hold), with the date changes that put it right.
--       It is given to the roles that already have Adjust Quantity/Value on
--       Hand, with the same rights to add (a date change is an adjustment).
--    2. A line in the audit trail.
--
--  No table or column is added: a date change is an inventory adjustment
--  marked in transactions.received_via ('date_change'). Nothing is deleted
--  and no amount or quantity changes. The stock already on file is not
--  touched by this script: open the new page to see what to put right.
--
--  For an EXISTING G-SMaRT Distribution System database. New installs do not
--  need it: the bundled .sql files and tools/install.php include it.
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    Super Admin > Database updates (runs it on every company), or
--    phpMyAdmin: click the gsmart_distribution database > Import > this file > Go
--    or:         mysql -u root -p gsmart_distribution < 2027_04_05_production_expiry_dates.sql
--  Run it on each company database (gsmart_distribution_company_002 ...) too,
--  unless Super Admin > Database updates does it for you.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. The page and who may use it
-- ---------------------------------------------------------------------

SET @inv_mod = (SELECT module_id FROM pages WHERE page_key = 'inv.adjust' LIMIT 1);
SET @pc_sort = (SELECT sort_order FROM pages WHERE page_key = 'inv.physical_count' LIMIT 1);

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('inv.lot_check', @inv_mod, 'Production and Expiry Dates', 'transaction', 'Transactions', COALESCE(@pc_sort, 1350) + 5, 1);

-- the roles that adjust inventory check its dates too (adding a date change is adding an adjustment)
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, src.can_create, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'inv.adjust'
  JOIN pages dst ON dst.page_key = 'inv.lot_check'
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  2. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Production and Expiry Dates',
        'Migration 2027_04_05: Inventory > Production and Expiry Dates (date check and date changes)');

-- Done. Open Inventory > Production and Expiry Dates to see the stock without dates
-- and the crates whose dates the stock does not carry.
