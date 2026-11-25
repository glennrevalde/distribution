<?php
declare(strict_types=1);

/**
 * Inventory > Crate Center
 *
 * Every crate on hand, item by item: its number, heads, the kilos it came with and the kilos still in it, its
 * production and expiry dates, where it is and where it came from. A crate's own page shows its whole history
 * (received, kilos sold out of it, sold whole, moved, converted to kilos). Crates can be ticked here and
 * converted to kilos or moved to another site.
 */
require_once APP_ROOT . '/modules/txn/_common.php';

$pageKey = 'inv.crates';

// ------------------------------------------------------------------ one crate
if (g('a') === 'view') {
    $c = DB::row('SELECT c.*, i.code, i.name AS item_name, s.name AS site_name, v.name AS vendor_name, u.full_name AS converted_name
                     FROM crates c JOIN items i ON i.id = c.item_id JOIN sites s ON s.id = c.site_id
                     LEFT JOIN vendors v ON v.id = c.vendor_id LEFT JOIN users u ON u.id = c.converted_by WHERE c.id = :id', ['id' => gint('id') ?? 0]);
    if (!$c || !Access::siteAllowed((int)$c['site_id'])) {
        flash('warning', 'Crate not found.');
        redirect(url($pageKey));
    }
    $base = Crates::baseUnit((int)$c['item_id']);
    $moves = DB::all('SELECT m.*, t.txn_type, t.txn_no, cu.name AS customer_name, s1.name AS site_name, s2.name AS site2_name, u.full_name AS user_name
                        FROM crate_movements m LEFT JOIN transactions t ON t.id = m.txn_id LEFT JOIN customers cu ON cu.id = m.customer_id
                        LEFT JOIN sites s1 ON s1.id = m.site_id LEFT JOIN sites s2 ON s2.id = m.site2_id LEFT JOIN users u ON u.id = m.created_by
                       WHERE m.crate_id = :c ORDER BY m.move_date, m.id', ['c' => $c['id']]);
    $days = $c['expiry_date'] ? (int)floor((strtotime($c['expiry_date']) - strtotime(today())) / 86400) : null;
    $usedPct = (float)$c['qty_in'] > 0 ? max(0, min(100, round((1 - (float)$c['qty_left'] / (float)$c['qty_in']) * 100))) : 0;
    layout_start('Crate ' . $c['crate_no'], ['actions' => btn_link(url($pageKey, ['item_id' => $c['item_id'], 'site_id' => $c['site_id']]), 'Crate Center', 'btn-outline-secondary', 'boxes')]);
    ?>
    <div class="crate-sheet mb-3">
      <div class="crate-tag">
        <div class="crate-tag-no"><?= h($c['crate_no']) ?></div>
        <div class="crate-tag-item"><strong><?= h($c['code']) ?></strong> <?= h($c['item_name']) ?></div>
        <div class="crate-fill" title="<?= $usedPct ?>% taken out"><span style="height:<?= 100 - $usedPct ?>%"></span></div>
      </div>
      <?php $packed = (bool)DB::value("SELECT 1 FROM crate_movements WHERE crate_id = :c AND kind = 'pack' LIMIT 1", ['c' => $c['id']]);   // v4: filled from loose stock ?>
      <dl class="crate-facts">
        <div><dt>Status</dt><dd><span class="state-text state-<?= h($c['status']) ?>"><?= h(Crates::statusText($c['status'])) ?></span></dd></div>
        <div><dt>Left in the crate</dt><dd class="fig"><?= Crates::fig($c['qty_left'], $base) ?> <?= h($base) ?></dd></div>
        <div><dt><?= $packed ? 'Filled with' : 'Received with' ?></dt><dd class="fig"><?= Crates::fig($c['qty_in'], $base) ?> <?= h($base) ?><?= (float)$c['pcs'] > 0 ? ', ' . qty($c['pcs']) . ' heads' : '' ?></dd></div>
        <div><dt>Site</dt><dd><?= h($c['site_name']) ?></dd></div>
        <div><dt>Production date</dt><dd><?= h(fdate($c['production_date'])) ?: '<span class="text-muted">none</span>' ?></dd></div>
        <div><dt>Expiry date</dt><dd><?= $c['expiry_date'] ? h(fdate($c['expiry_date'])) . ' <span class="small ' . ($days < 0 ? 'text-danger' : ($days <= 3 ? 'text-warning-emphasis' : 'text-muted')) . '">' . ($days < 0 ? 'expired ' . abs($days) . ' day' . (abs($days) === 1 ? '' : 's') . ' ago' : ($days === 0 ? 'expires today' : $days . ' day' . ($days === 1 ? '' : 's') . ' left')) . '</span>' : '<span class="text-muted">none</span>' ?></dd></div>
        <div><dt><?= $packed ? 'Filled from loose stock' : 'Received' ?></dt><dd><?= h(fdate($c['received_date'])) ?><?= $c['receive_txn_id'] ? ' on ' . Txn::link((int)$c['receive_txn_id']) : ($packed ? ' on Convert Kilos to Crates' : '') ?></dd></div>
        <div><dt>Supplier</dt><dd><?= h((string)$c['vendor_name']) ?: '<span class="text-muted">none</span>' ?></dd></div>
        <?php if (Access::viewCosts()): ?><div><dt>Cost per <?= h($base) ?></dt><dd class="fig"><?= money($c['unit_cost']) ?></dd></div><?php endif; ?>
        <?php if ($c['status'] === 'converted'): ?><div><dt>Converted</dt><dd><?= h(fdatetime($c['converted_at'])) ?> by <?= h((string)$c['converted_name']) ?><?= $c['convert_note'] ? '<div class="small text-muted">' . h($c['convert_note']) . '</div>' : '' ?></dd></div><?php endif; ?>
      </dl>
    </div>
    <div class="card"><div class="card-header">History of the crate</div><div class="table-responsive"><table class="table table-sm mb-0">
      <thead><tr><th>Date</th><th>What happened</th><th>Document</th><th>Customer / site</th><th class="num"><?= h($base) ?></th><th class="num">Left after</th><th>By</th></tr></thead>
      <tbody>
      <?php $left = 0.0; foreach ($moves as $m):
          if ($m['kind'] === 'receive' || $m['kind'] === 'pack') { $left += (float)$m['qty']; } elseif (in_array($m['kind'], Crates::TAKE_KINDS, true)) { $left -= (float)$m['qty']; } ?>
        <tr class="move-<?= h($m['kind']) ?>">
          <td><?= h(fdate($m['move_date'])) ?></td>
          <td><?= h(Crates::kindText($m['kind'])) ?><?= in_array($m['kind'], ['sale', 'shrink', 'shortage'], true) || ($m['kind'] === 'adjust' && (float)$m['qty'] > 0) ? ((int)$m['whole'] ? ', the whole crate' : ($m['kind'] === 'adjust' ? ', down' : ', part of it')) : ($m['kind'] === 'adjust' ? ', up' : '') ?><?= $m['note'] ? '<div class="small text-muted">' . h($m['note']) . '</div>' : '' ?></td>
          <td><?= $m['txn_id'] ? Txn::link((int)$m['txn_id']) : '' ?></td>
          <td><?= $m['kind'] === 'transfer' ? h($m['site_name'] . ' to ' . $m['site2_name']) : h((string)($m['customer_name'] ?: $m['site_name'])) ?></td>
          <td class="num"><?= Crates::signedFig($m, $base) ?></td>
          <td class="num"><?= Crates::fig(max(0, $left), $base) ?></td>
          <td class="small"><?= h((string)$m['user_name']) ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody></table></div></div>
    <?php
    layout_end();
    return;
}

// ------------------------------------------------------------------ the list
$siteId = gint('site_id');
$itemId = gint('item_id');
$status = (string)g('status', 'open');
$q = trim((string)g('q'));
$within = (string)g('within');
$where = ['1 = 1'];
$params = [];
if ($siteId) {
    $where[] = 'c.site_id = :s';
    $params['s'] = $siteId;
}
if ($itemId) {
    $where[] = 'c.item_id = :i';
    $params['i'] = $itemId;
}
if (in_array($status, ['open', 'sold', 'converted', 'used'], true)) {
    $where[] = 'c.status = :st';
    $params['st'] = $status;
}
if ($q !== '') {
    $where[] = 'c.crate_no LIKE :q';
    $params['q'] = $q . '%';
}
if ($within === '0') {
    $where[] = 'c.expiry_date IS NOT NULL AND c.expiry_date < :lim';
    $params['lim'] = today();
} elseif ($within !== '' && ctype_digit($within)) {
    $where[] = 'c.expiry_date IS NOT NULL AND c.expiry_date <= :lim';
    $params['lim'] = date('Y-m-d', strtotime('+' . (int)$within . ' days'));
}
[$sf, $sp] = Access::siteFilter('c.site_id', 'cc');
$crates = DB::all(
    "SELECT c.*, i.code, i.name AS item_name, s.name AS site_name, v.name AS vendor_name, us.base_unit
       FROM crates c JOIN items i ON i.id = c.item_id JOIN sites s ON s.id = c.site_id LEFT JOIN vendors v ON v.id = c.vendor_id
       LEFT JOIN uom_sets us ON us.id = i.uom_set_id
      WHERE " . implode(' AND ', $where) . $sf . '
      ORDER BY i.code, s.name, (c.expiry_date IS NULL), c.expiry_date, c.received_date, c.id LIMIT 2000',
    $params + $sp
);
// the totals by item and site
$byItem = [];
foreach ($crates as $c) {
    $k = $c['item_id'] . ':' . $c['site_id'];
    $byItem[$k] ??= ['code' => $c['code'], 'name' => $c['item_name'], 'site' => $c['site_name'], 'base' => $c['base_unit'] ?: 'kg', 'n' => 0, 'left' => 0.0, 'pcs' => 0.0, 'exp' => null,
        'item_id' => (int)$c['item_id'], 'site_id' => (int)$c['site_id']];
    $byItem[$k]['n']++;
    $byItem[$k]['left'] += (float)$c['qty_left'];
    $byItem[$k]['pcs'] += (float)$c['pcs'];
    if ($c['expiry_date'] && ($byItem[$k]['exp'] === null || $c['expiry_date'] < $byItem[$k]['exp'])) {
        $byItem[$k]['exp'] = $c['expiry_date'];
    }
}
$itemOpts = DB::pairs("SELECT DISTINCT i.id, CONCAT(i.code, ' - ', i.name) FROM items i JOIN crates c ON c.item_id = i.id ORDER BY i.code");
$canConvert = Access::can('inv.crate_convert', 'create');
$canMove = Access::can('inv.crate_move', 'create');
$totalByBase = [];
foreach ($byItem as $b) {
    $totalByBase[$b['base']] = ($totalByBase[$b['base']] ?? 0) + $b['left'];
}
$totalText = implode(', ', array_map(fn($u, $v) => Crates::fig($v, $u) . ' ' . $u, array_keys($totalByBase), $totalByBase));

layout_start('Crate Center', ['actions' => page_link('inv.crate_convert', [], 'Convert crates to kilos', 'btn-outline-secondary', 'arrow-left-right', 'create')
    . ' ' . page_link('inv.crate_move', [], 'Move crates', 'btn-outline-secondary', 'truck-flatbed', 'create')
    . ' ' . page_link('rpt.crates_on_hand', [], 'Crates remaining report', 'btn-outline-secondary', 'bar-chart')]);
?>
<form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="row g-2 align-items-end">
    <?= select_field('site_id', 'Site', Lookup::sites(), $siteId, ['blank' => 'All sites', 'class' => 'col-6 col-md-2', 'no_add' => true]) ?>
    <?= select_field('item_id', 'Item', $itemOpts, $itemId, ['blank' => 'All items', 'class' => 'col-md-4', 'no_add' => true, 'extra' => 'data-combo']) ?>
    <?= select_field('status', 'Crates', ['open' => 'Open (on hand)', 'sold' => 'Sold out', 'used' => 'Used up (adjusted, shrinkage, shortage)', 'converted' => 'Converted to kilos', 'all' => 'All'], $status, ['class' => 'col-6 col-md-2', 'no_add' => true]) ?>
    <?= select_field('within', 'Expiring', ['3' => 'Within 3 days', '7' => 'Within 7 days', '15' => 'Within 15 days', '30' => 'Within 30 days', '0' => 'Expired'], $within, ['blank' => 'Any date', 'class' => 'col-6 col-md-2', 'no_add' => true]) ?>
    <?= input_field('q', 'Crate no.', $q, ['class' => 'col-6 col-md-1']) ?>
    <div class="col-6 col-md-1"><button class="btn btn-sm btn-outline-primary w-100">Show</button></div>
  </div>
</form>

<?php if (count($byItem) > 8): ?>
<div class="card mb-3"><div class="card-header d-flex justify-content-between"><span>Crates by item and site</span><span class="small text-muted"><?= count($byItem) ?> lines</span></div>
  <div class="crate-sumtable"><table class="table table-sm table-hover mb-0">
    <thead><tr><th>Item</th><th>Site</th><th class="num">Crates</th><th class="num">In them</th><th class="num">Average per crate</th><th>Earliest expiry</th></tr></thead>
    <tbody>
    <?php foreach ($byItem as $b): ?>
      <tr><td><a href="<?= h(url($pageKey, ['item_id' => $b['item_id'], 'site_id' => $b['site_id'], 'status' => $status])) ?>"><strong><?= h($b['code']) ?></strong></a> <span class="small text-muted"><?= h($b['name']) ?></span></td>
        <td><?= h($b['site']) ?></td><td class="num n"><?= (int)$b['n'] ?></td><td class="num"><?= Crates::fig($b['left'], $b['base']) ?> <?= h($b['base']) ?></td>
        <td class="num"><?= $b['n'] ? Crates::fig($b['left'] / $b['n'], $b['base']) : '' ?></td><td><?= h(fdate($b['exp'])) ?></td></tr>
    <?php endforeach; ?>
    </tbody></table></div></div>
<?php elseif ($byItem): ?>
<div class="crate-summary mb-3">
  <?php foreach ($byItem as $b): ?>
    <a class="crate-sum" href="<?= h(url($pageKey, ['item_id' => $b['item_id'], 'site_id' => $b['site_id'], 'status' => $status])) ?>">
      <span class="crate-sum-name"><strong><?= h($b['code']) ?></strong> <?= h($b['name']) ?></span>
      <span class="crate-sum-site"><?= h($b['site']) ?></span>
      <span class="crate-sum-fig"><span class="n"><?= (int)$b['n'] ?></span> crate<?= $b['n'] === 1 ? '' : 's' ?></span>
      <span class="crate-sum-fig"><span class="n"><?= Crates::fig($b['left'], $b['base']) ?></span> <?= h($b['base']) ?></span>
      <span class="crate-sum-exp"><?= $b['exp'] ? 'Earliest expiry ' . h(fdate($b['exp'])) : 'No expiry dates' ?></span>
    </a>
  <?php endforeach; ?>
</div>
<?php endif; ?>

<form method="get" id="crateForm"><input type="hidden" name="p" id="crateTarget" value="inv.crate_convert">
<div class="card">
  <div class="card-header d-flex flex-wrap gap-2 align-items-center">
    <span><?= count($crates) ?> crate<?= count($crates) === 1 ? '' : 's' ?><?= $status === 'open' && $totalText !== '' ? ': ' . h($totalText) . ' in them' : '' ?></span>
    <?php if ($status === 'open' && $crates && ($canConvert || $canMove)): ?>
    <span class="ms-auto d-flex gap-2 crate-actions">
      <?php if ($canConvert): ?><button class="btn btn-sm btn-outline-primary" data-crate-go="inv.crate_convert" disabled><i class="bi bi-arrow-left-right"></i> Convert ticked to kilos</button><?php endif; ?>
      <?php if ($canMove): ?><button class="btn btn-sm btn-outline-primary" data-crate-go="inv.crate_move" disabled><i class="bi bi-truck-flatbed"></i> Move ticked</button><?php endif; ?>
    </span>
    <?php endif; ?>
  </div>
  <div class="table-responsive"><table class="table table-sm table-hover mb-0 crate-list">
    <thead><tr><?php if ($status === 'open'): ?><th><input type="checkbox" class="form-check-input" data-check-all="#crateForm .crate-tick" aria-label="Tick every crate"></th><?php endif; ?>
      <th>Crate no.</th><th>Item</th><th>Site</th><th class="num">Heads</th><th class="num">Received</th><th class="num">Left</th><th>Production</th><th>Expiry</th><th>Received on</th><th>Supplier</th><th>Status</th></tr></thead>
    <tbody>
    <?php foreach ($crates as $c):
        $days = $c['expiry_date'] ? (int)floor((strtotime($c['expiry_date']) - strtotime(today())) / 86400) : null;
        $pct = (float)$c['qty_in'] > 0 ? max(0, min(100, round((float)$c['qty_left'] / (float)$c['qty_in'] * 100))) : 0; ?>
      <tr>
        <?php if ($status === 'open'): ?><td><input type="checkbox" class="form-check-input crate-tick" name="ids[]" value="<?= (int)$c['id'] ?>" aria-label="Tick crate <?= h($c['crate_no']) ?>"></td><?php endif; ?>
        <td class="crate-no"><a href="<?= h(url($pageKey, ['a' => 'view', 'id' => $c['id']])) ?>"><?= h($c['crate_no']) ?></a></td>
        <td><strong><?= h($c['code']) ?></strong> <span class="text-muted small"><?= h($c['item_name']) ?></span></td>
        <td><?= h($c['site_name']) ?></td>
        <td class="num"><?= (float)$c['pcs'] > 0 ? qty($c['pcs']) : '' ?></td>
        <td class="num"><?= Crates::fig($c['qty_in'], $c['base_unit']) ?></td>
        <td class="num"><span class="left-bar" style="--pct:<?= $pct ?>%"><?= Crates::fig($c['qty_left'], $c['base_unit']) ?></span></td>
        <td><?= h(fdate($c['production_date'])) ?></td>
        <td class="<?= $days !== null && $c['status'] === 'open' ? ($days < 0 ? 'exp-past' : ($days <= 3 ? 'exp-near' : '')) : '' ?>"><?= h(fdate($c['expiry_date'])) ?></td>
        <td><?= h(fdate($c['received_date'])) ?></td>
        <td class="small"><?= h((string)$c['vendor_name']) ?></td>
        <td><span class="state-text state-<?= h($c['status']) ?>"><?= h(Crates::statusText($c['status'])) ?></span></td>
      </tr>
    <?php endforeach; ?>
    <?php if (!$crates): ?><tr><td colspan="12" class="empty-row">No crate matches. Crates are added when stock is received in crates (Receive Items, Enter Bills or Pick-Up Supplier Items).</td></tr><?php endif; ?>
    </tbody>
  </table></div>
</div>
</form>
<script>
(function () {
  const f = document.getElementById('crateForm');
  if (!f) return;
  const btns = f.querySelectorAll('[data-crate-go]');
  const sync = () => { const n = f.querySelectorAll('.crate-tick:checked').length; btns.forEach((b) => { b.disabled = n === 0; }); };
  f.addEventListener('change', sync);
  btns.forEach((b) => b.addEventListener('click', () => { document.getElementById('crateTarget').value = b.dataset.crateGo; }));
  sync();
})();
</script>
<?php
layout_end();
