<?php
declare(strict_types=1);

/**
 * Customers > Customer Checks (v9)
 *
 * Every check received from a customer, at the POS or on Receive Payments, with its status:
 *   Pending   post-dated: only its receipt is kept; nothing is in the books yet
 *   On Date   its date has come: the payment is recorded and applied to the invoices chosen
 *   Cleared   deposited to the bank and honored
 *   Returned  deposited to the bank and dishonored: the amount goes back on the customer's account (a statement charge)
 * The printable list is Customers > Reports > Check Registry.
 */
require_once APP_ROOT . '/modules/txn/_common.php';

$pageKey = 'cust.checks';
$a = g('a', 'list');

if (!Checks::ready()) {
    layout_start('Customer Checks');
    echo '<div class="alert alert-warning">Run database/migrations/2027_05_03_payment_types_checks.sql (Super Admin &gt; Database updates) to keep the checks of customers.</div>';
    layout_end();
    return;
}

// the checks whose date has come since the system was first opened today
$failed = [];
Checks::postDue(true, $failed);

handle_post(function () use ($pageKey) {
    $do = (string)p('do');
    $back = (string)p('back') !== '' ? (string)p('back') : url($pageKey);
    if (!str_starts_with($back, base_url() . '/index.php?')) {
        $back = url($pageKey);
    }
    $id = pint('id') ?? 0;
    $note = mb_substr(trim((string)p('note')), 0, 255);
    // a check taken at the counter of a site this user may not use is not theirs to change
    foreach ($id ? [$id] : array_map('intval', (array)($_POST['ids'] ?? [])) as $one) {
        $site = DB::value('SELECT site_id FROM customer_checks WHERE id = :id', ['id' => $one]);
        if ($site && !Access::siteAllowed((int)$site)) {
            fail('One of the checks was taken at a site you may not record for.');
        }
    }
    switch ($do) {
        case 'cleared':
            Access::require($pageKey, 'edit');
            $date = pdate('status_date') ?: today();
            $ids = $id ? [$id] : array_values(array_unique(array_map('intval', (array)($_POST['ids'] ?? []))));
            if (!$ids) {
                fail('Tick the checks that cleared.');
            }
            DB::tx(function () use ($ids, $date, $note) {
                foreach ($ids as $cid) {
                    Checks::markCleared($cid, $date, $note);
                }
            });
            flash('success', count($ids) . ' check' . (count($ids) === 1 ? '' : 's') . ' marked Cleared on ' . fdate($date) . '.');
            break;
        case 'returned':
            Access::require($pageKey, 'edit');
            $date = pdate('status_date') ?: today();
            $chargeId = Checks::markReturned($id, $date, $note);
            $charge = Txn::load($chargeId);
            flash('success', 'Check marked Returned. ' . money($charge['total']) . ' is back on the customer\'s account with statement charge ' . $charge['txn_no'] . '.');
            break;
        case 'undo':
            Access::require($pageKey, 'edit');
            Checks::undo($id, (string)p('reason'));
            flash('success', 'The check is On Date again.');
            break;
        case 'record':
            Access::require($pageKey, 'edit');
            $txnId = Checks::record($id, pdate('record_date'));
            $t = Txn::load($txnId);
            flash('success', 'Payment ' . $t['txn_no'] . ' recorded for the check, dated ' . fdate($t['txn_date']) . '.');
            break;
        case 'remove':
            Access::require($pageKey, 'delete');
            Checks::remove($id, (string)p('reason'));
            flash('success', 'The post-dated check was taken off the list.');
            $back = url($pageKey);
            break;
        default:
            fail('Unknown action.');
    }
    redirect($back);
});

$canEdit = Access::can($pageKey, 'edit');
$canDelete = Access::can($pageKey, 'delete');

/** The status word of a check, with its colour */
function ck_status(array $c): string
{
    $s = Checks::status($c);
    return '<span class="state-text ck-' . h($s) . '" title="' . h(Checks::STATUS_HELP[$s] ?? '') . '">' . h(Checks::statusText($s)) . '</span>';
}

