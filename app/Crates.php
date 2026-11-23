<?php
declare(strict_types=1);

/**
 * Distribution: stock received, followed and sold by the crate.
 *
 * A crate is a container with a number of heads (chickens, packs) and a weight that is different every time,
 * so a crate is never a fixed number of kilos. Items keep their stock in their base unit (kilos or packs); the
 * crate unit of an item's U/M set is marked "variable", and every crate received in it is kept here with its own
 * number, heads, kilos, production date and expiry date.
 *
 *  - Receiving in crates (Receive Items, Receive Items and Enter Bills, Enter Bills, Write Checks, the Pick-Up
 *    Supplier Items page) records one crate per row typed; the line's quantity is the total kilos of its crates.
 *  - Selling (Create Invoices, Enter Sales Receipts, the POS Register) takes crates chosen on the line: whole crates
 *    when the line is in crates, or kilos taken out of a crate when the line is in kilos (12.87 kg crate, 6 kg sold:
 *    6.87 kg stay in it; once the rest is sold the crate is finished and leaves the list).
 *  - Stock received in crates is sold by the crate: kilos sold without a crate can only come from loose stock
 *    (stock received in kilos, or crates converted to kilos). Converting a crate to kilos stops following it.
 *  - Moving crates to another site moves the crate with the stock (an inventory transfer is recorded).
 *  - v3: Adjust Quantity/Value on Hand adjusts crate by crate: the user types each crate's new weight (and the loose
 *    stock's), so the crates keep their own weights. An adjustment that names no crate may only change loose stock.
 *  - Anything else that takes stock out without naming a crate (builds, processing, supplier returns, batch invoices,
 *    counts) takes loose stock first, then the oldest crates, so the crates never add up to more than what is on
 *    hand. Those are kept as "taken automatically" in each crate's history.
 *
 * Every change is tied to the transaction that made it, so editing, voiding or deleting a transaction puts its
 * crates back exactly as they were.
 */
final class Crates
{
    public const EPS = 0.00005;

    /** transaction types whose lines may bring crates in, and types whose lines may take crates out */
    public const IN_TYPES = ['item_receipt', 'bill', 'check'];
    public const OUT_TYPES = ['invoice', 'sales_receipt', 'pos_sale'];

    /**
     * v2: what a crate chosen on a line is recorded as: sold (sales), shrinkage (an inventory adjustment, as the
     * shrinkage of an Inventory Transfer Closing) or shortage (a shortage charged to an employee).
     */
    public const OUT_KINDS = ['inventory_adjustment' => 'shrink', 'shortage_charge' => 'shortage'];
    /**
     * the movements that take kilos out of a crate, and the ones a document chose itself (line by line).
     * v3: 'adjust' is a crate adjusted on Adjust Quantity/Value on Hand: its qty is what the adjustment took out of the
     * crate, negative when it put kilos back in (never above what the crate came in with).
     */
    public const TAKE_KINDS = ['sale', 'auto', 'shrink', 'shortage', 'adjust'];
    public const CHOSEN_KINDS = ['sale', 'transfer', 'shrink', 'shortage', 'adjust'];

    /** "'sale','auto',..." for an SQL IN list */
    private static function sqlKinds(array $kinds): string
    {
        return "'" . implode("','", $kinds) . "'";
    }

    /** The movement kind of crates chosen on a document of this type */
    public static function outKind(string $txnType): string
    {
        return self::OUT_KINDS[$txnType] ?? 'sale';
    }

    private static array $ready = [];
    private static array $unitCache = [];
    private static array $itemCache = [];

    public static function ready(): bool
    {
        $db = DB::databaseName();
        if (!isset(self::$ready[$db])) {
            try {
                DB::value('SELECT COUNT(*) FROM crates WHERE 1 = 0');
                DB::value('SELECT COUNT(*) FROM crate_movements WHERE 1 = 0');
                DB::value('SELECT COUNT(is_variable) FROM uom_units WHERE 1 = 0');
                DB::value('SELECT COUNT(crate_count) FROM transaction_lines WHERE 1 = 0');
                self::$ready[$db] = true;
            } catch (Throwable $e) {
                self::$ready[$db] = false;
            }
        }
        return self::$ready[$db];
    }

    public static function flush(): void
    {
        self::$unitCache = [];
        self::$itemCache = [];
    }

    // ------------------------------------------------------------------ units and items

    /** The unit is a crate (a container holding no fixed number of base units) */
    public static function isCrateUnit(?int $uomId): bool
    {
        if (!$uomId || !self::ready()) {
            return false;
        }
        if (!array_key_exists($uomId, self::$unitCache)) {
            self::$unitCache[$uomId] = (int)DB::value('SELECT is_variable FROM uom_units WHERE id = :id', ['id' => $uomId]) === 1;
        }
        return self::$unitCache[$uomId];
    }

    /** The crate unit of an item (its U/M set has a variable unit), or null */
    public static function crateUnit(?int $itemId): ?array
    {
        if (!$itemId || !self::ready()) {
            return null;
        }
        if (!array_key_exists($itemId, self::$itemCache)) {
            self::$itemCache[$itemId] = DB::row(
                "SELECT u.id, u.code, u.name, s.base_unit FROM items i JOIN uom_units u ON u.set_id = i.uom_set_id JOIN uom_sets s ON s.id = u.set_id
                  WHERE i.id = :i AND u.is_variable = 1 AND i.item_type IN ('inventory','assembly') ORDER BY u.sort_order, u.id LIMIT 1",
                ['i' => $itemId]
            );
        }
        return self::$itemCache[$itemId];
    }

    /** item id => [unit id, unit code, base unit] for the items of a list that can be kept in crates (one query) */
    public static function crateItems(array $itemIds = []): array
    {
        if (!self::ready()) {
            return [];
        }
        $sql = "SELECT i.id AS item_id, u.id, u.code, s.base_unit FROM items i JOIN uom_units u ON u.set_id = i.uom_set_id JOIN uom_sets s ON s.id = u.set_id
                 WHERE u.is_variable = 1 AND i.item_type IN ('inventory','assembly')";
        $p = [];
        $itemIds = array_values(array_unique(array_filter(array_map('intval', $itemIds))));
        if ($itemIds) {
            [$in, $p] = DB::in('ci', $itemIds);
            $sql .= " AND i.id IN $in";
        }
        $out = [];
        foreach (DB::all($sql . ' ORDER BY u.sort_order, u.id', $p) as $r) {
            $out[(int)$r['item_id']] ??= ['unit_id' => (int)$r['id'], 'code' => $r['code'], 'base' => $r['base_unit']];
        }
        return $out;
    }

