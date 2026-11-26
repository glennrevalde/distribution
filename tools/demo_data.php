<?php
declare(strict_types=1);

/**
 * Sample transactions of a chicken and frozen food distributor, covering every module, recorded through the same
 * posting engine the screens use (so the ledger, inventory, crates and audit trail are consistent): supplier
 * allocations picked up crate by crate, crates received, moved, sold whole or by the kilo, converted to kilos,
 * invoices, sales receipts, the POS, payments, bills, banking, fixed assets and depreciation.
 * Dates are relative to "today" so the aging reports look realistic. Crate weights come from a fixed seed, so
 * every install gives the same figures.
 */
require_once APP_ROOT . '/views/layout.php';
require_once APP_ROOT . '/modules/txn/_common.php';

function demo_id(string $table, string $col, string $val): int
{
    $id = DB::value("SELECT id FROM `$table` WHERE `$col` = :v", ['v' => $val]);
    if (!$id) {
        throw new RuntimeException("Demo data: $table.$col = $val not found");
    }
    return (int)$id;
}

function load_demo_data(): void
{
    mt_srand(20261122);
    // days ago (a negative number of days is in the future)
    $d = fn(int $daysAgo) => date('Y-m-d', strtotime(($daysAgo >= 0 ? '-' : '+') . abs($daysAgo) . ' days'));
    $item = fn(string $c) => demo_id('items', 'code', $c);
    $cust = fn(string $n) => demo_id('customers', 'name', $n);
    $vend = fn(string $n) => demo_id('vendors', 'name', $n);
    $acct = fn(string $c) => demo_id('accounts', 'code', $c);
    $site = fn(string $c) => demo_id('sites', 'code', $c);
    $user = fn(string $u) => demo_id('users', 'username', $u);
    $vat = demo_id('tax_codes', 'code', 'VAT12');
    $pm = fn(string $n) => demo_id('payment_methods', 'name', $n);
    $admin = $user('admin');
    Auth::actAs($admin);
    $GLOBALS['__vat'] = $vat;

    $nga = $site('NGA');
    $not = $site('NOT');
    $lgz = $site('LGZ');
    $price = fn(string $code) => (float)DB::value('SELECT sales_price FROM items WHERE code = :c', ['c' => $code]);
    $cost = fn(string $code) => (float)DB::value('SELECT cost FROM items WHERE code = :c', ['c' => $code]);
    $taxOf = fn(string $code) => DB::value('SELECT tax_code_id FROM items WHERE code = :c', ['c' => $code]);
    $crateUnit = fn(string $code) => (int)(Crates::crateUnit($item($code))['id'] ?? 0);
    $baseUnit = fn(string $code) => (int)DB::value('SELECT u.id FROM uom_units u JOIN items i ON i.uom_set_id = u.set_id WHERE i.code = :c AND u.is_base = 1', ['c' => $code]);

    // ---------------------------------------------------------------- classes (sample names; a company names its own)
    $class = [];
    foreach ([['Head Office', 'Wholesale, deliveries and administration', 1], ['Naga Outlet', 'Retail counter at the Naga cold storage', 2], ['Legazpi Depot', 'Depot and counter in Legazpi', 3]] as [$cn, $cd, $co]) {
        $class[$cn] = DB::insert('classes', ['name' => $cn, 'description' => $cd, 'sort_order' => $co, 'created_by' => $admin]);
    }
    Classes::reset();
    DB::run("UPDATE pos_terminals SET class_id = :c WHERE code = 'POS-01'", ['c' => $class['Naga Outlet']]);
    DB::run("UPDATE pos_terminals SET class_id = :c WHERE code = 'POS-02'", ['c' => $class['Legazpi Depot']]);
    DB::insert('other_names', ['name_type' => 'employee', 'name' => 'Glenn Abad', 'employee_no' => 'EMP-010', 'position' => 'Pick-up driver']);
    DB::insert('other_names', ['name_type' => 'employee', 'name' => 'Dan Villanueva', 'employee_no' => 'EMP-005', 'position' => 'Cold storage clerk']);
    DB::insert('other_names', ['name_type' => 'other', 'name' => 'Barangay Treasurer', 'position' => 'Permits and clearances']);

    // ---------------------------------------------------------------- helpers
    /** crates as they come off the scale: n crates around $avg kilos (or packs), with heads and dates */
    $weigh = function (int $n, float $avg, float $spread, int $heads, string $prod, int $shelfDays, bool $whole = false) {
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $q = $whole ? (float)round($avg + mt_rand(-(int)$spread, (int)$spread)) : round($avg + (mt_rand(-1000, 1000) / 1000) * $spread, 2);
            $out[] = ['no' => '', 'pcs' => $heads ? $heads + mt_rand(-1, 1) : 0, 'qty' => $q, 'prod' => $prod, 'exp' => date('Y-m-d', strtotime($prod . " +$shelfDays days"))];
        }
        return $out;
    };
    /** the oldest open crates of an item at a site: whole crates ($count), or $kilos taken from them */
    $pick = function (string $code, int $siteId, ?int $count, ?float $kilos = null) use ($item) {
        $out = [];
        foreach (Crates::open($item($code), $siteId) as $c) {
            if ($count !== null) {
                if (count($out) >= $count) {
                    break;
                }
                $out[] = ['id' => (int)$c['id'], 'qty' => (float)$c['qty_left']];
            } else {
                if ($kilos <= 0.00005) {
                    break;
                }
                $t = round(min((float)$c['qty_left'], $kilos), 4);
                $out[] = ['id' => (int)$c['id'], 'qty' => $t];
                $kilos = round($kilos - $t, 4);
            }
        }
        return $out;
    };
    $sales = fn(array $rows, ?int $c, int $siteId) => parse_item_lines($rows, 'sales', ['customer_id' => $c, 'crates' => 'out', 'site_id' => $siteId]);
    $buy = fn(array $rows, ?int $siteId = null) => parse_item_lines($rows, 'purchase', ['crates' => 'in', 'site_id' => $siteId]);
    // a sales line: loose (no crates), whole crates, or kilos taken from crates
    $line = fn(string $code, float $q, ?float $rate = null, float $disc = 0) => [
        'item_id' => $item($code), 'qty' => $q, 'rate' => $rate ?? $price($code), 'discount_pct' => $disc, 'tax_code_id' => $taxOf($code),
    ];
    $crateLine = function (string $code, int $siteId, int $n, ?float $rate = null) use ($item, $price, $taxOf, $pick, $crateUnit) {
        return ['item_id' => $item($code), 'uom_id' => $crateUnit($code), 'qty' => 0, 'rate' => $rate ?? $price($code), 'tax_code_id' => $taxOf($code),
            'crates' => $pick($code, $siteId, $n)];
    };
    $kgLine = function (string $code, int $siteId, float $kg, ?float $rate = null) use ($item, $price, $taxOf, $pick, $baseUnit) {
        return ['item_id' => $item($code), 'uom_id' => $baseUnit($code), 'qty' => $kg, 'rate' => $rate ?? $price($code), 'tax_code_id' => $taxOf($code),
            'crates' => $pick($code, $siteId, null, $kg)];
    };
    // a purchase line received in crates
    $inCrates = fn(string $code, array $crates, ?float $rate = null, ?int $siteId = null) => [
        'item_id' => $item($code), 'uom_id' => $crateUnit($code), 'qty' => 0, 'rate' => $rate ?? $cost($code), 'tax_code_id' => $vat, 'site_id' => $siteId, 'crates' => $crates,
    ];
    $pline = fn(string $code, float $q, ?float $c = null, ?int $siteId = null) => [
        'item_id' => $item($code), 'qty' => $q, 'rate' => $c ?? $cost($code), 'tax_code_id' => $vat, 'site_id' => $siteId,
    ];
    $exp = fn(string $code, float $amt, string $memo, ?int $tax = null, ?int $job = null) => [
        'account_id' => $acct($code), 'amount' => $amt, 'description' => $memo, 'tax_code_id' => $tax, 'customer_id' => $job, 'is_billable' => $job ? 1 : 0,
    ];
    $pay = function (int $customerId, string $date, float $amount, array $apps, array $extra = []) use ($acct) {
        $disc = array_sum(array_column($apps, 'discount'));
        $wht = array_sum(array_column($apps, 'withholding'));
        return Txn::save('payment', array_merge([
            'txn_date' => $date, 'customer_id' => $customerId, 'account_id' => $acct('1050'), 'account2_id' => Accts::get('ar'),
            'total' => $amount, 'discount_amount' => $disc, 'withholding_amount' => $wht,
        ], $extra), [], null, ['keep_totals' => true, 'applications' => $apps]);
    };
    $invoice = function (string $customer, string $date, array $rows, array $extra = []) use ($cust, $sales, $nga, $class) {
        $cid = $cust($customer);
        $c = DB::row('SELECT * FROM customers WHERE id = :id', ['id' => $cid]);
        $siteId = (int)($extra['site_id'] ?? $nga);
        return Txn::save('invoice', array_merge([
            'txn_date' => $date, 'customer_id' => $cid, 'account_id' => Accts::get('ar'), 'terms_id' => $c['terms_id'],
            'due_date' => Txn::dueDate($date, $c['terms_id'] ? (int)$c['terms_id'] : null), 'sales_rep_id' => $c['sales_rep_id'],
            'site_id' => $siteId, 'billing_address' => $c['billing_address'], 'shipping_address' => $c['shipping_address'], 'customer_message' => 'Thank you for your business.',
            'class_id' => $class['Head Office'],
        ], $extra), $sales($rows, $cid, $siteId));
    };
    // a supplier allocation, picked up crate by crate and received
    $allocate = function (string $vendor, string $date, int $siteId, string $picker, array $lines, string $finish) use ($vend, $item, $user, $crateUnit, $baseUnit, $weigh, $admin, $class) {
        Auth::actAs($user('allocator'));
        $id = DB::insert('supplier_allocations', ['alloc_no' => Seq::next('allocation'), 'alloc_date' => $date, 'vendor_id' => $vend($vendor), 'site_id' => $siteId,
            'assigned_user_id' => $user($picker), 'class_id' => $class['Head Office'], 'status' => 'open', 'created_by' => Auth::id(), 'updated_at' => $date . ' 06:10:00']);
        $no = DB::value('SELECT alloc_no FROM supplier_allocations WHERE id = :id', ['id' => $id]);
        Audit::log('create', 'vend', 'allocation', $id, (string)$no, ['page_key' => 'vend.allocations', 'site_id' => $siteId]);
        $n = 0;
        $lineIds = [];
        foreach ($lines as [$code, $q, $avg, $heads, $shelf]) {
            $crate = $avg !== null;
            $uom = $crate ? $crateUnit($code) : $baseUnit($code);
            $lineIds[] = [DB::insert('supplier_allocation_lines', ['allocation_id' => $id, 'line_no' => ++$n, 'item_id' => $item($code), 'uom_id' => $uom,
                'unit_code' => Uom::code($uom), 'qty' => $q]), $crate, $q, $avg, $heads, $shelf];
        }
        if ($finish === 'open') {
            Auth::actAs($admin);
            return $id;
        }
        Auth::actAs($user($picker));
        foreach ($lineIds as $k => [$lid, $crate, $q, $avg, $heads, $shelf]) {
            if ($finish === 'picking' && $k >= 1) {
                break;      // the pick-up crew is still at the supplier
            }
            if ($crate) {
                $whole = $heads === 0;
                $rows = $weigh((int)$q - ($k === 2 && $q > 4 ? 1 : 0), $avg, $whole ? 2 : 0.6, $heads, date('Y-m-d', strtotime($date . ' -1 day')), $shelf, $whole);
                $start = (int)max((int)Crates::peekNo(), (int)DB::value("SELECT COALESCE(MAX(CAST(crate_no AS UNSIGNED)),0) FROM supplier_allocation_crates") + 1);
                foreach ($rows as $i => &$r) {
                    $r['no'] = (string)($start + $i);
                }
                unset($r);
                Allocations::savePicked($lid, $rows, null, true);
            } else {
                Allocations::savePicked($lid, [], round($q * (0.97 + mt_rand(0, 6) / 100), 2), true);
            }
        }
        if ($finish === 'received') {
            Allocations::complete($id, $date);
        }
        Auth::actAs($admin);
        return $id;
    };

    // ---------------------------------------------------------------- opening balances
    Txn::save('opening_balance', ['txn_date' => $d(80), 'memo' => 'Opening balances', 'txn_no' => 'OB-0001'], [
        ['line_kind' => 'journal', 'account_id' => $acct('1010'), 'amount' => 3200000, 'description' => 'BDO checking opening balance'],
        ['line_kind' => 'journal', 'account_id' => $acct('1020'), 'amount' => 900000, 'description' => 'BPI savings opening balance'],
        ['line_kind' => 'journal', 'account_id' => $acct('1005'), 'amount' => 15000, 'description' => 'Petty cash fund'],
        ['line_kind' => 'journal', 'account_id' => $acct('1001'), 'amount' => 10000, 'description' => 'Register cash funds'],
        ['line_kind' => 'journal', 'account_id' => $acct('3000'), 'amount' => -4125000, 'description' => "Owner's capital"],
    ]);

    // ---------------------------------------------------------------- fixed assets
    $mkAsset = function (array $a) use ($acct) {
        $cat = DB::row('SELECT * FROM asset_categories WHERE name = :n', ['n' => $a['category']]);
        $no = Seq::next('asset');
        $lineA = ['line_kind' => 'expense', 'account_id' => (int)$cat['asset_account_id'], 'amount' => $a['cost'], 'description' => $a['description']];
        if ($a['funding'] === 'check') {
            $txn = Txn::save('check', ['txn_date' => $a['date'], 'account_id' => $acct('1010'), 'vendor_id' => $a['vendor'], 'memo' => 'Purchase of ' . $a['description']], [$lineA]);
        } else {
            $txn = Txn::save('bill', ['txn_date' => $a['date'], 'vendor_id' => $a['vendor'], 'account_id' => Accts::get('ap'), 'terms_id' => 3,
                'due_date' => date('Y-m-d', strtotime($a['date'] . ' +30 days')), 'ref_no' => $a['ref'] ?? null, 'memo' => 'Purchase of ' . $a['description']], [$lineA]);
        }
        $locId = DB::value('SELECT id FROM asset_locations WHERE name = :n', ['n' => $a['location']]) ?: DB::insert('asset_locations', ['name' => $a['location']]);
        $id = DB::insert('fixed_assets', [
            'asset_no' => $no, 'description' => $a['description'], 'category_id' => $cat['id'], 'location' => $a['location'], 'location_id' => (int)$locId, 'vendor_id' => $a['vendor'],
            'acquisition_date' => $a['date'], 'cost' => $a['cost'], 'salvage_value' => $a['salvage'], 'useful_life_years' => $a['life'], 'method' => $a['method'],
            'total_units' => $a['units'] ?? null, 'unit_label' => $a['unit_label'] ?? null, 'acquisition_txn_id' => $txn, 'serial_no' => $a['serial'] ?? null,
        ]);
        Audit::log('create', 'fa', 'asset', $id, $no . ' ' . $a['description'], ['amount' => $a['cost'], 'page_key' => 'fa.register']);
        return $id;
    };
    $start = date('Y-m-01', strtotime('-2 months'));
    $btr = $vend('Bicol Truck and Reefer Corp.');
    $cool = $vend('Coolwave Refrigeration Services');
    $mkAsset(['description' => 'Blast Freezer and Cold Room (20 tons)', 'category' => 'Machinery and Equipment', 'location' => 'Naga Cold Storage', 'vendor' => $cool, 'date' => $start,
        'cost' => 1850000, 'salvage' => 150000, 'life' => 10, 'method' => 'straight_line', 'funding' => 'check', 'serial' => 'CR-20T-0091']);
    $truck = $mkAsset(['description' => 'Reefer Truck 1 (6-wheeler, -18 C)', 'category' => 'Transportation Equipment', 'location' => 'Naga Cold Storage', 'vendor' => $btr, 'date' => $start,
        'cost' => 2450000, 'salvage' => 350000, 'life' => 5, 'method' => 'declining_balance', 'funding' => 'bill', 'ref' => 'BTR-5521', 'serial' => 'RFT-ABC-1234']);
    $posSet = $mkAsset(['description' => 'POS Terminal Set (Naga Outlet)', 'category' => 'Computer and POS Equipment', 'location' => 'Naga Outlet', 'vendor' => $btr, 'date' => $start,
        'cost' => 65000, 'salvage' => 0, 'life' => 3, 'method' => 'syd', 'funding' => 'check']);
    $scale = $mkAsset(['description' => 'Platform Scale 300 kg (receiving)', 'category' => 'Production Machinery (usage-based)', 'location' => 'Naga Cold Storage', 'vendor' => $cool, 'date' => $start,
        'cost' => 85000, 'salvage' => 5000, 'life' => 5, 'method' => 'units_of_production', 'units' => 150000, 'unit_label' => 'weighings', 'funding' => 'bill', 'ref' => 'CRS-5530']);

    DB::update('fixed_assets', ['current_meter' => 18200, 'meter_unit' => 'km'], 'id = :id', ['id' => $truck]);
    foreach ([
        [$truck, 'Vehicle registration renewal (LTO)', 'registration', 1, 'years', null, date('Y-m-d', strtotime('+20 days')), null, 30, 'Bring the OR/CR and the emission test result'],
        [$truck, 'Change oil and oil filter', 'change_oil', 3, 'months', 5000, date('Y-m-d', strtotime('-3 days')), 20000, 7, null],
        [$truck, 'Reefer unit check (temperature hold test)', 'other', 1, 'months', null, date('Y-m-d', strtotime('+5 days')), null, 5, 'Must hold -18 C for 4 hours'],
        [$posSet, 'Clean the computers and POS units', 'cleaning', 6, 'months', null, date('Y-m-d', strtotime('+75 days')), null, 14, null],
    ] as [$aid, $task, $kind, $iv, $unit, $miv, $due, $dueMeter, $remind, $note]) {
        DB::insert('asset_pm_schedules', ['asset_id' => $aid, 'task_name' => $task, 'task_type' => $kind, 'interval_value' => $iv, 'interval_unit' => $unit, 'meter_interval' => $miv,
            'next_due_date' => $due, 'next_due_meter' => $dueMeter, 'remind_days' => $remind, 'notes' => $note, 'created_by' => Auth::id()]);
    }
    $repAcct = AssetMaint::defaultExpenseAccount();
    $mDate = date('Y-m-d', strtotime('-20 days'));
    $mRow = ['maint_no' => Seq::next('maintenance'), 'asset_id' => $truck, 'maint_date' => $mDate, 'maint_type' => 'repair', 'status' => 'completed', 'problem' => 'Reefer unit not holding temperature on long trips',
        'description' => 'Replaced the condenser fan motor and recharged the refrigerant.', 'vendor_id' => $cool, 'performed_by' => 'Coolwave service team', 'ref_no' => 'CRS-SV-0192',
        'meter_reading' => 18200, 'downtime_days' => 1, 'parts_total' => 14500, 'labor_total' => 2500, 'tax_total' => 0, 'total' => 17000, 'with_vat' => 0, 'payment_mode' => 'bill',
        'parts_account_id' => $repAcct, 'labor_account_id' => $repAcct, 'created_by' => Auth::id()];
    $mId = DB::insert('asset_maintenance', $mRow);
    DB::insert('asset_maintenance_parts', ['maintenance_id' => $mId, 'line_no' => 1, 'part_no' => 'CFM-24V', 'description' => 'Condenser fan motor', 'brand' => 'Thermo', 'serial_no' => 'TK-778812', 'model_no' => 'T-600',
        'size_spec' => '24 V', 'qty' => 1, 'unit' => 'pc', 'unit_cost' => 11500, 'amount' => 11500, 'warranty_until' => date('Y-m-d', strtotime($mDate . ' +1 year'))]);
    DB::insert('asset_maintenance_parts', ['maintenance_id' => $mId, 'line_no' => 2, 'part_no' => 'R404A', 'description' => 'Refrigerant R404A', 'brand' => 'Freon', 'qty' => 3, 'unit' => 'kg', 'unit_cost' => 1000, 'amount' => 3000]);
    DB::insert('asset_maintenance_labor', ['maintenance_id' => $mId, 'line_no' => 1, 'description' => 'Replace fan motor and recharge', 'worker' => 'Coolwave technician', 'charge_type' => 'hourly', 'hours' => 5, 'rate' => 300, 'amount' => 1500]);
    DB::insert('asset_maintenance_labor', ['maintenance_id' => $mId, 'line_no' => 2, 'description' => 'Temperature hold test', 'charge_type' => 'bulk', 'hours' => 0, 'rate' => 0, 'amount' => 1000]);
    DB::update('asset_maintenance', ['txn_id' => AssetMaint::syncTransaction($mRow + ['id' => $mId], null)], 'id = :id', ['id' => $mId]);

    // ---------------------------------------------------------------- receiving in crates
    $npc = $vend('Northfield Poultry Corp.');
    $gpf = $vend('Golden Plume Farms Inc.');
    // Receive Items and Enter Bills: whole chicken, breasts and liver in crates, blood by the kilo
    Txn::save('bill', ['txn_date' => $d(74), 'vendor_id' => $npc, 'site_id' => $nga, 'ref_no' => 'NPC-INV-10231', 'terms_id' => 2, 'due_date' => $d(59), 'account_id' => Accts::get('ap'),
        'memo' => 'Opening stock, received in crates', 'received_via' => 'bill'], $buy([
        $inCrates('WCK-FC', $weigh(12, 12.4, 0.5, 11, $d(75), 12), null, $nga),
        $inCrates('BRS-FZ', $weigh(6, 15.0, 0.6, 0, $d(76), 180), null, $nga),
        $inCrates('LVR-FZ', $weigh(3, 10.0, 0.4, 0, $d(75), 90), null, $nga),
        $inCrates('ACU-FZ', $weigh(6, 14.5, 0.6, 0, $d(76), 180), null, $nga),
        $pline('BLD', 40, null, $nga),
    ], $nga));
    // Receive Items now, the bill afterwards at a different price on wings
    $ir = Txn::save('item_receipt', ['txn_date' => $d(72), 'vendor_id' => $gpf, 'site_id' => $nga, 'ref_no' => 'DR-7781', 'account_id' => Accts::get('ap'), 'received_via' => 'receipt'], $buy([
        $inCrates('DRM-FZ', $weigh(8, 15.2, 0.5, 0, $d(74), 180), null, $nga),
        $inCrates('WNG-FZ', $weigh(6, 12.0, 0.5, 0, $d(74), 180), null, $nga),
        $inCrates('GIZ-FZ', $weigh(3, 10.0, 0.3, 0, $d(73), 90), null, $nga),
        $inCrates('BLB-250', $weigh(6, 40, 0, 0, $d(80), 270, true), null, $nga),
        $inCrates('NGT-500', $weigh(4, 24, 0, 0, $d(82), 270, true), null, $nga),
    ], $nga));
    $conv = [];
    foreach (Txn::lines($ir) as $l) {
        $conv[] = ['id' => $l['id'], 'item_id' => $l['item_id'], 'qty' => $l['qty'], 'rate' => $l['item_code'] === 'WNG-FZ' ? 188 : $l['rate'], 'tax_code_id' => $vat,
            'site_id' => $l['site_id'], 'uom_id' => $l['uom_id']];
    }
    $convLines = parse_item_lines($conv, 'purchase');    // as Enter Bill for Received Items: the crates stay as received
    foreach ($convLines as &$cl) {
        // the crates stay as received: the bill only sets the price
        $old = DB::row('SELECT uom_id, unit, uom_qty, uom_factor FROM transaction_lines WHERE id = :id', ['id' => $cl['id']]);
        $cl = array_merge($cl, $old);
    }
    unset($cl);
    Txn::save('bill', ['txn_date' => $d(66), 'txn_no' => Seq::next('bill'), 'vendor_id' => $gpf, 'ref_no' => 'GPF-INV-10288', 'terms_id' => 3, 'due_date' => $d(36),
        'account_id' => Accts::get('ap'), 'memo' => 'Bill for received items'], $convLines, $ir, ['audit_action' => 'convert']);
    // packaging by the bundle of 100
    $bundle = (int)DB::value("SELECT u.id FROM uom_units u JOIN uom_sets s ON s.id = u.set_id WHERE s.base_unit = 'pc' AND u.code = 'bundle' LIMIT 1");
    Txn::save('bill', ['txn_date' => $d(70), 'vendor_id' => $vend('Bicol Packaging Supply'), 'site_id' => $nga, 'ref_no' => 'BPS-99812', 'terms_id' => 2, 'due_date' => $d(55),
        'account_id' => Accts::get('ap'), 'memo' => 'Vacuum bags'], $buy([['item_id' => $item('PKG-BAG'), 'qty' => 20, 'rate' => 330, 'uom_id' => $bundle, 'site_id' => $nga, 'tax_code_id' => $vat]]));

    // ---------------------------------------------------------------- supplier allocations and pick-ups
    // [item, quantity allocated, average weight of a crate (null = by the kilo), heads per crate (0 = packs), shelf life in days]
    $allocate('Northfield Poultry Corp.', $d(60), $nga, 'glenn', [['WCK-FC', 10, 12.4, 11, 12], ['BBD-FC', 6, 14.8, 9, 10], ['ACU-FZ', 5, 14.5, 0, 180], ['BLD', 30, null, 0, 0]], 'received');
    $allocate('Golden Plume Farms Inc.', $d(52), $nga, 'glenn', [['DRM-FZ', 6, 15.2, 0, 180], ['WNG-FZ', 4, 12.0, 0, 180], ['BLB-250', 5, 40, 0, 270]], 'received');
    $allocate('Northfield Poultry Corp.', $d(45), $nga, 'glenn', [['WCK-FC', 12, 12.5, 11, 12], ['BRS-FZ', 5, 15.0, 0, 180], ['LVR-FZ', 3, 10.0, 0, 90]], 'received');
    $allocate('Northfield Poultry Corp.', $d(30), $nga, 'glenn', [['WCK-FC', 10, 12.3, 11, 12], ['BBD-FC', 6, 14.9, 9, 10], ['ACU-FZ', 4, 14.4, 0, 180], ['BLD', 25, null, 0, 0]], 'received');
    $allocate('Golden Plume Farms Inc.', $d(21), $lgz, 'glenn', [['WCK-FC', 8, 12.2, 11, 12], ['DRM-FZ', 4, 15.1, 0, 180], ['GIZ-FZ', 2, 10.0, 0, 90], ['NGT-500', 3, 24, 0, 270]], 'received');
    $allocate('Northfield Poultry Corp.', $d(9), $nga, 'glenn', [['WCK-FC', 10, 12.4, 11, 12], ['BRS-FZ', 4, 15.1, 0, 180], ['ACU-FZ', 4, 14.6, 0, 180]], 'received');
    $allocate('Northfield Poultry Corp.', $d(2), $nga, 'glenn', [['WCK-FC', 8, 12.5, 11, 12], ['BBD-FC', 5, 14.7, 9, 10], ['LVR-FZ', 2, 10.0, 0, 90], ['BLD', 20, null, 0, 0]], 'received');
    // today: one being picked up, one still waiting, and tomorrow's
    $allocate('Northfield Poultry Corp.', $d(0), $nga, 'glenn', [['WCK-FC', 5, 12.4, 11, 12], ['BBD-FC', 5, 14.8, 9, 10], ['ACU-FZ', 3, 14.5, 0, 180], ['BLD', 20, null, 0, 0]], 'picking');
    $allocate('Golden Plume Farms Inc.', $d(0), $lgz, 'glenn', [['DRM-FZ', 4, 15.2, 0, 180], ['WNG-FZ', 3, 12.0, 0, 180], ['BLB-250', 4, 40, 0, 270], ['NGT-500', 2, 24, 0, 270]], 'open');
    $allocate('Northfield Poultry Corp.', $d(-1), $nga, 'glenn', [['WCK-FC', 15, 12.4, 11, 12], ['BRS-FZ', 4, 15.0, 0, 180]], 'open');

    // ---------------------------------------------------------------- crates to the outlet and the depot
    $move = function (string $date, int $from, int $to, array $what, string $memo) use ($item, $pick) {
        $lines = [];
        foreach ($what as [$code, $n]) {
            $crates = $pick($code, $from, $n);
            if (!$crates) {
                continue;
            }
            $unit = Crates::crateUnit($item($code));
            $q = round(array_sum(array_column($crates, 'qty')), 4);
            $lines[] = ['line_kind' => 'item', 'item_id' => $item($code), 'qty' => $q, 'description' => 'Crates to the branch', 'site_id' => $from,
                'uom_id' => $unit['id'], 'unit' => $unit['code'], 'uom_qty' => count($crates), 'uom_factor' => round($q / count($crates), 6),
                '_crates' => ['dir' => 'move', 'rows' => array_map(fn($c) => ['id' => $c['id']], $crates)]];
        }
        return Txn::save('inventory_transfer', ['txn_date' => $date, 'site_id' => $from, 'site2_id' => $to, 'status' => 'open', 'memo' => $memo], $lines);
    };
    $move($d(64), $nga, $not, [['WCK-FC', 3], ['DRM-FZ', 2], ['WNG-FZ', 1], ['LVR-FZ', 1], ['BLB-250', 2], ['NGT-500', 1]], 'Stock for the Naga Outlet');
    $move($d(63), $nga, $lgz, [['WCK-FC', 2], ['BRS-FZ', 2], ['DRM-FZ', 2], ['BLB-250', 1]], 'Stock for the Legazpi Depot');
    $move($d(29), $nga, $not, [['WCK-FC', 3], ['BBD-FC', 2], ['ACU-FZ', 1]], 'Weekend stock for the outlet');
    $move($d(8), $nga, $not, [['WCK-FC', 4], ['BRS-FZ', 1], ['ACU-FZ', 1]], 'Stock for the outlet');
    $move($d(1), $nga, $not, [['WCK-FC', 3], ['BBD-FC', 2], ['LVR-FZ', 1]], 'Stock for the outlet');
    // loose stock (not kept in crates) goes the usual way
    Txn::save('inventory_transfer', ['txn_date' => $d(30), 'site_id' => $nga, 'site2_id' => $not, 'status' => 'open', 'memo' => 'Blood and vacuum bags for the outlet'], [
        ['line_kind' => 'item', 'item_id' => $item('BLD'), 'qty' => 12, 'description' => 'Chicken blood', 'site_id' => $nga],
        ['line_kind' => 'item', 'item_id' => $item('PKG-BAG'), 'qty' => 200, 'description' => 'Vacuum bags', 'site_id' => $nga],
    ]);

    // two crates of cut-ups converted to kilos for repacking at the outlet
    $toConvert = array_column(array_slice(Crates::open($item('ACU-FZ'), $not), 0, 1), 'id');
    $toConvert = array_merge($toConvert, array_column(array_slice(Crates::open($item('ACU-FZ'), $nga), 0, 1), 'id'));
    Crates::convert($toConvert, 'Repacked into 1 kg retail bags', $d(28));

    // ---------------------------------------------------------------- cutting whole chicken into parts, and party packs
    $process = function (string $source, float $batches, string $date, int $siteId, array $opt = []) {
        $f = Processing::formula(demo_id('process_formulas', 'code', $source));
        [$in, $out, $cs] = Processing::expandFormula((int)$f['id'], $batches);
        $type = $f['process_type'];
        $method = $opt['method'] ?? $f['alloc_method'];
        foreach ($out as &$o) {
            $code = (string)DB::value('SELECT code FROM items WHERE id = :id', ['id' => $o['item_id']]);
            if (isset($opt['actual'][$code])) {
                $o['qty'] = $opt['actual'][$code];
            }
        }
        unset($o);
        $pending = !empty($opt['pending']);
        [$lines, $est] = Processing::orderLines($in, $out, $cs, $method);
        return Txn::save(Processing::TXN_TYPE, [
            'txn_date' => $date, 'site_id' => $siteId, 'process_type' => $type, 'alloc_method' => $method,
            'process_formula_id' => $f['id'], 'process_batches' => $batches, 'memo' => $opt['memo'] ?? null,
            'account_id' => Processing::isValueMethod($method) ? Accts::get('processing_variance') : null,
            'is_pending' => $pending ? 1 : 0, 'status' => $pending ? 'pending' : 'completed',
            'subtotal' => $est['materials'], 'total' => $est['pool'],
        ], $lines);
    };
    // whole chickens are taken from the oldest crates (the crates give their kilos automatically)
    $process('CUT-WCK', 3, $d(56), $nga, ['memo' => 'Cut-ups for the restaurant orders']);
    $process('CUT-WCK', 2, $d(26), $nga, ['memo' => 'Cut-ups; a little more breast than planned', 'actual' => ['BRS-FZ' => 5.4, 'ACU-FZ' => 5.8]]);
    $process('CUT-WCK', 2, $d(1), $nga, ['pending' => true, 'memo' => 'Waiting for the cutting crew']);
    $bom = DB::all('SELECT component_item_id, qty FROM item_components WHERE parent_item_id = :p', ['p' => $item('PARTY-PK')]);
    $build = function (float $q, string $date, bool $pending) use ($bom, $item, $nga) {
        $lines = [['line_kind' => 'item', 'item_id' => $item('PARTY-PK'), 'qty' => $q, 'description' => 'Party Pack', 'site_id' => $nga]];
        foreach ($bom as $b) {
            $lines[] = ['line_kind' => 'component', 'item_id' => (int)$b['component_item_id'], 'qty' => (float)$b['qty'] * $q, 'description' => 'Component', 'site_id' => $nga];
        }
        return Txn::save('build_assembly', ['txn_date' => $date, 'site_id' => $nga, 'is_pending' => $pending ? 1 : 0, 'status' => $pending ? 'pending' : 'completed',
            'memo' => $pending ? 'Waiting for wings' : 'Party packs for the weekend'], $lines);
    };
    $build(8, $d(40), false);
    Txn::save('inventory_transfer', ['txn_date' => $d(39), 'site_id' => $nga, 'site2_id' => $not, 'status' => 'open', 'memo' => 'Party packs for the outlet'],
        [['line_kind' => 'item', 'item_id' => $item('PARTY-PK'), 'qty' => 3, 'description' => 'Party Pack', 'site_id' => $nga]]);
    $build(20, $d(3), true);

    // ---------------------------------------------------------------- sales: crates sold whole, kilos sold out of crates
    $sun = $cust('Sunrise Supermart');
    $sunPili = $cust('Sunrise Supermart Pili Branch');
    $lola = $cust('Kusina ni Lola Restaurant');
    $grill = $cust('Legazpi Grill House');
    $hosp = $cust('St. Raphael Hospital Kitchen');
    $tess = $cust('Aling Tess Market Stall');
    // estimate -> sales order -> invoices (the crates are chosen when the goods go out)
    $est = Txn::save('estimate', ['txn_date' => $d(58), 'customer_id' => $sun, 'status' => 'accepted', 'due_date' => $d(28), 'sales_rep_id' => 1,
        'memo' => 'Weekly supply for both branches'], parse_item_lines([
        $line('WCK-FC', 120, 165), $line('BRS-FZ', 45, 215), $line('DEL-FEE', 2),
    ], 'sales', ['customer_id' => $sun]));
    $soRows = [];
    foreach (Txn::lines($est) as $l) {
        $soRows[] = ['item_id' => $l['item_id'], 'qty' => $l['qty'], 'rate' => $l['rate'], 'tax_code_id' => $l['tax_code_id'], 'source_line_id' => $l['id'], 'description' => $l['description']];
    }
    $so = Txn::save('sales_order', ['txn_date' => $d(57), 'customer_id' => $sun, 'site_id' => $nga, 'sales_rep_id' => 1, 'ship_date' => $d(50), 'ref_no' => 'SUN-PO-7781',
        'billing_address' => 'Magsaysay Avenue, Naga City'], parse_item_lines($soRows, 'sales', ['customer_id' => $sun]));
    $soLines = [];
    foreach (Txn::lines($so) as $l) {
        $soLines[$l['item_code']] = $l;
    }
    $fromSo = function (string $code, array $row) use ($soLines) {
        $l = $soLines[$code];
        return $row + ['source_line_id' => $l['id'], 'description' => $l['description']];
    };
    $inv1 = $invoice('Sunrise Supermart', $d(55), [
        $fromSo('WCK-FC', $crateLine('WCK-FC', $nga, 5, 165)), $fromSo('BRS-FZ', $crateLine('BRS-FZ', $nga, 2, 215)), $fromSo('DEL-FEE', $line('DEL-FEE', 1)),
    ], ['ref_no' => 'SUN-PO-7781']);
    $inv2 = $invoice('Sunrise Supermart', $d(48), [
        $fromSo('WCK-FC', $crateLine('WCK-FC', $nga, 4, 165)), $fromSo('DEL-FEE', $line('DEL-FEE', 1)),
    ], ['ref_no' => 'SUN-PO-7781']);
    $invoice('Sunrise Supermart Pili Branch', $d(44), [$crateLine('WCK-FC', $nga, 3, 165), $crateLine('DRM-FZ', $nga, 2), $line('DEL-FEE', 1)]);
    $invL = $invoice('Kusina ni Lola Restaurant', $d(50), [$kgLine('WCK-FC', $nga, 18), $kgLine('BRS-FZ', $nga, 10), $kgLine('LVR-FZ', $nga, 4), $line('BLD', 6)]);
    $invL2 = $invoice('Kusina ni Lola Restaurant', $d(36), [$kgLine('DRM-FZ', $nga, 12), $kgLine('WNG-FZ', $nga, 8), $line('SRV-CUT', 12)]);
    $invG = $invoice('Legazpi Grill House', $d(42), [$crateLine('WCK-FC', $lgz, 1), $crateLine('DRM-FZ', $lgz, 1), $kgLine('BRS-FZ', $lgz, 8)], ['site_id' => $lgz, 'class_id' => $class['Legazpi Depot']]);
    $invG2 = $invoice('Legazpi Grill House', $d(18), [$crateLine('WCK-FC', $lgz, 4), $kgLine('DRM-FZ', $lgz, 10), $line('DEL-FEE', 1)], ['site_id' => $lgz, 'class_id' => $class['Legazpi Depot']]);
    $invH = $invoice('St. Raphael Hospital Kitchen', $d(40), [$kgLine('BRS-FZ', $nga, 20), $kgLine('ACU-FZ', $nga, 15)]);
    foreach ([33, 12] as $ago) {
        $batch = 'B' . date('Ymd', strtotime("-$ago days")) . '0900';
        $invoice('St. Raphael Hospital Kitchen', $d($ago), [$kgLine('BRS-FZ', $nga, 15), $kgLine('ACU-FZ', $nga, 12)], ['batch_ref' => $batch, 'memo' => 'Weekly hospital kitchen delivery']);
        $invoice('Aling Tess Market Stall', $d($ago), [$crateLine('WCK-FC', $nga, 2, 168)], ['batch_ref' => $batch, 'memo' => 'Weekly market stall delivery']);
    }
    $invSun3 = $invoice('Sunrise Supermart', $d(25), [$crateLine('WCK-FC', $nga, 6, 165), $crateLine('BBD-FC', $nga, 3), $crateLine('NGT-500', $nga, 1), $line('SUBTOTAL', 0), $line('DISC-5', 0)]);
    $invSun4 = $invoice('Sunrise Supermart', $d(6), [$crateLine('WCK-FC', $nga, 5, 165), $crateLine('BRS-FZ', $nga, 1, 215), $line('DEL-FEE', 1)]);
    $invoice('Kusina ni Lola Restaurant', $d(4), [$kgLine('WCK-FC', $nga, 25), $kgLine('GIZ-FZ', $nga, 3)]);
    // a pending sale and a crate deposit
    $invoice('Legazpi Grill House', $d(2), [$crateLine('WCK-FC', $lgz, 1), $line('CRATE-DEP', 2)], ['is_pending' => 1, 'memo' => 'Awaiting PO approval', 'site_id' => $lgz, 'class_id' => $class['Legazpi Depot']]);
    // cash sale from the back office: kilos out of a crate
    Txn::save('sales_receipt', ['txn_date' => $d(39), 'customer_id' => $cust('Juan Dela Cruz'), 'account_id' => $acct('1050'), 'payment_method_id' => $pm('Cash'),
        'site_id' => $nga, 'memo' => 'Phone order'], $sales([$kgLine('LVR-FZ', $nga, 2.5), $kgLine('WCK-FC', $nga, 6.2), $line('BLD', 2)], $cust('Juan Dela Cruz'), $nga));

    // payments
    $pay($sun, $d(28), 60000, [['target_txn_id' => $inv1, 'amount' => 60000, 'discount' => 0, 'withholding' => 0]], ['payment_method_id' => $pm('Check'), 'ref_no' => 'BDO-004412']);
    $gOpen = Balances::open(Txn::load($invG));
    $gTot = (float)Txn::load($invG)['total'];
    $pay($grill, $d(34), r2($gOpen - r2($gTot * 0.02)), [['target_txn_id' => $invG, 'amount' => r2($gOpen - r2($gTot * 0.02)), 'discount' => r2($gTot * 0.02), 'withholding' => 0]],
        ['payment_method_id' => $pm('Bank Transfer'), 'ref_no' => 'IB-88123', 'account_id' => $acct('1010')]);
    $lOpen = Balances::open(Txn::load($invL));
    $pay($lola, $d(37), $lOpen + 500, [['target_txn_id' => $invL, 'amount' => $lOpen, 'discount' => 0, 'withholding' => 0]], ['payment_method_id' => $pm('Check'), 'ref_no' => 'MBTC-1120']);
    $hOpen = Balances::open(Txn::load($invH));
    $pay($hosp, $d(26), round($hOpen / 2, 2), [['target_txn_id' => $invH, 'amount' => round($hOpen / 2, 2), 'discount' => 0, 'withholding' => 0]], ['payment_method_id' => $pm('GCash')]);

    // a government buyer: 5% VAT and 1% income tax withheld on the VAT-exclusive amount
    $wtRow = function (string $code, float $base, string $side) {
        $w = DB::row('SELECT * FROM withholding_taxes WHERE code = :c', ['c' => $code]);
        return ['wht_id' => (int)$w['id'], 'tax_kind' => $w['tax_kind'], 'atc' => $w['atc'], 'rate' => (float)$w['rate'], 'base' => r2($base),
            'amount' => r2($base * (float)$w['rate'] / 100), 'account_id' => Withholding::account($w, $side)];
    };
    $gov = $cust('Municipality of San Isidro');
    $invGov = $invoice('Municipality of San Isidro', $d(34), [$crateLine('WCK-FC', $nga, 2), $kgLine('ACU-FZ', $nga, 10)], ['memo' => 'Feeding program, barangay day care centers']);
    $govInv = Txn::load($invGov);
    $govW = [$wtRow('WT-VAT', (float)$govInv['subtotal'], 'sales'), $wtRow('WT-GOODS', (float)$govInv['subtotal'], 'sales')];
    $govWht = r2(array_sum(array_column($govW, 'amount')));
    Txn::save('payment', ['txn_date' => $d(12), 'customer_id' => $gov, 'account_id' => $acct('1050'), 'account2_id' => Accts::get('ar'), 'payment_method_id' => $pm('Check'),
        'ref_no' => 'LBP-205511', 'total' => r2((float)$govInv['total'] - $govWht), 'withholding_amount' => $govWht, 'memo' => '5% VAT and 1% withheld; BIR Form 2307 to follow'],
        [], null, ['keep_totals' => true, 'applications' => [['target_txn_id' => $invGov, 'amount' => r2((float)$govInv['total'] - $govWht), 'withholding' => $govWht]],
            'withholdings' => [$invGov => $govW]]);

    // credit memo (spoiled delivery returned) - kept as credit; the kilos come back as loose stock
    Txn::save('credit_memo', ['txn_date' => $d(47), 'customer_id' => $lola, 'account_id' => Accts::get('ar'), 'restock' => 0, 'site_id' => $nga,
        'memo' => 'Returned 3 kg liver, not frozen on arrival', 'credit_disposition' => 'keep'], parse_item_lines([$line('LVR-FZ', 3)], 'sales', ['customer_id' => $lola]));

    // statement charge and finance charge
    Txn::save('statement_charge', ['txn_date' => $d(15), 'due_date' => $d(15), 'customer_id' => $tess, 'account_id' => Accts::get('ar'), 'memo' => 'Late payment fee'],
        parse_item_lines([$line('LATE-FEE', 1)], 'sales', ['customer_id' => $tess]));
    Txn::save('finance_charge', ['txn_date' => $d(1), 'due_date' => $d(1), 'customer_id' => $tess, 'account_id' => Accts::get('ar'), 'memo' => 'Finance charge on overdue balance'], [
        ['line_kind' => 'item', 'account_id' => Accts::get('finance_charge_income'), 'description' => 'Finance charge (12% p.a.)', 'qty' => 0, 'rate' => 0, 'amount' => 86.40, 'tax_amount' => 0],
    ]);

    // ---------------------------------------------------------------- expenses and payables
    foreach ([74, 44, 14] as $ago) {
        Txn::save('check', ['txn_date' => $d($ago), 'account_id' => $acct('1010'), 'vendor_id' => $vend('Metro Property Leasing'), 'memo' => 'Cold storage and outlet rent'], [
            array_merge($exp('6010', 95000, 'Monthly rent', $vat), ['line_kind' => 'expense', 'tax_amount' => 11400]),
        ]);
    }
    $power = $vend('Camarines Power Cooperative');
    $elec = [];
    foreach ([[60, 86450.75], [30, 92230.40]] as [$ago, $amt]) {
        $elec[] = Txn::save('bill', ['txn_date' => $d($ago), 'vendor_id' => $power, 'ref_no' => 'CPC-' . date('Ym', strtotime("-$ago days")), 'terms_id' => 1, 'due_date' => $d($ago - 10),
            'account_id' => Accts::get('ap')], [array_merge($exp('6020', $amt, 'Electricity, cold storage', $vat), ['line_kind' => 'expense', 'tax_amount' => r2($amt * 0.12)])]);
    }
    $prof = Txn::save('bill', ['txn_date' => $d(55), 'vendor_id' => $vend('Accounting Partners & Co.'), 'ref_no' => 'APC-2231', 'terms_id' => 3, 'due_date' => $d(25),
        'account_id' => Accts::get('ap'), 'memo' => 'Quarterly bookkeeping review'], [array_merge($exp('6070', 45000, 'Professional fees', $vat), ['line_kind' => 'expense', 'tax_amount' => 5400])]);
    foreach ([61, 33, 5] as $ago) {
        Txn::save('check', ['txn_date' => $d($ago), 'account_id' => $acct('1005'), 'vendor_id' => $vend('Diversion Road Fuel Station'), 'memo' => 'Diesel for the reefer truck'], [
            array_merge($exp('6050', 6800, 'Diesel', $vat), ['line_kind' => 'expense', 'tax_amount' => 816]),
        ]);
    }
    // supplier debit memo: spoiled crate returned to the supplier (taken from the oldest crate)
    Txn::save('vendor_credit', ['txn_date' => $d(57), 'vendor_id' => $npc, 'ref_no' => 'NPC-CM-331', 'account_id' => Accts::get('ap'), 'site_id' => $nga, 'memo' => 'Returned 12 kg whole chicken, warm on arrival'],
        parse_item_lines([$pline('WCK-FC', 12, null, $nga)], 'purchase'));
    // pay bills
    $nBill = (int)DB::value("SELECT id FROM transactions WHERE txn_type = 'bill' AND ref_no = 'NPC-INV-10231'");
    $nOpen = Balances::open(Txn::load($nBill));
    foreach (Balances::vendorCredits($npc) as $c) {
        DB::insert('payment_applications', ['payment_txn_id' => $c['id'], 'target_txn_id' => $nBill, 'amount' => $c['remaining']]);
        Balances::refreshApplications((int)$c['id']);
        $nOpen -= $c['remaining'];
    }
    Txn::save('bill_payment', ['txn_date' => $d(52), 'vendor_id' => $npc, 'account_id' => $acct('1010'), 'account2_id' => Accts::get('ap'), 'payment_method_id' => $pm('Check'),
        'total' => r2($nOpen), 'memo' => 'Payment of NPC-INV-10231'], [], null, ['keep_totals' => true, 'applications' => [['target_txn_id' => $nBill, 'amount' => r2($nOpen)]]]);
    $eOpen = Balances::open(Txn::load($elec[0]));
    Txn::save('bill_payment', ['txn_date' => $d(52), 'vendor_id' => $power, 'account_id' => $acct('1010'), 'account2_id' => Accts::get('ap'), 'payment_method_id' => $pm('Bank Transfer'),
        'ref_no' => 'IB-77100', 'total' => $eOpen, 'memo' => 'Electricity'], [], null, ['keep_totals' => true, 'applications' => [['target_txn_id' => $elec[0], 'amount' => $eOpen]]]);
    $profBill = Txn::load($prof);
    $profW = [$wtRow('WT-SERVICES', (float)$profBill['subtotal'], 'purchases')];
    $profWht = r2(array_sum(array_column($profW, 'amount')));
    Txn::save('bill_payment', ['txn_date' => $d(20), 'vendor_id' => $profBill['vendor_id'], 'account_id' => $acct('1010'), 'account2_id' => Accts::get('ap'), 'payment_method_id' => $pm('Check'),
        'total' => r2((float)$profBill['total'] - $profWht), 'withholding_amount' => $profWht, 'memo' => 'Payment of APC-2231, 2% withheld'], [], null,
        ['keep_totals' => true, 'applications' => [['target_txn_id' => $prof, 'amount' => r2((float)$profBill['total'] - $profWht), 'withholding' => $profWht]], 'withholdings' => [$prof => $profW]]);
    // an advance paid to a supplier before the goods come
    Txn::save('vendor_advance', ['txn_date' => $d(14), 'vendor_id' => $gpf, 'account_id' => $acct('1010'), 'account2_id' => Accts::get('vendor_advances'),
        'payment_method_id' => $pm('Check'), 'ref_no' => '1188', 'due_date' => $d(-20), 'total' => 150000, 'subtotal' => 150000, 'status' => 'open',
        'memo' => 'Advance on the holiday season allocation'], [], null, ['keep_totals' => true]);
    // voided check (audit example)
    $bad = Txn::save('check', ['txn_date' => $d(10), 'account_id' => $acct('1010'), 'payee_name' => 'Office Snacks Co.', 'memo' => 'Pantry supplies'], [
        array_merge($exp('6900', 2500, 'Pantry supplies'), ['line_kind' => 'expense', 'tax_amount' => 0]),
    ]);
    Txn::void($bad, 'Check printed with wrong payee');
    // deleted estimate (audit example)
    $tmpEst = Txn::save('estimate', ['txn_date' => $d(9), 'customer_id' => $grill, 'status' => 'pending', 'memo' => 'Duplicate quote'], parse_item_lines([$line('WCK-FC', 40)], 'sales', ['customer_id' => $grill]));
    Txn::delete($tmpEst, 'Duplicate of an existing quotation');

    // ---------------------------------------------------------------- inventory adjustments (the oldest crates give the kilos)
    Txn::save('inventory_adjustment', ['txn_date' => $d(24), 'site_id' => $nga, 'account_id' => Accts::get('inventory_adjustment'), 'memo' => 'Spoilage - freezer door left open', 'status' => 'open'], [
        ['line_kind' => 'item', 'item_id' => $item('LVR-FZ'), 'qty' => -1.5, 'description' => 'Spoilage', 'site_id' => $nga],
    ], null, ['reason' => 'Spoilage']);
    Txn::save('inventory_adjustment', ['txn_date' => $d(8), 'site_id' => $not, 'account_id' => Accts::get('inventory_adjustment'), 'memo' => 'Physical count by D. Villanueva', 'status' => 'open'], [
        ['line_kind' => 'item', 'item_id' => $item('BLB-250'), 'qty' => -2, 'description' => 'Count difference (2 packs torn)', 'site_id' => $not],
        ['line_kind' => 'item', 'item_id' => $item('PKG-BAG'), 'qty' => 50, 'description' => 'Count difference (bags found in the store room)', 'site_id' => $not],
    ], null, ['reason' => 'Physical inventory count']);

    // ---------------------------------------------------------------- banking
    Txn::save('transfer', ['txn_date' => $d(45), 'account_id' => $acct('1010'), 'account2_id' => $acct('1005'), 'total' => 15000, 'memo' => 'Replenish petty cash', 'status' => 'open'], [], null, ['keep_totals' => true]);
    $emp = demo_id('other_names', 'name', 'Glenn Abad');
    Txn::save('cash_voucher', ['txn_date' => $d(30), 'account_id' => $acct('1005'), 'other_name_id' => $emp, 'memo' => 'Toll and parking, pick-ups at Pili',
        'class_id' => $class['Head Office'], 'subtotal' => 1250, 'total' => 1250, 'status' => 'open'], [
        ['line_kind' => 'journal', 'account_id' => $acct('6100'), 'amount' => 1250, 'description' => 'Toll and parking', 'other_name_id' => $emp],
    ], null, ['keep_totals' => true]);
    Txn::save('cash_voucher', ['txn_date' => $d(12), 'account_id' => $acct('1005'), 'payee_name' => 'Tricycle fares', 'memo' => 'Small deliveries, Naga Outlet',
        'class_id' => $class['Naga Outlet'], 'subtotal' => 480, 'total' => 480, 'status' => 'open'], [
        ['line_kind' => 'journal', 'account_id' => $acct('6100'), 'amount' => 480, 'description' => 'Fares for small deliveries'],
    ], null, ['keep_totals' => true]);
    $uf = Accts::get('undeposited_funds');
    $toDeposit = DB::all("SELECT * FROM transactions WHERE txn_type IN ('payment','sales_receipt') AND account_id = :uf AND is_voided = 0 AND txn_date <= :d", ['uf' => $uf, 'd' => $d(24)]);
    $depLines = array_map(fn($t) => ['line_kind' => 'deposit', 'account_id' => $uf, 'amount' => (float)$t['total'], 'ref_txn_id' => $t['id'], 'customer_id' => $t['customer_id'],
        'description' => Txn::ref($t)], $toDeposit);
    $depLines[] = ['line_kind' => 'deposit', 'account_id' => $acct('4200'), 'amount' => 1250.00, 'description' => 'Interest on time deposit'];
    Txn::save('deposit', ['txn_date' => $d(24), 'account_id' => $acct('1010'), 'ref_no' => 'DS-1001', 'memo' => 'Deposit', 'status' => 'open'], $depLines);

    // ---------------------------------------------------------------- depreciation (two months)
    for ($i = 2; $i >= 1; $i--) {
        $y = (int)date('Y', strtotime("first day of -$i month"));
        $m = (int)date('n', strtotime("first day of -$i month"));
        DB::insert('asset_meter_readings', ['asset_id' => $scale, 'period_year' => $y, 'period_month' => $m, 'units' => $i === 2 ? 2400 : 2650, 'entered_by' => $admin]);
        Depreciation::run($y, $m);
    }

    // ---------------------------------------------------------------- bank reconciliation (first month)
    $bdo = $acct('1010');
    $recEnd = date('Y-m-t', strtotime('first day of -2 month'));
    $items = DB::all("SELECT j.txn_id, SUM(j.debit - j.credit) AS amt FROM journal_lines j WHERE j.account_id = :a AND j.txn_date <= :d GROUP BY j.txn_id", ['a' => $bdo, 'd' => $recEnd]);
    $cleared = 0.0;
    $rid = DB::insert('bank_reconciliations', ['account_id' => $bdo, 'statement_date' => $recEnd, 'beginning_balance' => 0, 'created_by' => $admin, 'status' => 'in_progress']);
    foreach ($items as $it) {
        $t = Txn::load((int)$it['txn_id']);
        $isCleared = !($t['txn_type'] === 'check' && $t['txn_date'] > date('Y-m-d', strtotime("$recEnd -5 days")));
        DB::insert('reconciliation_items', ['reconciliation_id' => $rid, 'txn_id' => $it['txn_id'], 'amount' => r2($it['amt']), 'cleared' => $isCleared ? 1 : 0]);
        if ($isCleared) {
            DB::run('UPDATE journal_lines SET cleared = 1, reconciliation_id = :r WHERE txn_id = :t AND account_id = :a', ['r' => $rid, 't' => $it['txn_id'], 'a' => $bdo]);
            $cleared += (float)$it['amt'];
        }
    }
    $svc = Txn::save('bank_charge', ['txn_date' => $recEnd, 'account_id' => $bdo, 'memo' => 'Bank service charge'], [
        ['line_kind' => 'journal', 'account_id' => $acct('6080'), 'amount' => 150, 'description' => 'Service charge'],
        ['line_kind' => 'journal', 'account_id' => $bdo, 'amount' => -150, 'description' => 'Service charge'],
    ]);
    DB::run('UPDATE journal_lines SET cleared = 1, reconciliation_id = :r WHERE txn_id = :t AND account_id = :a', ['r' => $rid, 't' => $svc, 'a' => $bdo]);
    DB::insert('reconciliation_items', ['reconciliation_id' => $rid, 'txn_id' => $svc, 'amount' => -150, 'cleared' => 1]);
    $cleared -= 150;
    DB::update('bank_reconciliations', ['ending_balance' => r2($cleared), 'cleared_balance' => r2($cleared), 'difference' => 0, 'status' => 'completed',
        'service_charge_txn_id' => $svc, 'completed_by' => $admin, 'completed_at' => date('Y-m-d H:i:s', strtotime("$recEnd +5 days"))], 'id = :id', ['id' => $rid]);
    Audit::log('reconcile', 'bank', 'reconciliation', $rid, 'BDO Checking, ' . fdate($recEnd), ['amount' => $cleared, 'page_key' => 'bank.reconcile']);

    // ---------------------------------------------------------------- point of sale at the Naga Outlet
    $term = (int)DB::value("SELECT id FROM pos_terminals WHERE code = 'POS-01'");
    $cashier = $user('cashier1');
    $super = $user('supervisor');
    $posSale = function (int $shiftId, string $date, array $rows, array $tenders, ?int $customer = null, float $tendered = 0) use ($term, $not, $sales, $class) {
        $lines = $sales($rows, $customer, $not);
        foreach ($lines as &$l) {
            $l['site_id'] = $not;
        }
        unset($l);
        $total = 0.0;
        foreach ($lines as $l) {
            $total += $l['amount'] + $l['tax_amount'];
        }
        $total = r2($total);
        $base = ['txn_date' => $date, 'site_id' => $not, 'terminal_id' => $term, 'pos_shift_id' => $shiftId, 'customer_id' => $customer, 'class_id' => $class['Naga Outlet']];
        $receipt = Pos::nextReceipt($term);
        $sid = Txn::save('pos_sale', $base + ['status' => 'suspended', 'receipt_no' => $receipt], $lines, null, ['audit_action' => 'start']);
        $left = $total;
        $cashPm = null;
        foreach ($tenders as [$pmId, $amt]) {
            if ($amt === 'cash') {
                $cashPm = $pmId;
                continue;
            }
            if ($amt === 'full') {
                $amt = r2($left);
            }
            DB::insert('pos_tenders', ['txn_id' => $sid, 'payment_method_id' => $pmId, 'amount' => $amt, 'reference' => 'APR' . mt_rand(1000, 9999)]);
            $left -= $amt;
        }
        if ($cashPm && $left > 0) {
            DB::insert('pos_tenders', ['txn_id' => $sid, 'payment_method_id' => $cashPm, 'amount' => r2($left)]);
        }
        $tend = $tendered ?: $total;
        return Txn::save('pos_sale', $base + ['status' => 'completed', 'receipt_no' => $receipt, 'amount_tendered' => $tend, 'change_given' => r2(max(0, $tend - $total))],
            $lines, $sid, ['audit_action' => 'sale']);
    };
    Auth::actAs($cashier);
    $_SESSION['pos_terminal_id'] = $term;
    $yday = $d(1);
    $shift1 = DB::insert('pos_shifts', ['terminal_id' => $term, 'cashier_id' => $cashier, 'business_date' => $yday, 'opening_float' => 3000, 'opened_at' => $yday . ' 06:55:00']);
    Audit::log('shift_open', 'pos', 'shift', $shift1, 'Naga Outlet Counter 1', ['amount' => 3000]);
    $cash = $pm('Cash');
    $s1 = $posSale($shift1, $yday, [$kgLine('WCK-FC', $not, 3.4), $kgLine('BLB-250', $not, 2)], [[$cash, 'cash']], null, 1000);
    $posSale($shift1, $yday, [$crateLine('WCK-FC', $not, 1, 170)], [[$pm('Credit/Debit Card'), 'full']], $tess);
    $posSale($shift1, $yday, [$kgLine('LVR-FZ', $not, 1.2), $kgLine('NGT-500', $not, 1)], [[$pm('GCash'), 'full']]);
    $s4 = $posSale($shift1, $yday, [$kgLine('BBD-FC', $not, 4.6)], [[$cash, 'cash']], null, 1000);
    $posSale($shift1, $yday, [$line('PARTY-PK', 1), $line('ACU-FZ', 2)], [[$cash, 'cash']], null, 1500);
    DB::insert('pos_cash_drops', ['shift_id' => $shift1, 'amount' => 2000, 'reason' => 'Excess cash to safe', 'created_by' => $cashier]);
    Audit::log('cash_drop', 'pos', 'shift', $shift1, 'Cash drop', ['amount' => 2000, 'terminal_id' => $term]);
    // the supervisor voids a sale (its kilos go back into the crate) and takes back a pack
    Auth::actAs($super);
    Txn::void($s4, 'Customer changed mind before leaving the counter', DB::row('SELECT * FROM users WHERE id = :id', ['id' => $super]));
    $saleLines = Txn::lines($s1);
    $retLine = $saleLines[1];
    $ret = Txn::save('pos_return', ['txn_date' => $yday, 'site_id' => $not, 'restock' => 1, 'terminal_id' => $term, 'pos_shift_id' => $shift1, 'source_txn_id' => $s1,
        'status' => 'suspended', 'receipt_no' => Pos::nextReceipt($term), 'memo' => 'Return: pack thawed', 'approved_by' => $super], [[
        'line_kind' => 'item', 'item_id' => $retLine['item_id'], 'description' => $retLine['description'], 'qty' => 1, 'rate' => $retLine['rate'],
        'amount' => (float)$retLine['rate'], 'tax_code_id' => $vat, 'tax_amount' => r2((float)$retLine['rate'] * 0.12), 'site_id' => $not, 'source_line_id' => $retLine['id'],
    ]], null, ['audit_action' => 'start', 'reason' => 'Pack thawed']);
    DB::insert('pos_tenders', ['txn_id' => $ret, 'payment_method_id' => $cash, 'amount' => r2((float)$retLine['rate'] * 1.12), 'reference' => 'Refund']);
    $rl = array_map(fn($l) => array_intersect_key($l, array_flip(['id', 'line_kind', 'item_id', 'description', 'qty', 'rate', 'discount_pct', 'discount_amount', 'amount', 'tax_code_id', 'tax_amount', 'site_id', 'source_line_id'])), Txn::lines($ret));
    Txn::save('pos_return', ['txn_date' => $yday, 'status' => 'completed'], $rl, $ret, ['audit_action' => 'refund', 'reason' => 'Pack thawed', 'approved_by' => 'supervisor']);
    Pos::saveReading('X', $shift1);
    $sum = Pos::summary($shift1);
    $counted = r2($sum['expected_cash'] - 20);
    $os = Txn::save('pos_over_short', ['txn_date' => $yday, 'terminal_id' => $term, 'pos_shift_id' => $shift1, 'site_id' => $not, 'memo' => 'Cash short - Naga Outlet Counter 1'], [
        ['line_kind' => 'journal', 'account_id' => $acct('1001'), 'amount' => -20, 'description' => 'Drawer count difference'],
        ['line_kind' => 'journal', 'account_id' => Accts::get('cash_over_short'), 'amount' => 20, 'description' => 'Cash over and short'],
    ]);
    Pos::saveReading('Z', $shift1, $counted);
    DB::update('pos_shifts', ['status' => 'closed', 'closed_at' => $yday . ' 19:05:00', 'closed_by' => $super, 'expected_cash' => $sum['expected_cash'],
        'counted_cash' => $counted, 'over_short' => -20, 'over_short_txn_id' => $os], 'id = :id', ['id' => $shift1]);
    Audit::log('shift_close', 'pos', 'shift', $shift1, 'Z-reading', ['amount' => $counted, 'approved_by' => 'supervisor', 'reason' => 'Short by 20.00']);
    foreach (DB::column('SELECT id FROM transactions WHERE pos_shift_id = :s ORDER BY id', ['s' => $shift1]) as $k => $tid) {
        $min = 7 * 60 + 12 + $k * 83;
        DB::run('UPDATE transactions SET created_at = :c WHERE id = :id', ['c' => $yday . ' ' . sprintf('%02d:%02d:00', min(18, intdiv($min, 60)), $min % 60), 'id' => $tid]);
    }
    // today's shift stays open
    Auth::actAs($cashier);
    $shift2 = DB::insert('pos_shifts', ['terminal_id' => $term, 'cashier_id' => $cashier, 'business_date' => today(), 'opening_float' => 3000]);
    Audit::log('shift_open', 'pos', 'shift', $shift2, 'Naga Outlet Counter 1', ['amount' => 3000]);
    $posSale($shift2, today(), [$kgLine('WCK-FC', $not, 2.8), $line('BLD', 1)], [[$cash, 'cash']], null, 1000);
    $posSale($shift2, today(), [$line('GRP-FIESTA', 1)], [[$pm('Maya'), 'full']]);
    Access::reset();
    Audit::log('access_denied', 'security', 'page', null, 'User Role Configuration (open)', ['page_key' => 'admin.roles']);
    unset($_SESSION['pos_terminal_id']);

    // ---------------------------------------------------------------- condemned stock: fresh chilled crates past expiry are written off
    // (the write-off takes the oldest crates first, so the expired ones leave the monitoring; last week's stay to be checked)
    Auth::actAs($admin);
    $old = DB::all("SELECT site_id, item_id, ROUND(SUM(qty_left), 4) AS q, COUNT(*) AS n FROM crates
                     WHERE status = 'open' AND expiry_date < :lim GROUP BY site_id, item_id ORDER BY site_id, item_id", ['lim' => $d(15)]);
    $bySite = [];
    foreach ($old as $o) {
        $bySite[(int)$o['site_id']][] = ['line_kind' => 'item', 'item_id' => (int)$o['item_id'], 'qty' => -(float)$o['q'],
            'description' => 'Condemned, ' . (int)$o['n'] . ' expired crate(s)', 'site_id' => (int)$o['site_id']];
    }
    foreach ($bySite as $siteId => $rows) {
        Txn::save('inventory_adjustment', ['txn_date' => $d(14), 'site_id' => $siteId, 'account_id' => Accts::get('inventory_adjustment'),
            'memo' => 'Expired fresh chilled stock condemned (city meat inspector present)', 'status' => 'open'], $rows, null, ['reason' => 'Spoilage']);
    }

    // ---------------------------------------------------------------- van stores (v2): loaded in the morning, selling on the road,
    // closed in the evening: what comes back goes to the cold storage, shrinkage is adjusted, shortages are charged to the salesman
    if (TransferClosing::ready() && SalesReps::ready()) {
        Auth::actAs($admin);
        $van1 = $site('VAN1');
        $van2 = $site('VAN2');
        $repId = fn(string $n) => (int)DB::value('SELECT id FROM sales_reps WHERE name = :n', ['n' => $n]);
        $rico = $repId('Rico Mendoza');
        $arnel = $repId('Arnel Cruz');
        $walkin = $cust('Walk-in Customer');
        $loose = fn(string $date, int $to, array $what, string $memo) => Txn::save('inventory_transfer', ['txn_date' => $date, 'site_id' => $nga, 'site2_id' => $to, 'status' => 'open', 'memo' => $memo],
            array_map(fn($w) => ['line_kind' => 'item', 'item_id' => $item($w[0]), 'qty' => $w[1], 'description' => (string)DB::value('SELECT name FROM items WHERE code = :c', ['c' => $w[0]]), 'site_id' => $nga], $what));
        $vanSale = function (string $date, int $siteId, int $rep, int $customer, array $rows, string $memo) use ($sales, $acct, $pm) {
            return Txn::save('sales_receipt', ['txn_date' => $date, 'customer_id' => $customer, 'account_id' => $acct('1050'), 'payment_method_id' => $pm('Cash'),
                'site_id' => $siteId, 'sales_rep_id' => $rep, 'memo' => $memo], $sales($rows, $customer, $siteId));
        };
        /** the closing as the receiver types it: everything back unless $diff says otherwise (key = item code or "code#n" for the n-th crate) */
        $close = function (string $date, int $van, int $rep, array $diff, array $people, string $memo) use ($nga, $user) {
            Auth::actAs($user('invclerk'));
            $rows = [];
            $crateN = [];
            foreach (TransferClosing::balances($van) as $b) {
                $code = (string)$b['code'];
                $key = $code;
                if ($b['crate_id']) {
                    $crateN[$code] = ($crateN[$code] ?? 0) + 1;
                    $key = $code . '#' . $crateN[$code];
                }
                $bal = (float)$b['balance'];
                [$back, $shrink, $short] = [$bal, 0.0, 0.0];
                if (isset($diff[$key])) {
                    [$kind, $q] = $diff[$key];
                    $q = $q === 'all' ? $bal : min($bal, (float)$q);
                    $back = round($bal - $q, 4);
                    if ($kind === 'shrink') {
                        $shrink = $q;
                    } else {
                        $short = $q;
                    }
                }
                $rows[] = ['item_id' => $b['item_id'], 'crate_id' => $b['crate_id'], 'balance' => $bal, 'transfer' => $back, 'shrink' => $shrink, 'shortage' => $short, 'use' => 1,
                    'note' => isset($diff[$key]) ? ($diff[$key][2] ?? '') : ''];
            }
            $id = TransferClosing::save(['closing_date' => $date, 'from_site_id' => $van, 'to_site_id' => $nga, 'sales_rep_id' => $rep, 'customer_id' => SalesReps::ensureCustomer($rep),
                'shrink_account_id' => Accts::get('inventory_adjustment'), 'shortage_account_id' => Accts::get('shortage_receivable'),
                'transferred_by' => $people[0], 'checked_by' => $people[1], 'received_by' => $people[2], 'memo' => $memo], $rows);
            Auth::actAs($user('admin'));
            return $id;
        };

        // Van Store 1, four days ago: Rico Mendoza takes crates of whole chicken, drumsticks and bola-bola, and some blood
        $move($d(4), $nga, $van1, [['WCK-FC', 3], ['DRM-FZ', 1], ['BLB-250', 1]], 'Van Store 1 load-out (Rico Mendoza)');
        $loose($d(4), $van1, [['BLD', 6]], 'Van Store 1 load-out: chicken blood');
        $vanSale($d(4), $van1, $rico, $tess, [$crateLine('WCK-FC', $van1, 1), $kgLine('DRM-FZ', $van1, 4.5)], 'Van sale, Naga public market');
        $vanSale($d(4), $van1, $rico, $walkin, [$kgLine('WCK-FC', $van1, 3.2), $line('BLD', 2), $kgLine('BLB-250', $van1, 6)], 'Van sale, Barangay Concepcion');
        // in the evening: one crate of chicken dried out a little, two packs of bola-bola and half a kilo of blood are missing
        $c1 = $close($d(4), $van1, $rico, ['WCK-FC#1' => ['shrink', 0.18, 'Drip loss'], 'BLB-250#1' => ['shortage', 2, 'Two packs not accounted for'], 'BLD' => ['shortage', 0.5]],
            ['Rico Mendoza', 'Fred Tan', 'Dan Villanueva'], 'Evening closing, Naga route');
        // Rico pays part of the shortage the next day
        $sc1 = (int)DB::value('SELECT shortage_txn_id FROM transfer_closings WHERE id = :c', ['c' => $c1]);
        if ($sc1) {
            $t1 = Txn::load($sc1);
            $half = r2((float)$t1['total'] / 2);
            $pay((int)$t1['customer_id'], $d(3), $half, [['target_txn_id' => $sc1, 'amount' => $half, 'discount' => 0, 'withholding' => 0]],
                ['payment_method_id' => $pm('Cash'), 'memo' => 'Shortage on ' . DB::value('SELECT closing_no FROM transfer_closings WHERE id = :c', ['c' => $c1]) . ', first half']);
        }

        // Van Store 2, three days ago: Arnel Cruz, the Pili route; a crate of chicken did not come back
        $move($d(3), $nga, $van2, [['WCK-FC', 2], ['BRS-FZ', 1]], 'Van Store 2 load-out (Arnel Cruz)');
        $vanSale($d(3), $van2, $arnel, $walkin, [$kgLine('BRS-FZ', $van2, 5.0), $kgLine('WCK-FC', $van2, 2.4)], 'Van sale, Pili town proper');
        $close($d(3), $van2, $arnel, ['WCK-FC#2' => ['shortage', 'all', 'Crate not returned'], 'BRS-FZ#1' => ['shrink', 0.12]],
            ['Arnel Cruz', 'Fred Tan', 'Dan Villanueva'], 'Evening closing, Pili route');

        // Van Store 1 yesterday: everything back but the weight of one crate
        $move($d(1), $nga, $van1, [['WCK-FC', 2], ['BBD-FC', 1]], 'Van Store 1 load-out (Rico Mendoza)');
        $vanSale($d(1), $van1, $rico, $walkin, [$kgLine('WCK-FC', $van1, 4.8)], 'Van sale, Barangay Triangulo');
        $close($d(1), $van1, $rico, ['BBD-FC#1' => ['shrink', 0.1]], ['Rico Mendoza', 'Fred Tan', 'Dan Villanueva'], 'Evening closing, Naga route');

        // today: Van Store 1 is out again (close it with Inventory Transfer Closing tonight)
        $move($d(0), $nga, $van1, [['WCK-FC', 2], ['DRM-FZ', 1]], 'Van Store 1 load-out (Rico Mendoza)');
        $loose($d(0), $van1, [['BLD', 4]], 'Van Store 1 load-out: chicken blood');

        // the outlet's cashier: two kilos of cut-ups short at the counter count, charged to her (Adjust Quantity/Value on Hand)
        $ella = $repId('Ella Ramos');
        $acu = $item('ACU-FZ');
        if ($ella && Stock::bookQty($acu, $not) > 2) {
            $uc = TransferClosing::unitCost($acu);
            Txn::save('shortage_charge', ['txn_date' => $d(2), 'due_date' => $d(2), 'site_id' => $not, 'customer_id' => SalesReps::ensureCustomer($ella), 'sales_rep_id' => $ella,
                'account_id' => Accts::get('shortage_receivable'), 'memo' => 'Shortage - counter count', 'status' => 'open'], [
                ['line_kind' => 'item', 'item_id' => $acu, 'qty' => 2, 'rate' => $uc, 'uom_rate' => $uc, 'amount' => r2(2 * $uc), 'site_id' => $not, 'unit' => 'kg',
                    'description' => 'Chicken Assorted Cut-Ups, Frozen, Bag (shortage: counter count)'],
            ], null, ['reason' => 'Shortage charged to Ella Ramos (counter count)']);
        }
        // shrinkage found at the cold storage count (Adjust Quantity/Value on Hand, reason Shrinkage)
        if (Stock::bookQty($item('BLD'), $nga) > 2) {
            Txn::save('inventory_adjustment', ['txn_date' => $d(2), 'site_id' => $nga, 'account_id' => Accts::get('inventory_adjustment'), 'memo' => 'Shrinkage - weekly count', 'status' => 'open'], [
                ['line_kind' => 'item', 'item_id' => $item('BLD'), 'qty' => -1.35, 'rate' => 0, 'value_change' => 0, 'site_id' => $nga, 'description' => 'Shrinkage'],
            ], null, ['reason' => 'Shrinkage']);
        }
    }

    // ---------------------------------------------------------------- v8: a dispatch gathering stock from two sites into one
    // (Dispatch Inventory, From sites: Naga Cold Storage and Legazpi Depot, To site: Reefer Truck 1), each crate going whole
    // with its own number and dates
    $rft = $site('RFT1');
    if ($rft) {
        Auth::actAs($user('invclerk') ?: $admin);
        $dlines = [];
        foreach ([[$nga, 'BRS-FZ', 1], [$lgz, 'NGT-500', 1], [$nga, 'WNG-FZ', 1]] as [$from, $code, $n]) {
            $unit = Crates::crateUnit($item($code));
            foreach ($pick($code, $from, $n) as $c) {
                $cr = DB::row('SELECT production_date, expiry_date FROM crates WHERE id = :c', ['c' => $c['id']]);
                $dlines[] = ['line_kind' => 'item', 'item_id' => $item($code), 'qty' => $c['qty'], 'description' => (string)DB::value('SELECT name FROM items WHERE code = :c', ['c' => $code]),
                    'site_id' => $from, 'uom_id' => $unit['id'], 'unit' => $unit['code'], 'uom_qty' => 1, 'uom_factor' => round($c['qty'], 6),
                    'production_date' => $cr['production_date'], 'expiry_date' => $cr['expiry_date'], '_crates' => ['dir' => 'move', 'rows' => [['id' => $c['id']]]]];
            }
        }
        if ($dlines) {
            Txn::save('inventory_dispatch', ['txn_date' => $d(0), 'site_id' => $nga, 'site2_id' => $rft, 'status' => 'open', 'memo' => 'Reefer run: the cold storage and the depot'], $dlines);
        }
        Auth::actAs($admin);
    }

    // ---------------------------------------------------------------- security examples
    $salesrep = $user('salesrep');
    $arclerk = $user('arclerk');
    DB::insert('user_page_overrides', ['user_id' => $salesrep, 'page_id' => demo_id('pages', 'page_key', 'rpt.customer_balance_summary'), 'allowed' => 1, 'can_print' => 1,
        'reason' => 'Needs balances for account visits', 'created_by' => $admin]);
    DB::insert('user_page_overrides', ['user_id' => $arclerk, 'page_id' => demo_id('pages', 'page_key', 'cust.finance_charges'), 'allowed' => 0,
        'reason' => 'Finance charges are assessed by the accountant', 'created_by' => $admin]);
    Audit::log('page_access_override', 'admin', 'user', $salesrep, 'User: salesrep', ['changes' => [['field' => 'Customer Balance Summary', 'old' => 'Inherit from role', 'new' => 'Override: allowed [P]']], 'reason' => 'Needs balances for account visits']);
    Audit::log('page_access_override', 'admin', 'user', $arclerk, 'User: arclerk', ['changes' => [['field' => 'Assess Finance Charges', 'old' => 'Inherit from role', 'new' => 'Override: denied']], 'reason' => 'Finance charges are assessed by the accountant']);
    foreach (['wrongpass1', 'wrongpass2'] as $bad) {
        Auth::attempt('apclerk', $bad);
    }
    DB::insert('entity_notes', ['entity_type' => 'customer', 'entity_id' => $tess, 'note' => 'Collect the crate deposit and the overdue balance on the next delivery', 'is_todo' => 1, 'due_date' => $d(-2), 'created_by' => $admin]);
    DB::insert('entity_notes', ['entity_type' => 'vendor', 'entity_id' => $npc, 'note' => 'Ask for a better price on whole chicken for the holiday volume', 'is_todo' => 1, 'due_date' => $d(-10), 'created_by' => $admin]);
    DB::insert('receipt_documents', ['file_path' => 'sample_fuel_receipt.txt', 'original_name' => 'Fuel_' . $d(3) . '_6800.00.txt', 'mime_type' => 'text/plain', 'source' => 'email',
        'vendor_id' => $vend('Diversion Road Fuel Station'), 'receipt_date' => $d(3), 'amount' => 6800.00, 'account_id' => $acct('6050'), 'uploaded_by' => $admin]);

    // books closed through the opening balance date
    Settings::set('closing_date', $d(80));
    Audit::log('closing_date_change', 'admin', 'settings', null, 'Closing date', ['changes' => [['field' => 'closing_date', 'old' => '', 'new' => $d(80)]], 'reason' => 'Opening balances finalized']);
}
