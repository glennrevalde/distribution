-- =====================================================================
--  G-SMaRT Distribution System - clean database (setup lists and users, no transactions)
--  Generated 2026-11-27 00:03:04 +08:00 from database `gsmart_distribution`
--  110 tables, 1282 rows (0 transactions)
--
--  Import:  phpMyAdmin > Import > choose this file > Go
--      or:  mysql -u root -p < gsmart_distribution_sample.sql
--  Works on MySQL 5.5.3 or newer (5.5, 5.6, 5.7, 8.x) and MariaDB 5.5 or newer.
--  Import as root (or a user with CREATE, INSERT, REFERENCES and TRIGGER privileges).
--  WARNING: importing drops and recreates every table in the database below.
--
--  Default login: admin / Admin@12345 (a new password is required at first login)
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
SET time_zone = '+08:00';

CREATE DATABASE IF NOT EXISTS `gsmart_distribution` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `gsmart_distribution`;

-- ---------------------------------------------------------------------
--  1. TABLES
-- ---------------------------------------------------------------------
-- =====================================================================
--  G-SMaRT Distribution System - database schema (company database)
--  MySQL 5.5.3+ / 5.6 / 5.7 / 8.x and MariaDB 5.5+ (XAMPP / WAMP / Laragon)
--  MySQL 5.5 rules followed here: only TIMESTAMP columns default to
--  CURRENT_TIMESTAMP (one per table), indexed text columns stay within
--  767 bytes (utf8mb4), and foreign key columns match exactly.
-- =====================================================================


