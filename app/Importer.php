<?php
declare(strict_types=1);

/**
 * Import from CSV (System Administration > Utilities > Import from CSV).
 *
 * Every import type describes its own columns; the same description makes the blank template,
 * the format shown on screen, and the checks the rows are read with. Nothing is written until
 * every row of the file has been read and checked, so a file with a bad row changes nothing.
 *
 * A file can be exported straight out of Excel: the first line holds the column names, in any order,
 * and a column that is not needed can be left out. Blank lines are skipped.
 */
final class Importer
{
    /**
     * Column kinds:
     *   text, num, int, date, bool  - plain values
     *   ref:<table>                 - the name (or the code / number) of an existing record; empty allowed unless required
     *   list:a|b|c                  - one of a fixed set of words
     */
    public static function types(): array
    {
        return [
            'accounts' => [
                'label' => 'Chart of accounts',
                'group' => 'Lists',
                'note'  => 'One line per account. A sub-account names its parent\'s code in "Sub-account of"; the parent must '
                    . 'already exist or appear earlier in the file. An account whose code is already there is updated rather than added again. '
                    . 'Leave "Normal balance" blank and it follows the account type, which is what all but contra accounts want.',
                'columns' => [
                    'code'            => ['Account code', 'text', true],
                    'name'            => ['Account name', 'text', true],
                    'account_type'    => ['Account type, exactly as the Chart of Accounts lists it (Bank, Expense, Income, ...)',
                        'list:Bank|Accounts Receivable|Other Current Asset|Fixed Asset|Other Asset|Accounts Payable|Credit Card|Other Current Liability|Long Term Liability|Equity|Income|Other Income|Cost of Goods Sold|Expense|Other Expense', true],
                    'parent_code'     => ['Sub-account of: the code of the parent account', 'text'],
                    'normal_balance'  => ['Debit or Credit (blank = from the account type)', 'list:Debit|Credit'],
                    'bank_account_no' => ['Bank account number (bank accounts)', 'text'],
                    'with_sl'         => ['Yes when the account keeps a subsidiary ledger ("With SL")', 'bool'],
                    'description'     => ['Description', 'text'],
                    'is_active'       => ['Yes for an active account; blank counts as yes', 'bool'],
                ],
                'sample' => ['6075', 'Cold Storage Fee', 'Expense', '', '', '', '', 'Monthly cold storage of frozen stock', 'Yes'],
            ],
            'items' => [
                'label' => 'Inventory items',
                'group' => 'Inventory',
                'note'  => 'One line per item. An item whose code is already on the Item List is updated rather than added again, and only the columns in the file are changed. '
                    . 'Type is Inventory part when left blank. A category that is not on the list yet is added. '
                    . 'Assemblies and groups list their components as "CODE x quantity", separated by semicolons; a component must already exist or appear earlier in the file. '
                    . 'Fill "Opening quantity" for new inventory parts and assemblies that are already in stock: one inventory adjustment per site and date is posted against Opening Balance Equity. '
                    . 'With production and expiry dates tracked, an opening quantity needs its production date and expiry date.',
                'columns' => self::itemColumns(),
                'sample' => self::itemSample(),
            ],
            'customers' => [
                'label' => 'Customers',
                'group' => 'Names',
                'note'  => 'One line per customer. A job is written as "Customer:Job" in the Name column; the customer must already exist or appear earlier in the file. '
                    . 'A customer that is already on the list is updated: only the cells of its line that have something in them are changed, and blank cells keep what is saved.',
                'columns' => [
                    'name'            => ['Name of the customer (or Customer:Job)', 'text', true],
                    'company_name'    => ['Company name', 'text'],
                    'contact_person'  => ['Contact person', 'text'],
                    'phone'           => ['Phone', 'text'],
                    'mobile'          => ['Mobile', 'text'],
                    'email'           => ['E-mail', 'text'],
                    'billing_address' => ['Billing address', 'text'],
                    'shipping_address' => ['Shipping address', 'text'],
                    'tin'             => ['TIN', 'text'],
                    'terms'           => ['Payment terms, as named in the Terms list', 'ref:terms'],
                    'credit_limit'    => ['Credit limit', 'num'],
                    'price_level'     => ['Price level, as named in the Price levels list', 'ref:price_levels'],
                    'tax_code'        => ['Tax code', 'ref:tax_codes'],
                    'customer_type'   => ['Customer type', 'ref:customer_types'],
                    'sales_rep'       => ['Sales representative', 'ref:sales_reps'],
                    'allow_pos_charge' => ['Can charge at the POS (yes/no)', 'bool'],
                    'notes'           => ['Notes', 'text'],
                ],
                'sample' => ['Sunrise Supermart', 'Sunrise Supermart Inc.', 'Ana Cruz', '(054) 473-1234', '0917 000 0000', 'purchasing@sunrise.example', 'Magsaysay Ave., Naga City', '', '123-456-789-000', 'Net 15', '100000', '', 'VAT12', '', '', 'no', ''],
            ],
            'vendors' => [
                'label' => 'Vendors (suppliers)',
                'group' => 'Names',
                'note'  => 'One line per supplier. A supplier that is already on the list is updated: only the cells of its line that have something in them are changed, and blank cells keep what is saved.',
                'columns' => [
                    'name'           => ['Name of the supplier', 'text', true],
                    'company_name'   => ['Company name', 'text'],
                    'contact_person' => ['Contact person', 'text'],
                    'phone'          => ['Phone', 'text'],
                    'fax'            => ['Fax', 'text'],
                    'email'          => ['E-mail', 'text'],
                    'address'        => ['Address', 'text'],
                    'tin'            => ['TIN', 'text'],
                    'terms'          => ['Payment terms', 'ref:terms'],
                    'credit_limit'   => ['Credit limit', 'num'],
                    'default_expense_account' => ['Account the purchases usually go to (code or name)', 'ref:accounts'],
                    'account_no'     => ['Your account number with the supplier', 'text'],
                    'notes'          => ['Notes', 'text'],
                ],
                'sample' => ['Northfield Poultry Corp.', 'Northfield Poultry Corporation', 'Ben Santos', '(054) 811-2233', '', 'orders@northfield.example', 'Pili, Camarines Sur', '293-713-644-000', 'Net 15', '0', '5000', 'NPC-0012', ''],
            ],
            'fixed_assets' => [
                'label' => 'Fixed assets',
                'group' => 'Names',
                'note'  => 'One line per asset. The asset is added to the register without an accounting entry, so an existing register can be loaded beside an opening trial balance that already carries it. '
                    . 'Put Yes in "Post opening" for assets that are not on the books yet, and an opening-balance entry is written for them. '
                    . 'Fill "Accumulated depreciation" and "Depreciated through" for assets that were already being depreciated.',
                'columns' => [
                    'description'      => ['Description of the asset', 'text', true],
                    'category'         => ['Asset category, as named in Asset Categories', 'ref:asset_categories', true],
                    'asset_no'         => ['Asset number (blank = the next one)', 'text'],
                    'location'         => ['Location (added to the Location list when it is new)', 'text'],
                    'serial_no'        => ['Serial / plate number', 'text'],
                    'vendor'           => ['Supplier it was bought from', 'ref:vendors'],
                    'class'            => ['Default class', 'ref:classes'],
                    'acquisition_date' => ['Date acquired', 'date', true],
                    'cost'             => ['Cost', 'num', true],
                    'salvage_value'    => ['Salvage (residual) value', 'num'],
                    'useful_life_years' => ['Useful life in years', 'num', true],
                    'method'           => ['Method: straight_line, declining_balance, syd or units_of_production', 'list:straight_line|declining_balance|syd|units_of_production'],
                    'opening_accum_dep' => ['Accumulated depreciation to date', 'num'],
                    'opening_through'  => ['Depreciated through (date)', 'date'],
                    'post_opening'     => ['Yes to post an opening-balance entry for this asset; leave blank when it is already on the books', 'bool'],
                    'notes'            => ['Notes', 'text'],
                ],
                'sample' => ['Reefer Van (L300)', 'Transportation Equipment', '', 'Naga Cold Storage', 'NAB-1234', 'Northfield Poultry Corp.', '', '2026-07-01', '1200000', '200000', '5', 'declining_balance', '80000', '2026-08-31', '', ''],
            ],
            'invoices' => [
                'label' => 'Invoices',
                'group' => 'Customer transactions',
                'note'  => 'One line per item line. Lines that carry the same "Document no." belong to one invoice; the header details are taken from its first line.',
                'txn'   => 'invoice',
                'columns' => self::salesColumns('invoice'),
                'sample' => ['INV-IMP-001', '2026-09-01', 'Sunrise Supermart', 'Net 15', 'DRM-FZ', 'Chicken Drumstick, Frozen', '12.5', '185', '0', 'VAT12', 'Naga Cold Storage', 'Head Office', 'Imported invoice', ''],
            ],
            'sales_receipts' => [
                'label' => 'Sales receipts',
                'group' => 'Customer transactions',
                'note'  => 'One line per item line, grouped by "Document no.". The money is put into the account named in "Deposit to", or Undeposited Funds when it is blank.',
                'txn'   => 'sales_receipt',
                'columns' => self::salesColumns('sales_receipt'),
                'sample' => ['SR-IMP-001', '2026-09-01', 'Walk-in Customer', '', 'BLB-250', 'Chicken Bola-Bola 250 g', '4', '65', '0', 'VAT12', 'Naga Outlet', 'Naga Outlet', 'Counter sale', '1000'],
            ],
            'sales_orders' => [
                'label' => 'Sales orders',
                'group' => 'Customer transactions',
                'note'  => 'One line per item line, grouped by "Document no.". Sales orders do not post to the ledger until they are invoiced.',
                'txn'   => 'sales_order',
                'columns' => self::salesColumns('sales_order'),
                'sample' => ['SO-IMP-001', '2026-09-01', 'Sunrise Supermart', '', 'WCK-FC', 'Whole Chicken, Fresh Chilled', '50', '175', '0', 'VAT12', 'Naga Cold Storage', '', 'Imported order', ''],
            ],
            'purchase_orders' => [
                'label' => 'Purchase orders',
                'group' => 'Supplier transactions',
                'note'  => 'One line per item line, grouped by "Document no.". Purchase orders do not post to the ledger.',
                'txn'   => 'purchase_order',
                'columns' => self::purchaseColumns('purchase_order'),
                'sample' => ['PO-IMP-001', '2026-09-01', 'Bicol Packaging Supply', '', 'PKG-BAG', 'Vacuum Bag 2 kg', '500', '4.50', 'VAT12', 'Naga Cold Storage', '', 'Imported order'],
            ],
            'receive_bills' => [
                'label' => 'Receive items and enter bills',
                'group' => 'Supplier transactions',
                'note'  => 'One line per item line, grouped by "Document no.". Each document becomes a bill: the items come into stock and Accounts Payable is credited. With production and expiry dates tracked, fill both dates on every line of an item that keeps them.',
                'txn'   => 'bill',
                'columns' => self::purchaseColumns('bill'),
                'sample' => ['BILL-IMP-001', '2026-09-01', 'Northfield Poultry Corp.', 'SI-99120', 'BRS-FZ', 'Chicken Breast, Frozen', '100', '180', 'VAT12', 'Naga Cold Storage', 'Head Office', 'Imported bill', '2026-08-30', '2027-02-26'],
            ],
            'checks' => [
                'label' => 'Write checks',
                'group' => 'Banking',
                'note'  => 'One line per expense line, grouped by "Document no.". Each document becomes a check drawn on the bank account named in "Bank account".',
                'txn'   => 'check',
                'columns' => [
                    'doc_no'       => ['Document no. (your own reference; lines with the same one make one check)', 'text', true],
                    'date'         => ['Date', 'date', true],
                    'bank_account' => ['Bank account (code or name)', 'ref:accounts', true],
                    'payee'        => ['Paid to: a supplier name, or any name', 'text', true],
                    'check_no'     => ['Check number', 'text'],
                    'account'      => ['Account charged (code or name)', 'ref:accounts', true],
                    'description'  => ['Description of the line', 'text'],
                    'amount'       => ['Amount', 'num', true],
                    'tax_code'     => ['Tax code', 'ref:tax_codes'],
                    'class'        => ['Class', 'ref:classes'],
                    'memo'         => ['Memo', 'text'],
                ],
                'sample' => ['CHK-IMP-001', '2026-09-02', '1010', 'Camarines Power Cooperative', '1051', '6020', 'August electricity', '8450', '', 'Head Office', 'Utilities'],
            ],
            'cash_vouchers' => [
                'label' => 'Cash vouchers',
                'group' => 'Banking',
                'note'  => 'One line per voucher line, grouped by "Document no.". The cash account is credited with the total of the debits less the credits.',
                'txn'   => 'cash_voucher',
                'columns' => [
                    'doc_no'       => ['Document no. (lines with the same one make one voucher)', 'text', true],
                    'date'         => ['Date', 'date', true],
                    'cash_account' => ['Cash account paid from (code or name)', 'ref:accounts', true],
                    'paid_to'      => ['Paid to: employee, customer, supplier or any name', 'text', true],
                    'account'      => ['Account (code or name)', 'ref:accounts', true],
                    'debit'        => ['Debit', 'num'],
                    'credit'       => ['Credit', 'num'],
                    'memo'         => ['Memo of the line', 'text'],
                    'class'        => ['Class', 'ref:classes'],
                    'particulars'  => ['Particulars (header)', 'text'],
                    'ref_no'       => ['Reference no.', 'text'],
                ],
                'sample' => ['CAV-IMP-001', '2026-09-03', '1005', 'Maria Santos', '6040', '900.50', '', 'Bond paper', 'Head Office', 'Office supplies', 'OR-5512'],
            ],
            'journals' => [
                'label' => 'Journal entries',
                'group' => 'Banking',
                'note'  => 'One line per journal line, grouped by "Document no.". The debits and the credits of each document must be equal.',
                'txn'   => 'journal',
                'columns' => [
                    'doc_no'      => ['Document no. (lines with the same one make one entry)', 'text', true],
                    'date'        => ['Date', 'date', true],
                    'account'     => ['Account (code or name)', 'ref:accounts', true],
                    'debit'       => ['Debit', 'num'],
                    'credit'      => ['Credit', 'num'],
                    'description' => ['Memo of the line', 'text'],
                    'name'        => ['Name on the line: customer, supplier, employee or other name', 'text'],
                    'class'       => ['Class', 'ref:classes'],
                    'memo'        => ['Memo (header)', 'text'],
                    'ref_no'      => ['Reference no.', 'text'],
                ],
                'sample' => ['JE-IMP-001', '2026-09-30', '6000', '25000', '', 'September salaries', '', 'Head Office', 'Payroll accrual', ''],
            ],
            'pos_sales' => [
                'label' => 'POS transactions',
                'group' => 'Point of sale',
                'note'  => 'One line per item line, grouped by "Receipt no.". Each receipt becomes a completed POS sale on the terminal named in "Terminal", '
                    . 'with its payment recorded in "Payment method". A shift is opened for the terminal if none is open.',
                'txn'   => 'pos_sale',
                'columns' => [
                    'receipt_no'  => ['Receipt no. (lines with the same one make one sale)', 'text', true],
                    'date'        => ['Date', 'date', true],
                    'terminal'    => ['POS terminal (code or name)', 'ref:pos_terminals', true],
                    'customer'    => ['Customer (blank = walk-in)', 'ref:customers'],
                    'item'        => ['Item name/code', 'ref:items', true],
                    'description' => ['Description', 'text'],
                    'qty'         => ['Quantity', 'num', true],
                    'price'       => ['Price per unit', 'num', true],
                    'discount_pct' => ['Discount %', 'num'],
                    'tax_code'    => ['Tax code', 'ref:tax_codes'],
                    'payment_method' => ['Payment method: Cash, GCash, BPI ...', 'ref:payment_methods'],
                    'class'       => ['Class', 'ref:classes'],
                ],
                'sample' => ['POS1-IMP-0001', '2026-09-05', 'POS-01', '', 'BRS-FZ', 'Chicken Breast, Frozen', '1.5', '210', '0', 'VAT12', 'Cash', 'Naga Outlet'],
            ],
        ];
    }

