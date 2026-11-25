<?php
declare(strict_types=1);

/**
 * v5: Inventory > Production and Expiry Dates.
 *
 * For every item that keeps production and expiry dates, by site: how much of the stock has dates, how much has none
 * and which documents brought it in without them (and why), and whether the stock of each date group agrees with
 * what its open crates hold. Two fixes, each recorded as a date change (an inventory adjustment that moves a quantity
 * from one date group to another at the same site, at the same value; nothing is posted to the books):
 *  - Give dates: loose stock without dates gets the production and expiry dates typed;
 *  - Put in agreement with the crates: each date group gets what its crates hold, from the loose stock of the others
 *    (the group without dates first).
 * Both are voided like any adjustment, which takes the change back.
 */
$pageKey = 'inv.lot_check';
$sites = Lookup::sites();
$siteId = gint('site_id');
if ($siteId && !isset($sites[$siteId])) {
    $siteId = null;
}
$search = trim((string)g('q'));
$showAll = g('show') === 'all';

handle_post(function () use ($pageKey) {
    Access::require($pageKey, 'create');
    if (!Lots::on()) {
        fail('Production and expiry dates are not kept: switch on date tracking first.');
    }
    $date = pdate('change_date') ?: today();
    $back = url($pageKey, array_filter(['site_id' => pint('back_site') ?: null, 'q' => p('back_q') ?: null, 'show' => p('back_show') ?: null]));
    $a = (string)p('do');
    if ($a === 'give') {
        $itemId = pint('item_id');
        $siteId = pint('site_id');
        if (!$itemId || !$siteId) {
            fail('Choose the item and the site.');
        }
        $code = (string)(DB::value('SELECT code FROM items WHERE id = :i', ['i' => $itemId]) ?: 'The item');
        if (!Lots::itemTracked($itemId)) {
            fail($code . ' does not keep production and expiry dates (it is marked as not expiring on the Item List).');
        }
        $have = Lots::looseQty($itemId, $siteId, null, null);
        $q = round(pnum('qty'), 4);
        if ($q <= Crates::EPS) {
            fail('Type the quantity that gets the dates.');
        }
        if ($q > $have + Crates::EPS) {
            fail($code . ' has ' . qty(max(0, $have)) . ' without dates at this site' . (Crates::crateUnit($itemId) ? ' outside its crates' : '') . '; dates can be given to that much at most.');
        }
        $prod = Lots::date(p('production_date'), 'production date');
        $exp = Lots::date(p('expiry_date'), 'expiry date');
        Lots::check($prod, $exp, $code, true, $date);
        $note = trim((string)p('note'));
        $id = LotCheck::changeDates($siteId, $date, [['item_id' => $itemId, 'qty' => $q, 'from' => [null, null], 'to' => [$prod, $exp]]],
            'Production and expiry dates given to ' . $code . ($note !== '' ? ' - ' . $note : ''), 'Dates given to stock that had none');
        flash('success', qty($q) . ' of ' . $code . ' now carries ' . Lots::label($prod, $exp) . ', on ' . Txn::ref(Txn::load($id)) . '. Void that adjustment to take it back.');
        redirect($back);
    }
    if ($a === 'align') {
        $itemId = pint('item_id') ?: null;
        $siteId = pint('site_id') ?: null;
        $rows = array_values(array_filter(LotCheck::overview($siteId, $itemId), fn($r) => $r['deficit'] > Crates::EPS));
        if (!$rows) {
            fail('The stock already agrees with its crates.');
        }
        $ids = LotCheck::align($rows, $date);
        $refs = implode(', ', array_map(fn($id) => Txn::ref(Txn::load($id)), $ids));
        flash('success', count($rows) . ' item' . (count($rows) === 1 ? '' : 's') . ' put in agreement with their crates, on ' . $refs . '.');
        redirect($back);
    }
    fail('Choose what to do.');
});

$on = Lots::on();
$rows = $on ? LotCheck::overview($siteId, null, $showAll, $search) : [];
$toCheck = array_values(array_filter($rows, fn($r) => !$r['ok']));
$undatedItems = count(array_filter($rows, fn($r) => $r['undated'] > Crates::EPS));
$offItems = count(array_filter($rows, fn($r) => $r['deficit'] > Crates::EPS));
$canFix = Access::can($pageKey, 'create');
$backFields = '<input type="hidden" name="back_site" value="' . (int)$siteId . '"><input type="hidden" name="back_q" value="' . h($search) . '"><input type="hidden" name="back_show" value="' . ($showAll ? 'all' : '') . '">';
$fig = fn($q, string $u): string => '<span class="qty-fig">' . Crates::fig((float)$q, $u ?: 'kg') . '</span> <span class="qty-unit">' . h($u) . '</span>';

