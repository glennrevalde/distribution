<?php
declare(strict_types=1);

/**
 * Inventory > Move Crates to Another Site
 *
 * Crates ticked here go to another site with their stock: an Inventory Transfer is recorded for the kilos of
 * every item moved, and each crate keeps its number, heads, kilos and dates at the new site. Voiding the
 * transfer brings the crates back.
 */
$pageKey = 'inv.crate_move';
$sites = Lookup::sites();
$fromId = gint('site_id') ?: (int)array_key_first($sites);
$picked = array_map('intval', (array)($_GET['ids'] ?? []));
if ($picked && ($first = DB::row('SELECT site_id FROM crates WHERE id = :id', ['id' => $picked[0]]))) {
    $fromId = (int)$first['site_id'];
}

handle_post(function () use ($pageKey) {
    Access::require($pageKey, 'create');
    $from = pint('from_id');
    $to = pint('to_id');
    $date = pdate('txn_date') ?: today();
    if (!$from || !$to || $from === $to) {
        fail('Choose the site the crates go to (another site than where they are).');
    }
    if (!Access::siteAllowed($from) || !Access::siteAllowed($to)) {
        fail('You are not allowed to move stock between those sites.');
    }
    $ids = array_values(array_filter(array_map('intval', (array)($_POST['ids'] ?? []))));
    if (!$ids) {
        fail('Tick the crates to move.');
    }
    [$in, $p] = DB::in('mv', $ids);
    $crates = DB::all("SELECT c.*, i.code, i.name AS item_name FROM crates c JOIN items i ON i.id = c.item_id WHERE c.id IN $in AND c.status = 'open' AND c.site_id = :s ORDER BY i.code, c.id", $p + ['s' => $from]);
    if (count($crates) !== count($ids)) {
        fail('Some of the crates ticked are no longer open at that site. Show the list again and tick them again.');
    }
    $byItem = [];
    foreach ($crates as $c) {
        $byItem[(int)$c['item_id']]['crates'][] = ['id' => (int)$c['id']];
        $byItem[(int)$c['item_id']]['qty'] = ($byItem[(int)$c['item_id']]['qty'] ?? 0.0) + (float)$c['qty_left'];
        $byItem[(int)$c['item_id']]['name'] = $c['item_name'];
        $byItem[(int)$c['item_id']]['n'] = ($byItem[(int)$c['item_id']]['n'] ?? 0) + 1;
    }
    $lines = [];
    foreach ($byItem as $itemId => $b) {
        $unit = Crates::crateUnit($itemId);
        $lines[] = ['line_kind' => 'item', 'item_id' => $itemId, 'qty' => round($b['qty'], 4), 'description' => $b['name'] . ' (' . $b['n'] . ' crate' . ($b['n'] === 1 ? '' : 's') . ')',
            'site_id' => $from, 'uom_id' => $unit['id'] ?? null, 'unit' => $unit['code'] ?? null, 'uom_qty' => $b['n'], 'uom_factor' => $b['n'] ? round($b['qty'] / $b['n'], 6) : 1,
            '_crates' => ['dir' => 'move', 'rows' => $b['crates']]];
    }
    $id = Txn::save('inventory_transfer', ['txn_date' => $date, 'site_id' => $from, 'site2_id' => $to, 'status' => 'open',
        'memo' => mb_substr(trim((string)p('memo')) ?: 'Crates moved', 0, 255)], $lines, null, ['reason' => 'Crates moved to another site']);
    $t = Txn::load($id);
    flash('success', count($crates) . ' crate' . (count($crates) === 1 ? '' : 's') . ' moved on ' . Txn::ref($t) . '.');
    redirect(url($pageKey, ['site_id' => $from]));
});

$crates = Access::siteAllowed($fromId) ? DB::all(
    "SELECT c.*, i.code, i.name AS item_name, us.base_unit FROM crates c JOIN items i ON i.id = c.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
      WHERE c.status = 'open' AND c.site_id = :s ORDER BY i.code, (c.expiry_date IS NULL), c.expiry_date, c.id",
    ['s' => $fromId]
) : [];
$toOpts = array_filter($sites, fn($k) => (int)$k !== $fromId, ARRAY_FILTER_USE_KEY);

