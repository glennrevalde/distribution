# G-SMaRT Distribution System

A web system for distributors of chilled and frozen goods, built on G-SMaRT Accounting. It adds supplier allocations, pick-ups at the supplier, stock received and sold in **crates whose weight varies**, and crate-by-crate tracking of production and expiry dates, on top of the full accounting system: Financial, Fixed Assets, Customers (A/R), Vendors (A/P), Inventory, Point of Sale, Banking, BIR Reports, the Community and System Administration.

It runs several companies from one installation, each with its own database, managed by a Super Admin.

Plain HTML, CSS, JavaScript, PHP and MySQL. No framework, no build step, no CDN: Bootstrap, Bootstrap Icons and the fonts are inside `assets/`, so it runs offline on XAMPP, WAMP, Laragon or any PHP host.

---

## 1. Requirements

| | |
|---|---|
| PHP | 8.1 or newer (8.2+ recommended), with `pdo_mysql` and `mbstring` (on by default in XAMPP) |
| Database | MySQL 5.5.3 or newer (5.5, 5.6, 5.7, 8.x) or MariaDB 5.5 or newer |
| Web server | Apache (the `.htaccess` files are included) or nginx (section 10) |
| Browser | Any current browser, desktop or phone |

**PHP and MySQL versions are separate.** The database can be as old as MySQL 5.5, but the PHP code needs PHP 8.1 or newer. If your MySQL 5.5 came with an old XAMPP (PHP 5), install a current XAMPP or point a PHP 8 install at your MySQL 5.5 server in `config/config.php`.

## 2. Install with XAMPP and phpMyAdmin

1. Unzip so you have `C:\xampp\htdocs\gsmart-distribution\index.php`.
2. Start **Apache** and **MySQL** in the XAMPP Control Panel.
3. Open <http://localhost/phpmyadmin>, choose **Import**, pick **one** of these files and press **Go**:
   - `database/gsmart_distribution_clean.sql`: the clean database. Chart of accounts, tax codes, terms, U/M sets (kilos and crates, packs and crates), roles with their page access, the user accounts, sites, POS terminals and number series. **No customers, suppliers, items or transactions.** Use this one to start real work.
   - `database/gsmart_distribution_sample.sql`: the same set-up plus the demo company, **Northpoint Cold Chain Distributors Inc.**, with about two and a half months of sample data in every module: suppliers and their items, allocations and pick-ups (received, being picked up today, waiting for tomorrow), crates received, sold whole and by the kilo, moved, converted and condemned, invoices, sales receipts, POS shifts, bills, payments, banking, fixed assets and more.

   Each file creates **two databases**: `gsmart_distribution` (Company 1) and `gsmart_distribution_master` (the platform: the Super Admin and the list of companies). Importing drops and recreates their tables.
4. If your MySQL `root` user has a password, put it in `config/config.php` (`'pass'`), or set the `DB_PASS` environment variable.
5. Open <http://localhost/gsmart-distribution/> and log in (section 4).

Keep these two database names when importing: the platform database records Company 1 under `gsmart_distribution`. To use other names, set the company database name in `config/config.php` (the platform database is the same name followed by `_master`) and install from the command line (section 3), which builds both databases under the new names.

The sample data is dated relative to the day the file was made (November 2026). To rebuild it dated around today, use the command line below.

## 3. Install from the command line (alternative)

```bash
php tools/install.php --drop            # empty company database with the set-up (DELETES ALL DATA)
php tools/install.php --drop --demo     # the same, plus the sample transactions dated around today
php tools/build_platform.php superadmin 'SuperAdmin@2026'   # the platform database, Company 1 and the Super Admin
php tools/build_release.php             # rebuilds both .sql files in database/ from scratch
```

`build_platform.php` is for a server with no platform database yet; `build_release.php` drops and rebuilds both databases itself.

Settings come from `config/config.php`; `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` and `DB_PASS` override them.

## 4. User accounts, lowest to highest

The same accounts are in both .sql files.

