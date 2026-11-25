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
 * with what the open crates of that group hold. Stock in a crate whose date group does not have it, and a group
 * below zero, are put right by moving the quantity from the loose stock of another group: the group without dates
 * first (where those kilos were recorded), then the oldest.
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
     * What puts the date groups of one item at one site in agreement with its crates: [[from key, to key, qty], ...].
     * Each group short of what its crates hold (or below zero) gets it from the loose stock of the other groups,
     * the group without dates first, then the oldest.
     */
    public static function alignMoves(array $row): array
    {
        $short = [];
        $spare = [];
        foreach ($row['groups'] as $k => $g) {
            if ($g['loose'] < -Crates::EPS) {
                $short[$k] = -$g['loose'];
            } elseif ($g['loose'] > Crates::EPS) {
                $spare[$k] = $g['loose'];
            }
        }
        $moves = [];
        foreach ($short as $to => $need) {
            foreach ($spare as $from => $have) {
                if ($need <= Crates::EPS) {
                    break;
                }
                if ($have <= Crates::EPS) {
                    continue;
                }
                $m = round(min($need, $have), 4);
                $moves[] = [$from, $to, $m];
                $spare[$from] = round($have - $m, 4);
                $need = round($need - $m, 4);
            }
        }
        return $moves;
    }

    /**
     * The documents that brought stock without dates in, newest first, with why they carry none:
     * [['txn_id', 'type', 'no', 'date', 'qty', 'why', 'url'], ...]
     */
    public static function sources(int $itemId, int $siteId, int $limit = 12): array
    {
        $rows = DB::all(
            "SELECT m.txn_id, t.txn_type, t.txn_no, t.txn_date, t.account_id, t.site_id, t.site2_id, t.received_via, SUM(m.qty) AS q
               FROM inventory_movements m JOIN transactions t ON t.id = m.txn_id
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
        $out = [];
        foreach ($rows as $r) {
            $id = (int)$r['txn_id'];
            $type = (string)$r['txn_type'];
            if (isset($imported[$id])) {
                $why = $type === 'inventory_adjustment' ? 'Opening quantity imported from a spreadsheet, which had no date columns before this version'
                    : 'Imported from a spreadsheet, which had no date columns before this version';
            } elseif (isset($crated[$id])) {
                $why = 'Came in or was filled in ' . $crated[$id] . ' crate' . ($crated[$id] === 1 ? '' : 's') . ' that carry dates; the stock was recorded without them before this version';
            } elseif ($type === 'opening_balance' || ($type === 'inventory_adjustment' && (int)$r['account_id'] === $opening)) {
                $why = 'Opening quantity entered without dates';
            } elseif (in_array($type, ['inventory_transfer', 'inventory_dispatch'], true)) {
                $why = 'Arrived from ' . ($sites[(int)$r['site_id']] ?? 'another site') . ' in stock that had no dates there';
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
                'qty' => round((float)$r['q'], 4), 'why' => $why, 'url' => Txn::url($t)];
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

    /** Puts the date groups of the rows given in agreement with their crates: one date change per site. Returns the ids. */
    public static function align(array $rows, string $date): array
    {
        $bySite = [];
        foreach ($rows as $row) {
            foreach (self::alignMoves($row) as [$from, $to, $q]) {
                $bySite[$row['site_id']][] = ['item_id' => $row['item_id'], 'qty' => $q, 'from' => Lots::split($from), 'to' => Lots::split($to)];
            }
        }
        $ids = [];
        foreach ($bySite as $siteId => $moves) {
            $items = count(array_unique(array_column($moves, 'item_id')));
            $ids[] = self::changeDates((int)$siteId, $date, $moves,
                'Production and expiry dates put in agreement with the crates (' . $items . ' item' . ($items === 1 ? '' : 's') . ')',
                'The stock of each date group set to what its crates hold');
        }
        return $ids;
    }
}
