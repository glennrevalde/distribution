<?php
declare(strict_types=1);

/**
 * Registers the database of config/config.php as Company 1 and creates the platform (master) database and the
 * Super Admin, exactly as System Administration > Multi-Company Setup does, from the command line:
 *
 *   php tools/build_platform.php <super admin username> <super admin password> [owner username]
 *
 * The Company Owner of Company 1 is the user "admin" unless another username is given.
 */
if (PHP_SAPI !== 'cli') {
    exit('Run this from the command line.');
}
require __DIR__ . '/../app/bootstrap.php';
require __DIR__ . '/lib.php';

[$saUser, $saPass] = [$argv[1] ?? '', $argv[2] ?? ''];
$ownerName = $argv[3] ?? 'admin';
if ($saUser === '' || $saPass === '') {
    out('Usage: php tools/build_platform.php <super admin username> <password> [owner username]');
    exit(1);
}
if (Master::enabled()) {
    out('Multi-company is already set up (storage/platform/multi_company.json).');
    exit(1);
}
$owner = DB::row('SELECT * FROM users WHERE username = :u', ['u' => $ownerName]);
if (!$owner) {
    out("No user $ownerName in the company database.");
    exit(1);
}
Auth::actAs((int)$owner['id']);
$s = Settings::all();
$r = Provision::setupPrimary(
    ['username' => $saUser, 'full_name' => 'Platform Super Admin', 'email' => 'superadmin@' . (explode('@', (string)$s['company_email'])[1] ?? 'local.test'), 'password' => $saPass],
    ['name' => (string)$s['company_name'], 'address' => (string)$s['company_address'], 'contact_person' => (string)$owner['full_name'],
        'phone' => (string)$s['company_phone'], 'email' => (string)$s['company_email'], 'tin' => (string)$s['company_tin']],
    (int)$owner['id'],
    true
);
out('Platform set up: Company 1 (code ' . CompanyCode::display($r['code']) . ', ' . ($r['users'] ?? 0) . ' users), master database ' . ($r['master_db'] ?? Master::dbName())
    . ', Super Admin ' . $saUser . '.');
