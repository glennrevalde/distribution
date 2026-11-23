<?php
declare(strict_types=1);

require_once APP_ROOT . '/modules/txn/_common.php';

/**
 * Inventory > Inventory Transfer Closing (distribution, v2)
 *
 * The van salesman (or an outlet) remits the sales of the day and sends back what is left to the warehouse or cold
 * storage. The site's whole balance is listed (one line per open crate, one per item outside crates); the receiver types
 * what came back in crates, kilos, packs or another unit of the item, and says what any difference is: shrinkage,
 * shortage, or part of each. See TransferClosing for what is recorded.
 */
$pageKey = 'inv.transfer_closing';
$a = g('a', 'list');

if (!TransferClosing::ready()) {
    layout_start('Inventory Transfer Closing');
    echo '<div class="alert alert-warning">This page needs the database update of this version. Ask the Super Admin to run Database updates, or run database/migrations/2027_03_08_van_closing_shortages.sql.</div>';
    layout_end();
    return;
}

// ------------------------------------------------------------------ void
if ($a === 'void' && is_post()) {
    Access::require($pageKey, 'delete');
    $id = pint('id') ?? 0;
    try {
        TransferClosing::void($id, (string)p('reason'));
        flash('success', 'The closing was voided: its transfer, shortage charge and shrinkage adjustment are void, and the stock is back at the site it was closed for.');
    } catch (UserError $e) {
        flash('danger', $e->getMessage());
    }
    redirect(url($pageKey, ['a' => 'view', 'id' => $id]));
}

/** The documents of a closing, as links */
function tc_doc_links(array $c): array
{
    $out = [];
    foreach (['transfer_txn_id' => 'Transfer', 'shrink_txn_id' => 'Shrinkage adjustment', 'shortage_txn_id' => 'Shortage charge'] as $k => $label) {
        if (!empty($c[$k]) && ($t = Txn::load((int)$c[$k]))) {
            $out[] = $label . ' ' . Txn::link($t, (string)$t['txn_no']) . ((int)$t['is_voided'] === 1 ? ' (void)' : '');
        }
    }
    return $out;
}

/** "245.30 kg, 40 pack" from base unit => quantity */
function tc_by_unit(array $byUnit): string
{
    $parts = [];
    foreach ($byUnit as $u => $q) {
        if (abs($q) > 0.00001) {
            $parts[] = Crates::fig($q, $u) . ' ' . $u;
        }
    }
    return $parts ? implode(', ', $parts) : '0';
}