layout_start('Move Crates to Another Site', ['actions' => page_link('inv.crates', [], 'Crate Center', 'btn-outline-secondary', 'boxes')
    . ' ' . page_link('inv.transfers', [], 'Transfer Inventory', 'btn-outline-secondary', 'arrow-left-right')]);
?>
<form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="row g-2 align-items-end"><?= select_field('site_id', 'Crates at', $sites, $fromId, ['class' => 'col-md-3', 'no_add' => true, 'extra' => 'data-autosubmit']) ?>
    <div class="col-md-9 small text-muted">An Inventory Transfer is recorded for the kilos moved; each crate keeps its number, heads, kilos and dates.</div></div>
</form>
<form method="post" class="card" id="moveForm"><?= csrf_field() ?><input type="hidden" name="from_id" value="<?= (int)$fromId ?>">
  <div class="table-responsive"><table class="table table-sm table-hover mb-0">
    <thead><tr><th><input type="checkbox" class="form-check-input" data-check-all="#moveForm .mv-tick" aria-label="Tick every crate"></th><th>Crate no.</th><th>Item</th><th class="num">Heads</th><th class="num">Left</th><th>Production</th><th>Expiry</th></tr></thead>
    <tbody>
    <?php foreach ($crates as $c): ?>
      <tr><td><input type="checkbox" class="form-check-input mv-tick" name="ids[]" value="<?= (int)$c['id'] ?>"<?= in_array((int)$c['id'], $picked, true) ? ' checked' : '' ?> data-qty="<?= h((string)$c['qty_left']) ?>"></td>
        <td class="crate-no"><?= h($c['crate_no']) ?></td><td><strong><?= h($c['code']) ?></strong> <span class="small text-muted"><?= h($c['item_name']) ?></span></td>
        <td class="num"><?= (float)$c['pcs'] > 0 ? qty($c['pcs']) : '' ?></td><td class="num"><?= qty($c['qty_left']) ?> <?= h($c['base_unit'] ?: 'kg') ?></td>
        <td><?= h(fdate($c['production_date'])) ?></td><td><?= h(fdate($c['expiry_date'])) ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$crates): ?><tr><td colspan="7" class="empty-row">No open crate at this site.</td></tr><?php endif; ?>
    </tbody>
  </table></div>
  <?php if ($crates && Access::can($pageKey, 'create')): ?>
  <div class="card-footer"><div class="row g-2 align-items-end">
    <?= select_field('to_id', 'Move to', $toOpts, '', ['blank' => '— choose —', 'class' => 'col-md-3', 'required' => true, 'no_add' => true]) ?>
    <?= input_field('txn_date', 'Date', today(), ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
    <?= input_field('memo', 'Memo', '', ['class' => 'col-md-4']) ?>
    <div class="col-md-3 d-flex gap-2 align-items-center"><button class="btn btn-primary btn-sm" id="mvGo" disabled><i class="bi bi-truck-flatbed"></i> Move crates</button><span class="small text-muted" id="mvSum"></span></div>
  </div></div>
  <?php endif; ?>
</form>
<script>
(function () {
  const f = document.getElementById('moveForm'), go = document.getElementById('mvGo'), sum = document.getElementById('mvSum');
  if (!f || !go) return;
  const sync = () => {
    const t = f.querySelectorAll('.mv-tick:checked');
    let q = 0; t.forEach((c) => { q += parseFloat(c.dataset.qty) || 0; });
    go.disabled = !t.length;
    sum.textContent = t.length ? t.length + (t.length === 1 ? ' crate, ' : ' crates, ') + q.toLocaleString('en-US', { maximumFractionDigits: 3 }) : '';
  };
  f.addEventListener('change', sync);
  sync();
})();
</script>
<?php
layout_end();
