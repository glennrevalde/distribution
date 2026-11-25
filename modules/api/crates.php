<?php
declare(strict_types=1);

/**
 * Distribution: the open crates of an item at a site, for the crate window of the transaction forms and the POS.
 * GET item_id=N & site_id=N [& txn=id of the document being edited, whose own crates count back in]
 * [& pack=1: v4, also the groups of loose stock that can be put into crates, with the container's name; v6: with
 * 'fixable', the kilos without dates there that came in with dates, and 'why', the Production and Expiry Dates page].
 * Any logged-in user who may see the site: it shows crate numbers, heads, kilos and dates, as the forms do.
 */
header('Cache-Control: no-store');
$itemId = (int)g('item_id');
$siteId = (int)g('site_id');
if (!Crates::ready() || !$itemId) {
    json_out(['crates' => [], 'base' => '', 'loose' => 0, 'next' => Crates::ready() ? Crates::peekNo() : '1']);
}
if ($siteId && !Access::siteAllowed($siteId)) {
    json_out(['error' => 'You may not see the stock of that site.'], 403);
}
$unit = Crates::crateUnit($itemId);
$base = Crates::baseUnit($itemId);
$list = [];
$loose = 0.0;
if ($siteId && $unit) {
    foreach (Crates::open($itemId, $siteId, (int)g('txn') ?: null) as $c) {
        $list[] = Crates::js($c);
    }
    // v3: a document being edited counts back in what it did itself (Adjust Quantity/Value on Hand adjusts loose stock too)
    $loose = (int)g('txn') ? Crates::looseFor($itemId, $siteId, (int)g('txn')) : Crates::loose($itemId, $siteId);
    $loose = g('signed') === '1' ? $loose : max(0.0, $loose);
}
$out = [
    'crates' => $list, 'base' => $base, 'unit' => $unit['code'] ?? '', 'loose' => round($loose, 4), 'next' => Crates::peekNo(),
    'site' => $siteId ? (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => $siteId]) : '',
];
// v4: pack=1: the groups of loose stock that can go into crates (Dispatch Inventory, Convert Kilos to Crates)
if (g('pack') === '1' && $siteId && $unit) {
    $out['groups'] = Crates::looseGroups($itemId, $siteId, (int)g('txn') ?: null);
    $out['container'] = Crates::containerName($itemId);
    $out['container1'] = Crates::containerName($itemId, false);
    $out['label'] = Crates::convertLabel($itemId);
    $out['lots'] = Lots::on() && Lots::itemTracked($itemId);
    // v6: kilos without dates here that came in with dates (Production and Expiry Dates puts them back)
    if ($out['lots'] && array_filter($out['groups'], fn($gr) => !$gr['dated'])) {
        $row = LotCheck::overview($siteId, $itemId)[0] ?? null;
        $out['fixable'] = $row ? $row['fixable'] : 0;
        if (Access::can('inv.lot_check', 'view')) {
            $out['why'] = url('inv.lot_check', ['site_id' => $siteId, 'q' => (string)DB::value('SELECT code FROM items WHERE id = :i', ['i' => $itemId])]);
        }
    }
}
json_out($out);
