<?php
declare(strict_types=1);

require_once APP_ROOT . '/modules/txn/_common.php';
require_once APP_ROOT . '/modules/txn/_grids.php';
require_once APP_ROOT . '/modules/inventory/_stockmove.php';

/**
 * Transfer Inventory between sites, and Edit Inventory Transfer (a=edit): the date, the two sites, the memo and the
 * lines of a posted transfer can be changed. Saving posts it again (stock leaves and arrives at the new sites and
 * quantities, the value moves at average cost) and the before and after, with the reason, go to the audit trail.
 */

$pageKey = 'inv.transfers';
if (txn_common_actions($pageKey, ['inventory_transfer'])) {
    return;
}
$a = g('a', 'list');
if ($a === 'list') {
    render_txn_list($pageKey, ['inventory_transfer'], 'Inventory Transfers', ['statuses' => ['open' => 'Posted', 'void' => 'Void'], 'new_label' => 'New transfer', 'site_cols' => true]);
    return;
}
$edit = null;
if ($a === 'edit') {
    Access::require($pageKey, 'edit');
    $edit = Txn::load(gint('id') ?? 0);
    if (!$edit || $edit['txn_type'] !== 'inventory_transfer') {
        flash('warning', 'Transfer not found.');
        redirect(url($pageKey));
    }
    if ((int)$edit['is_voided'] === 1) {
        flash('warning', 'A voided transfer cannot be edited.');
        redirect(Txn::url($edit));
    }
    if (!Access::siteAllowed($edit['site_id'] ? (int)$edit['site_id'] : null)) {
        Access::denyPage($pageKey, 'edit a transfer of another site on');
    }
    // v2: crates moved with the transfer are at the other site now: such a transfer is voided and recorded again
    if (Crates::ready() && DB::value("SELECT 1 FROM crate_movements WHERE txn_id = :t AND kind = 'transfer' LIMIT 1", ['t' => $edit['id']])) {
        flash('warning', Txn::ref($edit) . ' moved crates to ' . (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => $edit['site2_id']])
            . '. A transfer of crates is not edited: void it (the crates go back) and record it again.');
        redirect(Txn::url($edit));
    }
} else {
    Access::require($pageKey, 'create');
}
$items = Lookup::itemPairs("is_active = 1 AND item_type IN ('inventory','assembly')");
// an item already on the transfer stays on the list even if it was made inactive since
$editLines = $edit ? array_values(array_filter(Txn::lines((int)$edit['id']), fn($l) => !empty($l['item_id']))) : [];
foreach ($editLines as $l) {
    if (!isset($items[(int)$l['item_id']]) && ($it = item_cache((int)$l['item_id']))) {
        $items[(int)$it['id']] = $it['code'] . ' ' . $it['name'];
    }
}
$sites = Lookup::sites();

/** What this transfer itself took out of a site, by item (added back to what is available when it is edited) */
$ownOut = function (?array $edit, int $siteId): array {
    $out = [];
    if ($edit && (int)$edit['site_id'] === $siteId) {
        foreach (Txn::lines((int)$edit['id']) as $l) {
            if ($l['item_id']) {
                $out[(int)$l['item_id']] = ($out[(int)$l['item_id']] ?? 0.0) + (float)$l['qty'];
            }
        }
    }
    return $out;
};