layout_start('Production and Expiry Dates', ['actions' => page_link('inv.adjust', [], 'Adjustments', 'btn-outline-secondary', 'sliders')
    . ' ' . page_link('inv.crates', [], 'Crate Center', 'btn-outline-secondary', 'boxes')]);
?>
<p class="text-muted small page-lead">Every item that keeps production and expiry dates, site by site: how much of its stock has dates, how much has none and which documents
  brought that in, and whether each date group holds what its crates hold. A change of dates made here is an inventory adjustment that moves the quantity from one
  date group to another at the same value, so nothing is posted to the books; void it to take it back.</p>

<?php if (!$on): ?>
<div class="card lc-off"><div class="card-body">
  <h2 class="h6 mb-1">Production and expiry dates are not kept</h2>
  <p class="mb-2 small text-muted">Date tracking is switched off, so no stock carries dates and there is nothing to check. Switch on <strong>Track inventory production date and expiry date</strong> under Inventory and POS.</p>
  <?= page_link('admin.settings', [], 'Company, Security & Closing Date', 'btn-outline-primary btn-sm', 'gear') ?>
</div></div>
<?php layout_end(); return; endif; ?>

<form method="get" class="filter-bar mb-3"><input type="hidden" name="p" value="<?= h($pageKey) ?>">
  <div class="row g-2 align-items-end">
    <?= select_field('site_id', 'Site', $sites, $siteId, ['class' => 'col-6 col-md-3', 'blank' => 'All sites', 'no_add' => true, 'extra' => 'data-autosubmit']) ?>
    <?= input_field('q', 'Item', $search, ['class' => 'col-6 col-md-3', 'extra' => 'placeholder="Code or name"']) ?>
    <?= select_field('show', 'Show', ['' => 'Items to check', 'all' => 'Every item that keeps dates'], $showAll ? 'all' : '', ['class' => 'col-8 col-md-3', 'no_add' => true, 'extra' => 'data-autosubmit']) ?>
    <div class="col-4 col-md-auto"><button class="btn btn-sm btn-outline-secondary w-100"><i class="bi bi-search"></i> Show</button></div>
  </div>
</form>

<div class="lc-summary card mb-3"><div class="card-body d-flex flex-wrap align-items-center gap-3">
  <div class="lc-summary-text">
    <?php if (!$toCheck): ?>
      <strong>Every item <?= $showAll ? 'listed' : 'that keeps dates' ?> is in order.</strong>
      <span class="text-muted small d-block">All its stock carries production and expiry dates, and each date group holds what its crates hold.</span>
    <?php else: ?>
      <strong><?= count($toCheck) ?> item<?= count($toCheck) === 1 ? '' : 's' ?> to check<?= $siteId ? ' at ' . h($sites[$siteId]) : '' ?>.</strong>
      <span class="text-muted small d-block"><?= $undatedItems ?> with stock that has no dates<?= $offItems ? '; ' . $offItems . ' with crates whose dates the stock does not carry' : '' ?>.</span>
    <?php endif; ?>
  </div>
  <?php if ($canFix && $offItems): ?>
  <form method="post" class="ms-md-auto"><?= csrf_field() ?><?= $backFields ?><input type="hidden" name="do" value="align"><input type="hidden" name="site_id" value="<?= (int)$siteId ?>">
    <button class="btn btn-primary btn-sm" data-confirm="Put the stock of every item listed in agreement with its crates? One date change is recorded for each site."><i class="bi bi-arrow-repeat"></i> Put all in agreement with their crates</button>
  </form>
  <?php endif; ?>
</div></div>

