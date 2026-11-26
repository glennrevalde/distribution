<?php
declare(strict_types=1);

/*
 * Distribution reports: crates on hand, the kilos in each crate, crates sold with their production and expiry
 * dates, the history of every crate, the crates received by supplier, and supplier allocations against what
 * was picked up.
 */

/** The site restriction of the user, for crate queries: [sql, params] */
function dist_site_sql(string $col): array
{
    return Access::siteFilter($col, 'ds');
}

Report::define('crates_on_hand', [
    'filters' => ['site', 'item'],
    'filter_labels' => ['site' => 'Site'],
    'checks' => ['with_loose' => 'Show the loose kilos (stock not in crates) beside the crates'],
    'run' => function (array $f): array {
        [$sf, $sp] = dist_site_sql('c.site_id');
        $p = $sp;
        $w = "c.status = 'open'";
        if ($f['site_id']) {
            $w .= ' AND c.site_id = :s';
            $p['s'] = $f['site_id'];
        }
        if ($f['item_id']) {
            $w .= ' AND c.item_id = :i';
            $p['i'] = $f['item_id'];
        }
        $rows = [];
        $tot = ['item' => 'TOTAL', 'crates' => 0, 'pcs' => 0.0, 'qty' => 0.0, 'loose' => 0.0, 'onhand' => 0.0];
        $chart = [];
        foreach (DB::all("SELECT c.item_id, c.site_id, i.code, i.name, s.name AS site, us.base_unit, COUNT(*) AS n, SUM(c.pcs) AS pcs, SUM(c.qty_left) AS q,
                                 MIN(c.expiry_date) AS exp, MIN(c.received_date) AS oldest
                            FROM crates c JOIN items i ON i.id = c.item_id JOIN sites s ON s.id = c.site_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                           WHERE $w $sf GROUP BY c.item_id, c.site_id, i.code, i.name, s.name, us.base_unit ORDER BY i.code, s.name", $p) as $r) {
            $onHand = Stock::bookQty((int)$r['item_id'], (int)$r['site_id']);
            $loose = round($onHand - (float)$r['q'], 4);
            $days = $r['exp'] ? (int)floor((strtotime($r['exp']) - strtotime(today())) / 86400) : null;
            $rows[] = [
                'item' => $r['code'], 'desc' => $r['name'], 'site' => $r['site'], 'crates' => (int)$r['n'], 'pcs' => (float)$r['pcs'],
                'qty' => round((float)$r['q'], 4), 'unit' => $r['base_unit'] ?: 'kg', 'avg' => (int)$r['n'] ? round((float)$r['q'] / (int)$r['n'], 4) : 0,
                'loose' => max(0.0, $loose), 'onhand' => $onHand, 'exp' => $r['exp'], 'days' => $days, 'oldest' => $r['oldest'],
                '_links' => ['item' => Report::link('inv.crates', ['item_id' => $r['item_id'], 'site_id' => $r['site_id']]),
                    'crates' => Report::link('rpt.crate_detail', ['item_id' => $r['item_id'], 'site_id' => $r['site_id']])],
                '_class' => $days !== null && $days < 0 ? 'lot-expired-row' : ($days !== null && $days <= 3 ? 'lot-expiring-row' : ''),
            ];
            $tot['crates'] += (int)$r['n'];
            $tot['pcs'] += (float)$r['pcs'];
            $tot['qty'] += (float)$r['q'];
            $tot['loose'] += max(0.0, $loose);
            $tot['onhand'] += $onHand;
            $chart[$r['code']] = ($chart[$r['code']] ?? 0) + (int)$r['n'];
        }
        $cols = [['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description'], ['key' => 'site', 'label' => 'Site'],
            ['key' => 'crates', 'label' => 'Crates left', 'type' => 'int'], ['key' => 'pcs', 'label' => 'Heads', 'type' => 'qty', 'optional' => true],
            ['key' => 'qty', 'label' => 'Kilos in crates', 'type' => 'kg'], ['key' => 'unit', 'label' => 'U/M'], ['key' => 'avg', 'label' => 'Average per crate', 'type' => 'kg']];
        if (!empty($f['with_loose'])) {
            $cols[] = ['key' => 'loose', 'label' => 'Loose', 'type' => 'kg'];
            $cols[] = ['key' => 'onhand', 'label' => 'Total on hand', 'type' => 'kg'];
        }
        $cols[] = ['key' => 'exp', 'label' => 'Earliest expiry', 'type' => 'date'];
        $cols[] = ['key' => 'days', 'label' => 'Days left', 'type' => 'int'];
        $cols[] = ['key' => 'oldest', 'label' => 'Oldest crate received', 'type' => 'date', 'optional' => true];
        return [
            'columns' => $cols, 'rows' => $rows, 'totals' => $tot,
            'chart' => $chart ? ['bars' => $chart, 'bars_title' => 'Crates left by item', 'bars_format' => 'int'] : null,
            'notes' => 'Open crates on hand now, by item and site: how many are left, the kilos (or packs) in them and the average per crate. '
                . 'Crates converted to kilos are counted as loose stock.',
        ];
    },
]);

Report::define('crate_detail', [
    'filters' => ['site', 'item'],
    'extra_filters' => [
        'cstatus' => ['Crates', fn() => ['open' => 'Open (on hand)', 'sold' => 'Sold out', 'used' => 'Used up (adjusted, shrinkage, shortage)', 'converted' => 'Converted to kilos', 'all' => 'All'], null],
    ],
    'run' => function (array $f): array {
        [$sf, $sp] = dist_site_sql('c.site_id');
        $p = $sp;
        $status = ($f['cstatus'] ?? '') !== '' ? $f['cstatus'] : 'open';
        $w = '1 = 1';
        if ($status !== 'all') {
            $w .= ' AND c.status = :st';
            $p['st'] = $status;
        }
        if ($f['site_id']) {
            $w .= ' AND c.site_id = :s';
            $p['s'] = $f['site_id'];
        }
        if ($f['item_id']) {
            $w .= ' AND c.item_id = :i';
            $p['i'] = $f['item_id'];
        }
        $rows = [];
        $lastKey = null;
        $sub = null;
        $tot = ['item' => 'TOTAL', 'crate' => 0, 'pcs' => 0.0, 'qty_in' => 0.0, 'qty_left' => 0.0];
        $flush = function () use (&$rows, &$sub) {
            if ($sub) {
                $rows[] = $sub + ['_class' => 'subtotal-row'];
            }
        };
        foreach (DB::all("SELECT c.*, i.code, i.name, s.name AS site, us.base_unit, v.name AS vendor
                            FROM crates c JOIN items i ON i.id = c.item_id JOIN sites s ON s.id = c.site_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                            LEFT JOIN vendors v ON v.id = c.vendor_id
                           WHERE $w $sf ORDER BY i.code, s.name, (c.expiry_date IS NULL), c.expiry_date, c.id LIMIT 5000", $p) as $c) {
            $key = $c['item_id'] . ':' . $c['site_id'];
            if ($key !== $lastKey) {
                $flush();
                $rows[] = ['item' => $c['code'] . ' ' . $c['name'] . ', ' . $c['site'], '_class' => 'group-row'];
                $sub = ['item' => 'Total ' . $c['code'], 'crate' => 0, 'pcs' => 0.0, 'qty_in' => 0.0, 'qty_left' => 0.0];
                $lastKey = $key;
            }
            $days = $c['expiry_date'] ? (int)floor((strtotime($c['expiry_date']) - strtotime(today())) / 86400) : null;
            $rows[] = [
                'item' => '', 'crate' => $c['crate_no'], 'pcs' => (float)$c['pcs'], 'qty_in' => (float)$c['qty_in'], 'qty_left' => (float)$c['qty_left'], 'unit' => $c['base_unit'] ?: 'kg',
                'prod' => $c['production_date'], 'exp' => $c['expiry_date'], 'days' => $days, 'received' => $c['received_date'], 'vendor' => $c['vendor'],
                'status' => Crates::statusText($c['status']),
                '_links' => ['crate' => Report::link('inv.crates', ['a' => 'view', 'id' => $c['id']])], '_class' => 'indent-1',
            ];
            $sub['crate']++;
            $sub['pcs'] += (float)$c['pcs'];
            $sub['qty_in'] += (float)$c['qty_in'];
            $sub['qty_left'] += (float)$c['qty_left'];
            $tot['crate']++;
            $tot['pcs'] += (float)$c['pcs'];
            $tot['qty_in'] += (float)$c['qty_in'];
            $tot['qty_left'] += (float)$c['qty_left'];
        }
        $flush();
        return [
            'sortable' => false,
            'columns' => [['key' => 'item', 'label' => 'Item'], ['key' => 'crate', 'label' => 'Crate no.'], ['key' => 'pcs', 'label' => 'Heads', 'type' => 'qty'],
                ['key' => 'qty_in', 'label' => 'Kilos received', 'type' => 'kg'], ['key' => 'qty_left', 'label' => 'Kilos left', 'type' => 'kg'], ['key' => 'unit', 'label' => 'U/M'],
                ['key' => 'prod', 'label' => 'Production date', 'type' => 'date'], ['key' => 'exp', 'label' => 'Expiry date', 'type' => 'date'], ['key' => 'days', 'label' => 'Days left', 'type' => 'int'],
                ['key' => 'received', 'label' => 'Received', 'type' => 'date'], ['key' => 'vendor', 'label' => 'Supplier', 'optional' => true], ['key' => 'status', 'label' => 'Status']],
            'rows' => $rows, 'totals' => $tot,
            'notes' => 'Each crate of each item, with the kilos (or packs) it came with and what is left in it. The crate number counts the crates in the subtotals.',
        ];
    },
]);

Report::define('crates_sold', [
    'filters' => ['range', 'site', 'item', 'customer'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        [$sf, $sp] = dist_site_sql('m.site_id');
        $p = $sp + ['f' => $f['from'], 't' => $f['to']];
        $w = "m.kind = 'sale' AND m.move_date BETWEEN :f AND :t AND tx.is_voided = 0";
        if ($f['site_id']) {
            $w .= ' AND m.site_id = :s';
            $p['s'] = $f['site_id'];
        }
        if ($f['item_id']) {
            $w .= ' AND c.item_id = :i';
            $p['i'] = $f['item_id'];
        }
        if ($f['customer_id']) {
            $w .= ' AND m.customer_id = :cu';
            $p['cu'] = $f['customer_id'];
        }
        $rows = [];
        $tot = ['date' => 'TOTAL', 'qty' => 0.0];
        $whole = 0;
        foreach (DB::all("SELECT m.*, c.crate_no, c.qty_in, c.production_date, c.expiry_date, c.pcs, i.code, i.name, us.base_unit, cu.name AS customer, tx.txn_type, tx.txn_no, s.name AS site
                            FROM crate_movements m JOIN crates c ON c.id = m.crate_id JOIN items i ON i.id = c.item_id JOIN transactions tx ON tx.id = m.txn_id
                            LEFT JOIN uom_sets us ON us.id = i.uom_set_id LEFT JOIN customers cu ON cu.id = m.customer_id LEFT JOIN sites s ON s.id = m.site_id
                           WHERE $w $sf ORDER BY m.move_date, m.id", $p) as $r) {
            $days = $r['expiry_date'] ? (int)floor((strtotime($r['expiry_date']) - strtotime($r['move_date'])) / 86400) : null;
            $rows[] = [
                'date' => $r['move_date'], 'doc' => Txn::label($r['txn_type']) . ' ' . $r['txn_no'], 'customer' => $r['customer'] ?: 'Walk-in', 'site' => $r['site'],
                'item' => $r['code'], 'desc' => $r['name'], 'crate' => $r['crate_no'], 'how' => (int)$r['whole'] ? 'Whole crate' : 'Part of the crate',
                'qty' => (float)$r['qty'], 'unit' => $r['base_unit'] ?: 'kg', 'qty_in' => (float)$r['qty_in'], 'prod' => $r['production_date'], 'exp' => $r['expiry_date'], 'days' => $days,
                '_links' => ['doc' => Report::txnLink(['txn_type' => $r['txn_type'], 'txn_id' => $r['txn_id']]), 'crate' => Report::link('inv.crates', ['a' => 'view', 'id' => $r['crate_id']])],
                '_class' => $days !== null && $days < 0 ? 'lot-expired-row' : '',
            ];
            $tot['qty'] += (float)$r['qty'];
            $whole += (int)$r['whole'];
        }
        return [
            'columns' => [['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'doc', 'label' => 'Document'], ['key' => 'customer', 'label' => 'Customer'],
                ['key' => 'site', 'label' => 'Site', 'optional' => true], ['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description', 'optional' => true],
                ['key' => 'crate', 'label' => 'Crate no.'], ['key' => 'how', 'label' => 'Sold'], ['key' => 'qty', 'label' => 'Kilos sold', 'type' => 'kg'], ['key' => 'unit', 'label' => 'U/M'],
                ['key' => 'qty_in', 'label' => 'Crate held', 'type' => 'kg', 'optional' => true], ['key' => 'prod', 'label' => 'Production date', 'type' => 'date'],
                ['key' => 'exp', 'label' => 'Expiry date', 'type' => 'date'], ['key' => 'days', 'label' => 'Days to expiry when sold', 'type' => 'int']],
            'rows' => $rows, 'totals' => $tot,
            'notes' => 'Every crate sold from ' . fdate($f['from']) . ' to ' . fdate($f['to']) . ' on invoices, sales receipts and the POS: whole crates and kilos taken out of a crate, '
                . 'with the production and expiry dates of the crate. ' . $whole . ' whole crate(s) in the period.',
        ];
    },
]);

Report::define('crate_movements', [
    'filters' => ['range', 'site', 'item'],
    'default_dates' => 'this_month',
    'extra_filters' => [
        'kind' => ['What happened', fn() => ['receive' => 'Received', 'sale' => 'Sold', 'auto' => 'Taken automatically', 'transfer' => 'Moved', 'convert' => 'Converted to kilos', 'shrink' => 'Shrinkage', 'shortage' => 'Shortage charged', 'adjust' => 'Adjusted', 'pack' => 'Filled from loose stock', 'dates' => 'Dates given'], 'Everything'],
    ],
    'run' => function (array $f): array {
        [$sf, $sp] = dist_site_sql('c.site_id');
        $p = $sp + ['f' => $f['from'], 't' => $f['to']];
        $w = 'm.move_date BETWEEN :f AND :t';
        if ($f['site_id']) {
            $w .= ' AND (m.site_id = :s OR m.site2_id = :s2)';
            $p['s'] = $f['site_id'];
            $p['s2'] = $f['site_id'];
        }
        if ($f['item_id']) {
            $w .= ' AND c.item_id = :i';
            $p['i'] = $f['item_id'];
        }
        if (($f['kind'] ?? '') !== '') {
            $w .= ' AND m.kind = :k';
            $p['k'] = $f['kind'];
        }
        $rows = [];
        foreach (DB::all("SELECT m.*, c.crate_no, i.code, i.name, us.base_unit, tx.txn_type, tx.txn_no, cu.name AS customer, s1.name AS site, s2.name AS site2, u.full_name AS user
                            FROM crate_movements m JOIN crates c ON c.id = m.crate_id JOIN items i ON i.id = c.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                            LEFT JOIN transactions tx ON tx.id = m.txn_id LEFT JOIN customers cu ON cu.id = m.customer_id
                            LEFT JOIN sites s1 ON s1.id = m.site_id LEFT JOIN sites s2 ON s2.id = m.site2_id LEFT JOIN users u ON u.id = m.created_by
                           WHERE $w $sf ORDER BY m.move_date, m.id LIMIT 10000", $p) as $r) {
            $rows[] = [
                'date' => $r['move_date'], 'crate' => $r['crate_no'], 'item' => $r['code'], 'desc' => $r['name'], 'what' => Crates::kindText($r['kind']) . (in_array($r['kind'], ['sale', 'shrink', 'shortage'], true) ? ((int)$r['whole'] ? ', whole' : ', part') : ($r['kind'] === 'adjust' ? ((float)$r['qty'] < 0 ? ', up' : ((int)$r['whole'] ? ', down to 0' : ', down')) : '')),
                'doc' => $r['txn_no'] ? Txn::label($r['txn_type']) . ' ' . $r['txn_no'] : '', 'who' => $r['kind'] === 'transfer' ? $r['site'] . ' to ' . $r['site2'] : ($r['customer'] ?: $r['site']),
                'in' => $r['kind'] === 'receive' || $r['kind'] === 'pack' ? (float)$r['qty'] : ($r['kind'] === 'adjust' && (float)$r['qty'] < 0 ? -(float)$r['qty'] : 0.0),
                'out' => in_array($r['kind'], Crates::TAKE_KINDS, true) && (float)$r['qty'] > 0 ? (float)$r['qty'] : 0.0, 'unit' => $r['base_unit'] ?: 'kg',
                'note' => $r['note'], 'user' => $r['user'],
                '_links' => ['crate' => Report::link('inv.crates', ['a' => 'view', 'id' => $r['crate_id']]), 'doc' => $r['txn_id'] ? Report::txnLink(['txn_type' => $r['txn_type'], 'txn_id' => $r['txn_id']]) : null],
            ];
        }
        $in = array_sum(array_column($rows, 'in'));
        $out = array_sum(array_column($rows, 'out'));
        return [
            'columns' => [['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'crate', 'label' => 'Crate no.'], ['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description', 'optional' => true],
                ['key' => 'what', 'label' => 'What happened'], ['key' => 'doc', 'label' => 'Document'], ['key' => 'who', 'label' => 'Customer / site'],
                ['key' => 'in', 'label' => 'In', 'type' => 'kg'], ['key' => 'out', 'label' => 'Out', 'type' => 'kg'], ['key' => 'unit', 'label' => 'U/M'],
                ['key' => 'note', 'label' => 'Note', 'optional' => true], ['key' => 'user', 'label' => 'By', 'optional' => true]],
            'rows' => $rows, 'totals' => ['date' => 'TOTAL', 'in' => $in, 'out' => $out],
            'notes' => 'Everything that happened to the crates from ' . fdate($f['from']) . ' to ' . fdate($f['to']) . '. "Taken automatically" is stock taken out without naming a crate '
                . '(an adjustment, a build, a return to the supplier): the oldest crate gives it first.',
        ];
    },
]);

Report::define('crates_received', [
    'filters' => ['range', 'site', 'vendor', 'item'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        [$sf, $sp] = dist_site_sql('m.site_id');
        $p = $sp + ['f' => $f['from'], 't' => $f['to']];
        $w = "m.kind = 'receive' AND m.move_date BETWEEN :f AND :t";
        if ($f['site_id']) {
            $w .= ' AND m.site_id = :s';
            $p['s'] = $f['site_id'];
        }
        if ($f['vendor_id']) {
            $w .= ' AND c.vendor_id = :v';
            $p['v'] = $f['vendor_id'];
        }
        if ($f['item_id']) {
            $w .= ' AND c.item_id = :i';
            $p['i'] = $f['item_id'];
        }
        $rows = [];
        $last = null;
        $sub = null;
        $tot = ['vendor' => 'TOTAL', 'crates' => 0, 'pcs' => 0.0, 'qty' => 0.0, 'value' => 0.0];
        $data = DB::all("SELECT m.move_date, m.txn_id, c.vendor_id, v.name AS vendor, tx.txn_type, tx.txn_no, i.code, i.name, us.base_unit, COUNT(*) AS n, SUM(c.pcs) AS pcs, SUM(m.qty) AS q,
                                SUM(m.qty * c.unit_cost) AS val, MIN(c.production_date) AS prod, MIN(c.expiry_date) AS exp
                           FROM crate_movements m JOIN crates c ON c.id = m.crate_id JOIN items i ON i.id = c.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                           LEFT JOIN vendors v ON v.id = c.vendor_id LEFT JOIN transactions tx ON tx.id = m.txn_id
                          WHERE $w $sf GROUP BY m.move_date, m.txn_id, c.vendor_id, v.name, tx.txn_type, tx.txn_no, i.code, i.name, us.base_unit
                          ORDER BY v.name, m.move_date, tx.txn_no, i.code", $p);
        foreach ($data as $r) {
            if ($r['vendor_id'] !== $last) {
                if ($sub) {
                    $rows[] = $sub + ['_class' => 'subtotal-row'];
                }
                $rows[] = ['vendor' => $r['vendor'] ?: 'No supplier', '_class' => 'group-row'];
                $sub = ['vendor' => 'Total ' . ($r['vendor'] ?: 'no supplier'), 'crates' => 0, 'pcs' => 0.0, 'qty' => 0.0, 'value' => 0.0];
                $last = $r['vendor_id'];
            }
            $rows[] = ['vendor' => '', 'date' => $r['move_date'], 'doc' => $r['txn_no'] ? Txn::label($r['txn_type']) . ' ' . $r['txn_no'] : '', 'item' => $r['code'], 'desc' => $r['name'],
                'crates' => (int)$r['n'], 'pcs' => (float)$r['pcs'], 'qty' => (float)$r['q'], 'unit' => $r['base_unit'] ?: 'kg', 'avg' => (int)$r['n'] ? round((float)$r['q'] / (int)$r['n'], 4) : 0,
                'value' => r2((float)$r['val']), 'prod' => $r['prod'], 'exp' => $r['exp'], '_class' => 'indent-1',
                '_links' => ['doc' => $r['txn_id'] ? Report::txnLink(['txn_type' => $r['txn_type'], 'txn_id' => $r['txn_id']]) : null]];
            foreach (['crates', 'pcs', 'qty'] as $k) {
                $sub[$k] += $k === 'crates' ? (int)$r['n'] : (float)($k === 'pcs' ? $r['pcs'] : $r['q']);
                $tot[$k] += $k === 'crates' ? (int)$r['n'] : (float)($k === 'pcs' ? $r['pcs'] : $r['q']);
            }
            $sub['value'] += r2((float)$r['val']);
            $tot['value'] += r2((float)$r['val']);
        }
        if ($sub) {
            $rows[] = $sub + ['_class' => 'subtotal-row'];
        }
        return [
            'sortable' => false,
            'columns' => [['key' => 'vendor', 'label' => 'Supplier'], ['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'doc', 'label' => 'Document'],
                ['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description', 'optional' => true], ['key' => 'crates', 'label' => 'Crates', 'type' => 'int'],
                ['key' => 'pcs', 'label' => 'Heads', 'type' => 'qty'], ['key' => 'qty', 'label' => 'Kilos', 'type' => 'kg'], ['key' => 'unit', 'label' => 'U/M'],
                ['key' => 'avg', 'label' => 'Average per crate', 'type' => 'kg'], ['key' => 'value', 'label' => 'Cost', 'type' => 'money', 'sensitive' => 'cost'],
                ['key' => 'prod', 'label' => 'Production date', 'type' => 'date', 'optional' => true], ['key' => 'exp', 'label' => 'Earliest expiry', 'type' => 'date', 'optional' => true]],
            'rows' => $rows, 'totals' => $tot,
            'notes' => 'Crates received from each supplier from ' . fdate($f['from']) . ' to ' . fdate($f['to']) . ', by document and item, with the heads, the kilos and the average weight per crate.',
        ];
    },
]);

Report::define('alloc_pickup', [
    'filters' => ['range', 'site', 'vendor', 'item'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        [$sf, $sp] = dist_site_sql('a.site_id');
        $p = $sp + ['f' => $f['from'], 't' => $f['to']];
        $w = "a.alloc_date BETWEEN :f AND :t AND a.status <> 'cancelled'";
        if ($f['site_id']) {
            $w .= ' AND a.site_id = :s';
            $p['s'] = $f['site_id'];
        }
        if ($f['vendor_id']) {
            $w .= ' AND a.vendor_id = :v';
            $p['v'] = $f['vendor_id'];
        }
        if ($f['item_id']) {
            $w .= ' AND l.item_id = :i';
            $p['i'] = $f['item_id'];
        }
        $rows = [];
        $tot = ['date' => 'TOTAL', 'alloc' => 0.0, 'picked' => 0.0, 'qty' => 0.0];
        foreach (DB::all("SELECT a.alloc_date, a.alloc_no, a.status, a.id AS alloc_id, a.receipt_txn_id, v.name AS vendor, s.name AS site, COALESCE(u.username, a.assigned_to) AS assigned,
                                 i.code, i.name, l.unit_code, l.qty, l.picked_count, l.picked_qty, uu.is_variable, us.base_unit
                            FROM supplier_allocation_lines l JOIN supplier_allocations a ON a.id = l.allocation_id JOIN vendors v ON v.id = a.vendor_id
                            JOIN sites s ON s.id = a.site_id JOIN items i ON i.id = l.item_id LEFT JOIN users u ON u.id = a.assigned_user_id
                            LEFT JOIN uom_units uu ON uu.id = l.uom_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                           WHERE $w $sf ORDER BY a.alloc_date, v.name, a.alloc_no, l.line_no", $p) as $r) {
            $picked = (float)$r['picked_count'];
            $diff = round($picked - (float)$r['qty'], 4);
            $rows[] = [
                'date' => $r['alloc_date'], 'no' => $r['alloc_no'], 'vendor' => $r['vendor'], 'site' => $r['site'], 'assigned' => $r['assigned'],
                'item' => $r['code'], 'desc' => $r['name'], 'unit' => $r['unit_code'], 'alloc' => (float)$r['qty'], 'picked' => $picked, 'diff' => $diff,
                'qty' => (float)$r['picked_qty'], 'base' => $r['base_unit'] ?: 'kg', 'status' => Allocations::statusText($r['status']),
                '_links' => ['no' => Report::link('vend.allocations', ['a' => 'edit', 'id' => $r['alloc_id']])],
                '_class' => abs($diff) > 0.00005 && $r['status'] === 'received' ? 'lot-expiring-row' : '',
            ];
            $tot['alloc'] += (float)$r['qty'];
            $tot['picked'] += $picked;
            $tot['qty'] += (float)$r['picked_qty'];
        }
        return [
            'columns' => [['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'no', 'label' => 'Allocation'], ['key' => 'vendor', 'label' => 'Supplier'], ['key' => 'site', 'label' => 'Location'],
                ['key' => 'assigned', 'label' => 'Assigned to', 'optional' => true], ['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description', 'optional' => true],
                ['key' => 'unit', 'label' => 'Unit'], ['key' => 'alloc', 'label' => 'Allocated', 'type' => 'qty'], ['key' => 'picked', 'label' => 'Picked up', 'type' => 'qty'],
                ['key' => 'diff', 'label' => 'Difference', 'type' => 'qty'], ['key' => 'qty', 'label' => 'Kilos picked up', 'type' => 'kg'], ['key' => 'base', 'label' => 'U/M'],
                ['key' => 'status', 'label' => 'Status']],
            'rows' => $rows, 'totals' => $tot + ['diff' => round($tot['picked'] - $tot['alloc'], 4)],
            'notes' => 'What was allocated against what was picked up, line by line, from ' . fdate($f['from']) . ' to ' . fdate($f['to']) . '. Crates for lines in crates, else kilos or packs.',
        ];
    },
]);

// ---------------------------------------------------------------------------------------------------- v8: transfers

/**
 * v8: the stock sent out by Transfer Inventory and Dispatch Inventory (a dispatch may gather it from many sites), one
 * row per document line, site and date group it left: where it left from, where it went, its production and expiry
 * dates, how many days it had left when it was sent, the crates and the quantity. Filters: dates, the site it left
 * (Site), the site it went to, the item, and which documents.
 */
function dist_transfer_rows(array $f): array
{
    [$sf, $sp] = Access::siteFilter('m.site_id', 'tm');
    $p = $sp + ['f' => $f['from'], 't' => $f['to']];
    $types = ($f['doc'] ?? '') === 'dispatch' ? "('inventory_dispatch')" : (($f['doc'] ?? '') === 'transfer' ? "('inventory_transfer')" : "('inventory_transfer', 'inventory_dispatch')");
    $w = "t.txn_type IN $types AND t.is_voided = 0 AND m.qty < 0 AND t.txn_date BETWEEN :f AND :t";
    if ($f['site_id']) {
        $w .= ' AND m.site_id = :s';
        $p['s'] = $f['site_id'];
    }
    if ((int)($f['to_site'] ?? 0) > 0) {
        $w .= ' AND t.site2_id = :s2';
        $p['s2'] = (int)$f['to_site'];
    }
    if ($f['item_id']) {
        $w .= ' AND m.item_id = :i';
        $p['i'] = $f['item_id'];
    }
    $rows = DB::all("SELECT m.txn_id, m.txn_line_id, t.txn_type, t.txn_no, t.txn_date, m.site_id, t.site2_id, m.item_id, i.code, i.name,
                            COALESCE(NULLIF(us.base_unit, ''), NULLIF(i.unit, ''), '') AS unit, m.production_date AS p, m.expiry_date AS e,
                            -SUM(m.qty) AS q, -SUM(m.total_cost) AS v
                       FROM inventory_movements m JOIN transactions t ON t.id = m.txn_id JOIN items i ON i.id = m.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                      WHERE $w $sf
                      GROUP BY m.txn_id, m.txn_line_id, t.txn_type, t.txn_no, t.txn_date, m.site_id, t.site2_id, m.item_id, i.code, i.name, us.base_unit, i.unit, m.production_date, m.expiry_date
                      ORDER BY t.txn_date, t.id, m.txn_line_id LIMIT 20000", $p);
    // the crates moved with each line, by their dates (a line of crates may hold more than one date group)
    $crates = [];
    if ($rows && Crates::ready()) {
        foreach (array_chunk(array_values(array_unique(array_map(fn($r) => (int)$r['txn_id'], $rows))), 500) as $chunk) {
            [$in, $ip] = DB::in('tc', $chunk);
            foreach (DB::all("SELECT m.txn_id, m.line_id, m.site_id, c.production_date AS p, c.expiry_date AS e, COUNT(*) AS n
                                FROM crate_movements m JOIN crates c ON c.id = m.crate_id
                               WHERE m.kind = 'transfer' AND m.txn_id IN $in GROUP BY m.txn_id, m.line_id, m.site_id, c.production_date, c.expiry_date", $ip) as $c) {
                $crates[$c['txn_id'] . ':' . $c['line_id'] . ':' . $c['site_id']][Lots::key($c['p'] ?: null, $c['e'] ?: null)] = (int)$c['n'];
            }
        }
    }
    $sites = DB::pairs('SELECT id, name FROM sites');
    // the date groups each line left in: the crates whose dates match none of them count on the line's first row
    $keysOf = [];
    foreach ($rows as $r) {
        $keysOf[$r['txn_id'] . ':' . $r['txn_line_id'] . ':' . $r['site_id']][Lots::key($r['p'] ?: null, $r['e'] ?: null)] = true;
    }
    $seen = [];
    $out = [];
    foreach ($rows as $r) {
        $ck = $r['txn_id'] . ':' . $r['txn_line_id'] . ':' . $r['site_id'];
        $key = Lots::key($r['p'] ?: null, $r['e'] ?: null);
        $n = $crates[$ck][$key] ?? 0;
        if (!isset($seen[$ck])) {
            $n += array_sum(array_diff_key($crates[$ck] ?? [], $keysOf[$ck]));
            $seen[$ck] = true;
        }
        $days = $r['e'] ? (int)round((strtotime($r['e']) - strtotime($r['txn_date'])) / 86400) : null;
        $out[] = [
            'txn_id' => (int)$r['txn_id'], 'txn_type' => $r['txn_type'], 'date' => $r['txn_date'], 'doc' => (string)$r['txn_no'],
            'site_id' => (int)$r['site_id'], 'site' => (string)($sites[$r['site_id']] ?? ''), 'site2_id' => (int)$r['site2_id'], 'to' => (string)($sites[$r['site2_id']] ?? ''),
            'item_id' => (int)$r['item_id'], 'code' => (string)$r['code'], 'name' => (string)$r['name'], 'unit' => (string)$r['unit'] ?: 'unit',
            'prod' => $r['p'], 'exp' => $r['e'], 'days' => $days, 'crates' => $n, 'qty' => round((float)$r['q'], 4), 'value' => r2((float)$r['v']),
        ];
    }
    return $out;
}

/** v8: a detail row of a transfer report (the columns both reports share) */
function dist_transfer_cells(array $r): array
{
    return [
        'date' => $r['date'], 'doc' => $r['doc'], 'site' => $r['site'], 'item' => $r['code'], 'desc' => $r['name'], 'to' => $r['to'],
        'prod' => $r['prod'], 'exp' => $r['exp'], 'days' => $r['days'], 'crates' => $r['crates'] ?: '', 'qty' => $r['qty'], 'unit' => $r['unit'], 'value' => $r['value'],
        '_html' => ['site' => SiteMark::html($r['site_id'], $r['site'])],
        '_links' => ['doc' => Report::txnLink(['txn_type' => $r['txn_type'], 'txn_id' => $r['txn_id']])],
        '_class' => $r['days'] !== null && $r['days'] < 0 ? 'lot-expired-row' : ($r['days'] !== null && $r['days'] <= 3 ? 'lot-expiring-row' : ''),
    ];
}

/** v8: the subtotal (or total) of some rows: crates, value, and the quantity when they share one unit */
function dist_transfer_sum(array $rows, array $base): array
{
    $units = array_values(array_unique(array_column($rows, 'unit')));
    $byUnit = [];
    foreach ($rows as $r) {
        $byUnit[$r['unit']] = ($byUnit[$r['unit']] ?? 0.0) + $r['qty'];
    }
    return $base + [
        'crates' => array_sum(array_column($rows, 'crates')) ?: '',
        'qty' => count($units) === 1 ? round($byUnit[$units[0]], 4) : '',
        'unit' => count($units) === 1 ? $units[0] : implode(', ', array_map(fn($u, $q) => Crates::fig($q, (string)$u) . ' ' . $u, array_keys($byUnit), $byUnit)),
        'value' => r2(array_sum(array_column($rows, 'value'))),
    ];
}

function dist_transfer_def(string $by): array
{
    return [
        'filters' => ['range', 'site', 'item'],
        'filter_labels' => ['site' => 'From site'],
        'default_dates' => 'this_month',
        'sortable' => false,
        'extra_filters' => [
            'to_site' => ['To site', fn() => Lookup::sites(false), 'All'],
            'doc' => ['Documents', fn() => ['dispatch' => 'Dispatch Inventory', 'transfer' => 'Transfer Inventory'], 'Both'],
        ],
        'run' => function (array $f) use ($by): array {
            $all = dist_transfer_rows($f);
            $groups = [];
            foreach ($all as $r) {
                $k = $by === 'site' ? $r['site'] . "\0" . $r['site_id'] : $r['code'];
                $groups[$k][] = $r;
            }
            ksort($groups, SORT_NATURAL | SORT_FLAG_CASE);
            $rows = [];
            $chart = [];
            foreach ($groups as $list) {
                $first = $list[0];
                if ($by === 'site') {
                    // within a site, item by item
                    usort($list, fn($a, $b) => [$a['code'], $a['date'], $a['txn_id']] <=> [$b['code'], $b['date'], $b['txn_id']]);
                    $rows[] = ['date' => $first['site'], '_class' => 'group-row', '_html' => ['date' => SiteMark::html($first['site_id'], $first['site'])]];
                } else {
                    $rows[] = ['date' => $first['code'] . '  ' . $first['name'], '_class' => 'group-row'];
                }
                foreach ($list as $r) {
                    $rows[] = dist_transfer_cells($r);
                }
                $label = $by === 'site' ? $first['site'] : $first['code'];
                $rows[] = dist_transfer_sum($list, ['date' => 'Subtotal ' . $label, '_class' => 'subtotal-row']);
                $chart[$label] = round(array_sum(array_column($list, 'qty')), 2);
            }
            $cols = [['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'doc', 'label' => 'Document no.']];
            if ($by === 'site') {
                $cols[] = ['key' => 'item', 'label' => 'Item code'];
                $cols[] = ['key' => 'desc', 'label' => 'Description', 'optional' => true];
            } else {
                $cols[] = ['key' => 'site', 'label' => 'From site'];
            }
            $cols = array_merge($cols, [
                ['key' => 'to', 'label' => 'To site'], ['key' => 'prod', 'label' => 'Production date', 'type' => 'date'], ['key' => 'exp', 'label' => 'Expiry date', 'type' => 'date'],
                ['key' => 'days', 'label' => 'Days left when sent', 'type' => 'int'], ['key' => 'crates', 'label' => 'Crates', 'type' => 'int'],
                ['key' => 'qty', 'label' => 'Quantity', 'type' => 'kg'], ['key' => 'unit', 'label' => 'U/M'], ['key' => 'value', 'label' => 'Value at cost', 'type' => 'money', 'sensitive' => 'cost', 'optional' => true],
            ]);
            arsort($chart);
            return [
                'columns' => $cols, 'rows' => $rows,
                'totals' => $all ? dist_transfer_sum($all, ['date' => 'TOTAL']) : null,
                'chart' => $chart ? ['bars' => array_slice($chart, 0, 12, true), 'bars_title' => $by === 'site' ? 'Quantity sent by site' : 'Quantity sent by item code', 'bars_format' => 'qty'] : null,
                'notes' => 'The stock sent by Transfer Inventory and Dispatch Inventory from ' . fdate($f['from']) . ' to ' . fdate($f['to']) . ', '
                    . ($by === 'site' ? 'grouped by the site it left (a dispatch may gather stock from many sites), item by item, with a subtotal per site.' : 'grouped by item code, with a subtotal per item code and the site each line left.')
                    . ' Each line shows the production and expiry dates it went with and the days it had left to its expiry when it was sent; rows in red had expired.'
                    . ' IT- numbers are Transfer Inventory, DSP- numbers Dispatch Inventory.',
            ];
        },
    ];
}

Report::define('transfer_item', dist_transfer_def('item'));
Report::define('transfer_site', dist_transfer_def('site'));
