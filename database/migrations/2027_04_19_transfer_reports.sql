-- =====================================================================
--  G-SMaRT Distribution System - migration: dispatch from many sites,
--  Transfer Reports (v8)
--
--  What it changes
--    1. Two reports under Inventory > Transfer Reports:
--         Transfers by Item Code  - the stock sent by Transfer Inventory
--                                   and Dispatch Inventory, grouped by item
--                                   code, a subtotal per item code;
--         Transfers by Site       - the same, grouped by the site the stock
--                                   left, a subtotal per site.
--       Both show the production and expiry dates each line went with.
--       They are given to the roles that already have Transfer Inventory,
--       Dispatch Inventory or the Inventory Movement Summary report.
--    2. A line in the audit trail.
--
--  No table or column is added: a dispatch from many sites keeps the site
--  each line leaves from in transaction_lines.site_id (already there), and
--  the site markers follow each site's id. Nothing is deleted and no
--  amount or quantity changes.
--
--  For an EXISTING G-SMaRT Distribution System database. New installs do not
--  need it: the bundled .sql files and tools/install.php include it.
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    Super Admin > Database updates (runs it on every company), or
--    phpMyAdmin: click the gsmart_distribution database > Import > this file > Go
--    or:         mysql -u root -p gsmart_distribution < 2027_04_19_transfer_reports.sql
--  Run it on each company database (gsmart_distribution_company_002 ...) too,
--  unless Super Admin > Database updates does it for you.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. The reports and who may run them
-- ---------------------------------------------------------------------

SET @inv_mod = (SELECT module_id FROM pages WHERE page_key = 'inv.transfers' LIMIT 1);
SET @sd_sort = (SELECT sort_order FROM pages WHERE page_key = 'rpt.shrinkage_detail' LIMIT 1);

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('rpt.transfer_item', @inv_mod, 'Transfers by Item Code', 'report', 'Transfer Reports', COALESCE(@sd_sort, 1550) + 3, 1),
  ('rpt.transfer_site', @inv_mod, 'Transfers by Site',      'report', 'Transfer Reports', COALESCE(@sd_sort, 1550) + 6, 1);

-- the roles that move stock between sites, or read the inventory movement reports
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, MAX(src.can_print), 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key IN ('inv.transfers', 'inv.dispatch', 'rpt.inv_movement_summary')
  JOIN pages dst ON dst.page_key IN ('rpt.transfer_item', 'rpt.transfer_site')
 WHERE src.allowed = 1
 GROUP BY src.role_id, dst.id;

-- ---------------------------------------------------------------------
--  2. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Transfer Reports',
        'Migration 2027_04_19: Inventory > Transfer Reports (Transfers by Item Code, Transfers by Site); Dispatch Inventory from many sites');

-- Done. Dispatch Inventory now takes stock from one site or several (From sites),
-- and Inventory > Transfer Reports lists what was sent, by item code or by site.