    /** Item types, and the other ways people write them */
    public const ITEM_TYPES = [
        'inventory' => 'Inventory part', 'non_inventory' => 'Non-inventory part', 'service' => 'Service', 'assembly' => 'Inventory assembly',
        'other_charge' => 'Other charge', 'group' => 'Group', 'discount' => 'Discount', 'subtotal' => 'Subtotal', 'payment' => 'Payment',
    ];

    /** "Inventory part", "inventory", "Non-inventory part", "Inventory assembly" ... to the system's own spelling ('' = blank, null = unknown) */
    public static function itemType(string $raw): ?string
    {
        $k = strtolower(preg_replace('/[^a-z]/i', '', $raw));
        if ($k === '') {
            return '';
        }
        $aliases = ['inventorypart' => 'inventory', 'inventoryitem' => 'inventory', 'part' => 'inventory', 'stock' => 'inventory',
            'noninventorypart' => 'non_inventory', 'noninventoryitem' => 'non_inventory', 'noninventory' => 'non_inventory',
            'inventoryassembly' => 'assembly', 'assembly' => 'assembly', 'othercharge' => 'other_charge', 'charge' => 'other_charge'];
        if (isset($aliases[$k])) {
            return $aliases[$k];
        }
        foreach (array_keys(self::ITEM_TYPES) as $t) {
            if ($k === str_replace('_', '', $t)) {
                return $t;
            }
        }
        return null;
    }

