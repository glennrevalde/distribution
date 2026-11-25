<?php
declare(strict_types=1);

require_once APP_ROOT . '/modules/txn/_grids.php';

/**
 * v4 distribution: Inventory > Convert Kilos to Crates (the other way round from Convert Crates to Kilos).
 *
 * Loose stock of a site - kilos, or packs - put into crates where it is (or into sacks: whatever the container unit of
 * the item's U/M set is). The user picks the production / expiry group the stock comes from and types each crate's
 * weight as the scale reads it (1330 = 13.30 kg); the crates are numbered on from the last one. From then on the
 * stock is followed and sold crate by crate. Nothing is posted: the quantity and the value on hand stay the same.
 * Dispatch Inventory does the same as stock leaves for a van or outlet.
 */
$pageKey = 'inv.crate_pack';
$sites = Lookup::sites();
$siteId = gint('site_id') ?: (int)array_key_first($sites);
if (!isset($sites[$siteId])) {
    $siteId = (int)array_key_first($sites);
}

handle_post(function () use ($pageKey) {
    Access::require($pageKey, 'create');
    $siteId = pint('site_id');
    $itemId = pint('item_id');
    if (!$siteId || !$itemId) {
        fail('Choose the site and the item.');
    }
    $it = DB::row('SELECT code, name FROM items WHERE id = :i', ['i' => $itemId]);
    if (!$it) {
        fail('Item not found.');
    }
    $date = pdate('pack_date') ?: today();
    $used = [];
    $data = Crates::packRows(['crates' => p('crates'), 'pack_lot' => p('pack_lot'), 'pack_prod' => p('pack_prod'), 'pack_exp' => p('pack_exp')],
        $itemId, $it['code'], $siteId, null, $date, $used);
    if (!$data) {
        fail('Press Fill crates on the item and type the weight of each crate.');
    }
    $note = mb_substr(trim((string)p('note')), 0, 200);
    $unit = Crates::baseUnit($itemId);
    [$fp, $fe] = Lots::split((string)($data['key'] ?? '|'));
    $redate = Lots::itemTracked($itemId) && Lots::key($fp, $fe) !== Lots::key($data['prod'] ?? null, $data['exp'] ?? null);
    if ($redate) {
        // v5: loose stock without dates given the dates typed: the stock itself moves to those dates (a date change, at
        // the same value), so the crates and the stock they hold carry the same dates
        $txnId = LotCheck::changeDates($siteId, $date, [[
            'item_id' => $itemId, 'qty' => $data['qty'], 'from' => [$fp, $fe], 'to' => [$data['prod'] ?? null, $data['exp'] ?? null],
            'crates' => ['dir' => 'pack', 'rows' => $data['rows'], 'from' => [$fp, $fe]],
        ]], 'Loose stock put into ' . strtolower(Crates::containerName($itemId)) . ' with its production and expiry dates' . ($note !== '' ? ' - ' . $note : ''),
            'Convert Kilos to Crates: dates given to loose stock without dates');
        $n = (int)DB::value('SELECT COUNT(*) FROM crates WHERE receive_txn_id = :t', ['t' => $txnId]);
        $nos = DB::column('SELECT crate_no FROM crates WHERE receive_txn_id = :t', ['t' => $txnId]);
    } else {
        $n = Crates::packAt($itemId, $siteId, $data, $note, $date);
        $nos = DB::column("SELECT crate_no FROM crates WHERE item_id = :i AND site_id = :s AND receive_txn_id IS NULL ORDER BY id DESC LIMIT " . (int)$n, ['i' => $itemId, 's' => $siteId]);
    }
    sort($nos, SORT_NATURAL);
    flash('success', $n . ' ' . strtolower(Crates::containerName($itemId, $n !== 1)) . ' filled: ' . Crates::fig($data['qty'], $unit) . ' ' . $unit . ' of ' . $it['code']
        . ' is now followed crate by crate (' . ($n === 1 ? 'no. ' . $nos[0] : 'nos. ' . reset($nos) . ' to ' . end($nos)) . ')'
        . ($redate ? ', with ' . Lots::label($data['prod'] ?? null, $data['exp'] ?? null) . ' on the stock and on the crates (' . Txn::ref(Txn::load($txnId)) . ').' : '.'));
    redirect(url($pageKey, ['site_id' => $siteId]));
});

