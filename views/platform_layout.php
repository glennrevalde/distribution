<?php
declare(strict_types=1);

/**
 * Page frame of the Super Admin (platform) pages: the same look as the company pages, with the platform's
 * own menu. No company database is open on these pages.
 */

const PLATFORM_MENU = [
    'Companies' => [
        'companies' => ['Companies', 'buildings'],
        'new'       => ['New company', 'plus-square'],
        'updates'   => ['Database updates', 'database-check'],
    ],
    'Platform' => [
        'admins'    => ['Super Admins', 'shield-lock'],
        'settings'  => ['Platform settings', 'sliders'],
        'audit'     => ['Platform audit log', 'journal-text'],
        'account'   => ['My account', 'person-circle'],
    ],
];

function platform_start(string $title, array $opt = []): void
{
    $sa = Platform::admin();
    $current = (string)($GLOBALS['PLATFORM_PAGE'] ?? '');
    $app = app_name();
    ?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<link rel="icon" type="image/svg+xml" href="<?= h(asset('img/favicon.svg')) ?>">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="theme-color" content="#0f2a3d">
<title><?= h($title) ?> - Platform - <?= h($app) ?></title>
<link rel="stylesheet" href="<?= h(vendor_asset('bootstrap.css')) ?>">
<link rel="stylesheet" href="<?= h(vendor_asset('icons.css')) ?>">
<link rel="stylesheet" href="<?= h(asset('css/app.css')) ?>">
<link rel="stylesheet" href="<?= h(asset('css/theme.css')) ?>">
<script src="<?= h(asset('js/fmt.js')) ?>"></script>
</head>
<body class="gs platform">
<div class="nav-progress no-print" aria-hidden="true"><span></span></div>
<div class="app-frame">
  <aside class="offcanvas-lg offcanvas-start rail no-print" id="sidebar" tabindex="-1" aria-label="Platform menu">
    <div class="rail-brand">
      <a class="rail-logo" href="<?= h(purl()) ?>" aria-label="Platform: Companies"><?= brand_mark() ?><span class="rail-name"><strong>G-SMaRT</strong><span>Platform administration</span></span></a>
      <button type="button" class="btn-close btn-close-white d-lg-none" data-bs-dismiss="offcanvas" data-bs-target="#sidebar" aria-label="Close the menu"></button>
    </div>
    <div class="offcanvas-body d-block p-0 rail-scroll">
      <?php foreach (PLATFORM_MENU as $group => $items): ?>
        <div class="menu-group"><?= h($group) ?></div>
        <?php foreach ($items as $k => [$name, $icon]): ?>
          <a class="menu-link platform-link <?= $k === $current ? 'active' : '' ?>" href="<?= h(purl($k)) ?>"<?= $k === $current ? ' aria-current="page"' : '' ?>><i class="bi bi-<?= h($icon) ?>"></i><?= h($name) ?></a>
        <?php endforeach; ?>
      <?php endforeach; ?>
    </div>
    <div class="rail-foot"><i class="bi bi-shield-lock"></i><span>Super Admin: every company of the system</span></div>
  </aside>
  <div class="app-main">
  <header class="topbar no-print">
    <button class="topbar-btn d-lg-none" type="button" data-bs-toggle="offcanvas" data-bs-target="#sidebar" aria-label="Open the menu"><i class="bi bi-list"></i></button>
    <a class="topbar-mark d-lg-none" href="<?= h(purl()) ?>" aria-label="Companies"><?= brand_mark() ?></a>
    <div class="topbar-where d-none d-md-flex"><span class="topbar-company">Platform</span><span class="topbar-module"><?= h($title) ?></span></div>
    <?php if ($sa): ?>
    <div class="topbar-tools">
      <div class="dropdown">
        <button class="user-btn dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false"><span class="user-ini" aria-hidden="true"><?= h(user_initials((string)$sa['full_name'])) ?></span><span class="user-name"><?= h($sa['full_name']) ?></span></button>
        <ul class="dropdown-menu dropdown-menu-end">
          <li><span class="dropdown-item-text small text-muted">Super Admin</span></li>
          <li><a class="dropdown-item" href="<?= h(purl('account')) ?>"><i class="bi bi-key"></i> Change password</a></li>
          <?php if (Manual::available()): ?>
          <li><a class="dropdown-item" href="<?= h(Manual::url()) ?>" target="_blank" rel="noopener"><i class="bi bi-book"></i> User's Manual</a></li>
          <?php endif; ?>
          <li><hr class="dropdown-divider"></li>
          <li><form method="post" action="<?= h(purl('companies', ['a' => 'logout'])) ?>"><?= csrf_field() ?><button class="dropdown-item"><i class="bi bi-box-arrow-right"></i> Log out</button></form></li>
        </ul>
      </div>
    </div>
    <?php endif; ?>
  </header>
  <main class="main-area" id="main">
    <?php foreach (take_flash() as [$type, $msg]): ?>
      <div class="alert alert-<?= h($type) ?> alert-dismissible fade show no-print" role="alert"><?= h($msg) ?><button type="button" class="btn-close" data-bs-dismiss="alert"></button></div>
    <?php endforeach; ?>
    <div class="page-bar">
      <h1><?= h($title) ?></h1>
      <div class="page-actions no-print"><?= $opt['actions'] ?? '' ?><?= $sa ? Manual::helpButton(Manual::forPlatform($current)) : '' ?></div>
    </div>
    <?= form_error() ?>
<?php
}

function platform_end(): void
{
    ?>
  </main>
  </div>
</div>
<script src="<?= h(vendor_asset('bootstrap.js')) ?>"></script>
<script src="<?= h(asset('js/app.js')) ?>"></script>
<script src="<?= h(asset('js/theme.js')) ?>"></script>
</body>
</html>
<?php
}

/** Company status in words, with a colour cue (plain text, no badge) */
function platform_status(string $status): string
{
    $t = ['active' => 'Active', 'inactive' => 'Inactive', 'provisioning' => 'Being set up', 'failed' => 'Set-up failed'][$status] ?? ucfirst($status);
    return '<span class="co-state co-' . h($status) . '">' . h($t) . '</span>';
}
