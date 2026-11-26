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
 *
 * v8: many sites to one. "From sites" takes one site or several (a cold storage and an outlet, say), and each line
 * names the site its stock leaves from; everything arrives at the one To site. "Stock at the sites" lists what each
 * site chosen holds, with the site's marker on every row, its loose kilos, its crates and its earliest expiry; the
 * filter narrows it to an item, and Add puts the item on a line with that site. Each line takes its date groups and
 * its crates from its own site, so the production and expiry dates are followed as before.
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
    foreach (array_unique(array_merge([(int)$edit['site_id']], array_map('intval', DB::column('SELECT DISTINCT site_id FROM transaction_lines WHERE txn_id = :t AND site_id IS NOT NULL', ['t' => $edit['id']])))) as $es) {
        if ($es && !Access::siteAllowed($es)) {
            Access::denyPage($pageKey, 'edit a dispatch of another site on');
        }
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
$siteNames = Lookup::sites(false);

/** v8: the site each line of a dispatch leaves from (the dispatch's own site for lines saved before v8) */
$lineSite = fn(array $l, ?array $t): int => (int)($l['site_id'] ?? 0) ?: (int)($t['site_id'] ?? 0);

/** What this dispatch itself took out of each site, by site and item (added back to what is available when it is edited) */
$ownOut = function (?array $edit) use ($lineSite): array {
    $out = [];
    if ($edit) {
        foreach (Txn::lines((int)$edit['id']) as $l) {
            if ($l['item_id']) {
                $s = $lineSite($l, $edit);
                $out[$s][(int)$l['item_id']] = ($out[$s][(int)$l['item_id']] ?? 0.0) + (float)$l['qty'];
            }
        }
    }
    return $out;
};

/** v8: the sites the stock comes from, as sent (from_sites[]), or the single site of a form sent before v8 */
$postedFrom = function (): array {
    $ids = array_values(array_unique(array_filter(array_map('intval', (array)($_POST['from_sites'] ?? [])))));
    if (!$ids && pint('site_id')) {
        $ids = [pint('site_id')];
    }
    return $ids;
};

handle_post(function () use ($pageKey, $type, $edit, $ownOut, $postedFrom, $siteNames) {
    $to = pint('site2_id');
    $fromSites = $postedFrom();
    if (!$to) {
        fail('Choose the site the stock goes to (To site).');
    }
    if (!$fromSites) {
        fail('Choose the site or sites the stock comes from (From sites).');
    }
    foreach ($fromSites as $fs) {
        if ($fs === $to) {
            fail(($siteNames[$fs] ?? 'The To site') . ' is the site the stock goes to: it can not also be a site it comes from.');
        }
        if (!Access::siteAllowed($fs)) {
            fail('You are not allowed to move stock from ' . ($siteNames[$fs] ?? 'that site') . '.');
        }
    }
    if (!Access::siteAllowed($to)) {
        fail('You are not allowed to move stock to ' . ($siteNames[$to] ?? 'that site') . '.');
    }
    $date = pdate('txn_date', today());
    $lines = [];
    $looseCheck = [];   // the lines that take loose stock (crates packed from it included), for Crates::checkLoose
    $own = $ownOut($edit);
    $want = [];
    $wantLot = [];
    $used = [];         // what earlier lines packed: crate numbers and kilos of each group (v8: of each site)
    $exclude = $edit ? (int)$edit['id'] : null;
    $crated = Crates::ready() ? Crates::crateItems() : [];
    foreach ((array)($_POST['rows'] ?? []) as $r) {
        $iid = (int)($r['item_id'] ?? 0);
        if (!$iid) {
            continue;
        }
        // v8: each line leaves from its own site, one of the From sites
        $from = (int)($r['site_id'] ?? 0) ?: $fromSites[0];
        $code = item_cache($iid)['code'];
        if (!in_array($from, $fromSites, true)) {
            fail($code . ': it is sent from ' . ($siteNames[$from] ?? 'a site') . ', which is not one of the From sites. Choose the site on the line again.');
        }
        $at = ' at ' . ($siteNames[$from] ?? 'the source site');
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
                $k = $iid . '@' . $from . '#' . Lots::key($prod, $exp);
                $wantLot[$k] = round(($wantLot[$k] ?? 0.0) + $q, 4);
                // v5: loose stock only for an item kept in crates (its crates go by the crate)
                $have = isset($crated[$iid]) ? Lots::looseQty($iid, $from, $prod, $exp, $exclude) : Lots::qty($iid, $from, $prod, $exp, $exclude);
                if ($wantLot[$k] > $have + 0.00005) {
                    fail($code . ': only ' . qty(max(0, $have)) . ' left with ' . Lots::label($prod, $exp) . $at . '. Send at most that from this date group, and the rest from another.');
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
        $want[$from][$iid] = ($want[$from][$iid] ?? 0.0) + $q;
        $avail = Stock::onHand($iid, $from) + ($own[$from][$iid] ?? 0.0);
        if ($want[$from][$iid] > $avail + 0.00001 && Settings::get('allow_negative_stock') !== '1') {
            fail('Not enough stock of ' . $code . $at . ' (' . qty($avail) . ').');
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
    // loose stock sent as it is, and loose stock put into crates, both come out of the loose stock of the line's site
    Crates::checkLoose($looseCheck, null, $exclude, 'dispatch');
    // the dispatch's own site: the site of its first line (v8: the others are on their lines)
    $h = ['txn_date' => $date, 'site_id' => (int)$lines[0]['site_id'], 'site2_id' => $to, 'memo' => p('memo') ?: null, 'status' => 'open'];
    if ($edit) {
        $id = Txn::save($type, $h, $lines, (int)$edit['id'], ['reason' => trim((string)p('reason')) ?: null]);
        flash('success', Txn::ref(Txn::load($id)) . ' updated. Stock at both sites follows the new quantities.');
        redirect(url($pageKey, ['a' => 'view', 'id' => $id]));
    }
    $id = Txn::save($type, $h, $lines);
    $packed = (int)DB::value("SELECT COUNT(*) FROM crate_movements WHERE txn_id = :t AND kind = 'pack'", ['t' => $id]);
    $n = count(array_unique(array_column($lines, 'site_id')));
    flash('success', 'Dispatch ' . Txn::load($id)['txn_no'] . ' recorded' . ($n > 1 ? ', from ' . $n . ' sites to ' . ($siteNames[$to] ?? 'one site') : '') . '.'
        . ($packed ? ' ' . $packed . ' crate' . ($packed === 1 ? ' was' : 's were') . ' packed from loose stock and sent with it.' : '')
        . ' Print it on the POS printer from the dispatch.');
    redirect_after_save(url($pageKey, ['a' => 'new']), url($pageKey, ['a' => 'view', 'id' => $id]));
});

$lotOn = Lots::on();
$lotTracked = $lotOn ? Lots::trackedIds(array_keys($items)) : [];
// v8: the sites the stock comes from (as sent back, the sites of the lines of the dispatch edited, or the first site)
if (is_post()) {
    $fromSites = array_values(array_filter($postedFrom(), fn($x) => isset($sites[$x])));
} elseif ($edit) {
    $fromSites = [];
    foreach ($editLines as $l) {
        $fromSites[] = $lineSite($l, $edit);
    }
    $fromSites = array_values(array_unique(array_merge($fromSites ?: [(int)$edit['site_id']])));
} else {
    $fromSites = gint('site_id') && isset($sites[gint('site_id')]) ? [gint('site_id')] : [];
}
if (!$fromSites && $sites) {
    $fromSites = [(int)array_key_first($sites)];
}
if (is_post()) {
    $rows = array_values((array)($_POST['rows'] ?? []));
} elseif ($edit) {
    $rows = [];
    $byItem = [];
    foreach ($editLines as $l) {
        $iid = (int)$l['item_id'];
        $ls = $lineSite($l, $edit);
        if (!isset($lotTracked[$iid])) {
            $rows[] = ['id' => $l['id'], 'item_id' => $iid, 'site_id' => $ls, 'qty' => rtrim(rtrim(number_format((float)$l['qty'], 4, '.', ''), '0'), '.')];
            continue;
        }
        // an item with dates: one line per item and site, its date groups under it
        $bk = $iid . '@' . $ls;
        if (!isset($byItem[$bk])) {
            $byItem[$bk] = count($rows);
            $rows[] = ['item_id' => $iid, 'site_id' => $ls, 'qty' => '', 'lots' => [], 'lot_ids' => []];
        }
        $k = $byItem[$bk];
        $took = DB::all('SELECT production_date AS p, expiry_date AS e, -SUM(qty) AS q FROM inventory_movements WHERE txn_line_id = :l AND site_id = :s AND qty < 0
                          GROUP BY production_date, expiry_date', ['l' => $l['id'], 's' => $ls]);
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
$siteOfRow = fn(array $r): int => in_array((int)($r['site_id'] ?? 0), $fromSites, true) ? (int)$r['site_id'] : $fromSites[0];
$ownNow = $ownOut($edit);
// the date groups of each line's item at the line's site
$lotGroups = [];
if ($lotTracked) {
    $bySite = [];
    foreach ($rows as $r) {
        if (!empty($r['item_id'])) {
            $bySite[$siteOfRow($r)][] = (int)$r['item_id'];
        }
    }
    foreach ($bySite as $sid => $ids) {
        $lotGroups[$sid] = Lots::forItems(array_values(array_unique($ids)), (int)$sid, $edit ? (int)$edit['id'] : null, true);
    }
}
$crateItems = Crates::ready() ? Crates::crateItems(array_keys($items)) : [];
$crateOn = (bool)$crateItems;
$units = stockmove_units(array_keys($items));
$colCount = 4 + ($lotTracked ? 1 : 0) + ($crateOn ? 2 : 0);
$fromOptions = array_intersect_key($sites, array_flip($fromSites));
$fromOptions = array_replace(array_flip($fromSites), $fromOptions);

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
/** v8: the From site of a line, under its item: the site's marker and the site, one of the From sites (shown when there are two or more) */
$sitePick = function (array $r, string $i) use ($fromOptions, $siteOfRow): string {
    $sid = $siteOfRow($r);
    return '<div class="ds-site-pick"><span class="site-mark ' . SiteMark::cls($sid) . '" data-ds-mark aria-hidden="true"></span>'
        . '<select class="form-select form-select-sm ds-site" name="rows[' . h($i) . '][site_id]" data-no-combo aria-label="From site">' . options($fromOptions, $sid) . '</select></div>';
};
$lotBox = function (array $r, string $i) use ($lotTracked, $lotGroups, $colCount, $siteOfRow): string {
    $iid = (int)($r['item_id'] ?? 0);
    $on = $iid && isset($lotTracked[$iid]);
    $html = '<tr class="tr-lots"' . ($on ? '' : ' hidden') . '><td colspan="' . $colCount . '"><div class="tr-lotbox">';
    if ($on) {
        $html .= tr_lot_table($lotGroups[$siteOfRow($r)][$iid] ?? [], (array)($r['lots'] ?? []), (array)($r['lot_ids'] ?? []), $i);
    }
    return $html . '</div></td></tr>';
};
/** One line of the grid */
$lineRow = function (array $r, string $i) use ($items, $lotTracked, $lotGroups, $crateOn, $convCell, $crateCell, $sitePick, $units, $siteOfRow): string {
    $iid = (int)($r['item_id'] ?? 0);
    $dated = $iid && isset($lotTracked[$iid]);
    $sum = $dated ? array_sum(array_map('to_num', (array)($r['lots'] ?? []))) : 0.0;
    $qty = $dated ? ($sum > 0 ? rtrim(rtrim(number_format($sum, 4, '.', ''), '0'), '.') : '') : (string)($r['qty'] ?? '');
    $unit = $iid ? (string)($units[$iid]['base'] ?? '') : '';
    return '<tr class="tr-main' . ($dated ? ' has-lots' : '') . '"><td>' . (!empty($r['id']) ? '<input type="hidden" name="rows[' . h($i) . '][id]" value="' . (int)$r['id'] . '">' : '')
        . '<select class="form-select form-select-sm tr-item" data-f="item_id" name="rows[' . h($i) . '][item_id]" aria-label="Item">' . options($items, $iid ?: null, '') . '</select>'
        . $sitePick($r, $i) . '</td>'
        . '<td class="num tr-avail" data-label="On hand at source"></td>'
        . ($lotTracked ? '<td class="tr-lotsum" data-label="Production / expiry date">' . ($dated ? tr_lot_summary($lotGroups[$siteOfRow($r)][$iid] ?? []) : '') . '</td>' : '')
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
    'lookup' => url('api.lookup', ['what' => 'stock']), 'siteStock' => url('api.lookup', ['what' => 'site_stock']), 'cratesUrl' => url('api.crates'), 'lotsUrl' => $lotTracked ? url('api.lots') : '',
    'own' => (object)array_map(fn($x) => (object)$x, $ownNow), 'txn' => $edit ? (int)$edit['id'] : null,
    'crates' => (object)$crateItems, 'units' => (object)$units, 'dated' => (object)array_map(fn() => 1, $lotTracked),
    'marks' => (object)SiteMark::map(array_keys($siteNames)), 'sites' => (object)$siteNames,
];
$fromText = function (array $ids) use ($siteNames): string {
    $names = array_map(fn($x) => $siteNames[$x] ?? '', $ids);
    return count($names) <= 2 ? implode(' and ', $names) : $names[0] . ' and ' . (count($names) - 1) . ' more';
};
$toValue = (string)fv('site2_id', $edit);
?>
<?php if ($edit): ?>
<p class="text-muted small">Saving sends the stock again: the quantities this dispatch moved go back to the sites they left, then the new lines leave their sites and arrive at the destination.</p>
<?php endif; ?>
<form method="post" id="dsForm"><?= csrf_field() ?><?= negative_stock_fields() ?>
<div class="card mb-3"><div class="card-body row g-2">
  <?= input_field('txn_date', 'Date', fv('txn_date', $edit, today()), ['type' => 'date', 'class' => 'col-6 col-md-2']) ?>
  <div class="col-6 col-md-3">
    <label class="form-label" id="dsFromLabel">From sites</label>
    <div class="dropdown ds-sites" data-ds-sites>
      <button type="button" class="form-select form-select-sm ds-sites-btn" data-bs-toggle="dropdown" data-bs-auto-close="outside" aria-expanded="false" aria-labelledby="dsFromLabel" id="dsFromBtn">
        <span class="ds-sites-marks" data-ds-sites-marks><?php foreach ($fromSites as $fs): ?><?= SiteMark::html($fs) ?><?php endforeach; ?></span>
        <span class="ds-sites-text" data-ds-sites-text><?= h($fromText($fromSites)) ?></span>
      </button>
      <div class="dropdown-menu ds-sites-menu" aria-labelledby="dsFromBtn">
        <div class="ds-sites-head">Send stock from</div>
        <?php foreach ($sites as $sid => $sn): ?>
        <label class="ds-site-opt<?= (string)$sid === $toValue ? ' is-to' : '' ?>">
          <input class="form-check-input" type="checkbox" name="from_sites[]" value="<?= (int)$sid ?>"<?= in_array((int)$sid, $fromSites, true) ? ' checked' : '' ?><?= (string)$sid === $toValue ? ' disabled' : '' ?>>
          <?= SiteMark::html((int)$sid) ?><span class="ds-site-name"><?= h($sn) ?></span><span class="ds-site-note"><?= (string)$sid === $toValue ? 'the To site' : '' ?></span>
        </label>
        <?php endforeach; ?>
        <div class="ds-sites-foot"><button type="button" class="btn btn-sm btn-link" data-ds-sites-all>All sites</button><button type="button" class="btn btn-sm btn-link" data-ds-sites-first>Only the first</button></div>
      </div>
    </div>
  </div>
  <?= select_field('site2_id', 'To site (van or outlet)', Lookup::sites(false), $toValue, ['class' => 'col-md-3', 'blank' => '— choose —', 'extra' => 'id="toSite"']) ?>
  <?= input_field('memo', 'Memo', fv('memo', $edit), ['class' => Classes::ready() ? 'col-md-2' : 'col-md-4']) ?>
  <?= Classes::field(fv('class_id', $edit), 'col-md-2') ?>
  <?php if ($edit): ?><?= input_field('reason', 'Reason for the change', fv('reason'), ['class' => 'col-12', 'extra' => 'maxlength="255" placeholder="Recorded in the audit trail"']) ?><?php endif; ?>
</div></div>

<section class="card mb-3 ds-stock" id="dsStock" aria-labelledby="dsStockTitle">
  <div class="ds-stock-head">
    <div class="ds-stock-title">
      <h2 id="dsStockTitle">Stock at the sites</h2>
      <div class="ds-stock-legend" data-ds-legend role="group" aria-label="Show the stock of"></div>
    </div>
    <div class="ds-stock-tools">
      <div class="ds-stock-search"><i class="bi bi-search" aria-hidden="true"></i><input type="search" class="form-control form-control-sm" placeholder="Filter by item code or name" aria-label="Filter the stock by item code or name" data-ds-filter></div>
      <button type="button" class="btn btn-sm btn-outline-secondary ds-stock-toggle" data-ds-stock-toggle aria-expanded="true" aria-controls="dsStockBody"><i class="bi bi-chevron-up"></i><span>Hide</span></button>
    </div>
  </div>
  <div class="ds-stock-body" id="dsStockBody" data-ds-stock-body>
    <div class="ds-stock-empty text-muted small">Loading the stock…</div>
  </div>
</section>

<div class="card card-body mb-3 ds-lines">
  <div class="table-responsive"><table class="table table-sm tr-table ds-table<?= $crateOn ? ' tr-has-crates' : '' ?><?= count($fromSites) > 1 ? ' ds-many' : '' ?>" id="dsTable">
    <thead><tr><th>Item<span class="ds-site-h"> and the site it comes from</span></th><th class="num">On hand at source</th><?= $lotTracked ? '<th class="tr-lotsum-h">Production / expiry date</th>' : '' ?><?= $crateOn ? '<th>Conversion</th>' : '' ?><th class="num">Qty to dispatch</th><?= $crateOn ? '<th>Crates</th>' : '' ?><th></th></tr></thead><tbody>
  <?php foreach ($rows as $i => $r): ?>
    <?= $lineRow($r, (string)$i) ?>
    <?= $lotTracked ? $lotBox($r, (string)$i) : '' ?>
  <?php endforeach; ?>
  </tbody></table></div>
  <template id="dsTpl"><?= $lineRow([], '__i__') ?><?= $lotTracked ? '<tr class="tr-lots" hidden><td colspan="' . $colCount . '"><div class="tr-lotbox"></div></td></tr>' : '' ?></template>
  <div class="grid-add"><?php foreach ([1 => 'Add line', 5 => 'Add 5 lines', 10 => 'Add 10 lines'] as $n => $lbl): ?><button type="button" class="btn btn-sm btn-outline-secondary tr-add" data-count="<?= $n ?>"><i class="bi bi-plus"></i> <?= h($lbl) ?></button><?php endforeach; ?></div>
  <div class="ds-total" aria-live="polite">
    <div class="ds-total-sites" data-ds-total-sites></div>
    <div class="ds-total-all"><span>Total to dispatch</span><strong data-ds-total></strong></div>
  </div>
</div>
<?php if ($edit): ?>
  <div class="d-flex flex-wrap gap-2"><button class="btn btn-primary"><i class="bi bi-check2"></i> Save changes</button><?= btn_link(Txn::url($edit), 'Cancel', 'btn-outline-secondary') ?></div>
<?php else: ?>
<?= save_buttons('Record dispatch', url($pageKey), Access::can($pageKey, 'create')) ?>
<?php endif; ?>
<div class="ds-help small text-muted mt-3">
  <p class="mb-1"><i class="bi bi-diagram-3"></i> <strong>From many sites</strong>: tick each site in <strong>From sites</strong>, then choose the site on each line, or press <strong>Add</strong> beside a row of <strong>Stock at the sites</strong>. Everything goes to the one To site.</p>
  <?php if ($crateOn): ?>
  <p class="mb-1"><i class="bi bi-boxes"></i> <strong>Crates on hand</strong> go whole: press <strong>Crates</strong> and tick them, or type the figure the scale shows in <strong>Find figure</strong> (1330 for 13.30 kg) and press Enter to take the crate with that weight.</p>
  <p class="mb-0"><i class="bi bi-box-arrow-in-down"></i> <strong>Loose stock into crates</strong>: choose <strong>Kilos to Crates</strong> under Conversion (the crate window opens; <strong>Fill crates</strong> opens it again), pick the production / expiry group and type each crate's dispatch figure. The crates are numbered on from the last one and take the group's dates.</p>
  <?php endif; ?>
</div>
</form>
<script type="application/json" id="dsConfig"><?= json_encode($config, JSON_HEX_TAG | JSON_HEX_AMP) ?></script>
<?= $crateOn ? crates_script_tag() : '' ?>
<script src="<?= h(asset('js/dispatch.js')) ?>" defer></script>
<?php
layout_end();