    /** The base unit of an item ("kg", "pack") */
    public static function baseUnit(int $itemId): string
    {
        $u = DB::value('SELECT s.base_unit FROM items i LEFT JOIN uom_sets s ON s.id = i.uom_set_id WHERE i.id = :i', ['i' => $itemId]);
        return (string)($u ?: (DB::value('SELECT unit FROM items WHERE id = :i', ['i' => $itemId]) ?: 'kg'));
    }

    /** Next crate number suggested (numbers can be typed over: crates usually carry their own painted number) */
    public static function peekNo(): string
    {
        $row = DB::row("SELECT prefix, next_no FROM sequences WHERE seq_key = 'crate'");
        if (!$row) {
            return '1';
        }
        return $row['prefix'] . $row['next_no'];
    }

    /** Takes the next crate number, and moves the counter past a number typed by hand */
    public static function takeNo(?string $typed = null): string
    {
        if (!DB::value("SELECT 1 FROM sequences WHERE seq_key = 'crate'")) {
            DB::insert('sequences', ['seq_key' => 'crate', 'prefix' => '', 'next_no' => 1, 'pad' => 1]);
        }
        $typed = trim((string)$typed);
        if ($typed !== '') {
            if (ctype_digit($typed)) {
                DB::run("UPDATE sequences SET next_no = GREATEST(next_no, :n) WHERE seq_key = 'crate'", ['n' => (int)$typed + 1]);
            }
            return mb_substr($typed, 0, 30);
        }
        $row = DB::row("SELECT prefix, next_no FROM sequences WHERE seq_key = 'crate' FOR UPDATE");
        DB::run("UPDATE sequences SET next_no = next_no + 1 WHERE seq_key = 'crate'");
        return $row['prefix'] . $row['next_no'];
    }

    // ------------------------------------------------------------------ crates on hand

    /**
     * Open crates of an item at a site, oldest dates first. With $txnId the crates (and the kilos) that transaction
     * itself took are counted back in, so a document being edited still sees what it took.
     */
    public static function open(int $itemId, int $siteId, ?int $txnId = null): array
    {
        $rows = DB::all(
            "SELECT c.*, v.name AS vendor_name FROM crates c LEFT JOIN vendors v ON v.id = c.vendor_id
              WHERE c.item_id = :i AND c.site_id = :s AND (c.status = 'open'" . ($txnId ? ' OR c.id IN (SELECT m.crate_id FROM crate_movements m WHERE m.txn_id = :t1)' : '') . ")
              ORDER BY (c.expiry_date IS NULL), c.expiry_date, c.received_date, c.id",
            ['i' => $itemId, 's' => $siteId] + ($txnId ? ['t1' => $txnId] : [])
        );
        $back = $txnId ? self::takenBy($txnId) : [];
        $out = [];
        foreach ($rows as $r) {
            if ($r['status'] === 'converted') {
                continue;
            }
            $left = round((float)$r['qty_left'] + ($back[(int)$r['id']] ?? 0.0), 4);
            if ($left <= self::EPS) {
                continue;
            }
            $r['qty_left'] = $left;
            $out[] = $r;
        }
        return $out;
    }

    /** crate id => base units the transaction took out of it */
    public static function takenBy(int $txnId): array
    {
        $out = [];
        foreach (DB::all('SELECT crate_id, SUM(qty) AS q FROM crate_movements WHERE txn_id = :t AND kind IN (' . self::sqlKinds(self::TAKE_KINDS) . ') GROUP BY crate_id', ['t' => $txnId]) as $r) {
            $out[(int)$r['crate_id']] = (float)$r['q'];
        }
        return $out;
    }

    /** Base units of an item at a site still in open crates */
    public static function inCrates(int $itemId, int $siteId): float
    {
        return round((float)DB::value("SELECT COALESCE(SUM(qty_left),0) FROM crates WHERE item_id = :i AND site_id = :s AND status = 'open'", ['i' => $itemId, 's' => $siteId]), 4);
    }

    /** Loose stock: what is on hand at the site and not in an open crate */
    public static function loose(int $itemId, int $siteId): float
    {
        return round(Stock::bookQty($itemId, $siteId) - self::inCrates($itemId, $siteId), 4);
    }

    /**
     * v3: loose stock as a document sees it: with $txnId, what that document did to the stock and to the crates is
     * counted back in (it is being edited, and may already be off the books).
     */
    public static function looseFor(int $itemId, int $siteId, ?int $txnId): float
    {
        if (!$txnId) {
            return self::loose($itemId, $siteId);
        }
        $own = -(float)DB::value('SELECT COALESCE(SUM(qty),0) FROM inventory_movements WHERE txn_id = :t AND item_id = :i AND site_id = :s', ['t' => $txnId, 'i' => $itemId, 's' => $siteId]);
        $ownCrates = (float)DB::value('SELECT COALESCE(SUM(m.qty),0) FROM crate_movements m JOIN crates c ON c.id = m.crate_id
                                        WHERE m.txn_id = :t AND m.kind IN (' . self::sqlKinds(self::TAKE_KINDS) . ') AND c.item_id = :i AND c.site_id = :s',
            ['t' => $txnId, 'i' => $itemId, 's' => $siteId]);
        return round(Stock::bookQty($itemId, $siteId) + $own - (self::inCrates($itemId, $siteId) + $ownCrates), 4);
    }

    /** v3: the open crates of each crate item, by site: item id => [site id => number of open crates] */
    public static function openCounts(): array
    {
        if (!self::ready()) {
            return [];
        }
        $out = [];
        foreach (DB::all("SELECT item_id, site_id, COUNT(*) AS n FROM crates WHERE status = 'open' GROUP BY item_id, site_id") as $r) {
            $out[(int)$r['item_id']][(int)$r['site_id']] = (int)$r['n'];
        }
        return $out;
    }

