<?php
declare(strict_types=1);

// Small JSON lookups for forms (prices by price level, stock, customer info).
$what = g('what');
switch ($what) {
    case 'price':
        json_out(['price' => Lookup::priceFor((int)g('item'), gint('customer'))]);
    case 'customer':
        $c = DB::row('SELECT id, billing_address, shipping_address, terms_id, sales_rep_id, tax_code_id, credit_limit FROM customers WHERE id = :id', ['id' => (int)g('id')]);
        if ($c) {
            $c['balance'] = Balances::customerBalance((int)$c['id']);
        }
        json_out($c ?: []);
    case 'open_invoices':
        // v9: a customer paying an account balance at the POS: the outstanding invoices to tick, oldest due first
        if (!Access::page('pos.register') && !Access::page('pos.fb') && !Access::page('cust.payments')) {
            json_out(['docs' => [], 'balance' => 0], 403);
        }
        $cid = (int)g('customer');
        if (!$cid || !DB::value('SELECT 1 FROM customers WHERE id = :id', ['id' => $cid])) {
            json_out(['docs' => [], 'balance' => 0]);
        }
        json_out(PosPayments::openDocs($cid));
    case 'vendor':
        $v = DB::row('SELECT id, address, terms_id, default_expense_account_id, tax_code_id FROM vendors WHERE id = :id', ['id' => (int)g('id')]);
        json_out($v ?: []);
    case 'stock':
        $it = DB::row('SELECT id, item_type, unit FROM items WHERE id = :id', ['id' => (int)g('item')]);
        $onHand = Stock::onHand((int)g('item'), gint('site'));
        // v4: the quantity's unit, and what it is made of when the item has two or more units (the tooltip of the figure)
        $parts = $it ? Stock::unitParts((int)$it['id'], gint('site'), (float)$onHand) : ['unit' => '', 'lines' => []];
        json_out([
            'on_hand' => $onHand,
            'tracked' => $it ? Stock::isTracked($it['item_type']) : false,
            'unit' => $parts['unit'] !== '' ? $parts['unit'] : ($it['unit'] ?? ''),
            'detail' => $parts['lines'],
        ]);
    case 'site_stock':
        // v8: Dispatch Inventory, "Stock at the sites": what each site chosen holds, item by item, with the site it
        // belongs to, its crates, its loose stock and its earliest expiry. &sites=1,3 &q=words (code or name)
        $ids = array_values(array_unique(array_filter(array_map('intval', explode(',', (string)g('sites'))), fn($x) => $x > 0 && Access::siteAllowed($x))));
        if (!$ids) {
            json_out(['rows' => [], 'more' => false]);
        }
        [$in, $ps] = DB::in('sst', $ids);
        $p = $ps;
        $w = '';
        $q = trim((string)g('q'));
        if ($q !== '') {
            foreach (array_slice(preg_split('/\s+/', $q) ?: [], 0, 4) as $n => $word) {
                $w .= " AND (i.code LIKE :q$n OR i.name LIKE :q$n)";
                $p['q' . $n] = '%' . $word . '%';
            }
        }
        $limit = 300;
        $lotsOn = Lots::on();
        $rows = DB::all("SELECT ss.item_id, ss.site_id, ss.qty_on_hand, i.code, i.name, i.track_expiry, COALESCE(NULLIF(us.base_unit, ''), NULLIF(i.unit, ''), '') AS unit
                           FROM item_site_stock ss JOIN items i ON i.id = ss.item_id LEFT JOIN uom_sets us ON us.id = i.uom_set_id
                          WHERE ss.site_id IN $in AND ss.qty_on_hand > 0.00005 AND i.is_active = 1 AND i.item_type IN ('inventory','assembly') $w
                          ORDER BY i.code, ss.site_id LIMIT " . ($limit + 1), $p);
        $more = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        $crates = [];
        $exp = [];
        if ($rows) {
            [$in2, $p2] = DB::in('ssi', array_values(array_unique(array_map(fn($r) => (int)$r['item_id'], $rows))));
            if (Crates::ready()) {
                foreach (DB::all("SELECT item_id, site_id, COUNT(*) AS n, SUM(qty_left) AS q FROM crates WHERE status = 'open' AND site_id IN $in AND item_id IN $in2 GROUP BY item_id, site_id", $ps + $p2) as $c) {
                    $crates[$c['item_id'] . ':' . $c['site_id']] = $c;
                }
            }
            // the earliest expiry of the stock each site holds (the date groups still on hand)
            if ($lotsOn) {
                foreach (DB::all("SELECT item_id, site_id, expiry_date AS e, production_date AS pd, SUM(qty) AS q FROM inventory_movements
                                   WHERE site_id IN $in AND item_id IN $in2 AND expiry_date IS NOT NULL
                                   GROUP BY item_id, site_id, expiry_date, production_date HAVING SUM(qty) > 0.00005", $ps + $p2) as $g) {
                    $k = $g['item_id'] . ':' . $g['site_id'];
                    if (!isset($exp[$k]) || $g['e'] < $exp[$k]) {
                        $exp[$k] = $g['e'];
                    }
                }
            }
        }
        $out = [];
        foreach ($rows as $r) {
            $k = $r['item_id'] . ':' . $r['site_id'];
            $onHand = round((float)$r['qty_on_hand'], 4);
            $inCrates = round((float)($crates[$k]['q'] ?? 0), 4);
            $e = (int)$r['track_expiry'] === 1 ? ($exp[$k] ?? null) : null;
            $out[] = ['item_id' => (int)$r['item_id'], 'site_id' => (int)$r['site_id'], 'code' => (string)$r['code'], 'name' => (string)$r['name'], 'unit' => (string)$r['unit'],
                'on_hand' => $onHand, 'crates' => (int)($crates[$k]['n'] ?? 0), 'in_crates' => $inCrates, 'loose' => round(max(0.0, $onHand - $inCrates), 4),
                'exp' => $e, 'days' => Lots::daysLeft($e), 'status' => $e ? Lots::status($e) : '', 'dated' => $lotsOn && (int)$r['track_expiry'] === 1];
        }
        json_out(['rows' => $out, 'more' => $more, 'lots' => $lotsOn]);
    default:
        json_out(['error' => 'unknown lookup'], 400);
}
