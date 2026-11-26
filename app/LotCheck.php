<?php
declare(strict_types=1);

/**
 * v5: Production and Expiry Dates (Inventory). Finds the stock that has no production and expiry dates, says where
 * it came from, and puts things right with a date change (an inventory adjustment marked Lots::DATE_CHANGE that
 * moves a quantity from one date group to another at the same site, at the same value: Posting::dateChange()).
 *
 * Why stock may carry no dates although dates were typed:
 *  - it came in before this version on a document whose dates were not taken over (Excel imports of bills and
 *    opening quantities had no date columns; stock received, sold or moved in crates followed "first in, first out"
 *    instead of the crates' own dates; "Kilos to Crates" with dates typed for stock without dates did not move the
 *    stock to those dates);
 *  - it came in while date tracking was switched off, or for an item marked as not expiring at the time.
 *
 * The check compares, for every item that keeps dates and every site, the stock of each date group (its movements)
 * with what the open crates of that group hold.
 *
 * v6: dates are never taken off stock that has them. In v5, "Put in agreement with the crates" filled a group short
 * of its crates from the loose stock of the other groups, the group without dates included as a destination: when
 * crates without dates held more than the stock without dates, kilos received with their dates (a bill of 1,100 kg
 * with Prod. 11/24/2026, Exp. 11/30/2026) were moved into "no dates", and Dispatch Inventory showed them there. Now:
 *  - crates without dates that hold more than the stock without dates get the dates of the stock (plan());
 *  - "Take the dates from the documents" (repair()) puts back what v5 did: it voids the date changes that took dates
 *    off (or, when one can no longer be voided, gives the kilos it moved back their dates where they are recorded),
 *    gives stock received without dates on a document line that carries dates the dates of that line, then puts
 *    each group in agreement with its crates.
 */
