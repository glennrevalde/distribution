<?php
declare(strict_types=1);

require_once APP_ROOT . '/modules/txn/_common.php';
require_once APP_ROOT . '/modules/txn/_grids.php';
require_once APP_ROOT . '/modules/inventory/_stockmove.php';

/**
 * v4 distribution: Inventory > Dispatch Inventory.
 *
 * Stock sent from one site (the cold storage) to another (a van store, an outlet), the way Transfer Inventory moves
 * it, with these differences:
 *  - Conversion: on a line of an item kept in crates, "Kilos to Crates" (or "Packs to Sacks": whatever the item's
 *    container unit is) puts loose stock into crates as it is dispatched. The user picks the production / expiry
 *    group the kilos come from; the crate numbers follow on from the last one used (typing over a number carries on
 *    from it); each crate's weight is typed as the dispatch figure the scale shows (1330 = 13.30 kg). The quantity
 *    does not change: the kilos leave the loose stock and go on in crates, with the group's dates.
 *  - Crates already on hand are picked with Find figure (the weights that start with the digits typed) and a
 *    dispatch figure, checked against the crate's own weight (a crate goes whole).
 *  - Every quantity shows its unit, and what it is made of when the item has two or more units.
 * A dispatch posts as a transfer: no journal entry, the value moves between the sites at average cost.
 */
$pageKey = 'inv.dispatch';
$type = 'inventory_dispatch';
if (txn_common_actions($pageKey, [$type])) {
    return;
}
$a = g('a', 'list');
if ($a === 'list') {
    render_txn_list($pageKey, [$type], 'Inventory Dispatches', ['statuses' => ['open' => 'Posted', 'void' => 'Void'], 'new_label' => 'New dispatch', 'site_cols' => true]);
    return;
}
$edit = null;
if ($a === 'edit') {
    Access::require($pageKey, 'edit');
    $edit = Txn::load(gint('id') ?? 0);
    if (!$edit || $edit['txn_type'] !== $type) {
        flash('warning', 'Dispatch not found.');
        redirect(url($pageKey));
    }
    if ((int)$edit['is_voided'] === 1) {
        flash('warning', 'A voided dispatch cannot be edited.');
        redirect(Txn::url($edit));
    }
    if (!Access::siteAllowed($edit['site_id'] ? (int)$edit['site_id'] : null)) {
        Access::denyPage($pageKey, 'edit a dispatch of another site on');
    }
    // crates sent (or packed) with the dispatch are at the other site now: such a dispatch is voided and recorded again
    if (Crates::ready() && DB::value("SELECT 1 FROM crate_movements WHERE txn_id = :t AND kind IN ('transfer', 'pack') LIMIT 1", ['t' => $edit['id']])) {
        flash('warning', Txn::ref($edit) . ' sent crates to ' . (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => $edit['site2_id']])
            . '. A dispatch of crates is not edited: void it (the crates go back, and crates it packed become loose stock again) and record it again.');
        redirect(Txn::url($edit));
    }
} else {
    Access::require($pageKey, 'create');
}
$items = Lookup::itemPairs("is_active = 1 AND item_type IN ('inventory','assembly')");
$editLines = $edit ? array_values(array_filter(Txn::lines((int)$edit['id']), fn($l) => !empty($l['item_id']))) : [];
foreach ($editLines as $l) {
    if (!isset($items[(int)$l['item_id']]) && ($it = item_cache((int)$l['item_id']))) {
        $items[(int)$it['id']] = $it['code'] . ' ' . $it['name'];
    }
}
$sites = Lookup::sites();

/** What this dispatch itself took out of a site, by item (added back to what is available when it is edited) */
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

