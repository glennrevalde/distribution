<?php
declare(strict_types=1);

/**
 * v3 distribution: the Inventory Transfer as a slip for a POS printer (58 mm or 80 mm roll, through the browser or
 * a Bluetooth printer), and as a PDF of the same slip to send as a soft copy.
 *
 * The body lists what was transferred the way it was entered: one row per crate (its number, the item code and the
 * weight the crate had when it moved, e.g. 11.65kg), and one row per line moved without a crate in the unit it was
 * entered in (kilos, packs, boxes). Only the item code is printed, to save room. Under it: the number of crates and the
 * total of each unit, so the sales representative knows how many crates he or she is carrying, then the signature
 * lines Transferred by and Received by.
 *
 *   TransferReceipt::model($t)  the slip's content, worked out once
 *   ::render($t)                the page with the slip and its buttons (Print, Bluetooth printer, Save as PDF)
 *   ::ops($model)               the slip for the Bluetooth printer (assets/js/btprint.js)
 *   ::pdf($model)               the slip as a PDF, as wide as the paper roll
 */
final class TransferReceipt
{
    /** A quantity with its unit, as the slip prints it: 11.65kg, 10pack */
    public static function qtyText(float $qty, string $unit): string
    {
        return Crates::fig($qty, $unit) . $unit;
    }

