<?php
declare(strict_types=1);

require_once APP_ROOT . '/modules/txn/_common.php';

/**
 * Inventory > Shortage Charges (distribution, v2)
 *
 * Stock found short at a van or an outlet and charged to the employee answerable for it (Inventory Transfer Closing,
 * or an adjustment for a shortage on Adjust Quantity/Value on Hand). Each charge is a receivable at cost on the
 * employee as a customer, collected with Receive Payments. It is not a sale. The top of the list shows what each
 * person still owes.
 */
$pageKey = 'inv.shortages';
if (txn_common_actions($pageKey, ['shortage_charge'])) {
    return;
}
if (in_array(g('a'), ['new', 'edit'], true)) {
    flash('info', 'Shortage charges are made by Inventory Transfer Closing, or by Adjust Quantity/Value on Hand with the person the shortage is charged to. To change one, void it and record it again.');
    redirect(url($pageKey));
}

// what each person still owes, with a shortcut to Receive Payments
$owing = DB::all("SELECT t.customer_id, c.name, sr.name AS rep_name, sr.rep_type, COUNT(*) AS n, SUM(t.total) AS charged
                    FROM transactions t JOIN customers c ON c.id = t.customer_id LEFT JOIN sales_reps sr ON sr.customer_id = t.customer_id
                   WHERE t.txn_type = 'shortage_charge' AND t.is_voided = 0 AND t.status IN ('open','partial')
                   GROUP BY t.customer_id, c.name, sr.name, sr.rep_type ORDER BY c.name");
$box = '';
if ($owing) {
    $cards = '';
    foreach ($owing as $o) {
        $open = 0.0;
        foreach (DB::all("SELECT * FROM transactions WHERE txn_type = 'shortage_charge' AND is_voided = 0 AND status IN ('open','partial') AND customer_id = :c", ['c' => $o['customer_id']]) as $t) {
            $open += Balances::open($t);
        }
        $cards .= '<div class="owe-card"><div class="owe-who"><strong>' . h($o['rep_name'] ?: $o['name']) . '</strong><span>' . h($o['rep_type'] ? SalesReps::typeText($o['rep_type']) : 'Customer')
            . ', ' . (int)$o['n'] . ' charge' . ((int)$o['n'] === 1 ? '' : 's') . ' open</span></div>'
            . '<div class="owe-fig">' . money($open) . '</div>'
            . (Access::can('cust.payments', 'create') ? '<a class="btn btn-sm btn-outline-success" href="' . h(url('cust.payments', ['customer_id' => $o['customer_id']])) . '"><i class="bi bi-cash"></i> Receive payment</a>' : '')
            . '</div>';
    }
    $box = '<div class="owe-strip mb-3" aria-label="Shortages still to collect">' . $cards . '</div>';
}
render_txn_list($pageKey, ['shortage_charge'], 'Shortage Charges', [
    'no_new' => true,
    'statuses' => ['open' => 'Open', 'partial' => 'Partly collected', 'paid' => 'Collected', 'void' => 'Void'],
    'before_table' => $box,
    'actions' => page_link('inv.transfer_closing', ['a' => 'new'], 'Inventory Transfer Closing', 'btn-outline-primary', 'truck', 'create')
        . ' ' . page_link('rpt.shortage_rep', [], 'Shortages by Sales Representative', 'btn-outline-secondary', 'bar-chart'),
]);
