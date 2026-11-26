-- =====================================================================
--  G-SMaRT Distribution System - migration: bank payment types with
--  their G.L. accounts, customer checks and the Check Registry (v9)
--
--  What it changes
--    1. Five payment types are renamed to the banks the company is paid
--       through (POS Register, Receive Payments, Enter Sales Receipts):
--         Credit/Debit Card -> BPI
--         Maya              -> Metrobank
--         Gift Voucher      -> EastWest
--         P.O. Card         -> Gotymebank
--         Bank              -> BOC
--       They become bank payment types. Each is linked to the Bank
--       account of the Chart of Accounts whose name carries the bank's
--       name, when exactly one does; otherwise it is left for you to link
--       on Point of Sale > Payment Types & G.L. Accounts (until then its
--       payments go to Undeposited Funds). A type is renamed only when no
--       payment type has the new name yet. Past sales keep their amounts
--       and their entries: they show the new name.
--       Every POS tender already recorded keeps the account it was
--       posted to (a new column, pos_tenders.account_id), so posting a
--       past sale again never moves it to another account.
--    2. A new table, customer_checks: every check received from a
--       customer, at the POS or on Receive Payments, with its bank,
--       number, date and amount. A post-dated check is kept there only
--       ("Receipt of Post Dated Check") until its date, when its payment
--       and journal entries are recorded.
--    3. New pages, given to the roles that already have the pages next
--       to them:
--         Point of Sale > Payment Types & G.L. Accounts (from POS
--             Terminals and Terms, Tax Codes & Other Lists)
--         Customers > Customer Checks (from Receive Payments; Make
--             Deposits may mark checks Cleared or Returned)
--         Customers > Reports > Check Registry and
--         Customers > Reports > Collections by Cashier / User (from the
--             Collections Report, Receive Payments and POS Sales by
--             Cashier & Payment Method)
--    4. A line in the audit trail.
--
--  Nothing is deleted and no amount or quantity changes.
--
--  For an EXISTING G-SMaRT Distribution System database. New installs do not
--  need it: the bundled .sql files and tools/install.php include it.
--  Safe to run more than once. Works on MySQL 5.5.3+ and MariaDB 5.5+.
--
--  How to run (back up the database first):
--    Super Admin > Database updates (runs it on every company), or
--    phpMyAdmin: click the gsmart_distribution database > Import > this file > Go
--    or:         mysql -u root -p gsmart_distribution < 2027_05_03_payment_types_checks.sql
--  Run it on each company database (gsmart_distribution_company_002 ...) too,
--  unless Super Admin > Database updates does it for you.
-- =====================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
--  1. The bank payment types
-- ---------------------------------------------------------------------

-- Each POS tender keeps the account it was posted to, so a sale posted again later (a correction, re-costing)
-- stays on the account it went to, whatever its payment type is linked to by then. The tenders already there get the
-- account they were posted to: the payment type's account, else Card Clearing (E-wallet Clearing for an e-wallet).
-- Cash stays empty: it goes to the cash drawer of the terminal.
SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE pos_tenders ADD COLUMN account_id INT UNSIGNED NULL AFTER reference',
  'SELECT ''pos_tenders: account_id already exists''')
  FROM information_schema.columns
 WHERE table_schema = DATABASE() AND table_name = 'pos_tenders' AND column_name = 'account_id');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @card_clr = (SELECT account_id FROM default_accounts WHERE setting_key = 'card_clearing' LIMIT 1);
SET @ewal_clr = (SELECT account_id FROM default_accounts WHERE setting_key = 'ewallet_clearing' LIMIT 1);
UPDATE pos_tenders pt JOIN payment_methods pm ON pm.id = pt.payment_method_id
   SET pt.account_id = COALESCE(pm.clearing_account_id, IF(pm.method_type = 'ewallet', @ewal_clr, @card_clr))
 WHERE pt.account_id IS NULL AND pm.method_type <> 'cash';