| # | Username | Password | Role | What they can do |
|---|---|---|---|---|
| 1 | `glenn` | `Demo@12345` | Pick-Up Crew | Only the pick-ups assigned to him: weigh and date the crates at the supplier and mark the pick-up complete. Can view the Crate Center. |
| 2 | `cashier1` | `Demo@12345` | Cashier | POS Register at Naga Outlet Counter 1 only: sales (crates included), returns, cash drops, own shift |
| 3 | `supervisor` | `Demo@12345` | POS Supervisor | Cashier rights plus approving voids, refunds, discounts and price overrides, approval codes, X/Z readings |
| 4 | `salesrep` | `Demo@12345` | Sales Representative | Estimates, sales orders and invoices (by the crate or by the kilo), sales reports, viewing the Crate Center and crate reports |
| 5 | `allocator` | `Demo@12345` | Allocation Officer | Supplier Items, Supplier Allocation and Pick-Up Supplier Items for every crew member; views the Crate Center and the receipts; allocation and crate reports |
| 6 | `invclerk` | `Demo@12345` | Inventory Clerk | Items, U/M sets, sites, receiving, pick-ups, adjustments, transfers, builds, processing, counts, Crate Center, Convert Crates to Kilos, Move Crates, inventory and crate reports |
| 7 | `arclerk` | `Demo@12345` | A/R Clerk | Every customer transaction (invoices and sales receipts in crates included), payments, statements, receivables reports |
| 8 | `apclerk` | `Demo@12345` | A/P Clerk | Allocations, pick-ups and supplier items, purchase orders, receiving, bills, Pay Bills with withholding, advances, debit memos, payables and withholding reports |
| 9 | `accountant` | `Demo@12345` | Accountant | Financial, Fixed Assets, Banking, BIR Reports and inventory adjustments; views the customer, vendor and inventory pages; every report |
| 10 | `auditor` | `Demo@12345` | Auditor | View-only access to every page, report and the audit trail; cannot change anything |
| 11 | `admin` | `Admin@12345` | Administrator and **Company Owner** | Everything in the company: users, roles, page access, settings, the Company Code and join requests. Must choose a new password at the first log-in. |
| 12 | `superadmin` | `SuperAdmin@2026` | **Super Admin** (platform) | Belongs to no company. Manages the platform: adds companies, assigns owners, opens any company, runs database updates. |

Everyone logs in on the same page (`login.php`); the page finds the user's company by the username, and the Super Admin lands on the platform pages.

**Change the passwords of `admin` and `superadmin`, and deactivate the demo accounts you don't need, before real use** (System Administration → User Accounts).

## 5. Several companies

The system serves any number of companies. Each has its **own database**, so no company can see, change or report on another's records.

