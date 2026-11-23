-- =====================================================================
--  G-SMaRT Distribution System - migration: Inventory Transfer Closing,
--  shortages and shrinkage, crate transfers (v2)
--
--  What it changes
--    1. sales_reps: rep_type (sales_rep, van = van salesman, cashier) and
--       customer_id (the employee as a customer: shortages are charged to
--       them and collected with Receive Payments).
--    2. sites: sales_rep_id, the van salesman or cashier answerable for the
--       site's stock.
--    3. Two new tables: transfer_closings and transfer_closing_lines.
--    4. Account 1120 Shortage Receivable - Employees (Accounts Receivable)
--       and the module default account "Shortage Receivable (Employees)".
--    5. Customer type "Employee"; number series TC- (closings) and SHC-
--       (shortage charges).
--    6. Pages, given to the roles that already have the pages they follow:
--         Inventory > Inventory Transfer Closing   (as Transfer Inventory)
--         Inventory > Shortage Charges             (as Transfer Inventory,
--                                                  and view for the roles
--                                                  that receive payments)
--         Inventory Reports > Shortage and Shrinkage Reports (7 reports,
--                                                  as Inventory Valuation Summary)
--    7. A line in the audit trail.
--
--  Nothing is deleted and no amount or quantity changes.
--
--  For an EXISTING G-SMaRT Distribution System database (installed from the
--  first release). New installs do not need it: the bundled .sql files and
--  tools/install.php include it. Safe to run more than once.
--  Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    Super Admin > Database updates (runs it on every company), or
--    phpMyAdmin: click the gsmart_distribution database > Import > this file > Go
--    or:         mysql -u root -p gsmart_distribution < 2027_03_08_van_closing_shortages.sql
--  Run it on each company database (gsmart_distribution_company_002 ...) too,
--  unless Super Admin > Database updates does it for you.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. Sales representatives, van salesmen and cashiers
-- ---------------------------------------------------------------------

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE sales_reps ADD COLUMN rep_type VARCHAR(12) NOT NULL DEFAULT ''sales_rep'' AFTER commission_pct, ADD COLUMN customer_id INT UNSIGNED NULL AFTER rep_type, ADD KEY ix_rep_customer (customer_id)',
  'SELECT ''sales_reps: rep_type and customer_id already exist''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'sales_reps' AND column_name = 'rep_type');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------------------------------------------------------------------
--  2. Sites
-- ---------------------------------------------------------------------

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE sites ADD COLUMN sales_rep_id INT UNSIGNED NULL AFTER address',
  'SELECT ''sites: sales_rep_id already exists''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'sites' AND column_name = 'sales_rep_id');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ---------------------------------------------------------------------