final class LotCheck
{
    /**
     * The items that keep dates, by site: what each date group holds, what its crates hold, and what is wrong.
     * [['item_id', 'code', 'name', 'unit', 'site_id', 'site', 'on_hand', 'dated', 'undated', 'undated_loose',
     *   'in_crates', 'crate_item', 'deficit', 'groups' => [key => ['prod', 'exp', 'label', 'stock', 'crates', 'loose']]], ...]
     */
    public static function overview(?int $siteId = null, ?int $itemId = null, bool $all = false, string $search = ''): array
    {
        if (!Lots::on()) {
            return [];
        }
        $where = "i.item_type IN ('inventory','assembly') AND i.track_expiry = 1";
        $p = [];
        if ($siteId) {
            $where .= ' AND x.site_id = :s';
            $p['s'] = $siteId;
        }
        if ($itemId) {
            $where .= ' AND x.item_id = :i';
            $p['i'] = $itemId;
        }
        if ($search !== '') {
            $where .= ' AND (i.code LIKE :q OR i.name LIKE :q2)';
            $p['q'] = '%' . $search . '%';
            $p['q2'] = '%' . $search . '%';
        }
        $rows = [];
        $sql = "SELECT x.item_id, x.site_id, x.production_date AS pd, x.expiry_date AS ed, SUM(x.qty) AS q
                  FROM inventory_movements x JOIN items i ON i.id = x.item_id
                 WHERE $where GROUP BY x.item_id, x.site_id, x.production_date, x.expiry_date";
        foreach (DB::all($sql, $p) as $r) {
            self::put($rows, (int)$r['item_id'], (int)$r['site_id'], $r['pd'] ?: null, $r['ed'] ?: null, 'stock', (float)$r['q']);
        }
        if (Crates::ready()) {
            $sql = "SELECT x.item_id, x.site_id, x.production_date AS pd, x.expiry_date AS ed, SUM(x.qty_left) AS q
                      FROM crates x JOIN items i ON i.id = x.item_id
                     WHERE x.status = 'open' AND $where GROUP BY x.item_id, x.site_id, x.production_date, x.expiry_date";
            foreach (DB::all($sql, $p) as $r) {
                self::put($rows, (int)$r['item_id'], (int)$r['site_id'], $r['pd'] ?: null, $r['ed'] ?: null, 'crates', (float)$r['q']);
            }
        }
        if (!$rows) {
            return [];
        }
        $itemIds = array_values(array_unique(array_map(fn($r) => $r['item_id'], $rows)));
        [$in, $ip] = DB::in('lci', $itemIds);
        $items = [];
        foreach (DB::all("SELECT id, code, name, unit FROM items WHERE id IN $in", $ip) as $it) {
            $items[(int)$it['id']] = $it;
        }
        $crateItems = Crates::ready() ? Crates::crateItems($itemIds) : [];
        $sites = Lookup::sites(false);
        // v6: the stock without dates that came in with dates: taken off by a date change, or received on a line that carries them
        $off = [];
        foreach (self::takenOff($siteId, $itemId) as $d) {
            foreach ($d['moves'] as $m) {
                if ((!$siteId || $m['site_id'] === $siteId) && (!$itemId || $m['item_id'] === $itemId)) {
                    $off[$m['item_id'] . ':' . $m['site_id']] = ($off[$m['item_id'] . ':' . $m['site_id']] ?? 0.0) + $m['qty'];
                }
            }
        }
        $docDated = [];
        foreach (self::docDated($siteId, $itemId) as $d) {
            $docDated[$d['item_id'] . ':' . $d['site_id']] = ($docDated[$d['item_id'] . ':' . $d['site_id']] ?? 0.0) + $d['qty'];
        }
        $out = [];
        foreach ($rows as $r) {
            $it = $items[$r['item_id']] ?? null;
            if (!$it || !Access::siteAllowed($r['site_id'])) {
                continue;
            }
            $onHand = 0.0;
            $dated = 0.0;
            $undated = 0.0;
            $undatedLoose = 0.0;
            $inCrates = 0.0;
            $deficit = 0.0;
            foreach ($r['groups'] as $k => &$g) {
                $g['stock'] = round($g['stock'], 4);
                $g['crates'] = round($g['crates'], 4);
                $g['loose'] = round($g['stock'] - $g['crates'], 4);
                $g['label'] = Lots::label($g['prod'], $g['exp']);
                $onHand += $g['stock'];
                $inCrates += $g['crates'];
                if ($g['prod'] || $g['exp']) {
                    $dated += $g['stock'];
                } else {
                    $undated += $g['stock'];
                    $undatedLoose += $g['loose'];
                }
                if ($g['loose'] < -Crates::EPS) {
                    $deficit += -$g['loose'];
                }
            }
            unset($g);
            uasort($r['groups'], [Lots::class, 'fifoOrder']);
            $row = [
                'item_id' => $r['item_id'], 'code' => (string)$it['code'], 'name' => (string)$it['name'],
                'unit' => (string)(Crates::baseUnit($r['item_id']) ?: ($it['unit'] ?: '')),
                'site_id' => $r['site_id'], 'site' => (string)($sites[$r['site_id']] ?? ('Site #' . $r['site_id'])),
                'on_hand' => round($onHand, 4), 'dated' => round($dated, 4), 'undated' => round($undated, 4),
                'undated_loose' => round(max(0.0, $undatedLoose), 4), 'in_crates' => round($inCrates, 4),
                'crate_item' => isset($crateItems[$r['item_id']]), 'deficit' => round($deficit, 4), 'groups' => $r['groups'],
            ];
            $k = $r['item_id'] . ':' . $r['site_id'];
            $row['taken_off'] = round($off[$k] ?? 0.0, 4);
            $row['doc_dated'] = round($docDated[$k] ?? 0.0, 4);
            // what "Take the dates from the documents" gives back: never more than the stock without dates
            $row['fixable'] = round(min(max(0.0, $row['undated']), $row['taken_off'] + $row['doc_dated']), 4);
            $row['ok'] = $row['deficit'] <= Crates::EPS && $row['undated'] <= Crates::EPS;
            if (!$all && $row['ok']) {
                continue;
            }
            if (!$all && abs($row['on_hand']) <= Crates::EPS && $row['deficit'] <= Crates::EPS) {
                continue;
            }
            $out[] = $row;
        }
        usort($out, fn($a, $b) => [$a['ok'], $a['code'], $a['site']] <=> [$b['ok'], $b['code'], $b['site']]);
        return $out;
    }

    private static function put(array &$rows, int $itemId, int $siteId, ?string $prod, ?string $exp, string $what, float $q): void
    {
        $k = $itemId . ':' . $siteId;
        $rows[$k] ??= ['item_id' => $itemId, 'site_id' => $siteId, 'groups' => []];
        $g = Lots::key($prod, $exp);
        $rows[$k]['groups'][$g] ??= ['key' => $g, 'prod' => $prod, 'exp' => $exp, 'stock' => 0.0, 'crates' => 0.0];
        $rows[$k]['groups'][$g][$what] += $q;
    }

