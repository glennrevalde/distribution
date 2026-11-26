<?php
declare(strict_types=1);

/*
 * v9: the checks received from customers, at the POS and on Receive Payments
 *   check_registry       CHECK REGISTRY: customer name, bank, check number, check date, amount and status
 *                        (Pending, On Date, Cleared, Returned)
 *   cashier_collections  what each cashier or user collected from customers, by payment type, and the
 *                        Receipt of Post Dated Check: the post-dated checks they received (not payments yet)
 */

Report::define('check_registry', [
    'filters' => ['range', 'customer'],
    'default_dates' => 'all',
    'sortable' => true,
    'extra_filters' => [
        'cstatus' => ['Status', fn() => Checks::STATUSES, 'Any status'],
        'dateby' => ['Dates of', fn() => ['check' => 'The check date', 'received' => 'The date received'], null],
        'csource' => ['Received on', fn() => ['pos' => 'POS', 'payment' => 'Receive Payments'], 'POS and Receive Payments'],
    ],
    'run' => function (array $f): array {
        $rows = [];
        $by = [];
        $total = 0.0;
        $list = Checks::registry([
            'from' => $f['from'] ?? '', 'to' => $f['to'] ?? '', 'customer_id' => $f['customer_id'] ?? null,
            'status' => (string)($f['cstatus'] ?? ''), 'by' => ($f['dateby'] ?? '') === 'received' ? 'received' : 'check',
            'source' => (string)($f['csource'] ?? ''),
        ]);
        foreach ($list as $c) {
            $s = $c['shown'];
            $link = Report::link('cust.checks', ['a' => 'view', 'id' => $c['id']]);
            $rows[] = [
                'customer' => $c['customer_name'], 'bank' => $c['bank'], 'check_no' => $c['check_no'], 'check_date' => $c['check_date'],
                'amount' => r2((float)$c['amount']), 'status' => Checks::statusText($s),
                '_html' => ['status' => '<span class="state-text ck-' . h($s) . '">' . h(Checks::statusText($s)) . '</span>'],
                '_links' => array_filter(['customer' => $link, 'check_no' => $link]),
            ];
            $by[$s][0] = ($by[$s][0] ?? 0) + 1;
            $by[$s][1] = ($by[$s][1] ?? 0) + (float)$c['amount'];
            $total += (float)$c['amount'];
        }
        $parts = [];
        foreach (Checks::STATUSES as $k => $label) {
            if (isset($by[$k])) {
                $parts[] = $label . ': ' . $by[$k][0] . ' check' . ($by[$k][0] === 1 ? '' : 's') . ', ' . money($by[$k][1]);
            }
        }
        return [
            'columns' => [
                ['key' => 'customer', 'label' => 'Customer Name'], ['key' => 'bank', 'label' => 'Bank'], ['key' => 'check_no', 'label' => 'Check Number'],
                ['key' => 'check_date', 'label' => 'Check Date', 'type' => 'date'], ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'status', 'label' => 'Status'],
            ],
            'rows' => $rows,
            'totals' => ['customer' => 'TOTAL (' . count($rows) . ' check' . (count($rows) === 1 ? '' : 's') . ')', 'amount' => r2($total)],
            'notes' => ($parts ? implode('; ', $parts) . '. ' : '')
                . 'Pending: the check is post-dated (not a payment yet). On Date: the date of the check is on or before today (recorded as payment). '
                . 'Cleared: deposited to the bank and honored. Returned: deposited to the bank and dishonored.',
        ];
    },
]);