<div class="lc-list">
<?php foreach ($rows as $i => $r): $u = $r['unit'] ?: 'kg'; $state = $r['deficit'] > Crates::EPS ? 'is-off' : ($r['undated'] > Crates::EPS ? 'is-undated' : 'is-ok'); ?>
  <article class="card lc-item <?= $state ?>">
    <div class="card-body">
      <div class="lc-head">
        <div class="lc-title"><strong><?= h($r['code']) ?></strong> <span class="lc-name"><?= h($r['name']) ?></span>
          <span class="lc-site"><i class="bi bi-geo-alt"></i> <?= h($r['site']) ?></span></div>
        <div class="lc-state">
          <?php if ($r['deficit'] > Crates::EPS): ?><span class="lc-flag lc-flag-off"><i class="bi bi-exclamation-triangle"></i> <?= $fig($r['deficit'], $u) ?> in crates whose dates the stock does not carry</span>
          <?php elseif ($r['undated'] > Crates::EPS): ?><span class="lc-flag lc-flag-undated"><i class="bi bi-calendar-x"></i> <?= $fig($r['undated'], $u) ?> without dates</span>
          <?php else: ?><span class="lc-flag lc-flag-ok"><i class="bi bi-check2-circle"></i> In order</span><?php endif; ?>
        </div>
      </div>
      <dl class="lc-figs">
        <div><dt>On hand</dt><dd><?= $fig($r['on_hand'], $u) ?></dd></div>
        <div><dt>With dates</dt><dd><?= $fig($r['dated'], $u) ?></dd></div>
        <div class="<?= $r['undated'] > Crates::EPS ? 'lc-attn' : '' ?>"><dt>Without dates</dt><dd><?= $fig($r['undated'], $u) ?></dd></div>
        <?php if ($r['crate_item']): ?><div><dt>In crates</dt><dd><?= $fig($r['in_crates'], $u) ?></dd></div><?php endif; ?>
      </dl>
      <?php if ($canFix && ($r['undated_loose'] > Crates::EPS || $r['deficit'] > Crates::EPS)): ?>
      <div class="lc-actions">
        <?php if ($r['deficit'] > Crates::EPS): ?>
        <form method="post"><?= csrf_field() ?><?= $backFields ?><input type="hidden" name="do" value="align"><input type="hidden" name="item_id" value="<?= (int)$r['item_id'] ?>"><input type="hidden" name="site_id" value="<?= (int)$r['site_id'] ?>">
          <button class="btn btn-sm btn-primary"><i class="bi bi-arrow-repeat"></i> Put in agreement with the crates</button></form>
        <?php endif; ?>
        <?php if ($r['undated_loose'] > Crates::EPS && $r['deficit'] <= Crates::EPS): ?>
        <button type="button" class="btn btn-sm btn-outline-primary" data-lc-give data-item="<?= (int)$r['item_id'] ?>" data-site="<?= (int)$r['site_id'] ?>"
          data-title="<?= h($r['code'] . ' - ' . $r['name']) ?>" data-site-name="<?= h($r['site']) ?>" data-max="<?= h(rtrim(rtrim(number_format($r['undated_loose'], 4, '.', ''), '0'), '.')) ?>" data-unit="<?= h($u) ?>"
          data-crates="<?= $r['crate_item'] ? '1' : '' ?>"><i class="bi bi-calendar-plus"></i> Give dates</button>
        <?php endif; ?>
      </div>
      <?php endif; ?>
      <details class="lc-more"<?= count($rows) <= 3 && $state !== 'is-ok' ? ' open' : '' ?>>
        <summary>Date groups<?= $r['undated'] > Crates::EPS ? ' and where the stock without dates came from' : '' ?></summary>
        <div class="table-responsive"><table class="table table-sm lc-groups mb-2">
          <thead><tr><th>Date group</th><th class="num">Stock</th><?php if ($r['crate_item']): ?><th class="num">In crates</th><th class="num">Loose</th><?php endif; ?></tr></thead>
          <tbody>
          <?php foreach ($r['groups'] as $g): if (abs($g['stock']) <= Crates::EPS && abs($g['crates']) <= Crates::EPS) { continue; } $st = Lots::status($g['exp']); ?>
            <tr class="<?= $g['loose'] < -Crates::EPS ? 'lc-neg' : '' ?>">
              <td data-label="Date group"><?= ($g['prod'] || $g['exp']) ? h(Lots::label($g['prod'], $g['exp'])) . ($st === 'expired' ? ' <span class="lc-exp is-expired">expired</span>' : ($st === 'expiring' ? ' <span class="lc-exp is-expiring">expiring</span>' : '')) : '<em>No production or expiry date</em>' ?></td>
              <td data-label="Stock" class="num"><?= $fig($g['stock'], $u) ?></td>
              <?php if ($r['crate_item']): ?><td data-label="In crates" class="num"><?= $fig($g['crates'], $u) ?></td>
              <td data-label="Loose" class="num"><?= $fig($g['loose'], $u) ?><?= $g['loose'] < -Crates::EPS ? '<small class="d-block">the crates hold more than the stock of this group</small>' : '' ?></td><?php endif; ?>
            </tr>
          <?php endforeach; ?>
          </tbody>
        </table></div>
        <?php if ($r['undated'] > Crates::EPS): $src = LotCheck::sources($r['item_id'], $r['site_id']); ?>
        <h3 class="lc-sub">Where the stock without dates came from</h3>
        <?php if ($src): ?>
        <ul class="lc-sources">
          <?php foreach ($src as $sr): ?>
          <li><a href="<?= h($sr['url']) ?>"><?= h($sr['type'] . ' ' . ($sr['no'] ?: '#' . $sr['txn_id'])) ?></a>
            <span class="lc-src-date"><?= h(fdate($sr['date'])) ?></span>
            <span class="lc-src-qty"><?= $fig($sr['qty'], $u) ?></span>
            <span class="lc-src-why"><?= h($sr['why']) ?></span></li>
          <?php endforeach; ?>
        </ul>
        <?php else: ?><p class="small text-muted mb-0">No document at this site brought it in without dates: it is stock that went out of a dated group past what that group held.</p><?php endif; ?>
        <?php endif; ?>
      </details>
    </div>
  </article>
