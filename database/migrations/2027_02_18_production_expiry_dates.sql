-- =====================================================================
--  G-SMaRT Distribution System - migration: Production and Expiry Dates (v43)
--
--  What it changes
--    1. transaction_lines: production_date and expiry_date, the dates of the
--       stock a line brings in (receipts, bills, checks, returns, adjustments,
--       builds, processing outputs) or the date group it takes out (sales, POS,
--       supplier debit memos, adjustments down, transfers). Empty on every
--       existing line.
--    2. inventory_movements: the same two dates on every movement, so the
--       quantity on hand is known by item, site and date group. Existing
--       movements have none ("No dates"). Two indexes for the look-ups.
--    3. items: track_expiry (1 = this item has production and expiry dates when
--       the company tracks them; 0 = it does not expire). 1 for every item.
--    4. Three settings: track_expiry (off), expiry_warn_days (30) and
--       block_expired_sales (off).
--    5. Two reports for the roles that may open Inventory Valuation Summary:
--         Inventory Reports > Expiring and Expired Items
--         Inventory Reports > Stock by Production and Expiry Date
--    6. A line in the audit trail.
--
--  Nothing is deleted and no amount or quantity changes. Tracking stays off
--  until it is switched on in System Administration > Company, Security &
--  Closing Date > Inventory and POS.
--
--  For an EXISTING database that already has the earlier migrations.
--  New installs do not need it (tools/install.php and the bundled dumps include it).
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    phpMyAdmin: click the accounting_system database > Import > choose this file > Go
--    Navicat:    right-click the accounting_system database > Execute SQL File
--    or:         mysql -u root -p accounting_system < 2027_02_18_production_expiry_dates.sql
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. Transaction lines
-- ---------------------------------------------------------------------

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE transaction_lines ADD COLUMN production_date DATE NULL AFTER site_id, ADD COLUMN expiry_date DATE NULL AFTER production_date',
  'SELECT ''transaction_lines: production and expiry dates already exist''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'transaction_lines' AND column_name = 'production_date');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------------------------------------------------------------------
--  2. Inventory movements
-- ---------------------------------------------------------------------

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE inventory_movements ADD COLUMN production_date DATE NULL AFTER site_id, ADD COLUMN expiry_date DATE NULL AFTER production_date, ADD KEY ix_im_lot (item_id, site_id, expiry_date, production_date), ADD KEY ix_im_expiry (expiry_date)',
  'SELECT ''inventory_movements: production and expiry dates already exist''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'inventory_movements' AND column_name = 'production_date');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------------------------------------------------------------------
--  3. Items
-- ---------------------------------------------------------------------

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE items ADD COLUMN track_expiry TINYINT(1) NOT NULL DEFAULT 1 AFTER max_stock',
  'SELECT ''items: track_expiry already exists''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'items' AND column_name = 'track_expiry');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------------------------------------------------------------------
--  4. Settings (tracking starts switched off)
-- ---------------------------------------------------------------------

INSERT IGNORE INTO settings (setting_key, setting_value) VALUES
  ('track_expiry', '0'),
  ('expiry_warn_days', '30'),
  ('block_expired_sales', '0');

-- ---------------------------------------------------------------------
--  5. The two reports
-- ---------------------------------------------------------------------

SET @ex_mod  = (SELECT module_id FROM pages WHERE page_key = 'rpt.inv_valuation_summary' LIMIT 1);
SET @ex_sort = (SELECT COALESCE(MAX(sort_order), 3000) FROM pages WHERE page_key = 'rpt.inv_valuation_detail');

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('rpt.expiring_items', @ex_mod, 'Expiring and Expired Items',          'report', 'Inventory Reports', @ex_sort + 2, 1),
  ('rpt.stock_by_lot',   @ex_mod, 'Stock by Production and Expiry Date', 'report', 'Inventory Reports', @ex_sort + 3, 1);

INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'rpt.inv_valuation_summary'
  JOIN pages dst ON dst.page_key IN ('rpt.expiring_items', 'rpt.stock_by_lot')
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  6. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Production and expiry dates',
        'Migration 2027_02_18: production and expiry dates on transaction lines and inventory movements, track_expiry on items, three settings, and the reports Expiring and Expired Items and Stock by Production and Expiry Date');

-- Done. Next steps in the application:
--   System Administration > Company, Security & Closing Date > Inventory and POS:
--   tick "Track inventory production date and expiry date" and save.