    /**
     * v6: what puts the date groups of one item at one site in agreement with its crates, without ever taking dates
     * off stock that has them:
     *  - the stock without dates below zero (what went out of it came from stock with dates): that much comes from the
     *    loose stock with dates, oldest first, so the group comes back to zero and no further;
     *  - crates without dates holding more than the stock without dates: those crates get the dates of the loose stock
     *    with dates, oldest first (the kilos in them are kilos the stock records with dates);
     *  - a group with dates below zero, or below what its crates hold: from the loose stock without dates first, then
     *    from the loose stock of the oldest other groups with dates.
     * ['moves' => [[from key, to key, qty]], 'crates' => [['id', 'no', 'qty', 'key']], 'left' => what can not be put right]
     */
    public static function plan(array $row): array
    {
        $none = Lots::key(null, null);
        $g = [];
        foreach ($row['groups'] as $k => $x) {
            $g[$k] = ['prod' => $x['prod'], 'exp' => $x['exp'], 'stock' => (float)$x['stock'], 'crates' => (float)$x['crates']];
        }
        $g[$none] ??= ['prod' => null, 'exp' => null, 'stock' => 0.0, 'crates' => 0.0];
        uasort($g, [Lots::class, 'fifoOrder']);
        $loose = function (string $k) use (&$g): float {
            return round($g[$k]['stock'] - $g[$k]['crates'], 4);
        };
        $dated = array_values(array_filter(array_keys($g), fn($k) => $k !== $none));
        $moves = [];
        $crates = [];
        $move = function (string $from, string $to, float $q) use (&$g, &$moves): void {
            $q = round($q, 4);
            $moves[] = [$from, $to, $q];
            $g[$from]['stock'] = round($g[$from]['stock'] - $q, 4);
            $g[$to]['stock'] = round($g[$to]['stock'] + $q, 4);
        };
        // 1. the stock without dates below zero: back to zero from the loose stock with dates
        $need = round(-$g[$none]['stock'], 4);
        foreach ($dated as $k) {
            if ($need <= Crates::EPS) {
                break;
            }
            $have = $loose($k);
            if ($have > Crates::EPS) {
                $q = min($need, $have);
                $move($k, $none, $q);
                $need = round($need - $q, 4);
            }
        }
        // 2. crates without dates holding more than the stock without dates: they get the dates of the stock
        $over = round($g[$none]['crates'] - max(0.0, $g[$none]['stock']), 4);
        if ($over > Crates::EPS && $dated && Crates::ready()) {
            $list = array_values(array_filter(Crates::open((int)$row['item_id'], (int)$row['site_id']), fn($c) => !$c['production_date'] && !$c['expiry_date']));
            usort($list, fn($a, $b) => [(string)$a['received_date'], (int)$a['id']] <=> [(string)$b['received_date'], (int)$b['id']]);
            foreach ($list as $c) {
                if ($over <= Crates::EPS) {
                    break;
                }
                $q = round((float)$c['qty_left'], 4);
                $to = null;
                foreach ($dated as $k) {
                    if ($loose($k) >= $q - Crates::EPS) {
                        $to = $k;
                        break;
                    }
                }
                if ($to === null) {
                    $best = 0.0;
                    foreach ($dated as $k) {
                        if ($loose($k) > $best + Crates::EPS) {
                            [$to, $best] = [$k, $loose($k)];
                        }
                    }
                }
                if ($to === null) {
                    break;  // no stock with dates is loose: nothing to take the dates from
                }
                $crates[] = ['id' => (int)$c['id'], 'no' => (string)$c['crate_no'], 'qty' => $q, 'key' => $to];
                $g[$none]['crates'] = round($g[$none]['crates'] - $q, 4);
                $g[$to]['crates'] = round($g[$to]['crates'] + $q, 4);
                $over = round($over - $q, 4);
            }
        }
        // 3. groups with dates below zero or below their crates: from the stock without dates first, then the oldest
        foreach ($dated as $to) {
            $need = round(-$loose($to), 4);
            foreach (array_merge([$none], $dated) as $from) {
                if ($need <= Crates::EPS) {
                    break;
                }
                if ($from === $to) {
                    continue;
                }
                $have = $loose($from);
                if ($have > Crates::EPS) {
                    $q = min($need, $have);
                    $move($from, $to, $q);
                    $need = round($need - $q, 4);
                }
            }
        }
        $left = 0.0;
        foreach (array_keys($g) as $k) {
            $left += max(0.0, -$loose($k));
        }
        return ['moves' => $moves, 'crates' => $crates, 'left' => round($left, 4)];
    }

    /** v5's "Put in agreement with the crates" recorded its date changes with this memo (date changes are not editable) */
    public const V5_ALIGN_MEMO = 'Production and expiry dates put in agreement with the crates (';