    /**
     * v3: the crates of a line of Adjust Quantity/Value on Hand ($row['crates'], JSON from the crate window): each crate's
     * difference, [{id, qty (+ added, - taken out), no}], and the loose stock's difference, {id: 'loose', qty}.
     * A crate can go down to 0, or up to what it came in with; loose stock can go down only as far as there is.
     * Returns null when the line names no crate, else ['dir' => 'adjust', 'rows', 'qty' (crates), 'loose', 'total',
     * 'count'] with the rows carrying the crates' dates.
     */
    public static function adjustRows(array $row, int $itemId, string $label, int $siteId, ?int $txnId): ?array
    {
        $raw = $row['crates'] ?? '';
        $list = is_array($raw) ? $raw : (trim((string)$raw) !== '' ? json_decode((string)$raw, true) : null);
        if (!is_array($list) || !$list) {
            return null;
        }
        if (!self::crateUnit($itemId)) {
            fail($label . ' is not kept in crates: its U/M set has no crate unit.');
        }
        $base = self::baseUnit($itemId);
        $avail = [];
        foreach (self::open($itemId, $siteId, $txnId) as $c) {
            $avail[(int)$c['id']] = $c;
        }
        $rows = [];
        $total = 0.0;
        $loose = 0.0;
        $seen = [];
        foreach ($list as $c) {
            $d = round(to_num($c['qty'] ?? 0), 4);
            if (($c['id'] ?? '') === 'loose') {
                $loose = $d;
                continue;
            }
            $id = (int)($c['id'] ?? 0);
            if (!$id || abs($d) <= self::EPS) {
                continue;
            }
            if (isset($seen[$id])) {
                fail('A crate is adjusted twice on ' . $label . '.');
            }
            $seen[$id] = 1;
            $crate = $avail[$id] ?? null;
            if (!$crate) {
                $no = DB::value('SELECT crate_no FROM crates WHERE id = :id', ['id' => $id]);
                fail('Crate ' . ($no ?: '#' . $id) . ' of ' . $label . ' is no longer open at this site. Open the crates of the line again.');
            }
            $left = (float)$crate['qty_left'];
            if ($left + $d < -self::EPS) {
                fail('Crate ' . $crate['crate_no'] . ' of ' . $label . ' has ' . self::fig($left, $base) . ' ' . $base . '; it cannot go down by ' . self::fig(-$d, $base) . '.');
            }
            if ($left + $d > (float)$crate['qty_in'] + self::EPS) {
                fail('Crate ' . $crate['crate_no'] . ' of ' . $label . ' came in with ' . self::fig($crate['qty_in'], $base) . ' ' . $base . '; an adjustment can put it back up to that, not above it.');
            }
            $rows[] = ['id' => $id, 'qty' => $d, 'no' => $crate['crate_no'], 'left' => $left, 'prod' => $crate['production_date'], 'exp' => $crate['expiry_date']];
            $total += $d;
        }
        if ($loose < -self::EPS) {
            $have = max(0.0, self::looseFor($itemId, $siteId, $txnId));
            if (-$loose > $have + self::EPS) {
                fail($label . ' has ' . self::fig($have, $base) . ' ' . $base . ' of loose stock here (not in a crate); the loose stock cannot go down by ' . self::fig(-$loose, $base) . '. Lower the crates themselves instead.');
            }
        }
        if (!$rows && abs($loose) <= self::EPS) {
            return null;
        }
        return ['dir' => 'adjust', 'rows' => $rows, 'qty' => round($total, 4), 'loose' => round($loose, 4), 'total' => round($total + $loose, 4), 'count' => count($rows)];
    }

    /** The open crates of several items at a site, for the POS and the line grids: item id => [crate, ...] */
    public static function openForItems(array $itemIds, int $siteId, ?int $txnId = null): array
    {
        $out = [];
        foreach (array_keys(self::crateItems($itemIds)) as $iid) {
            $list = [];
            foreach (self::open($iid, $siteId, $txnId) as $c) {
                $list[] = self::js($c);
            }
            $out[$iid] = $list;
        }
        return $out;
    }

    /** A crate as the screens' scripts use it */
    public static function js(array $c): array
    {
        return [
            'id' => (int)$c['id'], 'no' => (string)$c['crate_no'], 'pcs' => (float)$c['pcs'], 'qty' => round((float)$c['qty_left'], 4),
            'qin' => round((float)$c['qty_in'], 4), 'prod' => $c['production_date'] ?: '', 'exp' => $c['expiry_date'] ?: '',
            'recv' => $c['received_date'], 'vendor' => $c['vendor_name'] ?? '',
            'days' => $c['expiry_date'] ? (int)floor((strtotime($c['expiry_date']) - strtotime(today())) / 86400) : null,
        ];
    }

    // ------------------------------------------------------------------ reading a line posted from a form

    /**
     * The crates of a posted line ($row['crates'], JSON from the crate window) for parse_item_lines().
     *   $dir 'in'  : rows [{id?, no, pcs, qty, prod, exp}] typed for stock coming in
     *   $dir 'out' : rows [{id, qty}] chosen from the open crates for stock going out
     * Returns null when the line carries no crates, else ['dir', 'rows', 'qty' (total), 'count', 'prod', 'exp'].
     * $wholeOnly: the line is in crates, so a crate goes whole.
     */
    public static function fromRow(array $row, int $itemId, string $dir, bool $wholeOnly, string $label, int $siteId, ?int $txnId, ?string $txnDate): ?array
    {
        $raw = $row['crates'] ?? '';
        $list = is_array($raw) ? $raw : (trim((string)$raw) !== '' ? json_decode((string)$raw, true) : null);
        if (!is_array($list) || !$list) {
            return null;
        }
        if (!self::crateUnit($itemId)) {
            fail($label . ' is not kept in crates: its U/M set has no crate unit.');
        }
        $rows = [];
        $total = 0.0;
        if ($dir === 'in') {
            $seen = [];
            foreach (array_values($list) as $i => $c) {
                $q = round(to_num($c['qty'] ?? 0), 4);
                $no = trim((string)($c['no'] ?? ''));
                if ($q <= 0 && $no === '') {
                    continue;
                }
                if ($q <= 0) {
                    fail('Enter the kilos of crate ' . ($no !== '' ? $no : '#' . ($i + 1)) . ' of ' . $label . '.');
                }
                if ($no !== '' && isset($seen[mb_strtolower($no)])) {
                    fail('Crate number ' . $no . ' is typed twice on ' . $label . '.');
                }
                $seen[mb_strtolower($no)] = 1;
                $prod = Lots::date($c['prod'] ?? '', 'production date');
                $exp = Lots::date($c['exp'] ?? '', 'expiry date');
                Lots::check($prod, $exp, $label . ' crate ' . ($no !== '' ? $no : '#' . ($i + 1)), false, $txnDate);
                $rows[] = [
                    'id' => !empty($c['id']) ? (int)$c['id'] : null, 'no' => $no, 'pcs' => max(0.0, round(to_num($c['pcs'] ?? 0), 2)),
                    'qty' => $q, 'prod' => $prod, 'exp' => $exp,
                ];
                $total += $q;
            }
        } else {
            $avail = [];
            foreach (self::open($itemId, $siteId, $txnId) as $c) {
                $avail[(int)$c['id']] = $c;
            }
            $seen = [];
            foreach ($list as $c) {
                $id = (int)($c['id'] ?? 0);
                if (!$id) {
                    continue;
                }
                if (isset($seen[$id])) {
                    fail('A crate is chosen twice on ' . $label . '.');
                }
                $seen[$id] = 1;
                $crate = $avail[$id] ?? null;
                if (!$crate) {
                    $no = DB::value('SELECT crate_no FROM crates WHERE id = :id', ['id' => $id]);
                    fail('Crate ' . ($no ?: '#' . $id) . ' of ' . $label . ' is no longer open at this site. Choose the crates again.');
                }
                $left = (float)$crate['qty_left'];
                $q = $wholeOnly ? $left : round(to_num($c['qty'] ?? $left), 4);
                if ($q <= 0) {
                    continue;
                }
                if ($q > $left + self::EPS) {
                    fail('Crate ' . $crate['crate_no'] . ' of ' . $label . ' has only ' . qty($left) . ' ' . self::baseUnit($itemId) . ' left; ' . qty($q) . ' cannot be taken from it.');
                }
                $rows[] = ['id' => $id, 'qty' => min($q, $left), 'whole' => abs($q - $left) <= self::EPS ? 1 : 0, 'no' => $crate['crate_no'],
                    'prod' => $crate['production_date'], 'exp' => $crate['expiry_date']];
                $total += min($q, $left);
            }
        }
        if (!$rows) {
            return null;
        }
        // the dates of the line: the crates' own dates when they all share them, else the oldest of them
        $prods = array_values(array_unique(array_filter(array_column($rows, 'prod'))));
        $exps = array_values(array_unique(array_filter(array_column($rows, 'exp'))));
        sort($prods);
        sort($exps);
        return ['dir' => $dir, 'rows' => $rows, 'qty' => round($total, 4), 'count' => count($rows), 'prod' => $prods[0] ?? null, 'exp' => $exps[0] ?? null];
    }