--  3. Inventory Transfer Closing
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS transfer_closings (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  closing_no          VARCHAR(30)  NOT NULL,
  closing_date        DATE         NOT NULL,
  from_site_id        INT UNSIGNED NOT NULL,
  to_site_id          INT UNSIGNED NOT NULL,
  sales_rep_id        INT UNSIGNED NULL,
  customer_id         INT UNSIGNED NULL,
  shrink_account_id   INT UNSIGNED NULL,
  shortage_account_id INT UNSIGNED NULL,
  transferred_by      VARCHAR(80)  NULL,
  checked_by          VARCHAR(80)  NULL,
  received_by         VARCHAR(80)  NULL,
  memo                VARCHAR(255) NULL,
  transfer_txn_id     BIGINT UNSIGNED NULL,
  shrink_txn_id       BIGINT UNSIGNED NULL,
  shortage_txn_id     BIGINT UNSIGNED NULL,
  balance_qty         DECIMAL(15,4) NOT NULL DEFAULT 0,
  transfer_qty        DECIMAL(15,4) NOT NULL DEFAULT 0,
  shrink_qty          DECIMAL(15,4) NOT NULL DEFAULT 0,
  shortage_qty        DECIMAL(15,4) NOT NULL DEFAULT 0,
  shrink_amount       DECIMAL(15,2) NOT NULL DEFAULT 0,
  shortage_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,
  status              VARCHAR(10)  NOT NULL DEFAULT 'posted',
  void_reason         VARCHAR(255) NULL,
  voided_by           INT UNSIGNED NULL,
  voided_at           DATETIME     NULL,
  created_by          INT UNSIGNED NULL,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tc_no (closing_no),
  KEY ix_tc_date (closing_date),
  KEY ix_tc_from (from_site_id, closing_date),
  KEY ix_tc_rep (sales_rep_id),
  KEY ix_tc_transfer (transfer_txn_id),
  KEY ix_tc_shrink (shrink_txn_id),
  KEY ix_tc_shortage (shortage_txn_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS transfer_closing_lines (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  closing_id   INT UNSIGNED NOT NULL,
  line_no      INT          NOT NULL DEFAULT 0,
  item_id      INT UNSIGNED NOT NULL,
  crate_id     BIGINT UNSIGNED NULL,
  crate_no     VARCHAR(30)  NULL,
  unit         VARCHAR(20)  NULL,
  balance      DECIMAL(15,4) NOT NULL DEFAULT 0,
  transfer_qty DECIMAL(15,4) NOT NULL DEFAULT 0,
  shrink_qty   DECIMAL(15,4) NOT NULL DEFAULT 0,
  shortage_qty DECIMAL(15,4) NOT NULL DEFAULT 0,
  unit_cost    DECIMAL(15,4) NOT NULL DEFAULT 0,
  note         VARCHAR(255) NULL,
  KEY ix_tcl_closing (closing_id),
  KEY ix_tcl_item (item_id),
  KEY ix_tcl_crate (crate_id),
  CONSTRAINT fk_tcl_closing FOREIGN KEY (closing_id) REFERENCES transfer_closings(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  4. The Shortage Receivable account and its module default
--     (code 1120, or 1121 ... when 1120 is already used by another account)
-- ---------------------------------------------------------------------

SET @have = (SELECT id FROM accounts WHERE name = 'Shortage Receivable - Employees' LIMIT 1);
SET @code = (SELECT CASE
    WHEN NOT EXISTS (SELECT 1 FROM accounts WHERE code = '1120') THEN '1120'
    WHEN NOT EXISTS (SELECT 1 FROM accounts WHERE code = '1121') THEN '1121'
    WHEN NOT EXISTS (SELECT 1 FROM accounts WHERE code = '1122') THEN '1122'
    ELSE CONCAT('1120-', FLOOR(RAND() * 900 + 100)) END);
INSERT INTO accounts (code, name, account_type, category, normal_balance, description, is_active, is_system)
SELECT @code, 'Shortage Receivable - Employees', 'Accounts Receivable', 'Asset', 'Debit',
       'Stock short at vans and outlets, charged at cost to the employee answerable for it', 1, 0
  FROM DUAL WHERE @have IS NULL;
SET @acct = (SELECT id FROM accounts WHERE name = 'Shortage Receivable - Employees' ORDER BY id LIMIT 1);

INSERT IGNORE INTO default_accounts (setting_key, label, module, account_id)
VALUES ('shortage_receivable', 'Shortage Receivable (Employees)', 'inv', @acct);
UPDATE default_accounts SET account_id = @acct WHERE setting_key = 'shortage_receivable' AND account_id IS NULL;

-- ---------------------------------------------------------------------
--  5. Customer type and number series
-- ---------------------------------------------------------------------

INSERT INTO customer_types (name) SELECT 'Employee' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM customer_types WHERE name = 'Employee');

INSERT IGNORE INTO sequences (seq_key, prefix, next_no, pad) VALUES
  ('transfer_closing', 'TC-', 1, 5),
  ('shortage', 'SHC-', 1, 5);

-- ---------------------------------------------------------------------
--  6. Pages and access
-- ---------------------------------------------------------------------

SET @inv_mod  = (SELECT module_id FROM pages WHERE page_key = 'inv.transfers' LIMIT 1);
SET @tr_sort  = (SELECT sort_order FROM pages WHERE page_key = 'inv.transfers' LIMIT 1);
SET @rp_sort  = (SELECT COALESCE(MAX(sort_order), 3000) FROM pages WHERE page_key IN ('rpt.crates_received', 'rpt.inv_valuation_detail'));

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('inv.transfer_closing', @inv_mod, 'Inventory Transfer Closing', 'transaction', 'Transactions', @tr_sort + 1, 1),
  ('inv.shortages',        @inv_mod, 'Shortage Charges',           'transaction', 'Transactions', @tr_sort + 2, 1),
  ('rpt.closing_register', @inv_mod, 'Inventory Transfer Closing Register', 'report', 'Shortage and Shrinkage Reports', @rp_sort + 1, 1),
  ('rpt.shortage_item',    @inv_mod, 'Shortages by Item',                   'report', 'Shortage and Shrinkage Reports', @rp_sort + 2, 1),
  ('rpt.shortage_site',    @inv_mod, 'Shortages by Site',                   'report', 'Shortage and Shrinkage Reports', @rp_sort + 3, 1),
  ('rpt.shortage_rep',     @inv_mod, 'Shortages by Sales Representative',   'report', 'Shortage and Shrinkage Reports', @rp_sort + 4, 1),
  ('rpt.shortage_detail',  @inv_mod, 'Shortage Detail',                     'report', 'Shortage and Shrinkage Reports', @rp_sort + 5, 1),
  ('rpt.shrinkage_item',   @inv_mod, 'Shrinkage by Item',                   'report', 'Shortage and Shrinkage Reports', @rp_sort + 6, 1),
  ('rpt.shrinkage_detail', @inv_mod, 'Shrinkage Detail',                    'report', 'Shortage and Shrinkage Reports', @rp_sort + 7, 1);

-- the roles that transfer inventory close vans and see the shortage charges
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, src.can_create, 0, src.can_delete, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'inv.transfers'
  JOIN pages dst ON dst.page_key = 'inv.transfer_closing'
 WHERE src.allowed = 1;
-- the roles that see the inventory adjustments see the closings too (view and print only)
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key = 'inv.adjust'
  JOIN pages dst ON dst.page_key = 'inv.transfer_closing'
 WHERE src.allowed = 1;
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, src.can_delete, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key IN ('inv.transfers', 'cust.payments')
  JOIN pages dst ON dst.page_key = 'inv.shortages'
 WHERE src.allowed = 1;
-- the roles that see the inventory valuation see the shortage and shrinkage reports
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, src.can_print, 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key IN ('rpt.inv_valuation_summary', 'rpt.crates_on_hand')
  JOIN pages dst ON dst.page_key IN ('rpt.closing_register', 'rpt.shortage_item', 'rpt.shortage_site', 'rpt.shortage_rep',
                                     'rpt.shortage_detail', 'rpt.shrinkage_item', 'rpt.shrinkage_detail')
 WHERE src.allowed = 1;

-- ---------------------------------------------------------------------
--  7. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Inventory Transfer Closing',
        'Migration 2027_03_08: Inventory Transfer Closing, Shortage Charges, shortage and shrinkage reports, van salesmen and cashiers on the sales representatives list, the Shortage Receivable account');

-- Done. Next steps in the application:
--   Customers > Terms, Tax Codes & Other Lists > Sales representatives: set the Kind of each person (van salesman, cashier).
--   Inventory > Inventory Site List: set the van salesman or cashier answerable for each van store and outlet.
