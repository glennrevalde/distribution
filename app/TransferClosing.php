<?php
declare(strict_types=1);

/**
 * Distribution (v2): Inventory Transfer Closing.
 *
 * At the end of the day the van salesman (or an outlet) remits the sales and sends back to the warehouse or cold storage
 * whatever is left. The closing lists everything the site holds, one line per open crate and one per item for the stock
 * outside crates, with its balance. The receiver types what came back (crates re-weighed, kilos, packs or another unit
 * of the item); a difference is identified as shrinkage, as shortage, or part of each:
 *
 *  - what came back goes on an Inventory Transfer to the warehouse; crates keep their numbers and dates;
 *  - shrinkage goes on an Inventory Adjustment (reason Shrinkage) to the shrinkage adjustment account;
 *  - shortage goes on a Shortage Charge: Dr Shortage Receivable / Cr Inventory at cost, on the employee as a customer
 *    (see SalesReps). It is never a sale. It is collected through Receive Payments.
 *
 * Crate lines take their shrinkage and shortage out of that very crate before it is moved, so each crate's history
 * shows what happened to it. The three documents are made, and voided, together.
 */
final class TransferClosing
{
    public const EPS = 0.0005;

    /** id of the closing being voided: its own documents may be voided while it is */
    public static ?int $voiding = null;

    private static array $ready = [];
    private static array $owner = [];

    public static function ready(): bool
    {
        $db = DB::databaseName();
        if (!isset(self::$ready[$db])) {
            try {
                DB::value('SELECT COUNT(*) FROM transfer_closings WHERE 1 = 0');
                DB::value('SELECT COUNT(*) FROM transfer_closing_lines WHERE 1 = 0');
                self::$ready[$db] = true;
            } catch (Throwable $e) {
                self::$ready[$db] = false;
            }
        }
        return self::$ready[$db];
    }

    /** The closing a transaction belongs to ("TC-00003"), or null. Not while that closing itself is being voided. */
    public static function ownerOf(int $txnId): ?string
    {
        if (!$txnId || !self::ready()) {
            return null;
        }
        $key = DB::databaseName() . ':' . $txnId;
        if (!array_key_exists($key, self::$owner)) {
            $r = DB::row("SELECT id, closing_no FROM transfer_closings WHERE status = 'posted' AND (transfer_txn_id = :a OR shrink_txn_id = :b OR shortage_txn_id = :c) LIMIT 1",
                ['a' => $txnId, 'b' => $txnId, 'c' => $txnId]);
            self::$owner[$key] = $r ?: null;
        }
        $r = self::$owner[$key];
        if (!$r || (self::$voiding !== null && (int)$r['id'] === self::$voiding)) {
            return null;
        }
        return (string)$r['closing_no'];
    }