    /**
     * Kilos sold without a crate may only come from loose stock: stock received in crates is sold by the crate,
     * unless the crates are converted to kilos first. Checked once for all the lines of a sale.
     */
    public static function checkLoose(array $lines, ?int $siteId, ?int $txnId, string $doing = 'sale'): void
    {
        if (!self::ready()) {
            return;
        }
        $need = [];
        foreach ($lines as $l) {
            // the items of an item group are taken from the oldest crates automatically, as their dates are (first in, first out)
            if (empty($l['item_id']) || isset($l['_crates']['rows']) || !empty($l['group_ref'])) {
                continue;
            }
            $sid = (int)($l['site_id'] ?? 0) ?: (int)$siteId;
            if (!$sid || (float)$l['qty'] <= 0 || !self::crateUnit((int)$l['item_id'])) {
                continue;
            }
            $need[(int)$l['item_id'] . ':' . $sid] = ($need[(int)$l['item_id'] . ':' . $sid] ?? 0.0) + (float)$l['qty'];
        }
        foreach ($need as $key => $q) {
            [$iid, $sid] = array_map('intval', explode(':', $key));
            if (!DB::value("SELECT 1 FROM crates WHERE item_id = :i AND site_id = :s AND status = 'open' LIMIT 1", ['i' => $iid, 's' => $sid])
                && !($txnId && DB::value('SELECT 1 FROM crate_movements m JOIN crates c ON c.id = m.crate_id WHERE m.txn_id = :t AND c.item_id = :i LIMIT 1', ['t' => $txnId, 'i' => $iid]))) {
                continue;   // nothing of it is in crates here: kilos are sold as they always were
            }
            // what this document already took counts back in (it is being edited)
            $own = $txnId ? -(float)DB::value('SELECT COALESCE(SUM(qty),0) FROM inventory_movements WHERE txn_id = :t AND item_id = :i AND site_id = :s', ['t' => $txnId, 'i' => $iid, 's' => $sid]) : 0.0;
            $ownCrates = $txnId ? (float)DB::value("SELECT COALESCE(SUM(m.qty),0) FROM crate_movements m JOIN crates c ON c.id = m.crate_id
                                                     WHERE m.txn_id = :t AND m.kind IN (" . self::sqlKinds(self::TAKE_KINDS) . ") AND c.item_id = :i AND c.site_id = :s", ['t' => $txnId, 'i' => $iid, 's' => $sid]) : 0.0;
            $loose = round(Stock::bookQty($iid, $sid) + $own - (self::inCrates($iid, $sid) + $ownCrates), 4);
            if ($q > max(0.0, $loose) + self::EPS) {
                $it = DB::row('SELECT code, name FROM items WHERE id = :i', ['i' => $iid]);
                $site = (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => $sid]);
                $unit = self::baseUnit($iid);
                if ($doing === 'adjustment') {
                    fail($it['code'] . ' ' . $it['name'] . ' is kept in crates at ' . $site . ': ' . qty(max(0.0, $loose)) . ' ' . $unit . ' of it is loose, and this adjustment lowers it by '
                        . qty($q) . ' ' . $unit . ' without naming a crate. Press Crates on the line and type the new weight of each crate adjusted, '
                        . 'so every crate keeps its own weight.');
                }
                if ($doing === 'transfer') {
                    fail($it['code'] . ' ' . $it['name'] . ' is kept in crates at ' . $site . ': ' . qty(max(0.0, $loose)) . ' ' . $unit . ' of it is loose, and this transfer moves '
                        . qty($q) . ' ' . $unit . ' without naming a crate. Press Crates on the line to move the crates themselves (they keep their numbers and dates), '
                        . 'or convert crates to loose stock first (Inventory > Convert Crates to Kilos).');
                }
                fail($it['code'] . ' ' . $it['name'] . ' is kept in crates at ' . $site . ': ' . qty(max(0.0, $loose)) . ' ' . $unit . ' of it is loose, and this sale takes '
                    . qty($q) . ' ' . $unit . ' without naming a crate. Press Crates on the line to choose the crate it comes from, sell it by the crate, '
                    . 'or convert crates to loose stock first (Inventory > Convert Crates to Kilos).');
            }
        }
    }

    // ------------------------------------------------------------------ after a transaction is saved

