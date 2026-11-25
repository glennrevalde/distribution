<?php
declare(strict_types=1);

/**
 * v43: the production / expiry date groups of items at a site, for the transaction forms (the choice of date group on
 * a line) and the POS. GET item_ids=1,2,3 & site_id=N [& exclude=txn id]. Any logged-in user: it shows quantities
 * only, as the forms already do.
 */
header('Cache-Control: no-store');
$ids = array_values(array_filter(array_map('intval', explode(',', (string)g('item_ids'))), fn($v) => $v > 0));
$siteId = (int)g('site_id');
if (!$ids || !$siteId || !Lots::on()) {
    json_out(['on' => Lots::on(), 'groups' => (object)[]]);
}
if (!Access::siteAllowed($siteId)) {
    json_out(['error' => 'You may not see the stock of that site.'], 403);
}
$exclude = (int)g('exclude') ?: null;
// v5: an item kept in crates offers the loose stock of each date group (its crates are chosen by the crate)
$groups = Lots::forItems(array_slice($ids, 0, 200), $siteId, $exclude, g('all') !== '1');
foreach ($groups as &$list) {
    foreach ($list as &$g) {
        $g['text'] = Lots::pickText($g);
    }
    unset($g);
}
unset($list);
json_out(['on' => true, 'groups' => (object)$groups]);