    /**
     * v6: the date changes of v5's "Put in agreement with the crates" (not void) whose stock still moves kilos with
     * dates into "no dates" (what it did when crates without dates held more than the stock without dates). Only those
     * touching the site / item given. [['id', 'no', 'date', 'moves' => [['item_id', 'site_id', 'from' => key, 'qty',
     * 'line_id' => the line that put the kilos into "no dates"]], 'total'], ...]
     */
    public static function takenOff(?int $siteId = null, ?int $itemId = null): array
    {
        if (!Lots::ready()) {
            return [];
        }
        $rows = DB::all(
            "SELECT t.id, t.txn_no, t.txn_date, m.txn_line_id, l.line_no, m.item_id, m.site_id, m.production_date AS p, m.expiry_date AS e, SUM(m.qty) AS q
               FROM transactions t JOIN inventory_movements m ON m.txn_id = t.id JOIN transaction_lines l ON l.id = m.txn_line_id
              WHERE t.txn_type = 'inventory_adjustment' AND t.received_via = :dc AND t.is_voided = 0 AND t.memo LIKE :memo
              GROUP BY t.id, t.txn_no, t.txn_date, m.txn_line_id, l.line_no, m.item_id, m.site_id, m.production_date, m.expiry_date
              ORDER BY t.id, l.line_no, m.txn_line_id",
            ['dc' => Lots::DATE_CHANGE, 'memo' => self::V5_ALIGN_MEMO . '%']
        );
        $docs = [];
        $out = null;
        foreach ($rows as $r) {
            $id = (int)$r['id'];
            $q = (float)$r['q'];
            if ($q < 0) {
                $out = $r;
                continue;
            }
            // each change is a pair of lines: out of one group, into another
            if ($q > 0 && $out && (int)$out['id'] === $id && (int)$out['item_id'] === (int)$r['item_id'] && (int)$out['site_id'] === (int)$r['site_id']
                && ($out['p'] || $out['e']) && !$r['p'] && !$r['e']) {
                $m = round(min(-(float)$out['q'], $q), 4);
                $docs[$id] ??= ['id' => $id, 'no' => (string)$r['txn_no'], 'date' => (string)$r['txn_date'], 'moves' => [], 'total' => 0.0];
                $docs[$id]['moves'][] = ['item_id' => (int)$r['item_id'], 'site_id' => (int)$r['site_id'], 'from' => Lots::key($out['p'] ?: null, $out['e'] ?: null),
                    'qty' => $m, 'line_id' => (int)$r['txn_line_id']];
                $docs[$id]['total'] = round($docs[$id]['total'] + $m, 4);
            }
            $out = null;
        }
        $list = [];
        foreach ($docs as $d) {
            foreach ($d['moves'] as $m) {
                if ((!$siteId || $m['site_id'] === $siteId) && (!$itemId || $m['item_id'] === $itemId)) {
                    $list[] = $d;
                    break;
                }
            }
        }
        return $list;
    }

    /**
     * v6: stock that came in without dates on a document line that carries production or expiry dates (not a date
     * change): [['item_id', 'site_id', 'txn_id', 'line_id', 'type', 'no', 'date', 'prod', 'exp', 'qty'], ...], oldest first
     */
    public static function docDated(?int $siteId = null, ?int $itemId = null): array
    {
        if (!Lots::ready()) {
            return [];
        }
        $w = '';
        $p = ['dc' => Lots::DATE_CHANGE];
        if ($siteId) {
            $w .= ' AND m.site_id = :s';
            $p['s'] = $siteId;
        }
        if ($itemId) {
            $w .= ' AND m.item_id = :i';
            $p['i'] = $itemId;
        }
        $out = [];
        foreach (DB::all(
            "SELECT m.item_id, m.site_id, m.txn_id, m.txn_line_id, t.txn_type, t.txn_no, t.txn_date, l.production_date AS lp, l.expiry_date AS le, SUM(m.qty) AS q
               FROM inventory_movements m JOIN transaction_lines l ON l.id = m.txn_line_id JOIN transactions t ON t.id = m.txn_id JOIN items i ON i.id = m.item_id
              WHERE m.qty > 0 AND m.production_date IS NULL AND m.expiry_date IS NULL AND (l.production_date IS NOT NULL OR l.expiry_date IS NOT NULL)
                AND t.is_voided = 0 AND (t.received_via IS NULL OR t.received_via <> :dc) AND i.track_expiry = 1 $w
              GROUP BY m.item_id, m.site_id, m.txn_id, m.txn_line_id, t.txn_type, t.txn_no, t.txn_date, l.production_date, l.expiry_date
              ORDER BY t.txn_date, m.txn_id, m.txn_line_id",
            $p
        ) as $r) {
            if ((float)$r['q'] <= Crates::EPS) {
                continue;
            }
            $out[] = ['item_id' => (int)$r['item_id'], 'site_id' => (int)$r['site_id'], 'txn_id' => (int)$r['txn_id'], 'line_id' => (int)$r['txn_line_id'],
                'type' => (string)$r['txn_type'], 'no' => (string)$r['txn_no'], 'date' => (string)$r['txn_date'],
                'prod' => $r['lp'] ?: null, 'exp' => $r['le'] ?: null, 'qty' => round((float)$r['q'], 4)];
        }
        return $out;
    }

