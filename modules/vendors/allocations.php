<?php
declare(strict_types=1);

/**
 * Vendors > Supplier Allocation
 *
 * What is to be picked up from a supplier on a day: the supplier, the date, the location the goods go to and who
 * picks them up, with the number of crates (or kilos, or packs) of each of the supplier's items. "Go" lists the
 * supplier's items (Vendors > Supplier Items); the quantities are typed against them. The pick-up itself is done on
 * Pick-Up Supplier Items, where each crate is weighed and dated, and the goods are received into stock.
 */
require_once APP_ROOT . '/modules/txn/_common.php';

$pageKey = 'vend.allocations';
$a = g('a', 'list');

// ------------------------------------------------------------------ cancel
if ($a === 'cancel' && is_post()) {
    Access::require($pageKey, 'delete');
    $al = Allocations::load(pint('id') ?? 0);
    if (!$al || in_array($al['status'], ['received', 'cancelled'], true)) {
        flash('warning', 'Only an allocation that has not been received can be cancelled.');
        redirect(url($pageKey));
    }
    $reason = trim((string)p('reason'));
    if ($reason === '') {
        flash('warning', 'Enter the reason for cancelling the allocation.');
        redirect(url($pageKey, ['a' => 'edit', 'id' => $al['id']]));
    }
    DB::update('supplier_allocations', ['status' => 'cancelled', 'updated_at' => date('Y-m-d H:i:s'), 'memo' => mb_substr(trim(($al['memo'] ? $al['memo'] . ' / ' : '') . 'Cancelled: ' . $reason), 0, 255)],
        'id = :id', ['id' => $al['id']]);
    Audit::log('cancel', 'vend', 'allocation', (int)$al['id'], $al['alloc_no'], ['page_key' => $pageKey, 'reason' => $reason, 'site_id' => (int)$al['site_id']]);
    flash('success', 'Allocation ' . $al['alloc_no'] . ' cancelled.');
    redirect(url($pageKey));
}

