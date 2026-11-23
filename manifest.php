<?php
declare(strict_types=1);

/**
 * The web app manifest: what the browser installs (name, colors, icons, start page). See app/Pwa.php.
 *
 * The name comes from the system's settings (config/config.php, 'app' => 'name'), or the product name.
 * It is read without logging in and without the database. Only the JSON may reach the browser: notices,
 * warnings and any stray output are thrown away, so a PHP message can never break the manifest.
 */
error_reporting(0);
ini_set('display_errors', '0');
ob_start();

$name = 'G-SMaRT Distribution System';
$short = 'G-SMaRT Dist';
$theme = '#0f2a3d';
$background = '#0f2a3d';
try {
    if (!defined('APP_ROOT')) {
        define('APP_ROOT', __DIR__);
    }
    if (is_file(__DIR__ . '/config/config.php')) {
        $GLOBALS['CONFIG'] = require __DIR__ . '/config/config.php';
    }
    if (is_file(__DIR__ . '/app/helpers.php') && is_file(__DIR__ . '/app/Pwa.php')) {
        require_once __DIR__ . '/app/helpers.php';
        require_once __DIR__ . '/app/Pwa.php';
        $name = Pwa::name() ?: $name;
        $short = Pwa::shortName() ?: $short;
        $theme = Pwa::THEME;
        $background = Pwa::BACKGROUND;
    }
} catch (Throwable $e) {
    // the defaults above
}

$icons = [];
foreach ([192, 512] as $size) {
    $icons[] = ['src' => 'assets/icons/icon-' . $size . '.png', 'sizes' => $size . 'x' . $size, 'type' => 'image/png', 'purpose' => 'any'];
}
foreach ([192, 512] as $size) {
    $icons[] = ['src' => 'assets/icons/maskable-' . $size . '.png', 'sizes' => $size . 'x' . $size, 'type' => 'image/png', 'purpose' => 'maskable'];
}

$manifest = [
    'id' => './',
    'name' => $name,
    'short_name' => $short,
    'description' => $name . ': allocations, pick-ups, crates, sales, inventory and accounting.',
    'lang' => 'en',
    'dir' => 'ltr',
    'start_url' => './index.php',
    'scope' => './',
    'display' => 'standalone',
    'orientation' => 'any',
    'theme_color' => $theme,
    'background_color' => $background,
    'categories' => ['business', 'productivity', 'finance'],
    'prefer_related_applications' => false,
    'icons' => $icons,
];

while (ob_get_level() > 0) {
    ob_end_clean();
}
if (!headers_sent()) {
    header('Content-Type: application/manifest+json; charset=utf-8');
    header('Cache-Control: no-cache');
    header('X-Content-Type-Options: nosniff');
}
echo json_encode($manifest, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_INVALID_UTF8_SUBSTITUTE);