    /** The columns of the item import, with one price column for every active price level */
    private static function itemColumns(): array
    {
        $cols = [
            'code'                 => ['Item name / code (unique)', 'text', true],
            'name'                 => ['Display name (needed for a new item)', 'text'],
            'item_type'            => ['Type: ' . implode(', ', self::ITEM_TYPES) . ' (blank = Inventory part)', 'text'],
            'barcode'              => ['Barcode (unique)', 'text'],
            'description'          => ['Sales description', 'text'],
            'purchase_description' => ['Purchase description', 'text'],
            'category'             => ['Category (added to the Category list when it is new)', 'text'],
            'unit'                 => ['Unit of measure, e.g. pc, box, kg (blank = pc; ignored when a U/M set is named)', 'text'],
            'uom_set'              => ['U/M set, as named in Units of Measure (blank = single unit)', 'ref:uom_sets'],
            'sales_unit'           => ['Unit of the U/M set offered first on sales (code or name)', 'text'],
            'purchase_unit'        => ['Unit of the U/M set offered first on purchases (code or name)', 'text'],
            'cost'                 => ['Purchase cost per unit', 'num'],
            'sales_price'          => ['Sales price (for a discount item: the fixed discount amount)', 'num'],
        ];
        try {
            foreach (DB::all('SELECT id, name FROM price_levels WHERE is_active = 1 ORDER BY id') as $pl) {
                $cols['price_level_' . (int)$pl['id']] = ['Price for the price level "' . $pl['name'] . '" (blank = the level\'s own percentage)', 'num'];
            }
        } catch (Throwable $e) {
            // no company database open: the columns without the price levels
        }
        return $cols + [
            'discount_pct'     => ['Discount items: discount % (0 = the fixed amount in Sales price)', 'num'],
            'tax_code'         => ['Tax code', 'ref:tax_codes'],
            'income_account'   => ['Income account, code or name (blank = the module default)', 'ref:accounts'],
            'cogs_account'     => ['Cost of goods sold account for inventory parts and assemblies (blank = the default)', 'ref:accounts'],
            'asset_account'    => ['Inventory asset account for inventory parts and assemblies (blank = the default)', 'ref:accounts'],
            'expense_account'  => ['Expense / purchase account for non-inventory parts, services and other charges', 'ref:accounts'],
            'preferred_vendor' => ['Preferred supplier', 'ref:vendors'],
            'reorder_point'    => ['Reorder point (minimum)', 'num'],
            'max_stock'        => ['Maximum stock', 'num'],
            'build_point'      => ['Build point (assemblies)', 'num'],
            'components'       => ['Assemblies and groups: components as CODE x quantity; CODE x quantity', 'text'],
            'opening_qty'      => ['Opening quantity on hand (new inventory parts and assemblies)', 'num'],
            'opening_cost'     => ['Opening cost per unit (blank = the Cost column)', 'num'],
            'opening_site'     => ['Site the opening quantity is at, code or name (blank = the only site)', 'ref:sites'],
            'opening_date'     => ['Opening quantity as of (blank = today)', 'date'],
            'opening_production_date' => ['Production date of the opening quantity (needed when production and expiry dates are tracked)', 'date'],
            'opening_expiry_date'     => ['Expiry date of the opening quantity (needed when production and expiry dates are tracked)', 'date'],
            'is_active'        => ['Yes for an active item; blank counts as yes', 'bool'],
        ];
    }

