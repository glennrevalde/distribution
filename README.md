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
   - `database/gsmart_distribution_sample.sql`: the same set-up plus the demo company, **Northpoint Cold Chain Distributors Inc.**, with about two and a half months of sample data in every module: suppliers and their items, allocations and pick-ups (received, being picked up today, waiting for tomorrow), crates received, sold whole and by the kilo, moved, converted and condemned, crates sent to the van stores and their closings with shrinkage and shortages, shortage charges and their collection, invoices, sales receipts, POS shifts, bills, payments, banking, fixed assets and more.

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
| 6 | `invclerk` | `Demo@12345` | Inventory Clerk | Items, U/M sets, sites, receiving, pick-ups, adjustments, transfers (by the crate too), Inventory Transfer Closing, Shortage Charges, builds, processing, counts, Crate Center, Convert Crates to Kilos, Move Crates, inventory, crate, shortage and shrinkage reports |
| 7 | `arclerk` | `Demo@12345` | A/R Clerk | Every customer transaction (invoices and sales receipts in crates included), payments (collecting shortages too), Shortage Charges, statements, receivables and shortage reports |
| 8 | `apclerk` | `Demo@12345` | A/P Clerk | Allocations, pick-ups and supplier items, purchase orders, receiving, bills, Pay Bills with withholding, advances, debit memos, payables and withholding reports |
| 9 | `accountant` | `Demo@12345` | Accountant | Financial, Fixed Assets, Banking, BIR Reports, inventory adjustments and Inventory Transfer Closing; views the customer, vendor and inventory pages; every report |
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
- **Pick-Up Supplier Items:** built for the crew's phone. One day at a time (with arrows), **Only the pick-ups assigned to me**, one card per supplier with its progress. **Weigh crates** opens the crate window: one row per crate with Seq, Crate no., Heads, Weight, Production date and Expiry date. Heads and dates typed on the first crate are copied to the crates below at once, and every crate whose weight is typed passes its heads and dates to the next one; the weight is never copied and every copied value can be changed. **Replicate** copies the first crate's heads and dates down again, Enter jumps to the next weight, and a scale readout shows the total. Items by the kilo or pack get a quantity box. **Reset** clears a card. **Pick-up complete** receives everything into the location on an **Item Receipt** at the supplier's last cost; the bill is entered later with Enter Bill for Received Items. Voiding that receipt reopens the pick-up (refused while any of its crates has been sold or moved).
- **Report:** Supplier Allocation vs Pick-Up.

### Crates