<?php endforeach; ?>
<?php if (!$rows): ?>
  <div class="card"><div class="card-body empty-row"><?= $search !== '' || $siteId ? 'No item matches.' : 'No item that keeps dates has stock yet.' ?></div></div>
<?php endif; ?>
</div>

<?php if ($canFix): ?>
<div class="modal fade" id="lcGive" tabindex="-1" aria-labelledby="lcGiveTitle" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-fullscreen-sm-down"><form method="post" class="modal-content"><?= csrf_field() ?><?= $backFields ?>
    <input type="hidden" name="do" value="give"><input type="hidden" name="item_id" data-lcg="item"><input type="hidden" name="site_id" data-lcg="site">
    <div class="modal-header"><div><h5 class="modal-title" id="lcGiveTitle" data-lcg="title">Give dates</h5><div class="small text-muted" data-lcg="where"></div></div>
      <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>
    <div class="modal-body">
      <p class="small text-muted" data-lcg="lead"></p>
      <div class="row g-2">
        <div class="col-12"><label class="form-label" for="lcgQty">Quantity that gets the dates</label>
          <div class="input-group input-group-sm qty-unit-group"><input class="form-control text-end" id="lcgQty" name="qty" inputmode="decimal" required data-lcg="qty"><span class="input-group-text" data-lcg="unit">kg</span></div>
          <div class="form-text" data-lcg="max"></div></div>
        <?= input_field('production_date', 'Production date', '', ['type' => 'date', 'class' => 'col-6', 'required' => true]) ?>
        <?= input_field('expiry_date', 'Expiry date', '', ['type' => 'date', 'class' => 'col-6', 'required' => true]) ?>
        <?= input_field('change_date', 'Date of the change', today(), ['type' => 'date', 'class' => 'col-6']) ?>
        <?= input_field('note', 'Note', '', ['class' => 'col-6', 'extra' => 'maxlength="150" placeholder="From the supplier\'s delivery receipt"']) ?>
      </div>
    </div>
    <div class="modal-footer"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Cancel</button>
      <button class="btn btn-primary"><i class="bi bi-calendar-check"></i> Give these dates</button></div>
  </form></div>
</div>
<script>
document.addEventListener('DOMContentLoaded', function () {
  var box = document.getElementById('lcGive');
  if (!box || !window.bootstrap) return;
  var modal = new bootstrap.Modal(box);
  var f = function (k) { return box.querySelector('[data-lcg="' + k + '"]'); };
  document.querySelectorAll('[data-lc-give]').forEach(function (b) {
    b.addEventListener('click', function () {
      f('item').value = b.dataset.item; f('site').value = b.dataset.site;
      f('title').textContent = 'Give dates: ' + b.dataset.title;
      f('where').textContent = 'At ' + b.dataset.siteName;
      f('unit').textContent = b.dataset.unit;
      f('qty').value = b.dataset.max;
      f('max').textContent = b.dataset.max + ' ' + b.dataset.unit + ' has no dates' + (b.dataset.crates ? ' outside the crates' : '') + ' here.';
      f('lead').textContent = 'The quantity moves from the stock without dates to the dates typed, at the same value. Give dates only to stock whose dates you know, for example from the supplier\'s delivery receipt.';
      box.querySelector('[name="production_date"]').value = '';
      box.querySelector('[name="expiry_date"]').value = '';
      modal.show();
    });
  });
});
</script>
<?php endif; ?>
<?php
layout_end();