    /** One example line for the item template, in the order of the columns */
    private static function itemSample(): array
    {
        $example = [
            'code' => 'THG-FZ', 'name' => 'Chicken Thigh, Frozen, Bag', 'item_type' => 'Inventory part', 'barcode' => '4800000150157',
            'description' => 'Chicken Thigh, Frozen', 'purchase_description' => 'Chicken Thigh, Frozen (supplier code NPC-THG)', 'category' => 'Chicken Cuts',
            'unit' => 'kg', 'cost' => '160', 'sales_price' => '195', 'tax_code' => 'VAT12', 'preferred_vendor' => 'Northfield Poultry Corp.',
            'reorder_point' => '100', 'max_stock' => '800', 'opening_qty' => '250', 'opening_cost' => '160', 'opening_site' => 'Naga Cold Storage',
            'opening_date' => today(), 'opening_production_date' => date('Y-m-d', strtotime('-1 day')), 'opening_expiry_date' => date('Y-m-d', strtotime('+6 months')),
            'is_active' => 'Yes',
        ];
        return array_map(fn($k) => $example[$k] ?? '', array_keys(self::itemColumns()));
    }

    private static function salesColumns(string $type): array
    {
        $cols = [
            'doc_no'      => ['Document no. (your own reference; lines with the same one make one document)', 'text', true],
            'date'        => ['Date', 'date', true],
            'customer'    => ['Customer (or Customer:Job)', 'ref:customers', true],
            'terms'       => ['Payment terms', 'ref:terms'],
            'item'        => ['Item name/code', 'ref:items', true],
            'description' => ['Description', 'text'],
            'qty'         => ['Quantity', 'num', true],
            'rate'        => ['Price per unit', 'num', true],
            'discount_pct' => ['Discount %', 'num'],
            'tax_code'    => ['Tax code', 'ref:tax_codes'],
            'site'        => ['Inventory site', 'ref:sites'],
            'class'       => ['Class', 'ref:classes'],
            'memo'        => ['Memo (header)', 'text'],
        ];
        $cols['deposit_to'] = $type === 'sales_receipt'
            ? ['Deposit to (bank or cash account; blank = Undeposited Funds)', 'ref:accounts']
            : ['(not used)', 'text'];
        return $cols;
    }

