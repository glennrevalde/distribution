-- =====================================================================
--  G-SMaRT Distribution System - complete database with sample data
--  Generated 2026-11-25 21:50:06 +08:00 from database `gsmart_distribution`
--  109 tables, 3385 rows (112 transactions)
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

-- ---------------------------------------------------------------------
--  2. DATA
-- ---------------------------------------------------------------------

-- settings (54 rows)
INSERT INTO `settings` (`setting_key`,`setting_value`,`updated_at`) VALUES
('adopt_group_price','1','2026-11-25 21:50:03'),
('allow_negative_stock','1','2026-11-25 21:50:03'),
('audit_retention_years','10','2026-11-25 21:50:03'),
('auto_recost_limit','2000','2026-11-25 21:50:03'),
('auto_recost_scope','process','2026-11-25 21:50:03'),
('bir_signatory_name','','2026-11-25 21:50:03'),
('bir_signatory_tin','','2026-11-25 21:50:03'),
('bir_signatory_title','','2026-11-25 21:50:03'),
('bir_zip_code','','2026-11-25 21:50:03'),
('block_expired_sales','0','2026-11-25 21:50:03'),
('block_zero_cost_processing','1','2026-11-25 21:50:03'),
('block_zero_cost_sales','1','2026-11-25 21:50:03'),
('bt_printer_autoprint','0','2026-11-25 21:50:03'),
('bt_printer_cut','0','2026-11-25 21:50:03'),
('bt_printer_enabled','0','2026-11-25 21:50:03'),
('bt_printer_feed','4','2026-11-25 21:50:03'),
('bt_printer_name','','2026-11-25 21:50:03'),
('bt_printer_width','32','2026-11-25 21:50:03'),
('closing_date','2026-09-06','2026-11-25 21:50:05'),
('company_address','Km 2 Diversion Road, Naga City, Camarines Sur','2026-11-25 21:50:03'),
('company_email','accounting@northpoint.test','2026-11-25 21:50:03'),
('company_logo','','2026-11-25 21:50:03'),
('company_name','Northpoint Cold Chain Distributors Inc.','2026-11-25 21:50:03'),
('company_phone','(054) 881-2047','2026-11-25 21:50:03'),
('company_tin','000-482-915-000','2026-11-25 21:50:03'),
('costing_method','weighted_average','2026-11-25 21:50:03'),
('expiry_warn_days','30','2026-11-25 21:50:03'),
('finance_charge_grace_days','0','2026-11-25 21:50:03'),
('finance_charge_min','50','2026-11-25 21:50:03'),
('finance_charge_on_charges','0','2026-11-25 21:50:03'),
('finance_charge_rate','12','2026-11-25 21:50:03'),
('fiscal_year_start_month','1','2026-11-25 21:50:03'),
('item_search_by_page','','2026-11-25 21:50:03'),
('item_search_format','code_name','2026-11-25 21:50:03'),
('large_discount_pct','10','2026-11-25 21:50:03'),
('logo_targets','','2026-11-25 21:50:03'),
('max_failed_logins','5','2026-11-25 21:50:03'),
('pos_posting_mode','per_sale','2026-11-25 21:50:03'),
('pos_receipt_footer','Thank you for shopping!\nThis serves as your official receipt.','2026-11-25 21:50:03'),
('pos_receipt_show_customer','1','2026-11-25 21:50:03'),
('pos_receipt_title','OFFICIAL RECEIPT','2026-11-25 21:50:03'),
('pos_receipt_title_charge','CHARGE INVOICE','2026-11-25 21:50:03'),
('pos_receipt_title_payment','ACKNOWLEDGEMENT RECEIPT','2026-11-25 21:50:03'),
('pos_receipt_title_return','RETURN / REFUND','2026-11-25 21:50:03'),
('processing_cost_tolerance','2','2026-11-25 21:50:03'),
('pw_expiry_days','90','2026-11-25 21:50:03'),
('pw_min_length','8','2026-11-25 21:50:03'),
('pw_require_number','1','2026-11-25 21:50:03'),
('pw_require_symbol','1','2026-11-25 21:50:03'),
('pw_require_upper','1','2026-11-25 21:50:03'),
('session_timeout_minutes','30','2026-11-25 21:50:03'),
('track_expiry','0','2026-11-25 21:50:03'),
('track_group_sales','1','2026-11-25 21:50:03'),
('withholding_agent','1','2026-11-25 21:50:03');

-- users (11 rows)
INSERT INTO `users` (`id`,`username`,`password_hash`,`full_name`,`email`,`employee_no`,`pos_default_site_id`,`pos_default_class_id`,`status`,`approval_status`,`created_via`,`approved_by`,`approved_at`,`rejected_reason`,`is_platform`,`must_change_password`,`password_changed_at`,`failed_attempts`,`last_login_at`,`last_login_ip`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'admin','$2y$10$9AnC04V2fYeJYOCeqp4Q1e5XtVU5OjpYZoqJEXEu58G2mGG44IE2y','System Administrator','admin@northpoint.test','EMP-001',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,1,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(2,'accountant','$2y$10$/8sIJw3m0bWnNDR1iANBbeOROSnHQyXe6iHLYkafGpMeufmgAwJbK','Ana Cruz','accountant@northpoint.test','EMP-002',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(3,'arclerk','$2y$10$6qXtb3NvwXSiJoEAhjVymOHQjZzMHYs7qtHQfD2CieNID5lB8GMzW','Ben Garcia','arclerk@northpoint.test','EMP-003',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(4,'apclerk','$2y$10$0tEe0kLzka.HSmxHeLMlSexGHyJn76s8xwbPqCIzY7pc5PLHdOt0e','Carla Lim','apclerk@northpoint.test','EMP-004',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',2,NULL,NULL,NULL,'2026-11-25 21:50:03','2026-11-25 21:50:05'),
(5,'invclerk','$2y$10$yUp6sNI3O9iIx5gnlWxKHeBF8J9bv7xGoMyT/iXdk/MD87bG6R72K','Dan Villanueva','invclerk@northpoint.test','EMP-005',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(6,'allocator','$2y$10$joJmjRlKDjQ.BXNZRe2ls./bOBw8G6HCW7k4eprE1VAJc7qMlVEpu','Lito Bautista','allocator@northpoint.test','EMP-006',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(7,'salesrep','$2y$10$byr591xcQL5IE6GsIH09uOdMuKzNtS6Ipw.JC6YcZHSC28eDDse4G','Maria Santos','salesrep@northpoint.test','EMP-007',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(8,'supervisor','$2y$10$yAyTi1k24zkA0UvX8M2dvOrvibxlg6N2NfvGKrFIONJqZKwScQ0i.','Fred Tan','supervisor@northpoint.test','EMP-008',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(9,'cashier1','$2y$10$zHmDCPZLf9X8fuRd3S/jR.qRGWAOegSRphKy3vblZjNbx6B/8hMOW','Ella Ramos','cashier1@northpoint.test','EMP-009',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(10,'glenn','$2y$10$.HdXpqd4MqwuA2wB5oIq5O3vqEj2SY55CAHH40nRIW96Y/2woR3bq','Glenn Abad','glenn@northpoint.test','EMP-010',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:03',0,NULL,NULL,NULL,'2026-11-25 21:50:03',NULL),
(11,'auditor','$2y$10$gNf4BFehLd9RbISb14P7QOJeazYotYjDjfejsKgy8/6vkMJtOHdyK','Grace Uy','auditor@northpoint.test','EMP-011',NULL,NULL,'active','approved','admin',NULL,NULL,NULL,0,0,'2026-11-25 21:50:04',0,NULL,NULL,NULL,'2026-11-25 21:50:04',NULL);

-- roles (11 rows)
INSERT INTO `roles` (`id`,`name`,`description`,`is_admin`,`is_system`,`all_sites`,`created_at`,`updated_at`) VALUES
(1,'Administrator','Everything in every module, including user accounts, roles, page access, the closing date, and the audit trail.',1,1,1,'2026-11-25 21:50:03',NULL),
(2,'Accountant','Chart of Accounts, Fixed Assets, Banking and reconciliation, the BIR Reports and Withholding Tax Table, all module reports, and the financial statements.',0,1,1,'2026-11-25 21:50:03',NULL),
(3,'A/R Clerk','Customers module transactions and the Customer and Receivables reports.',0,1,1,'2026-11-25 21:50:03',NULL),
(4,'A/P Clerk','Vendors module transactions, Pay Bills, advances to suppliers, the Vendors and Payables reports, and BIR Form 2307 for suppliers.',0,1,1,'2026-11-25 21:50:03',NULL),
(5,'Inventory Clerk','Items, sites, receiving, adjustments, assembly builds, disassembly and processing orders, stock counts, and inventory quantity reports.',0,1,1,'2026-11-25 21:50:03',NULL),
(6,'Sales Representative','Estimates, sales orders, and invoices, and the Sales reports.',0,1,1,'2026-11-25 21:50:03',NULL),
(7,'Cashier','POS sales, returns, and cash drops at the assigned terminal only.',0,1,0,'2026-11-25 21:50:03',NULL),
(8,'POS Supervisor','Everything a cashier can do, plus approving voids, refunds, price overrides, and large discounts, and running X- and Z-readings.',0,1,1,'2026-11-25 21:50:03',NULL),
(9,'Allocation Officer','Supplier Allocation, the Supplier Items of each supplier, Pick-Up Supplier Items, the Crate Center and the crate and allocation reports.',0,1,1,'2026-11-25 21:50:03',NULL),
(10,'Pick-Up Crew','The pick-ups assigned to them: weighing and dating the crates at the supplier and marking the pick-up complete.',0,1,1,'2026-11-25 21:50:03',NULL),
(11,'Auditor','View-only access to all transactions, reports, and the audit trail. Cannot create or change anything.',0,1,1,'2026-11-25 21:50:03',NULL);

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

-- pages (238 rows)
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
(69,'cust.credit_memos',4,'Create Credit Memos/Refunds','transaction','Transactions',690,1,NULL),
(70,'rpt.ar_aging_summary',4,'A/R Aging Summary','report','Customer and Receivables Reports',700,1,NULL),
(71,'rpt.ar_aging_detail',4,'A/R Aging Detail','report','Customer and Receivables Reports',710,1,NULL),
(72,'rpt.customer_balance_summary',4,'Customer Balance Summary','report','Customer and Receivables Reports',720,1,NULL),
(73,'rpt.customer_balance_detail',4,'Customer Balance Detail','report','Customer and Receivables Reports',730,1,NULL),
(74,'rpt.open_invoices',4,'Open Invoices','report','Customer and Receivables Reports',740,1,NULL),
(75,'rpt.collections',4,'Collections Report','report','Customer and Receivables Reports',750,1,NULL),
(76,'rpt.avg_days_summary',4,'Average Days to Pay Summary','report','Customer and Receivables Reports',760,1,NULL),
(77,'rpt.avg_days_detail',4,'Average Days to Pay','report','Customer and Receivables Reports',770,1,NULL),
(78,'rpt.ar_graph',4,'Accounts Receivable Graph','report','Customer and Receivables Reports',780,1,NULL),
(79,'rpt.unbilled_costs',4,'Unbilled Cost by Job','report','Customer and Receivables Reports',790,1,NULL),
(80,'rpt.txn_list_customer',4,'Transaction List by Customer','report','Customer and Receivables Reports',800,1,NULL),
(81,'rpt.item_price_list',4,'Item Price List','report','Customer and Receivables Reports',810,1,NULL),
(82,'rpt.sales_customer_summary',4,'Sales by Customer Summary','report','Sales Reports',820,1,NULL),
(83,'rpt.forecast_vs_actual',4,'Forecast vs Actual by Customer','report','Sales Reports',830,1,NULL),
(84,'rpt.sales_customer_detail',4,'Sales by Customer Detail','report','Sales Reports',840,1,NULL),
(85,'rpt.income_customer_summary',4,'Income by Customer Summary','report','Sales Reports',850,1,NULL),
(86,'rpt.income_customer_detail',4,'Income by Customer Detail','report','Sales Reports',860,1,NULL),
(87,'rpt.sales_item_summary',4,'Sales by Item Summary','report','Sales Reports',870,1,NULL),
(88,'rpt.sales_item_detail',4,'Sales by Item Detail','report','Sales Reports',880,1,NULL),
(89,'rpt.sales_item_group',4,'Sales by Item Group','report','Sales Reports',890,1,NULL),
(90,'rpt.sales_rep_summary',4,'Sales by Rep Summary','report','Sales Reports',900,1,NULL),
(91,'rpt.sales_rep_detail',4,'Sales by Rep Detail','report','Sales Reports',910,1,NULL),
(92,'rpt.inventory_sales_site',4,'Inventory Sales by Site','report','Sales Reports',920,1,NULL),
(93,'rpt.sales_inv_movement',4,'Sales Report Through Inventory Movement','report','Sales Reports',930,1,NULL),
(94,'rpt.pending_sales',4,'Pending Sales','report','Sales Reports',940,1,NULL),
(95,'rpt.open_so_customer',4,'Open Sales Orders by Customer','report','Sales Reports',950,1,NULL),
(96,'rpt.open_so_item',4,'Open Sales Orders by Item','report','Sales Reports',960,1,NULL),
(97,'vend.center',5,'Vendor Center','center','Transactions',970,1,NULL),
(98,'vend.bill_tracker',5,'Bill Tracker','center','Transactions',980,1,NULL),
(99,'vend.bills',5,'Enter Bills','transaction','Transactions',990,1,NULL),
(100,'vend.debit_memos',5,'Supplier Debit Memos','transaction','Transactions',1000,1,NULL);
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(101,'vend.pay_bills',5,'Pay Bills','transaction','Transactions',1010,1,NULL),
(102,'vend.receipts',5,'Receipt Management','transaction','Transactions',1020,1,NULL),
(103,'vend.purchase_orders',5,'Create Purchase Orders','transaction','Transactions',1030,1,NULL),
(104,'vend.receive_bill',5,'Receive Items and Enter Bills','transaction','Transactions',1040,1,NULL),
(105,'vend.receive_items',5,'Receive Items','transaction','Transactions',1050,1,NULL),
(106,'vend.bill_received',5,'Enter Bill for Received Items','transaction','Transactions',1060,1,NULL),
(107,'vend.advances',5,'Advances to Suppliers','transaction','Transactions',1070,1,NULL),
(108,'vend.allocations',5,'Supplier Allocation','transaction','Distribution',1080,1,NULL),
(109,'vend.pickup',5,'Pick-Up Supplier Items','transaction','Distribution',1090,1,NULL),
(110,'vend.supplier_items',5,'Supplier Items','list','Distribution',1100,1,NULL),
(111,'rpt.alloc_pickup',5,'Supplier Allocation vs Pick-Up','report','Distribution Reports',1110,1,NULL),
(112,'rpt.ap_aging_summary',5,'A/P Aging Summary','report','Vendors and Payables Reports',1120,1,NULL),
(113,'rpt.ap_aging_detail',5,'A/P Aging Detail','report','Vendors and Payables Reports',1130,1,NULL),
(114,'rpt.vendor_balance_summary',5,'Vendor Balance Summary','report','Vendors and Payables Reports',1140,1,NULL),
(115,'rpt.vendor_balance_detail',5,'Vendor Balance Detail','report','Vendors and Payables Reports',1150,1,NULL),
(116,'rpt.unpaid_bills',5,'Unpaid Bills Detail','report','Vendors and Payables Reports',1160,1,NULL),
(117,'rpt.txn_list_vendor',5,'Transaction List by Vendor','report','Vendors and Payables Reports',1170,1,NULL),
(118,'rpt.vendor_contacts',5,'Vendor Contact List','report','Vendors and Payables Reports',1180,1,NULL),
(119,'rpt.expenses_vendor_summary',5,'Expenses by Vendor Summary','report','Vendors and Payables Reports',1190,1,NULL),
(120,'rpt.expenses_vendor_detail',5,'Expenses by Vendor Detail','report','Vendors and Payables Reports',1200,1,NULL),
(121,'rpt.vendor_advances',5,'Advances to Suppliers','report','Vendors and Payables Reports',1210,1,NULL),
(122,'inv.center',6,'Inventory Center','center','Transactions',1220,1,NULL),
(123,'inv.items',6,'Item List','list','Lists',1230,1,NULL),
(124,'inv.categories',6,'Category List','list','Lists',1240,1,NULL),
(125,'inv.sites',6,'Inventory Site List','list','Lists',1250,1,NULL),
(126,'inv.uom',6,'U/M Set List','list','Lists',1260,1,NULL),
(127,'inv.formulas',6,'Processing Formulas (Multi-Output BOM)','list','Lists',1270,1,NULL),
(128,'inv.transfers',6,'Transfer Inventory','transaction','Transactions',1280,1,NULL),
(129,'inv.dispatch',6,'Dispatch Inventory','transaction','Transactions',1290,1,NULL),
(130,'inv.transfer_closing',6,'Inventory Transfer Closing','transaction','Transactions',1300,1,NULL),
(131,'inv.shortages',6,'Shortage Charges','transaction','Transactions',1310,1,NULL),
(132,'inv.adjust',6,'Adjust Quantity/Value on Hand','transaction','Transactions',1320,1,NULL),
(133,'inv.build',6,'Build Assemblies','transaction','Transactions',1330,1,NULL),
(134,'inv.process',6,'Disassemble / Process Items','transaction','Transactions',1340,1,NULL),
(135,'inv.physical_count',6,'Physical Inventory Count','transaction','Transactions',1350,1,NULL),
(136,'inv.lot_check',6,'Production and Expiry Dates','transaction','Transactions',1360,1,NULL),
(137,'inv.change_prices',6,'Change Item Prices','transaction','Transactions',1370,1,NULL),
(138,'inv.set_prices',6,'Set Item Prices and Levels','transaction','Transactions',1380,1,NULL),
(139,'inv.crates',6,'Crate Center','center','Crates',1390,1,NULL),
(140,'inv.crate_convert',6,'Convert Crates to Kilos','transaction','Crates',1400,1,NULL),
(141,'inv.crate_pack',6,'Convert Kilos to Crates','transaction','Crates',1410,1,NULL),
(142,'inv.crate_move',6,'Move Crates to Another Site','transaction','Crates',1420,1,NULL),
(143,'rpt.crates_on_hand',6,'Crates Remaining by Item','report','Crate Reports',1430,1,NULL),
(144,'rpt.crate_detail',6,'Kilos per Crate by Item','report','Crate Reports',1440,1,NULL),
(145,'rpt.crates_sold',6,'Crates Sold with Production and Expiry Dates','report','Crate Reports',1450,1,NULL),
(146,'rpt.crate_movements',6,'Crate Movement History','report','Crate Reports',1460,1,NULL),
(147,'rpt.crates_received',6,'Crates Received by Supplier','report','Crate Reports',1470,1,NULL),
(148,'rpt.closing_register',6,'Inventory Transfer Closing Register','report','Shortage and Shrinkage Reports',1480,1,NULL),
(149,'rpt.shortage_item',6,'Shortages by Item','report','Shortage and Shrinkage Reports',1490,1,NULL),
(150,'rpt.shortage_site',6,'Shortages by Site','report','Shortage and Shrinkage Reports',1500,1,NULL),
(151,'rpt.shortage_rep',6,'Shortages by Sales Representative','report','Shortage and Shrinkage Reports',1510,1,NULL),
(152,'rpt.shortage_detail',6,'Shortage Detail','report','Shortage and Shrinkage Reports',1520,1,NULL),
(153,'rpt.shrinkage_item',6,'Shrinkage by Item','report','Shortage and Shrinkage Reports',1530,1,NULL),
(154,'rpt.shrinkage_detail',6,'Shrinkage Detail','report','Shortage and Shrinkage Reports',1540,1,NULL),
(155,'rpt.qoh_by_site',6,'Quantity on Hand by Site','report','Inventory Reports',1550,1,NULL),
(156,'rpt.inv_valuation_summary',6,'Inventory Valuation Summary','report','Inventory Reports',1560,1,NULL),
(157,'rpt.inv_valuation_site',6,'Inventory Valuation Summary by Site','report','Inventory Reports',1570,1,NULL),
(158,'rpt.inv_valuation_detail',6,'Inventory Valuation Detail','report','Inventory Reports',1580,1,NULL),
(159,'rpt.expiring_items',6,'Expiring and Expired Items','report','Inventory Reports',1590,1,NULL),
(160,'rpt.stock_by_lot',6,'Stock by Production and Expiry Date','report','Inventory Reports',1600,1,NULL),
(161,'rpt.avg_cost_changes',6,'Average Cost Changes','report','Inventory Reports',1610,1,NULL),
(162,'rpt.stock_status_item',6,'Inventory Stock Status by Item','report','Inventory Reports',1620,1,NULL),
(163,'rpt.stock_status_vendor',6,'Inventory Stock Status by Vendor','report','Inventory Reports',1630,1,NULL),
(164,'rpt.stock_status_site',6,'Inventory Stock Status by Site','report','Inventory Reports',1640,1,NULL),
(165,'rpt.physical_worksheet',6,'Physical Inventory Worksheet','report','Inventory Reports',1650,1,NULL),
(166,'rpt.pending_builds',6,'Pending Builds','report','Inventory Reports',1660,1,NULL),
(167,'rpt.pending_builds_site',6,'Pending Builds by Site','report','Inventory Reports',1670,1,NULL),
(168,'rpt.processing_register',6,'Processing & Disassembly Register','report','Inventory Reports',1680,1,NULL),
(169,'rpt.coproduct_costs',6,'Co-product & By-product Cost Allocation','report','Inventory Reports',1690,1,NULL),
(170,'rpt.process_yield',6,'Processing Yield Analysis','report','Inventory Reports',1700,1,NULL),
(171,'rpt.negative_inventory',6,'Negative Inventory Listing','report','Inventory Reports',1710,1,NULL),
(172,'rpt.inv_no_movement',6,'No. of Days Inventory Has No Movement','report','Inventory Reports',1720,1,NULL),
(173,'rpt.inv_custom',6,'Customized Inventory Report','report','Inventory Reports',1730,1,NULL),
(174,'rpt.inv_movement_summary',6,'Inventory Movement Summary Report','report','Inventory Reports',1740,1,NULL),
(175,'rpt.inv_movement_detail',6,'Inventory Movement Detailed Report','report','Inventory Reports',1750,1,NULL),
(176,'rpt.inv_movement_txns',6,'Inventory Movement Transactions','report','Inventory Reports',1760,0,NULL),
(177,'pos.register',7,'POS Register','transaction','Transactions',1770,1,NULL),
(178,'pos.fb',7,'FB POS','transaction','Transactions',1780,1,NULL),
(179,'pos.shifts',7,'Shifts, Cash Drops & Readings','transaction','Transactions',1790,1,NULL),
(180,'pos.receipts',7,'POS Receipts, Returns & Voids','transaction','Transactions',1800,1,NULL),
(181,'pos.approval_codes',7,'Approval Codes','transaction','Transactions',1810,1,NULL),
(182,'pos.terminals',7,'POS Terminals','setup','Setup',1820,1,NULL),
(183,'pos.fb_menu',7,'FB POS Menu & Groups','setup','Setup',1830,1,NULL),
(184,'rpt.pos_sales_txn',7,'POS Sales by Transaction No. (detail)','report','Reports',1840,1,NULL),
(185,'rpt.pos_sales_item',7,'POS Sales by Item','report','Reports',1850,1,NULL),
(186,'rpt.pos_sales_item_group',7,'POS Sales by Item Group','report','Reports',1860,1,NULL),
(187,'rpt.pos_sales_category',7,'POS Sales by Category','report','Reports',1870,1,NULL),
(188,'rpt.pos_sales_cashier',7,'POS Sales by Cashier & Payment Method','report','Reports',1880,1,NULL),
(189,'rpt.pos_sales_payment',7,'POS Sales by Payment Method','report','Reports',1890,0,NULL),
(190,'rpt.pos_sales_hour',7,'POS Sales by Hour','report','Reports',1900,1,NULL),
(191,'rpt.pos_daily_summary',7,'POS Daily Sales Summary','report','Reports',1910,1,NULL),
(192,'rpt.pos_readings',7,'X- and Z-Reading Summary','report','Reports',1920,1,NULL),
(193,'rpt.pos_discount_log',7,'POS Discount Log','report','Reports',1930,1,NULL),
(194,'rpt.pos_void_log',7,'POS Void and Refund Log','report','Reports',1940,1,NULL),
(195,'rpt.pos_ending_inventory',7,'Ending Inventory - POS Cashier','report','Reports',1950,1,NULL),
(196,'rpt.pos_cash_count',7,'Cash Count Sheet','report','Reports',1960,1,NULL),
(197,'bank.write_checks',8,'Write Checks','transaction','Transactions',1970,1,NULL),
(198,'bank.cash_voucher',8,'Cash Voucher','transaction','Transactions',1980,1,NULL),
(199,'bank.register',8,'Use Register','center','Transactions',1990,1,NULL),
(200,'bank.deposits',8,'Make Deposits','transaction','Transactions',2000,1,NULL);
INSERT INTO `pages` (`id`,`page_key`,`module_id`,`name`,`page_type`,`menu_group`,`sort_order`,`show_in_menu`,`description`) VALUES
(201,'bank.transfers',8,'Transfer Funds','transaction','Transactions',2010,1,NULL),
(202,'bank.reconcile',8,'Reconcile','transaction','Transactions',2020,1,NULL),
(203,'rpt.recon_summary',8,'Reconciliation Summary','report','Reports',2030,1,NULL),
(204,'rpt.recon_detail',8,'Reconciliation Detail','report','Reports',2040,1,NULL),
(205,'rpt.recon_discrepancy',8,'Reconciliation Discrepancy','report','Reports',2050,1,NULL),
(206,'rpt.check_register',8,'Check Register','report','Reports',2060,1,NULL),
(207,'bir.form_2307',9,'Print BIR Form 2307','transaction','Transactions',2070,1,NULL),
(208,'bir.wht_table',9,'Withholding Tax Table','setup','Setup',2080,1,NULL),
(209,'rpt.bir_wht_summary',9,'Summary of Taxes Withheld from Vendors/Suppliers','report','BIR Reports',2090,1,NULL),
(210,'rpt.bir_ewt_register',9,'Expanded Withholding Tax Register (1% / 2%)','report','BIR Reports',2100,1,NULL),
(211,'rpt.bir_remittance',9,'Withholding Tax Remittances (0619-E, 1601-EQ, 1600-VT)','report','BIR Reports',2110,1,NULL),
(212,'rpt.bir_vat_withholding',9,'VAT Withholding Register (1600-VT)','report','BIR Reports',2120,1,NULL),
(213,'rpt.bir_sales_register',9,'Output VAT / Sales Register','report','BIR Reports',2130,1,NULL),
(214,'rpt.bir_purchase_register',9,'Input VAT / Purchases Register','report','BIR Reports',2140,1,NULL),
(215,'rpt.bir_cvat_withheld',9,'Creditable VAT Withheld Schedule (2550Q Schedule 3)','report','BIR Reports',2150,1,NULL),
(216,'rpt.bir_2550q',9,'Quarterly VAT Return Worksheet (2550Q)','report','BIR Reports',2160,1,NULL),
(217,'admin.users',10,'User Accounts','admin','Setup',2170,1,NULL),
(218,'admin.roles',10,'User Role Configuration','admin','Setup',2180,1,NULL),
(219,'admin.page_access',10,'Page Access Configuration','admin','Setup',2190,1,NULL),
(220,'admin.effective_access',10,'Effective Access (View as User)','admin','Setup',2200,1,NULL),
(221,'admin.settings',10,'Company, Security & Closing Date','admin','Setup',2210,1,NULL),
(222,'admin.utilities',10,'Utilities: Verify & Rebuild Data','admin','Setup',2220,1,NULL),
(223,'admin.import',10,'Import from CSV','admin','Utilities',2230,1,NULL),
(224,'admin.backup',10,'Backup & Restore','admin','Utilities',2240,1,NULL),
(225,'admin.multi_company',10,'Multi-Company Setup','admin','Setup',2250,1,NULL),
(226,'admin.audit_trail',10,'Audit Trail','report','Audit Reports',2260,1,NULL),
(227,'admin.txn_history',10,'Transaction History','report','Audit Reports',2270,1,NULL),
(228,'rpt.voided_deleted_summary',10,'Voided and Deleted Transactions Summary','report','Audit Reports',2280,1,NULL),
(229,'rpt.voided_deleted_detail',10,'Voided and Deleted Transactions Detail','report','Audit Reports',2290,1,NULL),
(230,'rpt.user_activity',10,'User Activity','report','Audit Reports',2300,1,NULL),
(231,'rpt.login_history',10,'Login History','report','Audit Reports',2310,1,NULL),
(232,'rpt.user_access',10,'User Access and Permission Changes','report','Audit Reports',2320,1,NULL),
(233,'company.profile',11,'Company Profile & Code','admin','Company',2330,1,NULL),
(234,'company.users',11,'Employees & Users','admin','Company',2340,1,NULL),
(235,'company.join_requests',11,'Join Requests','admin','Company',2350,1,NULL),
(236,'comm.chat',12,'Community Chat','center','Community',2360,1,NULL),
(237,'comm.inquiries',12,'Questions & Inquiries','center','Community',2370,1,NULL),
(238,'comm.manage',12,'Community Management','admin','Moderation',2380,1,NULL);

-- role_page_access (631 rows)
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(1,236,1,0,0,0,0,0),
(1,237,1,0,0,0,0,0),
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
(2,70,1,0,0,0,1,0),
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
(2,101,1,0,0,0,1,0),
(2,107,1,0,0,0,1,0),
(2,111,1,0,0,0,1,0),
(2,112,1,0,0,0,1,0),
(2,113,1,0,0,0,1,0),
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
(2,126,1,0,0,0,1,0),
(2,127,1,0,0,0,1,0),
(2,130,1,0,0,0,1,0),
(2,131,1,0,0,0,1,0),
(2,132,1,0,0,0,1,0),
(2,134,1,0,0,0,1,0),
(2,136,1,0,0,0,1,0),
(2,143,1,0,0,0,1,0),
(2,144,1,0,0,0,1,0),
(2,145,1,0,0,0,1,0),
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
(2,184,1,0,0,0,1,0),
(2,185,1,0,0,0,1,0),
(2,186,1,0,0,0,1,0),
(2,187,1,0,0,0,1,0),
(2,188,1,0,0,0,1,0),
(2,189,1,0,0,0,1,0),
(2,190,1,0,0,0,1,0),
(2,191,1,0,0,0,1,0),
(2,192,1,0,0,0,1,0),
(2,193,1,0,0,0,1,0),
(2,194,1,0,0,0,1,0),
(2,195,1,0,0,0,1,0),
(2,196,1,0,0,0,1,0),
(2,197,1,1,1,1,1,0),
(2,198,1,1,1,1,1,0),
(2,199,1,1,1,1,1,0),
(2,200,1,1,1,1,1,0),
(2,201,1,1,1,1,1,0),
(2,202,1,1,1,1,1,0),
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
(2,222,1,0,0,0,1,0),
(2,236,1,1,1,1,0,0),
(2,237,1,1,1,1,0,0),
(3,1,1,0,0,0,1,0),
(3,2,1,0,0,0,1,0),
(3,3,1,0,0,0,1,0),
(3,4,1,0,0,0,1,0),
(3,5,1,0,0,0,1,0),
(3,6,1,0,0,0,1,0),
(3,7,1,0,0,0,1,0),
(3,58,1,1,1,0,1,0),
(3,59,1,1,1,0,1,0),
(3,60,1,1,1,0,1,0),
(3,61,1,1,1,0,1,0),
(3,62,1,1,1,0,1,0),
(3,63,1,1,1,0,1,0),
(3,64,1,1,1,0,1,0),
(3,65,1,1,1,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(3,66,1,1,1,0,1,0),
(3,67,1,1,1,0,1,0),
(3,68,1,1,1,0,1,0),
(3,69,1,1,1,0,1,0),
(3,70,1,0,0,0,1,0),
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
(3,123,1,0,0,0,0,0),
(3,131,1,0,0,0,1,0),
(3,151,1,0,0,0,1,0),
(3,152,1,0,0,0,1,0),
(3,236,1,1,1,1,0,0),
(3,237,1,1,1,1,0,0),
(4,1,1,0,0,0,1,0),
(4,2,1,0,0,0,1,0),
(4,3,1,0,0,0,1,0),
(4,4,1,0,0,0,1,0),
(4,5,1,0,0,0,1,0),
(4,6,1,0,0,0,1,0),
(4,7,1,0,0,0,1,0),
(4,97,1,1,1,0,1,0),
(4,98,1,1,1,0,1,0),
(4,99,1,1,1,0,1,0),
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
(4,111,1,0,0,0,1,0),
(4,112,1,0,0,0,1,0),
(4,113,1,0,0,0,1,0),
(4,114,1,0,0,0,1,0),
(4,115,1,0,0,0,1,0),
(4,116,1,0,0,0,1,0),
(4,117,1,0,0,0,1,0),
(4,118,1,0,0,0,1,0),
(4,119,1,0,0,0,1,0),
(4,120,1,0,0,0,1,0),
(4,121,1,0,0,0,1,0),
(4,123,1,0,0,0,0,0),
(4,207,1,0,0,0,1,0),
(4,208,1,0,0,0,0,0),
(4,209,1,0,0,0,1,0),
(4,210,1,0,0,0,1,0),
(4,211,1,0,0,0,1,0),
(4,212,1,0,0,0,1,0),
(4,236,1,1,1,1,0,0),
(4,237,1,1,1,1,0,0),
(5,1,1,0,0,0,1,0),
(5,2,1,0,0,0,1,0),
(5,3,1,0,0,0,1,0),
(5,4,1,0,0,0,1,0),
(5,5,1,0,0,0,1,0),
(5,6,1,0,0,0,1,0),
(5,7,1,0,0,0,1,0),
(5,103,1,0,0,0,1,0),
(5,105,1,1,1,0,1,0),
(5,108,1,0,0,0,1,0),
(5,109,1,1,1,0,1,0),
(5,110,1,0,0,0,1,0),
(5,111,1,0,0,0,1,0),
(5,122,1,0,0,0,1,0),
(5,123,1,1,1,0,1,0),
(5,124,1,1,1,1,1,0),
(5,125,1,1,1,0,1,0),
(5,126,1,1,1,0,1,0),
(5,127,1,1,1,0,1,0),
(5,128,1,1,1,0,1,0),
(5,129,1,1,1,0,1,0),
(5,130,1,1,0,0,1,0),
(5,131,1,0,0,0,1,0),
(5,132,1,1,1,0,1,0),
(5,133,1,1,1,0,1,0),
(5,134,1,1,1,0,1,0),
(5,135,1,0,0,0,1,0),
(5,136,1,1,0,0,1,0),
(5,139,1,0,0,0,1,0),
(5,140,1,1,0,0,1,0),
(5,141,1,1,0,0,1,0),
(5,142,1,1,0,0,1,0),
(5,143,1,0,0,0,1,0),
(5,144,1,0,0,0,1,0),
(5,145,1,0,0,0,1,0),
(5,146,1,0,0,0,1,0),
(5,147,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(5,148,1,0,0,0,1,0),
(5,149,1,0,0,0,1,0),
(5,150,1,0,0,0,1,0),
(5,151,1,0,0,0,1,0),
(5,152,1,0,0,0,1,0),
(5,153,1,0,0,0,1,0),
(5,154,1,0,0,0,1,0),
(5,155,1,0,0,0,1,0),
(5,162,1,0,0,0,1,0),
(5,163,1,0,0,0,1,0),
(5,164,1,0,0,0,1,0),
(5,165,1,0,0,0,1,0),
(5,166,1,0,0,0,1,0),
(5,167,1,0,0,0,1,0),
(5,168,1,0,0,0,1,0),
(5,170,1,0,0,0,1,0),
(5,171,1,0,0,0,1,0),
(5,172,1,0,0,0,1,0),
(5,174,1,0,0,0,1,0),
(5,175,1,0,0,0,1,0),
(5,176,1,0,0,0,1,0),
(5,236,1,1,1,1,0,0),
(5,237,1,1,1,1,0,0),
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
(6,81,1,0,0,0,1,0),
(6,82,1,0,0,0,1,0),
(6,83,1,0,0,0,1,0),
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
(6,139,1,0,0,0,1,0),
(6,143,1,0,0,0,1,0),
(6,144,1,0,0,0,1,0),
(6,176,1,0,0,0,1,0),
(6,236,1,1,1,1,0,0),
(6,237,1,1,1,1,0,0),
(7,1,1,0,0,0,0,0),
(7,177,1,1,0,0,1,0),
(7,179,1,1,0,0,1,0),
(7,180,1,1,0,1,1,0),
(7,195,1,0,0,0,1,0),
(7,236,1,1,1,1,0,0),
(7,237,1,1,1,1,0,0),
(8,1,1,0,0,0,0,0),
(8,2,1,0,0,0,0,0),
(8,177,1,1,1,1,1,1),
(8,179,1,1,1,1,1,1),
(8,180,1,1,1,1,1,1),
(8,181,1,1,1,1,1,1),
(8,182,1,0,0,0,1,0),
(8,184,1,0,0,0,1,0),
(8,185,1,0,0,0,1,0),
(8,186,1,0,0,0,1,0),
(8,187,1,0,0,0,1,0),
(8,188,1,0,0,0,1,0),
(8,189,1,0,0,0,1,0),
(8,190,1,0,0,0,1,0),
(8,191,1,0,0,0,1,0),
(8,192,1,0,0,0,1,0),
(8,193,1,0,0,0,1,0),
(8,194,1,0,0,0,1,0),
(8,195,1,0,0,0,1,0),
(8,196,1,0,0,0,1,0),
(8,236,1,1,1,1,0,0),
(8,237,1,1,1,1,0,0),
(9,1,1,0,0,0,0,0),
(9,2,1,0,0,0,0,0),
(9,97,1,0,0,0,1,0),
(9,105,1,0,0,0,1,0),
(9,108,1,1,1,1,1,0),
(9,109,1,1,1,0,1,0),
(9,110,1,1,1,0,1,0),
(9,111,1,0,0,0,1,0),
(9,122,1,0,0,0,1,0),
(9,139,1,0,0,0,1,0),
(9,143,1,0,0,0,1,0),
(9,144,1,0,0,0,1,0),
(9,145,1,0,0,0,1,0),
(9,146,1,0,0,0,1,0),
(9,147,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
(9,155,1,0,0,0,1,0),
(9,236,1,1,1,1,0,0),
(9,237,1,1,1,1,0,0),
(10,1,1,0,0,0,0,0),
(10,109,1,1,1,0,0,0),
(10,139,1,0,0,0,1,0),
(10,236,1,1,1,1,0,0),
(10,237,1,1,1,1,0,0),
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
(11,78,1,0,0,0,1,0),
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
(11,92,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
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
(11,178,1,0,0,0,1,0),
(11,180,1,0,0,0,1,0),
(11,181,1,0,0,0,1,0),
(11,182,1,0,0,0,1,0),
(11,183,1,0,0,0,1,0),
(11,184,1,0,0,0,1,0),
(11,185,1,0,0,0,1,0),
(11,186,1,0,0,0,1,0),
(11,187,1,0,0,0,1,0),
(11,188,1,0,0,0,1,0),
(11,189,1,0,0,0,1,0),
(11,190,1,0,0,0,1,0),
(11,191,1,0,0,0,1,0),
(11,192,1,0,0,0,1,0),
(11,193,1,0,0,0,1,0),
(11,194,1,0,0,0,1,0);
INSERT INTO `role_page_access` (`role_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`) VALUES
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
(11,226,1,0,0,0,1,0),
(11,227,1,0,0,0,1,0),
(11,228,1,0,0,0,1,0),
(11,229,1,0,0,0,1,0),
(11,230,1,0,0,0,1,0),
(11,231,1,0,0,0,1,0),
(11,232,1,0,0,0,1,0),
(11,236,1,0,0,0,1,0),
(11,237,1,0,0,0,1,0);

-- user_page_overrides (2 rows)
INSERT INTO `user_page_overrides` (`user_id`,`page_id`,`allowed`,`can_create`,`can_edit`,`can_delete`,`can_print`,`can_approve`,`reason`,`created_by`,`created_at`) VALUES
(3,66,0,0,0,0,0,0,'Finance charges are assessed by the accountant',1,'2026-11-25 21:50:05'),
(7,72,1,0,0,0,1,0,'Needs balances for account visits',1,'2026-11-25 21:50:05');

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

-- audit_trail (170 rows)
INSERT INTO `audit_trail` (`id`,`created_at`,`user_id`,`username`,`user_roles`,`ip_address`,`workstation`,`site_id`,`terminal_id`,`module`,`page_key`,`action`,`record_type`,`record_id`,`record_ref`,`amount`,`changes`,`snapshot`,`reason`,`approved_by`) VALUES
(1,'2026-11-25 21:50:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',1,'Maria Santos',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Maria Santos (Sales representative)',NULL),
(2,'2026-11-25 21:50:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',2,'Jose Reyes',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Jose Reyes (Sales representative)',NULL),
(3,'2026-11-25 21:50:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',3,'Rico Mendoza',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Rico Mendoza (Van salesman)',NULL),
(4,'2026-11-25 21:50:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',4,'Arnel Cruz',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Arnel Cruz (Van salesman)',NULL),
(5,'2026-11-25 21:50:04',NULL,NULL,NULL,'cli','CLI',NULL,NULL,'cust','coa.lists','create','customer',5,'Ella Ramos',NULL,NULL,NULL,'The employee as a customer, for the shortages charged to Ella Ramos (Cashier)',NULL),
(6,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'coa','coa.journal','create','transaction',1,'Opening Balance OB-0001','4125000.00',NULL,'{\"txn_type\":\"opening_balance\",\"txn_no\":\"OB-0001\",\"txn_date\":\"2026-09-06\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Opening balances\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"4125000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1010\",\"description\":\"BDO checking opening balance\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3200000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1020\",\"description\":\"BPI savings opening balance\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"900000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1005\",\"description\":\"Petty cash fund\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"15000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1001\",\"description\":\"Register cash funds\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"3000\",\"description\":\"Owner\'s capital\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-4125000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(7,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',2,'Check 1001','1850000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1001\",\"txn_date\":\"2026-09-01\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Purchase of Blast Freezer and Cold Room (20 tons)\",\"subtotal\":\"1850000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1850000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Coolwave Refrigeration Services\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1520\",\"description\":\"Blast Freezer and Cold Room (20 tons)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1850000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(8,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',1,'FA-00001 Blast Freezer and Cold Room (20 tons)','1850000.00',NULL,NULL,NULL,NULL),
(9,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',3,'Bill BILL-00001','2450000.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00001\",\"txn_date\":\"2026-09-01\",\"due_date\":\"2026-10-01\",\"ref_no\":\"BTR-5521\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Purchase of Reefer Truck 1 (6-wheeler, -18 C)\",\"subtotal\":\"2450000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2450000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Bicol Truck and Reefer Corp.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1530\",\"description\":\"Reefer Truck 1 (6-wheeler, -18 C)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2450000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(10,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',2,'FA-00002 Reefer Truck 1 (6-wheeler, -18 C)','2450000.00',NULL,NULL,NULL,NULL),
(11,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',4,'Check 1002','65000.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1002\",\"txn_date\":\"2026-09-01\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Purchase of POS Terminal Set (Naga Outlet)\",\"subtotal\":\"65000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"65000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Bicol Truck and Reefer Corp.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1550\",\"description\":\"POS Terminal Set (Naga Outlet)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"65000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(12,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',3,'FA-00003 POS Terminal Set (Naga Outlet)','65000.00',NULL,NULL,NULL,NULL),
(13,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',5,'Bill BILL-00002','85000.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00002\",\"txn_date\":\"2026-09-01\",\"due_date\":\"2026-10-01\",\"ref_no\":\"CRS-5530\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Purchase of Platform Scale 300 kg (receiving)\",\"subtotal\":\"85000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"85000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Coolwave Refrigeration Services\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"1520\",\"description\":\"Platform Scale 300 kg (receiving)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"85000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(14,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.register','create','asset',4,'FA-00004 Platform Scale 300 kg (receiving)','85000.00',NULL,NULL,NULL,NULL),
(15,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',6,'Bill BILL-00003','17000.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00003\",\"txn_date\":\"2026-11-05\",\"due_date\":\"2026-11-20\",\"ref_no\":\"CRS-SV-0192\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":null,\"memo\":\"Repair of FA-00002 Reefer Truck 1 (6-wheeler, -18 C) (MNT-00001)\",\"subtotal\":\"17000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"17000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Coolwave Refrigeration Services\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6030\",\"description\":\"Parts - MNT-00001 FA-00002 Reefer Truck 1 (6-wheeler, -18 C)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"14500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6030\",\"description\":\"Labor - MNT-00001 FA-00002 Reefer Truck 1 (6-wheeler, -18 C)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Maintenance record MNT-00001',NULL),
(16,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','create','transaction',7,'Bill BILL-00004','59545.22',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00004\",\"txn_date\":\"2026-09-12\",\"due_date\":\"2026-09-27\",\"ref_no\":\"NPC-INV-10231\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":null,\"memo\":\"Opening stock, received in crates\",\"subtotal\":\"53165.38\",\"tax_total\":\"6379.84\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"59545.22\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"148.7400\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"21121.08\",\"tax_amount\":\"2534.53\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"89.8100\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"16614.85\",\"tax_amount\":\"1993.78\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"29.6500\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2816.75\",\"tax_amount\":\"338.01\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"86.0200\",\"rate\":\"135.0000\",\"discount_amount\":\"0.00\",\"amount\":\"11612.70\",\"tax_amount\":\"1393.52\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"40.0000\",\"rate\":\"25.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1000.00\",\"tax_amount\":\"120.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(17,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',8,'Item Receipt IR-00001','66305.63',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00001\",\"txn_date\":\"2026-09-14\",\"due_date\":null,\"ref_no\":\"DR-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"59201.45\",\"tax_total\":\"7104.18\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"66305.63\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Golden Plume Farms Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"122.8100\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"21491.75\",\"tax_amount\":\"2579.01\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"72.4200\",\"rate\":\"190.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13759.80\",\"tax_amount\":\"1651.18\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"30.0900\",\"rate\":\"110.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3309.90\",\"tax_amount\":\"397.19\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"240.0000\",\"rate\":\"48.0000\",\"discount_amount\":\"0.00\",\"amount\":\"11520.00\",\"tax_amount\":\"1382.40\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"96.0000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"9120.00\",\"tax_amount\":\"1094.40\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(18,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','convert','transaction',8,'Bill BILL-00005','66143.41','[{\"field\":\"txn_type\",\"old\":\"item_receipt\",\"new\":\"bill\"},{\"field\":\"txn_no\",\"old\":\"IR-00001\",\"new\":\"BILL-00005\"},{\"field\":\"txn_date\",\"old\":\"2026-09-14\",\"new\":\"2026-09-20\"},{\"field\":\"due_date\",\"old\":null,\"new\":\"2026-10-20\"},{\"field\":\"ref_no\",\"old\":\"DR-7781\",\"new\":\"GPF-INV-10288\"},{\"field\":\"terms_id\",\"old\":null,\"new\":3},{\"field\":\"memo\",\"old\":null,\"new\":\"Bill for received items\"},{\"field\":\"subtotal\",\"old\":\"59201.45\",\"new\":\"59056.61\"},{\"field\":\"tax_total\",\"old\":\"7104.18\",\"new\":\"7086.80\"},{\"field\":\"total\",\"old\":\"66305.63\",\"new\":\"66143.41\"},{\"field\":\"lines[2].rate\",\"old\":\"190.0000\",\"new\":\"188.0000\"},{\"field\":\"lines[2].amount\",\"old\":\"13759.80\",\"new\":\"13614.96\"},{\"field\":\"lines[2].tax_amount\",\"old\":\"1651.18\",\"new\":\"1633.80\"}]','{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00005\",\"txn_date\":\"2026-09-20\",\"due_date\":\"2026-10-20\",\"ref_no\":\"GPF-INV-10288\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Bill for received items\",\"subtotal\":\"59056.61\",\"tax_total\":\"7086.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"66143.41\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Golden Plume Farms Inc.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"122.8100\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"21491.75\",\"tax_amount\":\"2579.01\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"72.4200\",\"rate\":\"188.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13614.96\",\"tax_amount\":\"1633.80\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"30.0900\",\"rate\":\"110.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3309.90\",\"tax_amount\":\"397.19\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"240.0000\",\"rate\":\"48.0000\",\"discount_amount\":\"0.00\",\"amount\":\"11520.00\",\"tax_amount\":\"1382.40\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"96.0000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"9120.00\",\"tax_amount\":\"1094.40\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(19,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.bills','create','transaction',9,'Bill BILL-00006','7392.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00006\",\"txn_date\":\"2026-09-16\",\"due_date\":\"2026-10-01\",\"ref_no\":\"BPS-99812\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":null,\"memo\":\"Vacuum bags\",\"subtotal\":\"6600.00\",\"tax_total\":\"792.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7392.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Bicol Packaging Supply\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"PKG-BAG\",\"account\":null,\"description\":\"Vacuum Bag 2 kg\",\"qty\":\"2000.0000\",\"rate\":\"3.3000\",\"discount_amount\":\"0.00\",\"amount\":\"6600.00\",\"tax_amount\":\"792.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(20,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',1,'AL-00001',NULL,NULL,NULL,NULL,NULL),
(21,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',10,'Item Receipt IR-00002','39395.62',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00002\",\"txn_date\":\"2026-09-26\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00001\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00001)\",\"subtotal\":\"39395.62\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"39395.62\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"125.8600\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"17872.12\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"87.2400\",\"rate\":\"150.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13086.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"57.0000\",\"rate\":\"135.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7695.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"29.7000\",\"rate\":\"25.0000\",\"discount_amount\":\"0.00\",\"amount\":\"742.50\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00001 completed',NULL),
(22,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.pickup','pickup_complete','allocation',1,'AL-00001',NULL,NULL,NULL,'Received on Item Receipt IR-00002',NULL),
(23,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',2,'AL-00002',NULL,NULL,NULL,NULL,NULL),
(24,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',11,'Item Receipt IR-00003','32776.00',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00003\",\"txn_date\":\"2026-10-04\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00002\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00002)\",\"subtotal\":\"32776.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"32776.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Golden Plume Farms Inc.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"94.0000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"16450.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"45.0000\",\"rate\":\"190.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8550.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"162.0000\",\"rate\":\"48.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7776.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00002 completed',NULL),
(25,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.pickup','pickup_complete','allocation',2,'AL-00002',NULL,NULL,NULL,'Received on Item Receipt IR-00003',NULL),
(26,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',3,'AL-00003',NULL,NULL,NULL,NULL,NULL),
(27,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',12,'Item Receipt IR-00004','37957.44',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00004\",\"txn_date\":\"2026-10-11\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00003\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00003)\",\"subtotal\":\"37957.44\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"37957.44\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"148.8200\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"21132.44\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"74.0000\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13690.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"33.0000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3135.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00003 completed',NULL),
(28,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.pickup','pickup_complete','allocation',3,'AL-00003',NULL,NULL,NULL,'Received on Item Receipt IR-00004',NULL),
(29,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',4,'AL-00004',NULL,NULL,NULL,NULL,NULL),
(30,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',13,'Item Receipt IR-00005','39660.04',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00005\",\"txn_date\":\"2026-10-26\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00004\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00004)\",\"subtotal\":\"39660.04\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"39660.04\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"123.1200\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"17483.04\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"91.4800\",\"rate\":\"150.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13722.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"58.0000\",\"rate\":\"135.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7830.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"25.0000\",\"rate\":\"25.0000\",\"discount_amount\":\"0.00\",\"amount\":\"625.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00004 completed',NULL),
(31,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.pickup','pickup_complete','allocation',4,'AL-00004',NULL,NULL,NULL,'Received on Item Receipt IR-00005',NULL),
(32,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',3,NULL,'vend','vend.allocations','create','allocation',5,'AL-00005',NULL,NULL,NULL,NULL,NULL),
(33,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',3,NULL,'vend','vend.receive_items','create','transaction',14,'Item Receipt IR-00006','32971.80',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00006\",\"txn_date\":\"2026-11-04\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00005\",\"payee_name\":null,\"site_id\":3,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00005)\",\"subtotal\":\"32971.80\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"32971.80\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Golden Plume Farms Inc.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"96.3700\",\"rate\":\"140.0000\",\"discount_amount\":\"0.00\",\"amount\":\"13491.80\",\"tax_amount\":\"0.00\",\"site_id\":3,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"61.0000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10675.00\",\"tax_amount\":\"0.00\",\"site_id\":3,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"17.0000\",\"rate\":\"110.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1870.00\",\"tax_amount\":\"0.00\",\"site_id\":3,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"73.0000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6935.00\",\"tax_amount\":\"0.00\",\"site_id\":3,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00005 completed',NULL),
(34,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',3,NULL,'vend','vend.pickup','pickup_complete','allocation',5,'AL-00005',NULL,NULL,NULL,'Received on Item Receipt IR-00006',NULL),
(35,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',6,'AL-00006',NULL,NULL,NULL,NULL,NULL),
(36,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',15,'Item Receipt IR-00007','37817.08',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00007\",\"txn_date\":\"2026-11-16\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00006\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00006)\",\"subtotal\":\"37817.08\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"37817.08\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"124.2400\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"17642.08\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"66.0000\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"12210.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"59.0000\",\"rate\":\"135.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7965.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00006 completed',NULL),
(37,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.pickup','pickup_complete','allocation',6,'AL-00006',NULL,NULL,NULL,'Received on Item Receipt IR-00007',NULL),
(38,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',7,'AL-00007',NULL,NULL,NULL,NULL,NULL),
(39,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.receive_items','create','transaction',16,'Item Receipt IR-00008','28074.58',NULL,'{\"txn_type\":\"item_receipt\",\"txn_no\":\"IR-00008\",\"txn_date\":\"2026-11-23\",\"due_date\":null,\"ref_no\":\"Pick-up AL-00007\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Picked up by Glenn Abad (AL-00007)\",\"subtotal\":\"28074.58\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"28074.58\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"100.9900\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"14340.58\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"72.9600\",\"rate\":\"150.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10944.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"24.0000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2280.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"20.4000\",\"rate\":\"25.0000\",\"discount_amount\":\"0.00\",\"amount\":\"510.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pick-up AL-00007 completed',NULL),
(40,'2026-11-25 21:50:04',10,'glenn','Pick-Up Crew','cli','CLI',1,NULL,'vend','vend.pickup','pickup_complete','allocation',7,'AL-00007',NULL,NULL,NULL,'Received on Item Receipt IR-00008',NULL),
(41,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',8,'AL-00008',NULL,NULL,NULL,NULL,NULL),
(42,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',3,NULL,'vend','vend.allocations','create','allocation',9,'AL-00009',NULL,NULL,NULL,NULL,NULL),
(43,'2026-11-25 21:50:04',6,'allocator','Allocation Officer','cli','CLI',1,NULL,'vend','vend.allocations','create','allocation',10,'AL-00010',NULL,NULL,NULL,NULL,NULL),
(44,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',17,'Inventory Transfer IT-00001','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00001\",\"txn_date\":\"2026-09-22\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Stock for the Naga Outlet\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"36.8900\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"30.3700\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"12.2500\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"10.2200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"80.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"24.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(45,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',18,'Inventory Transfer IT-00002','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00002\",\"txn_date\":\"2026-09-23\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":3,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Stock for the Legazpi Depot\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"24.4400\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"30.2100\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"30.8900\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"40.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(46,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',19,'Inventory Transfer IT-00003','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00003\",\"txn_date\":\"2026-10-27\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Weekend stock for the outlet\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"37.9900\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"29.0700\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"14.2600\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(47,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',20,'Inventory Transfer IT-00004','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00004\",\"txn_date\":\"2026-11-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Stock for the outlet\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"49.4200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"14.9000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"14.3000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(48,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',21,'Inventory Transfer IT-00005','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00005\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Stock for the outlet\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"37.8800\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"29.1100\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"9.7200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(49,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',22,'Inventory Transfer IT-00006','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00006\",\"txn_date\":\"2026-10-26\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Blood and vacuum bags for the outlet\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken blood\",\"qty\":\"12.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"PKG-BAG\",\"account\":null,\"description\":\"Vacuum bags\",\"qty\":\"200.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(50,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',2,NULL,'inv','inv.crate_convert','crate_convert','crate',22,'Crate 22 (ACU-FZ)','14.26',NULL,NULL,'Repacked into 1 kg retail bags',NULL),
(51,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.crate_convert','crate_convert','crate',24,'Crate 24 (ACU-FZ)','13.93',NULL,NULL,'Repacked into 1 kg retail bags',NULL),
(52,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',23,'Processing Order PRC-00001','4613.34',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00001\",\"txn_date\":\"2026-09-30\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cut-ups for the restaurant orders\",\"subtotal\":\"4253.34\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"4613.34\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"disassembly\",\"alloc_method\":\"sales_value\",\"process_formula_id\":1,\"process_batches\":\"3.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"30.0000\",\"rate\":\"141.7780\",\"discount_amount\":\"0.00\",\"amount\":\"4253.34\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"cost\",\"item\":null,\"account\":\"5200\",\"description\":\"Cutting and packing labor\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"360.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"7.8000\",\"rate\":\"181.5436\",\"discount_amount\":\"0.00\",\"amount\":\"1416.04\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"6.6000\",\"rate\":\"171.1939\",\"discount_amount\":\"0.00\",\"amount\":\"1129.88\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"3.3000\",\"rate\":\"187.1182\",\"discount_amount\":\"0.00\",\"amount\":\"617.49\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"9.0000\",\"rate\":\"133.7700\",\"discount_amount\":\"0.00\",\"amount\":\"1203.93\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"1.2000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"114.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"95.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"1.2000\",\"rate\":\"110.0000\",\"discount_amount\":\"0.00\",\"amount\":\"132.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"110.0000\",\"class\":null}]}',NULL,NULL),
(53,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'inv',NULL,'recost','transaction',NULL,'Costs from 09/30/2026',NULL,NULL,NULL,'11 inventory transaction(s) dated from 09/30/2026 costed again in date order after a back-dated, edited, voided or deleted transaction',NULL),
(54,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',24,'Processing Order PRC-00002','3075.40',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00002\",\"txn_date\":\"2026-10-30\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cut-ups; a little more breast than planned\",\"subtotal\":\"2835.40\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3075.40\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"disassembly\",\"alloc_method\":\"sales_value\",\"process_formula_id\":1,\"process_batches\":\"2.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"20.0000\",\"rate\":\"141.7700\",\"discount_amount\":\"0.00\",\"amount\":\"2835.40\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"cost\",\"item\":null,\"account\":\"5200\",\"description\":\"Cutting and packing labor\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"240.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"5.4000\",\"rate\":\"180.9407\",\"discount_amount\":\"0.00\",\"amount\":\"977.08\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"4.4000\",\"rate\":\"170.6250\",\"discount_amount\":\"0.00\",\"amount\":\"750.75\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"2.2000\",\"rate\":\"186.4955\",\"discount_amount\":\"0.00\",\"amount\":\"410.29\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"5.8000\",\"rate\":\"133.3241\",\"discount_amount\":\"0.00\",\"amount\":\"773.28\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"0.8000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"76.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"95.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"0.8000\",\"rate\":\"110.0000\",\"discount_amount\":\"0.00\",\"amount\":\"88.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"110.0000\",\"class\":null}]}',NULL,NULL),
(55,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'inv',NULL,'recost','transaction',NULL,'Costs from 10/30/2026',NULL,NULL,NULL,'6 inventory transaction(s) dated from 10/30/2026 costed again in date order after a back-dated, edited, voided or deleted transaction',NULL),
(56,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.process','create','transaction',25,'Processing Order PRC-00003','3075.29',NULL,'{\"txn_type\":\"item_processing\",\"txn_no\":\"PRC-00003\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Waiting for the cutting crew\",\"subtotal\":\"2835.29\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3075.29\",\"status\":\"pending\",\"is_pending\":1,\"is_voided\":0,\"receipt_no\":null,\"process_type\":\"disassembly\",\"alloc_method\":\"sales_value\",\"process_formula_id\":1,\"process_batches\":\"2.0000\",\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"input\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"20.0000\",\"rate\":\"141.7644\",\"discount_amount\":\"0.00\",\"amount\":\"2835.29\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"cost\",\"item\":null,\"account\":\"5200\",\"description\":\"Cutting and packing labor\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"240.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"5.2000\",\"rate\":\"181.5288\",\"discount_amount\":\"0.00\",\"amount\":\"943.95\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"4.4000\",\"rate\":\"171.1773\",\"discount_amount\":\"0.00\",\"amount\":\"753.18\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"2.2000\",\"rate\":\"187.1000\",\"discount_amount\":\"0.00\",\"amount\":\"411.62\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"6.0000\",\"rate\":\"133.7567\",\"discount_amount\":\"0.00\",\"amount\":\"802.54\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"co_product\",\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"0.8000\",\"rate\":\"95.0000\",\"discount_amount\":\"0.00\",\"amount\":\"76.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"95.0000\",\"class\":null},{\"line_kind\":\"output\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"0.8000\",\"rate\":\"110.0000\",\"discount_amount\":\"0.00\",\"amount\":\"88.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":\"by_product\",\"alloc_basis\":\"110.0000\",\"class\":null}]}',NULL,NULL),
(57,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.build','create','transaction',26,'Build Assembly BLD-00001','0.00',NULL,'{\"txn_type\":\"build_assembly\",\"txn_no\":\"BLD-00001\",\"txn_date\":\"2026-10-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Party packs for the weekend\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"PARTY-PK\",\"account\":null,\"description\":\"Party Pack\",\"qty\":\"8.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Component\",\"qty\":\"8.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Component\",\"qty\":\"16.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"PKG-BAG\",\"account\":null,\"description\":\"Component\",\"qty\":\"16.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"LAB-CUT\",\"account\":null,\"description\":\"Component\",\"qty\":\"2.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(58,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',27,'Inventory Transfer IT-00007','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00007\",\"txn_date\":\"2026-10-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":2,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Party packs for the outlet\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"PARTY-PK\",\"account\":null,\"description\":\"Party Pack\",\"qty\":\"3.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(59,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.build','create','transaction',28,'Build Assembly BLD-00002','0.00',NULL,'{\"txn_type\":\"build_assembly\",\"txn_no\":\"BLD-00002\",\"txn_date\":\"2026-11-22\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Waiting for wings\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"pending\",\"is_pending\":1,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"PARTY-PK\",\"account\":null,\"description\":\"Party Pack\",\"qty\":\"20.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Component\",\"qty\":\"20.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Component\",\"qty\":\"40.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"PKG-BAG\",\"account\":null,\"description\":\"Component\",\"qty\":\"40.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"component\",\"item\":\"LAB-CUT\",\"account\":null,\"description\":\"Component\",\"qty\":\"5.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(60,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.estimates','create','transaction',29,'Estimate EST-00001','33796.00',NULL,'{\"txn_type\":\"estimate\",\"txn_no\":\"EST-00001\",\"txn_date\":\"2026-09-28\",\"due_date\":\"2026-10-28\",\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":1,\"memo\":\"Weekly supply for both branches\",\"subtotal\":\"30175.00\",\"tax_total\":\"3621.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"33796.00\",\"status\":\"accepted\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"120.0000\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"19800.00\",\"tax_amount\":\"2376.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"45.0000\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"9675.00\",\"tax_amount\":\"1161.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"2.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"700.00\",\"tax_amount\":\"84.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(61,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.sales_orders','create','transaction',30,'Sales Order SO-00001','33796.00',NULL,'{\"txn_type\":\"sales_order\",\"txn_no\":\"SO-00001\",\"txn_date\":\"2026-09-29\",\"due_date\":null,\"ref_no\":\"SUN-PO-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"30175.00\",\"tax_total\":\"3621.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"33796.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"120.0000\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"19800.00\",\"tax_amount\":\"2376.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"45.0000\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"9675.00\",\"tax_amount\":\"1161.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"2.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"700.00\",\"tax_amount\":\"84.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(62,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',31,'Invoice INV-00001','16905.79',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00001\",\"txn_date\":\"2026-10-01\",\"due_date\":\"2026-10-31\",\"ref_no\":\"SUN-PO-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"15094.45\",\"tax_total\":\"1811.34\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"16905.79\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"50.9600\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8408.40\",\"tax_amount\":\"1009.01\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"29.4700\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6336.05\",\"tax_amount\":\"760.33\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(63,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',32,'Invoice INV-00002','9546.99',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00002\",\"txn_date\":\"2026-10-08\",\"due_date\":\"2026-11-07\",\"ref_no\":\"SUN-PO-7781\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"8524.10\",\"tax_total\":\"1022.89\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"9546.99\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"49.5400\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8174.10\",\"tax_amount\":\"980.89\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(64,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',33,'Invoice INV-00003','14708.62',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00003\",\"txn_date\":\"2026-10-12\",\"due_date\":\"2026-11-11\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"13132.70\",\"tax_total\":\"1575.92\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"14708.62\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart Pili Branch\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"37.0900\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6119.85\",\"tax_amount\":\"734.38\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"30.9900\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6662.85\",\"tax_amount\":\"799.54\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(65,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',34,'Invoice INV-00004','6904.00',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00004\",\"txn_date\":\"2026-10-06\",\"due_date\":\"2026-10-21\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"6190.00\",\"tax_total\":\"714.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"6904.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Kusina ni Lola Restaurant\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"18.0000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3150.00\",\"tax_amount\":\"378.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"10.0000\",\"rate\":\"228.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2280.00\",\"tax_amount\":\"273.60\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"4.0000\",\"rate\":\"130.0000\",\"discount_amount\":\"0.00\",\"amount\":\"520.00\",\"tax_amount\":\"62.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"6.0000\",\"rate\":\"40.0000\",\"discount_amount\":\"0.00\",\"amount\":\"240.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(66,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',35,'Invoice INV-00005','5196.80',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00005\",\"txn_date\":\"2026-10-20\",\"due_date\":\"2026-11-04\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"4640.00\",\"tax_total\":\"556.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5196.80\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Kusina ni Lola Restaurant\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"12.0000\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2580.00\",\"tax_amount\":\"309.60\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WNG-FZ\",\"account\":null,\"description\":\"Chicken Wings, Frozen, Bag\",\"qty\":\"8.0000\",\"rate\":\"235.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1880.00\",\"tax_amount\":\"225.60\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SRV-CUT\",\"account\":null,\"description\":\"Custom Cutting Service\",\"qty\":\"12.0000\",\"rate\":\"15.0000\",\"discount_amount\":\"0.00\",\"amount\":\"180.00\",\"tax_amount\":\"21.60\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(67,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',3,NULL,'cust','cust.invoices','create','transaction',36,'Invoice INV-00006','8083.77',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00006\",\"txn_date\":\"2026-10-14\",\"due_date\":\"2026-11-13\",\"ref_no\":null,\"payee_name\":null,\"site_id\":3,\"site2_id\":null,\"terms_id\":4,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"7217.65\",\"tax_total\":\"866.12\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"8083.77\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Legazpi Grill House\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Legazpi Depot\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"11.9500\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2091.25\",\"tax_amount\":\"250.95\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"15.3600\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3302.40\",\"tax_amount\":\"396.29\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"8.0000\",\"rate\":\"228.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1824.00\",\"tax_amount\":\"218.88\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(68,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',3,NULL,'cust','cust.invoices','create','transaction',37,'Invoice INV-00007','12321.68',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00007\",\"txn_date\":\"2026-11-07\",\"due_date\":\"2026-12-07\",\"ref_no\":null,\"payee_name\":null,\"site_id\":3,\"site2_id\":null,\"terms_id\":4,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"11001.50\",\"tax_total\":\"1320.18\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"12321.68\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Legazpi Grill House\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Legazpi Depot\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"48.5800\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8501.50\",\"tax_amount\":\"1020.18\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"10.0000\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2150.00\",\"tax_amount\":\"258.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(69,'2026-11-25 21:50:04',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',38,'Invoice INV-00008','7929.60',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00008\",\"txn_date\":\"2026-10-16\",\"due_date\":\"2026-10-31\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"7080.00\",\"tax_total\":\"849.60\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7929.60\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"St. Raphael Hospital Kitchen\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"20.0000\",\"rate\":\"228.0000\",\"discount_amount\":\"0.00\",\"amount\":\"4560.00\",\"tax_amount\":\"547.20\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"15.0000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2520.00\",\"tax_amount\":\"302.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(70,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',39,'Invoice INV-00009','6088.32',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00009\",\"txn_date\":\"2026-10-23\",\"due_date\":\"2026-11-07\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Weekly hospital kitchen delivery\",\"subtotal\":\"5436.00\",\"tax_total\":\"652.32\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"6088.32\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"St. Raphael Hospital Kitchen\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"15.0000\",\"rate\":\"228.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3420.00\",\"tax_amount\":\"410.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"12.0000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2016.00\",\"tax_amount\":\"241.92\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(71,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',40,'Invoice INV-00010','3593.86',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00010\",\"txn_date\":\"2026-10-23\",\"due_date\":\"2026-11-07\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Weekly market stall delivery\",\"subtotal\":\"3208.80\",\"tax_total\":\"385.06\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3593.86\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"19.1000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3208.80\",\"tax_amount\":\"385.06\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(72,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',41,'Invoice INV-00011','6088.32',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00011\",\"txn_date\":\"2026-11-13\",\"due_date\":\"2026-11-28\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Weekly hospital kitchen delivery\",\"subtotal\":\"5436.00\",\"tax_total\":\"652.32\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"6088.32\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"St. Raphael Hospital Kitchen\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"15.0000\",\"rate\":\"228.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3420.00\",\"tax_amount\":\"410.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"12.0000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2016.00\",\"tax_amount\":\"241.92\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(73,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',42,'Invoice INV-00012','4581.70',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00012\",\"txn_date\":\"2026-11-13\",\"due_date\":\"2026-11-28\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":1,\"memo\":\"Weekly market stall delivery\",\"subtotal\":\"4090.80\",\"tax_total\":\"490.90\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"4581.70\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"24.3500\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"4090.80\",\"tax_amount\":\"490.90\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(74,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',43,'Invoice INV-00013','26106.70',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00013\",\"txn_date\":\"2026-10-31\",\"due_date\":\"2026-11-30\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"23309.55\",\"tax_total\":\"2797.15\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"26106.70\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"73.7000\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"12160.50\",\"tax_amount\":\"1459.26\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"44.4900\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"8230.65\",\"tax_amount\":\"987.68\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"24.0000\",\"rate\":\"128.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3072.00\",\"tax_amount\":\"368.64\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"SUBTOTAL\",\"account\":null,\"description\":\"Subtotal\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DISC-5\",\"account\":null,\"description\":\"5% Volume Discount\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-153.60\",\"tax_amount\":\"-18.43\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(75,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',44,'Invoice INV-00014','12006.62',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00014\",\"txn_date\":\"2026-11-19\",\"due_date\":\"2026-12-19\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":1,\"memo\":null,\"subtotal\":\"10720.20\",\"tax_total\":\"1286.42\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"12006.62\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"62.5500\",\"rate\":\"165.0000\",\"discount_amount\":\"0.00\",\"amount\":\"10320.75\",\"tax_amount\":\"1238.49\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"0.2300\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"49.45\",\"tax_amount\":\"5.93\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DEL-FEE\",\"account\":null,\"description\":\"Delivery Fee (reefer)\",\"qty\":\"1.0000\",\"rate\":\"350.0000\",\"discount_amount\":\"0.00\",\"amount\":\"350.00\",\"tax_amount\":\"42.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(76,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',45,'Invoice INV-00015','5387.20',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00015\",\"txn_date\":\"2026-11-21\",\"due_date\":\"2026-12-06\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":2,\"sales_rep_id\":2,\"memo\":null,\"subtotal\":\"4810.00\",\"tax_total\":\"577.20\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5387.20\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Kusina ni Lola Restaurant\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"25.0000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"4375.00\",\"tax_amount\":\"525.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"GIZ-FZ\",\"account\":null,\"description\":\"Chicken Gizzard, Frozen, Bag\",\"qty\":\"3.0000\",\"rate\":\"145.0000\",\"discount_amount\":\"0.00\",\"amount\":\"435.00\",\"tax_amount\":\"52.20\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(77,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',3,NULL,'cust','cust.invoices','create','transaction',46,'Invoice INV-00016','2855.92',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00016\",\"txn_date\":\"2026-11-23\",\"due_date\":\"2026-12-23\",\"ref_no\":null,\"payee_name\":null,\"site_id\":3,\"site2_id\":null,\"terms_id\":4,\"sales_rep_id\":2,\"memo\":\"Awaiting PO approval\",\"subtotal\":\"2603.50\",\"tax_total\":\"252.42\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2855.92\",\"status\":\"pending\",\"is_pending\":1,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Legazpi Grill House\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Legazpi Depot\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"12.0200\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2103.50\",\"tax_amount\":\"252.42\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"CRATE-DEP\",\"account\":null,\"description\":\"Crate Deposit\",\"qty\":\"2.0000\",\"rate\":\"250.0000\",\"discount_amount\":\"0.00\",\"amount\":\"500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(78,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.sales_receipts','create','transaction',47,'Sales Receipt SR-00001','1659.20',NULL,'{\"txn_type\":\"sales_receipt\",\"txn_no\":\"SR-00001\",\"txn_date\":\"2026-10-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Phone order\",\"subtotal\":\"1490.00\",\"tax_total\":\"169.20\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1659.20\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Juan Dela Cruz\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"2.5000\",\"rate\":\"130.0000\",\"discount_amount\":\"0.00\",\"amount\":\"325.00\",\"tax_amount\":\"39.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"6.2000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1085.00\",\"tax_amount\":\"130.20\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"2.0000\",\"rate\":\"40.0000\",\"discount_amount\":\"0.00\",\"amount\":\"80.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(79,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',48,'Customer Payment PMT-00001','60000.00',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00001\",\"txn_date\":\"2026-10-28\",\"due_date\":null,\"ref_no\":\"BDO-004412\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"60000.00\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Sunrise Supermart\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00001\",\"amount\":\"60000.00\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(80,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',49,'Customer Payment PMT-00002','7922.09',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00002\",\"txn_date\":\"2026-10-22\",\"due_date\":null,\"ref_no\":\"IB-88123\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"161.68\",\"withholding_amount\":\"0.00\",\"total\":\"7922.09\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Legazpi Grill House\",\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00006\",\"amount\":\"7922.09\",\"discount\":\"161.68\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(81,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',50,'Customer Payment PMT-00003','7404.00',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00003\",\"txn_date\":\"2026-10-19\",\"due_date\":null,\"ref_no\":\"MBTC-1120\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7404.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Kusina ni Lola Restaurant\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00004\",\"amount\":\"6904.00\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(82,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',51,'Customer Payment PMT-00004','3964.80',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00004\",\"txn_date\":\"2026-10-30\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3964.80\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"St. Raphael Hospital Kitchen\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00008\",\"amount\":\"3964.80\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(83,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.invoices','create','transaction',52,'Invoice INV-00017','5423.32',NULL,'{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00017\",\"txn_date\":\"2026-10-22\",\"due_date\":\"2026-11-21\",\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Feeding program, barangay day care centers\",\"subtotal\":\"4842.25\",\"tax_total\":\"581.07\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"5423.32\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Municipality of San Isidro\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":\"Head Office\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"18.0700\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3162.25\",\"tax_amount\":\"379.47\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"10.0000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1680.00\",\"tax_amount\":\"201.60\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(84,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',53,'Customer Payment PMT-00005','5132.79',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00005\",\"txn_date\":\"2026-11-13\",\"due_date\":null,\"ref_no\":\"LBP-205511\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"5% VAT and 1% withheld; BIR Form 2307 to follow\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"290.53\",\"total\":\"5132.79\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Municipality of San Isidro\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"invoice\",\"txn_no\":\"INV-00017\",\"amount\":\"5132.79\",\"discount\":\"0.00\",\"withholding\":\"290.53\"}]}',NULL,NULL),
(85,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'cust','cust.credit_memos','create','transaction',54,'Credit Memo CM-00001','436.80',NULL,'{\"txn_type\":\"credit_memo\",\"txn_no\":\"CM-00001\",\"txn_date\":\"2026-10-09\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Returned 3 kg liver, not frozen on arrival\",\"subtotal\":\"390.00\",\"tax_total\":\"46.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"436.80\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Kusina ni Lola Restaurant\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"3.0000\",\"rate\":\"130.0000\",\"discount_amount\":\"0.00\",\"amount\":\"390.00\",\"tax_amount\":\"46.80\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(86,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.statement_charges','create','transaction',55,'Statement Charge SC-00001','200.00',NULL,'{\"txn_type\":\"statement_charge\",\"txn_no\":\"SC-00001\",\"txn_date\":\"2026-11-10\",\"due_date\":\"2026-11-10\",\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Late payment fee\",\"subtotal\":\"200.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"200.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LATE-FEE\",\"account\":null,\"description\":\"Late Payment Fee\",\"qty\":\"1.0000\",\"rate\":\"200.0000\",\"discount_amount\":\"0.00\",\"amount\":\"200.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(87,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.finance_charges','create','transaction',56,'Finance Charge FC-00001','86.40',NULL,'{\"txn_type\":\"finance_charge\",\"txn_no\":\"FC-00001\",\"txn_date\":\"2026-11-24\",\"due_date\":\"2026-11-24\",\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Finance charge on overdue balance\",\"subtotal\":\"86.40\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"86.40\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":\"Accounts Receivable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":null,\"account\":\"4100\",\"description\":\"Finance charge (12% p.a.)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"86.40\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(88,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',57,'Check 1003','106400.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1003\",\"txn_date\":\"2026-09-12\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cold storage and outlet rent\",\"subtotal\":\"95000.00\",\"tax_total\":\"11400.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"106400.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Metro Property Leasing\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6010\",\"description\":\"Monthly rent\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"95000.00\",\"tax_amount\":\"11400.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(89,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',58,'Check 1004','106400.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1004\",\"txn_date\":\"2026-10-12\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cold storage and outlet rent\",\"subtotal\":\"95000.00\",\"tax_total\":\"11400.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"106400.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Metro Property Leasing\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6010\",\"description\":\"Monthly rent\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"95000.00\",\"tax_amount\":\"11400.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(90,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',59,'Check 1005','106400.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1005\",\"txn_date\":\"2026-11-11\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cold storage and outlet rent\",\"subtotal\":\"95000.00\",\"tax_total\":\"11400.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"106400.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Metro Property Leasing\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6010\",\"description\":\"Monthly rent\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"95000.00\",\"tax_amount\":\"11400.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(91,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',60,'Bill BILL-00007','96824.84',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00007\",\"txn_date\":\"2026-09-26\",\"due_date\":\"2026-10-06\",\"ref_no\":\"CPC-202609\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":1,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"86450.75\",\"tax_total\":\"10374.09\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"96824.84\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Camarines Power Cooperative\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6020\",\"description\":\"Electricity, cold storage\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"86450.75\",\"tax_amount\":\"10374.09\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(92,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',61,'Bill BILL-00008','103298.05',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00008\",\"txn_date\":\"2026-10-26\",\"due_date\":\"2026-11-05\",\"ref_no\":\"CPC-202610\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":1,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"92230.40\",\"tax_total\":\"11067.65\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"103298.05\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Camarines Power Cooperative\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6020\",\"description\":\"Electricity, cold storage\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"92230.40\",\"tax_amount\":\"11067.65\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(93,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.bills','create','transaction',62,'Bill BILL-00009','50400.00',NULL,'{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00009\",\"txn_date\":\"2026-10-01\",\"due_date\":\"2026-10-31\",\"ref_no\":\"APC-2231\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":3,\"sales_rep_id\":null,\"memo\":\"Quarterly bookkeeping review\",\"subtotal\":\"45000.00\",\"tax_total\":\"5400.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"50400.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Accounting Partners & Co.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6070\",\"description\":\"Professional fees\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"45000.00\",\"tax_amount\":\"5400.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(94,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',63,'Check 1006','7616.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1006\",\"txn_date\":\"2026-09-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Diesel for the reefer truck\",\"subtotal\":\"6800.00\",\"tax_total\":\"816.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7616.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Diversion Road Fuel Station\",\"account\":\"Petty Cash Fund\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6050\",\"description\":\"Diesel\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6800.00\",\"tax_amount\":\"816.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(95,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',64,'Check 1007','7616.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1007\",\"txn_date\":\"2026-10-23\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Diesel for the reefer truck\",\"subtotal\":\"6800.00\",\"tax_total\":\"816.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7616.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Diversion Road Fuel Station\",\"account\":\"Petty Cash Fund\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6050\",\"description\":\"Diesel\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6800.00\",\"tax_amount\":\"816.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(96,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',65,'Check 1008','7616.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1008\",\"txn_date\":\"2026-11-20\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Diesel for the reefer truck\",\"subtotal\":\"6800.00\",\"tax_total\":\"816.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7616.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Diversion Road Fuel Station\",\"account\":\"Petty Cash Fund\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6050\",\"description\":\"Diesel\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"6800.00\",\"tax_amount\":\"816.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(97,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'vend','vend.debit_memos','create','transaction',66,'Supplier Debit Memo DM-00001','1908.48',NULL,'{\"txn_type\":\"vendor_credit\",\"txn_no\":\"DM-00001\",\"txn_date\":\"2026-09-29\",\"due_date\":null,\"ref_no\":\"NPC-CM-331\",\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Returned 12 kg whole chicken, warm on arrival\",\"subtotal\":\"1704.00\",\"tax_total\":\"204.48\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1908.48\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Accounts Payable\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"12.0000\",\"rate\":\"142.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1704.00\",\"tax_amount\":\"204.48\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(98,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.pay_bills','create','transaction',67,'Bill Payment 1009','57636.74',NULL,'{\"txn_type\":\"bill_payment\",\"txn_no\":\"1009\",\"txn_date\":\"2026-10-04\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Payment of NPC-INV-10231\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"57636.74\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Northfield Poultry Corp.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00004\",\"amount\":\"57636.74\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(99,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.pay_bills','create','transaction',68,'Bill Payment 1010','96824.84',NULL,'{\"txn_type\":\"bill_payment\",\"txn_no\":\"1010\",\"txn_date\":\"2026-10-04\",\"due_date\":null,\"ref_no\":\"IB-77100\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Electricity\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"96824.84\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Camarines Power Cooperative\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00007\",\"amount\":\"96824.84\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(100,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.pay_bills','create','transaction',69,'Bill Payment 1011','49500.00',NULL,'{\"txn_type\":\"bill_payment\",\"txn_no\":\"1011\",\"txn_date\":\"2026-11-05\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Payment of APC-2231, 2% withheld\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"900.00\",\"total\":\"49500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Accounting Partners & Co.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"bill\",\"txn_no\":\"BILL-00009\",\"amount\":\"49500.00\",\"discount\":\"0.00\",\"withholding\":\"900.00\"}]}',NULL,NULL);
INSERT INTO `audit_trail` (`id`,`created_at`,`user_id`,`username`,`user_roles`,`ip_address`,`workstation`,`site_id`,`terminal_id`,`module`,`page_key`,`action`,`record_type`,`record_id`,`record_ref`,`amount`,`changes`,`snapshot`,`reason`,`approved_by`) VALUES
(101,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'vend','vend.advances','create','transaction',70,'Advance to Supplier ADV-00001','150000.00',NULL,'{\"txn_type\":\"vendor_advance\",\"txn_no\":\"ADV-00001\",\"txn_date\":\"2026-11-11\",\"due_date\":\"2026-12-15\",\"ref_no\":\"1188\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Advance on the holiday season allocation\",\"subtotal\":\"150000.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"150000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":\"Golden Plume Farms Inc.\",\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[]}',NULL,NULL),
(102,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','create','transaction',71,'Check 1012','2500.00',NULL,'{\"txn_type\":\"check\",\"txn_no\":\"1012\",\"txn_date\":\"2026-11-15\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Office Snacks Co.\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Pantry supplies\",\"subtotal\":\"2500.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6900\",\"description\":\"Pantry supplies\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(103,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.write_checks','void','transaction',71,'Check 1012','2500.00','[{\"field\":\"status\",\"old\":\"open\",\"new\":\"void\"}]','{\"txn_type\":\"check\",\"txn_no\":\"1012\",\"txn_date\":\"2026-11-15\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Office Snacks Co.\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Pantry supplies\",\"subtotal\":\"2500.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"2500.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"expense\",\"item\":null,\"account\":\"6900\",\"description\":\"Pantry supplies\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2500.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Check printed with wrong payee',NULL),
(104,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.estimates','create','transaction',72,'Estimate EST-00002','7840.00',NULL,'{\"txn_type\":\"estimate\",\"txn_no\":\"EST-00002\",\"txn_date\":\"2026-11-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Duplicate quote\",\"subtotal\":\"7000.00\",\"tax_total\":\"840.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7840.00\",\"status\":\"pending\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Legazpi Grill House\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"40.0000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7000.00\",\"tax_amount\":\"840.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(105,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.estimates','delete','transaction',72,'Estimate EST-00002','7840.00',NULL,'{\"txn_type\":\"estimate\",\"txn_no\":\"EST-00002\",\"txn_date\":\"2026-11-16\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Duplicate quote\",\"subtotal\":\"7000.00\",\"tax_total\":\"840.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"7840.00\",\"status\":\"pending\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Legazpi Grill House\",\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"40.0000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7000.00\",\"tax_amount\":\"840.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Duplicate of an existing quotation',NULL),
(106,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.adjust','create','transaction',73,'Inventory Adjustment ADJ-00001','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00001\",\"txn_date\":\"2026-11-01\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Spoilage - freezer door left open\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Spoilage\",\"qty\":\"-1.5000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Spoilage',NULL),
(107,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',2,NULL,'inv','inv.adjust','create','transaction',74,'Inventory Adjustment ADJ-00002','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00002\",\"txn_date\":\"2026-11-17\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Physical count by D. Villanueva\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Count difference (2 packs torn)\",\"qty\":\"-2.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"PKG-BAG\",\"account\":null,\"description\":\"Count difference (bags found in the store room)\",\"qty\":\"50.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Physical inventory count',NULL),
(108,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.transfers','create','transaction',75,'Transfer TRF-00001','15000.00',NULL,'{\"txn_type\":\"transfer\",\"txn_no\":\"TRF-00001\",\"txn_date\":\"2026-10-11\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Replenish petty cash\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"15000.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[]}',NULL,NULL),
(109,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.cash_voucher','create','transaction',76,'Cash Voucher CAV-00001','1250.00',NULL,'{\"txn_type\":\"cash_voucher\",\"txn_no\":\"CAV-00001\",\"txn_date\":\"2026-10-26\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Toll and parking, pick-ups at Pili\",\"subtotal\":\"1250.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1250.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Petty Cash Fund\",\"class\":\"Head Office\",\"other_name\":\"Glenn Abad\",\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6100\",\"description\":\"Toll and parking\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1250.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(110,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.cash_voucher','create','transaction',77,'Cash Voucher CAV-00002','480.00',NULL,'{\"txn_type\":\"cash_voucher\",\"txn_no\":\"CAV-00002\",\"txn_date\":\"2026-11-13\",\"due_date\":null,\"ref_no\":null,\"payee_name\":\"Tricycle fares\",\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Small deliveries, Naga Outlet\",\"subtotal\":\"480.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"480.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Petty Cash Fund\",\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6100\",\"description\":\"Fares for small deliveries\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"480.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(111,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.deposits','create','transaction',78,'Deposit DEP-00001','74278.00',NULL,'{\"txn_type\":\"deposit\",\"txn_no\":\"DEP-00001\",\"txn_date\":\"2026-11-01\",\"due_date\":null,\"ref_no\":\"DS-1001\",\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Deposit\",\"subtotal\":\"74278.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"74278.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Sales Receipt SR-00001\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1659.20\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Customer Payment PMT-00001\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"60000.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Customer Payment PMT-00003\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"7404.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"1050\",\"description\":\"Customer Payment PMT-00004\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"3964.80\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"deposit\",\"item\":null,\"account\":\"4200\",\"description\":\"Interest on time deposit\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1250.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(112,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.depreciation','create','transaction',79,'Depreciation JE-00001','99821.67',NULL,'{\"txn_type\":\"depreciation\",\"txn_no\":\"JE-00001\",\"txn_date\":\"2026-09-30\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Depreciation for September 2026\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"99821.67\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2708.33\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1555\",\"description\":\"Accumulated depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-2708.33\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"15446.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1525\",\"description\":\"Accumulated depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-15446.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"81666.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1535\",\"description\":\"Accumulated depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-81666.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(113,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'fa','fa.depreciation','create','transaction',80,'Depreciation JE-00002','99955.00',NULL,'{\"txn_type\":\"depreciation\",\"txn_no\":\"JE-00002\",\"txn_date\":\"2026-10-31\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Depreciation for October 2026\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"99955.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2708.33\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1555\",\"description\":\"Accumulated depreciation - Computer and POS Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-2708.33\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"15580.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1525\",\"description\":\"Accumulated depreciation - Production Machinery (usage-based)\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-15580.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6090\",\"description\":\"Depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"81666.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1535\",\"description\":\"Accumulated depreciation - Transportation Equipment\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-81666.67\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(114,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.reconcile','create','transaction',81,'Service Charge JE-00003','150.00',NULL,'{\"txn_type\":\"bank_charge\",\"txn_no\":\"JE-00003\",\"txn_date\":\"2026-09-30\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Bank service charge\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"150.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Cash in Bank - BDO Checking\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6080\",\"description\":\"Service charge\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"150.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1010\",\"description\":\"Service charge\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-150.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(115,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'bank','bank.reconcile','reconcile','reconciliation',1,'BDO Checking, 09/30/2026','1178450.00',NULL,NULL,NULL,NULL),
(116,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',NULL,1,'pos',NULL,'shift_open','shift',1,'Naga Outlet Counter 1','3000.00',NULL,NULL,NULL,NULL),
(117,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',82,'POS Sale POS-000001','812.00',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000001\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"725.00\",\"tax_total\":\"87.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"812.00\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000001\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"3.4000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"595.00\",\"tax_amount\":\"71.40\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"2.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"130.00\",\"tax_amount\":\"15.60\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(118,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',82,'POS Sale POS-000001','812.00','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000001\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"725.00\",\"tax_total\":\"87.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"812.00\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000001\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"3.4000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"595.00\",\"tax_amount\":\"71.40\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"2.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"130.00\",\"tax_amount\":\"15.60\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(119,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',83,'POS Sale POS-000002','1717.41',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000002\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1533.40\",\"tax_total\":\"184.01\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1717.41\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000002\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"9.0200\",\"rate\":\"170.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1533.40\",\"tax_amount\":\"184.01\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(120,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',83,'POS Sale POS-000002','1717.41','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000002\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1533.40\",\"tax_total\":\"184.01\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1717.41\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000002\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"9.0200\",\"rate\":\"170.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1533.40\",\"tax_amount\":\"184.01\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(121,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',84,'POS Sale POS-000003','318.08',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000003\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"284.00\",\"tax_total\":\"34.08\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"318.08\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000003\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"1.2000\",\"rate\":\"130.0000\",\"discount_amount\":\"0.00\",\"amount\":\"156.00\",\"tax_amount\":\"18.72\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"1.0000\",\"rate\":\"128.0000\",\"discount_amount\":\"0.00\",\"amount\":\"128.00\",\"tax_amount\":\"15.36\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(122,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',84,'POS Sale POS-000003','318.08','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000003\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"284.00\",\"tax_total\":\"34.08\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"318.08\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000003\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"LVR-FZ\",\"account\":null,\"description\":\"Chicken Liver, Frozen, Bag\",\"qty\":\"1.2000\",\"rate\":\"130.0000\",\"discount_amount\":\"0.00\",\"amount\":\"156.00\",\"tax_amount\":\"18.72\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"1.0000\",\"rate\":\"128.0000\",\"discount_amount\":\"0.00\",\"amount\":\"128.00\",\"tax_amount\":\"15.36\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(123,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',85,'POS Sale POS-000004','953.12',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000004\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"851.00\",\"tax_total\":\"102.12\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"953.12\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000004\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"4.6000\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"851.00\",\"tax_amount\":\"102.12\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(124,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',85,'POS Sale POS-000004','953.12','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000004\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"851.00\",\"tax_total\":\"102.12\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"953.12\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000004\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"4.6000\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"851.00\",\"tax_amount\":\"102.12\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(125,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',86,'POS Sale POS-000005','1182.72',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000005\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1056.00\",\"tax_total\":\"126.72\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1182.72\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000005\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"PARTY-PK\",\"account\":null,\"description\":\"Party Pack (2 kg wings, 1 kg drumsticks)\",\"qty\":\"1.0000\",\"rate\":\"720.0000\",\"discount_amount\":\"0.00\",\"amount\":\"720.00\",\"tax_amount\":\"86.40\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"2.0000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"336.00\",\"tax_amount\":\"40.32\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(126,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',86,'POS Sale POS-000005','1182.72','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000005\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"1056.00\",\"tax_total\":\"126.72\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1182.72\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000005\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"PARTY-PK\",\"account\":null,\"description\":\"Party Pack (2 kg wings, 1 kg drumsticks)\",\"qty\":\"1.0000\",\"rate\":\"720.0000\",\"discount_amount\":\"0.00\",\"amount\":\"720.00\",\"tax_amount\":\"86.40\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag\",\"qty\":\"2.0000\",\"rate\":\"168.0000\",\"discount_amount\":\"0.00\",\"amount\":\"336.00\",\"tax_amount\":\"40.32\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(127,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',NULL,1,'pos',NULL,'cash_drop','shift',1,'Cash drop','2000.00',NULL,NULL,NULL,NULL),
(128,'2026-11-25 21:50:05',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.receipts','void','transaction',85,'POS Sale POS-000004','953.12','[{\"field\":\"status\",\"old\":\"completed\",\"new\":\"void\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000004\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"851.00\",\"tax_total\":\"102.12\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"953.12\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000004\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"4.6000\",\"rate\":\"185.0000\",\"discount_amount\":\"0.00\",\"amount\":\"851.00\",\"tax_amount\":\"102.12\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Customer changed mind before leaving the counter','supervisor'),
(129,'2026-11-25 21:50:05',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.receipts','start','transaction',87,'POS Return POS-000006','72.80',NULL,'{\"txn_type\":\"pos_return\",\"txn_no\":\"POS-000006\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Return: pack thawed\",\"subtotal\":\"65.00\",\"tax_total\":\"7.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"72.80\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000006\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"1.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"65.00\",\"tax_amount\":\"7.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pack thawed',NULL),
(130,'2026-11-25 21:50:05',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.receipts','refund','transaction',87,'POS Return POS-000006','72.80','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_return\",\"txn_no\":\"POS-000006\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Return: pack thawed\",\"subtotal\":\"65.00\",\"tax_total\":\"7.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"72.80\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000006\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"1.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"65.00\",\"tax_amount\":\"7.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Pack thawed','supervisor'),
(131,'2026-11-25 21:50:05',8,'supervisor','POS Supervisor','cli','CLI',2,1,'pos','pos.shifts','create','transaction',88,'Cash Over/Short JE-00004','20.00',NULL,'{\"txn_type\":\"pos_over_short\",\"txn_no\":\"JE-00004\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Cash short - Naga Outlet Counter 1\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"20.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"journal\",\"item\":null,\"account\":\"1001\",\"description\":\"Drawer count difference\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-20.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"journal\",\"item\":null,\"account\":\"6200\",\"description\":\"Cash over and short\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"20.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(132,'2026-11-25 21:50:05',8,'supervisor','POS Supervisor','cli','CLI',NULL,1,'pos',NULL,'shift_close','shift',1,'Z-reading','2901.92',NULL,NULL,'Short by 20.00','supervisor'),
(133,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',NULL,1,'pos',NULL,'shift_open','shift',2,'Naga Outlet Counter 1','3000.00',NULL,NULL,NULL,NULL),
(134,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',89,'POS Sale POS-000007','588.80',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000007\",\"txn_date\":\"2026-11-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"530.00\",\"tax_total\":\"58.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"588.80\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000007\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"2.8000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"490.00\",\"tax_amount\":\"58.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"1.0000\",\"rate\":\"40.0000\",\"discount_amount\":\"0.00\",\"amount\":\"40.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(135,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',89,'POS Sale POS-000007','588.80','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000007\",\"txn_date\":\"2026-11-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"530.00\",\"tax_total\":\"58.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"588.80\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000007\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"2.8000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"490.00\",\"tax_amount\":\"58.80\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"1.0000\",\"rate\":\"40.0000\",\"discount_amount\":\"0.00\",\"amount\":\"40.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(136,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','start','transaction',90,'POS Sale POS-000008','537.60',NULL,'{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000008\",\"txn_date\":\"2026-11-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"480.00\",\"tax_total\":\"57.60\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"537.60\",\"status\":\"suspended\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000008\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"4.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"260.00\",\"tax_amount\":\"31.20\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"2.0000\",\"rate\":\"128.0000\",\"discount_amount\":\"0.00\",\"amount\":\"256.00\",\"tax_amount\":\"30.72\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":null,\"account\":\"4070\",\"description\":\"Price variance: Fiesta Bundle\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-36.00\",\"tax_amount\":\"-4.32\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(137,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',2,1,'pos','pos.receipts','sale','transaction',90,'POS Sale POS-000008','537.60','[{\"field\":\"status\",\"old\":\"suspended\",\"new\":\"completed\"}]','{\"txn_type\":\"pos_sale\",\"txn_no\":\"POS-000008\",\"txn_date\":\"2026-11-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":null,\"subtotal\":\"480.00\",\"tax_total\":\"57.60\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"537.60\",\"status\":\"completed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":\"NO1-00000008\",\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":\"Naga Outlet\",\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"4.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"260.00\",\"tax_amount\":\"31.20\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"NGT-500\",\"account\":null,\"description\":\"Chicken Nuggets 500 g, Frozen, Pack\",\"qty\":\"2.0000\",\"rate\":\"128.0000\",\"discount_amount\":\"0.00\",\"amount\":\"256.00\",\"tax_amount\":\"30.72\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":null,\"account\":\"4070\",\"description\":\"Price variance: Fiesta Bundle\",\"qty\":\"0.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"-36.00\",\"tax_amount\":\"-4.32\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(138,'2026-11-25 21:50:05',9,'cashier1','Cashier','cli','CLI',NULL,1,'security','admin.roles','access_denied','page',NULL,'User Role Configuration (open)',NULL,NULL,NULL,NULL,NULL),
(139,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.adjust','create','transaction',91,'Inventory Adjustment ADJ-00003','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00003\",\"txn_date\":\"2026-11-11\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Expired fresh chilled stock condemned (city meat inspector present)\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Condemned, 5 expired crate(s)\",\"qty\":\"-76.0500\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Spoilage',NULL),
(140,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',2,NULL,'inv','inv.adjust','create','transaction',92,'Inventory Adjustment ADJ-00004','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00004\",\"txn_date\":\"2026-11-11\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Expired fresh chilled stock condemned (city meat inspector present)\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Condemned, 12 expired crate(s)\",\"qty\":\"-146.9600\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Condemned, 4 expired crate(s)\",\"qty\":\"-58.1800\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Spoilage',NULL),
(141,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',93,'Inventory Transfer IT-00008','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00008\",\"txn_date\":\"2026-11-21\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":6,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Van Store 1 load-out (Rico Mendoza)\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"37.6000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"3.4200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"40.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(142,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',94,'Inventory Transfer IT-00009','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00009\",\"txn_date\":\"2026-11-21\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":6,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Van Store 1 load-out: chicken blood\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"6.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(143,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',6,NULL,'cust','cust.sales_receipts','create','transaction',95,'Sales Receipt SR-00002','3330.38',NULL,'{\"txn_type\":\"sales_receipt\",\"txn_no\":\"SR-00002\",\"txn_date\":\"2026-11-21\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":6,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":3,\"memo\":\"Van sale, Naga public market\",\"subtotal\":\"2973.55\",\"tax_total\":\"356.83\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"3330.38\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Aling Tess Market Stall\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"12.7900\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"2238.25\",\"tax_amount\":\"268.59\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Chicken Drumstick, Frozen, Bag\",\"qty\":\"3.4200\",\"rate\":\"215.0000\",\"discount_amount\":\"0.00\",\"amount\":\"735.30\",\"tax_amount\":\"88.24\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(144,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',6,NULL,'cust','cust.sales_receipts','create','transaction',96,'Sales Receipt SR-00003','1144.00',NULL,'{\"txn_type\":\"sales_receipt\",\"txn_no\":\"SR-00003\",\"txn_date\":\"2026-11-21\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":6,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":3,\"memo\":\"Van sale, Barangay Concepcion\",\"subtotal\":\"1030.00\",\"tax_total\":\"114.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1144.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Walk-in Customer\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"3.2000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"560.00\",\"tax_amount\":\"67.20\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"2.0000\",\"rate\":\"40.0000\",\"discount_amount\":\"0.00\",\"amount\":\"80.00\",\"tax_amount\":\"0.00\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"6.0000\",\"rate\":\"65.0000\",\"discount_amount\":\"0.00\",\"amount\":\"390.00\",\"tax_amount\":\"46.80\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(145,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.adjust','create','transaction',97,'Inventory Adjustment ADJ-00005','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00005\",\"txn_date\":\"2026-11-21\",\"due_date\":null,\"ref_no\":\"TC-00001\",\"payee_name\":null,\"site_id\":6,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":3,\"memo\":\"Shrinkage - Inventory Transfer Closing TC-00001 - Evening closing, Naga route\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Shrinkage\",\"qty\":\"-0.1800\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shrinkage on Inventory Transfer Closing TC-00001',NULL),
(146,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.shortages','create','transaction',98,'Shortage Charge SHC-00001','108.50',NULL,'{\"txn_type\":\"shortage_charge\",\"txn_no\":\"SHC-00001\",\"txn_date\":\"2026-11-21\",\"due_date\":\"2026-11-21\",\"ref_no\":\"TC-00001\",\"payee_name\":null,\"site_id\":6,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":3,\"memo\":\"Shortage - Inventory Transfer Closing TC-00001 - Evening closing, Naga route\",\"subtotal\":\"108.50\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"108.50\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Rico Mendoza\",\"vendor\":null,\"account\":\"Shortage Receivable - Employees\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack, crate 48 (shortage)\",\"qty\":\"2.0000\",\"rate\":\"48.0000\",\"discount_amount\":\"0.00\",\"amount\":\"96.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood (shortage)\",\"qty\":\"0.5000\",\"rate\":\"25.0000\",\"discount_amount\":\"0.00\",\"amount\":\"12.50\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shortage on Inventory Transfer Closing TC-00001',NULL),
(147,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.transfers','create','transaction',99,'Inventory Transfer IT-00010','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00010\",\"txn_date\":\"2026-11-21\",\"due_date\":null,\"ref_no\":\"TC-00001\",\"payee_name\":null,\"site_id\":6,\"site2_id\":1,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Inventory Transfer Closing TC-00001 - Evening closing, Naga route\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLB-250\",\"account\":null,\"description\":\"Chicken Bola-Bola 250 g, Frozen, Pack\",\"qty\":\"32.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"3.5000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"9.1500\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"12.2800\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Inventory Transfer Closing TC-00001',NULL),
(148,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.transfer_closing','create','transfer_closing',1,'TC-00001','108.50',NULL,NULL,'Closing of Van Store 1 (LAB 4417) back to Naga Cold Storage: 4 line(s), 56.93 back, 0.18 shrinkage, 2.5 shortage',NULL),
(149,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'cust','cust.payments','create','transaction',100,'Customer Payment PMT-00006','54.25',NULL,'{\"txn_type\":\"payment\",\"txn_no\":\"PMT-00006\",\"txn_date\":\"2026-11-22\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":null,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Shortage on TC-00001, first half\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"54.25\",\"status\":\"closed\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Rico Mendoza\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[],\"applied_to\":[{\"txn_type\":\"shortage_charge\",\"txn_no\":\"SHC-00001\",\"amount\":\"54.25\",\"discount\":\"0.00\",\"withholding\":\"0.00\"}]}',NULL,NULL),
(150,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',101,'Inventory Transfer IT-00011','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00011\",\"txn_date\":\"2026-11-22\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":7,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Van Store 2 load-out (Arnel Cruz)\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"21.4300\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"13.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(151,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',7,NULL,'cust','cust.sales_receipts','create','transaction',102,'Sales Receipt SR-00004','1747.20',NULL,'{\"txn_type\":\"sales_receipt\",\"txn_no\":\"SR-00004\",\"txn_date\":\"2026-11-22\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":7,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":4,\"memo\":\"Van sale, Pili town proper\",\"subtotal\":\"1560.00\",\"tax_total\":\"187.20\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1747.20\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Walk-in Customer\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"5.0000\",\"rate\":\"228.0000\",\"discount_amount\":\"0.00\",\"amount\":\"1140.00\",\"tax_amount\":\"136.80\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"2.4000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"420.00\",\"tax_amount\":\"50.40\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(152,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',7,NULL,'inv','inv.adjust','create','transaction',103,'Inventory Adjustment ADJ-00006','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00006\",\"txn_date\":\"2026-11-22\",\"due_date\":null,\"ref_no\":\"TC-00002\",\"payee_name\":null,\"site_id\":7,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":4,\"memo\":\"Shrinkage - Inventory Transfer Closing TC-00002 - Evening closing, Pili route\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Shrinkage\",\"qty\":\"-0.1200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":7,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shrinkage on Inventory Transfer Closing TC-00002',NULL),
(153,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',7,NULL,'inv','inv.shortages','create','transaction',104,'Shortage Charge SHC-00002','1740.77',NULL,'{\"txn_type\":\"shortage_charge\",\"txn_no\":\"SHC-00002\",\"txn_date\":\"2026-11-22\",\"due_date\":\"2026-11-22\",\"ref_no\":\"TC-00002\",\"payee_name\":null,\"site_id\":7,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":4,\"memo\":\"Shortage - Inventory Transfer Closing TC-00002 - Evening closing, Pili route\",\"subtotal\":\"1740.77\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"1740.77\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Arnel Cruz\",\"vendor\":null,\"account\":\"Shortage Receivable - Employees\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag, crate 155 (shortage)\",\"qty\":\"12.2800\",\"rate\":\"141.7566\",\"discount_amount\":\"0.00\",\"amount\":\"1740.77\",\"tax_amount\":\"0.00\",\"site_id\":7,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shortage on Inventory Transfer Closing TC-00002',NULL),
(154,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',7,NULL,'inv','inv.transfers','create','transaction',105,'Inventory Transfer IT-00012','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00012\",\"txn_date\":\"2026-11-22\",\"due_date\":null,\"ref_no\":\"TC-00002\",\"payee_name\":null,\"site_id\":7,\"site2_id\":1,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Inventory Transfer Closing TC-00002 - Evening closing, Pili route\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BRS-FZ\",\"account\":null,\"description\":\"Chicken Breast, Frozen, Bag\",\"qty\":\"7.8800\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":7,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"6.7500\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":7,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Inventory Transfer Closing TC-00002',NULL),
(155,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',7,NULL,'inv','inv.transfer_closing','create','transfer_closing',2,'TC-00002','1740.77',NULL,NULL,'Closing of Van Store 2 (LAB 4428) back to Naga Cold Storage: 3 line(s), 14.63 back, 0.12 shrinkage, 12.28 shortage',NULL),
(156,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',106,'Inventory Transfer IT-00013','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00013\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":6,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Van Store 1 load-out (Rico Mendoza)\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"19.6200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"14.5400\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(157,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',6,NULL,'cust','cust.sales_receipts','create','transaction',107,'Sales Receipt SR-00005','940.80',NULL,'{\"txn_type\":\"sales_receipt\",\"txn_no\":\"SR-00005\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":6,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":3,\"memo\":\"Van sale, Barangay Triangulo\",\"subtotal\":\"840.00\",\"tax_total\":\"100.80\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"940.80\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Walk-in Customer\",\"vendor\":null,\"account\":\"Undeposited Funds\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"4.8000\",\"rate\":\"175.0000\",\"discount_amount\":\"0.00\",\"amount\":\"840.00\",\"tax_amount\":\"100.80\",\"site_id\":null,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(158,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.adjust','create','transaction',108,'Inventory Adjustment ADJ-00007','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00007\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":\"TC-00003\",\"payee_name\":null,\"site_id\":6,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":3,\"memo\":\"Shrinkage - Inventory Transfer Closing TC-00003 - Evening closing, Naga route\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Shrinkage\",\"qty\":\"-0.1000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shrinkage on Inventory Transfer Closing TC-00003',NULL),
(159,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.transfers','create','transaction',109,'Inventory Transfer IT-00014','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00014\",\"txn_date\":\"2026-11-24\",\"due_date\":null,\"ref_no\":\"TC-00003\",\"payee_name\":null,\"site_id\":6,\"site2_id\":1,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Inventory Transfer Closing TC-00003 - Evening closing, Naga route\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BBD-FC\",\"account\":null,\"description\":\"Big Bird Chicken, Fresh Chilled, Vac\",\"qty\":\"14.4400\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"1.9500\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Whole Chicken, Fresh Chilled, Bag\",\"qty\":\"12.8700\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":6,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Inventory Transfer Closing TC-00003',NULL),
(160,'2026-11-25 21:50:05',5,'invclerk','Inventory Clerk','cli','CLI',6,NULL,'inv','inv.transfer_closing','create','transfer_closing',3,'TC-00003','0.00',NULL,NULL,'Closing of Van Store 1 (LAB 4417) back to Naga Cold Storage: 3 line(s), 29.26 back, 0.1 shrinkage, 0 shortage',NULL),
(161,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',110,'Inventory Transfer IT-00015','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00015\",\"txn_date\":\"2026-11-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":6,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Van Store 1 load-out (Rico Mendoza)\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"WCK-FC\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"14.8200\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null},{\"line_kind\":\"item\",\"item\":\"DRM-FZ\",\"account\":null,\"description\":\"Crates to the branch\",\"qty\":\"15.1400\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(162,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.transfers','create','transaction',111,'Inventory Transfer IT-00016','0.00',NULL,'{\"txn_type\":\"inventory_transfer\",\"txn_no\":\"IT-00016\",\"txn_date\":\"2026-11-25\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":6,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Van Store 1 load-out: chicken blood\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":null,\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Chicken Blood\",\"qty\":\"4.0000\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}',NULL,NULL),
(163,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',2,NULL,'inv','inv.shortages','create','transaction',112,'Shortage Charge SHC-00003','269.87',NULL,'{\"txn_type\":\"shortage_charge\",\"txn_no\":\"SHC-00003\",\"txn_date\":\"2026-11-23\",\"due_date\":\"2026-11-23\",\"ref_no\":null,\"payee_name\":null,\"site_id\":2,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":5,\"memo\":\"Shortage - counter count\",\"subtotal\":\"269.87\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"269.87\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":\"Ella Ramos\",\"vendor\":null,\"account\":\"Shortage Receivable - Employees\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"ACU-FZ\",\"account\":null,\"description\":\"Chicken Assorted Cut-Ups, Frozen, Bag (shortage: counter count)\",\"qty\":\"2.0000\",\"rate\":\"134.9355\",\"discount_amount\":\"0.00\",\"amount\":\"269.87\",\"tax_amount\":\"0.00\",\"site_id\":2,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shortage charged to Ella Ramos (counter count)',NULL),
(164,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',1,NULL,'inv','inv.adjust','create','transaction',113,'Inventory Adjustment ADJ-00008','0.00',NULL,'{\"txn_type\":\"inventory_adjustment\",\"txn_no\":\"ADJ-00008\",\"txn_date\":\"2026-11-23\",\"due_date\":null,\"ref_no\":null,\"payee_name\":null,\"site_id\":1,\"site2_id\":null,\"terms_id\":null,\"sales_rep_id\":null,\"memo\":\"Shrinkage - weekly count\",\"subtotal\":\"0.00\",\"tax_total\":\"0.00\",\"discount_amount\":\"0.00\",\"withholding_amount\":\"0.00\",\"total\":\"0.00\",\"status\":\"open\",\"is_pending\":0,\"is_voided\":0,\"receipt_no\":null,\"process_type\":null,\"alloc_method\":null,\"process_formula_id\":null,\"process_batches\":null,\"customer\":null,\"vendor\":null,\"account\":\"Inventory Adjustments and Shrinkage\",\"class\":null,\"other_name\":null,\"lines\":[{\"line_kind\":\"item\",\"item\":\"BLD\",\"account\":null,\"description\":\"Shrinkage\",\"qty\":\"-1.3500\",\"rate\":\"0.0000\",\"discount_amount\":\"0.00\",\"amount\":\"0.00\",\"tax_amount\":\"0.00\",\"site_id\":1,\"is_billable\":0,\"output_role\":null,\"alloc_basis\":\"0.0000\",\"class\":null}]}','Shrinkage',NULL),
(165,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin',NULL,'page_access_override','user',7,'User: salesrep',NULL,'[{\"field\":\"Customer Balance Summary\",\"old\":\"Inherit from role\",\"new\":\"Override: allowed [P]\"}]',NULL,'Needs balances for account visits',NULL),
(166,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin',NULL,'page_access_override','user',3,'User: arclerk',NULL,'[{\"field\":\"Assess Finance Charges\",\"old\":\"Inherit from role\",\"new\":\"Override: denied\"}]',NULL,'Finance charges are assessed by the accountant',NULL),
(167,'2026-11-25 21:50:05',4,'apclerk','','cli','CLI',NULL,NULL,'security',NULL,'login_failed','user',4,'apclerk',NULL,NULL,NULL,'Wrong password (attempt 1 of 5)',NULL),
(168,'2026-11-25 21:50:05',4,'apclerk','','cli','CLI',NULL,NULL,'security',NULL,'login_failed','user',4,'apclerk',NULL,NULL,NULL,'Wrong password (attempt 2 of 5)',NULL),
(169,'2026-11-25 21:50:05',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin',NULL,'closing_date_change','settings',NULL,'Closing date',NULL,'[{\"field\":\"closing_date\",\"old\":\"\",\"new\":\"2026-09-06\"}]',NULL,'Opening balances finalized',NULL),
(170,'2026-11-25 21:50:06',1,'admin','Administrator','cli','CLI',NULL,NULL,'admin','admin.multi_company','multi_company_setup','company',1,'Northpoint Cold Chain Distributors Inc.',NULL,NULL,NULL,'Registered as Company 1 of the platform. Company Owner: admin. Super Admin: superadmin.',NULL);

-- sequences (31 rows)
INSERT INTO `sequences` (`seq_key`,`prefix`,`next_no`,`pad`) VALUES
('adjustment','ADJ-',9,5),
('advance_apply','AAP-',1,5),
('allocation','AL-',11,5),
('asset','FA-',5,5),
('bill','BILL-',10,5),
('build','BLD-',3,5),
('cash_voucher','CAV-',3,5),
('check','',1013,4),
('crate','',179,1),
('credit_memo','CM-',2,5),
('debit_memo','DM-',2,5),
('deposit','DEP-',2,5),
('estimate','EST-',3,5),
('finance_charge','FC-',2,5),
('inv_dispatch','DSP-',1,5),
('inv_transfer','IT-',17,5),
('invoice','INV-',18,5),
('item_receipt','IR-',9,5),
('journal','JE-',5,5),
('maintenance','MNT-',2,5),
('payment','PMT-',7,5),
('pos','POS-',9,6),
('processing','PRC-',4,5),
('purchase_order','PO-',1,5),
('sales_order','SO-',2,5),
('sales_receipt','SR-',6,5),
('shortage','SHC-',4,5),
('statement_charge','SC-',2,5),
('transfer','TRF-',2,5),
('transfer_closing','TC-',4,5),
('vendor_advance','ADV-',2,5);

-- accounts (73 rows)
INSERT INTO `accounts` (`id`,`code`,`name`,`account_type`,`category`,`normal_balance`,`parent_id`,`description`,`bank_account_no`,`with_sl`,`is_active`,`is_system`,`created_at`,`updated_at`) VALUES
(1,'1000','Cash','Bank','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(2,'1001','Cash on Hand - Store Registers','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(3,'1005','Petty Cash Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(4,'1006','Revolving Fund','Bank','Asset','Debit',1,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(5,'1010','Cash in Bank - BDO Checking','Bank','Asset','Debit',1,NULL,'0012-3456-7890',0,1,0,'2026-11-25 21:50:03',NULL),
(6,'1020','Cash in Bank - BPI Savings','Bank','Asset','Debit',1,NULL,'1234-5678-90',0,1,0,'2026-11-25 21:50:03',NULL),
(7,'1050','Undeposited Funds','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(8,'1060','Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(9,'1065','E-wallet Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(10,'1070','P.O. Card Clearing','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(11,'1100','Accounts Receivable','Accounts Receivable','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(12,'1120','Shortage Receivable - Employees','Accounts Receivable','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(13,'1150','Allowance for Doubtful Accounts','Other Current Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(14,'1200','Inventory','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(15,'1300','Input Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(16,'1310','Creditable Withholding Tax','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(17,'1315','Creditable VAT Withheld','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(18,'1400','Prepaid Expenses','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(19,'1410','Advances to Suppliers','Other Current Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(20,'1500','Land','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(21,'1510','Building','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(22,'1515','Accumulated Depreciation - Building','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(23,'1520','Machinery and Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(24,'1525','Accumulated Depreciation - Machinery','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(25,'1530','Transportation Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(26,'1535','Accumulated Depreciation - Transportation','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(27,'1540','Furniture and Fixtures','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(28,'1545','Accumulated Depreciation - Furniture','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(29,'1550','Computer and POS Equipment','Fixed Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(30,'1555','Accumulated Depreciation - Computer and POS','Fixed Asset','Asset','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(31,'1600','Security Deposits','Other Asset','Asset','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(32,'2000','Accounts Payable','Accounts Payable','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(33,'2050','Company Credit Card','Credit Card','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(34,'2100','Output Tax','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(35,'2110','Withholding Tax Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(36,'2115','VAT Withheld Payable','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(37,'2120','Gift Vouchers Outstanding','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(38,'2130','Customer Deposits','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(39,'2200','Accrued Expenses','Other Current Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(40,'2500','Loans Payable','Long Term Liability','Liability','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(41,'3000','Owner\'s Capital','Equity','Equity','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(42,'3100','Owner\'s Drawings','Equity','Equity','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(43,'3200','Retained Earnings','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(44,'3900','Opening Balance Equity','Equity','Equity','Credit',NULL,NULL,NULL,0,1,1,'2026-11-25 21:50:03',NULL),
(45,'4000','Sales','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(46,'4010','Service Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(47,'4020','Delivery Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(48,'4050','Sales Returns and Allowances','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(49,'4060','Sales Discounts','Income','Income','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(50,'4070','Item Group Price Variance','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(51,'4110','Reimbursable Expense Income','Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(52,'4100','Finance Charge Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(53,'4200','Interest Income','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(54,'4300','Gain (Loss) on Disposal of Assets','Other Income','Income','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(55,'5000','Cost of Goods Sold','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(56,'5050','Purchase Discounts','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(57,'5100','Inventory Adjustments and Shrinkage','Cost of Goods Sold','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(58,'5200','Direct Labor Absorbed','Cost of Goods Sold','Expense','Credit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(59,'6000','Salaries and Wages','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(60,'6010','Rent Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(61,'6020','Utilities Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(62,'6030','Repairs and Maintenance','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(63,'6040','Office Supplies Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(64,'6050','Fuel and Oil','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(65,'6060','Meals and Representation','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(66,'6070','Professional Fees','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(67,'6080','Bank and Merchant Charges','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(68,'6090','Depreciation Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(69,'6100','Freight and Delivery','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(70,'6110','Purchases - Non-inventory','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(71,'6200','Cash Over and Short','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(72,'6900','Miscellaneous Expense','Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL),
(73,'7000','Interest Expense','Other Expense','Expense','Debit',NULL,NULL,NULL,0,1,0,'2026-11-25 21:50:03',NULL);

-- default_accounts (33 rows)
INSERT INTO `default_accounts` (`setting_key`,`label`,`module`,`account_id`) VALUES
('ap','Accounts Payable','vend',32),
('ar','Accounts Receivable','cust',11),
('card_clearing','Card Clearing','pos',8),
('cash_on_hand','Cash on Hand (Register)','pos',2),
('cash_over_short','Cash Over and Short','pos',71),
('cogs','Cost of Goods Sold','inv',55),
('cvat_withheld','Creditable VAT Withheld','cust',17),
('cwt','Creditable Withholding Tax','cust',16),
('default_expense','Default Purchases / Expense','vend',70),
('ewallet_clearing','E-wallet Clearing','pos',9),
('finance_charge_income','Finance Charge Income','cust',52),
('gain_loss_disposal','Gain / Loss on Disposal of Assets','fa',54),
('group_price_variance','Item Group Price Variance','inv',50),
('input_tax','Input Tax','vend',15),
('interest_income','Interest Income','bank',53),
('inventory_adjustment','Inventory Adjustment (Shrinkage)','inv',57),
('inventory_asset','Inventory Asset','inv',14),
('merchant_fees','Bank / Merchant Charges','bank',67),
('opening_equity','Opening Balance Equity','coa',44),
('output_tax','Output Tax','cust',34),
('processing_absorbed','Processing Labor & Overhead Absorbed','inv',58),
('processing_variance','Processing / Disassembly Variance','inv',57),
('purchase_discounts','Purchase Discounts','vend',56),
('reimbursable_income','Reimbursable Expense Income','cust',51),
('retained_earnings','Retained Earnings','coa',43),
('sales_discounts','Sales Discounts','cust',49),
('sales_income','Default Sales Income','cust',45),
('sales_returns','Sales Returns and Allowances','cust',48),
('shortage_receivable','Shortage Receivable (Employees)','inv',12),
('undeposited_funds','Undeposited Funds','cust',7),
('vat_withheld_payable','VAT Withheld Payable','vend',36),
('vendor_advances','Advances to Suppliers','vend',19),
('wht_payable','Withholding Tax Payable (Expanded)','vend',35);

-- terms (5 rows)
INSERT INTO `terms` (`id`,`name`,`net_days`,`discount_pct`,`discount_days`,`is_active`) VALUES
(1,'Due on receipt',0,'0.00',0,1),
(2,'Net 15',15,'0.00',0,1),
(3,'Net 30',30,'0.00',0,1),
(4,'2% 10 Net 30',30,'2.00',10,1),
(5,'Net 60',60,'0.00',0,1);

-- tax_codes (4 rows)
INSERT INTO `tax_codes` (`id`,`code`,`name`,`rate`,`sales_account_id`,`purchase_account_id`,`is_active`) VALUES
(1,'VAT12','VAT 12%','12.000',34,15,1),
(2,'ZR','Zero-rated','0.000',34,15,1),
(3,'EX','VAT-exempt','0.000',34,15,1),
(4,'NT','Non-taxable','0.000',34,15,1);

-- payment_methods (9 rows)
INSERT INTO `payment_methods` (`id`,`name`,`method_type`,`clearing_account_id`,`is_active`,`show_in_pos`) VALUES
(1,'Cash','cash',NULL,1,1),
(2,'Check','check',NULL,1,0),
(3,'Credit/Debit Card','card',8,1,1),
(4,'GCash','ewallet',9,1,1),
(5,'Maya','ewallet',9,1,1),
(6,'Bank Transfer','bank_transfer',NULL,1,0),
(7,'Gift Voucher','voucher',37,1,1),
(8,'P.O. Card','card',10,1,1),
(9,'Bank','bank_transfer',5,1,1);

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

-- sales_reps (5 rows)
INSERT INTO `sales_reps` (`id`,`name`,`initials`,`user_id`,`commission_pct`,`rep_type`,`customer_id`,`is_active`) VALUES
(1,'Maria Santos','MS',7,'1.50','sales_rep',1,1),
(2,'Jose Reyes','JR',NULL,'2.50','sales_rep',2,1),
(3,'Rico Mendoza','RM',NULL,'1.00','van',3,1),
(4,'Arnel Cruz','AC',NULL,'1.00','van',4,1),
(5,'Ella Ramos','ER',9,'0.00','cashier',5,1);

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

-- classes (3 rows)
INSERT INTO `classes` (`id`,`name`,`description`,`is_active`,`sort_order`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'Head Office','Wholesale, deliveries and administration',1,1,1,'2026-11-25 21:50:04',NULL),
(2,'Naga Outlet','Retail counter at the Naga cold storage',1,2,1,'2026-11-25 21:50:04',NULL),
(3,'Legazpi Depot','Depot and counter in Legazpi',1,3,1,'2026-11-25 21:50:04',NULL);

-- other_names (3 rows)
INSERT INTO `other_names` (`id`,`name_type`,`name`,`employee_no`,`position`,`phone`,`address`,`tin`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'employee','Glenn Abad','EMP-010','Pick-up driver',NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL),
(2,'employee','Dan Villanueva','EMP-005','Cold storage clerk',NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL),
(3,'other','Barangay Treasurer',NULL,'Permits and clearances',NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL);

-- customers (14 rows)
INSERT INTO `customers` (`id`,`parent_id`,`name`,`company_name`,`contact_person`,`phone`,`mobile`,`email`,`billing_address`,`shipping_address`,`tin`,`wht_ids`,`terms_id`,`credit_limit`,`price_level_id`,`tax_code_id`,`payment_method_id`,`customer_type_id`,`sales_rep_id`,`billing_group_id`,`allow_pos_charge`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,NULL,'Maria Santos',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,NULL,NULL,6,1,NULL,0,'Sales representative of the company. Shortages charged to them are collected with Receive Payments.',1,'2026-11-25 21:50:04',NULL),
(2,NULL,'Jose Reyes',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,NULL,NULL,6,2,NULL,0,'Sales representative of the company. Shortages charged to them are collected with Receive Payments.',1,'2026-11-25 21:50:04',NULL),
(3,NULL,'Rico Mendoza',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,NULL,NULL,6,3,NULL,0,'Van salesman of the company. Shortages charged to them are collected with Receive Payments.',1,'2026-11-25 21:50:04',NULL),
(4,NULL,'Arnel Cruz',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,NULL,NULL,6,4,NULL,0,'Van salesman of the company. Shortages charged to them are collected with Receive Payments.',1,'2026-11-25 21:50:04',NULL),
(5,NULL,'Ella Ramos',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,NULL,NULL,6,5,NULL,0,'Cashier of the company. Shortages charged to them are collected with Receive Payments.',1,'2026-11-25 21:50:04',NULL),
(6,NULL,'Sunrise Supermart','Sunrise Supermart Inc.','Mr. Albert Co','(054) 881-1001',NULL,'ap@sunrisesupermart.test','Magsaysay Avenue, Naga City','Magsaysay Avenue, Naga City','111-222-333-000',NULL,3,'400000.00',2,1,2,1,1,NULL,1,NULL,1,'2026-11-25 21:50:04',NULL),
(7,6,'Sunrise Supermart Pili Branch',NULL,NULL,NULL,NULL,NULL,'Maharlika Highway, Pili, Camarines Sur','Maharlika Highway, Pili, Camarines Sur',NULL,NULL,3,'0.00',2,1,NULL,1,1,NULL,0,NULL,1,'2026-11-25 21:50:04',NULL),
(8,NULL,'Kusina ni Lola Restaurant','Kusina ni Lola Food House','Ms. Bea Lim','(054) 881-2002',NULL,'purchasing@kusinanilola.test','Elias Angeles St., Naga City',NULL,NULL,NULL,2,'120000.00',1,1,NULL,2,2,NULL,0,NULL,1,'2026-11-25 21:50:04',NULL),
(9,NULL,'Legazpi Grill House','Legazpi Grill House Co.','Mr. Carlo Sy','(052) 480-3003',NULL,'finance@legazpigrill.test','Rizal St., Legazpi City',NULL,NULL,NULL,4,'150000.00',1,1,NULL,2,2,NULL,0,NULL,1,'2026-11-25 21:50:04',NULL),
(10,NULL,'St. Raphael Hospital Kitchen','St. Raphael Hospital','Dr. Dina Reyes','(054) 881-4004',NULL,'dietary@straphael.test','Panganiban Drive, Naga City',NULL,NULL,NULL,2,'80000.00',NULL,1,NULL,4,1,1,0,NULL,1,'2026-11-25 21:50:04',NULL),
(11,NULL,'Aling Tess Market Stall',NULL,'Teresita Bernal','0917-555-0101',NULL,NULL,'Naga City Public Market, Stall 42',NULL,NULL,NULL,2,'30000.00',NULL,1,NULL,3,1,1,1,NULL,1,'2026-11-25 21:50:04',NULL),
(12,NULL,'Municipality of San Isidro','Municipal Government of San Isidro','Procurement Office','(054) 450-1000',NULL,'procurement@sanisidro.test','Municipal Hall, San Isidro, Camarines Sur',NULL,'000-456-789-000','3,1',3,'0.00',NULL,1,2,5,NULL,NULL,0,NULL,1,'2026-11-25 21:50:04',NULL),
(13,NULL,'Juan Dela Cruz',NULL,'Juan Dela Cruz',NULL,'0917-555-0000',NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,1,1,3,NULL,NULL,0,NULL,1,'2026-11-25 21:50:04',NULL),
(14,NULL,'Walk-in Customer',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'0.00',NULL,1,1,3,NULL,NULL,0,NULL,1,'2026-11-25 21:50:04',NULL);

-- vendors (9 rows)
INSERT INTO `vendors` (`id`,`name`,`company_name`,`contact_person`,`phone`,`fax`,`email`,`address`,`tin`,`terms_id`,`credit_limit`,`default_expense_account_id`,`tax_code_id`,`account_no`,`wht_ids`,`notes`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'Northfield Poultry Corp.','Northfield Poultry Corp.','Ramon Velasco','(054) 472-1180',NULL,'orders@northfieldpoultry.test','Pili, Camarines Sur','302-617-336-000',2,'0.00',NULL,1,'NPC-20418','1',NULL,1,'2026-11-25 21:50:04',NULL),
(2,'Golden Plume Farms Inc.','Golden Plume Farms Inc.','Teresa Lagman','(054) 811-0932',NULL,'sales@goldenplume.test','Ocampo, Camarines Sur','846-846-948-000',3,'0.00',NULL,1,'GPF-7751','1',NULL,1,'2026-11-25 21:50:04',NULL),
(3,'Bicol Packaging Supply','Bicol Packaging Supply','Liza Go','(054) 473-2255',NULL,'orders@bicolpack.test','Naga City','813-856-790-000',2,'0.00',63,1,'BPS-4410',NULL,NULL,1,'2026-11-25 21:50:04',NULL),
(4,'Camarines Power Cooperative','Camarines Power Cooperative','Customer Service','(054) 473-0001',NULL,'billing@campower.test','Naga City','923-170-377-000',1,'0.00',61,1,'1234-5678-9012',NULL,NULL,1,'2026-11-25 21:50:04',NULL),
(5,'Metro Property Leasing','Metro Property Leasing','Tony Chua','(054) 473-0303',NULL,'leasing@metroprop.test','Naga City','343-940-611-000',1,'0.00',60,1,'L-2291',NULL,NULL,1,'2026-11-25 21:50:04',NULL),
(6,'Diversion Road Fuel Station','Diversion Road Fuel Station',NULL,'(054) 473-0404',NULL,NULL,'Naga City','595-959-997-000',1,'0.00',64,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL),
(7,'Coolwave Refrigeration Services','Coolwave Refrigeration Services','Operations','(054) 473-0505',NULL,'service@coolwave.test','Naga City','633-248-156-000',2,'0.00',62,1,'CRS-7781','2',NULL,1,'2026-11-25 21:50:04',NULL),
(8,'Accounting Partners & Co.','Accounting Partners & Co.','Atty. Reyes','(054) 473-0606',NULL,'hello@apco.test','Naga City','657-425-749-000',3,'0.00',66,1,NULL,'2',NULL,1,'2026-11-25 21:50:04',NULL),
(9,'Bicol Truck and Reefer Corp.','Bicol Truck and Reefer Corp.','Sales','(054) 473-0707',NULL,'sales@bicoltruck.test','Legazpi City','983-568-526-000',3,'0.00',NULL,1,'BTR-100','1',NULL,1,'2026-11-25 21:50:04',NULL);

-- entity_notes (2 rows)
INSERT INTO `entity_notes` (`id`,`entity_type`,`entity_id`,`note`,`is_todo`,`due_date`,`is_done`,`created_by`,`created_at`) VALUES
(1,'customer',11,'Collect the crate deposit and the overdue balance on the next delivery',1,'2026-11-27',0,1,'2026-11-25 21:50:05'),
(2,'vendor',1,'Ask for a better price on whole chicken for the holiday volume',1,'2026-12-05',0,1,'2026-11-25 21:50:05');

-- sites (7 rows)
INSERT INTO `sites` (`id`,`code`,`name`,`site_type`,`address`,`sales_rep_id`,`is_active`) VALUES
(1,'NGA','Naga Cold Storage','warehouse',NULL,NULL,1),
(2,'NOT','Naga Outlet','store',NULL,5,1),
(3,'LGZ','Legazpi Depot','store',NULL,NULL,1),
(4,'RFT1','Reefer Truck 1','van',NULL,NULL,1),
(5,'DMG','Spoilage and Damaged','damaged',NULL,NULL,1),
(6,'VAN1','Van Store 1 (LAB 4417)','van',NULL,3,1),
(7,'VAN2','Van Store 2 (LAB 4428)','van',NULL,4,1);

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
(1,'Kilos and crates','weight','kg',1,'2026-11-25 21:50:03',NULL),
(2,'Packs and crates','count','pack',1,'2026-11-25 21:50:03',NULL),
(3,'Kilos','weight','kg',1,'2026-11-25 21:50:03',NULL),
(4,'Piece','count','pc',1,'2026-11-25 21:50:03',NULL),
(5,'Volume (L)','volume','L',1,'2026-11-25 21:50:03',NULL),
(6,'Time (hour)','time','hr',1,'2026-11-25 21:50:03',NULL);

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

-- items (24 rows)
INSERT INTO `items` (`id`,`item_type`,`code`,`barcode`,`name`,`description`,`purchase_description`,`category_id`,`unit`,`uom_set_id`,`sales_uom_id`,`purchase_uom_id`,`cost`,`avg_cost`,`sales_price`,`discount_pct`,`income_account_id`,`cogs_account_id`,`asset_account_id`,`expense_account_id`,`tax_code_id`,`group_variance_account_id`,`preferred_vendor_id`,`reorder_point`,`max_stock`,`track_expiry`,`build_point`,`is_active`,`fb_pos`,`fb_group_id`,`fb_sort`,`image_file`,`created_at`,`updated_at`) VALUES
(1,'inventory','WCK-FC','4809001000011','Whole Chicken, Fresh Chilled, Bag','Whole Chicken, Fresh Chilled, Bag','Whole Chicken, Fresh Chilled, Bag',1,'kg',1,NULL,NULL,'142.0000','141.7566','175.0000','0.00',45,55,14,NULL,1,NULL,1,'300.0000','1500.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(2,'inventory','BBD-FC','4809001000028','Big Bird Chicken, Fresh Chilled, Vac','Big Bird Chicken, Fresh Chilled, Vac','Big Bird Chicken, Fresh Chilled, Vac',1,'kg',1,NULL,NULL,'150.0000','150.0000','185.0000','0.00',45,55,14,NULL,1,NULL,1,'200.0000','1000.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(3,'inventory','ACU-FZ','4809001000035','Chicken Assorted Cut-Ups, Frozen, Bag','Chicken Assorted Cut-Ups, Frozen, Bag','Chicken Assorted Cut-Ups, Frozen, Bag',2,'kg',1,NULL,NULL,'135.0000','134.9355','168.0000','0.00',45,55,14,NULL,1,NULL,1,'200.0000','1000.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(4,'inventory','BRS-FZ','4809001000042','Chicken Breast, Frozen, Bag','Chicken Breast, Frozen, Bag','Chicken Breast, Frozen, Bag',2,'kg',1,NULL,NULL,'185.0000','184.8142','228.0000','0.00',45,55,14,NULL,1,NULL,1,'150.0000','800.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(5,'inventory','DRM-FZ','4809001000059','Chicken Drumstick, Frozen, Bag','Chicken Drumstick, Frozen, Bag','Chicken Drumstick, Frozen, Bag',2,'kg',1,NULL,NULL,'175.0000','174.8564','215.0000','0.00',45,55,14,NULL,1,NULL,2,'150.0000','800.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(6,'inventory','WNG-FZ','4809001000066','Chicken Wings, Frozen, Bag','Chicken Wings, Frozen, Bag','Chicken Wings, Frozen, Bag',2,'kg',1,NULL,NULL,'190.0000','188.6945','235.0000','0.00',45,55,14,NULL,1,NULL,2,'100.0000','600.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(7,'inventory','LVR-FZ','4809001000073','Chicken Liver, Frozen, Bag','Chicken Liver, Frozen, Bag','Chicken Liver, Frozen, Bag',3,'kg',1,NULL,NULL,'95.0000','95.0000','130.0000','0.00',45,55,14,NULL,1,NULL,1,'50.0000','300.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(8,'inventory','GIZ-FZ','4809001000080','Chicken Gizzard, Frozen, Bag','Chicken Gizzard, Frozen, Bag','Chicken Gizzard, Frozen, Bag',3,'kg',1,NULL,NULL,'110.0000','110.0000','145.0000','0.00',45,55,14,NULL,1,NULL,2,'50.0000','300.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(9,'inventory','BLD','4809001000097','Chicken Blood','Chicken blood, chilled','Chicken blood',3,'kg',3,NULL,NULL,'25.0000','25.0000','40.0000','0.00',45,55,14,NULL,3,NULL,1,'20.0000','150.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(10,'inventory','BLB-250','4809001000103','Chicken Bola-Bola 250 g, Frozen, Pack','Chicken Bola-Bola 250 g, Frozen, Pack','Chicken Bola-Bola 250 g, Frozen, Pack',4,'pack',2,NULL,NULL,'48.0000','48.0000','65.0000','0.00',45,55,14,NULL,1,NULL,2,'200.0000','1200.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(11,'inventory','NGT-500','4809001000110','Chicken Nuggets 500 g, Frozen, Pack','Chicken Nuggets 500 g, Frozen, Pack','Chicken Nuggets 500 g, Frozen, Pack',4,'pack',2,NULL,NULL,'95.0000','95.0000','128.0000','0.00',45,55,14,NULL,1,NULL,2,'120.0000','800.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(12,'inventory','PKG-BAG','4809001000127','Vacuum Bag 2 kg','Vacuum bag, 2 kg','Vacuum bag 2 kg',6,'pc',4,NULL,NULL,'3.5000','3.3000','0.0000','0.00',45,55,14,NULL,1,NULL,3,'500.0000','5000.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(13,'service','LAB-CUT',NULL,'Cutting and Packing Labor','Cutting and packing labor',NULL,7,'hr',6,NULL,NULL,'25.0000','0.0000','0.0000','0.00',46,58,NULL,58,4,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(14,'assembly','PARTY-PK','4809001000134','Party Pack (2 kg wings, 1 kg drumsticks)','Party pack: 2 kg wings and 1 kg drumsticks, vacuum packed',NULL,5,'pc',4,NULL,NULL,'0.0000','565.0943','720.0000','0.00',45,55,14,NULL,1,NULL,NULL,'5.0000','40.0000',1,'5.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(15,'service','SRV-CUT',NULL,'Custom Cutting Service','Custom cutting per customer specification',NULL,7,'kg',3,NULL,NULL,'0.0000','0.0000','15.0000','0.00',46,55,NULL,NULL,1,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(16,'non_inventory','NI-ICE',NULL,'Ice Block (special order)','Ice block, special order for long trips',NULL,6,'pc',4,NULL,NULL,'60.0000','0.0000','90.0000','0.00',45,55,NULL,55,1,NULL,3,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(17,'other_charge','DEL-FEE',NULL,'Delivery Fee (reefer)','Delivery fee, refrigerated truck',NULL,8,'pc',NULL,NULL,NULL,'0.0000','0.0000','350.0000','0.00',47,55,NULL,69,1,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(18,'other_charge','CRATE-DEP',NULL,'Crate Deposit','Deposit on crates not yet returned',NULL,8,'pc',NULL,NULL,NULL,'0.0000','0.0000','250.0000','0.00',38,55,NULL,72,4,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(19,'other_charge','LATE-FEE',NULL,'Late Payment Fee','Late payment fee',NULL,8,'pc',NULL,NULL,NULL,'0.0000','0.0000','200.0000','0.00',52,55,NULL,NULL,4,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(20,'discount','DISC-5',NULL,'5% Volume Discount','5% volume discount',NULL,8,'pc',NULL,NULL,NULL,'0.0000','0.0000','0.0000','5.00',49,55,NULL,NULL,1,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(21,'discount','DISC-AMT',NULL,'Fixed Discount','Discount',NULL,8,'pc',NULL,NULL,NULL,'0.0000','0.0000','100.0000','0.00',49,55,NULL,NULL,1,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(22,'subtotal','SUBTOTAL',NULL,'Subtotal','Subtotal',NULL,NULL,'pc',NULL,NULL,NULL,'0.0000','0.0000','0.0000','0.00',45,55,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(23,'group','GRP-FIESTA',NULL,'Fiesta Bundle','4 packs bola-bola and 2 packs nuggets',NULL,5,'pc',NULL,NULL,NULL,'0.0000','0.0000','480.0000','0.00',45,55,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL),
(24,'payment','DOWNPMT',NULL,'Down Payment Received','Less: down payment received',NULL,NULL,'pc',NULL,NULL,NULL,'0.0000','0.0000','0.0000','0.00',45,55,NULL,NULL,NULL,NULL,NULL,'0.0000','0.0000',1,'0.0000',1,0,NULL,0,NULL,'2026-11-25 21:50:04',NULL);

-- item_components (6 rows)
INSERT INTO `item_components` (`parent_item_id`,`component_item_id`,`qty`) VALUES
(14,5,'1.0000'),
(14,6,'2.0000'),
(14,12,'2.0000'),
(14,13,'0.2500'),
(23,10,'4.0000'),
(23,11,'2.0000');

-- process_formulas (1 rows)
INSERT INTO `process_formulas` (`id`,`code`,`name`,`process_type`,`alloc_method`,`site_id`,`description`,`is_active`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'CUT-WCK','Cut up whole chicken (10 kg)','disassembly','sales_value',NULL,'Whole chickens cut into breasts, drumsticks, wings and assorted cut-ups; liver and gizzard bagged on their own.',1,NULL,'2026-11-25 21:50:04',NULL);

-- process_formula_lines (8 rows)
INSERT INTO `process_formula_lines` (`id`,`formula_id`,`line_no`,`line_type`,`item_id`,`account_id`,`description`,`qty`,`output_role`,`alloc_basis`,`amount`) VALUES
(1,1,1,'input',1,NULL,NULL,'10.0000',NULL,'0.0000','0.00'),
(2,1,2,'cost',NULL,58,'Cutting and packing labor','0.0000',NULL,'0.0000','120.00'),
(3,1,3,'output',4,NULL,NULL,'2.6000','co_product','0.0000','0.00'),
(4,1,4,'output',5,NULL,NULL,'2.2000','co_product','0.0000','0.00'),
(5,1,5,'output',6,NULL,NULL,'1.1000','co_product','0.0000','0.00'),
(6,1,6,'output',3,NULL,NULL,'3.0000','co_product','0.0000','0.00'),
(7,1,7,'output',7,NULL,NULL,'0.4000','by_product','95.0000','0.00'),
(8,1,8,'output',8,NULL,NULL,'0.4000','by_product','110.0000','0.00');

-- price_level_items (2 rows)
INSERT INTO `price_level_items` (`price_level_id`,`item_id`,`custom_price`) VALUES
(2,1,'165.0000'),
(2,4,'215.0000');

-- item_site_stock (38 rows)
INSERT INTO `item_site_stock` (`item_id`,`site_id`,`qty_on_hand`) VALUES
(1,1,'88.1200'),
(1,2,'0.0000'),
(1,3,'60.2800'),
(1,6,'14.8200'),
(1,7,'0.0000'),
(2,1,'72.8600'),
(2,2,'0.0000'),
(2,6,'0.0000'),
(3,1,'197.2600'),
(3,2,'24.5600'),
(4,1,'103.0800'),
(4,2,'14.9000'),
(4,3,'22.2100'),
(4,7,'0.0000'),
(5,1,'97.0000'),
(5,2,'30.3700'),
(5,3,'66.5300'),
(5,6,'15.1400'),
(6,1,'86.6700'),
(6,2,'12.2500'),
(7,1,'60.7100'),
(7,2,'18.7400'),
(8,1,'29.0900'),
(8,3,'17.0000'),
(9,1,'87.2500'),
(9,2,'11.0000'),
(9,6,'4.0000'),
(10,1,'274.0000'),
(10,2,'73.0000'),
(10,3,'40.0000'),
(10,6,'0.0000'),
(11,1,'48.0000'),
(11,2,'21.0000'),
(11,3,'73.0000'),
(12,1,'1784.0000'),
(12,2,'250.0000'),
(14,1,'5.0000'),
(14,2,'2.0000');

-- transactions (112 rows)
INSERT INTO `transactions` (`id`,`txn_type`,`txn_no`,`txn_date`,`due_date`,`ship_date`,`ref_no`,`customer_id`,`vendor_id`,`payee_name`,`account_id`,`account2_id`,`site_id`,`site2_id`,`terms_id`,`sales_rep_id`,`payment_method_id`,`billing_address`,`shipping_address`,`memo`,`customer_message`,`subtotal`,`tax_total`,`discount_amount`,`withholding_amount`,`cash_back_amount`,`total`,`status`,`is_pending`,`is_voided`,`void_reason`,`voided_by`,`voided_at`,`to_be_printed`,`is_printed`,`restock`,`credit_disposition`,`progress_pct`,`source_txn_id`,`terminal_id`,`pos_shift_id`,`receipt_no`,`amount_tendered`,`change_given`,`approved_by`,`batch_ref`,`process_type`,`alloc_method`,`process_formula_id`,`process_batches`,`class_id`,`other_name_id`,`received_via`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES
(1,'opening_balance','OB-0001','2026-09-06',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Opening balances',NULL,'0.00','0.00','0.00','0.00','0.00','4125000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(2,'check','1001','2026-09-01',NULL,NULL,NULL,NULL,7,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Purchase of Blast Freezer and Cold Room (20 tons)',NULL,'1850000.00','0.00','0.00','0.00','0.00','1850000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(3,'bill','BILL-00001','2026-09-01','2026-10-01',NULL,'BTR-5521',NULL,9,NULL,32,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Purchase of Reefer Truck 1 (6-wheeler, -18 C)',NULL,'2450000.00','0.00','0.00','0.00','0.00','2450000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(4,'check','1002','2026-09-01',NULL,NULL,NULL,NULL,9,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Purchase of POS Terminal Set (Naga Outlet)',NULL,'65000.00','0.00','0.00','0.00','0.00','65000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(5,'bill','BILL-00002','2026-09-01','2026-10-01',NULL,'CRS-5530',NULL,7,NULL,32,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Purchase of Platform Scale 300 kg (receiving)',NULL,'85000.00','0.00','0.00','0.00','0.00','85000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(6,'bill','BILL-00003','2026-11-05','2026-11-20',NULL,'CRS-SV-0192',NULL,7,NULL,32,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,'Repair of FA-00002 Reefer Truck 1 (6-wheeler, -18 C) (MNT-00001)',NULL,'17000.00','0.00','0.00','0.00','0.00','17000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(7,'bill','BILL-00004','2026-09-12','2026-09-27',NULL,'NPC-INV-10231',NULL,1,NULL,32,NULL,1,NULL,2,NULL,NULL,NULL,NULL,'Opening stock, received in crates',NULL,'53165.38','6379.84','0.00','0.00','0.00','59545.22','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'bill',1,'2026-11-25 21:50:04',NULL,'2026-11-25 21:50:05'),
(8,'bill','BILL-00005','2026-09-20','2026-10-20',NULL,'GPF-INV-10288',NULL,2,NULL,32,NULL,1,NULL,3,NULL,NULL,NULL,NULL,'Bill for received items',NULL,'59056.61','7086.80','0.00','0.00','0.00','66143.41','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'receipt',1,'2026-11-25 21:50:04',1,'2026-11-25 21:50:04'),
(9,'bill','BILL-00006','2026-09-16','2026-10-01',NULL,'BPS-99812',NULL,3,NULL,32,NULL,1,NULL,2,NULL,NULL,NULL,NULL,'Vacuum bags',NULL,'6600.00','792.00','0.00','0.00','0.00','7392.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(10,'item_receipt','IR-00002','2026-09-26',NULL,NULL,'Pick-up AL-00001',NULL,1,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00001)',NULL,'39395.62','0.00','0.00','0.00','0.00','39395.62','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(11,'item_receipt','IR-00003','2026-10-04',NULL,NULL,'Pick-up AL-00002',NULL,2,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00002)',NULL,'32776.00','0.00','0.00','0.00','0.00','32776.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(12,'item_receipt','IR-00004','2026-10-11',NULL,NULL,'Pick-up AL-00003',NULL,1,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00003)',NULL,'37957.44','0.00','0.00','0.00','0.00','37957.44','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(13,'item_receipt','IR-00005','2026-10-26',NULL,NULL,'Pick-up AL-00004',NULL,1,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00004)',NULL,'39660.04','0.00','0.00','0.00','0.00','39660.04','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(14,'item_receipt','IR-00006','2026-11-04',NULL,NULL,'Pick-up AL-00005',NULL,2,NULL,32,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00005)',NULL,'32971.80','0.00','0.00','0.00','0.00','32971.80','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(15,'item_receipt','IR-00007','2026-11-16',NULL,NULL,'Pick-up AL-00006',NULL,1,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00006)',NULL,'37817.08','0.00','0.00','0.00','0.00','37817.08','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(16,'item_receipt','IR-00008','2026-11-23',NULL,NULL,'Pick-up AL-00007',NULL,1,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Picked up by Glenn Abad (AL-00007)',NULL,'28074.58','0.00','0.00','0.00','0.00','28074.58','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,'pickup',10,'2026-11-25 21:50:04',NULL,NULL),
(17,'inventory_transfer','IT-00001','2026-09-22',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Stock for the Naga Outlet',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(18,'inventory_transfer','IT-00002','2026-09-23',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,3,NULL,NULL,NULL,NULL,NULL,'Stock for the Legazpi Depot',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(19,'inventory_transfer','IT-00003','2026-10-27',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Weekend stock for the outlet',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(20,'inventory_transfer','IT-00004','2026-11-17',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Stock for the outlet',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(21,'inventory_transfer','IT-00005','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Stock for the outlet',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(22,'inventory_transfer','IT-00006','2026-10-26',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Blood and vacuum bags for the outlet',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(23,'item_processing','PRC-00001','2026-09-30',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Cut-ups for the restaurant orders',NULL,'4260.00','0.00','0.00','0.00','0.00','4620.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'disassembly','sales_value',1,'3.0000',NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(24,'item_processing','PRC-00002','2026-10-30',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Cut-ups; a little more breast than planned',NULL,'2840.00','0.00','0.00','0.00','0.00','3080.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'disassembly','sales_value',1,'2.0000',NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(25,'item_processing','PRC-00003','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Waiting for the cutting crew',NULL,'2835.29','0.00','0.00','0.00','0.00','3075.29','pending',1,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,'disassembly','sales_value',1,'2.0000',NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(26,'build_assembly','BLD-00001','2026-10-16',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Party packs for the weekend',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(27,'inventory_transfer','IT-00007','2026-10-17',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,2,NULL,NULL,NULL,NULL,NULL,'Party packs for the outlet',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(28,'build_assembly','BLD-00002','2026-11-22',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Waiting for wings',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','pending',1,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(29,'estimate','EST-00001','2026-09-28','2026-10-28',NULL,NULL,6,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL,'Weekly supply for both branches',NULL,'30175.00','3621.00','0.00','0.00','0.00','33796.00','accepted',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(30,'sales_order','SO-00001','2026-09-29',NULL,'2026-10-06','SUN-PO-7781',6,NULL,NULL,NULL,NULL,1,NULL,NULL,1,NULL,'Magsaysay Avenue, Naga City',NULL,NULL,NULL,'30175.00','3621.00','0.00','0.00','0.00','33796.00','partial',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL,'2026-11-25 21:50:04'),
(31,'invoice','INV-00001','2026-10-01','2026-10-31',NULL,'SUN-PO-7781',6,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'Magsaysay Avenue, Naga City','Magsaysay Avenue, Naga City',NULL,'Thank you for your business.','15094.45','1811.34','0.00','0.00','0.00','16905.79','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,'2026-11-25 21:50:05'),
(32,'invoice','INV-00002','2026-10-08','2026-11-07',NULL,'SUN-PO-7781',6,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'Magsaysay Avenue, Naga City','Magsaysay Avenue, Naga City',NULL,'Thank you for your business.','8524.10','1022.89','0.00','0.00','0.00','9546.99','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(33,'invoice','INV-00003','2026-10-12','2026-11-11',NULL,NULL,7,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'Maharlika Highway, Pili, Camarines Sur','Maharlika Highway, Pili, Camarines Sur',NULL,'Thank you for your business.','13132.70','1575.92','0.00','0.00','0.00','14708.62','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(34,'invoice','INV-00004','2026-10-06','2026-10-21',NULL,NULL,8,NULL,NULL,11,NULL,1,NULL,2,2,NULL,'Elias Angeles St., Naga City',NULL,NULL,'Thank you for your business.','6190.00','714.00','0.00','0.00','0.00','6904.00','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,'2026-11-25 21:50:05'),
(35,'invoice','INV-00005','2026-10-20','2026-11-04',NULL,NULL,8,NULL,NULL,11,NULL,1,NULL,2,2,NULL,'Elias Angeles St., Naga City',NULL,NULL,'Thank you for your business.','4640.00','556.80','0.00','0.00','0.00','5196.80','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(36,'invoice','INV-00006','2026-10-14','2026-11-13',NULL,NULL,9,NULL,NULL,11,NULL,3,NULL,4,2,NULL,'Rizal St., Legazpi City',NULL,NULL,'Thank you for your business.','7217.65','866.12','0.00','0.00','0.00','8083.77','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,3,NULL,NULL,1,'2026-11-25 21:50:04',NULL,'2026-11-25 21:50:05'),
(37,'invoice','INV-00007','2026-11-07','2026-12-07',NULL,NULL,9,NULL,NULL,11,NULL,3,NULL,4,2,NULL,'Rizal St., Legazpi City',NULL,NULL,'Thank you for your business.','11001.50','1320.18','0.00','0.00','0.00','12321.68','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,3,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(38,'invoice','INV-00008','2026-10-16','2026-10-31',NULL,NULL,10,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'Panganiban Drive, Naga City',NULL,NULL,'Thank you for your business.','7080.00','849.60','0.00','0.00','0.00','7929.60','partial',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,'2026-11-25 21:50:05'),
(39,'invoice','INV-00009','2026-10-23','2026-11-07',NULL,NULL,10,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'Panganiban Drive, Naga City',NULL,'Weekly hospital kitchen delivery','Thank you for your business.','5436.00','652.32','0.00','0.00','0.00','6088.32','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202610230900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:04',NULL,NULL),
(40,'invoice','INV-00010','2026-10-23','2026-11-07',NULL,NULL,11,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'Naga City Public Market, Stall 42',NULL,'Weekly market stall delivery','Thank you for your business.','3208.80','385.06','0.00','0.00','0.00','3593.86','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202610230900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(41,'invoice','INV-00011','2026-11-13','2026-11-28',NULL,NULL,10,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'Panganiban Drive, Naga City',NULL,'Weekly hospital kitchen delivery','Thank you for your business.','5436.00','652.32','0.00','0.00','0.00','6088.32','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202611130900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(42,'invoice','INV-00012','2026-11-13','2026-11-28',NULL,NULL,11,NULL,NULL,11,NULL,1,NULL,2,1,NULL,'Naga City Public Market, Stall 42',NULL,'Weekly market stall delivery','Thank you for your business.','4090.80','490.90','0.00','0.00','0.00','4581.70','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,'B202611130900',NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(43,'invoice','INV-00013','2026-10-31','2026-11-30',NULL,NULL,6,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'Magsaysay Avenue, Naga City','Magsaysay Avenue, Naga City',NULL,'Thank you for your business.','23309.55','2797.15','0.00','0.00','0.00','26106.70','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(44,'invoice','INV-00014','2026-11-19','2026-12-19',NULL,NULL,6,NULL,NULL,11,NULL,1,NULL,3,1,NULL,'Magsaysay Avenue, Naga City','Magsaysay Avenue, Naga City',NULL,'Thank you for your business.','10720.20','1286.42','0.00','0.00','0.00','12006.62','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(45,'invoice','INV-00015','2026-11-21','2026-12-06',NULL,NULL,8,NULL,NULL,11,NULL,1,NULL,2,2,NULL,'Elias Angeles St., Naga City',NULL,NULL,'Thank you for your business.','4810.00','577.20','0.00','0.00','0.00','5387.20','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(46,'invoice','INV-00016','2026-11-23','2026-12-23',NULL,NULL,9,NULL,NULL,11,NULL,3,NULL,4,2,NULL,'Rizal St., Legazpi City',NULL,'Awaiting PO approval','Thank you for your business.','2603.50','252.42','0.00','0.00','0.00','2855.92','pending',1,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,3,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(47,'sales_receipt','SR-00001','2026-10-17',NULL,NULL,NULL,13,NULL,NULL,7,NULL,1,NULL,NULL,NULL,1,NULL,NULL,'Phone order',NULL,'1490.00','169.20','0.00','0.00','0.00','1659.20','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(48,'payment','PMT-00001','2026-10-28',NULL,NULL,'BDO-004412',6,NULL,NULL,7,11,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,'0.00','0.00','0.00','0.00','0.00','60000.00','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(49,'payment','PMT-00002','2026-10-22',NULL,NULL,'IB-88123',9,NULL,NULL,5,11,NULL,NULL,NULL,NULL,6,NULL,NULL,NULL,NULL,'0.00','0.00','161.68','0.00','0.00','7922.09','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(50,'payment','PMT-00003','2026-10-19',NULL,NULL,'MBTC-1120',8,NULL,NULL,7,11,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,'0.00','0.00','0.00','0.00','0.00','7404.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(51,'payment','PMT-00004','2026-10-30',NULL,NULL,NULL,10,NULL,NULL,7,11,NULL,NULL,NULL,NULL,4,NULL,NULL,NULL,NULL,'0.00','0.00','0.00','0.00','0.00','3964.80','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(52,'invoice','INV-00017','2026-10-22','2026-11-21',NULL,NULL,12,NULL,NULL,11,NULL,1,NULL,3,NULL,NULL,'Municipal Hall, San Isidro, Camarines Sur',NULL,'Feeding program, barangay day care centers','Thank you for your business.','4842.25','581.07','0.00','0.00','0.00','5423.32','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(53,'payment','PMT-00005','2026-11-13',NULL,NULL,'LBP-205511',12,NULL,NULL,7,11,NULL,NULL,NULL,NULL,2,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',NULL,'0.00','0.00','0.00','290.53','0.00','5132.79','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(54,'credit_memo','CM-00001','2026-10-09',NULL,NULL,NULL,8,NULL,NULL,11,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Returned 3 kg liver, not frozen on arrival',NULL,'390.00','46.80','0.00','0.00','0.00','436.80','open',0,0,NULL,NULL,NULL,0,0,0,'keep',NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(55,'statement_charge','SC-00001','2026-11-10','2026-11-10',NULL,NULL,11,NULL,NULL,11,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Late payment fee',NULL,'200.00','0.00','0.00','0.00','0.00','200.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(56,'finance_charge','FC-00001','2026-11-24','2026-11-24',NULL,NULL,11,NULL,NULL,11,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Finance charge on overdue balance',NULL,'86.40','0.00','0.00','0.00','0.00','86.40','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(57,'check','1003','2026-09-12',NULL,NULL,NULL,NULL,5,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Cold storage and outlet rent',NULL,'95000.00','11400.00','0.00','0.00','0.00','106400.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(58,'check','1004','2026-10-12',NULL,NULL,NULL,NULL,5,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Cold storage and outlet rent',NULL,'95000.00','11400.00','0.00','0.00','0.00','106400.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(59,'check','1005','2026-11-11',NULL,NULL,NULL,NULL,5,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Cold storage and outlet rent',NULL,'95000.00','11400.00','0.00','0.00','0.00','106400.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(60,'bill','BILL-00007','2026-09-26','2026-10-06',NULL,'CPC-202609',NULL,4,NULL,32,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'86450.75','10374.09','0.00','0.00','0.00','96824.84','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(61,'bill','BILL-00008','2026-10-26','2026-11-05',NULL,'CPC-202610',NULL,4,NULL,32,NULL,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'92230.40','11067.65','0.00','0.00','0.00','103298.05','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(62,'bill','BILL-00009','2026-10-01','2026-10-31',NULL,'APC-2231',NULL,8,NULL,32,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,'Quarterly bookkeeping review',NULL,'45000.00','5400.00','0.00','0.00','0.00','50400.00','paid',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(63,'check','1006','2026-09-25',NULL,NULL,NULL,NULL,6,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Diesel for the reefer truck',NULL,'6800.00','816.00','0.00','0.00','0.00','7616.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(64,'check','1007','2026-10-23',NULL,NULL,NULL,NULL,6,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Diesel for the reefer truck',NULL,'6800.00','816.00','0.00','0.00','0.00','7616.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(65,'check','1008','2026-11-20',NULL,NULL,NULL,NULL,6,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Diesel for the reefer truck',NULL,'6800.00','816.00','0.00','0.00','0.00','7616.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(66,'vendor_credit','DM-00001','2026-09-29',NULL,NULL,'NPC-CM-331',NULL,1,NULL,32,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Returned 12 kg whole chicken, warm on arrival',NULL,'1704.00','204.48','0.00','0.00','0.00','1908.48','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(67,'bill_payment','1009','2026-10-04',NULL,NULL,NULL,NULL,1,NULL,5,32,NULL,NULL,NULL,NULL,2,NULL,NULL,'Payment of NPC-INV-10231',NULL,'0.00','0.00','0.00','0.00','0.00','57636.74','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(68,'bill_payment','1010','2026-10-04',NULL,NULL,'IB-77100',NULL,4,NULL,5,32,NULL,NULL,NULL,NULL,6,NULL,NULL,'Electricity',NULL,'0.00','0.00','0.00','0.00','0.00','96824.84','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(69,'bill_payment','1011','2026-11-05',NULL,NULL,NULL,NULL,8,NULL,5,32,NULL,NULL,NULL,NULL,2,NULL,NULL,'Payment of APC-2231, 2% withheld',NULL,'0.00','0.00','0.00','900.00','0.00','49500.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(70,'vendor_advance','ADV-00001','2026-11-11','2026-12-15',NULL,'1188',NULL,2,NULL,5,19,NULL,NULL,NULL,NULL,2,NULL,NULL,'Advance on the holiday season allocation',NULL,'150000.00','0.00','0.00','0.00','0.00','150000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(71,'check','1012','2026-11-15',NULL,NULL,NULL,NULL,NULL,'Office Snacks Co.',5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Pantry supplies',NULL,'2500.00','0.00','0.00','0.00','0.00','2500.00','void',0,1,'Check printed with wrong payee',1,'2026-11-25 21:50:05',0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(73,'inventory_adjustment','ADJ-00001','2026-11-01',NULL,NULL,NULL,NULL,NULL,NULL,57,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Spoilage - freezer door left open',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(74,'inventory_adjustment','ADJ-00002','2026-11-17',NULL,NULL,NULL,NULL,NULL,NULL,57,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Physical count by D. Villanueva',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(75,'transfer','TRF-00001','2026-10-11',NULL,NULL,NULL,NULL,NULL,NULL,5,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Replenish petty cash',NULL,'0.00','0.00','0.00','0.00','0.00','15000.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(76,'cash_voucher','CAV-00001','2026-10-26',NULL,NULL,NULL,NULL,NULL,NULL,3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Toll and parking, pick-ups at Pili',NULL,'1250.00','0.00','0.00','0.00','0.00','1250.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,1,1,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(77,'cash_voucher','CAV-00002','2026-11-13',NULL,NULL,NULL,NULL,NULL,'Tricycle fares',3,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Small deliveries, Naga Outlet',NULL,'480.00','0.00','0.00','0.00','0.00','480.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(78,'deposit','DEP-00001','2026-11-01',NULL,NULL,'DS-1001',NULL,NULL,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Deposit',NULL,'74278.00','0.00','0.00','0.00','0.00','74278.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(79,'depreciation','JE-00001','2026-09-30',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation for September 2026',NULL,'0.00','0.00','0.00','0.00','0.00','99821.67','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(80,'depreciation','JE-00002','2026-10-31',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation for October 2026',NULL,'0.00','0.00','0.00','0.00','0.00','99955.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(81,'bank_charge','JE-00003','2026-09-30',NULL,NULL,NULL,NULL,NULL,NULL,5,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Bank service charge',NULL,'0.00','0.00','0.00','0.00','0.00','150.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(82,'pos_sale','POS-000001','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'725.00','87.00','0.00','0.00','0.00','812.00','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'NO1-00000001','1000.00','188.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-24 07:12:00',9,'2026-11-25 21:50:05'),
(83,'pos_sale','POS-000002','2026-11-24',NULL,NULL,NULL,11,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'1533.40','184.01','0.00','0.00','0.00','1717.41','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'NO1-00000002','1717.41','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-24 08:35:00',9,'2026-11-25 21:50:05'),
(84,'pos_sale','POS-000003','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'284.00','34.08','0.00','0.00','0.00','318.08','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'NO1-00000003','318.08','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-24 09:58:00',9,'2026-11-25 21:50:05'),
(85,'pos_sale','POS-000004','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'851.00','102.12','0.00','0.00','0.00','953.12','void',0,1,'Customer changed mind before leaving the counter',8,'2026-11-25 21:50:05',0,0,1,NULL,NULL,NULL,1,1,'NO1-00000004','1000.00','46.88',8,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-24 11:21:00',9,'2026-11-25 21:50:05'),
(86,'pos_sale','POS-000005','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'1056.00','126.72','0.00','0.00','0.00','1182.72','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,'NO1-00000005','1500.00','317.28',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-24 12:44:00',9,'2026-11-25 21:50:05'),
(87,'pos_return','POS-000006','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Return: pack thawed',NULL,'65.00','7.80','0.00','0.00','0.00','72.80','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,82,1,1,'NO1-00000006','0.00','0.00',8,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8,'2026-11-24 14:07:00',8,'2026-11-25 21:50:05'),
(88,'pos_over_short','JE-00004','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Cash short - Naga Outlet Counter 1',NULL,'0.00','0.00','0.00','0.00','0.00','20.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,1,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8,'2026-11-24 15:30:00',NULL,NULL),
(89,'pos_sale','POS-000007','2026-11-25',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'530.00','58.80','0.00','0.00','0.00','588.80','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,2,'NO1-00000007','1000.00','411.20',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-25 21:50:05',9,'2026-11-25 21:50:05'),
(90,'pos_sale','POS-000008','2026-11-25',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'480.00','57.60','0.00','0.00','0.00','537.60','completed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,1,2,'NO1-00000008','537.60','0.00',NULL,NULL,NULL,NULL,NULL,NULL,2,NULL,NULL,9,'2026-11-25 21:50:05',9,'2026-11-25 21:50:05'),
(91,'inventory_adjustment','ADJ-00003','2026-11-11',NULL,NULL,NULL,NULL,NULL,NULL,57,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Expired fresh chilled stock condemned (city meat inspector present)',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(92,'inventory_adjustment','ADJ-00004','2026-11-11',NULL,NULL,NULL,NULL,NULL,NULL,57,NULL,2,NULL,NULL,NULL,NULL,NULL,NULL,'Expired fresh chilled stock condemned (city meat inspector present)',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(93,'inventory_transfer','IT-00008','2026-11-21',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,6,NULL,NULL,NULL,NULL,NULL,'Van Store 1 load-out (Rico Mendoza)',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(94,'inventory_transfer','IT-00009','2026-11-21',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,6,NULL,NULL,NULL,NULL,NULL,'Van Store 1 load-out: chicken blood',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(95,'sales_receipt','SR-00002','2026-11-21',NULL,NULL,NULL,11,NULL,NULL,7,NULL,6,NULL,NULL,3,1,NULL,NULL,'Van sale, Naga public market',NULL,'2973.55','356.83','0.00','0.00','0.00','3330.38','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(96,'sales_receipt','SR-00003','2026-11-21',NULL,NULL,NULL,14,NULL,NULL,7,NULL,6,NULL,NULL,3,1,NULL,NULL,'Van sale, Barangay Concepcion',NULL,'1030.00','114.00','0.00','0.00','0.00','1144.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(97,'inventory_adjustment','ADJ-00005','2026-11-21',NULL,NULL,'TC-00001',NULL,NULL,NULL,57,NULL,6,NULL,NULL,3,NULL,NULL,NULL,'Shrinkage - Inventory Transfer Closing TC-00001 - Evening closing, Naga route',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(98,'shortage_charge','SHC-00001','2026-11-21','2026-11-21',NULL,'TC-00001',3,NULL,NULL,12,NULL,6,NULL,NULL,3,NULL,NULL,NULL,'Shortage - Inventory Transfer Closing TC-00001 - Evening closing, Naga route',NULL,'108.50','0.00','0.00','0.00','0.00','108.50','partial',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(99,'inventory_transfer','IT-00010','2026-11-21',NULL,NULL,'TC-00001',NULL,NULL,NULL,NULL,NULL,6,1,NULL,NULL,NULL,NULL,NULL,'Inventory Transfer Closing TC-00001 - Evening closing, Naga route',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(100,'payment','PMT-00006','2026-11-22',NULL,NULL,NULL,3,NULL,NULL,7,11,NULL,NULL,NULL,NULL,1,NULL,NULL,'Shortage on TC-00001, first half',NULL,'0.00','0.00','0.00','0.00','0.00','54.25','closed',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,'2026-11-25 21:50:05'),
(101,'inventory_transfer','IT-00011','2026-11-22',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,7,NULL,NULL,NULL,NULL,NULL,'Van Store 2 load-out (Arnel Cruz)',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL);
INSERT INTO `transactions` (`id`,`txn_type`,`txn_no`,`txn_date`,`due_date`,`ship_date`,`ref_no`,`customer_id`,`vendor_id`,`payee_name`,`account_id`,`account2_id`,`site_id`,`site2_id`,`terms_id`,`sales_rep_id`,`payment_method_id`,`billing_address`,`shipping_address`,`memo`,`customer_message`,`subtotal`,`tax_total`,`discount_amount`,`withholding_amount`,`cash_back_amount`,`total`,`status`,`is_pending`,`is_voided`,`void_reason`,`voided_by`,`voided_at`,`to_be_printed`,`is_printed`,`restock`,`credit_disposition`,`progress_pct`,`source_txn_id`,`terminal_id`,`pos_shift_id`,`receipt_no`,`amount_tendered`,`change_given`,`approved_by`,`batch_ref`,`process_type`,`alloc_method`,`process_formula_id`,`process_batches`,`class_id`,`other_name_id`,`received_via`,`created_by`,`created_at`,`updated_by`,`updated_at`) VALUES
(102,'sales_receipt','SR-00004','2026-11-22',NULL,NULL,NULL,14,NULL,NULL,7,NULL,7,NULL,NULL,4,1,NULL,NULL,'Van sale, Pili town proper',NULL,'1560.00','187.20','0.00','0.00','0.00','1747.20','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(103,'inventory_adjustment','ADJ-00006','2026-11-22',NULL,NULL,'TC-00002',NULL,NULL,NULL,57,NULL,7,NULL,NULL,4,NULL,NULL,NULL,'Shrinkage - Inventory Transfer Closing TC-00002 - Evening closing, Pili route',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(104,'shortage_charge','SHC-00002','2026-11-22','2026-11-22',NULL,'TC-00002',4,NULL,NULL,12,NULL,7,NULL,NULL,4,NULL,NULL,NULL,'Shortage - Inventory Transfer Closing TC-00002 - Evening closing, Pili route',NULL,'1740.77','0.00','0.00','0.00','0.00','1740.77','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(105,'inventory_transfer','IT-00012','2026-11-22',NULL,NULL,'TC-00002',NULL,NULL,NULL,NULL,NULL,7,1,NULL,NULL,NULL,NULL,NULL,'Inventory Transfer Closing TC-00002 - Evening closing, Pili route',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(106,'inventory_transfer','IT-00013','2026-11-24',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,6,NULL,NULL,NULL,NULL,NULL,'Van Store 1 load-out (Rico Mendoza)',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(107,'sales_receipt','SR-00005','2026-11-24',NULL,NULL,NULL,14,NULL,NULL,7,NULL,6,NULL,NULL,3,1,NULL,NULL,'Van sale, Barangay Triangulo',NULL,'840.00','100.80','0.00','0.00','0.00','940.80','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(108,'inventory_adjustment','ADJ-00007','2026-11-24',NULL,NULL,'TC-00003',NULL,NULL,NULL,57,NULL,6,NULL,NULL,3,NULL,NULL,NULL,'Shrinkage - Inventory Transfer Closing TC-00003 - Evening closing, Naga route',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(109,'inventory_transfer','IT-00014','2026-11-24',NULL,NULL,'TC-00003',NULL,NULL,NULL,NULL,NULL,6,1,NULL,NULL,NULL,NULL,NULL,'Inventory Transfer Closing TC-00003 - Evening closing, Naga route',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5,'2026-11-25 21:50:05',NULL,NULL),
(110,'inventory_transfer','IT-00015','2026-11-25',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,6,NULL,NULL,NULL,NULL,NULL,'Van Store 1 load-out (Rico Mendoza)',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(111,'inventory_transfer','IT-00016','2026-11-25',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,6,NULL,NULL,NULL,NULL,NULL,'Van Store 1 load-out: chicken blood',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(112,'shortage_charge','SHC-00003','2026-11-23','2026-11-23',NULL,NULL,5,NULL,NULL,12,NULL,2,NULL,NULL,5,NULL,NULL,NULL,'Shortage - counter count',NULL,'269.87','0.00','0.00','0.00','0.00','269.87','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL),
(113,'inventory_adjustment','ADJ-00008','2026-11-23',NULL,NULL,NULL,NULL,NULL,NULL,57,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,'Shrinkage - weekly count',NULL,'0.00','0.00','0.00','0.00','0.00','0.00','open',0,0,NULL,NULL,NULL,0,0,1,NULL,NULL,NULL,NULL,NULL,NULL,'0.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:05',NULL,NULL);

-- transaction_lines (248 rows)
INSERT INTO `transaction_lines` (`id`,`txn_id`,`line_no`,`line_kind`,`item_id`,`account_id`,`description`,`qty`,`unit`,`uom_id`,`uom_factor`,`uom_qty`,`uom_rate`,`rate`,`discount_kind`,`discount_pct`,`discount_amount`,`amount`,`tax_code_id`,`tax_amount`,`site_id`,`production_date`,`expiry_date`,`customer_id`,`vendor_id`,`is_billable`,`billed_txn_id`,`ref_txn_id`,`pos_shift_id`,`source_line_id`,`qty_fulfilled`,`amount_fulfilled`,`is_closed`,`cost_amount`,`value_change`,`output_role`,`alloc_basis`,`alloc_pct`,`planned_qty`,`class_id`,`other_name_id`,`group_item_id`,`group_ref`,`group_qty`,`group_rate`,`group_role`,`crate_count`) VALUES
(1,1,1,'journal',NULL,5,'BDO checking opening balance','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','3200000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(2,1,2,'journal',NULL,6,'BPI savings opening balance','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','900000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(3,1,3,'journal',NULL,3,'Petty cash fund','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','15000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(4,1,4,'journal',NULL,2,'Register cash funds','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','10000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(5,1,5,'journal',NULL,41,'Owner\'s capital','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-4125000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(6,2,1,'expense',NULL,23,'Blast Freezer and Cold Room (20 tons)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1850000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(7,3,1,'expense',NULL,25,'Reefer Truck 1 (6-wheeler, -18 C)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2450000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(8,4,1,'expense',NULL,29,'POS Terminal Set (Naga Outlet)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','65000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(9,5,1,'expense',NULL,23,'Platform Scale 300 kg (receiving)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','85000.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(10,6,1,'expense',NULL,62,'Parts - MNT-00001 FA-00002 Reefer Truck 1 (6-wheeler, -18 C)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','14500.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(11,6,2,'expense',NULL,62,'Labor - MNT-00001 FA-00002 Reefer Truck 1 (6-wheeler, -18 C)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2500.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(12,7,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','148.7400','CRT',2,'12.395000','12.0000','142.0000','142.0000','pct','0.00','0.00','21121.08',1,'2534.53',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,12),
(13,7,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','89.8100','CRT',2,'14.968333','6.0000','185.0000','185.0000','pct','0.00','0.00','16614.85',1,'1993.78',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(14,7,3,'item',7,NULL,'Chicken Liver, Frozen, Bag','29.6500','CRT',2,'9.883333','3.0000','95.0000','95.0000','pct','0.00','0.00','2816.75',1,'338.01',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(15,7,4,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','86.0200','CRT',2,'14.336667','6.0000','135.0000','135.0000','pct','0.00','0.00','11612.70',1,'1393.52',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(16,7,5,'item',9,NULL,'Chicken Blood','40.0000','kg',NULL,'1.000000','40.0000','25.0000','25.0000','pct','0.00','0.00','1000.00',1,'120.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(17,8,1,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','122.8100','CRT',2,'15.351250','8.0000','175.0000','175.0000','pct','0.00','0.00','21491.75',1,'2579.01',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8),
(18,8,2,'item',6,NULL,'Chicken Wings, Frozen, Bag','72.4200','CRT',2,'12.070000','6.0000','188.0000','188.0000','pct','0.00','0.00','13614.96',1,'1633.80',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(19,8,3,'item',8,NULL,'Chicken Gizzard, Frozen, Bag','30.0900','CRT',2,'10.030000','3.0000','110.0000','110.0000','pct','0.00','0.00','3309.90',1,'397.19',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(20,8,4,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','240.0000','CRT',4,'40.000000','6.0000','48.0000','48.0000','pct','0.00','0.00','11520.00',1,'1382.40',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(21,8,5,'item',11,NULL,'Chicken Nuggets 500 g, Frozen, Pack','96.0000','CRT',4,'24.000000','4.0000','95.0000','95.0000','pct','0.00','0.00','9120.00',1,'1094.40',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(22,9,1,'item',12,NULL,'Vacuum Bag 2 kg','2000.0000','bundle',11,'100.000000','20.0000','330.0000','3.3000','pct','0.00','0.00','6600.00',1,'792.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(23,10,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','125.8600','CRT',2,'12.586000','10.0000','142.0000','142.0000','pct','0.00','0.00','17872.12',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10),
(24,10,2,'item',2,NULL,'Big Bird Chicken, Fresh Chilled, Vac','87.2400','CRT',2,'14.540000','6.0000','150.0000','150.0000','pct','0.00','0.00','13086.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(25,10,3,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','57.0000','CRT',2,'14.250000','4.0000','135.0000','135.0000','pct','0.00','0.00','7695.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(26,10,4,'item',9,NULL,'Chicken Blood','29.7000','kg',6,'1.000000','29.7000','25.0000','25.0000','pct','0.00','0.00','742.50',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(27,11,1,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','94.0000','CRT',2,'15.666667','6.0000','175.0000','175.0000','pct','0.00','0.00','16450.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(28,11,2,'item',6,NULL,'Chicken Wings, Frozen, Bag','45.0000','CRT',2,'11.250000','4.0000','190.0000','190.0000','pct','0.00','0.00','8550.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(29,11,3,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','162.0000','CRT',4,'40.500000','4.0000','48.0000','48.0000','pct','0.00','0.00','7776.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(30,12,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','148.8200','CRT',2,'12.401667','12.0000','142.0000','142.0000','pct','0.00','0.00','21132.44',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,12),
(31,12,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','74.0000','CRT',2,'14.800000','5.0000','185.0000','185.0000','pct','0.00','0.00','13690.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5),
(32,12,3,'item',7,NULL,'Chicken Liver, Frozen, Bag','33.0000','CRT',2,'11.000000','3.0000','95.0000','95.0000','pct','0.00','0.00','3135.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(33,13,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','123.1200','CRT',2,'12.312000','10.0000','142.0000','142.0000','pct','0.00','0.00','17483.04',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10),
(34,13,2,'item',2,NULL,'Big Bird Chicken, Fresh Chilled, Vac','91.4800','CRT',2,'15.246667','6.0000','150.0000','150.0000','pct','0.00','0.00','13722.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(35,13,3,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','58.0000','CRT',2,'14.500000','4.0000','135.0000','135.0000','pct','0.00','0.00','7830.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(36,13,4,'item',9,NULL,'Chicken Blood','25.0000','kg',6,'1.000000','25.0000','25.0000','25.0000','pct','0.00','0.00','625.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(37,14,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','96.3700','CRT',2,'12.046250','8.0000','140.0000','140.0000','pct','0.00','0.00','13491.80',NULL,'0.00',3,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8),
(38,14,2,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','61.0000','CRT',2,'15.250000','4.0000','175.0000','175.0000','pct','0.00','0.00','10675.00',NULL,'0.00',3,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(39,14,3,'item',8,NULL,'Chicken Gizzard, Frozen, Bag','17.0000','CRT',2,'8.500000','2.0000','110.0000','110.0000','pct','0.00','0.00','1870.00',NULL,'0.00',3,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(40,14,4,'item',11,NULL,'Chicken Nuggets 500 g, Frozen, Pack','73.0000','CRT',4,'24.333333','3.0000','95.0000','95.0000','pct','0.00','0.00','6935.00',NULL,'0.00',3,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(41,15,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','124.2400','CRT',2,'12.424000','10.0000','142.0000','142.0000','pct','0.00','0.00','17642.08',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10),
(42,15,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','66.0000','CRT',2,'16.500000','4.0000','185.0000','185.0000','pct','0.00','0.00','12210.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(43,15,3,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','59.0000','CRT',2,'14.750000','4.0000','135.0000','135.0000','pct','0.00','0.00','7965.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(44,16,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','100.9900','CRT',2,'12.623750','8.0000','142.0000','142.0000','pct','0.00','0.00','14340.58',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,8),
(45,16,2,'item',2,NULL,'Big Bird Chicken, Fresh Chilled, Vac','72.9600','CRT',2,'14.592000','5.0000','150.0000','150.0000','pct','0.00','0.00','10944.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5),
(46,16,3,'item',7,NULL,'Chicken Liver, Frozen, Bag','24.0000','CRT',2,'12.000000','2.0000','95.0000','95.0000','pct','0.00','0.00','2280.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(47,16,4,'item',9,NULL,'Chicken Blood','20.4000','kg',6,'1.000000','20.4000','25.0000','25.0000','pct','0.00','0.00','510.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(48,17,1,'item',1,NULL,'Crates to the branch','36.8900','CRT',2,'12.296667','3.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5230.19','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(49,17,2,'item',5,NULL,'Crates to the branch','30.3700','CRT',2,'15.185000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5314.75','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(50,17,3,'item',6,NULL,'Crates to the branch','12.2500','CRT',2,'12.250000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2312.39','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(51,17,4,'item',7,NULL,'Crates to the branch','10.2200','CRT',2,'10.220000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'970.90','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(52,17,5,'item',10,NULL,'Crates to the branch','80.0000','CRT',4,'40.000000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3840.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(53,17,6,'item',11,NULL,'Crates to the branch','24.0000','CRT',4,'24.000000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2280.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(54,18,1,'item',1,NULL,'Crates to the branch','24.4400','CRT',2,'12.220000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3465.05','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(55,18,2,'item',4,NULL,'Crates to the branch','30.2100','CRT',2,'15.105000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5588.85','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(56,18,3,'item',5,NULL,'Crates to the branch','30.8900','CRT',2,'15.445000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5405.75','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(57,18,4,'item',10,NULL,'Crates to the branch','40.0000','CRT',4,'40.000000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1920.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(58,19,1,'item',1,NULL,'Crates to the branch','37.9900','CRT',2,'12.663333','3.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5394.58','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(59,19,2,'item',2,NULL,'Crates to the branch','29.0700','CRT',2,'14.535000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4360.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(60,19,3,'item',3,NULL,'Crates to the branch','14.2600','CRT',2,'14.260000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1924.47','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(61,20,1,'item',1,NULL,'Crates to the branch','49.4200','CRT',2,'12.355000','4.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'7004.36','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(62,20,2,'item',4,NULL,'Crates to the branch','14.9000','CRT',2,'14.900000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2753.73','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(63,20,3,'item',3,NULL,'Crates to the branch','14.3000','CRT',2,'14.300000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1929.58','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(64,21,1,'item',1,NULL,'Crates to the branch','37.8800','CRT',2,'12.626667','3.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5370.04','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(65,21,2,'item',2,NULL,'Crates to the branch','29.1100','CRT',2,'14.555000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4366.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(66,21,3,'item',7,NULL,'Crates to the branch','9.7200','CRT',2,'9.720000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'923.40','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(67,22,1,'item',9,NULL,'Chicken blood','12.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'300.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(68,22,2,'item',12,NULL,'Vacuum bags','200.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'660.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(69,23,1,'input',1,NULL,'Whole Chicken, Fresh Chilled, Bag','30.0000','kg',NULL,'1.000000','0.0000','0.0000','142.0000','pct','0.00','0.00','4260.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4260.00','0.00',NULL,'0.0000','0.0000','30.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(70,23,2,'cost',NULL,58,'Cutting and packing labor','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','360.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'360.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(71,23,3,'output',4,NULL,'Chicken Breast, Frozen, Bag','7.8000','kg',NULL,'1.000000','0.0000','0.0000','181.8218','pct','0.00','0.00','1418.21',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1418.21','0.00','co_product','0.0000','30.6972','7.8000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(72,23,4,'output',5,NULL,'Chicken Drumstick, Frozen, Bag','6.6000','kg',NULL,'1.000000','0.0000','0.0000','171.4545','pct','0.00','0.00','1131.60',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1131.60','0.00','co_product','0.0000','24.4935','6.6000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(73,23,5,'output',6,NULL,'Chicken Wings, Frozen, Bag','3.3000','kg',NULL,'1.000000','0.0000','0.0000','187.4030','pct','0.00','0.00','618.43',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'618.43','0.00','co_product','0.0000','13.3859','3.3000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(74,23,6,'output',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','9.0000','kg',NULL,'1.000000','0.0000','0.0000','133.9733','pct','0.00','0.00','1205.76',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1205.76','0.00','co_product','0.0000','26.0987','9.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(75,23,7,'output',7,NULL,'Chicken Liver, Frozen, Bag','1.2000','kg',NULL,'1.000000','0.0000','0.0000','95.0000','pct','0.00','0.00','114.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'114.00','0.00','by_product','95.0000','2.4675','1.2000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(76,23,8,'output',8,NULL,'Chicken Gizzard, Frozen, Bag','1.2000','kg',NULL,'1.000000','0.0000','0.0000','110.0000','pct','0.00','0.00','132.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'132.00','0.00','by_product','110.0000','2.8571','1.2000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(77,24,1,'input',1,NULL,'Whole Chicken, Fresh Chilled, Bag','20.0000','kg',NULL,'1.000000','0.0000','0.0000','142.0000','pct','0.00','0.00','2840.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2840.00','0.00',NULL,'0.0000','0.0000','20.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(78,24,2,'cost',NULL,58,'Cutting and packing labor','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','240.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'240.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(79,24,3,'output',4,NULL,'Chicken Breast, Frozen, Bag','5.4000','kg',NULL,'1.000000','0.0000','0.0000','181.2259','pct','0.00','0.00','978.62',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'978.62','0.00','co_product','0.0000','31.7734','5.2000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(80,24,4,'output',5,NULL,'Chicken Drumstick, Frozen, Bag','4.4000','kg',NULL,'1.000000','0.0000','0.0000','170.8932','pct','0.00','0.00','751.93',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'751.93','0.00','co_product','0.0000','24.4133','4.4000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(81,24,5,'output',6,NULL,'Chicken Wings, Frozen, Bag','2.2000','kg',NULL,'1.000000','0.0000','0.0000','186.7909','pct','0.00','0.00','410.94',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'410.94','0.00','co_product','0.0000','13.3422','2.2000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(82,24,6,'output',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','5.8000','kg',NULL,'1.000000','0.0000','0.0000','133.5362','pct','0.00','0.00','774.51',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'774.51','0.00','co_product','0.0000','25.1464','6.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(83,24,7,'output',7,NULL,'Chicken Liver, Frozen, Bag','0.8000','kg',NULL,'1.000000','0.0000','0.0000','95.0000','pct','0.00','0.00','76.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'76.00','0.00','by_product','95.0000','2.4675','0.8000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(84,24,8,'output',8,NULL,'Chicken Gizzard, Frozen, Bag','0.8000','kg',NULL,'1.000000','0.0000','0.0000','110.0000','pct','0.00','0.00','88.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'88.00','0.00','by_product','110.0000','2.8571','0.8000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(85,25,1,'input',1,NULL,'Whole Chicken, Fresh Chilled, Bag','20.0000','kg',NULL,'1.000000','0.0000','0.0000','141.7644','pct','0.00','0.00','2835.29',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000','20.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(86,25,2,'cost',NULL,58,'Cutting and packing labor','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','240.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(87,25,3,'output',4,NULL,'Chicken Breast, Frozen, Bag','5.2000','kg',NULL,'1.000000','0.0000','0.0000','181.5288','pct','0.00','0.00','943.95',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','co_product','0.0000','30.6947','5.2000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(88,25,4,'output',5,NULL,'Chicken Drumstick, Frozen, Bag','4.4000','kg',NULL,'1.000000','0.0000','0.0000','171.1773','pct','0.00','0.00','753.18',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','co_product','0.0000','24.4913','4.4000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(89,25,5,'output',6,NULL,'Chicken Wings, Frozen, Bag','2.2000','kg',NULL,'1.000000','0.0000','0.0000','187.1000','pct','0.00','0.00','411.62',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','co_product','0.0000','13.3848','2.2000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(90,25,6,'output',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','6.0000','kg',NULL,'1.000000','0.0000','0.0000','133.7567','pct','0.00','0.00','802.54',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','co_product','0.0000','26.0964','6.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(91,25,7,'output',7,NULL,'Chicken Liver, Frozen, Bag','0.8000','kg',NULL,'1.000000','0.0000','0.0000','95.0000','pct','0.00','0.00','76.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','by_product','95.0000','2.4713','0.8000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(92,25,8,'output',8,NULL,'Chicken Gizzard, Frozen, Bag','0.8000','kg',NULL,'1.000000','0.0000','0.0000','110.0000','pct','0.00','0.00','88.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00','by_product','110.0000','2.8615','0.8000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(93,26,1,'item',14,NULL,'Party Pack','8.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'4520.76','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(94,26,2,'component',5,NULL,'Component','8.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1398.85','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(95,26,3,'component',6,NULL,'Component','16.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3019.11','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(96,26,4,'component',12,NULL,'Component','16.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'52.80','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(97,26,5,'component',13,NULL,'Component','2.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'50.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(98,27,1,'item',14,NULL,'Party Pack','3.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1695.29','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(99,28,1,'item',14,NULL,'Party Pack','20.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(100,28,2,'component',5,NULL,'Component','20.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0);
INSERT INTO `transaction_lines` (`id`,`txn_id`,`line_no`,`line_kind`,`item_id`,`account_id`,`description`,`qty`,`unit`,`uom_id`,`uom_factor`,`uom_qty`,`uom_rate`,`rate`,`discount_kind`,`discount_pct`,`discount_amount`,`amount`,`tax_code_id`,`tax_amount`,`site_id`,`production_date`,`expiry_date`,`customer_id`,`vendor_id`,`is_billable`,`billed_txn_id`,`ref_txn_id`,`pos_shift_id`,`source_line_id`,`qty_fulfilled`,`amount_fulfilled`,`is_closed`,`cost_amount`,`value_change`,`output_role`,`alloc_basis`,`alloc_pct`,`planned_qty`,`class_id`,`other_name_id`,`group_item_id`,`group_ref`,`group_qty`,`group_rate`,`group_role`,`crate_count`) VALUES
(101,28,3,'component',6,NULL,'Component','40.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(102,28,4,'component',12,NULL,'Component','40.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(103,28,5,'component',13,NULL,'Component','5.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(104,29,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','120.0000','kg',NULL,'1.000000','120.0000','165.0000','165.0000','pct','0.00','0.00','19800.00',1,'2376.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(105,29,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','45.0000','kg',NULL,'1.000000','45.0000','215.0000','215.0000','pct','0.00','0.00','9675.00',1,'1161.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(106,29,3,'item',17,NULL,'Delivery Fee (reefer)','2.0000','pc',NULL,'1.000000','2.0000','350.0000','350.0000','pct','0.00','0.00','700.00',1,'84.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(107,30,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','120.0000','kg',NULL,'1.000000','120.0000','165.0000','165.0000','pct','0.00','0.00','19800.00',1,'2376.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,104,'100.5000','16582.50',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(108,30,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','45.0000','kg',NULL,'1.000000','45.0000','215.0000','215.0000','pct','0.00','0.00','9675.00',1,'1161.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,105,'29.4700','6336.05',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(109,30,3,'item',17,NULL,'Delivery Fee (reefer)','2.0000','pc',NULL,'1.000000','2.0000','350.0000','350.0000','pct','0.00','0.00','700.00',1,'84.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,106,'2.0000','700.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(110,31,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','50.9600','CRT',2,'10.192000','5.0000','165.0000','165.0000','pct','0.00','0.00','8408.40',1,'1009.01',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,107,'0.0000','0.00',0,'7224.31','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5),
(111,31,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','29.4700','CRT',2,'14.735000','2.0000','215.0000','215.0000','pct','0.00','0.00','6336.05',1,'760.33',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,108,'0.0000','0.00',0,'5446.47','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(112,31,3,'item',17,NULL,'Delivery Fee (reefer)','1.0000','pc',NULL,'1.000000','1.0000','350.0000','350.0000','pct','0.00','0.00','350.00',1,'42.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,109,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(113,32,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','49.5400','CRT',2,'12.385000','4.0000','165.0000','165.0000','pct','0.00','0.00','8174.10',1,'980.89',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,107,'0.0000','0.00',0,'7023.01','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(114,32,2,'item',17,NULL,'Delivery Fee (reefer)','1.0000','pc',NULL,'1.000000','1.0000','350.0000','350.0000','pct','0.00','0.00','350.00',1,'42.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,109,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(115,33,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','37.0900','CRT',2,'12.363333','3.0000','165.0000','165.0000','pct','0.00','0.00','6119.85',1,'734.38',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5258.04','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(116,33,2,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','30.9900','CRT',2,'15.495000','2.0000','215.0000','215.0000','pct','0.00','0.00','6662.85',1,'799.54',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5418.80','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(117,33,3,'item',17,NULL,'Delivery Fee (reefer)','1.0000','pc',NULL,'1.000000','1.0000','350.0000','350.0000','pct','0.00','0.00','350.00',1,'42.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(118,34,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','18.0000','kg',1,'1.000000','18.0000','175.0000','175.0000','pct','0.00','0.00','3150.00',1,'378.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2551.76','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(119,34,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','10.0000','kg',1,'1.000000','10.0000','228.0000','228.0000','pct','0.00','0.00','2280.00',1,'273.60',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1848.14','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(120,34,3,'item',7,NULL,'Chicken Liver, Frozen, Bag','4.0000','kg',1,'1.000000','4.0000','130.0000','130.0000','pct','0.00','0.00','520.00',1,'62.40',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'380.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(121,34,4,'item',9,NULL,'Chicken Blood','6.0000','kg',NULL,'1.000000','6.0000','40.0000','40.0000','pct','0.00','0.00','240.00',3,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'150.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(122,35,1,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','12.0000','kg',1,'1.000000','12.0000','215.0000','215.0000','pct','0.00','0.00','2580.00',1,'309.60',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2098.28','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(123,35,2,'item',6,NULL,'Chicken Wings, Frozen, Bag','8.0000','kg',1,'1.000000','8.0000','235.0000','235.0000','pct','0.00','0.00','1880.00',1,'225.60',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1509.56','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(124,35,3,'item',15,NULL,'Custom Cutting Service','12.0000','kg',NULL,'1.000000','12.0000','15.0000','15.0000','pct','0.00','0.00','180.00',1,'21.60',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(125,36,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','11.9500','CRT',2,'11.950000','1.0000','175.0000','175.0000','pct','0.00','0.00','2091.25',1,'250.95',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1694.08','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(126,36,2,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','15.3600','CRT',2,'15.360000','1.0000','215.0000','215.0000','pct','0.00','0.00','3302.40',1,'396.29',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2685.79','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(127,36,3,'item',4,NULL,'Chicken Breast, Frozen, Bag','8.0000','kg',1,'1.000000','8.0000','228.0000','228.0000','pct','0.00','0.00','1824.00',1,'218.88',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1478.51','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(128,37,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','48.5800','CRT',2,'12.145000','4.0000','175.0000','175.0000','pct','0.00','0.00','8501.50',1,'1020.18',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6886.92','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,4),
(129,37,2,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','10.0000','kg',1,'1.000000','10.0000','215.0000','215.0000','pct','0.00','0.00','2150.00',1,'258.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1748.56','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(130,37,3,'item',17,NULL,'Delivery Fee (reefer)','1.0000','pc',NULL,'1.000000','1.0000','350.0000','350.0000','pct','0.00','0.00','350.00',1,'42.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(131,38,1,'item',4,NULL,'Chicken Breast, Frozen, Bag','20.0000','kg',1,'1.000000','20.0000','228.0000','228.0000','pct','0.00','0.00','4560.00',1,'547.20',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3696.28','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(132,38,2,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','15.0000','kg',1,'1.000000','15.0000','168.0000','168.0000','pct','0.00','0.00','2520.00',1,'302.40',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2024.03','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(133,39,1,'item',4,NULL,'Chicken Breast, Frozen, Bag','15.0000','kg',1,'1.000000','15.0000','228.0000','228.0000','pct','0.00','0.00','3420.00',1,'410.40',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2772.21','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(134,39,2,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','12.0000','kg',1,'1.000000','12.0000','168.0000','168.0000','pct','0.00','0.00','2016.00',1,'241.92',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1619.23','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(135,40,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','19.1000','CRT',2,'9.550000','2.0000','168.0000','168.0000','pct','0.00','0.00','3208.80',1,'385.06',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2707.70','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(136,41,1,'item',4,NULL,'Chicken Breast, Frozen, Bag','15.0000','kg',1,'1.000000','15.0000','228.0000','228.0000','pct','0.00','0.00','3420.00',1,'410.40',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2772.21','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(137,41,2,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','12.0000','kg',1,'1.000000','12.0000','168.0000','168.0000','pct','0.00','0.00','2016.00',1,'241.92',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1619.23','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(138,42,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','24.3500','CRT',2,'12.175000','2.0000','168.0000','168.0000','pct','0.00','0.00','4090.80',1,'490.90',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3451.96','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(139,43,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','73.7000','CRT',2,'12.283333','6.0000','165.0000','165.0000','pct','0.00','0.00','12160.50',1,'1459.26',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'10448.04','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,6),
(140,43,2,'item',2,NULL,'Big Bird Chicken, Fresh Chilled, Vac','44.4900','CRT',2,'14.830000','3.0000','185.0000','185.0000','pct','0.00','0.00','8230.65',1,'987.68',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'6673.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(141,43,3,'item',11,NULL,'Chicken Nuggets 500 g, Frozen, Pack','24.0000','CRT',4,'24.000000','1.0000','128.0000','128.0000','pct','0.00','0.00','3072.00',1,'368.64',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2280.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(142,43,4,'item',22,NULL,'Subtotal','0.0000','pc',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(143,43,5,'item',20,NULL,'5% Volume Discount','0.0000','pc',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-153.60',1,'-18.43',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(144,44,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','62.5500','CRT',2,'12.510000','5.0000','165.0000','165.0000','pct','0.00','0.00','10320.75',1,'1238.49',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'8867.37','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,5),
(145,44,2,'item',4,NULL,'Chicken Breast, Frozen, Bag','0.2300','CRT',2,'0.230000','1.0000','215.0000','215.0000','pct','0.00','0.00','49.45',1,'5.93',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'42.51','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(146,44,3,'item',17,NULL,'Delivery Fee (reefer)','1.0000','pc',NULL,'1.000000','1.0000','350.0000','350.0000','pct','0.00','0.00','350.00',1,'42.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(147,45,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','25.0000','kg',1,'1.000000','25.0000','175.0000','175.0000','pct','0.00','0.00','4375.00',1,'525.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3544.11','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(148,45,2,'item',8,NULL,'Chicken Gizzard, Frozen, Bag','3.0000','kg',1,'1.000000','3.0000','145.0000','145.0000','pct','0.00','0.00','435.00',1,'52.20',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'330.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(149,46,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','12.0200','CRT',2,'12.020000','1.0000','175.0000','175.0000','pct','0.00','0.00','2103.50',1,'252.42',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(150,46,2,'item',18,NULL,'Crate Deposit','2.0000','pc',NULL,'1.000000','2.0000','250.0000','250.0000','pct','0.00','0.00','500.00',4,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(151,47,1,'item',7,NULL,'Chicken Liver, Frozen, Bag','2.5000','kg',1,'1.000000','2.5000','130.0000','130.0000','pct','0.00','0.00','325.00',1,'39.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'237.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(152,47,2,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','6.2000','kg',1,'1.000000','6.2000','175.0000','175.0000','pct','0.00','0.00','1085.00',1,'130.20',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'878.94','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(153,47,3,'item',9,NULL,'Chicken Blood','2.0000','kg',NULL,'1.000000','2.0000','40.0000','40.0000','pct','0.00','0.00','80.00',3,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'50.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(154,52,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','18.0700','CRT',2,'9.035000','2.0000','175.0000','175.0000','pct','0.00','0.00','3162.25',1,'379.47',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2561.68','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(155,52,2,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','10.0000','kg',1,'1.000000','10.0000','168.0000','168.0000','pct','0.00','0.00','1680.00',1,'201.60',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1349.35','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(156,54,1,'item',7,NULL,'Chicken Liver, Frozen, Bag','3.0000','kg',NULL,'1.000000','3.0000','130.0000','130.0000','pct','0.00','0.00','390.00',1,'46.80',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(157,55,1,'item',19,NULL,'Late Payment Fee','1.0000','pc',NULL,'1.000000','1.0000','200.0000','200.0000','pct','0.00','0.00','200.00',4,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(158,56,1,'item',NULL,52,'Finance charge (12% p.a.)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','86.40',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(159,57,1,'expense',NULL,60,'Monthly rent','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','95000.00',1,'11400.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(160,58,1,'expense',NULL,60,'Monthly rent','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','95000.00',1,'11400.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(161,59,1,'expense',NULL,60,'Monthly rent','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','95000.00',1,'11400.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(162,60,1,'expense',NULL,61,'Electricity, cold storage','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','86450.75',1,'10374.09',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(163,61,1,'expense',NULL,61,'Electricity, cold storage','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','92230.40',1,'11067.65',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(164,62,1,'expense',NULL,66,'Professional fees','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','45000.00',1,'5400.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(165,63,1,'expense',NULL,64,'Diesel','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','6800.00',1,'816.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(166,64,1,'expense',NULL,64,'Diesel','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','6800.00',1,'816.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(167,65,1,'expense',NULL,64,'Diesel','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','6800.00',1,'816.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(168,66,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','12.0000','kg',NULL,'1.000000','12.0000','142.0000','142.0000','pct','0.00','0.00','1704.00',1,'204.48',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(169,71,1,'expense',NULL,72,'Pantry supplies','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2500.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(171,73,1,'item',7,NULL,'Spoilage','-1.5000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-142.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(172,74,1,'item',10,NULL,'Count difference (2 packs torn)','-2.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-96.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(173,74,2,'item',12,NULL,'Count difference (bags found in the store room)','50.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'165.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(174,76,1,'journal',NULL,69,'Toll and parking','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1250.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,0),
(175,77,1,'journal',NULL,69,'Fares for small deliveries','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','480.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(176,78,1,'deposit',NULL,7,'Sales Receipt SR-00001','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1659.20',NULL,'0.00',NULL,NULL,NULL,13,NULL,0,NULL,47,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(177,78,2,'deposit',NULL,7,'Customer Payment PMT-00001','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','60000.00',NULL,'0.00',NULL,NULL,NULL,6,NULL,0,NULL,48,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(178,78,3,'deposit',NULL,7,'Customer Payment PMT-00003','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','7404.00',NULL,'0.00',NULL,NULL,NULL,8,NULL,0,NULL,50,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(179,78,4,'deposit',NULL,7,'Customer Payment PMT-00004','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','3964.80',NULL,'0.00',NULL,NULL,NULL,10,NULL,0,NULL,51,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(180,78,5,'deposit',NULL,53,'Interest on time deposit','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','1250.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(181,79,1,'journal',NULL,68,'Depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2708.33',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(182,79,2,'journal',NULL,30,'Accumulated depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-2708.33',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(183,79,3,'journal',NULL,68,'Depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','15446.67',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(184,79,4,'journal',NULL,24,'Accumulated depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-15446.67',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(185,79,5,'journal',NULL,68,'Depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','81666.67',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(186,79,6,'journal',NULL,26,'Accumulated depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-81666.67',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(187,80,1,'journal',NULL,68,'Depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','2708.33',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(188,80,2,'journal',NULL,30,'Accumulated depreciation - Computer and POS Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-2708.33',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(189,80,3,'journal',NULL,68,'Depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','15580.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(190,80,4,'journal',NULL,24,'Accumulated depreciation - Production Machinery (usage-based)','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-15580.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(191,80,5,'journal',NULL,68,'Depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','81666.67',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(192,80,6,'journal',NULL,26,'Accumulated depreciation - Transportation Equipment','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-81666.67',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(193,81,1,'journal',NULL,67,'Service charge','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','150.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(194,81,2,'journal',NULL,5,'Service charge','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-150.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(197,82,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','3.4000','kg',1,'1.000000','3.4000','175.0000','175.0000','pct','0.00','0.00','595.00',1,'71.40',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'481.97','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(198,82,2,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','2.0000','pack',3,'1.000000','2.0000','65.0000','65.0000','pct','0.00','0.00','130.00',1,'15.60',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'1.0000','65.00',0,'96.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(200,83,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','9.0200','CRT',2,'9.020000','1.0000','170.0000','170.0000','pct','0.00','0.00','1533.40',1,'184.01',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1278.64','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(203,84,1,'item',7,NULL,'Chicken Liver, Frozen, Bag','1.2000','kg',1,'1.000000','1.2000','130.0000','130.0000','pct','0.00','0.00','156.00',1,'18.72',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'114.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(204,84,2,'item',11,NULL,'Chicken Nuggets 500 g, Frozen, Pack','1.0000','pack',3,'1.000000','1.0000','128.0000','128.0000','pct','0.00','0.00','128.00',1,'15.36',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'95.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(206,85,1,'item',2,NULL,'Big Bird Chicken, Fresh Chilled, Vac','4.6000','kg',1,'1.000000','4.6000','185.0000','185.0000','pct','0.00','0.00','851.00',1,'102.12',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'690.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(209,86,1,'item',14,NULL,'Party Pack (2 kg wings, 1 kg drumsticks)','1.0000','pc',NULL,'1.000000','1.0000','720.0000','720.0000','pct','0.00','0.00','720.00',1,'86.40',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'565.10','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0);
INSERT INTO `transaction_lines` (`id`,`txn_id`,`line_no`,`line_kind`,`item_id`,`account_id`,`description`,`qty`,`unit`,`uom_id`,`uom_factor`,`uom_qty`,`uom_rate`,`rate`,`discount_kind`,`discount_pct`,`discount_amount`,`amount`,`tax_code_id`,`tax_amount`,`site_id`,`production_date`,`expiry_date`,`customer_id`,`vendor_id`,`is_billable`,`billed_txn_id`,`ref_txn_id`,`pos_shift_id`,`source_line_id`,`qty_fulfilled`,`amount_fulfilled`,`is_closed`,`cost_amount`,`value_change`,`output_role`,`alloc_basis`,`alloc_pct`,`planned_qty`,`class_id`,`other_name_id`,`group_item_id`,`group_ref`,`group_qty`,`group_rate`,`group_role`,`crate_count`) VALUES
(210,86,2,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag','2.0000','kg',NULL,'1.000000','2.0000','168.0000','168.0000','pct','0.00','0.00','336.00',1,'40.32',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'269.87','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(211,87,1,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','1.0000',NULL,NULL,'1.000000','0.0000','0.0000','65.0000','pct','0.00','0.00','65.00',1,'7.80',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,198,'0.0000','0.00',0,'48.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(212,88,1,'journal',NULL,2,'Drawer count difference','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','-20.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(213,88,2,'journal',NULL,71,'Cash over and short','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','20.00',NULL,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(216,89,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','2.8000','kg',1,'1.000000','2.8000','175.0000','175.0000','pct','0.00','0.00','490.00',1,'58.80',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'396.92','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(217,89,2,'item',9,NULL,'Chicken Blood','1.0000','kg',NULL,'1.000000','1.0000','40.0000','40.0000','pct','0.00','0.00','40.00',3,'0.00',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'25.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(221,90,1,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','4.0000','pack',NULL,'1.000000','4.0000','65.0000','65.0000','pct','0.00','0.00','260.00',1,'31.20',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'192.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,23,1,'1.0000','480.0000','member',0),
(222,90,2,'item',11,NULL,'Chicken Nuggets 500 g, Frozen, Pack','2.0000','pack',NULL,'1.000000','2.0000','128.0000','128.0000','pct','0.00','0.00','256.00',1,'30.72',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'190.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,23,1,'1.0000','480.0000','member',0),
(223,90,3,'item',NULL,50,'Price variance: Fiesta Bundle','0.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','amt','0.00','0.00','-36.00',1,'-4.32',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'0.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,23,1,'1.0000','480.0000','variance',0),
(224,91,1,'item',2,NULL,'Condemned, 5 expired crate(s)','-76.0500',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-11407.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(225,92,1,'item',1,NULL,'Condemned, 12 expired crate(s)','-146.9600',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-20832.55','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(226,92,2,'item',2,NULL,'Condemned, 4 expired crate(s)','-58.1800',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-8727.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(227,93,1,'item',1,NULL,'Crates to the branch','37.6000','CRT',2,'12.533333','3.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'5330.05','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,3),
(228,93,2,'item',5,NULL,'Crates to the branch','3.4200','CRT',2,'3.420000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'598.01','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(229,93,3,'item',10,NULL,'Crates to the branch','40.0000','CRT',4,'40.000000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1920.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(230,94,1,'item',9,NULL,'Chicken Blood','6.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'150.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(231,95,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','12.7900','CRT',2,'12.790000','1.0000','175.0000','175.0000','pct','0.00','0.00','2238.25',1,'268.59',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1813.07','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(232,95,2,'item',5,NULL,'Chicken Drumstick, Frozen, Bag','3.4200','kg',1,'1.000000','3.4200','215.0000','215.0000','pct','0.00','0.00','735.30',1,'88.24',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'598.01','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(233,96,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','3.2000','kg',1,'1.000000','3.2000','175.0000','175.0000','pct','0.00','0.00','560.00',1,'67.20',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'453.62','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(234,96,2,'item',9,NULL,'Chicken Blood','2.0000','kg',NULL,'1.000000','2.0000','40.0000','40.0000','pct','0.00','0.00','80.00',3,'0.00',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'50.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(235,96,3,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','6.0000','pack',3,'1.000000','6.0000','65.0000','65.0000','pct','0.00','0.00','390.00',1,'46.80',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'288.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(236,97,1,'item',1,NULL,'Shrinkage','-0.1800','kg',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-25.52','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(237,98,1,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack, crate 48 (shortage)','2.0000','pack',NULL,'1.000000','0.0000','48.0000','48.0000','pct','0.00','0.00','96.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'96.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(238,98,2,'item',9,NULL,'Chicken Blood (shortage)','0.5000','kg',NULL,'1.000000','0.0000','25.0000','25.0000','pct','0.00','0.00','12.50',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'12.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(239,99,1,'item',10,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack','32.0000','CRT',4,'32.000000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1536.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(240,99,2,'item',9,NULL,'Chicken Blood','3.5000','kg',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'87.50','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(241,99,3,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','9.1500','CRT',2,'9.150000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1297.07','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(242,99,4,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','12.2800','CRT',2,'12.280000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1740.77','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(243,101,1,'item',1,NULL,'Crates to the branch','21.4300','CRT',2,'10.715000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'3037.84','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(244,101,2,'item',4,NULL,'Crates to the branch','13.0000','CRT',2,'13.000000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2402.58','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(245,102,1,'item',4,NULL,'Chicken Breast, Frozen, Bag','5.0000','kg',1,'1.000000','5.0000','228.0000','228.0000','pct','0.00','0.00','1140.00',1,'136.80',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'924.07','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(246,102,2,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','2.4000','kg',1,'1.000000','2.4000','175.0000','175.0000','pct','0.00','0.00','420.00',1,'50.40',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'340.22','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(247,103,1,'item',4,NULL,'Shrinkage','-0.1200','kg',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',7,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-22.18','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(248,104,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag, crate 155 (shortage)','12.2800','kg',NULL,'1.000000','0.0000','141.7566','141.7566','pct','0.00','0.00','1740.77',NULL,'0.00',7,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1740.77','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(249,105,1,'item',4,NULL,'Chicken Breast, Frozen, Bag','7.8800','CRT',2,'7.880000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',7,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1456.34','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(250,105,2,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','6.7500','CRT',2,'6.750000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',7,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'956.86','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(251,106,1,'item',1,NULL,'Crates to the branch','19.6200','CRT',2,'9.810000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2781.26','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(252,106,2,'item',2,NULL,'Crates to the branch','14.5400','CRT',2,'14.540000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2181.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(253,107,1,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','4.8000','kg',1,'1.000000','4.8000','175.0000','175.0000','pct','0.00','0.00','840.00',1,'100.80',NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'680.43','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(254,108,1,'item',2,NULL,'Shrinkage','-0.1000','kg',NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-15.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(255,109,1,'item',2,NULL,'Big Bird Chicken, Fresh Chilled, Vac','14.4400','CRT',2,'14.440000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2166.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(256,109,2,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','1.9500','CRT',2,'1.950000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'276.43','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(257,109,3,'item',1,NULL,'Whole Chicken, Fresh Chilled, Bag','12.8700','CRT',2,'12.870000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',6,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'1824.41','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(258,110,1,'item',1,NULL,'Crates to the branch','14.8200','CRT',2,'7.410000','2.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2100.83','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2),
(259,110,2,'item',5,NULL,'Crates to the branch','15.1400','CRT',2,'15.140000','1.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'2647.33','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1),
(260,111,1,'item',9,NULL,'Chicken Blood','4.0000',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'100.00','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(261,112,1,'item',3,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag (shortage: counter count)','2.0000','kg',NULL,'1.000000','0.0000','134.9355','134.9355','pct','0.00','0.00','269.87',NULL,'0.00',2,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'269.87','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0),
(262,113,1,'item',9,NULL,'Shrinkage','-1.3500',NULL,NULL,'1.000000','0.0000','0.0000','0.0000','pct','0.00','0.00','0.00',NULL,'0.00',1,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL,'0.0000','0.00',0,'-33.75','0.00',NULL,'0.0000','0.0000',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0);

-- payment_applications (10 rows)
INSERT INTO `payment_applications` (`id`,`payment_txn_id`,`target_txn_id`,`amount`,`discount`,`withholding`,`created_at`) VALUES
(1,48,31,'60000.00','0.00','0.00','2026-11-25 21:50:05'),
(2,49,36,'7922.09','161.68','0.00','2026-11-25 21:50:05'),
(3,50,34,'6904.00','0.00','0.00','2026-11-25 21:50:05'),
(4,51,38,'3964.80','0.00','0.00','2026-11-25 21:50:05'),
(5,53,52,'5132.79','0.00','290.53','2026-11-25 21:50:05'),
(6,66,7,'1908.48','0.00','0.00','2026-11-25 21:50:05'),
(7,67,7,'57636.74','0.00','0.00','2026-11-25 21:50:05'),
(8,68,60,'96824.84','0.00','0.00','2026-11-25 21:50:05'),
(9,69,62,'49500.00','0.00','900.00','2026-11-25 21:50:05'),
(10,100,98,'54.25','0.00','0.00','2026-11-25 21:50:05');

-- withholding_taxes (3 rows)
INSERT INTO `withholding_taxes` (`id`,`code`,`atc`,`name`,`tax_kind`,`rate`,`base_type`,`applies_to`,`payable_account_id`,`receivable_account_id`,`description`,`sort_order`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'WT-GOODS','WC158','WT on Goods','income','1.0000','net_of_vat','both',NULL,NULL,'Goods bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',10,1,'2026-11-25 21:50:03',NULL),
(2,'WT-SERVICES','WC160','WT on Services','income','2.0000','net_of_vat','both',NULL,NULL,'Services bought from regular suppliers by government payors and top withholding agents (RR 11-2018)',20,1,'2026-11-25 21:50:03',NULL),
(3,'WT-VAT','WV010','WT on VAT','vat','5.0000','net_of_vat','both',NULL,NULL,'Creditable VAT withheld by government buyers on VATable purchases (5% of the VAT-exclusive payment)',30,1,'2026-11-25 21:50:03',NULL);

-- payment_withholdings (3 rows)
INSERT INTO `payment_withholdings` (`id`,`payment_txn_id`,`target_txn_id`,`wht_id`,`tax_kind`,`atc`,`rate`,`base`,`amount`,`account_id`,`created_at`) VALUES
(1,53,52,3,'vat','WV010','5.0000','4842.25','242.11',17,'2026-11-25 21:50:05'),
(2,53,52,1,'income','WC158','1.0000','4842.25','48.42',16,'2026-11-25 21:50:05'),
(3,69,62,2,'income','WC160','2.0000','45000.00','900.00',35,'2026-11-25 21:50:05');

-- item_group_sales (1 rows)
INSERT INTO `item_group_sales` (`id`,`txn_id`,`group_ref`,`group_item_id`,`txn_type`,`txn_date`,`customer_id`,`site_id`,`terminal_id`,`class_id`,`sales_rep_id`,`created_by`,`qty`,`group_price`,`amount`,`consolidated`,`variance`,`tax_amount`,`created_at`) VALUES
(2,90,1,23,'pos_sale','2026-11-25',NULL,2,1,2,NULL,9,'1.0000','480.0000','480.00','516.00','-36.00','57.60','2026-11-25 21:50:05');

-- journal_lines (475 rows)
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(1,1,'2026-09-06',5,'3200000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'BDO checking opening balance',1,1,'2026-11-25 21:50:04'),
(2,1,'2026-09-06',6,'900000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'BPI savings opening balance',0,NULL,'2026-11-25 21:50:04'),
(3,1,'2026-09-06',3,'15000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Petty cash fund',0,NULL,'2026-11-25 21:50:04'),
(4,1,'2026-09-06',2,'10000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Register cash funds',0,NULL,'2026-11-25 21:50:04'),
(5,1,'2026-09-06',41,'0.00','4125000.00',NULL,NULL,NULL,NULL,NULL,NULL,'Owner\'s capital',0,NULL,'2026-11-25 21:50:04'),
(6,2,'2026-09-01',23,'1850000.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Blast Freezer and Cold Room (20 tons)',0,NULL,'2026-11-25 21:50:04'),
(7,2,'2026-09-01',5,'0.00','1850000.00',NULL,7,NULL,NULL,NULL,NULL,'Purchase of Blast Freezer and Cold Room (20 tons)',1,1,'2026-11-25 21:50:04'),
(8,3,'2026-09-01',25,'2450000.00','0.00',NULL,9,NULL,NULL,NULL,NULL,'Reefer Truck 1 (6-wheeler, -18 C)',0,NULL,'2026-11-25 21:50:04'),
(9,3,'2026-09-01',32,'0.00','2450000.00',NULL,9,NULL,NULL,NULL,NULL,'Purchase of Reefer Truck 1 (6-wheeler, -18 C)',0,NULL,'2026-11-25 21:50:04'),
(10,4,'2026-09-01',29,'65000.00','0.00',NULL,9,NULL,NULL,NULL,NULL,'POS Terminal Set (Naga Outlet)',0,NULL,'2026-11-25 21:50:04'),
(11,4,'2026-09-01',5,'0.00','65000.00',NULL,9,NULL,NULL,NULL,NULL,'Purchase of POS Terminal Set (Naga Outlet)',1,1,'2026-11-25 21:50:04'),
(12,5,'2026-09-01',23,'85000.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Platform Scale 300 kg (receiving)',0,NULL,'2026-11-25 21:50:04'),
(13,5,'2026-09-01',32,'0.00','85000.00',NULL,7,NULL,NULL,NULL,NULL,'Purchase of Platform Scale 300 kg (receiving)',0,NULL,'2026-11-25 21:50:04'),
(14,6,'2026-11-05',62,'14500.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Parts - MNT-00001 FA-00002 Reefer Truck 1 (6-wheeler, -18 C)',0,NULL,'2026-11-25 21:50:04'),
(15,6,'2026-11-05',62,'2500.00','0.00',NULL,7,NULL,NULL,NULL,NULL,'Labor - MNT-00001 FA-00002 Reefer Truck 1 (6-wheeler, -18 C)',0,NULL,'2026-11-25 21:50:04'),
(16,6,'2026-11-05',32,'0.00','17000.00',NULL,7,NULL,NULL,NULL,NULL,'Repair of FA-00002 Reefer Truck 1 (6-wheeler, -18 C) (MNT-00001)',0,NULL,'2026-11-25 21:50:04'),
(17,7,'2026-09-12',14,'21121.08','0.00',NULL,1,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(18,7,'2026-09-12',15,'2534.53','0.00',NULL,1,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(19,7,'2026-09-12',14,'16614.85','0.00',NULL,1,4,1,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(20,7,'2026-09-12',15,'1993.78','0.00',NULL,1,4,1,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(21,7,'2026-09-12',14,'2816.75','0.00',NULL,1,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(22,7,'2026-09-12',15,'338.01','0.00',NULL,1,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(23,7,'2026-09-12',14,'11612.70','0.00',NULL,1,3,1,NULL,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(24,7,'2026-09-12',15,'1393.52','0.00',NULL,1,3,1,NULL,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(25,7,'2026-09-12',14,'1000.00','0.00',NULL,1,9,1,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(26,7,'2026-09-12',15,'120.00','0.00',NULL,1,9,1,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(27,7,'2026-09-12',32,'0.00','59545.22',NULL,1,NULL,1,NULL,NULL,'Opening stock, received in crates',0,NULL,'2026-11-25 21:50:04'),
(39,8,'2026-09-20',14,'21491.75','0.00',NULL,2,5,1,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(40,8,'2026-09-20',15,'2579.01','0.00',NULL,2,5,1,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(41,8,'2026-09-20',14,'13614.96','0.00',NULL,2,6,1,NULL,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(42,8,'2026-09-20',15,'1633.80','0.00',NULL,2,6,1,NULL,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(43,8,'2026-09-20',14,'3309.90','0.00',NULL,2,8,1,NULL,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(44,8,'2026-09-20',15,'397.19','0.00',NULL,2,8,1,NULL,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(45,8,'2026-09-20',14,'11520.00','0.00',NULL,2,10,1,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:04'),
(46,8,'2026-09-20',15,'1382.40','0.00',NULL,2,10,1,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:04'),
(47,8,'2026-09-20',14,'9120.00','0.00',NULL,2,11,1,NULL,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:04'),
(48,8,'2026-09-20',15,'1094.40','0.00',NULL,2,11,1,NULL,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:04'),
(49,8,'2026-09-20',32,'0.00','66143.41',NULL,2,NULL,1,NULL,NULL,'Bill for received items',0,NULL,'2026-11-25 21:50:04'),
(50,9,'2026-09-16',14,'6600.00','0.00',NULL,3,12,1,NULL,NULL,'Vacuum Bag 2 kg',0,NULL,'2026-11-25 21:50:04'),
(51,9,'2026-09-16',15,'792.00','0.00',NULL,3,12,1,NULL,NULL,'Vacuum Bag 2 kg',0,NULL,'2026-11-25 21:50:04'),
(52,9,'2026-09-16',32,'0.00','7392.00',NULL,3,NULL,1,NULL,NULL,'Vacuum bags',0,NULL,'2026-11-25 21:50:04'),
(53,10,'2026-09-26',14,'17872.12','0.00',NULL,1,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(54,10,'2026-09-26',14,'13086.00','0.00',NULL,1,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:04'),
(55,10,'2026-09-26',14,'7695.00','0.00',NULL,1,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(56,10,'2026-09-26',14,'742.50','0.00',NULL,1,9,1,1,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(57,10,'2026-09-26',32,'0.00','39395.62',NULL,1,NULL,1,1,NULL,'Picked up by Glenn Abad (AL-00001)',0,NULL,'2026-11-25 21:50:04'),
(93,23,'2026-09-30',14,'0.00','4260.00',NULL,NULL,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(94,23,'2026-09-30',58,'0.00','360.00',NULL,NULL,NULL,1,NULL,NULL,'Cutting and packing labor',0,NULL,'2026-11-25 21:50:04'),
(95,23,'2026-09-30',14,'1418.21','0.00',NULL,NULL,4,1,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(96,23,'2026-09-30',14,'1131.60','0.00',NULL,NULL,5,1,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(97,23,'2026-09-30',14,'618.43','0.00',NULL,NULL,6,1,NULL,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(98,23,'2026-09-30',14,'1205.76','0.00',NULL,NULL,3,1,NULL,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(99,23,'2026-09-30',14,'114.00','0.00',NULL,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(100,23,'2026-09-30',14,'132.00','0.00',NULL,NULL,8,1,NULL,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(101,11,'2026-10-04',14,'16450.00','0.00',NULL,2,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(102,11,'2026-10-04',14,'8550.00','0.00',NULL,2,6,1,1,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(103,11,'2026-10-04',14,'7776.00','0.00',NULL,2,10,1,1,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:04'),
(104,11,'2026-10-04',32,'0.00','32776.00',NULL,2,NULL,1,1,NULL,'Picked up by Glenn Abad (AL-00002)',0,NULL,'2026-11-25 21:50:04'),
(105,12,'2026-10-11',14,'21132.44','0.00',NULL,1,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(106,12,'2026-10-11',14,'13690.00','0.00',NULL,1,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(107,12,'2026-10-11',14,'3135.00','0.00',NULL,1,7,1,1,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(108,12,'2026-10-11',32,'0.00','37957.44',NULL,1,NULL,1,1,NULL,'Picked up by Glenn Abad (AL-00003)',0,NULL,'2026-11-25 21:50:04'),
(109,13,'2026-10-26',14,'17483.04','0.00',NULL,1,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(110,13,'2026-10-26',14,'13722.00','0.00',NULL,1,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:04'),
(111,13,'2026-10-26',14,'7830.00','0.00',NULL,1,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(112,13,'2026-10-26',14,'625.00','0.00',NULL,1,9,1,1,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(113,13,'2026-10-26',32,'0.00','39660.04',NULL,1,NULL,1,1,NULL,'Picked up by Glenn Abad (AL-00004)',0,NULL,'2026-11-25 21:50:04'),
(136,24,'2026-10-30',14,'0.00','2840.00',NULL,NULL,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(137,24,'2026-10-30',58,'0.00','240.00',NULL,NULL,NULL,1,NULL,NULL,'Cutting and packing labor',0,NULL,'2026-11-25 21:50:04'),
(138,24,'2026-10-30',14,'978.62','0.00',NULL,NULL,4,1,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(139,24,'2026-10-30',14,'751.93','0.00',NULL,NULL,5,1,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(140,24,'2026-10-30',14,'410.94','0.00',NULL,NULL,6,1,NULL,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(141,24,'2026-10-30',14,'774.51','0.00',NULL,NULL,3,1,NULL,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(142,24,'2026-10-30',14,'76.00','0.00',NULL,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(143,24,'2026-10-30',14,'88.00','0.00',NULL,NULL,8,1,NULL,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(144,14,'2026-11-04',14,'13491.80','0.00',NULL,2,1,3,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(145,14,'2026-11-04',14,'10675.00','0.00',NULL,2,5,3,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(146,14,'2026-11-04',14,'1870.00','0.00',NULL,2,8,3,1,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(147,14,'2026-11-04',14,'6935.00','0.00',NULL,2,11,3,1,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:04'),
(148,14,'2026-11-04',32,'0.00','32971.80',NULL,2,NULL,3,1,NULL,'Picked up by Glenn Abad (AL-00005)',0,NULL,'2026-11-25 21:50:04'),
(149,15,'2026-11-16',14,'17642.08','0.00',NULL,1,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(150,15,'2026-11-16',14,'12210.00','0.00',NULL,1,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(151,15,'2026-11-16',14,'7965.00','0.00',NULL,1,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(152,15,'2026-11-16',32,'0.00','37817.08',NULL,1,NULL,1,1,NULL,'Picked up by Glenn Abad (AL-00006)',0,NULL,'2026-11-25 21:50:04'),
(153,16,'2026-11-23',14,'14340.58','0.00',NULL,1,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(154,16,'2026-11-23',14,'10944.00','0.00',NULL,1,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:04'),
(155,16,'2026-11-23',14,'2280.00','0.00',NULL,1,7,1,1,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(156,16,'2026-11-23',14,'510.00','0.00',NULL,1,9,1,1,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(157,16,'2026-11-23',32,'0.00','28074.58',NULL,1,NULL,1,1,NULL,'Picked up by Glenn Abad (AL-00007)',0,NULL,'2026-11-25 21:50:04'),
(158,26,'2026-10-16',14,'0.00','1398.85',NULL,NULL,5,1,NULL,NULL,'Party packs for the weekend',0,NULL,'2026-11-25 21:50:04'),
(159,26,'2026-10-16',14,'0.00','3019.11',NULL,NULL,6,1,NULL,NULL,'Party packs for the weekend',0,NULL,'2026-11-25 21:50:04'),
(160,26,'2026-10-16',14,'0.00','52.80',NULL,NULL,12,1,NULL,NULL,'Party packs for the weekend',0,NULL,'2026-11-25 21:50:04'),
(161,26,'2026-10-16',58,'0.00','50.00',NULL,NULL,13,1,NULL,NULL,'Party packs for the weekend',0,NULL,'2026-11-25 21:50:04'),
(162,26,'2026-10-16',14,'4520.76','0.00',NULL,NULL,14,1,NULL,NULL,'Party packs for the weekend',0,NULL,'2026-11-25 21:50:04'),
(163,31,'2026-10-01',45,'0.00','8408.40',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(164,31,'2026-10-01',34,'0.00','1009.01',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(165,31,'2026-10-01',55,'7224.31','0.00',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(166,31,'2026-10-01',14,'0.00','7224.31',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(167,31,'2026-10-01',45,'0.00','6336.05',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(168,31,'2026-10-01',34,'0.00','760.33',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(169,31,'2026-10-01',55,'5446.47','0.00',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(170,31,'2026-10-01',14,'0.00','5446.47',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(171,31,'2026-10-01',47,'0.00','350.00',6,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(172,31,'2026-10-01',34,'0.00','42.00',6,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(173,31,'2026-10-01',11,'16905.79','0.00',6,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(174,32,'2026-10-08',45,'0.00','8174.10',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(175,32,'2026-10-08',34,'0.00','980.89',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(176,32,'2026-10-08',55,'7023.01','0.00',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(177,32,'2026-10-08',14,'0.00','7023.01',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(178,32,'2026-10-08',47,'0.00','350.00',6,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(179,32,'2026-10-08',34,'0.00','42.00',6,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(180,32,'2026-10-08',11,'9546.99','0.00',6,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(181,33,'2026-10-12',45,'0.00','6119.85',7,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(182,33,'2026-10-12',34,'0.00','734.38',7,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(183,33,'2026-10-12',55,'5258.04','0.00',7,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(184,33,'2026-10-12',14,'0.00','5258.04',7,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(185,33,'2026-10-12',45,'0.00','6662.85',7,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(186,33,'2026-10-12',34,'0.00','799.54',7,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(187,33,'2026-10-12',55,'5418.80','0.00',7,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(188,33,'2026-10-12',14,'0.00','5418.80',7,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(189,33,'2026-10-12',47,'0.00','350.00',7,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(190,33,'2026-10-12',34,'0.00','42.00',7,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(191,33,'2026-10-12',11,'14708.62','0.00',7,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(192,34,'2026-10-06',45,'0.00','3150.00',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(193,34,'2026-10-06',34,'0.00','378.00',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(194,34,'2026-10-06',55,'2551.76','0.00',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(195,34,'2026-10-06',14,'0.00','2551.76',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(196,34,'2026-10-06',45,'0.00','2280.00',8,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(197,34,'2026-10-06',34,'0.00','273.60',8,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(198,34,'2026-10-06',55,'1848.14','0.00',8,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(199,34,'2026-10-06',14,'0.00','1848.14',8,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(200,34,'2026-10-06',45,'0.00','520.00',8,NULL,7,1,1,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(201,34,'2026-10-06',34,'0.00','62.40',8,NULL,7,1,1,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(202,34,'2026-10-06',55,'380.00','0.00',8,NULL,7,1,1,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(203,34,'2026-10-06',14,'0.00','380.00',8,NULL,7,1,1,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(204,34,'2026-10-06',45,'0.00','240.00',8,NULL,9,1,1,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(205,34,'2026-10-06',55,'150.00','0.00',8,NULL,9,1,1,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(206,34,'2026-10-06',14,'0.00','150.00',8,NULL,9,1,1,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:04'),
(207,34,'2026-10-06',11,'6904.00','0.00',8,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(208,35,'2026-10-20',45,'0.00','2580.00',8,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(209,35,'2026-10-20',34,'0.00','309.60',8,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(210,35,'2026-10-20',55,'2098.28','0.00',8,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(211,35,'2026-10-20',14,'0.00','2098.28',8,NULL,5,1,1,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(212,35,'2026-10-20',45,'0.00','1880.00',8,NULL,6,1,1,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(213,35,'2026-10-20',34,'0.00','225.60',8,NULL,6,1,1,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(214,35,'2026-10-20',55,'1509.56','0.00',8,NULL,6,1,1,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(215,35,'2026-10-20',14,'0.00','1509.56',8,NULL,6,1,1,NULL,'Chicken Wings, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(216,35,'2026-10-20',46,'0.00','180.00',8,NULL,15,1,1,NULL,'Custom Cutting Service',0,NULL,'2026-11-25 21:50:04'),
(217,35,'2026-10-20',34,'0.00','21.60',8,NULL,15,1,1,NULL,'Custom Cutting Service',0,NULL,'2026-11-25 21:50:04'),
(218,35,'2026-10-20',11,'5196.80','0.00',8,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(219,36,'2026-10-14',45,'0.00','2091.25',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(220,36,'2026-10-14',34,'0.00','250.95',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(221,36,'2026-10-14',55,'1694.08','0.00',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(222,36,'2026-10-14',14,'0.00','1694.08',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(223,36,'2026-10-14',45,'0.00','3302.40',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(224,36,'2026-10-14',34,'0.00','396.29',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(225,36,'2026-10-14',55,'2685.79','0.00',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(226,36,'2026-10-14',14,'0.00','2685.79',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(227,36,'2026-10-14',45,'0.00','1824.00',9,NULL,4,3,3,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(228,36,'2026-10-14',34,'0.00','218.88',9,NULL,4,3,3,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(229,36,'2026-10-14',55,'1478.51','0.00',9,NULL,4,3,3,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(230,36,'2026-10-14',14,'0.00','1478.51',9,NULL,4,3,3,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(231,36,'2026-10-14',11,'8083.77','0.00',9,NULL,NULL,3,3,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(232,37,'2026-11-07',45,'0.00','8501.50',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(233,37,'2026-11-07',34,'0.00','1020.18',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(234,37,'2026-11-07',55,'6886.92','0.00',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(235,37,'2026-11-07',14,'0.00','6886.92',9,NULL,1,3,3,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:04'),
(236,37,'2026-11-07',45,'0.00','2150.00',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(237,37,'2026-11-07',34,'0.00','258.00',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(238,37,'2026-11-07',55,'1748.56','0.00',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(239,37,'2026-11-07',14,'0.00','1748.56',9,NULL,5,3,3,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(240,37,'2026-11-07',47,'0.00','350.00',9,NULL,17,3,3,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(241,37,'2026-11-07',34,'0.00','42.00',9,NULL,17,3,3,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:04'),
(242,37,'2026-11-07',11,'12321.68','0.00',9,NULL,NULL,3,3,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(243,38,'2026-10-16',45,'0.00','4560.00',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(244,38,'2026-10-16',34,'0.00','547.20',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(245,38,'2026-10-16',55,'3696.28','0.00',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(246,38,'2026-10-16',14,'0.00','3696.28',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(247,38,'2026-10-16',45,'0.00','2520.00',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(248,38,'2026-10-16',34,'0.00','302.40',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(249,38,'2026-10-16',55,'2024.03','0.00',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(250,38,'2026-10-16',14,'0.00','2024.03',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(251,38,'2026-10-16',11,'7929.60','0.00',10,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:04'),
(252,39,'2026-10-23',45,'0.00','3420.00',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(253,39,'2026-10-23',34,'0.00','410.40',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(254,39,'2026-10-23',55,'2772.21','0.00',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(255,39,'2026-10-23',14,'0.00','2772.21',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(256,39,'2026-10-23',45,'0.00','2016.00',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(257,39,'2026-10-23',34,'0.00','241.92',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(258,39,'2026-10-23',55,'1619.23','0.00',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(259,39,'2026-10-23',14,'0.00','1619.23',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:04'),
(260,39,'2026-10-23',11,'6088.32','0.00',10,NULL,NULL,1,1,NULL,'Weekly hospital kitchen delivery',0,NULL,'2026-11-25 21:50:04'),
(261,40,'2026-10-23',45,'0.00','3208.80',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(262,40,'2026-10-23',34,'0.00','385.06',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(263,40,'2026-10-23',55,'2707.70','0.00',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(264,40,'2026-10-23',14,'0.00','2707.70',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(265,40,'2026-10-23',11,'3593.86','0.00',11,NULL,NULL,1,1,NULL,'Weekly market stall delivery',0,NULL,'2026-11-25 21:50:05'),
(266,41,'2026-11-13',45,'0.00','3420.00',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(267,41,'2026-11-13',34,'0.00','410.40',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(268,41,'2026-11-13',55,'2772.21','0.00',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(269,41,'2026-11-13',14,'0.00','2772.21',10,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(270,41,'2026-11-13',45,'0.00','2016.00',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(271,41,'2026-11-13',34,'0.00','241.92',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(272,41,'2026-11-13',55,'1619.23','0.00',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(273,41,'2026-11-13',14,'0.00','1619.23',10,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(274,41,'2026-11-13',11,'6088.32','0.00',10,NULL,NULL,1,1,NULL,'Weekly hospital kitchen delivery',0,NULL,'2026-11-25 21:50:05'),
(275,42,'2026-11-13',45,'0.00','4090.80',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(276,42,'2026-11-13',34,'0.00','490.90',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(277,42,'2026-11-13',55,'3451.96','0.00',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(278,42,'2026-11-13',14,'0.00','3451.96',11,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(279,42,'2026-11-13',11,'4581.70','0.00',11,NULL,NULL,1,1,NULL,'Weekly market stall delivery',0,NULL,'2026-11-25 21:50:05'),
(280,43,'2026-10-31',45,'0.00','12160.50',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(281,43,'2026-10-31',34,'0.00','1459.26',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(282,43,'2026-10-31',55,'10448.04','0.00',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(283,43,'2026-10-31',14,'0.00','10448.04',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(284,43,'2026-10-31',45,'0.00','8230.65',6,NULL,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:05'),
(285,43,'2026-10-31',34,'0.00','987.68',6,NULL,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:05'),
(286,43,'2026-10-31',55,'6673.50','0.00',6,NULL,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:05'),
(287,43,'2026-10-31',14,'0.00','6673.50',6,NULL,2,1,1,NULL,'Big Bird Chicken, Fresh Chilled, Vac',0,NULL,'2026-11-25 21:50:05'),
(288,43,'2026-10-31',45,'0.00','3072.00',6,NULL,11,1,1,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(289,43,'2026-10-31',34,'0.00','368.64',6,NULL,11,1,1,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(290,43,'2026-10-31',55,'2280.00','0.00',6,NULL,11,1,1,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(291,43,'2026-10-31',14,'0.00','2280.00',6,NULL,11,1,1,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(292,43,'2026-10-31',49,'153.60','0.00',6,NULL,20,1,1,NULL,'5% Volume Discount',0,NULL,'2026-11-25 21:50:05'),
(293,43,'2026-10-31',34,'18.43','0.00',6,NULL,20,1,1,NULL,'5% Volume Discount',0,NULL,'2026-11-25 21:50:05'),
(294,43,'2026-10-31',11,'26106.70','0.00',6,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(295,44,'2026-11-19',45,'0.00','10320.75',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(296,44,'2026-11-19',34,'0.00','1238.49',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(297,44,'2026-11-19',55,'8867.37','0.00',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(298,44,'2026-11-19',14,'0.00','8867.37',6,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(299,44,'2026-11-19',45,'0.00','49.45',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(300,44,'2026-11-19',34,'0.00','5.93',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(301,44,'2026-11-19',55,'42.51','0.00',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(302,44,'2026-11-19',14,'0.00','42.51',6,NULL,4,1,1,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(303,44,'2026-11-19',47,'0.00','350.00',6,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:05'),
(304,44,'2026-11-19',34,'0.00','42.00',6,NULL,17,1,1,NULL,'Delivery Fee (reefer)',0,NULL,'2026-11-25 21:50:05'),
(305,44,'2026-11-19',11,'12006.62','0.00',6,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(306,45,'2026-11-21',45,'0.00','4375.00',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(307,45,'2026-11-21',34,'0.00','525.00',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(308,45,'2026-11-21',55,'3544.11','0.00',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(309,45,'2026-11-21',14,'0.00','3544.11',8,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(310,45,'2026-11-21',45,'0.00','435.00',8,NULL,8,1,1,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(311,45,'2026-11-21',34,'0.00','52.20',8,NULL,8,1,1,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(312,45,'2026-11-21',55,'330.00','0.00',8,NULL,8,1,1,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(313,45,'2026-11-21',14,'0.00','330.00',8,NULL,8,1,1,NULL,'Chicken Gizzard, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(314,45,'2026-11-21',11,'5387.20','0.00',8,NULL,NULL,1,1,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(315,47,'2026-10-17',45,'0.00','325.00',13,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(316,47,'2026-10-17',34,'0.00','39.00',13,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(317,47,'2026-10-17',55,'237.50','0.00',13,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(318,47,'2026-10-17',14,'0.00','237.50',13,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(319,47,'2026-10-17',45,'0.00','1085.00',13,NULL,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(320,47,'2026-10-17',34,'0.00','130.20',13,NULL,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(321,47,'2026-10-17',55,'878.94','0.00',13,NULL,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(322,47,'2026-10-17',14,'0.00','878.94',13,NULL,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(323,47,'2026-10-17',45,'0.00','80.00',13,NULL,9,1,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(324,47,'2026-10-17',55,'50.00','0.00',13,NULL,9,1,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(325,47,'2026-10-17',14,'0.00','50.00',13,NULL,9,1,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(326,47,'2026-10-17',7,'1659.20','0.00',13,NULL,NULL,1,NULL,NULL,'Phone order',0,NULL,'2026-11-25 21:50:05'),
(327,48,'2026-10-28',7,'60000.00','0.00',6,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(328,48,'2026-10-28',11,'0.00','60000.00',6,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(329,49,'2026-10-22',5,'7922.09','0.00',9,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(330,49,'2026-10-22',49,'161.68','0.00',9,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(331,49,'2026-10-22',11,'0.00','8083.77',9,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(332,50,'2026-10-19',7,'7404.00','0.00',8,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(333,50,'2026-10-19',11,'0.00','7404.00',8,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(334,51,'2026-10-30',7,'3964.80','0.00',10,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(335,51,'2026-10-30',11,'0.00','3964.80',10,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(336,52,'2026-10-22',45,'0.00','3162.25',12,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(337,52,'2026-10-22',34,'0.00','379.47',12,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(338,52,'2026-10-22',55,'2561.68','0.00',12,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(339,52,'2026-10-22',14,'0.00','2561.68',12,NULL,1,1,1,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(340,52,'2026-10-22',45,'0.00','1680.00',12,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(341,52,'2026-10-22',34,'0.00','201.60',12,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(342,52,'2026-10-22',55,'1349.35','0.00',12,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(343,52,'2026-10-22',14,'0.00','1349.35',12,NULL,3,1,1,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(344,52,'2026-10-22',11,'5423.32','0.00',12,NULL,NULL,1,1,NULL,'Feeding program, barangay day care centers',0,NULL,'2026-11-25 21:50:05'),
(345,53,'2026-11-13',7,'5132.79','0.00',12,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-11-25 21:50:05'),
(346,53,'2026-11-13',16,'48.42','0.00',12,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-11-25 21:50:05'),
(347,53,'2026-11-13',17,'242.11','0.00',12,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-11-25 21:50:05'),
(348,53,'2026-11-13',11,'0.00','5423.32',12,NULL,NULL,NULL,NULL,NULL,'5% VAT and 1% withheld; BIR Form 2307 to follow',0,NULL,'2026-11-25 21:50:05'),
(349,54,'2026-10-09',48,'390.00','0.00',8,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(350,54,'2026-10-09',34,'46.80','0.00',8,NULL,7,1,NULL,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(351,54,'2026-10-09',11,'0.00','436.80',8,NULL,NULL,1,NULL,NULL,'Returned 3 kg liver, not frozen on arrival',0,NULL,'2026-11-25 21:50:05'),
(352,55,'2026-11-10',52,'0.00','200.00',11,NULL,19,NULL,NULL,NULL,'Late Payment Fee',0,NULL,'2026-11-25 21:50:05'),
(353,55,'2026-11-10',11,'200.00','0.00',11,NULL,NULL,NULL,NULL,NULL,'Late payment fee',0,NULL,'2026-11-25 21:50:05'),
(354,56,'2026-11-24',52,'0.00','86.40',11,NULL,NULL,NULL,NULL,NULL,'Finance charge (12% p.a.)',0,NULL,'2026-11-25 21:50:05'),
(355,56,'2026-11-24',11,'86.40','0.00',11,NULL,NULL,NULL,NULL,NULL,'Finance charge on overdue balance',0,NULL,'2026-11-25 21:50:05'),
(356,57,'2026-09-12',60,'95000.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-11-25 21:50:05'),
(357,57,'2026-09-12',15,'11400.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-11-25 21:50:05'),
(358,57,'2026-09-12',5,'0.00','106400.00',NULL,5,NULL,NULL,NULL,NULL,'Cold storage and outlet rent',1,1,'2026-11-25 21:50:05'),
(359,58,'2026-10-12',60,'95000.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-11-25 21:50:05'),
(360,58,'2026-10-12',15,'11400.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-11-25 21:50:05'),
(361,58,'2026-10-12',5,'0.00','106400.00',NULL,5,NULL,NULL,NULL,NULL,'Cold storage and outlet rent',0,NULL,'2026-11-25 21:50:05'),
(362,59,'2026-11-11',60,'95000.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-11-25 21:50:05'),
(363,59,'2026-11-11',15,'11400.00','0.00',NULL,5,NULL,NULL,NULL,NULL,'Monthly rent',0,NULL,'2026-11-25 21:50:05'),
(364,59,'2026-11-11',5,'0.00','106400.00',NULL,5,NULL,NULL,NULL,NULL,'Cold storage and outlet rent',0,NULL,'2026-11-25 21:50:05'),
(365,60,'2026-09-26',61,'86450.75','0.00',NULL,4,NULL,NULL,NULL,NULL,'Electricity, cold storage',0,NULL,'2026-11-25 21:50:05'),
(366,60,'2026-09-26',15,'10374.09','0.00',NULL,4,NULL,NULL,NULL,NULL,'Electricity, cold storage',0,NULL,'2026-11-25 21:50:05'),
(367,60,'2026-09-26',32,'0.00','96824.84',NULL,4,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(368,61,'2026-10-26',61,'92230.40','0.00',NULL,4,NULL,NULL,NULL,NULL,'Electricity, cold storage',0,NULL,'2026-11-25 21:50:05');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(369,61,'2026-10-26',15,'11067.65','0.00',NULL,4,NULL,NULL,NULL,NULL,'Electricity, cold storage',0,NULL,'2026-11-25 21:50:05'),
(370,61,'2026-10-26',32,'0.00','103298.05',NULL,4,NULL,NULL,NULL,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(371,62,'2026-10-01',66,'45000.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Professional fees',0,NULL,'2026-11-25 21:50:05'),
(372,62,'2026-10-01',15,'5400.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Professional fees',0,NULL,'2026-11-25 21:50:05'),
(373,62,'2026-10-01',32,'0.00','50400.00',NULL,8,NULL,NULL,NULL,NULL,'Quarterly bookkeeping review',0,NULL,'2026-11-25 21:50:05'),
(374,63,'2026-09-25',64,'6800.00','0.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-11-25 21:50:05'),
(375,63,'2026-09-25',15,'816.00','0.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-11-25 21:50:05'),
(376,63,'2026-09-25',3,'0.00','7616.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel for the reefer truck',0,NULL,'2026-11-25 21:50:05'),
(377,64,'2026-10-23',64,'6800.00','0.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-11-25 21:50:05'),
(378,64,'2026-10-23',15,'816.00','0.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-11-25 21:50:05'),
(379,64,'2026-10-23',3,'0.00','7616.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel for the reefer truck',0,NULL,'2026-11-25 21:50:05'),
(380,65,'2026-11-20',64,'6800.00','0.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-11-25 21:50:05'),
(381,65,'2026-11-20',15,'816.00','0.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel',0,NULL,'2026-11-25 21:50:05'),
(382,65,'2026-11-20',3,'0.00','7616.00',NULL,6,NULL,NULL,NULL,NULL,'Diesel for the reefer truck',0,NULL,'2026-11-25 21:50:05'),
(383,66,'2026-09-29',14,'0.00','1704.00',NULL,1,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(384,66,'2026-09-29',15,'0.00','204.48',NULL,1,1,1,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(385,66,'2026-09-29',32,'1908.48','0.00',NULL,1,NULL,1,NULL,NULL,'Returned 12 kg whole chicken, warm on arrival',0,NULL,'2026-11-25 21:50:05'),
(386,67,'2026-10-04',32,'57636.74','0.00',NULL,1,NULL,NULL,NULL,NULL,'Payment of NPC-INV-10231',0,NULL,'2026-11-25 21:50:05'),
(387,67,'2026-10-04',5,'0.00','57636.74',NULL,1,NULL,NULL,NULL,NULL,'Payment of NPC-INV-10231',0,NULL,'2026-11-25 21:50:05'),
(388,68,'2026-10-04',32,'96824.84','0.00',NULL,4,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-11-25 21:50:05'),
(389,68,'2026-10-04',5,'0.00','96824.84',NULL,4,NULL,NULL,NULL,NULL,'Electricity',0,NULL,'2026-11-25 21:50:05'),
(390,69,'2026-11-05',32,'50400.00','0.00',NULL,8,NULL,NULL,NULL,NULL,'Payment of APC-2231, 2% withheld',0,NULL,'2026-11-25 21:50:05'),
(391,69,'2026-11-05',5,'0.00','49500.00',NULL,8,NULL,NULL,NULL,NULL,'Payment of APC-2231, 2% withheld',0,NULL,'2026-11-25 21:50:05'),
(392,69,'2026-11-05',35,'0.00','900.00',NULL,8,NULL,NULL,NULL,NULL,'Payment of APC-2231, 2% withheld',0,NULL,'2026-11-25 21:50:05'),
(393,70,'2026-11-11',19,'150000.00','0.00',NULL,2,NULL,NULL,NULL,NULL,'Advance on the holiday season allocation',0,NULL,'2026-11-25 21:50:05'),
(394,70,'2026-11-11',5,'0.00','150000.00',NULL,2,NULL,NULL,NULL,NULL,'Advance on the holiday season allocation',0,NULL,'2026-11-25 21:50:05'),
(397,73,'2026-11-01',14,'0.00','142.50',NULL,NULL,7,1,NULL,NULL,'Spoilage',0,NULL,'2026-11-25 21:50:05'),
(398,73,'2026-11-01',57,'142.50','0.00',NULL,NULL,7,1,NULL,NULL,'Spoilage',0,NULL,'2026-11-25 21:50:05'),
(399,74,'2026-11-17',14,'0.00','96.00',NULL,NULL,10,2,NULL,NULL,'Count difference (2 packs torn)',0,NULL,'2026-11-25 21:50:05'),
(400,74,'2026-11-17',57,'96.00','0.00',NULL,NULL,10,2,NULL,NULL,'Count difference (2 packs torn)',0,NULL,'2026-11-25 21:50:05'),
(401,74,'2026-11-17',14,'165.00','0.00',NULL,NULL,12,2,NULL,NULL,'Count difference (bags found in the store room)',0,NULL,'2026-11-25 21:50:05'),
(402,74,'2026-11-17',57,'0.00','165.00',NULL,NULL,12,2,NULL,NULL,'Count difference (bags found in the store room)',0,NULL,'2026-11-25 21:50:05'),
(403,75,'2026-10-11',3,'15000.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Replenish petty cash',0,NULL,'2026-11-25 21:50:05'),
(404,75,'2026-10-11',5,'0.00','15000.00',NULL,NULL,NULL,NULL,NULL,NULL,'Replenish petty cash',0,NULL,'2026-11-25 21:50:05'),
(405,76,'2026-10-26',69,'1250.00','0.00',NULL,NULL,NULL,NULL,1,1,'Toll and parking',0,NULL,'2026-11-25 21:50:05'),
(406,76,'2026-10-26',3,'0.00','1250.00',NULL,NULL,NULL,NULL,1,1,'Toll and parking, pick-ups at Pili',0,NULL,'2026-11-25 21:50:05'),
(407,77,'2026-11-13',69,'480.00','0.00',NULL,NULL,NULL,NULL,2,NULL,'Fares for small deliveries',0,NULL,'2026-11-25 21:50:05'),
(408,77,'2026-11-13',3,'0.00','480.00',NULL,NULL,NULL,NULL,2,NULL,'Small deliveries, Naga Outlet',0,NULL,'2026-11-25 21:50:05'),
(409,78,'2026-11-01',7,'0.00','1659.20',13,NULL,NULL,NULL,NULL,NULL,'Sales Receipt SR-00001',0,NULL,'2026-11-25 21:50:05'),
(410,78,'2026-11-01',7,'0.00','60000.00',6,NULL,NULL,NULL,NULL,NULL,'Customer Payment PMT-00001',0,NULL,'2026-11-25 21:50:05'),
(411,78,'2026-11-01',7,'0.00','7404.00',8,NULL,NULL,NULL,NULL,NULL,'Customer Payment PMT-00003',0,NULL,'2026-11-25 21:50:05'),
(412,78,'2026-11-01',7,'0.00','3964.80',10,NULL,NULL,NULL,NULL,NULL,'Customer Payment PMT-00004',0,NULL,'2026-11-25 21:50:05'),
(413,78,'2026-11-01',53,'0.00','1250.00',NULL,NULL,NULL,NULL,NULL,NULL,'Interest on time deposit',0,NULL,'2026-11-25 21:50:05'),
(414,78,'2026-11-01',5,'74278.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Deposit',0,NULL,'2026-11-25 21:50:05'),
(415,79,'2026-09-30',68,'2708.33','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Computer and POS Equipment',0,NULL,'2026-11-25 21:50:05'),
(416,79,'2026-09-30',30,'0.00','2708.33',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Computer and POS Equipment',0,NULL,'2026-11-25 21:50:05'),
(417,79,'2026-09-30',68,'15446.67','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Production Machinery (usage-based)',0,NULL,'2026-11-25 21:50:05'),
(418,79,'2026-09-30',24,'0.00','15446.67',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Production Machinery (usage-based)',0,NULL,'2026-11-25 21:50:05'),
(419,79,'2026-09-30',68,'81666.67','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Transportation Equipment',0,NULL,'2026-11-25 21:50:05'),
(420,79,'2026-09-30',26,'0.00','81666.67',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Transportation Equipment',0,NULL,'2026-11-25 21:50:05'),
(421,80,'2026-10-31',68,'2708.33','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Computer and POS Equipment',0,NULL,'2026-11-25 21:50:05'),
(422,80,'2026-10-31',30,'0.00','2708.33',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Computer and POS Equipment',0,NULL,'2026-11-25 21:50:05'),
(423,80,'2026-10-31',68,'15580.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Production Machinery (usage-based)',0,NULL,'2026-11-25 21:50:05'),
(424,80,'2026-10-31',24,'0.00','15580.00',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Production Machinery (usage-based)',0,NULL,'2026-11-25 21:50:05'),
(425,80,'2026-10-31',68,'81666.67','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Depreciation - Transportation Equipment',0,NULL,'2026-11-25 21:50:05'),
(426,80,'2026-10-31',26,'0.00','81666.67',NULL,NULL,NULL,NULL,NULL,NULL,'Accumulated depreciation - Transportation Equipment',0,NULL,'2026-11-25 21:50:05'),
(427,81,'2026-09-30',67,'150.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Service charge',0,NULL,'2026-11-25 21:50:05'),
(428,81,'2026-09-30',5,'0.00','150.00',NULL,NULL,NULL,NULL,NULL,NULL,'Service charge',1,1,'2026-11-25 21:50:05'),
(429,82,'2026-11-24',45,'0.00','595.00',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(430,82,'2026-11-24',34,'0.00','71.40',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(431,82,'2026-11-24',55,'481.97','0.00',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(432,82,'2026-11-24',14,'0.00','481.97',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(433,82,'2026-11-24',45,'0.00','130.00',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(434,82,'2026-11-24',34,'0.00','15.60',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(435,82,'2026-11-24',55,'96.00','0.00',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(436,82,'2026-11-24',14,'0.00','96.00',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(437,82,'2026-11-24',2,'812.00','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(438,83,'2026-11-24',45,'0.00','1533.40',11,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(439,83,'2026-11-24',34,'0.00','184.01',11,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(440,83,'2026-11-24',55,'1278.64','0.00',11,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(441,83,'2026-11-24',14,'0.00','1278.64',11,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(442,83,'2026-11-24',8,'1717.41','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(443,84,'2026-11-24',45,'0.00','156.00',NULL,NULL,7,2,2,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(444,84,'2026-11-24',34,'0.00','18.72',NULL,NULL,7,2,2,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(445,84,'2026-11-24',55,'114.00','0.00',NULL,NULL,7,2,2,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(446,84,'2026-11-24',14,'0.00','114.00',NULL,NULL,7,2,2,NULL,'Chicken Liver, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(447,84,'2026-11-24',45,'0.00','128.00',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(448,84,'2026-11-24',34,'0.00','15.36',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(449,84,'2026-11-24',55,'95.00','0.00',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(450,84,'2026-11-24',14,'0.00','95.00',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(451,84,'2026-11-24',9,'318.08','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(457,86,'2026-11-24',45,'0.00','720.00',NULL,NULL,14,2,2,NULL,'Party Pack (2 kg wings, 1 kg drumsticks)',0,NULL,'2026-11-25 21:50:05'),
(458,86,'2026-11-24',34,'0.00','86.40',NULL,NULL,14,2,2,NULL,'Party Pack (2 kg wings, 1 kg drumsticks)',0,NULL,'2026-11-25 21:50:05'),
(459,86,'2026-11-24',55,'565.10','0.00',NULL,NULL,14,2,2,NULL,'Party Pack (2 kg wings, 1 kg drumsticks)',0,NULL,'2026-11-25 21:50:05'),
(460,86,'2026-11-24',14,'0.00','565.10',NULL,NULL,14,2,2,NULL,'Party Pack (2 kg wings, 1 kg drumsticks)',0,NULL,'2026-11-25 21:50:05'),
(461,86,'2026-11-24',45,'0.00','336.00',NULL,NULL,3,2,2,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(462,86,'2026-11-24',34,'0.00','40.32',NULL,NULL,3,2,2,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(463,86,'2026-11-24',55,'269.87','0.00',NULL,NULL,3,2,2,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(464,86,'2026-11-24',14,'0.00','269.87',NULL,NULL,3,2,2,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(465,86,'2026-11-24',2,'1182.72','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(466,87,'2026-11-24',48,'65.00','0.00',NULL,NULL,10,2,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(467,87,'2026-11-24',34,'7.80','0.00',NULL,NULL,10,2,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(468,87,'2026-11-24',14,'48.00','0.00',NULL,NULL,10,2,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(469,87,'2026-11-24',55,'0.00','48.00',NULL,NULL,10,2,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(470,87,'2026-11-24',2,'0.00','72.80',NULL,NULL,NULL,2,NULL,NULL,'Return: pack thawed',0,NULL,'2026-11-25 21:50:05'),
(471,88,'2026-11-24',2,'0.00','20.00',NULL,NULL,NULL,NULL,NULL,NULL,'Drawer count difference',0,NULL,'2026-11-25 21:50:05'),
(472,88,'2026-11-24',71,'20.00','0.00',NULL,NULL,NULL,NULL,NULL,NULL,'Cash over and short',0,NULL,'2026-11-25 21:50:05'),
(473,89,'2026-11-25',45,'0.00','490.00',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(474,89,'2026-11-25',34,'0.00','58.80',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(475,89,'2026-11-25',55,'396.92','0.00',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05');
INSERT INTO `journal_lines` (`id`,`txn_id`,`txn_date`,`account_id`,`debit`,`credit`,`customer_id`,`vendor_id`,`item_id`,`site_id`,`class_id`,`other_name_id`,`memo`,`cleared`,`reconciliation_id`,`created_at`) VALUES
(476,89,'2026-11-25',14,'0.00','396.92',NULL,NULL,1,2,2,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(477,89,'2026-11-25',45,'0.00','40.00',NULL,NULL,9,2,2,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(478,89,'2026-11-25',55,'25.00','0.00',NULL,NULL,9,2,2,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(479,89,'2026-11-25',14,'0.00','25.00',NULL,NULL,9,2,2,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(480,89,'2026-11-25',2,'588.80','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(481,90,'2026-11-25',45,'0.00','260.00',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(482,90,'2026-11-25',34,'0.00','31.20',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(483,90,'2026-11-25',55,'192.00','0.00',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(484,90,'2026-11-25',14,'0.00','192.00',NULL,NULL,10,2,2,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(485,90,'2026-11-25',45,'0.00','256.00',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(486,90,'2026-11-25',34,'0.00','30.72',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(487,90,'2026-11-25',55,'190.00','0.00',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(488,90,'2026-11-25',14,'0.00','190.00',NULL,NULL,11,2,2,NULL,'Chicken Nuggets 500 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(489,90,'2026-11-25',50,'36.00','0.00',NULL,NULL,NULL,2,2,NULL,'Price variance: Fiesta Bundle',0,NULL,'2026-11-25 21:50:05'),
(490,90,'2026-11-25',34,'4.32','0.00',NULL,NULL,NULL,2,2,NULL,'Price variance: Fiesta Bundle',0,NULL,'2026-11-25 21:50:05'),
(491,90,'2026-11-25',9,'537.60','0.00',NULL,NULL,NULL,2,2,NULL,NULL,0,NULL,'2026-11-25 21:50:05'),
(492,91,'2026-11-11',14,'0.00','11407.50',NULL,NULL,2,1,NULL,NULL,'Condemned, 5 expired crate(s)',0,NULL,'2026-11-25 21:50:05'),
(493,91,'2026-11-11',57,'11407.50','0.00',NULL,NULL,2,1,NULL,NULL,'Condemned, 5 expired crate(s)',0,NULL,'2026-11-25 21:50:05'),
(494,92,'2026-11-11',14,'0.00','20832.55',NULL,NULL,1,2,NULL,NULL,'Condemned, 12 expired crate(s)',0,NULL,'2026-11-25 21:50:05'),
(495,92,'2026-11-11',57,'20832.55','0.00',NULL,NULL,1,2,NULL,NULL,'Condemned, 12 expired crate(s)',0,NULL,'2026-11-25 21:50:05'),
(496,92,'2026-11-11',14,'0.00','8727.00',NULL,NULL,2,2,NULL,NULL,'Condemned, 4 expired crate(s)',0,NULL,'2026-11-25 21:50:05'),
(497,92,'2026-11-11',57,'8727.00','0.00',NULL,NULL,2,2,NULL,NULL,'Condemned, 4 expired crate(s)',0,NULL,'2026-11-25 21:50:05'),
(498,95,'2026-11-21',45,'0.00','2238.25',11,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(499,95,'2026-11-21',34,'0.00','268.59',11,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(500,95,'2026-11-21',55,'1813.07','0.00',11,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(501,95,'2026-11-21',14,'0.00','1813.07',11,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(502,95,'2026-11-21',45,'0.00','735.30',11,NULL,5,6,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(503,95,'2026-11-21',34,'0.00','88.24',11,NULL,5,6,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(504,95,'2026-11-21',55,'598.01','0.00',11,NULL,5,6,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(505,95,'2026-11-21',14,'0.00','598.01',11,NULL,5,6,NULL,NULL,'Chicken Drumstick, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(506,95,'2026-11-21',7,'3330.38','0.00',11,NULL,NULL,6,NULL,NULL,'Van sale, Naga public market',0,NULL,'2026-11-25 21:50:05'),
(507,96,'2026-11-21',45,'0.00','560.00',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(508,96,'2026-11-21',34,'0.00','67.20',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(509,96,'2026-11-21',55,'453.62','0.00',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(510,96,'2026-11-21',14,'0.00','453.62',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(511,96,'2026-11-21',45,'0.00','80.00',14,NULL,9,6,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(512,96,'2026-11-21',55,'50.00','0.00',14,NULL,9,6,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(513,96,'2026-11-21',14,'0.00','50.00',14,NULL,9,6,NULL,NULL,'Chicken Blood',0,NULL,'2026-11-25 21:50:05'),
(514,96,'2026-11-21',45,'0.00','390.00',14,NULL,10,6,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(515,96,'2026-11-21',34,'0.00','46.80',14,NULL,10,6,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(516,96,'2026-11-21',55,'288.00','0.00',14,NULL,10,6,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(517,96,'2026-11-21',14,'0.00','288.00',14,NULL,10,6,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack',0,NULL,'2026-11-25 21:50:05'),
(518,96,'2026-11-21',7,'1144.00','0.00',14,NULL,NULL,6,NULL,NULL,'Van sale, Barangay Concepcion',0,NULL,'2026-11-25 21:50:05'),
(519,97,'2026-11-21',14,'0.00','25.52',NULL,NULL,1,6,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(520,97,'2026-11-21',57,'25.52','0.00',NULL,NULL,1,6,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(521,98,'2026-11-21',14,'0.00','96.00',3,NULL,10,6,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack, crate 48 (shortage)',0,NULL,'2026-11-25 21:50:05'),
(522,98,'2026-11-21',12,'96.00','0.00',3,NULL,10,6,NULL,NULL,'Chicken Bola-Bola 250 g, Frozen, Pack, crate 48 (shortage)',0,NULL,'2026-11-25 21:50:05'),
(523,98,'2026-11-21',14,'0.00','12.50',3,NULL,9,6,NULL,NULL,'Chicken Blood (shortage)',0,NULL,'2026-11-25 21:50:05'),
(524,98,'2026-11-21',12,'12.50','0.00',3,NULL,9,6,NULL,NULL,'Chicken Blood (shortage)',0,NULL,'2026-11-25 21:50:05'),
(525,100,'2026-11-22',7,'54.25','0.00',3,NULL,NULL,NULL,NULL,NULL,'Shortage on TC-00001, first half',0,NULL,'2026-11-25 21:50:05'),
(526,100,'2026-11-22',12,'0.00','54.25',3,NULL,NULL,NULL,NULL,NULL,'Shortage on TC-00001, first half',0,NULL,'2026-11-25 21:50:05'),
(527,102,'2026-11-22',45,'0.00','1140.00',14,NULL,4,7,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(528,102,'2026-11-22',34,'0.00','136.80',14,NULL,4,7,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(529,102,'2026-11-22',55,'924.07','0.00',14,NULL,4,7,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(530,102,'2026-11-22',14,'0.00','924.07',14,NULL,4,7,NULL,NULL,'Chicken Breast, Frozen, Bag',0,NULL,'2026-11-25 21:50:05'),
(531,102,'2026-11-22',45,'0.00','420.00',14,NULL,1,7,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(532,102,'2026-11-22',34,'0.00','50.40',14,NULL,1,7,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(533,102,'2026-11-22',55,'340.22','0.00',14,NULL,1,7,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(534,102,'2026-11-22',14,'0.00','340.22',14,NULL,1,7,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(535,102,'2026-11-22',7,'1747.20','0.00',14,NULL,NULL,7,NULL,NULL,'Van sale, Pili town proper',0,NULL,'2026-11-25 21:50:05'),
(536,103,'2026-11-22',14,'0.00','22.18',NULL,NULL,4,7,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(537,103,'2026-11-22',57,'22.18','0.00',NULL,NULL,4,7,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(538,104,'2026-11-22',14,'0.00','1740.77',4,NULL,1,7,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag, crate 155 (shortage)',0,NULL,'2026-11-25 21:50:05'),
(539,104,'2026-11-22',12,'1740.77','0.00',4,NULL,1,7,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag, crate 155 (shortage)',0,NULL,'2026-11-25 21:50:05'),
(540,107,'2026-11-24',45,'0.00','840.00',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(541,107,'2026-11-24',34,'0.00','100.80',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(542,107,'2026-11-24',55,'680.43','0.00',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(543,107,'2026-11-24',14,'0.00','680.43',14,NULL,1,6,NULL,NULL,'Whole Chicken, Fresh Chilled, Bag',0,NULL,'2026-11-25 21:50:05'),
(544,107,'2026-11-24',7,'940.80','0.00',14,NULL,NULL,6,NULL,NULL,'Van sale, Barangay Triangulo',0,NULL,'2026-11-25 21:50:05'),
(545,108,'2026-11-24',14,'0.00','15.00',NULL,NULL,2,6,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(546,108,'2026-11-24',57,'15.00','0.00',NULL,NULL,2,6,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(547,112,'2026-11-23',14,'0.00','269.87',5,NULL,3,2,NULL,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag (shortage: counter count)',0,NULL,'2026-11-25 21:50:05'),
(548,112,'2026-11-23',12,'269.87','0.00',5,NULL,3,2,NULL,NULL,'Chicken Assorted Cut-Ups, Frozen, Bag (shortage: counter count)',0,NULL,'2026-11-25 21:50:05'),
(549,113,'2026-11-23',14,'0.00','33.75',NULL,NULL,9,1,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05'),
(550,113,'2026-11-23',57,'33.75','0.00',NULL,NULL,9,1,NULL,NULL,'Shrinkage',0,NULL,'2026-11-25 21:50:05');

-- inventory_movements (223 rows)
INSERT INTO `inventory_movements` (`id`,`txn_id`,`txn_line_id`,`txn_date`,`item_id`,`site_id`,`production_date`,`expiry_date`,`qty`,`unit_cost`,`total_cost`,`qty_after`,`avg_after`,`created_at`) VALUES
(1,7,12,'2026-09-12',1,1,'2026-09-11','2026-09-23','148.7400','142.0000','21121.08','148.7400','142.0000','2026-11-25 21:50:04'),
(2,7,13,'2026-09-12',4,1,'2026-09-10','2027-03-09','89.8100','185.0000','16614.85','89.8100','185.0000','2026-11-25 21:50:04'),
(3,7,14,'2026-09-12',7,1,'2026-09-11','2026-12-10','29.6500','95.0000','2816.75','29.6500','95.0000','2026-11-25 21:50:04'),
(4,7,15,'2026-09-12',3,1,'2026-09-10','2027-03-09','86.0200','135.0000','11612.70','86.0200','135.0000','2026-11-25 21:50:04'),
(5,7,16,'2026-09-12',9,1,NULL,NULL,'40.0000','25.0000','1000.00','40.0000','25.0000','2026-11-25 21:50:04'),
(11,8,17,'2026-09-20',5,1,'2026-09-12','2027-03-11','122.8100','175.0000','21491.75','122.8100','175.0000','2026-11-25 21:50:04'),
(12,8,18,'2026-09-20',6,1,'2026-09-12','2027-03-11','72.4200','188.0000','13614.96','72.4200','188.0000','2026-11-25 21:50:04'),
(13,8,19,'2026-09-20',8,1,'2026-09-13','2026-12-12','30.0900','110.0000','3309.90','30.0900','110.0000','2026-11-25 21:50:04'),
(14,8,20,'2026-09-20',10,1,'2026-09-06','2027-06-03','240.0000','48.0000','11520.00','240.0000','48.0000','2026-11-25 21:50:04'),
(15,8,21,'2026-09-20',11,1,'2026-09-04','2027-06-01','96.0000','95.0000','9120.00','96.0000','95.0000','2026-11-25 21:50:04'),
(16,9,22,'2026-09-16',12,1,NULL,NULL,'2000.0000','3.3000','6600.00','2000.0000','3.3000','2026-11-25 21:50:04'),
(17,10,23,'2026-09-26',1,1,'2026-09-25','2026-10-07','125.8600','142.0000','17872.12','274.6000','142.0000','2026-11-25 21:50:04'),
(18,10,24,'2026-09-26',2,1,'2026-09-25','2026-10-05','87.2400','150.0000','13086.00','87.2400','150.0000','2026-11-25 21:50:04'),
(19,10,25,'2026-09-26',3,1,'2026-09-25','2027-03-24','57.0000','135.0000','7695.00','143.0200','135.0000','2026-11-25 21:50:04'),
(20,10,26,'2026-09-26',9,1,NULL,NULL,'29.7000','25.0000','742.50','69.7000','25.0000','2026-11-25 21:50:04'),
(42,17,48,'2026-09-22',1,1,'2026-09-11','2026-09-23','-36.8900','141.7780','-5230.19','831.2500','141.7780','2026-11-25 21:50:04'),
(43,17,48,'2026-09-22',1,2,'2026-09-11','2026-09-23','36.8900','141.7780','5230.19','868.1400','141.7780','2026-11-25 21:50:04'),
(44,17,49,'2026-09-22',5,1,'2026-09-12','2027-03-11','-30.3700','175.0000','-5314.75','247.4400','175.0000','2026-11-25 21:50:04'),
(45,17,49,'2026-09-22',5,2,'2026-09-12','2027-03-11','30.3700','175.0000','5314.75','277.8100','175.0000','2026-11-25 21:50:04'),
(46,17,50,'2026-09-22',6,1,'2026-09-12','2027-03-11','-12.2500','188.7665','-2312.39','105.1700','188.7665','2026-11-25 21:50:04'),
(47,17,50,'2026-09-22',6,2,'2026-09-12','2027-03-11','12.2500','188.7665','2312.39','117.4200','188.7665','2026-11-25 21:50:04'),
(48,17,51,'2026-09-22',7,1,'2026-09-11','2026-12-10','-10.2200','95.0000','-970.90','76.4300','95.0000','2026-11-25 21:50:04'),
(49,17,51,'2026-09-22',7,2,'2026-09-11','2026-12-10','10.2200','95.0000','970.90','86.6500','95.0000','2026-11-25 21:50:04'),
(50,17,52,'2026-09-22',10,1,'2026-09-06','2027-06-03','-80.0000','48.0000','-3840.00','322.0000','48.0000','2026-11-25 21:50:04'),
(51,17,52,'2026-09-22',10,2,'2026-09-06','2027-06-03','80.0000','48.0000','3840.00','402.0000','48.0000','2026-11-25 21:50:04'),
(52,17,53,'2026-09-22',11,1,'2026-09-04','2027-06-01','-24.0000','95.0000','-2280.00','145.0000','95.0000','2026-11-25 21:50:04'),
(53,17,53,'2026-09-22',11,2,'2026-09-04','2027-06-01','24.0000','95.0000','2280.00','169.0000','95.0000','2026-11-25 21:50:04'),
(54,18,54,'2026-09-23',1,1,'2026-09-11','2026-09-23','-24.4400','141.7780','-3465.05','843.7000','141.7780','2026-11-25 21:50:04'),
(55,18,54,'2026-09-23',1,3,'2026-09-11','2026-09-23','24.4400','141.7778','3465.05','868.1400','141.7780','2026-11-25 21:50:04'),
(56,18,55,'2026-09-23',4,1,'2026-09-10','2027-03-09','-30.2100','185.0000','-5588.85','199.6000','185.0000','2026-11-25 21:50:04'),
(57,18,55,'2026-09-23',4,3,'2026-09-10','2027-03-09','30.2100','185.0000','5588.85','229.8100','185.0000','2026-11-25 21:50:04'),
(58,18,56,'2026-09-23',5,1,'2026-09-12','2027-03-11','-30.8900','175.0000','-5405.75','246.9200','175.0000','2026-11-25 21:50:04'),
(59,18,56,'2026-09-23',5,3,'2026-09-12','2027-03-11','30.8900','175.0000','5405.75','277.8100','175.0000','2026-11-25 21:50:04'),
(60,18,57,'2026-09-23',10,1,'2026-09-06','2027-06-03','-40.0000','48.0000','-1920.00','362.0000','48.0000','2026-11-25 21:50:04'),
(61,18,57,'2026-09-23',10,3,'2026-09-06','2027-06-03','40.0000','48.0000','1920.00','402.0000','48.0000','2026-11-25 21:50:04'),
(91,23,69,'2026-09-30',1,1,'2026-09-25','2026-10-07','-30.0000','142.0000','-4260.00','244.6000','142.0000','2026-11-25 21:50:04'),
(92,23,71,'2026-09-30',4,1,NULL,NULL,'7.8000','181.8218','1418.21','97.6100','184.7460','2026-11-25 21:50:04'),
(93,23,72,'2026-09-30',5,1,NULL,NULL,'6.6000','171.4545','1131.60','129.4100','174.8192','2026-11-25 21:50:04'),
(94,23,73,'2026-09-30',6,1,NULL,NULL,'3.3000','187.4030','618.43','75.7200','187.9740','2026-11-25 21:50:04'),
(95,23,74,'2026-09-30',3,1,NULL,NULL,'9.0000','133.9733','1205.76','152.0200','134.9392','2026-11-25 21:50:04'),
(96,23,75,'2026-09-30',7,1,NULL,NULL,'1.2000','95.0000','114.00','30.8500','95.0000','2026-11-25 21:50:04'),
(97,23,76,'2026-09-30',8,1,NULL,NULL,'1.2000','110.0000','132.00','31.2900','110.0000','2026-11-25 21:50:04'),
(98,11,27,'2026-10-04',5,1,'2026-10-03','2027-04-01','94.0000','175.0000','16450.00','223.4100','174.8953','2026-11-25 21:50:04'),
(99,11,28,'2026-10-04',6,1,'2026-10-03','2027-04-01','45.0000','190.0000','8550.00','120.7200','188.7292','2026-11-25 21:50:04'),
(100,11,29,'2026-10-04',10,1,'2026-10-03','2027-06-30','162.0000','48.0000','7776.00','402.0000','48.0000','2026-11-25 21:50:04'),
(101,12,30,'2026-10-11',1,1,'2026-10-10','2026-10-22','148.8200','142.0000','21132.44','393.4200','142.0000','2026-11-25 21:50:04'),
(102,12,31,'2026-10-11',4,1,'2026-10-10','2027-04-08','74.0000','185.0000','13690.00','171.6100','184.8555','2026-11-25 21:50:04'),
(103,12,32,'2026-10-11',7,1,'2026-10-10','2027-01-08','33.0000','95.0000','3135.00','63.8500','95.0000','2026-11-25 21:50:04'),
(104,13,33,'2026-10-26',1,1,'2026-10-25','2026-11-06','123.1200','142.0000','17483.04','516.5400','142.0000','2026-11-25 21:50:04'),
(105,13,34,'2026-10-26',2,1,'2026-10-25','2026-11-04','91.4800','150.0000','13722.00','178.7200','150.0000','2026-11-25 21:50:04'),
(106,13,35,'2026-10-26',3,1,'2026-10-25','2027-04-23','58.0000','135.0000','7830.00','210.0200','134.9560','2026-11-25 21:50:04'),
(107,13,36,'2026-10-26',9,1,NULL,NULL,'25.0000','25.0000','625.00','94.7000','25.0000','2026-11-25 21:50:04'),
(108,22,67,'2026-10-26',9,1,NULL,NULL,'-12.0000','25.0000','-300.00','82.7000','25.0000','2026-11-25 21:50:04'),
(109,22,67,'2026-10-26',9,2,NULL,NULL,'12.0000','25.0000','300.00','94.7000','25.0000','2026-11-25 21:50:04'),
(110,22,68,'2026-10-26',12,1,NULL,NULL,'-200.0000','3.3000','-660.00','1800.0000','3.3000','2026-11-25 21:50:04'),
(111,22,68,'2026-10-26',12,2,NULL,NULL,'200.0000','3.3000','660.00','2000.0000','3.3000','2026-11-25 21:50:04'),
(112,19,58,'2026-10-27',1,1,'2026-09-11','2026-09-23','-37.9900','142.0000','-5394.58','478.5500','142.0000','2026-11-25 21:50:04'),
(113,19,58,'2026-10-27',1,2,'2026-09-11','2026-09-23','37.9900','142.0000','5394.58','516.5400','142.0000','2026-11-25 21:50:04'),
(114,19,59,'2026-10-27',2,1,'2026-09-25','2026-10-05','-29.0700','150.0000','-4360.50','149.6500','150.0000','2026-11-25 21:50:04'),
(115,19,59,'2026-10-27',2,2,'2026-09-25','2026-10-05','29.0700','150.0000','4360.50','178.7200','150.0000','2026-11-25 21:50:04'),
(116,19,60,'2026-10-27',3,1,'2026-09-10','2027-03-09','-14.2600','134.9560','-1924.47','195.7600','134.9560','2026-11-25 21:50:04'),
(117,19,60,'2026-10-27',3,2,'2026-09-10','2027-03-09','14.2600','134.9558','1924.47','210.0200','134.9560','2026-11-25 21:50:04'),
(148,24,77,'2026-10-30',1,1,'2026-09-25','2026-10-07','-20.0000','142.0000','-2840.00','496.5400','142.0000','2026-11-25 21:50:04'),
(149,24,79,'2026-10-30',4,1,NULL,NULL,'5.4000','181.2259','978.62','177.0100','184.7448','2026-11-25 21:50:04'),
(150,24,80,'2026-10-30',5,1,NULL,NULL,'4.4000','170.8932','751.93','227.8100','174.8180','2026-11-25 21:50:04'),
(151,24,81,'2026-10-30',6,1,NULL,NULL,'2.2000','186.7909','410.94','122.9200','188.6945','2026-11-25 21:50:04'),
(152,24,82,'2026-10-30',3,1,NULL,NULL,'5.8000','133.5362','774.51','215.8200','134.9178','2026-11-25 21:50:04'),
(153,24,83,'2026-10-30',7,1,NULL,NULL,'0.8000','95.0000','76.00','64.6500','95.0000','2026-11-25 21:50:04'),
(154,24,84,'2026-10-30',8,1,NULL,NULL,'0.8000','110.0000','88.00','32.0900','110.0000','2026-11-25 21:50:04'),
(155,14,37,'2026-11-04',1,3,'2026-11-03','2026-11-15','96.3700','140.0000','13491.80','592.9100','141.6749','2026-11-25 21:50:04'),
(156,14,38,'2026-11-04',5,3,'2026-11-03','2027-05-02','61.0000','175.0000','10675.00','288.8100','174.8564','2026-11-25 21:50:04'),
(157,14,39,'2026-11-04',8,3,'2026-11-03','2027-02-01','17.0000','110.0000','1870.00','49.0900','110.0000','2026-11-25 21:50:04'),
(158,14,40,'2026-11-04',11,3,'2026-11-03','2027-07-31','73.0000','95.0000','6935.00','169.0000','95.0000','2026-11-25 21:50:04'),
(159,15,41,'2026-11-16',1,1,'2026-11-15','2026-11-27','124.2400','142.0000','17642.08','717.1500','141.7312','2026-11-25 21:50:04'),
(160,15,42,'2026-11-16',4,1,'2026-11-15','2027-05-14','66.0000','185.0000','12210.00','243.0100','184.8141','2026-11-25 21:50:04'),
(161,15,43,'2026-11-16',3,1,'2026-11-15','2027-05-14','59.0000','135.0000','7965.00','274.8200','134.9355','2026-11-25 21:50:04'),
(162,20,61,'2026-11-17',1,1,'2026-09-11','2026-09-23','-49.4200','141.7312','-7004.36','667.7300','141.7312','2026-11-25 21:50:04'),
(163,20,61,'2026-11-17',1,2,'2026-09-11','2026-09-23','49.4200','141.7313','7004.36','717.1500','141.7312','2026-11-25 21:50:04'),
(164,20,62,'2026-11-17',4,1,'2026-09-10','2027-03-09','-14.9000','184.8141','-2753.73','228.1100','184.8141','2026-11-25 21:50:04'),
(165,20,62,'2026-11-17',4,2,'2026-09-10','2027-03-09','14.9000','184.8141','2753.73','243.0100','184.8141','2026-11-25 21:50:04'),
(166,20,63,'2026-11-17',3,1,'2026-09-10','2027-03-09','-14.3000','134.9355','-1929.58','260.5200','134.9355','2026-11-25 21:50:04'),
(167,20,63,'2026-11-17',3,2,'2026-09-10','2027-03-09','14.3000','134.9357','1929.58','274.8200','134.9355','2026-11-25 21:50:04'),
(168,16,44,'2026-11-23',1,1,'2026-11-22','2026-12-04','100.9900','142.0000','14340.58','818.1400','141.7644','2026-11-25 21:50:04'),
(169,16,45,'2026-11-23',2,1,'2026-11-22','2026-12-02','72.9600','150.0000','10944.00','251.6800','150.0000','2026-11-25 21:50:04'),
(170,16,46,'2026-11-23',7,1,'2026-11-22','2027-02-20','24.0000','95.0000','2280.00','88.6500','95.0000','2026-11-25 21:50:04'),
(171,16,47,'2026-11-23',9,1,NULL,NULL,'20.4000','25.0000','510.00','115.1000','25.0000','2026-11-25 21:50:04'),
(172,21,64,'2026-11-24',1,1,'2026-09-25','2026-10-07','-37.8800','141.7644','-5370.04','780.2600','141.7644','2026-11-25 21:50:04'),
(173,21,64,'2026-11-24',1,2,'2026-09-25','2026-10-07','37.8800','141.7645','5370.04','818.1400','141.7644','2026-11-25 21:50:04'),
(174,21,65,'2026-11-24',2,1,'2026-09-25','2026-10-05','-29.1100','150.0000','-4366.50','222.5700','150.0000','2026-11-25 21:50:04'),
(175,21,65,'2026-11-24',2,2,'2026-09-25','2026-10-05','29.1100','150.0000','4366.50','251.6800','150.0000','2026-11-25 21:50:04'),
(176,21,66,'2026-11-24',7,1,'2026-09-11','2026-12-10','-9.7200','95.0000','-923.40','78.9300','95.0000','2026-11-25 21:50:04'),
(177,21,66,'2026-11-24',7,2,'2026-09-11','2026-12-10','9.7200','95.0000','923.40','88.6500','95.0000','2026-11-25 21:50:04'),
(178,26,94,'2026-10-16',5,1,NULL,NULL,'-8.0000','174.8564','-1398.85','280.8100','174.8564','2026-11-25 21:50:04'),
(179,26,95,'2026-10-16',6,1,NULL,NULL,'-5.5000','188.6945','-1037.82','117.4200','188.6945','2026-11-25 21:50:04'),
(180,26,95,'2026-10-16',6,1,'2026-09-12','2027-03-11','-10.5000','188.6945','-1981.29','106.9200','188.6945','2026-11-25 21:50:04'),
(181,26,96,'2026-10-16',12,1,NULL,NULL,'-16.0000','3.3000','-52.80','1984.0000','3.3000','2026-11-25 21:50:04'),
(182,26,93,'2026-10-16',14,1,NULL,NULL,'8.0000','565.0950','4520.76','8.0000','565.0950','2026-11-25 21:50:04'),
(183,27,98,'2026-10-17',14,1,NULL,NULL,'-3.0000','565.0950','-1695.29','5.0000','565.0940','2026-11-25 21:50:04'),
(184,27,98,'2026-10-17',14,2,NULL,NULL,'3.0000','565.0967','1695.29','8.0000','565.0950','2026-11-25 21:50:04'),
(185,31,110,'2026-10-01',1,1,'2026-09-25','2026-10-07','-37.9800','141.7644','-5384.21','780.1600','141.7644','2026-11-25 21:50:04');
INSERT INTO `inventory_movements` (`id`,`txn_id`,`txn_line_id`,`txn_date`,`item_id`,`site_id`,`production_date`,`expiry_date`,`qty`,`unit_cost`,`total_cost`,`qty_after`,`avg_after`,`created_at`) VALUES
(186,31,110,'2026-10-01',1,1,'2026-10-10','2026-10-22','-12.9800','141.7644','-1840.10','767.1800','141.7644','2026-11-25 21:50:04'),
(187,31,111,'2026-10-01',4,1,'2026-09-10','2027-03-09','-29.4700','184.8141','-5446.47','213.5400','184.8141','2026-11-25 21:50:04'),
(188,32,113,'2026-10-08',1,1,'2026-10-10','2026-10-22','-49.5400','141.7644','-7023.01','717.6400','141.7644','2026-11-25 21:50:04'),
(189,33,115,'2026-10-12',1,1,'2026-10-10','2026-10-22','-37.0900','141.7644','-5258.04','680.5500','141.7644','2026-11-25 21:50:04'),
(190,33,116,'2026-10-12',5,1,'2026-09-12','2027-03-11','-30.9900','174.8564','-5418.80','249.8200','174.8564','2026-11-25 21:50:04'),
(191,34,118,'2026-10-06',1,1,'2026-10-10','2026-10-22','-18.0000','141.7644','-2551.76','662.5500','141.7644','2026-11-25 21:50:04'),
(192,34,119,'2026-10-06',4,1,'2026-09-10','2027-03-09','-10.0000','184.8141','-1848.14','203.5400','184.8141','2026-11-25 21:50:04'),
(193,34,120,'2026-10-06',7,1,'2026-09-11','2026-12-10','-4.0000','95.0000','-380.00','84.6500','95.0000','2026-11-25 21:50:04'),
(194,34,121,'2026-10-06',9,1,NULL,NULL,'-6.0000','25.0000','-150.00','109.1000','25.0000','2026-11-25 21:50:04'),
(195,35,122,'2026-10-20',5,1,'2026-09-12','2027-03-11','-12.0000','174.8564','-2098.28','237.8200','174.8564','2026-11-25 21:50:04'),
(196,35,123,'2026-10-20',6,1,'2026-09-12','2027-03-11','-8.0000','188.6945','-1509.56','98.9200','188.6945','2026-11-25 21:50:04'),
(197,36,125,'2026-10-14',1,3,'2026-09-11','2026-09-23','-11.9500','141.7644','-1694.08','650.6000','141.7644','2026-11-25 21:50:04'),
(198,36,126,'2026-10-14',5,3,'2026-09-12','2027-03-11','-15.3600','174.8564','-2685.79','222.4600','174.8564','2026-11-25 21:50:04'),
(199,36,127,'2026-10-14',4,3,'2026-09-10','2027-03-09','-8.0000','184.8141','-1478.51','195.5400','184.8142','2026-11-25 21:50:04'),
(200,37,128,'2026-11-07',1,3,'2026-09-11','2026-09-23','-12.4900','141.7644','-1770.64','638.1100','141.7644','2026-11-25 21:50:04'),
(201,37,128,'2026-11-07',1,3,'2026-11-03','2026-11-15','-36.0900','141.7644','-5116.28','602.0200','141.7644','2026-11-25 21:50:04'),
(202,37,129,'2026-11-07',5,3,'2026-09-12','2027-03-11','-10.0000','174.8564','-1748.56','212.4600','174.8564','2026-11-25 21:50:04'),
(203,38,131,'2026-10-16',4,1,'2026-09-10','2027-03-09','-5.2300','184.8142','-966.58','190.3100','184.8142','2026-11-25 21:50:04'),
(204,38,131,'2026-10-16',4,1,'2026-10-10','2027-04-08','-14.7700','184.8142','-2729.70','175.5400','184.8142','2026-11-25 21:50:04'),
(205,38,132,'2026-10-16',3,1,'2026-09-10','2027-03-09','-15.0000','134.9355','-2024.03','259.8200','134.9355','2026-11-25 21:50:04'),
(206,39,133,'2026-10-23',4,1,'2026-10-10','2027-04-08','-15.0000','184.8142','-2772.21','160.5400','184.8142','2026-11-25 21:50:04'),
(207,39,134,'2026-10-23',3,1,'2026-09-10','2027-03-09','-12.0000','134.9355','-1619.23','247.8200','134.9355','2026-11-25 21:50:04'),
(208,40,135,'2026-10-23',1,1,'2026-10-10','2026-10-22','-19.1000','141.7644','-2707.70','582.9200','141.7644','2026-11-25 21:50:05'),
(209,41,136,'2026-11-13',4,1,'2026-10-10','2027-04-08','-15.0000','184.8142','-2772.21','145.5400','184.8142','2026-11-25 21:50:05'),
(210,41,137,'2026-11-13',3,1,'2026-09-10','2027-03-09','-12.0000','134.9355','-1619.23','235.8200','134.9355','2026-11-25 21:50:05'),
(211,42,138,'2026-11-13',1,1,'2026-10-10','2026-10-22','-12.1100','141.7644','-1716.77','570.8100','141.7644','2026-11-25 21:50:05'),
(212,42,138,'2026-11-13',1,1,'2026-10-25','2026-11-06','-12.2400','141.7644','-1735.19','558.5700','141.7644','2026-11-25 21:50:05'),
(213,43,139,'2026-10-31',1,1,'2026-10-25','2026-11-06','-73.7000','141.7644','-10448.04','484.8700','141.7644','2026-11-25 21:50:05'),
(214,43,140,'2026-10-31',2,1,'2026-09-25','2026-10-05','-29.0600','150.0000','-4359.00','222.6200','150.0000','2026-11-25 21:50:05'),
(215,43,140,'2026-10-31',2,1,'2026-10-25','2026-11-04','-15.4300','150.0000','-2314.50','207.1900','150.0000','2026-11-25 21:50:05'),
(216,43,141,'2026-10-31',11,1,'2026-09-04','2027-06-01','-24.0000','95.0000','-2280.00','145.0000','95.0000','2026-11-25 21:50:05'),
(217,44,144,'2026-11-19',1,1,'2026-10-25','2026-11-06','-37.1800','141.7644','-5270.80','447.6900','141.7644','2026-11-25 21:50:05'),
(218,44,144,'2026-11-19',1,1,'2026-11-15','2026-11-27','-25.3700','141.7644','-3596.57','422.3200','141.7644','2026-11-25 21:50:05'),
(219,44,145,'2026-11-19',4,1,'2026-10-10','2027-04-08','-0.2300','184.8142','-42.51','145.3100','184.8142','2026-11-25 21:50:05'),
(220,45,147,'2026-11-21',1,1,'2026-11-15','2026-11-27','-25.0000','141.7644','-3544.11','397.3200','141.7644','2026-11-25 21:50:05'),
(221,45,148,'2026-11-21',8,1,'2026-09-13','2026-12-12','-3.0000','110.0000','-330.00','46.0900','110.0000','2026-11-25 21:50:05'),
(222,47,151,'2026-10-17',7,1,'2026-09-11','2026-12-10','-2.5000','95.0000','-237.50','82.1500','95.0000','2026-11-25 21:50:05'),
(223,47,152,'2026-10-17',1,1,'2026-11-15','2026-11-27','-6.2000','141.7644','-878.94','391.1200','141.7644','2026-11-25 21:50:05'),
(224,47,153,'2026-10-17',9,1,NULL,NULL,'-2.0000','25.0000','-50.00','107.1000','25.0000','2026-11-25 21:50:05'),
(225,52,154,'2026-10-22',1,1,'2026-11-15','2026-11-27','-18.0700','141.7644','-2561.68','373.0500','141.7644','2026-11-25 21:50:05'),
(226,52,155,'2026-10-22',3,1,'2026-09-10','2027-03-09','-4.5300','134.9355','-611.26','231.2900','134.9355','2026-11-25 21:50:05'),
(227,52,155,'2026-10-22',3,1,'2026-09-25','2027-03-24','-5.4700','134.9355','-738.09','225.8200','134.9355','2026-11-25 21:50:05'),
(228,66,168,'2026-09-29',1,1,'2026-11-15','2026-11-27','-12.0000','142.0000','-1704.00','361.0500','141.7566','2026-11-25 21:50:05'),
(229,73,171,'2026-11-01',7,1,NULL,NULL,'-1.5000','95.0000','-142.50','80.6500','95.0000','2026-11-25 21:50:05'),
(230,74,172,'2026-11-17',10,2,'2026-09-06','2027-06-03','-2.0000','48.0000','-96.00','400.0000','48.0000','2026-11-25 21:50:05'),
(231,74,173,'2026-11-17',12,2,NULL,NULL,'50.0000','3.3000','165.00','2034.0000','3.3000','2026-11-25 21:50:05'),
(232,82,197,'2026-11-24',1,2,'2026-09-11','2026-09-23','-3.4000','141.7566','-481.97','357.6500','141.7566','2026-11-25 21:50:05'),
(233,82,198,'2026-11-24',10,2,'2026-09-06','2027-06-03','-2.0000','48.0000','-96.00','398.0000','48.0000','2026-11-25 21:50:05'),
(234,83,200,'2026-11-24',1,2,'2026-09-11','2026-09-23','-9.0200','141.7566','-1278.64','348.6300','141.7566','2026-11-25 21:50:05'),
(235,84,203,'2026-11-24',7,2,'2026-09-11','2026-12-10','-1.2000','95.0000','-114.00','79.4500','95.0000','2026-11-25 21:50:05'),
(236,84,204,'2026-11-24',11,2,'2026-09-04','2027-06-01','-1.0000','95.0000','-95.00','144.0000','95.0000','2026-11-25 21:50:05'),
(238,86,209,'2026-11-24',14,2,NULL,NULL,'-1.0000','565.0950','-565.10','7.0000','565.0943','2026-11-25 21:50:05'),
(239,86,210,'2026-11-24',3,2,'2026-09-10','2027-03-09','-2.0000','134.9355','-269.87','223.8200','134.9355','2026-11-25 21:50:05'),
(240,87,211,'2026-11-24',10,2,NULL,NULL,'1.0000','48.0000','48.00','399.0000','48.0000','2026-11-25 21:50:05'),
(241,89,216,'2026-11-25',1,2,'2026-09-11','2026-09-23','-2.8000','141.7566','-396.92','345.8300','141.7566','2026-11-25 21:50:05'),
(242,89,217,'2026-11-25',9,2,NULL,NULL,'-1.0000','25.0000','-25.00','106.1000','25.0000','2026-11-25 21:50:05'),
(243,90,221,'2026-11-25',10,2,NULL,NULL,'-1.0000','48.0000','-48.00','398.0000','48.0000','2026-11-25 21:50:05'),
(244,90,221,'2026-11-25',10,2,'2026-09-06','2027-06-03','-3.0000','48.0000','-144.00','395.0000','48.0000','2026-11-25 21:50:05'),
(245,90,222,'2026-11-25',11,2,'2026-09-04','2027-06-01','-2.0000','95.0000','-190.00','142.0000','95.0000','2026-11-25 21:50:05'),
(246,91,224,'2026-11-11',2,1,'2026-10-25','2026-11-04','-76.0500','150.0000','-11407.50','131.1400','150.0000','2026-11-25 21:50:05'),
(247,92,225,'2026-11-11',1,2,'2026-09-11','2026-09-23','-109.0800','141.7566','-15462.81','236.7500','141.7566','2026-11-25 21:50:05'),
(248,92,225,'2026-11-11',1,2,'2026-09-25','2026-10-07','-37.8800','141.7566','-5369.74','198.8700','141.7566','2026-11-25 21:50:05'),
(249,92,226,'2026-11-11',2,2,'2026-09-25','2026-10-05','-58.1800','150.0000','-8727.00','72.9600','150.0000','2026-11-25 21:50:05'),
(250,93,227,'2026-11-21',1,1,'2026-11-15','2026-11-27','-37.6000','141.7566','-5330.05','161.2700','141.7566','2026-11-25 21:50:05'),
(251,93,227,'2026-11-21',1,6,'2026-11-15','2026-11-27','37.6000','141.7566','5330.05','198.8700','141.7566','2026-11-25 21:50:05'),
(252,93,228,'2026-11-21',5,1,'2026-09-12','2027-03-11','-3.4200','174.8564','-598.01','209.0400','174.8564','2026-11-25 21:50:05'),
(253,93,228,'2026-11-21',5,6,'2026-09-12','2027-03-11','3.4200','174.8567','598.01','212.4600','174.8564','2026-11-25 21:50:05'),
(254,93,229,'2026-11-21',10,1,'2026-09-06','2027-06-03','-40.0000','48.0000','-1920.00','355.0000','48.0000','2026-11-25 21:50:05'),
(255,93,229,'2026-11-21',10,6,'2026-09-06','2027-06-03','40.0000','48.0000','1920.00','395.0000','48.0000','2026-11-25 21:50:05'),
(256,94,230,'2026-11-21',9,1,NULL,NULL,'-6.0000','25.0000','-150.00','100.1000','25.0000','2026-11-25 21:50:05'),
(257,94,230,'2026-11-21',9,6,NULL,NULL,'6.0000','25.0000','150.00','106.1000','25.0000','2026-11-25 21:50:05'),
(258,95,231,'2026-11-21',1,6,'2026-11-15','2026-11-27','-12.7900','141.7566','-1813.07','186.0800','141.7566','2026-11-25 21:50:05'),
(259,95,232,'2026-11-21',5,6,'2026-09-12','2027-03-11','-3.4200','174.8564','-598.01','209.0400','174.8564','2026-11-25 21:50:05'),
(260,96,233,'2026-11-21',1,6,'2026-11-15','2026-11-27','-3.2000','141.7566','-453.62','182.8800','141.7566','2026-11-25 21:50:05'),
(261,96,234,'2026-11-21',9,6,NULL,NULL,'-2.0000','25.0000','-50.00','104.1000','25.0000','2026-11-25 21:50:05'),
(262,96,235,'2026-11-21',10,6,'2026-09-06','2027-06-03','-6.0000','48.0000','-288.00','389.0000','48.0000','2026-11-25 21:50:05'),
(263,97,236,'2026-11-21',1,6,'2026-11-15','2026-11-27','-0.1800','141.7566','-25.52','182.7000','141.7566','2026-11-25 21:50:05'),
(264,98,237,'2026-11-21',10,6,'2026-09-06','2027-06-03','-2.0000','48.0000','-96.00','387.0000','48.0000','2026-11-25 21:50:05'),
(265,98,238,'2026-11-21',9,6,NULL,NULL,'-0.5000','25.0000','-12.50','103.6000','25.0000','2026-11-25 21:50:05'),
(266,99,239,'2026-11-21',10,6,'2026-09-06','2027-06-03','-32.0000','48.0000','-1536.00','355.0000','48.0000','2026-11-25 21:50:05'),
(267,99,239,'2026-11-21',10,1,'2026-09-06','2027-06-03','32.0000','48.0000','1536.00','387.0000','48.0000','2026-11-25 21:50:05'),
(268,99,240,'2026-11-21',9,6,NULL,NULL,'-3.5000','25.0000','-87.50','100.1000','25.0000','2026-11-25 21:50:05'),
(269,99,240,'2026-11-21',9,1,NULL,NULL,'3.5000','25.0000','87.50','103.6000','25.0000','2026-11-25 21:50:05'),
(270,99,241,'2026-11-21',1,6,'2026-11-15','2026-11-27','-9.1500','141.7566','-1297.07','173.5500','141.7566','2026-11-25 21:50:05'),
(271,99,241,'2026-11-21',1,1,'2026-11-15','2026-11-27','9.1500','141.7563','1297.07','182.7000','141.7566','2026-11-25 21:50:05'),
(272,99,242,'2026-11-21',1,6,'2026-11-15','2026-11-27','-12.2800','141.7566','-1740.77','170.4200','141.7566','2026-11-25 21:50:05'),
(273,99,242,'2026-11-21',1,1,'2026-11-15','2026-11-27','12.2800','141.7565','1740.77','182.7000','141.7566','2026-11-25 21:50:05'),
(274,101,243,'2026-11-22',1,1,'2026-11-15','2026-11-27','-21.4300','141.7566','-3037.84','161.2700','141.7566','2026-11-25 21:50:05'),
(275,101,243,'2026-11-22',1,7,'2026-11-15','2026-11-27','21.4300','141.7564','3037.84','182.7000','141.7566','2026-11-25 21:50:05'),
(276,101,244,'2026-11-22',4,1,'2026-10-10','2027-04-08','-13.0000','184.8142','-2402.58','132.3100','184.8142','2026-11-25 21:50:05'),
(277,101,244,'2026-11-22',4,7,'2026-10-10','2027-04-08','13.0000','184.8138','2402.58','145.3100','184.8142','2026-11-25 21:50:05'),
(278,102,245,'2026-11-22',4,7,'2026-10-10','2027-04-08','-5.0000','184.8142','-924.07','140.3100','184.8142','2026-11-25 21:50:05'),
(279,102,246,'2026-11-22',1,7,'2026-11-15','2026-11-27','-2.4000','141.7566','-340.22','180.3000','141.7566','2026-11-25 21:50:05'),
(280,103,247,'2026-11-22',4,7,'2026-10-10','2027-04-08','-0.1200','184.8142','-22.18','140.1900','184.8142','2026-11-25 21:50:05'),
(281,104,248,'2026-11-22',1,7,'2026-11-15','2026-11-27','-12.2800','141.7565','-1740.77','168.0200','141.7566','2026-11-25 21:50:05'),
(282,105,249,'2026-11-22',4,7,'2026-10-10','2027-04-08','-7.8800','184.8142','-1456.34','132.3100','184.8141','2026-11-25 21:50:05'),
(283,105,249,'2026-11-22',4,1,'2026-10-10','2027-04-08','7.8800','184.8147','1456.34','140.1900','184.8142','2026-11-25 21:50:05'),
(284,105,250,'2026-11-22',1,7,'2026-11-15','2026-11-27','-6.7500','141.7566','-956.86','161.2700','141.7566','2026-11-25 21:50:05'),
(285,105,250,'2026-11-22',1,1,'2026-11-15','2026-11-27','6.7500','141.7570','956.86','168.0200','141.7566','2026-11-25 21:50:05'),
(286,106,251,'2026-11-24',1,1,'2026-11-15','2026-11-27','-6.7500','141.7566','-956.86','161.2700','141.7566','2026-11-25 21:50:05');
INSERT INTO `inventory_movements` (`id`,`txn_id`,`txn_line_id`,`txn_date`,`item_id`,`site_id`,`production_date`,`expiry_date`,`qty`,`unit_cost`,`total_cost`,`qty_after`,`avg_after`,`created_at`) VALUES
(287,106,251,'2026-11-24',1,1,'2026-11-22','2026-12-04','-12.8700','141.7566','-1824.40','148.4000','141.7566','2026-11-25 21:50:05'),
(288,106,251,'2026-11-24',1,6,'2026-11-15','2026-11-27','6.7500','141.7564','956.86','155.1500','141.7566','2026-11-25 21:50:05'),
(289,106,251,'2026-11-24',1,6,'2026-11-22','2026-12-04','12.8700','141.7564','1824.40','168.0200','141.7566','2026-11-25 21:50:05'),
(290,106,252,'2026-11-24',2,1,'2026-11-22','2026-12-02','-14.5400','150.0000','-2181.00','58.4200','150.0000','2026-11-25 21:50:05'),
(291,106,252,'2026-11-24',2,6,'2026-11-22','2026-12-02','14.5400','150.0000','2181.00','72.9600','150.0000','2026-11-25 21:50:05'),
(292,107,253,'2026-11-24',1,6,'2026-11-15','2026-11-27','-4.8000','141.7566','-680.43','163.2200','141.7566','2026-11-25 21:50:05'),
(293,108,254,'2026-11-24',2,6,'2026-11-22','2026-12-02','-0.1000','150.0000','-15.00','72.8600','150.0000','2026-11-25 21:50:05'),
(294,109,255,'2026-11-24',2,6,'2026-11-22','2026-12-02','-14.4400','150.0000','-2166.00','58.4200','150.0000','2026-11-25 21:50:05'),
(295,109,255,'2026-11-24',2,1,'2026-11-22','2026-12-02','14.4400','150.0000','2166.00','72.8600','150.0000','2026-11-25 21:50:05'),
(296,109,256,'2026-11-24',1,6,'2026-11-15','2026-11-27','-1.9500','141.7566','-276.43','161.2700','141.7566','2026-11-25 21:50:05'),
(297,109,256,'2026-11-24',1,1,'2026-11-15','2026-11-27','1.9500','141.7590','276.43','163.2200','141.7566','2026-11-25 21:50:05'),
(298,109,257,'2026-11-24',1,6,'2026-11-22','2026-12-04','-12.8700','141.7566','-1824.41','150.3500','141.7566','2026-11-25 21:50:05'),
(299,109,257,'2026-11-24',1,1,'2026-11-22','2026-12-04','12.8700','141.7568','1824.41','163.2200','141.7566','2026-11-25 21:50:05'),
(300,110,258,'2026-11-25',1,1,'2026-11-15','2026-11-27','-1.9500','141.7566','-276.43','161.2700','141.7566','2026-11-25 21:50:05'),
(301,110,258,'2026-11-25',1,1,'2026-11-22','2026-12-04','-12.8700','141.7566','-1824.40','148.4000','141.7566','2026-11-25 21:50:05'),
(302,110,258,'2026-11-25',1,6,'2026-11-15','2026-11-27','1.9500','141.7564','276.43','150.3500','141.7566','2026-11-25 21:50:05'),
(303,110,258,'2026-11-25',1,6,'2026-11-22','2026-12-04','12.8700','141.7564','1824.40','163.2200','141.7566','2026-11-25 21:50:05'),
(304,110,259,'2026-11-25',5,1,'2026-09-12','2027-03-11','-15.1400','174.8564','-2647.33','193.9000','174.8564','2026-11-25 21:50:05'),
(305,110,259,'2026-11-25',5,6,'2026-09-12','2027-03-11','15.1400','174.8567','2647.33','209.0400','174.8564','2026-11-25 21:50:05'),
(306,111,260,'2026-11-25',9,1,NULL,NULL,'-4.0000','25.0000','-100.00','99.6000','25.0000','2026-11-25 21:50:05'),
(307,111,260,'2026-11-25',9,6,NULL,NULL,'4.0000','25.0000','100.00','103.6000','25.0000','2026-11-25 21:50:05'),
(308,112,261,'2026-11-23',3,2,'2026-09-10','2027-03-09','-2.0000','134.9350','-269.87','221.8200','134.9355','2026-11-25 21:50:05'),
(309,113,262,'2026-11-23',9,1,NULL,NULL,'-1.3500','25.0000','-33.75','102.2500','25.0000','2026-11-25 21:50:05');

-- receipt_documents (1 rows)
INSERT INTO `receipt_documents` (`id`,`file_path`,`original_name`,`mime_type`,`source`,`vendor_id`,`receipt_date`,`amount`,`account_id`,`memo`,`status`,`linked_txn_id`,`uploaded_by`,`uploaded_at`,`reviewed_by`,`reviewed_at`) VALUES
(1,'sample_fuel_receipt.txt','Fuel_2026-11-22_6800.00.txt','text/plain','email',6,'2026-11-22','6800.00',64,NULL,'for_review',NULL,1,'2026-11-25 21:50:05',NULL,NULL);

-- asset_categories (6 rows)
INSERT INTO `asset_categories` (`id`,`name`,`asset_account_id`,`accum_dep_account_id`,`dep_expense_account_id`,`default_method`,`default_life_years`,`is_active`) VALUES
(1,'Buildings',21,22,68,'straight_line','25.00',1),
(2,'Machinery and Equipment',23,24,68,'straight_line','5.00',1),
(3,'Production Machinery (usage-based)',23,24,68,'units_of_production','5.00',1),
(4,'Transportation Equipment',25,26,68,'declining_balance','5.00',1),
(5,'Furniture and Fixtures',27,28,68,'straight_line','10.00',1),
(6,'Computer and POS Equipment',29,30,68,'declining_balance','3.00',1);

-- asset_locations (2 rows)
INSERT INTO `asset_locations` (`id`,`name`,`is_active`,`created_at`,`updated_at`) VALUES
(1,'Naga Cold Storage',1,'2026-11-25 21:50:04',NULL),
(2,'Naga Outlet',1,'2026-11-25 21:50:04',NULL);

-- fixed_assets (4 rows)
INSERT INTO `fixed_assets` (`id`,`asset_no`,`description`,`category_id`,`location`,`location_id`,`site_id`,`class_id`,`serial_no`,`vendor_id`,`acquisition_date`,`cost`,`salvage_value`,`useful_life_years`,`method`,`db_multiplier`,`total_units`,`unit_label`,`basis_date`,`basis_nbv`,`basis_life_months`,`opening_accum_dep`,`opening_through`,`acquisition_txn_id`,`status`,`disposal_date`,`disposal_proceeds`,`disposal_txn_id`,`notes`,`current_meter`,`meter_unit`,`created_at`,`updated_at`) VALUES
(1,'FA-00001','Blast Freezer and Cold Room (20 tons)',2,'Naga Cold Storage',1,NULL,NULL,'CR-20T-0091',7,'2026-09-01','1850000.00','150000.00','10.00','straight_line','2.00',NULL,NULL,NULL,NULL,NULL,'0.00',NULL,2,'active',NULL,NULL,NULL,NULL,NULL,NULL,'2026-11-25 21:50:04',NULL),
(2,'FA-00002','Reefer Truck 1 (6-wheeler, -18 C)',4,'Naga Cold Storage',1,NULL,NULL,'RFT-ABC-1234',9,'2026-09-01','2450000.00','350000.00','5.00','declining_balance','2.00',NULL,NULL,NULL,NULL,NULL,'0.00',NULL,3,'active',NULL,NULL,NULL,NULL,'18200.00','km','2026-11-25 21:50:04','2026-11-25 21:50:04'),
(3,'FA-00003','POS Terminal Set (Naga Outlet)',6,'Naga Outlet',2,NULL,NULL,NULL,9,'2026-09-01','65000.00','0.00','3.00','syd','2.00',NULL,NULL,NULL,NULL,NULL,'0.00',NULL,4,'active',NULL,NULL,NULL,NULL,NULL,NULL,'2026-11-25 21:50:04',NULL),
(4,'FA-00004','Platform Scale 300 kg (receiving)',3,'Naga Cold Storage',1,NULL,NULL,NULL,7,'2026-09-01','85000.00','5000.00','5.00','units_of_production','2.00','150000.00','weighings',NULL,NULL,NULL,'0.00',NULL,5,'active',NULL,NULL,NULL,NULL,NULL,NULL,'2026-11-25 21:50:04',NULL);

-- asset_depreciation (8 rows)
INSERT INTO `asset_depreciation` (`id`,`asset_id`,`period_year`,`period_month`,`units_used`,`amount`,`txn_id`,`created_at`) VALUES
(1,3,2026,9,NULL,'2708.33',79,'2026-11-25 21:50:05'),
(2,1,2026,9,NULL,'14166.67',79,'2026-11-25 21:50:05'),
(3,4,2026,9,'2400.00','1280.00',79,'2026-11-25 21:50:05'),
(4,2,2026,9,NULL,'81666.67',79,'2026-11-25 21:50:05'),
(5,3,2026,10,NULL,'2708.33',80,'2026-11-25 21:50:05'),
(6,1,2026,10,NULL,'14166.67',80,'2026-11-25 21:50:05'),
(7,4,2026,10,'2650.00','1413.33',80,'2026-11-25 21:50:05'),
(8,2,2026,10,NULL,'81666.67',80,'2026-11-25 21:50:05');

-- asset_meter_readings (2 rows)
INSERT INTO `asset_meter_readings` (`asset_id`,`period_year`,`period_month`,`units`,`entered_by`,`entered_at`) VALUES
(4,2026,9,'2400.00',1,'2026-11-25 21:50:05'),
(4,2026,10,'2650.00',1,'2026-11-25 21:50:05');

-- asset_pm_schedules (4 rows)
INSERT INTO `asset_pm_schedules` (`id`,`asset_id`,`task_name`,`task_type`,`interval_value`,`interval_unit`,`meter_interval`,`next_due_date`,`next_due_meter`,`remind_days`,`last_done_date`,`last_done_meter`,`assigned_to`,`notes`,`is_active`,`created_by`,`created_at`,`updated_at`) VALUES
(1,2,'Vehicle registration renewal (LTO)','registration',1,'years',NULL,'2026-12-15',NULL,30,NULL,NULL,NULL,'Bring the OR/CR and the emission test result',1,1,'2026-11-25 21:50:04',NULL),
(2,2,'Change oil and oil filter','change_oil',3,'months','5000.00','2026-11-22','20000.00',7,NULL,NULL,NULL,NULL,1,1,'2026-11-25 21:50:04',NULL),
(3,2,'Reefer unit check (temperature hold test)','other',1,'months',NULL,'2026-11-30',NULL,5,NULL,NULL,NULL,'Must hold -18 C for 4 hours',1,1,'2026-11-25 21:50:04',NULL),
(4,3,'Clean the computers and POS units','cleaning',6,'months',NULL,'2027-02-08',NULL,14,NULL,NULL,NULL,NULL,1,1,'2026-11-25 21:50:04',NULL);

-- asset_maintenance (1 rows)
INSERT INTO `asset_maintenance` (`id`,`maint_no`,`asset_id`,`maint_date`,`maint_type`,`status`,`problem`,`description`,`vendor_id`,`performed_by`,`ref_no`,`meter_reading`,`downtime_days`,`parts_total`,`labor_total`,`tax_total`,`total`,`with_vat`,`payment_mode`,`pay_account_id`,`parts_account_id`,`labor_account_id`,`class_id`,`txn_id`,`schedule_id`,`next_service_date`,`notes`,`void_reason`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'MNT-00001',2,'2026-11-05','repair','completed','Reefer unit not holding temperature on long trips','Replaced the condenser fan motor and recharged the refrigerant.',7,'Coolwave service team','CRS-SV-0192','18200.00','1.00','14500.00','2500.00','0.00','17000.00',0,'bill',NULL,62,62,NULL,6,NULL,NULL,NULL,NULL,1,'2026-11-25 21:50:04',NULL);

-- asset_maintenance_parts (2 rows)
INSERT INTO `asset_maintenance_parts` (`id`,`maintenance_id`,`line_no`,`part_no`,`description`,`serial_no`,`model_no`,`size_spec`,`brand`,`qty`,`unit`,`unit_cost`,`amount`,`warranty_until`) VALUES
(1,1,1,'CFM-24V','Condenser fan motor','TK-778812','T-600','24 V','Thermo','1.0000','pc','11500.0000','11500.00','2027-11-05'),
(2,1,2,'R404A','Refrigerant R404A',NULL,NULL,NULL,'Freon','3.0000','kg','1000.0000','3000.00',NULL);

-- asset_maintenance_labor (2 rows)
INSERT INTO `asset_maintenance_labor` (`id`,`maintenance_id`,`line_no`,`description`,`worker`,`charge_type`,`hours`,`rate`,`amount`) VALUES
(1,1,1,'Replace fan motor and recharge','Coolwave technician','hourly','5.00','300.0000','1500.00'),
(2,1,2,'Temperature hold test',NULL,'bulk','0.00','0.0000','1000.00');

-- pos_terminals (2 rows)
INSERT INTO `pos_terminals` (`id`,`code`,`name`,`site_id`,`cash_account_id`,`receipt_prefix`,`next_receipt_no`,`next_z_no`,`is_active`,`class_id`) VALUES
(1,'POS-01','Naga Outlet Counter 1',2,2,'NO1-',9,2,1,2),
(2,'POS-02','Legazpi Depot Counter',3,2,'LG1-',1,1,1,3);

-- pos_shifts (2 rows)
INSERT INTO `pos_shifts` (`id`,`terminal_id`,`cashier_id`,`business_date`,`opened_at`,`opening_float`,`closed_at`,`expected_cash`,`counted_cash`,`over_short`,`over_short_txn_id`,`deposit_txn_id`,`status`,`closed_by`,`corrected_by`,`corrected_at`) VALUES
(1,1,9,'2026-11-24','2026-11-24 06:55:00','3000.00','2026-11-24 19:05:00','2921.92','2901.92','-20.00',88,NULL,'closed',8,NULL,NULL),
(2,1,9,'2026-11-25','2026-11-25 21:50:05','3000.00',NULL,NULL,NULL,NULL,NULL,NULL,'open',NULL,NULL,NULL);

-- pos_tenders (8 rows)
INSERT INTO `pos_tenders` (`id`,`txn_id`,`payment_method_id`,`amount`,`reference`) VALUES
(1,82,1,'812.00',NULL),
(2,83,3,'1717.41','APR4679'),
(3,84,4,'318.08','APR6914'),
(4,85,1,'953.12',NULL),
(5,86,1,'1182.72',NULL),
(6,87,1,'72.80','Refund'),
(7,89,1,'588.80',NULL),
(8,90,5,'537.60','APR2789');

-- pos_cash_drops (1 rows)
INSERT INTO `pos_cash_drops` (`id`,`shift_id`,`amount`,`reason`,`created_by`,`approved_by`,`created_at`) VALUES
(1,1,'2000.00','Excess cash to safe',9,NULL,'2026-11-25 21:50:05');

-- pos_readings (2 rows)
INSERT INTO `pos_readings` (`id`,`reading_type`,`terminal_id`,`shift_id`,`z_no`,`business_date`,`first_receipt`,`last_receipt`,`sales_count`,`gross_sales`,`discounts`,`returns`,`voids`,`net_sales`,`tax`,`tenders_json`,`cash_drops`,`expected_cash`,`counted_cash`,`over_short`,`created_by`,`created_at`) VALUES
(1,'X',1,1,NULL,'2026-11-24','NO1-00000001','NO1-00000005',4,'3598.40','0.00','72.80','953.12','3533.40','424.01','{\"Cash\":1921.92,\"Credit\\/Debit Card\":1717.41,\"GCash\":318.08}','2000.00','2921.92',NULL,NULL,8,'2026-11-25 21:50:05'),
(2,'Z',1,1,1,'2026-11-24','NO1-00000001','NO1-00000005',4,'3598.40','0.00','72.80','953.12','3533.40','424.01','{\"Cash\":1921.92,\"Credit\\/Debit Card\":1717.41,\"GCash\":318.08}','2000.00','2921.92','2901.92','-20.00',8,'2026-11-25 21:50:05');

-- bank_reconciliations (1 rows)
INSERT INTO `bank_reconciliations` (`id`,`account_id`,`statement_date`,`beginning_balance`,`ending_balance`,`cleared_balance`,`difference`,`service_charge_txn_id`,`interest_txn_id`,`service_charge`,`service_date`,`service_account_id`,`interest_earned`,`interest_date`,`interest_account_id`,`class_id`,`status`,`created_by`,`created_at`,`completed_by`,`completed_at`) VALUES
(1,5,'2026-09-30','0.00','1178450.00','1178450.00','0.00',81,NULL,'0.00',NULL,NULL,'0.00',NULL,NULL,NULL,'completed',1,'2026-11-25 21:50:05',1,'2026-10-05 00:00:00');

-- reconciliation_items (5 rows)
INSERT INTO `reconciliation_items` (`reconciliation_id`,`txn_id`,`amount`,`cleared`) VALUES
(1,1,'3200000.00',1),
(1,2,'-1850000.00',1),
(1,4,'-65000.00',1),
(1,57,'-106400.00',1),
(1,81,'-150.00',1);

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
(1,'general','General Discussion','Everyday conversations and community interactions.','chat','everyone',0,0,10,NULL,'2026-11-25 21:50:04',NULL),
(2,'questions','Questions and Inquiries','General questions that need answers.','chat','everyone',0,0,20,NULL,'2026-11-25 21:50:04',NULL),
(3,'help','Help and Support','Help with the system, your account or a technical problem.','chat','everyone',0,0,30,NULL,'2026-11-25 21:50:04',NULL),
(4,'announcements','Announcements','Important updates from the administrators.','announcement','moderators',0,0,40,NULL,'2026-11-25 21:50:04',NULL),
(5,'suggestions','Suggestions and Feedback','Recommendations and requests for improvement.','chat','everyone',0,0,50,NULL,'2026-11-25 21:50:04',NULL),
(6,'concerns','Community Concerns','Questions and concerns that can be discussed openly.','chat','everyone',0,0,60,NULL,'2026-11-25 21:50:04',NULL);

-- community_inquiry_categories (6 rows)
INSERT INTO `community_inquiry_categories` (`id`,`name`,`description`,`sort_order`,`is_active`) VALUES
(1,'General',NULL,10,1),
(2,'Accounts and Access',NULL,20,1),
(3,'Transactions',NULL,30,1),
(4,'Reports',NULL,40,1),
(5,'Technical Issues',NULL,50,1),
(6,'Suggestions',NULL,60,1);

-- vendor_items (12 rows)
INSERT INTO `vendor_items` (`id`,`vendor_id`,`item_id`,`uom_id`,`vendor_code`,`last_cost`,`sort_order`,`is_active`) VALUES
(1,1,1,2,NULL,'142.0000',1,1),
(2,1,2,2,NULL,'150.0000',2,1),
(3,1,3,2,NULL,'135.0000',3,1),
(4,1,4,2,NULL,'185.0000',4,1),
(5,1,7,2,NULL,'95.0000',5,1),
(6,1,9,6,NULL,'25.0000',6,1),
(7,2,1,2,NULL,'140.0000',1,1),
(8,2,5,2,NULL,'175.0000',2,1),
(9,2,6,2,NULL,'190.0000',3,1),
(10,2,8,2,NULL,'110.0000',4,1),
(11,2,10,4,NULL,'48.0000',5,1),
(12,2,11,4,NULL,'95.0000',6,1);

-- supplier_allocations (10 rows)
INSERT INTO `supplier_allocations` (`id`,`alloc_no`,`alloc_date`,`vendor_id`,`site_id`,`assigned_user_id`,`assigned_to`,`class_id`,`status`,`memo`,`picked_at`,`picked_by`,`receipt_txn_id`,`created_by`,`created_at`,`updated_at`) VALUES
(1,'AL-00001','2026-09-26',1,1,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,10,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(2,'AL-00002','2026-10-04',2,1,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,11,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(3,'AL-00003','2026-10-11',1,1,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,12,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(4,'AL-00004','2026-10-26',1,1,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,13,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(5,'AL-00005','2026-11-04',2,3,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,14,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(6,'AL-00006','2026-11-16',1,1,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,15,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(7,'AL-00007','2026-11-23',1,1,10,NULL,1,'received',NULL,'2026-11-25 21:50:04',10,16,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(8,'AL-00008','2026-11-25',1,1,10,NULL,1,'picking',NULL,NULL,NULL,NULL,6,'2026-11-25 21:50:04','2026-11-25 21:50:04'),
(9,'AL-00009','2026-11-25',2,3,10,NULL,1,'open',NULL,NULL,NULL,NULL,6,'2026-11-25 21:50:04','2026-11-25 06:10:00'),
(10,'AL-00010','2026-11-26',1,1,10,NULL,1,'open',NULL,NULL,NULL,NULL,6,'2026-11-25 21:50:04','2026-11-26 06:10:00');

-- supplier_allocation_lines (35 rows)
INSERT INTO `supplier_allocation_lines` (`id`,`allocation_id`,`line_no`,`item_id`,`uom_id`,`unit_code`,`qty`,`picked`,`picked_count`,`picked_qty`,`rate`,`receipt_line_id`) VALUES
(1,1,1,1,2,'CRT','10.0000',1,'10.0000','125.8600','0.0000',23),
(2,1,2,2,2,'CRT','6.0000',1,'6.0000','87.2400','0.0000',24),
(3,1,3,3,2,'CRT','5.0000',1,'4.0000','57.0000','0.0000',25),
(4,1,4,9,6,'kg','30.0000',1,'29.7000','29.7000','0.0000',26),
(5,2,1,5,2,'CRT','6.0000',1,'6.0000','94.0000','0.0000',27),
(6,2,2,6,2,'CRT','4.0000',1,'4.0000','45.0000','0.0000',28),
(7,2,3,10,4,'CRT','5.0000',1,'4.0000','162.0000','0.0000',29),
(8,3,1,1,2,'CRT','12.0000',1,'12.0000','148.8200','0.0000',30),
(9,3,2,4,2,'CRT','5.0000',1,'5.0000','74.0000','0.0000',31),
(10,3,3,7,2,'CRT','3.0000',1,'3.0000','33.0000','0.0000',32),
(11,4,1,1,2,'CRT','10.0000',1,'10.0000','123.1200','0.0000',33),
(12,4,2,2,2,'CRT','6.0000',1,'6.0000','91.4800','0.0000',34),
(13,4,3,3,2,'CRT','4.0000',1,'4.0000','58.0000','0.0000',35),
(14,4,4,9,6,'kg','25.0000',1,'25.0000','25.0000','0.0000',36),
(15,5,1,1,2,'CRT','8.0000',1,'8.0000','96.3700','0.0000',37),
(16,5,2,5,2,'CRT','4.0000',1,'4.0000','61.0000','0.0000',38),
(17,5,3,8,2,'CRT','2.0000',1,'2.0000','17.0000','0.0000',39),
(18,5,4,11,4,'CRT','3.0000',1,'3.0000','73.0000','0.0000',40),
(19,6,1,1,2,'CRT','10.0000',1,'10.0000','124.2400','0.0000',41),
(20,6,2,4,2,'CRT','4.0000',1,'4.0000','66.0000','0.0000',42),
(21,6,3,3,2,'CRT','4.0000',1,'4.0000','59.0000','0.0000',43),
(22,7,1,1,2,'CRT','8.0000',1,'8.0000','100.9900','0.0000',44),
(23,7,2,2,2,'CRT','5.0000',1,'5.0000','72.9600','0.0000',45),
(24,7,3,7,2,'CRT','2.0000',1,'2.0000','24.0000','0.0000',46),
(25,7,4,9,6,'kg','20.0000',1,'20.4000','20.4000','0.0000',47),
(26,8,1,1,2,'CRT','5.0000',1,'5.0000','62.6600','0.0000',NULL),
(27,8,2,2,2,'CRT','5.0000',0,'0.0000','0.0000','0.0000',NULL),
(28,8,3,3,2,'CRT','3.0000',0,'0.0000','0.0000','0.0000',NULL),
(29,8,4,9,6,'kg','20.0000',0,'0.0000','0.0000','0.0000',NULL),
(30,9,1,5,2,'CRT','4.0000',0,'0.0000','0.0000','0.0000',NULL),
(31,9,2,6,2,'CRT','3.0000',0,'0.0000','0.0000','0.0000',NULL),
(32,9,3,10,4,'CRT','4.0000',0,'0.0000','0.0000','0.0000',NULL),
(33,9,4,11,4,'CRT','2.0000',0,'0.0000','0.0000','0.0000',NULL),
(34,10,1,1,2,'CRT','15.0000',0,'0.0000','0.0000','0.0000',NULL),
(35,10,2,4,2,'CRT','4.0000',0,'0.0000','0.0000','0.0000',NULL);

-- supplier_allocation_crates (129 rows)
INSERT INTO `supplier_allocation_crates` (`id`,`line_id`,`seq`,`crate_no`,`pcs`,`qty`,`production_date`,`expiry_date`) VALUES
(1,1,1,'55','11.00','12.6000','2026-09-25','2026-10-07'),
(2,1,2,'56','11.00','12.5500','2026-09-25','2026-10-07'),
(3,1,3,'57','11.00','12.7300','2026-09-25','2026-10-07'),
(4,1,4,'58','10.00','12.1200','2026-09-25','2026-10-07'),
(5,1,5,'59','11.00','12.3200','2026-09-25','2026-10-07'),
(6,1,6,'60','11.00','12.9700','2026-09-25','2026-10-07'),
(7,1,7,'61','10.00','12.9300','2026-09-25','2026-10-07'),
(8,1,8,'62','10.00','12.8300','2026-09-25','2026-10-07'),
(9,1,9,'63','12.00','12.2600','2026-09-25','2026-10-07'),
(10,1,10,'64','12.00','12.5500','2026-09-25','2026-10-07'),
(11,2,1,'65','8.00','14.2100','2026-09-25','2026-10-05'),
(12,2,2,'66','10.00','14.8600','2026-09-25','2026-10-05'),
(13,2,3,'67','9.00','14.5200','2026-09-25','2026-10-05'),
(14,2,4,'68','9.00','14.5900','2026-09-25','2026-10-05'),
(15,2,5,'69','8.00','14.6500','2026-09-25','2026-10-05'),
(16,2,6,'70','8.00','14.4100','2026-09-25','2026-10-05'),
(17,3,1,'71','0.00','13.0000','2026-09-25','2027-03-24'),
(18,3,2,'72','0.00','13.0000','2026-09-25','2027-03-24'),
(19,3,3,'73','0.00','17.0000','2026-09-25','2027-03-24'),
(20,3,4,'74','0.00','14.0000','2026-09-25','2027-03-24'),
(21,5,1,'75','0.00','16.0000','2026-10-03','2027-04-01'),
(22,5,2,'76','0.00','15.0000','2026-10-03','2027-04-01'),
(23,5,3,'77','0.00','17.0000','2026-10-03','2027-04-01'),
(24,5,4,'78','0.00','15.0000','2026-10-03','2027-04-01'),
(25,5,5,'79','0.00','16.0000','2026-10-03','2027-04-01'),
(26,5,6,'80','0.00','15.0000','2026-10-03','2027-04-01'),
(27,6,1,'81','0.00','10.0000','2026-10-03','2027-04-01'),
(28,6,2,'82','0.00','10.0000','2026-10-03','2027-04-01'),
(29,6,3,'83','0.00','11.0000','2026-10-03','2027-04-01'),
(30,6,4,'84','0.00','14.0000','2026-10-03','2027-04-01'),
(31,7,1,'85','0.00','40.0000','2026-10-03','2027-06-30'),
(32,7,2,'86','0.00','40.0000','2026-10-03','2027-06-30'),
(33,7,3,'87','0.00','40.0000','2026-10-03','2027-06-30'),
(34,7,4,'88','0.00','42.0000','2026-10-03','2027-06-30'),
(35,8,1,'89','12.00','12.9800','2026-10-10','2026-10-22'),
(36,8,2,'90','12.00','12.9100','2026-10-10','2026-10-22'),
(37,8,3,'91','10.00','12.5000','2026-10-10','2026-10-22'),
(38,8,4,'92','10.00','12.2000','2026-10-10','2026-10-22'),
(39,8,5,'93','12.00','11.9300','2026-10-10','2026-10-22'),
(40,8,6,'94','11.00','12.7100','2026-10-10','2026-10-22'),
(41,8,7,'95','12.00','12.2000','2026-10-10','2026-10-22'),
(42,8,8,'96','11.00','12.1800','2026-10-10','2026-10-22'),
(43,8,9,'97','10.00','12.3900','2026-10-10','2026-10-22'),
(44,8,10,'98','10.00','12.7300','2026-10-10','2026-10-22'),
(45,8,11,'99','11.00','11.9800','2026-10-10','2026-10-22'),
(46,8,12,'100','11.00','12.1100','2026-10-10','2026-10-22'),
(47,9,1,'101','0.00','17.0000','2026-10-10','2027-04-08'),
(48,9,2,'102','0.00','14.0000','2026-10-10','2027-04-08'),
(49,9,3,'103','0.00','14.0000','2026-10-10','2027-04-08'),
(50,9,4,'104','0.00','13.0000','2026-10-10','2027-04-08'),
(51,9,5,'105','0.00','16.0000','2026-10-10','2027-04-08'),
(52,10,1,'106','0.00','11.0000','2026-10-10','2027-01-08'),
(53,10,2,'107','0.00','10.0000','2026-10-10','2027-01-08'),
(54,10,3,'108','0.00','12.0000','2026-10-10','2027-01-08'),
(55,11,1,'109','11.00','12.2400','2026-10-25','2026-11-06'),
(56,11,2,'110','12.00','12.4800','2026-10-25','2026-11-06'),
(57,11,3,'111','11.00','11.8700','2026-10-25','2026-11-06'),
(58,11,4,'112','11.00','12.6500','2026-10-25','2026-11-06'),
(59,11,5,'113','12.00','12.0200','2026-10-25','2026-11-06'),
(60,11,6,'114','10.00','12.1200','2026-10-25','2026-11-06'),
(61,11,7,'115','10.00','12.5600','2026-10-25','2026-11-06'),
(62,11,8,'116','12.00','11.7100','2026-10-25','2026-11-06'),
(63,11,9,'117','11.00','12.6900','2026-10-25','2026-11-06'),
(64,11,10,'118','11.00','12.7800','2026-10-25','2026-11-06'),
(65,12,1,'119','8.00','15.4300','2026-10-25','2026-11-04'),
(66,12,2,'120','10.00','15.3500','2026-10-25','2026-11-04'),
(67,12,3,'121','9.00','14.7000','2026-10-25','2026-11-04'),
(68,12,4,'122','10.00','15.4600','2026-10-25','2026-11-04'),
(69,12,5,'123','8.00','15.1400','2026-10-25','2026-11-04'),
(70,12,6,'124','10.00','15.4000','2026-10-25','2026-11-04'),
(71,13,1,'125','0.00','14.0000','2026-10-25','2027-04-23'),
(72,13,2,'126','0.00','16.0000','2026-10-25','2027-04-23'),
(73,13,3,'127','0.00','14.0000','2026-10-25','2027-04-23'),
(74,13,4,'128','0.00','14.0000','2026-10-25','2027-04-23'),
(75,15,1,'129','12.00','12.3900','2026-11-03','2026-11-15'),
(76,15,2,'130','10.00','11.7300','2026-11-03','2026-11-15'),
(77,15,3,'131','12.00','11.9700','2026-11-03','2026-11-15'),
(78,15,4,'132','12.00','12.0200','2026-11-03','2026-11-15'),
(79,15,5,'133','12.00','12.3600','2026-11-03','2026-11-15'),
(80,15,6,'134','12.00','12.2300','2026-11-03','2026-11-15'),
(81,15,7,'135','11.00','12.0600','2026-11-03','2026-11-15'),
(82,15,8,'136','11.00','11.6100','2026-11-03','2026-11-15'),
(83,16,1,'137','0.00','17.0000','2026-11-03','2027-05-02'),
(84,16,2,'138','0.00','15.0000','2026-11-03','2027-05-02'),
(85,16,3,'139','0.00','13.0000','2026-11-03','2027-05-02'),
(86,16,4,'140','0.00','16.0000','2026-11-03','2027-05-02'),
(87,17,1,'141','0.00','8.0000','2026-11-03','2027-02-01'),
(88,17,2,'142','0.00','9.0000','2026-11-03','2027-02-01'),
(89,18,1,'143','0.00','26.0000','2026-11-03','2027-07-31'),
(90,18,2,'144','0.00','22.0000','2026-11-03','2027-07-31'),
(91,18,3,'145','0.00','25.0000','2026-11-03','2027-07-31'),
(92,19,1,'146','12.00','12.7100','2026-11-15','2026-11-27'),
(93,19,2,'147','12.00','12.6600','2026-11-15','2026-11-27'),
(94,19,3,'148','11.00','11.8100','2026-11-15','2026-11-27'),
(95,19,4,'149','11.00','11.8700','2026-11-15','2026-11-27'),
(96,19,5,'150','12.00','12.9800','2026-11-15','2026-11-27'),
(97,19,6,'151','10.00','12.6100','2026-11-15','2026-11-27'),
(98,19,7,'152','10.00','11.9000','2026-11-15','2026-11-27'),
(99,19,8,'153','10.00','12.8900','2026-11-15','2026-11-27'),
(100,19,9,'154','11.00','12.5300','2026-11-15','2026-11-27');
INSERT INTO `supplier_allocation_crates` (`id`,`line_id`,`seq`,`crate_no`,`pcs`,`qty`,`production_date`,`expiry_date`) VALUES
(101,19,10,'155','11.00','12.2800','2026-11-15','2026-11-27'),
(102,20,1,'156','0.00','15.0000','2026-11-15','2027-05-14'),
(103,20,2,'157','0.00','17.0000','2026-11-15','2027-05-14'),
(104,20,3,'158','0.00','17.0000','2026-11-15','2027-05-14'),
(105,20,4,'159','0.00','17.0000','2026-11-15','2027-05-14'),
(106,21,1,'160','0.00','15.0000','2026-11-15','2027-05-14'),
(107,21,2,'161','0.00','13.0000','2026-11-15','2027-05-14'),
(108,21,3,'162','0.00','16.0000','2026-11-15','2027-05-14'),
(109,21,4,'163','0.00','15.0000','2026-11-15','2027-05-14'),
(110,22,1,'164','10.00','12.8700','2026-11-22','2026-12-04'),
(111,22,2,'165','11.00','12.9400','2026-11-22','2026-12-04'),
(112,22,3,'166','10.00','12.4100','2026-11-22','2026-12-04'),
(113,22,4,'167','11.00','12.5200','2026-11-22','2026-12-04'),
(114,22,5,'168','11.00','12.2500','2026-11-22','2026-12-04'),
(115,22,6,'169','12.00','12.5100','2026-11-22','2026-12-04'),
(116,22,7,'170','10.00','12.9700','2026-11-22','2026-12-04'),
(117,22,8,'171','11.00','12.5200','2026-11-22','2026-12-04'),
(118,23,1,'172','9.00','14.5400','2026-11-22','2026-12-02'),
(119,23,2,'173','8.00','14.3800','2026-11-22','2026-12-02'),
(120,23,3,'174','10.00','14.8100','2026-11-22','2026-12-02'),
(121,23,4,'175','10.00','14.5300','2026-11-22','2026-12-02'),
(122,23,5,'176','10.00','14.7000','2026-11-22','2026-12-02'),
(123,24,1,'177','0.00','12.0000','2026-11-22','2027-02-20'),
(124,24,2,'178','0.00','12.0000','2026-11-22','2027-02-20'),
(125,26,1,'179','12.00','12.9300','2026-11-24','2026-12-06'),
(126,26,2,'180','10.00','12.3500','2026-11-24','2026-12-06'),
(127,26,3,'181','12.00','12.2500','2026-11-24','2026-12-06'),
(128,26,4,'182','10.00','12.8800','2026-11-24','2026-12-06'),
(129,26,5,'183','10.00','12.2500','2026-11-24','2026-12-06');

-- crates (178 rows)
INSERT INTO `crates` (`id`,`crate_no`,`item_id`,`site_id`,`vendor_id`,`receive_txn_id`,`receive_line_id`,`allocation_id`,`received_date`,`pcs`,`qty_in`,`qty_left`,`unit_cost`,`production_date`,`expiry_date`,`status`,`converted_at`,`converted_by`,`convert_note`,`created_by`,`created_at`) VALUES
(1,'1',1,2,1,7,12,NULL,'2026-09-12','11.00','12.4200','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(2,'2',1,2,1,7,12,NULL,'2026-09-12','11.00','12.0000','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(3,'3',1,2,1,7,12,NULL,'2026-09-12','11.00','12.4700','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(4,'4',1,3,1,7,12,NULL,'2026-09-12','11.00','11.9500','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(5,'5',1,3,1,7,12,NULL,'2026-09-12','10.00','12.4900','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(6,'6',1,2,1,7,12,NULL,'2026-09-12','11.00','12.3100','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(7,'7',1,2,1,7,12,NULL,'2026-09-12','11.00','12.8900','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(8,'8',1,2,1,7,12,NULL,'2026-09-12','10.00','12.7900','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(9,'9',1,2,1,7,12,NULL,'2026-09-12','10.00','12.1100','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(10,'10',1,2,1,7,12,NULL,'2026-09-12','11.00','12.5000','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(11,'11',1,2,1,7,12,NULL,'2026-09-12','12.00','12.5700','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(12,'12',1,2,1,7,12,NULL,'2026-09-12','11.00','12.2400','0.0000','142.0000','2026-09-11','2026-09-23','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(13,'13',4,3,1,7,13,NULL,'2026-09-12','0.00','14.9600','6.9600','185.0000','2026-09-10','2027-03-09','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(14,'14',4,3,1,7,13,NULL,'2026-09-12','0.00','15.2500','15.2500','185.0000','2026-09-10','2027-03-09','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(15,'15',4,2,1,7,13,NULL,'2026-09-12','0.00','14.9000','14.9000','185.0000','2026-09-10','2027-03-09','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(16,'16',4,1,1,7,13,NULL,'2026-09-12','0.00','14.6100','0.0000','185.0000','2026-09-10','2027-03-09','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(17,'17',4,1,1,7,13,NULL,'2026-09-12','0.00','14.8600','0.0000','185.0000','2026-09-10','2027-03-09','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(18,'18',4,1,1,7,13,NULL,'2026-09-12','0.00','15.2300','0.0000','185.0000','2026-09-10','2027-03-09','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(19,'19',7,2,1,7,14,NULL,'2026-09-12','0.00','10.2200','9.0200','95.0000','2026-09-11','2026-12-10','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(20,'20',7,2,1,7,14,NULL,'2026-09-12','0.00','9.7200','9.7200','95.0000','2026-09-11','2026-12-10','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(21,'21',7,1,1,7,14,NULL,'2026-09-12','0.00','9.7100','3.2100','95.0000','2026-09-11','2026-12-10','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(22,'22',3,2,1,7,15,NULL,'2026-09-12','0.00','14.2600','14.2600','135.0000','2026-09-10','2027-03-09','converted','2026-11-25 21:50:04',1,'Repacked into 1 kg retail bags',1,'2026-11-25 21:50:04'),
(23,'23',3,2,1,7,15,NULL,'2026-09-12','0.00','14.3000','14.3000','135.0000','2026-09-10','2027-03-09','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(24,'24',3,1,1,7,15,NULL,'2026-09-12','0.00','13.9300','13.9300','135.0000','2026-09-10','2027-03-09','converted','2026-11-25 21:50:04',1,'Repacked into 1 kg retail bags',1,'2026-11-25 21:50:04'),
(25,'25',3,1,1,7,15,NULL,'2026-09-12','0.00','14.4700','0.0000','135.0000','2026-09-10','2027-03-09','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(26,'26',3,1,1,7,15,NULL,'2026-09-12','0.00','14.9700','0.0000','135.0000','2026-09-10','2027-03-09','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(27,'27',3,1,1,7,15,NULL,'2026-09-12','0.00','14.0900','0.0000','135.0000','2026-09-10','2027-03-09','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(28,'28',5,2,2,8,17,NULL,'2026-09-14','0.00','15.6100','15.6100','175.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(29,'29',5,2,2,8,17,NULL,'2026-09-14','0.00','14.7600','14.7600','175.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(30,'30',5,3,2,8,17,NULL,'2026-09-14','0.00','15.3600','0.0000','175.0000','2026-09-12','2027-03-11','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(31,'31',5,3,2,8,17,NULL,'2026-09-14','0.00','15.5300','5.5300','175.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(32,'32',5,1,2,8,17,NULL,'2026-09-14','0.00','15.6500','0.0000','175.0000','2026-09-12','2027-03-11','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(33,'33',5,1,2,8,17,NULL,'2026-09-14','0.00','15.3400','0.0000','175.0000','2026-09-12','2027-03-11','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(34,'34',5,6,2,8,17,NULL,'2026-09-14','0.00','15.4200','0.0000','175.0000','2026-09-12','2027-03-11','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(35,'35',5,6,2,8,17,NULL,'2026-09-14','0.00','15.1400','15.1400','175.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(36,'36',6,2,2,8,18,NULL,'2026-09-14','0.00','12.2500','12.2500','190.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(37,'37',6,1,2,8,18,NULL,'2026-09-14','0.00','12.3600','0.0000','190.0000','2026-09-12','2027-03-11','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(38,'38',6,1,2,8,18,NULL,'2026-09-14','0.00','12.2600','6.1200','190.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(39,'39',6,1,2,8,18,NULL,'2026-09-14','0.00','11.6200','11.6200','190.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(40,'40',6,1,2,8,18,NULL,'2026-09-14','0.00','11.7200','11.7200','190.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(41,'41',6,1,2,8,18,NULL,'2026-09-14','0.00','12.2100','12.2100','190.0000','2026-09-12','2027-03-11','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(42,'42',8,1,2,8,19,NULL,'2026-09-14','0.00','10.0100','7.0100','110.0000','2026-09-13','2026-12-12','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(43,'43',8,1,2,8,19,NULL,'2026-09-14','0.00','9.8400','9.8400','110.0000','2026-09-13','2026-12-12','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(44,'44',8,1,2,8,19,NULL,'2026-09-14','0.00','10.2400','10.2400','110.0000','2026-09-13','2026-12-12','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(45,'45',10,2,2,8,20,NULL,'2026-09-14','0.00','40.0000','33.0000','48.0000','2026-09-06','2027-06-03','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(46,'46',10,2,2,8,20,NULL,'2026-09-14','0.00','40.0000','40.0000','48.0000','2026-09-06','2027-06-03','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(47,'47',10,3,2,8,20,NULL,'2026-09-14','0.00','40.0000','40.0000','48.0000','2026-09-06','2027-06-03','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(48,'48',10,1,2,8,20,NULL,'2026-09-14','0.00','40.0000','32.0000','48.0000','2026-09-06','2027-06-03','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(49,'49',10,1,2,8,20,NULL,'2026-09-14','0.00','40.0000','40.0000','48.0000','2026-09-06','2027-06-03','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(50,'50',10,1,2,8,20,NULL,'2026-09-14','0.00','40.0000','40.0000','48.0000','2026-09-06','2027-06-03','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(51,'51',11,2,2,8,21,NULL,'2026-09-14','0.00','24.0000','21.0000','95.0000','2026-09-04','2027-06-01','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(52,'52',11,1,2,8,21,NULL,'2026-09-14','0.00','24.0000','0.0000','95.0000','2026-09-04','2027-06-01','sold',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(53,'53',11,1,2,8,21,NULL,'2026-09-14','0.00','24.0000','24.0000','95.0000','2026-09-04','2027-06-01','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(54,'54',11,1,2,8,21,NULL,'2026-09-14','0.00','24.0000','24.0000','95.0000','2026-09-04','2027-06-01','open',NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(55,'55',1,2,1,10,23,1,'2026-09-26','11.00','12.6000','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(56,'56',1,2,1,10,23,1,'2026-09-26','11.00','12.5500','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(57,'57',1,2,1,10,23,1,'2026-09-26','11.00','12.7300','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(58,'58',1,1,1,10,23,1,'2026-09-26','10.00','12.1200','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(59,'59',1,1,1,10,23,1,'2026-09-26','11.00','12.3200','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(60,'60',1,1,1,10,23,1,'2026-09-26','11.00','12.9700','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(61,'61',1,1,1,10,23,1,'2026-09-26','10.00','12.9300','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(62,'62',1,1,1,10,23,1,'2026-09-26','10.00','12.8300','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(63,'63',1,1,1,10,23,1,'2026-09-26','12.00','12.2600','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(64,'64',1,1,1,10,23,1,'2026-09-26','12.00','12.5500','0.0000','142.0000','2026-09-25','2026-10-07','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(65,'65',2,2,1,10,24,1,'2026-09-26','8.00','14.2100','0.0000','150.0000','2026-09-25','2026-10-05','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(66,'66',2,2,1,10,24,1,'2026-09-26','10.00','14.8600','0.0000','150.0000','2026-09-25','2026-10-05','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(67,'67',2,2,1,10,24,1,'2026-09-26','9.00','14.5200','0.0000','150.0000','2026-09-25','2026-10-05','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(68,'68',2,2,1,10,24,1,'2026-09-26','9.00','14.5900','0.0000','150.0000','2026-09-25','2026-10-05','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(69,'69',2,1,1,10,24,1,'2026-09-26','8.00','14.6500','0.0000','150.0000','2026-09-25','2026-10-05','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(70,'70',2,1,1,10,24,1,'2026-09-26','8.00','14.4100','0.0000','150.0000','2026-09-25','2026-10-05','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(71,'71',3,1,1,10,25,1,'2026-09-26','0.00','13.0000','7.5300','135.0000','2026-09-25','2027-03-24','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(72,'72',3,1,1,10,25,1,'2026-09-26','0.00','13.0000','13.0000','135.0000','2026-09-25','2027-03-24','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(73,'73',3,1,1,10,25,1,'2026-09-26','0.00','17.0000','17.0000','135.0000','2026-09-25','2027-03-24','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(74,'74',3,1,1,10,25,1,'2026-09-26','0.00','14.0000','14.0000','135.0000','2026-09-25','2027-03-24','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(75,'75',5,1,2,11,27,2,'2026-10-04','0.00','16.0000','16.0000','175.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(76,'76',5,1,2,11,27,2,'2026-10-04','0.00','15.0000','15.0000','175.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(77,'77',5,1,2,11,27,2,'2026-10-04','0.00','17.0000','17.0000','175.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(78,'78',5,1,2,11,27,2,'2026-10-04','0.00','15.0000','15.0000','175.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(79,'79',5,1,2,11,27,2,'2026-10-04','0.00','16.0000','16.0000','175.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(80,'80',5,1,2,11,27,2,'2026-10-04','0.00','15.0000','15.0000','175.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(81,'81',6,1,2,11,28,2,'2026-10-04','0.00','10.0000','10.0000','190.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(82,'82',6,1,2,11,28,2,'2026-10-04','0.00','10.0000','10.0000','190.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(83,'83',6,1,2,11,28,2,'2026-10-04','0.00','11.0000','11.0000','190.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(84,'84',6,1,2,11,28,2,'2026-10-04','0.00','14.0000','14.0000','190.0000','2026-10-03','2027-04-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(85,'85',10,1,2,11,29,2,'2026-10-04','0.00','40.0000','40.0000','48.0000','2026-10-03','2027-06-30','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(86,'86',10,1,2,11,29,2,'2026-10-04','0.00','40.0000','40.0000','48.0000','2026-10-03','2027-06-30','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(87,'87',10,1,2,11,29,2,'2026-10-04','0.00','40.0000','40.0000','48.0000','2026-10-03','2027-06-30','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(88,'88',10,1,2,11,29,2,'2026-10-04','0.00','42.0000','42.0000','48.0000','2026-10-03','2027-06-30','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(89,'89',1,1,1,12,30,3,'2026-10-11','12.00','12.9800','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(90,'90',1,1,1,12,30,3,'2026-10-11','12.00','12.9100','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(91,'91',1,1,1,12,30,3,'2026-10-11','10.00','12.5000','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(92,'92',1,1,1,12,30,3,'2026-10-11','10.00','12.2000','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(93,'93',1,1,1,12,30,3,'2026-10-11','12.00','11.9300','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(94,'94',1,1,1,12,30,3,'2026-10-11','11.00','12.7100','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(95,'95',1,1,1,12,30,3,'2026-10-11','12.00','12.2000','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(96,'96',1,1,1,12,30,3,'2026-10-11','11.00','12.1800','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(97,'97',1,1,1,12,30,3,'2026-10-11','10.00','12.3900','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(98,'98',1,1,1,12,30,3,'2026-10-11','10.00','12.7300','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(99,'99',1,1,1,12,30,3,'2026-10-11','11.00','11.9800','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(100,'100',1,1,1,12,30,3,'2026-10-11','11.00','12.1100','0.0000','142.0000','2026-10-10','2026-10-22','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04');
INSERT INTO `crates` (`id`,`crate_no`,`item_id`,`site_id`,`vendor_id`,`receive_txn_id`,`receive_line_id`,`allocation_id`,`received_date`,`pcs`,`qty_in`,`qty_left`,`unit_cost`,`production_date`,`expiry_date`,`status`,`converted_at`,`converted_by`,`convert_note`,`created_by`,`created_at`) VALUES
(101,'101',4,1,1,12,31,3,'2026-10-11','0.00','17.0000','0.0000','185.0000','2026-10-10','2027-04-08','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(102,'102',4,1,1,12,31,3,'2026-10-11','0.00','14.0000','0.0000','185.0000','2026-10-10','2027-04-08','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(103,'103',4,1,1,12,31,3,'2026-10-11','0.00','14.0000','0.0000','185.0000','2026-10-10','2027-04-08','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(104,'104',4,1,1,12,31,3,'2026-10-11','0.00','13.0000','7.8800','185.0000','2026-10-10','2027-04-08','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(105,'105',4,1,1,12,31,3,'2026-10-11','0.00','16.0000','16.0000','185.0000','2026-10-10','2027-04-08','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(106,'106',7,1,1,12,32,3,'2026-10-11','0.00','11.0000','11.0000','95.0000','2026-10-10','2027-01-08','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(107,'107',7,1,1,12,32,3,'2026-10-11','0.00','10.0000','10.0000','95.0000','2026-10-10','2027-01-08','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(108,'108',7,1,1,12,32,3,'2026-10-11','0.00','12.0000','12.0000','95.0000','2026-10-10','2027-01-08','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(109,'109',1,1,1,13,33,4,'2026-10-26','11.00','12.2400','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(110,'110',1,1,1,13,33,4,'2026-10-26','12.00','12.4800','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(111,'111',1,1,1,13,33,4,'2026-10-26','11.00','11.8700','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(112,'112',1,1,1,13,33,4,'2026-10-26','11.00','12.6500','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(113,'113',1,1,1,13,33,4,'2026-10-26','12.00','12.0200','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(114,'114',1,1,1,13,33,4,'2026-10-26','10.00','12.1200','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(115,'115',1,1,1,13,33,4,'2026-10-26','10.00','12.5600','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(116,'116',1,1,1,13,33,4,'2026-10-26','12.00','11.7100','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(117,'117',1,1,1,13,33,4,'2026-10-26','11.00','12.6900','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(118,'118',1,1,1,13,33,4,'2026-10-26','11.00','12.7800','0.0000','142.0000','2026-10-25','2026-11-06','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(119,'119',2,1,1,13,34,4,'2026-10-26','8.00','15.4300','0.0000','150.0000','2026-10-25','2026-11-04','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(120,'120',2,1,1,13,34,4,'2026-10-26','10.00','15.3500','0.0000','150.0000','2026-10-25','2026-11-04','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(121,'121',2,1,1,13,34,4,'2026-10-26','9.00','14.7000','0.0000','150.0000','2026-10-25','2026-11-04','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(122,'122',2,1,1,13,34,4,'2026-10-26','10.00','15.4600','0.0000','150.0000','2026-10-25','2026-11-04','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(123,'123',2,1,1,13,34,4,'2026-10-26','8.00','15.1400','0.0000','150.0000','2026-10-25','2026-11-04','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(124,'124',2,1,1,13,34,4,'2026-10-26','10.00','15.4000','0.0000','150.0000','2026-10-25','2026-11-04','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(125,'125',3,1,1,13,35,4,'2026-10-26','0.00','14.0000','14.0000','135.0000','2026-10-25','2027-04-23','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(126,'126',3,1,1,13,35,4,'2026-10-26','0.00','16.0000','16.0000','135.0000','2026-10-25','2027-04-23','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(127,'127',3,1,1,13,35,4,'2026-10-26','0.00','14.0000','14.0000','135.0000','2026-10-25','2027-04-23','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(128,'128',3,1,1,13,35,4,'2026-10-26','0.00','14.0000','14.0000','135.0000','2026-10-25','2027-04-23','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(129,'129',1,3,2,14,37,5,'2026-11-04','12.00','12.3900','0.0000','140.0000','2026-11-03','2026-11-15','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(130,'130',1,3,2,14,37,5,'2026-11-04','10.00','11.7300','0.0000','140.0000','2026-11-03','2026-11-15','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(131,'131',1,3,2,14,37,5,'2026-11-04','12.00','11.9700','0.0000','140.0000','2026-11-03','2026-11-15','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(132,'132',1,3,2,14,37,5,'2026-11-04','12.00','12.0200','0.0000','140.0000','2026-11-03','2026-11-15','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(133,'133',1,3,2,14,37,5,'2026-11-04','12.00','12.3600','12.3600','140.0000','2026-11-03','2026-11-15','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(134,'134',1,3,2,14,37,5,'2026-11-04','12.00','12.2300','12.2300','140.0000','2026-11-03','2026-11-15','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(135,'135',1,3,2,14,37,5,'2026-11-04','11.00','12.0600','12.0600','140.0000','2026-11-03','2026-11-15','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(136,'136',1,3,2,14,37,5,'2026-11-04','11.00','11.6100','11.6100','140.0000','2026-11-03','2026-11-15','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(137,'137',5,3,2,14,38,5,'2026-11-04','0.00','17.0000','17.0000','175.0000','2026-11-03','2027-05-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(138,'138',5,3,2,14,38,5,'2026-11-04','0.00','15.0000','15.0000','175.0000','2026-11-03','2027-05-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(139,'139',5,3,2,14,38,5,'2026-11-04','0.00','13.0000','13.0000','175.0000','2026-11-03','2027-05-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(140,'140',5,3,2,14,38,5,'2026-11-04','0.00','16.0000','16.0000','175.0000','2026-11-03','2027-05-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(141,'141',8,3,2,14,39,5,'2026-11-04','0.00','8.0000','8.0000','110.0000','2026-11-03','2027-02-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(142,'142',8,3,2,14,39,5,'2026-11-04','0.00','9.0000','9.0000','110.0000','2026-11-03','2027-02-01','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(143,'143',11,3,2,14,40,5,'2026-11-04','0.00','26.0000','26.0000','95.0000','2026-11-03','2027-07-31','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(144,'144',11,3,2,14,40,5,'2026-11-04','0.00','22.0000','22.0000','95.0000','2026-11-03','2027-07-31','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(145,'145',11,3,2,14,40,5,'2026-11-04','0.00','25.0000','25.0000','95.0000','2026-11-03','2027-07-31','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(146,'146',1,1,1,15,41,6,'2026-11-16','12.00','12.7100','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(147,'147',1,1,1,15,41,6,'2026-11-16','12.00','12.6600','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(148,'148',1,1,1,15,41,6,'2026-11-16','11.00','11.8100','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(149,'149',1,1,1,15,41,6,'2026-11-16','11.00','11.8700','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(150,'150',1,1,1,15,41,6,'2026-11-16','12.00','12.9800','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(151,'151',1,1,1,15,41,6,'2026-11-16','10.00','12.6100','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(152,'152',1,1,1,15,41,6,'2026-11-16','10.00','11.9000','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(153,'153',1,6,1,15,41,6,'2026-11-16','10.00','12.8900','0.0000','142.0000','2026-11-15','2026-11-27','sold',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(154,'154',1,6,1,15,41,6,'2026-11-16','11.00','12.5300','1.9500','142.0000','2026-11-15','2026-11-27','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(155,'155',1,7,1,15,41,6,'2026-11-16','11.00','12.2800','0.0000','142.0000','2026-11-15','2026-11-27','used',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(156,'156',4,1,1,15,42,6,'2026-11-16','0.00','15.0000','15.0000','185.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(157,'157',4,1,1,15,42,6,'2026-11-16','0.00','17.0000','17.0000','185.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(158,'158',4,1,1,15,42,6,'2026-11-16','0.00','17.0000','17.0000','185.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(159,'159',4,1,1,15,42,6,'2026-11-16','0.00','17.0000','17.0000','185.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(160,'160',3,1,1,15,43,6,'2026-11-16','0.00','15.0000','15.0000','135.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(161,'161',3,1,1,15,43,6,'2026-11-16','0.00','13.0000','13.0000','135.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(162,'162',3,1,1,15,43,6,'2026-11-16','0.00','16.0000','16.0000','135.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(163,'163',3,1,1,15,43,6,'2026-11-16','0.00','15.0000','15.0000','135.0000','2026-11-15','2027-05-14','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(164,'164',1,6,1,16,44,7,'2026-11-23','10.00','12.8700','12.8700','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(165,'165',1,1,1,16,44,7,'2026-11-23','11.00','12.9400','12.9400','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(166,'166',1,1,1,16,44,7,'2026-11-23','10.00','12.4100','12.4100','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(167,'167',1,1,1,16,44,7,'2026-11-23','11.00','12.5200','12.5200','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(168,'168',1,1,1,16,44,7,'2026-11-23','11.00','12.2500','12.2500','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(169,'169',1,1,1,16,44,7,'2026-11-23','12.00','12.5100','12.5100','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(170,'170',1,1,1,16,44,7,'2026-11-23','10.00','12.9700','12.9700','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(171,'171',1,1,1,16,44,7,'2026-11-23','11.00','12.5200','12.5200','142.0000','2026-11-22','2026-12-04','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(172,'172',2,1,1,16,45,7,'2026-11-23','9.00','14.5400','14.4400','150.0000','2026-11-22','2026-12-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(173,'173',2,1,1,16,45,7,'2026-11-23','8.00','14.3800','14.3800','150.0000','2026-11-22','2026-12-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(174,'174',2,1,1,16,45,7,'2026-11-23','10.00','14.8100','14.8100','150.0000','2026-11-22','2026-12-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(175,'175',2,1,1,16,45,7,'2026-11-23','10.00','14.5300','14.5300','150.0000','2026-11-22','2026-12-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(176,'176',2,1,1,16,45,7,'2026-11-23','10.00','14.7000','14.7000','150.0000','2026-11-22','2026-12-02','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(177,'177',7,1,1,16,46,7,'2026-11-23','0.00','12.0000','12.0000','95.0000','2026-11-22','2027-02-20','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(178,'178',7,1,1,16,46,7,'2026-11-23','0.00','12.0000','12.0000','95.0000','2026-11-22','2027-02-20','open',NULL,NULL,NULL,10,'2026-11-25 21:50:04');

-- crate_movements (360 rows)
INSERT INTO `crate_movements` (`id`,`crate_id`,`move_date`,`kind`,`txn_id`,`line_id`,`qty`,`whole`,`site_id`,`site2_id`,`customer_id`,`note`,`created_by`,`created_at`) VALUES
(1,1,'2026-09-12','receive',7,12,'12.4200',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(2,2,'2026-09-12','receive',7,12,'12.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(3,3,'2026-09-12','receive',7,12,'12.4700',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(4,4,'2026-09-12','receive',7,12,'11.9500',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(5,5,'2026-09-12','receive',7,12,'12.4900',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(6,6,'2026-09-12','receive',7,12,'12.3100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(7,7,'2026-09-12','receive',7,12,'12.8900',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(8,8,'2026-09-12','receive',7,12,'12.7900',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(9,9,'2026-09-12','receive',7,12,'12.1100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(10,10,'2026-09-12','receive',7,12,'12.5000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(11,11,'2026-09-12','receive',7,12,'12.5700',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(12,12,'2026-09-12','receive',7,12,'12.2400',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(13,13,'2026-09-12','receive',7,13,'14.9600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(14,14,'2026-09-12','receive',7,13,'15.2500',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(15,15,'2026-09-12','receive',7,13,'14.9000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(16,16,'2026-09-12','receive',7,13,'14.6100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(17,17,'2026-09-12','receive',7,13,'14.8600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(18,18,'2026-09-12','receive',7,13,'15.2300',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(19,19,'2026-09-12','receive',7,14,'10.2200',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(20,20,'2026-09-12','receive',7,14,'9.7200',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(21,21,'2026-09-12','receive',7,14,'9.7100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(22,22,'2026-09-12','receive',7,15,'14.2600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(23,23,'2026-09-12','receive',7,15,'14.3000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(24,24,'2026-09-12','receive',7,15,'13.9300',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(25,25,'2026-09-12','receive',7,15,'14.4700',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(26,26,'2026-09-12','receive',7,15,'14.9700',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(27,27,'2026-09-12','receive',7,15,'14.0900',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(28,28,'2026-09-14','receive',8,17,'15.6100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(29,29,'2026-09-14','receive',8,17,'14.7600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(30,30,'2026-09-14','receive',8,17,'15.3600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(31,31,'2026-09-14','receive',8,17,'15.5300',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(32,32,'2026-09-14','receive',8,17,'15.6500',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(33,33,'2026-09-14','receive',8,17,'15.3400',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(34,34,'2026-09-14','receive',8,17,'15.4200',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(35,35,'2026-09-14','receive',8,17,'15.1400',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(36,36,'2026-09-14','receive',8,18,'12.2500',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(37,37,'2026-09-14','receive',8,18,'12.3600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(38,38,'2026-09-14','receive',8,18,'12.2600',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(39,39,'2026-09-14','receive',8,18,'11.6200',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(40,40,'2026-09-14','receive',8,18,'11.7200',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(41,41,'2026-09-14','receive',8,18,'12.2100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(42,42,'2026-09-14','receive',8,19,'10.0100',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(43,43,'2026-09-14','receive',8,19,'9.8400',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(44,44,'2026-09-14','receive',8,19,'10.2400',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(45,45,'2026-09-14','receive',8,20,'40.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(46,46,'2026-09-14','receive',8,20,'40.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(47,47,'2026-09-14','receive',8,20,'40.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(48,48,'2026-09-14','receive',8,20,'40.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(49,49,'2026-09-14','receive',8,20,'40.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(50,50,'2026-09-14','receive',8,20,'40.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(51,51,'2026-09-14','receive',8,21,'24.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(52,52,'2026-09-14','receive',8,21,'24.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(53,53,'2026-09-14','receive',8,21,'24.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(54,54,'2026-09-14','receive',8,21,'24.0000',0,1,NULL,NULL,NULL,1,'2026-11-25 21:50:04'),
(55,55,'2026-09-26','receive',10,23,'12.6000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(56,56,'2026-09-26','receive',10,23,'12.5500',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(57,57,'2026-09-26','receive',10,23,'12.7300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(58,58,'2026-09-26','receive',10,23,'12.1200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(59,59,'2026-09-26','receive',10,23,'12.3200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(60,60,'2026-09-26','receive',10,23,'12.9700',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(61,61,'2026-09-26','receive',10,23,'12.9300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(62,62,'2026-09-26','receive',10,23,'12.8300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(63,63,'2026-09-26','receive',10,23,'12.2600',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(64,64,'2026-09-26','receive',10,23,'12.5500',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(65,65,'2026-09-26','receive',10,24,'14.2100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(66,66,'2026-09-26','receive',10,24,'14.8600',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(67,67,'2026-09-26','receive',10,24,'14.5200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(68,68,'2026-09-26','receive',10,24,'14.5900',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(69,69,'2026-09-26','receive',10,24,'14.6500',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(70,70,'2026-09-26','receive',10,24,'14.4100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(71,71,'2026-09-26','receive',10,25,'13.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(72,72,'2026-09-26','receive',10,25,'13.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(73,73,'2026-09-26','receive',10,25,'17.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(74,74,'2026-09-26','receive',10,25,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(75,75,'2026-10-04','receive',11,27,'16.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(76,76,'2026-10-04','receive',11,27,'15.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(77,77,'2026-10-04','receive',11,27,'17.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(78,78,'2026-10-04','receive',11,27,'15.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(79,79,'2026-10-04','receive',11,27,'16.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(80,80,'2026-10-04','receive',11,27,'15.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(81,81,'2026-10-04','receive',11,28,'10.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(82,82,'2026-10-04','receive',11,28,'10.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(83,83,'2026-10-04','receive',11,28,'11.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(84,84,'2026-10-04','receive',11,28,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(85,85,'2026-10-04','receive',11,29,'40.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(86,86,'2026-10-04','receive',11,29,'40.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(87,87,'2026-10-04','receive',11,29,'40.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(88,88,'2026-10-04','receive',11,29,'42.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(89,89,'2026-10-11','receive',12,30,'12.9800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(90,90,'2026-10-11','receive',12,30,'12.9100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(91,91,'2026-10-11','receive',12,30,'12.5000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(92,92,'2026-10-11','receive',12,30,'12.2000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(93,93,'2026-10-11','receive',12,30,'11.9300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(94,94,'2026-10-11','receive',12,30,'12.7100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(95,95,'2026-10-11','receive',12,30,'12.2000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(96,96,'2026-10-11','receive',12,30,'12.1800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(97,97,'2026-10-11','receive',12,30,'12.3900',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(98,98,'2026-10-11','receive',12,30,'12.7300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(99,99,'2026-10-11','receive',12,30,'11.9800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(100,100,'2026-10-11','receive',12,30,'12.1100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04');
INSERT INTO `crate_movements` (`id`,`crate_id`,`move_date`,`kind`,`txn_id`,`line_id`,`qty`,`whole`,`site_id`,`site2_id`,`customer_id`,`note`,`created_by`,`created_at`) VALUES
(101,101,'2026-10-11','receive',12,31,'17.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(102,102,'2026-10-11','receive',12,31,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(103,103,'2026-10-11','receive',12,31,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(104,104,'2026-10-11','receive',12,31,'13.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(105,105,'2026-10-11','receive',12,31,'16.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(106,106,'2026-10-11','receive',12,32,'11.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(107,107,'2026-10-11','receive',12,32,'10.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(108,108,'2026-10-11','receive',12,32,'12.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(109,109,'2026-10-26','receive',13,33,'12.2400',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(110,110,'2026-10-26','receive',13,33,'12.4800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(111,111,'2026-10-26','receive',13,33,'11.8700',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(112,112,'2026-10-26','receive',13,33,'12.6500',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(113,113,'2026-10-26','receive',13,33,'12.0200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(114,114,'2026-10-26','receive',13,33,'12.1200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(115,115,'2026-10-26','receive',13,33,'12.5600',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(116,116,'2026-10-26','receive',13,33,'11.7100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(117,117,'2026-10-26','receive',13,33,'12.6900',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(118,118,'2026-10-26','receive',13,33,'12.7800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(119,119,'2026-10-26','receive',13,34,'15.4300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(120,120,'2026-10-26','receive',13,34,'15.3500',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(121,121,'2026-10-26','receive',13,34,'14.7000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(122,122,'2026-10-26','receive',13,34,'15.4600',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(123,123,'2026-10-26','receive',13,34,'15.1400',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(124,124,'2026-10-26','receive',13,34,'15.4000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(125,125,'2026-10-26','receive',13,35,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(126,126,'2026-10-26','receive',13,35,'16.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(127,127,'2026-10-26','receive',13,35,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(128,128,'2026-10-26','receive',13,35,'14.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(129,129,'2026-11-04','receive',14,37,'12.3900',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(130,130,'2026-11-04','receive',14,37,'11.7300',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(131,131,'2026-11-04','receive',14,37,'11.9700',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(132,132,'2026-11-04','receive',14,37,'12.0200',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(133,133,'2026-11-04','receive',14,37,'12.3600',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(134,134,'2026-11-04','receive',14,37,'12.2300',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(135,135,'2026-11-04','receive',14,37,'12.0600',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(136,136,'2026-11-04','receive',14,37,'11.6100',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(137,137,'2026-11-04','receive',14,38,'17.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(138,138,'2026-11-04','receive',14,38,'15.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(139,139,'2026-11-04','receive',14,38,'13.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(140,140,'2026-11-04','receive',14,38,'16.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(141,141,'2026-11-04','receive',14,39,'8.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(142,142,'2026-11-04','receive',14,39,'9.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(143,143,'2026-11-04','receive',14,40,'26.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(144,144,'2026-11-04','receive',14,40,'22.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(145,145,'2026-11-04','receive',14,40,'25.0000',0,3,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(146,146,'2026-11-16','receive',15,41,'12.7100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(147,147,'2026-11-16','receive',15,41,'12.6600',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(148,148,'2026-11-16','receive',15,41,'11.8100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(149,149,'2026-11-16','receive',15,41,'11.8700',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(150,150,'2026-11-16','receive',15,41,'12.9800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(151,151,'2026-11-16','receive',15,41,'12.6100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(152,152,'2026-11-16','receive',15,41,'11.9000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(153,153,'2026-11-16','receive',15,41,'12.8900',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(154,154,'2026-11-16','receive',15,41,'12.5300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(155,155,'2026-11-16','receive',15,41,'12.2800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(156,156,'2026-11-16','receive',15,42,'15.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(157,157,'2026-11-16','receive',15,42,'17.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(158,158,'2026-11-16','receive',15,42,'17.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(159,159,'2026-11-16','receive',15,42,'17.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(160,160,'2026-11-16','receive',15,43,'15.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(161,161,'2026-11-16','receive',15,43,'13.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(162,162,'2026-11-16','receive',15,43,'16.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(163,163,'2026-11-16','receive',15,43,'15.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(164,164,'2026-11-23','receive',16,44,'12.8700',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(165,165,'2026-11-23','receive',16,44,'12.9400',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(166,166,'2026-11-23','receive',16,44,'12.4100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(167,167,'2026-11-23','receive',16,44,'12.5200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(168,168,'2026-11-23','receive',16,44,'12.2500',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(169,169,'2026-11-23','receive',16,44,'12.5100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(170,170,'2026-11-23','receive',16,44,'12.9700',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(171,171,'2026-11-23','receive',16,44,'12.5200',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(172,172,'2026-11-23','receive',16,45,'14.5400',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(173,173,'2026-11-23','receive',16,45,'14.3800',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(174,174,'2026-11-23','receive',16,45,'14.8100',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(175,175,'2026-11-23','receive',16,45,'14.5300',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(176,176,'2026-11-23','receive',16,45,'14.7000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(177,177,'2026-11-23','receive',16,46,'12.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(178,178,'2026-11-23','receive',16,46,'12.0000',0,1,NULL,NULL,NULL,10,'2026-11-25 21:50:04'),
(179,1,'2026-09-22','transfer',17,48,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(180,2,'2026-09-22','transfer',17,48,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(181,3,'2026-09-22','transfer',17,48,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(182,28,'2026-09-22','transfer',17,49,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(183,29,'2026-09-22','transfer',17,49,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(184,36,'2026-09-22','transfer',17,50,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(185,19,'2026-09-22','transfer',17,51,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(186,45,'2026-09-22','transfer',17,52,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(187,46,'2026-09-22','transfer',17,52,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(188,51,'2026-09-22','transfer',17,53,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(189,4,'2026-09-23','transfer',18,54,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(190,5,'2026-09-23','transfer',18,54,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(191,13,'2026-09-23','transfer',18,55,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(192,14,'2026-09-23','transfer',18,55,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(193,30,'2026-09-23','transfer',18,56,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(194,31,'2026-09-23','transfer',18,56,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(195,47,'2026-09-23','transfer',18,57,'0.0000',0,1,3,NULL,NULL,1,'2026-11-25 21:50:04'),
(196,6,'2026-10-27','transfer',19,58,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(197,7,'2026-10-27','transfer',19,58,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(198,8,'2026-10-27','transfer',19,58,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(199,65,'2026-10-27','transfer',19,59,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(200,66,'2026-10-27','transfer',19,59,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04');
INSERT INTO `crate_movements` (`id`,`crate_id`,`move_date`,`kind`,`txn_id`,`line_id`,`qty`,`whole`,`site_id`,`site2_id`,`customer_id`,`note`,`created_by`,`created_at`) VALUES
(201,22,'2026-10-27','transfer',19,60,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(202,9,'2026-11-17','transfer',20,61,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(203,10,'2026-11-17','transfer',20,61,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(204,11,'2026-11-17','transfer',20,61,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(205,12,'2026-11-17','transfer',20,61,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(206,15,'2026-11-17','transfer',20,62,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(207,23,'2026-11-17','transfer',20,63,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(208,55,'2026-11-24','transfer',21,64,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(209,56,'2026-11-24','transfer',21,64,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(210,57,'2026-11-24','transfer',21,64,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(211,67,'2026-11-24','transfer',21,65,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(212,68,'2026-11-24','transfer',21,65,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(213,20,'2026-11-24','transfer',21,66,'0.0000',0,1,2,NULL,NULL,1,'2026-11-25 21:50:04'),
(214,22,'2026-10-28','convert',NULL,NULL,'0.0000',0,2,NULL,NULL,'Converted to kg: 14.26 left loose. Repacked into 1 kg retail bags',1,'2026-11-25 21:50:04'),
(215,24,'2026-10-28','convert',NULL,NULL,'0.0000',0,1,NULL,NULL,'Converted to kg: 13.93 left loose. Repacked into 1 kg retail bags',1,'2026-11-25 21:50:04'),
(216,58,'2026-09-30','auto',23,NULL,'12.1200',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:04'),
(217,59,'2026-09-30','auto',23,NULL,'12.3200',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:04'),
(218,60,'2026-09-30','auto',23,NULL,'5.5600',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:04'),
(219,60,'2026-10-30','auto',24,NULL,'7.4100',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:04'),
(220,61,'2026-10-30','auto',24,NULL,'12.5900',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:04'),
(221,37,'2026-10-16','auto',26,NULL,'10.5000',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:04'),
(222,61,'2026-10-01','sale',31,110,'0.3400',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(223,62,'2026-10-01','sale',31,110,'12.8300',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(224,63,'2026-10-01','sale',31,110,'12.2600',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(225,64,'2026-10-01','sale',31,110,'12.5500',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(226,89,'2026-10-01','sale',31,110,'12.9800',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(227,16,'2026-10-01','sale',31,111,'14.6100',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(228,17,'2026-10-01','sale',31,111,'14.8600',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(229,90,'2026-10-08','sale',32,113,'12.9100',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(230,91,'2026-10-08','sale',32,113,'12.5000',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(231,92,'2026-10-08','sale',32,113,'12.2000',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(232,93,'2026-10-08','sale',32,113,'11.9300',1,1,NULL,6,NULL,1,'2026-11-25 21:50:04'),
(233,94,'2026-10-12','sale',33,115,'12.7100',1,1,NULL,7,NULL,1,'2026-11-25 21:50:04'),
(234,95,'2026-10-12','sale',33,115,'12.2000',1,1,NULL,7,NULL,1,'2026-11-25 21:50:04'),
(235,96,'2026-10-12','sale',33,115,'12.1800',1,1,NULL,7,NULL,1,'2026-11-25 21:50:04'),
(236,32,'2026-10-12','sale',33,116,'15.6500',1,1,NULL,7,NULL,1,'2026-11-25 21:50:04'),
(237,33,'2026-10-12','sale',33,116,'15.3400',1,1,NULL,7,NULL,1,'2026-11-25 21:50:04'),
(238,97,'2026-10-06','sale',34,118,'12.3900',1,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(239,98,'2026-10-06','sale',34,118,'5.6100',0,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(240,18,'2026-10-06','sale',34,119,'10.0000',0,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(241,21,'2026-10-06','sale',34,120,'4.0000',0,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(242,34,'2026-10-20','sale',35,122,'12.0000',0,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(243,37,'2026-10-20','sale',35,123,'1.8600',1,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(244,38,'2026-10-20','sale',35,123,'6.1400',0,1,NULL,8,NULL,1,'2026-11-25 21:50:04'),
(245,4,'2026-10-14','sale',36,125,'11.9500',1,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(246,30,'2026-10-14','sale',36,126,'15.3600',1,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(247,13,'2026-10-14','sale',36,127,'8.0000',0,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(248,5,'2026-11-07','sale',37,128,'12.4900',1,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(249,129,'2026-11-07','sale',37,128,'12.3900',1,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(250,130,'2026-11-07','sale',37,128,'11.7300',1,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(251,131,'2026-11-07','sale',37,128,'11.9700',1,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(252,31,'2026-11-07','sale',37,129,'10.0000',0,3,NULL,9,NULL,1,'2026-11-25 21:50:04'),
(253,18,'2026-10-16','sale',38,131,'5.2300',1,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(254,101,'2026-10-16','sale',38,131,'14.7700',0,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(255,25,'2026-10-16','sale',38,132,'14.4700',1,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(256,26,'2026-10-16','sale',38,132,'0.5300',0,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(257,101,'2026-10-23','sale',39,133,'2.2300',1,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(258,102,'2026-10-23','sale',39,133,'12.7700',0,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(259,26,'2026-10-23','sale',39,134,'12.0000',0,1,NULL,10,NULL,1,'2026-11-25 21:50:04'),
(260,98,'2026-10-23','sale',40,135,'7.1200',1,1,NULL,11,NULL,1,'2026-11-25 21:50:05'),
(261,99,'2026-10-23','sale',40,135,'11.9800',1,1,NULL,11,NULL,1,'2026-11-25 21:50:05'),
(262,102,'2026-11-13','sale',41,136,'1.2300',1,1,NULL,10,NULL,1,'2026-11-25 21:50:05'),
(263,103,'2026-11-13','sale',41,136,'13.7700',0,1,NULL,10,NULL,1,'2026-11-25 21:50:05'),
(264,26,'2026-11-13','sale',41,137,'2.4400',1,1,NULL,10,NULL,1,'2026-11-25 21:50:05'),
(265,27,'2026-11-13','sale',41,137,'9.5600',0,1,NULL,10,NULL,1,'2026-11-25 21:50:05'),
(266,100,'2026-11-13','sale',42,138,'12.1100',1,1,NULL,11,NULL,1,'2026-11-25 21:50:05'),
(267,109,'2026-11-13','sale',42,138,'12.2400',1,1,NULL,11,NULL,1,'2026-11-25 21:50:05'),
(268,110,'2026-10-31','sale',43,139,'12.4800',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(269,111,'2026-10-31','sale',43,139,'11.8700',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(270,112,'2026-10-31','sale',43,139,'12.6500',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(271,113,'2026-10-31','sale',43,139,'12.0200',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(272,114,'2026-10-31','sale',43,139,'12.1200',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(273,115,'2026-10-31','sale',43,139,'12.5600',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(274,69,'2026-10-31','sale',43,140,'14.6500',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(275,70,'2026-10-31','sale',43,140,'14.4100',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(276,119,'2026-10-31','sale',43,140,'15.4300',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(277,52,'2026-10-31','sale',43,141,'24.0000',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(278,116,'2026-11-19','sale',44,144,'11.7100',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(279,117,'2026-11-19','sale',44,144,'12.6900',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(280,118,'2026-11-19','sale',44,144,'12.7800',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(281,146,'2026-11-19','sale',44,144,'12.7100',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(282,147,'2026-11-19','sale',44,144,'12.6600',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(283,103,'2026-11-19','sale',44,145,'0.2300',1,1,NULL,6,NULL,1,'2026-11-25 21:50:05'),
(284,148,'2026-11-21','sale',45,147,'11.8100',1,1,NULL,8,NULL,1,'2026-11-25 21:50:05'),
(285,149,'2026-11-21','sale',45,147,'11.8700',1,1,NULL,8,NULL,1,'2026-11-25 21:50:05'),
(286,150,'2026-11-21','sale',45,147,'1.3200',0,1,NULL,8,NULL,1,'2026-11-25 21:50:05'),
(287,42,'2026-11-21','sale',45,148,'3.0000',0,1,NULL,8,NULL,1,'2026-11-25 21:50:05'),
(288,132,'2026-11-23','sale',46,149,'12.0200',1,3,NULL,9,NULL,1,'2026-11-25 21:50:05'),
(289,21,'2026-10-17','sale',47,151,'2.5000',0,1,NULL,13,NULL,1,'2026-11-25 21:50:05'),
(290,150,'2026-10-17','sale',47,152,'6.2000',0,1,NULL,13,NULL,1,'2026-11-25 21:50:05'),
(291,150,'2026-10-22','sale',52,154,'5.4600',1,1,NULL,12,NULL,1,'2026-11-25 21:50:05'),
(292,151,'2026-10-22','sale',52,154,'12.6100',1,1,NULL,12,NULL,1,'2026-11-25 21:50:05'),
(293,27,'2026-10-22','sale',52,155,'4.5300',1,1,NULL,12,NULL,1,'2026-11-25 21:50:05'),
(294,71,'2026-10-22','sale',52,155,'5.4700',0,1,NULL,12,NULL,1,'2026-11-25 21:50:05'),
(295,152,'2026-09-29','auto',66,NULL,'11.9000',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(296,153,'2026-09-29','auto',66,NULL,'0.1000',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(297,45,'2026-11-17','auto',74,NULL,'2.0000',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(300,1,'2026-11-24','sale',82,197,'3.4000',0,2,NULL,NULL,NULL,9,'2026-11-25 21:50:05'),
(301,45,'2026-11-24','sale',82,198,'2.0000',0,2,NULL,NULL,NULL,9,'2026-11-25 21:50:05'),
(303,1,'2026-11-24','sale',83,200,'9.0200',1,2,NULL,11,NULL,9,'2026-11-25 21:50:05');
INSERT INTO `crate_movements` (`id`,`crate_id`,`move_date`,`kind`,`txn_id`,`line_id`,`qty`,`whole`,`site_id`,`site2_id`,`customer_id`,`note`,`created_by`,`created_at`) VALUES
(306,19,'2026-11-24','sale',84,203,'1.2000',0,2,NULL,NULL,NULL,9,'2026-11-25 21:50:05'),
(307,51,'2026-11-24','sale',84,204,'1.0000',0,2,NULL,NULL,NULL,9,'2026-11-25 21:50:05'),
(311,2,'2026-11-25','sale',89,216,'2.8000',0,2,NULL,NULL,NULL,9,'2026-11-25 21:50:05'),
(312,45,'2026-11-25','auto',90,NULL,'3.0000',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',9,'2026-11-25 21:50:05'),
(313,51,'2026-11-25','auto',90,NULL,'2.0000',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',9,'2026-11-25 21:50:05'),
(314,120,'2026-11-11','auto',91,NULL,'15.3500',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(315,121,'2026-11-11','auto',91,NULL,'14.7000',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(316,122,'2026-11-11','auto',91,NULL,'15.4600',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(317,123,'2026-11-11','auto',91,NULL,'15.1400',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(318,124,'2026-11-11','auto',91,NULL,'15.4000',0,1,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(319,2,'2026-11-11','auto',92,NULL,'9.2000',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(320,3,'2026-11-11','auto',92,NULL,'12.4700',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(321,6,'2026-11-11','auto',92,NULL,'12.3100',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(322,7,'2026-11-11','auto',92,NULL,'12.8900',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(323,8,'2026-11-11','auto',92,NULL,'12.7900',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(324,9,'2026-11-11','auto',92,NULL,'12.1100',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(325,10,'2026-11-11','auto',92,NULL,'12.5000',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(326,11,'2026-11-11','auto',92,NULL,'12.5700',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(327,12,'2026-11-11','auto',92,NULL,'12.2400',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(328,55,'2026-11-11','auto',92,NULL,'12.6000',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(329,56,'2026-11-11','auto',92,NULL,'12.5500',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(330,57,'2026-11-11','auto',92,NULL,'12.7300',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(331,65,'2026-11-11','auto',92,NULL,'14.2100',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(332,66,'2026-11-11','auto',92,NULL,'14.8600',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(333,67,'2026-11-11','auto',92,NULL,'14.5200',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(334,68,'2026-11-11','auto',92,NULL,'14.5900',0,2,NULL,NULL,'Taken out without naming a crate (oldest crate first)',1,'2026-11-25 21:50:05'),
(335,153,'2026-11-21','transfer',93,227,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(336,154,'2026-11-21','transfer',93,227,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(337,155,'2026-11-21','transfer',93,227,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(338,34,'2026-11-21','transfer',93,228,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(339,48,'2026-11-21','transfer',93,229,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(340,153,'2026-11-21','sale',95,231,'12.7900',1,6,NULL,11,NULL,1,'2026-11-25 21:50:05'),
(341,34,'2026-11-21','sale',95,232,'3.4200',1,6,NULL,11,NULL,1,'2026-11-25 21:50:05'),
(342,154,'2026-11-21','sale',96,233,'3.2000',0,6,NULL,14,NULL,1,'2026-11-25 21:50:05'),
(343,48,'2026-11-21','sale',96,235,'6.0000',0,6,NULL,14,NULL,1,'2026-11-25 21:50:05'),
(344,154,'2026-11-21','shrink',97,236,'0.1800',0,6,NULL,NULL,'Shrinkage on TC-00001',5,'2026-11-25 21:50:05'),
(345,48,'2026-11-21','shortage',98,237,'2.0000',0,6,NULL,3,'Shortage on TC-00001',5,'2026-11-25 21:50:05'),
(346,48,'2026-11-21','transfer',99,239,'0.0000',0,6,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(347,154,'2026-11-21','transfer',99,241,'0.0000',0,6,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(348,155,'2026-11-21','transfer',99,242,'0.0000',0,6,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(349,154,'2026-11-22','transfer',101,243,'0.0000',0,1,7,NULL,NULL,1,'2026-11-25 21:50:05'),
(350,155,'2026-11-22','transfer',101,243,'0.0000',0,1,7,NULL,NULL,1,'2026-11-25 21:50:05'),
(351,104,'2026-11-22','transfer',101,244,'0.0000',0,1,7,NULL,NULL,1,'2026-11-25 21:50:05'),
(352,104,'2026-11-22','sale',102,245,'5.0000',0,7,NULL,14,NULL,1,'2026-11-25 21:50:05'),
(353,154,'2026-11-22','sale',102,246,'2.4000',0,7,NULL,14,NULL,1,'2026-11-25 21:50:05'),
(354,104,'2026-11-22','shrink',103,247,'0.1200',0,7,NULL,NULL,'Shrinkage on TC-00002',5,'2026-11-25 21:50:05'),
(355,155,'2026-11-22','shortage',104,248,'12.2800',1,7,NULL,4,'Shortage on TC-00002',5,'2026-11-25 21:50:05'),
(356,104,'2026-11-22','transfer',105,249,'0.0000',0,7,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(357,154,'2026-11-22','transfer',105,250,'0.0000',0,7,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(358,154,'2026-11-24','transfer',106,251,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(359,164,'2026-11-24','transfer',106,251,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(360,172,'2026-11-24','transfer',106,252,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(361,154,'2026-11-24','sale',107,253,'4.8000',0,6,NULL,14,NULL,1,'2026-11-25 21:50:05'),
(362,172,'2026-11-24','shrink',108,254,'0.1000',0,6,NULL,NULL,'Shrinkage on TC-00003',5,'2026-11-25 21:50:05'),
(363,172,'2026-11-24','transfer',109,255,'0.0000',0,6,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(364,154,'2026-11-24','transfer',109,256,'0.0000',0,6,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(365,164,'2026-11-24','transfer',109,257,'0.0000',0,6,1,NULL,NULL,5,'2026-11-25 21:50:05'),
(366,154,'2026-11-25','transfer',110,258,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(367,164,'2026-11-25','transfer',110,258,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05'),
(368,35,'2026-11-25','transfer',110,259,'0.0000',0,1,6,NULL,NULL,1,'2026-11-25 21:50:05');

-- transfer_closings (3 rows)
INSERT INTO `transfer_closings` (`id`,`closing_no`,`closing_date`,`from_site_id`,`to_site_id`,`sales_rep_id`,`customer_id`,`shrink_account_id`,`shortage_account_id`,`transferred_by`,`checked_by`,`received_by`,`memo`,`transfer_txn_id`,`shrink_txn_id`,`shortage_txn_id`,`balance_qty`,`transfer_qty`,`shrink_qty`,`shortage_qty`,`shrink_amount`,`shortage_amount`,`status`,`void_reason`,`voided_by`,`voided_at`,`created_by`,`created_at`) VALUES
(1,'TC-00001','2026-11-21',6,1,3,3,57,12,'Rico Mendoza','Fred Tan','Dan Villanueva','Evening closing, Naga route',99,97,98,'59.6100','56.9300','0.1800','2.5000','25.52','108.50','posted',NULL,NULL,NULL,5,'2026-11-25 21:50:05'),
(2,'TC-00002','2026-11-22',7,1,4,4,57,12,'Arnel Cruz','Fred Tan','Dan Villanueva','Evening closing, Pili route',105,103,104,'27.0300','14.6300','0.1200','12.2800','22.18','1740.77','posted',NULL,NULL,NULL,5,'2026-11-25 21:50:05'),
(3,'TC-00003','2026-11-24',6,1,3,3,57,12,'Rico Mendoza','Fred Tan','Dan Villanueva','Evening closing, Naga route',109,108,NULL,'29.3600','29.2600','0.1000','0.0000','15.00','0.00','posted',NULL,NULL,NULL,5,'2026-11-25 21:50:05');

-- transfer_closing_lines (10 rows)
INSERT INTO `transfer_closing_lines` (`id`,`closing_id`,`line_no`,`item_id`,`crate_id`,`crate_no`,`unit`,`balance`,`transfer_qty`,`shrink_qty`,`shortage_qty`,`unit_cost`,`note`) VALUES
(1,1,1,10,48,'48','pack','34.0000','32.0000','0.0000','2.0000','48.0000','Two packs not accounted for'),
(2,1,2,9,NULL,NULL,'kg','4.0000','3.5000','0.0000','0.5000','25.0000',NULL),
(3,1,3,1,154,'154','kg','9.3300','9.1500','0.1800','0.0000','141.7566','Drip loss'),
(4,1,4,1,155,'155','kg','12.2800','12.2800','0.0000','0.0000','141.7566',NULL),
(5,2,1,4,104,'104','kg','8.0000','7.8800','0.1200','0.0000','184.8142',NULL),
(6,2,2,1,154,'154','kg','6.7500','6.7500','0.0000','0.0000','141.7566',NULL),
(7,2,3,1,155,'155','kg','12.2800','0.0000','0.0000','12.2800','141.7566','Crate not returned'),
(8,3,1,2,172,'172','kg','14.5400','14.4400','0.1000','0.0000','150.0000',NULL),
(9,3,2,1,154,'154','kg','1.9500','1.9500','0.0000','0.0000','141.7566',NULL),
(10,3,3,1,164,'164','kg','12.8700','12.8700','0.0000','0.0000','141.7566',NULL);

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
(1,'superadmin','$2y$10$8hzcqfeGPf9Em2nJJjInJ.OrKczfZR8nQ6mwJ/eZ6e3533/To5xOq','Platform Super Admin','superadmin@northpoint.test','active',0,'2026-11-25 21:50:06',0,NULL,NULL,NULL,'2026-11-25 21:50:06');

-- companies (1 rows)
INSERT INTO `companies` (`id`,`name`,`address`,`contact_person`,`phone`,`email`,`tin`,`status`,`owner_user_id`,`require_approval`,`join_role_id`,`template_company_id`,`notes`,`last_error`,`created_by`,`created_at`,`activated_at`,`deactivated_at`,`updated_at`) VALUES
(1,'Northpoint Cold Chain Distributors Inc.','Km 2 Diversion Road, Naga City, Camarines Sur','System Administrator','(054) 881-2047','accounting@northpoint.test','000-482-915-000','active',1,1,NULL,NULL,'The original database, registered as Company 1',NULL,NULL,'2026-11-25 21:50:06','2026-11-25 21:50:06',NULL,NULL);

-- company_databases (1 rows)
INSERT INTO `company_databases` (`company_id`,`db_name`,`is_primary`,`created_by_platform`,`table_count`,`triggers_ok`,`created_at`,`verified_at`) VALUES
(1,'gsmart_distribution',1,0,109,1,'2026-11-25 21:50:06','2026-11-25 21:50:06');

-- company_codes (1 rows)
INSERT INTO `company_codes` (`id`,`company_id`,`code`,`status`,`expires_at`,`created_by`,`created_at`,`retired_at`) VALUES
(1,1,'NCC5X3WF','active',NULL,'setup:admin','2026-11-25 21:50:06',NULL);

-- user_company_memberships (11 rows)
INSERT INTO `user_company_memberships` (`id`,`company_id`,`company_user_id`,`username`,`full_name`,`email`,`status`,`created_via`,`joined_at`,`updated_at`) VALUES
(1,1,1,'admin','System Administrator','admin@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(2,1,2,'accountant','Ana Cruz','accountant@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(3,1,3,'arclerk','Ben Garcia','arclerk@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(4,1,4,'apclerk','Carla Lim','apclerk@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(5,1,5,'invclerk','Dan Villanueva','invclerk@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(6,1,6,'allocator','Lito Bautista','allocator@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(7,1,7,'salesrep','Maria Santos','salesrep@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(8,1,8,'supervisor','Fred Tan','supervisor@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(9,1,9,'cashier1','Ella Ramos','cashier1@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(10,1,10,'glenn','Glenn Abad','glenn@northpoint.test','active','admin','2026-11-25 21:50:03','2026-11-25 21:50:06'),
(11,1,11,'auditor','Grace Uy','auditor@northpoint.test','active','admin','2026-11-25 21:50:04','2026-11-25 21:50:06');

-- platform_audit (1 rows)
INSERT INTO `platform_audit` (`id`,`created_at`,`actor_type`,`actor_id`,`actor_name`,`company_id`,`action`,`details`,`ip_address`) VALUES
(1,'2026-11-25 21:50:06','user',1,'admin',1,'platform_setup','The existing database was registered as Company 1 (Northpoint Cold Chain Distributors Inc.); owner admin; Super Admin superadmin created','cli');

-- platform_settings (1 rows)
INSERT INTO `platform_settings` (`setting_key`,`setting_value`) VALUES
('default_require_approval','1');

USE `gsmart_distribution`;
SET FOREIGN_KEY_CHECKS = 1;