- **The crate unit:** in a U/M set (Inventory → Unit of Measure) tick **Varies (crate)** on a unit such as `CRT`. Its kilos per crate vary, so no factor is used. The base unit is kilos (poultry, meat) or packs (packed goods). Stock, cost and price stay per kilo (or pack); every crate is followed with its own number, weight, heads, production and expiry dates.
- **Receiving:** pick-ups, Receive Items, Receive Items and Enter Bills, Enter Bills and Write Checks. Choose the crate unit on a line and the crate window opens. Crate numbers are given in sequence and can never be duplicated among open crates.
- **Selling:** Create Invoices, Enter Sales Receipts and the POS Register. Choose the crate unit to sell **whole crates** (type Crates needed and press **Oldest first**, or tick them), or sell in kilos and press the crate button to take **kilos out of a crate**. A crate of 12.87 kg from which 6 kg is sold keeps 6.87 kg; when the rest is sold it leaves the crates on hand. Documents show and print the crates under each line, with their expiry dates.
- **Stock in crates is sold by the crate:** a line that names no crate may only take the loose stock (not in any open crate). Otherwise the sale is refused with the loose quantity, until the crate is chosen or crates are converted.
- **Convert Crates to Kilos** (Inventory → Crates): stops following the ticked crates; what is left in them is sold as loose kilos. Nothing is posted.
- **Convert Kilos to Crates** (Inventory → Crates): the other way round. The site's items kept in crates are listed with what is loose; **Kilos to Crates** (or **Packs to Crates**) opens the crate window: choose the production / expiry group, type each crate's figure as the scale reads it (`1330` = 13.30 kg), and the loose stock becomes new open crates numbered on from the last one, with the group's dates. Nothing is posted.
- **Move Crates to Another Site:** an inventory transfer that carries the crates, with their numbers and dates, to the other site.
- **Transfer Inventory by the crate:** a line of an item with open crates has a **Crates** button; the crates ticked go to the outlet or van store whole, with their numbers, heads, weights and dates. Kilos without a crate can only come from the loose stock of the site.
- **Dispatch Inventory** (Inventory → Transactions, number series `DSP-`): sends stock to a van or outlet like a transfer, with what the dispatch counter needs. Each line has a **Conversion**: *As kept* (crates on hand go whole, picked in the crate window) or *Kilos to Crates* (loose kilos or packs are put into new crates as they leave). The crate window has **Find figure**: type the figure the scale shows (`1294` for 12.94 kg) and the crates of similar weight are filtered; Enter takes the crate. A **Dispatch** column takes each crate's figure as read at the counter and checks it against the crate. When filling crates, the crate number follows on from the last one and can be typed over (the crates below carry on +1), the loose stock is shown by production / expiry group to choose from, and the crates take that group's dates. Saving moves the stock at average cost (nothing posted), fills the crates at the source and moves them; voiding takes it all back. **Print POS Receipt** prints it as *INVENTORY DISPATCH* with **Dispatched by:**.
- **Units and quantity tooltips** (Transfer Inventory and Dispatch Inventory): every quantity shows its unit after it (`197.26 kg`, `274 pack`). For an item with two units or more, holding the pointer over the quantity (or tapping it) shows what it is made of: in crates and loose, the crates chosen, or the quantity in its other units (`= 2.25 box (20 pack each)`).
- **Print POS Receipt** (on a saved transfer or dispatch, and on a closing for its transfer back): a slip for a 58 or 80 mm POS printer or a Bluetooth roll printer, or a PDF to send. One row per crate (**Crate# | Item Code | Qty/Unit**, e.g. `11.65kg`), the crate number in bold and larger, loose quantities in the unit entered, totals with the number of crates, and **Transferred by:** / **Received by:** signature lines.
- **Adjust Quantity/Value on Hand crate by crate:** an item kept in crates has a **Crates** button on its line (and beside New qty in Per Batch). The window lists the open crates at the site and the loose stock; type the new weight (or the difference) of each crate that changed. The line's quantity is the total. A crate can go down to 0 (Used up) or back up to what it came in with; the system never spreads a lump adjustment over the crates by itself, and lowering crated stock without naming crates is limited to the loose stock. Set Qty to Zero, shortages charged to a person, edits and voids work crate by crate.
- **Crate Center:** the crates by item and site (count, kilos, average per crate, earliest expiry) and every crate with how full it is, filtered by site, item, status, expiry window and crate number; each crate has a sheet with its full history.
- **Agreement with the books:** a site's open crates never hold more than its stock on hand. Physical counts, builds and processing orders that take stock without naming crates take it from the oldest-expiring crates automatically (Adjust Quantity/Value on Hand names its crates). Edits, voids and deletes put the kilos back into their crates.
- **Reports** (Inventory → Reports → Crate Reports): Crates Remaining by Item (with the loose kilos if wanted), Kilos per Crate by Item, Crates Sold with Production and Expiry Dates, Crate Movement History, Crates Received by Supplier.
- **Home:** open crates in storage with the number expiring within three days, and Today's pick-ups.

### Van stores, outlets and shortages (Inventory)

- **Inventory Transfer Closing:** the van salesman remits his sales and brings back what is left. Choose the van store or outlet (From), the warehouse or cold storage (To) and the date; every item it still holds is listed with its balance, one line per crate and one for the loose stock. Type what came back in **Transfer Qty/Wgt** (re-weighed crates, kilos, packs or any unit of the item). Each difference is **shrinkage**, a **shortage**, or part of each: a crate that came back lighter goes to shrinkage, anything missing to shortage, and both can be changed. Fields: Shrinkage Adjustment GL Account, Shortage Receivable GL Account, the cashier, sales rep or customer charged, Transferred by, Checked by, Received by. Saving enters the transfer back (crates whole), an adjustment for the shrinkage (to the adjustment account, at average cost) and a **Shortage Charge** for the shortage. Buttons: New closing, Reset, Save, Save & New, Close; a closing is voided as a whole.
- **Shortage Charges:** a shortage is a receivable of the employee **as a customer**, at cost, on account 1120 Shortage Receivable - Employees. It is not a sale (no sales, VAT or cost of goods sold). The page lists every charge with what each person still owes; **Receive Payments** collects them and shows the sales representative's name.
- **Sales representatives:** the Sales Rep list has a Kind (Sales representative, Van salesman, Cashier). Each person is also a customer of type Employee, made by the system. The sales rep box of the customer form, the closing and the adjustment has **Add new sales representative**, so the form is never left. A site can name the van salesman or cashier answerable for it.
- **Adjust Quantity/Value on Hand:** **Display Inventory Balances** lists every item of the site that is above or below zero (items at zero are left out); remove the lines not adjusted. **Shortage charged to** puts the decreases on a Shortage Charge for the cashier or sales rep instead of the adjustment account.
- **Reports** (Inventory → Reports → Shortage and Shrinkage Reports): Inventory Transfer Closing Register, Shortages by Item, by Site and by Sales Representative, Shortage Detail, Shrinkage by Item, Shrinkage Detail.

The User's Manual (Help button on every page) has a chapter on all of this: **8. Distribution and Crates**.

### Updating from the previous version

Dispatch Inventory and Convert Kilos to Crates need one small database update, `database/migrations/2027_03_22_dispatch_inventory.sql`. It adds the number series DSP- and the two pages, gives them to the roles that already have Transfer Inventory and Convert Crates to Kilos, and changes no record. No table or column is added. It is written for MySQL 5.5 and can be run twice safely.

1. Back up every company database.
2. Copy the new program files over the old ones.
3. Log in as `superadmin` and open **Database updates**: press **Update all companies**. Without the platform, import the file into each company database in phpMyAdmin (Import). Until it is run, the program shows a page saying the update is needed.

Installations of the first version need the update below first, then this one.

### Updating an installation of the first version

The database of a Distribution System already in use needs one update, `database/migrations/2027_03_08_van_closing_shortages.sql`. It adds the closing tables, the van salesman and cashier kinds, account 1120, the Employee customer type, the number series TC- and SHC-, the new pages with their access, and keeps every record. It is written for MySQL 5.5 and can be run twice safely.

1. Back up every company database (System Administration → Backup & Restore, or phpMyAdmin Export).
2. Copy the new program files over the old ones.
3. Log in as `superadmin` and open **Database updates**: press **Update all companies** (or update one company). Without the platform, import the file into the company database in phpMyAdmin (Import) instead. Until it is run, the program shows a page saying the update is needed and nothing can be changed.

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
- **System Administration:** users, roles, page access per role and per user, special permissions, company settings, closing date, imports from Excel workbooks (.xlsx templates with drop-down lists) and CSV files, backup and restore, and an audit trail that cannot be edited or deleted (MySQL triggers block it).
- **Reports:** filters, drill-down, export to Excel (.xlsx), print, PDF, memorize, scheduled e-mail, and Modify Report layouts. Every list and report export is an Excel workbook.

## 8. The interface

The look is built around a cold-chain warehouse: a freezer-navy menu rail, frost-white work surfaces, cold blue actions and crate yellow as the one accent, with a weighing-scale readout wherever kilos add up. The type is Barlow (Barlow Semi Condensed for titles) with Share Tech Mono only for scale figures and crate numbers. Buttons press in; the log-in page stacks crates onto a scale. Motion is limited to page arrival, the navigation progress bar, window openings and the scale count, and it switches off when the device asks for reduced motion. Every page works on a phone: the menu becomes a panel, wide tables scroll inside their own box, and the pick-up page turns each item into a block.

Styles: `assets/css/app.css` (layout and components) and `assets/css/theme.css` (the theme). Scripts: `assets/js/app.js`, `assets/js/theme.js`, `assets/js/crates.js` (the crate window), `assets/js/pwa.js` (installing the app). The stylesheets and scripts are addressed with `?v=<release>.<file date>`; raise `ASSET_RELEASE` in `app/helpers.php` to make every browser load them again.

### Installing it as an app

The system installs as an app (a PWA) on phones, tablets and computers: an icon that opens it in its own window, without the browser's address bar. No app store and nothing to build.

- **Install app** in the top bar and **Install the app** on the log-in page. Chrome, Edge and Android open their own install window; where the browser does not offer one, the button shows the steps for that browser (iPhone and iPad: **Share > Add to Home Screen**). Both are hidden inside the installed app.
- **It needs https.** Browsers install apps, and run the app's service worker, only from an `https://` address or from `localhost` on the server itself. Opened as `http://192.168.x.x/gsmart-distribution/` on an office network, the system works as before but cannot be installed; the button then says so. Give the server an https address (a certificate) for phones and other computers.
- **Nothing private is stored on the device.** Pages are never cached: every page comes from the server. Only `assets/` is cached (stylesheets, scripts, fonts, icons), so the app opens quickly. With no connection, `offline.html` says so with a **Try again** button. Saves, log-ins, uploads and downloads are never touched.
- **Files:** `manifest.php` (name, colors, icons; the name is the one in `config/config.php`), `sw.js` (the service worker), `offline.html`, `assets/icons/` (the app's initials on the menu-rail navy), `assets/js/pwa.js`, `app/Pwa.php`. Change `VERSION` in `sw.js` whenever `offline.html` changes. Nothing is added to the database.

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

`database/migrations/` holds the upgrade scripts of the accounting base, `2027_03_08_van_closing_shortages.sql` for a Distribution System database of the first version and `2027_03_22_dispatch_inventory.sql` for Dispatch Inventory (section 6). A new installation is made from the .sql files (or `tools/install.php`) and needs none of them.

## 12. Folder structure

```
index.php, login.php      entry points (index.php?p=<page key>)
register.php              joining a company with the Company Code
platform.php              the Super Admin pages
manual.php                the User's Manual (views/manual/, assets/manual/)
manifest.php, sw.js       the installable app (offline.html, assets/icons/, assets/js/pwa.js)
sign.php                  signing a voucher from a link
app/                      core classes: DB, Auth, Access, Txn, Posting, Stock, Crates, Allocations, Report, Tenant ...
app/registry.php          every page (menus and Page Access Configuration)
app/reports/              report definitions (distribution.php: crates and allocations; variances.php: shortages and shrinkage)
modules/                  pages, one folder per module (vendors/pickup.php, inventory/crates.php, inventory/transfer_closing.php ...)
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