// ------------------------------------------------------------------ list
if ($a === 'list') {
    $from = gdate('from', date('Y-m-d', strtotime('-30 days')));
    $to = gdate('to', today());
    $siteF = gint('site_id');
    $repF = gint('rep_id');
    $where = ['tc.closing_date BETWEEN :f AND :t'];
    $params = ['f' => $from, 't' => $to];
    if ($siteF) {
        $where[] = 'tc.from_site_id = :s';
        $params['s'] = $siteF;
    }
    if ($repF) {
        $where[] = 'tc.sales_rep_id = :r';
        $params['r'] = $repF;
    }
    [$sf, $sp] = Access::siteFilter('tc.from_site_id', 'tcs');
    $rows = DB::all("SELECT tc.*, fs.name AS from_name, ts.name AS to_name, sr.name AS rep_name, sr.rep_type, sh.txn_no AS shortage_no, sh.status AS shortage_status
                       FROM transfer_closings tc JOIN sites fs ON fs.id = tc.from_site_id JOIN sites ts ON ts.id = tc.to_site_id
                       LEFT JOIN sales_reps sr ON sr.id = tc.sales_rep_id LEFT JOIN transactions sh ON sh.id = tc.shortage_txn_id
                      WHERE " . implode(' AND ', $where) . $sf . ' ORDER BY tc.closing_date DESC, tc.id DESC LIMIT 500', $params + $sp);
    $sites = Lookup::sites();
    layout_start('Inventory Transfer Closing', ['actions' => page_link($pageKey, ['a' => 'new'], 'New closing', 'btn-primary', 'plus-lg', 'create')
        . ' ' . page_link('inv.shortages', [], 'Shortage Charges', 'btn-outline-secondary', 'person-exclamation')
        . ' ' . page_link('rpt.closing_register', [], 'Closing register', 'btn-outline-secondary', 'journal-text')]);
    ?>
    <form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
      <div class="row g-2 align-items-end">
        <?= input_field('from', 'From', $from, ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
        <?= input_field('to', 'To', $to, ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
        <?= select_field('site_id', 'Van or outlet closed', $sites, $siteF, ['blank' => 'Every site', 'class' => 'col-md-3', 'no_add' => true]) ?>
        <?= select_field('rep_id', 'Sales rep or cashier', SalesReps::pickers(), $repF, ['blank' => 'Anyone', 'class' => 'col-md-3', 'no_add' => true]) ?>
        <div class="col-md-2"><button class="btn btn-sm btn-outline-primary w-100"><i class="bi bi-funnel"></i> Show</button></div>
      </div>
    </form>
    <div class="card"><div class="table-responsive"><table class="table table-sm table-hover mb-0 tc-list">
      <thead><tr><th>No.</th><th>Date</th><th>Closed</th><th>Back to</th><th>Sales rep or cashier</th><th class="num">Lines</th><th class="num">Shrinkage</th><th class="num">Shortage</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($rows as $r): $n = (int)DB::value('SELECT COUNT(*) FROM transfer_closing_lines WHERE closing_id = :c', ['c' => $r['id']]); ?>
        <tr class="<?= $r['status'] === 'void' ? 'is-void' : '' ?>">
          <td class="fw-semibold"><a href="<?= h(url($pageKey, ['a' => 'view', 'id' => $r['id']])) ?>"><?= h($r['closing_no']) ?></a></td>
          <td><?= h(fdate($r['closing_date'])) ?></td><td><?= h($r['from_name']) ?></td><td><?= h($r['to_name']) ?></td>
          <td><?= $r['rep_name'] ? h($r['rep_name']) . ' <span class="small text-muted">' . h(SalesReps::typeText($r['rep_type'])) . '</span>' : '' ?></td>
          <td class="num"><?= $n ?></td>
          <td class="num"><?= (float)$r['shrink_qty'] > 0 ? (Access::viewCosts() ? money($r['shrink_amount']) : qty($r['shrink_qty'])) : '' ?></td>
          <td class="num"><?= (float)$r['shortage_amount'] > 0 ? money($r['shortage_amount']) : '' ?></td>
          <td><span class="state-text state-<?= h($r['status'] === 'void' ? 'void' : 'received') ?>"><?= $r['status'] === 'void' ? 'Void' : 'Posted' ?></span>
            <?= $r['shortage_no'] && $r['status'] !== 'void' ? '<span class="small text-muted ms-1">' . ($r['shortage_status'] === 'paid' ? 'shortage collected' : 'shortage to collect') . '</span>' : '' ?></td>
          <td class="text-end"><a class="btn btn-sm btn-outline-secondary" href="<?= h(url($pageKey, ['a' => 'print', 'id' => $r['id']])) ?>" title="Print the closing sheet" aria-label="Print <?= h($r['closing_no']) ?>"><i class="bi bi-printer"></i></a></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$rows): ?><tr><td colspan="10" class="empty-row">No closing from <?= h(fdate($from)) ?> to <?= h(fdate($to)) ?>.<?= Access::can($pageKey, 'create') ? ' <a href="' . h(url($pageKey, ['a' => 'new'])) . '">Close a van or outlet</a>.' : '' ?></td></tr><?php endif; ?>
      </tbody></table></div></div>
    <?php
    layout_end();
    return;
}

// ------------------------------------------------------------------ one closing (and its printed sheet)
if ($a === 'view' || $a === 'print') {
    $c = TransferClosing::load(gint('id') ?? 0);
    if (!$c) {
        flash('warning', 'Closing not found.');
        redirect(url($pageKey));
    }
    if (!Access::siteAllowed((int)$c['from_site_id'])) {
        Access::denyPage($pageKey, 'open a closing of another site on');
    }
    $lines = TransferClosing::lines((int)$c['id']);
    $costs = Access::viewCosts();
    $accts = Accts::all(false);
    $byUnit = ['balance' => [], 'transfer_qty' => [], 'shrink_qty' => [], 'shortage_qty' => []];
    foreach ($lines as $l) {
        foreach ($byUnit as $k => $_) {
            $byUnit[$k][$l['unit']] = ($byUnit[$k][$l['unit']] ?? 0.0) + (float)$l[$k];
        }
    }
    $print = $a === 'print';
    if ($print) {
        Access::require($pageKey, 'print');
        layout_start('Inventory Transfer Closing ' . $c['closing_no'], ['bare' => true, 'no_title' => true]);
        echo '<div class="no-print mb-2 text-center print-toolbar"><button class="btn btn-primary btn-sm" onclick="window.print()"><i class="bi bi-printer"></i> Print</button> '
            . '<a class="btn btn-outline-secondary btn-sm" href="' . h(url($pageKey, ['a' => 'view', 'id' => $c['id']])) . '">Back</a></div>';
        echo '<div class="tc-print">' . print_company_block('logo') . '<h1 class="tc-print-title">Inventory Transfer Closing ' . h($c['closing_no']) . '</h1>';
    } else {
        layout_start('Inventory Transfer Closing ' . $c['closing_no'], ['actions' => btn_link(url($pageKey, ['a' => 'print', 'id' => $c['id']]), 'Print', 'btn-outline-secondary', 'printer')
            // v3: what came back, on the POS printer crate by crate (the slip of the closing's transfer)
            . ($c['transfer_txn_id'] && Access::can('inv.transfers', 'print') ? ' ' . btn_link(url('inv.transfers', ['a' => 'receipt', 'id' => (int)$c['transfer_txn_id']]), 'Print POS Receipt', 'btn-outline-primary', 'receipt') : '')
            . ' ' . page_link($pageKey, ['a' => 'new', 'from_id' => $c['from_site_id'], 'to_id' => $c['to_site_id']], 'New closing', 'btn-outline-primary', 'plus-lg', 'create')
            . ' ' . btn_link(url($pageKey), 'All closings', 'btn-outline-secondary', 'list-ul')
            . ($c['status'] === 'posted' && Access::can($pageKey, 'delete') ? ' <button type="button" class="btn btn-sm btn-outline-danger" data-bs-toggle="modal" data-bs-target="#tcVoid"><i class="bi bi-x-circle"></i> Void closing</button>' : '')]);
        $docs = tc_doc_links($c);
        echo '<div class="doc-state mb-3"><span class="state-text state-' . ($c['status'] === 'void' ? 'void' : 'received') . '">' . ($c['status'] === 'void' ? 'Void' : 'Posted') . '</span>'
            . ($docs ? '<span>' . implode(', ', $docs) . '</span>' : '')
            . ($c['status'] === 'void' ? '<span>Voided ' . h(fdate(substr((string)$c['voided_at'], 0, 10))) . ': ' . h((string)$c['void_reason']) . '</span>' : '') . '</div>';
    }
    ?>
    <dl class="crate-facts tc-facts mb-3">
      <div><dt>Date</dt><dd><?= h(fdate($c['closing_date'])) ?></dd></div>
      <div><dt>Closed (van or outlet)</dt><dd><?= h($c['from_name']) ?></dd></div>
      <div><dt>Back to</dt><dd><?= h($c['to_name']) ?></dd></div>
      <div><dt>Sales rep or cashier</dt><dd><?= $c['rep_name'] ? h($c['rep_name']) . ' <span class="small text-muted">' . h(SalesReps::typeText($c['rep_type'])) . '</span>' : 'None' ?></dd></div>
      <div><dt>Shortage charged to</dt><dd><?= $c['customer_name'] ? h($c['customer_name']) : 'No shortage' ?></dd></div>
      <div><dt>Shrinkage adjustment account</dt><dd><?= h($accts[(int)$c['shrink_account_id']] ?? '') ?></dd></div>
      <div><dt>Shortage receivable account</dt><dd><?= h($accts[(int)$c['shortage_account_id']] ?? '') ?></dd></div>
      <div><dt>Came back</dt><dd class="fig"><?= h(tc_by_unit($byUnit['transfer_qty'])) ?></dd></div>
      <div><dt>Shrinkage</dt><dd class="fig"><?= h(tc_by_unit($byUnit['shrink_qty'])) ?><?= $costs && (float)$c['shrink_amount'] > 0 ? ' <span class="small text-muted">' . money($c['shrink_amount']) . '</span>' : '' ?></dd></div>
      <div><dt>Shortage</dt><dd class="fig"><?= h(tc_by_unit($byUnit['shortage_qty'])) ?><?= (float)$c['shortage_amount'] > 0 ? ' <span class="small text-muted">' . money($c['shortage_amount']) . '</span>' : '' ?></dd></div>
      <?php if ($c['memo']): ?><div class="tc-facts-wide"><dt>Remarks</dt><dd><?= h($c['memo']) ?></dd></div><?php endif; ?>
    </dl>
    <div class="card mb-3"><div class="table-responsive"><table class="table table-sm mb-0 tc-sheet">
      <thead><tr><th>Item</th><th>Description</th><th>Crate no.</th><th>U/M</th><th class="num">Balance</th><th class="num">Came back</th><th class="num">Shrinkage</th><th class="num">Shortage</th>
        <?= $costs ? '<th class="num">Unit cost</th>' : '' ?><th class="num">Shortage amount</th><th>Note</th></tr></thead>
      <tbody>
      <?php foreach ($lines as $l): ?>
        <tr><td class="fw-semibold tc-s-code"><?= h($l['code']) ?></td><td class="tc-s-name"><?= h($l['name']) ?></td><td class="crate-no tc-s-crate"<?= $l['crate_no'] !== null && $l['crate_no'] !== '' ? ' data-label="Crate"' : '' ?>><?= h((string)$l['crate_no']) ?></td><td data-label="U/M"><?= h((string)$l['unit']) ?></td>
          <td class="num" data-label="Balance"><?= Crates::fig($l['balance'], $l['unit']) ?></td><td class="num" data-label="Came back"><?= Crates::fig($l['transfer_qty'], $l['unit']) ?></td>
          <td class="num<?= (float)$l['shrink_qty'] > 0 ? ' tc-amber' : ' tc-s-none' ?>" data-label="Shrinkage"><?= (float)$l['shrink_qty'] > 0 ? Crates::fig($l['shrink_qty'], $l['unit']) : '' ?></td>
          <td class="num<?= (float)$l['shortage_qty'] > 0 ? ' tc-red' : ' tc-s-none' ?>" data-label="Shortage"><?= (float)$l['shortage_qty'] > 0 ? Crates::fig($l['shortage_qty'], $l['unit']) : '' ?></td>
          <?= $costs ? '<td class="num" data-label="Unit cost">' . number_format((float)$l['unit_cost'], 2) . '</td>' : '' ?>
          <td class="num<?= (float)$l['shortage_qty'] > 0 ? '' : ' tc-s-none' ?>" data-label="Shortage amount"><?= (float)$l['shortage_qty'] > 0 ? money(r2((float)$l['shortage_qty'] * (float)$l['unit_cost'])) : '' ?></td>
          <td class="small tc-s-note<?= (string)$l['note'] === '' ? ' tc-s-none' : '' ?>" data-label="Note"><?= h((string)$l['note']) ?></td></tr>
      <?php endforeach; ?>
      </tbody>
    </table></div></div>
    <div class="tc-signs">
      <div><span class="tc-sign-name"><?= h((string)$c['transferred_by']) ?></span><span class="tc-sign-label">Transferred by</span></div>
      <div><span class="tc-sign-name"><?= h((string)$c['checked_by']) ?></span><span class="tc-sign-label">Checked by</span></div>
      <div><span class="tc-sign-name"><?= h((string)$c['received_by']) ?></span><span class="tc-sign-label">Received by</span></div>
    </div>
    <?php
    if ($print) {
        echo '<p class="small text-muted mt-3">Recorded by ' . h((string)($c['created_name'] ?: $c['username'])) . ' on ' . h(fdate(substr((string)$c['created_at'], 0, 10))) . '. '
            . h(implode(', ', array_map('strip_tags', tc_doc_links($c)))) . '</p></div>';
    } elseif ($c['status'] === 'posted' && Access::can($pageKey, 'delete')) {
        echo reason_modal('tcVoid', 'Void closing', url($pageKey, ['a' => 'void']), 'btn-danger',
            '<input type="hidden" name="id" value="' . (int)$c['id'] . '"><p class="small text-muted mt-2 mb-0">The transfer, the shortage charge and the shrinkage adjustment are voided together; the crates and the stock go back to '
            . h($c['from_name']) . '. A shortage charge that has payments applied to it is not voided: remove the payment first.</p>');
    }
    layout_end();
    return;
}

// ------------------------------------------------------------------ new closing
Access::require($pageKey, 'create');
$allSites = Lookup::sites();
$siteTypes = DB::pairs('SELECT id, site_type FROM sites');
$firstOf = function (array $types) use ($allSites, $siteTypes) {
    foreach (array_keys($allSites) as $id) {
        if (in_array($siteTypes[$id] ?? '', $types, true)) {
            return (int)$id;
        }
    }
    return null;
};
$fromId = gint('from_id') ?: (is_post() ? pint('from_site_id') : null) ?: $firstOf(['van']) ?: (int)array_key_first($allSites);
$toId = gint('to_id') ?: (is_post() ? pint('to_site_id') : null) ?: $firstOf(['warehouse']);
if ($toId === $fromId) {
    $toId = null;
}
$date = gdate('date', '') ?: (is_post() ? (string)(pdate('closing_date') ?: today()) : today());

handle_post(function () use ($pageKey) {
    Access::require($pageKey, 'create');
    $id = TransferClosing::save([
        'closing_date' => pdate('closing_date') ?: '', 'from_site_id' => pint('from_site_id'), 'to_site_id' => pint('to_site_id'),
        'sales_rep_id' => pint('sales_rep_id'), 'customer_id' => pint('customer_id'), 'shrink_account_id' => pint('shrink_account_id'),
        'shortage_account_id' => pint('shortage_account_id'), 'transferred_by' => (string)p('transferred_by'), 'checked_by' => (string)p('checked_by'),
        'received_by' => (string)p('received_by'), 'memo' => (string)p('memo'),
    ], array_values((array)($_POST['rows'] ?? [])));
    $c = TransferClosing::load($id);
    flash('success', 'Closing ' . $c['closing_no'] . ' recorded: ' . implode(', ', array_map('strip_tags', tc_doc_links($c))) . '.');
    redirect_after_save(url($pageKey, ['a' => 'new', 'from_id' => $c['from_site_id'], 'to_id' => $c['to_site_id']]), url($pageKey, ['a' => 'view', 'id' => $id]));
});

SalesReps::ensureAll();   // every van salesman and cashier can be charged (the employee as a customer)
$siteRep = DB::pairs('SELECT id, sales_rep_id FROM sites WHERE sales_rep_id IS NOT NULL');
$repRows = DB::all('SELECT id, name, rep_type, customer_id FROM sales_reps WHERE is_active = 1 ORDER BY name');
$repCustomer = [];
$repName = [];
foreach ($repRows as $r) {
    $repCustomer[(int)$r['id']] = (int)$r['customer_id'];
    $repName[(int)$r['id']] = (string)$r['name'];
}
$repId = is_post() ? (pint('sales_rep_id') ?: null) : (isset($siteRep[$fromId]) ? (int)$siteRep[$fromId] : null);
$customerId = is_post() ? (pint('customer_id') ?: null) : ($repId ? ($repCustomer[$repId] ?? null) : null);
$rows = $fromId && Access::siteAllowed($fromId) ? TransferClosing::balances($fromId) : [];
$postedRows = [];
foreach ((array)($_POST['rows'] ?? []) as $pr) {
    $postedRows[(int)($pr['item_id'] ?? 0) . ':' . (int)($pr['crate_id'] ?? 0)] = $pr;
}
$costs = Access::viewCosts();
$unitCost = [];
foreach (array_unique(array_column($rows, 'item_id')) as $iid) {
    $unitCost[(int)$iid] = TransferClosing::unitCost((int)$iid);
}
$people = DB::column("SELECT full_name FROM users WHERE status = 'active' AND is_platform = 0 ORDER BY full_name");
$me = (string)(Auth::user()['full_name'] ?? '');
$fq = fn($v) => rtrim(rtrim(number_format((float)$v, 4, '.', ''), '0'), '.');

layout_start('Inventory Transfer Closing', ['actions' => btn_link(url($pageKey), 'All closings', 'btn-outline-secondary', 'list-ul')
    . ' ' . page_link('inv.shortages', [], 'Shortage Charges', 'btn-outline-secondary', 'person-exclamation')]);
?>
<form method="get" class="filter-bar mb-3 tc-go"><input type="hidden" name="p" value="<?= h($pageKey) ?>"><input type="hidden" name="a" value="new">
  <div class="row g-2 align-items-end">
    <?= select_field('from_id', 'From (van, outlet or other site)', $allSites, $fromId, ['class' => 'col-md-4', 'no_add' => true, 'extra' => 'id="tcFrom"']) ?>
    <?= select_field('to_id', 'To (warehouse or cold storage)', $allSites, $toId, ['blank' => '— choose —', 'class' => 'col-md-4', 'no_add' => true]) ?>
    <?= input_field('date', 'Closing date', $date, ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
    <div class="col-6 col-md-2"><button class="btn btn-sm btn-outline-primary w-100"><i class="bi bi-arrow-repeat"></i> Show balances</button></div>
  </div>
</form>

<form method="post" id="tcForm" class="tc-form" data-costs="<?= $costs ? 1 : 0 ?>"><?= csrf_field() ?>
<input type="hidden" name="from_site_id" value="<?= (int)$fromId ?>"><input type="hidden" name="to_site_id" value="<?= (int)$toId ?>"><input type="hidden" name="closing_date" value="<?= h($date) ?>">
<div class="card mb-3"><div class="card-body"><div class="row g-2 align-items-end">
  <?= select_field('sales_rep_id', 'Van salesman, sales rep or cashier', SalesReps::pickers(), $repId, ['blank' => '— none —', 'class' => 'col-md-4', 'no_add' => true, 'extra' => 'id="tcRep" data-combo' . QuickAdd::attr('rep')]) ?>
  <?= select_field('customer_id', 'Shortage charged to (cashier, sales rep or customer)', SalesReps::labelCustomers(Lookup::customers(false)), $customerId, ['blank' => '— choose when there is a shortage —', 'class' => 'col-md-4', 'no_add' => true, 'extra' => 'id="tcCust" data-combo']) ?>
  <?= select_field('shortage_account_id', 'Shortage receivable GL account', Accts::ofType(['Accounts Receivable', 'Other Current Asset']), fv('shortage_account_id', null, Accts::get('shortage_receivable')), ['class' => 'col-md-4', 'no_add' => true]) ?>
  <?= select_field('shrink_account_id', 'Shrinkage adjustment GL account', Accts::all(), fv('shrink_account_id', null, Accts::get('inventory_adjustment')), ['class' => 'col-md-4', 'no_add' => true]) ?>
  <?= input_field('transferred_by', 'Transferred by', fv('transferred_by', null, $repId ? ($repName[$repId] ?? '') : ''), ['class' => 'col-md-4 col-lg-2', 'extra' => 'list="tcPeople" id="tcBy"']) ?>
  <?= input_field('checked_by', 'Checked by', fv('checked_by'), ['class' => 'col-md-4 col-lg-2', 'extra' => 'list="tcPeople"']) ?>
  <?= input_field('received_by', 'Received by', fv('received_by', null, $me), ['class' => 'col-md-4 col-lg-2', 'extra' => 'list="tcPeople"']) ?>
  <?= input_field('memo', 'Remarks', fv('memo'), ['class' => 'col-md-8 col-lg-6', 'extra' => 'maxlength="255"']) ?>
  <datalist id="tcPeople"><?php foreach ($people as $pn): ?><option value="<?= h($pn) ?>"><?php endforeach; ?><?php foreach ($repName as $pn): ?><option value="<?= h($pn) ?>"><?php endforeach; ?></datalist>
</div></div></div>

<div class="card mb-3 tc-card">
  <div class="card-header tc-head">
    <div><strong>Balance of <?= h($allSites[$fromId] ?? 'the site') ?></strong> <span class="small text-muted">what the site holds now, one line per crate</span></div>
    <div class="tc-tools">
      <div class="live-search tc-find"><i class="bi bi-search"></i><input class="form-control form-control-sm" type="search" id="tcFind" placeholder="Find an item or crate" autocomplete="off" aria-label="Find an item or crate"></div>
      <button type="button" class="btn btn-sm btn-outline-secondary" data-tc-all="back" title="Everything ticked came back as listed"><i class="bi bi-check2-all"></i> All came back</button>
      <button type="button" class="btn btn-sm btn-outline-secondary" data-tc-all="shrink" title="Every difference is shrinkage"><i class="bi bi-droplet-half"></i> Variance to shrinkage</button>
      <button type="button" class="btn btn-sm btn-outline-secondary" data-tc-all="shortage" title="Every difference is a shortage"><i class="bi bi-person-exclamation"></i> Variance to shortage</button>
    </div>
  </div>
  <div class="table-responsive"><table class="table table-sm mb-0 tc-grid" id="tcGrid">
    <thead><tr><th class="tc-c-use"><input type="checkbox" class="form-check-input" id="tcAll" checked aria-label="Tick every line"></th><th>Item</th><th>Crate</th><th>U/M</th><th class="num">Balance</th>
      <th class="num">Transfer qty/wgt</th><th class="num">Variance</th><th class="num">Shrinkage</th><th class="num">Shortage</th><th>Note</th></tr></thead>
    <tbody>
    <?php foreach ($rows as $i => $r):
        $key = $r['item_id'] . ':' . $r['crate_id'];
        $pr = $postedRows[$key] ?? null;
        $neg = (float)$r['balance'] < -0.00001;
        $use = $pr ? !empty($pr['use']) : !$neg;
        $factor = 1.0;
        $uomId = $pr ? (int)($pr['uom_id'] ?? 0) : 0;
        foreach ($r['units'] as $u) {
            if ($u['id'] === $uomId) {
                $factor = $u['factor'];
            }
        }
        $bal = (float)$r['balance'] / $factor;
        $tr = $pr ? (string)($pr['transfer'] ?? '') : ($neg ? '0' : $fq($bal));
        $days = $r['exp'] ? (int)floor((strtotime($r['exp']) - strtotime(today())) / 86400) : null;
        $n = 'rows[' . $i . ']'; ?>
      <tr class="tc-row<?= $r['crate_id'] ? ' is-crate' : '' ?><?= $neg ? ' is-neg' : '' ?><?= $use ? '' : ' is-off' ?>" data-base="<?= h($fq($r['balance'])) ?>" data-factor="<?= h($fq($factor)) ?>"
          data-cost="<?= h((string)($unitCost[(int)$r['item_id']] ?? 0)) ?>" data-unit="<?= h($r['base']) ?>" data-find="<?= h(mb_strtolower($r['code'] . ' ' . $r['name'] . ' ' . $r['crate_no'])) ?>">
        <td class="tc-c-use"><input type="hidden" name="<?= $n ?>[item_id]" value="<?= (int)$r['item_id'] ?>"><input type="hidden" name="<?= $n ?>[crate_id]" value="<?= (int)$r['crate_id'] ?>">
          <input type="hidden" name="<?= $n ?>[balance]" value="<?= h($fq($bal)) ?>" data-tc-bal>
          <input type="checkbox" class="form-check-input" name="<?= $n ?>[use]" value="1"<?= $use ? ' checked' : '' ?><?= $neg ? ' disabled' : '' ?> data-tc-use aria-label="Close this line"></td>
        <td class="tc-c-item"><strong><?= h($r['code']) ?></strong><span class="tc-name"><?= h($r['name']) ?></span></td>
        <td class="tc-c-crate"><?php if ($r['crate_id']): ?><span class="crate-no"><?= h($r['crate_no']) ?></span><span class="tc-crate-meta"><?= (float)$r['pcs'] > 0 ? qty($r['pcs']) . ' heads' : '' ?><?= $r['exp'] ? ($r['pcs'] > 0 ? ', ' : '') . 'exp. ' . h(fdate($r['exp'])) : '' ?></span>
          <?php elseif (!empty($r['in_crates'])): ?><span class="small text-muted">Loose, outside crates</span><?php else: ?><span class="small text-muted">Not in crates</span><?php endif; ?></td>
        <td class="tc-c-unit" data-label="U/M"><?php if ($r['units']): ?><select class="form-select form-select-sm" name="<?= $n ?>[uom_id]" data-tc-uom data-no-combo aria-label="Unit counted in">
            <?php foreach ($r['units'] as $u): ?><option value="<?= (int)$u['id'] ?>" data-factor="<?= h($fq($u['factor'])) ?>"<?= ($uomId ? $u['id'] === $uomId : $u['base']) ? ' selected' : '' ?>><?= h($u['code']) ?></option><?php endforeach; ?></select>
          <?php else: ?><?= h($r['base']) ?><?php endif; ?></td>
        <td class="num tc-c-bal" data-label="Balance"><span data-tc-balshow><?= h(Crates::fig($bal, $r['base'])) ?></span><?= $neg ? '<span class="tc-neg-note">Below zero</span>' : '' ?></td>
        <td class="tc-c-q" data-label="Transfer qty/wgt"><input class="form-control form-control-sm text-end" inputmode="decimal" name="<?= $n ?>[transfer]" value="<?= h($tr) ?>" data-tc-q="transfer" aria-label="Transfer quantity or weight"<?= $neg ? ' disabled' : '' ?>></td>
        <td class="num tc-c-var" data-label="Variance" data-tc-var></td>
        <td class="tc-c-q" data-label="Shrinkage"><input class="form-control form-control-sm text-end" inputmode="decimal" name="<?= $n ?>[shrink]" value="<?= h($pr ? (string)($pr['shrink'] ?? '') : '') ?>" data-tc-q="shrink" aria-label="Shrinkage"<?= $neg ? ' disabled' : '' ?>></td>
        <td class="tc-c-q" data-label="Shortage"><input class="form-control form-control-sm text-end" inputmode="decimal" name="<?= $n ?>[shortage]" value="<?= h($pr ? (string)($pr['shortage'] ?? '') : '') ?>" data-tc-q="shortage" aria-label="Shortage"<?= $neg ? ' disabled' : '' ?>></td>
        <td class="tc-c-note" data-label="Note"><input class="form-control form-control-sm" name="<?= $n ?>[note]" value="<?= h($pr ? (string)($pr['note'] ?? '') : '') ?>" maxlength="255" aria-label="Note"<?= $neg ? ' disabled' : '' ?>></td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$rows): ?><tr><td colspan="10" class="empty-row"><?= $fromId ? 'Nothing is on hand at ' . h($allSites[$fromId] ?? 'this site') . ': there is nothing to close.' : 'Choose the site to close and press Show balances.' ?></td></tr><?php endif; ?>
    </tbody>
  </table></div>
  <?php if ($rows): ?>
  <div class="tc-foot">
    <div class="scale-readout" aria-live="polite"><span class="scale-digits" id="tcBack">0.00</span><span class="scale-unit" id="tcBackUnit">kg back</span><span class="scale-count" id="tcLines">0 lines</span></div>
    <dl class="tc-sum">
      <div><dt>Came back</dt><dd id="tcSumBack">0</dd></div>
      <div><dt>Shrinkage</dt><dd id="tcSumShrink">0</dd></div>
      <div><dt>Shortage</dt><dd id="tcSumShort">0</dd></div>
      <?php if ($costs): ?><div><dt>Shrinkage at cost</dt><dd id="tcCostShrink">0.00</dd></div><?php endif; ?>
      <div><dt>Shortage charged at cost</dt><dd id="tcCostShort">0.00</dd></div>
    </dl>
  </div>
  <?php endif; ?>
</div>
<p class="small text-muted">Type in <strong>Transfer qty/wgt</strong> what came back: the weight of each crate as re-weighed, the kilos, packs or other unit counted. Any difference must be put down as <strong>shrinkage</strong>
  (adjusted to the shrinkage account at average cost) or <strong>shortage</strong> (charged at cost to the person above, collected through Receive Payments, never counted as a sale), or part of each.
  Lines not ticked stay at the site.</p>
<div class="form-actions">
  <?php if ($rows): ?><button class="btn btn-primary" name="save" value="1"><i class="bi bi-check-lg"></i> Save closing</button>
  <button class="btn btn-outline-primary" name="save_new" value="1"><i class="bi bi-plus-lg"></i> Save &amp; New</button><?php endif; ?>
  <a class="btn btn-outline-secondary" href="<?= h(url($pageKey, ['a' => 'new', 'from_id' => $fromId, 'to_id' => $toId, 'date' => $date])) ?>"><i class="bi bi-arrow-counterclockwise"></i> Reset</a>
  <a class="btn btn-outline-secondary" href="<?= h(url($pageKey)) ?>">Close</a>
</div>
</form>
<script>
(function () {
  const form = document.getElementById('tcForm');
  const grid = document.getElementById('tcGrid');
  if (!form || !grid) return;
  const repCustomer = <?= json_encode((object)$repCustomer) ?>, repName = <?= json_encode((object)$repName) ?>;
  const num = (v) => { const n = parseFloat(String(v == null ? '' : v).replace(/,/g, '')); return isFinite(n) ? n : 0; };
  const r4 = (n) => Math.round(n * 10000) / 10000;
  const show = (n) => String(r4(n));
  const fmt2 = (n) => n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const fig = (n, u) => (/^(kg|kgs|kilo|kilos|g|lb|lbs)$/i.test(u) || /kilo/i.test(u) ? fmt2(n) : n.toLocaleString('en-US', { maximumFractionDigits: 3 }));
  const rows = () => Array.prototype.slice.call(grid.querySelectorAll('tr.tc-row'));
  const inp = (tr, k) => tr.querySelector('[data-tc-q="' + k + '"]');

  // the balance, in the unit the line is counted in
  const balOf = (tr) => num(tr.querySelector('[data-tc-bal]').value);
  // a difference left alone goes where it most likely belongs: a crate that came back lighter dried out (shrinkage),
  // a crate or item that did not come back is missing (shortage). Typed shrinkage or shortage is kept.
  function split(tr, from) {
    const bal = balOf(tr), back = num(inp(tr, 'transfer').value);
    const v = r4(bal - back);
    const sh = inp(tr, 'shrink'), so = inp(tr, 'shortage');
    if (from === 'shrink') { so.value = v > 0 ? show(Math.max(0, r4(v - num(sh.value)))) : ''; }
    else if (from === 'shortage') { sh.value = v > 0 ? show(Math.max(0, r4(v - num(so.value)))) : ''; }
    else if (v <= 0) { sh.value = ''; so.value = ''; }
    else if (tr.dataset.touched === 'shrink') { so.value = show(Math.max(0, r4(v - num(sh.value)))); }
    else if (tr.dataset.touched === 'shortage') { sh.value = show(Math.max(0, r4(v - num(so.value)))); }
    else if (tr.classList.contains('is-crate') && back > 0) { sh.value = show(v); so.value = ''; }
    else { so.value = show(v); sh.value = ''; }
    if (sh.value === '0') sh.value = '';
    if (so.value === '0') so.value = '';
  }
  function paint(tr) {
    const bal = balOf(tr), back = num(inp(tr, 'transfer').value), v = r4(bal - back);
    const cell = tr.querySelector('[data-tc-var]');
    const unit = tr.dataset.unit;
    cell.textContent = Math.abs(v) < 0.00005 ? '' : (v > 0 ? '-' : '+') + fig(Math.abs(v), unit);
    const off = Math.abs(r4(back + num(inp(tr, 'shrink').value) + num(inp(tr, 'shortage').value) - bal)) > 0.0005;
    tr.classList.toggle('is-bad', !tr.classList.contains('is-off') && (off || v < -0.00005));
    cell.classList.toggle('is-var', v > 0.00005);
    tr.title = v < -0.00005 ? 'More than the balance came back: check the weight, or record the stock that came in first.' : (off ? 'What came back, the shrinkage and the shortage must add up to the balance.' : '');
  }
  function totals() {
    const back = {}, shrink = {}, short = {};
    let cShrink = 0, cShort = 0, n = 0, kg = 0;
    rows().forEach((tr) => {
      if (tr.classList.contains('is-off')) return;
      const f = num(tr.dataset.factor) || 1, u = tr.dataset.unit, c = num(tr.dataset.cost);
      const b = num(inp(tr, 'transfer').value) * f, s = num(inp(tr, 'shrink').value) * f, o = num(inp(tr, 'shortage').value) * f;
      back[u] = (back[u] || 0) + b; shrink[u] = (shrink[u] || 0) + s; short[u] = (short[u] || 0) + o;
      cShrink += s * c; cShort += Math.round(o * c * 100) / 100; n++;
      if (/^kg$/i.test(u)) kg += b;
    });
    const txt = (o) => Object.keys(o).filter((u) => Math.abs(o[u]) > 0.00005).map((u) => fig(o[u], u) + ' ' + u).join(', ') || '0';
    const set = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
    set('tcSumBack', txt(back)); set('tcSumShrink', txt(shrink)); set('tcSumShort', txt(short));
    set('tcCostShrink', fmt2(cShrink)); set('tcCostShort', fmt2(cShort));
    set('tcBack', fmt2(kg)); set('tcLines', n + (n === 1 ? ' line' : ' lines'));
  }
  grid.addEventListener('input', (e) => {
    const k = e.target.dataset.tcQ; if (!k) return;
    const tr = e.target.closest('tr');
    if (k === 'shrink' || k === 'shortage') tr.dataset.touched = k;
    split(tr, k === 'transfer' ? null : k);
    paint(tr); totals();
  });
  grid.addEventListener('change', (e) => {
    const tr = e.target.closest('tr.tc-row');
    if (e.target.matches('[data-tc-use]')) {
      tr.classList.toggle('is-off', !e.target.checked);
      tr.querySelectorAll('input:not([type=hidden]):not([data-tc-use]), select').forEach((x) => { x.tabIndex = e.target.checked ? 0 : -1; });
      paint(tr); totals();
    } else if (e.target.matches('[data-tc-uom]')) {
      // counted in another unit: every figure of the line follows
      const o = e.target.options[e.target.selectedIndex], oldF = num(tr.dataset.factor) || 1, f = num(o.dataset.factor) || 1;
      ['transfer', 'shrink', 'shortage'].forEach((k) => { const x = inp(tr, k); if (x.value !== '') x.value = show(num(x.value) * oldF / f); });
      tr.dataset.factor = String(f);
      const bal = num(tr.dataset.base) / f;
      tr.querySelector('[data-tc-bal]').value = show(bal);
      tr.querySelector('[data-tc-balshow]').textContent = fig(bal, o.textContent);
      paint(tr); totals();
    }
  });
  document.getElementById('tcAll').addEventListener('change', (e) => {
    rows().forEach((tr) => { const c = tr.querySelector('[data-tc-use]'); if (!c.disabled && c.checked !== e.target.checked) { c.checked = e.target.checked; c.dispatchEvent(new Event('change', { bubbles: true })); } });
  });
  document.querySelectorAll('[data-tc-all]').forEach((b) => b.addEventListener('click', () => {
    const how = b.dataset.tcAll;
    rows().forEach((tr) => {
      if (tr.classList.contains('is-off') || tr.classList.contains('is-neg')) return;
      const bal = balOf(tr), v = r4(bal - num(inp(tr, 'transfer').value));
      if (how === 'back') { inp(tr, 'transfer').value = show(bal); inp(tr, 'shrink').value = ''; inp(tr, 'shortage').value = ''; delete tr.dataset.touched; }
      else if (v > 0) { inp(tr, how).value = show(v); inp(tr, how === 'shrink' ? 'shortage' : 'shrink').value = ''; tr.dataset.touched = how; }
      paint(tr);
    });
    totals();
  }));
  const find = document.getElementById('tcFind');
  find.addEventListener('input', () => {
    const q = find.value.trim().toLowerCase();
    rows().forEach((tr) => { tr.hidden = q !== '' && tr.dataset.find.indexOf(q) < 0; });
  });
  // the person chosen: the shortage goes to them, and they handed the stock over
  const rep = document.getElementById('tcRep'), cust = document.getElementById('tcCust'), by = document.getElementById('tcBy');
  if (rep) rep.addEventListener('change', () => {
    const c = repCustomer[rep.value];
    if (c && cust) { cust.value = String(c); if (cust.comboSync) cust.comboSync(); }
    if (by && repName[rep.value] && (by.value === '' || Object.values(repName).indexOf(by.value) >= 0)) by.value = repName[rep.value];
  });
  // a person added with "Add new sales representative": their customer goes in "Shortage charged to" too
  document.addEventListener('gs:quickadd', (e) => {
    const r = e.detail || {};
    if (r.kind !== 'rep') return;
    repName[r.id] = r.name;
    if (r.customer) {
      repCustomer[r.id] = r.customer;
      if (cust && !Array.prototype.some.call(cust.options, (o) => o.value === String(r.customer))) {
        const o = document.createElement('option'); o.value = String(r.customer); o.textContent = r.typed || r.name; cust.appendChild(o);
      }
    }
    if (rep && rep.value === String(r.id)) rep.dispatchEvent(new Event('change', { bubbles: true }));
  });
  form.addEventListener('submit', (e) => {
    const bad = grid.querySelector('tr.is-bad:not(.is-off)');
    if (bad && !e.submitter?.dataset.force) {
      e.preventDefault();
      bad.hidden = false; bad.scrollIntoView({ block: 'center', behavior: 'smooth' });
      const x = inp(bad, 'transfer'); if (x) x.focus();
      if (window.AppToast) window.AppToast('A line does not add up: what came back, the shrinkage and the shortage must make its balance.', 'warn');
    }
  });
  rows().forEach((tr) => { if (!tr.classList.contains('is-off')) { if (inp(tr, 'shrink').value === '' && inp(tr, 'shortage').value === '') split(tr, null); } paint(tr); });
  totals();
})();
</script>
<?php
layout_end();
