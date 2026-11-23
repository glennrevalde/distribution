<?php
declare(strict_types=1);

require __DIR__ . '/app/bootstrap.php';
require __DIR__ . '/views/layout.php';

// already logged in: into a company, or (several companies) on the platform pages as a Super Admin
if (!DB::isBlocked() && Auth::user()) {
    redirect(url('home.dashboard'));
}
if (Tenant::isMulti() && !Tenant::id() && Platform::admin()) {
    redirect(purl());
}

$error = '';
if (is_post()) {
    verify_csrf();
    // which company (or the platform) the username belongs to is decided on the server: app/Login.php
    [$ok, $error, $to] = Login::attempt((string)p('username'), (string)($_POST['password'] ?? ''));
    if ($ok) {
        redirect($to);
    }
}
$app = app_name();
$multi = Tenant::isMulti();
$companyName = $multi ? '' : (string)Settings::get('company_name');
// the four crates that land on the scale, and what the scale reads once they are all on it
$weights = [12.45, 12.34, 12.56, 12.54];
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<?= Pwa::head() ?>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Log in - <?= h($app) ?></title>
<link rel="stylesheet" href="<?= h(vendor_asset('bootstrap.css')) ?>">
<link rel="stylesheet" href="<?= h(vendor_asset('icons.css')) ?>">
<link rel="stylesheet" href="<?= h(asset('css/app.css')) ?>">
<link rel="stylesheet" href="<?= h(asset('css/theme.css')) ?>">
</head>
<body class="gs login-page">
<div class="login-wrap">
  <section class="login-art" aria-hidden="true">
    <div class="rail-logo"><?= brand_mark() ?><span class="rail-name"><strong>G-SMaRT</strong><span>Distribution System</span></span></div>
    <div class="login-stage">
      <svg viewBox="0 0 460 310" role="presentation">
        <defs>
          <symbol id="crt" viewBox="0 0 130 74">
            <rect x="0" y="5" width="130" height="69" rx="7" fill="#f2b705"/>
            <rect x="0" y="62" width="130" height="12" rx="6" fill="#d39f00"/>
            <rect x="0" y="5" width="130" height="5" rx="2.5" fill="#ffd54a"/>
            <g fill="#0f2a3d" opacity=".78">
              <rect x="12" y="19" width="22" height="8" rx="3"/><rect x="41" y="19" width="22" height="8" rx="3"/><rect x="70" y="19" width="22" height="8" rx="3"/><rect x="99" y="19" width="19" height="8" rx="3"/>
              <rect x="12" y="34" width="22" height="8" rx="3"/><rect x="41" y="34" width="22" height="8" rx="3"/><rect x="70" y="34" width="22" height="8" rx="3"/><rect x="99" y="34" width="19" height="8" rx="3"/>
              <rect x="12" y="49" width="22" height="8" rx="3"/><rect x="41" y="49" width="22" height="8" rx="3"/><rect x="70" y="49" width="22" height="8" rx="3"/><rect x="99" y="49" width="19" height="8" rx="3"/>
            </g>
            <rect x="44" y="0" width="42" height="11" rx="5" fill="#c69300"/>
            <rect x="53" y="3" width="24" height="5" rx="2.5" fill="#0f2a3d"/>
          </symbol>
        </defs>
        <ellipse cx="230" cy="292" rx="190" ry="10" fill="#06141e" opacity=".55"/>
        <rect x="70" y="262" width="320" height="12" rx="3" fill="#33495b"/>
        <rect x="58" y="252" width="344" height="14" rx="4" fill="#4d6577"/>
        <rect x="58" y="252" width="344" height="3" rx="1.5" fill="#7590a4"/>
        <rect x="88" y="274" width="12" height="14" rx="2" fill="#24384a"/><rect x="360" y="274" width="12" height="14" rx="2" fill="#24384a"/>
        <use href="#crt" class="crate-drop d1" x="96" y="178" width="130" height="74"/>
        <use href="#crt" class="crate-drop d2" x="234" y="178" width="130" height="74"/>
        <use href="#crt" class="crate-drop d3" x="165" y="104" width="130" height="74"/>
        <use href="#crt" class="crate-drop d4" x="165" y="30" width="130" height="74"/>
      </svg>
      <div class="login-scale scale-readout"><span class="scale-digits" id="loginScale">0.00</span><span class="scale-unit">kg</span></div>
    </div>
    <div class="login-company"><?php if ($companyName !== ''): ?><strong><?= h($companyName) ?></strong><?php endif; ?>Crates weighed in, followed and sold, crate by crate.</div>
  </section>
  <main class="login-side">
    <div class="login-form">
      <div class="login-mobile-brand"><?= brand_mark() ?><div><strong>G-SMaRT</strong><span>Distribution System</span></div></div>
      <h1>Log in</h1>
      <p class="lead-line"><?= $multi ? 'Use the username your company gave you.' : h($companyName) ?></p>
      <?php foreach (take_flash() as [$type, $msg]): ?>
        <div class="alert alert-<?= h($type) ?> py-2"><?= h($msg) ?></div>
      <?php endforeach; ?>
      <?php if ($error): ?><div class="alert alert-danger py-2" role="alert"><?= h($error) ?></div><?php endif; ?>
      <form method="post" autocomplete="off">
        <?= csrf_field() ?>
        <div class="mb-3"><label class="form-label" for="lgUser">Username</label>
          <input class="form-control" id="lgUser" name="username" value="<?= h(p('username')) ?>" required autofocus autocapitalize="none" spellcheck="false"></div>
        <div class="mb-4"><label class="form-label" for="lgPass">Password</label>
          <div class="pw-wrap"><input class="form-control" type="password" id="lgPass" name="password" required>
            <button type="button" class="pw-eye" id="lgEye" aria-label="Show the password" title="Show the password"><i class="bi bi-eye"></i></button></div></div>
        <button class="btn btn-primary w-100"><i class="bi bi-box-arrow-in-right"></i> Log in</button>
      </form>
      <?php if ($multi): ?>
      <div class="login-join mt-3">New employee? <a href="<?= h(base_url() . '/register.php') ?>">Join your company with its Company Code</a></div>
      <?php endif; ?>
      <?= Pwa::loginBox() ?>
      <div class="login-foot"><span>Every log-in, failed attempt and action is recorded in the audit trail.</span>
        <?php if (Manual::available()): ?><a href="<?= h(Manual::forPage('login')) ?>" target="_blank" rel="noopener"><i class="bi bi-book"></i> User's Manual</a><?php endif; ?></div>
    </div>
  </main>