    /**
     * The documents that brought stock without dates in, newest first, with why they carry none:
     * [['txn_id', 'type', 'no', 'date', 'qty', 'why', 'url', 'fix' (v6: Take the dates from the documents puts it right)], ...]
     */
    public static function sources(int $itemId, int $siteId, int $limit = 12): array
    {
        $rows = DB::all(
            "SELECT m.txn_id, t.txn_type, t.txn_no, t.txn_date, t.account_id, t.site_id, t.site2_id, t.received_via, SUM(m.qty) AS q,
                    MAX(l.production_date) AS lp, MAX(l.expiry_date) AS le, GROUP_CONCAT(DISTINCT l.site_id) AS lsites
               FROM inventory_movements m JOIN transactions t ON t.id = m.txn_id LEFT JOIN transaction_lines l ON l.id = m.txn_line_id
              WHERE m.item_id = :i AND m.site_id = :s AND m.qty > 0 AND m.production_date IS NULL AND m.expiry_date IS NULL
              GROUP BY m.txn_id, t.txn_type, t.txn_no, t.txn_date, t.account_id, t.site_id, t.site2_id, t.received_via
              ORDER BY t.txn_date DESC, m.txn_id DESC LIMIT " . max(1, $limit),
            ['i' => $itemId, 's' => $siteId]
        );
        if (!$rows) {
            return [];
        }
        $ids = array_map(fn($r) => (int)$r['txn_id'], $rows);
        [$in, $p] = DB::in('lcs', $ids);
        $imported = [];
        foreach (DB::all("SELECT record_id, reason FROM audit_trail WHERE record_type = 'transaction' AND record_id IN $in
                           AND (reason LIKE 'Imported from CSV%' OR reason LIKE 'Opening balance imported%')", $p) as $a) {
            $imported[(int)$a['record_id']] = true;
        }
        $crated = [];
        if (Crates::ready()) {
            foreach (DB::all("SELECT receive_txn_id AS t, COUNT(*) AS n FROM crates WHERE receive_txn_id IN $in AND item_id = :item
                               AND (production_date IS NOT NULL OR expiry_date IS NOT NULL) GROUP BY receive_txn_id", $p + ['item' => $itemId]) as $c) {
                $crated[(int)$c['t']] = (int)$c['n'];
            }
        }
        $sites = Lookup::sites(false);
        $opening = (int)Accts::get('opening_equity');
        // v6: the date changes that took the dates off (v5 "Put in agreement with the crates"): the groups they took them from
        $off = [];
        foreach (self::takenOff($siteId, $itemId) as $d) {
            foreach ($d['moves'] as $m) {
                if ($m['item_id'] === $itemId && $m['site_id'] === $siteId) {
                    $off[$d['id']][$m['from']] = Lots::label(...Lots::split($m['from']));
                }
            }
        }
        $out = [];
        foreach ($rows as $r) {
            $id = (int)$r['txn_id'];
            $type = (string)$r['txn_type'];
            $fix = false;
            if (isset($off[$id])) {
                $why = 'Moved here from ' . implode(' and ', $off[$id]) . ' by "Put in agreement with the crates" of the previous version, which took the dates off stock that had them. Take the dates from the documents puts them back';
                $fix = true;
            } elseif ($r['received_via'] === Lots::DATE_CHANGE) {
                $why = 'Moved here by a date change';
            } elseif ($r['lp'] || $r['le']) {
                $why = 'The document carries ' . Lots::label($r['lp'] ?: null, $r['le'] ?: null) . ' on the line, but the stock was recorded without them. Take the dates from the documents gives them';
                $fix = true;
            } elseif (isset($imported[$id])) {
                $why = $type === 'inventory_adjustment' ? 'Opening quantity imported from a spreadsheet, which had no date columns before this version'
                    : 'Imported from a spreadsheet, which had no date columns before this version';
            } elseif (isset($crated[$id])) {
                $why = 'Came in or was filled in ' . $crated[$id] . ' crate' . ($crated[$id] === 1 ? '' : 's') . ' that carry dates; the stock was recorded without them before this version';
            } elseif ($type === 'opening_balance' || ($type === 'inventory_adjustment' && (int)$r['account_id'] === $opening)) {
                $why = 'Opening quantity entered without dates';
            } elseif (in_array($type, ['inventory_transfer', 'inventory_dispatch'], true)) {
                // v8: a dispatch may have gathered it from many sites: the sites of its lines
                $from = array_filter(array_map('intval', explode(',', (string)($r['lsites'] ?? ''))), fn($x) => $x && $x !== $siteId) ?: [(int)$r['site_id']];
                $why = 'Arrived from ' . implode(' and ', array_map(fn($x) => $sites[$x] ?? 'another site', $from)) . ' in stock that had no dates there';
            } elseif (in_array($type, ['credit_memo', 'pos_return'], true)) {
                $why = 'Returned by a customer without dates';
            } elseif (in_array($type, ['build_assembly', Processing::TXN_TYPE], true)) {
                $why = 'Made without dates';
            } elseif ($type === 'inventory_adjustment') {
                $why = 'Added on an adjustment without dates';
            } else {
                $why = 'Received without production and expiry dates (date tracking off, or the item marked as not expiring, at the time)';
            }
            $t = ['id' => $id, 'txn_type' => $type, 'txn_no' => $r['txn_no']];
            $out[] = ['txn_id' => $id, 'type' => Txn::label($type), 'no' => (string)$r['txn_no'], 'date' => (string)$r['txn_date'],
                'qty' => round((float)$r['q'], 4), 'why' => $why, 'url' => Txn::url($t), 'fix' => $fix];
        }
        return $out;
    }

    /**
     * Records a change of production / expiry dates at one site: one inventory adjustment (Lots::DATE_CHANGE) with a
     * pair of lines for each move, [['item_id', 'qty', 'from' => [prod, exp], 'to' => [prod, exp], 'crates' => ?pack data]].
     * Returns the adjustment's id.
     */
    public static function changeDates(int $siteId, string $date, array $moves, string $memo, string $reason): int
    {
        if (!$moves) {
            fail('There is nothing to change.');
        }
        if (!Access::siteAllowed($siteId)) {
            fail('You are not allowed to change the stock of that site.');
        }
        $lines = [];
        foreach ($moves as $m) {
            $iid = (int)$m['item_id'];
            $q = round((float)$m['qty'], 4);
            [$fp, $fe] = [$m['from'][0] ?? null, $m['from'][1] ?? null];
            [$tp, $te] = [$m['to'][0] ?? null, $m['to'][1] ?? null];
            if ($q <= Crates::EPS || !$iid) {
                continue;
            }
            $it = DB::row('SELECT code, name FROM items WHERE id = :i', ['i' => $iid]) ?: ['code' => 'an item', 'name' => ''];
            if (Lots::key($fp, $fe) === Lots::key($tp, $te)) {
                fail('The new dates of ' . $it['code'] . ' are the dates it already has.');
            }
            $name = (string)$it['name'];
            $lines[] = ['line_kind' => 'item', 'item_id' => $iid, 'qty' => -$q, 'rate' => 0, 'value_change' => 0, 'site_id' => $siteId,
                'description' => mb_substr($name . ': out of ' . Lots::label($fp, $fe), 0, 255), 'production_date' => $fp, 'expiry_date' => $fe];
            $line = ['line_kind' => 'item', 'item_id' => $iid, 'qty' => $q, 'rate' => 0, 'value_change' => 0, 'site_id' => $siteId,
                'description' => mb_substr($name . ': into ' . Lots::label($tp, $te), 0, 255), 'production_date' => $tp, 'expiry_date' => $te];
            if (!empty($m['crates'])) {
                $line['_crates'] = $m['crates'];
            }
            $lines[] = $line;
        }
        if (!$lines) {
            fail('There is nothing to change.');
        }
        return Txn::save('inventory_adjustment', [
            'txn_date' => $date, 'site_id' => $siteId, 'account_id' => Accts::get('inventory_adjustment'),
            'memo' => mb_substr($memo, 0, 255), 'status' => 'open', 'received_via' => Lots::DATE_CHANGE,
        ], $lines, null, ['reason' => $reason]);
    }

    /**
     * Puts the date groups of the rows given in agreement with their crates (v6: plan()): one date change per site for
     * the quantities moved, and the crates without dates that get the dates of their stock.
     * ['docs' => [adjustment ids], 'crates' => number of crates given dates, 'qty' => kilos moved, 'left' => what can not be put right]
     */
    public static function align(array $rows, string $date): array
    {
        $bySite = [];
        $crates = [];
        $left = 0.0;
        $qty = 0.0;
        foreach ($rows as $row) {
            $p = self::plan($row);
            foreach ($p['moves'] as [$from, $to, $q]) {
                $bySite[$row['site_id']][] = ['item_id' => $row['item_id'], 'qty' => $q, 'from' => Lots::split($from), 'to' => Lots::split($to)];
                $qty += $q;
            }
            foreach ($p['crates'] as $c) {
                $crates[] = $c + ['item_id' => (int)$row['item_id'], 'site_id' => (int)$row['site_id']];
            }
            $left += $p['left'];
        }
        return DB::tx(function () use ($bySite, $crates, $left, $qty, $date) {
            $n = 0;
            foreach ($crates as $c) {
                $n += self::dateCrate($c, $date) ? 1 : 0;
            }
            $ids = [];
            foreach ($bySite as $siteId => $moves) {
                $items = count(array_unique(array_column($moves, 'item_id')));
                $ids[] = self::changeDates((int)$siteId, $date, $moves,
                    'Production and expiry dates of the stock put in agreement with its crates (' . $items . ' item' . ($items === 1 ? '' : 's') . ')',
                    'The stock of each date group set to what its crates hold, without taking dates off stock that has them');
            }
            return ['docs' => $ids, 'crates' => $n, 'qty' => round($qty, 4), 'left' => round($left, 4)];
        });
    }

    /** v6: a crate without dates given the dates of the stock it holds (no stock moves: the crate follows its stock) */
    private static function dateCrate(array $c, string $date): bool
    {
        $cur = DB::row('SELECT c.*, i.code FROM crates c JOIN items i ON i.id = c.item_id WHERE c.id = :id FOR UPDATE', ['id' => $c['id']]);
        if (!$cur || $cur['status'] !== 'open' || $cur['production_date'] || $cur['expiry_date']) {
            return false;
        }
        [$p, $e] = Lots::split($c['key']);
        DB::update('crates', ['production_date' => $p, 'expiry_date' => $e], 'id = :id', ['id' => (int)$cur['id']]);
        DB::insert('crate_movements', [
            'crate_id' => (int)$cur['id'], 'move_date' => $date, 'kind' => 'dates', 'qty' => 0, 'site_id' => (int)$cur['site_id'],
            'note' => mb_substr('Given ' . Lots::label($p, $e) . ': the stock it holds carries these dates, the crate had none', 0, 255), 'created_by' => Auth::id(),
        ]);
        Audit::log('crate_dates', 'inv', 'crate', (int)$cur['id'], 'Crate ' . $cur['crate_no'] . ' (' . $cur['code'] . ')', [
            'reason' => 'Crate without dates given ' . Lots::label($p, $e) . ', the dates of the stock it holds', 'amount' => (float)$cur['qty_left'],
            'page_key' => 'inv.lot_check', 'site_id' => (int)$cur['site_id'],
            'changes' => [['field' => 'production_date', 'old' => null, 'new' => $p], ['field' => 'expiry_date', 'old' => null, 'new' => $e]],
        ]);
        return true;
    }

    /**
     * v6: Take the dates from the documents, for one item / site or all of them. What the stock records is put back to
     * what the documents say, at the source, so it is never done twice:
     *  1. each date change of v5's "Put in agreement with the crates" that took dates off is voided (when its period is
     *     closed, it is signed or something blocks it, the kilos it put into "no dates" are given back the dates they
     *     came out of, which leaves the change moving them from a group to the same group);
     *  2. stock received without dates on a document line that carries dates is given the dates of that line, and so
     *     are the open crates without dates received on that line;
     *  3. every item touched is put in agreement with its crates (plan()): what has since left the stock without dates
     *     (now below zero) comes back to zero from the stock with dates, crates without dates get the dates of their
     *     stock.
     * Steps 1 and 2 change no quantity and no value. ['voided' => [ids], 'relabeled' => document lines, 'docs' =>
     * [date change ids of step 3], 'qty' => kilos that got their dates back, 'items' => how many items, 'units' => [unit =>
     * qty], 'crates' => crates given dates, 'left']
     */
    public static function repair(?int $siteId, ?int $itemId, string $date): array
    {
        if (!Lots::on()) {
            fail('Production and expiry dates are not kept: switch on date tracking first.');
        }
        return DB::tx(function () use ($siteId, $itemId, $date) {
            $done = ['voided' => [], 'relabeled' => 0, 'docs' => [], 'qty' => 0.0, 'crates' => 0, 'left' => 0.0, 'items' => [], 'units' => []];
            $touched = [];
            $got = function (int $item, float $q) use (&$done): void {
                if ($q <= Crates::EPS) {
                    return;
                }
                $done['qty'] += $q;
                $done['items'][$item] = true;
                $u = Crates::baseUnit($item);
                $done['units'][$u] = round(($done['units'][$u] ?? 0.0) + $q, 4);
            };
            foreach (self::takenOff($siteId, $itemId) as $d) {
                if (self::voidable($d['id'])) {
                    foreach (DB::all('SELECT DISTINCT item_id, site_id FROM inventory_movements WHERE txn_id = :t', ['t' => $d['id']]) as $m) {
                        $touched[$m['item_id'] . ':' . $m['site_id']] = [(int)$m['item_id'], (int)$m['site_id']];
                    }
                    Txn::void($d['id'], 'It took the production and expiry dates off stock that had them (a fault of the previous version); voided by Take the dates from the documents');
                    $done['voided'][] = $d['id'];
                    foreach ($d['moves'] as $m) {
                        $got($m['item_id'], $m['qty']);
                    }
                    continue;
                }
                foreach ($d['moves'] as $m) {
                    if (!Access::siteAllowed($m['site_id'])) {
                        continue;
                    }
                    $got($m['item_id'], self::relabel($m['line_id'], $m['item_id'], $m['site_id'], Lots::split($m['from']),
                        'Put back to ' . Lots::label(...Lots::split($m['from'])) . ', the dates "Put in agreement with the crates" of the previous version took off'));
                    $touched[$m['item_id'] . ':' . $m['site_id']] = [$m['item_id'], $m['site_id']];
                }
            }
            foreach (self::docDated($siteId, $itemId) as $r) {
                if (!Access::siteAllowed($r['site_id'])) {
                    continue;
                }
                $dates = [$r['prod'], $r['exp']];
                $q = self::relabel($r['line_id'], $r['item_id'], $r['site_id'], $dates, 'Given ' . Lots::label(...$dates) . ', the dates its line carries');
                if ($q > Crates::EPS) {
                    $got($r['item_id'], $q);
                    $done['relabeled']++;
                }
                // the open crates without dates received on that line carry the line's dates too
                if (Crates::ready()) {
                    foreach (DB::column("SELECT id FROM crates WHERE receive_line_id = :l AND item_id = :i AND site_id = :s AND status = 'open'
                                          AND production_date IS NULL AND expiry_date IS NULL", ['l' => $r['line_id'], 'i' => $r['item_id'], 's' => $r['site_id']]) as $cid) {
                        $done['crates'] += self::dateCrate(['id' => (int)$cid, 'key' => Lots::key(...$dates)], $date) ? 1 : 0;
                    }
                }
                $touched[$r['item_id'] . ':' . $r['site_id']] = [$r['item_id'], $r['site_id']];
            }
            // each group in agreement with its crates: the rows asked for, and every item the steps above touched
            $rows = [];
            foreach (self::overview($siteId, $itemId) as $r) {
                $rows[$r['item_id'] . ':' . $r['site_id']] = $r;
            }
            foreach ($touched as $k => [$i, $s]) {
                if (!isset($rows[$k]) && Access::siteAllowed($s)) {
                    foreach (self::overview($s, $i) as $r) {
                        $rows[$r['item_id'] . ':' . $r['site_id']] = $r;
                    }
                }
            }
            $rows = array_filter($rows, fn($r) => $r['deficit'] > Crates::EPS);
            if ($rows) {
                $a = self::align(array_values($rows), $date);
                $done['docs'] = $a['docs'];
                $done['crates'] += $a['crates'];
                $done['left'] = $a['left'];
            }
            $done['qty'] = round($done['qty'], 4);
            $done['items'] = count($done['items']);
            return $done;
        });
    }

    /**
     * v6: the stock a document line brought in without dates given the dates it should carry, where it is recorded
     * (its movements): no quantity or value changes, the stock simply shows in its own date group, and keeps it through
     * Rebuild Data and recosting. Returns the quantity.
     */
    private static function relabel(int $lineId, int $itemId, int $siteId, array $dates, string $why): float
    {
        [$p, $e] = [$dates[0] ?? null, $dates[1] ?? null];
        if (!$p && !$e) {
            return 0.0;
        }
        $w = 'txn_line_id = :l AND item_id = :i AND site_id = :s AND qty > 0 AND production_date IS NULL AND expiry_date IS NULL';
        $par = ['l' => $lineId, 'i' => $itemId, 's' => $siteId];
        $q = round((float)DB::value("SELECT COALESCE(SUM(qty), 0) FROM inventory_movements WHERE $w", $par), 4);
        if ($q <= Crates::EPS) {
            return 0.0;
        }
        DB::run("UPDATE inventory_movements SET production_date = :p, expiry_date = :e WHERE $w", $par + ['p' => $p, 'e' => $e]);
        $t = DB::row('SELECT t.id, t.txn_type, t.txn_no, t.site_id, i.code FROM transaction_lines l JOIN transactions t ON t.id = l.txn_id JOIN items i ON i.id = :i2 WHERE l.id = :l',
            ['l' => $lineId, 'i2' => $itemId]);
        if ($t) {
            Audit::log('lot_dates', 'inv', 'transaction', (int)$t['id'], Txn::ref($t), [
                'reason' => mb_substr($t['code'] . ': ' . qty($q) . ' ' . $why, 0, 255), 'amount' => $q, 'page_key' => 'inv.lot_check', 'site_id' => $siteId,
                'changes' => [['field' => 'production_date', 'old' => null, 'new' => $p], ['field' => 'expiry_date', 'old' => null, 'new' => $e]],
            ]);
        }
        return $q;
    }

    /** v6: whether the repair can void a date change: its period is open, it is not signed, nothing blocks it */
    private static function voidable(int $id): bool
    {
        $t = Txn::load($id);
        if (!$t || (int)$t['is_voided'] === 1) {
            return false;
        }
        try {
            Txn::assertPeriod(null, $t);
            Signatures::assertUnlocked($t, 'voided');
        } catch (UserError $e) {
            return false;
        }
        return !Txn::blockers($t, false);
    }
}
