<?php
declare(strict_types=1);

/**
 * Distribution: supplier allocations and their pick-up.
 *
 * A supplier allocation says what is to be picked up from a supplier on a day, for which location, and who picks
 * it up: the supplier's items with the number of crates (or kilos, or packs) allocated. At the supplier the
 * pick-up crew types each crate as it is loaded (crate number, heads, weight, production and expiry dates) on
 * Pick-Up Supplier Items, and "Pick-up complete" receives everything into stock at the location with one Item
 * Receipt: the crates are then in the Crate Center, and the bill follows with Enter Bill for Received Items.
 */
final class Allocations
{
    public const STATUSES = ['open' => 'Allocated', 'picking' => 'Being picked up', 'received' => 'Received', 'cancelled' => 'Cancelled'];

    public static function load(int $id): ?array
    {
        return DB::row(
            "SELECT a.*, v.name AS vendor_name, s.name AS site_name, u.full_name AS assigned_name, u.username AS assigned_username,
                    t.txn_no AS receipt_no
               FROM supplier_allocations a JOIN vendors v ON v.id = a.vendor_id JOIN sites s ON s.id = a.site_id
               LEFT JOIN users u ON u.id = a.assigned_user_id LEFT JOIN transactions t ON t.id = a.receipt_txn_id
              WHERE a.id = :id",
            ['id' => $id]
        );
    }

    /** The lines of an allocation, with their item, unit, and the crates typed at pick-up */
    public static function lines(int $id): array
    {
        $lines = DB::all(
            "SELECT l.*, i.code AS item_code, i.name AS item_name, i.cost AS item_cost, i.unit AS item_unit, u.is_variable, u.code AS uom_code, s.base_unit
               FROM supplier_allocation_lines l JOIN items i ON i.id = l.item_id
               LEFT JOIN uom_units u ON u.id = l.uom_id LEFT JOIN uom_sets s ON s.id = i.uom_set_id
              WHERE l.allocation_id = :a ORDER BY l.line_no, l.id",
            ['a' => $id]
        );
        $crates = [];
        if ($lines) {
            [$in, $p] = DB::in('al', array_map(fn($l) => (int)$l['id'], $lines));
            foreach (DB::all("SELECT * FROM supplier_allocation_crates WHERE line_id IN $in ORDER BY line_id, seq, id", $p) as $c) {
                $crates[(int)$c['line_id']][] = $c;
            }
        }
        foreach ($lines as &$l) {
            $l['crates'] = $crates[(int)$l['id']] ?? [];
            $l['is_crate'] = (int)($l['is_variable'] ?? 0) === 1;
            $l['base'] = $l['base_unit'] ?: ($l['item_unit'] ?: 'kg');
            $l['unit_label'] = $l['unit_code'] ?: ($l['uom_code'] ?: $l['base']);
        }
        unset($l);
        return $lines;
    }

    /** The items a supplier delivers, in the order they are allocated */
    public static function supplierItems(int $vendorId, bool $activeOnly = true): array
    {
        return DB::all(
            "SELECT vi.*, i.code, i.name, i.cost, i.unit, i.uom_set_id, s.base_unit, u.code AS uom_code, u.is_variable
               FROM vendor_items vi JOIN items i ON i.id = vi.item_id LEFT JOIN uom_units u ON u.id = vi.uom_id LEFT JOIN uom_sets s ON s.id = i.uom_set_id
              WHERE vi.vendor_id = :v" . ($activeOnly ? ' AND vi.is_active = 1 AND i.is_active = 1' : '') . '
              ORDER BY vi.sort_order, i.code',
            ['v' => $vendorId]
        );
    }

    /** Suppliers that have items on their Supplier Items list: id => name */
    public static function suppliers(): array
    {
        return DB::pairs('SELECT v.id, v.name FROM vendors v WHERE v.is_active = 1 AND EXISTS (SELECT 1 FROM vendor_items vi WHERE vi.vendor_id = v.id AND vi.is_active = 1) ORDER BY v.name');
    }

    /** Units an item can be allocated in (its U/M set): id => code, the crate unit marked */
    public static function unitOptions(int $itemId): array
    {
        $out = [];
        foreach (Uom::unitsForItem($itemId) as $u) {
            $out[(int)$u['id']] = $u['code'] . ((int)($u['is_variable'] ?? 0) === 1 ? ' (crates)' : '');
        }
        return $out;
    }

    /** Users who can be assigned a pick-up (anyone who may open Pick-Up Supplier Items) */
    public static function pickers(): array
    {
        $out = [];
        foreach (DB::all("SELECT id, full_name, username FROM users WHERE status = 'active' AND is_platform = 0 AND approval_status = 'approved' ORDER BY full_name") as $u) {
            $out[(int)$u['id']] = $u['full_name'] . ' (' . $u['username'] . ')';
        }
        return $out;
    }