handle_post(function () use ($pageKey, $edit, $ownOut) {
    $from = pint('site_id');
    $to = pint('site2_id');
    if (!$from || !$to || $from === $to) {
        fail('Choose two different sites.');
    }
    if (!Access::siteAllowed($to)) {
        fail('You are not allowed to move stock to that site.');
    }
    $lines = [];
    $own = $ownOut($edit, $from);
    $want = [];
    $wantLot = [];
    $exclude = $edit ? (int)$edit['id'] : null;
    $crated = Crates::ready() ? Crates::crateItems() : [];
    foreach ((array)($_POST['rows'] ?? []) as $r) {
        $iid = (int)($r['item_id'] ?? 0);
        if (!$iid) {
            continue;
        }
        $code = item_cache($iid)['code'];
        // v2 distribution: crates chosen on the line go to the other site whole, keeping their numbers, heads and dates:
        // one transfer line per crate (with the crate's production and expiry dates when the company keeps them)
        if (isset($crated[$iid]) && trim((string)($r['crates'] ?? '')) !== '') {
            $cr = Crates::fromRow($r, $iid, 'out', true, $code, $from, $exclude, pdate('txn_date', today()));
            foreach ($cr['rows'] ?? [] as $c) {
                $line = ['line_kind' => 'item', 'item_id' => $iid, 'qty' => (float)$c['qty'], 'description' => item_cache($iid)['name'], 'site_id' => $from,
                    'uom_id' => $crated[$iid]['unit_id'], 'unit' => $crated[$iid]['code'], 'uom_qty' => 1, 'uom_factor' => round((float)$c['qty'], 6),
                    '_crates' => ['dir' => 'move', 'rows' => [['id' => (int)$c['id']]]]];
                if (Lots::on() && Lots::itemTracked($iid)) {
                    $line['production_date'] = $c['prod'] ?: null;
                    $line['expiry_date'] = $c['exp'] ?: null;
                }
                $lines[] = $line;
            }
            continue;
        }
        // v44: an item with production and expiry dates is moved date group by date group (the sub-form under its line):
        // one line per group, each at most what the source site holds of that group
        if (Lots::on() && Lots::itemTracked($iid) && isset($r['lots']) && is_array($r['lots'])) {
            foreach ($r['lots'] as $key => $q) {
                $q = round(to_num($q), 4);
                if ($q <= 0) {
                    continue;
                }
                [$prod, $exp] = Lots::split((string)$key);
                $k = $iid . '#' . Lots::key($prod, $exp);
                $wantLot[$k] = round(($wantLot[$k] ?? 0.0) + $q, 4);
                // v5: loose stock only for an item kept in crates (its crates go by the crate)
                $have = isset($crated[$iid]) ? Lots::looseQty($iid, $from, $prod, $exp, $exclude) : Lots::qty($iid, $from, $prod, $exp, $exclude);
                if ($wantLot[$k] > $have + 0.00005) {
                    fail($code . ': only ' . qty(max(0, $have)) . ' left with ' . Lots::label($prod, $exp) . ' at the source site. Move at most that from this date group, and the rest from another.');
                }
                $lineId = (int)($r['lot_ids'][$key] ?? 0);
                $lines[] = ['id' => $lineId ?: null, 'line_kind' => 'item', 'item_id' => $iid, 'qty' => $q, 'description' => item_cache($iid)['name'], 'site_id' => $from,
                    'production_date' => $prod, 'expiry_date' => $exp];
            }
            continue;
        }
        $q = to_num($r['qty'] ?? 0);
        if ($q <= 0) {
            continue;
        }
        $want[$iid] = ($want[$iid] ?? 0.0) + $q;
        $q = $want[$iid];
        $avail = Stock::onHand($iid, $from) + ($own[$iid] ?? 0.0);
        if ($q > $avail + 0.00001 && Settings::get('allow_negative_stock') !== '1') {
            fail('Not enough stock of ' . $code . ' at the source site (' . qty($avail) . ').');
        }
        $line = ['id' => (int)($r['id'] ?? 0) ?: null, 'line_kind' => 'item', 'item_id' => $iid, 'qty' => to_num($r['qty'] ?? 0), 'description' => item_cache($iid)['name'], 'site_id' => $from];
        // a line of an item that keeps dates, posted without its date groups: first in, first out, within what the site has
        if (Lots::on() && Lots::itemTracked($iid)) {
            $line += Lots::fromRow($r, $iid, 'out', false, $code);
            if ($line['production_date'] || $line['expiry_date']) {
                Lots::checkOut($iid, $from, $line['production_date'], $line['expiry_date'], to_num($r['qty'] ?? 0), $code, $exclude, false, isset($crated[$iid]));
            }
        }
        $lines[] = $line;
    }
    $lines = array_map(function ($l) {
        if (empty($l['id'])) {
            unset($l['id']);
        }
        return $l;
    }, $lines);
    if (!$lines) {
        fail('Enter at least one item and quantity.');
    }
    // v2: stock kept in crates moves by the crate; kilos without a crate come only from the loose stock of the site
    Crates::checkLoose($lines, $from, $exclude, 'transfer');
    $h = ['txn_date' => pdate('txn_date', today()), 'site_id' => $from, 'site2_id' => $to, 'memo' => p('memo') ?: null, 'status' => 'open'];
    if ($edit) {
        $id = Txn::save('inventory_transfer', $h, $lines, (int)$edit['id'], ['reason' => trim((string)p('reason')) ?: null]);
        flash('success', Txn::ref(Txn::load($id)) . ' updated. Stock at both sites follows the new quantities.');
        redirect(url($pageKey, ['a' => 'view', 'id' => $id]));
    }
    $id = Txn::save('inventory_transfer', $h, $lines);
    flash('success', 'Transfer recorded. Quantities moved without changing total inventory value.');
    redirect_after_save(url($pageKey, ['a' => 'new']), url($pageKey, ['a' => 'view', 'id' => $id]));
});