    public static function load(int $id): ?array
    {
        return DB::row('SELECT tc.*, fs.name AS from_name, fs.code AS from_code, ts.name AS to_name, sr.name AS rep_name, sr.rep_type, c.name AS customer_name,
                               u.username, u.full_name AS created_name
                          FROM transfer_closings tc JOIN sites fs ON fs.id = tc.from_site_id JOIN sites ts ON ts.id = tc.to_site_id
                          LEFT JOIN sales_reps sr ON sr.id = tc.sales_rep_id LEFT JOIN customers c ON c.id = tc.customer_id
                          LEFT JOIN users u ON u.id = tc.created_by WHERE tc.id = :id', ['id' => $id]);
    }

    public static function lines(int $id): array
    {
        return DB::all('SELECT l.*, i.code, i.name FROM transfer_closing_lines l JOIN items i ON i.id = l.item_id WHERE l.closing_id = :id ORDER BY l.line_no, l.id', ['id' => $id]);
    }

    /** The unit cost a shortage is charged at: what the books carry for the item now (its average cost) */
    public static function unitCost(int $itemId): float
    {
        $qty = Stock::onHand($itemId);
        $val = Stock::valueOnHand($itemId);
        if ($qty > 0.000001 && $val > 0.004) {
            return round($val / $qty, 4);
        }
        $it = DB::row('SELECT avg_cost, cost FROM items WHERE id = :i', ['i' => $itemId]);
        return round((float)($it['avg_cost'] ?? 0) > 0 ? (float)$it['avg_cost'] : (float)($it['cost'] ?? 0), 4);
    }

    /**
     * What the site holds now, as the lines of a closing: one line per open crate, one per item for its stock outside
     * crates (all of it for items not kept in crates). Items below zero are listed too (they cannot be closed).
     */
    public static function balances(int $siteId): array
    {
        $rows = [];
        $items = DB::all("SELECT s.item_id, s.qty_on_hand, i.code, i.name, i.unit, i.uom_set_id, us.base_unit
                            FROM item_site_stock s JOIN items i ON i.id = s.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                           WHERE s.site_id = :s AND ABS(s.qty_on_hand) > 0.00001 AND i.item_type IN ('inventory','assembly')
                           ORDER BY i.code", ['s' => $siteId]);
        $ids = array_map(fn($r) => (int)$r['item_id'], $items);
        $units = $ids ? Uom::unitsByItem($ids) : [];
        $crated = $ids && Crates::ready() ? Crates::crateItems($ids) : [];
        foreach ($items as $it) {
            $iid = (int)$it['item_id'];
            $base = (string)($it['base_unit'] ?: $it['unit'] ?: 'pc');
            $book = Stock::bookQty($iid, $siteId);
            $inCrates = 0.0;
            if (isset($crated[$iid])) {
                foreach (DB::all("SELECT * FROM crates WHERE item_id = :i AND site_id = :s AND status = 'open' ORDER BY (expiry_date IS NULL), expiry_date, received_date, id",
                    ['i' => $iid, 's' => $siteId]) as $c) {
                    $rows[] = [
                        'item_id' => $iid, 'code' => $it['code'], 'name' => $it['name'], 'base' => $base, 'crate_id' => (int)$c['id'], 'crate_no' => (string)$c['crate_no'],
                        'pcs' => (float)$c['pcs'], 'prod' => $c['production_date'], 'exp' => $c['expiry_date'], 'balance' => round((float)$c['qty_left'], 4), 'units' => [],
                    ];
                    $inCrates += (float)$c['qty_left'];
                }
            }
            $loose = round($book - $inCrates, 4);
            if (abs($loose) > 0.00001) {
                // the units it can be counted in besides the base (box of 20 packs ...); never the crate unit
                $u = array_values(array_filter($units[$iid] ?? [], fn($x) => !$x['v'] && $x['factor'] > 0));
                $rows[] = [
                    'item_id' => $iid, 'code' => $it['code'], 'name' => $it['name'], 'base' => $base, 'crate_id' => 0, 'crate_no' => '',
                    'pcs' => 0.0, 'prod' => null, 'exp' => null, 'balance' => $loose, 'units' => count($u) > 1 ? $u : [],
                    'in_crates' => isset($crated[$iid]),
                ];
            }
        }
        return $rows;
    }

    /**
     * Records a closing: $h = closing_date, from_site_id, to_site_id, sales_rep_id, customer_id, shrink_account_id,
     * shortage_account_id, transferred_by, checked_by, received_by, memo. $posted = the lines as typed:
     * [item_id, crate_id, uom_id, balance, transfer, shrink, shortage, note, use]. Returns the closing id.
     */
    public static function save(array $h, array $posted): int
    {
        if (!self::ready()) {
            fail('Inventory Transfer Closing needs the database update of this version (Super Admin > Database updates, or the migration file).');
        }
        $from = (int)($h['from_site_id'] ?? 0);
        $to = (int)($h['to_site_id'] ?? 0);
        $date = (string)($h['closing_date'] ?? '');
        if (!$from || !$to || $from === $to) {
            fail('Choose the site being closed and the warehouse or cold storage the stock goes back to (two different sites).');
        }
        if (!valid_date($date)) {
            fail('Enter the date of the closing.');
        }
        if (!Access::siteAllowed($from) || !Access::siteAllowed($to)) {
            fail('You are not allowed to move stock between those sites.');
        }
        $sites = DB::pairs('SELECT id, name FROM sites WHERE id IN (:a, :b)', ['a' => $from, 'b' => $to]);
        if (count($sites) !== 2) {
            fail('One of the sites chosen no longer exists.');
        }

        return DB::tx(function () use ($h, $posted, $from, $to, $date, $sites) {
            // what the site holds now, by line key
            $now = [];
            foreach (self::balances($from) as $b) {
                $now[$b['item_id'] . ':' . $b['crate_id']] = $b;
            }
            $unitsOf = Uom::unitsByItem(array_unique(array_map(fn($r) => (int)($r['item_id'] ?? 0), $posted)) ?: [0]);
            $lots = Lots::ready() && Lots::on();
            $lines = [];
            $n = 0;
            foreach ($posted as $r) {
                $iid = (int)($r['item_id'] ?? 0);
                $cid = (int)($r['crate_id'] ?? 0);
                if (!$iid || empty($r['use'])) {
                    continue;
                }
                $b = $now[$iid . ':' . $cid] ?? null;
                $label = DB::value('SELECT code FROM items WHERE id = :i', ['i' => $iid]) . ($cid ? ' crate ' . DB::value('SELECT crate_no FROM crates WHERE id = :c', ['c' => $cid]) : '');
                if (!$b) {
                    fail($label . ' is no longer at ' . $sites[$from] . '. Press Show balances again.');
                }
                // the unit it was counted in (another unit of the item's set; crates are always in their base unit)
                $factor = 1.0;
                $unit = $b['base'];
                $uomId = (int)($r['uom_id'] ?? 0);
                if (!$cid && $uomId) {
                    foreach ($unitsOf[$iid] ?? [] as $u) {
                        if ($u['id'] === $uomId && !$u['v'] && $u['factor'] > 0) {
                            $factor = $u['factor'];
                            $unit = $u['code'];
                        }
                    }
                }
                $shown = round(to_num($r['balance'] ?? 0) * $factor, 4);
                if (abs($shown - (float)$b['balance']) > self::EPS) {
                    fail('The stock of ' . $label . ' at ' . $sites[$from] . ' changed since the list was shown (' . qty($b['balance']) . ' ' . $b['base'] . ' now). Press Show balances again.');
                }
                if ((float)$b['balance'] < -0.00001) {
                    fail($label . ' is below zero at ' . $sites[$from] . ' (' . qty($b['balance']) . ' ' . $b['base'] . '). Record the stock that went out or came in first, or untick it.');
                }
                $tq = round(to_num($r['transfer'] ?? 0) * $factor, 4);
                $sq = round(to_num($r['shrink'] ?? 0) * $factor, 4);
                $oq = round(to_num($r['shortage'] ?? 0) * $factor, 4);
                if ($tq < 0 || $sq < 0 || $oq < 0) {
                    fail($label . ': the quantities cannot be below zero.');
                }
                $bal = (float)$b['balance'];
                if (abs($tq + $sq + $oq - $bal) > self::EPS) {
                    fail($label . ': what came back (' . qty($tq / $factor) . '), the shrinkage (' . qty($sq / $factor) . ') and the shortage (' . qty($oq / $factor)
                        . ') must add up to the balance (' . qty($bal / $factor) . ' ' . $unit . '). Identify the whole difference as shrinkage, shortage or both.');
                }
                if ($tq + $sq + $oq <= 0.00001) {
                    continue;
                }
                $lines[] = [
                    'line_no' => ++$n, 'item_id' => $iid, 'crate_id' => $cid ?: null, 'crate_no' => $cid ? $b['crate_no'] : null, 'unit' => $b['base'],
                    'balance' => $bal, 'transfer_qty' => $tq, 'shrink_qty' => $sq, 'shortage_qty' => $oq, 'unit_cost' => self::unitCost($iid),
                    'note' => mb_substr(trim((string)($r['note'] ?? '')), 0, 255) ?: null,
                    '_name' => (string)$b['name'], '_prod' => $b['prod'], '_exp' => $b['exp'], '_dated' => $lots && Lots::itemTracked($iid),
                ];
            }
            if (!$lines) {
                fail('Nothing to close: tick the lines that came back (or are short) and type what came back.');
            }
            $shortQty = array_sum(array_column($lines, 'shortage_qty'));
            $repId = (int)($h['sales_rep_id'] ?? 0) ?: null;
            $customerId = (int)($h['customer_id'] ?? 0) ?: null;
            if ($shortQty > 0.00001 && !$customerId && $repId) {
                $customerId = SalesReps::ensureCustomer($repId);
            }
            if ($shortQty > 0.00001 && !$customerId) {
                fail('There is a shortage: choose the cashier, sales representative or customer it is charged to.');
            }
            $shrinkAcct = (int)($h['shrink_account_id'] ?? 0) ?: Accts::get('inventory_adjustment');
            $shortAcct = (int)($h['shortage_account_id'] ?? 0) ?: Accts::get('shortage_receivable');
            $no = Seq::next('transfer_closing');
            $memo = trim((string)($h['memo'] ?? ''));
            $ref = 'Inventory Transfer Closing ' . $no;

            // 1. shrinkage: an adjustment at the site closed, from the crate itself for crate lines
            $shrinkId = null;
            $adj = [];
            foreach ($lines as $l) {
                if ($l['shrink_qty'] > 0.00001) {
                    $line = ['line_kind' => 'item', 'item_id' => $l['item_id'], 'qty' => -$l['shrink_qty'], 'rate' => 0, 'value_change' => 0, 'site_id' => $from,
                        'description' => 'Shrinkage', 'unit' => $l['unit']];
                    if ($l['crate_id']) {
                        $line['_crates'] = ['dir' => 'out', 'rows' => [['id' => $l['crate_id'], 'qty' => $l['shrink_qty'],
                            'whole' => abs($l['shrink_qty'] - $l['balance']) <= self::EPS ? 1 : 0, 'note' => 'Shrinkage on ' . $no]]];
                        if ($l['_dated']) {
                            $line['production_date'] = $l['_prod'];
                            $line['expiry_date'] = $l['_exp'];
                        }
                    }
                    $adj[] = $line;
                }
            }
            if ($adj) {
                $shrinkId = Txn::save('inventory_adjustment', ['txn_date' => $date, 'site_id' => $from, 'account_id' => $shrinkAcct, 'ref_no' => $no,
                    'memo' => mb_substr('Shrinkage - ' . $ref . ($memo !== '' ? ' - ' . $memo : ''), 0, 255), 'status' => 'open', 'sales_rep_id' => $repId],
                    $adj, null, ['reason' => 'Shrinkage on ' . $ref]);
            }

            // 2. shortage: charged to the employee as a customer at cost (not a sale)
            $shortId = null;
            $sc = [];
            foreach ($lines as $l) {
                if ($l['shortage_qty'] > 0.00001) {
                    $line = ['line_kind' => 'item', 'item_id' => $l['item_id'], 'qty' => $l['shortage_qty'], 'rate' => $l['unit_cost'], 'uom_rate' => $l['unit_cost'],
                        'amount' => r2($l['shortage_qty'] * $l['unit_cost']), 'site_id' => $from, 'unit' => $l['unit'],
                        'description' => $l['_name'] . ($l['crate_id'] ? ', crate ' . $l['crate_no'] : '') . ' (shortage)'];
                    if ($l['crate_id']) {
                        $line['_crates'] = ['dir' => 'out', 'rows' => [['id' => $l['crate_id'], 'qty' => $l['shortage_qty'],
                            'whole' => abs($l['shortage_qty'] + $l['shrink_qty'] - $l['balance']) <= self::EPS ? 1 : 0, 'note' => 'Shortage on ' . $no]]];
                        if ($l['_dated']) {
                            $line['production_date'] = $l['_prod'];
                            $line['expiry_date'] = $l['_exp'];
                        }
                    }
                    $sc[] = $line;
                }
            }
            if ($sc) {
                $shortId = Txn::save('shortage_charge', ['txn_date' => $date, 'due_date' => $date, 'customer_id' => $customerId, 'sales_rep_id' => $repId,
                    'site_id' => $from, 'account_id' => $shortAcct, 'ref_no' => $no, 'status' => 'open',
                    'memo' => mb_substr('Shortage - ' . $ref . ($memo !== '' ? ' - ' . $memo : ''), 0, 255)], $sc, null, ['reason' => 'Shortage on ' . $ref]);
            }

            // 3. what came back: one transfer line per crate (it keeps its number and dates) and per item outside crates
            $transferId = null;
            $tr = [];
            foreach ($lines as $l) {
                if ($l['transfer_qty'] <= 0.00001) {
                    continue;
                }
                $line = ['line_kind' => 'item', 'item_id' => $l['item_id'], 'qty' => $l['transfer_qty'], 'site_id' => $from, 'unit' => $l['unit'],
                    'description' => $l['_name']];
                if ($l['crate_id']) {
                    $cu = Crates::crateUnit((int)$l['item_id']);
                    $line += ['uom_id' => $cu['id'] ?? null, 'uom_qty' => 1, 'uom_factor' => round($l['transfer_qty'], 6)];
                    if ($cu) {
                        $line['unit'] = $cu['code'];
                    }
                    $line['_crates'] = ['dir' => 'move', 'rows' => [['id' => $l['crate_id']]]];
                    if ($l['_dated']) {
                        $line['production_date'] = $l['_prod'];
                        $line['expiry_date'] = $l['_exp'];
                    }
                }
                $tr[] = $line;
            }
            if ($tr) {
                $transferId = Txn::save('inventory_transfer', ['txn_date' => $date, 'site_id' => $from, 'site2_id' => $to, 'ref_no' => $no, 'status' => 'open',
                    'memo' => mb_substr($ref . ($memo !== '' ? ' - ' . $memo : ''), 0, 255)], $tr, null, ['reason' => $ref]);
                // a crate moved back holds exactly what was typed as having come back
                foreach ($lines as $l) {
                    if ($l['crate_id'] && $l['transfer_qty'] > 0.00001) {
                        $left = (float)DB::value('SELECT qty_left FROM crates WHERE id = :c', ['c' => $l['crate_id']]);
                        if (abs($left - $l['transfer_qty']) > self::EPS) {
                            fail('Crate ' . $l['crate_no'] . ' holds ' . qty($left) . ' ' . $l['unit'] . ' after its shrinkage and shortage, not the ' . qty($l['transfer_qty']) . ' typed. Show the balances again.');
                        }
                    }
                }
            }

            $tot = ['balance_qty' => 0.0, 'transfer_qty' => 0.0, 'shrink_qty' => 0.0, 'shortage_qty' => 0.0];
            foreach ($lines as $l) {
                $tot['balance_qty'] += $l['balance'];
                $tot['transfer_qty'] += $l['transfer_qty'];
                $tot['shrink_qty'] += $l['shrink_qty'];
                $tot['shortage_qty'] += $l['shortage_qty'];
            }
            $shrinkAmount = $shrinkId ? r2(-(float)DB::value('SELECT COALESCE(SUM(total_cost),0) FROM inventory_movements WHERE txn_id = :t', ['t' => $shrinkId])) : 0.0;
            $id = DB::insert('transfer_closings', [
                'closing_no' => $no, 'closing_date' => $date, 'from_site_id' => $from, 'to_site_id' => $to, 'sales_rep_id' => $repId, 'customer_id' => $customerId,
                'shrink_account_id' => $shrinkAcct, 'shortage_account_id' => $shortAcct,
                'transferred_by' => mb_substr(trim((string)($h['transferred_by'] ?? '')), 0, 80) ?: null,
                'checked_by' => mb_substr(trim((string)($h['checked_by'] ?? '')), 0, 80) ?: null,
                'received_by' => mb_substr(trim((string)($h['received_by'] ?? '')), 0, 80) ?: null,
                'memo' => $memo !== '' ? mb_substr($memo, 0, 255) : null,
                'transfer_txn_id' => $transferId, 'shrink_txn_id' => $shrinkId, 'shortage_txn_id' => $shortId,
                'balance_qty' => round($tot['balance_qty'], 4), 'transfer_qty' => round($tot['transfer_qty'], 4),
                'shrink_qty' => round($tot['shrink_qty'], 4), 'shortage_qty' => round($tot['shortage_qty'], 4),
                'shrink_amount' => $shrinkAmount, 'shortage_amount' => $shortId ? r2((float)DB::value('SELECT total FROM transactions WHERE id = :t', ['t' => $shortId])) : 0.0,
                'status' => 'posted', 'created_by' => Auth::id(),
            ]);
            foreach ($lines as $l) {
                DB::insert('transfer_closing_lines', ['closing_id' => $id] + array_filter($l, fn($k) => $k[0] !== '_', ARRAY_FILTER_USE_KEY));
            }
            self::$owner = [];
            Audit::log('create', 'inv', 'transfer_closing', $id, $no, [
                'page_key' => 'inv.transfer_closing', 'site_id' => $from, 'amount' => $shortId ? (float)DB::value('SELECT total FROM transactions WHERE id = :t', ['t' => $shortId]) : 0,
                'reason' => 'Closing of ' . $sites[$from] . ' back to ' . $sites[$to] . ': ' . count($lines) . ' line(s), '
                    . qty($tot['transfer_qty']) . ' back, ' . qty($tot['shrink_qty']) . ' shrinkage, ' . qty($tot['shortage_qty']) . ' shortage',
            ]);
            return $id;
        });
    }

    /** Voids a closing: its transfer, shortage charge and shrinkage adjustment are voided together (newest first) */
    public static function void(int $id, string $reason): void
    {
        $c = self::load($id);
        if (!$c || $c['status'] !== 'posted') {
            fail('This closing is not posted (it may already be void).');
        }
        if (trim($reason) === '') {
            fail('Enter the reason for voiding the closing.');
        }
        DB::tx(function () use ($c, $id, $reason) {
            self::$voiding = $id;
            self::$owner = [];
            try {
                foreach (['transfer_txn_id', 'shortage_txn_id', 'shrink_txn_id'] as $k) {
                    $tid = (int)($c[$k] ?? 0);
                    if ($tid && ($t = Txn::load($tid)) && (int)$t['is_voided'] === 0) {
                        Txn::void($tid, 'Inventory Transfer Closing ' . $c['closing_no'] . ' voided: ' . $reason);
                    }
                }
            } finally {
                self::$voiding = null;
            }
            DB::update('transfer_closings', ['status' => 'void', 'void_reason' => mb_substr($reason, 0, 255), 'voided_by' => Auth::id(), 'voided_at' => date('Y-m-d H:i:s')],
                'id = :id', ['id' => $id]);
            self::$owner = [];
            Audit::log('void', 'inv', 'transfer_closing', $id, $c['closing_no'], ['page_key' => 'inv.transfer_closing', 'reason' => $reason, 'site_id' => (int)$c['from_site_id'],
                'changes' => [['field' => 'status', 'old' => 'posted', 'new' => 'void']]]);
        });
    }
}
