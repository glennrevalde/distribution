<?php
declare(strict_types=1);

/**
 * Vendors > Supplier Items
 *
 * The items each supplier delivers, in the unit they are allocated and picked up in (crates, kilos or packs),
 * with the supplier's own code and the cost per kilo (or pack) the last pick-up was received at. Supplier
 * Allocation lists these items for the supplier, in this order, so the day's allocation is typed in one pass.
 */
require_once APP_ROOT . '/modules/txn/_common.php';

$pageKey = 'vend.supplier_items';
$vendorId = gint('vendor_id') ?: pint('vendor_id');
$vendor = $vendorId ? DB::row('SELECT * FROM vendors WHERE id = :id', ['id' => $vendorId]) : null;
$canEdit = Access::can($pageKey, 'edit') || Access::can($pageKey, 'create');

handle_post(function () use ($pageKey, $vendor) {
    if (!$vendor) {
        fail('Choose the supplier first.');
    }
    if (!Access::can($pageKey, 'edit') && !Access::can($pageKey, 'create')) {
        Access::denyPage($pageKey, 'change the supplier items on');
    }
    $rows = [];
    $order = 0;
    foreach ((array)($_POST['si'] ?? []) as $r) {
        $itemId = (int)($r['item_id'] ?? 0);
        if (!$itemId) {
            continue;
        }
        $item = DB::row("SELECT id, code, item_type FROM items WHERE id = :id", ['id' => $itemId]);
        if (!$item) {
            fail('An item on the list no longer exists.');
        }
        if (isset($rows[$itemId])) {
            fail($item['code'] . ' is on the list twice.');
        }
        $uomId = !empty($r['uom_id']) ? (int)$r['uom_id'] : null;
        if ($uomId && !Uom::unitBelongsTo($uomId, $itemId)) {
            fail('The unit chosen for ' . $item['code'] . ' is not in its U/M set.');
        }
        $rows[$itemId] = [
            'vendor_id' => (int)$vendor['id'], 'item_id' => $itemId, 'uom_id' => $uomId,
            'vendor_code' => mb_substr(trim((string)($r['vendor_code'] ?? '')), 0, 40) ?: null,
            'last_cost' => max(0.0, round(to_num($r['last_cost'] ?? 0), 4)),
            'sort_order' => ++$order, 'is_active' => !empty($r['is_active']) ? 1 : 0,
        ];
    }
    DB::tx(function () use ($vendor, $rows, $pageKey) {
        $before = DB::all('SELECT i.code, vi.uom_id, vi.last_cost, vi.is_active FROM vendor_items vi JOIN items i ON i.id = vi.item_id WHERE vi.vendor_id = :v ORDER BY vi.sort_order', ['v' => $vendor['id']]);
        $keep = [];
        foreach ($rows as $itemId => $d) {
            $id = DB::value('SELECT id FROM vendor_items WHERE vendor_id = :v AND item_id = :i', ['v' => $vendor['id'], 'i' => $itemId]);
            if ($id) {
                DB::update('vendor_items', $d, 'id = :id', ['id' => $id]);
                $keep[] = (int)$id;
            } else {
                $keep[] = DB::insert('vendor_items', $d);
            }
        }
        if ($keep) {
            [$in, $p] = DB::in('k', $keep);
            DB::run("DELETE FROM vendor_items WHERE vendor_id = :v AND id NOT IN $in", ['v' => $vendor['id']] + $p);
        } else {
            DB::run('DELETE FROM vendor_items WHERE vendor_id = :v', ['v' => $vendor['id']]);
        }
        Audit::log('edit', 'vend', 'supplier_items', (int)$vendor['id'], $vendor['name'], ['page_key' => $pageKey,
            'before' => $before, 'after' => array_values(array_map(fn($r) => ['item_id' => $r['item_id'], 'uom_id' => $r['uom_id'], 'last_cost' => $r['last_cost']], $rows))]);
    });
    flash('success', 'Supplier items of ' . $vendor['name'] . ' saved (' . count($rows) . ').');
    redirect(url($pageKey, ['vendor_id' => $vendor['id']]));
});

