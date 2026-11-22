<?php
declare(strict_types=1);

$pageKey = 'inv.physical_count';
$sites = Lookup::sites();
$siteId = (int)(g('site_id') ?: p('site_id') ?: array_key_first($sites));
$blind = g('blind') === '1';
$items = DB::all("SELECT i.id, i.code, i.name, i.unit, i.avg_cost, v.name AS vendor, COALESCE(s.qty_on_hand,0) AS qty
                    FROM items i LEFT JOIN item_site_stock s ON s.item_id = i.id AND s.site_id = :s
                    LEFT JOIN vendors v ON v.id = i.preferred_vendor_id
                   WHERE i.is_active = 1 AND i.item_type IN ('inventory','assembly') ORDER BY i.code", ['s' => $siteId]);

// v43: an item that keeps production / expiry dates is counted by date group (one row each)
$lotGroups = Lots::on() ? Lots::forItems(array_column($items, 'id'), $siteId) : [];
foreach ($lotGroups as $iid => $gs) {
    if (!array_filter($gs, fn($g) => $g['prod'] || $g['exp'])) {
        unset($lotGroups[$iid]);    // only stock with no dates: counted as before
    }
}

handle_post(function () use ($pageKey, $siteId, $items, $lotGroups) {
    Access::require($pageKey, 'create');
    if (!Access::siteAllowed($siteId)) {
        fail('You are not allowed to post counts for that site.');
    }
    $lines = [];
    $value = 0.0;
    foreach ($items as $it) {
        if (isset($lotGroups[(int)$it['id']])) {
            foreach ($lotGroups[(int)$it['id']] as $g) {
                $v = $_POST['count_lot'][$it['id']][$g['key']] ?? '';
                if (trim((string)$v) === '') {
                    continue;
                }
                $diff = round(to_num($v) - (float)$g['qty'], 4);
                if (abs($diff) < 0.00001) {
                    continue;
                }
                $lines[] = ['line_kind' => 'item', 'item_id' => (int)$it['id'], 'qty' => $diff, 'site_id' => $siteId,
                    'production_date' => $g['prod'], 'expiry_date' => $g['exp'],
                    'description' => 'Count difference (' . $g['label'] . ': counted ' . qty(to_num($v)) . ', system ' . qty($g['qty']) . ')'];
                $value += abs($diff * (float)$it['avg_cost']);
            }
            continue;
        }
        $v = $_POST['count'][$it['id']] ?? '';
        if (trim((string)$v) === '') {
            continue;
        }
        $diff = to_num($v) - (float)$it['qty'];
        if (abs($diff) < 0.00001) {
            continue;
        }
        $lines[] = ['line_kind' => 'item', 'item_id' => (int)$it['id'], 'qty' => $diff, 'site_id' => $siteId, 'description' => 'Count difference (counted ' . qty(to_num($v)) . ', system ' . qty($it['qty']) . ')'];
        $value += abs($diff * (float)$it['avg_cost']);
    }
    if (!$lines) {
        fail('No differences to post. Counted quantities match the system.');
    }
    $approver = Approval::check($pageKey, Approval::exceeds(Access::limit('max_amount'), $value), 'count adjustment of about ' . money($value));
    $id = Txn::save('inventory_adjustment', [
        'txn_date' => pdate('txn_date', today()), 'site_id' => $siteId, 'account_id' => Accts::get('inventory_adjustment'),
        'memo' => 'Physical count' . (p('counted_by') ? ' by ' . p('counted_by') : ''), 'ref_no' => p('ref_no') ?: null, 'status' => 'open',
        'approved_by' => $approver['id'] ?? null,
    ], $lines, null, ['reason' => 'Physical inventory count', 'approved_by' => $approver['username'] ?? null]);
    flash('success', count($lines) . ' count difference(s) posted.');
    redirect(Access::page('inv.adjust') ? url('inv.adjust', ['a' => 'view', 'id' => $id]) : url($pageKey, ['site_id' => $siteId]));
});

layout_start('Physical Inventory Count', ['actions' => page_link('rpt.physical_worksheet', ['site_id' => $siteId, 'blind' => 1], 'Print blank worksheet', 'btn-outline-secondary', 'printer')]);
?>
<form method="get" class="row g-2 mb-2 filters"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <?= select_field('site_id', 'Site', $sites, $siteId, ['class' => 'col-md-3', 'extra' => 'data-autosubmit']) ?>
  <div class="col-md-3 d-flex align-items-end"><label class="small"><input type="checkbox" name="blind" value="1" <?= checked($blind) ?> data-autosubmit> Hide system quantities (blind count)</label></div>
</form>
<?php if (Access::can($pageKey, 'create')): ?>
<form method="post"><?= csrf_field() ?><input type="hidden" name="site_id" value="<?= (int)$siteId ?>">
<div class="card mb-3"><div class="card-body row g-2">
  <?= input_field('txn_date', 'Count date', fv('txn_date', null, today()), ['type' => 'date', 'class' => 'col-md-2']) ?>
  <?= input_field('counted_by', 'Counted by', fv('counted_by'), ['class' => 'col-md-3']) ?>
  <?= input_field('ref_no', 'Count sheet no.', fv('ref_no'), ['class' => 'col-md-2']) ?>
  <?= Classes::field(fv('class_id'), 'col-md-3') ?>
</div></div>
<?php endif; ?>
<div class="card mb-3"><div class="table-responsive" style="max-height:65vh"><table class="table table-sm mb-0">
  <thead class="sticky-top bg-white"><tr><?php [$h1, $h2] = item_cols(); ?><th><?= h($h1) ?></th><th><?= h($h2) ?></th><th>Unit</th><th>Pref. vendor</th><?= $blind ? '' : '<th class="num">System qty</th>' ?><th class="num">Counted</th><?= $blind ? '' : '<th class="num">Difference</th>' ?></tr></thead>
  <?php foreach ($items as $it): ?>
    <?php [$c1, $c2] = item_vals($it['code'], $it['name']); ?>
    <?php if (isset($lotGroups[(int)$it['id']])): ?>
      <tr class="pc-item-head"><td><?= h($c1) ?></td><td><?= h($c2) ?></td><td><?= h($it['unit']) ?></td><td class="small"><?= h($it['vendor']) ?></td><?= $blind ? '' : '<td class="num">' . qty($it['qty']) . '</td>' ?><td class="small text-muted text-end">by date group</td><?= $blind ? '' : '<td></td>' ?></tr>
      <?php foreach ($lotGroups[(int)$it['id']] as $g): ?>
      <tr class="pc-lot-row"><td></td><td class="small adj-lot-label lot-<?= h($g['status']) ?>" colspan="3"><i class="bi bi-calendar2-week"></i> <?= h($g['label']) ?><?= $g['status'] === 'expired' ? ' <span class="lot-flag">expired</span>' : '' ?></td>
        <?= $blind ? '' : '<td class="num">' . qty($g['qty']) . '</td>' ?>
        <td><?php if (Access::can($pageKey, 'create')): ?><input class="form-control form-control-sm text-end ms-auto pc-in" style="width:100px" data-sys="<?= h((string)$g['qty']) ?>" name="count_lot[<?= (int)$it['id'] ?>][<?= h($g['key']) ?>]" value="<?= h($_POST['count_lot'][$it['id']][$g['key']] ?? '') ?>" aria-label="Counted <?= h($it['code'] . ', ' . $g['label']) ?>"><?php else: ?>______<?php endif; ?></td>
        <?= $blind ? '' : '<td class="num pc-diff"></td>' ?></tr>
      <?php endforeach; continue; ?>
    <?php endif; ?>
    <tr><td><?= h($c1) ?></td><td><?= h($c2) ?></td><td><?= h($it['unit']) ?></td><td class="small"><?= h($it['vendor']) ?></td>
      <?= $blind ? '' : '<td class="num">' . qty($it['qty']) . '</td>' ?>
      <td><?php if (Access::can($pageKey, 'create')): ?><input class="form-control form-control-sm text-end ms-auto pc-in" style="width:100px" data-sys="<?= h($it['qty']) ?>" name="count[<?= (int)$it['id'] ?>]" value="<?= h($_POST['count'][$it['id']] ?? '') ?>"><?php else: ?>______<?php endif; ?></td>
      <?= $blind ? '' : '<td class="num pc-diff"></td>' ?></tr>
  <?php endforeach; ?>
</table></div></div>
<?php if (Access::can($pageKey, 'create')): ?>
<?= Approval::fields() ?>
<p class="small text-muted mt-2">Leave items blank to skip them. Differences are posted through Adjust Quantity/Value on Hand with the reason "Count difference".<?= $lotGroups ? ' Items with production and expiry dates are counted by date group; stock found with other dates is added in Adjust Quantity/Value on Hand with its dates.' : '' ?></p>
<button class="btn btn-primary">Post count differences</button>
</form>
<?php endif; ?>
<script>
document.querySelectorAll('.pc-in').forEach(i => i.addEventListener('input', () => {
  const d = i.closest('tr').querySelector('.pc-diff'); if (!d) return;
  d.textContent = i.value === '' ? '' : (AppFmt.num(i.value) - AppFmt.num(i.dataset.sys)).toString();
  d.className = 'num pc-diff ' + (AppFmt.num(i.value) - AppFmt.num(i.dataset.sys) < 0 ? 'neg' : '');
}));
</script>
<?php
layout_end();
