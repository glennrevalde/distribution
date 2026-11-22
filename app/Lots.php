<?php
declare(strict_types=1);

/**
 * v43: production and expiry dates of inventory (perishable goods).
 *
 * A "date group" is the stock of an item at a site that has the same production date and expiry date. The dates
 * live on the transaction lines (transaction_lines.production_date / expiry_date) and on the inventory movements
 * the lines post (inventory_movements), so the quantity of each date group is the total of its movements, exactly
 * as the quantity on hand of an item is (Stock). The weighted-average cost does not change: it stays per item.
 *
 *  - Stock coming in (Receive Items, Receive Items and Enter Bills, Enter Bills, Write Checks, credit memo returns,
 *    POS returns, adjustments up, builds, processing outputs) carries the dates typed on its line; when tracking is
 *    switched on they are required on purchases and adjustments up.
 *  - Stock going out takes the date group chosen on its line (invoices, sales receipts, batch invoices, the POS,
 *    supplier debit memos, adjustments down, transfers); when none is chosen, or for stock used automatically (the
 *    items of an item group, the FB POS, build components, processing inputs), it is taken first in, first out:
 *    stock with no dates first (received before tracking started), then the oldest production date, then the
 *    earliest expiry date (Stock::move splits the movement over the groups).
 *  - A transfer keeps the dates: what leaves one site in a date group arrives at the other site in the same group.
 *
 * Tracking is switched on in System Administration > Company, Security & Closing Date > Inventory and POS
 * ("Track inventory production date and expiry date"); an item can be marked as not expiring on the Item List.
 */
final class Lots
{
    /** database name => the columns are there (migration 2027_02_18) */
    private static array $ready = [];
    private static array $itemFlag = [];

    public static function ready(): bool
    {
        $db = DB::databaseName();
        if (!isset(self::$ready[$db])) {
            try {
                DB::value('SELECT COUNT(production_date) + COUNT(expiry_date) FROM inventory_movements WHERE 1 = 0');
                DB::value('SELECT COUNT(production_date) FROM transaction_lines WHERE 1 = 0');
                DB::value('SELECT COUNT(track_expiry) FROM items WHERE 1 = 0');
                self::$ready[$db] = true;
            } catch (Throwable $e) {
                self::$ready[$db] = false;
            }
        }
        return self::$ready[$db];
    }

    /** Tracking is switched on for the company */
    public static function on(): bool
    {
        return self::ready() && Settings::get('track_expiry', '0') === '1';
    }

    /** The item keeps production and expiry dates (an inventory part or assembly that is not marked as not expiring) */
    public static function itemTracked(?int $itemId): bool
    {
        if (!$itemId || !self::on()) {
            return false;
        }
        if (!array_key_exists($itemId, self::$itemFlag)) {
            $r = DB::row('SELECT item_type, track_expiry FROM items WHERE id = :id', ['id' => $itemId]);
            self::$itemFlag[$itemId] = $r && Stock::isTracked((string)$r['item_type']) && (int)$r['track_expiry'] === 1;
        }
        return self::$itemFlag[$itemId];
    }

    /** item id => true for the items of a list that keep dates (one query) */
    public static function trackedIds(array $itemIds): array
    {
        $itemIds = array_values(array_unique(array_filter(array_map('intval', $itemIds))));
        if (!$itemIds || !self::on()) {
            return [];
        }
        $out = [];
        foreach (array_chunk($itemIds, 500) as $chunk) {
            [$in, $p] = DB::in('lti', $chunk);
            foreach (DB::column("SELECT id FROM items WHERE id IN $in AND item_type IN ('inventory','assembly') AND track_expiry = 1", $p) as $id) {
                $out[(int)$id] = true;
                self::$itemFlag[(int)$id] = true;
            }
        }
        return $out;
    }

    public static function flush(): void
    {
        self::$itemFlag = [];
    }

    /** Days before expiry when stock counts as "expiring" (settings) */
    public static function warnDays(): int
    {
        return max(0, (int)Settings::get('expiry_warn_days', '30'));
    }

    /** Expired stock may not be sold (settings) */
    public static function blockExpired(): bool
    {
        return self::on() && Settings::get('block_expired_sales', '0') === '1';
    }

    // ------------------------------------------------------------------ dates