$lotOn = Lots::on();
$lotTracked = $lotOn ? Lots::trackedIds(array_keys($items)) : [];
if (is_post()) {
    $rows = array_values((array)($_POST['rows'] ?? []));
} elseif ($edit) {
    // v44: the lines of one item come back as one line with its date groups (what each line took at the source site)
    $rows = [];
    $byItem = [];
    foreach ($editLines as $l) {
        $iid = (int)$l['item_id'];
        if (!isset($lotTracked[$iid])) {
            $rows[] = ['id' => $l['id'], 'item_id' => $iid, 'qty' => rtrim(rtrim(number_format((float)$l['qty'], 4, '.', ''), '0'), '.')];
            continue;
        }
        if (!isset($byItem[$iid])) {
            $byItem[$iid] = count($rows);
            $rows[] = ['item_id' => $iid, 'qty' => '', 'lots' => [], 'lot_ids' => []];
        }
        $k = $byItem[$iid];
        $took = DB::all('SELECT production_date AS p, expiry_date AS e, -SUM(qty) AS q FROM inventory_movements WHERE txn_line_id = :l AND site_id = :s AND qty < 0
                          GROUP BY production_date, expiry_date', ['l' => $l['id'], 's' => (int)$edit['site_id']]);
        if (!$took) {
            $took = [['p' => $l['production_date'] ?? null, 'e' => $l['expiry_date'] ?? null, 'q' => $l['qty']]];
        }
        foreach ($took as $g) {
            $key = Lots::key($g['p'] ?: null, $g['e'] ?: null);
            $rows[$k]['lots'][$key] = round(($rows[$k]['lots'][$key] ?? 0.0) + (float)$g['q'], 4);
            $rows[$k]['lot_ids'][$key] ??= (int)$l['id'];
        }
    }
} else {
    $rows = gint('item_id') ? [['item_id' => gint('item_id'), 'qty' => '']] : [];
}
$rows = $rows ?: [['item_id' => '', 'qty' => ''], ['item_id' => '', 'qty' => ''], ['item_id' => '', 'qty' => '']];
$ownNow = $ownOut($edit, (int)($edit['site_id'] ?? 0));
// v44: the production / expiry date groups at the source site, filled in under each line of an item that keeps dates
$lotSite = (int)fv('site_id', $edit, array_key_first($sites));
$lotGroups = $lotTracked ? Lots::forItems(array_filter(array_column($rows, 'item_id')), $lotSite, $edit ? (int)$edit['id'] : null, true) : [];
$lotItemsJson = json_encode((object)array_map(fn() => 1, $lotTracked));
// v2 distribution: items kept in crates get a Crates button: the crates chosen move whole to the other site
$crateItems = Crates::ready() ? Crates::crateItems(array_keys($items)) : [];
$crateOn = (bool)$crateItems;
// v4: the unit of each item, shown after its quantities (and its other units, in the quantity's tooltip)
$units = stockmove_units(array_keys($items));
$colCount = 4 + ($lotTracked ? 1 : 0) + ($crateOn ? 1 : 0);
/** The Crates cell of a line */
$crateCell = function (array $r, string $i) use ($crateItems): string {
    $iid = (int)($r['item_id'] ?? 0);
    $on = $iid && isset($crateItems[$iid]);
    return '<td class="tr-crates-cell"><input type="hidden" name="rows[' . h($i) . '][crates]" value="' . h($on ? (string)($r['crates'] ?? '') : '') . '" data-tr-crates>'
        . '<button type="button" class="btn btn-sm crate-btn" data-tr-crate-open' . ($on ? '' : ' disabled') . ' title="Choose the crates moved: they keep their numbers and dates">'
        . '<i class="bi bi-boxes"></i><span data-crate-label>Crates</span></button></td>';
};
/** The sub-form of a line: one row per date group the source site holds, with the quantity to move from it */
$lotBox = function (array $r, string $i) use ($lotTracked, $lotGroups, $colCount): string {
    $iid = (int)($r['item_id'] ?? 0);
    $on = $iid && isset($lotTracked[$iid]);
    $html = '<tr class="tr-lots"' . ($on ? '' : ' hidden') . '><td colspan="' . $colCount . '"><div class="tr-lotbox">';
    if ($on) {
        $html .= tr_lot_table($lotGroups[$iid] ?? [], (array)($r['lots'] ?? []), (array)($r['lot_ids'] ?? []), $i);
    }
    return $html . '</div></td></tr>';
};
layout_start($edit ? 'Edit Inventory Transfer ' . $edit['txn_no'] : 'Transfer Inventory', ['js' => ['js/qtytip.js'], 'actions' => $edit
    ? btn_link(Txn::url($edit), 'Cancel', 'btn-outline-secondary')
    : btn_link(url($pageKey), 'Transfers list') . (Access::can('inv.dispatch', 'create') ? ' ' . page_link('inv.dispatch', ['a' => 'new'], 'Dispatch Inventory', 'btn-outline-secondary', 'truck', 'create') : '')]);
?>
<?php if ($edit): ?>
<p class="text-muted small">Saving moves the stock again: the quantities this transfer moved go back to <?= h($sites[(int)$edit['site_id']] ?? 'the source site') ?>, then the new lines leave the source site and arrive at the destination. "On hand at source" counts what this transfer took from the site it moved from.</p>
<?php endif; ?>
<form method="post"><?= csrf_field() ?><?= negative_stock_fields() ?>
<div class="card mb-3"><div class="card-body row g-2">
  <?= input_field('txn_date', 'Date', fv('txn_date', $edit, today()), ['type' => 'date', 'class' => 'col-md-2']) ?>
  <?= select_field('site_id', 'From site', $sites, fv('site_id', $edit, array_key_first($sites)), ['class' => 'col-md-3', 'extra' => 'id="fromSite"']) ?>
  <?= select_field('site2_id', 'To site', Lookup::sites(false), fv('site2_id', $edit), ['class' => 'col-md-3', 'blank' => '— choose —']) ?>
  <?= input_field('memo', 'Memo', fv('memo', $edit), ['class' => Classes::ready() ? 'col-md-2' : 'col-md-4']) ?>
  <?= Classes::field(fv('class_id', $edit), 'col-md-2') ?>
  <?php if ($edit): ?><?= input_field('reason', 'Reason for the change', fv('reason'), ['class' => 'col-12', 'extra' => 'maxlength="255" placeholder="Recorded in the audit trail"']) ?><?php endif; ?>
</div></div>
<div class="card card-body mb-3">
  <div class="table-responsive"><table class="table table-sm tr-table<?= $crateOn ? ' tr-has-crates' : '' ?>" id="trTable"<?= $lotTracked ? ' data-lots-url="' . h(url('api.lots')) . '" data-items="' . h($lotItemsJson) . '"' . ($edit ? ' data-lots-txn="' . (int)$edit['id'] . '"' : '') : '' ?>>
    <thead><tr><th>Item</th><th class="num">On hand at source</th><?= $lotTracked ? '<th class="tr-lotsum-h">Production / expiry date</th>' : '' ?><th class="num">Qty to move</th><?= $crateOn ? '<th>Crates</th>' : '' ?><th></th></tr></thead><tbody>
  <?php foreach ($rows as $i => $r): $iid = (int)($r['item_id'] ?? 0); $dated = $iid && isset($lotTracked[$iid]);
      $sum = $dated ? array_sum(array_map('to_num', (array)($r['lots'] ?? []))) : 0.0; ?>
    <tr class="tr-main<?= $dated ? ' has-lots' : '' ?>"><td><?php if (!empty($r['id'])): ?><input type="hidden" name="rows[<?= $i ?>][id]" value="<?= (int)$r['id'] ?>"><?php endif; ?><select class="form-select form-select-sm tr-item" data-f="item_id" name="rows[<?= $i ?>][item_id]" aria-label="Item"><?= options($items, $r['item_id'], '') ?></select></td>
      <td class="num tr-avail"></td><?= $lotTracked ? '<td class="tr-lotsum">' . ($dated ? tr_lot_summary($lotGroups[$iid] ?? []) : '') . '</td>' : '' ?>
      <td><div class="input-group input-group-sm qty-unit-group"><input class="form-control text-end tr-qty" name="rows[<?= $i ?>][qty]" value="<?= h($dated ? ($sum > 0 ? rtrim(rtrim(number_format($sum, 4, '.', ''), '0'), '.') : '') : ($r['qty'] ?? '')) ?>" inputmode="decimal" placeholder="Qty to move" aria-label="Qty to move"<?= $dated ? ' readonly tabindex="-1" title="The total of the date groups below"' : '' ?>><span class="input-group-text tr-unit"><?= h($iid ? ($units[$iid]['base'] ?? '') : '') ?: 'unit' ?></span></div></td>
      <?= $crateOn ? $crateCell($r, (string)$i) : '' ?>
      <td class="grid-acts"><button type="button" class="btn btn-sm btn-link p-0 grid-ins tr-ins" title="Insert a line above this one" aria-label="Insert a line above"><i class="bi bi-plus-square"></i></button><button type="button" class="btn btn-sm btn-link text-danger p-0 tr-del" aria-label="Remove the line"><i class="bi bi-x-lg"></i></button></td></tr>
    <?= $lotTracked ? $lotBox($r, (string)$i) : '' ?>
  <?php endforeach; ?>
  </tbody></table></div>
  <template id="trTpl"><tr class="tr-main"><td><select class="form-select form-select-sm tr-item" data-f="item_id" name="rows[__i__][item_id]" aria-label="Item"><?= options($items, null, '') ?></select></td><td class="num tr-avail"></td><?= $lotTracked ? '<td class="tr-lotsum"></td>' : '' ?><td><div class="input-group input-group-sm qty-unit-group"><input class="form-control text-end tr-qty" name="rows[__i__][qty]" inputmode="decimal" placeholder="Qty to move" aria-label="Qty to move"><span class="input-group-text tr-unit">unit</span></div></td><?= $crateOn ? $crateCell([], '__i__') : '' ?><td class="grid-acts"><button type="button" class="btn btn-sm btn-link p-0 grid-ins tr-ins" title="Insert a line above this one" aria-label="Insert a line above"><i class="bi bi-plus-square"></i></button><button type="button" class="btn btn-sm btn-link text-danger p-0 tr-del" aria-label="Remove the line"><i class="bi bi-x-lg"></i></button></td></tr><?= $lotTracked ? '<tr class="tr-lots" hidden><td colspan="' . $colCount . '"><div class="tr-lotbox"></div></td></tr>' : '' ?></template>
  <div class="grid-add"><?php foreach ([1 => 'Add line', 5 => 'Add 5 lines', 10 => 'Add 10 lines'] as $n => $lbl): ?><button type="button" class="btn btn-sm btn-outline-secondary tr-add" data-count="<?= $n ?>"><i class="bi bi-plus"></i> <?= h($lbl) ?></button><?php endforeach; ?></div>
</div>
<?php if ($edit): ?>
  <div class="d-flex flex-wrap gap-2"><button class="btn btn-primary"><i class="bi bi-check2"></i> Save changes</button><?= btn_link(Txn::url($edit), 'Cancel', 'btn-outline-secondary') ?></div>
<?php else: ?>
<?= save_buttons('Record transfer', url($pageKey), Access::can($pageKey, 'create')) ?>
<?php endif; ?>
<?php if ($crateOn): ?><p class="small text-muted mt-2 mb-0"><i class="bi bi-boxes"></i> Items kept in crates move by the crate: press <strong>Crates</strong> on the line and tick the crates going to the outlet or van store. They arrive with their numbers, heads, weights and dates, and are followed there as before. Kilos without a crate can only come from the loose stock of the site.</p><?php endif; ?>
</form>
<?= $crateOn ? crates_script_tag() : '' ?>
<script>
(function () {
  const lookup = <?= json_encode(url('api.lookup', ['what' => 'stock'])) ?>;
  // on an edit, what the transfer itself took from its source site is counted as available there
  const own = <?= json_encode((object)$ownNow) ?>, ownSite = <?= json_encode((string)($edit['site_id'] ?? '')) ?>;
  const table = document.getElementById('trTable');
  const tbody = table.querySelector('tbody');
  const fromSite = document.getElementById('fromSite');
  // v44: items with production and expiry dates: their date groups at the source site, in a sub-form under the line
  let dated = {};
  try { dated = JSON.parse(table.dataset.items || '{}'); } catch (e) { dated = {}; }
  const lotsUrl = table.dataset.lotsUrl || '';
  const num = (v) => { const n = parseFloat(String(v || '').replace(/,/g, '')); return isFinite(n) ? n : 0; };
  const r4 = (n) => Math.round(n * 10000) / 10000;
  const fmtQ = (n) => (window.AppFmt && AppFmt.num ? AppFmt.num(n) : String(r4(n)));
  const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const subOf = (tr) => { const n = tr.nextElementSibling; return n && n.classList.contains('tr-lots') ? n : null; };
  const nameOf = (tr) => tr.querySelector('.tr-item').name.replace(/\[item_id\]$/, '');
  const date = (d) => { if (!d) return '<span class="text-muted">None</span>'; const p = d.split('-'); return p[1] + '/' + p[2] + '/' + p[0]; };

  // v4: every quantity with its unit; what it is made of (crates and loose kilos, boxes of 20) in a tooltip
  const units = <?= json_encode((object)$units) ?>;
  // qtytip.js loads at the end of the page, after this script: look it up when it is needed
  const T0 = { set() {}, figure(el, q, u) { el.textContent = q + ' ' + u; }, units() { return []; }, fig: (v) => String(v) };
  const T = { set: (...a) => (window.QtyTip || T0).set(...a), figure: (...a) => (window.QtyTip || T0).figure(...a), units: (...a) => (window.QtyTip || T0).units(...a), fig: (...a) => (window.QtyTip || T0).fig(...a) };
  const siteName = () => { const o = fromSite.options[fromSite.selectedIndex]; return o ? o.textContent.trim() : ''; };
  const refresh = (tr) => {
    const sel = tr.querySelector('.tr-item'); const out = tr.querySelector('.tr-avail');
    if (!sel.value) { out.textContent = ''; T.set(out, []); return; }
    const site = fromSite.value;
    fetch(lookup + '&item=' + sel.value + '&site=' + site).then(r => r.json()).then(d => {
      const back = site === ownSite ? (+own[sel.value] || 0) : 0;
      const unit = d.unit || (units[sel.value] && units[sel.value].base) || '';
      T.figure(out, num(d.on_hand) + back, unit);
      T.set(out, d.detail || [], 'At ' + siteName());
    }).catch(() => {});
  };
  const paintQty = (tr) => {
    const sel = tr.querySelector('.tr-item'), info = units[sel.value] || null;
    const u = tr.querySelector('.tr-unit'); if (!u) return;
    u.textContent = (info && info.base) || 'unit';
    const h = tr.querySelector('[data-tr-crates]');
    let list = []; try { list = JSON.parse((h && h.value) || '[]'); } catch (e) { list = []; }
    const base = info ? info.base : '';
    let lines, title = '';
    if (list.length) {
      title = 'In ' + list.length + (list.length === 1 ? ' crate' : ' crates');
      lines = list.slice(0, 12).map((c) => (c.no || '#') + ': ' + T.fig(c.qty, base) + ' ' + base);
      if (list.length > 12) lines.push('and ' + (list.length - 12) + ' more');
    } else {
      lines = T.units(num(tr.querySelector('.tr-qty').value), info);
    }
    T.set(tr.querySelector('.qty-unit-group'), lines, title);
  };

  // the total of the sub-form goes to the line's "Qty to move"; a group asked for more than it holds is marked
  const total = (tr) => {
    const sub = subOf(tr);
    if (!sub || sub.hidden) return;
    let sum = 0;
    sub.querySelectorAll('.tr-lot-qty').forEach((inp) => {
      const v = num(inp.value), max = num(inp.dataset.max);
      sum += v;
      const over = v > max + 0.00005;
      inp.classList.toggle('is-invalid', over);
      inp.title = over ? 'Only ' + fmtQ(max) + ' with these dates at the source site' : '';
    });
    const q = tr.querySelector('.tr-qty');
    q.value = sum > 0 ? String(r4(sum)) : '';
  };
  const summary = (groups) => {
    if (!groups.length) return '<span class="text-muted small">No stock at the source site</span>';
    const dates = groups.filter((g) => g.prod || g.exp).length;
    return '<span class="small">' + groups.length + ' date group' + (groups.length === 1 ? '' : 's') + (dates < groups.length ? ' (one without dates)' : '') + '</span><span class="tr-lotsum-hint small text-muted">Type the quantities below</span>';
  };
  const subTable = (tr, groups, keep) => {
    const n = nameOf(tr);
    if (!groups.length) return '<div class="tr-lot-empty">No stock of this item at the source site.</div>';
    return '<table class="table table-sm mb-0 tr-lot-table"><thead><tr><th>Expiry date</th><th>Production date</th><th>Status</th><th class="num">On hand</th><th class="num">Qty to move</th></tr></thead><tbody>'
      + groups.map((g) => {
        const st = !g.prod && !g.exp ? 'No dates' : (g.status === 'expired' ? 'Expired ' + Math.abs(g.days) + ' day(s) ago' : 'Expires in ' + g.days + ' day(s)');
        const cls = g.status === 'expired' ? 'lot-expired-row' : (g.status === 'expiring' ? 'lot-expiring-row' : '');
        return '<tr class="' + cls + '"><td data-label="Expiry date">' + date(g.exp) + '</td><td data-label="Production date">' + date(g.prod) + '</td><td data-label="Status" class="small">' + esc(st) + '</td>'
          + '<td data-label="On hand" class="num tr-lot-have">' + esc(fmtQ(g.qty)) + '</td>'
          + '<td data-label="Qty to move"><input class="form-control form-control-sm text-end tr-lot-qty" name="' + esc(n + '[lots][' + g.key + ']') + '" value="' + esc(keep[g.key] || '') + '" data-max="' + g.qty + '" inputmode="decimal" placeholder="0" aria-label="Quantity to move"></td></tr>';
      }).join('') + '</tbody></table>';
  };
  // the date groups of the line's item at the source site (kept quantities stay with their group)
  const loadLots = (tr) => {
    const sel = tr.querySelector('.tr-item');
    const sub = subOf(tr);
    const cell = tr.querySelector('.tr-lotsum');
    const q = tr.querySelector('.tr-qty');
    const on = !!(sel.value && dated[sel.value]);
    tr.classList.toggle('has-lots', on);
    if (!sub) return;
    if (!on) {
      sub.hidden = true; sub.querySelector('.tr-lotbox').innerHTML = '';
      if (cell) cell.innerHTML = '';
      q.readOnly = false; q.removeAttribute('tabindex'); q.title = '';
      return;
    }
    const keep = {};
    sub.querySelectorAll('.tr-lot-qty').forEach((inp) => { const m = inp.name.match(/\[lots\]\[([^\]]*)\]$/); if (m && inp.value) keep[m[1]] = inp.value; });
    q.readOnly = true; q.tabIndex = -1; q.title = 'The total of the date groups below';
    sub.hidden = false;
    const url = lotsUrl + '&item_ids=' + sel.value + '&site_id=' + encodeURIComponent(fromSite.value) + (table.dataset.lotsTxn ? '&exclude=' + table.dataset.lotsTxn : '');
    fetch(url, { credentials: 'same-origin', headers: { 'X-Background': '1' } }).then((r) => r.json()).then((j) => {
      const groups = (j.groups && j.groups[sel.value]) || [];
      sub.querySelector('.tr-lotbox').innerHTML = subTable(tr, groups, keep);
      if (cell) cell.innerHTML = summary(groups);
      total(tr);
    }).catch(() => {});
  };

  tbody.addEventListener('change', (e) => {
    if (e.target.classList.contains('tr-item')) { const tr = e.target.closest('tr'); refresh(tr); loadLots(tr); paintQty(tr); }
  });
  tbody.addEventListener('input', (e) => {
    if (e.target.classList.contains('tr-lot-qty')) { const sub = e.target.closest('tr.tr-lots'); if (sub && sub.previousElementSibling) { total(sub.previousElementSibling); paintQty(sub.previousElementSibling); } }
    if (e.target.classList.contains('tr-qty')) paintQty(e.target.closest('tr'));
  });
  fromSite.addEventListener('change', () => tbody.querySelectorAll('tr.tr-main').forEach((tr) => { refresh(tr); if (tr.classList.contains('has-lots')) loadLots(tr); }));
  let seq = 0;
  const newRow = (before) => {
    const tmp = document.createElement('tbody');
    tmp.innerHTML = document.getElementById('trTpl').innerHTML.replace(/__i__/g, 'n' + Date.now() + '_' + (seq++)).trim();
    const rows = Array.prototype.slice.call(tmp.children);
    rows.forEach((r) => { if (before) tbody.insertBefore(r, before); else tbody.appendChild(r); });
    if (window.AppCombo) window.AppCombo.init(rows[0]);
    return rows[0];
  };
  document.querySelectorAll('.tr-add').forEach((b) => b.addEventListener('click', () => { for (let i = 0; i < (+b.dataset.count || 1); i++) newRow(); }));
  tbody.addEventListener('click', (e) => {
    const ins = e.target.closest('.tr-ins'); if (ins) { newRow(ins.closest('tr')); return; }
    const del = e.target.closest('.tr-del');
    if (del) { const tr = del.closest('tr'); const sub = subOf(tr); if (sub) sub.remove(); tr.remove(); }
  });
  tbody.querySelectorAll('tr.tr-main').forEach((tr) => { refresh(tr); total(tr); });
  // the tooltips once Bootstrap and qtytip.js are there
  const paintAll = () => tbody.querySelectorAll('tr.tr-main').forEach((tr) => paintQty(tr));
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', paintAll); else paintAll();

  // v2 distribution: the crates of a line (items kept in crates): chosen in the crate window, moved whole
  const crateItems = <?= json_encode((object)$crateItems) ?>;
  const cratesUrl = <?= json_encode(url('api.crates')) ?>;
  const parseC = (v) => { try { const x = JSON.parse(v || '[]'); return Array.isArray(x) ? x : []; } catch (e) { return []; } };
  const paintC = (tr) => {
    const hid = tr.querySelector('[data-tr-crates]'), btn = tr.querySelector('[data-tr-crate-open]');
    if (!hid || !btn) return;
    const sel = tr.querySelector('.tr-item'), it = crateItems[sel.value];
    btn.disabled = !it;
    if (!it && hid.value) hid.value = '';
    const list = parseC(hid.value), q = tr.querySelector('.tr-qty');
    const lbl = btn.querySelector('[data-crate-label]');
    btn.classList.toggle('has-crates', list.length > 0);
    lbl.textContent = list.length ? list.length + (list.length === 1 ? ' crate' : ' crates') : 'Crates';
    if (list.length) {
      const kg = list.reduce((a, c) => a + num(c.qty), 0);
      q.value = String(r4(kg)); q.readOnly = true; q.classList.add('qty-from-crates'); q.title = 'The total of the crates: press Crates to change it';
      const sub = subOf(tr); if (sub) sub.hidden = true;
    } else if (q.classList.contains('qty-from-crates')) {
      q.readOnly = tr.classList.contains('has-lots'); q.classList.remove('qty-from-crates'); q.title = ''; q.value = '';
      const sub = subOf(tr); if (sub && tr.classList.contains('has-lots')) sub.hidden = false;
    }
    paintQty(tr);
  };
  const openC = (tr) => {
    const sel = tr.querySelector('.tr-item'), it = crateItems[sel.value], hid = tr.querySelector('[data-tr-crates]');
    if (!it || !window.CrateWindow) return;
    const opt = sel.options[sel.selectedIndex];
    fetch(cratesUrl + '&item_id=' + encodeURIComponent(sel.value) + '&site_id=' + encodeURIComponent(fromSite.value), { credentials: 'same-origin' }).then((r) => r.json()).then((d) => {
      if (d.error) { alert(d.error); return; }
      window.CrateWindow.open({ dir: 'out', whole: true, title: opt ? opt.textContent : 'Crates', base: d.base || it.base || 'kg', crates: d.crates || [], loose: d.loose, value: hid.value,
        sub: 'Choose the crates moved from ' + (d.site || 'the source site') + ', or type a crate\'s weight in Find figure. Each crate goes whole, with its number and dates.',
        onSave: (list) => { hid.value = list.length ? JSON.stringify(list) : ''; paintC(tr); } });
    }).catch(() => alert('The open crates could not be loaded. Check the connection and try again.'));
  };
  tbody.addEventListener('click', (e) => { const b = e.target.closest('[data-tr-crate-open]'); if (b && !b.disabled) openC(b.closest('tr')); });
  tbody.addEventListener('change', (e) => {
    if (!e.target.classList.contains('tr-item')) return;
    const tr = e.target.closest('tr'), hid = tr.querySelector('[data-tr-crates]');
    if (hid) { hid.value = ''; const q = tr.querySelector('.tr-qty'); q.classList.remove('qty-from-crates'); q.readOnly = false; }
    paintC(tr);
  });
  fromSite.addEventListener('change', () => tbody.querySelectorAll('tr.tr-main').forEach((tr) => { const h = tr.querySelector('[data-tr-crates]'); if (h && h.value) { h.value = ''; paintC(tr); } }));
  tbody.querySelectorAll('tr.tr-main').forEach(paintC);
})();
</script>
<?php
layout_end();