    private static function purchaseColumns(string $type): array
    {
        $cols = [
            'doc_no'      => ['Document no. (your own reference; lines with the same one make one document)', 'text', true],
            'date'        => ['Date', 'date', true],
            'vendor'      => ['Supplier', 'ref:vendors', true],
            'ref_no'      => [$type === 'bill' ? "Supplier's invoice no." : 'Reference no.', 'text'],
            'item'        => ['Item name/code', 'ref:items', true],
            'description' => ['Description', 'text'],
            'qty'         => ['Quantity', 'num', true],
            'rate'        => ['Cost per unit', 'num', true],
            'tax_code'    => ['Tax code', 'ref:tax_codes'],
            'site'        => ['Inventory site', 'ref:sites'],
            'class'       => ['Class', 'ref:classes'],
            'memo'        => ['Memo (header)', 'text'],
        ];
        // v5: what comes into stock on a bill carries its production and expiry dates, as on the Enter Bills form
        if ($type === 'bill') {
            $cols['production_date'] = ['Production date (needed for items that keep dates, when production and expiry dates are tracked)', 'date'];
            $cols['expiry_date'] = ['Expiry date (needed for items that keep dates, when production and expiry dates are tracked)', 'date'];
        }
        return $cols;
    }

    public static function type(string $key): ?array
    {
        return self::types()[$key] ?? null;
    }

    /** The blank template of one import type: the headings, and one example line */
    public static function template(string $key): array
    {
        $t = self::type($key);
        return [array_keys($t['columns']), [$t['sample'] ?? []]];
    }