    /** A date typed on a form, or null; fails on a date that is not a date */
    public static function date($v, string $what): ?string
    {
        $v = trim((string)$v);
        if ($v === '') {
            return null;
        }
        if (!valid_date($v)) {
            fail('Enter a valid ' . $what . '.');
        }
        return $v;
    }

    /**
     * Checks the dates of a line: both required ($required), expiry not before production, production not later
     * than the transaction date (it cannot be produced after it was received).
     */
    public static function check(?string $prod, ?string $exp, string $itemLabel, bool $required, ?string $txnDate = null): void
    {
        if ($required && (!$prod || !$exp)) {
            fail('Enter the production date and the expiry date of ' . $itemLabel . '.');
        }
        if ($prod && $exp && $exp < $prod) {
            fail('The expiry date of ' . $itemLabel . ' (' . fdate($exp) . ') is before its production date (' . fdate($prod) . ').');
        }
        if ($prod && $txnDate && $prod > $txnDate) {
            fail('The production date of ' . $itemLabel . ' (' . fdate($prod) . ') is after the date of the transaction (' . fdate($txnDate) . ').');
        }
    }

    /** "prod|exp" (empty parts for no date): the key of a date group */
    public static function key(?string $prod, ?string $exp): string
    {
        return ($prod ?? '') . '|' . ($exp ?? '');
    }

    /** [prod, exp] from a key */
    public static function split(string $key): array
    {
        $p = explode('|', $key . '|');
        return [valid_date($p[0]) ? $p[0] : null, valid_date($p[1]) ? $p[1] : null];
    }

    /** "Prod. 10/01/2026, Exp. 12/01/2026", or "No dates" */
    public static function label(?string $prod, ?string $exp): string
    {
        if (!$prod && !$exp) {
            return 'No dates';
        }
        return trim(($prod ? 'Prod. ' . fdate($prod) : '') . ($prod && $exp ? ', ' : '') . ($exp ? 'Exp. ' . fdate($exp) : ''));
    }

    /**
     * The words of a date group in a list to pick from, the expiry first (what the choice turns on):
     * "Exp. 12/01/2026 (prod. 10/01/2026): 24 on hand, expires in 9 days"
     */
    public static function pickText(array $g, bool $withQty = true): string
    {
        $prod = $g['prod'] ?? null;
        $exp = $g['exp'] ?? null;
        $t = !$prod && !$exp ? 'No dates' : ($exp ? 'Exp. ' . fdate($exp) . ($prod ? ' (prod. ' . fdate($prod) . ')' : '') : 'Prod. ' . fdate($prod));
        if ($withQty) {
            $t .= ': ' . qty($g['qty']) . ' on hand';
        }
        $st = $g['status'] ?? self::status($exp);
        $days = $g['days'] ?? self::daysLeft($exp);
        if ($st === 'expired') {
            $t .= ', expired';
        } elseif ($st === 'expiring' && $days !== null) {
            $t .= ', expires ' . ($days === 0 ? 'today' : 'in ' . $days . ' day' . ($days === 1 ? '' : 's'));
        }
        return $t;
    }

    /** expired, expiring (within the warning days) or ok (no expiry date: ok) */
    public static function status(?string $exp, ?string $asof = null): string
    {
        if (!$exp) {
            return 'ok';
        }
        $asof ??= today();
        if ($exp < $asof) {
            return 'expired';
        }
        return $exp <= date('Y-m-d', strtotime($asof . ' +' . self::warnDays() . ' days')) ? 'expiring' : 'ok';
    }

    /** Days from a date to the expiry date (negative once expired) */
    public static function daysLeft(?string $exp, ?string $asof = null): ?int
    {
        return $exp ? (int)round((strtotime($exp) - strtotime($asof ?? today())) / 86400) : null;
    }

    // ------------------------------------------------------------------ quantities

