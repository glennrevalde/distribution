<?php
declare(strict_types=1);

/**
 * Vendors > Pick-Up Supplier Items
 *
 * The day's supplier allocations, for the people who pick the goods up. Opening an allocation lists its items;
 * an item allocated in crates opens the crate window, where every crate loaded is typed: crate number, heads,
 * weight, production and expiry dates (Replicate copies the first crate's heads and dates down). Items in kilos
 * or packs take the quantity picked up. "Pick-up complete" receives it all into stock at the allocation's
 * location with one Item Receipt, and the crates appear in the Crate Center.
 */
require_once APP_ROOT . '/modules/txn/_common.php';

$pageKey = 'vend.pickup';
$a = (string)g('a');

// ------------------------------------------------------------------ one line picked up (from the crate window)
if ($a === 'save_line' && is_post()) {
    try {
        if (!Access::can($pageKey, 'edit') && !Access::can($pageKey, 'create')) {
            json_out(['error' => 'You may not record pick-ups.'], 403);
        }
        $lineId = (int)p('line_id');
        $al = DB::row('SELECT a.* FROM supplier_allocations a JOIN supplier_allocation_lines l ON l.allocation_id = a.id WHERE l.id = :l', ['l' => $lineId]);
        if (!$al || !Access::siteAllowed((int)$al['site_id'])) {
            json_out(['error' => 'That allocation is not open to you.'], 403);
        }
        $rows = json_decode((string)p('crates', '[]'), true);
        Allocations::savePicked($lineId, is_array($rows) ? $rows : [], p('qty') !== '' ? to_num(p('qty')) : null, p('done', '1') === '1');
        $l = null;
        foreach (Allocations::lines((int)$al['id']) as $x) {
            if ((int)$x['id'] === $lineId) {
                $l = $x;
            }
        }
        json_out(['ok' => true, 'line' => pickup_line_js($l), 'status' => Allocations::statusText((string)DB::value('SELECT status FROM supplier_allocations WHERE id = :id', ['id' => $al['id']]))]);
    } catch (UserError $e) {
        json_out(['error' => $e->getMessage()], 422);
    }
}

handle_post(function () use ($pageKey, $a) {
    $al = Allocations::load(pint('id') ?? 0);
    if (!$al || !Access::siteAllowed((int)$al['site_id'])) {
        fail('That allocation is not open to you.');
    }
    if ($a === 'reset') {
        Access::require($pageKey, 'edit');
        Allocations::reset((int)$al['id']);
        flash('info', 'Pick-up details of ' . $al['alloc_no'] . ' cleared. The allocated quantities stay.');
        redirect(url($pageKey, ['date' => $al['alloc_date'], 'open' => $al['id']]));
    }
    if ($a === 'complete') {
        Access::require($pageKey, 'create');
        $txnId = Allocations::complete((int)$al['id'], pdate('receive_date') ?: null);
        $t = Txn::load($txnId);
        flash('success', 'Pick-up ' . $al['alloc_no'] . ' complete: received into ' . $al['site_name'] . ' on ' . Txn::ref($t) . ' (' . money($t['total']) . ').'
            . ' Enter the supplier\'s bill with Enter Bill for Received Items when it arrives.');
        redirect(url($pageKey, ['date' => $al['alloc_date'], 'open' => $al['id']]));
    }
    fail('Unknown action.');
});

/** One allocation line as the page's script shows it */
function pickup_line_js(?array $l): ?array
{
    if (!$l) {
        return null;
    }
    return [
        'id' => (int)$l['id'], 'item_id' => (int)$l['item_id'], 'code' => $l['item_code'], 'name' => $l['item_name'], 'unit' => $l['unit_label'], 'base' => $l['base'],
        'crate' => $l['is_crate'], 'qty' => (float)$l['qty'], 'picked' => (int)$l['picked'] === 1, 'picked_qty' => round((float)$l['picked_qty'], 4),
        'picked_count' => (float)$l['picked_count'],
        'crates' => array_map(fn($c) => ['no' => (string)$c['crate_no'], 'pcs' => (float)$c['pcs'], 'qty' => (float)$c['qty'],
            'prod' => $c['production_date'] ?: '', 'exp' => $c['expiry_date'] ?: ''], $l['crates']),
    ];
}

