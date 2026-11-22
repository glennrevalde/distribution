<?php
declare(strict_types=1);

/**
 * Distribution: the open crates of an item at a site, for the crate window of the transaction forms and the POS.
 * GET item_id=N & site_id=N [& txn=id of the document being edited, whose own crates count back in].
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
    $loose = max(0.0, Crates::loose($itemId, $siteId));
}
json_out([
    'crates' => $list, 'base' => $base, 'unit' => $unit['code'] ?? '', 'loose' => round($loose, 4), 'next' => Crates::peekNo(),
    'site' => $siteId ? (string)DB::value('SELECT name FROM sites WHERE id = :s', ['s' => $siteId]) : '',
]);