    /**
     * The date groups of an item at a site with their quantity on hand, first in first out (no dates first, then
     * oldest production date, then earliest expiry date). $excludeTxnId: leave out the movements of the transaction
     * being edited. $all: also the groups at zero (never those below 0.00005 when false).
     * @return array<int, array{prod: ?string, exp: ?string, key: string, qty: float}>
     */
    public static function available(int $itemId, int $siteId, ?int $excludeTxnId = null, bool $all = false): array
    {
        if (!self::ready()) {
            return [];
        }
        $sql = 'SELECT production_date AS p, expiry_date AS e, SUM(qty) AS q FROM inventory_movements WHERE item_id = :i AND site_id = :s';
        $par = ['i' => $itemId, 's' => $siteId];
        if ($excludeTxnId) {
            $sql .= ' AND txn_id <> :x';
            $par['x'] = $excludeTxnId;
        }
        $rows = DB::all($sql . ' GROUP BY production_date, expiry_date', $par);
        $out = [];
        foreach ($rows as $r) {
            $q = round((float)$r['q'], 4);
            if (!$all && $q < 0.00005) {
                continue;
            }
            $out[] = ['prod' => $r['p'] ?: null, 'exp' => $r['e'] ?: null, 'key' => self::key($r['p'] ?: null, $r['e'] ?: null), 'qty' => $q];
        }
        usort($out, [self::class, 'fifoOrder']);
        return $out;
    }

    /** First in, first out: no dates first, then the oldest production date, then the earliest expiry date */
    public static function fifoOrder(array $a, array $b): int
    {
        $da = ($a['prod'] || $a['exp']) ? 1 : 0;
        $db = ($b['prod'] || $b['exp']) ? 1 : 0;
        return [$da, $a['prod'] ?? '9999-12-31', $a['exp'] ?? '9999-12-31'] <=> [$db, $b['prod'] ?? '9999-12-31', $b['exp'] ?? '9999-12-31'];
    }

    /** The quantity of one date group of an item at a site */
    public static function qty(int $itemId, int $siteId, ?string $prod, ?string $exp, ?int $excludeTxnId = null): float
    {
        $sql = 'SELECT COALESCE(SUM(qty),0) FROM inventory_movements WHERE item_id = :i AND site_id = :s AND '
            . ($prod ? 'production_date = :p' : 'production_date IS NULL') . ' AND ' . ($exp ? 'expiry_date = :e' : 'expiry_date IS NULL');
        $par = ['i' => $itemId, 's' => $siteId];
        if ($prod) {
            $par['p'] = $prod;
        }
        if ($exp) {
            $par['e'] = $exp;
        }
        if ($excludeTxnId) {
            $sql .= ' AND txn_id <> :x';
            $par['x'] = $excludeTxnId;
        }
        return round((float)DB::value($sql, $par), 4);
    }

    /**
     * How a quantity going out is split over the date groups, first in first out: [[prod, exp, qty], ...] with qty
     * positive. What the groups do not cover goes to the last group taken (or to "no dates" when there is none),
     * which then shows below zero, as stock sold below zero does. With $skipExpiredBefore (a date), the groups that
     * expired before it are passed over. $reserved (key => qty, v44): what other lines of the document will take from
     * the groups they name, left for them.
     */
    public static function fifo(int $itemId, int $siteId, float $qty, ?string $skipExpiredBefore = null, array $reserved = []): array
    {
        $need = round(abs($qty), 4);
        $out = [];
        foreach (self::available($itemId, $siteId) as $g) {
            if ($need < 0.00005) {
                break;
            }
            // v44: what other lines of the same document take from a group they name is not offered here
            if (!empty($reserved[$g['key']])) {
                $g['qty'] = round($g['qty'] - (float)$reserved[$g['key']], 4);
                if ($g['qty'] < 0.00005) {
                    continue;
                }
            }
            // expired stock that may not be sold is passed over (a sale with "Do not allow selling stock that has expired")
            if ($skipExpiredBefore && $g['exp'] && $g['exp'] < $skipExpiredBefore) {
                continue;
            }
            $take = min($need, $g['qty']);
            $out[] = [$g['prod'], $g['exp'], round($take, 4)];
            $need = round($need - $take, 4);
        }
        if ($need >= 0.00005) {
            if ($out) {
                $out[array_key_last($out)][2] = round($out[array_key_last($out)][2] + $need, 4);
            } else {
                $out[] = [null, null, $need];
            }
        }
        return $out;
    }