handle_post(function () use ($pageKey, $type, $edit, $ownOut) {
    $from = pint('site_id');
    $to = pint('site2_id');
    if (!$from || !$to || $from === $to) {
        fail('Choose two different sites.');
    }
    if (!Access::siteAllowed($from) || !Access::siteAllowed($to)) {
        fail('You are not allowed to move stock to or from that site.');
    }
    $date = pdate('txn_date', today());
    $lines = [];
    $looseCheck = [];   // the lines that take loose stock (crates packed from it included), for Crates::checkLoose
    $own = $ownOut($edit, $from);
    $want = [];
    $wantLot = [];
    $used = [];         // what earlier lines packed: crate numbers and kilos of each group
    $exclude = $edit ? (int)$edit['id'] : null;
    $crated = Crates::ready() ? Crates::crateItems() : [];
    foreach ((array)($_POST['rows'] ?? []) as $r) {
        $iid = (int)($r['item_id'] ?? 0);
        if (!$iid) {
            continue;
        }
        $code = item_cache($iid)['code'];
        $name = item_cache($iid)['name'];
        $lotOn = Lots::on() && Lots::itemTracked($iid);
        $conv = (string)($r['convert'] ?? '');
        // Conversion: loose kilos (packs) put into new crates, one line per crate with the group's dates
        if ($conv === 'pack') {
            if (!isset($crated[$iid])) {
                fail($code . ' has no container unit (a unit marked "weight varies" in its U/M set): it can not be put into crates.');
            }
            $pk = Crates::packRows($r, $iid, $code, $from, $exclude, $date, $used);
            if (!$pk) {
                if (to_num($r['qty'] ?? 0) > 0) {
                    fail($code . ': press ' . Crates::containerName($iid) . ' on the line and type the weight of each ' . strtolower(Crates::containerName($iid, false)) . ' filled.');
                }
                continue;
            }
            // v5: the kilos leave the source in the date group they were taken from (the line's dates), and arrive at the
            // other site in the crates' dates (the group's, or the dates typed for stock that had none)
            $fromGroup = Lots::split((string)($pk['key'] ?? '|'));
            foreach ($pk['rows'] as $c) {
                $line = ['line_kind' => 'item', 'item_id' => $iid, 'qty' => (float)$c['qty'], 'description' => $name, 'site_id' => $from,
                    'uom_id' => $crated[$iid]['unit_id'], 'unit' => $crated[$iid]['code'], 'uom_qty' => 1, 'uom_factor' => round((float)$c['qty'], 6),
                    '_crates' => ['dir' => 'pack', 'rows' => [$c], 'from' => $fromGroup]];
                if ($lotOn) {
                    $line['production_date'] = $fromGroup[0];
                    $line['expiry_date'] = $fromGroup[1];
                }
                $lines[] = $line;
                $looseCheck[] = ['item_id' => $iid, 'qty' => (float)$c['qty'], 'site_id' => $from];
            }
            continue;
        }
        // crates already on hand go whole, keeping their numbers, heads and dates (one line per crate)
        if (isset($crated[$iid]) && trim((string)($r['crates'] ?? '')) !== '') {
            $cr = Crates::fromRow($r, $iid, 'out', true, $code, $from, $exclude, $date);
            foreach ($cr['rows'] ?? [] as $c) {
                $line = ['line_kind' => 'item', 'item_id' => $iid, 'qty' => (float)$c['qty'], 'description' => $name, 'site_id' => $from,
                    'uom_id' => $crated[$iid]['unit_id'], 'unit' => $crated[$iid]['code'], 'uom_qty' => 1, 'uom_factor' => round((float)$c['qty'], 6),
                    '_crates' => ['dir' => 'move', 'rows' => [['id' => (int)$c['id']]]]];
                if ($lotOn) {
                    $line['production_date'] = $c['prod'] ?: null;
                    $line['expiry_date'] = $c['exp'] ?: null;
                }
                $lines[] = $line;
            }
            continue;
        }
        // an item with production and expiry dates is sent date group by date group (the sub-form under its line)
        if ($lotOn && isset($r['lots']) && is_array($r['lots'])) {
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
                    fail($code . ': only ' . qty(max(0, $have)) . ' left with ' . Lots::label($prod, $exp) . ' at the source site. Send at most that from this date group, and the rest from another.');
                }
                $lineId = (int)($r['lot_ids'][$key] ?? 0);
                $line = ['id' => $lineId ?: null, 'line_kind' => 'item', 'item_id' => $iid, 'qty' => $q, 'description' => $name, 'site_id' => $from,
                    'production_date' => $prod, 'expiry_date' => $exp];
                $lines[] = $line;
                $looseCheck[] = $line;
            }
            continue;
        }
        $q = to_num($r['qty'] ?? 0);
        if ($q <= 0) {
            continue;
        }
        $want[$iid] = ($want[$iid] ?? 0.0) + $q;
        $avail = Stock::onHand($iid, $from) + ($own[$iid] ?? 0.0);
        if ($want[$iid] > $avail + 0.00001 && Settings::get('allow_negative_stock') !== '1') {
            fail('Not enough stock of ' . $code . ' at the source site (' . qty($avail) . ').');
        }
        $line = ['id' => (int)($r['id'] ?? 0) ?: null, 'line_kind' => 'item', 'item_id' => $iid, 'qty' => $q, 'description' => $name, 'site_id' => $from];
        if ($lotOn) {
            $line += Lots::fromRow($r, $iid, 'out', false, $code);
            if ($line['production_date'] || $line['expiry_date']) {
                Lots::checkOut($iid, $from, $line['production_date'], $line['expiry_date'], $q, $code, $exclude, false, isset($crated[$iid]));
            }
        }
        $lines[] = $line;
        $looseCheck[] = $line;
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
    // loose stock sent as it is, and loose stock put into crates, both come out of the site's loose stock
    Crates::checkLoose($looseCheck, $from, $exclude, 'dispatch');
    $h = ['txn_date' => $date, 'site_id' => $from, 'site2_id' => $to, 'memo' => p('memo') ?: null, 'status' => 'open'];
    if ($edit) {
        $id = Txn::save($type, $h, $lines, (int)$edit['id'], ['reason' => trim((string)p('reason')) ?: null]);
        flash('success', Txn::ref(Txn::load($id)) . ' updated. Stock at both sites follows the new quantities.');
        redirect(url($pageKey, ['a' => 'view', 'id' => $id]));
    }
    $id = Txn::save($type, $h, $lines);
    $packed = (int)DB::value("SELECT COUNT(*) FROM crate_movements WHERE txn_id = :t AND kind = 'pack'", ['t' => $id]);
    flash('success', 'Dispatch ' . Txn::load($id)['txn_no'] . ' recorded.' . ($packed ? ' ' . $packed . ' crate' . ($packed === 1 ? ' was' : 's were') . ' packed from loose stock and sent with it.' : '')
        . ' Print it on the POS printer from the dispatch.');
    redirect_after_save(url($pageKey, ['a' => 'new']), url($pageKey, ['a' => 'view', 'id' => $id]));
});

