<?php
declare(strict_types=1);

/**
 * Master data: modules, pages, standard roles and their access, demo users,
 * chart of accounts, default accounts, lists, sites, items, customers, vendors,
 * asset categories, POS terminals and number sequences.
 */
function seed_master_data(): void
{
    $reg = require APP_ROOT . '/app/registry.php';

    // ---------------------------------------------------------------- settings
    $settings = Settings::DEFAULTS;
    $settings['company_name'] = 'Northpoint Cold Chain Distributors Inc.';
    $settings['company_address'] = 'Km 2 Diversion Road, Naga City, Camarines Sur';
    $settings['company_tin'] = '000-482-915-000';
    $settings['company_phone'] = '(054) 881-2047';
    $settings['company_email'] = 'accounting@northpoint.test';
    foreach ($settings as $k => $v) {
        DB::insert('settings', ['setting_key' => $k, 'setting_value' => $v]);
    }

    // ---------------------------------------------------------------- modules & pages
    $moduleIds = [];
    foreach ($reg['modules'] as $code => [$name, $icon, $sort]) {
        $moduleIds[$code] = DB::insert('modules', ['code' => $code, 'name' => $name, 'icon' => $icon, 'sort_order' => $sort]);
    }
    $pageIds = [];
    $sort = 0;
    foreach ($reg['pages'] as $key => [$module, $name, $type, $group, $file, $params, $menu]) {
        $pageIds[$key] = DB::insert('pages', [
            'page_key' => $key, 'module_id' => $moduleIds[$module], 'name' => $name, 'page_type' => $type,
            'menu_group' => $group, 'sort_order' => ++$sort * 10, 'show_in_menu' => $menu,
        ]);
    }

    // ---------------------------------------------------------------- chart of accounts
    $typeInfo = [
        'Bank' => ['Asset', 'Debit'], 'Accounts Receivable' => ['Asset', 'Debit'], 'Other Current Asset' => ['Asset', 'Debit'],
        'Fixed Asset' => ['Asset', 'Debit'], 'Other Asset' => ['Asset', 'Debit'], 'Accounts Payable' => ['Liability', 'Credit'],
        'Credit Card' => ['Liability', 'Credit'], 'Other Current Liability' => ['Liability', 'Credit'], 'Long Term Liability' => ['Liability', 'Credit'],
        'Equity' => ['Equity', 'Credit'], 'Income' => ['Income', 'Credit'], 'Other Income' => ['Income', 'Credit'],
        'Cost of Goods Sold' => ['Expense', 'Debit'], 'Expense' => ['Expense', 'Debit'], 'Other Expense' => ['Expense', 'Debit'],
    ];
    // code, name, type, normal balance override, parent code
    $coa = [
        ['1000', 'Cash', 'Bank', null, null],
        ['1001', 'Cash on Hand - Store Registers', 'Bank', null, '1000'],
        ['1005', 'Petty Cash Fund', 'Bank', null, '1000'],
        ['1006', 'Revolving Fund', 'Bank', null, '1000'],
        ['1010', 'Cash in Bank - BDO Checking', 'Bank', null, '1000'],
        ['1020', 'Cash in Bank - BPI Savings', 'Bank', null, '1000'],
        ['1050', 'Undeposited Funds', 'Other Current Asset', null, null],
        ['1060', 'Card Clearing', 'Other Current Asset', null, null],
        ['1065', 'E-wallet Clearing', 'Other Current Asset', null, null],
        ['1070', 'P.O. Card Clearing', 'Other Current Asset', null, null],
        ['1100', 'Accounts Receivable', 'Accounts Receivable', null, null],
        ['1120', 'Shortage Receivable - Employees', 'Accounts Receivable', null, null],
        ['1150', 'Allowance for Doubtful Accounts', 'Other Current Asset', 'Credit', null],
        ['1200', 'Inventory', 'Other Current Asset', null, null],
        ['1300', 'Input Tax', 'Other Current Asset', null, null],
        ['1310', 'Creditable Withholding Tax', 'Other Current Asset', null, null],
        ['1315', 'Creditable VAT Withheld', 'Other Current Asset', null, null],
        ['1400', 'Prepaid Expenses', 'Other Current Asset', null, null],
        ['1410', 'Advances to Suppliers', 'Other Current Asset', null, null],
        ['1500', 'Land', 'Fixed Asset', null, null],
        ['1510', 'Building', 'Fixed Asset', null, null],
        ['1515', 'Accumulated Depreciation - Building', 'Fixed Asset', 'Credit', null],
        ['1520', 'Machinery and Equipment', 'Fixed Asset', null, null],
        ['1525', 'Accumulated Depreciation - Machinery', 'Fixed Asset', 'Credit', null],
        ['1530', 'Transportation Equipment', 'Fixed Asset', null, null],
        ['1535', 'Accumulated Depreciation - Transportation', 'Fixed Asset', 'Credit', null],
        ['1540', 'Furniture and Fixtures', 'Fixed Asset', null, null],
        ['1545', 'Accumulated Depreciation - Furniture', 'Fixed Asset', 'Credit', null],
        ['1550', 'Computer and POS Equipment', 'Fixed Asset', null, null],
        ['1555', 'Accumulated Depreciation - Computer and POS', 'Fixed Asset', 'Credit', null],
        ['1600', 'Security Deposits', 'Other Asset', null, null],
        ['2000', 'Accounts Payable', 'Accounts Payable', null, null],
        ['2050', 'Company Credit Card', 'Credit Card', null, null],
        ['2100', 'Output Tax', 'Other Current Liability', null, null],
        ['2110', 'Withholding Tax Payable', 'Other Current Liability', null, null],
        ['2115', 'VAT Withheld Payable', 'Other Current Liability', null, null],
        ['2120', 'Gift Vouchers Outstanding', 'Other Current Liability', null, null],
        ['2130', 'Customer Deposits', 'Other Current Liability', null, null],
        ['2200', 'Accrued Expenses', 'Other Current Liability', null, null],
        ['2500', 'Loans Payable', 'Long Term Liability', null, null],
        ['3000', "Owner's Capital", 'Equity', null, null],
        ['3100', "Owner's Drawings", 'Equity', 'Debit', null],
        ['3200', 'Retained Earnings', 'Equity', null, null],
        ['3900', 'Opening Balance Equity', 'Equity', null, null],
        ['4000', 'Sales', 'Income', null, null],
        ['4010', 'Service Income', 'Income', null, null],
        ['4020', 'Delivery Income', 'Income', null, null],
        ['4050', 'Sales Returns and Allowances', 'Income', 'Debit', null],
        ['4060', 'Sales Discounts', 'Income', 'Debit', null],
        ['4070', 'Item Group Price Variance', 'Income', null, null],
        ['4110', 'Reimbursable Expense Income', 'Income', null, null],
        ['4100', 'Finance Charge Income', 'Other Income', null, null],
        ['4200', 'Interest Income', 'Other Income', null, null],
        ['4300', 'Gain (Loss) on Disposal of Assets', 'Other Income', null, null],
        ['5000', 'Cost of Goods Sold', 'Cost of Goods Sold', null, null],
        ['5050', 'Purchase Discounts', 'Cost of Goods Sold', 'Credit', null],
        ['5100', 'Inventory Adjustments and Shrinkage', 'Cost of Goods Sold', null, null],
        ['5200', 'Direct Labor Absorbed', 'Cost of Goods Sold', 'Credit', null],
        ['6000', 'Salaries and Wages', 'Expense', null, null],
        ['6010', 'Rent Expense', 'Expense', null, null],
        ['6020', 'Utilities Expense', 'Expense', null, null],
        ['6030', 'Repairs and Maintenance', 'Expense', null, null],
        ['6040', 'Office Supplies Expense', 'Expense', null, null],
        ['6050', 'Fuel and Oil', 'Expense', null, null],
        ['6060', 'Meals and Representation', 'Expense', null, null],
        ['6070', 'Professional Fees', 'Expense', null, null],
        ['6080', 'Bank and Merchant Charges', 'Expense', null, null],
        ['6090', 'Depreciation Expense', 'Expense', null, null],
        ['6100', 'Freight and Delivery', 'Expense', null, null],
        ['6110', 'Purchases - Non-inventory', 'Expense', null, null],
        ['6200', 'Cash Over and Short', 'Expense', null, null],
        ['6900', 'Miscellaneous Expense', 'Expense', null, null],
        ['7000', 'Interest Expense', 'Other Expense', null, null],
    ];
    $acct = [];
    foreach ($coa as [$code, $name, $type, $nb, $parent]) {
        [$cat, $normal] = $typeInfo[$type];
        $acct[$code] = DB::insert('accounts', [
            'code' => $code, 'name' => $name, 'account_type' => $type, 'category' => $cat,
            'normal_balance' => $nb ?? $normal, 'parent_id' => $parent ? $acct[$parent] : null,
            'is_system' => in_array($code, ['1050', '1100', '1200', '2000', '2100', '1300', '3200', '3900'], true) ? 1 : 0,
            'bank_account_no' => $code === '1010' ? '0012-3456-7890' : ($code === '1020' ? '1234-5678-90' : null),
        ]);
    }

    $defaults = [
        'ar' => '1100', 'undeposited_funds' => '1050', 'sales_income' => '4000', 'sales_returns' => '4050',
        'sales_discounts' => '4060', 'finance_charge_income' => '4100', 'reimbursable_income' => '4110', 'cwt' => '1310',
        'output_tax' => '2100', 'ap' => '2000', 'input_tax' => '1300', 'purchase_discounts' => '5050',
        'default_expense' => '6110', 'inventory_asset' => '1200', 'cogs' => '5000', 'inventory_adjustment' => '5100',
        'cash_on_hand' => '1001', 'cash_over_short' => '6200', 'card_clearing' => '1060', 'ewallet_clearing' => '1065',
        'merchant_fees' => '6080', 'interest_income' => '4200', 'retained_earnings' => '3200', 'opening_equity' => '3900',
        'gain_loss_disposal' => '4300', 'processing_variance' => '5100', 'processing_absorbed' => '5200',
        'cvat_withheld' => '1315', 'wht_payable' => '2110', 'vat_withheld_payable' => '2115', 'vendor_advances' => '1410',
        'group_price_variance' => '4070', 'shortage_receivable' => '1120',
    ];
    foreach (Accts::KEYS as $key => [$label, $module]) {
        DB::insert('default_accounts', ['setting_key' => $key, 'label' => $label, 'module' => $module, 'account_id' => $acct[$defaults[$key]]]);
    }
    Accts::reset();

    // ---------------------------------------------------------------- lists
    $terms = [];
    foreach ([['Due on receipt', 0, 0, 0], ['Net 15', 15, 0, 0], ['Net 30', 30, 0, 0], ['2% 10 Net 30', 30, 2, 10], ['Net 60', 60, 0, 0]] as [$n, $d, $p, $dd]) {
        $terms[$n] = DB::insert('terms', ['name' => $n, 'net_days' => $d, 'discount_pct' => $p, 'discount_days' => $dd]);
    }
    $tax = [];
    $tax['VAT12'] = DB::insert('tax_codes', ['code' => 'VAT12', 'name' => 'VAT 12%', 'rate' => 12, 'sales_account_id' => $acct['2100'], 'purchase_account_id' => $acct['1300']]);
    $tax['ZR'] = DB::insert('tax_codes', ['code' => 'ZR', 'name' => 'Zero-rated', 'rate' => 0, 'sales_account_id' => $acct['2100'], 'purchase_account_id' => $acct['1300']]);
    $tax['EX'] = DB::insert('tax_codes', ['code' => 'EX', 'name' => 'VAT-exempt', 'rate' => 0, 'sales_account_id' => $acct['2100'], 'purchase_account_id' => $acct['1300']]);
    $tax['NT'] = DB::insert('tax_codes', ['code' => 'NT', 'name' => 'Non-taxable', 'rate' => 0, 'sales_account_id' => $acct['2100'], 'purchase_account_id' => $acct['1300']]);

    // the Withholding Tax Table (BIR Reports): 1% goods and 2% services income tax, 5% VAT, on the amount net of VAT
    $wht = [];
    foreach ([
        ['WT-GOODS', 'WC158', 'WT on Goods', 'income', 1, 'Goods bought from regular suppliers by government payors and top withholding agents (RR 11-2018)', 10],
        ['WT-SERVICES', 'WC160', 'WT on Services', 'income', 2, 'Services bought from regular suppliers by government payors and top withholding agents (RR 11-2018)', 20],
        ['WT-VAT', 'WV010', 'WT on VAT', 'vat', 5, 'Creditable VAT withheld by government buyers on VATable purchases (5% of the VAT-exclusive payment)', 30],
    ] as [$code, $atc, $name, $kind, $rate, $desc, $sortNo]) {
        $wht[$code] = DB::insert('withholding_taxes', ['code' => $code, 'atc' => $atc, 'name' => $name, 'tax_kind' => $kind, 'rate' => $rate,
            'base_type' => 'net_of_vat', 'applies_to' => 'both', 'description' => $desc, 'sort_order' => $sortNo]);
    }
    Withholding::reset();

    $pm = [];
    // name, type, POS clearing account, offered as a payment option on the POS register
    foreach ([
        ['Cash', 'cash', null, 1], ['Check', 'check', null, 0], ['Credit/Debit Card', 'card', '1060', 1], ['GCash', 'ewallet', '1065', 1],
        ['Maya', 'ewallet', '1065', 1], ['Bank Transfer', 'bank_transfer', null, 0], ['Gift Voucher', 'voucher', '2120', 1],
        ['P.O. Card', 'card', '1070', 1], ['Bank', 'bank_transfer', '1010', 1],
    ] as [$n, $t, $a, $pos]) {
        $pm[$n] = DB::insert('payment_methods', ['name' => $n, 'method_type' => $t, 'clearing_account_id' => $a ? $acct[$a] : null, 'show_in_pos' => $pos]);
    }
    $pl = [];
    foreach ([['Wholesale', -5], ['Key Account', -8], ['Retail Plus', 5], ['Price Level 4', 0], ['Price Level 5', 0], ['Price Level 6', 0], ['Price Level 7', 0], ['Price Level 8', 0], ['Price Level 9', 0], ['Price Level 10', 0]] as [$n, $p]) {
        $pl[$n] = DB::insert('price_levels', ['name' => $n, 'adjust_pct' => $p]);
    }
    $ctype = [];
    foreach (['Supermarket', 'Restaurant', 'Market Retailer', 'Institution', 'Government', 'Employee'] as $n) {
        $ctype[$n] = DB::insert('customer_types', ['name' => $n]);
    }
    $bg = DB::insert('billing_groups', ['name' => 'Weekly Delivery Accounts']);

    // ---------------------------------------------------------------- units of measure
    // A set holds the base unit (stock and costs are kept in it) plus the larger or
    // smaller units a document may be entered in.
    // Distribution: chicken is received and sold in CRATES whose weight differs from crate to crate (flag V: the crate
    // unit holds no fixed number of kilos; every crate is weighed and followed in the Crate Center), in kilos, or in packs.
    $uomSets = [];
    foreach ([
        ['Kilos and crates', 'weight', 'kg', 'crate_kg', [['kg', 'Kilogram', 1, 'S'], ['CRT', 'Crate (weight varies)', 1, 'PV']]],
        ['Packs and crates', 'count', 'pack', 'crate_pack', [['pack', 'Pack', 1, 'S'], ['CRT', 'Crate (packs vary)', 1, 'PV'], ['box', 'Box of 20 packs', 20, '']]],
        ['Kilos', 'weight', 'kg', 'kg', [['kg', 'Kilogram', 1, 'SP'], ['g', 'Gram', 0.001, ''], ['sack', 'Sack of 25 kg', 25, '']]],
        ['Piece', 'count', 'pc', 'pc', [['pc', 'Piece', 1, 'S'], ['dz', 'Dozen (12 pieces)', 12, ''], ['bundle', 'Bundle of 100', 100, 'P']]],
        ['Volume (L)', 'volume', 'L', 'L', [['L', 'Liter', 1, 'SP'], ['mL', 'Milliliter', 0.001, ''], ['gal', 'Gallon (3.785 L)', 3.785, '']]],
        ['Time (hour)', 'time', 'hr', 'hr', [['hr', 'Hour', 1, 'SP'], ['day', 'Day (8 hours)', 8, ''], ['wk', 'Week (40 hours)', 40, '']]],
    ] as [$sName, $kind, $baseUnit, $key, $units]) {
        $sid = DB::insert('uom_sets', ['name' => $sName, 'uom_kind' => $kind, 'base_unit' => $baseUnit, 'is_active' => 1]);
        $uomSets[$key] = $sid;
        $sort = 0;
        foreach ($units as [$code, $uName, $factor, $flags]) {
            DB::insert('uom_units', ['set_id' => $sid, 'code' => $code, 'name' => $uName, 'factor' => $factor,
                'is_base' => $code === $baseUnit ? 1 : 0, 'is_sales_default' => str_contains($flags, 'S') ? 1 : 0,
                'is_purchase_default' => str_contains($flags, 'P') ? 1 : 0, 'sort_order' => $sort++, 'is_variable' => str_contains($flags, 'V') ? 1 : 0]);
        }
    }

    $cat = [];
    foreach (['Whole Chicken', 'Chicken Cuts', 'Offal and By-products', 'Processed Chicken', 'Bundles', 'Packaging', 'Services', 'Charges'] as $n) {
        $cat[$n] = DB::insert('item_categories', ['name' => $n]);
    }

    // ---------------------------------------------------------------- sites & terminals
    $site = [];
    foreach ([['NGA', 'Naga Cold Storage', 'warehouse'], ['NOT', 'Naga Outlet', 'store'], ['LGZ', 'Legazpi Depot', 'store'], ['RFT1', 'Reefer Truck 1', 'van'], ['DMG', 'Spoilage and Damaged', 'damaged'],
              ['VAN1', 'Van Store 1 (LAB 4417)', 'van'], ['VAN2', 'Van Store 2 (LAB 4428)', 'van']] as [$c, $n, $t]) {
        $site[$c] = DB::insert('sites', ['code' => $c, 'name' => $n, 'site_type' => $t]);
    }
    $term = [];
    $term['POS-01'] = DB::insert('pos_terminals', ['code' => 'POS-01', 'name' => 'Naga Outlet Counter 1', 'site_id' => $site['NOT'], 'cash_account_id' => $acct['1001'], 'receipt_prefix' => 'NO1-']);
    $term['POS-02'] = DB::insert('pos_terminals', ['code' => 'POS-02', 'name' => 'Legazpi Depot Counter', 'site_id' => $site['LGZ'], 'cash_account_id' => $acct['1001'], 'receipt_prefix' => 'LG1-']);

    // ---------------------------------------------------------------- roles
    $pageDefs = [];
    foreach ($reg['pages'] as $k => $d) {
        $pageDefs[$k] = ['module' => $d[0], 'type' => $d[2], 'group' => $d[3]];
    }
    $adminSetup = ['admin.users', 'admin.roles', 'admin.page_access', 'admin.effective_access', 'admin.settings',
        'admin.utilities', 'admin.import', 'admin.backup', 'admin.multi_company',
        'company.profile', 'company.users', 'company.join_requests', 'comm.manage'];
    $select = function (string $pattern) use ($pageDefs): array {
        // "module:*", "module:report", "module:!report", "group:Sales Reports", exact key
        if (isset($pageDefs[$pattern])) {
            return [$pattern];
        }
        [$a, $b] = explode(':', $pattern, 2) + [1 => '*'];
        $out = [];
        foreach ($pageDefs as $k => $d) {
            if ($a === 'group') {
                if ($d['group'] === $b) {
                    $out[] = $k;
                }
                continue;
            }
            if ($d['module'] !== $a) {
                continue;
            }
            if ($b === '*' || ($b === 'report' && $d['type'] === 'report') || ($b === '!report' && $d['type'] !== 'report')) {
                $out[] = $k;
            }
        }
        return $out;
    };

    $roleDefs = [
        'Administrator' => [
            'desc' => 'Everything in every module, including user accounts, roles, page access, the closing date, and the audit trail.',
            'admin' => 1, 'pages' => [], 'special' => [],
        ],
        'Accountant' => [
            'desc' => 'Chart of Accounts, Fixed Assets, Banking and reconciliation, the BIR Reports and Withholding Tax Table, all module reports, and the financial statements.',
            'pages' => [
                'home:*' => 'P', 'coa:*' => 'CEDP', 'fa:*' => 'CEDP', 'bank:*' => 'CEDP',
                'cust:report' => 'P', 'vend:report' => 'P', 'inv:report' => 'P', 'pos:report' => 'P',
                'cust.center' => 'P', 'cust.payments' => 'P', 'cust.invoices' => 'P', 'vend.center' => 'P',
                'vend.bill_tracker' => 'P', 'vend.bills' => 'P', 'vend.pay_bills' => 'P', 'vend.advances' => 'P', 'bir:*' => 'CEDP',
                'inv.center' => 'P', 'inv.items' => 'P', 'inv.categories' => 'P', 'inv.adjust' => 'P', 'inv.process' => 'P', 'inv.formulas' => 'P', 'inv.uom' => 'P',
                'inv.transfer_closing' => 'P', 'inv.shortages' => 'P', 'inv.lot_check' => 'P', 'admin.utilities' => 'P',
            ],
            'special' => ['view_costs' => '1', 'view_bank_balances' => '1', 'coa_changes' => '1', 'max_amount' => '', 'max_discount_pct' => '0', 'max_price_override_pct' => '0', 'credit_limit_override' => '0', 'closed_period_changes' => '0', 'design_reports' => '1'],
        ],
        'A/R Clerk' => [
            'desc' => 'Customers module transactions and the Customer and Receivables reports.',
            'pages' => ['home:*' => 'P', 'cust:!report' => 'CEP', 'group:Customer and Receivables Reports' => 'P', 'inv.items' => '',
                'inv.shortages' => 'P', 'rpt.shortage_rep' => 'P', 'rpt.shortage_detail' => 'P'],
            'special' => ['view_costs' => '0', 'view_bank_balances' => '0', 'max_discount_pct' => '10', 'max_price_override_pct' => '5', 'max_amount' => '50000', 'credit_limit_override' => '0'],
        ],
        'A/P Clerk' => [
            'desc' => 'Vendors module transactions, Pay Bills, advances to suppliers, the Vendors and Payables reports, and BIR Form 2307 for suppliers.',
            'pages' => ['home:*' => 'P', 'vend:!report' => 'CEP', 'vend.center' => 'P', 'vend:report' => 'P', 'inv.items' => '',
                'bir.form_2307' => 'P', 'bir.wht_table' => '', 'rpt.bir_wht_summary' => 'P', 'rpt.bir_ewt_register' => 'P', 'rpt.bir_vat_withholding' => 'P', 'rpt.bir_remittance' => 'P'],
            'special' => ['view_costs' => '1', 'view_bank_balances' => '0', 'max_amount' => '100000'],
        ],
        'Inventory Clerk' => [
            'desc' => 'Items, sites, receiving, adjustments, assembly builds, disassembly and processing orders, stock counts, and inventory quantity reports.',
            'pages' => [
                'home:*' => 'P', 'inv.center' => 'P', 'inv.items' => 'CEP', 'inv.categories' => 'CEDP', 'inv.sites' => 'CEP', 'inv.transfers' => 'CEP',
                'inv.adjust' => 'CEP', 'inv.build' => 'CEP', 'inv.physical_count' => 'P', 'inv.lot_check' => 'CP',
                'inv.process' => 'CEP', 'inv.formulas' => 'CEP', 'inv.uom' => 'CEP', 'rpt.processing_register' => 'P', 'rpt.process_yield' => 'P',
                'vend.receive_items' => 'CEP', 'vend.purchase_orders' => 'P', 'vend.pickup' => 'CEP', 'vend.allocations' => 'P', 'vend.supplier_items' => 'P',
                'inv.crates' => 'P', 'inv.crate_convert' => 'CP', 'inv.crate_pack' => 'CP', 'inv.crate_move' => 'CP', 'group:Crate Reports' => 'P', 'rpt.alloc_pickup' => 'P',
                'inv.dispatch' => 'CEP',
                'inv.transfer_closing' => 'CP', 'inv.shortages' => 'P', 'group:Shortage and Shrinkage Reports' => 'P', 'group:Transfer Reports' => 'P',
                'rpt.qoh_by_site' => 'P', 'rpt.stock_status_item' => 'P', 'rpt.stock_status_vendor' => 'P', 'rpt.stock_status_site' => 'P',
                'rpt.physical_worksheet' => 'P', 'rpt.pending_builds' => 'P', 'rpt.pending_builds_site' => 'P', 'rpt.negative_inventory' => 'P', 'rpt.inv_no_movement' => 'P',
                'rpt.inv_movement_summary' => 'P', 'rpt.inv_movement_detail' => 'P', 'rpt.inv_movement_txns' => 'P',
            ],
            'special' => ['view_costs' => '0', 'max_amount' => '20000'],
        ],
        'Sales Representative' => [
            'desc' => 'Estimates, sales orders, and invoices, and the Sales reports.',
            'pages' => [
                'home:*' => 'P', 'cust.center' => 'P', 'cust.estimates' => 'CEP', 'cust.sales_orders' => 'CEP', 'cust.invoices' => 'CEP',
                'group:Sales Reports' => 'P', 'rpt.item_price_list' => 'P', 'rpt.inv_movement_txns' => 'P', 'inv.crates' => 'P', 'rpt.crates_on_hand' => 'P', 'rpt.crate_detail' => 'P',
            ],
            'special' => ['view_costs' => '0', 'max_discount_pct' => '5', 'max_price_override_pct' => '0'],
        ],
        'Cashier' => [
            'desc' => 'POS sales, returns, and cash drops at the assigned terminal only.',
            'pages' => ['home.dashboard' => '', 'pos.register' => 'CP', 'pos.shifts' => 'CP', 'pos.receipts' => 'CDP', 'rpt.pos_ending_inventory' => 'P'],
            'special' => ['view_costs' => '0', 'max_discount_pct' => '5', 'max_price_override_pct' => '0', 'max_amount' => '0'],
            'sites' => ['NOT', 'LGZ'],
        ],
        'POS Supervisor' => [
            'desc' => 'Everything a cashier can do, plus approving voids, refunds, price overrides, and large discounts, and running X- and Z-readings.',
            'pages' => ['home.dashboard' => '', 'home.reports' => '', 'pos.register' => 'CEDPA', 'pos.shifts' => 'CEDPA', 'pos.receipts' => 'CEDPA', 'pos.approval_codes' => 'CEDPA', 'pos.terminals' => 'P', 'pos:report' => 'P'],
            'special' => ['view_costs' => '0', 'max_discount_pct' => '30', 'max_price_override_pct' => '20', 'max_amount' => '20000'],
        ],
        'Allocation Officer' => [
            'desc' => 'Supplier Allocation, the Supplier Items of each supplier, Pick-Up Supplier Items, the Crate Center and the crate and allocation reports.',
            'pages' => [
                'home.dashboard' => '', 'home.reports' => '', 'vend.center' => 'P', 'vend.allocations' => 'CEDP', 'vend.supplier_items' => 'CEP', 'vend.pickup' => 'CEP',
                'vend.receive_items' => 'P', 'inv.center' => 'P', 'inv.crates' => 'P', 'group:Crate Reports' => 'P', 'rpt.alloc_pickup' => 'P', 'rpt.qoh_by_site' => 'P',
            ],
            'special' => ['view_costs' => '0', 'max_amount' => '0'],
        ],
        'Pick-Up Crew' => [
            'desc' => 'The pick-ups assigned to them: weighing and dating the crates at the supplier and marking the pick-up complete.',
            'pages' => ['home.dashboard' => '', 'vend.pickup' => 'CE', 'inv.crates' => 'P'],
            'special' => ['view_costs' => '0', 'max_amount' => '0'],
        ],
        'Auditor' => [
            'desc' => 'View-only access to all transactions, reports, and the audit trail. Cannot create or change anything.',
            'pages' => ['*' => 'P'],
            'deny' => array_merge($adminSetup, ['pos.register', 'pos.shifts']),
            'special' => ['view_costs' => '1', 'view_bank_balances' => '1'],
        ],
    ];

    $roleIds = [];
    foreach ($roleDefs as $name => $def) {
        $rid = DB::insert('roles', [
            'name' => $name, 'description' => $def['desc'], 'is_admin' => $def['admin'] ?? 0, 'is_system' => 1,
            'all_sites' => isset($def['sites']) ? 0 : 1,
        ]);
        $roleIds[$name] = $rid;
        $grant = [];
        foreach ($def['pages'] as $pattern => $letters) {
            $keys = $pattern === '*' ? array_keys($pageDefs) : $select($pattern);
            foreach ($keys as $k) {
                $grant[$k] = ($grant[$k] ?? '') . $letters;
            }
        }
        foreach ($def['deny'] ?? [] as $k) {
            unset($grant[$k]);
        }
        // v41: every role reads the community; a role that may create anything may post (and edit and delete its own)
        $poster = (bool)array_filter($grant, fn($l) => str_contains($l, 'C'));
        foreach (['comm.chat', 'comm.inquiries'] as $k) {
            $grant[$k] = ($grant[$k] ?? '') . ($poster ? 'CED' : '');
        }
        foreach ($grant as $k => $letters) {
            DB::insert('role_page_access', [
                'role_id' => $rid, 'page_id' => $pageIds[$k], 'allowed' => 1,
                'can_create' => (int)str_contains($letters, 'C'), 'can_edit' => (int)str_contains($letters, 'E'),
                'can_delete' => (int)str_contains($letters, 'D'), 'can_print' => (int)str_contains($letters, 'P'),
                'can_approve' => (int)str_contains($letters, 'A'),
            ]);
        }
        foreach ($def['special'] as $k => $v) {
            DB::insert('role_special_permissions', ['role_id' => $rid, 'perm_key' => $k, 'perm_value' => $v]);
        }
        foreach ($def['sites'] ?? [] as $s) {
            DB::insert('role_sites', ['role_id' => $rid, 'site_id' => $site[$s]]);
        }
    }

    // ---------------------------------------------------------------- users
    $users = [
        ['admin', 'System Administrator', 'Administrator', 'Admin@12345', 1, null, null],
        ['accountant', 'Ana Cruz', 'Accountant', 'Demo@12345', 0, null, null],
        ['arclerk', 'Ben Garcia', 'A/R Clerk', 'Demo@12345', 0, null, null],
        ['apclerk', 'Carla Lim', 'A/P Clerk', 'Demo@12345', 0, null, null],
        ['invclerk', 'Dan Villanueva', 'Inventory Clerk', 'Demo@12345', 0, null, null],
        ['allocator', 'Lito Bautista', 'Allocation Officer', 'Demo@12345', 0, null, null],
        ['salesrep', 'Maria Santos', 'Sales Representative', 'Demo@12345', 0, null, null],
        ['supervisor', 'Fred Tan', 'POS Supervisor', 'Demo@12345', 0, 'NOT', 'POS-01'],
        ['cashier1', 'Ella Ramos', 'Cashier', 'Demo@12345', 0, 'NOT', 'POS-01'],
        ['glenn', 'Glenn Abad', 'Pick-Up Crew', 'Demo@12345', 0, null, null],
        ['auditor', 'Grace Uy', 'Auditor', 'Demo@12345', 0, null, null],
    ];
    $userIds = [];
    $n = 0;
    foreach ($users as [$u, $full, $role, $pw, $must, $s, $t]) {
        $uid = DB::insert('users', [
            'username' => $u, 'password_hash' => password_hash($pw, PASSWORD_DEFAULT), 'full_name' => $full,
            'email' => $u . '@northpoint.test', 'employee_no' => sprintf('EMP-%03d', ++$n), 'status' => 'active',
            'must_change_password' => $must, 'password_changed_at' => date('Y-m-d H:i:s'),
        ]);
        $userIds[$u] = $uid;
        DB::insert('user_roles', ['user_id' => $uid, 'role_id' => $roleIds[$role]]);
        if ($s) {
            DB::insert('user_sites', ['user_id' => $uid, 'site_id' => $site[$s]]);
        }
        if ($t) {
            DB::insert('user_terminals', ['user_id' => $uid, 'terminal_id' => $term[$t]]);
        }
    }

    // ---------------------------------------------------------------- sales reps
    $rep = [];
    $rep['MS'] = DB::insert('sales_reps', ['name' => 'Maria Santos', 'initials' => 'MS', 'user_id' => $userIds['salesrep'], 'commission_pct' => 1.5]);
    $rep['JR'] = DB::insert('sales_reps', ['name' => 'Jose Reyes', 'initials' => 'JR', 'commission_pct' => 2.5]);
    // v2 distribution: the van salesmen answerable for the van stores, and the cashier of the outlet; each is also a customer
    // of type Employee (shortages are charged to them and collected with Receive Payments)
    if (SalesReps::ready()) {
        $rep['RM'] = DB::insert('sales_reps', ['name' => 'Rico Mendoza', 'initials' => 'RM', 'commission_pct' => 1, 'rep_type' => 'van']);
        $rep['AC'] = DB::insert('sales_reps', ['name' => 'Arnel Cruz', 'initials' => 'AC', 'commission_pct' => 1, 'rep_type' => 'van']);
        $rep['ER'] = DB::insert('sales_reps', ['name' => 'Ella Ramos', 'initials' => 'ER', 'user_id' => $userIds['cashier1'], 'commission_pct' => 0, 'rep_type' => 'cashier']);
        DB::update('sites', ['sales_rep_id' => $rep['RM']], 'id = :id', ['id' => $site['VAN1']]);
        DB::update('sites', ['sales_rep_id' => $rep['AC']], 'id = :id', ['id' => $site['VAN2']]);
        DB::update('sites', ['sales_rep_id' => $rep['ER']], 'id = :id', ['id' => $site['NOT']]);
        SalesReps::ensureAll();
    }

    // ---------------------------------------------------------------- vendors (sample names; a company enters its own)
    $vend = [];
    foreach ([
        ['Northfield Poultry Corp.', 'Ramon Velasco', '(054) 472-1180', 'orders@northfieldpoultry.test', 'Pili, Camarines Sur', 'Net 15', null, 'NPC-20418'],
        ['Golden Plume Farms Inc.', 'Teresa Lagman', '(054) 811-0932', 'sales@goldenplume.test', 'Ocampo, Camarines Sur', 'Net 30', null, 'GPF-7751'],
        ['Bicol Packaging Supply', 'Liza Go', '(054) 473-2255', 'orders@bicolpack.test', 'Naga City', 'Net 15', '6040', 'BPS-4410'],
        ['Camarines Power Cooperative', 'Customer Service', '(054) 473-0001', 'billing@campower.test', 'Naga City', 'Due on receipt', '6020', '1234-5678-9012'],
        ['Metro Property Leasing', 'Tony Chua', '(054) 473-0303', 'leasing@metroprop.test', 'Naga City', 'Due on receipt', '6010', 'L-2291'],
        ['Diversion Road Fuel Station', null, '(054) 473-0404', null, 'Naga City', 'Due on receipt', '6050', null],
        ['Coolwave Refrigeration Services', 'Operations', '(054) 473-0505', 'service@coolwave.test', 'Naga City', 'Net 15', '6030', 'CRS-7781'],
        ['Accounting Partners & Co.', 'Atty. Reyes', '(054) 473-0606', 'hello@apco.test', 'Naga City', 'Net 30', '6070', null],
        ['Bicol Truck and Reefer Corp.', 'Sales', '(054) 473-0707', 'sales@bicoltruck.test', 'Legazpi City', 'Net 30', null, 'BTR-100'],
    ] as [$name, $contact, $phone, $email, $addr, $t, $exp, $acctNo]) {
        $vend[$name] = DB::insert('vendors', [
            'name' => $name, 'company_name' => $name, 'contact_person' => $contact, 'phone' => $phone, 'email' => $email,
            'address' => $addr, 'tin' => sprintf('%03d-%03d-%03d-000', random_int(100, 999), random_int(100, 999), random_int(100, 999)),
            'terms_id' => $terms[$t], 'default_expense_account_id' => $exp ? $acct[$exp] : null, 'tax_code_id' => $tax['VAT12'],
            'account_no' => $acctNo,
            // the taxes withheld when the supplier is paid: 1% on goods suppliers, 2% on service providers
            'wht_ids' => ['Northfield Poultry Corp.' => $wht['WT-GOODS'], 'Golden Plume Farms Inc.' => $wht['WT-GOODS'], 'Bicol Truck and Reefer Corp.' => $wht['WT-GOODS'],
                'Accounting Partners & Co.' => $wht['WT-SERVICES'], 'Coolwave Refrigeration Services' => $wht['WT-SERVICES']][$name] ?? null,
        ]);
    }

    // ---------------------------------------------------------------- items
    $item = [];
    $mk = function (array $d) use (&$item, $acct, $tax, $cat, $vend) {
        $row = array_merge([
            'income_account_id' => $acct['4000'], 'cogs_account_id' => $acct['5000'], 'asset_account_id' => null,
            'expense_account_id' => null, 'tax_code_id' => $tax['VAT12'], 'unit' => 'pc',
        ], $d);
        if (isset($row['cat'])) {
            $row['category_id'] = $cat[$row['cat']];
            unset($row['cat']);
        }
        if (isset($row['vendor'])) {
            $row['preferred_vendor_id'] = $vend[$row['vendor']];
            unset($row['vendor']);
        }
        if (in_array($row['item_type'], ['inventory', 'assembly'], true)) {
            $row['asset_account_id'] ??= $acct['1200'];
            $row['avg_cost'] = 0;
        }
        $item[$row['code']] = DB::insert('items', $row);
    };
    // chicken received and sold in crates (weight varies) or by the kilo: code, name, cost / kg, price / kg, reorder kg, max kg, barcode, category, supplier
    foreach ([
        ['WCK-FC', 'Whole Chicken, Fresh Chilled, Bag', 142, 175, 300, 1500, '4809001000011', 'Whole Chicken', 'Northfield Poultry Corp.'],
        ['BBD-FC', 'Big Bird Chicken, Fresh Chilled, Vac', 150, 185, 200, 1000, '4809001000028', 'Whole Chicken', 'Northfield Poultry Corp.'],
        ['ACU-FZ', 'Chicken Assorted Cut-Ups, Frozen, Bag', 135, 168, 200, 1000, '4809001000035', 'Chicken Cuts', 'Northfield Poultry Corp.'],
        ['BRS-FZ', 'Chicken Breast, Frozen, Bag', 185, 228, 150, 800, '4809001000042', 'Chicken Cuts', 'Northfield Poultry Corp.'],
        ['DRM-FZ', 'Chicken Drumstick, Frozen, Bag', 175, 215, 150, 800, '4809001000059', 'Chicken Cuts', 'Golden Plume Farms Inc.'],
        ['WNG-FZ', 'Chicken Wings, Frozen, Bag', 190, 235, 100, 600, '4809001000066', 'Chicken Cuts', 'Golden Plume Farms Inc.'],
        ['LVR-FZ', 'Chicken Liver, Frozen, Bag', 95, 130, 50, 300, '4809001000073', 'Offal and By-products', 'Northfield Poultry Corp.'],
        ['GIZ-FZ', 'Chicken Gizzard, Frozen, Bag', 110, 145, 50, 300, '4809001000080', 'Offal and By-products', 'Golden Plume Farms Inc.'],
    ] as [$code, $name, $cost, $price, $reorder, $max, $barcode, $c, $v]) {
        $mk(['item_type' => 'inventory', 'code' => $code, 'barcode' => $barcode, 'name' => $name, 'description' => $name,
            'purchase_description' => $name, 'cost' => $cost, 'sales_price' => $price, 'reorder_point' => $reorder,
            'max_stock' => $max, 'cat' => $c, 'vendor' => $v, 'unit' => 'kg', 'uom_set_id' => $uomSets['crate_kg']]);
    }
    // by the kilo only
    $mk(['item_type' => 'inventory', 'code' => 'BLD', 'barcode' => '4809001000097', 'name' => 'Chicken Blood', 'description' => 'Chicken blood, chilled',
        'purchase_description' => 'Chicken blood', 'cost' => 25, 'sales_price' => 40, 'reorder_point' => 20, 'max_stock' => 150, 'cat' => 'Offal and By-products',
        'vendor' => 'Northfield Poultry Corp.', 'unit' => 'kg', 'uom_set_id' => $uomSets['kg'], 'tax_code_id' => $tax['EX']]);
    // packs, received in crates of a varying number of packs
    foreach ([
        ['BLB-250', 'Chicken Bola-Bola 250 g, Frozen, Pack', 48, 65, 200, 1200, '4809001000103'],
        ['NGT-500', 'Chicken Nuggets 500 g, Frozen, Pack', 95, 128, 120, 800, '4809001000110'],
    ] as [$code, $name, $cost, $price, $reorder, $max, $barcode]) {
        $mk(['item_type' => 'inventory', 'code' => $code, 'barcode' => $barcode, 'name' => $name, 'description' => $name,
            'purchase_description' => $name, 'cost' => $cost, 'sales_price' => $price, 'reorder_point' => $reorder,
            'max_stock' => $max, 'cat' => 'Processed Chicken', 'vendor' => 'Golden Plume Farms Inc.', 'unit' => 'pack', 'uom_set_id' => $uomSets['crate_pack']]);
    }
    $mk(['item_type' => 'inventory', 'code' => 'PKG-BAG', 'barcode' => '4809001000127', 'name' => 'Vacuum Bag 2 kg', 'description' => 'Vacuum bag, 2 kg',
        'purchase_description' => 'Vacuum bag 2 kg', 'cost' => 3.5, 'sales_price' => 0, 'reorder_point' => 500, 'max_stock' => 5000, 'cat' => 'Packaging',
        'vendor' => 'Bicol Packaging Supply', 'unit' => 'pc', 'uom_set_id' => $uomSets['pc']]);
    $mk(['item_type' => 'service', 'code' => 'LAB-CUT', 'name' => 'Cutting and Packing Labor', 'description' => 'Cutting and packing labor', 'cost' => 25, 'sales_price' => 0,
        'income_account_id' => $acct['4010'], 'expense_account_id' => $acct['5200'], 'cogs_account_id' => $acct['5200'], 'tax_code_id' => $tax['NT'], 'unit' => 'hr',
        'uom_set_id' => $uomSets['hr'], 'cat' => 'Services']);
    $mk(['item_type' => 'assembly', 'code' => 'PARTY-PK', 'barcode' => '4809001000134', 'name' => 'Party Pack (2 kg wings, 1 kg drumsticks)', 'description' => 'Party pack: 2 kg wings and 1 kg drumsticks, vacuum packed',
        'cost' => 0, 'sales_price' => 720, 'build_point' => 5, 'reorder_point' => 5, 'max_stock' => 40, 'cat' => 'Bundles', 'unit' => 'pc', 'uom_set_id' => $uomSets['pc']]);
    foreach ([['WNG-FZ', 2], ['DRM-FZ', 1], ['PKG-BAG', 2], ['LAB-CUT', 0.25]] as [$c, $q]) {
        DB::insert('item_components', ['parent_item_id' => $item['PARTY-PK'], 'component_item_id' => $item[$c], 'qty' => $q]);
    }
    $mk(['item_type' => 'service', 'code' => 'SRV-CUT', 'name' => 'Custom Cutting Service', 'description' => 'Custom cutting per customer specification', 'sales_price' => 15,
        'income_account_id' => $acct['4010'], 'unit' => 'kg', 'uom_set_id' => $uomSets['kg'], 'cat' => 'Services']);
    $mk(['item_type' => 'non_inventory', 'code' => 'NI-ICE', 'name' => 'Ice Block (special order)', 'description' => 'Ice block, special order for long trips',
        'cost' => 60, 'sales_price' => 90, 'expense_account_id' => $acct['5000'], 'cat' => 'Packaging', 'vendor' => 'Bicol Packaging Supply', 'unit' => 'pc', 'uom_set_id' => $uomSets['pc']]);
    $mk(['item_type' => 'other_charge', 'code' => 'DEL-FEE', 'name' => 'Delivery Fee (reefer)', 'description' => 'Delivery fee, refrigerated truck', 'sales_price' => 350,
        'income_account_id' => $acct['4020'], 'expense_account_id' => $acct['6100'], 'cat' => 'Charges']);
    $mk(['item_type' => 'other_charge', 'code' => 'CRATE-DEP', 'name' => 'Crate Deposit', 'description' => 'Deposit on crates not yet returned', 'sales_price' => 250,
        'income_account_id' => $acct['2130'], 'expense_account_id' => $acct['6900'], 'tax_code_id' => $tax['NT'], 'cat' => 'Charges']);
    $mk(['item_type' => 'other_charge', 'code' => 'LATE-FEE', 'name' => 'Late Payment Fee', 'description' => 'Late payment fee', 'sales_price' => 200,
        'income_account_id' => $acct['4100'], 'tax_code_id' => $tax['NT'], 'cat' => 'Charges']);
    $mk(['item_type' => 'discount', 'code' => 'DISC-5', 'name' => '5% Volume Discount', 'description' => '5% volume discount', 'discount_pct' => 5,
        'income_account_id' => $acct['4060'], 'cat' => 'Charges']);
    $mk(['item_type' => 'discount', 'code' => 'DISC-AMT', 'name' => 'Fixed Discount', 'description' => 'Discount', 'sales_price' => 100,
        'income_account_id' => $acct['4060'], 'cat' => 'Charges']);
    $mk(['item_type' => 'subtotal', 'code' => 'SUBTOTAL', 'name' => 'Subtotal', 'description' => 'Subtotal', 'tax_code_id' => null]);
    $mk(['item_type' => 'group', 'code' => 'GRP-FIESTA', 'name' => 'Fiesta Bundle', 'description' => '4 packs bola-bola and 2 packs nuggets', 'tax_code_id' => null, 'cat' => 'Bundles', 'sales_price' => 480]);
    foreach ([['BLB-250', 4], ['NGT-500', 2]] as [$c, $q]) {
        DB::insert('item_components', ['parent_item_id' => $item['GRP-FIESTA'], 'component_item_id' => $item[$c], 'qty' => $q]);
    }
    $mk(['item_type' => 'payment', 'code' => 'DOWNPMT', 'name' => 'Down Payment Received', 'description' => 'Less: down payment received', 'tax_code_id' => null]);
    DB::insert('price_level_items', ['price_level_id' => $pl['Key Account'], 'item_id' => $item['WCK-FC'], 'custom_price' => 165]);
    DB::insert('price_level_items', ['price_level_id' => $pl['Key Account'], 'item_id' => $item['BRS-FZ'], 'custom_price' => 215]);

    // the items each supplier delivers, in the unit they are allocated in (Vendors > Supplier Items)
    $crateUnit = fn(string $key) => (int)DB::value("SELECT id FROM uom_units WHERE set_id = :s AND is_variable = 1", ['s' => $uomSets[$key]]);
    $kgUnit = (int)DB::value("SELECT id FROM uom_units WHERE set_id = :s AND is_base = 1", ['s' => $uomSets['kg']]);
    $n = 0;
    foreach ([
        ['Northfield Poultry Corp.', [['WCK-FC', 'crate_kg', 142], ['BBD-FC', 'crate_kg', 150], ['ACU-FZ', 'crate_kg', 135], ['BRS-FZ', 'crate_kg', 185], ['LVR-FZ', 'crate_kg', 95], ['BLD', 'kg', 25]]],
        ['Golden Plume Farms Inc.', [['WCK-FC', 'crate_kg', 140], ['DRM-FZ', 'crate_kg', 175], ['WNG-FZ', 'crate_kg', 190], ['GIZ-FZ', 'crate_kg', 110], ['BLB-250', 'crate_pack', 48], ['NGT-500', 'crate_pack', 95]]],
    ] as [$vName, $list]) {
        $n = 0;
        foreach ($list as [$code, $set, $cost]) {
            DB::insert('vendor_items', ['vendor_id' => $vend[$vName], 'item_id' => $item[$code], 'uom_id' => $set === 'kg' ? $kgUnit : $crateUnit($set),
                'last_cost' => $cost, 'sort_order' => ++$n, 'is_active' => 1]);
        }
    }

    $mkFormula = function (string $code, string $name, string $type, string $method, string $desc, array $lines) use ($item, $acct) {
        $fid = DB::insert('process_formulas', ['code' => $code, 'name' => $name, 'process_type' => $type, 'alloc_method' => $method, 'description' => $desc]);
        $n = 0;
        foreach ($lines as $l) {
            [$kind, $ref, $qty] = $l;
            DB::insert('process_formula_lines', [
                'formula_id' => $fid, 'line_no' => ++$n, 'line_type' => $kind,
                'item_id' => $kind === 'cost' ? null : $item[$ref], 'account_id' => $kind === 'cost' ? $acct[$ref] : null,
                'qty' => $kind === 'cost' ? 0 : $qty, 'amount' => $kind === 'cost' ? $qty : 0,
                'output_role' => $kind === 'output' ? ($l[3] ?? 'co_product') : null, 'alloc_basis' => $l[4] ?? 0,
                'description' => $l[5] ?? null,
            ]);
        }
    };
    $mkFormula('CUT-WCK', 'Cut up whole chicken (10 kg)', 'disassembly', 'sales_value', 'Whole chickens cut into breasts, drumsticks, wings and assorted cut-ups; liver and gizzard bagged on their own.', [
        ['input', 'WCK-FC', 10],
        ['cost', '5200', 120, null, 0, 'Cutting and packing labor'],
        ['output', 'BRS-FZ', 2.6, 'co_product'],
        ['output', 'DRM-FZ', 2.2, 'co_product'],
        ['output', 'WNG-FZ', 1.1, 'co_product'],
        ['output', 'ACU-FZ', 3.0, 'co_product'],
        ['output', 'LVR-FZ', 0.4, 'by_product', 95],
        ['output', 'GIZ-FZ', 0.4, 'by_product', 110],
    ]);

    // ---------------------------------------------------------------- customers (sample names)
    $cust = [];
    $mkc = function (array $d) use (&$cust, $terms, $tax, $rep, $pl, $ctype, $pm) {
        $row = array_merge(['tax_code_id' => $tax['VAT12']], $d);
        foreach (['terms' => 'terms_id', 'rep' => 'sales_rep_id', 'pl' => 'price_level_id', 'type' => 'customer_type_id', 'pm' => 'payment_method_id'] as $k => $col) {
            if (isset($row[$k])) {
                $map = ['terms' => $terms, 'rep' => $rep, 'pl' => $pl, 'type' => $ctype, 'pm' => $pm][$k];
                $row[$col] = $map[$row[$k]];
                unset($row[$k]);
            }
        }
        $cust[$row['name']] = DB::insert('customers', $row);
    };
    $mkc(['name' => 'Sunrise Supermart', 'company_name' => 'Sunrise Supermart Inc.', 'contact_person' => 'Mr. Albert Co', 'phone' => '(054) 881-1001', 'email' => 'ap@sunrisesupermart.test',
        'billing_address' => 'Magsaysay Avenue, Naga City', 'shipping_address' => 'Magsaysay Avenue, Naga City', 'tin' => '111-222-333-000',
        'terms' => 'Net 30', 'credit_limit' => 400000, 'rep' => 'MS', 'type' => 'Supermarket', 'pl' => 'Key Account', 'pm' => 'Check', 'allow_pos_charge' => 1]);
    $mkc(['parent_id' => $cust['Sunrise Supermart'], 'name' => 'Sunrise Supermart Pili Branch', 'billing_address' => 'Maharlika Highway, Pili, Camarines Sur',
        'shipping_address' => 'Maharlika Highway, Pili, Camarines Sur', 'terms' => 'Net 30', 'rep' => 'MS', 'type' => 'Supermarket', 'pl' => 'Key Account']);
    $mkc(['name' => 'Kusina ni Lola Restaurant', 'company_name' => 'Kusina ni Lola Food House', 'contact_person' => 'Ms. Bea Lim', 'phone' => '(054) 881-2002', 'email' => 'purchasing@kusinanilola.test',
        'billing_address' => 'Elias Angeles St., Naga City', 'terms' => 'Net 15', 'credit_limit' => 120000, 'pl' => 'Wholesale', 'rep' => 'JR', 'type' => 'Restaurant']);
    $mkc(['name' => 'Legazpi Grill House', 'company_name' => 'Legazpi Grill House Co.', 'contact_person' => 'Mr. Carlo Sy', 'phone' => '(052) 480-3003', 'email' => 'finance@legazpigrill.test',
        'billing_address' => 'Rizal St., Legazpi City', 'terms' => '2% 10 Net 30', 'credit_limit' => 150000, 'pl' => 'Wholesale', 'rep' => 'JR', 'type' => 'Restaurant']);
    $mkc(['name' => 'St. Raphael Hospital Kitchen', 'company_name' => 'St. Raphael Hospital', 'contact_person' => 'Dr. Dina Reyes', 'phone' => '(054) 881-4004', 'email' => 'dietary@straphael.test',
        'billing_address' => 'Panganiban Drive, Naga City', 'terms' => 'Net 15', 'credit_limit' => 80000, 'rep' => 'MS', 'type' => 'Institution', 'billing_group_id' => $bg]);
    $mkc(['name' => 'Aling Tess Market Stall', 'contact_person' => 'Teresita Bernal', 'phone' => '0917-555-0101', 'billing_address' => 'Naga City Public Market, Stall 42',
        'terms' => 'Net 15', 'credit_limit' => 30000, 'rep' => 'MS', 'type' => 'Market Retailer', 'billing_group_id' => $bg, 'allow_pos_charge' => 1]);
    // a government buyer: withholds 5% VAT and 1% income tax from what it pays
    $mkc(['name' => 'Municipality of San Isidro', 'company_name' => 'Municipal Government of San Isidro', 'contact_person' => 'Procurement Office', 'phone' => '(054) 450-1000',
        'email' => 'procurement@sanisidro.test', 'billing_address' => 'Municipal Hall, San Isidro, Camarines Sur', 'tin' => '000-456-789-000',
        'terms' => 'Net 30', 'type' => 'Government', 'pm' => 'Check', 'wht_ids' => $wht['WT-VAT'] . ',' . $wht['WT-GOODS']]);
    $mkc(['name' => 'Juan Dela Cruz', 'contact_person' => 'Juan Dela Cruz', 'mobile' => '0917-555-0000', 'terms' => 'Due on receipt', 'type' => 'Market Retailer', 'pm' => 'Cash']);
    $mkc(['name' => 'Walk-in Customer', 'terms' => 'Due on receipt', 'type' => 'Market Retailer', 'pm' => 'Cash']);

    // ---------------------------------------------------------------- fixed asset categories
    foreach ([
        ['Buildings', '1510', '1515', 'straight_line', 25],
        ['Machinery and Equipment', '1520', '1525', 'straight_line', 5],
        ['Production Machinery (usage-based)', '1520', '1525', 'units_of_production', 5],
        ['Transportation Equipment', '1530', '1535', 'declining_balance', 5],
        ['Furniture and Fixtures', '1540', '1545', 'straight_line', 10],
        ['Computer and POS Equipment', '1550', '1555', 'declining_balance', 3],
    ] as [$n, $a, $ad, $m, $life]) {
        DB::insert('asset_categories', ['name' => $n, 'asset_account_id' => $acct[$a], 'accum_dep_account_id' => $acct[$ad],
            'dep_expense_account_id' => $acct['6090'], 'default_method' => $m, 'default_life_years' => $life]);
    }

    // ---------------------------------------------------------------- sequences
    foreach ([
        ['estimate', 'EST-', 1, 5], ['sales_order', 'SO-', 1, 5], ['invoice', 'INV-', 1, 5], ['sales_receipt', 'SR-', 1, 5],
        ['statement_charge', 'SC-', 1, 5], ['finance_charge', 'FC-', 1, 5], ['payment', 'PMT-', 1, 5], ['credit_memo', 'CM-', 1, 5],
        ['purchase_order', 'PO-', 1, 5], ['bill', 'BILL-', 1, 5], ['item_receipt', 'IR-', 1, 5], ['check', '', 1001, 4],
        ['deposit', 'DEP-', 1, 5], ['transfer', 'TRF-', 1, 5], ['journal', 'JE-', 1, 5], ['adjustment', 'ADJ-', 1, 5],
        ['inv_transfer', 'IT-', 1, 5], ['build', 'BLD-', 1, 5], ['asset', 'FA-', 1, 5], ['pos', 'POS-', 1, 6],
        ['processing', 'PRC-', 1, 5], ['cash_voucher', 'CAV-', 1, 5],
        ['maintenance', 'MNT-', 1, 5], ['debit_memo', 'DM-', 1, 5], ['vendor_advance', 'ADV-', 1, 5], ['advance_apply', 'AAP-', 1, 5],
        ['allocation', 'AL-', 1, 5], ['crate', '', 1, 1], ['transfer_closing', 'TC-', 1, 5], ['shortage', 'SHC-', 1, 5],
        ['inv_dispatch', 'DSP-', 1, 5],
    ] as [$k, $pfx, $next, $pad]) {
        DB::insert('sequences', ['seq_key' => $k, 'prefix' => $pfx, 'next_no' => $next, 'pad' => $pad]);
    }

    // ---------------------------------------------------------------- community (v41): channels and inquiry categories
    if (Community::ready()) {
        Community::seedDefaults();
    }
}