// ------------------------------------------------------------------ one check
if ($a === 'view') {
    $c = Checks::load(gint('id') ?? 0);
    if (!$c || ($c['site_id'] && !Access::siteAllowed((int)$c['site_id']))) {
        flash('warning', 'Check not found.');
        redirect(url($pageKey));
    }
    $shown = Checks::status($c);
    $dep = Checks::deposit($c['payment_txn_id'] ? (int)$c['payment_txn_id'] : null);
    $forDocs = [];
    foreach (Checks::applyList($c) as $ap) {
        $d = DB::row('SELECT id, txn_type, txn_no, txn_date, due_date, total, status, is_voided, is_pending FROM transactions WHERE id = :id', ['id' => $ap['id']]);
        if ($d) {
            $forDocs[] = $d + ['plan' => $ap['amount'], 'open' => Balances::open($d)];
        }
    }
    $applied = $c['payment_txn_id'] ? DB::all('SELECT tg.id, tg.txn_type, tg.txn_no, tg.txn_date, pa.amount FROM payment_applications pa JOIN transactions tg ON tg.id = pa.target_txn_id
                                                 WHERE pa.payment_txn_id = :p ORDER BY tg.txn_date, tg.id', ['p' => $c['payment_txn_id']]) : [];
    $history = DB::all("SELECT created_at, username, action, reason FROM audit_trail WHERE record_type = 'customer_check' AND record_id = :id ORDER BY id", ['id' => $c['id']]);
    $self = url($pageKey, ['a' => 'view', 'id' => $c['id']]);
    $due = $c['status'] === 'pending' && !$c['payment_txn_id'] && $c['check_date'] <= today();
    layout_start('Check ' . $c['bank'] . ' no. ' . $c['check_no'], ['actions' => btn_link(url($pageKey), 'All checks', 'btn-outline-secondary', 'arrow-left')
        . ($c['source'] === 'pos' && $c['check_date'] > $c['received_date'] && Access::page('pos.register') ? ' ' . btn_link(url('pos.register', ['a' => 'check_receipt', 'id' => $c['id']]), 'Acknowledgement slip', 'btn-outline-secondary', 'receipt') : '')
        . ' ' . page_link('rpt.check_registry', ['customer_id' => $c['customer_id'], 'dates' => 'all'], 'Check Registry', 'btn-outline-secondary', 'printer')]);
    ?>
    <div class="ck-view">
      <div class="card ck-slip">
        <div class="ck-slip-top">
          <div><div class="ck-slip-bank"><?= h($c['bank']) ?></div><div class="ck-slip-no">No. <?= h($c['check_no']) ?></div></div>
          <div class="text-end"><div class="ck-slip-date"><?= h(fdate($c['check_date'])) ?></div><?= ck_status($c) ?></div>
        </div>
        <div class="ck-slip-pay"><span>Pay to the order of <?= h(Settings::get('company_name')) ?></span><strong><?= money($c['amount']) ?></strong></div>
        <div class="ck-slip-from">From <?= safe_link('cust.center', ['id' => $c['customer_id']], $c['customer_name']) ?></div>
      </div>

      <div class="card"><div class="card-body">
        <dl class="ck-facts">
          <dt>Received</dt><dd><?= h(fdate($c['received_date'])) ?> by <?= h($c['received_by_name'] ?: '') ?>, <?= $c['source'] === 'pos' ? 'at the POS' . ($c['terminal_name'] ? ' (' . h($c['terminal_name']) . ')' : '') : 'on Receive Payments' ?>
            <?= $c['check_date'] > $c['received_date'] ? '<div class="small text-muted">Receipt of Post Dated Check' . ($c['source'] === 'pos' ? ', ' . h(Checks::ackNo((int)$c['id'])) : '') . '</div>' : '' ?></dd>
          <dt>Payment</dt><dd><?php if ($c['payment_txn_id']): ?><?= Txn::link((int)$c['payment_txn_id'], 'Payment ' . $c['payment_no']) ?><?= (int)$c['payment_void'] === 1 ? ' <span class="text-danger">(void)</span>' : '' ?>
            <?php if ($c['recorded_at'] && $c['check_date'] > $c['received_date']): ?><div class="small text-muted">Recorded on the check's date (<?= h(fdatetime($c['recorded_at'])) ?>)</div><?php endif; ?>
            <?php elseif ($due): ?><span class="text-danger">Not recorded yet</span><?= $c['status_note'] ? '<div class="small text-muted">' . h($c['status_note']) . '</div>' : '' ?>
            <?php else: ?>Recorded on <?= h(fdate($c['check_date'])) ?>, when the check is due<?php endif; ?></dd>
          <dt>Account</dt><dd><?= h(account_label($c['account_id'] ? (int)$c['account_id'] : null)) ?><?= $c['method_name'] ? ' <span class="text-muted">(' . h($c['method_name']) . ')</span>' : '' ?></dd>
          <dt>Deposit</dt><dd><?= $dep ? Txn::link((int)$dep['id'], 'Deposit ' . $dep['txn_no']) . ', ' . h(fdate($dep['txn_date'])) . ', to ' . h(account_label((int)$dep['account_id'])) : '<span class="text-muted">Not on a bank deposit yet</span>' ?></dd>
          <?php if ($c['status'] === 'cleared'): ?><dt>Cleared</dt><dd><?= h(fdate($c['cleared_date'])) ?><?= $c['status_note'] ? ', ' . h($c['status_note']) : '' ?></dd><?php endif; ?>
          <?php if ($c['status'] === 'returned'): ?><dt>Returned</dt><dd><?= h(fdate($c['returned_date'])) ?><?= $c['status_note'] ? ', ' . h($c['status_note']) : '' ?>
            <?= $c['return_txn_id'] ? '<div>' . Txn::link((int)$c['return_txn_id'], 'Statement charge ' . $c['return_no']) . ' puts it back on the account</div>' : '' ?></dd><?php endif; ?>
          <?php if ($c['memo']): ?><dt>Memo</dt><dd><?= h($c['memo']) ?></dd><?php endif; ?>
        </dl>
      </div></div>

      <?php if ($forDocs || $applied): ?>
      <div class="card"><div class="card-header fw-semibold"><?= $applied ? 'Invoices paid' : 'Invoices it is to pay' ?></div>
        <div class="table-responsive"><table class="table table-sm mb-0">
          <thead><tr><th>Document</th><th>Date</th><th class="num"><?= $applied ? 'Applied' : 'To pay' ?></th><?php if (!$applied): ?><th class="num">Open now</th><?php endif; ?></tr></thead>
          <?php if ($applied): foreach ($applied as $ap): ?><tr><td><?= h(Txn::label($ap['txn_type'])) ?> <?= Txn::link((int)$ap['id'], $ap['txn_no']) ?></td><td><?= h(fdate($ap['txn_date'])) ?></td><td class="num"><?= money($ap['amount']) ?></td></tr><?php endforeach;
          else: foreach ($forDocs as $d): ?><tr><td><?= h(Txn::label($d['txn_type'])) ?> <?= Txn::link((int)$d['id'], $d['txn_no']) ?></td><td><?= h(fdate($d['txn_date'])) ?></td><td class="num"><?= money($d['plan']) ?></td><td class="num"><?= money($d['open']) ?></td></tr><?php endforeach; endif; ?>
        </table></div>
        <?php if (!$applied && $forDocs): ?><div class="card-body small text-muted pt-2">On the check's date the payment goes to these invoices, as far as they are still open; the rest stays with the customer as a credit.</div><?php endif; ?>
      </div>
      <?php endif; ?>

      <?php if ($canEdit || $canDelete): ?>
      <div class="card ck-actions"><div class="card-header fw-semibold">What happened to the check</div><div class="card-body">
        <?php if ($due && $canEdit): ?>
        <form method="post" class="ck-act"><?= csrf_field() ?><input type="hidden" name="do" value="record"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>"><input type="hidden" name="back" value="<?= h($self) ?>">
          <div class="ck-act-text"><strong>Record the payment</strong><span>The check's date has come. The payment is dated the check's date unless another date is chosen.</span></div>
          <input class="form-control form-control-sm" type="date" name="record_date" value="<?= h($c['check_date']) ?>" min="<?= h($c['check_date']) ?>" aria-label="Payment date">
          <button class="btn btn-sm btn-primary"><i class="bi bi-journal-check"></i> Record payment</button></form>
        <?php endif; ?>
        <?php if ($shown === 'on_date' && $c['payment_txn_id'] && (int)$c['payment_void'] !== 1 && $canEdit): ?>
        <form method="post" class="ck-act"><?= csrf_field() ?><input type="hidden" name="do" value="cleared"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>"><input type="hidden" name="back" value="<?= h($self) ?>">
          <div class="ck-act-text"><strong>Cleared</strong><span>Deposited to the bank and honored.</span></div>
          <input class="form-control form-control-sm" type="date" name="status_date" value="<?= h(max(today(), (string)$c['check_date'])) ?>" aria-label="Date cleared">
          <input class="form-control form-control-sm" name="note" maxlength="255" placeholder="Note (optional)" aria-label="Note">
          <button class="btn btn-sm btn-success"><i class="bi bi-check2-circle"></i> Mark cleared</button></form>
        <?php endif; ?>
        <?php if (in_array($shown, ['on_date', 'cleared'], true) && $c['payment_txn_id'] && (int)$c['payment_void'] !== 1 && $canEdit): ?>
        <form method="post" class="ck-act"><?= csrf_field() ?><input type="hidden" name="do" value="returned"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>"><input type="hidden" name="back" value="<?= h($self) ?>">
          <div class="ck-act-text"><strong>Returned</strong><span>Deposited and dishonored. <?= h(money($c['amount'])) ?> goes back on the customer's account (a statement charge, credited to <?= h(account_label(Checks::moneyAccount($c))) ?>).</span></div>
          <input class="form-control form-control-sm" type="date" name="status_date" value="<?= h(max(today(), (string)$c['check_date'])) ?>" aria-label="Date returned">
          <input class="form-control form-control-sm" name="note" maxlength="255" placeholder="Reason, e.g. insufficient funds" aria-label="Reason">
          <button class="btn btn-sm btn-outline-danger" data-confirm="Mark this check Returned? <?= h(money($c['amount'])) ?> goes back on <?= h($c['customer_name']) ?>'s account with a statement charge."><i class="bi bi-arrow-counterclockwise"></i> Mark returned</button></form>
        <?php endif; ?>
        <?php if (in_array($c['status'], ['cleared', 'returned'], true) && $canEdit): ?>
        <form method="post" class="ck-act"><?= csrf_field() ?><input type="hidden" name="do" value="undo"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>"><input type="hidden" name="back" value="<?= h($self) ?>">
          <div class="ck-act-text"><strong>Back to On Date</strong><span><?= $c['status'] === 'returned' ? 'The statement charge of the returned check is voided.' : 'The check is no longer marked cleared.' ?></span></div>
          <input class="form-control form-control-sm" name="reason" maxlength="255" required placeholder="Reason (required)" aria-label="Reason">
          <button class="btn btn-sm btn-outline-secondary"><i class="bi bi-arrow-left"></i> Set back</button></form>
        <?php endif; ?>
        <?php if ($c['status'] === 'pending' && !$c['payment_txn_id'] && $canDelete): ?>
        <form method="post" class="ck-act"><?= csrf_field() ?><input type="hidden" name="do" value="remove"><input type="hidden" name="id" value="<?= (int)$c['id'] ?>">
          <div class="ck-act-text"><strong>Take off the list</strong><span>The check was given back, replaced, or entered by mistake. Nothing was recorded in the books for it.</span></div>
          <input class="form-control form-control-sm" name="reason" maxlength="255" required placeholder="Reason (required)" aria-label="Reason">
          <button class="btn btn-sm btn-outline-danger"><i class="bi bi-x-circle"></i> Remove</button></form>
        <?php endif; ?>
        <?php if ($shown === 'pending'): ?><p class="small text-muted mb-0">The check is post-dated. On <?= h(fdate($c['check_date'])) ?> its payment is recorded, and it can then be marked Cleared or Returned.</p><?php endif; ?>
      </div></div>
      <?php endif; ?>

      <?php if ($history): ?>
      <div class="card"><div class="card-header fw-semibold">History</div><ul class="list-group list-group-flush small">
        <?php foreach ($history as $hrow): ?><li class="list-group-item"><span class="text-muted"><?= h(fdatetime($hrow['created_at'])) ?>, <?= h($hrow['username']) ?>:</span> <?= h($hrow['reason']) ?></li><?php endforeach; ?>
      </ul></div>
      <?php endif; ?>
    </div>
    <?php
    layout_end();
    return;
}

// ------------------------------------------------------------------ the list
$status = in_array(g('status'), ['pending', 'on_date', 'cleared', 'returned', 'all'], true) ? g('status') : 'open';
$f = [
    'from' => gdate('from', ''), 'to' => gdate('to', ''), 'customer_id' => gint('customer_id'), 'q' => trim((string)g('q')),
    'source' => in_array(g('source'), ['pos', 'payment'], true) ? g('source') : '', 'by' => g('by') === 'received' ? 'received' : 'check',
];
$base = array_filter(['from' => $f['from'], 'to' => $f['to'], 'customer_id' => $f['customer_id'], 'q' => $f['q'], 'source' => $f['source'], 'by' => $f['by'] === 'received' ? 'received' : ''], fn($v) => $v !== '' && $v !== null);
$all = Checks::registry($f);
$counts = ['pending' => [0, 0.0], 'on_date' => [0, 0.0], 'cleared' => [0, 0.0], 'returned' => [0, 0.0]];
foreach ($all as $r) {
    $counts[$r['shown']][0]++;
    $counts[$r['shown']][1] += (float)$r['amount'];
}
$rows = array_values(array_filter($all, fn($r) => $status === 'all' || ($status === 'open' ? in_array($r['shown'], ['pending', 'on_date'], true) : $r['shown'] === $status)));
$tabs = ['open' => ['Pending and On Date', $counts['pending'][0] + $counts['on_date'][0]], 'pending' => ['Pending', $counts['pending'][0]], 'on_date' => ['On Date', $counts['on_date'][0]],
    'cleared' => ['Cleared', $counts['cleared'][0]], 'returned' => ['Returned', $counts['returned'][0]], 'all' => ['All', count($all)]];
$notRecorded = array_filter($all, fn($r) => $r['status'] === 'pending' && $r['check_date'] <= today());
$canBulk = $canEdit && array_filter($rows, fn($r) => $r['shown'] === 'on_date' && $r['payment_txn_id']);

layout_start('Customer Checks', ['actions' => page_link('rpt.check_registry', ['dates' => 'all'], 'Check Registry', 'btn-outline-secondary', 'printer')
    . ' ' . page_link('cust.payments', [], 'Receive payment', 'btn-primary', 'plus-lg', 'create')]);
?>
<?php if ($notRecorded): ?>
<div class="alert alert-warning py-2 small"><i class="bi bi-exclamation-triangle"></i> <?= count($notRecorded) ?> check<?= count($notRecorded) === 1 ? ' has' : 's have' ?> reached <?= count($notRecorded) === 1 ? 'its' : 'their' ?> date but the payment is not recorded yet<?= $failed ? ': ' . h(reset($failed)) : '' ?>. Open the check to record it.</div>
<?php endif; ?>
<div class="ck-tabs" role="tablist">
  <?php foreach ($tabs as $k => [$label, $n]): ?>
    <a class="ck-tab<?= $k === $status ? ' is-on' : '' ?>" role="tab" aria-selected="<?= $k === $status ? 'true' : 'false' ?>" href="<?= h(url($pageKey, $base + ($k === 'open' ? [] : ['status' => $k]))) ?>"><span><?= h($label) ?></span><strong><?= (int)$n ?></strong></a>
  <?php endforeach; ?>
</div>
<form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>"><?php if ($status !== 'open'): ?><input type="hidden" name="status" value="<?= h($status) ?>"><?php endif; ?>
  <div class="row g-2 align-items-end">
    <div class="col-6 col-md-2"><label class="form-label" for="ckBy">Dates of</label><select class="form-select form-select-sm" id="ckBy" name="by" data-no-combo><?= options(['check' => 'The check', 'received' => 'Receipt'], $f['by']) ?></select></div>
    <?= input_field('from', 'From', $f['from'], ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
    <?= input_field('to', 'To', $f['to'], ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
    <?= select_field('customer_id', 'Customer', Lookup::customers(), $f['customer_id'], ['blank' => 'All customers', 'class' => 'col-6 col-md-3', 'no_add' => true]) ?>
    <?= input_field('q', 'Bank or check no.', $f['q'], ['class' => 'col-8 col-md-2', 'extra' => 'placeholder="Find"']) ?>
    <div class="col-4 col-md-1"><button class="btn btn-sm btn-outline-primary w-100"><i class="bi bi-funnel"></i> Show</button></div>
  </div>
</form>

<form method="post" id="ckBulk"><?= csrf_field() ?><input type="hidden" name="do" value="cleared"><input type="hidden" name="back" value="<?= h(current_url()) ?>">
<div class="card"><div class="table-responsive"><table class="table table-sm table-hover align-middle mb-0 ck-table">
  <thead><tr><?php if ($canBulk): ?><th class="ck-c-tick"><input class="form-check-input" type="checkbox" id="ckAll" aria-label="Tick every check On Date"></th><?php endif; ?>
    <th>Check date</th><th>Customer</th><th>Bank</th><th>Check no.</th><th class="num">Amount</th><th>Status</th><th>Received</th><th>Payment</th></tr></thead>
  <tbody>
  <?php foreach ($rows as $r): $link = url($pageKey, ['a' => 'view', 'id' => $r['id']]); ?>
    <tr class="ck-row ck-row-<?= h($r['shown']) ?>">
      <?php if ($canBulk): ?><td class="ck-c-tick"><?php if ($r['shown'] === 'on_date' && $r['payment_txn_id']): ?><input class="form-check-input ck-tick" type="checkbox" name="ids[]" value="<?= (int)$r['id'] ?>" aria-label="Tick check <?= h($r['check_no']) ?>"><?php endif; ?></td><?php endif; ?>
      <td class="ck-c-date" data-label="Check date"><?= h(fdate($r['check_date'])) ?></td>
      <td class="ck-c-cust" data-label="Customer"><a href="<?= h($link) ?>"><?= h($r['customer_name']) ?></a></td>
      <td class="ck-c-bank" data-label="Bank"><?= h($r['bank']) ?></td>
      <td class="ck-c-no" data-label="Check no."><a href="<?= h($link) ?>"><?= h($r['check_no']) ?></a></td>
      <td class="num ck-c-amt" data-label="Amount"><?= money($r['amount']) ?></td>
      <td class="ck-c-status" data-label="Status"><?= ck_status($r) ?></td>
      <td class="ck-c-recv small" data-label="Received"><?= h(fdate($r['received_date'])) ?>, <?= $r['source'] === 'pos' ? 'POS' : 'Receive Payments' ?><div class="text-muted"><?= h($r['received_by_name']) ?></div></td>
      <td class="ck-c-pay small" data-label="Payment"><?= $r['payment_txn_id'] ? Txn::link((int)$r['payment_txn_id'], $r['payment_no']) : ($r['check_date'] <= today() ? '<span class="text-danger">Not recorded</span>' : '<span class="text-muted">On ' . h(fdate($r['check_date'])) . '</span>') ?>
        <?= $r['return_no'] ? '<div>' . Txn::link((int)$r['return_txn_id'], $r['return_no']) . '</div>' : '' ?></td>
    </tr>
  <?php endforeach; ?>
  <?php if (!$rows): ?><tr><td colspan="9" class="empty-row">No checks<?= $status !== 'all' && $status !== 'open' ? ' marked ' . h(Checks::statusText($status)) : ($status === 'open' ? ' waiting to clear' : '') ?>.</td></tr><?php endif; ?>
  </tbody>
  <?php if ($rows): ?><tfoot><tr class="grid-totals fw-semibold"><?php if ($canBulk): ?><td></td><?php endif; ?><td colspan="4"><?= count($rows) ?> check<?= count($rows) === 1 ? '' : 's' ?></td><td class="num"><?= money(array_sum(array_column($rows, 'amount'))) ?></td><td colspan="3"></td></tr></tfoot><?php endif; ?>
</table></div>
<?php if ($canBulk): ?>
<div class="card-body ck-bulk" id="ckBulkBar">
  <span class="small"><strong id="ckN">0</strong> ticked</span>
  <input class="form-control form-control-sm" type="date" name="status_date" value="<?= h(today()) ?>" aria-label="Date cleared">
  <input class="form-control form-control-sm" name="note" maxlength="255" placeholder="Note, e.g. the deposit slip" aria-label="Note">
  <button class="btn btn-sm btn-success" id="ckGo" disabled><i class="bi bi-check2-circle"></i> Mark cleared</button>
</div>
<?php endif; ?>
</div>
</form>
<p class="small text-muted mt-2">Pending: post-dated, nothing is in the books yet. On Date: its date has come and the payment is recorded. Cleared: deposited and honored. Returned: deposited and dishonored; open the check to mark it.</p>
<script>
(function () {
  const all = document.getElementById('ckAll');
  const ticks = Array.from(document.querySelectorAll('.ck-tick'));
  const go = document.getElementById('ckGo');
  if (!go) return;
  const paint = () => { const n = ticks.filter((t) => t.checked).length; document.getElementById('ckN').textContent = n; go.disabled = n === 0; if (all) all.checked = n > 0 && n === ticks.length; };
  ticks.forEach((t) => t.addEventListener('change', paint));
  if (all) all.addEventListener('change', () => { ticks.forEach((t) => { t.checked = all.checked; }); paint(); });
  paint();
})();
</script>
<?php
layout_end();
