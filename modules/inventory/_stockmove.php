<?php
declare(strict_types=1);

/**
 * Shared by Transfer Inventory and Dispatch Inventory (v4): the date-group sub-form of a line, and the units the
 * quantities are shown in (with what a quantity is made of, in a tooltip, when the item has two or more units).
 */

/**
 * v44: the date groups of an item at the source site, with a box for the quantity to move from each (the sub-form of a
 * transfer line). Groups the line already moves that the site no longer shows (an edit) are kept.
 */
function tr_lot_table(array $groups, array $chosen, array $ids, string $i): string
{
    $seen = [];
    foreach ($groups as $g) {
        $seen[$g['key']] = true;
    }
    foreach ($chosen as $key => $q) {
        if (!isset($seen[$key]) && to_num($q) > 0) {
            [$p, $e] = Lots::split((string)$key);
            $groups[] = ['key' => Lots::key($p, $e), 'prod' => $p, 'exp' => $e, 'qty' => 0.0, 'status' => Lots::status($e), 'days' => Lots::daysLeft($e)];
        }
    }
    if (!$groups) {
        return '<div class="tr-lot-empty">No stock of this item at the source site.</div>';
    }
    $rows = '';
    foreach ($groups as $g) {
        $st = !$g['prod'] && !$g['exp'] ? 'No dates' : ($g['status'] === 'expired' ? 'Expired ' . abs((int)$g['days']) . ' day(s) ago' : 'Expires in ' . (int)$g['days'] . ' day(s)');
        $v = $chosen[$g['key']] ?? '';
        $n = 'rows[' . $i . ']';
        $rows .= '<tr class="' . ($g['status'] === 'expired' ? 'lot-expired-row' : ($g['status'] === 'expiring' ? 'lot-expiring-row' : '')) . '">'
            . '<td data-label="Expiry date">' . ($g['exp'] ? h(fdate($g['exp'])) : '<span class="text-muted">None</span>') . '</td>'
            . '<td data-label="Production date">' . ($g['prod'] ? h(fdate($g['prod'])) : '<span class="text-muted">None</span>') . '</td>'
            . '<td data-label="Status" class="small">' . h($st) . '</td>'
            . '<td data-label="On hand" class="num tr-lot-have">' . qty($g['qty']) . '</td>'
            . '<td data-label="Qty to move"><input class="form-control form-control-sm text-end tr-lot-qty" name="' . h($n . '[lots][' . $g['key'] . ']') . '" value="' . h($v === '' ? '' : rtrim(rtrim(number_format((float)$v, 4, '.', ''), '0'), '.')) . '"'
            . ' data-max="' . h((string)$g['qty']) . '" inputmode="decimal" placeholder="0" aria-label="Quantity to move with ' . h(Lots::label($g['prod'], $g['exp'])) . '">'
            . (!empty($ids[$g['key']]) ? '<input type="hidden" name="' . h($n . '[lot_ids][' . $g['key'] . ']') . '" value="' . (int)$ids[$g['key']] . '">' : '') . '</td></tr>';
    }
    return '<table class="table table-sm mb-0 tr-lot-table"><thead><tr><th>Expiry date</th><th>Production date</th><th>Status</th><th class="num">On hand</th><th class="num">Qty to move</th></tr></thead><tbody>'
        . $rows . '</tbody></table>';
}

/** v44: what the date-group column of a transfer line says (the groups are filled in under the line) */
function tr_lot_summary(array $groups): string
{
    if (!$groups) {
        return '<span class="text-muted small">No stock at the source site</span>';
    }
    $dated = count(array_filter($groups, fn($g) => $g['prod'] || $g['exp']));
    return '<span class="small">' . count($groups) . ' date group' . (count($groups) === 1 ? '' : 's') . ($dated < count($groups) ? ' (one without dates)' : '')
        . '</span><span class="tr-lotsum-hint small text-muted">Type the quantities below</span>';
}

/**
 * v4: item id => ['base' => "kg", 'units' => [[code, factor], ...] (its other fixed units), 'conv' => "Kilos to Crates"
 * (items kept in containers), 'one' => "Crate"] for the quantity labels and tooltips of the lines.
 */
function stockmove_units(array $itemIds): array
{
    $ids = array_values(array_unique(array_filter(array_map('intval', $itemIds))));
    if (!$ids) {
        return [];
    }
    $out = [];
    foreach (array_chunk($ids, 1000) as $chunk) {
        [$in, $p] = DB::in('smu', $chunk);
        foreach (DB::all("SELECT i.id, COALESCE(NULLIF(s.base_unit, ''), NULLIF(i.unit, ''), '') AS base FROM items i LEFT JOIN uom_sets s ON s.id = i.uom_set_id WHERE i.id IN $in", $p) as $r) {
            $out[(int)$r['id']] = ['base' => (string)$r['base'], 'units' => []];
        }
    }
    foreach (Uom::unitsByItem($ids) as $iid => $units) {
        foreach ($units as $u) {
            if (!$u['v'] && abs($u['factor'] - 1.0) > 0.0000001 && $u['factor'] > 0 && isset($out[$iid])) {
                $out[$iid]['units'][] = [$u['code'], $u['factor']];
            }
        }
    }
    if (Crates::ready()) {
        foreach (array_keys(Crates::crateItems($ids)) as $iid) {
            if (isset($out[$iid])) {
                $out[$iid]['conv'] = Crates::convertLabel($iid);
                $out[$iid]['one'] = Crates::containerName($iid, false);
                $out[$iid]['many'] = Crates::containerName($iid);
            }
        }
    }
    return $out;
}