    /**
     * The template as an Excel workbook: an Import sheet with the column names on row 1 (frozen) and nothing
     * under them, a How to fill sheet with what goes in each column and an example, and drop-down lists on the
     * Import sheet: the allowed words of a column (Debit / Credit, the account types, Yes / No) and the
     * company's own sites, customers, items, accounts, terms and the rest. Every column but the amounts is
     * formatted as text, so codes keep their leading zeros and dates stay as they are typed.
     */
    public static function workbook(string $key): array
    {
        $t = self::type($key);
        $cols = $t['columns'];
        $head = array_keys($cols);
        $sample = array_values($t['sample'] ?? []);
        $kinds = [];
        $lists = [];
        $guide = [];
        foreach ($head as $i => $col) {
            [$label, $kind] = [$cols[$col][0], $cols[$col][1]];
            $required = !empty($cols[$col][2]);
            $kinds[$i] = in_array($kind, ['num', 'int'], true) ? 'num' : 'text';
            $allowed = '';
            if ($kind === 'bool') {
                $lists[$i] = ['values' => ['Yes', 'No'], 'strict' => true];
                $allowed = 'Yes or No';
            } elseif (str_starts_with($kind, 'list:')) {
                $words = explode('|', substr($kind, 5));
                $lists[$i] = ['values' => $words, 'strict' => true];
                $allowed = implode(', ', $words);
            } elseif (str_starts_with($kind, 'ref:')) {
                $values = self::refValues(substr($kind, 4));
                if ($values) {
                    $lists[$i] = ['values' => $values, 'strict' => false];
                    $allowed = 'Pick from the list (' . count($values) . ') or type it';
                    // the example is one that is really on the company's list
                    $ex = (string)($sample[$i] ?? '');
                    if ($ex !== '' && !in_array(mb_strtolower($ex), array_map('mb_strtolower', $values), true) && !self::ref(substr($kind, 4), $ex)) {
                        $sample[$i] = $values[0];
                    }
                }
            } elseif ($kind === 'date') {
                $allowed = 'A date: 2026-09-30 or 09/30/2026';
            } elseif ($kind === 'num' || $kind === 'int') {
                $allowed = 'A number';
            }
            $guide[] = [$col, $label, $required ? 'Yes' : '', $allowed, (string)($sample[$i] ?? '')];
        }
        return [
            ['name' => 'Import', 'head' => $head, 'rows' => [], 'kinds' => $kinds, 'lists' => $lists,
                'widths' => array_map(fn($c) => max(12, min(34, strlen($c) + 4)), $head)],
            ['name' => 'How to fill', 'wrap' => true, 'kinds' => ['text', 'text', 'text', 'text', 'text'], 'widths' => [24, 58, 9, 34, 30],
                'title' => [
                    [$t['label'], 'bold'],
                    ['Fill in the Import sheet: keep row 1 as it is and type one ' . (isset($t['txn']) ? 'item line' : 'record') . ' per row from row 2. '
                        . 'A column you do not need can be left blank or deleted, and the order of the columns does not matter. '
                        . 'Save the workbook as it is (Excel Workbook, .xlsx) and choose it on System Administration > Import from CSV, then press Check the file.', 'note'],
                    [(string)($t['note'] ?? ''), 'note'],
                ],
                'head' => ['Column', 'What goes in it', 'Needed', 'Allowed values', 'Example'], 'rows' => $guide],
        ];
    }

    /** The names (or codes) a drop-down of a reference column offers: what Import looks the value up by */
    private static function refValues(string $table): array
    {
        $show = [
            'terms' => 'name', 'price_levels' => 'name', 'tax_codes' => 'code', 'customer_types' => 'name', 'sales_reps' => 'name',
            'accounts' => 'name', 'classes' => 'name', 'sites' => 'name', 'item_categories' => 'name', 'uom_sets' => 'name',
            'customers' => 'name', 'vendors' => 'name', 'items' => 'code', 'asset_categories' => 'name', 'pos_terminals' => 'code',
            'payment_methods' => 'name',
        ][$table] ?? null;
        if (!$show || !preg_match('/^[a-z_]+$/', $table)) {
            return [];
        }
        foreach (["SELECT DISTINCT $show FROM $table WHERE is_active = 1 AND $show <> '' ORDER BY $show LIMIT 3000",
                  "SELECT DISTINCT $show FROM $table WHERE $show <> '' ORDER BY $show LIMIT 3000"] as $sql) {
            try {
                return array_map('strval', DB::column($sql));
            } catch (Throwable $e) {
                // no is_active column on this list: all of it
            }
        }
        return [];
    }

    /**
     * Opens a CSV as UTF-8 text whatever Excel saved it as. Excel on Windows writes "CSV" files in the
     * Windows-1252 code page, so curly quotes (" "), dashes and the peso sign arrive as single bytes that are
     * not UTF-8; MySQL then refuses them ("Incorrect string value") or the cell turns up blank. Those files are
     * converted here; UTF-8 files (with or without a byte-order mark) and UTF-16 "Unicode text" files are read
     * as they are. The check and the import both go through this, so they always agree.
     */
    public static function openAsUtf8(string $file)
    {
        $raw = @file_get_contents($file);
        if ($raw === false) {
            fail('The file could not be read.');
        }
        if (str_starts_with($raw, "\xFF\xFE") || str_starts_with($raw, "\xFE\xFF")) {
            // Excel's "Unicode text" (tab-separated: read() finds the tabs)
            $raw = mb_convert_encoding(substr($raw, 2), 'UTF-8', str_starts_with($raw, "\xFF\xFE") ? 'UTF-16LE' : 'UTF-16BE');
        } elseif (str_starts_with($raw, "\xEF\xBB\xBF")) {
            $raw = substr($raw, 3);
        } elseif (!mb_check_encoding($raw, 'UTF-8')) {
            $raw = mb_convert_encoding($raw, 'UTF-8', 'Windows-1252');
        }
        // the curly quotes Excel puts in are kept as they are typed (they are ordinary characters in UTF-8);
        // a stray C1 control byte that Windows-1252 could not map becomes a plain straight quote or dash
        $raw = strtr($raw, ["\xC2\x93" => "\xE2\x80\x9C", "\xC2\x94" => "\xE2\x80\x9D", "\xC2\x91" => "\xE2\x80\x98", "\xC2\x92" => "\xE2\x80\x99", "\xC2\x96" => "\xE2\x80\x93", "\xC2\x97" => "\xE2\x80\x94"]);
        $fh = fopen('php://temp', 'r+');
        fwrite($fh, $raw);
        rewind($fh);
        return $fh;
    }

    /** The column separator of a file, from its first line: the one that splits it into the most known column names */
    public static function separator(string $first, array $columns): string
    {
        $best = ',';
        $bestScore = [-1, -1];
        foreach ([',', ';', "\t", '|'] as $sep) {
            $cells = str_getcsv(rtrim($first, "\r\n"), $sep, '"', '');
            $known = 0;
            foreach ($cells as $c) {
                $known += isset($columns[strtolower(trim(str_replace([' ', '-'], '_', (string)$c)))]) ? 1 : 0;
            }
            $score = [$known, count($cells)];
            if ($score > $bestScore) {
                [$best, $bestScore] = [$sep, $score];
            }
        }
        return $best;
    }