- **Adding a company:** log in as `superadmin`, open **Companies → New company**, enter the company's details, choose the company whose set-up is copied (Company 1 by default), choose whether employees need approval, and the owner's account. **Create company** makes the database `gsmart_distribution_company_002` (then `_003` …), creates every table, copies the set-up lists only (settings, roles and page access, chart of accounts, terms, tax codes, U/M sets including the crate units, categories and so on), creates the owner (who changes the temporary password at the first log-in), checks the new database and switches the company on. No customers, suppliers, items, transactions or users are copied.
- **Company Owner:** each company has one. The owner manages the company's users, approves employees who join with the **Company Code** (log-in page → *Join your company*), and can regenerate the code. `admin` is the owner of Company 1.
- **Super Admin pages:** Companies (with Open, to work inside any company), New company, Database updates, Super Admins, Platform settings, Platform audit log.
- **One user, two companies:** an administrator can give a user of another company access with **User Accounts → Add user from another company**; the company name in the top bar then switches between them.
- **MySQL rights:** the MySQL user in `config/config.php` creates the company databases, so it needs CREATE and DROP on databases and full rights inside them, including TRIGGER (XAMPP's `root` has all of them). On MySQL 5.5 with binary logging on, creating triggers also needs SUPER or `log_bin_trust_function_creators = 1`.
- **Command line:** `php tools/platform.php list | reset-superadmin <username> <password> | sync <company id> | update-all`.

## 6. The distribution features

### Supplier allocation and pick-up (Vendors → Distribution)

- **Supplier Items:** per supplier, the items it sells you, the unit it allocates them in (crates, kilos or packs), its own item code and the last cost. Fills the allocation form and prices the pick-up receipt.
- **Supplier Allocation:** Supplier, Date and Location, then **Go** lists the supplier's items. Type the quantity of each, untick **Use** to leave a line out, copy or delete lines, assign it to a pick-up crew member (or type a name). Buttons: New allocation, Reset, Save, Save & New, Close, Cancel allocation. Status: Allocated, Being picked up, Received, Cancelled.
- **Pick-Up Supplier Items:** built for the crew's phone. One day at a time (with arrows), **Only the pick-ups assigned to me**, one card per supplier with its progress. **Weigh crates** opens the crate window: one row per crate with Seq, Crate no., Heads, Weight, Production date and Expiry date, **Replicate** copies the first crate's heads and dates down, Enter jumps to the next weight, and a scale readout shows the total. Items by the kilo or pack get a quantity box. **Reset** clears a card. **Pick-up complete** receives everything into the location on an **Item Receipt** at the supplier's last cost; the bill is entered later with Enter Bill for Received Items. Voiding that receipt reopens the pick-up (refused while any of its crates has been sold or moved).
- **Report:** Supplier Allocation vs Pick-Up.

### Crates

- **The crate unit:** in a U/M set (Inventory → Unit of Measure) tick **Varies (crate)** on a unit such as `CRT`. Its kilos per crate vary, so no factor is used. The base unit is kilos (poultry, meat) or packs (packed goods). Stock, cost and price stay per kilo (or pack); every crate is followed with its own number, weight, heads, production and expiry dates.
- **Receiving:** pick-ups, Receive Items, Receive Items and Enter Bills, Enter Bills and Write Checks. Choose the crate unit on a line and the crate window opens. Crate numbers are given in sequence and can never be duplicated among open crates.
- **Selling:** Create Invoices, Enter Sales Receipts and the POS Register. Choose the crate unit to sell **whole crates** (type Crates needed and press **Oldest first**, or tick them), or sell in kilos and press the crate button to take **kilos out of a crate**. A crate of 12.87 kg from which 6 kg is sold keeps 6.87 kg; when the rest is sold it leaves the crates on hand. Documents show and print the crates under each line, with their expiry dates.
- **Stock in crates is sold by the crate:** a line that names no crate may only take the loose stock (not in any open crate). Otherwise the sale is refused with the loose quantity, until the crate is chosen or crates are converted.
- **Convert Crates to Kilos** (Inventory → Crates): stops following the ticked crates; what is left in them is sold as loose kilos. Nothing is posted.
- **Move Crates to Another Site:** an inventory transfer that carries the crates, with their numbers and dates, to the other site.
- **Crate Center:** the crates by item and site (count, kilos, average per crate, earliest expiry) and every crate with how full it is, filtered by site, item, status, expiry window and crate number; each crate has a sheet with its full history.
- **Agreement with the books:** a site's open crates never hold more than its stock on hand. Adjustments, counts, builds and processing orders that take stock without naming crates take it from the oldest-expiring crates automatically. Edits, voids and deletes put the kilos back into their crates.
- **Reports** (Inventory → Reports → Crate Reports): Crates Remaining by Item (with the loose kilos if wanted), Kilos per Crate by Item, Crates Sold with Production and Expiry Dates, Crate Movement History, Crates Received by Supplier.
- **Home:** open crates in storage with the number expiring within three days, and Today's pick-ups.

The User's Manual (Help button on every page) has a chapter on all of this: **8. Distribution and Crates**.

## 7. The accounting base

Everything in G-SMaRT Accounting is included and unchanged in its logic:

- **Financial:** chart of accounts, journal entries, classes, memorized transactions, budgets, trial balance, balance sheet, income statement, comparative statements, cash flows, general ledger, subsidiary ledgers.
- **Fixed Assets** with depreciation, maintenance and preventive maintenance.
- **Customers:** estimates, sales orders, invoices, sales receipts, statements, payments with withholding, credit memos, forecasts, A/R reports.
- **Vendors:** purchase orders, receiving, bills, pay bills with withholding, advances, debit memos, receipt management, A/P reports.
- **Inventory:** items, U/M sets, sites, transfers, adjustments, builds, processing orders, physical counts, price levels, production and expiry dates, weighted-average costing, inventory reports.
- **Point of Sale:** POS Register and FB POS, shifts, split tenders, suspend and recall, returns and voids with supervisor approval or approval codes, X/Z readings, cash count sheet, Bluetooth receipt printing.
- **Banking:** checks, cash vouchers, deposits, transfers, reconciliation. **BIR Reports:** withholding tax table, Form 2307 and the VAT and withholding registers.
- **Community:** chat channels, private messages, questions and inquiries.
- **System Administration:** users, roles, page access per role and per user, special permissions, company settings, closing date, CSV imports, backup and restore, and an audit trail that cannot be edited or deleted (MySQL triggers block it).
- **Reports:** filters, drill-down, CSV, print, PDF, memorize, scheduled e-mail, and Modify Report layouts.

## 8. The interface

The look is built around a cold-chain warehouse: a freezer-navy menu rail, frost-white work surfaces, cold blue actions and crate yellow as the one accent, with a weighing-scale readout wherever kilos add up. The type is Barlow (Barlow Semi Condensed for titles) with Share Tech Mono only for scale figures and crate numbers. Buttons press in; the log-in page stacks crates onto a scale. Motion is limited to page arrival, the navigation progress bar, window openings and the scale count, and it switches off when the device asks for reduced motion. Every page works on a phone: the menu becomes a panel, wide tables scroll inside their own box, and the pick-up page turns each item into a block.

Styles: `assets/css/app.css` (layout and components) and `assets/css/theme.css` (the theme). Scripts: `assets/js/app.js`, `assets/js/theme.js`, `assets/js/crates.js` (the crate window).

## 9. Configuration and maintenance

- **`config/config.php`:** database connection, time zone (`Asia/Manila`), currency, app name. The platform database is the company database name followed by `_master` unless `'master' => ['name' => '...']` is added. Set `APP_DEBUG=1` only while troubleshooting.
- **System Administration → Company, Security & Closing Date:** company details and logo, password rules, lockout, session timeout, negative-stock rule, production and expiry dates, closing date.
- **Scheduled report e-mails:** run daily: `php tools/send_scheduled_reports.php` (cron) or `C:\xampp\php\php.exe C:\xampp\htdocs\gsmart-distribution\tools\send_scheduled_reports.php` (Task Scheduler).
- **Backups:** System Administration → Backup & Restore, or `php tools/export_sql.php --out=backup.sql` (add `--with-master` to include the platform database). Back up the platform database together with every company database.
- **`storage/`** must be writable by the web server: receipts, logos, maintenance pictures, backups, signature keys, and `storage/platform/multi_company.json`, which switches multi-company on. Every company after the first keeps its files under `storage/companies/c002/` and so on.

## 10. nginx

```nginx
root /var/www/gsmart-distribution;
index index.php;
location ~ ^/(app|config|database|modules|storage|tools|views)/ { deny all; }
location ~ /\.  { deny all; }
location ~ \.(sql|md)$ { deny all; }
location ~ \.php$ { include fastcgi_params; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; fastcgi_pass unix:/run/php/php8.2-fpm.sock; }
```

## 11. MySQL 5.5 notes

Both .sql files and `database/schema.sql` follow the MySQL 5.5 rules: at most one `TIMESTAMP ... DEFAULT CURRENT_TIMESTAMP` per table, no JSON columns, no generated columns or fractional seconds, and every indexed text column within 767 bytes in utf8mb4. Automatic "created" dates are `TIMESTAMP` (up to 2038-01-19); business dates are `DATE`. Tested by importing both files on MariaDB and checking every page.

`database/migrations/` holds the upgrade scripts of the accounting base, for an existing G-SMaRT Accounting database. A new Distribution System installation is made from the .sql files (or `tools/install.php`) and needs none of them.

## 12. Folder structure

```
index.php, login.php      entry points (index.php?p=<page key>)
register.php              joining a company with the Company Code
platform.php              the Super Admin pages
manual.php                the User's Manual (views/manual/, assets/manual/)
sign.php                  signing a voucher from a link
app/                      core classes: DB, Auth, Access, Txn, Posting, Stock, Crates, Allocations, Report, Tenant ...
app/registry.php          every page (menus and Page Access Configuration)
app/reports/              report definitions (distribution.php holds the crate and allocation reports)
modules/                  pages, one folder per module (vendors/allocations.php, vendors/pickup.php, inventory/crates.php ...)
views/                    page layouts
assets/                   CSS, JavaScript, fonts, Bootstrap and icons (all local)
config/config.php         database and app settings
database/                 schema.sql, master_schema.sql, triggers.sql and the two importable .sql files
tools/                    installer, sample data, SQL export, release build, platform tools
storage/                  uploads, backups, keys and the multi-company switch (not web-accessible)
```

## 13. Before going live

- Import `gsmart_distribution_clean.sql`.
- Log in as `superadmin` and `admin` and change both passwords; deactivate the demo users you don't need.
- Set the company details (System Administration → Company, Security & Closing Date), the sites, the POS terminals and the module default accounts.
- Add your suppliers, their **Supplier Items**, and your items with a crate U/M set where stock comes in crates.
- Create a MySQL user for the system instead of `root`, with the rights in section 5, and put it in `config/config.php`.
- Use HTTPS and keep `APP_DEBUG` off.
#   d i s t r i b u t i o n  
 