    /**
     * Called by Txn::save once the lines are written and posted. $map: line id => the crates of the line as read by
     * fromRow() (null: the line has no crates any more). Lines not in $map keep the crates they already had.
     */
    public static function afterSave(int $txnId, array $map): void
    {
        if (!self::ready()) {
            return;
        }
        $t = DB::row('SELECT * FROM transactions WHERE id = :id', ['id' => $txnId]);
        if (!$t) {
            return;
        }
        $lines = [];
        foreach (DB::all('SELECT * FROM transaction_lines WHERE txn_id = :t', ['t' => $txnId]) as $l) {
            $lines[(int)$l['id']] = $l;
        }
        $touched = [];      // crate ids to work out again
        $pairs = [];        // "item:site" to check against the stock on hand

        // what this transaction took automatically is worked out again from scratch
        foreach (DB::all("SELECT m.crate_id, c.item_id, c.site_id FROM crate_movements m JOIN crates c ON c.id = m.crate_id WHERE m.txn_id = :t AND m.kind = 'auto'", ['t' => $txnId]) as $r) {
            $touched[(int)$r['crate_id']] = 1;
            $pairs[$r['item_id'] . ':' . $r['site_id']] = 1;
        }
        DB::run("DELETE FROM crate_movements WHERE txn_id = :t AND kind = 'auto'", ['t' => $txnId]);

        // lines taken off the document: their crates go back (sold) or away (received)
        foreach (DB::all('SELECT id, crate_id, line_id FROM crate_movements WHERE txn_id = :t AND kind IN (' . self::sqlKinds(self::CHOSEN_KINDS) . ')', ['t' => $txnId]) as $m) {
            if (!isset($lines[(int)$m['line_id']])) {
                self::undoMovement($m, $touched, $pairs);
            }
        }
        foreach (DB::all('SELECT * FROM crates WHERE receive_txn_id = :t', ['t' => $txnId]) as $c) {
            if (!isset($lines[(int)$c['receive_line_id']])) {
                self::removeReceived($c, $pairs);
            }
        }

        // a pending invoice or a suspended POS sale keeps its crates aside for itself until it is completed or cancelled
        $voided = (int)$t['is_voided'] === 1;
        foreach ($map as $lineId => $data) {
            $line = $lines[(int)$lineId] ?? null;
            if (!$line) {
                continue;
            }
            $site = (int)($line['site_id'] ?: $t['site_id']);
            $dir = $data['dir'] ?? null;
            // the line's previous crates
            foreach (DB::all('SELECT id, crate_id, line_id FROM crate_movements WHERE txn_id = :t AND line_id = :l AND kind IN (' . self::sqlKinds(self::CHOSEN_KINDS) . ')', ['t' => $txnId, 'l' => $lineId]) as $m) {
                self::undoMovement($m, $touched, $pairs);
            }
            if ($dir !== 'in') {
                foreach (DB::all('SELECT * FROM crates WHERE receive_txn_id = :t AND receive_line_id = :l', ['t' => $txnId, 'l' => $lineId]) as $c) {
                    self::removeReceived($c, $pairs);
                }
            }
            $count = 0;
            if ($dir === 'in' && !$voided) {
                $count = self::syncReceived($t, $line, $site, $data['rows'], $touched, $pairs);
            } elseif ($dir === 'in') {
                foreach (DB::all('SELECT * FROM crates WHERE receive_txn_id = :t AND receive_line_id = :l', ['t' => $txnId, 'l' => $lineId]) as $c) {
                    self::removeReceived($c, $pairs);
                }
            } elseif ($dir === 'out' && !$voided) {
                foreach ($data['rows'] as $r) {
                    $crate = DB::row('SELECT * FROM crates WHERE id = :id', ['id' => $r['id']]);
                    if (!$crate || (int)$crate['item_id'] !== (int)$line['item_id'] || (int)$crate['site_id'] !== $site || $crate['status'] === 'converted') {
                        fail('Crate ' . ($crate['crate_no'] ?? '#' . $r['id']) . ' is not an open crate of this item at this site.');
                    }
                    DB::insert('crate_movements', [
                        'crate_id' => (int)$r['id'], 'move_date' => $t['txn_date'], 'kind' => self::outKind((string)$t['txn_type']), 'txn_id' => $txnId, 'line_id' => (int)$lineId,
                        'qty' => round((float)$r['qty'], 4), 'whole' => (int)($r['whole'] ?? 0), 'site_id' => $site, 'customer_id' => $t['customer_id'],
                        'note' => isset($r['note']) && $r['note'] !== '' ? mb_substr((string)$r['note'], 0, 255) : null,
                        'created_by' => Auth::id(),
                    ]);
                    $touched[(int)$r['id']] = 1;
                    $count++;
                }
                $pairs[$line['item_id'] . ':' . $site] = 1;
            } elseif ($dir === 'adjust' && !$voided) {
                // v3: each crate's own adjustment (qty kept as what was taken out of it: negative when kilos were put back)
                foreach ($data['rows'] as $r) {
                    $crate = DB::row('SELECT * FROM crates WHERE id = :id', ['id' => $r['id']]);
                    if (!$crate || (int)$crate['item_id'] !== (int)$line['item_id'] || (int)$crate['site_id'] !== $site || $crate['status'] === 'converted') {
                        fail('Crate ' . ($crate['crate_no'] ?? '#' . $r['id']) . ' is not an open crate of this item at this site.');
                    }
                    $d = round((float)$r['qty'], 4);
                    DB::insert('crate_movements', [
                        'crate_id' => (int)$r['id'], 'move_date' => $t['txn_date'], 'kind' => 'adjust', 'txn_id' => $txnId, 'line_id' => (int)$lineId,
                        'qty' => -$d, 'whole' => isset($r['left']) && $d < 0 && abs((float)$r['left'] + $d) <= self::EPS ? 1 : 0, 'site_id' => $site,
                        'note' => mb_substr(trim((string)$line['description']) !== '' ? trim((string)$line['description']) : 'Adjusted', 0, 255),
                        'created_by' => Auth::id(),
                    ]);
                    $touched[(int)$r['id']] = 1;
                    $count++;
                }
                $pairs[$line['item_id'] . ':' . $site] = 1;
            } elseif ($dir === 'move' && !$voided) {
                $to = (int)($t['site2_id'] ?? 0);
                foreach ($data['rows'] as $r) {
                    $crate = DB::row('SELECT * FROM crates WHERE id = :id', ['id' => $r['id']]);
                    if (!$crate || $crate['status'] !== 'open' || (int)$crate['item_id'] !== (int)$line['item_id'] || (int)$crate['site_id'] !== $site) {
                        fail('Crate ' . ($crate['crate_no'] ?? '#' . $r['id']) . ' is not an open crate of this item at the site it is moved from.');
                    }
                    DB::insert('crate_movements', [
                        'crate_id' => (int)$r['id'], 'move_date' => $t['txn_date'], 'kind' => 'transfer', 'txn_id' => $txnId, 'line_id' => (int)$lineId,
                        'qty' => 0, 'site_id' => $site, 'site2_id' => $to, 'created_by' => Auth::id(),
                    ]);
                    DB::update('crates', ['site_id' => $to], 'id = :id', ['id' => (int)$r['id']]);
                    $touched[(int)$r['id']] = 1;
                    $count++;
                }
                $pairs[$line['item_id'] . ':' . $site] = 1;
                $pairs[$line['item_id'] . ':' . $to] = 1;
            }
            DB::run('UPDATE transaction_lines SET crate_count = :n WHERE id = :id', ['n' => $count, 'id' => $lineId]);
        }

        // a sale that was voided, suspended or left pending holds no crate
        if ($voided) {
            foreach (DB::all('SELECT id, crate_id, line_id FROM crate_movements WHERE txn_id = :t AND kind IN (' . self::sqlKinds(self::CHOSEN_KINDS) . ')', ['t' => $txnId]) as $m) {
                self::undoMovement($m, $touched, $pairs);
            }
        }

        // every item and site the transaction moved stock for
        foreach (DB::all('SELECT DISTINCT item_id, site_id FROM inventory_movements WHERE txn_id = :t', ['t' => $txnId]) as $r) {
            $pairs[$r['item_id'] . ':' . $r['site_id']] = 1;
        }
        foreach (array_keys($touched) as $cid) {
            self::recompute((int)$cid);
            // the same crate chosen on two lines of the document can not give more than it holds
            $over = DB::row('SELECT c.crate_no, c.qty_in, SUM(m.qty) AS q FROM crates c JOIN crate_movements m ON m.crate_id = c.id AND m.kind IN (' . self::sqlKinds(self::TAKE_KINDS) . ')
                              WHERE c.id = :c GROUP BY c.id, c.crate_no, c.qty_in', ['c' => $cid]);
            if ($over && (float)$over['q'] > (float)$over['qty_in'] + self::EPS) {
                fail('Crate ' . $over['crate_no'] . ' holds ' . qty($over['qty_in']) . ' in all; more than that is being taken from it. Check the crates chosen on each line.');
            }
            if ($over && (float)$over['q'] < -self::EPS) {
                fail('Crate ' . $over['crate_no'] . ' came in with ' . qty($over['qty_in']) . '; an adjustment cannot put more than that back in it.');
            }
        }
        foreach (array_keys($pairs) as $key) {
            [$iid, $sid] = array_map('intval', explode(':', (string)$key));
            if ($iid && $sid) {
                self::reconcile($iid, $sid, $txnId, (string)$t['txn_date']);
            }
        }
    }

    /**
     * A transaction is voided (stays on file) or deleted: crates it sold go back, crates it received go away
     * (refused when another document already sold from them).
     */
    public static function release(int $txnId, bool $deleting): void
    {
        if (!self::ready()) {
            return;
        }
        $touched = [];
        $pairs = [];
        foreach (DB::all('SELECT id, crate_id, line_id FROM crate_movements WHERE txn_id = :t AND kind IN (' . self::sqlKinds(array_merge(self::CHOSEN_KINDS, ['auto'])) . ')', ['t' => $txnId]) as $m) {
            self::undoMovement($m, $touched, $pairs);
        }
        foreach (DB::all('SELECT * FROM crates WHERE receive_txn_id = :t', ['t' => $txnId]) as $c) {
            self::removeReceived($c, $pairs);
        }
        DB::run('DELETE FROM crate_movements WHERE txn_id = :t', ['t' => $txnId]);
        if (!$deleting) {
            DB::run('UPDATE transaction_lines SET crate_count = 0 WHERE txn_id = :t', ['t' => $txnId]);
        }
        foreach (array_keys($touched) as $cid) {
            self::recompute((int)$cid);
        }
        $date = (string)(DB::value('SELECT txn_date FROM transactions WHERE id = :t', ['t' => $txnId]) ?: today());
        foreach (array_keys($pairs) as $key) {
            [$iid, $sid] = array_map('intval', explode(':', (string)$key));
            if ($iid && $sid) {
                self::reconcile($iid, $sid, $deleting ? null : $txnId, $date);
            }
        }
    }

    /** Puts back what one movement did (a sale gives the kilos back; a move puts the crate back where it was) */
    private static function undoMovement(array $m, array &$touched, array &$pairs): void
    {
        $mv = DB::row('SELECT m.*, c.item_id, c.site_id AS crate_site FROM crate_movements m JOIN crates c ON c.id = m.crate_id WHERE m.id = :id', ['id' => $m['id']]);
        if (!$mv) {
            return;
        }
        if ($mv['kind'] === 'transfer') {
            // the crate goes back to the site it came from, unless it has moved on since
            $later = DB::value('SELECT 1 FROM crate_movements WHERE crate_id = :c AND id > :id AND kind IN (' . self::sqlKinds(self::CHOSEN_KINDS) . ') AND (txn_id IS NULL OR txn_id <> :t) LIMIT 1',
                ['c' => $mv['crate_id'], 'id' => $mv['id'], 't' => (int)$mv['txn_id']]);
            if ($later) {
                fail('Crate ' . DB::value('SELECT crate_no FROM crates WHERE id = :c', ['c' => $mv['crate_id']]) . ' was moved here and has been sold or moved again since. Undo that first.');
            }
            DB::update('crates', ['site_id' => (int)$mv['site_id']], 'id = :id', ['id' => (int)$mv['crate_id']]);
            $pairs[$mv['item_id'] . ':' . $mv['site_id']] = 1;
            $pairs[$mv['item_id'] . ':' . $mv['site2_id']] = 1;
        } else {
            $pairs[$mv['item_id'] . ':' . $mv['crate_site']] = 1;
        }
        DB::run('DELETE FROM crate_movements WHERE id = :id', ['id' => $mv['id']]);
        $touched[(int)$mv['crate_id']] = 1;
    }

    /** Crates typed on a receiving line: kept ones are updated, new ones added, the others removed */
    private static function syncReceived(array $t, array $line, int $site, array $rows, array &$touched, array &$pairs): int
    {
        $existing = [];
        foreach (DB::all('SELECT * FROM crates WHERE receive_txn_id = :t AND receive_line_id = :l', ['t' => $t['id'], 'l' => $line['id']]) as $c) {
            $existing[(int)$c['id']] = $c;
        }
        $keep = [];
        $n = 0;
        foreach ($rows as $r) {
            $no = $r['no'] !== '' ? $r['no'] : null;
            $id = $r['id'] && isset($existing[$r['id']]) ? (int)$r['id'] : null;
            if ($id) {
                $c = $existing[$id];
                $out = round((float)DB::value('SELECT COALESCE(SUM(qty),0) FROM crate_movements WHERE crate_id = :c AND kind IN (' . self::sqlKinds(self::TAKE_KINDS) . ')', ['c' => $id]), 4);
                if ($out > 0 && (float)$r['qty'] + self::EPS < $out) {
                    fail('Crate ' . $c['crate_no'] . ' already had ' . qty($out) . ' ' . self::baseUnit((int)$line['item_id']) . ' sold from it; it cannot hold less than that.');
                }
                if ($out > 0 && ((int)$c['item_id'] !== (int)$line['item_id'] || (int)$c['site_id'] !== $site)) {
                    fail('Crate ' . $c['crate_no'] . ' has been sold from: its item and site can no longer change.');
                }
                $no ??= $c['crate_no'];
                self::assertNoFree($no, $id);
                DB::update('crates', [
                    'crate_no' => $no, 'item_id' => (int)$line['item_id'], 'site_id' => $site, 'vendor_id' => $t['vendor_id'], 'received_date' => $t['txn_date'],
                    'pcs' => $r['pcs'], 'qty_in' => $r['qty'], 'unit_cost' => (float)$line['rate'], 'production_date' => $r['prod'], 'expiry_date' => $r['exp'],
                ], 'id = :id', ['id' => $id]);
                DB::run("UPDATE crate_movements SET qty = :q, move_date = :d, site_id = :s WHERE crate_id = :c AND kind = 'receive'", ['q' => $r['qty'], 'd' => $t['txn_date'], 's' => $site, 'c' => $id]);
            } else {
                $no = self::takeNo($no);
                self::assertNoFree($no, null);
                $id = DB::insert('crates', [
                    'crate_no' => $no, 'item_id' => (int)$line['item_id'], 'site_id' => $site, 'vendor_id' => $t['vendor_id'],
                    'receive_txn_id' => (int)$t['id'], 'receive_line_id' => (int)$line['id'], 'allocation_id' => $r['allocation_id'] ?? null,
                    'received_date' => $t['txn_date'], 'pcs' => $r['pcs'], 'qty_in' => $r['qty'], 'qty_left' => $r['qty'], 'unit_cost' => (float)$line['rate'],
                    'production_date' => $r['prod'], 'expiry_date' => $r['exp'], 'status' => 'open', 'created_by' => Auth::id(),
                ]);
                DB::insert('crate_movements', [
                    'crate_id' => $id, 'move_date' => $t['txn_date'], 'kind' => 'receive', 'txn_id' => (int)$t['id'], 'line_id' => (int)$line['id'],
                    'qty' => $r['qty'], 'site_id' => $site, 'created_by' => Auth::id(),
                ]);
            }
            $keep[$id] = 1;
            $touched[$id] = 1;
            $n++;
        }
        foreach ($existing as $id => $c) {
            if (!isset($keep[$id])) {
                self::removeReceived($c, $pairs);
            }
        }
        $pairs[$line['item_id'] . ':' . $site] = 1;
        return $n;
    }

    /** Two open crates can never carry the same number (a crate is one physical container) */
    private static function assertNoFree(string $no, ?int $selfId): void
    {
        $clash = DB::row("SELECT c.id, i.code FROM crates c JOIN items i ON i.id = c.item_id WHERE c.crate_no = :n AND c.status = 'open'" . ($selfId ? ' AND c.id <> :id' : '') . ' LIMIT 1',
            ['n' => $no] + ($selfId ? ['id' => $selfId] : []));
        if ($clash) {
            fail('Crate number ' . $no . ' is already in use by an open crate of ' . $clash['code'] . '. Use another number, or finish that crate first.');
        }
    }

    /** A crate received by a document that no longer has it: refused once another document took from it */
    private static function removeReceived(array $c, array &$pairs): void
    {
        $used = DB::row('SELECT m.txn_id, m.kind FROM crate_movements m WHERE m.crate_id = :c AND m.kind IN (' . self::sqlKinds(self::CHOSEN_KINDS) . ') AND (m.txn_id IS NULL OR m.txn_id <> :t) LIMIT 1',
            ['c' => $c['id'], 't' => (int)$c['receive_txn_id']]);
        if ($used) {
            $ref = $used['txn_id'] ? Txn::ref(Txn::load((int)$used['txn_id']) ?? ['txn_type' => 'transaction', 'txn_no' => '#' . $used['txn_id']]) : 'another document';
            fail('Crate ' . $c['crate_no'] . ' received on this document was already ' . (['transfer' => 'moved', 'shrink' => 'adjusted for shrinkage', 'shortage' => 'charged as a shortage', 'adjust' => 'adjusted'][$used['kind']] ?? 'sold') . ' on ' . $ref . '. Void or change that document first.');
        }
        $pairs[$c['item_id'] . ':' . $c['site_id']] = 1;
        DB::run('DELETE FROM crates WHERE id = :id', ['id' => $c['id']]);   // its movements go with it
        DB::run('UPDATE supplier_allocation_lines SET receipt_line_id = NULL WHERE receipt_line_id = :l', ['l' => $c['receive_line_id']]);
    }

    /** qty_left and status of a crate, from its movements */
    public static function recompute(int $crateId): void
    {
        $c = DB::row('SELECT * FROM crates WHERE id = :id', ['id' => $crateId]);
        if (!$c) {
            return;
        }
        $out = (float)DB::value('SELECT COALESCE(SUM(qty),0) FROM crate_movements WHERE crate_id = :c AND kind IN (' . self::sqlKinds(self::TAKE_KINDS) . ')', ['c' => $crateId]);
        $left = round(max(0.0, (float)$c['qty_in'] - $out), 4);
        // emptied: sold out, unless what finished it was shrinkage or a shortage (used up)
        $emptied = 'sold';
        if ($left <= self::EPS && in_array((string)DB::value('SELECT kind FROM crate_movements WHERE crate_id = :c AND kind IN (' . self::sqlKinds(self::TAKE_KINDS) . ') ORDER BY id DESC LIMIT 1',
            ['c' => $crateId]), ['shrink', 'shortage', 'adjust'], true)) {
            $emptied = 'used';
        }
        $status = $c['status'] === 'converted' ? 'converted' : ($left <= self::EPS ? $emptied : 'open');
        DB::update('crates', ['qty_left' => $left, 'status' => $status], 'id = :id', ['id' => $crateId]);
    }

    /**
     * The open crates of an item at a site never hold more than the stock on hand there. When they would (stock
     * taken out without naming a crate), the difference is taken from the oldest crates, recorded against $txnId.
     */
    public static function reconcile(int $itemId, int $siteId, ?int $txnId, string $date): void
    {
        $excess = round(self::inCrates($itemId, $siteId) - Stock::bookQty($itemId, $siteId), 4);
        if ($excess <= self::EPS) {
            return;
        }
        $crates = DB::all("SELECT * FROM crates WHERE item_id = :i AND site_id = :s AND status = 'open' ORDER BY (expiry_date IS NULL), expiry_date, received_date, id",
            ['i' => $itemId, 's' => $siteId]);
        foreach ($crates as $c) {
            if ($excess <= self::EPS) {
                break;
            }
            $take = round(min($excess, (float)$c['qty_left']), 4);
            if ($take <= self::EPS) {
                continue;
            }
            DB::insert('crate_movements', [
                'crate_id' => (int)$c['id'], 'move_date' => $date, 'kind' => 'auto', 'txn_id' => $txnId, 'qty' => $take, 'site_id' => $siteId,
                'note' => 'Taken out without naming a crate (oldest crate first)', 'created_by' => Auth::id(),
            ]);
            self::recompute((int)$c['id']);
            $excess = round($excess - $take, 4);
        }
    }

    // ------------------------------------------------------------------ converting crates to kilos

    /** Stops following crates: what is left in them stays on hand as loose kilos (or packs). Returns how many. */
    public static function convert(array $crateIds, string $note, ?string $date = null): int
    {
        $date ??= today();
        return DB::tx(function () use ($crateIds, $note, $date) {
            $n = 0;
            foreach (array_unique(array_map('intval', $crateIds)) as $id) {
                $c = DB::row("SELECT c.*, i.code FROM crates c JOIN items i ON i.id = c.item_id WHERE c.id = :id FOR UPDATE", ['id' => $id]);
                if (!$c || $c['status'] !== 'open') {
                    continue;
                }
                if (!Access::siteAllowed((int)$c['site_id'])) {
                    fail('You are not allowed to work with the stock of that site.');
                }
                DB::insert('crate_movements', [
                    'crate_id' => $id, 'move_date' => $date, 'kind' => 'convert', 'qty' => 0, 'site_id' => (int)$c['site_id'],
                    'note' => mb_substr('Converted to ' . self::baseUnit((int)$c['item_id']) . ': ' . qty($c['qty_left']) . ' left loose' . ($note !== '' ? '. ' . $note : ''), 0, 255),
                    'created_by' => Auth::id(),
                ]);
                DB::update('crates', ['status' => 'converted', 'converted_at' => date('Y-m-d H:i:s'), 'converted_by' => Auth::id(), 'convert_note' => $note !== '' ? mb_substr($note, 0, 255) : null],
                    'id = :id', ['id' => $id]);
                Audit::log('crate_convert', 'inv', 'crate', $id, 'Crate ' . $c['crate_no'] . ' (' . $c['code'] . ')', [
                    'reason' => $note !== '' ? $note : 'Converted to loose stock', 'amount' => (float)$c['qty_left'], 'page_key' => 'inv.crate_convert', 'site_id' => (int)$c['site_id'],
                ]);
                $n++;
            }
            return $n;
        });
    }

    // ------------------------------------------------------------------ showing crates

    /** The crates of a document's lines: line id => [crate rows with the quantity the line put in or took] */
    public static function forTxn(int $txnId): array
    {
        if (!self::ready()) {
            return [];
        }
        $out = [];
        // w_before: what the crate held just before this movement (a transfer shows the weight it went with, even
        // after the crate was sold at the site it went to)
        foreach (DB::all("SELECT m.line_id, m.qty, m.whole, m.kind, c.id AS crate_id, c.crate_no, c.pcs, c.qty_in, c.qty_left, c.production_date, c.expiry_date, c.status,
                                 c.qty_in - COALESCE((SELECT SUM(x.qty) FROM crate_movements x WHERE x.crate_id = m.crate_id AND x.id < m.id
                                                       AND x.kind IN (" . self::sqlKinds(self::TAKE_KINDS) . ")), 0) AS w_before
                            FROM crate_movements m JOIN crates c ON c.id = m.crate_id
                           WHERE m.txn_id = :t AND m.kind IN ('receive'," . self::sqlKinds(self::CHOSEN_KINDS) . ") ORDER BY m.line_id, m.id", ['t' => $txnId]) as $r) {
            $out[(int)$r['line_id']][] = $r;
        }
        return $out;
    }

    /** What the crate window of a line starts with on a form being edited (JSON for the hidden field) */
    public static function formValue(array $rows, string $dir): string
    {
        $list = [];
        foreach ($rows as $r) {
            if ($dir === 'in') {
                $list[] = ['id' => (int)$r['crate_id'], 'no' => (string)$r['crate_no'], 'pcs' => (float)$r['pcs'], 'qty' => (float)$r['qty'],
                    'prod' => $r['production_date'] ?: '', 'exp' => $r['expiry_date'] ?: ''];
            } elseif ($dir === 'adjust') {
                $list[] = ['id' => (int)$r['crate_id'], 'qty' => round(-(float)$r['qty'], 4), 'no' => (string)$r['crate_no']];
            } else {
                $list[] = ['id' => (int)$r['crate_id'], 'qty' => (float)$r['qty'], 'no' => (string)$r['crate_no']];
            }
        }
        return $list ? json_encode($list) : '';
    }

    /** "3 crates (36.12 kg)" */
    public static function summary(int $count, float $qty, string $unit): string
    {
        return $count . ' crate' . ($count === 1 ? '' : 's') . ' (' . qty($qty) . ' ' . $unit . ')';
    }

    /** A crate figure in its base unit: weights always with two decimals (12.30 kg), counts as they are (40 packs) */
    public static function fig($v, ?string $base): string
    {
        $b = strtolower(trim((string)$base));
        if ($b === '' || in_array($b, ['kg', 'kgs', 'kilo', 'kilos', 'g', 'lb', 'lbs'], true) || str_contains($b, 'kilo')) {
            return number_format(round((float)$v, 2), 2);
        }
        return qty(round((float)$v, 4));
    }

    /** v3: what a movement did to the crate, signed: +12.87 received, -6.00 sold, +0.50 adjusted up, '' moved or converted */
    public static function signedFig(array $m, ?string $base): string
    {
        $q = (float)$m['qty'];
        if ($m['kind'] === 'receive') {
            return '+' . self::fig($q, $base);
        }
        if (!in_array($m['kind'], self::TAKE_KINDS, true) || abs($q) <= self::EPS) {
            return '';
        }
        return ($q < 0 ? '+' : '-') . self::fig(abs($q), $base);
    }

    public static function statusText(string $status): string
    {
        return ['open' => 'Open', 'sold' => 'Sold out', 'converted' => 'Converted to kilos', 'used' => 'Used up (adjusted, shrinkage or shortage)'][$status] ?? ucfirst($status);
    }

    public static function kindText(string $kind): string
    {
        return ['receive' => 'Received', 'sale' => 'Sold', 'auto' => 'Taken automatically', 'transfer' => 'Moved', 'convert' => 'Converted to kilos',
            'shrink' => 'Shrinkage', 'shortage' => 'Shortage charged', 'adjust' => 'Adjusted'][$kind] ?? ucfirst($kind);
    }
}
