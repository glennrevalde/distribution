<?php
declare(strict_types=1);

/**
 * v8 distribution: the marker of a site. Wherever stock of several sites shows together (the stock by site on Dispatch
 * Inventory, the lines of a dispatch sent from many sites, the transfer reports), each site carries a small square of
 * its own colour beside its name, so the eye tells at a glance which site a quantity belongs to.
 *
 * The colour follows the site's id (eight colours in turn), so a site keeps its colour on every page and printout.
 * No table or column is needed.
 */
final class SiteMark
{
    public const COUNT = 8;

    /** 0..7 */
    public static function idx(?int $siteId): int
    {
        return $siteId ? (($siteId - 1) % self::COUNT + self::COUNT) % self::COUNT : 0;
    }

    public static function cls(?int $siteId): string
    {
        return 'sm-' . self::idx($siteId);
    }

    /** The square alone, or the square followed by the site's name */
    public static function html(?int $siteId, ?string $label = null): string
    {
        $m = '<span class="site-mark ' . self::cls($siteId) . '" aria-hidden="true"></span>';
        return $label === null ? $m : '<span class="site-tag">' . $m . '<span>' . h($label) . '</span></span>';
    }

    /** The marker's colour as 0..1 RGB, for the PDFs (the same colours as .sm-0 ... .sm-7 in theme.css) */
    public static function rgb(?int $siteId): array
    {
        $hex = ['1f6f9f', 'c27c0e', '2f8f5b', '7f4fb0', 'c0453a', '138a8a', '6d7322', 'b14f86'][self::idx($siteId)];
        return [hexdec(substr($hex, 0, 2)) / 255, hexdec(substr($hex, 2, 2)) / 255, hexdec(substr($hex, 4, 2)) / 255];
    }

    /** site id => marker number, for scripts */
    public static function map(array $siteIds): array
    {
        $out = [];
        foreach ($siteIds as $id) {
            $out[(int)$id] = self::idx((int)$id);
        }
        return $out;
    }
}