-- ---------------------------------------------------------------------
--  SYSTEM ADMINISTRATION AND SECURITY
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS settings;
CREATE TABLE settings (
  setting_key   VARCHAR(60)  NOT NULL PRIMARY KEY,
  setting_value TEXT         NULL,
  updated_at    TIMESTAMP    NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username             VARCHAR(50)  NOT NULL,
  password_hash        VARCHAR(255) NOT NULL,
  full_name            VARCHAR(120) NOT NULL,
  email                VARCHAR(120) NULL,
  employee_no          VARCHAR(30)  NULL,
  pos_default_site_id  INT UNSIGNED NULL,                 -- the site this user's POS Register opens on
  pos_default_class_id INT UNSIGNED NULL,                 -- the class every new sale of theirs starts with
  status               ENUM('active','inactive','locked') NOT NULL DEFAULT 'active',
  approval_status      VARCHAR(10)  NOT NULL DEFAULT 'approved',  -- approved / pending / rejected (joined with the Company Code)
  created_via          VARCHAR(12)  NOT NULL DEFAULT 'admin',     -- admin / registration / provisioning / setup / platform
  approved_by          INT UNSIGNED NULL,                         -- who approved or rejected the registration
  approved_at          DATETIME     NULL,
  rejected_reason      VARCHAR(255) NULL,
  is_platform          TINYINT(1)   NOT NULL DEFAULT 0,           -- the account a Super Admin works through inside the company
  must_change_password TINYINT(1)   NOT NULL DEFAULT 1,
  password_changed_at  DATETIME     NULL,
  failed_attempts      INT          NOT NULL DEFAULT 0,
  last_login_at        DATETIME     NULL,
  last_login_ip        VARCHAR(45)  NULL,
  created_by           INT UNSIGNED NULL,
  created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_users_username (username),
  KEY ix_users_approval (approval_status),
  KEY ix_users_pos_site (pos_default_site_id),
  KEY ix_users_pos_class (pos_default_class_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(60)  NOT NULL,
  description VARCHAR(255) NULL,
  is_admin    TINYINT(1)   NOT NULL DEFAULT 0,   -- full access to everything
  is_system   TINYINT(1)   NOT NULL DEFAULT 0,   -- standard role shipped with the system
  all_sites   TINYINT(1)   NOT NULL DEFAULT 1,   -- 0 = limited to role_sites
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_roles_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS user_roles;
CREATE TABLE user_roles (
  user_id INT UNSIGNED NOT NULL,
  role_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),
  CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS modules;
CREATE TABLE modules (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code       VARCHAR(20)  NOT NULL,
  name       VARCHAR(80)  NOT NULL,
  icon       VARCHAR(40)  NULL,
  sort_order INT          NOT NULL DEFAULT 0,
  UNIQUE KEY uq_modules_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pages;
CREATE TABLE pages (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  page_key     VARCHAR(60)  NOT NULL,
  module_id    INT UNSIGNED NOT NULL,
  name         VARCHAR(120) NOT NULL,
  page_type    ENUM('center','transaction','list','report','setup','admin') NOT NULL DEFAULT 'transaction',
  menu_group   VARCHAR(40)  NULL,
  sort_order   INT          NOT NULL DEFAULT 0,
  show_in_menu TINYINT(1)   NOT NULL DEFAULT 1,
  description  VARCHAR(255) NULL,
  UNIQUE KEY uq_pages_key (page_key),
  CONSTRAINT fk_pages_module FOREIGN KEY (module_id) REFERENCES modules(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Page access + action permissions per role (View = allowed)
DROP TABLE IF EXISTS role_page_access;
CREATE TABLE role_page_access (
  role_id     INT UNSIGNED NOT NULL,
  page_id     INT UNSIGNED NOT NULL,
  allowed     TINYINT(1)   NOT NULL DEFAULT 0,
  can_create  TINYINT(1)   NOT NULL DEFAULT 0,
  can_edit    TINYINT(1)   NOT NULL DEFAULT 0,
  can_delete  TINYINT(1)   NOT NULL DEFAULT 0,
  can_print   TINYINT(1)   NOT NULL DEFAULT 0,
  can_approve TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (role_id, page_id),
  CONSTRAINT fk_rpa_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rpa_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- User-level overrides always take precedence over roles
DROP TABLE IF EXISTS user_page_overrides;
CREATE TABLE user_page_overrides (
  user_id     INT UNSIGNED NOT NULL,
  page_id     INT UNSIGNED NOT NULL,
  allowed     TINYINT(1)   NOT NULL DEFAULT 0,
  can_create  TINYINT(1)   NOT NULL DEFAULT 0,
  can_edit    TINYINT(1)   NOT NULL DEFAULT 0,
  can_delete  TINYINT(1)   NOT NULL DEFAULT 0,
  can_print   TINYINT(1)   NOT NULL DEFAULT 0,
  can_approve TINYINT(1)   NOT NULL DEFAULT 0,
  reason      VARCHAR(255) NULL,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, page_id),
  CONSTRAINT fk_upo_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_upo_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sensitive permissions set separately from the grid
--  view_costs, view_bank_balances, credit_limit_override, coa_changes,
--  closed_period_changes (0/1); max_discount_pct, max_price_override_pct,
--  max_amount (number, blank = unlimited)
DROP TABLE IF EXISTS role_special_permissions;
CREATE TABLE role_special_permissions (
  role_id    INT UNSIGNED NOT NULL,
  perm_key   VARCHAR(40)  NOT NULL,
  perm_value VARCHAR(40)  NULL,
  PRIMARY KEY (role_id, perm_key),
  CONSTRAINT fk_rsp_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Permanent, read-only audit trail (see triggers at the end of the file)
DROP TABLE IF EXISTS audit_trail;
CREATE TABLE audit_trail (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id     INT UNSIGNED NULL,
  username    VARCHAR(50)  NULL,
  user_roles  VARCHAR(255) NULL,
  ip_address  VARCHAR(45)  NULL,
  workstation VARCHAR(255) NULL,
  site_id     INT UNSIGNED NULL,
  terminal_id INT UNSIGNED NULL,
  module      VARCHAR(20)  NOT NULL,
  page_key    VARCHAR(60)  NULL,
  action      VARCHAR(30)  NOT NULL,
  record_type VARCHAR(40)  NULL,
  record_id   BIGINT       NULL,
  record_ref  VARCHAR(160) NULL,
  amount      DECIMAL(15,2) NULL,
  changes     LONGTEXT     NULL,   -- JSON [{field, old, new}]
  snapshot    LONGTEXT     NULL,   -- JSON copy of the record
  reason      VARCHAR(255) NULL,
  approved_by VARCHAR(50)  NULL,
  KEY ix_audit_date (created_at),
  KEY ix_audit_user (user_id, created_at),
  KEY ix_audit_record (record_type, record_id),
  KEY ix_audit_action (action),
  KEY ix_audit_module (module)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS memorized_reports;
CREATE TABLE memorized_reports (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  group_name  VARCHAR(60)  NULL,
  report_key  VARCHAR(60)  NOT NULL,
  query_string TEXT        NULL,
  is_shared   TINYINT(1)   NOT NULL DEFAULT 0,
  schedule    VARCHAR(10)  NULL,          -- daily, weekly, monthly (tools/send_scheduled_reports.php)
  email_to    VARCHAR(255) NULL,
  last_sent_at DATETIME    NULL,
  created_by  INT UNSIGNED NOT NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_mr_user FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS sequences;
CREATE TABLE sequences (
  seq_key VARCHAR(30) NOT NULL PRIMARY KEY,
  prefix  VARCHAR(10) NOT NULL DEFAULT '',
  next_no INT UNSIGNED NOT NULL DEFAULT 1,
  pad     TINYINT      NOT NULL DEFAULT 5
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  CHART OF ACCOUNTS AND LISTS
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code            VARCHAR(20)  NOT NULL,
  name            VARCHAR(120) NOT NULL,
  account_type    ENUM('Bank','Accounts Receivable','Other Current Asset','Fixed Asset','Other Asset',
                       'Accounts Payable','Credit Card','Other Current Liability','Long Term Liability',
                       'Equity','Income','Other Income','Cost of Goods Sold','Expense','Other Expense') NOT NULL,
  category        ENUM('Asset','Liability','Equity','Income','Expense') NOT NULL,
  normal_balance  ENUM('Debit','Credit') NOT NULL,
  parent_id       INT UNSIGNED NULL,
  description     VARCHAR(255) NULL,
  bank_account_no VARCHAR(40)  NULL,
  with_sl         TINYINT(1)   NOT NULL DEFAULT 0,    -- keeps a subsidiary ledger: every entry needs a name
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  is_system       TINYINT(1)   NOT NULL DEFAULT 0,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_accounts_code (code),
  KEY ix_acc_with_sl (with_sl),
  CONSTRAINT fk_accounts_parent FOREIGN KEY (parent_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Module default accounts (ar, ap, undeposited_funds, output_tax, ...)
DROP TABLE IF EXISTS default_accounts;
CREATE TABLE default_accounts (
  setting_key VARCHAR(40)  NOT NULL PRIMARY KEY,
  label       VARCHAR(120) NOT NULL,
  module      VARCHAR(20)  NOT NULL,
  account_id  INT UNSIGNED NULL,
  CONSTRAINT fk_da_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS terms;
CREATE TABLE terms (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(40)  NOT NULL,
  net_days      INT          NOT NULL DEFAULT 0,
  discount_pct  DECIMAL(5,2) NOT NULL DEFAULT 0,
  discount_days INT          NOT NULL DEFAULT 0,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tax_codes;
CREATE TABLE tax_codes (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code                VARCHAR(20)  NOT NULL,
  name                VARCHAR(80)  NOT NULL,
  rate                DECIMAL(6,3) NOT NULL DEFAULT 0,
  sales_account_id    INT UNSIGNED NULL,   -- Output Tax
  purchase_account_id INT UNSIGNED NULL,   -- Input Tax
  is_active           TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_tax_code (code),
  CONSTRAINT fk_tax_sales FOREIGN KEY (sales_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tax_purch FOREIGN KEY (purchase_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS payment_methods;
CREATE TABLE payment_methods (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                VARCHAR(40)  NOT NULL,
  method_type         ENUM('cash','check','card','ewallet','bank_transfer','voucher','other') NOT NULL DEFAULT 'other',
  clearing_account_id INT UNSIGNED NULL,   -- POS clearing account for card / e-wallet / voucher / bank
  is_active           TINYINT(1)   NOT NULL DEFAULT 1,
  show_in_pos         TINYINT(1)   NOT NULL DEFAULT 1,   -- offered as a payment option at the POS register
  CONSTRAINT fk_pm_account FOREIGN KEY (clearing_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS price_levels;
CREATE TABLE price_levels (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(40)  NOT NULL,
  adjust_pct DECIMAL(6,2) NOT NULL DEFAULT 0,  -- e.g. -10 = 10% below standard price
  is_active  TINYINT(1)   NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS sales_reps;
CREATE TABLE sales_reps (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name      VARCHAR(80)  NOT NULL,
  initials  VARCHAR(10)  NULL,
  user_id   INT UNSIGNED NULL,
  commission_pct DECIMAL(5,2) NOT NULL DEFAULT 0,
  rep_type  VARCHAR(12)  NOT NULL DEFAULT 'sales_rep',   -- distribution: sales_rep, van (van salesman), cashier
  customer_id INT UNSIGNED NULL,                         -- distribution: the employee as a customer, for shortages charged to them
  is_active TINYINT(1)   NOT NULL DEFAULT 1,
  KEY ix_rep_customer (customer_id),
  CONSTRAINT fk_rep_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS customer_types;
CREATE TABLE customer_types (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS billing_groups;
CREATE TABLE billing_groups (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Class List: your own way of splitting the books (branches, departments, projects ...).
-- Every transaction can carry a class; the ledger keeps it, so financial reports can filter by it.
DROP TABLE IF EXISTS classes;
CREATE TABLE classes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(80)  NOT NULL,
  description VARCHAR(255) NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  sort_order  INT          NOT NULL DEFAULT 0,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_classes_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Employees and other names (payees and subsidiary ledgers that are neither customers nor vendors)
DROP TABLE IF EXISTS other_names;
CREATE TABLE other_names (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name_type   VARCHAR(10)  NOT NULL DEFAULT 'other',  -- employee, other
  name        VARCHAR(120) NOT NULL,
  employee_no VARCHAR(30)  NULL,
  position    VARCHAR(80)  NULL,
  phone       VARCHAR(40)  NULL,
  address     VARCHAR(255) NULL,
  tin         VARCHAR(30)  NULL,
  notes       VARCHAR(255) NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_other_names_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  CUSTOMERS AND VENDORS
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  parent_id           INT UNSIGNED NULL,          -- job / project under a customer
  name                VARCHAR(120) NOT NULL,
  company_name        VARCHAR(120) NULL,
  contact_person      VARCHAR(120) NULL,
  phone               VARCHAR(40)  NULL,
  mobile              VARCHAR(40)  NULL,
  email               VARCHAR(120) NULL,
  billing_address     VARCHAR(255) NULL,
  shipping_address    VARCHAR(255) NULL,
  tin                 VARCHAR(30)  NULL,
  wht_ids             VARCHAR(100) NULL,          -- withholding taxes it usually withholds from its payments
  terms_id            INT UNSIGNED NULL,
  credit_limit        DECIMAL(15,2) NOT NULL DEFAULT 0,  -- 0 = no limit
  price_level_id      INT UNSIGNED NULL,
  tax_code_id         INT UNSIGNED NULL,
  payment_method_id   INT UNSIGNED NULL,
  customer_type_id    INT UNSIGNED NULL,
  sales_rep_id        INT UNSIGNED NULL,
  billing_group_id    INT UNSIGNED NULL,
  allow_pos_charge    TINYINT(1)   NOT NULL DEFAULT 0,  -- approved account customer at the POS
  notes               TEXT         NULL,
  is_active           TINYINT(1)   NOT NULL DEFAULT 1,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_customers_name (name),
  CONSTRAINT fk_cust_parent FOREIGN KEY (parent_id) REFERENCES customers(id),
  CONSTRAINT fk_cust_terms  FOREIGN KEY (terms_id) REFERENCES terms(id),
  CONSTRAINT fk_cust_pl     FOREIGN KEY (price_level_id) REFERENCES price_levels(id),
  CONSTRAINT fk_cust_tax    FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id),
  CONSTRAINT fk_cust_pm     FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
  CONSTRAINT fk_cust_type   FOREIGN KEY (customer_type_id) REFERENCES customer_types(id),
  CONSTRAINT fk_cust_rep    FOREIGN KEY (sales_rep_id) REFERENCES sales_reps(id),
  CONSTRAINT fk_cust_bg     FOREIGN KEY (billing_group_id) REFERENCES billing_groups(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS vendors;
CREATE TABLE vendors (
  id                         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                       VARCHAR(120) NOT NULL,
  company_name               VARCHAR(120) NULL,
  contact_person             VARCHAR(120) NULL,
  phone                      VARCHAR(40)  NULL,
  fax                        VARCHAR(40)  NULL,
  email                      VARCHAR(120) NULL,
  address                    VARCHAR(255) NULL,
  tin                        VARCHAR(30)  NULL,
  terms_id                   INT UNSIGNED NULL,
  credit_limit               DECIMAL(15,2) NOT NULL DEFAULT 0,
  default_expense_account_id INT UNSIGNED NULL,
  tax_code_id                INT UNSIGNED NULL,
  account_no                 VARCHAR(40)  NULL,   -- our account number with the vendor
  wht_ids                    VARCHAR(100) NULL,   -- withholding taxes usually withheld from it (withholding_taxes ids, "1,3")
  notes                      TEXT         NULL,
  is_active                  TINYINT(1)   NOT NULL DEFAULT 1,
  created_at                 TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at                 DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_vendors_name (name),
  CONSTRAINT fk_vend_terms FOREIGN KEY (terms_id) REFERENCES terms(id),
  CONSTRAINT fk_vend_exp   FOREIGN KEY (default_expense_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_vend_tax   FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS entity_notes;
CREATE TABLE entity_notes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  entity_type ENUM('customer','vendor','item') NOT NULL,
  entity_id   INT UNSIGNED NOT NULL,
  note        TEXT         NOT NULL,
  is_todo     TINYINT(1)   NOT NULL DEFAULT 0,
  due_date    DATE         NULL,
  is_done     TINYINT(1)   NOT NULL DEFAULT 0,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_notes_entity (entity_type, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  INVENTORY
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS sites;
CREATE TABLE sites (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code      VARCHAR(20)  NOT NULL,
  name      VARCHAR(80)  NOT NULL,
  site_type ENUM('warehouse','store','stockroom','van','damaged','other') NOT NULL DEFAULT 'warehouse',
  address   VARCHAR(255) NULL,
  sales_rep_id INT UNSIGNED NULL,                        -- distribution: the van salesman (or outlet cashier) answerable for its stock
  is_active TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_sites_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS item_categories;
CREATE TABLE item_categories (
  id   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(60)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Units of measure: a set holds the base unit (stock and costs are kept in it)
-- plus the larger or smaller units a document may be entered in
DROP TABLE IF EXISTS uom_sets;
CREATE TABLE uom_sets (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(60)  NOT NULL,
  uom_kind   VARCHAR(10)  NOT NULL DEFAULT 'count',  -- count, weight, volume, length, time, other
  base_unit  VARCHAR(20)  NOT NULL,
  is_active  TINYINT(1)   NOT NULL DEFAULT 1,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_uom_sets_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS uom_units;
CREATE TABLE uom_units (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  set_id              INT UNSIGNED NOT NULL,
  code                VARCHAR(20)  NOT NULL,
  name                VARCHAR(60)  NOT NULL,
  factor              DECIMAL(15,6) NOT NULL DEFAULT 1,  -- base units in one of this unit
  is_base             TINYINT(1)   NOT NULL DEFAULT 0,
  is_sales_default    TINYINT(1)   NOT NULL DEFAULT 0,
  is_purchase_default TINYINT(1)   NOT NULL DEFAULT 0,
  sort_order          INT          NOT NULL DEFAULT 0,
  is_variable         TINYINT(1)   NOT NULL DEFAULT 0,  -- a container (crate) holding no fixed number of base units
  UNIQUE KEY uq_uom_units (set_id, code),
  CONSTRAINT fk_uom_units_set FOREIGN KEY (set_id) REFERENCES uom_sets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS items;
CREATE TABLE items (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  item_type            ENUM('service','inventory','non_inventory','assembly','other_charge','subtotal','group','discount','payment') NOT NULL,
  code                 VARCHAR(40)  NOT NULL,
  barcode              VARCHAR(60)  NULL,
  name                 VARCHAR(120) NOT NULL,
  description          VARCHAR(255) NULL,
  purchase_description VARCHAR(255) NULL,
  category_id          INT UNSIGNED NULL,
  unit                 VARCHAR(20)  NULL,
  uom_set_id           INT UNSIGNED NULL,                  -- U/M set (blank = single unit)
  sales_uom_id         INT UNSIGNED NULL,                  -- unit offered first on sales forms
  purchase_uom_id      INT UNSIGNED NULL,                  -- unit offered first on purchase forms
  cost                 DECIMAL(15,4) NOT NULL DEFAULT 0,  -- standard purchase cost
  avg_cost             DECIMAL(15,4) NOT NULL DEFAULT 0,  -- weighted average cost
  sales_price          DECIMAL(15,4) NOT NULL DEFAULT 0,
  discount_pct         DECIMAL(6,2)  NOT NULL DEFAULT 0,  -- discount items: percent (0 = use sales_price as amount)
  income_account_id    INT UNSIGNED NULL,
  cogs_account_id      INT UNSIGNED NULL,
  asset_account_id     INT UNSIGNED NULL,
  expense_account_id   INT UNSIGNED NULL,
  tax_code_id          INT UNSIGNED NULL,
  group_variance_account_id INT UNSIGNED NULL,             -- group items: account of the group price less the consolidated price
  preferred_vendor_id  INT UNSIGNED NULL,
  reorder_point        DECIMAL(15,4) NOT NULL DEFAULT 0,
  max_stock            DECIMAL(15,4) NOT NULL DEFAULT 0,
  track_expiry TINYINT(1) NOT NULL DEFAULT 1,     -- v43: 0 = does not expire (no production / expiry dates)
  build_point          DECIMAL(15,4) NOT NULL DEFAULT 0,
  is_active            TINYINT(1)   NOT NULL DEFAULT 1,
  fb_pos               TINYINT(1)   NOT NULL DEFAULT 0,    -- v35: shown on the FB POS
  fb_group_id          INT UNSIGNED NULL,                  -- v35: its FB POS menu group (fb_pos_groups)
  fb_sort              INT          NOT NULL DEFAULT 0,    -- v35: its order in the group
  image_file           VARCHAR(120) NULL,                  -- v35: its picture (storage/items)
  created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_items_code (code),
  KEY ix_items_barcode (barcode),
  KEY ix_items_fb (fb_pos, fb_group_id),
  CONSTRAINT fk_items_cat    FOREIGN KEY (category_id) REFERENCES item_categories(id),
  CONSTRAINT fk_items_inc    FOREIGN KEY (income_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_cogs   FOREIGN KEY (cogs_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_asset  FOREIGN KEY (asset_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_exp    FOREIGN KEY (expense_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_tax    FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id),
  CONSTRAINT fk_items_gvar   FOREIGN KEY (group_variance_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_items_vendor FOREIGN KEY (preferred_vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_items_uom    FOREIGN KEY (uom_set_id) REFERENCES uom_sets(id),
  CONSTRAINT fk_items_suom   FOREIGN KEY (sales_uom_id) REFERENCES uom_units(id),
  CONSTRAINT fk_items_puom   FOREIGN KEY (purchase_uom_id) REFERENCES uom_units(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Bill of materials for assemblies, and members of group items
DROP TABLE IF EXISTS item_components;
CREATE TABLE item_components (
  parent_item_id    INT UNSIGNED NOT NULL,
  component_item_id INT UNSIGNED NOT NULL,
  qty               DECIMAL(15,4) NOT NULL DEFAULT 1,
  PRIMARY KEY (parent_item_id, component_item_id),
  CONSTRAINT fk_ic_parent FOREIGN KEY (parent_item_id) REFERENCES items(id) ON DELETE CASCADE,
  CONSTRAINT fk_ic_comp   FOREIGN KEY (component_item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Processing formulas (multi-output bills of materials) for disassembly,
-- de-kitting / break-bulk and co-product / by-product processing
DROP TABLE IF EXISTS process_formulas;
CREATE TABLE process_formulas (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code         VARCHAR(30)  NOT NULL,
  name         VARCHAR(120) NOT NULL,
  process_type VARCHAR(20)  NOT NULL DEFAULT 'co_product',  -- disassembly, dekit, co_product
  alloc_method VARCHAR(20)  NOT NULL DEFAULT 'sales_value', -- sales_value, standard_cost, quantity, weight, percent, average_cost, manual
  site_id      INT UNSIGNED NULL,                           -- usual processing site
  description  VARCHAR(255) NULL,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  created_by   INT UNSIGNED NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NULL,                           -- set by the application (DB::update)
  UNIQUE KEY uq_pf_code (code),
  CONSTRAINT fk_pf_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Formula lines, quantities per batch. input = consumed, output = produced, cost = labor / overhead absorbed
DROP TABLE IF EXISTS process_formula_lines;
CREATE TABLE process_formula_lines (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  formula_id  INT UNSIGNED NOT NULL,
  line_no     INT          NOT NULL DEFAULT 0,
  line_type   VARCHAR(10)  NOT NULL,                  -- input, output, cost
  item_id     INT UNSIGNED NULL,
  account_id  INT UNSIGNED NULL,                      -- cost lines: account credited
  description VARCHAR(255) NULL,
  qty         DECIMAL(15,4) NOT NULL DEFAULT 0,
  output_role VARCHAR(12)  NULL,                      -- co_product, by_product, scrap
  alloc_basis DECIMAL(15,4) NOT NULL DEFAULT 0,       -- price / weight / percent per unit, by-product value per unit, manual amount per batch
  amount      DECIMAL(15,2) NOT NULL DEFAULT 0,       -- cost lines: amount per batch
  KEY ix_pfl_formula (formula_id),
  KEY ix_pfl_item (item_id),
  CONSTRAINT fk_pfl_formula FOREIGN KEY (formula_id) REFERENCES process_formulas(id) ON DELETE CASCADE,
  CONSTRAINT fk_pfl_item    FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_pfl_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS price_level_items;
CREATE TABLE price_level_items (
  price_level_id INT UNSIGNED NOT NULL,
  item_id        INT UNSIGNED NOT NULL,
  custom_price   DECIMAL(15,4) NOT NULL,
  PRIMARY KEY (price_level_id, item_id),
  CONSTRAINT fk_pli_level FOREIGN KEY (price_level_id) REFERENCES price_levels(id) ON DELETE CASCADE,
  CONSTRAINT fk_pli_item  FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS item_site_stock;
CREATE TABLE item_site_stock (
  item_id     INT UNSIGNED NOT NULL,
  site_id     INT UNSIGNED NOT NULL,
  qty_on_hand DECIMAL(15,4) NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id, site_id),
  CONSTRAINT fk_iss_item FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
  CONSTRAINT fk_iss_site FOREIGN KEY (site_id) REFERENCES sites(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  TRANSACTIONS (all modules)
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_type           VARCHAR(30)  NOT NULL,
  -- estimate, sales_order, invoice, sales_receipt, statement_charge, finance_charge,
  -- payment, credit_memo, refund, purchase_order, bill, vendor_credit, item_receipt,
  -- bill_payment, check, deposit, transfer, journal, inventory_adjustment,
  -- inventory_transfer, build_assembly, pos_sale, pos_return, depreciation,
  -- asset_disposal, bank_charge, bank_interest, item_processing, cash_voucher, vendor_advance,
  -- shortage_charge (distribution: stock short charged to the employee answerable for it, at cost)
  txn_no             VARCHAR(30)  NULL,
  txn_date           DATE         NOT NULL,
  due_date           DATE         NULL,
  ship_date          DATE         NULL,
  ref_no             VARCHAR(60)  NULL,
  customer_id        INT UNSIGNED NULL,
  vendor_id          INT UNSIGNED NULL,
  payee_name         VARCHAR(120) NULL,
  account_id         INT UNSIGNED NULL,     -- AR / AP / bank / deposit-to / from account
  account2_id        INT UNSIGNED NULL,     -- transfer-to / cash-back / adjustment account
  site_id            INT UNSIGNED NULL,
  site2_id           INT UNSIGNED NULL,     -- transfer-to site
  terms_id           INT UNSIGNED NULL,
  sales_rep_id       INT UNSIGNED NULL,
  payment_method_id  INT UNSIGNED NULL,
  billing_address    VARCHAR(255) NULL,
  shipping_address   VARCHAR(255) NULL,
  memo               VARCHAR(255) NULL,
  customer_message   VARCHAR(255) NULL,
  subtotal           DECIMAL(15,2) NOT NULL DEFAULT 0,
  tax_total          DECIMAL(15,2) NOT NULL DEFAULT 0,
  discount_amount    DECIMAL(15,2) NOT NULL DEFAULT 0,
  withholding_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  cash_back_amount   DECIMAL(15,2) NOT NULL DEFAULT 0,
  total              DECIMAL(15,2) NOT NULL DEFAULT 0,
  status             VARCHAR(20)  NOT NULL DEFAULT 'open',
  -- open, closed, paid, partial, pending, accepted, suspended, completed, void
  is_pending         TINYINT(1)   NOT NULL DEFAULT 0,
  is_voided          TINYINT(1)   NOT NULL DEFAULT 0,
  void_reason        VARCHAR(255) NULL,
  voided_by          INT UNSIGNED NULL,
  voided_at          DATETIME     NULL,
  to_be_printed      TINYINT(1)   NOT NULL DEFAULT 0,
  is_printed         TINYINT(1)   NOT NULL DEFAULT 0,
  restock            TINYINT(1)   NOT NULL DEFAULT 1,     -- credit memos / POS returns
  credit_disposition VARCHAR(10)  NULL,                   -- keep, apply, refund
  progress_pct       DECIMAL(6,2) NULL,                   -- progress invoicing
  source_txn_id      BIGINT UNSIGNED NULL,                -- converted from / refund of
  terminal_id        INT UNSIGNED NULL,
  pos_shift_id       INT UNSIGNED NULL,
  receipt_no         VARCHAR(30)  NULL,
  amount_tendered    DECIMAL(15,2) NOT NULL DEFAULT 0,
  change_given       DECIMAL(15,2) NOT NULL DEFAULT 0,
  approved_by        INT UNSIGNED NULL,
  batch_ref          VARCHAR(40)  NULL,
  process_type       VARCHAR(20)  NULL,                   -- item processing: disassembly, dekit, co_product
  alloc_method       VARCHAR(20)  NULL,                   -- item processing: cost allocation method
  process_formula_id INT UNSIGNED NULL,                   -- item processing: formula used
  process_batches    DECIMAL(15,4) NULL,                  -- item processing: formula batches run
  class_id           INT UNSIGNED NULL,                   -- class of the whole transaction (lines may override it)
  other_name_id      INT UNSIGNED NULL,                   -- payee from Employees & Other Names
  received_via       VARCHAR(12)  NULL,                   -- receipt = Receive Items, bill = Receive Items and Enter Bills
  created_by         INT UNSIGNED NULL,
  created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_by         INT UNSIGNED NULL,
  updated_at         DATETIME     NULL,                  -- set by the application (DB::update)
  KEY ix_txn_type_date (txn_type, txn_date),
  KEY ix_txn_customer (customer_id, txn_date),
  KEY ix_txn_vendor (vendor_id, txn_date),
  KEY ix_txn_status (status),
  KEY ix_txn_source (source_txn_id),
  KEY ix_txn_shift (pos_shift_id),
  KEY ix_txn_formula (process_formula_id),
  KEY ix_txn_class (class_id),
  KEY ix_txn_other_name (other_name_id),
  CONSTRAINT fk_txn_class    FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_txn_other_name FOREIGN KEY (other_name_id) REFERENCES other_names(id),
  CONSTRAINT fk_txn_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT fk_txn_vendor   FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_txn_account  FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_txn_formula  FOREIGN KEY (process_formula_id) REFERENCES process_formulas(id) ON DELETE SET NULL,
  CONSTRAINT fk_txn_account2 FOREIGN KEY (account2_id) REFERENCES accounts(id),
  CONSTRAINT fk_txn_site     FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_txn_site2    FOREIGN KEY (site2_id) REFERENCES sites(id),
  CONSTRAINT fk_txn_terms    FOREIGN KEY (terms_id) REFERENCES terms(id),
  CONSTRAINT fk_txn_rep      FOREIGN KEY (sales_rep_id) REFERENCES sales_reps(id),
  CONSTRAINT fk_txn_pm       FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS transaction_lines;
CREATE TABLE transaction_lines (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id          BIGINT UNSIGNED NOT NULL,
  line_no         INT          NOT NULL DEFAULT 0,
  line_kind       VARCHAR(10)  NOT NULL DEFAULT 'item',   -- item, expense, journal, deposit, component, input, output, cost
  item_id         INT UNSIGNED NULL,
  account_id      INT UNSIGNED NULL,
  description     VARCHAR(255) NULL,
  qty             DECIMAL(15,4) NOT NULL DEFAULT 0,
  unit            VARCHAR(20)  NULL,
  uom_id          INT UNSIGNED NULL,                      -- unit the line was entered in
  uom_factor      DECIMAL(15,6) NOT NULL DEFAULT 1,       -- base units in one entered unit
  uom_qty         DECIMAL(15,4) NOT NULL DEFAULT 0,       -- quantity as entered
  uom_rate        DECIMAL(15,4) NOT NULL DEFAULT 0,       -- price as entered
  rate            DECIMAL(15,4) NOT NULL DEFAULT 0,
  discount_kind   VARCHAR(3)    NOT NULL DEFAULT 'pct',   -- pct = percent of the line, amt = amount off
  discount_pct    DECIMAL(6,2)  NOT NULL DEFAULT 0,
  discount_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,       -- journal: + debit / - credit
  tax_code_id     INT UNSIGNED NULL,
  tax_amount      DECIMAL(15,2) NOT NULL DEFAULT 0,
  site_id         INT UNSIGNED NULL,
  production_date DATE NULL,                      -- v43: production / expiry date group of the line
  expiry_date DATE NULL,
  customer_id     INT UNSIGNED NULL,                      -- customer:job for billable costs / journal
  vendor_id       INT UNSIGNED NULL,
  is_billable     TINYINT(1)   NOT NULL DEFAULT 0,
  billed_txn_id   BIGINT UNSIGNED NULL,                   -- invoice that billed this cost
  ref_txn_id      BIGINT UNSIGNED NULL,                   -- deposit: payment / receipt being deposited
  pos_shift_id    INT UNSIGNED NULL,                      -- deposit: the POS shift whose cash the line deposits
  source_line_id  BIGINT UNSIGNED NULL,                   -- estimate / SO / PO line
  qty_fulfilled   DECIMAL(15,4) NOT NULL DEFAULT 0,       -- SO invoiced / PO received
  amount_fulfilled DECIMAL(15,2) NOT NULL DEFAULT 0,      -- estimate progress-invoiced
  is_closed       TINYINT(1)   NOT NULL DEFAULT 0,
  cost_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,       -- COGS captured at posting
  value_change    DECIMAL(15,2) NOT NULL DEFAULT 0,       -- inventory value adjustment
  output_role     VARCHAR(12)  NULL,                      -- item processing output: co_product, by_product, scrap
  alloc_basis     DECIMAL(15,4) NOT NULL DEFAULT 0,       -- item processing: price / weight / percent / value entered
  alloc_pct       DECIMAL(9,4)  NOT NULL DEFAULT 0,       -- item processing: share of the total cost
  planned_qty     DECIMAL(15,4) NULL,                     -- item processing: quantity expected by the formula
  class_id        INT UNSIGNED NULL,                      -- class of this line (blank = the transaction's class)
  other_name_id   INT UNSIGNED NULL,                      -- subsidiary ledger: employee / other name
  group_item_id   INT UNSIGNED NULL,                      -- item group sold: the group this line belongs to
  group_ref       INT UNSIGNED NULL,                      -- which group of the document (several of the same group can be on it)
  group_qty       DECIMAL(15,4) NULL,                     -- groups sold on the line's group
  group_rate      DECIMAL(15,4) NULL,                     -- price of one group
  group_role      VARCHAR(10)  NULL,                      -- member = an item of the group, variance = group price less consolidated price
  crate_count     INT          NOT NULL DEFAULT 0,        -- distribution: crates on the line (received or sold whole or in part)
  KEY ix_tl_txn (txn_id),
  KEY ix_tl_group (group_item_id),
  KEY ix_tl_item (item_id),
  KEY ix_tl_ref (ref_txn_id),
  KEY ix_tl_shift (pos_shift_id),
  KEY ix_tl_source (source_line_id),
  KEY ix_tl_class (class_id),
  KEY ix_tl_other_name (other_name_id),
  CONSTRAINT fk_tl_class   FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_tl_other_name FOREIGN KEY (other_name_id) REFERENCES other_names(id),
  CONSTRAINT fk_tl_txn     FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_tl_item    FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_tl_account FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_tl_tax     FOREIGN KEY (tax_code_id) REFERENCES tax_codes(id),
  CONSTRAINT fk_tl_site    FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_tl_cust    FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT fk_tl_uom     FOREIGN KEY (uom_id) REFERENCES uom_units(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Payments / credits applied to invoices and bills
DROP TABLE IF EXISTS payment_applications;
CREATE TABLE payment_applications (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  payment_txn_id BIGINT UNSIGNED NOT NULL,   -- payment, credit memo, bill payment, vendor credit
  target_txn_id  BIGINT UNSIGNED NOT NULL,   -- invoice, statement/finance charge, bill
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,
  discount       DECIMAL(15,2) NOT NULL DEFAULT 0,
  withholding    DECIMAL(15,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pa_payment (payment_txn_id),
  KEY ix_pa_target (target_txn_id),
  CONSTRAINT fk_pa_payment FOREIGN KEY (payment_txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_pa_target  FOREIGN KEY (target_txn_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Withholding Tax Table (BIR Reports): the taxes a payment can have withheld
DROP TABLE IF EXISTS withholding_taxes;
CREATE TABLE withholding_taxes (
  id                    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code                  VARCHAR(20)  NOT NULL,
  atc                   VARCHAR(10)  NULL,                   -- BIR alphanumeric tax code (WC158, WC160, WV010 ...)
  name                  VARCHAR(100) NOT NULL,
  tax_kind              ENUM('income','vat') NOT NULL DEFAULT 'income',   -- expanded withholding of income tax, or VAT / business tax withheld
  rate                  DECIMAL(9,4) NOT NULL DEFAULT 0,     -- percent
  base_type             ENUM('net_of_vat','gross') NOT NULL DEFAULT 'net_of_vat',
  applies_to            ENUM('purchases','sales','both') NOT NULL DEFAULT 'both',
  payable_account_id    INT UNSIGNED NULL,                   -- withheld from suppliers (blank = module default)
  receivable_account_id INT UNSIGNED NULL,                   -- withheld by customers (blank = module default)
  description           VARCHAR(255) NULL,
  sort_order            INT          NOT NULL DEFAULT 0,
  is_active             TINYINT(1)   NOT NULL DEFAULT 1,
  created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME     NULL,
  UNIQUE KEY uq_wht_code (code),
  CONSTRAINT fk_wht_payable FOREIGN KEY (payable_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_wht_receivable FOREIGN KEY (receivable_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Taxes withheld by a payment (bill payment or customer payment), by document paid and type: BIR Form 2307 and the BIR Reports
DROP TABLE IF EXISTS payment_withholdings;
CREATE TABLE payment_withholdings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  payment_txn_id BIGINT UNSIGNED NOT NULL,
  target_txn_id  BIGINT UNSIGNED NULL,        -- the bill / invoice it was withheld on
  wht_id         INT UNSIGNED NOT NULL,
  tax_kind       ENUM('income','vat') NOT NULL DEFAULT 'income',
  atc            VARCHAR(10)  NULL,
  rate           DECIMAL(9,4) NOT NULL DEFAULT 0,
  base           DECIMAL(15,2) NOT NULL DEFAULT 0,
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,
  account_id     INT UNSIGNED NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pw_payment (payment_txn_id),
  KEY ix_pw_target (target_txn_id),
  KEY ix_pw_wht (wht_id),
  CONSTRAINT fk_pw_payment FOREIGN KEY (payment_txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_pw_target  FOREIGN KEY (target_txn_id) REFERENCES transactions(id) ON DELETE SET NULL,
  CONSTRAINT fk_pw_wht     FOREIGN KEY (wht_id) REFERENCES withholding_taxes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Item group sales (System Administration > Track Item Group Sales transactions): one row per group sold on a document
DROP TABLE IF EXISTS item_group_sales;
CREATE TABLE item_group_sales (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id         BIGINT UNSIGNED NOT NULL,
  group_ref      INT UNSIGNED NOT NULL DEFAULT 0,
  group_item_id  INT UNSIGNED NOT NULL,
  txn_type       VARCHAR(30)  NOT NULL,
  txn_date       DATE         NOT NULL,
  customer_id    INT UNSIGNED NULL,
  site_id        INT UNSIGNED NULL,
  terminal_id    INT UNSIGNED NULL,
  class_id       INT UNSIGNED NULL,
  sales_rep_id   INT UNSIGNED NULL,
  created_by     INT UNSIGNED NULL,
  qty            DECIMAL(15,4) NOT NULL DEFAULT 0,   -- groups sold
  group_price    DECIMAL(15,4) NOT NULL DEFAULT 0,   -- price of one group
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,   -- what the groups sold for (before tax)
  consolidated   DECIMAL(15,2) NOT NULL DEFAULT 0,   -- the items of the groups at their own prices
  variance       DECIMAL(15,2) NOT NULL DEFAULT 0,   -- amount less consolidated (to the price variance account)
  tax_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_igs_txn (txn_id),
  KEY ix_igs_group (group_item_id, txn_date),
  KEY ix_igs_date (txn_type, txn_date),
  CONSTRAINT fk_igs_txn   FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_igs_group FOREIGN KEY (group_item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Card and e-wallet receipts ticked to settle on Make Deposits (v32, Details > Settle)
DROP TABLE IF EXISTS clearing_settlements;
CREATE TABLE clearing_settlements (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  deposit_txn_id  BIGINT UNSIGNED NOT NULL,                -- the deposit that holds the settlement
  account_id      INT UNSIGNED    NOT NULL,                -- the card / e-wallet clearing account
  receipt_txn_id  BIGINT UNSIGNED NOT NULL,                -- the POS sale, payment or sales receipt settled
  amount          DECIMAL(15,2)   NOT NULL DEFAULT 0,      -- what of it was settled
  created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cs_deposit (deposit_txn_id),
  KEY ix_cs_receipt (account_id, receipt_txn_id),
  KEY ix_cs_receipt_txn (receipt_txn_id),
  CONSTRAINT fk_cs_deposit FOREIGN KEY (deposit_txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_cs_receipt FOREIGN KEY (receipt_txn_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FB POS menu groups (v35, Point of Sale > FB POS Menu & Groups)
DROP TABLE IF EXISTS fb_pos_groups;
CREATE TABLE fb_pos_groups (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(60)  NOT NULL,
  sort_order  INT          NOT NULL DEFAULT 0,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_fb_group_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- General ledger (generated automatically by the posting engine)
DROP TABLE IF EXISTS journal_lines;
CREATE TABLE journal_lines (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id            BIGINT UNSIGNED NOT NULL,
  txn_date          DATE         NOT NULL,
  account_id        INT UNSIGNED NOT NULL,
  debit             DECIMAL(15,2) NOT NULL DEFAULT 0,
  credit            DECIMAL(15,2) NOT NULL DEFAULT 0,
  customer_id       INT UNSIGNED NULL,
  vendor_id         INT UNSIGNED NULL,
  item_id           INT UNSIGNED NULL,
  site_id           INT UNSIGNED NULL,
  class_id          INT UNSIGNED NULL,
  other_name_id     INT UNSIGNED NULL,
  memo              VARCHAR(255) NULL,
  cleared           TINYINT(1)   NOT NULL DEFAULT 0,
  reconciliation_id INT UNSIGNED NULL,
  created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_jl_account_date (account_id, txn_date),
  KEY ix_jl_txn (txn_id),
  KEY ix_jl_customer (customer_id),
  KEY ix_jl_vendor (vendor_id),
  KEY ix_jl_class (class_id, txn_date),
  KEY ix_jl_other_name (other_name_id),
  CONSTRAINT fk_jl_class   FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_jl_other_name FOREIGN KEY (other_name_id) REFERENCES other_names(id),
  CONSTRAINT fk_jl_txn     FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_jl_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Perpetual inventory movements (generated automatically)
DROP TABLE IF EXISTS inventory_movements;
CREATE TABLE inventory_movements (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id      BIGINT UNSIGNED NOT NULL,
  txn_line_id BIGINT UNSIGNED NULL,
  txn_date    DATE         NOT NULL,
  item_id     INT UNSIGNED NOT NULL,
  site_id     INT UNSIGNED NOT NULL,
  production_date DATE NULL,                  -- v43: production / expiry date group
  expiry_date DATE NULL,
  qty         DECIMAL(15,4) NOT NULL DEFAULT 0,
  unit_cost   DECIMAL(15,4) NOT NULL DEFAULT 0,
  total_cost  DECIMAL(15,2) NOT NULL DEFAULT 0,
  qty_after   DECIMAL(15,4) NOT NULL DEFAULT 0,    -- total on hand (all sites) after the movement
  avg_after   DECIMAL(15,4) NOT NULL DEFAULT 0,    -- average cost after the movement
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_im_item_date (item_id, txn_date),
  KEY ix_im_txn (txn_id),
  KEY ix_im_lot (item_id, site_id, expiry_date, production_date),
  KEY ix_im_expiry (expiry_date),
  CONSTRAINT fk_im_txn  FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_im_item FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_im_site FOREIGN KEY (site_id) REFERENCES sites(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  VENDORS - RECEIPT MANAGEMENT
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS receipt_documents;
CREATE TABLE receipt_documents (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  file_path     VARCHAR(255) NOT NULL,
  original_name VARCHAR(255) NULL,
  mime_type     VARCHAR(80)  NULL,
  source        ENUM('upload','email','mobile') NOT NULL DEFAULT 'upload',
  vendor_id     INT UNSIGNED NULL,
  receipt_date  DATE         NULL,
  amount        DECIMAL(15,2) NULL,
  account_id    INT UNSIGNED NULL,
  memo          VARCHAR(255) NULL,
  status        ENUM('for_review','matched','created','rejected') NOT NULL DEFAULT 'for_review',
  linked_txn_id BIGINT UNSIGNED NULL,
  uploaded_by   INT UNSIGNED NULL,
  uploaded_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_by   INT UNSIGNED NULL,
  reviewed_at   DATETIME     NULL,
  CONSTRAINT fk_rd_vendor  FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_rd_account FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_rd_txn     FOREIGN KEY (linked_txn_id) REFERENCES transactions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  FIXED ASSETS
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS asset_categories;
CREATE TABLE asset_categories (
  id                     INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                   VARCHAR(80)  NOT NULL,
  asset_account_id       INT UNSIGNED NOT NULL,
  accum_dep_account_id   INT UNSIGNED NOT NULL,
  dep_expense_account_id INT UNSIGNED NOT NULL,
  default_method         ENUM('straight_line','declining_balance','units_of_production','syd') NOT NULL DEFAULT 'straight_line',
  default_life_years     DECIMAL(5,2) NOT NULL DEFAULT 5,
  is_active              TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT fk_ac_asset FOREIGN KEY (asset_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_ac_accum FOREIGN KEY (accum_dep_account_id) REFERENCES accounts(id),
  CONSTRAINT fk_ac_exp   FOREIGN KEY (dep_expense_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_locations;
CREATE TABLE asset_locations (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(120) NOT NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NULL,
  UNIQUE KEY uq_asset_locations_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS fixed_assets;
CREATE TABLE fixed_assets (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  asset_no            VARCHAR(30)  NOT NULL,
  description         VARCHAR(160) NOT NULL,
  category_id         INT UNSIGNED NOT NULL,
  location            VARCHAR(120) NULL,
  location_id         INT UNSIGNED NULL,
  site_id             INT UNSIGNED NULL,
  class_id            INT UNSIGNED NULL,      -- default class (depreciation entry when no class is chosen)
  serial_no           VARCHAR(60)  NULL,
  vendor_id           INT UNSIGNED NULL,
  acquisition_date    DATE         NOT NULL,
  cost                DECIMAL(15,2) NOT NULL,
  salvage_value       DECIMAL(15,2) NOT NULL DEFAULT 0,
  useful_life_years   DECIMAL(5,2) NOT NULL,
  method              ENUM('straight_line','declining_balance','units_of_production','syd') NOT NULL,
  db_multiplier       DECIMAL(4,2) NOT NULL DEFAULT 2.00,
  total_units         DECIMAL(15,2) NULL,      -- units of production
  unit_label          VARCHAR(30)  NULL,
  -- change in estimate: new basis applied from basis_date forward
  basis_date          DATE         NULL,
  basis_nbv           DECIMAL(15,2) NULL,
  basis_life_months   INT          NULL,
  -- existing assets: depreciation recorded before the system was used
  opening_accum_dep   DECIMAL(15,2) NOT NULL DEFAULT 0,
  opening_through     DATE         NULL,
  acquisition_txn_id  BIGINT UNSIGNED NULL,
  status              ENUM('active','fully_depreciated','disposed') NOT NULL DEFAULT 'active',
  disposal_date       DATE         NULL,
  disposal_proceeds   DECIMAL(15,2) NULL,
  disposal_txn_id     BIGINT UNSIGNED NULL,
  notes               TEXT         NULL,
  current_meter       DECIMAL(15,2) NULL,     -- odometer / running hours
  meter_unit          VARCHAR(20)  NULL,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NULL,                  -- set by the application (DB::update)
  UNIQUE KEY uq_fa_no (asset_no),
  KEY ix_fa_location (location_id),
  KEY ix_fa_class (class_id),
  CONSTRAINT fk_fa_location FOREIGN KEY (location_id) REFERENCES asset_locations(id),
  CONSTRAINT fk_fa_class  FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_fa_cat    FOREIGN KEY (category_id) REFERENCES asset_categories(id),
  CONSTRAINT fk_fa_site   FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_fa_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_fa_acq    FOREIGN KEY (acquisition_txn_id) REFERENCES transactions(id) ON DELETE SET NULL,
  CONSTRAINT fk_fa_disp   FOREIGN KEY (disposal_txn_id) REFERENCES transactions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_depreciation;
CREATE TABLE asset_depreciation (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  asset_id     INT UNSIGNED NOT NULL,
  period_year  SMALLINT     NOT NULL,
  period_month TINYINT      NOT NULL,
  units_used   DECIMAL(15,2) NULL,
  amount       DECIMAL(15,2) NOT NULL,
  txn_id       BIGINT UNSIGNED NOT NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_ad_period (asset_id, period_year, period_month),
  CONSTRAINT fk_ad_asset FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_txn   FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_meter_readings;
CREATE TABLE asset_meter_readings (
  asset_id     INT UNSIGNED NOT NULL,
  period_year  SMALLINT     NOT NULL,
  period_month TINYINT      NOT NULL,
  units        DECIMAL(15,2) NOT NULL,
  entered_by   INT UNSIGNED NULL,
  entered_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (asset_id, period_year, period_month),
  CONSTRAINT fk_amr_asset FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- fixed asset maintenance and preventive maintenance
DROP TABLE IF EXISTS asset_pm_schedules;
CREATE TABLE asset_pm_schedules (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  asset_id         INT UNSIGNED NOT NULL,
  task_name        VARCHAR(160) NOT NULL,
  task_type        VARCHAR(30)  NOT NULL DEFAULT 'other',  -- registration, change_oil, cleaning, inspection, insurance, other
  interval_value   INT          NULL,                      -- repeat every N ... (NULL = one time only)
  interval_unit    VARCHAR(10)  NULL,                      -- days, weeks, months, years
  meter_interval   DECIMAL(15,2) NULL,                     -- or every N km / hours
  next_due_date    DATE         NULL,
  next_due_meter   DECIMAL(15,2) NULL,
  remind_days      INT          NOT NULL DEFAULT 14,       -- start reminding this many days before the due date
  last_done_date   DATE         NULL,
  last_done_meter  DECIMAL(15,2) NULL,
  assigned_to      VARCHAR(120) NULL,
  notes            VARCHAR(255) NULL,
  is_active        TINYINT(1)   NOT NULL DEFAULT 1,
  created_by       INT UNSIGNED NULL,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     NULL,
  KEY ix_pm_asset (asset_id),
  KEY ix_pm_due (is_active, next_due_date),
  CONSTRAINT fk_pm_asset FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance;
CREATE TABLE asset_maintenance (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maint_no            VARCHAR(30)  NOT NULL,
  asset_id            INT UNSIGNED NOT NULL,
  maint_date          DATE         NOT NULL,
  maint_type          VARCHAR(20)  NOT NULL DEFAULT 'repair',     -- repair, preventive, inspection, upgrade
  status              VARCHAR(20)  NOT NULL DEFAULT 'completed',  -- in_progress, completed, void
  problem             VARCHAR(255) NULL,                          -- what was reported / why
  description         TEXT         NULL,                          -- maintenance description: the work done
  vendor_id           INT UNSIGNED NULL,                          -- supplier of the parts / service
  performed_by        VARCHAR(120) NULL,                          -- mechanic, technician or shop
  ref_no              VARCHAR(60)  NULL,                          -- supplier invoice / job order no.
  meter_reading       DECIMAL(15,2) NULL,
  downtime_days       DECIMAL(7,2) NULL,
  parts_total         DECIMAL(15,2) NOT NULL DEFAULT 0,
  labor_total         DECIMAL(15,2) NOT NULL DEFAULT 0,
  tax_total           DECIMAL(15,2) NOT NULL DEFAULT 0,
  total               DECIMAL(15,2) NOT NULL DEFAULT 0,
  with_vat            TINYINT(1)   NOT NULL DEFAULT 0,
  payment_mode        VARCHAR(20)  NOT NULL DEFAULT 'none',       -- none, bill, check, cash_voucher
  pay_account_id      INT UNSIGNED NULL,                          -- bank (check) or cash account (cash voucher)
  parts_account_id    INT UNSIGNED NULL,
  labor_account_id    INT UNSIGNED NULL,
  class_id            INT UNSIGNED NULL,
  txn_id              BIGINT UNSIGNED NULL,                       -- the bill, check or cash voucher created for it
  schedule_id         INT UNSIGNED NULL,                          -- preventive maintenance task completed by this record
  next_service_date   DATE         NULL,
  notes               TEXT         NULL,
  void_reason         VARCHAR(255) NULL,
  created_by          INT UNSIGNED NULL,
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME     NULL,
  UNIQUE KEY uq_maint_no (maint_no),
  KEY ix_maint_asset (asset_id, maint_date),
  KEY ix_maint_vendor (vendor_id),
  KEY ix_maint_txn (txn_id),
  KEY ix_maint_class (class_id),
  KEY ix_maint_schedule (schedule_id),
  CONSTRAINT fk_maint_asset    FOREIGN KEY (asset_id) REFERENCES fixed_assets(id),
  CONSTRAINT fk_maint_vendor   FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_maint_class    FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_maint_txn      FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE SET NULL,
  CONSTRAINT fk_maint_schedule FOREIGN KEY (schedule_id) REFERENCES asset_pm_schedules(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance_parts;
CREATE TABLE asset_maintenance_parts (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maintenance_id  INT UNSIGNED NOT NULL,
  line_no         INT          NOT NULL DEFAULT 0,
  part_no         VARCHAR(60)  NULL,
  description     VARCHAR(200) NOT NULL,
  serial_no       VARCHAR(60)  NULL,
  model_no        VARCHAR(60)  NULL,
  size_spec       VARCHAR(60)  NULL,
  brand           VARCHAR(60)  NULL,
  qty             DECIMAL(15,4) NOT NULL DEFAULT 1,
  unit            VARCHAR(20)  NULL,
  unit_cost       DECIMAL(15,4) NOT NULL DEFAULT 0,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  warranty_until  DATE         NULL,
  KEY ix_mparts_maint (maintenance_id),
  KEY ix_mparts_partno (part_no),
  CONSTRAINT fk_mparts_maint FOREIGN KEY (maintenance_id) REFERENCES asset_maintenance(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance_labor;
CREATE TABLE asset_maintenance_labor (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maintenance_id  INT UNSIGNED NOT NULL,
  line_no         INT          NOT NULL DEFAULT 0,
  description     VARCHAR(200) NOT NULL,
  worker          VARCHAR(120) NULL,
  charge_type     VARCHAR(10)  NOT NULL DEFAULT 'hourly',   -- hourly (man-hours x rate) or bulk (one charge)
  hours           DECIMAL(9,2) NOT NULL DEFAULT 0,
  rate            DECIMAL(15,4) NOT NULL DEFAULT 0,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  KEY ix_mlabor_maint (maintenance_id),
  CONSTRAINT fk_mlabor_maint FOREIGN KEY (maintenance_id) REFERENCES asset_maintenance(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_maintenance_photos;
CREATE TABLE asset_maintenance_photos (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  maintenance_id  INT UNSIGNED NOT NULL,
  file_name       VARCHAR(120) NOT NULL,      -- name inside storage/maintenance/
  original_name   VARCHAR(190) NULL,
  mime_type       VARCHAR(60)  NULL,
  file_size       INT UNSIGNED NOT NULL DEFAULT 0,
  caption         VARCHAR(190) NULL,
  uploaded_by     INT UNSIGNED NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_mphotos_maint (maintenance_id),
  CONSTRAINT fk_mphotos_maint FOREIGN KEY (maintenance_id) REFERENCES asset_maintenance(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS asset_pm_log;
CREATE TABLE asset_pm_log (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  schedule_id     INT UNSIGNED NOT NULL,
  asset_id        INT UNSIGNED NOT NULL,
  task_name       VARCHAR(160) NOT NULL,
  due_date        DATE         NULL,
  done_date       DATE         NOT NULL,
  done_meter      DECIMAL(15,2) NULL,
  maintenance_id  INT UNSIGNED NULL,
  remarks         VARCHAR(255) NULL,
  done_by         INT UNSIGNED NULL,          -- the user who acknowledged that the task is complete
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pmlog_schedule (schedule_id),
  KEY ix_pmlog_asset (asset_id, done_date),
  CONSTRAINT fk_pmlog_schedule FOREIGN KEY (schedule_id) REFERENCES asset_pm_schedules(id) ON DELETE CASCADE,
  CONSTRAINT fk_pmlog_asset    FOREIGN KEY (asset_id) REFERENCES fixed_assets(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  POINT OF SALE
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS pos_terminals;
CREATE TABLE pos_terminals (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code            VARCHAR(20)  NOT NULL,
  name            VARCHAR(80)  NOT NULL,
  site_id         INT UNSIGNED NOT NULL,
  cash_account_id INT UNSIGNED NOT NULL,
  receipt_prefix  VARCHAR(10)  NOT NULL DEFAULT 'OR',
  next_receipt_no INT UNSIGNED NOT NULL DEFAULT 1,
  next_z_no       INT UNSIGNED NOT NULL DEFAULT 1,
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  class_id        INT UNSIGNED NULL,                      -- default class of sales made at this terminal
  UNIQUE KEY uq_term_code (code),
  CONSTRAINT fk_term_class FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_term_site FOREIGN KEY (site_id) REFERENCES sites(id),
  CONSTRAINT fk_term_cash FOREIGN KEY (cash_account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_shifts;
CREATE TABLE pos_shifts (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  terminal_id    INT UNSIGNED NOT NULL,
  cashier_id     INT UNSIGNED NOT NULL,
  business_date  DATE         NOT NULL,
  opened_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  opening_float  DECIMAL(15,2) NOT NULL DEFAULT 0,
  closed_at      DATETIME     NULL,
  expected_cash  DECIMAL(15,2) NULL,
  counted_cash   DECIMAL(15,2) NULL,
  over_short     DECIMAL(15,2) NULL,
  over_short_txn_id BIGINT UNSIGNED NULL,
  deposit_txn_id BIGINT UNSIGNED NULL,
  status         ENUM('open','closed') NOT NULL DEFAULT 'open',
  closed_by      INT UNSIGNED NULL,
  corrected_by   INT UNSIGNED NULL,          -- who last corrected the closing entries (float, drops, count)
  corrected_at   DATETIME     NULL,
  KEY ix_shift_term (terminal_id, status),
  CONSTRAINT fk_shift_term FOREIGN KEY (terminal_id) REFERENCES pos_terminals(id),
  CONSTRAINT fk_shift_user FOREIGN KEY (cashier_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_tenders;
CREATE TABLE pos_tenders (
  id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  txn_id            BIGINT UNSIGNED NOT NULL,
  payment_method_id INT UNSIGNED NOT NULL,
  amount            DECIMAL(15,2) NOT NULL,     -- net amount applied to the sale (after change)
  reference         VARCHAR(60)  NULL,
  account_id        INT UNSIGNED NULL,          -- v9: the G.L. account the tender was posted to (kept when re-posted)
  KEY ix_pt_txn (txn_id),
  CONSTRAINT fk_pt_txn FOREIGN KEY (txn_id) REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT fk_pt_pm  FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_cash_drops;
CREATE TABLE pos_cash_drops (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  shift_id    INT UNSIGNED NOT NULL,
  amount      DECIMAL(15,2) NOT NULL,
  reason      VARCHAR(255) NULL,
  created_by  INT UNSIGNED NOT NULL,
  approved_by INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_cd_shift FOREIGN KEY (shift_id) REFERENCES pos_shifts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_cash_counts;
CREATE TABLE pos_cash_counts (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT PRIMARY KEY,
  shift_id      INT UNSIGNED  NOT NULL,
  kind          VARCHAR(5)    NOT NULL DEFAULT 'bill',   -- bill or coin
  denomination  DECIMAL(10,2) NOT NULL,
  qty           INT           NOT NULL DEFAULT 0,
  amount        DECIMAL(15,2) NOT NULL DEFAULT 0,
  counted_by    INT UNSIGNED  NULL,
  created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_pcc_shift (shift_id),
  CONSTRAINT fk_pcc_shift FOREIGN KEY (shift_id) REFERENCES pos_shifts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS pos_readings;
CREATE TABLE pos_readings (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reading_type   ENUM('X','Z') NOT NULL,
  terminal_id    INT UNSIGNED NOT NULL,
  shift_id       INT UNSIGNED NOT NULL,
  z_no           INT UNSIGNED NULL,
  business_date  DATE         NOT NULL,
  first_receipt  VARCHAR(30)  NULL,
  last_receipt   VARCHAR(30)  NULL,
  sales_count    INT          NOT NULL DEFAULT 0,
  gross_sales    DECIMAL(15,2) NOT NULL DEFAULT 0,
  discounts      DECIMAL(15,2) NOT NULL DEFAULT 0,
  returns        DECIMAL(15,2) NOT NULL DEFAULT 0,
  voids          DECIMAL(15,2) NOT NULL DEFAULT 0,
  net_sales      DECIMAL(15,2) NOT NULL DEFAULT 0,
  tax            DECIMAL(15,2) NOT NULL DEFAULT 0,
  tenders_json   TEXT         NULL,
  cash_drops     DECIMAL(15,2) NOT NULL DEFAULT 0,
  expected_cash  DECIMAL(15,2) NOT NULL DEFAULT 0,
  counted_cash   DECIMAL(15,2) NULL,
  over_short     DECIMAL(15,2) NULL,
  created_by     INT UNSIGNED NOT NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_pr_term  FOREIGN KEY (terminal_id) REFERENCES pos_terminals(id),
  CONSTRAINT fk_pr_shift FOREIGN KEY (shift_id) REFERENCES pos_shifts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One-time approval codes a supervisor generates for a cashier or clerk (used once, then expired)
DROP TABLE IF EXISTS approval_codes;
CREATE TABLE approval_codes (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(12)  NOT NULL,
  purpose       VARCHAR(160) NULL,
  for_user_id   INT UNSIGNED NULL,          -- the user it is meant for (NULL: any user)
  page_key      VARCHAR(60)  NULL,          -- the page it may approve on (NULL: any page the issuer may approve on)
  max_amount    DECIMAL(15,2) NULL,
  status        VARCHAR(10)  NOT NULL DEFAULT 'open',   -- open / used / expired / cancelled
  issued_by     INT UNSIGNED NOT NULL,
  issued_at     DATETIME     NOT NULL,
  expires_at    DATETIME     NOT NULL,
  used_by       INT UNSIGNED NULL,
  used_at       DATETIME     NULL,
  used_on       VARCHAR(160) NULL,
  used_txn_id   BIGINT UNSIGNED NULL,
  cancelled_by  INT UNSIGNED NULL,
  cancelled_at  DATETIME     NULL,
  UNIQUE KEY uq_approval_codes_code (code),
  KEY ix_approval_codes_status (status, expires_at),
  KEY ix_approval_codes_issued (issued_by, issued_at),
  CONSTRAINT fk_apc_issuer FOREIGN KEY (issued_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  BANKING
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS bank_reconciliations;
CREATE TABLE bank_reconciliations (
  id                 INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  account_id         INT UNSIGNED NOT NULL,
  statement_date     DATE         NOT NULL,
  beginning_balance  DECIMAL(15,2) NOT NULL DEFAULT 0,
  ending_balance     DECIMAL(15,2) NOT NULL DEFAULT 0,
  cleared_balance    DECIMAL(15,2) NOT NULL DEFAULT 0,
  difference         DECIMAL(15,2) NOT NULL DEFAULT 0,
  service_charge_txn_id BIGINT UNSIGNED NULL,
  interest_txn_id    BIGINT UNSIGNED NULL,
  service_charge     DECIMAL(15,2) NOT NULL DEFAULT 0,
  service_date       DATE         NULL,
  service_account_id INT UNSIGNED NULL,
  interest_earned    DECIMAL(15,2) NOT NULL DEFAULT 0,
  interest_date      DATE         NULL,
  interest_account_id INT UNSIGNED NULL,
  class_id           INT UNSIGNED NULL,
  status             ENUM('in_progress','completed') NOT NULL DEFAULT 'in_progress',
  created_by         INT UNSIGNED NULL,
  created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_by       INT UNSIGNED NULL,
  completed_at       DATETIME     NULL,
  KEY ix_br_account (account_id, statement_date),
  CONSTRAINT fk_br_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Snapshot of the items cleared in each reconciliation (used by the reports)
DROP TABLE IF EXISTS reconciliation_items;
CREATE TABLE reconciliation_items (
  reconciliation_id INT UNSIGNED NOT NULL,
  txn_id            BIGINT UNSIGNED NOT NULL,
  amount            DECIMAL(15,2) NOT NULL,   -- + deposit / - payment
  cleared           TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (reconciliation_id, txn_id),
  CONSTRAINT fk_ri_rec FOREIGN KEY (reconciliation_id) REFERENCES bank_reconciliations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cleared transactions changed after reconciliation
DROP TABLE IF EXISTS reconciliation_discrepancies;
CREATE TABLE reconciliation_discrepancies (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reconciliation_id INT UNSIGNED NULL,
  account_id        INT UNSIGNED NOT NULL,
  txn_id            BIGINT UNSIGNED NOT NULL,
  txn_ref           VARCHAR(80)  NULL,
  change_type       VARCHAR(20)  NOT NULL,   -- amount changed, voided, deleted, uncleared
  cleared_amount    DECIMAL(15,2) NOT NULL DEFAULT 0,
  new_amount        DECIMAL(15,2) NOT NULL DEFAULT 0,
  changed_by        INT UNSIGNED NULL,
  changed_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_rd_account (account_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
--  SECURITY - site and terminal assignments
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS role_sites;
CREATE TABLE role_sites (
  role_id INT UNSIGNED NOT NULL,
  site_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, site_id),
  CONSTRAINT fk_rs_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  CONSTRAINT fk_rs_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS user_sites;
CREATE TABLE user_sites (
  user_id INT UNSIGNED NOT NULL,
  site_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, site_id),
  CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_us_site FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS user_terminals;
CREATE TABLE user_terminals (
  user_id     INT UNSIGNED NOT NULL,
  terminal_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, terminal_id),
  CONSTRAINT fk_ut_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ut_term FOREIGN KEY (terminal_id) REFERENCES pos_terminals(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  Memorized transactions, budgets and forecasts, report layouts,
--  CSV imports and database backups
-- ---------------------------------------------------------------------

DROP TABLE IF EXISTS memorized_txns;
CREATE TABLE memorized_txns (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(120) NOT NULL,
  group_name     VARCHAR(60)  NULL,
  txn_type       VARCHAR(30)  NOT NULL,
  entity_label   VARCHAR(160) NULL,               -- customer / supplier / payee, for the list
  amount         DECIMAL(15,2) NOT NULL DEFAULT 0,
  payload        LONGTEXT     NOT NULL,           -- the header and the lines of the saved transaction
  how            VARCHAR(20)  NOT NULL DEFAULT 'remind',   -- remind, auto, none (list only)
  frequency      VARCHAR(10)  NOT NULL DEFAULT 'monthly',  -- daily, weekly, months, quarterly, yearly
  every_n        INT          NOT NULL DEFAULT 1,
  next_date      DATE         NULL,
  days_in_advance INT         NOT NULL DEFAULT 5,
  remaining      INT          NULL,               -- how many are left to enter (NULL = no limit)
  end_date       DATE         NULL,
  last_entered   DATE         NULL,
  entered_count  INT          NOT NULL DEFAULT 0,
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  notes          VARCHAR(255) NULL,
  created_by     INT UNSIGNED NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     NULL,
  KEY ix_mt_due (is_active, next_date),
  KEY ix_mt_type (txn_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS budgets;
CREATE TABLE budgets (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(120) NOT NULL,
  kind          VARCHAR(10)  NOT NULL DEFAULT 'pl',   -- pl = income statement, bs = balance sheet, forecast = sales forecast
  fiscal_year   SMALLINT     NOT NULL,
  start_month   TINYINT      NOT NULL DEFAULT 1,      -- the month the fiscal year starts in
  class_id      INT UNSIGNED NULL,
  customer_id   INT UNSIGNED NULL,                    -- forecast for one customer (NULL = all customers)
  notes         VARCHAR(255) NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  created_by    INT UNSIGNED NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NULL,
  UNIQUE KEY uq_budget (kind, fiscal_year, name),
  KEY ix_budget_class (class_id),
  KEY ix_budget_customer (customer_id),
  CONSTRAINT fk_budget_class    FOREIGN KEY (class_id) REFERENCES classes(id),
  CONSTRAINT fk_budget_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS budget_lines;
CREATE TABLE budget_lines (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  budget_id    INT UNSIGNED NOT NULL,
  account_id   INT UNSIGNED NOT NULL,
  customer_id  INT UNSIGNED NULL,                 -- forecasts: the customer the amounts belong to
  period_month TINYINT      NOT NULL,             -- 1..12, counted from the start of the fiscal year
  amount       DECIMAL(15,2) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_budget_line (budget_id, account_id, customer_id, period_month),
  KEY ix_bl_account (account_id),
  CONSTRAINT fk_bl_budget   FOREIGN KEY (budget_id) REFERENCES budgets(id) ON DELETE CASCADE,
  CONSTRAINT fk_bl_account  FOREIGN KEY (account_id) REFERENCES accounts(id),
  CONSTRAINT fk_bl_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS report_layouts;
CREATE TABLE report_layouts (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  report_key   VARCHAR(60)  NOT NULL,
  name         VARCHAR(120) NOT NULL,
  title        VARCHAR(160) NULL,                 -- a heading of your own for the print-out
  columns      TEXT         NULL,                 -- key:Heading, one per line, in the order they print; a leading - means hidden
  options      TEXT         NULL,                 -- name=value, one per line: negatives, zeros, decimals, density and the rest
  is_shared    TINYINT(1)   NOT NULL DEFAULT 0,
  is_default   TINYINT(1)   NOT NULL DEFAULT 0,
  created_by   INT UNSIGNED NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NULL,
  KEY ix_rl_report (report_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS import_batches;
CREATE TABLE import_batches (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  import_type   VARCHAR(40)  NOT NULL,
  file_name     VARCHAR(190) NULL,
  rows_total    INT          NOT NULL DEFAULT 0,
  rows_ok       INT          NOT NULL DEFAULT 0,
  rows_failed   INT          NOT NULL DEFAULT 0,
  created_ids   LONGTEXT     NULL,                -- what the import created, so it can be traced
  messages      LONGTEXT     NULL,
  created_by    INT UNSIGNED NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_ib_type (import_type, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS backup_log;
CREATE TABLE backup_log (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  action       VARCHAR(10)  NOT NULL,             -- backup, restore
  file_name    VARCHAR(190) NOT NULL,
  file_size    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  tables_count INT          NOT NULL DEFAULT 0,
  rows_count   INT          NOT NULL DEFAULT 0,
  note         VARCHAR(255) NULL,
  created_by   INT UNSIGNED NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_bl_action (action, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS txn_attachment_chunks;
DROP TABLE IF EXISTS txn_attachments;
CREATE TABLE txn_attachments (
  id              INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id  BIGINT UNSIGNED NULL,                 -- empty while the form is not saved yet
  stage_key       VARCHAR(40)     NULL,                 -- the form session of a file not saved yet
  file_name       VARCHAR(255)    NOT NULL,
  mime_type       VARCHAR(150)    NOT NULL DEFAULT 'application/octet-stream',
  file_size       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  sha1            CHAR(40)        NULL,
  chunks          INT UNSIGNED    NOT NULL DEFAULT 0,
  uploaded_by     INT UNSIGNED    NULL,
  uploaded_at     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_ta_txn (transaction_id),
  KEY ix_ta_stage (stage_key),
  CONSTRAINT fk_ta_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE txn_attachment_chunks (
  attachment_id  INT UNSIGNED NOT NULL,
  seq            INT UNSIGNED NOT NULL,
  data           MEDIUMBLOB   NOT NULL,
  PRIMARY KEY (attachment_id, seq),
  CONSTRAINT fk_tac_att FOREIGN KEY (attachment_id) REFERENCES txn_attachments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_channels;
CREATE TABLE community_channels (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  slug           VARCHAR(40)  NOT NULL,
  name           VARCHAR(80)  NOT NULL,
  description    VARCHAR(255) NULL,
  kind           VARCHAR(12)  NOT NULL DEFAULT 'chat',        -- chat, announcement
  post_policy    VARCHAR(12)  NOT NULL DEFAULT 'everyone',    -- everyone, moderators
  is_restricted  TINYINT(1)   NOT NULL DEFAULT 0,             -- 1: only the roles in community_channel_roles (and moderators)
  is_archived    TINYINT(1)   NOT NULL DEFAULT 0,
  sort_order     INT          NOT NULL DEFAULT 0,
  created_by     INT UNSIGNED NULL,
  created_at     DATETIME     NOT NULL,
  updated_at     DATETIME     NULL,
  UNIQUE KEY uq_cch_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_channel_roles;
CREATE TABLE community_channel_roles (
  channel_id  INT UNSIGNED NOT NULL,
  role_id     INT UNSIGNED NOT NULL,
  PRIMARY KEY (channel_id, role_id),
  CONSTRAINT fk_ccr_channel FOREIGN KEY (channel_id) REFERENCES community_channels(id) ON DELETE CASCADE,
  CONSTRAINT fk_ccr_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_members;
CREATE TABLE community_members (
  channel_id    INT UNSIGNED NOT NULL,
  user_id       INT UNSIGNED NOT NULL,
  last_read_id  INT UNSIGNED NOT NULL DEFAULT 0,
  notify        VARCHAR(10)  NOT NULL DEFAULT 'mentions',     -- all, mentions, none
  joined_at     DATETIME     NOT NULL,
  PRIMARY KEY (channel_id, user_id),
  KEY ix_cm_user (user_id),
  CONSTRAINT fk_cm_channel FOREIGN KEY (channel_id) REFERENCES community_channels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_messages;
CREATE TABLE community_messages (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  channel_id     INT UNSIGNED NOT NULL,
  user_id        INT UNSIGNED NOT NULL,
  body           TEXT         NULL,
  reply_to_id    INT UNSIGNED NULL,
  client_key     VARCHAR(40)  NULL,                            -- the sender's own key: a message sent twice is kept once
  is_official    TINYINT(1)   NOT NULL DEFAULT 0,              -- posted by a moderator as an announcement
  is_pinned      TINYINT(1)   NOT NULL DEFAULT 0,
  pinned_by      INT UNSIGNED NULL,
  pinned_at      DATETIME     NULL,
  is_hidden      TINYINT(1)   NOT NULL DEFAULT 0,
  hidden_by      INT UNSIGNED NULL,
  hidden_reason  VARCHAR(255) NULL,
  edited_at      DATETIME     NULL,
  deleted_at     DATETIME     NULL,
  deleted_by     INT UNSIGNED NULL,
  created_at     DATETIME     NOT NULL,
  updated_at     DATETIME     NOT NULL,
  KEY ix_cmsg_channel (channel_id, id),
  KEY ix_cmsg_changed (channel_id, updated_at),
  KEY ix_cmsg_user (user_id, created_at),
  UNIQUE KEY uq_cmsg_client (user_id, client_key),
  CONSTRAINT fk_cmsg_channel FOREIGN KEY (channel_id) REFERENCES community_channels(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_reactions;
CREATE TABLE community_reactions (
  message_id  INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL,
  emoji       VARCHAR(16)  NOT NULL,
  created_at  DATETIME     NOT NULL,
  PRIMARY KEY (message_id, user_id, emoji),
  CONSTRAINT fk_crx_message FOREIGN KEY (message_id) REFERENCES community_messages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_files;
CREATE TABLE community_files (
  id          INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  owner_type  VARCHAR(12)     NOT NULL DEFAULT 'pending',     -- pending, message, dm, inquiry, response, avatar
  owner_id    INT UNSIGNED    NULL,
  user_id     INT UNSIGNED    NOT NULL,
  file_name   VARCHAR(255)    NOT NULL,
  mime_type   VARCHAR(150)    NOT NULL DEFAULT 'application/octet-stream',
  file_size   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  is_image    TINYINT(1)      NOT NULL DEFAULT 0,
  chunks      INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at  DATETIME        NOT NULL,
  KEY ix_cf_owner (owner_type, owner_id),
  KEY ix_cf_user (user_id, owner_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_file_chunks;
CREATE TABLE community_file_chunks (
  file_id  INT UNSIGNED NOT NULL,
  seq      INT UNSIGNED NOT NULL,
  data     MEDIUMBLOB   NOT NULL,
  PRIMARY KEY (file_id, seq),
  CONSTRAINT fk_cfc_file FOREIGN KEY (file_id) REFERENCES community_files(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_inquiry_categories;
CREATE TABLE community_inquiry_categories (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(80)  NOT NULL,
  description  VARCHAR(255) NULL,
  sort_order   INT          NOT NULL DEFAULT 0,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_cic_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_inquiries;
CREATE TABLE community_inquiries (
  id                    INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  category_id           INT UNSIGNED NULL,
  user_id               INT UNSIGNED NOT NULL,
  title                 VARCHAR(200) NOT NULL,
  body                  TEXT         NOT NULL,
  status                VARCHAR(10)  NOT NULL DEFAULT 'open',   -- open, answered, resolved
  accepted_response_id  INT UNSIGNED NULL,
  response_count        INT UNSIGNED NOT NULL DEFAULT 0,
  views                 INT UNSIGNED NOT NULL DEFAULT 0,
  client_key            VARCHAR(40)  NULL,
  is_hidden             TINYINT(1)   NOT NULL DEFAULT 0,
  hidden_by             INT UNSIGNED NULL,
  hidden_reason         VARCHAR(255) NULL,
  resolved_by           INT UNSIGNED NULL,
  resolved_at           DATETIME     NULL,
  edited_at             DATETIME     NULL,
  last_activity_at      DATETIME     NOT NULL,
  created_at            DATETIME     NOT NULL,
  KEY ix_ci_status (status, last_activity_at),
  KEY ix_ci_category (category_id),
  KEY ix_ci_user (user_id, created_at),
  UNIQUE KEY uq_ci_client (user_id, client_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_inquiry_responses;
CREATE TABLE community_inquiry_responses (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  inquiry_id     INT UNSIGNED NOT NULL,
  user_id        INT UNSIGNED NOT NULL,
  parent_id      INT UNSIGNED NULL,                            -- a comment on a response
  body           TEXT         NOT NULL,
  is_official    TINYINT(1)   NOT NULL DEFAULT 0,              -- given by a moderator as the official answer
  client_key     VARCHAR(40)  NULL,
  is_hidden      TINYINT(1)   NOT NULL DEFAULT 0,
  hidden_by      INT UNSIGNED NULL,
  hidden_reason  VARCHAR(255) NULL,
  edited_at      DATETIME     NULL,
  deleted_at     DATETIME     NULL,
  created_at     DATETIME     NOT NULL,
  KEY ix_cir_inquiry (inquiry_id, id),
  KEY ix_cir_user (user_id, created_at),
  UNIQUE KEY uq_cir_client (user_id, client_key),
  CONSTRAINT fk_cir_inquiry FOREIGN KEY (inquiry_id) REFERENCES community_inquiries(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_conversations;
CREATE TABLE community_conversations (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_a           INT UNSIGNED NOT NULL,                      -- the smaller user id
  user_b           INT UNSIGNED NOT NULL,
  a_last_read      INT UNSIGNED NOT NULL DEFAULT 0,
  b_last_read      INT UNSIGNED NOT NULL DEFAULT 0,
  last_message_id  INT UNSIGNED NOT NULL DEFAULT 0,
  last_message_at  DATETIME     NULL,
  created_at       DATETIME     NOT NULL,
  UNIQUE KEY uq_cconv_pair (user_a, user_b),
  KEY ix_cconv_b (user_b)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_dm_messages;
CREATE TABLE community_dm_messages (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  conversation_id  INT UNSIGNED NOT NULL,
  sender_id        INT UNSIGNED NOT NULL,
  body             TEXT         NULL,
  reply_to_id      INT UNSIGNED NULL,
  client_key       VARCHAR(40)  NULL,
  edited_at        DATETIME     NULL,
  deleted_at       DATETIME     NULL,
  created_at       DATETIME     NOT NULL,
  updated_at       DATETIME     NOT NULL,
  KEY ix_cdm_conv (conversation_id, id),
  KEY ix_cdm_changed (conversation_id, updated_at),
  KEY ix_cdm_sender (sender_id, created_at),
  UNIQUE KEY uq_cdm_client (sender_id, client_key),
  CONSTRAINT fk_cdm_conv FOREIGN KEY (conversation_id) REFERENCES community_conversations(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_blocks;
CREATE TABLE community_blocks (
  user_id     INT UNSIGNED NOT NULL,
  blocked_id  INT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL,
  PRIMARY KEY (user_id, blocked_id),
  KEY ix_cb_blocked (blocked_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_settings;
CREATE TABLE community_settings (
  user_id               INT UNSIGNED NOT NULL PRIMARY KEY,
  dm_policy             VARCHAR(12)  NOT NULL DEFAULT 'everyone',  -- everyone, moderators, nobody
  avatar_file_id        INT UNSIGNED NULL,
  notify_mentions       TINYINT(1)   NOT NULL DEFAULT 1,
  notify_dm             TINYINT(1)   NOT NULL DEFAULT 1,
  notify_announcements  TINYINT(1)   NOT NULL DEFAULT 1,
  notify_inquiries      TINYINT(1)   NOT NULL DEFAULT 1,
  last_seen_at          DATETIME     NULL,
  updated_at            DATETIME     NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_notifications;
CREATE TABLE community_notifications (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  kind        VARCHAR(20)  NOT NULL,     -- mention, reply, dm, response, official, accepted, announcement, resolved
  actor_id    INT UNSIGNED NULL,
  text        VARCHAR(255) NOT NULL,
  url         VARCHAR(255) NOT NULL,
  dedupe_key  VARCHAR(80)  NOT NULL,     -- one notification per thing: a second one only refreshes it
  is_read     TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  DATETIME     NOT NULL,
  UNIQUE KEY uq_cn_dedupe (user_id, dedupe_key),
  KEY ix_cn_user (user_id, is_read, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_reports;
CREATE TABLE community_reports (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reporter_id     INT UNSIGNED NOT NULL,
  target_type     VARCHAR(12)  NOT NULL,     -- message, dm, inquiry, response, user
  target_id       INT UNSIGNED NOT NULL,
  target_user_id  INT UNSIGNED NULL,
  reason          VARCHAR(40)  NOT NULL,
  details         VARCHAR(500) NULL,
  snapshot        TEXT         NULL,         -- the words reported, as they were (a private message is seen only through this)
  status          VARCHAR(10)  NOT NULL DEFAULT 'open',   -- open, actioned, dismissed
  handled_by      INT UNSIGNED NULL,
  handled_at      DATETIME     NULL,
  resolution      VARCHAR(255) NULL,
  created_at      DATETIME     NOT NULL,
  KEY ix_crep_status (status, id),
  KEY ix_crep_target (target_type, target_id),
  KEY ix_crep_reporter (reporter_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_sanctions;
CREATE TABLE community_sanctions (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id     INT UNSIGNED NOT NULL,
  kind        VARCHAR(10)  NOT NULL,         -- mute (may read, may not post), suspend (no community at all)
  reason      VARCHAR(255) NOT NULL,
  ends_at     DATETIME     NULL,             -- empty: until lifted
  created_by  INT UNSIGNED NOT NULL,
  created_at  DATETIME     NOT NULL,
  lifted_by   INT UNSIGNED NULL,
  lifted_at   DATETIME     NULL,
  KEY ix_cs_user (user_id, kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS community_mod_log;
CREATE TABLE community_mod_log (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  moderator_id    INT UNSIGNED NOT NULL,
  action          VARCHAR(30)  NOT NULL,
  target_type     VARCHAR(20)  NULL,
  target_id       INT UNSIGNED NULL,
  target_user_id  INT UNSIGNED NULL,
  reason          VARCHAR(255) NULL,
  detail          TEXT         NULL,
  created_at      DATETIME     NOT NULL,
  KEY ix_cml_created (created_at),
  KEY ix_cml_target_user (target_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- v42: digital voucher signatures (migration 2027_02_11)

DROP TABLE IF EXISTS voucher_sign_requests;
CREATE TABLE voucher_sign_requests (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id   BIGINT UNSIGNED NOT NULL,
  slot             VARCHAR(12)     NOT NULL,                 -- prepared, checked, approved, received
  signer_name      VARCHAR(120)    NOT NULL,
  signer_email     VARCHAR(160)    NULL,
  message          VARCHAR(255)    NULL,
  token_hash       CHAR(64)        NOT NULL,                 -- SHA-256 of the secret part of the link
  token_enc        VARCHAR(255)    NULL,                     -- the link, encrypted, so it can be copied again
  status           VARCHAR(10)     NOT NULL DEFAULT 'pending', -- pending, signed, revoked, expired
  expires_at       DATETIME        NOT NULL,
  created_by       INT UNSIGNED    NULL,
  created_at       DATETIME        NOT NULL,
  first_opened_at  DATETIME        NULL,
  last_opened_at   DATETIME        NULL,
  open_count       INT UNSIGNED    NOT NULL DEFAULT 0,
  revoked_by       INT UNSIGNED    NULL,
  revoked_at       DATETIME        NULL,
  revoke_reason    VARCHAR(255)    NULL,
  signed_at        DATETIME        NULL,
  signature_id     INT UNSIGNED    NULL,
  UNIQUE KEY uq_vsr_token (token_hash),
  KEY ix_vsr_txn (transaction_id, status),
  CONSTRAINT fk_vsr_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS voucher_signatures;
CREATE TABLE voucher_signatures (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id   BIGINT UNSIGNED NOT NULL,
  slot             VARCHAR(12)     NOT NULL,
  signer_name      VARCHAR(120)    NOT NULL,
  signer_user_id   INT UNSIGNED    NULL,                     -- signed in the system
  request_id       INT UNSIGNED    NULL,                     -- signed through a link
  method           VARCHAR(8)      NOT NULL DEFAULT 'internal', -- internal, link
  strokes          MEDIUMTEXT      NOT NULL,                 -- the drawing: {"w":..,"h":..,"s":[[x,y,x,y,...],...]}
  doc_hash         CHAR(64)        NOT NULL,                 -- SHA-256 of the voucher content that was signed
  ip_address       VARCHAR(45)     NULL,
  user_agent       VARCHAR(255)    NULL,
  signed_at        DATETIME        NOT NULL,
  is_active        TINYINT(1)      NULL DEFAULT 1,           -- 1 = on the voucher; empty once reset
  cleared_by       INT UNSIGNED    NULL,
  cleared_at       DATETIME        NULL,
  clear_reason     VARCHAR(255)    NULL,
  UNIQUE KEY uq_vs_slot (transaction_id, slot, is_active),  -- one active signature per line
  KEY ix_vs_user (signer_user_id),
  CONSTRAINT fk_vs_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS voucher_documents;
CREATE TABLE voucher_documents (
  id               INT UNSIGNED    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  transaction_id   BIGINT UNSIGNED NOT NULL,
  kind             VARCHAR(8)      NOT NULL,                 -- original, signed
  version          INT UNSIGNED    NOT NULL DEFAULT 1,
  file_name        VARCHAR(160)    NOT NULL,
  file_size        INT UNSIGNED    NOT NULL DEFAULT 0,
  sha256           CHAR(64)        NOT NULL,
  doc_hash         CHAR(64)        NULL,
  signature_count  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  chunks           INT UNSIGNED    NOT NULL DEFAULT 0,
  created_by       INT UNSIGNED    NULL,
  created_note     VARCHAR(160)    NULL,
  created_at       DATETIME        NOT NULL,
  KEY ix_vd_txn (transaction_id, kind, version),
  CONSTRAINT fk_vd_txn FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS voucher_document_chunks;
CREATE TABLE voucher_document_chunks (
  document_id  INT UNSIGNED NOT NULL,
  seq          INT UNSIGNED NOT NULL,
  data         MEDIUMBLOB   NOT NULL,
  PRIMARY KEY (document_id, seq),
  CONSTRAINT fk_vdc_doc FOREIGN KEY (document_id) REFERENCES voucher_documents(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
--  DISTRIBUTION: supplier items, supplier allocations and pick-ups, crates
-- ---------------------------------------------------------------------

-- The items a supplier delivers, in the unit they are allocated in (crates, kilos or packs)
DROP TABLE IF EXISTS vendor_items;
CREATE TABLE vendor_items (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  vendor_id    INT UNSIGNED NOT NULL,
  item_id      INT UNSIGNED NOT NULL,
  uom_id       INT UNSIGNED NULL,                 -- the unit the item is allocated and picked up in
  vendor_code  VARCHAR(40)  NULL,                 -- the supplier's own code for the item
  last_cost    DECIMAL(15,4) NOT NULL DEFAULT 0,  -- cost per base unit, used for the receipt of a pick-up
  sort_order   INT          NOT NULL DEFAULT 0,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  UNIQUE KEY uq_vendor_items (vendor_id, item_id),
  KEY ix_vendor_items_item (item_id),
  CONSTRAINT fk_vi_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE CASCADE,
  CONSTRAINT fk_vi_item   FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_vi_uom    FOREIGN KEY (uom_id) REFERENCES uom_units(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- What is to be picked up from a supplier on a day, at a location, by whom
DROP TABLE IF EXISTS supplier_allocations;
CREATE TABLE supplier_allocations (
  id               INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  alloc_no         VARCHAR(20)  NOT NULL,
  alloc_date       DATE         NOT NULL,
  vendor_id        INT UNSIGNED NOT NULL,
  site_id          INT UNSIGNED NOT NULL,           -- the location the goods are received at
  assigned_user_id INT UNSIGNED NULL,               -- the user who picks it up
  assigned_to      VARCHAR(80)  NULL,               -- or a name typed in (driver, helper)
  class_id         INT UNSIGNED NULL,
  status           VARCHAR(12)  NOT NULL DEFAULT 'open',   -- open, picking, received, cancelled
  memo             VARCHAR(255) NULL,
  picked_at        DATETIME     NULL,
  picked_by        INT UNSIGNED NULL,
  receipt_txn_id   BIGINT UNSIGNED NULL,            -- the item receipt made by "Pick-up complete"
  created_by       INT UNSIGNED NULL,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     NULL,
  UNIQUE KEY uq_alloc_no (alloc_no),
  KEY ix_alloc_date (alloc_date, status),
  KEY ix_alloc_vendor (vendor_id),
  CONSTRAINT fk_alloc_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id),
  CONSTRAINT fk_alloc_site   FOREIGN KEY (site_id) REFERENCES sites(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TABLE IF EXISTS supplier_allocation_lines;
CREATE TABLE supplier_allocation_lines (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  allocation_id INT UNSIGNED NOT NULL,
  line_no       INT          NOT NULL DEFAULT 0,
  item_id       INT UNSIGNED NOT NULL,
  uom_id        INT UNSIGNED NULL,
  unit_code     VARCHAR(20)  NULL,
  qty           DECIMAL(15,4) NOT NULL DEFAULT 0,  -- allocated, in the line's unit (crates, kilos, packs)
  picked        TINYINT(1)   NOT NULL DEFAULT 0,   -- ticked as picked up
  picked_count  DECIMAL(15,4) NOT NULL DEFAULT 0,  -- crates (or units) actually picked up
  picked_qty    DECIMAL(15,4) NOT NULL DEFAULT 0,  -- base units (kilos, packs) actually picked up
  rate          DECIMAL(15,4) NOT NULL DEFAULT 0,  -- cost per base unit on the receipt
  receipt_line_id BIGINT UNSIGNED NULL,
  KEY ix_alloc_lines (allocation_id, line_no),
  CONSTRAINT fk_al_alloc FOREIGN KEY (allocation_id) REFERENCES supplier_allocations(id) ON DELETE CASCADE,
  CONSTRAINT fk_al_item  FOREIGN KEY (item_id) REFERENCES items(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Crate by crate details typed at pick-up (number, heads, weight, production and expiry dates)
DROP TABLE IF EXISTS supplier_allocation_crates;
CREATE TABLE supplier_allocation_crates (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  line_id         INT UNSIGNED NOT NULL,
  seq             INT          NOT NULL DEFAULT 0,
  crate_no        VARCHAR(30)  NOT NULL,
  pcs             DECIMAL(12,2) NOT NULL DEFAULT 0,
  qty             DECIMAL(15,4) NOT NULL DEFAULT 0,  -- base units in the crate (kilos or packs)
  production_date DATE NULL,
  expiry_date     DATE NULL,
  KEY ix_alloc_crates (line_id, seq),
  CONSTRAINT fk_ac_line FOREIGN KEY (line_id) REFERENCES supplier_allocation_lines(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every crate received: the kilos (or packs) in it, what is left, its dates. A crate converted to kilos
-- is no longer followed: its stock stays on hand as loose kilos.
DROP TABLE IF EXISTS crates;
CREATE TABLE crates (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  crate_no        VARCHAR(30)  NOT NULL,
  item_id         INT UNSIGNED NOT NULL,
  site_id         INT UNSIGNED NOT NULL,
  vendor_id       INT UNSIGNED NULL,
  receive_txn_id  BIGINT UNSIGNED NULL,
  receive_line_id BIGINT UNSIGNED NULL,
  allocation_id   INT UNSIGNED NULL,
  received_date   DATE         NOT NULL,
  pcs             DECIMAL(12,2) NOT NULL DEFAULT 0,  -- heads / pieces in the crate
  qty_in          DECIMAL(15,4) NOT NULL DEFAULT 0,  -- base units received (kilos or packs)
  qty_left        DECIMAL(15,4) NOT NULL DEFAULT 0,  -- base units still in the crate
  unit_cost       DECIMAL(15,4) NOT NULL DEFAULT 0,
  production_date DATE NULL,
  expiry_date     DATE NULL,
  status          VARCHAR(10)  NOT NULL DEFAULT 'open',  -- open, sold, converted, used (emptied by shrinkage, shortage or an adjustment)
  converted_at    DATETIME     NULL,
  converted_by    INT UNSIGNED NULL,
  convert_note    VARCHAR(255) NULL,
  created_by      INT UNSIGNED NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_crates_item (item_id, site_id, status),
  KEY ix_crates_no (crate_no, status),
  KEY ix_crates_receive (receive_txn_id),
  KEY ix_crates_line (receive_line_id),
  KEY ix_crates_expiry (expiry_date),
  CONSTRAINT fk_crates_item FOREIGN KEY (item_id) REFERENCES items(id),
  CONSTRAINT fk_crates_site FOREIGN KEY (site_id) REFERENCES sites(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- What happened to each crate: received, sold whole, kilos taken out, moved, converted to kilos
DROP TABLE IF EXISTS crate_movements;
CREATE TABLE crate_movements (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  crate_id    BIGINT UNSIGNED NOT NULL,
  move_date   DATE         NOT NULL,
  kind        VARCHAR(10)  NOT NULL,       -- receive, sale, auto, transfer, convert, shrink, shortage
  txn_id      BIGINT UNSIGNED NULL,
  line_id     BIGINT UNSIGNED NULL,
  qty         DECIMAL(15,4) NOT NULL DEFAULT 0,  -- base units taken out (received: put in)
  whole       TINYINT(1)   NOT NULL DEFAULT 0,   -- the whole crate went with the sale
  site_id     INT UNSIGNED NULL,
  site2_id    INT UNSIGNED NULL,                 -- transfer: the site it went to
  customer_id INT UNSIGNED NULL,
  note        VARCHAR(255) NULL,
  created_by  INT UNSIGNED NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_cm_crate (crate_id, id),
  KEY ix_cm_txn (txn_id),
  KEY ix_cm_line (line_id),
  KEY ix_cm_date (move_date),
  CONSTRAINT fk_cm_crate FOREIGN KEY (crate_id) REFERENCES crates(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------------------------------------------------
-- Distribution (v2): Inventory Transfer Closing. The van salesman (or an outlet) remits the day and sends back what
-- is left; each line is a crate or an item, with what was on hand, what came back and the difference, split into
-- shrinkage (adjusted to the shrinkage account) and shortage (charged to the employee as a receivable, at cost).
-- ---------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS transfer_closing_lines;
DROP TABLE IF EXISTS transfer_closings;
CREATE TABLE transfer_closings (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  closing_no          VARCHAR(30)  NOT NULL,
  closing_date        DATE         NOT NULL,
  from_site_id        INT UNSIGNED NOT NULL,              -- the van or outlet closed
  to_site_id          INT UNSIGNED NOT NULL,              -- the warehouse or cold storage the stock goes back to
  sales_rep_id        INT UNSIGNED NULL,                  -- the van salesman or cashier who remits
  customer_id         INT UNSIGNED NULL,                  -- who the shortage is charged to (the employee as a customer)
  shrink_account_id   INT UNSIGNED NULL,
  shortage_account_id INT UNSIGNED NULL,
  transferred_by      VARCHAR(80)  NULL,
  checked_by          VARCHAR(80)  NULL,
  received_by         VARCHAR(80)  NULL,
  memo                VARCHAR(255) NULL,
  transfer_txn_id     BIGINT UNSIGNED NULL,               -- the inventory transfer back
  shrink_txn_id       BIGINT UNSIGNED NULL,               -- the inventory adjustment for the shrinkage
  shortage_txn_id     BIGINT UNSIGNED NULL,               -- the shortage charge
  balance_qty         DECIMAL(15,4) NOT NULL DEFAULT 0,
  transfer_qty        DECIMAL(15,4) NOT NULL DEFAULT 0,
  shrink_qty          DECIMAL(15,4) NOT NULL DEFAULT 0,
  shortage_qty        DECIMAL(15,4) NOT NULL DEFAULT 0,
  shrink_amount       DECIMAL(15,2) NOT NULL DEFAULT 0,
  shortage_amount     DECIMAL(15,2) NOT NULL DEFAULT 0,
  status              VARCHAR(10)  NOT NULL DEFAULT 'posted',   -- posted, void
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

CREATE TABLE transfer_closing_lines (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  closing_id   INT UNSIGNED NOT NULL,
  line_no      INT          NOT NULL DEFAULT 0,
  item_id      INT UNSIGNED NOT NULL,
  crate_id     BIGINT UNSIGNED NULL,                      -- a crate line: one crate (else the item's stock outside crates)
  crate_no     VARCHAR(30)  NULL,
  unit         VARCHAR(20)  NULL,
  balance      DECIMAL(15,4) NOT NULL DEFAULT 0,          -- on hand at the van / outlet when closed
  transfer_qty DECIMAL(15,4) NOT NULL DEFAULT 0,          -- came back (crates, kilos, packs ...)
  shrink_qty   DECIMAL(15,4) NOT NULL DEFAULT 0,
  shortage_qty DECIMAL(15,4) NOT NULL DEFAULT 0,
  unit_cost    DECIMAL(15,4) NOT NULL DEFAULT 0,
  note         VARCHAR(255) NULL,
  KEY ix_tcl_closing (closing_id),
  KEY ix_tcl_item (item_id),
  KEY ix_tcl_crate (crate_id),
  CONSTRAINT fk_tcl_closing FOREIGN KEY (closing_id) REFERENCES transfer_closings(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- v9: the checks customers pay with (POS account payments, Receive Payments): the Check Registry.
-- A post-dated check is kept here only (status pending, no payment) until its date: then its payment is recorded.
DROP TABLE IF EXISTS customer_checks;
CREATE TABLE customer_checks (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  customer_id       INT UNSIGNED NOT NULL,
  payment_txn_id    BIGINT UNSIGNED NULL,                  -- the payment (NULL while post-dated)
  source            VARCHAR(10)  NOT NULL DEFAULT 'payment', -- pos, payment (Receive Payments)
  terminal_id       INT UNSIGNED NULL,
  pos_shift_id      INT UNSIGNED NULL,                     -- the shift it was received in (Receipt of Post Dated Check)
  site_id           INT UNSIGNED NULL,
  bank              VARCHAR(80)  NOT NULL,
  check_no          VARCHAR(40)  NOT NULL,
  check_date        DATE         NOT NULL,
  amount            DECIMAL(15,2) NOT NULL DEFAULT 0,
  received_date     DATE         NOT NULL,
  status            VARCHAR(12)  NOT NULL DEFAULT 'pending', -- pending, on_date, cleared, returned
  payment_method_id INT UNSIGNED NULL,
  account_id        INT UNSIGNED NULL,                     -- the account the payment goes to
  class_id          INT UNSIGNED NULL,
  memo              VARCHAR(255) NULL,
  apply_json        TEXT         NULL,                     -- post-dated: the invoices it pays [{"id":..,"amount":..}]
  recorded_at       DATETIME     NULL,
  cleared_date      DATE         NULL,
  returned_date     DATE         NULL,
  return_txn_id     BIGINT UNSIGNED NULL,                  -- the statement charge of a returned check
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
--  2. DATA
-- ---------------------------------------------------------------------

-- settings (54 rows)
INSERT INTO `settings` (`setting_key`,`setting_value`,`updated_at`) VALUES
('adopt_group_price','1','2026-11-27 00:03:03'),
('allow_negative_stock','1','2026-11-27 00:03:03'),
('audit_retention_years','10','2026-11-27 00:03:03'),
('auto_recost_limit','2000','2026-11-27 00:03:03'),
('auto_recost_scope','process','2026-11-27 00:03:03'),
('bir_signatory_name','','2026-11-27 00:03:03'),
('bir_signatory_tin','','2026-11-27 00:03:03'),
('bir_signatory_title','','2026-11-27 00:03:03'),
('bir_zip_code','','2026-11-27 00:03:03'),
('block_expired_sales','0','2026-11-27 00:03:03'),
('block_zero_cost_processing','1','2026-11-27 00:03:03'),
('block_zero_cost_sales','1','2026-11-27 00:03:03'),
('bt_printer_autoprint','0','2026-11-27 00:03:03'),
('bt_printer_cut','0','2026-11-27 00:03:03'),
('bt_printer_enabled','0','2026-11-27 00:03:03'),
('bt_printer_feed','4','2026-11-27 00:03:03'),
('bt_printer_name','','2026-11-27 00:03:03'),
('bt_printer_width','32','2026-11-27 00:03:03'),
('closing_date','','2026-11-27 00:03:03'),
('company_address','Company address','2026-11-27 00:03:04'),
('company_email','','2026-11-27 00:03:04'),
('company_logo','','2026-11-27 00:03:03'),
('company_name','Your Company Name','2026-11-27 00:03:04'),
('company_phone','','2026-11-27 00:03:04'),
('company_tin','','2026-11-27 00:03:04'),
('costing_method','weighted_average','2026-11-27 00:03:03'),
('expiry_warn_days','30','2026-11-27 00:03:03'),
('finance_charge_grace_days','0','2026-11-27 00:03:03'),
('finance_charge_min','50','2026-11-27 00:03:03'),
('finance_charge_on_charges','0','2026-11-27 00:03:03'),
('finance_charge_rate','12','2026-11-27 00:03:03'),
('fiscal_year_start_month','1','2026-11-27 00:03:03'),
('item_search_by_page','','2026-11-27 00:03:03'),
('item_search_format','code_name','2026-11-27 00:03:03'),
('large_discount_pct','10','2026-11-27 00:03:03'),
('logo_targets','','2026-11-27 00:03:03'),
('max_failed_logins','5','2026-11-27 00:03:03'),
('pos_posting_mode','per_sale','2026-11-27 00:03:03'),
('pos_receipt_footer','Thank you for shopping!\nThis serves as your official receipt.','2026-11-27 00:03:03'),
('pos_receipt_show_customer','1','2026-11-27 00:03:03'),
('pos_receipt_title','OFFICIAL RECEIPT','2026-11-27 00:03:03'),
('pos_receipt_title_charge','CHARGE INVOICE','2026-11-27 00:03:03'),
('pos_receipt_title_payment','ACKNOWLEDGEMENT RECEIPT','2026-11-27 00:03:03'),
('pos_receipt_title_return','RETURN / REFUND','2026-11-27 00:03:03'),
('processing_cost_tolerance','2','2026-11-27 00:03:03'),
('pw_expiry_days','90','2026-11-27 00:03:03'),
('pw_min_length','8','2026-11-27 00:03:03'),
('pw_require_number','1','2026-11-27 00:03:03'),
('pw_require_symbol','1','2026-11-27 00:03:03'),
('pw_require_upper','1','2026-11-27 00:03:03'),
('session_timeout_minutes','30','2026-11-27 00:03:03'),
('track_expiry','0','2026-11-27 00:03:03'),
('track_group_sales','1','2026-11-27 00:03:03'),
('withholding_agent','1','2026-11-27 00:03:03');

-- users (11 rows)
INSERT INTO `users` (`id`,`username`,`password_hash`,`full_name`,`email`,`employee_no`,`pos_default_site_id`,`pos_default_class_id`,`status`,`approval_status`,`created_via`,`approved_by`,`approved_at`,`rejected_reason`,`is_platform`,`must_change_password`,`password_changed_at`,`failed_attempts`,`last_login_at`,`last_login_ip`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'admin','$2y$10$cHiijKeunmOl1OcqdXN7f.oLagbGAVgLRj/mSp98iZnip5yiGDpT2','System Administrator','admin@northpoint.test','EMP-001',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,1,'2026-11-27 00:03:03',0,NULL,NULL,NULL,'2026-11-27 00:03:03',NULL),
(2,'accountant','$2y$10$GMwU5eH1ZQlAcY/T27ubwuN2ea7Ki4tWXBKZ5UyedcSIqnoqqYrKS','Ana Cruz','accountant@northpoint.test','EMP-002',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:03',0,NULL,NULL,NULL,'2026-11-27 00:03:03',NULL),
(3,'arclerk','$2y$10$ljoRuLBYGs9YyXR1Wfk11eXlbDVBZ2x4YxGx0a9LJP1MzR.Ub6xm.','Ben Garcia','arclerk@northpoint.test','EMP-003',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:03',0,NULL,NULL,NULL,'2026-11-27 00:03:03',NULL),
(4,'apclerk','$2y$10$z1204GpihkYsUhSyOOdl5.nj4Mx.xioaFrTv9plkNBWYwoIIEJC2u','Carla Lim','apclerk@northpoint.test','EMP-004',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:03',0,NULL,NULL,NULL,'2026-11-27 00:03:03',NULL),
(5,'invclerk','$2y$10$aZpVxtXjfYSb6KezO0nUTun8J74Sdn3sZfVqJQLhcsmGaR9BPpw06','Dan Villanueva','invclerk@northpoint.test','EMP-005',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL),
(6,'allocator','$2y$10$uhjBTLkmBIkjdcjkktaG/OZ18iLKrCrTRfob5GjBrYmPvZFDygttO','Lito Bautista','allocator@northpoint.test','EMP-006',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL),
(7,'salesrep','$2y$10$Ddq9SJU87y1PtA.h0O4SpuVc8Tnir5i67BhVB3Jd6VjpAbV0b/A92','Maria Santos','salesrep@northpoint.test','EMP-007',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL),
(8,'supervisor','$2y$10$MibvPqHk1NVL0OCvSZTyte3WD/nYtNK72Ug7LdaCdudAJalH2xlKq','Fred Tan','supervisor@northpoint.test','EMP-008',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL),
(9,'cashier1','$2y$10$JnWV85N9rTLJymfsV3lvYuVBGDaxynxIgV2WTuQHzG7rm1iH.48d6','Ella Ramos','cashier1@northpoint.test','EMP-009',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL),
(10,'glenn','$2y$10$YxlvzzOT5Rvy/snmD5.6K.2a3GQGLUNabJCYIIZrR0YscfQfGfsLK','Glenn Abad','glenn@northpoint.test','EMP-010',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL),
(11,'auditor','$2y$10$o2TS29vqd1POkTSqntAWHuYxwYZSYZuFl0FUPbmQ3hDybPtTfNvYG','Grace Uy','auditor@northpoint.test','EMP-011',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04',NULL);

-- roles (11 rows)
INSERT INTO `roles` (`id`,`name`,`description`,`is_admin`,`is_system`,`all_sites`,`created_at`,`updated_at`) VALUES
(1,'Administrator','Everything in every module, including user accounts, roles, page access, the closing date, and the audit trail.',1,1,1,'2026-11-27 00:03:03',NULL),
(2,'Accountant','Chart of Accounts, Fixed Assets, Banking and reconciliation, the BIR Reports and Withholding Tax Table, all module reports, and the financial statements.',0,1,1,'2026-11-27 00:03:03',NULL),
(3,'A/R Clerk','Customers module transactions and the Customer and Receivables reports.',0,1,1,'2026-11-27 00:03:03',NULL),
(4,'A/P Clerk','Vendors module transactions, Pay Bills, advances to suppliers, the Vendors and Payables reports, and BIR Form 2307 for suppliers.',0,1,1,'2026-11-27 00:03:03',NULL),
(5,'Inventory Clerk','Items, sites, receiving, adjustments, assembly builds, disassembly and processing orders, stock counts, and inventory quantity reports.',0,1,1,'2026-11-27 00:03:03',NULL),
(6,'Sales Representative','Estimates, sales orders, and invoices, and the Sales reports.',0,1,1,'2026-11-27 00:03:03',NULL),
(7,'Cashier','POS sales, returns, and cash drops at the assigned terminal only.',0,1,0,'2026-11-27 00:03:03',NULL),
(8,'POS Supervisor','Everything a cashier can do, plus approving voids, refunds, price overrides, and large discounts, and running X- and Z-readings.',0,1,1,'2026-11-27 00:03:03',NULL),
(9,'Allocation Officer','Supplier Allocation, the Supplier Items of each supplier, Pick-Up Supplier Items, the Crate Center and the crate and allocation reports.',0,1,1,'2026-11-27 00:03:03',NULL),
(10,'Pick-Up Crew','The pick-ups assigned to them: weighing and dating the crates at the supplier and marking the pick-up complete.',0,1,1,'2026-11-27 00:03:03',NULL),
(11,'Auditor','View-only access to all transactions, reports, and the audit trail. Cannot create or change anything.',0,1,1,'2026-11-27 00:03:03',NULL);

-- user_roles (11 rows)
INSERT INTO `user_roles` (`user_id`,`role_id`) VALUES
(1,1),
(2,2),
(3,3),
(4,4),
(5,5),
(6,9),
(7,6),
(8,8),
(9,7),
(10,10),
(11,11);

-- modules (12 rows)
INSERT INTO `modules` (`id`,`code`,`name`,`icon`,`sort_order`) VALUES
(1,'home','Home','house',1),
(2,'coa','Financial','journal-bookmark',2),
(3,'fa','Fixed Assets','building',3),
(4,'cust','Customers','people',4),
(5,'vend','Vendors','truck',5),
(6,'inv','Inventory','box-seam',6),
(7,'pos','Point of Sale','cart',7),
(8,'bank','Banking','bank',8),
(9,'bir','BIR Reports','file-earmark-ruled',9),
(10,'admin','System Administration','shield-lock',10),
(11,'company','Company','buildings',11),
(12,'comm','Community','chat-dots',12);

-- pages (244 rows)
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(1,'home.dashboard',1,'Home Dashboard','center','Home',10,1,NULL),
(2,'home.reports',1,'Report Center','center','Home',20,1,NULL),
(3,'home.memorized',1,'Memorized Reports','list','Home',30,1,NULL),
(4,'home.report_layouts',1,'Saved Report Layouts','list','Home',40,1,NULL),
(5,'home.search',1,'Search','center','Home',50,0,NULL),
(6,'home.find',1,'Find','center','Home',60,1,NULL),
(7,'rpt.find',1,'Find Results','report','Reports',70,0,NULL),
(8,'coa.accounts',2,'Chart of Accounts','list','Lists',80,1,NULL),
(9,'coa.classes',2,'Class List','list','Lists',90,1,NULL),
(10,'coa.names',2,'Employees & Other Names','list','Lists',100,1,NULL),
(11,'coa.memorized_txns',2,'Memorized Transactions','list','Lists',110,1,NULL),
(12,'coa.budgets',2,'Set Up Budgets','setup','Setup',120,1,NULL),
(13,'coa.journal',2,'Make Journal Entries','transaction','Transactions',130,1,NULL),
(14,'coa.default_accounts',2,'Module Default Accounts','setup','Setup',140,1,NULL),
(15,'coa.lists',2,'Terms, Tax Codes & Other Lists','setup','Setup',150,1,NULL),
(16,'rpt.trial_balance',2,'Trial Balance','report','Reports',160,1,NULL),
(17,'rpt.trial_balance_class',2,'Trial Balance by Class','report','Reports',170,1,NULL),
(18,'rpt.balance_sheet',2,'Balance Sheet','report','Reports',180,1,NULL),
(19,'rpt.balance_sheet_class',2,'Balance Sheet by Class','report','Reports',190,1,NULL),
(20,'rpt.trial_balance_range',2,'Trial Balance by Date Range','report','Reports',200,1,NULL),
(21,'rpt.trial_balance_totals',2,'Trial Balance of Totals','report','Reports',210,1,NULL),
(22,'rpt.balance_sheet_range',2,'Balance Sheet by Date Range','report','Reports',220,1,NULL),
(23,'rpt.budget_income',2,'Income Statement vs Budget','report','Reports',230,1,NULL),
(24,'rpt.budget_balance',2,'Balance Sheet vs Budget','report','Reports',240,1,NULL),
(25,'rpt.income_statement',2,'Income Statement','report','Reports',250,1,NULL),
(26,'rpt.income_statement_class',2,'Income Statement by Class','report','Reports',260,1,NULL),
(27,'rpt.cmp_is_month',2,'Comparative Income Statement by Month','report','Reports',270,1,NULL),
(28,'rpt.cmp_is_quarter',2,'Comparative Income Statement by Quarter','report','Reports',280,1,NULL),
(29,'rpt.cmp_is_year',2,'Comparative Income Statement by Year','report','Reports',290,1,NULL),
(30,'rpt.cmp_is_custom',2,'Comparative Income Statement by Custom Range','report','Reports',300,1,NULL),
(31,'rpt.cmp_bs_month',2,'Comparative Balance Sheet by Month','report','Reports',310,1,NULL),
(32,'rpt.cmp_bs_quarter',2,'Comparative Balance Sheet by Quarter','report','Reports',320,1,NULL),
(33,'rpt.cmp_bs_year',2,'Comparative Balance Sheet by Year','report','Reports',330,1,NULL),
(34,'rpt.cmp_bs_custom',2,'Comparative Balance Sheet by Custom Date','report','Reports',340,1,NULL),
(35,'rpt.cash_flow',2,'Statement of Cash Flows','report','Reports',350,1,NULL),
(36,'rpt.cash_flow_class',2,'Statement of Cash Flows by Class','report','Reports',360,1,NULL),
(37,'rpt.general_ledger',2,'General Ledger','report','Reports',370,1,NULL),
(38,'rpt.subsidiary_ledger',2,'Subsidiary Ledger','report','Reports',380,1,NULL),
(39,'rpt.schedule_of_accounts',2,'Schedule of Accounts','report','Reports',390,1,NULL),
(40,'rpt.journal',2,'Journal','report','Reports',400,1,NULL),
(41,'fa.register',3,'Fixed Asset Register','center','Transactions',410,1,NULL),
(42,'fa.depreciation',3,'Run Depreciation','transaction','Transactions',420,1,NULL),
(43,'fa.disposal',3,'Dispose of Assets','transaction','Transactions',430,1,NULL),
(44,'fa.maintenance',3,'Asset Maintenance','transaction','Transactions',440,1,NULL),
(45,'fa.pm',3,'Preventive Maintenance','transaction','Transactions',450,1,NULL),
(46,'fa.categories',3,'Asset Categories','setup','Setup',460,1,NULL),
(47,'fa.locations',3,'Asset Locations','setup','Setup',470,1,NULL),
(48,'rpt.fa_register',3,'Fixed Asset Register Report','report','Reports',480,1,NULL),
(49,'rpt.fa_schedule',3,'Depreciation Schedule by Asset','report','Reports',490,1,NULL),
(50,'rpt.fa_by_category',3,'Depreciation by Category','report','Reports',500,1,NULL),
(51,'rpt.fa_additions',3,'Additions and Disposals','report','Reports',510,1,NULL),
(52,'rpt.fa_maint_history',3,'Maintenance History','report','Reports',520,1,NULL),
(53,'rpt.fa_maint_cost',3,'Maintenance Cost by Asset','report','Reports',530,1,NULL),
(54,'rpt.fa_maint_parts',3,'Spare Parts Used','report','Reports',540,1,NULL),
(55,'rpt.fa_maint_labor',3,'Maintenance Labor','report','Reports',550,1,NULL),
(56,'rpt.fa_pm_upcoming',3,'Upcoming Preventive Maintenance','report','Reports',560,1,NULL),
(57,'rpt.fa_pm_log',3,'Completed Preventive Maintenance','report','Reports',570,1,NULL),
(58,'cust.center',4,'Customer Center','center','Transactions',580,1,NULL),
(59,'cust.estimates',4,'Create Estimates','transaction','Transactions',590,1,NULL),
(60,'cust.sales_orders',4,'Create Sales Orders','transaction','Transactions',600,1,NULL),
(61,'cust.invoices',4,'Create Invoices','transaction','Transactions',610,1,NULL),
(62,'cust.batch_invoices',4,'Create Batch Invoices','transaction','Transactions',620,1,NULL),
(63,'cust.sales_receipts',4,'Enter Sales Receipts','transaction','Transactions',630,1,NULL),
(64,'cust.statement_charges',4,'Enter Statement Charges','transaction','Transactions',640,1,NULL),
(65,'cust.statements',4,'Create Statements','transaction','Transactions',650,1,NULL),
(66,'cust.finance_charges',4,'Assess Finance Charges','transaction','Transactions',660,1,NULL),
(67,'cust.forecast',4,'Set Up Forecast','setup','Transactions',670,1,NULL),
(68,'cust.payments',4,'Receive Payments','transaction','Transactions',680,1,NULL),
(69,'cust.checks',4,'Customer Checks','center','Transactions',690,1,NULL),
(70,'cust.credit_memos',4,'Create Credit Memos/Refunds','transaction','Transactions',700,1,NULL),
(71,'rpt.ar_aging_summary',4,'A/R Aging Summary','report','Customer and Receivables Reports',710,1,NULL),
(72,'rpt.ar_aging_detail',4,'A/R Aging Detail','report','Customer and Receivables Reports',720,1,NULL),
(73,'rpt.customer_balance_summary',4,'Customer Balance Summary','report','Customer and Receivables Reports',730,1,NULL),
(74,'rpt.customer_balance_detail',4,'Customer Balance Detail','report','Customer and Receivables Reports',740,1,NULL),
(75,'rpt.open_invoices',4,'Open Invoices','report','Customer and Receivables Reports',750,1,NULL),
(76,'rpt.collections',4,'Collections Report','report','Customer and Receivables Reports',760,1,NULL),
(77,'rpt.check_registry',4,'Check Registry','report','Customer and Receivables Reports',770,1,NULL),
(78,'rpt.cashier_collections',4,'Collections by Cashier / User','report','Customer and Receivables Reports',780,1,NULL),
(79,'rpt.avg_days_summary',4,'Average Days to Pay Summary','report','Customer and Receivables Reports',790,1,NULL),
(80,'rpt.avg_days_detail',4,'Average Days to Pay','report','Customer and Receivables Reports',800,1,NULL),
(81,'rpt.ar_graph',4,'Accounts Receivable Graph','report','Customer and Receivables Reports',810,1,NULL),
(82,'rpt.unbilled_costs',4,'Unbilled Cost by Job','report','Customer and Receivables Reports',820,1,NULL),
(83,'rpt.txn_list_customer',4,'Transaction List by Customer','report','Customer and Receivables Reports',830,1,NULL),
(84,'rpt.item_price_list',4,'Item Price List','report','Customer and Receivables Reports',840,1,NULL),
(85,'rpt.sales_customer_summary',4,'Sales by Customer Summary','report','Sales Reports',850,1,NULL),
(86,'rpt.forecast_vs_actual',4,'Forecast vs Actual by Customer','report','Sales Reports',860,1,NULL),
(87,'rpt.sales_customer_detail',4,'Sales by Customer Detail','report','Sales Reports',870,1,NULL),
(88,'rpt.income_customer_summary',4,'Income by Customer Summary','report','Sales Reports',880,1,NULL),
(89,'rpt.income_customer_detail',4,'Income by Customer Detail','report','Sales Reports',890,1,NULL),
(90,'rpt.sales_item_summary',4,'Sales by Item Summary','report','Sales Reports',900,1,NULL),
(91,'rpt.sales_item_detail',4,'Sales by Item Detail','report','Sales Reports',910,1,NULL),
(92,'rpt.sales_item_group',4,'Sales by Item Group','report','Sales Reports',920,1,NULL),
(93,'rpt.sales_rep_summary',4,'Sales by Rep Summary','report','Sales Reports',930,1,NULL),
(94,'rpt.sales_rep_detail',4,'Sales by Rep Detail','report','Sales Reports',940,1,NULL),
(95,'rpt.inventory_sales_site',4,'Inventory Sales by Site','report','Sales Reports',950,1,NULL),
(96,'rpt.sales_inv_movement',4,'Sales Report Through Inventory Movement','report','Sales Reports',960,1,NULL),
(97,'rpt.pending_sales',4,'Pending Sales','report','Sales Reports',970,1,NULL),
(98,'rpt.open_so_customer',4,'Open Sales Orders by Customer','report','Sales Reports',980,1,NULL),
(99,'rpt.open_so_item',4,'Open Sales Orders by Item','report','Sales Reports',990,1,NULL),
(100,'vend.center',5,'Vendor Center','center','Transactions',1000,1,NULL);
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(101,'vend.bill_tracker',5,'Bill Tracker','center','Transactions',1010,1,NULL),
(102,'vend.bills',5,'Enter Bills','transaction','Transactions',1020,1,NULL),
(103,'vend.debit_memos',5,'Supplier Debit Memos','transaction','Transactions',1030,1,NULL),
(104,'vend.pay_bills',5,'Pay Bills','transaction','Transactions',1040,1,NULL),
(105,'vend.receipts',5,'Receipt Management','transaction','Transactions',1050,1,NULL),
(106,'vend.purchase_orders',5,'Create Purchase Orders','transaction','Transactions',1060,1,NULL),
(107,'vend.receive_bill',5,'Receive Items and Enter Bills','transaction','Transactions',1070,1,NULL),
(108,'vend.receive_items',5,'Receive Items','transaction','Transactions',1080,1,NULL),
(109,'vend.bill_received',5,'Enter Bill for Received Items','transaction','Transactions',1090,1,NULL),
(110,'vend.advances',5,'Advances to Suppliers','transaction','Transactions',1100,1,NULL),
(111,'vend.allocations',5,'Supplier Allocation','transaction','Distribution',1110,1,NULL),
(112,'vend.pickup',5,'Pick-Up Supplier Items','transaction','Distribution',1120,1,NULL),
(113,'vend.supplier_items',5,'Supplier Items','list','Distribution',1130,1,NULL),
(114,'rpt.alloc_pickup',5,'Supplier Allocation vs Pick-Up','report','Distribution Reports',1140,1,NULL),
(115,'rpt.ap_aging_summary',5,'A/P Aging Summary','report','Vendors and Payables Reports',1150,1,NULL),
(116,'rpt.ap_aging_detail',5,'A/P Aging Detail','report','Vendors and Payables Reports',1160,1,NULL),
(117,'rpt.vendor_balance_summary',5,'Vendor Balance Summary','report','Vendors and Payables Reports',1170,1,NULL),
(118,'rpt.vendor_balance_detail',5,'Vendor Balance Detail','report','Vendors and Payables Reports',1180,1,NULL),
(119,'rpt.unpaid_bills',5,'Unpaid Bills Detail','report','Vendors and Payables Reports',1190,1,NULL),
(120,'rpt.txn_list_vendor',5,'Transaction List by Vendor','report','Vendors and Payables Reports',1200,1,NULL),
(121,'rpt.vendor_contacts',5,'Vendor Contact List','report','Vendors and Payables Reports',1210,1,NULL),
(122,'rpt.expenses_vendor_summary',5,'Expenses by Vendor Summary','report','Vendors and Payables Reports',1220,1,NULL),
(123,'rpt.expenses_vendor_detail',5,'Expenses by Vendor Detail','report','Vendors and Payables Reports',1230,1,NULL),
(124,'rpt.vendor_advances',5,'Advances to Suppliers','report','Vendors and Payables Reports',1240,1,NULL),
(125,'inv.center',6,'Inventory Center','center','Transactions',1250,1,NULL),
(126,'inv.items',6,'Item List','list','Lists',1260,1,NULL),
(127,'inv.categories',6,'Category List','list','Lists',1270,1,NULL),
(128,'inv.sites',6,'Inventory Site List','list','Lists',1280,1,NULL),
(129,'inv.uom',6,'U/M Set List','list','Lists',1290,1,NULL),
(130,'inv.formulas',6,'Processing Formulas (Multi-Output BOM)','list','Lists',1300,1,NULL),
(131,'inv.transfers',6,'Transfer Inventory','transaction','Transactions',1310,1,NULL),
(132,'inv.dispatch',6,'Dispatch Inventory','transaction','Transactions',1320,1,NULL),
(133,'inv.transfer_closing',6,'Inventory Transfer Closing','transaction','Transactions',1330,1,NULL),
(134,'inv.shortages',6,'Shortage Charges','transaction','Transactions',1340,1,NULL),
(135,'inv.adjust',6,'Adjust Quantity/Value on Hand','transaction','Transactions',1350,1,NULL),
(136,'inv.build',6,'Build Assemblies','transaction','Transactions',1360,1,NULL),
(137,'inv.process',6,'Disassemble / Process Items','transaction','Transactions',1370,1,NULL),
(138,'inv.physical_count',6,'Physical Inventory Count','transaction','Transactions',1380,1,NULL),
(139,'inv.lot_check',6,'Production and Expiry Dates','transaction','Transactions',1390,1,NULL),
(140,'inv.change_prices',6,'Change Item Prices','transaction','Transactions',1400,1,NULL),
(141,'inv.set_prices',6,'Set Item Prices and Levels','transaction','Transactions',1410,1,NULL),
(142,'inv.crates',6,'Crate Center','center','Crates',1420,1,NULL),
(143,'inv.crate_convert',6,'Convert Crates to Kilos','transaction','Crates',1430,1,NULL),
(144,'inv.crate_pack',6,'Convert Kilos to Crates','transaction','Crates',1440,1,NULL),
(145,'inv.crate_move',6,'Move Crates to Another Site','transaction','Crates',1450,1,NULL),
(146,'rpt.crates_on_hand',6,'Crates Remaining by Item','report','Crate Reports',1460,1,NULL),
(147,'rpt.crate_detail',6,'Kilos per Crate by Item','report','Crate Reports',1470,1,NULL),
(148,'rpt.crates_sold',6,'Crates Sold with Production and Expiry Dates','report','Crate Reports',1480,1,NULL),
(149,'rpt.crate_movements',6,'Crate Movement History','report','Crate Reports',1490,1,NULL),
(150,'rpt.crates_received',6,'Crates Received by Supplier','report','Crate Reports',1500,1,NULL),
(151,'rpt.closing_register',6,'Inventory Transfer Closing Register','report','Shortage and Shrinkage Reports',1510,1,NULL),
(152,'rpt.shortage_item',6,'Shortages by Item','report','Shortage and Shrinkage Reports',1520,1,NULL),
(153,'rpt.shortage_site',6,'Shortages by Site','report','Shortage and Shrinkage Reports',1530,1,NULL),
(154,'rpt.shortage_rep',6,'Shortages by Sales Representative','report','Shortage and Shrinkage Reports',1540,1,NULL),
(155,'rpt.shortage_detail',6,'Shortage Detail','report','Shortage and Shrinkage Reports',1550,1,NULL),
(156,'rpt.shrinkage_item',6,'Shrinkage by Item','report','Shortage and Shrinkage Reports',1560,1,NULL),
(157,'rpt.shrinkage_detail',6,'Shrinkage Detail','report','Shortage and Shrinkage Reports',1570,1,NULL),
(158,'rpt.transfer_item',6,'Transfers by Item Code','report','Transfer Reports',1580,1,NULL),
(159,'rpt.transfer_site',6,'Transfers by Site','report','Transfer Reports',1590,1,NULL),
(160,'rpt.qoh_by_site',6,'Quantity on Hand by Site','report','Inventory Reports',1600,1,NULL),
(161,'rpt.inv_valuation_summary',6,'Inventory Valuation Summary','report','Inventory Reports',1610,1,NULL),
(162,'rpt.inv_valuation_site',6,'Inventory Valuation Summary by Site','report','Inventory Reports',1620,1,NULL),
(163,'rpt.inv_valuation_detail',6,'Inventory Valuation Detail','report','Inventory Reports',1630,1,NULL),
(164,'rpt.expiring_items',6,'Expiring and Expired Items','report','Inventory Reports',1640,1,NULL),
(165,'rpt.stock_by_lot',6,'Stock by Production and Expiry Date','report','Inventory Reports',1650,1,NULL),
(166,'rpt.avg_cost_changes',6,'Average Cost Changes','report','Inventory Reports',1660,1,NULL),
(167,'rpt.stock_status_item',6,'Inventory Stock Status by Item','report','Inventory Reports',1670,1,NULL),
(168,'rpt.stock_status_vendor',6,'Inventory Stock Status by Vendor','report','Inventory Reports',1680,1,NULL),
(169,'rpt.stock_status_site',6,'Inventory Stock Status by Site','report','Inventory Reports',1690,1,NULL),
(170,'rpt.physical_worksheet',6,'Physical Inventory Worksheet','report','Inventory Reports',1700,1,NULL),
(171,'rpt.pending_builds',6,'Pending Builds','report','Inventory Reports',1710,1,NULL),
(172,'rpt.pending_builds_site',6,'Pending Builds by Site','report','Inventory Reports',1720,1,NULL),
(173,'rpt.processing_register',6,'Processing & Disassembly Register','report','Inventory Reports',1730,1,NULL),
(174,'rpt.coproduct_costs',6,'Co-product & By-product Cost Allocation','report','Inventory Reports',1740,1,NULL),
(175,'rpt.process_yield',6,'Processing Yield Analysis','report','Inventory Reports',1750,1,NULL),
(176,'rpt.negative_inventory',6,'Negative Inventory Listing','report','Inventory Reports',1760,1,NULL),
(177,'rpt.inv_no_movement',6,'No. of Days Inventory Has No Movement','report','Inventory Reports',1770,1,NULL),
(178,'rpt.inv_custom',6,'Customized Inventory Report','report','Inventory Reports',1780,1,NULL),
(179,'rpt.inv_movement_summary',6,'Inventory Movement Summary Report','report','Inventory Reports',1790,1,NULL),
(180,'rpt.inv_movement_detail',6,'Inventory Movement Detailed Report','report','Inventory Reports',1800,1,NULL),
(181,'rpt.inv_movement_txns',6,'Inventory Movement Transactions','report','Inventory Reports',1810,0,NULL),
(182,'pos.register',7,'POS Register','transaction','Transactions',1820,1,NULL),
(183,'pos.fb',7,'FB POS','transaction','Transactions',1830,1,NULL),
(184,'pos.shifts',7,'Shifts, Cash Drops & Readings','transaction','Transactions',1840,1,NULL),
(185,'pos.receipts',7,'POS Receipts, Returns & Voids','transaction','Transactions',1850,1,NULL),
(186,'pos.approval_codes',7,'Approval Codes','transaction','Transactions',1860,1,NULL),
(187,'pos.terminals',7,'POS Terminals','setup','Setup',1870,1,NULL),
(188,'pos.payment_types',7,'Payment Types & G.L. Accounts','setup','Setup',1880,1,NULL),
(189,'pos.fb_menu',7,'FB POS Menu & Groups','setup','Setup',1890,1,NULL),
(190,'rpt.pos_sales_txn',7,'POS Sales by Transaction No. (detail)','report','Reports',1900,1,NULL),
(191,'rpt.pos_sales_item',7,'POS Sales by Item','report','Reports',1910,1,NULL),
(192,'rpt.pos_sales_item_group',7,'POS Sales by Item Group','report','Reports',1920,1,NULL),
(193,'rpt.pos_sales_category',7,'POS Sales by Category','report','Reports',1930,1,NULL),
(194,'rpt.pos_sales_cashier',7,'POS Sales by Cashier & Payment Method','report','Reports',1940,1,NULL),
(195,'rpt.pos_sales_payment',7,'POS Sales by Payment Method','report','Reports',1950,0,NULL),
(196,'rpt.pos_sales_hour',7,'POS Sales by Hour','report','Reports',1960,1,NULL),
(197,'rpt.pos_daily_summary',7,'POS Daily Sales Summary','report','Reports',1970,1,NULL),
(198,'rpt.pos_readings',7,'X- and Z-Reading Summary','report','Reports',1980,1,NULL),
(199,'rpt.pos_discount_log',7,'POS Discount Log','report','Reports',1990,1,NULL),
(200,'rpt.pos_void_log',7,'POS Void and Refund Log','report','Reports',2000,1,NULL);
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(201,'rpt.pos_ending_inventory',7,'Ending Inventory - POS Cashier','report','Reports',2010,1,NULL),
(202,'rpt.pos_cash_count',7,'Cash Count Sheet','report','Reports',2020,1,NULL),
(203,'bank.write_checks',8,'Write Checks','transaction','Transactions',2030,1,NULL),
(204,'bank.cash_voucher',8,'Cash Voucher','transaction','Transactions',2040,1,NULL),
(205,'bank.register',8,'Use Register','center','Transactions',2050,1,NULL),
(206,'bank.deposits',8,'Make Deposits','transaction','Transactions',2060,1,NULL),
(207,'bank.transfers',8,'Transfer Funds','transaction','Transactions',2070,1,NULL),
(208,'bank.reconcile',8,'Reconcile','transaction','Transactions',2080,1,NULL),
(209,'rpt.recon_summary',8,'Reconciliation Summary','report','Reports',2090,1,NULL),
(210,'rpt.recon_detail',8,'Reconciliation Detail','report','Reports',2100,1,NULL),
(211,'rpt.recon_discrepancy',8,'Reconciliation Discrepancy','report','Reports',2110,1,NULL),
(212,'rpt.check_register',8,'Check Register','report','Reports',2120,1,NULL),
(213,'bir.form_2307',9,'Print BIR Form 2307','transaction','Transactions',2130,1,NULL),
(214,'bir.wht_table',9,'Withholding Tax Table','setup','Setup',2140,1,NULL),
(215,'rpt.bir_wht_summary',9,'Summary of Taxes Withheld from Vendors/Suppliers','report','BIR Reports',2150,1,NULL),
(216,'rpt.bir_ewt_register',9,'Expanded Withholding Tax Register (1% / 2%)','report','BIR Reports',2160,1,NULL),
(217,'rpt.bir_remittance',9,'Withholding Tax Remittances (0619-E, 1601-EQ, 1600-VT)','report','BIR Reports',2170,1,NULL),
(218,'rpt.bir_vat_withholding',9,'VAT Withholding Register (1600-VT)','report','BIR Reports',2180,1,NULL),
(219,'rpt.bir_sales_register',9,'Output VAT / Sales Register','report','BIR Reports',2190,1,NULL),
(220,'rpt.bir_purchase_register',9,'Input VAT / Purchases Register','report','BIR Reports',2200,1,NULL),
(221,'rpt.bir_cvat_withheld',9,'Creditable VAT Withheld Schedule (2550Q Schedule 3)','report','BIR Reports',2210,1,NULL),
(222,'rpt.bir_2550q',9,'Quarterly VAT Return Worksheet (2550Q)','report','BIR Reports',2220,1,NULL),
(223,'admin.users',10,'User Accounts','admin','Setup',2230,1,NULL),
(224,'admin.roles',10,'User Role Configuration','admin','Setup',2240,1,NULL),
(225,'admin.page_access',10,'Page Access Configuration','admin','Setup',2250,1,NULL),
(226,'admin.effective_access',10,'Effective Access (View as User)','admin','Setup',2260,1,NULL),
(227,'admin.settings',10,'Company, Security & Closing Date','admin','Setup',2270,1,NULL),
(228,'admin.utilities',10,'Utilities: Verify & Rebuild Data','admin','Setup',2280,1,NULL),
(229,'admin.import',10,'Import from CSV','admin','Utilities',2290,1,NULL),
(230,'admin.backup',10,'Backup & Restore','admin','Utilities',2300,1,NULL),
(231,'admin.multi_company',10,'Multi-Company Setup','admin','Setup',2310,1,NULL),
(232,'admin.audit_trail',10,'Audit Trail','report','Audit Reports',2320,1,NULL),
(233,'admin.txn_history',10,'Transaction History','report','Audit Reports',2330,1,NULL),
(234,'rpt.voided_deleted_summary',10,'Voided and Deleted Transactions Summary','report','Audit Reports',2340,1,NULL),
(235,'rpt.voided_deleted_detail',10,'Voided and Deleted Transactions Detail','report','Audit Reports',2350,1,NULL),
(236,'rpt.user_activity',10,'User Activity','report','Audit Reports',2360,1,NULL),
(237,'rpt.login_history',10,'Login History','report','Audit Reports',2370,1,NULL),
(238,'rpt.user_access',10,'User Access and Permission Changes','report','Audit Reports',2380,1,NULL),
(239,'company.profile',11,'Company Profile & Code','admin','Company',2390,1,NULL),
(240,'company.users',11,'Employees & Users','admin','Company',2400,1,NULL),
(241,'company.join_requests',11,'Join Requests','admin','Company',2410,1,NULL),
(242,'comm.chat',12,'Community Chat','center','Community',2420,1,NULL),
(243,'comm.inquiries',12,'Questions & Inquiries','center','Community',2430,1,NULL),
(244,'comm.manage',12,'Community Management','admin','Moderation',2440,1,NULL);

-- role_page_access (651 rows)
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(1,242,1,0,0,0,0,0),
(1,243,1,0,0,0,0,0),
(2,1,1,0,0,0,1,0),
(2,2,1,0,0,0,1,0),
(2,3,1,0,0,0,1,0),
(2,4,1,0,0,0,1,0),
(2,5,1,0,0,0,1,0),
(2,6,1,0,0,0,1,0),
(2,7,1,0,0,0,1,0),
(2,8,1,1,1,1,1,0),
(2,9,1,1,1,1,1,0),
(2,10,1,1,1,1,1,0),
(2,11,1,1,1,1,1,0),
(2,12,1,1,1,1,1,0),
(2,13,1,1,1,1,1,0),
(2,14,1,1,1,1,1,0),
(2,15,1,1,1,1,1,0),
(2,16,1,1,1,1,1,0),
(2,17,1,1,1,1,1,0),
(2,18,1,1,1,1,1,0),
(2,19,1,1,1,1,1,0),
(2,20,1,1,1,1,1,0),
(2,21,1,1,1,1,1,0),
(2,22,1,1,1,1,1,0),
(2,23,1,1,1,1,1,0),
(2,24,1,1,1,1,1,0),
(2,25,1,1,1,1,1,0),
(2,26,1,1,1,1,1,0),
(2,27,1,1,1,1,1,0),
(2,28,1,1,1,1,1,0),
(2,29,1,1,1,1,1,0),
(2,30,1,1,1,1,1,0),
(2,31,1,1,1,1,1,0),
(2,32,1,1,1,1,1,0),
(2,33,1,1,1,1,1,0),
(2,34,1,1,1,1,1,0),
(2,35,1,1,1,1,1,0),
(2,36,1,1,1,1,1,0),
(2,37,1,1,1,1,1,0),
(2,38,1,1,1,1,1,0),
(2,39,1,1,1,1,1,0),
(2,40,1,1,1,1,1,0),
(2,41,1,1,1,1,1,0),
(2,42,1,1,1,1,1,0),
(2,43,1,1,1,1,1,0),
(2,44,1,1,1,1,1,0),
(2,45,1,1,1,1,1,0),
(2,46,1,1,1,1,1,0),
(2,47,1,1,1,1,1,0),
(2,48,1,1,1,1,1,0),
(2,49,1,1,1,1,1,0),
(2,50,1,1,1,1,1,0),
(2,51,1,1,1,1,1,0),
(2,52,1,1,1,1,1,0),
(2,53,1,1,1,1,1,0),
(2,54,1,1,1,1,1,0),
(2,55,1,1,1,1,1,0),
(2,56,1,1,1,1,1,0),
(2,57,1,1,1,1,1,0),
(2,58,1,0,0,0,1,0),
(2,61,1,0,0,0,1,0),
(2,68,1,0,0,0,1,0),
(2,69,1,0,1,0,1,0),
(2,71,1,0,0,0,1,0),
(2,72,1,0,0,0,1,0),
(2,73,1,0,0,0,1,0),
(2,74,1,0,0,0,1,0),
(2,75,1,0,0,0,1,0),
(2,76,1,0,0,0,1,0),
(2,77,1,0,0,0,1,0),
(2,78,1,0,0,0,1,0),
(2,79,1,0,0,0,1,0),
(2,80,1,0,0,0,1,0),
(2,81,1,0,0,0,1,0),
(2,82,1,0,0,0,1,0),
(2,83,1,0,0,0,1,0),
(2,84,1,0,0,0,1,0),
(2,85,1,0,0,0,1,0),
(2,86,1,0,0,0,1,0),
(2,87,1,0,0,0,1,0),
(2,88,1,0,0,0,1,0),
(2,89,1,0,0,0,1,0),
(2,90,1,0,0,0,1,0),
(2,91,1,0,0,0,1,0),
(2,92,1,0,0,0,1,0),
(2,93,1,0,0,0,1,0),
(2,94,1,0,0,0,1,0),
(2,95,1,0,0,0,1,0),
(2,96,1,0,0,0,1,0),
(2,97,1,0,0,0,1,0),
(2,98,1,0,0,0,1,0),
(2,99,1,0,0,0,1,0),
(2,100,1,0,0,0,1,0),
(2,101,1,0,0,0,1,0),
(2,102,1,0,0,0,1,0),
(2,104,1,0,0,0,1,0),
(2,110,1,0,0,0,1,0),
(2,114,1,0,0,0,1,0),
(2,115,1,0,0,0,1,0),
(2,116,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(2,117,1,0,0,0,1,0),
(2,118,1,0,0,0,1,0),
(2,119,1,0,0,0,1,0),
(2,120,1,0,0,0,1,0),
(2,121,1,0,0,0,1,0),
(2,122,1,0,0,0,1,0),
(2,123,1,0,0,0,1,0),
(2,124,1,0,0,0,1,0),
(2,125,1,0,0,0,1,0),
(2,126,1,0,0,0,1,0),
(2,127,1,0,0,0,1,0),
(2,129,1,0,0,0,1,0),
(2,130,1,0,0,0,1,0),
(2,133,1,0,0,0,1,0),
(2,134,1,0,0,0,1,0),
(2,135,1,0,0,0,1,0),
(2,137,1,0,0,0,1,0),
(2,139,1,0,0,0,1,0),
(2,146,1,0,0,0,1,0),
(2,147,1,0,0,0,1,0),
(2,148,1,0,0,0,1,0),
(2,149,1,0,0,0,1,0),
(2,150,1,0,0,0,1,0),
(2,151,1,0,0,0,1,0),
(2,152,1,0,0,0,1,0),
(2,153,1,0,0,0,1,0),
(2,154,1,0,0,0,1,0),
(2,155,1,0,0,0,1,0),
(2,156,1,0,0,0,1,0),
(2,157,1,0,0,0,1,0),
(2,158,1,0,0,0,1,0),
(2,159,1,0,0,0,1,0),
(2,160,1,0,0,0,1,0),
(2,161,1,0,0,0,1,0),
(2,162,1,0,0,0,1,0),
(2,163,1,0,0,0,1,0),
(2,164,1,0,0,0,1,0),
(2,165,1,0,0,0,1,0),
(2,166,1,0,0,0,1,0),
(2,167,1,0,0,0,1,0),
(2,168,1,0,0,0,1,0),
(2,169,1,0,0,0,1,0),
(2,170,1,0,0,0,1,0),
(2,171,1,0,0,0,1,0),
(2,172,1,0,0,0,1,0),
(2,173,1,0,0,0,1,0),
(2,174,1,0,0,0,1,0),
(2,175,1,0,0,0,1,0),
(2,176,1,0,0,0,1,0),
(2,177,1,0,0,0,1,0),
(2,178,1,0,0,0,1,0),
(2,179,1,0,0,0,1,0),
(2,180,1,0,0,0,1,0),
(2,181,1,0,0,0,1,0),
(2,188,1,1,1,0,1,0),
(2,190,1,0,0,0,1,0),
(2,191,1,0,0,0,1,0),
(2,192,1,0,0,0,1,0),
(2,193,1,0,0,0,1,0),
(2,194,1,0,0,0,1,0),
(2,195,1,0,0,0,1,0),
(2,196,1,0,0,0,1,0),
(2,197,1,0,0,0,1,0),
(2,198,1,0,0,0,1,0),
(2,199,1,0,0,0,1,0),
(2,200,1,0,0,0,1,0),
(2,201,1,0,0,0,1,0),
(2,202,1,0,0,0,1,0),
(2,203,1,1,1,1,1,0),
(2,204,1,1,1,1,1,0),
(2,205,1,1,1,1,1,0),
(2,206,1,1,1,1,1,0),
(2,207,1,1,1,1,1,0),
(2,208,1,1,1,1,1,0),
(2,209,1,1,1,1,1,0),
(2,210,1,1,1,1,1,0),
(2,211,1,1,1,1,1,0),
(2,212,1,1,1,1,1,0),
(2,213,1,1,1,1,1,0),
(2,214,1,1,1,1,1,0),
(2,215,1,1,1,1,1,0),
(2,216,1,1,1,1,1,0),
(2,217,1,1,1,1,1,0),
(2,218,1,1,1,1,1,0),
(2,219,1,1,1,1,1,0),
(2,220,1,1,1,1,1,0),
(2,221,1,1,1,1,1,0),
(2,222,1,1,1,1,1,0),
(2,228,1,0,0,0,1,0),
(2,242,1,1,1,1,0,0),
(2,243,1,1,1,1,0,0),
(3,1,1,0,0,0,1,0),
(3,2,1,0,0,0,1,0),
(3,3,1,0,0,0,1,0),
(3,4,1,0,0,0,1,0),
(3,5,1,0,0,0,1,0),
(3,6,1,0,0,0,1,0),
(3,7,1,0,0,0,1,0),
(3,58,1,1,1,0,1,0),
(3,59,1,1,1,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(3,60,1,1,1,0,1,0),
(3,61,1,1,1,0,1,0),
(3,62,1,1,1,0,1,0),
(3,63,1,1,1,0,1,0),
(3,64,1,1,1,0,1,0),
(3,65,1,1,1,0,1,0),
(3,66,1,1,1,0,1,0),
(3,67,1,1,1,0,1,0),
(3,68,1,1,1,0,1,0),
(3,69,1,1,1,0,1,0),
(3,70,1,1,1,0,1,0),
(3,71,1,0,0,0,1,0),
(3,72,1,0,0,0,1,0),
(3,73,1,0,0,0,1,0),
(3,74,1,0,0,0,1,0),
(3,75,1,0,0,0,1,0),
(3,76,1,0,0,0,1,0),
(3,77,1,0,0,0,1,0),
(3,78,1,0,0,0,1,0),
(3,79,1,0,0,0,1,0),
(3,80,1,0,0,0,1,0),
(3,81,1,0,0,0,1,0),
(3,82,1,0,0,0,1,0),
(3,83,1,0,0,0,1,0),
(3,84,1,0,0,0,1,0),
(3,126,1,0,0,0,0,0),
(3,134,1,0,0,0,1,0),
(3,154,1,0,0,0,1,0),
(3,155,1,0,0,0,1,0),
(3,242,1,1,1,1,0,0),
(3,243,1,1,1,1,0,0),
(4,1,1,0,0,0,1,0),
(4,2,1,0,0,0,1,0),
(4,3,1,0,0,0,1,0),
(4,4,1,0,0,0,1,0),
(4,5,1,0,0,0,1,0),
(4,6,1,0,0,0,1,0),
(4,7,1,0,0,0,1,0),
(4,100,1,1,1,0,1,0),
(4,101,1,1,1,0,1,0),
(4,102,1,1,1,0,1,0),
(4,103,1,1,1,0,1,0),
(4,104,1,1,1,0,1,0),
(4,105,1,1,1,0,1,0),
(4,106,1,1,1,0,1,0),
(4,107,1,1,1,0,1,0),
(4,108,1,1,1,0,1,0),
(4,109,1,1,1,0,1,0),
(4,110,1,1,1,0,1,0),
(4,111,1,1,1,0,1,0),
(4,112,1,1,1,0,1,0),
(4,113,1,1,1,0,1,0),
(4,114,1,0,0,0,1,0),
(4,115,1,0,0,0,1,0),
(4,116,1,0,0,0,1,0),
(4,117,1,0,0,0,1,0),
(4,118,1,0,0,0,1,0),
(4,119,1,0,0,0,1,0),
(4,120,1,0,0,0,1,0),
(4,121,1,0,0,0,1,0),
(4,122,1,0,0,0,1,0),
(4,123,1,0,0,0,1,0),
(4,124,1,0,0,0,1,0),
(4,126,1,0,0,0,0,0),
(4,213,1,0,0,0,1,0),
(4,214,1,0,0,0,0,0),
(4,215,1,0,0,0,1,0),
(4,216,1,0,0,0,1,0),
(4,217,1,0,0,0,1,0),
(4,218,1,0,0,0,1,0),
(4,242,1,1,1,1,0,0),
(4,243,1,1,1,1,0,0),
(5,1,1,0,0,0,1,0),
(5,2,1,0,0,0,1,0),
(5,3,1,0,0,0,1,0),
(5,4,1,0,0,0,1,0),
(5,5,1,0,0,0,1,0),
(5,6,1,0,0,0,1,0),
(5,7,1,0,0,0,1,0),
(5,106,1,0,0,0,1,0),
(5,108,1,1,1,0,1,0),
(5,111,1,0,0,0,1,0),
(5,112,1,1,1,0,1,0),
(5,113,1,0,0,0,1,0),
(5,114,1,0,0,0,1,0),
(5,125,1,0,0,0,1,0),
(5,126,1,1,1,0,1,0),
(5,127,1,1,1,1,1,0),
(5,128,1,1,1,0,1,0),
(5,129,1,1,1,0,1,0),
(5,130,1,1,1,0,1,0),
(5,131,1,1,1,0,1,0),
(5,132,1,1,1,0,1,0),
(5,133,1,1,0,0,1,0),
(5,134,1,0,0,0,1,0),
(5,135,1,1,1,0,1,0),
(5,136,1,1,1,0,1,0),
(5,137,1,1,1,0,1,0),
(5,138,1,0,0,0,1,0),
(5,139,1,1,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(5,142,1,0,0,0,1,0),
(5,143,1,1,0,0,1,0),
(5,144,1,1,0,0,1,0),
(5,145,1,1,0,0,1,0),
(5,146,1,0,0,0,1,0),
(5,147,1,0,0,0,1,0),
(5,148,1,0,0,0,1,0),
(5,149,1,0,0,0,1,0),
(5,150,1,0,0,0,1,0),
(5,151,1,0,0,0,1,0),
(5,152,1,0,0,0,1,0),
(5,153,1,0,0,0,1,0),
(5,154,1,0,0,0,1,0),
(5,155,1,0,0,0,1,0),
(5,156,1,0,0,0,1,0),
(5,157,1,0,0,0,1,0),
(5,158,1,0,0,0,1,0),
(5,159,1,0,0,0,1,0),
(5,160,1,0,0,0,1,0),
(5,167,1,0,0,0,1,0),
(5,168,1,0,0,0,1,0),
(5,169,1,0,0,0,1,0),
(5,170,1,0,0,0,1,0),
(5,171,1,0,0,0,1,0),
(5,172,1,0,0,0,1,0),
(5,173,1,0,0,0,1,0),
(5,175,1,0,0,0,1,0),
(5,176,1,0,0,0,1,0),
(5,177,1,0,0,0,1,0),
(5,179,1,0,0,0,1,0),
(5,180,1,0,0,0,1,0),
(5,181,1,0,0,0,1,0),
(5,242,1,1,1,1,0,0),
(5,243,1,1,1,1,0,0),
(6,1,1,0,0,0,1,0),
(6,2,1,0,0,0,1,0),
(6,3,1,0,0,0,1,0),
(6,4,1,0,0,0,1,0),
(6,5,1,0,0,0,1,0),
(6,6,1,0,0,0,1,0),
(6,7,1,0,0,0,1,0),
(6,58,1,0,0,0,1,0),
(6,59,1,1,1,0,1,0),
(6,60,1,1,1,0,1,0),
(6,61,1,1,1,0,1,0),
(6,84,1,0,0,0,1,0),
(6,85,1,0,0,0,1,0),
(6,86,1,0,0,0,1,0),
(6,87,1,0,0,0,1,0),
(6,88,1,0,0,0,1,0),
(6,89,1,0,0,0,1,0),
(6,90,1,0,0,0,1,0),
(6,91,1,0,0,0,1,0),
(6,92,1,0,0,0,1,0),
(6,93,1,0,0,0,1,0),
(6,94,1,0,0,0,1,0),
(6,95,1,0,0,0,1,0),
(6,96,1,0,0,0,1,0),
(6,97,1,0,0,0,1,0),
(6,98,1,0,0,0,1,0),
(6,99,1,0,0,0,1,0),
(6,142,1,0,0,0,1,0),
(6,146,1,0,0,0,1,0),
(6,147,1,0,0,0,1,0),
(6,181,1,0,0,0,1,0),
(6,242,1,1,1,1,0,0),
(6,243,1,1,1,1,0,0),
(7,1,1,0,0,0,0,0),
(7,182,1,1,0,0,1,0),
(7,184,1,1,0,0,1,0),
(7,185,1,1,0,1,1,0),
(7,201,1,0,0,0,1,0),
(7,242,1,1,1,1,0,0),
(7,243,1,1,1,1,0,0),
(8,1,1,0,0,0,0,0),
(8,2,1,0,0,0,0,0),
(8,77,1,0,0,0,1,0),
(8,78,1,0,0,0,1,0),
(8,182,1,1,1,1,1,1),
(8,184,1,1,1,1,1,1),
(8,185,1,1,1,1,1,1),
(8,186,1,1,1,1,1,1),
(8,187,1,0,0,0,1,0),
(8,188,1,0,0,0,1,0),
(8,190,1,0,0,0,1,0),
(8,191,1,0,0,0,1,0),
(8,192,1,0,0,0,1,0),
(8,193,1,0,0,0,1,0),
(8,194,1,0,0,0,1,0),
(8,195,1,0,0,0,1,0),
(8,196,1,0,0,0,1,0),
(8,197,1,0,0,0,1,0),
(8,198,1,0,0,0,1,0),
(8,199,1,0,0,0,1,0),
(8,200,1,0,0,0,1,0),
(8,201,1,0,0,0,1,0),
(8,202,1,0,0,0,1,0),
(8,242,1,1,1,1,0,0),
(8,243,1,1,1,1,0,0),
(9,1,1,0,0,0,0,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(9,2,1,0,0,0,0,0),
(9,100,1,0,0,0,1,0),
(9,108,1,0,0,0,1,0),
(9,111,1,1,1,1,1,0),
(9,112,1,1,1,0,1,0),
(9,113,1,1,1,0,1,0),
(9,114,1,0,0,0,1,0),
(9,125,1,0,0,0,1,0),
(9,142,1,0,0,0,1,0),
(9,146,1,0,0,0,1,0),
(9,147,1,0,0,0,1,0),
(9,148,1,0,0,0,1,0),
(9,149,1,0,0,0,1,0),
(9,150,1,0,0,0,1,0),
(9,160,1,0,0,0,1,0),
(9,242,1,1,1,1,0,0),
(9,243,1,1,1,1,0,0),
(10,1,1,0,0,0,0,0),
(10,112,1,1,1,0,0,0),
(10,142,1,0,0,0,1,0),
(10,242,1,1,1,1,0,0),
(10,243,1,1,1,1,0,0),
(11,1,1,0,0,0,1,0),
(11,2,1,0,0,0,1,0),
(11,3,1,0,0,0,1,0),
(11,4,1,0,0,0,1,0),
(11,5,1,0,0,0,1,0),
(11,6,1,0,0,0,1,0),
(11,7,1,0,0,0,1,0),
(11,8,1,0,0,0,1,0),
(11,9,1,0,0,0,1,0),
(11,10,1,0,0,0,1,0),
(11,11,1,0,0,0,1,0),
(11,12,1,0,0,0,1,0),
(11,13,1,0,0,0,1,0),
(11,14,1,0,0,0,1,0),
(11,15,1,0,0,0,1,0),
(11,16,1,0,0,0,1,0),
(11,17,1,0,0,0,1,0),
(11,18,1,0,0,0,1,0),
(11,19,1,0,0,0,1,0),
(11,20,1,0,0,0,1,0),
(11,21,1,0,0,0,1,0),
(11,22,1,0,0,0,1,0),
(11,23,1,0,0,0,1,0),
(11,24,1,0,0,0,1,0),
(11,25,1,0,0,0,1,0),
(11,26,1,0,0,0,1,0),
(11,27,1,0,0,0,1,0),
(11,28,1,0,0,0,1,0),
(11,29,1,0,0,0,1,0),
(11,30,1,0,0,0,1,0),
(11,31,1,0,0,0,1,0),
(11,32,1,0,0,0,1,0),
(11,33,1,0,0,0,1,0),
(11,34,1,0,0,0,1,0),
(11,35,1,0,0,0,1,0),
(11,36,1,0,0,0,1,0),
(11,37,1,0,0,0,1,0),
(11,38,1,0,0,0,1,0),
(11,39,1,0,0,0,1,0),
(11,40,1,0,0,0,1,0),
(11,41,1,0,0,0,1,0),
(11,42,1,0,0,0,1,0),
(11,43,1,0,0,0,1,0),
(11,44,1,0,0,0,1,0),
(11,45,1,0,0,0,1,0),
(11,46,1,0,0,0,1,0),
(11,47,1,0,0,0,1,0),
(11,48,1,0,0,0,1,0),
(11,49,1,0,0,0,1,0),
(11,50,1,0,0,0,1,0),
(11,51,1,0,0,0,1,0),
(11,52,1,0,0,0,1,0),
(11,53,1,0,0,0,1,0),
(11,54,1,0,0,0,1,0),
(11,55,1,0,0,0,1,0),
(11,56,1,0,0,0,1,0),
(11,57,1,0,0,0,1,0),
(11,58,1,0,0,0,1,0),
(11,59,1,0,0,0,1,0),
(11,60,1,0,0,0,1,0),
(11,61,1,0,0,0,1,0),
(11,62,1,0,0,0,1,0),
(11,63,1,0,0,0,1,0),
(11,64,1,0,0,0,1,0),
(11,65,1,0,0,0,1,0),
(11,66,1,0,0,0,1,0),
(11,67,1,0,0,0,1,0),
(11,68,1,0,0,0,1,0),
(11,69,1,0,0,0,1,0),
(11,70,1,0,0,0,1,0),
(11,71,1,0,0,0,1,0),
(11,72,1,0,0,0,1,0),
(11,73,1,0,0,0,1,0),
(11,74,1,0,0,0,1,0),
(11,75,1,0,0,0,1,0),
(11,76,1,0,0,0,1,0),
(11,77,1,0,0,0,1,0),
(11,78,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(11,79,1,0,0,0,1,0),
(11,80,1,0,0,0,1,0),
(11,81,1,0,0,0,1,0),
(11,82,1,0,0,0,1,0),
(11,83,1,0,0,0,1,0),
(11,84,1,0,0,0,1,0),
(11,85,1,0,0,0,1,0),
(11,86,1,0,0,0,1,0),
(11,87,1,0,0,0,1,0),
(11,88,1,0,0,0,1,0),
(11,89,1,0,0,0,1,0),
(11,90,1,0,0,0,1,0),
(11,91,1,0,0,0,1,0),
(11,92,1,0,0,0,1,0),
(11,93,1,0,0,0,1,0),
(11,94,1,0,0,0,1,0),
(11,95,1,0,0,0,1,0),
(11,96,1,0,0,0,1,0),
(11,97,1,0,0,0,1,0),
(11,98,1,0,0,0,1,0),
(11,99,1,0,0,0,1,0),
(11,100,1,0,0,0,1,0),
(11,101,1,0,0,0,1,0),
(11,102,1,0,0,0,1,0),
(11,103,1,0,0,0,1,0),
(11,104,1,0,0,0,1,0),
(11,105,1,0,0,0,1,0),
(11,106,1,0,0,0,1,0),
(11,107,1,0,0,0,1,0),
(11,108,1,0,0,0,1,0),
(11,109,1,0,0,0,1,0),
(11,110,1,0,0,0,1,0),
(11,111,1,0,0,0,1,0),
(11,112,1,0,0,0,1,0),
(11,113,1,0,0,0,1,0),
(11,114,1,0,0,0,1,0),
(11,115,1,0,0,0,1,0),
(11,116,1,0,0,0,1,0),
(11,117,1,0,0,0,1,0),
(11,118,1,0,0,0,1,0),
(11,119,1,0,0,0,1,0),
(11,120,1,0,0,0,1,0),
(11,121,1,0,0,0,1,0),
(11,122,1,0,0,0,1,0),
(11,123,1,0,0,0,1,0),
(11,124,1,0,0,0,1,0),
(11,125,1,0,0,0,1,0),
(11,126,1,0,0,0,1,0),
(11,127,1,0,0,0,1,0),
(11,128,1,0,0,0,1,0),
(11,129,1,0,0,0,1,0),
(11,130,1,0,0,0,1,0),
(11,131,1,0,0,0,1,0),
(11,132,1,0,0,0,1,0),
(11,133,1,0,0,0,1,0),
(11,134,1,0,0,0,1,0),
(11,135,1,0,0,0,1,0),
(11,136,1,0,0,0,1,0),
(11,137,1,0,0,0,1,0),
(11,138,1,0,0,0,1,0),
(11,139,1,0,0,0,1,0),
(11,140,1,0,0,0,1,0),
(11,141,1,0,0,0,1,0),
(11,142,1,0,0,0,1,0),
(11,143,1,0,0,0,1,0),
(11,144,1,0,0,0,1,0),
(11,145,1,0,0,0,1,0),
(11,146,1,0,0,0,1,0),
(11,147,1,0,0,0,1,0),
(11,148,1,0,0,0,1,0),
(11,149,1,0,0,0,1,0),
(11,150,1,0,0,0,1,0),
(11,151,1,0,0,0,1,0),
(11,152,1,0,0,0,1,0),
(11,153,1,0,0,0,1,0),
(11,154,1,0,0,0,1,0),
(11,155,1,0,0,0,1,0),
(11,156,1,0,0,0,1,0),
(11,157,1,0,0,0,1,0),
(11,158,1,0,0,0,1,0),
(11,159,1,0,0,0,1,0),
(11,160,1,0,0,0,1,0),
(11,161,1,0,0,0,1,0),
(11,162,1,0,0,0,1,0),
(11,163,1,0,0,0,1,0),
(11,164,1,0,0,0,1,0),
(11,165,1,0,0,0,1,0),
(11,166,1,0,0,0,1,0),
(11,167,1,0,0,0,1,0),
(11,168,1,0,0,0,1,0),
(11,169,1,0,0,0,1,0),
(11,170,1,0,0,0,1,0),
(11,171,1,0,0,0,1,0),
(11,172,1,0,0,0,1,0),
(11,173,1,0,0,0,1,0),
(11,174,1,0,0,0,1,0),
(11,175,1,0,0,0,1,0),
(11,176,1,0,0,0,1,0),
(11,177,1,0,0,0,1,0),
(11,178,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(11,179,1,0,0,0,1,0),
(11,180,1,0,0,0,1,0),
(11,181,1,0,0,0,1,0),
(11,183,1,0,0,0,1,0),
(11,185,1,0,0,0,1,0),
(11,186,1,0,0,0,1,0),
(11,187,1,0,0,0,1,0),
(11,188,1,0,0,0,1,0),
(11,189,1,0,0,0,1,0),
(11,190,1,0,0,0,1,0),
(11,191,1,0,0,0,1,0),
(11,192,1,0,0,0,1,0),
(11,193,1,0,0,0,1,0),
(11,194,1,0,0,0,1,0),
(11,195,1,0,0,0,1,0),
(11,196,1,0,0,0,1,0),
(11,197,1,0,0,0,1,0),
(11,198,1,0,0,0,1,0),
(11,199,1,0,0,0,1,0),
(11,200,1,0,0,0,1,0),
(11,201,1,0,0,0,1,0),
(11,202,1,0,0,0,1,0),
(11,203,1,0,0,0,1,0),
(11,204,1,0,0,0,1,0),
(11,205,1,0,0,0,1,0),
(11,206,1,0,0,0,1,0),
(11,207,1,0,0,0,1,0),
(11,208,1,0,0,0,1,0),
(11,209,1,0,0,0,1,0),
(11,210,1,0,0,0,1,0),
(11,211,1,0,0,0,1,0),
(11,212,1,0,0,0,1,0),
(11,213,1,0,0,0,1,0),
(11,214,1,0,0,0,1,0),
(11,215,1,0,0,0,1,0),
(11,216,1,0,0,0,1,0),
(11,217,1,0,0,0,1,0),
(11,218,1,0,0,0,1,0),
(11,219,1,0,0,0,1,0),
(11,220,1,0,0,0,1,0),
(11,221,1,0,0,0,1,0),
(11,222,1,0,0,0,1,0),
(11,232,1,0,0,0,1,0),
(11,233,1,0,0,0,1,0),
(11,234,1,0,0,0,1,0),
(11,235,1,0,0,0,1,0),
(11,236,1,0,0,0,1,0),
(11,237,1,0,0,0,1,0),
(11,238,1,0,0,0,1,0),
(11,242,1,0,0,0,1,0),
(11,243,1,0,0,0,1,0);

-- role_special_permissions (37 rows)
INSERT INTO `role_special_permissions` (`role_id`,`perm_key`,`perm_value`) VALUES
(2,'closed_period_changes','0'),
(2,'coa_changes','1'),
(2,'credit_limit_override','0'),
(2,'design_reports','1'),
(2,'max_amount',''),
(2,'max_discount_pct','0'),
(2,'max_price_override_pct','0'),
(2,'view_bank_balances','1'),
(2,'view_costs','1'),
(3,'credit_limit_override','0'),
(3,'max_amount','50000'),
(3,'max_discount_pct','10'),
(3,'max_price_override_pct','5'),
(3,'view_bank_balances','0'),
(3,'view_costs','0'),
(4,'max_amount','100000'),
(4,'view_bank_balances','0'),
(4,'view_costs','1'),
(5,'max_amount','20000'),
(5,'view_costs','0'),
(6,'max_discount_pct','5'),
(6,'max_price_override_pct','0'),
(6,'view_costs','0'),
(7,'max_amount','0'),
(7,'max_discount_pct','5'),
(7,'max_price_override_pct','0'),
(7,'view_costs','0'),
(8,'max_amount','20000'),
(8,'max_discount_pct','30'),
(8,'max_price_override_pct','20'),
(8,'view_costs','0'),
(9,'max_amount','0'),
(9,'view_costs','0'),
(10,'max_amount','0'),
(10,'view_costs','0'),
(11,'view_bank_balances','1'),
(11,'view_costs','1');

-- audit_trail (6 rows)
INSERT INTO `audit_trail` (`id`,`created_at`,`user_id`,`username`,`user_roles`,`ip_address`,`workstation`,`site_id`,`terminal_id`,`module`,`page_key`,`action`,`record_type`,`record_id`,`record_ref`,`amount`,`changes`,`snapshot`,`reason`,`approved_by`) VALUES
(1,'2026-11-27 00:03:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',1,'Maria Santos',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Maria Santos (Sales representative)',NULL),
(2,'2026-11-27 00:03:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',2,'Jose Reyes',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Jose Reyes (Sales representative)',NULL),
(3,'2026-11-27 00:03:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',3,'Rico Mendoza',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Rico Mendoza (Van salesman)',NULL),
(4,'2026-11-27 00:03:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',4,'Arnel Cruz',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Arnel Cruz (Van salesman)',NULL),
(5,'2026-11-27 00:03:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',5,'Ella Ramos',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Ella Ramos (Cashier)',NULL),
(6,'2026-11-27 00:03:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin','admin.multi_company','multi_company_setup','company',1,'Your Company Name',NULL,NULL,NULL,'Registered as Company 1 of the platform. Company Owner: admin. Super Admin: superadmin.',NULL);

-- sequences (31 rows)
INSERT INTO `sequences` (`seq_key`,`prefix`,`next_no`,`pad`) VALUES
('adjustment','ADJ-',1,5),
('advance_apply','AAP-',1,5),
('allocation','AL-',1,5),
('asset','FA-',1,5),
('bill','BILL-',1,5),
('build','BLD-',1,5),
('cash_voucher','CAV-',1,5),
('check','',1001,4),
('crate','',1,1),
('credit_memo','CM-',1,5),
('debit_memo','DM-',1,5),
('deposit','DEP-',1,5),
('estimate','EST-',1,5),
('finance_charge','FC-',1,5),
('inv_dispatch','DSP-',1,5),
('inv_transfer','IT-',1,5),
('invoice','INV-',1,5),
('item_receipt','IR-',1,5),
('journal','JE-',1,5),
('maintenance','MNT-',1,5),
('payment','PMT-',1,5),
('pos','POS-',1,6),
('processing','PRC-',1,5),
('purchase_order','PO-',1,5),
('sales_order','SO-',1,5),
('sales_receipt','SR-',1,5),
('shortage','SHC-',1,5),
('statement_charge','SC-',1,5),
('transfer','TRF-',1,5),
('transfer_closing','TC-',1,5),
('vendor_advance','ADV-',1,5);

-- accounts (77 rows)
INSERT INTO `accounts` (`id`,`code`,`name`,`account_type`,`category`,`normal_balance`,`parent_id`,`description`,`bank_account_no`,`with_sl`,`is_active`,`is_system`,`created_at`,`updated_at`) VALUES
(1,'1000','Cash','Bank','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(2,'1001','Cash on Hand - Store Registers','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(3,'1005','Petty Cash Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(4,'1006','Revolving Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(5,'1010','Cash in Bank - BDO Checking','Bank','Asset','Debit',1,NULL,'0012-3456-7890',0,1,0,'2026-11-27 00:03:03',NULL),
(6,'1020','Cash in Bank - BPI Savings','Bank','Asset','Debit',1,NULL,'1234-5678-90',0,1,0,'2026-11-27 00:03:03',NULL),
(7,'1025','Cash in Bank - Metrobank','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(8,'1030','Cash in Bank - EastWest','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(9,'1035','Cash in Bank - GoTyme Bank','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(10,'1040','Cash in Bank - BOC','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(11,'1050','Undeposited Funds','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(12,'1060','Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(13,'1065','E-wallet Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(14,'1070','P.O. Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(15,'1100','Accounts Receivable','Accounts Receivable','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(16,'1120','Shortage Receivable - Employees','Accounts Receivable','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(17,'1150','Allowance for Doubtful Accounts','Other Current Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(18,'1200','Inventory','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(19,'1300','Input Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(20,'1310','Creditable Withholding Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(21,'1315','Creditable VAT Withheld','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(22,'1400','Prepaid Expenses','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(23,'1410','Advances to Suppliers','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(24,'1500','Land','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(25,'1510','Building','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(26,'1515','Accumulated Depreciation - Building','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(27,'1520','Machinery and Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(28,'1525','Accumulated Depreciation - Machinery','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(29,'1530','Transportation Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(30,'1535','Accumulated Depreciation - Transportation','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(31,'1540','Furniture and Fixtures','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(32,'1545','Accumulated Depreciation - Furniture','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(33,'1550','Computer and POS Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(34,'1555','Accumulated Depreciation - Computer and POS','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(35,'1600','Security Deposits','Other Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(36,'2000','Accounts Payable','Accounts Payable','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(37,'2050','Company Credit Card','Credit Card','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(38,'2100','Output Tax','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(39,'2110','Withholding Tax Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(40,'2115','VAT Withheld Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(41,'2120','Gift Vouchers Outstanding','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(42,'2130','Customer Deposits','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(43,'2200','Accrued Expenses','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(44,'2500','Loans Payable','Long Term Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(45,'3000','Owner\'s Capital','Equity','Equity','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(46,'3100','Owner\'s Drawings','Equity','Equity','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(47,'3200','Retained Earnings','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(48,'3900','Opening Balance Equity','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-11-27 00:03:03',NULL),
(49,'4000','Sales','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(50,'4010','Service Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(51,'4020','Delivery Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(52,'4050','Sales Returns and Allowances','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(53,'4060','Sales Discounts','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(54,'4070','Item Group Price Variance','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(55,'4110','Reimbursable Expense Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(56,'4100','Finance Charge Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(57,'4200','Interest Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(58,'4300','Gain (Loss) on Disposal of Assets','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(59,'5000','Cost of Goods Sold','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(60,'5050','Purchase Discounts','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(61,'5100','Inventory Adjustments and Shrinkage','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(62,'5200','Direct Labor Absorbed','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(63,'6000','Salaries and Wages','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(64,'6010','Rent Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(65,'6020','Utilities Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(66,'6030','Repairs and Maintenance','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(67,'6040','Office Supplies Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(68,'6050','Fuel and Oil','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(69,'6060','Meals and Representation','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(70,'6070','Professional Fees','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(71,'6080','Bank and Merchant Charges','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(72,'6090','Depreciation Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(73,'6100','Freight and Delivery','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(74,'6110','Purchases - Non-inventory','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(75,'6200','Cash Over and Short','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(76,'6900','Miscellaneous Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL),
(77,'7000','Interest Expense','Other Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-27 00:03:03',NULL);

-- default_accounts (33 rows)
INSERT INTO `default_accounts` (`setting_key`,`label`,`module`,`account_id`) VALUES
('ap','Accounts Payable','vend',36),
('ar','Accounts Receivable','cust',15),
('card_clearing','Card Clearing','pos',12),
('cash_on_hand','Cash on Hand (Register)','pos',2),
('cash_over_short','Cash Over and Short','pos',75),
('cogs','Cost of Goods Sold','inv',59),
('cvat_withheld','Creditable VAT Withheld','cust',21),
('cwt','Creditable Withholding Tax','cust',20),
('default_expense','Default Purchases / Expense','vend',74),
('ewallet_clearing','E-wallet Clearing','pos',13),
('finance_charge_income','Finance Charge Income','cust',56),
('gain_loss_disposal','Gain / Loss on Disposal of Assets','fa',58),
('group_price_variance','Item Group Price Variance','inv',54),
('input_tax','Input Tax','vend',19),
('interest_income','Interest Income','bank',57),
('inventory_adjustment','Inventory Adjustment (Shrinkage)','inv',61),
('inventory_asset','Inventory Asset','inv',18),
('merchant_fees','Bank / Merchant Charges','bank',71),
('opening_equity','Opening Balance Equity','coa',48),
('output_tax','Output Tax','cust',38),
('processing_absorbed','Processing Labor & Overhead Absorbed','inv',62),
('processing_variance','Processing / Disassembly Variance','inv',61),
('purchase_discounts','Purchase Discounts','vend',60),
('reimbursable_income','Reimbursable Expense Income','cust',55),
('retained_earnings','Retained Earnings','coa',47),
('sales_discounts','Sales Discounts','cust',53),
('sales_income','Default Sales Income','cust',49),
('sales_returns','Sales Returns and Allowances','cust',52),
('shortage_receivable','Shortage Receivable (Employees)','inv',16),
('undeposited_funds','Undeposited Funds','cust',11),
('vat_withheld_payable','VAT Withheld Payable','vend',40),
('vendor_advances','Advances to Suppliers','vend',23),
('wht_payable','Withholding Tax Payable (Expanded)','vend',39);

-- terms (5 rows)
INSERT INTO `terms` (`id`,`name`,`net_days`,`discount_pct`,`discount_days`,`is_active`) VALUES
(1,'Due on receipt',0,'0.00',0,1),
(2,'Net 15',15,'0.00',0,1),
(3,'Net 30',30,'0.00',0,1),
(4,'2% 10 Net 30',30,'2.00',10,1),
(5,'Net 60',60,'0.00',0,1);

-- tax_codes (4 rows)
INSERT INTO `tax_codes` (`id`,`code`,`name`,`rate`,`sales_account_id`,`purchase_account_id`,`is_active`) VALUES
(1,'VAT12','VAT 12%','12.000',38,19,1),
(2,'ZR','Zero-rated','0.000',38,19,1),
(3,'EX','VAT-exempt','0.000',38,19,1),
(4,'NT','Non-taxable','0.000',38,19,1);

-- payment_methods (9 rows)
INSERT INTO `payment_methods` (`id`,`name`,`method_type`,`clearing_account_id`,`is_active`,`show_in_pos`) VALUES
(1,'Cash','cash',NULL,1,1),
(2,'Check','check',NULL,1,0),
(3,'BPI','bank_transfer',6,1,1),
(4,'GCash','ewallet',13,1,1),
(5,'Metrobank','bank_transfer',7,1,1),
(6,'Bank Transfer','bank_transfer',NULL,1,0),
(7,'EastWest','bank_transfer',8,1,1),
(8,'Gotymebank','bank_transfer',9,1,1),
(9,'BOC','bank_transfer',10,1,1);

-- price_levels (10 rows)
INSERT INTO `price_levels` (`id`,`name`,`adjust_pct`,`is_active`) VALUES
(1,'Wholesale','-5.00',1),
(2,'Key Account','-8.00',1),
(3,'Retail Plus','5.00',1),
(4,'Price Level 4','0.00',1),
(5,'Price Level 5','0.00',1),
(6,'Price Level 6','0.00',1),
(7,'Price Level 7','0.00',1),
(8,'Price Level 8','0.00',1),
(9,'Price Level 9','0.00',1),
(10,'Price Level 10','0.00',1);

-- sales_reps (2 rows)
INSERT INTO `sales_reps` (`id`,`name`,`initials`,`user_id`,`commission_pct`,`rep_type`,`customer_id`,`is_active`) VALUES
(1,'Maria Santos','MS',7,'1.50','sales_rep',NULL,1),
(2,'Ella Ramos','ER',9,'0.00','cashier',NULL,1);

-- customer_types (6 rows)
INSERT INTO `customer_types` (`id`,`name`) VALUES
(1,'Supermarket'),
(2,'Restaurant'),
(3,'Market Retailer'),
(4,'Institution'),
(5,'Government'),
(6,'Employee');

-- billing_groups (1 rows)
INSERT INTO `billing_groups` (`id`,`name`) VALUES
(1,'Weekly Delivery Accounts');

-- sites (7 rows)
INSERT INTO `sites` (`id`,`code`,`name`,`site_type`,`address`,`sales_rep_id`,`is_active`) VALUES
(1,'NGA','Naga Cold Storage','warehouse',NULL,NULL,1),
(2,'NOT','Naga Outlet','store',NULL,2,1),
(3,'LGZ','Legazpi Depot','store',NULL,NULL,1),
(4,'RFT1','Reefer Truck 1','van',NULL,NULL,1),
(5,'DMG','Spoilage and Damaged','damaged',NULL,NULL,1),
(6,'VAN1','Van Store 1 (LAB 4417)','van',NULL,NULL,1),
(7,'VAN2','Van Store 2 (LAB 4428)','van',NULL,NULL,1);

-- item_categories (8 rows)
INSERT INTO `item_categories` (`id`,`name`) VALUES
(1,'Whole Chicken'),
(2,'Chicken Cuts'),
(3,'Offal and By-products'),
(4,'Processed Chicken'),
(5,'Bundles'),
(6,'Packaging'),
(7,'Services'),
(8,'Charges');

-- uom_sets (6 rows)
INSERT INTO `uom_sets` (`id`,`name`,`uom_kind`,`base_unit`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'Kilos and crates','weight','kg',1,'2026-11-27 00:03:03',NULL),
(2,'Packs and crates','count','pack',1,'2026-11-27 00:03:03',NULL),
(3,'Kilos','weight','kg',1,'2026-11-27 00:03:03',NULL),
(4,'Piece','count','pc',1,'2026-11-27 00:03:03',NULL),
(5,'Volume (L)','volume','L',1,'2026-11-27 00:03:03',NULL),
(6,'Time (hour)','time','hr',1,'2026-11-27 00:03:03',NULL);

-- uom_units (17 rows)
INSERT INTO `uom_units` (`id`,`set_id`,`code`,`name`,`factor`,`is_base`,`is_sales_default`,`is_purchase_default`,`sort_order`,`is_variable`) VALUES
(1,1,'kg','Kilogram','1.000000',1,1,0,0,0),
(2,1,'CRT','Crate (weight varies)','1.000000',0,0,1,1,1),
(3,2,'pack','Pack','1.000000',1,1,0,0,0),
(4,2,'CRT','Crate (packs vary)','1.000000',0,0,1,1,1),
(5,2,'box','Box of 20 packs','20.000000',0,0,0,2,0),
(6,3,'kg','Kilogram','1.000000',1,1,1,0,0),
(7,3,'g','Gram','0.001000',0,0,0,1,0),
(8,3,'sack','Sack of 25 kg','25.000000',0,0,0,2,0),
(9,4,'pc','Piece','1.000000',1,1,0,0,0),
(10,4,'dz','Dozen (12 pieces)','12.000000',0,0,0,1,0),
(11,4,'bundle','Bundle of 100','100.000000',0,0,1,2,0),
(12,5,'L','Liter','1.000000',1,1,1,0,0),
(13,5,'mL','Milliliter','0.001000',0,0,0,1,0),
(14,5,'gal','Gallon (3.785 L)','3.785000',0,0,0,2,0),
(15,6,'hr','Hour','1.000000',1,1,1,0,0),
(16,6,'day','Day (8 hours)','8.000000',0,0,0,1,0),
(17,6,'wk','Week (40 hours)','40.000000',0,0,0,2,0);

-- withholding_taxes (3 rows)
INSERT INTO `withholding_taxes` (`id`,`code`,`atc`,`name`,`tax_kind`,`rate`,`base_type`,`applies_to`,`payable_account_id`,`receivable_account_id`,`description`,`sort_order`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'WT-GOODS','WC158','WT on Goods','income','1.0000','net_of_vat','both',NULL,NULL,'Goods bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',10,1,'2026-11-27 00:03:03',NULL),
(2,'WT-SERVICES','WC160','WT on Services','income','2.0000','net_of_vat','both',NULL,NULL,'Services bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',20,1,'2026-11-27 00:03:03',NULL),
(3,'WT-VAT','WV010','WT on VAT','vat','5.0000','net_of_vat','both',NULL,NULL,'Creditable VAT withheld by government buyers on VATable purchases (5% of the VAT-exclusive payment)',30,1,'2026-11-27 00:03:03',NULL);

-- asset_categories (6 rows)
INSERT INTO `asset_categories` (`id`,`name`,`asset_account_id`,`accum_dep_account_id`,`dep_expense_account_id`,`default_method`,`default_life_years`,`is_active`) VALUES
(1,'Buildings',25,26,72,'straight_line','25.00',1),
(2,'Machinery and Equipment',27,28,72,'straight_line','5.00',1),
(3,'Production Machinery (usage-based)',27,28,72,'units_of_production','5.00',1),
(4,'Transportation Equipment',29,30,72,'declining_balance','5.00',1),
(5,'Furniture and Fixtures',31,32,72,'straight_line','10.00',1),
(6,'Computer and POS Equipment',33,34,72,'declining_balance','3.00',1);

-- pos_terminals (2 rows)
INSERT INTO `pos_terminals` (`id`,`code`,`name`,`site_id`,`cash_account_id`,`receipt_prefix`,`next_receipt_no`,`next_z_no`,`is_active`,`class_id`) VALUES
(1,'POS-01','Naga Outlet Counter 1',2,2,'NO1-',1,1,1,NULL),
(2,'POS-02','Legazpi Depot Counter',3,2,'LG1-',1,1,1,NULL);

-- role_sites (2 rows)
INSERT INTO `role_sites` (`role_id`,`site_id`) VALUES
(7,2),
(7,3);

-- user_sites (2 rows)
INSERT INTO `user_sites` (`user_id`,`site_id`) VALUES
(8,2),
(9,2);

-- user_terminals (2 rows)
INSERT INTO `user_terminals` (`user_id`,`terminal_id`) VALUES
(8,1),
(9,1);

-- community_channels (6 rows)
INSERT INTO `community_channels` (`id`,`slug`,`name`,`description`,`kind`,`post_policy`,`is_restricted`,`is_archived`,`sort_order`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'general','General Discussion','Everyday conversations and community interactions.','chat','everyone',0,0,10,NULL,'2026-11-27 00:03:04',NULL),
(2,'questions','Questions and Inquiries','General questions that need answers.','chat','everyone',0,0,20,NULL,'2026-11-27 00:03:04',NULL),
(3,'help','Help and Support','Help with the system, your account or a technical problem.','chat','everyone',0,0,30,NULL,'2026-11-27 00:03:04',NULL),
(4,'announcements','Announcements','Important updates from the administrators.','announcement','moderators',0,0,40,NULL,'2026-11-27 00:03:04',NULL),
(5,'suggestions','Suggestions and Feedback','Recommendations and requests for improvement.','chat','everyone',0,0,50,NULL,'2026-11-27 00:03:04',NULL),
(6,'concerns','Community Concerns','Questions and concerns that can be discussed openly.','chat','everyone',0,0,60,NULL,'2026-11-27 00:03:04',NULL);

-- community_inquiry_categories (6 rows)
INSERT INTO `community_inquiry_categories` (`id`,`name`,`description`,`sort_order`,`is_active`) VALUES
(1,'General',NULL,10,1),
(2,'Accounts and Access',NULL,20,1),
(3,'Transactions',NULL,30,1),
(4,'Reports',NULL,40,1),
(5,'Technical Issues',NULL,50,1),
(6,'Suggestions',NULL,60,1);

-- ---------------------------------------------------------------------
--  3. AUDIT TRAIL PROTECTION (created after the data is loaded)
-- ---------------------------------------------------------------------
--  Audit trail protection: entries can never be changed or deleted,
--  not even by administrators or directly in the database.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_trail_no_update;
DROP TRIGGER IF EXISTS trg_audit_trail_no_delete;

DELIMITER $$
CREATE TRIGGER trg_audit_trail_no_update BEFORE UPDATE ON audit_trail
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit trail entries are read-only and cannot be changed.';
END$$

CREATE TRIGGER trg_audit_trail_no_delete BEFORE DELETE ON audit_trail
FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit trail entries are permanent and cannot be deleted.';
END$$
DELIMITER ;

-- =====================================================================
--  4. PLATFORM (MASTER) DATABASE `gsmart_distribution_master`: 10 tables, 17 rows
--     The Super Admin, Company 1 and its Company Code, the usernames of every company.
--     Super Admin log-in: see README (System Administration > Multi-Company).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `gsmart_distribution_master` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `gsmart_distribution_master`;

DROP TABLE IF EXISTS `super_admins`;
DROP TABLE IF EXISTS `companies`;
DROP TABLE IF EXISTS `company_databases`;
DROP TABLE IF EXISTS `company_codes`;
DROP TABLE IF EXISTS `user_company_memberships`;
DROP TABLE IF EXISTS `user_company_links`;
DROP TABLE IF EXISTS `company_provisioning_log`;
DROP TABLE IF EXISTS `platform_audit`;
DROP TABLE IF EXISTS `platform_settings`;
DROP TABLE IF EXISTS `registration_attempts`;

-- =====================================================================
--  G-SMaRT Distribution System - master (platform) database
--  MySQL 5.5.3+ / 5.6 / 5.7 / 8.x and MariaDB 5.5+
--
--  One master database serves every company. It holds the companies,
--  the database each company uses, their Company Codes, which company
--  every username belongs to, the Super Admin accounts and the
--  platform's own audit log. Company records (transactions, lists,
--  users and their roles) stay in each company's own database.
--
--  The system creates this database and runs this file itself when the
--  first company is registered (System Administration > Multi-Company
--  Setup). Every statement can be run again safely.
-- =====================================================================


-- Super Admin accounts: they manage the platform and every company, and belong to no company
CREATE TABLE IF NOT EXISTS super_admins (
  id                   INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  username             VARCHAR(50)  NOT NULL,
  password_hash        VARCHAR(255) NOT NULL,
  full_name            VARCHAR(120) NOT NULL,
  email                VARCHAR(120) NULL,
  status               ENUM('active','inactive','locked') NOT NULL DEFAULT 'active',
  must_change_password TINYINT(1)   NOT NULL DEFAULT 0,
  password_changed_at  DATETIME     NULL,
  failed_attempts      INT          NOT NULL DEFAULT 0,
  last_login_at        DATETIME     NULL,
  last_login_ip        VARCHAR(45)  NULL,
  created_by           INT UNSIGNED NULL,
  created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_super_admins_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The companies. A company is usable only while its status is 'active'.
CREATE TABLE IF NOT EXISTS companies (
  id                  INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name                VARCHAR(150) NOT NULL,
  address             VARCHAR(255) NULL,
  contact_person      VARCHAR(120) NULL,
  phone               VARCHAR(60)  NULL,
  email               VARCHAR(120) NULL,
  tin                 VARCHAR(40)  NULL,
  status              ENUM('provisioning','active','failed','inactive') NOT NULL DEFAULT 'provisioning',
  owner_user_id       INT UNSIGNED NULL,               -- the Company Owner: a user id inside the company database
  require_approval    TINYINT(1)   NOT NULL DEFAULT 1, -- employees who join with the Company Code wait for approval
  join_role_id        INT UNSIGNED NULL,               -- role suggested for (or, without approval, given to) employees who join
  template_company_id INT UNSIGNED NULL,               -- the company whose set-up was copied
  notes               VARCHAR(255) NULL,
  last_error          TEXT         NULL,               -- why the last set-up attempt failed
  created_by          INT UNSIGNED NULL,               -- super_admins.id
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  activated_at        DATETIME     NULL,
  deactivated_at      DATETIME     NULL,
  updated_at          DATETIME     NULL,
  UNIQUE KEY uq_companies_name (name),
  KEY ix_companies_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Company -> database. The database name is made by the system and never typed by a user.
CREATE TABLE IF NOT EXISTS company_databases (
  company_id          INT UNSIGNED NOT NULL PRIMARY KEY,
  db_name             VARCHAR(64)  NOT NULL,
  is_primary          TINYINT(1)   NOT NULL DEFAULT 0, -- the original database (Company 1): never created or dropped by the platform
  created_by_platform TINYINT(1)   NOT NULL DEFAULT 0, -- 1 = the platform created it (and may drop it if its set-up fails)
  table_count         INT          NULL,
  triggers_ok         TINYINT(1)   NOT NULL DEFAULT 0, -- audit trail protection triggers are in place
  created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  verified_at         DATETIME     NULL,
  UNIQUE KEY uq_company_databases_name (db_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Company Codes: an employee types one to say which company they are joining. It is never a password.
-- Only one code of a company is 'active'; a regenerated code retires the old one for good.
CREATE TABLE IF NOT EXISTS company_codes (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  company_id  INT UNSIGNED NOT NULL,
  code        VARCHAR(20)  NOT NULL,
  status      ENUM('active','disabled','retired') NOT NULL DEFAULT 'active',
  expires_at  DATETIME     NULL,
  created_by  VARCHAR(80)  NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  retired_at  DATETIME     NULL,
  UNIQUE KEY uq_company_codes_code (code),
  KEY ix_company_codes_company (company_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which company every username belongs to (the log-in page reads it). Usernames are unique across companies.
-- The account itself (password, roles, lock-out) stays in the company database.
CREATE TABLE IF NOT EXISTS user_company_memberships (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  company_id      INT UNSIGNED NOT NULL,
  company_user_id INT UNSIGNED NOT NULL,
  username        VARCHAR(50)  NOT NULL,
  full_name       VARCHAR(120) NULL,
  email           VARCHAR(120) NULL,
  status          VARCHAR(12)  NOT NULL DEFAULT 'active',  -- active, inactive, locked, pending, rejected
  created_via     VARCHAR(12)  NOT NULL DEFAULT 'admin',   -- admin, registration, provisioning, setup (never 'link': see user_company_links)
  joined_at       DATETIME     NULL,
  updated_at      DATETIME     NULL,
  UNIQUE KEY uq_memberships_username (username),
  UNIQUE KEY uq_memberships_company_user (company_id, company_user_id),
  KEY ix_memberships_company (company_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Access to another company: a user of one company (home) who may also work in another company with the same
-- log-in, switching between them from the top bar. The other company holds a linked account (users.created_via =
-- 'link') with its own roles; it never logs in by itself. Made by that company's administrator (User Accounts).
CREATE TABLE IF NOT EXISTS user_company_links (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  home_company_id INT UNSIGNED NOT NULL,
  home_user_id    INT UNSIGNED NOT NULL,
  username        VARCHAR(50)  NOT NULL,
  company_id      INT UNSIGNED NOT NULL,              -- the company the user may switch to
  company_user_id INT UNSIGNED NOT NULL,              -- the linked account in that company's database
  status          VARCHAR(12)  NOT NULL DEFAULT 'active',  -- active, removed
  granted_by      VARCHAR(80)  NULL,
  granted_at      DATETIME     NULL,
  removed_by      VARCHAR(80)  NULL,
  removed_at      DATETIME     NULL,
  removed_reason  VARCHAR(255) NULL,
  last_switch_at  DATETIME     NULL,
  UNIQUE KEY uq_links_home_company (home_company_id, home_user_id, company_id),
  UNIQUE KEY uq_links_company_user (company_id, company_user_id),
  KEY ix_links_company (company_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every step of setting up a company database, for the Super Admin to follow and to recover from
CREATE TABLE IF NOT EXISTS company_provisioning_log (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  company_id INT UNSIGNED NOT NULL,
  attempt    INT          NOT NULL DEFAULT 1,
  step       VARCHAR(60)  NOT NULL,
  ok         TINYINT(1)   NOT NULL DEFAULT 1,
  message    TEXT         NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_provisioning_company (company_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The platform's own audit log: companies created, changed, switched on and off, owners, codes,
-- Super Admin log-ins and every time a Super Admin opened a company
CREATE TABLE IF NOT EXISTS platform_audit (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actor_type  VARCHAR(12)  NOT NULL,              -- super_admin, owner, user, guest, system
  actor_id    INT UNSIGNED NULL,
  actor_name  VARCHAR(80)  NULL,
  company_id  INT UNSIGNED NULL,
  action      VARCHAR(40)  NOT NULL,
  details     TEXT         NULL,
  ip_address  VARCHAR(45)  NULL,
  KEY ix_platform_audit_company (company_id, id),
  KEY ix_platform_audit_action (action, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Platform-wide settings (database name prefix for new companies, default approval rule, ...)
CREATE TABLE IF NOT EXISTS platform_settings (
  setting_key   VARCHAR(60) NOT NULL PRIMARY KEY,
  setting_value TEXT        NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Attempts on the join page, so Company Codes cannot be guessed by trying many of them
CREATE TABLE IF NOT EXISTS registration_attempts (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  ip_address  VARCHAR(45)  NOT NULL,
  ok          TINYINT(1)   NOT NULL DEFAULT 0,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_registration_attempts_ip (ip_address, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- super_admins (1 rows)
INSERT INTO `super_admins` (`id`,`username`,`password_hash`,`full_name`,`email`,`status`,`must_change_password`,`password_changed_at`,`failed_attempts`,`last_login_at`,`last_login_ip`,`created_by`,`created_at`) VALUES
(1,'superadmin','$2y$10$GE9vlMo1WL54lSRg3rOQi.uiQU3TWz.FS0i1YZ6pUk0X6oMTD7PTy','Platform Super Admin','superadmin@local.test','active',0,'2026-11-27 00:03:04',0,NULL,NULL,NULL,'2026-11-27 00:03:04');

-- companies (1 rows)
INSERT INTO `companies` (`id`,`name`,`address`,`contact_person`,`phone`,`email`,`tin`,`status`,`owner_user_id`,`require_approval`,`join_role_id`,`template_company_id`,`notes`,`last_error`,`created_by`,`created_at`,`activated_at`,`deactivated_at`,`updated_at`) VALUES
(1,'Your Company Name','Company address','System Administrator',NULL,NULL,NULL,'active',1,1,NULL,NULL,'The original database, registered as Company 1',NULL,NULL,'2026-11-27 00:03:04','2026-11-27 00:03:04',NULL,NULL);

-- company_databases (1 rows)
INSERT INTO `company_databases` (`company_id`,`db_name`,`is_primary`,`created_by_platform`,`table_count`,`triggers_ok`,`created_at`,`verified_at`) VALUES
(1,'gsmart_distribution',1,0,110,1,'2026-11-27 00:03:04','2026-11-27 00:03:04');

-- company_codes (1 rows)
INSERT INTO `company_codes` (`id`,`company_id`,`code`,`status`,`expires_at`,`created_by`,`created_at`,`retired_at`) VALUES
(1,1,'YCNJNAPK','active',NULL,'setup:admin','2026-11-27 00:03:04',NULL);

-- user_company_memberships (11 rows)
INSERT INTO `user_company_memberships` (`id`,`company_id`,`company_user_id`,`username`,`full_name`,`email`,`status`,`created_via`,`joined_at`,`updated_at`) VALUES
(1,1,1,'admin','System Administrator','admin@northpoint.test','active','admin','2026-11-27 00:03:03','2026-11-27 00:03:04'),
(2,1,2,'accountant','Ana Cruz','accountant@northpoint.test','active','admin','2026-11-27 00:03:03','2026-11-27 00:03:04'),
(3,1,3,'arclerk','Ben Garcia','arclerk@northpoint.test','active','admin','2026-11-27 00:03:03','2026-11-27 00:03:04'),
(4,1,4,'apclerk','Carla Lim','apclerk@northpoint.test','active','admin','2026-11-27 00:03:03','2026-11-27 00:03:04'),
(5,1,5,'invclerk','Dan Villanueva','invclerk@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04'),
(6,1,6,'allocator','Lito Bautista','allocator@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04'),
(7,1,7,'salesrep','Maria Santos','salesrep@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04'),
(8,1,8,'supervisor','Fred Tan','supervisor@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04'),
(9,1,9,'cashier1','Ella Ramos','cashier1@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04'),
(10,1,10,'glenn','Glenn Abad','glenn@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04'),
(11,1,11,'auditor','Grace Uy','auditor@northpoint.test','active','admin','2026-11-27 00:03:04','2026-11-27 00:03:04');

-- platform_audit (1 rows)
INSERT INTO `platform_audit` (`id`,`created_at`,`actor_type`,`actor_id`,`actor_name`,`company_id`,`action`,`details`,`ip_address`) VALUES
(1,'2026-11-27 00:03:04','user',1,'admin',1,'platform_setup','The existing database was registered as Company 1 (Your Company Name); owner admin; Super Admin superadmin created','cli');

-- platform_settings (1 rows)
INSERT INTO `platform_settings` (`setting_key`,`setting_value`) VALUES
('default_require_approval','1');

USE `gsmart_distribution`;
SET FOREIGN_KEY_CHECKS = 1;