// the items kept in crates, with their loose stock and their open crates at the site
$rows = [];
if (Crates::ready() && Access::siteAllowed($siteId)) {
    $crated = Crates::crateItems();
    if ($crated) {
        [$in, $p] = DB::in('cp', array_keys($crated));
        $p['s'] = $siteId;
        $p['s2'] = $siteId;
        foreach (DB::all("SELECT i.id, i.code, i.name, COALESCE(st.qty_on_hand, 0) AS on_hand,
                                 (SELECT COUNT(*) FROM crates c WHERE c.item_id = i.id AND c.site_id = :s2 AND c.status = 'open') AS crates
                            FROM items i LEFT JOIN item_site_stock st ON st.item_id = i.id AND st.site_id = :s
                           WHERE i.id IN $in AND i.is_active = 1 ORDER BY i.code", $p) as $r) {
            $loose = Crates::loose((int)$r['id'], $siteId);
            $rows[] = $r + ['loose' => max(0.0, $loose), 'base' => $crated[(int)$r['id']]['base'] ?: 'kg', 'conv' => Crates::convertLabel((int)$r['id']),
                'many' => Crates::containerName((int)$r['id'])];
        }
    }
}
$withLoose = array_values(array_filter($rows, fn($r) => $r['loose'] > Crates::EPS));
$canCreate = Access::can($pageKey, 'create');

layout_start('Convert Kilos to Crates', ['actions' => page_link('inv.crate_convert', [], 'Convert Crates to Kilos', 'btn-outline-secondary', 'arrow-left-right')
    . ' ' . page_link('inv.crates', [], 'Crate Center', 'btn-outline-secondary', 'boxes')]);
?>
<p class="text-muted small page-lead">Loose stock put into crates where it is: pick the production / expiry group, then type each crate's weight as the scale reads it (1330 for 13.30 kg).
  From then on the stock is followed and sold crate by crate. Nothing is posted to the books; the quantity and the value on hand stay the same.
  Loose stock without dates that is given dates in the crate window takes those dates as well: the change is kept as a date change on Adjustments.
  To fill crates as the stock leaves for a van or outlet, use <?= safe_link('inv.dispatch', ['a' => 'new'], 'Dispatch Inventory') ?>.</p>
<form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="row g-2 align-items-end">
    <?= select_field('site_id', 'Site', $sites, $siteId, ['class' => 'col-md-4', 'no_add' => true, 'extra' => 'data-autosubmit']) ?>
  </div>
</form>
<div class="card mb-3 pack-items">
  <div class="card-header d-flex flex-wrap align-items-center justify-content-between gap-2"><span>Items kept in crates at <?= h($sites[$siteId] ?? '') ?></span>
    <span class="small text-muted"><?= count($withLoose) ?> of <?= count($rows) ?> with loose stock</span></div>
  <div class="table-responsive"><table class="table table-sm table-hover mb-0 pack-items-table">
    <thead><tr><th>Item</th><th class="num">On hand</th><th class="num">In crates</th><th class="num">Loose</th><th class="text-end">Convert</th></tr></thead>
    <tbody>
    <?php foreach ($rows as $r): $loose = (float)$r['loose']; ?>
      <tr class="<?= $loose > Crates::EPS ? '' : 'is-none' ?>">
        <td data-label="Item"><strong><?= h($r['code']) ?></strong> <span class="small text-muted"><?= h($r['name']) ?></span></td>
        <td data-label="On hand" class="num"><?= Crates::fig($r['on_hand'], $r['base']) ?> <span class="qty-unit"><?= h($r['base']) ?></span></td>
        <td data-label="In crates" class="num"><?= (int)$r['crates'] ?></td>
        <td data-label="Loose" class="num fw-semibold"><?= Crates::fig($loose, $r['base']) ?> <span class="qty-unit"><?= h($r['base']) ?></span></td>
        <td class="text-end"><?php if ($canCreate && $loose > Crates::EPS): ?><button type="button" class="btn btn-sm crate-btn" data-pack-item="<?= (int)$r['id'] ?>" data-title="<?= h($r['code'] . ' - ' . $r['name']) ?>"><i class="bi bi-box-arrow-in-down"></i><span><?= h($r['conv']) ?></span></button><?php else: ?><span class="small text-muted"><?= $loose > Crates::EPS ? '' : 'Nothing loose' ?></span><?php endif; ?></td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$rows): ?><tr><td colspan="5" class="empty-row">No item is kept in crates. An item is kept in crates when its U/M set has a unit marked "weight varies".</td></tr><?php endif; ?>
    </tbody>
  </table></div>