Report::define('cashier_collections', [
    'filters' => ['range', 'user'],
    'filter_labels' => ['user' => 'Cashier / user'],
    'default_dates' => 'today',
    'sortable' => false,
    'extra_filters' => [
        'csource' => ['Received on', fn() => ['pos' => 'POS (account payments)', 'payment' => 'Receive Payments'], 'POS and Receive Payments'],
        'cshow' => ['Show', fn() => ['summary' => 'Totals by payment type', 'detail' => 'Every payment'], null],
    ],
    'run' => function (array $f): array {
        $users = DB::pairs("SELECT id, COALESCE(NULLIF(full_name, ''), username) FROM users");
        $p = ['f' => $f['from'], 't' => $f['to']];
        $w = '';
        if (!empty($f['user_id'])) {
            $w .= ' AND t.created_by = :u';
            $p['u'] = (int)$f['user_id'];
        }
        $src = (string)($f['csource'] ?? '');
        if ($src === 'pos') {
            $w .= ' AND t.terminal_id IS NOT NULL';
        } elseif ($src === 'payment') {
            $w .= ' AND t.terminal_id IS NULL';
        }
        $detail = ($f['cshow'] ?? '') === 'detail';
        $chk = Checks::ready() ? ', (SELECT CONCAT(cc.bank, \' no. \', cc.check_no, \', dated \', DATE_FORMAT(cc.check_date, \'%m/%d/%Y\')) FROM customer_checks cc WHERE cc.payment_txn_id = t.id LIMIT 1) AS chk' : ', NULL AS chk';
        $pays = DB::all(
            "SELECT t.id, t.txn_type, t.txn_no, t.txn_date, t.total, t.ref_no, t.created_by, t.terminal_id, c.name AS customer,
                    COALESCE(pm.name, '(no payment type)') AS method $chk
               FROM transactions t JOIN customers c ON c.id = t.customer_id LEFT JOIN payment_methods pm ON pm.id = t.payment_method_id
              WHERE t.txn_type = 'payment' AND t.is_voided = 0 AND t.total > 0 AND t.txn_date BETWEEN :f AND :t $w
              ORDER BY t.txn_date, t.id",
            $p
        );
        $pdcs = Checks::pdcReceived(['from' => $f['from'], 'to' => $f['to'], 'user_id' => $f['user_id'] ?? null]);
        if ($src !== '') {
            $pdcs = array_values(array_filter($pdcs, fn($c) => $c['source'] === $src));
        }
        $by = [];
        foreach ($pays as $t) {
            $by[(int)$t['created_by']]['pay'][$t['method']][] = $t;
        }
        foreach ($pdcs as $c) {
            $by[(int)$c['created_by']]['pdc'][] = $c;
        }
        uksort($by, fn($a, $b) => strcmp($users[$a] ?? '?', $users[$b] ?? '?'));
        $rows = [];
        $grand = 0.0;
        $grandPdc = 0.0;
        $methods = [];
        foreach ($by as $uid => $b) {
            $sum = 0.0;
            $n = 0;
            foreach ($b['pay'] ?? [] as $list) {
                $sum += array_sum(array_map(fn($t) => (float)$t['total'], $list));
                $n += count($list);
            }
            $rows[] = ['name' => $users[$uid] ?? 'User #' . $uid, 'detail' => $n ? $n . ' payment' . ($n === 1 ? '' : 's') . ' collected' : 'No payments collected', 'count' => $n ?: null, 'amount' => $n ? r2($sum) : null, '_class' => 'group-row'];
            if (!empty($b['pay'])) {
                ksort($b['pay']);
            }
            foreach ($b['pay'] ?? [] as $method => $list) {
                $amt = r2(array_sum(array_map(fn($t) => (float)$t['total'], $list)));
                $rows[] = ['name' => $method, 'count' => count($list), 'amount' => $amt, '_class' => 'indent-1'];
                $methods[$method][0] = ($methods[$method][0] ?? 0) + count($list);
                $methods[$method][1] = ($methods[$method][1] ?? 0) + $amt;
                if ($detail) {
                    foreach ($list as $t) {
                        $rows[] = ['name' => fdate($t['txn_date']) . ', ' . $t['txn_no'], 'detail' => $t['customer'] . ($t['chk'] ? ', check ' . $t['chk'] : ($t['ref_no'] ? ', ref. ' . $t['ref_no'] : '')) . ($t['terminal_id'] ? ' (POS)' : ''),
                            'amount' => r2((float)$t['total']), '_class' => 'indent-2', '_links' => ['name' => Report::txnLink($t)]];
                    }
                }
            }
            if (!empty($b['pdc'])) {
                $pdcSum = r2(array_sum(array_map(fn($c) => (float)$c['amount'], $b['pdc'])));
                $rows[] = ['name' => 'Receipt of Post Dated Check', 'detail' => 'Not a payment yet: recorded on the check date', 'count' => count($b['pdc']),
                    'pdc' => $pdcSum, '_class' => 'indent-1 subtotal-row'];
                foreach ($b['pdc'] as $c) {
                    $rows[] = ['name' => $c['customer_name'], 'detail' => $c['bank'] . ' no. ' . $c['check_no'] . ', dated ' . fdate($c['check_date'])
                        . ', received ' . fdate($c['received_date']) . ($c['source'] === 'pos' ? ' (POS)' : ''),
                        'pdc' => r2((float)$c['amount']), '_class' => 'indent-2', '_links' => ['name' => Report::link('cust.checks', ['a' => 'view', 'id' => $c['id']])]];
                }
                $grandPdc += $pdcSum;
            }
            $grand += $sum;
        }
        if (count($by) > 1 && $methods) {
            $rows[] = ['name' => 'All cashiers and users, by payment type', '_class' => 'group-row'];
            ksort($methods);
            foreach ($methods as $m => [$cnt, $amt]) {
                $rows[] = ['name' => $m, 'count' => $cnt, 'amount' => r2($amt), '_class' => 'indent-1'];
            }
        }
        return [
            'grouped' => true,
            'columns' => [
                ['key' => 'name', 'label' => 'Cashier / payment type'], ['key' => 'detail', 'label' => 'Details'], ['key' => 'count', 'label' => 'Count', 'type' => 'int'],
                ['key' => 'amount', 'label' => 'Collected', 'type' => 'money'], ['key' => 'pdc', 'label' => 'Post-dated checks', 'type' => 'money'],
            ],
            'rows' => $rows,
            'totals' => ['name' => 'TOTAL', 'amount' => r2($grand), 'pdc' => r2($grandPdc)],
            'notes' => 'Collected: the payments of customers recorded by each cashier or user (at the POS and on Receive Payments), by payment type, on the date of the payment. '
                . 'Receipt of Post Dated Check: the post-dated checks received in the period, with their details. They are not payments yet and are not in the Collected total; '
                . 'each is recorded as payment on its check date and is then collected by the cashier who received it.',
        ];
    },
]);
