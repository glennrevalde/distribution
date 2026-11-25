-- =====================================================================
--  G-SMaRT Distribution System - migration: Dispatch Inventory and
--  Convert Kilos to Crates (v4)
--
--  What it changes
--    1. Number series DSP- for the dispatches (Inventory Dispatch).
--    2. Two pages, given to the roles that already have the pages they follow:
--         Inventory > Dispatch Inventory        (as Transfer Inventory)
--         Inventory > Convert Kilos to Crates   (as Convert Crates to Kilos)
--    3. A line in the audit trail.
--
--  No table or column is added: a dispatch is kept as a transaction of type
--  inventory_dispatch, and a crate filled from loose stock is a crate like
--  any other, with a movement of kind 'pack' (crate_movements.kind is a
--  VARCHAR(10)). Nothing is deleted and no amount or quantity changes.
--
--  For an EXISTING G-SMaRT Distribution System database. New installs do not
--  need it: the bundled .sql files and tools/install.php include it.
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    Super Admin > Database updates (runs it on every company), or
--    phpMyAdmin: click the gsmart_distribution database > Import > this file > Go
--    or:         mysql -u root -p gsmart_distribution < 2027_03_22_dispatch_inventory.sql
--  Run it on each company database (gsmart_distribution_company_002 ...) too,
--  unless Super Admin > Database updates does it for you.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. Number series
-- ---------------------------------------------------------------------

INSERT IGNORE INTO sequences (seq_key, prefix, next_no, pad) VALUES ('inv_dispatch', 'DSP-', 1, 5);

-- ---------------------------------------------------------------------
--  2. Pages and access
-- ---------------------------------------------------------------------

SET @inv_mod  = (SELECT module_id FROM pages WHERE page_key = 'inv.transfers' LIMIT 1);
SET @tr_sort  = (SELECT sort_order FROM pages WHERE page_key = 'inv.transfers' LIMIT 1);
SET @cv_sort  = (SELECT sort_order FROM pages WHERE page_key = 'inv.crate_convert' LIMIT 1);

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('inv.dispatch',   @inv_mod, 'Dispatch Inventory',      'transaction', 'Transactions', COALESCE(@tr_sort, 1280) + 5, 1),
  ('inv.crate_pack', @inv_mod, 'Convert Kilos to Crates', 'transaction', 'Crates',       COALESCE(@cv_sort, 1380) + 5, 1);

-- the roles that transfer inventory dispatch it too (the same rights)
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, src.can_create, src.can_edit, src.can_delete, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'inv.transfers'
  JOIN pages dst ON dst.page_key = 'inv.dispatch'
 WHERE src.allowed = 1;

-- the roles that convert crates to kilos convert kilos to crates too
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, src.can_create, src.can_edit, src.can_delete, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'inv.crate_convert'
  JOIN pages dst ON dst.page_key = 'inv.crate_pack'
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  3. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Dispatch Inventory',
        'Migration 2027_03_22: Dispatch Inventory (number series DSP-) and Convert Kilos to Crates');

-- Done. Dispatch Inventory is under Inventory > Transactions, next to Transfer Inventory,
-- and Convert Kilos to Crates under Inventory > Crates.