</div>
<?php if ($canCreate): ?>
<form method="post" class="card pack-ready" id="packForm" hidden><?= csrf_field() ?>
  <input type="hidden" name="site_id" value="<?= (int)$siteId ?>"><input type="hidden" name="item_id" data-pk="item">
  <input type="hidden" name="crates" data-pk="crates" data-pack-crates><input type="hidden" name="pack_lot" data-pk="lot">
  <input type="hidden" name="pack_prod" data-pk="prod"><input type="hidden" name="pack_exp" data-pk="exp">
  <div class="card-header">Ready to convert</div>
  <div class="card-body">
    <div class="pack-summary"><div class="scale-readout"><span class="scale-digits" data-pk-total>0.00</span><span class="scale-unit" data-pk-unit>kg</span><span class="scale-count" data-pk-count></span></div>
      <div class="pack-summary-text"><strong data-pk-title></strong><span class="small text-muted" data-pk-from></span></div></div>
    <div class="row g-2 align-items-end mt-2">
      <?= input_field('pack_date', 'Date', today(), ['type' => 'date', 'class' => 'col-6 col-md-3 col-xl-2']) ?>
      <?= input_field('note', 'Note (kept in each crate\'s history)', '', ['class' => 'col-md-9 col-xl-5', 'extra' => 'maxlength="200" placeholder="Crated for the morning dispatch ..."']) ?>
      <div class="col-12 col-xl-5 d-flex flex-wrap gap-2 justify-content-xl-end pack-ready-btns"><button class="btn btn-primary"><i class="bi bi-check2"></i> Convert to crates</button>
        <button type="button" class="btn btn-outline-secondary" data-pk-edit><i class="bi bi-pencil"></i> Change</button>
        <button type="button" class="btn btn-outline-secondary" data-pk-cancel>Cancel</button></div>
    </div>
  </div>
</form>
<?php endif; ?>
<?= crates_script_tag() ?>
<script>
(function () {
  const form = document.getElementById('packForm');
  if (!form) return;
  const cratesUrl = <?= json_encode(url('api.crates')) ?>, siteId = <?= json_encode((string)$siteId) ?>;
  const f = (k) => form.querySelector('[data-pk="' + k + '"]');
  let last = null;
  const open = (btn) => {
    const item = btn.dataset.packItem;
    fetch(cratesUrl + '&item_id=' + encodeURIComponent(item) + '&site_id=' + encodeURIComponent(siteId) + '&pack=1', { credentials: 'same-origin' }).then((r) => r.json()).then((d) => {
      if (d.error) { alert(d.error); return; }
      const same = f('item').value === item;
      if (!same) { f('crates').value = ''; f('lot').value = ''; f('prod').value = ''; f('exp').value = ''; }
      last = btn;
      window.CrateWindow.open({ dir: 'pack', title: btn.dataset.title, base: d.base || 'kg', figure: true, container: d.container || 'Crates', container1: d.container1 || 'Crate',
        sub: (d.label || 'Kilos to Crates') + ' at ' + (d.site || 'this site') + '. The crates take the dates of the group the stock comes from.',
        groups: d.groups || [], site: d.site, next: d.next || '1', value: f('crates').value, own: f('crates'), lot: f('lot').value, prod: f('prod').value, exp: f('exp').value, defaultCount: 5,
        fixable: d.fixable || 0, why: d.why || '',
        onSave: (list, tot, extra) => {
          if (!list.length) { form.hidden = true; f('crates').value = ''; return; }
          f('item').value = item; f('crates').value = JSON.stringify(list); f('lot').value = extra.lot; f('prod').value = extra.prod; f('exp').value = extra.exp;
          form.querySelector('[data-pk-total]').textContent = window.CrateWindow.fq(tot.qty);
          form.querySelector('[data-pk-unit]').textContent = d.base || 'kg';
          form.querySelector('[data-pk-count]').textContent = list.length + ' ' + String(list.length === 1 ? (d.container1 || 'crate') : (d.container || 'crates')).toLowerCase();
          form.querySelector('[data-pk-title]').textContent = btn.dataset.title;
          form.querySelector('[data-pk-from]').textContent = 'From: ' + (extra.label || 'loose stock') + '. Numbers ' + list[0].no + (list.length > 1 ? ' to ' + list[list.length - 1].no : '') + '.';
          form.hidden = false;
          form.scrollIntoView({ behavior: 'smooth', block: 'center' });
        } });
    }).catch(() => alert('The loose stock could not be loaded. Check the connection and try again.'));
  };
  document.querySelectorAll('[data-pack-item]').forEach((b) => b.addEventListener('click', () => open(b)));
  form.querySelector('[data-pk-edit]').addEventListener('click', () => { if (last) open(last); });
  form.querySelector('[data-pk-cancel]').addEventListener('click', () => { form.hidden = true; f('crates').value = ''; f('item').value = ''; });
})();
</script>
<?php
layout_end();