    public static function statusText(string $s): string
    {
        return self::STATUSES[$s] ?? ucfirst($s);
    }

    /** The cost per base unit a pick-up is received at: the supplier's last cost, else the item's cost */
    public static function costFor(int $vendorId, int $itemId): float
    {
        $c = (float)DB::value('SELECT last_cost FROM vendor_items WHERE vendor_id = :v AND item_id = :i', ['v' => $vendorId, 'i' => $itemId]);
        return $c > 0 ? $c : (float)DB::value('SELECT cost FROM items WHERE id = :i', ['i' => $itemId]);
    }

    /**
     * The crates (or the quantity) picked up on one line. $rows: [{no, pcs, qty, prod, exp}] for a line in crates;
     * $qty: the base units picked for a line in kilos or packs.
     */
    public static function savePicked(int $lineId, array $rows, ?float $qty, bool $done): void
    {
        DB::tx(function () use ($lineId, $rows, $qty, $done) {
            $l = DB::row('SELECT l.*, a.status, a.alloc_date, a.id AS alloc_id FROM supplier_allocation_lines l JOIN supplier_allocations a ON a.id = l.allocation_id WHERE l.id = :id FOR UPDATE', ['id' => $lineId]);
            if (!$l) {
                fail('That line of the allocation no longer exists.');
            }
            if (in_array($l['status'], ['received', 'cancelled'], true)) {
                fail('This allocation is ' . strtolower(self::statusText($l['status'])) . ' and can no longer change.');
            }
            $isCrate = Crates::isCrateUnit($l['uom_id'] ? (int)$l['uom_id'] : null);
            DB::run('DELETE FROM supplier_allocation_crates WHERE line_id = :l', ['l' => $lineId]);
            $total = 0.0;
            $count = 0;
            if ($isCrate) {
                $seen = [];
                foreach (array_values($rows) as $i => $c) {
                    $q = round(to_num($c['qty'] ?? 0), 4);
                    $no = mb_substr(trim((string)($c['no'] ?? '')), 0, 30);
                    if ($q <= 0 && $no === '') {
                        continue;
                    }
                    if ($q <= 0) {
                        fail('Type the weight of crate ' . ($no ?: '#' . ($i + 1)) . '.');
                    }
                    if ($no !== '' && isset($seen[mb_strtolower($no)])) {
                        fail('Crate number ' . $no . ' is typed twice.');
                    }
                    $seen[mb_strtolower($no)] = 1;
                    $prod = Lots::date($c['prod'] ?? '', 'production date');
                    $exp = Lots::date($c['exp'] ?? '', 'expiry date');
                    Lots::check($prod, $exp, 'crate ' . ($no ?: '#' . ($i + 1)), false, null);
                    DB::insert('supplier_allocation_crates', ['line_id' => $lineId, 'seq' => $i + 1, 'crate_no' => $no !== '' ? $no : (string)($i + 1),
                        'pcs' => max(0.0, round(to_num($c['pcs'] ?? 0), 2)), 'qty' => $q, 'production_date' => $prod, 'expiry_date' => $exp]);
                    $total += $q;
                    $count++;
                }
            } else {
                $total = max(0.0, round((float)$qty, 4));
                $count = $total > 0 ? 1 : 0;
            }
            DB::update('supplier_allocation_lines', ['picked' => $done && $total > 0 ? 1 : 0, 'picked_qty' => round($total, 4), 'picked_count' => $isCrate ? $count : $total],
                'id = :id', ['id' => $lineId]);
            DB::update('supplier_allocations', ['status' => 'picking', 'updated_at' => date('Y-m-d H:i:s')], "id = :id AND status = 'open'", ['id' => $l['alloc_id']]);
        });
    }

    /** Clears what was picked up (Reset): the allocation goes back to its allocated quantities */
    public static function reset(int $id): void
    {
        DB::tx(function () use ($id) {
            $a = self::load($id);
            if (!$a || in_array($a['status'], ['received', 'cancelled'], true)) {
                fail('Only an allocation that has not been received can be reset.');
            }
            DB::run('DELETE c FROM supplier_allocation_crates c JOIN supplier_allocation_lines l ON l.id = c.line_id WHERE l.allocation_id = :a', ['a' => $id]);
            DB::run('UPDATE supplier_allocation_lines SET picked = 0, picked_qty = 0, picked_count = 0 WHERE allocation_id = :a', ['a' => $id]);
            DB::update('supplier_allocations', ['status' => 'open', 'updated_at' => date('Y-m-d H:i:s')], 'id = :id', ['id' => $id]);
            Audit::log('pickup_reset', 'vend', 'allocation', $id, $a['alloc_no'], ['page_key' => 'vend.pickup', 'reason' => 'Pick-up details cleared']);
        });
    }