$suppliers = Lookup::vendors();
$items = DB::all("SELECT i.id, i.code, i.name, i.cost, i.unit FROM items i WHERE i.is_active = 1 AND i.item_type IN ('inventory','assembly','non_inventory') ORDER BY i.code");
$itemOpts = [];
foreach ($items as $it) {
    $itemOpts[(int)$it['id']] = item_label($it['code'], $it['name']);
}
$unitsByItem = [];
foreach (Uom::unitsByItem(array_map(fn($i) => (int)$i['id'], $items)) as $iid => $list) {
    $unitsByItem[$iid] = array_map(fn($u) => ['id' => $u['id'], 'code' => $u['code'] . ($u['v'] ? ' (crates)' : ''), 'v' => $u['v'], 'base' => $u['base']], $list);
}
$rows = $vendor ? Allocations::supplierItems((int)$vendor['id'], false) : [];
if (is_post()) {
    $rows = array_values((array)($_POST['si'] ?? []));
}
$counts = DB::pairs('SELECT vendor_id, COUNT(*) FROM vendor_items GROUP BY vendor_id');
$supplierOpts = [];
foreach ($suppliers as $sid => $sname) {
    $supplierOpts[$sid] = $sname . (isset($counts[$sid]) ? ' (' . $counts[$sid] . ' item' . ((int)$counts[$sid] === 1 ? '' : 's') . ')' : '');
}

layout_start('Supplier Items', ['actions' => page_link('vend.allocations', [], 'Supplier Allocation', 'btn-outline-secondary', 'clipboard-check')
    . ' ' . page_link('vend.pickup', [], 'Pick-Up Supplier Items', 'btn-outline-secondary', 'truck')]);
?>
<form method="get" class="filter-bar mb-3">
  <input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="row g-2 align-items-end">
    <div class="col-md-5"><label class="form-label" for="siVendor">Supplier</label>
      <select class="form-select form-select-sm" id="siVendor" name="vendor_id" data-combo data-autosubmit><?= options($supplierOpts, $vendorId, '— choose a supplier —') ?></select></div>
    <div class="col-md-7 small text-muted">The items a supplier delivers and the unit each one is allocated in. Supplier Allocation lists them in this order.</div>
  </div>
</form>

