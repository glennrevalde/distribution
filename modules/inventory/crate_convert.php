<?php
declare(strict_types=1);

/**
 * Inventory > Convert Crates to Kilos
 *
 * Stock received in crates is sold by the crate. Converting a crate to kilos (or packs) stops following it: what
 * is left in it stays on hand as loose stock and is sold by the kilo like stock that was never in a crate. The
 * quantity on hand and its value do not change, so no journal entry is made; each conversion is kept in the
 * crate's history and in the audit trail.
 */
$pageKey = 'inv.crate_convert';
$siteId = gint('site_id') ?: (int)array_key_first(Lookup::sites());
$itemId = gint('item_id');
$picked = array_map('intval', (array)($_GET['ids'] ?? []));
if ($picked) {
    // crates ticked in the Crate Center: their site and item lead the list
    $first = DB::row('SELECT site_id, item_id FROM crates WHERE id = :id', ['id' => $picked[0]]);
    if ($first) {
        $siteId = (int)$first['site_id'];
        $itemId = count(array_unique(DB::column('SELECT item_id FROM crates WHERE id IN (' . implode(',', $picked) . ')'))) === 1 ? (int)$first['item_id'] : $itemId;
    }
}

handle_post(function () use ($pageKey) {
    Access::require($pageKey, 'create');
    $ids = array_values(array_filter(array_map('intval', (array)($_POST['ids'] ?? []))));
    if (!$ids) {
        fail('Tick the crates to convert.');
    }
    $note = mb_substr(trim((string)p('note')), 0, 200);
    $n = Crates::convert($ids, $note, pdate('convert_date') ?: today());
    flash('success', $n . ' crate' . ($n === 1 ? '' : 's') . ' converted: what was left in ' . ($n === 1 ? 'it is' : 'them is') . ' now loose stock, sold by the kilo.');
    redirect(url($pageKey, ['site_id' => pint('site_id'), 'item_id' => pint('item_id')]));
});

$where = "c.status = 'open' AND c.site_id = :s";
$params = ['s' => $siteId];
if ($itemId) {
    $where .= ' AND c.item_id = :i';
    $params['i'] = $itemId;
}
$crates = Access::siteAllowed($siteId) ? DB::all(
    "SELECT c.*, i.code, i.name AS item_name, us.base_unit FROM crates c JOIN items i ON i.id = c.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
      WHERE $where ORDER BY i.code, (c.expiry_date IS NULL), c.expiry_date, c.id",
    $params
) : [];
$itemOpts = DB::pairs("SELECT DISTINCT i.id, CONCAT(i.code, ' - ', i.name) FROM items i JOIN crates c ON c.item_id = i.id AND c.status = 'open' ORDER BY i.code");

layout_start('Convert Crates to Kilos', ['actions' => page_link('inv.crates', [], 'Crate Center', 'btn-outline-secondary', 'boxes')]);
?>
<p class="text-muted small page-lead">Converting a crate stops following it crate by crate: what is left in it stays on hand as loose kilos (or packs) and is sold by the kilo.
  Nothing is posted to the books; the quantity and the value on hand stay the same.</p>
<form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="row g-2 align-items-end">
    <?= select_field('site_id', 'Site', Lookup::sites(), $siteId, ['class' => 'col-md-3', 'no_add' => true, 'extra' => 'data-autosubmit']) ?>
    <?= select_field('item_id', 'Item', $itemOpts, $itemId, ['blank' => 'All items kept in crates', 'class' => 'col-md-5', 'no_add' => true, 'extra' => 'data-combo data-autosubmit']) ?>
  </div>
</form>
<form method="post" class="card" id="convForm"><?= csrf_field() ?>
  <input type="hidden" name="site_id" value="<?= (int)$siteId ?>"><input type="hidden" name="item_id" value="<?= (int)$itemId ?>">
  <div class="table-responsive"><table class="table table-sm table-hover mb-0">
    <thead><tr><th><input type="checkbox" class="form-check-input" data-check-all="#convForm .conv-tick" aria-label="Tick every crate"></th><th>Crate no.</th><th>Item</th><th class="num">Heads</th><th class="num">Received</th><th class="num">Left</th><th>Production</th><th>Expiry</th><th>Received on</th></tr></thead>
    <tbody>
    <?php foreach ($crates as $c): ?>
      <tr><td><input type="checkbox" class="form-check-input conv-tick" name="ids[]" value="<?= (int)$c['id'] ?>"<?= in_array((int)$c['id'], $picked, true) ? ' checked' : '' ?> data-qty="<?= h((string)$c['qty_left']) ?>" aria-label="Convert crate <?= h($c['crate_no']) ?>"></td>
        <td class="crate-no"><?= h($c['crate_no']) ?></td><td><strong><?= h($c['code']) ?></strong> <span class="small text-muted"><?= h($c['item_name']) ?></span></td>
        <td class="num"><?= (float)$c['pcs'] > 0 ? qty($c['pcs']) : '' ?></td><td class="num"><?= qty($c['qty_in']) ?></td><td class="num"><?= qty($c['qty_left']) ?> <?= h($c['base_unit'] ?: 'kg') ?></td>
        <td><?= h(fdate($c['production_date'])) ?></td><td><?= h(fdate($c['expiry_date'])) ?></td><td><?= h(fdate($c['received_date'])) ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$crates): ?><tr><td colspan="9" class="empty-row">No open crate at this site<?= $itemId ? ' for this item' : '' ?>.</td></tr><?php endif; ?>
    </tbody>
  </table></div>
  <?php if ($crates && Access::can($pageKey, 'create')): ?>
  <div class="card-footer"><div class="row g-2 align-items-end">
    <?= input_field('convert_date', 'Date', today(), ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
    <?= input_field('note', 'Reason or note (kept in each crate\'s history)', '', ['class' => 'col-md-6', 'extra' => 'placeholder="Repacked for retail, crate damaged ..."']) ?>
    <div class="col-md-4 d-flex gap-2 align-items-center"><button class="btn btn-primary btn-sm" id="convGo" disabled><i class="bi bi-arrow-left-right"></i> Convert to kilos</button><span class="small text-muted" id="convSum"></span></div>
  </div></div>
  <?php endif; ?>
</form>
<script>
(function () {
  const f = document.getElementById('convForm'), go = document.getElementById('convGo'), sum = document.getElementById('convSum');
  if (!f || !go) return;
  const sync = () => {
    const t = f.querySelectorAll('.conv-tick:checked');
    let q = 0; t.forEach((c) => { q += parseFloat(c.dataset.qty) || 0; });
    go.disabled = !t.length;
    sum.textContent = t.length ? t.length + (t.length === 1 ? ' crate, ' : ' crates, ') + q.toLocaleString('en-US', { maximumFractionDigits: 3 }) + ' left in them' : '';
  };
  f.addEventListener('change', sync);
  f.addEventListener('submit', (e) => { if (!confirm('Convert the ticked crates to loose stock? They will no longer be followed crate by crate.')) e.preventDefault(); });
  sync();
})();
</script>
<?php
layout_end();