// ------------------------------------------------------------------ list
if ($a === 'list') {
    $from = gdate('from', date('Y-m-d', strtotime('-7 days')));
    $to = gdate('to', date('Y-m-d', strtotime('+7 days')));
    $vendorF = gint('vendor_id');
    $statusF = (string)g('status');
    $where = ['a.alloc_date BETWEEN :f AND :t'];
    $params = ['f' => $from, 't' => $to];
    if ($vendorF) {
        $where[] = 'a.vendor_id = :v';
        $params['v'] = $vendorF;
    }
    if (isset(Allocations::STATUSES[$statusF])) {
        $where[] = 'a.status = :st';
        $params['st'] = $statusF;
    }
    $siteIds = Access::siteIds();
    if ($siteIds !== null) {
        [$sin, $sp] = DB::in('as', $siteIds ?: [0]);
        $where[] = "a.site_id IN $sin";
        $params += $sp;
    }
    $rows = DB::all(
        "SELECT a.*, v.name AS vendor_name, s.name AS site_name, u.full_name AS assigned_name,
                (SELECT COUNT(*) FROM supplier_allocation_lines l WHERE l.allocation_id = a.id) AS lines_n,
                (SELECT COALESCE(SUM(l.qty),0) FROM supplier_allocation_lines l JOIN uom_units uu ON uu.id = l.uom_id WHERE l.allocation_id = a.id AND uu.is_variable = 1) AS crates_alloc,
                (SELECT COUNT(*) FROM supplier_allocation_crates c JOIN supplier_allocation_lines l ON l.id = c.line_id WHERE l.allocation_id = a.id) AS crates_picked,
                (SELECT COALESCE(SUM(l.picked_qty),0) FROM supplier_allocation_lines l WHERE l.allocation_id = a.id) AS qty_picked,
                t.txn_no AS receipt_no
           FROM supplier_allocations a JOIN vendors v ON v.id = a.vendor_id JOIN sites s ON s.id = a.site_id
           LEFT JOIN users u ON u.id = a.assigned_user_id LEFT JOIN transactions t ON t.id = a.receipt_txn_id
          WHERE " . implode(' AND ', $where) . ' ORDER BY a.alloc_date DESC, a.id DESC',
        $params
    );
    layout_start('Supplier Allocation', ['actions' => page_link($pageKey, ['a' => 'new'], 'New allocation', 'btn-primary', 'plus-lg', 'create')
        . ' ' . page_link('vend.pickup', [], 'Pick-Up Supplier Items', 'btn-outline-secondary', 'truck')
        . ' ' . page_link('vend.supplier_items', [], 'Supplier Items', 'btn-outline-secondary', 'list-check')]);
    ?>
    <form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
      <div class="row g-2 align-items-end">
        <?= input_field('from', 'From', $from, ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
        <?= input_field('to', 'To', $to, ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
        <?= select_field('vendor_id', 'Supplier', Lookup::vendors(), $vendorF, ['blank' => 'All suppliers', 'class' => 'col-md-3', 'no_add' => true, 'extra' => 'data-combo']) ?>
        <?= select_field('status', 'Status', Allocations::STATUSES, $statusF, ['blank' => 'Any status', 'class' => 'col-md-2', 'no_add' => true]) ?>
        <div class="col-md-2"><button class="btn btn-sm btn-outline-primary w-100"><i class="bi bi-funnel"></i> Show</button></div>
      </div>
    </form>
    <div class="card"><div class="table-responsive"><table class="table table-sm table-hover mb-0 alloc-list">
      <thead><tr><th>No.</th><th>Date</th><th>Supplier</th><th>Location</th><th>Assigned to</th><th class="num">Items</th><th class="num">Crates allocated</th><th class="num">Crates picked</th><th>Status</th><th></th></tr></thead>
      <tbody>
      <?php foreach ($rows as $r): ?>
        <tr class="status-<?= h($r['status']) ?>">
          <td class="fw-semibold"><a href="<?= h(url($pageKey, ['a' => 'edit', 'id' => $r['id']])) ?>"><?= h($r['alloc_no']) ?></a></td>
          <td><?= h(fdate($r['alloc_date'])) ?></td>
          <td><?= h($r['vendor_name']) ?></td><td><?= h($r['site_name']) ?></td>
          <td><?= h($r['assigned_name'] ?: (string)$r['assigned_to']) ?></td>
          <td class="num"><?= (int)$r['lines_n'] ?></td>
          <td class="num"><?= qty($r['crates_alloc']) ?></td>
          <td class="num"><?= (int)$r['crates_picked'] ?></td>
          <td><span class="state-text state-<?= h($r['status']) ?>"><?= h(Allocations::statusText($r['status'])) ?></span><?= $r['receipt_no'] ? ' <span class="small text-muted">' . Txn::link((int)$r['receipt_txn_id'], 'IR ' . $r['receipt_no']) . '</span>' : '' ?></td>
          <td class="text-end text-nowrap"><?php if (in_array($r['status'], ['open', 'picking'], true) && Access::page('vend.pickup')): ?><a class="btn btn-sm btn-outline-primary" href="<?= h(url('vend.pickup', ['date' => $r['alloc_date'], 'open' => $r['id']])) ?>"><i class="bi bi-truck"></i> Pick up</a><?php endif; ?></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$rows): ?><tr><td colspan="10" class="empty-row">No allocations from <?= h(fdate($from)) ?> to <?= h(fdate($to)) ?>.<?= Access::can($pageKey, 'create') ? ' <a href="' . h(url($pageKey, ['a' => 'new'])) . '">Make one</a>.' : '' ?></td></tr><?php endif; ?>
      </tbody></table></div></div>
    <?php
    layout_end();
    return;
}

// ------------------------------------------------------------------ new / edit
$al = null;
if ($a === 'edit') {
    $al = Allocations::load(gint('id') ?? 0);
    if (!$al) {
        flash('warning', 'Allocation not found.');
        redirect(url($pageKey));
    }
    if (!Access::siteAllowed((int)$al['site_id'])) {
        Access::denyPage($pageKey, 'open an allocation of another location on');
    }
} elseif ($a !== 'new') {
    redirect(url($pageKey));
}
$locked = $al && in_array($al['status'], ['received', 'cancelled'], true);
Access::require($pageKey, $al ? 'view' : 'create');

handle_post(function () use ($al, $pageKey, $locked) {
    Access::require($pageKey, $al ? 'edit' : 'create');
    if ($locked) {
        fail('This allocation is ' . strtolower(Allocations::statusText($al['status'])) . ' and can no longer change.');
    }
    $vendorId = pint('vendor_id');
    $siteId = pint('site_id');
    $date = pdate('alloc_date');
    if (!$vendorId) {
        fail('Choose the supplier.');
    }
    if (!$date) {
        fail('Enter the date of the pick-up.');
    }
    if (!$siteId) {
        fail('Choose the location the goods go to.');
    }
    if (!Access::siteAllowed($siteId)) {
        fail('You are not allowed to allocate stock to that location.');
    }
    $assignedUser = pint('assigned_user_id');
    $assignedTo = mb_substr(trim((string)p('assigned_to')), 0, 80) ?: null;
    $lines = [];
    foreach ((array)($_POST['al'] ?? []) as $r) {
        $itemId = (int)($r['item_id'] ?? 0);
        $q = round(to_num($r['qty'] ?? 0), 4);
        if (!$itemId || empty($r['use']) || $q <= 0) {
            continue;
        }
        $uomId = !empty($r['uom_id']) ? (int)$r['uom_id'] : null;
        if ($uomId && !Uom::unitBelongsTo($uomId, $itemId)) {
            fail('A unit on the allocation does not belong to its item.');
        }
        $lines[] = ['id' => !empty($r['id']) ? (int)$r['id'] : null, 'item_id' => $itemId, 'uom_id' => $uomId, 'unit_code' => $uomId ? Uom::code($uomId) : null, 'qty' => $q];
    }
    if (!$lines) {
        fail('Type the quantity of at least one item and keep it ticked.');
    }
    $id = DB::tx(function () use ($al, $vendorId, $siteId, $date, $assignedUser, $assignedTo, $lines, $pageKey) {
        $h = ['alloc_date' => $date, 'vendor_id' => $vendorId, 'site_id' => $siteId, 'assigned_user_id' => $assignedUser, 'assigned_to' => $assignedUser ? null : $assignedTo,
            'memo' => mb_substr(trim((string)p('memo')), 0, 255) ?: null, 'updated_at' => date('Y-m-d H:i:s')];
        if (Classes::ready()) {
            $h['class_id'] = Classes::posted();
        }
        if ($al) {
            DB::update('supplier_allocations', $h, 'id = :id', ['id' => $al['id']]);
            $id = (int)$al['id'];
        } else {
            $id = DB::insert('supplier_allocations', $h + ['alloc_no' => Seq::next('allocation'), 'status' => 'open', 'created_by' => Auth::id()]);
        }
        $existing = array_map('intval', DB::column('SELECT id FROM supplier_allocation_lines WHERE allocation_id = :a', ['a' => $id]));
        $keep = [];
        $n = 0;
        foreach ($lines as $l) {
            $row = ['allocation_id' => $id, 'line_no' => ++$n, 'item_id' => $l['item_id'], 'uom_id' => $l['uom_id'], 'unit_code' => $l['unit_code'], 'qty' => $l['qty']];
            if ($l['id'] && in_array($l['id'], $existing, true)) {
                $old = DB::row('SELECT item_id, uom_id FROM supplier_allocation_lines WHERE id = :id', ['id' => $l['id']]);
                if ((int)$old['item_id'] !== $l['item_id'] || (int)$old['uom_id'] !== (int)$l['uom_id']) {
                    // a different item or unit: what was picked for the old one does not apply
                    DB::run('DELETE FROM supplier_allocation_crates WHERE line_id = :l', ['l' => $l['id']]);
                    $row += ['picked' => 0, 'picked_qty' => 0, 'picked_count' => 0];
                }
                DB::update('supplier_allocation_lines', $row, 'id = :id', ['id' => $l['id']]);
                $keep[] = $l['id'];
            } else {
                $keep[] = DB::insert('supplier_allocation_lines', $row);
            }
        }
        foreach (array_diff($existing, $keep) as $gone) {
            DB::run('DELETE FROM supplier_allocation_lines WHERE id = :id', ['id' => $gone]);
        }
        $saved = Allocations::load($id);
        Audit::log($al ? 'edit' : 'create', 'vend', 'allocation', $id, $saved['alloc_no'], ['page_key' => $pageKey, 'site_id' => $siteId,
            'snapshot' => ['supplier' => $saved['vendor_name'], 'date' => $date, 'location' => $saved['site_name'],
                'lines' => array_map(fn($l) => ['item_id' => $l['item_id'], 'unit' => $l['unit_code'], 'qty' => $l['qty']], $lines)]]);
        return $id;
    });
    $saved = Allocations::load($id);
    flash('success', 'Allocation ' . $saved['alloc_no'] . ' saved: ' . count($lines) . ' item' . (count($lines) === 1 ? '' : 's') . ' from ' . $saved['vendor_name'] . ' for ' . fdate($saved['alloc_date']) . '.');
    redirect(wants_new() ? url($pageKey, ['a' => 'new', 'date' => $saved['alloc_date'], 'site_id' => $saved['site_id']]) : url($pageKey, ['a' => 'edit', 'id' => $id]));
});

// what the form shows: the saved lines, or the supplier's items after "Go", or what was posted
$vendorId = (int)(is_post() ? pint('vendor_id') : (gint('vendor_id') ?: ($al['vendor_id'] ?? 0)));
$siteId = (int)(is_post() ? pint('site_id') : (gint('site_id') ?: ($al['site_id'] ?? array_key_first(Lookup::sites()))));
$date = is_post() ? (string)p('alloc_date') : (gdate('date') ?: ($al['alloc_date'] ?? today()));
$rows = [];
if (is_post()) {
    $rows = array_values((array)($_POST['al'] ?? []));
} elseif ($al && !gint('vendor_id')) {
    foreach (Allocations::lines((int)$al['id']) as $l) {
        $rows[] = ['id' => $l['id'], 'item_id' => $l['item_id'], 'uom_id' => $l['uom_id'], 'qty' => $l['qty'], 'use' => 1, 'picked' => (float)$l['picked_qty']];
    }
    // the supplier's other items, ready to be allocated too
    $have = array_map(fn($r) => (int)$r['item_id'], $rows);
    foreach (Allocations::supplierItems($vendorId) as $si) {
        if (!in_array((int)$si['item_id'], $have, true) && !$locked) {
            $rows[] = ['item_id' => $si['item_id'], 'uom_id' => $si['uom_id'], 'qty' => '', 'use' => 0];
        }
    }
} elseif ($vendorId) {
    foreach (Allocations::supplierItems($vendorId) as $si) {
        $rows[] = ['item_id' => $si['item_id'], 'uom_id' => $si['uom_id'], 'qty' => '', 'use' => 0];
    }
}
$items = DB::all("SELECT i.id, i.code, i.name FROM items i WHERE i.item_type IN ('inventory','assembly','non_inventory') ORDER BY i.code");
$itemById = [];
foreach ($items as $it) {
    $itemById[(int)$it['id']] = $it;
}
$unitsByItem = [];
foreach (Uom::unitsByItem(array_keys($itemById)) as $iid => $list) {
    $unitsByItem[$iid] = array_map(fn($u) => ['id' => $u['id'], 'code' => $u['code'], 'v' => $u['v'], 'base' => $u['base']], $list);
}
$canSave = !$locked && Access::can($pageKey, $al ? 'edit' : 'create');
$title = $al ? 'Allocation ' . $al['alloc_no'] : 'New Supplier Allocation';

layout_start($title, ['actions' => btn_link(url($pageKey), 'All allocations', 'btn-outline-secondary', 'list-ul')
    . ($al && in_array($al['status'], ['open', 'picking'], true) && Access::page('vend.pickup') ? ' ' . btn_link(url('vend.pickup', ['date' => $al['alloc_date'], 'open' => $al['id']]), 'Pick up', 'btn-outline-primary', 'truck') : '')
    . ($al && $al['receipt_txn_id'] ? ' ' . Txn::link((int)$al['receipt_txn_id'], 'Item receipt ' . $al['receipt_no']) : '')]);
?>
<?php if ($al): ?>
<div class="doc-state mb-3"><span class="state-text state-<?= h($al['status']) ?>"><?= h(Allocations::statusText($al['status'])) ?></span>
  <?php if ($al['receipt_txn_id']): ?><span>Received on <?= Txn::link((int)$al['receipt_txn_id'], 'item receipt ' . $al['receipt_no']) ?></span><?php endif; ?>
  <?php if ($al['status'] === 'picking'): ?><span>Pick-up has started: what was picked up so far is kept when the quantities change.</span><?php endif; ?></div>
<?php endif; ?>
<form method="post" class="alloc-form" id="allocForm"><?= csrf_field() ?>
<div class="card mb-3"><div class="card-body">
  <div class="row g-2 align-items-end">
    <?= select_field('vendor_id', 'Supplier', Lookup::vendors(), $vendorId ?: '', ['blank' => '— choose —', 'class' => 'col-md-5', 'required' => true, 'no_add' => true, 'extra' => 'id="alVendor" data-combo' . ($locked ? ' disabled' : '')]) ?>
    <?= input_field('alloc_date', 'Date', $date, ['type' => 'date', 'class' => 'col-6 col-md-2', 'required' => true, 'extra' => $locked ? 'disabled' : '']) ?>
    <?= select_field('site_id', 'Location', Lookup::sites(), $siteId, ['class' => 'col-6 col-md-3', 'no_add' => true, 'extra' => 'id="alSite"' . ($locked ? ' disabled' : '')]) ?>
    <?php if (!$locked): ?><div class="col-md-2"><button type="button" class="btn btn-sm btn-outline-primary w-100" id="alGo" title="List the items of the supplier"><i class="bi bi-arrow-repeat"></i> Go</button></div><?php endif; ?>
    <?= select_field('assigned_user_id', 'Assigned to', Allocations::pickers(), is_post() ? (string)p('assigned_user_id') : (string)($al['assigned_user_id'] ?? ''), ['blank' => '— a name not on the list —', 'class' => 'col-md-4', 'no_add' => true, 'extra' => 'id="alUser"' . ($locked ? ' disabled' : '')]) ?>
    <?= input_field('assigned_to', 'Name (driver or helper not on the list)', is_post() ? (string)p('assigned_to') : (string)($al['assigned_to'] ?? ''), ['class' => 'col-md-3', 'extra' => 'id="alName"' . ($locked ? ' disabled' : '')]) ?>
    <?= Classes::field(is_post() ? (string)p('class_id') : (string)($al['class_id'] ?? ''), 'col-md-2') ?>
    <?= input_field('memo', 'Memo', is_post() ? (string)p('memo') : (string)($al['memo'] ?? ''), ['class' => 'col-md-3', 'extra' => $locked ? 'disabled' : '']) ?>
  </div>
</div></div>

<div class="card mb-3">
  <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2"><span>Items allocated</span>
    <span class="small text-muted" id="alSum"></span></div>
  <div class="table-responsive"><table class="table table-sm mb-0 alloc-grid" id="alTable">
    <thead><tr><th style="width:9rem">Item code</th><th>Item description</th><th style="width:9rem">Unit</th><th class="num" style="width:8rem">Quantity</th><th class="num" style="width:7rem">Picked up</th><th class="text-center" style="width:7.5rem">Copy, remove</th><th class="text-center" style="width:4rem">Use</th></tr></thead>
    <tbody>
    <?php foreach ($rows as $i => $r): $it = $itemById[(int)($r['item_id'] ?? 0)] ?? null; ?>
      <tr class="<?= !empty($r['use']) ? 'is-used' : '' ?>">
        <td><input type="hidden" name="al[<?= h((string)$i) ?>][id]" value="<?= h((string)($r['id'] ?? '')) ?>">
          <select class="form-select form-select-sm" name="al[<?= h((string)$i) ?>][item_id]" data-al-item<?= $locked ? ' disabled' : '' ?>><?= options(array_map(fn($x) => $x['code'], $itemById), $r['item_id'] ?? '', '') ?></select></td>
        <td class="al-desc"><?= h($it['name'] ?? '') ?></td>
        <td><select class="form-select form-select-sm" name="al[<?= h((string)$i) ?>][uom_id]" data-al-uom data-value="<?= h((string)($r['uom_id'] ?? '')) ?>"<?= $locked ? ' disabled' : '' ?>></select></td>
        <td><input class="form-control form-control-sm text-end" inputmode="decimal" name="al[<?= h((string)$i) ?>][qty]" value="<?= h($r['qty'] !== '' && $r['qty'] !== null ? qty($r['qty']) : '') ?>" data-al-qty<?= $locked ? ' disabled' : '' ?>></td>
        <td class="num small"><?= !empty($r['picked']) ? qty($r['picked']) : '' ?></td>
        <td class="text-center text-nowrap"><?php if (!$locked): ?><button type="button" class="btn btn-sm btn-link p-0 me-2" data-al-copy title="Copy this line (the same item in another unit)" aria-label="Copy this line"><i class="bi bi-copy"></i></button><button type="button" class="btn btn-sm btn-link text-danger p-0" data-al-del title="Remove this line" aria-label="Remove this line"><i class="bi bi-trash3"></i></button><?php endif; ?></td>
        <td class="text-center"><input type="checkbox" class="form-check-input" name="al[<?= h((string)$i) ?>][use]" value="1" data-al-use<?= checked(!empty($r['use'])) ?><?= $locked ? ' disabled' : '' ?> aria-label="Allocate this item"></td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$rows): ?><tr class="al-empty"><td colspan="7" class="empty-row">Choose the supplier and press Go to list its items<?= Access::page('vend.supplier_items') ? ', or <a href="' . h(url('vend.supplier_items')) . '">set up its items</a> first' : '' ?>.</td></tr><?php endif; ?>
    </tbody>
  </table></div>
  <?php if (!$locked): ?><div class="card-body pt-2"><div class="grid-add"><button type="button" class="btn btn-sm btn-outline-secondary" id="alAdd"><i class="bi bi-plus"></i> Add another item</button></div></div><?php endif; ?>