    /** Reads an uploaded CSV into rows keyed by the column names of the type */
    /** v5: the column names of the file last read that are not columns of its import type (they are not read) */
    public static array $ignored = [];

    public static function read(string $file, string $key): array
    {
        self::$ignored = [];
        $t = self::type($key);
        if (!$t) {
            fail('Choose what to import.');
        }
        // an Excel workbook is read as it is (the template the system gives is one)
        $head8 = (string)@file_get_contents($file, false, null, 0, 8);
        if (Xlsx::isOldXls($head8)) {
            fail('This is an old Excel 97-2003 workbook (.xls). In Excel, save it as Excel Workbook (.xlsx) or as CSV, then choose it again.');
        }
        if (Xlsx::isXlsx($head8)) {
            return self::readWorkbook((string)file_get_contents($file), $t);
        }
        $fh = self::openAsUtf8($file);
        $first = fgets($fh);
        if ($first === false) {
            fclose($fh);
            fail('The file is empty.');
        }
        // Excel writes a byte-order mark, and the columns may be split by commas, by semicolons (a comma-decimal
        // Windows setting) or by tabs (Excel's "Text (Tab delimited)" or "Unicode Text" saved under a .csv name,
        // or cells pasted from a sheet): the separator is the one that turns the first line into the most known columns
        $first = preg_replace('/^\xEF\xBB\xBF/', '', $first);
        $sep = self::separator($first, $t['columns']);
        rewind($fh);
        $head = fgetcsv($fh, 0, $sep, '"', '');
        if ($head) {
            $head[0] = preg_replace('/^\xEF\xBB\xBF/', '', (string)$head[0]);
        }
        $map = [];
        foreach ((array)$head as $i => $name) {
            $n = strtolower(trim(str_replace([' ', '-'], '_', (string)$name)));
            if (isset($t['columns'][$n])) {
                $map[$i] = $n;
            } elseif (trim((string)$name) !== '') {
                self::$ignored[] = trim((string)$name);
            }
        }
        if (!$map) {
            fclose($fh);
            $seen = trim(preg_replace('/\s+/', ' ', str_replace(["\t", "\r", "\n"], [' | ', '', ''], (string)$first)));
            fail('The first line of the file must hold the column names (' . implode(', ', array_slice(array_keys($t['columns']), 0, 4)) . ', ...). '
                . 'The first line of this file reads: "' . mb_strimwidth($seen, 0, 90, '...') . '". Download the template for "' . $t['label'] . '" to see them.');
        }
        $rows = [];
        $line = 1;
        while (($r = fgetcsv($fh, 0, $sep, '"', '')) !== false) {
            $line++;
            if ($r === [null] || (count($r) === 1 && trim((string)$r[0]) === '')) {
                continue;
            }
            $row = ['_line' => $line];
            foreach ($map as $i => $n) {
                $row[$n] = isset($r[$i]) ? trim((string)$r[$i]) : '';
            }
            $rows[] = $row;
        }
        fclose($fh);
        if (!$rows) {
            fail('The file holds no data lines.');
        }
        return $rows;
    }

    /**
     * The rows of an Excel workbook: the sheet whose first filled row holds the most known column names (the
     * Import sheet of the template; How to fill is left alone), each row numbered as Excel numbers it.
     */
    private static function readWorkbook(string $bytes, array $t): array
    {
        $norm = fn($v): string => strtolower(trim(str_replace([' ', '-'], '_', (string)$v)));
        $best = null;
        $first = null;
        foreach (Xlsx::sheets($bytes) as $sheet) {
            if (!$sheet['rows']) {
                continue;
            }
            $headNo = array_key_first($sheet['rows']);
            $map = [];
            foreach ($sheet['rows'][$headNo] as $i => $name) {
                if (isset($t['columns'][$norm($name)])) {
                    $map[$i] = $norm($name);
                }
            }
            if ($map && (!$best || count($map) > count($best['map']))) {
                $best = ['sheet' => $sheet, 'head' => $headNo, 'map' => $map];
            }
            $first = $first ?? $sheet['rows'][$headNo];
        }
        if ($best) {
            foreach ($best['sheet']['rows'][$best['head']] as $i => $name) {
                if (!isset($best['map'][$i]) && trim((string)$name) !== '') {
                    self::$ignored[] = trim((string)$name);
                }
            }
        }
        if (!$best) {
            fail('Row 1 of the workbook must hold the column names (' . implode(', ', array_slice(array_keys($t['columns']), 0, 4)) . ', ...). '
                . ($first !== null ? 'It reads: "' . mb_strimwidth(implode(' | ', $first), 0, 90, '...') . '". ' : 'The workbook is empty. ')
                . 'Download the template for "' . $t['label'] . '" and fill in its Import sheet.');
        }
        $rows = [];
        foreach ($best['sheet']['rows'] as $no => $cells) {
            if ($no <= $best['head']) {
                continue;
            }
            $row = ['_line' => (int)$no];
            $any = false;
            foreach ($best['map'] as $i => $n) {
                $row[$n] = trim((string)($cells[$i] ?? ''));
                $any = $any || $row[$n] !== '';
            }
            if ($any) {
                $rows[] = $row;
            }
        }
        if (!$rows) {
            fail('The workbook holds no data rows under the column names.');
        }
        return $rows;
    }