-- the Bank account named after each bank, when exactly one is
SET @gl_bpi   = (SELECT MIN(id) FROM accounts WHERE account_type = 'Bank' AND is_active = 1 AND name LIKE '%BPI%' HAVING COUNT(*) = 1);
SET @gl_metro = (SELECT MIN(id) FROM accounts WHERE account_type = 'Bank' AND is_active = 1 AND name LIKE '%Metrobank%' HAVING COUNT(*) = 1);
SET @gl_ew    = (SELECT MIN(id) FROM accounts WHERE account_type = 'Bank' AND is_active = 1 AND (name LIKE '%EastWest%' OR name LIKE '%East West%') HAVING COUNT(*) = 1);
SET @gl_gt    = (SELECT MIN(id) FROM accounts WHERE account_type = 'Bank' AND is_active = 1 AND name LIKE '%GoTyme%' HAVING COUNT(*) = 1);
SET @gl_boc   = (SELECT MIN(id) FROM accounts WHERE account_type = 'Bank' AND is_active = 1 AND (name LIKE '%BOC%' OR name LIKE '%Bank of Commerce%') HAVING COUNT(*) = 1);

-- (the count of the new name is read through a derived table: MySQL 5.5 cannot read the table it updates otherwise)
UPDATE payment_methods SET name = 'BPI', method_type = 'bank_transfer', clearing_account_id = @gl_bpi
 WHERE name = 'Credit/Debit Card' AND 0 = (SELECT n FROM (SELECT COUNT(*) AS n FROM payment_methods WHERE name = 'BPI') x);
UPDATE payment_methods SET name = 'Metrobank', method_type = 'bank_transfer', clearing_account_id = @gl_metro
 WHERE name = 'Maya' AND 0 = (SELECT n FROM (SELECT COUNT(*) AS n FROM payment_methods WHERE name = 'Metrobank') x);
UPDATE payment_methods SET name = 'EastWest', method_type = 'bank_transfer', clearing_account_id = @gl_ew
 WHERE name = 'Gift Voucher' AND 0 = (SELECT n FROM (SELECT COUNT(*) AS n FROM payment_methods WHERE name = 'EastWest') x);
UPDATE payment_methods SET name = 'Gotymebank', method_type = 'bank_transfer', clearing_account_id = @gl_gt
 WHERE name = 'P.O. Card' AND 0 = (SELECT n FROM (SELECT COUNT(*) AS n FROM payment_methods WHERE name = 'Gotymebank') x);
UPDATE payment_methods SET name = 'BOC', method_type = 'bank_transfer', clearing_account_id = @gl_boc
 WHERE name = 'Bank' AND 0 = (SELECT n FROM (SELECT COUNT(*) AS n FROM payment_methods WHERE name = 'BOC') x);