</div>
<template id="alTpl"><tr>
  <td><input type="hidden" name="al[__i__][id]" value=""><select class="form-select form-select-sm" name="al[__i__][item_id]" data-al-item><?= options(array_map(fn($x) => $x['code'], $itemById), '', '') ?></select></td>
  <td class="al-desc"></td>
  <td><select class="form-select form-select-sm" name="al[__i__][uom_id]" data-al-uom data-value=""></select></td>
  <td><input class="form-control form-control-sm text-end" inputmode="decimal" name="al[__i__][qty]" data-al-qty></td>
  <td class="num small"></td>
  <td class="text-center text-nowrap"><button type="button" class="btn btn-sm btn-link p-0 me-2" data-al-copy title="Copy this line" aria-label="Copy this line"><i class="bi bi-copy"></i></button><button type="button" class="btn btn-sm btn-link text-danger p-0" data-al-del title="Remove this line" aria-label="Remove this line"><i class="bi bi-trash3"></i></button></td>
  <td class="text-center"><input type="checkbox" class="form-check-input" name="al[__i__][use]" value="1" data-al-use aria-label="Allocate this item"></td></tr></template>

<div class="form-actions">
  <a class="btn btn-outline-primary" href="<?= h(url($pageKey, ['a' => 'new'])) ?>"><i class="bi bi-plus-lg"></i> New allocation</a>
  <?php if (!$locked): ?><a class="btn btn-outline-secondary" href="<?= h($al ? url($pageKey, ['a' => 'edit', 'id' => $al['id']]) : url($pageKey, ['a' => 'new'])) ?>"><i class="bi bi-arrow-counterclockwise"></i> Reset</a><?php endif; ?>
  <?php if ($canSave): ?><button class="btn btn-primary" name="save" value="1"><i class="bi bi-check-lg"></i> Save</button>
    <button class="btn btn-outline-primary" name="save_new" value="1"><i class="bi bi-plus-lg"></i> Save &amp; New</button><?php endif; ?>
  <a class="btn btn-outline-secondary" href="<?= h(url($pageKey)) ?>">Close</a>
  <?php if ($al && !$locked && Access::can($pageKey, 'delete')): ?><button type="button" class="btn btn-outline-danger ms-auto" data-bs-toggle="modal" data-bs-target="#alCancel"><i class="bi bi-x-circle"></i> Cancel allocation</button><?php endif; ?>