</div>
<script>
(function () {
  var eye = document.getElementById('lgEye'), pw = document.getElementById('lgPass');
  if (eye) eye.addEventListener('click', function () {
    var show = pw.type === 'password';
    pw.type = show ? 'text' : 'password';
    eye.innerHTML = show ? '<i class="bi bi-eye-slash"></i>' : '<i class="bi bi-eye"></i>';
    eye.setAttribute('aria-label', show ? 'Hide the password' : 'Show the password');
    pw.focus();
  });
  // the scale reads each crate as it lands (once, when the page opens)
  var out = document.getElementById('loginScale');
  if (!out || out.offsetParent === null) return;
  var weights = <?= json_encode($weights) ?>, lands = [850, 1150, 1450, 1750], total = 0;
  if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    out.textContent = weights.reduce(function (a, b) { return a + b; }, 0).toFixed(2);
    return;
  }
  weights.forEach(function (w, i) {
    setTimeout(function () {
      var from = total, to = total + w, t0 = performance.now();
      total = to;
      (function step(now) {
        var k = Math.min(1, (now - t0) / 260);
        out.textContent = (from + (to - from) * (1 - Math.pow(1 - k, 3))).toFixed(2);
        if (k < 1) requestAnimationFrame(step); else { out.classList.remove('tick'); void out.offsetWidth; out.classList.add('tick'); }
      })(t0);
    }, lands[i]);
  });
})();
</script>
</body>
</html>