<?php if ($vendor): ?>
<form method="post" class="card" id="siForm"><?= csrf_field() ?><input type="hidden" name="vendor_id" value="<?= (int)$vendor['id'] ?>">
  <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2"><span><?= h($vendor['name']) ?></span>
    <span class="small text-muted"><?= count($rows) ?> item<?= count($rows) === 1 ? '' : 's' ?></span></div>
  <div class="table-responsive"><table class="table table-sm mb-0 si-table" id="siTable">
    <thead><tr><th style="min-width:260px">Item</th><th>Allocated in</th><th>Supplier's code</th><th class="num">Cost per base unit</th><th class="text-center">Active</th><th></th></tr></thead>
    <tbody>
    <?php foreach ($rows as $i => $r): ?>
      <tr>
        <td><select class="form-select form-select-sm" name="si[<?= $i ?>][item_id]" data-si-item data-combo><?= options($itemOpts, $r['item_id'] ?? '', '') ?></select></td>
        <td><select class="form-select form-select-sm" name="si[<?= $i ?>][uom_id]" data-si-uom data-value="<?= h((string)($r['uom_id'] ?? '')) ?>"></select></td>
        <td><input class="form-control form-control-sm" name="si[<?= $i ?>][vendor_code]" value="<?= h((string)($r['vendor_code'] ?? '')) ?>"></td>
        <td><input class="form-control form-control-sm text-end" name="si[<?= $i ?>][last_cost]" value="<?= h(isset($r['last_cost']) && (float)$r['last_cost'] > 0 ? rtrim(rtrim(number_format((float)$r['last_cost'], 4, '.', ''), '0'), '.') : '') ?>"></td>
        <td class="text-center"><input type="checkbox" class="form-check-input" name="si[<?= $i ?>][is_active]" value="1"<?= checked(($r['is_active'] ?? 1) ? 1 : 0) ?>></td>
        <td class="grid-acts"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-si-del title="Take off the list" aria-label="Take off the list"><i class="bi bi-x-lg"></i></button></td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table></div>
  <template id="siTpl"><tr>
    <td><select class="form-select form-select-sm" name="si[__i__][item_id]" data-si-item data-combo><?= options($itemOpts, '', '') ?></select></td>
    <td><select class="form-select form-select-sm" name="si[__i__][uom_id]" data-si-uom data-value=""></select></td>
    <td><input class="form-control form-control-sm" name="si[__i__][vendor_code]"></td>
    <td><input class="form-control form-control-sm text-end" name="si[__i__][last_cost]"></td>
    <td class="text-center"><input type="checkbox" class="form-check-input" name="si[__i__][is_active]" value="1" checked></td>
    <td class="grid-acts"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-si-del title="Take off the list" aria-label="Take off the list"><i class="bi bi-x-lg"></i></button></td></tr></template>
  <div class="card-body pt-2">
    <div class="grid-add"><button type="button" class="btn btn-sm btn-outline-secondary" data-si-add="1"><i class="bi bi-plus"></i> Add item</button>
      <button type="button" class="btn btn-sm btn-outline-secondary" data-si-add="5"><i class="bi bi-plus"></i> Add 5 items</button></div>
  </div>
  <?php if ($canEdit): ?><div class="card-footer"><button class="btn btn-primary btn-sm"><i class="bi bi-check-lg"></i> Save supplier items</button>
    <a class="btn btn-outline-secondary btn-sm" href="<?= h(url('vend.allocations', ['a' => 'new', 'vendor_id' => $vendor['id']])) ?>"><i class="bi bi-clipboard-plus"></i> New allocation for this supplier</a></div><?php endif; ?>
</form>
<script>
(function () {
  const units = <?= json_encode((object)$unitsByItem) ?>;
  const tb = document.querySelector('#siTable tbody'), tpl = document.getElementById('siTpl');
  function fill(tr) {
    const item = tr.querySelector('[data-si-item]'), sel = tr.querySelector('[data-si-uom]');
    const list = units[item.value] || [];
    const want = sel.value || sel.dataset.value || '';
    sel.innerHTML = list.map((u) => '<option value="' + u.id + '">' + u.code.replace(/</g, '&lt;') + '</option>').join('');
    const crate = list.find((u) => u.v), base = list.find((u) => u.base);
    sel.value = list.some((u) => String(u.id) === String(want)) ? want : String((crate || base || list[0] || { id: '' }).id);
  }
  tb.querySelectorAll('tr').forEach(fill);
  tb.addEventListener('change', (e) => { if (e.target.matches('[data-si-item]')) { const tr = e.target.closest('tr'); tr.querySelector('[data-si-uom]').value = ''; tr.querySelector('[data-si-uom]').dataset.value = ''; fill(tr); } });
  tb.addEventListener('click', (e) => { const b = e.target.closest('[data-si-del]'); if (b) b.closest('tr').remove(); });
  document.querySelectorAll('[data-si-add]').forEach((b) => b.addEventListener('click', () => {
    for (let k = 0; k < (+b.dataset.siAdd || 1); k++) {
      tb.insertAdjacentHTML('beforeend', tpl.innerHTML.replace(/__i__/g, 'n' + Date.now() + k));
      const tr = tb.lastElementChild; fill(tr); tr.classList.add('row-new');
      if (window.AppCombo) window.AppCombo.init(tr);
    }
  }));
  if (!tb.querySelector('tr')) document.querySelector('[data-si-add="5"]').click();
})();
</script>
<?php else: ?>
<div class="empty-state"><i class="bi bi-truck"></i><p>Choose a supplier to see and set the items it delivers.</p></div>
<?php endif; ?>
<?php
layout_end();