$lotOn = Lots::on();
$lotTracked = $lotOn ? Lots::trackedIds(array_keys($items)) : [];
if (is_post()) {
    $rows = array_values((array)($_POST['rows'] ?? []));
} elseif ($edit) {
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
$lotSite = (int)fv('site_id', $edit, array_key_first($sites));
$lotGroups = $lotTracked ? Lots::forItems(array_filter(array_column($rows, 'item_id')), $lotSite, $edit ? (int)$edit['id'] : null, true) : [];
$crateItems = Crates::ready() ? Crates::crateItems(array_keys($items)) : [];
$crateOn = (bool)$crateItems;
$units = stockmove_units(array_keys($items));
$colCount = 4 + ($lotTracked ? 1 : 0) + ($crateOn ? 2 : 0);

/** The Conversion cell of a line: "As kept" or "Kilos to Crates" for an item kept in crates */
$convCell = function (array $r, string $i) use ($crateItems, $units): string {
    $iid = (int)($r['item_id'] ?? 0);
    $on = $iid && isset($crateItems[$iid]);
    $v = $on ? (string)($r['convert'] ?? '') : '';
    $label = $on ? ($units[$iid]['conv'] ?? 'Kilos to Crates') : 'Kilos to Crates';
    return '<td class="ds-conv-cell"><select class="form-select form-select-sm ds-conv" name="rows[' . h($i) . '][convert]" aria-label="Conversion"' . ($on ? '' : ' disabled') . '>'
        . '<option value=""' . ($v === '' ? ' selected' : '') . '>As kept</option>'
        . '<option value="pack"' . ($v === 'pack' ? ' selected' : '') . '>' . h($label) . '</option></select></td>';
};
/** The Crates cell of a line: the crates sent whole, or the crates packed (hidden fields), and the button */
$crateCell = function (array $r, string $i) use ($crateItems): string {
    $iid = (int)($r['item_id'] ?? 0);
    $on = $iid && isset($crateItems[$iid]);
    $n = 'rows[' . h($i) . ']';
    return '<td class="tr-crates-cell"><input type="hidden" name="' . $n . '[crates]" value="' . h($on ? (string)($r['crates'] ?? '') : '') . '" data-tr-crates' . (($r['convert'] ?? '') === 'pack' ? ' data-pack-crates' : '') . '>'
        . '<input type="hidden" name="' . $n . '[pack_lot]" value="' . h((string)($r['pack_lot'] ?? '')) . '" data-pack-lot>'
        . '<input type="hidden" name="' . $n . '[pack_prod]" value="' . h((string)($r['pack_prod'] ?? '')) . '" data-pack-prod>'
        . '<input type="hidden" name="' . $n . '[pack_exp]" value="' . h((string)($r['pack_exp'] ?? '')) . '" data-pack-exp>'
        . '<button type="button" class="btn btn-sm crate-btn" data-tr-crate-open' . ($on ? '' : ' disabled') . ' title="Choose the crates sent, or fill crates from loose stock">'
        . '<i class="bi bi-boxes"></i><span data-crate-label>Crates</span></button></td>';
};
$lotBox = function (array $r, string $i) use ($lotTracked, $lotGroups, $colCount): string {
    $iid = (int)($r['item_id'] ?? 0);
    $on = $iid && isset($lotTracked[$iid]);
    $html = '<tr class="tr-lots"' . ($on ? '' : ' hidden') . '><td colspan="' . $colCount . '"><div class="tr-lotbox">';
    if ($on) {
        $html .= tr_lot_table($lotGroups[$iid] ?? [], (array)($r['lots'] ?? []), (array)($r['lot_ids'] ?? []), $i);
    }
    return $html . '</div></td></tr>';
};
/** One line of the grid */
$lineRow = function (array $r, string $i) use ($items, $lotTracked, $lotGroups, $crateOn, $convCell, $crateCell, $units): string {
    $iid = (int)($r['item_id'] ?? 0);
    $dated = $iid && isset($lotTracked[$iid]);
    $sum = $dated ? array_sum(array_map('to_num', (array)($r['lots'] ?? []))) : 0.0;
    $qty = $dated ? ($sum > 0 ? rtrim(rtrim(number_format($sum, 4, '.', ''), '0'), '.') : '') : (string)($r['qty'] ?? '');
    $unit = $iid ? (string)($units[$iid]['base'] ?? '') : '';
    return '<tr class="tr-main' . ($dated ? ' has-lots' : '') . '"><td>' . (!empty($r['id']) ? '<input type="hidden" name="rows[' . h($i) . '][id]" value="' . (int)$r['id'] . '">' : '')
        . '<select class="form-select form-select-sm tr-item" data-f="item_id" name="rows[' . h($i) . '][item_id]" aria-label="Item">' . options($items, $iid ?: null, '') . '</select></td>'
        . '<td class="num tr-avail" data-label="On hand at source"></td>'
        . ($lotTracked ? '<td class="tr-lotsum" data-label="Production / expiry date">' . ($dated ? tr_lot_summary($lotGroups[$iid] ?? []) : '') . '</td>' : '')
        . ($crateOn ? $convCell($r, $i) : '')
        . '<td class="ds-qty-cell"><div class="input-group input-group-sm qty-unit-group"><input class="form-control text-end tr-qty" name="rows[' . h($i) . '][qty]" value="' . h($qty) . '" inputmode="decimal" placeholder="Qty to dispatch" aria-label="Quantity to dispatch"'
        . ($dated ? ' readonly tabindex="-1" title="The total of the date groups below"' : '') . '><span class="input-group-text tr-unit">' . h($unit !== '' ? $unit : 'unit') . '</span></div></td>'
        . ($crateOn ? $crateCell($r, $i) : '')
        . '<td class="grid-acts"><button type="button" class="btn btn-sm btn-link p-0 grid-ins tr-ins" title="Insert a line above this one" aria-label="Insert a line above"><i class="bi bi-plus-square"></i></button>'
        . '<button type="button" class="btn btn-sm btn-link text-danger p-0 tr-del" aria-label="Remove the line"><i class="bi bi-x-lg"></i></button></td></tr>';
};

layout_start($edit ? 'Edit Inventory Dispatch ' . $edit['txn_no'] : 'Dispatch Inventory', ['js' => ['js/qtytip.js'], 'actions' => $edit
    ? btn_link(Txn::url($edit), 'Cancel', 'btn-outline-secondary')
    : btn_link(url($pageKey), 'Dispatch list') . ' ' . page_link('inv.transfers', ['a' => 'new'], 'Transfer Inventory', 'btn-outline-secondary', 'arrow-left-right', 'create')]);
$config = [
    'lookup' => url('api.lookup', ['what' => 'stock']), 'cratesUrl' => url('api.crates'), 'lotsUrl' => $lotTracked ? url('api.lots') : '',
    'own' => (object)$ownNow, 'ownSite' => (string)($edit['site_id'] ?? ''), 'txn' => $edit ? (int)$edit['id'] : null,
    'crates' => (object)$crateItems, 'units' => (object)$units, 'dated' => (object)array_map(fn() => 1, $lotTracked),
];
?>
<?php if ($edit): ?>
<p class="text-muted small">Saving sends the stock again: the quantities this dispatch moved go back to <?= h($sites[(int)$edit['site_id']] ?? 'the source site') ?>, then the new lines leave the source site and arrive at the destination.</p>
<?php endif; ?>
<form method="post" id="dsForm"><?= csrf_field() ?><?= negative_stock_fields() ?>
<div class="card mb-3"><div class="card-body row g-2">
  <?= input_field('txn_date', 'Date', fv('txn_date', $edit, today()), ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
  <?= select_field('site_id', 'From site', $sites, fv('site_id', $edit, array_key_first($sites)), ['class' => 'col-6 col-md-3', 'extra' => 'id="fromSite"']) ?>
  <?= select_field('site2_id', 'To site (van or outlet)', Lookup::sites(false), fv('site2_id', $edit), ['class' => 'col-md-3', 'blank' => '— choose —', 'extra' => 'id="toSite"']) ?>
  <?= input_field('memo', 'Memo', fv('memo', $edit), ['class' => Classes::ready() ? 'col-md-2' : 'col-md-4']) ?>
  <?= Classes::field(fv('class_id', $edit), 'col-md-2') ?>
  <?php if ($edit): ?><?= input_field('reason', 'Reason for the change', fv('reason'), ['class' => 'col-12', 'extra' => 'maxlength="255" placeholder="Recorded in the audit trail"']) ?><?php endif; ?>
</div></div>
<div class="card card-body mb-3 ds-lines">
  <div class="table-responsive"><table class="table table-sm tr-table ds-table<?= $crateOn ? ' tr-has-crates' : '' ?>" id="dsTable">
    <thead><tr><th>Item</th><th class="num">On hand at source</th><?= $lotTracked ? '<th class="tr-lotsum-h">Production / expiry date</th>' : '' ?><?= $crateOn ? '<th>Conversion</th>' : '' ?><th class="num">Qty to dispatch</th><?= $crateOn ? '<th>Crates</th>' : '' ?><th></th></tr></thead><tbody>
  <?php foreach ($rows as $i => $r): ?>
    <?= $lineRow($r, (string)$i) ?>
    <?= $lotTracked ? $lotBox($r, (string)$i) : '' ?>
  <?php endforeach; ?>
  </tbody></table></div>
  <template id="dsTpl"><?= $lineRow([], '__i__') ?><?= $lotTracked ? '<tr class="tr-lots" hidden><td colspan="' . $colCount . '"><div class="tr-lotbox"></div></td></tr>' : '' ?></template>
  <div class="grid-add"><?php foreach ([1 => 'Add line', 5 => 'Add 5 lines', 10 => 'Add 10 lines'] as $n => $lbl): ?><button type="button" class="btn btn-sm btn-outline-secondary tr-add" data-count="<?= $n ?>"><i class="bi bi-plus"></i> <?= h($lbl) ?></button><?php endforeach; ?></div>
  <div class="ds-total" aria-live="polite"><span>Total to dispatch</span><strong data-ds-total></strong></div>
</div>
<?php if ($edit): ?>
  <div class="d-flex flex-wrap gap-2"><button class="btn btn-primary"><i class="bi bi-check2"></i> Save changes</button><?= btn_link(Txn::url($edit), 'Cancel', 'btn-outline-secondary') ?></div>
<?php else: ?>
<?= save_buttons('Record dispatch', url($pageKey), Access::can($pageKey, 'create')) ?>
<?php endif; ?>
<?php if ($crateOn): ?>
<div class="ds-help small text-muted mt-3">
  <p class="mb-1"><i class="bi bi-boxes"></i> <strong>Crates on hand</strong> go whole: press <strong>Crates</strong> and tick them, or type the figure the scale shows in <strong>Find figure</strong> (1330 for 13.30 kg) and press Enter to take the crate with that weight.</p>
  <p class="mb-0"><i class="bi bi-box-arrow-in-down"></i> <strong>Loose stock into crates</strong>: choose <strong>Kilos to Crates</strong> under Conversion (the crate window opens; <strong>Fill crates</strong> opens it again), pick the production / expiry group and type each crate's dispatch figure. The crates are numbered on from the last one and take the group's dates.</p>
</div>
<?php endif; ?>
</form>
<script type="application/json" id="dsConfig"><?= json_encode($config, JSON_HEX_TAG | JSON_HEX_AMP) ?></script>
<?= $crateOn ? crates_script_tag() : '' ?>
<script src="<?= h(asset('js/dispatch.js')) ?>" defer></script>
<?php
layout_end();