    /** Looks a name up in a list; returns the id, or null. Accepts the code as well as the name. */
    public static function ref(string $table, string $value): ?int
    {
        $value = trim($value);
        if ($value === '') {
            return null;
        }
        static $cache = [];
        $k = $table . '|' . mb_strtolower($value);
        if (array_key_exists($k, $cache)) {
            return $cache[$k];
        }
        $cols = [
            'terms' => ['name'], 'price_levels' => ['name'], 'tax_codes' => ['code', 'name'], 'customer_types' => ['name'],
            'sales_reps' => ['name'], 'accounts' => ['code', 'name'], 'classes' => ['name'], 'sites' => ['name', 'code'],
            'item_categories' => ['name'], 'uom_sets' => ['name'],
            'customers' => ['name'], 'vendors' => ['name'], 'items' => ['code', 'name', 'barcode'],
            'asset_categories' => ['name'], 'pos_terminals' => ['code', 'name'], 'payment_methods' => ['name'],
        ][$table] ?? ['name'];
        $id = null;
        foreach ($cols as $c) {
            $id = DB::value("SELECT id FROM $table WHERE $c = :v ORDER BY id LIMIT 1", ['v' => $value]);
            if ($id) {
                break;
            }
        }
        return $cache[$k] = $id ? (int)$id : null;
    }

    /** Reads one value of a row the way its column says it should be read */
    public static function value(array $row, string $col, array $spec, array &$errors): mixed
    {
        [$label, $kind] = [$spec[0], $spec[1]];
        $required = $spec[2] ?? false;
        $raw = trim((string)($row[$col] ?? ''));
        if ($raw === '') {
            if ($required) {
                $errors[] = 'Line ' . $row['_line'] . ': "' . $col . '" (' . $label . ') is needed.';
            }
            return $kind === 'num' ? 0.0 : ($kind === 'int' ? 0 : ($kind === 'bool' ? 0 : null));
        }
        if (str_starts_with($kind, 'ref:')) {
            $table = substr($kind, 4);
            $id = self::ref($table, $raw);
            if (!$id) {
                $errors[] = 'Line ' . $row['_line'] . ': "' . $raw . '" is not in the ' . str_replace('_', ' ', $table) . ' list (column "' . $col . '").';
            }
            return $id;
        }
        if (str_starts_with($kind, 'list:')) {
            // a word from a fixed set. Either spelling is accepted - "Straight line", "straight_line",
            // "Cost of Goods Sold" - and what comes back is the spelling the set itself uses.
            $allowed = explode('|', substr($kind, 5));
            $loose = fn(string $x): string => strtolower(str_replace([' ', '-', '_'], '', trim($x)));
            $want = $loose($raw);
            foreach ($allowed as $a) {
                if ($loose($a) === $want) {
                    return $a;
                }
            }
            $errors[] = 'Line ' . $row['_line'] . ': "' . $raw . '" is not allowed in "' . $col . '". Use one of: ' . implode(', ', $allowed) . '.';
            return null;
        }
        switch ($kind) {
            case 'num':
                return r2(to_num($raw));
            case 'int':
                return (int)to_num($raw);
            case 'bool':
                return in_array(strtolower($raw), ['1', 'y', 'yes', 'true', 'oo', 'opo'], true) ? 1 : 0;
            case 'date':
                $d = self::date($raw);
                if (!$d) {
                    $errors[] = 'Line ' . $row['_line'] . ': "' . $raw . '" is not a date the system understands (use 2026-09-30 or 09/30/2026).';
                }
                return $d;
            default:
                return $raw;
        }
    }

    /** Dates as Excel and people write them */
    public static function date(string $v): ?string
    {
        $v = trim($v);
        foreach (['Y-m-d', 'm/d/Y', 'd/m/Y', 'Y/m/d', 'm-d-Y', 'd-m-Y', 'M j, Y', 'j M Y', 'Y-m-d H:i:s', 'm/d/Y H:i'] as $fmt) {
            $d = DateTime::createFromFormat($fmt, $v);
            if ($d && $d->format($fmt) === $v) {
                return $d->format('Y-m-d');
            }
        }
        $ts = strtotime($v);
        return $ts ? date('Y-m-d', $ts) : null;
    }

    /** Groups transaction rows by their document number, keeping the order of the file */
    public static function group(array $rows, string $keyCol): array
    {
        $out = [];
        foreach ($rows as $r) {
            $out[(string)($r[$keyCol] ?? '')][] = $r;
        }
        return $out;
    }

    /** Writes what an import did, so it can be traced later */
    public static function logBatch(string $type, string $fileName, int $total, int $ok, int $failed, array $created, array $messages): int
    {
        return DB::insert('import_batches', [
            'import_type' => $type, 'file_name' => mb_substr($fileName, 0, 190), 'rows_total' => $total, 'rows_ok' => $ok, 'rows_failed' => $failed,
            'created_ids' => json_encode(array_slice($created, 0, 2000)), 'messages' => mb_substr(implode("\n", $messages), 0, 60000), 'created_by' => Auth::id(),
        ]);
    }
}