-- ---------------------------------------------------------------------
--  2. The checks received from customers
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS customer_checks (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_id       INT UNSIGNED NOT NULL,
  payment_txn_id    BIGINT UNSIGNED NULL,
  source            VARCHAR(10)  NOT NULL DEFAULT 'payment',
  terminal_id       INT UNSIGNED NULL,
  pos_shift_id      INT UNSIGNED NULL,
  site_id           INT UNSIGNED NULL,
  bank              VARCHAR(80)  NOT NULL,
  check_no          VARCHAR(40)  NOT NULL,
  check_date        DATE         NOT NULL,
  amount            DECIMAL(15,2) NOT NULL DEFAULT 0,
  received_date     DATE         NOT NULL,
  status            VARCHAR(12)  NOT NULL DEFAULT 'pending',
  payment_method_id INT UNSIGNED NULL,
  account_id        INT UNSIGNED NULL,
  class_id          INT UNSIGNED NULL,
  memo              VARCHAR(255) NULL,
  apply_json        TEXT         NULL,
  recorded_at       DATETIME     NULL,
  cleared_date      DATE         NULL,
  returned_date     DATE         NULL,
  return_txn_id     BIGINT UNSIGNED NULL,
  status_note       VARCHAR(255) NULL,
  status_by         INT UNSIGNED NULL,
  created_by        INT UNSIGNED NULL,
  created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cc_customer (customer_id),
  KEY ix_cc_payment (payment_txn_id),
  KEY ix_cc_status (status, check_date),
  KEY ix_cc_shift (pos_shift_id),
  KEY ix_cc_received (received_date),
  KEY ix_cc_check (bank, check_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  3. The pages and who may open them
-- ---------------------------------------------------------------------

SET @pos_mod  = (SELECT module_id FROM pages WHERE page_key = 'pos.terminals' LIMIT 1);
SET @cust_mod = (SELECT module_id FROM pages WHERE page_key = 'cust.payments' LIMIT 1);
SET @term_sort = (SELECT sort_order FROM pages WHERE page_key = 'pos.terminals' LIMIT 1);
SET @pay_sort  = (SELECT sort_order FROM pages WHERE page_key = 'cust.payments' LIMIT 1);
SET @col_sort  = (SELECT sort_order FROM pages WHERE page_key = 'rpt.collections' LIMIT 1);

INSERT IGNORE INTO pages (page_key, module_id, name, page_type, menu_group, sort_order, show_in_menu) VALUES
  ('pos.payment_types',       @pos_mod,  'Payment Types & G.L. Accounts', 'setup',  'Setup',                            COALESCE(@term_sort, 2280) + 3, 1),
  ('cust.checks',             @cust_mod, 'Customer Checks',               'center', 'Transactions',                     COALESCE(@pay_sort, 1010) + 3, 1),
  ('rpt.check_registry',      @cust_mod, 'Check Registry',                'report', 'Customer and Receivables Reports', COALESCE(@col_sort, 1080) + 3, 1),
  ('rpt.cashier_collections', @cust_mod, 'Collections by Cashier / User', 'report', 'Customer and Receivables Reports', COALESCE(@col_sort, 1080) + 6, 1);

-- Payment Types & G.L. Accounts: whoever sets up the POS terminals or keeps the lists of payment types
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, MAX(src.can_create), MAX(src.can_edit), 0, MAX(src.can_print), 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key IN ('pos.terminals', 'coa.lists')
  JOIN pages dst ON dst.page_key = 'pos.payment_types'
 WHERE src.allowed = 1
 GROUP BY src.role_id, dst.id;

-- Customer Checks: whoever receives payments; whoever makes bank deposits may also mark checks Cleared or Returned
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1,
       MAX(IF(sp.page_key = 'cust.payments', src.can_create, 0)), MAX(src.can_edit), MAX(IF(sp.page_key = 'cust.payments', src.can_delete, 0)),
       MAX(src.can_print), MAX(IF(sp.page_key = 'cust.payments', src.can_approve, 0))
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key IN ('cust.payments', 'bank.deposits')
  JOIN pages dst ON dst.page_key = 'cust.checks'
 WHERE src.allowed = 1
 GROUP BY src.role_id, dst.id;

-- the two reports: whoever reads the Collections Report or the cashiers' report, or receives payments
INSERT IGNORE INTO role_page_access (role_id, page_id, allowed, can_create, can_edit, can_delete, can_print, can_approve)
SELECT src.role_id, dst.id, 1, 0, 0, 0, MAX(src.can_print), 0
  FROM role_page_access src
  JOIN pages sp  ON sp.id = src.page_id AND sp.page_key IN ('rpt.collections', 'cust.payments', 'rpt.pos_sales_cashier')
  JOIN pages dst ON dst.page_key IN ('rpt.check_registry', 'rpt.cashier_collections')
 WHERE src.allowed = 1
 GROUP BY src.role_id, dst.id;

-- ---------------------------------------------------------------------
--  4. Record the change in the audit trail
-- ---------------------------------------------------------------------

INSERT INTO audit_trail (username, user_roles, ip_address, workstation, module, page_key, action, record_type, record_ref, reason)
VALUES ('system', 'Database migration', '127.0.0.1', 'SQL migration', 'admin', 'admin.page_access', 'access_change', 'page',
        'Payment types and checks',
        'Migration 2027_05_03: payment types BPI, Metrobank, EastWest, Gotymebank, BOC; Payment Types & G.L. Accounts; Customer Checks; Check Registry; Collections by Cashier / User');

-- Done. Link each payment type to its account on Point of Sale > Payment Types & G.L. Accounts.
