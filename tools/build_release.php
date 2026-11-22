<?php
declare(strict_types=1);

/**
 * Builds the two importable database files of a release from scratch:
 *
 *   php tools/build_release.php
 *
 *   database/gsmart_distribution_clean.sql   setup only: chart of accounts, lists, units (crates), sites, POS terminals,
 *                                            roles, page access and users; no customers, suppliers, items or transactions
 *   database/gsmart_distribution_sample.sql  the same plus a sample chicken and frozen food distributor: items, suppliers,
 *                                            customers, about two and a half months of transactions, allocations and crates
 *
 * Each file holds BOTH databases: the company database (Company 1, the name in config/config.php) and the platform
 * (master) database with the Super Admin and Company 1 registered, so several companies can be added straight away.
 * DESTROYS the databases it builds: run it on a development server only.
 */
if (PHP_SAPI !== 'cli') {
    exit('Run this from the command line.');
}
require __DIR__ . '/../app/bootstrap.php';
require __DIR__ . '/lib.php';

const SA_USERNAME = 'superadmin';
const SA_PASSWORD = 'SuperAdmin@2026';

$php = escapeshellarg(PHP_BINARY);
$name = (string)$GLOBALS['CONFIG']['db']['name'];
$masterName = substr($name, 0, 57) . '_master';
$flag = APP_ROOT . Master::FLAG_FILE;

foreach (['clean' => false, 'sample' => true] as $kind => $demo) {
    out("== $kind");
    @unlink($flag);
    server_pdo()->exec("DROP DATABASE IF EXISTS `$masterName`");
    passthru("$php " . escapeshellarg(APP_ROOT . '/tools/install.php') . ' --drop' . ($demo ? ' --demo' : ''), $rc);
    if ($rc !== 0) {
        exit($rc);
    }
    if (!$demo) {
        // a clean database keeps the setup and the users, and nothing a company enters itself
        $pdo = DB::pdo();
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');
        foreach (['vendor_items', 'process_formula_lines', 'process_formulas', 'item_components', 'price_level_items', 'item_site_stock', 'items',
                  'customers', 'vendors', 'entity_notes', 'sales_reps'] as $t) {
            $pdo->exec("DELETE FROM `$t`");
            $pdo->exec("ALTER TABLE `$t` AUTO_INCREMENT = 1");
        }
        $pdo->exec("INSERT INTO sales_reps (name, initials, user_id, commission_pct) SELECT 'Maria Santos', 'MS', id, 1.5 FROM users WHERE username = 'salesrep'");
        $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');
        foreach (['company_name' => 'Your Company Name', 'company_address' => 'Company address', 'company_tin' => '', 'company_phone' => '', 'company_email' => ''] as $k => $v) {
            Settings::set($k, $v);
        }
    }
    // the platform: Company 1 with its owner, and the Super Admin who adds the other companies
    passthru("$php " . escapeshellarg(APP_ROOT . '/tools/build_platform.php') . ' ' . escapeshellarg(SA_USERNAME) . ' ' . escapeshellarg(SA_PASSWORD), $rc);
    if ($rc !== 0) {
        exit($rc);
    }
    $title = $demo ? 'G-SMaRT Distribution System - complete database with sample data' : 'G-SMaRT Distribution System - clean database (setup lists and users, no transactions)';
    passthru("$php " . escapeshellarg(APP_ROOT . '/tools/export_sql.php') . ' --with-master'
        . ' --out=' . escapeshellarg(APP_ROOT . "/database/gsmart_distribution_$kind.sql") . ' --title=' . escapeshellarg($title), $rc);
    if ($rc !== 0) {
        exit($rc);
    }
}
out('Done. Super Admin: ' . SA_USERNAME . ' / ' . SA_PASSWORD);
