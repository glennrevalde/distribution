<?php
declare(strict_types=1);

/**
 * The system as an installable app (PWA): an icon on the phone or computer that opens the system in its own
 * window, without the browser's address bar. Nothing is stored for it and the database is not touched.
 *
 *   manifest.php    the app's name, colors, icons and start page (read by the browser when it installs)
 *   sw.js           the service worker: pages are never cached (they hold private data); assets/ is, and
 *                   offline.html is shown when there is no connection
 *   offline.html    the "No internet connection" page
 *   assets/icons/   the app icons (the initials on the menu-rail navy, in crate yellow)
 *   assets/js/pwa.js  registers sw.js (https or localhost only) and runs the "Install app" buttons
 *
 * head() goes in the <head> of every page; installButton() in the top bar; loginBox() on the log-in page.
 * The buttons are hidden inside the installed app itself.
 */
final class Pwa
{
    /** the menu rail (--rail in theme.css): the app's title bar and splash screen */
    public const THEME = '#0f2a3d';
    public const BACKGROUND = '#0f2a3d';

    /** the name under the icon, when the app name is too long for a home screen */
    public const SHORT_NAME = 'G-SMaRT Dist';

    public static function name(): string
    {
        return function_exists('app_name') ? app_name() : APP_PRODUCT_NAME;
    }

    /** the name under the icon: the whole name when it is short, otherwise its first words (up to 12 letters) */
    public static function shortName(): string
    {
        $name = self::name();
        if (mb_strlen($name) <= 12) {
            return $name;
        }
        if ($name === APP_PRODUCT_NAME) {
            return self::SHORT_NAME;
        }
        $short = '';
        foreach (preg_split('/\s+/', $name) ?: [] as $word) {
            if (mb_strlen(trim($short . ' ' . $word)) > 12) {
                break;
            }
            $short = trim($short . ' ' . $word);
        }
        return $short !== '' ? $short : mb_substr($name, 0, 12);
    }

    /** the address of a file next to index.php (the system may sit in a sub-folder, e.g. /gsmart-distribution) */
    private static function root(string $file): string
    {
        $path = base_url() . '/' . $file;
        $full = APP_ROOT . '/' . $file;
        return is_file($full) ? $path . '?v=' . filemtime($full) : $path;
    }

    /** the tags for <head>: manifest, icons, theme color, the iPhone and iPad tags, and the install script */
    public static function head(): string
    {
        $name = h(self::shortName());
        return '<link rel="manifest" href="' . h(base_url() . '/manifest.php') . '">' . "\n"
            . '<link rel="icon" type="image/png" sizes="32x32" href="' . h(asset('icons/favicon-32.png')) . '">' . "\n"
            . '<link rel="apple-touch-icon" sizes="180x180" href="' . h(asset('icons/apple-touch-icon.png')) . '">' . "\n"
            . '<meta name="theme-color" content="' . self::THEME . '">' . "\n"
            . '<meta name="application-name" content="' . $name . '">' . "\n"
            . '<meta name="mobile-web-app-capable" content="yes">' . "\n"
            . '<meta name="apple-mobile-web-app-capable" content="yes">' . "\n"
            . '<meta name="apple-mobile-web-app-status-bar-style" content="black">' . "\n"
            . '<meta name="apple-mobile-web-app-title" content="' . $name . '">' . "\n"
            . '<script src="' . h(asset('js/pwa.js')) . '" data-sw="' . h(self::root('sw.js')) . '" data-scope="' . h(base_url() . '/') . '" data-app="' . h(self::name()) . '" data-icon="' . h(asset('icons/icon-192.png')) . '" defer></script>';
    }

    /** "Install app" in the top bar (hidden inside the installed app) */
    public static function installButton(): string
    {
        return '<button type="button" class="bell-btn pwa-install-btn" data-pwa-install title="Install the system as an app on this device" aria-label="Install app">'
            . '<i class="bi bi-download"></i><span class="pwa-install-text">Install app</span></button>';
    }

    /** "Install the app" on the log-in page (hidden inside the installed app) */
    public static function loginBox(): string
    {
        return '<div class="pwa-login-box" data-pwa-box>'
            . '<span class="pwa-login-icon"><img src="' . h(asset('icons/icon-192.png')) . '" alt="" width="40" height="40"></span>'
            . '<div class="pwa-login-text"><strong>Install the app</strong><span>Open the system from an icon on this phone or computer, in its own window.</span></div>'
            . '<button type="button" class="btn btn-sm btn-outline-primary" data-pwa-install><i class="bi bi-download"></i> Install</button></div>';
    }
}