    /**
     * Fails when a line takes more of its chosen date group than the site has, unless stock may go below zero
     * (settings); and when the group has expired and expired stock may not be sold.
     */
    public static function checkOut(int $itemId, int $siteId, ?string $prod, ?string $exp, float $qty, string $itemLabel, ?int $excludeTxnId = null, bool $isSale = false): void
    {
        if ($qty <= 0 || (!$prod && !$exp)) {
            return;
        }
        if ($isSale && self::blockExpired() && $exp && $exp < today()) {
            fail($itemLabel . ': the stock with ' . self::label($prod, $exp) . ' has expired and may not be sold.');
        }
        $have = self::qty($itemId, $siteId, $prod, $exp, $excludeTxnId);
        if ($have + 0.00005 < $qty && Settings::get('allow_negative_stock', '1') !== '1') {
            fail($itemLabel . ': only ' . qty(max(0, $have)) . ' left with ' . self::label($prod, $exp) . ' at this site. Choose another date group or a smaller quantity.');
        }
    }

    /**
     * v44: a sale may not take more of a date group than the site holds of it, whatever the negative-stock setting:
     * the quantity sold of each line is at most the balance of its production / expiry date group, and the rest is
     * sold on another line with another date group. Lines left to first in, first out take what the groups named by
     * the other lines leave, and together may not take more than that (expired stock not counted when it may not be
     * sold). $lines are the parsed lines of one document (qty in base units); lines without a site take $siteId.
     */
    public static function checkSaleLines(array $lines, ?int $siteId, ?int $excludeTxnId = null, ?string $txnDate = null): void
    {
        if (!self::on()) {
            return;
        }
        $named = [];
        $free = [];
        foreach ($lines as $l) {
            $iid = (int)($l['item_id'] ?? 0);
            $q = round((float)($l['qty'] ?? 0), 4);
            $site = (int)($l['site_id'] ?? 0) ?: (int)$siteId;
            if (!$iid || $q <= 0 || !$site || !self::itemTracked($iid)) {
                continue;
            }
            $k = $iid . ':' . $site;
            if (!empty($l['production_date']) || !empty($l['expiry_date'])) {
                $key = self::key($l['production_date'] ?: null, $l['expiry_date'] ?: null);
                $named[$k][$key] = round(($named[$k][$key] ?? 0.0) + $q, 4);
            } else {
                $free[$k] = round(($free[$k] ?? 0.0) + $q, 4);
            }
        }
        $day = $txnDate ?: today();
        $sites = Lookup::sites(false);
        foreach (array_unique(array_merge(array_keys($named), array_keys($free))) as $k) {
            [$iid, $site] = array_map('intval', explode(':', $k));
            $code = (string)(item_cache($iid)['code'] ?? 'An item');
            $where = $sites[$site] ?? 'this site';
            $have = [];
            $groups = [];
            foreach (self::available($iid, $site, $excludeTxnId) as $g) {
                $have[$g['key']] = $g['qty'];
                $groups[$g['key']] = $g;
            }
            foreach ($named[$k] ?? [] as $key => $q) {
                $h = $have[$key] ?? 0.0;
                if ($q > $h + 0.00005) {
                    [$p, $e] = self::split($key);
                    fail($code . ': only ' . qty(max(0, $h)) . ' left with ' . self::label($p, $e) . ' at ' . $where . ', and this sale takes ' . qty($q)
                        . '. Sell up to ' . qty(max(0, $h)) . ' from this date group and put the rest on another line with another expiry date.');
                }
                $have[$key] = round($h - $q, 4);
            }
            $want = $free[$k] ?? 0.0;
            if ($want > 0) {
                $left = 0.0;
                $expired = 0.0;
                foreach ($have as $key => $q) {
                    $g = $groups[$key] ?? null;
                    if ($g && $g['exp'] && $g['exp'] < $day && self::blockExpired()) {
                        $expired += max(0, $q);
                        continue;
                    }
                    $left += max(0, $q);
                }
                if ($want > $left + 0.00005) {
                    fail($code . ': only ' . qty($left) . ' left at ' . $where . ' in all its date groups' . ($expired > 0.00005 ? ' that have not expired' : '')
                        . ', and this sale takes ' . qty($want) . ' first in, first out. Sell at most the balance of each production and expiry date.');
                }
            }
        }
    }