    /**
     * Pick-up complete: everything picked up is received into stock at the allocation's location with one Item
     * Receipt (crates and all). Returns the receipt's id.
     */
    public static function complete(int $id, ?string $date = null): int
    {
        return DB::tx(function () use ($id, $date) {
            $a = DB::row('SELECT * FROM supplier_allocations WHERE id = :id FOR UPDATE', ['id' => $id]);
            if (!$a) {
                fail('Allocation not found.');
            }
            if ($a['status'] === 'received') {
                fail('This pick-up was already received on ' . Txn::ref(Txn::load((int)$a['receipt_txn_id']) ?? ['txn_type' => 'item_receipt', 'txn_no' => '']) . '.');
            }
            if ($a['status'] === 'cancelled') {
                fail('A cancelled allocation cannot be received.');
            }
            if (!Access::siteAllowed((int)$a['site_id'])) {
                fail('You are not allowed to receive stock at that location.');
            }
            $rows = [];
            $cratesByRow = [];
            foreach (self::lines($id) as $l) {
                if ((float)$l['picked_qty'] <= 0) {
                    continue;
                }
                $rate = (float)$l['rate'] > 0 ? (float)$l['rate'] : self::costFor((int)$a['vendor_id'], (int)$l['item_id']);
                $row = ['item_id' => (int)$l['item_id'], 'description' => $l['item_name'], 'uom_id' => $l['uom_id'], 'rate' => $rate, 'site_id' => (int)$a['site_id'],
                    'qty' => (float)$l['picked_qty']];
                if ($l['is_crate']) {
                    $row['crates'] = array_map(fn($c) => ['no' => (string)$c['crate_no'], 'pcs' => (float)$c['pcs'], 'qty' => (float)$c['qty'],
                        'prod' => $c['production_date'] ?: '', 'exp' => $c['expiry_date'] ?: ''], $l['crates']);
                }
                $rows[] = $row;
                $cratesByRow[] = (int)$l['id'];
            }
            if (!$rows) {
                fail('Nothing has been picked up yet: type the crates (or the kilos) picked up for at least one item.');
            }
            $txnDate = $date ?: (string)$a['alloc_date'];
            $lines = parse_item_lines($rows, 'purchase', ['lots' => 'in', 'txn_date' => $txnDate, 'crates' => 'in', 'site_id' => (int)$a['site_id']]);
            foreach ($lines as &$ln) {
                if (!empty($ln['_crates']['rows'])) {
                    foreach ($ln['_crates']['rows'] as &$cr) {
                        $cr['allocation_id'] = $id;
                    }
                    unset($cr);
                }
            }
            unset($ln);
            $h = [
                'txn_date' => $txnDate, 'vendor_id' => (int)$a['vendor_id'], 'site_id' => (int)$a['site_id'], 'account_id' => Accts::get('ap'),
                'ref_no' => mb_substr('Pick-up ' . $a['alloc_no'], 0, 40), 'memo' => 'Picked up by ' . ($a['assigned_to'] ?: (string)DB::value('SELECT full_name FROM users WHERE id = :u', ['u' => $a['assigned_user_id']])) . ' (' . $a['alloc_no'] . ')',
                'received_via' => 'pickup',
            ];
            if (Classes::ready() && $a['class_id']) {
                $h['class_id'] = (int)$a['class_id'];
            }
            $txnId = Txn::save('item_receipt', $h, $lines, null, ['reason' => 'Pick-up ' . $a['alloc_no'] . ' completed']);
            // link each allocation line to the receipt line it became
            $rLines = DB::column('SELECT id FROM transaction_lines WHERE txn_id = :t ORDER BY line_no', ['t' => $txnId]);
            foreach ($cratesByRow as $i => $lineId) {
                if (isset($rLines[$i])) {
                    DB::update('supplier_allocation_lines', ['receipt_line_id' => (int)$rLines[$i], 'picked' => 1], 'id = :id', ['id' => $lineId]);
                }
            }
            // the cost the supplier was received at is remembered for the next pick-up
            foreach ($lines as $ln) {
                DB::run('UPDATE vendor_items SET last_cost = :c WHERE vendor_id = :v AND item_id = :i', ['c' => (float)$ln['rate'], 'v' => $a['vendor_id'], 'i' => $ln['item_id']]);
            }
            DB::update('supplier_allocations', ['status' => 'received', 'receipt_txn_id' => $txnId, 'picked_at' => date('Y-m-d H:i:s'), 'picked_by' => Auth::id(),
                'updated_at' => date('Y-m-d H:i:s')], 'id = :id', ['id' => $id]);
            Audit::log('pickup_complete', 'vend', 'allocation', $id, $a['alloc_no'], ['page_key' => 'vend.pickup', 'site_id' => (int)$a['site_id'],
                'reason' => 'Received on ' . Txn::ref(Txn::load($txnId))]);
            return $txnId;
        });
    }
}
