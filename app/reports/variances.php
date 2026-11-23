<?php
declare(strict_types=1);

/*
 * Distribution (v2): shortages and shrinkage.
 *
 * Shortages are the Shortage Charges: stock missing at a van or an outlet, charged at cost to the employee answerable
 * for it (Inventory Transfer Closing, or an adjustment for a shortage). They are receivables, never sales: these
 * reports show what was charged, what has been collected and what is still open, by item, by site and by person.
 * Shrinkage is the stock written off as Shrinkage on inventory adjustments, the shrinkage of a closing included.
 */

/** Shortage lines in the period (not void), with the person, site and closing */
function var_shortages(array $f): array
{
    [$sf, $sp] = Access::siteFilter('t.site_id', 'vsh');
    $p = $sp + ['f' => $f['from'], 't' => $f['to']];
    $w = "t.txn_type = 'shortage_charge' AND t.is_voided = 0 AND t.txn_date BETWEEN :f AND :t";
    if (!empty($f['site_id'])) {
        $w .= ' AND t.site_id = :s';
        $p['s'] = $f['site_id'];
    }
    if (!empty($f['item_id'])) {
        $w .= ' AND l.item_id = :i';
        $p['i'] = $f['item_id'];
    }
    if (!empty($f['rep_id'])) {
        $w .= ' AND t.sales_rep_id = :r';
        $p['r'] = $f['rep_id'];
    }
    $rows = DB::all("SELECT l.id AS line_id, l.item_id, l.qty, l.rate, l.amount, l.unit, l.description, t.id AS txn_id, t.txn_type, t.txn_no, t.txn_date, t.total, t.status,
                            t.site_id, s.name AS site, t.sales_rep_id, sr.name AS rep, sr.rep_type, t.customer_id, c.name AS customer, i.code, i.name, us.base_unit,
                            tc.id AS closing_id, tc.closing_no
                       FROM transaction_lines l JOIN transactions t ON t.id = l.txn_id JOIN items i ON i.id = l.item_id
                       LEFT JOIN uom_sets us ON us.id = i.uom_set_id LEFT JOIN sites s ON s.id = t.site_id
                       LEFT JOIN sales_reps sr ON sr.id = t.sales_rep_id LEFT JOIN customers c ON c.id = t.customer_id
                       LEFT JOIN transfer_closings tc ON tc.shortage_txn_id = t.id AND tc.status = 'posted'
                      WHERE $w $sf ORDER BY t.txn_date, t.id, l.line_no", $p);
    // what has been collected of each charge, shared over its lines by amount
    $openOf = [];
    foreach ($rows as &$r) {
        $tid = (int)$r['txn_id'];
        if (!isset($openOf[$tid])) {
            $openOf[$tid] = Balances::open(['id' => $tid, 'total' => $r['total'], 'is_voided' => 0, 'is_pending' => 0]);
        }
        $share = (float)$r['total'] > 0 ? (float)$r['amount'] / (float)$r['total'] : 0.0;
        $r['open'] = r2($openOf[$tid] * $share);
        $r['collected'] = r2((float)$r['amount'] - $r['open']);
        $r['who'] = $r['rep'] ?: ($r['customer'] ?: 'Not named');
        $r['unit'] = $r['base_unit'] ?: ($r['unit'] ?: 'kg');
    }
    unset($r);
    return $rows;
}

/** Shrinkage lines in the period: adjustment lines down with the reason Shrinkage, and the shrinkage of closings */
function var_shrinkage(array $f): array
{
    [$sf, $sp] = Access::siteFilter('COALESCE(l.site_id, t.site_id)', 'vsk');
    $p = $sp + ['f' => $f['from'], 't' => $f['to']];
    $w = "t.txn_type = 'inventory_adjustment' AND t.is_voided = 0 AND l.qty < 0 AND t.txn_date BETWEEN :f AND :t AND (l.description = 'Shrinkage' OR tc.id IS NOT NULL)";
    if (!empty($f['site_id'])) {
        $w .= ' AND COALESCE(l.site_id, t.site_id) = :s';
        $p['s'] = $f['site_id'];
    }
    if (!empty($f['item_id'])) {
        $w .= ' AND l.item_id = :i';
        $p['i'] = $f['item_id'];
    }
    if (!empty($f['rep_id'])) {
        $w .= ' AND t.sales_rep_id = :r';
        $p['r'] = $f['rep_id'];
    }
    return DB::all("SELECT l.id AS line_id, l.item_id, -l.qty AS qty, -l.cost_amount AS cost, t.id AS txn_id, t.txn_type, t.txn_no, t.txn_date, t.memo,
                           COALESCE(l.site_id, t.site_id) AS site_id, s.name AS site, sr.name AS rep, i.code, i.name, COALESCE(us.base_unit, i.unit) AS unit,
                           tc.id AS closing_id, tc.closing_no
                      FROM transaction_lines l JOIN transactions t ON t.id = l.txn_id JOIN items i ON i.id = l.item_id
                      LEFT JOIN uom_sets us ON us.id = i.uom_set_id LEFT JOIN sites s ON s.id = COALESCE(l.site_id, t.site_id)
                      LEFT JOIN sales_reps sr ON sr.id = t.sales_rep_id
                      LEFT JOIN transfer_closings tc ON tc.shrink_txn_id = t.id AND tc.status = 'posted'
                     WHERE $w $sf ORDER BY t.txn_date, t.id, l.line_no", $p);
}

/** One summary row per group: quantities by unit, amounts */
function var_group(array $rows, callable $key, callable $label, array $sums): array
{
    $g = [];
    foreach ($rows as $r) {
        $k = (string)$key($r);
        if (!isset($g[$k])) {
            $g[$k] = ['_r' => $r, 'label' => $label($r), 'n' => 0, 'qty' => [], 'docs' => []] + array_fill_keys($sums, 0.0);
        }
        $g[$k]['qty'][$r['unit']] = ($g[$k]['qty'][$r['unit']] ?? 0.0) + (float)$r['qty'];
        $g[$k]['docs'][(int)$r['txn_id']] = 1;
        foreach ($sums as $s) {
            $g[$k][$s] += (float)$r[$s];
        }
        $g[$k]['n']++;
    }
    return $g;
}

function var_qty_text(array $byUnit): string
{
    $out = [];
    foreach ($byUnit as $u => $q) {
        $out[] = Crates::fig($q, $u) . ' ' . $u;
    }
    return implode(', ', $out);
}

Report::define('closing_register', [
    'filters' => ['range', 'site', 'rep'],
    'filter_labels' => ['site' => 'Van or outlet', 'rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $rows = [];
        if (TransferClosing::ready()) {
            [$sf, $sp] = Access::siteFilter('tc.from_site_id', 'vcr');
            $p = $sp + ['f' => $f['from'], 't' => $f['to']];
            $w = 'tc.closing_date BETWEEN :f AND :t';
            if ($f['site_id']) {
                $w .= ' AND tc.from_site_id = :s';
                $p['s'] = $f['site_id'];
            }
            if (!empty($f['rep_id'])) {
                $w .= ' AND tc.sales_rep_id = :r';
                $p['r'] = $f['rep_id'];
            }
            $tot = ['no' => 'TOTAL', 'lines' => 0, 'shrink_amount' => 0.0, 'shortage_amount' => 0.0];
            foreach (DB::all("SELECT tc.*, fs.name AS from_name, ts.name AS to_name, sr.name AS rep_name, (SELECT COUNT(*) FROM transfer_closing_lines x WHERE x.closing_id = tc.id) AS n
                                FROM transfer_closings tc JOIN sites fs ON fs.id = tc.from_site_id JOIN sites ts ON ts.id = tc.to_site_id LEFT JOIN sales_reps sr ON sr.id = tc.sales_rep_id
                               WHERE $w $sf ORDER BY tc.closing_date, tc.id", $p) as $c) {
                $void = $c['status'] === 'void';
                $rows[] = [
                    'no' => $c['closing_no'], 'date' => $c['closing_date'], 'from' => $c['from_name'], 'to' => $c['to_name'], 'rep' => $c['rep_name'] ?: '',
                    'lines' => (int)$c['n'], 'back' => (float)$c['transfer_qty'], 'shrink' => (float)$c['shrink_qty'], 'shrink_amount' => $void ? 0.0 : (float)$c['shrink_amount'],
                    'shortage' => (float)$c['shortage_qty'], 'shortage_amount' => $void ? 0.0 : (float)$c['shortage_amount'], 'status' => $void ? 'Void' : 'Posted',
                    'checked' => (string)$c['checked_by'], 'received' => (string)$c['received_by'],
                    '_links' => ['no' => Report::link('inv.transfer_closing', ['a' => 'view', 'id' => $c['id']])],
                    '_class' => $void ? 'void-row' : '',
                ];
                if (!$void) {
                    $tot['lines'] += (int)$c['n'];
                    $tot['shrink_amount'] += (float)$c['shrink_amount'];
                    $tot['shortage_amount'] += (float)$c['shortage_amount'];
                }
            }
        }
        $cols = [['key' => 'no', 'label' => 'Closing'], ['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'from', 'label' => 'Closed'], ['key' => 'to', 'label' => 'Back to'],
            ['key' => 'rep', 'label' => 'Sales rep or cashier'], ['key' => 'lines', 'label' => 'Lines', 'type' => 'int'], ['key' => 'back', 'label' => 'Came back (base units)', 'type' => 'qty', 'optional' => true],
            ['key' => 'shrink', 'label' => 'Shrinkage (base units)', 'type' => 'qty', 'optional' => true]];
        if (Access::viewCosts()) {
            $cols[] = ['key' => 'shrink_amount', 'label' => 'Shrinkage at cost', 'type' => 'money'];
        }
        $cols = array_merge($cols, [['key' => 'shortage', 'label' => 'Shortage (base units)', 'type' => 'qty', 'optional' => true],
            ['key' => 'shortage_amount', 'label' => 'Shortage charged', 'type' => 'money'], ['key' => 'checked', 'label' => 'Checked by', 'optional' => true],
            ['key' => 'received', 'label' => 'Received by', 'optional' => true], ['key' => 'status', 'label' => 'Status']]);
        return ['columns' => $cols, 'rows' => $rows, 'totals' => $tot ?? null,
            'notes' => 'Every Inventory Transfer Closing from ' . fdate($f['from']) . ' to ' . fdate($f['to']) . ': what each van or outlet sent back, its shrinkage and the shortage charged. Void closings count for nothing.'];
    },
]);

Report::define('shortage_item', [
    'filters' => ['range', 'site', 'item', 'rep'],
    'filter_labels' => ['rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $g = var_group(var_shortages($f), fn($r) => $r['item_id'], fn($r) => $r['code'], ['amount', 'collected', 'open']);
        uasort($g, fn($a, $b) => $b['amount'] <=> $a['amount']);
        $rows = [];
        $tot = ['item' => 'TOTAL', 'amount' => 0.0, 'collected' => 0.0, 'open' => 0.0, 'docs' => 0];
        $chart = [];
        foreach ($g as $x) {
            $r = $x['_r'];
            $rows[] = ['item' => $r['code'], 'desc' => $r['name'], 'qty' => var_qty_text($x['qty']), 'docs' => count($x['docs']), 'amount' => $x['amount'], 'collected' => $x['collected'], 'open' => $x['open'],
                '_links' => ['item' => Report::link('rpt.shortage_detail', ['item_id' => $r['item_id'], 'from' => $f['from'], 'to' => $f['to']])]];
            foreach (['amount', 'collected', 'open'] as $k) {
                $tot[$k] += $x[$k];
            }
            $tot['docs'] += count($x['docs']);
            $chart[$r['code']] = r2($x['amount']);
        }
        return [
            'columns' => [['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description'], ['key' => 'qty', 'label' => 'Quantity short'],
                ['key' => 'docs', 'label' => 'Charges', 'type' => 'int'], ['key' => 'amount', 'label' => 'Charged at cost', 'type' => 'money'],
                ['key' => 'collected', 'label' => 'Collected', 'type' => 'money'], ['key' => 'open', 'label' => 'Still to collect', 'type' => 'money']],
            'rows' => $rows, 'totals' => $tot,
            'chart' => $chart ? ['bars' => array_slice($chart, 0, 12, true), 'bars_title' => 'Shortage charged by item'] : null,
            'notes' => 'Stock found short and charged to the employees answerable for it, by item. Shortages are receivables at cost: they are not sales and are not in the sales reports.',
        ];
    },
]);

Report::define('shortage_site', [
    'filters' => ['range', 'site', 'item', 'rep'],
    'filter_labels' => ['rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $g = var_group(var_shortages($f), fn($r) => $r['site_id'], fn($r) => $r['site'], ['amount', 'collected', 'open']);
        $rows = [];
        $tot = ['site' => 'TOTAL', 'amount' => 0.0, 'collected' => 0.0, 'open' => 0.0, 'docs' => 0, 'lines' => 0];
        foreach ($g as $x) {
            $r = $x['_r'];
            $rows[] = ['site' => (string)$r['site'], 'docs' => count($x['docs']), 'lines' => $x['n'], 'qty' => var_qty_text($x['qty']), 'amount' => $x['amount'], 'collected' => $x['collected'], 'open' => $x['open'],
                '_links' => ['site' => Report::link('rpt.shortage_detail', ['site_id' => $r['site_id'], 'from' => $f['from'], 'to' => $f['to']])]];
            foreach (['amount', 'collected', 'open'] as $k) {
                $tot[$k] += $x[$k];
            }
            $tot['docs'] += count($x['docs']);
            $tot['lines'] += $x['n'];
        }
        return [
            'columns' => [['key' => 'site', 'label' => 'Site'], ['key' => 'docs', 'label' => 'Charges', 'type' => 'int'], ['key' => 'lines', 'label' => 'Items short', 'type' => 'int'],
                ['key' => 'qty', 'label' => 'Quantity short'], ['key' => 'amount', 'label' => 'Charged at cost', 'type' => 'money'],
                ['key' => 'collected', 'label' => 'Collected', 'type' => 'money'], ['key' => 'open', 'label' => 'Still to collect', 'type' => 'money']],
            'rows' => $rows, 'totals' => $tot,
            'notes' => 'Shortages by the van, outlet or other site they were found at.',
        ];
    },
]);

Report::define('shortage_rep', [
    'filters' => ['range', 'site', 'item', 'rep'],
    'filter_labels' => ['rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $g = var_group(var_shortages($f), fn($r) => $r['sales_rep_id'] ? 'r' . $r['sales_rep_id'] : 'c' . $r['customer_id'], fn($r) => $r['who'], ['amount', 'collected', 'open']);
        uasort($g, fn($a, $b) => strcmp($a['label'], $b['label']));
        $rows = [];
        $tot = ['who' => 'TOTAL', 'amount' => 0.0, 'collected' => 0.0, 'open' => 0.0, 'docs' => 0];
        $chart = [];
        foreach ($g as $x) {
            $r = $x['_r'];
            $rows[] = ['who' => $x['label'], 'kind' => $r['rep_type'] ? SalesReps::typeText($r['rep_type']) : 'Customer', 'charged_to' => (string)$r['customer'],
                'docs' => count($x['docs']), 'qty' => var_qty_text($x['qty']), 'amount' => $x['amount'], 'collected' => $x['collected'], 'open' => $x['open'],
                '_links' => ['who' => $r['sales_rep_id'] ? Report::link('rpt.shortage_detail', ['rep_id' => $r['sales_rep_id'], 'from' => $f['from'], 'to' => $f['to']]) : null,
                    'open' => $x['open'] > 0.004 ? Report::link('cust.payments', ['customer_id' => $r['customer_id']]) : null]];
            foreach (['amount', 'collected', 'open'] as $k) {
                $tot[$k] += $x[$k];
            }
            $tot['docs'] += count($x['docs']);
            $chart[$x['label']] = r2($x['open']);
        }
        return [
            'columns' => [['key' => 'who', 'label' => 'Sales rep, van salesman or cashier'], ['key' => 'kind', 'label' => 'Kind'], ['key' => 'charged_to', 'label' => 'Charged to (customer)', 'optional' => true],
                ['key' => 'docs', 'label' => 'Charges', 'type' => 'int'], ['key' => 'qty', 'label' => 'Quantity short', 'optional' => true],
                ['key' => 'amount', 'label' => 'Charged at cost', 'type' => 'money'], ['key' => 'collected', 'label' => 'Collected', 'type' => 'money'], ['key' => 'open', 'label' => 'Still to collect', 'type' => 'money']],
            'rows' => $rows, 'totals' => $tot,
            'chart' => array_filter($chart) ? ['bars' => array_filter($chart), 'bars_title' => 'Still to collect by person'] : null,
            'notes' => 'Shortages by the person they are charged to, with what has been collected through Receive Payments and what is still open.',
        ];
    },
]);

Report::define('shortage_detail', [
    'filters' => ['range', 'site', 'item', 'rep'],
    'filter_labels' => ['rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $rows = [];
        $tot = ['date' => 'TOTAL', 'amount' => 0.0, 'collected' => 0.0, 'open' => 0.0];
        foreach (var_shortages($f) as $r) {
            $rows[] = [
                'date' => $r['txn_date'], 'doc' => $r['txn_no'], 'from' => $r['closing_no'] ? 'Closing ' . $r['closing_no'] : 'Adjustment', 'who' => $r['who'], 'site' => (string)$r['site'],
                'item' => $r['code'], 'desc' => $r['description'] ?: $r['name'], 'qty' => (float)$r['qty'], 'unit' => $r['unit'], 'cost' => (float)$r['rate'], 'amount' => (float)$r['amount'],
                'collected' => $r['collected'], 'open' => $r['open'],
                'status' => ['open' => 'Open', 'partial' => 'Partly collected', 'paid' => 'Collected'][$r['status']] ?? ucfirst((string)$r['status']),
                '_links' => ['doc' => Report::txnLink($r), 'from' => $r['closing_id'] ? Report::link('inv.transfer_closing', ['a' => 'view', 'id' => $r['closing_id']]) : null],
            ];
            foreach (['amount', 'collected', 'open'] as $k) {
                $tot[$k] += (float)$rows[count($rows) - 1][$k];
            }
        }
        return [
            'columns' => [['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'doc', 'label' => 'Charge'], ['key' => 'from', 'label' => 'From'], ['key' => 'who', 'label' => 'Charged to'],
                ['key' => 'site', 'label' => 'Site'], ['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description', 'optional' => true], ['key' => 'qty', 'label' => 'Qty short', 'type' => 'qty'],
                ['key' => 'unit', 'label' => 'U/M'], ['key' => 'cost', 'label' => 'Unit cost', 'type' => 'money', 'optional' => true], ['key' => 'amount', 'label' => 'Charged', 'type' => 'money'],
                ['key' => 'collected', 'label' => 'Collected', 'type' => 'money'], ['key' => 'open', 'label' => 'Open', 'type' => 'money'], ['key' => 'status', 'label' => 'Status']],
            'rows' => $rows, 'totals' => $tot,
            'notes' => 'Every item charged as a shortage, with the closing or adjustment it came from. What is collected of a charge is shared over its items by amount.',
        ];
    },
]);

Report::define('shrinkage_item', [
    'filters' => ['range', 'site', 'item', 'rep'],
    'filter_labels' => ['rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $costs = Access::viewCosts();
        $lines = var_shrinkage($f);
        $onClosing = [];
        foreach ($lines as $l) {
            if ($l['closing_id']) {
                $onClosing[(int)$l['item_id']][(int)$l['closing_id']] = 1;
            }
        }
        $g = var_group($lines, fn($r) => $r['item_id'], fn($r) => $r['code'], ['cost']);
        uasort($g, fn($a, $b) => $b['cost'] <=> $a['cost']);
        $rows = [];
        $tot = ['item' => 'TOTAL', 'cost' => 0.0, 'docs' => 0, 'closings' => 0];
        $chart = [];
        foreach ($g as $x) {
            $r = $x['_r'];
            $closings = count($onClosing[(int)$r['item_id']] ?? []);
            $rows[] = ['item' => $r['code'], 'desc' => $r['name'], 'qty' => var_qty_text($x['qty']), 'docs' => count($x['docs']), 'closings' => $closings, 'cost' => $x['cost'],
                '_links' => ['item' => Report::link('rpt.shrinkage_detail', ['item_id' => $r['item_id'], 'from' => $f['from'], 'to' => $f['to']])]];
            $tot['cost'] += $x['cost'];
            $tot['docs'] += count($x['docs']);
            $tot['closings'] += $closings;
            $chart[$r['code']] = r2($x['cost']);
        }
        $cols = [['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description'], ['key' => 'qty', 'label' => 'Shrinkage'],
            ['key' => 'docs', 'label' => 'Adjustments', 'type' => 'int'], ['key' => 'closings', 'label' => 'Of them on closings', 'type' => 'int', 'optional' => true]];
        if ($costs) {
            $cols[] = ['key' => 'cost', 'label' => 'At cost', 'type' => 'money'];
        }
        return ['columns' => $cols, 'rows' => $rows, 'totals' => $tot,
            'chart' => $costs && $chart ? ['bars' => array_slice($chart, 0, 12, true), 'bars_title' => 'Shrinkage at cost by item'] : null,
            'notes' => 'Stock lost to shrinkage (weight loss, drip, trimming) by item: the shrinkage of Inventory Transfer Closings and every adjustment down with the reason Shrinkage.'];
    },
]);

Report::define('shrinkage_detail', [
    'filters' => ['range', 'site', 'item', 'rep'],
    'filter_labels' => ['rep' => 'Sales rep or cashier'],
    'default_dates' => 'this_month',
    'run' => function (array $f): array {
        $costs = Access::viewCosts();
        $rows = [];
        $tot = ['date' => 'TOTAL', 'cost' => 0.0];
        foreach (var_shrinkage($f) as $r) {
            $rows[] = ['date' => $r['txn_date'], 'doc' => $r['txn_no'], 'from' => $r['closing_no'] ? 'Closing ' . $r['closing_no'] : 'Adjustment', 'site' => (string)$r['site'],
                'rep' => (string)$r['rep'], 'item' => $r['code'], 'desc' => $r['name'], 'qty' => (float)$r['qty'], 'unit' => (string)$r['unit'], 'cost' => (float)$r['cost'],
                '_links' => ['doc' => Report::txnLink($r), 'from' => $r['closing_id'] ? Report::link('inv.transfer_closing', ['a' => 'view', 'id' => $r['closing_id']]) : null]];
            $tot['cost'] += (float)$r['cost'];
        }
        $cols = [['key' => 'date', 'label' => 'Date', 'type' => 'date'], ['key' => 'doc', 'label' => 'Adjustment'], ['key' => 'from', 'label' => 'From'], ['key' => 'site', 'label' => 'Site'],
            ['key' => 'rep', 'label' => 'Sales rep or cashier', 'optional' => true], ['key' => 'item', 'label' => 'Item'], ['key' => 'desc', 'label' => 'Description', 'optional' => true],
            ['key' => 'qty', 'label' => 'Shrinkage', 'type' => 'qty'], ['key' => 'unit', 'label' => 'U/M']];
        if ($costs) {
            $cols[] = ['key' => 'cost', 'label' => 'At cost', 'type' => 'money'];
        }
        return ['columns' => $cols, 'rows' => $rows, 'totals' => $tot,
            'notes' => 'Every line of shrinkage in the period, with the closing or adjustment it is on.'];
    },
]);