    /**
     * The date groups of several items at a site, for the forms and the POS:
     * item id => [[key, prod, exp, qty, label, status, days], ...] (only groups with stock).
     */
    public static function forItems(array $itemIds, int $siteId, ?int $excludeTxnId = null): array
    {
        $ids = array_keys(self::trackedIds($itemIds));
        if (!$ids) {
            return [];
        }
        [$in, $p] = DB::in('lfi', $ids);
        $p['s'] = $siteId;
        $sql = "SELECT item_id, production_date AS pd, expiry_date AS ed, SUM(qty) AS q FROM inventory_movements WHERE item_id IN $in AND site_id = :s";
        if ($excludeTxnId) {
            $sql .= ' AND txn_id <> :x';
            $p['x'] = $excludeTxnId;
        }
        $out = [];
        foreach (DB::all($sql . ' GROUP BY item_id, production_date, expiry_date HAVING SUM(qty) >= 0.00005', $p) as $r) {
            $prod = $r['pd'] ?: null;
            $exp = $r['ed'] ?: null;
            $out[(int)$r['item_id']][] = ['key' => self::key($prod, $exp), 'prod' => $prod, 'exp' => $exp, 'qty' => round((float)$r['q'], 4),
                'label' => self::label($prod, $exp), 'status' => self::status($exp), 'days' => self::daysLeft($exp)];
            $out[(int)$r['item_id']][array_key_last($out[(int)$r['item_id']])]['text'] = self::pickText(end($out[(int)$r['item_id']]));
        }
        foreach ($out as &$groups) {
            usort($groups, [self::class, 'fifoOrder']);
        }
        unset($groups);
        return $out;
    }

    /**
     * The production / expiry date group a sold line took, for a return of it: the line's own dates, or the dated group
     * most of its stock came from (first in, first out). [prod, exp] (both null: no dates).
     */
    public static function ofLine(int $lineId): array
    {
        if (!self::ready() || !$lineId) {
            return [null, null];
        }
        $l = DB::row('SELECT production_date, expiry_date FROM transaction_lines WHERE id = :id', ['id' => $lineId]);
        if ($l && ($l['production_date'] || $l['expiry_date'])) {
            return [$l['production_date'] ?: null, $l['expiry_date'] ?: null];
        }
        $g = DB::row('SELECT production_date, expiry_date FROM inventory_movements WHERE txn_line_id = :l AND (production_date IS NOT NULL OR expiry_date IS NOT NULL)
                       GROUP BY production_date, expiry_date ORDER BY ABS(SUM(qty)) DESC LIMIT 1', ['l' => $lineId]);
        return $g ? [$g['production_date'] ?: null, $g['expiry_date'] ?: null] : [null, null];
    }

    /** The dates of a line as shown on a document: "Prod. 10/01/2026, Exp. 12/01/2026" or '' */
    public static function lineText(array $l): string
    {
        $p = $l['production_date'] ?? null;
        $e = $l['expiry_date'] ?? null;
        return ($p || $e) ? self::label($p ?: null, $e ?: null) : '';
    }

    /**
     * The production and expiry dates of a line posted to the form ($r: the posted row) as a line's fields, checked:
     * 'in' = stock coming in (required when $required), 'out' = a date group chosen to take out (optional).
     * Returns ['production_date' => .., 'expiry_date' => ..] (both null when the item keeps no dates).
     */
    public static function fromRow(array $r, ?int $itemId, string $dir, bool $required, string $itemLabel, ?string $txnDate = null): array
    {
        if (!self::itemTracked($itemId)) {
            return ['production_date' => null, 'expiry_date' => null];
        }
        if ($dir === 'out' && isset($r['lot']) && (string)$r['lot'] !== '') {
            // "No dates" is the same as leaving it to first in, first out, which takes the stock with no dates first
            [$prod, $exp] = self::split((string)$r['lot']);
            return ['production_date' => $prod, 'expiry_date' => $exp];
        }
        $prod = self::date($r['production_date'] ?? '', 'production date for ' . $itemLabel);
        $exp = self::date($r['expiry_date'] ?? '', 'expiry date for ' . $itemLabel);
        self::check($prod, $exp, $itemLabel, $required && $dir === 'in', $dir === 'in' ? $txnDate : null);
        return ['production_date' => $prod, 'expiry_date' => $exp];
    }
}