    public static function model(array $t): array
    {
        $id = (int)$t['id'];
        $s = Settings::all();
        $lines = array_values(array_filter(Txn::lines($id), fn($l) => !empty($l['item_id'])));
        // the crates of each line, with the weight each had when it moved (what it came in with, less what was taken
        // out of it before the move)
        $crates = [];
        if (Crates::ready()) {
            foreach (DB::all("SELECT m.id, m.line_id, m.crate_id, c.crate_no, c.qty_in,
                                     c.qty_in - COALESCE((SELECT SUM(x.qty) FROM crate_movements x WHERE x.crate_id = m.crate_id AND x.id < m.id
                                                           AND x.kind IN ('sale','auto','shrink','shortage','adjust')), 0) AS w
                                FROM crate_movements m JOIN crates c ON c.id = m.crate_id
                               WHERE m.txn_id = :t AND m.kind = 'transfer' ORDER BY m.line_id, m.id", ['t' => $id]) as $m) {
                $crates[(int)$m['line_id']][] = $m;
            }
        }
        $rows = [];
        $units = [];        // unit => total, in the order they first appear
        $crateCount = 0;
        foreach ($lines as $l) {
            $base = Crates::baseUnit((int)$l['item_id']);
            $code = (string)$l['item_code'];
            $inCrates = 0.0;
            foreach ($crates[(int)$l['id']] ?? [] as $c) {
                $w = max(0.0, round((float)$c['w'], 4));
                $rows[] = ['crate' => (string)$c['crate_no'], 'code' => $code, 'qty' => $w, 'unit' => $base];
                $units[$base] = ($units[$base] ?? 0.0) + $w;
                $inCrates += $w;
                $crateCount++;
            }
            // what the line moved without a crate: in the unit it was entered in, or in the base unit
            $rest = round((float)$l['qty'] - $inCrates, 4);
            if ($inCrates > 0 && abs($rest) <= 0.005) {
                continue;
            }
            if ($inCrates <= 0 && !empty($l['uom_id']) && (float)$l['uom_factor'] > 0 && abs((float)$l['uom_factor'] - 1) > 0.0000001) {
                $q = (float)$l['uom_qty'];
                $u = (string)($l['unit'] ?: $base);
            } else {
                $q = $rest;
                $u = $inCrates > 0 ? $base : (string)($l['unit'] ?: $base);
            }
            if (abs($q) <= 0.00005) {
                continue;
            }
            $rows[] = ['crate' => '', 'code' => $code, 'qty' => $q, 'unit' => $u];
            $units[$u] = ($units[$u] ?? 0.0) + $q;
        }

        // the names under the signature lines: a closing's own names; otherwise who recorded the transfer, and the van
        // salesman or cashier answerable for the site it went to
        $closing = TransferClosing::ready() ? DB::row("SELECT closing_no, transferred_by, received_by FROM transfer_closings WHERE transfer_txn_id = :t AND status = 'posted' LIMIT 1", ['t' => $id]) : null;
        $from = (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => (int)$t['site_id']]);
        $to = (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => (int)$t['site2_id']]);
        if ($closing) {
            $by = (string)$closing['transferred_by'];
            $recv = (string)$closing['received_by'];
        } else {
            $by = (string)DB::value('SELECT full_name FROM users WHERE id = :u', ['u' => (int)$t['created_by']]);
            $recv = '';
            if (SalesReps::ready()) {
                $recv = (string)DB::value('SELECT r.name FROM sites s JOIN sales_reps r ON r.id = s.sales_rep_id WHERE s.id = :s', ['s' => (int)$t['site2_id']]);
            }
        }
        $time = $t['created_at'] ? date('h:i A', strtotime((string)$t['created_at'])) : '';
        $info = [
            ['No', (string)$t['txn_no']],
            ['Date', fdate($t['txn_date']) . ($time !== '' && substr((string)$t['created_at'], 0, 10) === (string)$t['txn_date'] ? ' ' . $time : '')],
            ['From', $from],
            ['To', $to],
        ];
        if (trim((string)$t['ref_no']) !== '') {
            $info[] = ['Ref', (string)$t['ref_no']];
        }
        if ($closing && trim((string)$t['ref_no']) === '') {
            $info[] = ['Closing', (string)$closing['closing_no']];
        }
        if (trim((string)$t['memo']) !== '') {
            $info[] = ['Memo', (string)$t['memo']];
        }
        return [
            'company' => (string)$s['company_name'], 'address' => (string)$s['company_address'], 'title' => 'INVENTORY TRANSFER',
            'txn_no' => (string)$t['txn_no'], 'voided' => (int)$t['is_voided'] === 1, 'info' => $info, 'rows' => $rows,
            'crates' => $crateCount, 'units' => $units, 'lines' => count($lines),
            'signs' => [['Transferred by:', $by], ['Received by:', $recv]],
            'printed' => 'Printed ' . date('m/d/Y h:i A') . ' by ' . (string)(Auth::user()['full_name'] ?? ''),
        ];
    }

    /** "3 crates" */
    public static function crateText(int $n): string
    {
        return $n . ($n === 1 ? ' crate' : ' crates');
    }

    // ------------------------------------------------------------------ the Bluetooth printer

    /**
     * The slip for the roll printer: the same content in characters. The crate number is printed in bold, so it reads
     * at a glance against the number painted on the crate.
     */
    public static function ops(array $m): array
    {
        $w = Receipt::width();
        $o = [['op' => 'text', 'text' => $m['company'], 'align' => 'center', 'bold' => 1]];
        foreach (self::wrap($m['address'], $w) as $l) {
            $o[] = ['op' => 'text', 'text' => $l, 'align' => 'center'];
        }
        $o[] = ['op' => 'rule'];
        $o[] = ['op' => 'text', 'text' => $m['title'], 'align' => 'center', 'bold' => 1];
        if ($m['voided']) {
            $o[] = ['op' => 'text', 'text' => '*** VOID ***', 'align' => 'center', 'bold' => 1];
        }
        foreach ($m['info'] as [$k, $v]) {
            foreach (self::wrap($k . ': ' . $v, $w) as $i => $part) {
                $o[] = ['op' => 'text', 'text' => $part, 'bold' => $k === 'No' ? 1 : 0];
            }
        }
        [$cw, $qw, $kw] = self::widths($m, $w);
        $o[] = ['op' => 'rule'];
        $o[] = ['op' => 'row', 'cells' => [['t' => 'Crate#', 'w' => $cw, 'b' => 1], ['t' => 'Item Code', 'w' => $kw, 'b' => 1], ['t' => 'Qty/Unit', 'w' => $qw, 'a' => 'r', 'b' => 1]]];
        $o[] = ['op' => 'rule'];
        foreach ($m['rows'] as $r) {
            $o[] = ['op' => 'row', 'cells' => [['t' => $r['crate'], 'w' => $cw, 'b' => 1], ['t' => $r['code'], 'w' => $kw], ['t' => self::qtyText($r['qty'], $r['unit']), 'w' => $qw, 'a' => 'r']]];
        }
        if (!$m['rows']) {
            $o[] = ['op' => 'text', 'text' => 'No items', 'align' => 'center'];
        }
        $o[] = ['op' => 'rule'];
        $totals = self::totalLines($m);
        foreach ($totals as $i => $t) {
            $o[] = ['op' => 'cols', 'left' => $i === 0 ? 'Total' : '', 'right' => $t, 'bold' => 1];
        }
        $o[] = ['op' => 'cols', 'left' => 'Lines', 'right' => (string)count($m['rows'])];
        $o[] = ['op' => 'rule'];
        foreach ($m['signs'] as [$caption, $name]) {
            $o[] = ['op' => 'text', 'text' => $caption];
            $o[] = ['op' => 'feed', 'n' => 2];
            $o[] = ['op' => 'text', 'text' => str_repeat('_', max(10, $w - 4)), 'align' => 'center'];
            $o[] = ['op' => 'text', 'text' => $name !== '' ? $name : ' ', 'align' => 'center'];
            $o[] = ['op' => 'feed', 'n' => 1];
        }
        $o[] = ['op' => 'rule'];
        foreach (self::wrap($m['printed'], $w) as $l) {
            $o[] = ['op' => 'text', 'text' => $l, 'align' => 'center'];
        }
        $opt = Receipt::btOptions();
        if ($opt['feed'] > 0) {
            $o[] = ['op' => 'feed', 'n' => $opt['feed']];
        }
        if ($opt['cut']) {
            $o[] = ['op' => 'cut'];
        }
        return $o;
    }

    /** Characters for the crate number, the quantity and the item code on a line of $w characters */
    private static function widths(array $m, int $w): array
    {
        $cw = 7;
        $qw = 9;
        foreach ($m['rows'] as $r) {
            $cw = max($cw, mb_strlen($r['crate']) + 1);
            $qw = max($qw, mb_strlen(self::qtyText($r['qty'], $r['unit'])) + 1);
        }
        $cw = min($cw, 10);
        $qw = min($qw, 13);
        $kw = max(6, $w - $cw - $qw);
        return [$cw, $qw, $kw];
    }

    /** "3 crates", then the total of each unit: "38.45kg", "10pack" */
    public static function totalLines(array $m): array
    {
        $out = [];
        if ($m['crates'] > 0) {
            $out[] = self::crateText((int)$m['crates']);
        }
        foreach ($m['units'] as $u => $q) {
            $out[] = self::qtyText((float)$q, (string)$u);
        }
        return $out ?: ['0'];
    }

    private static function wrap(string $text, int $w): array
    {
        $out = [];
        foreach (preg_split('/\r\n|\r|\n/', trim($text)) ?: [] as $line) {
            $line = trim(preg_replace('/\s+/u', ' ', $line) ?? '');
            if ($line === '') {
                continue;
            }
            foreach (explode("\n", wordwrap($line, $w, "\n", true)) as $part) {
                $out[] = $part;
            }
        }
        return $out;
    }

    // ------------------------------------------------------------------ the PDF

    /** The slip as a PDF as wide as the roll (58 or 80 mm), as long as it needs to be */
    public static function pdf(array $m): SimplePdf
    {
        $mm = Receipt::width() <= 32 ? 58 : 80;
        $pw = $mm * 72 / 25.4;
        $pad = 8.0;
        $inner = $pw - $pad * 2;
        $probe = new SimplePdf($pw, 200);
        // the layout is worked out twice: once to measure the height, once to write
        $draw = function (?SimplePdf $pdf) use ($m, $pw, $pad, $inner, $probe): float {
            $y = $pad;
            $put = function (float $x, string $s, float $size, bool $bold, string $align) use (&$y, $pdf) {
                if ($pdf) {
                    $pdf->text($x, $y, $s, $size, $bold, $align);
                }
            };
            $y += 10;
            foreach ($probe->wrap($m['company'], $inner, 9.5, true) as $l) {
                $put($pw / 2, $l, 9.5, true, 'C');
                $y += 11.5;
            }
            foreach ($probe->wrap(str_replace(["\r\n", "\n"], ' ', $m['address']), $inner, 7) as $l) {
                if ($l === '') {
                    continue;
                }
                $put($pw / 2, $l, 7, false, 'C');
                $y += 8.5;
            }
            $rule = function () use (&$y, $pdf, $pad, $pw) {
                $y += 3;
                if ($pdf) {
                    $pdf->line($pad, $y, $pw - $pad, $y, 0.6, 0.35);
                }
                $y += 11;
            };
            $rule();
            $put($pw / 2, $m['title'], 9.5, true, 'C');
            $y += 11;
            if ($m['voided']) {
                $put($pw / 2, '*** VOID ***', 9, true, 'C');
                $y += 11;
            }
            foreach ($m['info'] as [$k, $v]) {
                foreach ($probe->wrap($k . ': ' . $v, $inner, 7.5, $k === 'No') as $l) {
                    $put($pad, $l, 7.5, $k === 'No', 'L');
                    $y += 9.5;
                }
            }
            $rule();
            // the columns: crate number, item code, quantity and unit
            $cw = max($probe->textWidth('Crate#', 7, true) + 6, 0.0);
            foreach ($m['rows'] as $r) {
                $cw = max($cw, $probe->textWidth($r['crate'], 9, true) + 6);
            }
            $cw = min($cw, $inner * 0.34);
            $qx = $pw - $pad;
            $put($pad, 'Crate#', 7, true, 'L');
            $put($pad + $cw, 'Item Code', 7, true, 'L');
            $put($qx, 'Qty/Unit', 7, true, 'R');
            $y += 4;
            if ($pdf) {
                $pdf->line($pad, $y, $pw - $pad, $y, 0.4, 0.6);
            }
            $y += 10;
            foreach ($m['rows'] as $r) {
                $qt = self::qtyText($r['qty'], $r['unit']);
                $qw = $probe->textWidth($qt, 8);
                $put($pad, $probe->fit($r['crate'], $cw - 3, 9, true), 9, true, 'L');
                $put($pad + $cw, $probe->fit($r['code'], $inner - $cw - $qw - 4, 8, false), 8, false, 'L');
                $put($qx, $qt, 8, false, 'R');
                $y += 11;
            }
            if (!$m['rows']) {
                $put($pw / 2, 'No items', 8, false, 'C');
                $y += 11;
            }
            $rule();
            foreach (self::totalLines($m) as $i => $t) {
                if ($i === 0) {
                    $put($pad, 'Total', 8.5, true, 'L');
                }
                $put($qx, $t, 8.5, true, 'R');
                $y += 10.5;
            }
            $put($pad, 'Lines', 7.5, false, 'L');
            $put($qx, (string)count($m['rows']), 7.5, false, 'R');
            $y += 9.5;
            $rule();
            foreach ($m['signs'] as [$caption, $name]) {
                $put($pad, $caption, 7.5, false, 'L');
                $y += 24;
                if ($pdf) {
                    $pdf->line($pad + 6, $y, $pw - $pad - 6, $y, 0.6, 0);
                }
                $y += 9;
                if ($name !== '') {
                    $put($pw / 2, $name, 7.5, true, 'C');
                }
                $y += 12;
            }
            $rule();
            foreach ($probe->wrap($m['printed'], $inner, 6.5) as $l) {
                $put($pw / 2, $l, 6.5, false, 'C');
                $y += 8;
            }
            return $y + $pad;
        };
        $height = max(200.0, $draw(null));
        $pdf = new SimplePdf($pw, $height, 'Inventory Transfer ' . $m['txn_no']);
        $pdf->addPage();
        $draw($pdf);
        return $pdf;
    }

    // ------------------------------------------------------------------ the page

    public static function render(array $t, string $pageKey): void
    {
        $m = self::model($t);
        $mm = Receipt::width() <= 32 ? 58 : 80;
        $btOn = Receipt::btEnabled();
        layout_start('Inventory Transfer ' . $t['txn_no'] . ' receipt', ['bare' => true, 'no_title' => true, 'js' => $btOn ? ['js/btprint.js'] : [], 'body_class' => 'tr-slip-page']);
        ?>
        <style>@media print { @page { size: <?= $mm ?>mm auto; margin: 2mm; } .tr-slip { width: <?= $mm - 6 ?>mm; max-width: none; box-shadow: none; border: 0; margin: 0; } }</style>
        <div class="no-print tr-slip-bar">
          <div class="tr-slip-bar-title"><strong>Inventory Transfer <?= h($t['txn_no']) ?></strong><span><?= $mm ?> mm roll<?= $btOn ? ', Bluetooth printer on' : '' ?></span></div>
          <div class="tr-slip-actions">
            <button class="btn btn-primary btn-sm" type="button" onclick="window.print()" autofocus><i class="bi bi-printer"></i> Print</button>
            <?php if ($btOn): ?><button class="btn btn-outline-primary btn-sm" type="button" data-bt-print data-bt-ops="#btTransfer"><i class="bi bi-bluetooth"></i> Bluetooth printer</button><?php endif; ?>
            <a class="btn btn-outline-primary btn-sm" href="<?= h(Txn::url($t, 'receipt') . '&pdf=1') ?>"><i class="bi bi-file-earmark-pdf"></i> Save as PDF</a>
            <a class="btn btn-outline-secondary btn-sm" href="<?= h(Txn::url($t)) ?>">Back</a>
          </div>
          <?php if (!$btOn && Access::page('admin.settings')): ?><div class="tr-slip-hint">To print on a Bluetooth roll printer, switch it on (with the paper width) in <a href="<?= h(url('admin.settings')) ?>">Company, Security &amp; Closing Date</a>.</div><?php endif; ?>
        </div>
        <?php if ($btOn): ?>
        <div class="bt-note mx-auto" data-bt-status hidden></div>
        <script type="application/json" id="btPrinterOptions"><?= json_encode(Receipt::btOptions(), JSON_HEX_TAG | JSON_HEX_AMP) ?></script>
        <script type="application/json" id="btTransfer"><?= json_encode(self::ops($m), JSON_HEX_TAG | JSON_HEX_AMP) ?></script>
        <?php endif; ?>
        <div class="receipt tr-slip tr-slip-<?= $mm ?>">
          <div class="tr-slip-head"><strong><?= h($m['company']) ?></strong>
            <?php foreach (preg_split('/\r\n|\r|\n/', trim($m['address'])) ?: [] as $al): if (trim($al) === '') { continue; } ?><span><?= h($al) ?></span><?php endforeach; ?></div>
          <div class="tr-slip-title"><?= h($m['title']) ?><?= $m['voided'] ? '<span class="tr-slip-void">VOID</span>' : '' ?></div>
          <dl class="tr-slip-info">
            <?php foreach ($m['info'] as [$k, $v]): ?><div<?= $k === 'No' ? ' class="is-no"' : '' ?>><dt><?= h($k) ?></dt><dd><?= h($v) ?></dd></div><?php endforeach; ?>
          </dl>
          <table class="tr-slip-table">
            <thead><tr><th>Crate#</th><th>Item Code</th><th class="num">Qty/Unit</th></tr></thead>
            <tbody>
            <?php foreach ($m['rows'] as $r): ?>
              <tr><td class="tr-slip-crate"><?= h($r['crate']) ?></td><td class="tr-slip-code"><?= h($r['code']) ?></td><td class="num"><?= h(self::qtyText($r['qty'], $r['unit'])) ?></td></tr>
            <?php endforeach; ?>
            <?php if (!$m['rows']): ?><tr><td colspan="3" class="text-center">No items</td></tr><?php endif; ?>
            </tbody>
            <tfoot>
            <?php foreach (self::totalLines($m) as $i => $tl): ?><tr class="<?= $i === 0 ? 'is-first' : '' ?>"><td colspan="2"><?= $i === 0 ? 'Total' : '' ?></td><td class="num"><?= h($tl) ?></td></tr><?php endforeach; ?>
              <tr class="tr-slip-lines"><td colspan="2">Lines</td><td class="num"><?= count($m['rows']) ?></td></tr>
            </tfoot>
          </table>
          <div class="tr-slip-signs">
            <?php foreach ($m['signs'] as [$cap, $nm]): ?><div class="tr-slip-sign"><span><?= h($cap) ?></span><span class="tr-slip-line"></span><span class="tr-slip-name"><?= h($nm) ?></span></div><?php endforeach; ?>
          </div>
          <div class="tr-slip-printed"><?= h($m['printed']) ?></div>
        </div>
        <?php
        layout_end();
    }
}