$date = gdate('date', today());
$mineDefault = !Access::page('vend.allocations');
$mine = array_key_exists('mine', $_GET) ? g('mine') === '1' : $mineDefault;
$openId = gint('open');
$where = ['a.alloc_date = :d', "a.status <> 'cancelled'"];
$params = ['d' => $date];
if ($mine) {
    $where[] = '(a.assigned_user_id = :me OR a.created_by = :me2)';
    $params['me'] = Auth::id();
    $params['me2'] = Auth::id();
}
$siteIds = Access::siteIds();
if ($siteIds !== null) {
    [$sin, $sp] = DB::in('ps', $siteIds ?: [0]);
    $where[] = "a.site_id IN $sin";
    $params += $sp;
}
$allocs = DB::all(
    "SELECT a.*, v.name AS vendor_name, s.name AS site_name, u.full_name AS assigned_name, u.username AS assigned_username, t.txn_no AS receipt_no
       FROM supplier_allocations a JOIN vendors v ON v.id = a.vendor_id JOIN sites s ON s.id = a.site_id
       LEFT JOIN users u ON u.id = a.assigned_user_id LEFT JOIN transactions t ON t.id = a.receipt_txn_id
      WHERE " . implode(' AND ', $where) . ' ORDER BY v.name, a.id',
    $params
);
$data = [];
foreach ($allocs as $al) {
    $data[(int)$al['id']] = array_values(array_filter(array_map('pickup_line_js', Allocations::lines((int)$al['id']))));
}
// the next crate number: after the counter and every number typed on a pick-up not yet received
$typedMax = (int)DB::value("SELECT COALESCE(MAX(CAST(c.crate_no AS UNSIGNED)),0) FROM supplier_allocation_crates c JOIN supplier_allocation_lines l ON l.id = c.line_id
                             JOIN supplier_allocations a ON a.id = l.allocation_id WHERE a.status IN ('open','picking') AND c.crate_no REGEXP '^[0-9]+$'");
$next = (string)max((int)Crates::peekNo(), $typedMax + 1);
$canPick = Access::can($pageKey, 'edit') || Access::can($pageKey, 'create');
$canComplete = Access::can($pageKey, 'create');

$prev = date('Y-m-d', strtotime($date . ' -1 day'));
$nextDay = date('Y-m-d', strtotime($date . ' +1 day'));
layout_start('Pick-Up Supplier Items', ['js' => ['js/crates.js'], 'actions' => page_link('vend.allocations', ['a' => 'new', 'date' => $date], 'New allocation', 'btn-outline-primary', 'plus-lg', 'create')
    . ' ' . page_link('vend.allocations', [], 'Supplier Allocation', 'btn-outline-secondary', 'clipboard-check')]);
?>
<form method="get" class="pickup-bar mb-3" id="pickupBar"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="day-step">
    <a class="btn btn-sm btn-outline-secondary" href="<?= h(url($pageKey, ['date' => $prev] + ($mine !== $mineDefault ? ['mine' => $mine ? '1' : '0'] : []))) ?>" title="The day before" aria-label="The day before"><i class="bi bi-chevron-left"></i></a>
    <label class="visually-hidden" for="pkDate">Pick-up date</label>
    <input class="form-control form-control-sm" type="date" id="pkDate" name="date" value="<?= h($date) ?>" data-autosubmit>
    <a class="btn btn-sm btn-outline-secondary" href="<?= h(url($pageKey, ['date' => $nextDay] + ($mine !== $mineDefault ? ['mine' => $mine ? '1' : '0'] : []))) ?>" title="The day after" aria-label="The day after"><i class="bi bi-chevron-right"></i></a>
    <?php if ($date !== today()): ?><a class="btn btn-sm btn-link" href="<?= h(url($pageKey)) ?>">Today</a><?php endif; ?>
  </div>
  <div class="form-check form-switch m-0"><input type="hidden" name="mine" value="0"><input class="form-check-input" type="checkbox" role="switch" id="pkMine" name="mine" value="1"<?= checked($mine) ?> data-autosubmit>
    <label class="form-check-label small" for="pkMine">Only the pick-ups assigned to me</label></div>
  <div class="pickup-date-text"><?= h(date('l, F j, Y', strtotime($date))) ?></div>
</form>

<?php if (!$allocs): ?>
<div class="empty-state"><i class="bi bi-truck"></i><p>No pick-up <?= $mine ? 'assigned to you ' : '' ?>on <?= h(fdate($date)) ?>.</p>
  <?php if (Access::can('vend.allocations', 'create')): ?><a class="btn btn-primary btn-sm" href="<?= h(url('vend.allocations', ['a' => 'new', 'date' => $date])) ?>"><i class="bi bi-plus-lg"></i> Allocate a pick-up</a><?php endif; ?></div>
<?php else: ?>
<div class="pickup-list">
<?php foreach ($allocs as $al):
    $lines = $data[(int)$al['id']];
    $done = count(array_filter($lines, fn($l) => $l['picked']));
    $crates = array_sum(array_map(fn($l) => $l['crate'] ? count($l['crates']) : 0, $lines));
    $cratesAlloc = array_sum(array_map(fn($l) => $l['crate'] ? $l['qty'] : 0, $lines));
    $kg = array_sum(array_column($lines, 'picked_qty'));
    $isOpen = (int)$al['id'] === (int)$openId;
    $received = $al['status'] === 'received';
?>
  <section class="pickup-card status-<?= h($al['status']) ?><?= $isOpen ? ' is-open' : '' ?>" id="pk<?= (int)$al['id'] ?>" data-alloc="<?= (int)$al['id'] ?>">
    <header class="pickup-head">
      <button type="button" class="pickup-toggle" data-pk-toggle aria-expanded="<?= $isOpen ? 'true' : 'false' ?>" aria-controls="pkBody<?= (int)$al['id'] ?>">
        <span class="pickup-supplier"><span class="pickup-sid"><?= (int)$al['vendor_id'] ?></span><strong><?= h($al['vendor_name']) ?></strong></span>
        <span class="pickup-meta"><span><i class="bi bi-geo-alt"></i> <?= h($al['site_name']) ?></span><span><i class="bi bi-person"></i> <?= h($al['assigned_username'] ?: ($al['assigned_to'] ?: 'Not assigned')) ?></span><span class="text-muted"><?= h($al['alloc_no']) ?></span></span>
        <span class="pickup-progress" title="<?= $done ?> of <?= count($lines) ?> items picked up">
          <span class="pickup-meter"><span style="width:<?= count($lines) ? round($done / count($lines) * 100) : 0 ?>%"></span></span>
          <span class="pickup-count" data-pk-count><?= $done ?> of <?= count($lines) ?> items, <?= $crates ?> of <?= qty($cratesAlloc) ?> crates</span>
        </span>
        <span class="state-text state-<?= h($al['status']) ?>" data-pk-status><?= h(Allocations::statusText($al['status'])) ?></span>
        <i class="bi bi-chevron-down pickup-chev"></i>
      </button>
    </header>
    <div class="pickup-body" id="pkBody<?= (int)$al['id'] ?>"<?= $isOpen ? '' : ' hidden' ?>>
      <div class="table-responsive"><table class="table table-sm pickup-items mb-0">
        <thead><tr><th>Item code</th><th>Description</th><th>U/M</th><th class="num">Allocated</th><th class="num">Picked up</th><th class="num">Weight</th><th class="text-center">Done</th><th></th></tr></thead>
        <tbody>
        <?php foreach ($lines as $l): ?>
          <tr data-line="<?= (int)$l['id'] ?>" class="<?= $l['picked'] ? 'is-done' : '' ?>">
            <td class="fw-semibold"><?= h($l['code']) ?></td><td><?= h($l['name']) ?></td><td data-label="U/M"><?= h($l['unit']) ?></td>
            <td class="num" data-label="Allocated"><?= qty($l['qty']) ?></td>
            <td class="num" data-label="Picked up" data-pk-picked><?= $l['crate'] ? count($l['crates']) . ' crate' . (count($l['crates']) === 1 ? '' : 's') : ($l['picked_qty'] > 0 ? qty($l['picked_qty']) . ' ' . h($l['base']) : '') ?></td>
            <td class="num" data-label="Weight" data-pk-kg><?= $l['picked_qty'] > 0 ? qty($l['picked_qty']) . ' ' . h($l['base']) : '' ?></td>
            <td class="text-center"><i class="bi <?= $l['picked'] ? 'bi-check-circle-fill text-success' : 'bi-circle text-muted' ?>" data-pk-done aria-label="<?= $l['picked'] ? 'Picked up' : 'Not picked up yet' ?>"></i></td>
            <td class="text-end text-nowrap">
              <input type="hidden" data-f="crates" value="<?= h($l['crate'] && $l['crates'] ? json_encode($l['crates']) : '') ?>">
              <?php if ($received || !$canPick): ?>
                <?php if ($l['crate'] && $l['crates']): ?><button type="button" class="btn btn-sm btn-outline-secondary" data-pk-view><i class="bi bi-boxes"></i> Crates</button><?php endif; ?>
              <?php elseif ($l['crate']): ?>
                <button type="button" class="btn btn-sm btn-primary" data-pk-crates><i class="bi bi-boxes"></i> <?= $l['crates'] ? 'Change crates' : 'Weigh crates' ?></button>
              <?php else: ?>
                <span class="pk-qty"><input class="form-control form-control-sm text-end" inputmode="decimal" data-pk-qty value="<?= $l['picked_qty'] > 0 ? h(qty($l['picked_qty'])) : '' ?>" placeholder="<?= h($l['base']) ?>" aria-label="Quantity picked up in <?= h($l['base']) ?>">
                <button type="button" class="btn btn-sm btn-primary" data-pk-save>Save</button></span>
              <?php endif; ?>
            </td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table></div>
      <div class="pickup-foot">
        <div class="scale-readout scale-sm"><span class="scale-digits" data-pk-total><?= h(number_format($kg, 2)) ?></span><span class="scale-unit">total picked up</span></div>
        <div class="d-flex flex-wrap gap-2 ms-auto">
          <?php if ($received): ?>
            <span class="small">Received on <?= Txn::link((int)$al['receipt_txn_id'], 'item receipt ' . $al['receipt_no']) ?>.</span>
            <?php if (Access::page('vend.bill_received')): ?><a class="btn btn-sm btn-outline-primary" href="<?= h(url('vend.bill_received', ['id' => $al['receipt_txn_id']])) ?>"><i class="bi bi-receipt"></i> Enter the bill</a><?php endif; ?>
          <?php else: ?>
            <?php if (Access::can($pageKey, 'edit')): ?>
            <form method="post" action="<?= h(url($pageKey, ['a' => 'reset'])) ?>" onsubmit="return confirm('Clear everything picked up on <?= h($al['alloc_no']) ?>? The allocated quantities stay.');"><?= csrf_field() ?><input type="hidden" name="id" value="<?= (int)$al['id'] ?>">
              <button class="btn btn-sm btn-outline-secondary" title="Clear what was picked up"><i class="bi bi-arrow-counterclockwise"></i> Reset</button></form>
            <?php endif; ?>
            <?php if (Access::can('vend.allocations', 'edit')): ?><a class="btn btn-sm btn-outline-secondary" href="<?= h(url('vend.allocations', ['a' => 'edit', 'id' => $al['id']])) ?>"><i class="bi bi-pencil"></i> Allocation</a><?php endif; ?>
            <?php if ($canComplete): ?>
            <form method="post" action="<?= h(url($pageKey, ['a' => 'complete'])) ?>" class="pk-complete" data-pk-complete><?= csrf_field() ?><input type="hidden" name="id" value="<?= (int)$al['id'] ?>">
              <label class="visually-hidden" for="rd<?= (int)$al['id'] ?>">Receive on</label>
              <input class="form-control form-control-sm" type="date" id="rd<?= (int)$al['id'] ?>" name="receive_date" value="<?= h($al['alloc_date']) ?>" title="The date the goods are received into stock">
              <button class="btn btn-sm btn-success"><i class="bi bi-box-arrow-in-down"></i> Pick-up complete</button></form>
            <?php endif; ?>
          <?php endif; ?>
        </div>
      </div>
    </div>
  </section>
<?php endforeach; ?>
</div>
<?php endif; ?>
<script>
(function () {
  const data = <?= json_encode((object)$data) ?>;
  const nextNo = <?= json_encode($next) ?>;
  const saveUrl = <?= json_encode(url($pageKey, ['a' => 'save_line'])) ?>;
  const csrf = <?= json_encode(csrf_token()) ?>;
  const { num } = window.AppFmt;
  const fq = (v) => Number(v || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 3 });
  const lineOf = (allocId, lineId) => (data[allocId] || []).find((l) => l.id === lineId);

  document.querySelectorAll('[data-pk-toggle]').forEach((b) => b.addEventListener('click', () => {
    const card = b.closest('.pickup-card'), body = card.querySelector('.pickup-body');
    const open = body.hidden;
    body.hidden = !open;
    card.classList.toggle('is-open', open);
    b.setAttribute('aria-expanded', open ? 'true' : 'false');
  }));

  function refresh(card) {
    const id = +card.dataset.alloc, lines = data[id] || [];
    const done = lines.filter((l) => l.picked).length;
    const crates = lines.reduce((a, l) => a + (l.crate ? l.crates.length : 0), 0);
    const crAlloc = lines.reduce((a, l) => a + (l.crate ? l.qty : 0), 0);
    const kg = lines.reduce((a, l) => a + num(l.picked_qty), 0);
    card.querySelector('[data-pk-count]').textContent = done + ' of ' + lines.length + ' items, ' + crates + ' of ' + crAlloc + ' crates';
    card.querySelector('.pickup-meter span').style.width = (lines.length ? Math.round(done / lines.length * 100) : 0) + '%';
    const t = card.querySelector('[data-pk-total]');
    t.textContent = fq(kg); t.classList.remove('tick'); void t.offsetWidth; t.classList.add('tick');
  }

  function paintLine(tr, l) {
    tr.classList.toggle('is-done', l.picked);
    tr.querySelector('[data-pk-picked]').textContent = l.crate ? l.crates.length + (l.crates.length === 1 ? ' crate' : ' crates') : (l.picked_qty > 0 ? fq(l.picked_qty) + ' ' + l.base : '');
    tr.querySelector('[data-pk-kg]').textContent = l.picked_qty > 0 ? fq(l.picked_qty) + ' ' + l.base : '';
    const d = tr.querySelector('[data-pk-done]');
    d.className = 'bi ' + (l.picked ? 'bi-check-circle-fill text-success' : 'bi-circle text-muted');
    const h = tr.querySelector('input[data-f="crates"]'); if (h) h.value = l.crates.length ? JSON.stringify(l.crates) : '';
    const b = tr.querySelector('[data-pk-crates]'); if (b) b.innerHTML = '<i class="bi bi-boxes"></i> ' + (l.crates.length ? 'Change crates' : 'Weigh crates');
    tr.classList.remove('row-new'); void tr.offsetWidth; tr.classList.add('row-new');
  }

  function send(card, tr, l, body) {
    const fd = new FormData();
    fd.append('_csrf', csrf); fd.append('line_id', l.id);
    Object.keys(body).forEach((k) => fd.append(k, body[k]));
    return fetch(saveUrl, { method: 'POST', body: fd, credentials: 'same-origin' }).then((r) => r.json()).then((d) => {
      if (d.error) { alert(d.error); return; }
      Object.assign(l, d.line);
      paintLine(tr, l);
      if (card.classList.contains('status-open')) { card.classList.remove('status-open'); card.classList.add('status-picking'); }
      const st = card.querySelector('[data-pk-status]'); if (st && d.status) st.textContent = d.status;
      refresh(card);
    }).catch(() => alert('The pick-up could not be saved. Check the connection and try again.'));
  }

  document.querySelectorAll('.pickup-items').forEach((table) => table.addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    const tr = b.closest('tr'), card = b.closest('.pickup-card');
    const l = lineOf(+card.dataset.alloc, +tr.dataset.line);
    if (!l) return;
    if (b.hasAttribute('data-pk-crates') || b.hasAttribute('data-pk-view')) {
      const view = b.hasAttribute('data-pk-view');
      window.CrateWindow.open({ dir: 'in', title: l.code + ' ' + l.name, base: l.base, next: nextNo, defaultCount: Math.max(1, Math.round(l.qty)) || 5,
        sub: view ? 'Crates received.' : 'Allocated: ' + l.qty + ' ' + l.unit + '. Type each crate as it is loaded; Replicate copies the first crate\'s heads and dates down.',
        value: JSON.stringify(l.crates), today: <?= json_encode($date) ?>,
        onSave: view ? null : (list) => send(card, tr, l, { crates: JSON.stringify(list), done: list.length ? '1' : '0' }) });
    }
    if (b.hasAttribute('data-pk-save')) {
      const q = tr.querySelector('[data-pk-qty]');
      send(card, tr, l, { qty: String(num(q.value)), done: num(q.value) > 0 ? '1' : '0' });
    }
  }));
  // Pick-up complete asks first, naming what goes into stock
  document.querySelectorAll('[data-pk-complete]').forEach((f) => f.addEventListener('submit', (e) => {
    const card = f.closest('.pickup-card'), lines = data[+card.dataset.alloc] || [];
    const picked = lines.filter((l) => num(l.picked_qty) > 0);
    if (!picked.length) { e.preventDefault(); alert('Nothing has been picked up yet.'); return; }
    const left = lines.length - picked.length;
    if (!confirm('Receive ' + picked.length + (picked.length === 1 ? ' item' : ' items') + ' into stock now?' + (left ? ' ' + left + (left === 1 ? ' item was' : ' items were') + ' not picked up and will be left out.' : ''))) e.preventDefault();
  }));
  const open = document.querySelector('.pickup-card.is-open');
  if (open) try { open.scrollIntoView({ block: 'start', behavior: 'smooth' }); } catch (e) { /* older browser */ }
})();
</script>
<?php
layout_end();