</div>
</form>
<?php if ($al && !$locked && Access::can($pageKey, 'delete')): ?>
<?= reason_modal('alCancel', 'Cancel allocation', url($pageKey, ['a' => 'cancel']), 'btn-danger', '<input type="hidden" name="id" value="' . (int)$al['id'] . '">') ?>
<?php endif; ?>
<script>
(function () {
  const units = <?= json_encode((object)$unitsByItem) ?>;
  const names = <?= json_encode((object)array_map(fn($x) => $x['name'], $itemById)) ?>;
  const tb = document.querySelector('#alTable tbody'), tpl = document.getElementById('alTpl');
  const { num } = window.AppFmt;
  function fillUnits(tr) {
    const item = tr.querySelector('[data-al-item]'), sel = tr.querySelector('[data-al-uom]');
    if (!item || !sel) return;
    const list = units[item.value] || [];
    const want = sel.value || sel.dataset.value || '';
    sel.innerHTML = list.map((u) => '<option value="' + u.id + '">' + String(u.code).replace(/</g, '&lt;') + (u.v ? ' (crates)' : '') + '</option>').join('');
    const crate = list.find((u) => u.v), base = list.find((u) => u.base);
    sel.value = list.some((u) => String(u.id) === String(want)) ? want : String((crate || base || list[0] || { id: '' }).id);
    tr.querySelector('.al-desc').textContent = names[item.value] || '';
  }
  function sum() {
    let lines = 0, crates = 0;
    tb.querySelectorAll('tr').forEach((tr) => {
      const use = tr.querySelector('[data-al-use]'), q = tr.querySelector('[data-al-qty]'), sel = tr.querySelector('[data-al-uom]');
      if (!use || !use.checked || !(num(q.value) > 0)) return;
      lines++;
      const o = sel && sel.options[sel.selectedIndex];
      if (o && /\(crates\)/.test(o.textContent)) crates += num(q.value);
      tr.classList.add('is-used');
    });
    tb.querySelectorAll('tr').forEach((tr) => { const u = tr.querySelector('[data-al-use]'); if (u) tr.classList.toggle('is-used', u.checked); });
    document.getElementById('alSum').textContent = lines ? lines + (lines === 1 ? ' item, ' : ' items, ') + crates + (crates === 1 ? ' crate' : ' crates') : 'Nothing allocated yet';
  }
  function addRow(after, copyFrom) {
    const html = tpl.innerHTML.replace(/__i__/g, 'n' + Date.now() + Math.floor(Math.random() * 1000));
    if (after) after.insertAdjacentHTML('afterend', html); else tb.insertAdjacentHTML('beforeend', html);
    const tr = after ? after.nextElementSibling : tb.lastElementChild;
    if (copyFrom) {
      tr.querySelector('[data-al-item]').value = copyFrom.querySelector('[data-al-item]').value;
      fillUnits(tr);
      tr.querySelector('[data-al-use]').checked = true;
    }
    tr.classList.add('row-new');
    setTimeout(() => tr.classList.remove('row-new'), 1200);
    const empty = tb.querySelector('.al-empty'); if (empty) empty.remove();
    return tr;
  }
  tb.querySelectorAll('tr').forEach(fillUnits);
  tb.addEventListener('change', (e) => {
    const tr = e.target.closest('tr');
    if (e.target.matches('[data-al-item]')) { tr.querySelector('[data-al-uom]').dataset.value = ''; tr.querySelector('[data-al-uom]').value = ''; fillUnits(tr); }
    sum();
  });
  // typing a quantity ticks the line
  tb.addEventListener('input', (e) => { if (e.target.matches('[data-al-qty]')) { const u = e.target.closest('tr').querySelector('[data-al-use]'); if (u) u.checked = num(e.target.value) > 0; sum(); } });
  tb.addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    const tr = b.closest('tr');
    if (b.hasAttribute('data-al-copy')) { const n = addRow(tr, tr); n.querySelector('[data-al-qty]').focus(); }
    if (b.hasAttribute('data-al-del')) { tr.remove(); sum(); }
  });
  const add = document.getElementById('alAdd');
  if (add) add.addEventListener('click', () => { const tr = addRow(null, null); fillUnits(tr); });
  // Go: the supplier's items for the chosen supplier, keeping the date and the location
  const go = document.getElementById('alGo');
  if (go) go.addEventListener('click', () => {
    const v = document.getElementById('alVendor').value;
    if (!v) { alert('Choose the supplier first.'); return; }
    const u = new URL(window.location.href);
    u.searchParams.set('vendor_id', v);
    u.searchParams.set('date', document.querySelector('[name="alloc_date"]').value);
    u.searchParams.set('site_id', document.getElementById('alSite').value);
    window.location.href = u.toString();
  });
  // the typed name is used only when nobody on the list is chosen
  const usr = document.getElementById('alUser'), nm = document.getElementById('alName');
  const syncName = () => { if (usr && nm) { nm.disabled = usr.disabled || usr.value !== ''; if (usr.value !== '') nm.value = ''; } };
  if (usr) usr.addEventListener('change', syncName);
  syncName();
  sum();
})();
</script>
<?php
layout_end();
