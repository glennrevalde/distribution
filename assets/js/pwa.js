/*
 * The system as an installable app (PWA). See app/Pwa.php.
 *
 * - Registers sw.js, only on https or on localhost (browsers allow service workers nowhere else).
 * - "Install app" (top bar) and "Install the app" (log-in page): when the browser offers to install, its own install
 *   window opens; otherwise a window explains how to install in this browser. Both are hidden inside the installed app.
 */
(function () {
  'use strict';
  var me = document.currentScript || document.querySelector('script[data-sw]');
  var cfg = me ? me.dataset : {};
  var appName = cfg.app || 'the system';
  var host = location.hostname;
  var isLocal = host === 'localhost' || host === '127.0.0.1' || host === '[::1]' || host === '::1' || /\.localhost$/.test(host);
  var secure = location.protocol === 'https:' || isLocal;
  var deferred = null;

  // ------------------------------------------------------------------ inside the installed app?
  function standalone() {
    var mm = window.matchMedia;
    return !!(navigator.standalone === true || (mm && (mm('(display-mode: standalone)').matches || mm('(display-mode: fullscreen)').matches
      || mm('(display-mode: window-controls-overlay)').matches)));
  }
  function paint() {
    var inApp = standalone();
    document.documentElement.classList.toggle('pwa-standalone', inApp);
    document.querySelectorAll('[data-pwa-install], [data-pwa-box]').forEach(function (el) {
      if (el.matches('[data-pwa-box] [data-pwa-install]')) return;   // the button inside the log-in box follows its box
      el.hidden = inApp;
    });
    document.querySelectorAll('[data-pwa-install]').forEach(function (el) { el.classList.toggle('is-ready', !!deferred); });
  }
  paint();
  document.addEventListener('DOMContentLoaded', paint);
  if (window.matchMedia) {
    var dm = window.matchMedia('(display-mode: standalone)');
    if (dm.addEventListener) dm.addEventListener('change', paint);
  }

  // ------------------------------------------------------------------ the service worker
  if (secure && 'serviceWorker' in navigator && cfg.sw) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register(cfg.sw, { scope: cfg.scope || './' }).catch(function (e) {
        if (window.console) console.warn('The app service worker was not registered:', e && e.message);
      });
    });
  }

  // ------------------------------------------------------------------ the browser's own install window
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();          // kept for our buttons instead of the browser's own banner
    deferred = e;
    paint();
  });
  window.addEventListener('appinstalled', function () {
    deferred = null;
    paint();
    closeHelp();
    say(appName + ' was installed. Open it from its icon.');
  });

  document.addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('[data-pwa-install]') : null;
    if (!b) return;
    e.preventDefault();
    if (deferred) {
      var ev = deferred;
      deferred = null;
      ev.prompt();
      (ev.userChoice || Promise.resolve({})).then(function (r) {
        if (r && r.outcome === 'dismissed') say('Not installed. Press Install app again whenever you want it.');
        paint();
      }).catch(paint);
      return;
    }
    openHelp(b);
  });

  function say(text) {
    if (window.AppToast) { window.AppToast(text); return; }
    var t = document.createElement('div');
    t.className = 'pwa-toast';
    t.setAttribute('role', 'status');
    t.textContent = text;
    document.body.appendChild(t);
    setTimeout(function () { t.classList.add('is-on'); }, 20);
    setTimeout(function () { t.classList.remove('is-on'); setTimeout(function () { t.remove(); }, 400); }, 3600);
  }

  // ------------------------------------------------------------------ how to install, in this browser
  var ua = navigator.userAgent || '';
  var ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var android = /Android/.test(ua);
  var samsung = /SamsungBrowser/.test(ua);
  var edge = /Edg(e|A|iOS)?\//.test(ua);
  var firefox = /Firefox|FxiOS/.test(ua);
  var opera = /OPR\/|Opera/.test(ua);
  var chrome = /Chrome|CriOS/.test(ua) && !edge && !samsung && !opera;
  var safariMac = !ios && /Macintosh/.test(ua) && /Safari/.test(ua) && !chrome && !edge && !firefox && !opera;

  var GUIDES = {
    ios: { title: 'iPhone and iPad', steps: [
      'Open the system in <strong>Safari</strong> (on iOS 16.4 and later, Chrome and Edge work too).',
      'Tap the <strong>Share</strong> button <span class="pwa-key" aria-hidden="true"><i class="bi bi-box-arrow-up"></i></span> at the bottom of the screen (at the top on an iPad).',
      'Scroll down and tap <strong>Add to Home Screen</strong>, then <strong>Add</strong>.'] },
    android: { title: 'Android (Chrome)', steps: [
      'Tap the menu <span class="pwa-key" aria-hidden="true"><i class="bi bi-three-dots-vertical"></i></span> at the top right.',
      'Tap <strong>Install app</strong> (or <strong>Add to Home screen</strong>), then <strong>Install</strong>.'] },
    chrome: { title: 'Chrome on a computer', steps: [
      'Click the install icon <span class="pwa-key" aria-hidden="true"><i class="bi bi-display"></i></span> at the right end of the address bar. '
        + 'If it is not there, open the menu <span class="pwa-key" aria-hidden="true"><i class="bi bi-three-dots-vertical"></i></span> &gt; <strong>Cast, save and share</strong> &gt; <strong>Install page as app</strong>.',
      'Click <strong>Install</strong>.'] },
    edge: { title: 'Microsoft Edge', steps: [
      'On a computer: open the menu <span class="pwa-key" aria-hidden="true"><i class="bi bi-three-dots"></i></span> &gt; <strong>Apps</strong> &gt; <strong>Install this site as an app</strong>, then <strong>Install</strong>.',
      'On Android: menu <span class="pwa-key" aria-hidden="true"><i class="bi bi-three-dots"></i></span> &gt; <strong>Add to phone</strong>.'] },
    samsung: { title: 'Samsung Internet', steps: [
      'Tap the menu <span class="pwa-key" aria-hidden="true"><i class="bi bi-list"></i></span> &gt; <strong>Add page to</strong> &gt; <strong>Home screen</strong>.'] },
    firefox: { title: 'Firefox', steps: [
      'On Android: menu <span class="pwa-key" aria-hidden="true"><i class="bi bi-three-dots-vertical"></i></span> &gt; <strong>Add app to Home screen</strong>.',
      'On a computer, Firefox does not install apps: open the system in Chrome or Edge to install it.'] },
    safari: { title: 'Safari on a Mac', steps: [
      'Choose <strong>File</strong> &gt; <strong>Add to Dock</strong> (macOS Sonoma or later), then <strong>Add</strong>.'] }
  };
  var mine = ios ? 'ios' : samsung ? 'samsung' : edge ? 'edge' : firefox ? 'firefox' : android ? 'android' : safariMac ? 'safari' : 'chrome';

  var dlg = null, back = null;
  function guide(key, open) {
    var g = GUIDES[key];
    return '<section class="pwa-guide' + (open ? ' is-mine' : '') + '"><h3>' + g.title + '</h3><ol>'
      + g.steps.map(function (s) { return '<li>' + s + '</li>'; }).join('') + '</ol></section>';
  }
  function closeHelp() { if (dlg && dlg.open) dlg.close(); }
  function openHelp(from) {
    back = from;
    if (!dlg) {
      dlg = document.createElement('dialog');
      dlg.className = 'pwa-dialog';
      dlg.setAttribute('aria-labelledby', 'pwaTitle');
      document.body.appendChild(dlg);
      dlg.addEventListener('click', function (e) {
        if (e.target === dlg || (e.target.closest && e.target.closest('[data-pwa-close]'))) closeHelp();
      });
      dlg.addEventListener('close', function () { if (back && back.focus) back.focus(); });
    }
    var https = secure ? '' : '<div class="pwa-warn" role="note"><i class="bi bi-shield-lock"></i><div><strong>Installing needs a secure address.</strong> '
      + 'This page was opened at <code>' + location.protocol + '//' + location.host + '</code>. Browsers install apps only from an <strong>https://</strong> address, '
      + 'or from <strong>localhost</strong> on the computer that runs the system. Ask your administrator for the https address of the system, then install from there.</div></div>';
    var others = Object.keys(GUIDES).filter(function (k) { return k !== mine; });
    dlg.innerHTML = '<div class="pwa-dialog-head"><img src="' + (cfg.icon || iconUrl()) + '" alt="" width="40" height="40">'
      + '<div><h2 id="pwaTitle">Install ' + esc(appName) + '</h2><p>It opens from its own icon, in a window without the address bar.</p></div>'
      + '<button type="button" class="btn-close" data-pwa-close aria-label="Close"></button></div>'
      + '<div class="pwa-dialog-body">' + https
      + '<p class="pwa-lead">' + (!secure ? 'Once it is open at an https address:' : ios ? 'On an iPhone or iPad the app is added from the Share menu:'
        : 'This browser has not offered to install it from here. Follow these steps instead:') + '</p>'
      + guide(mine, true)
      + '<details class="pwa-more"><summary>Other browsers</summary>' + others.map(function (k) { return guide(k, false); }).join('') + '</details>'
      + (secure && !ios ? '<p class="pwa-note">If Install is not in the menu, the app may already be installed on this device: look for it among your apps.</p>' : '')
      + '</div><div class="pwa-dialog-foot"><button type="button" class="btn btn-primary" data-pwa-close>OK</button></div>';
    if (typeof dlg.showModal === 'function') {
      dlg.showModal();
      var ok = dlg.querySelector('.pwa-dialog-foot .btn');
      if (ok) ok.focus();
    } else {
      alert('Install ' + appName + ': ' + GUIDES[mine].steps.map(function (s) { return s.replace(/<[^>]+>/g, ''); }).join(' '));
    }
  }
  function iconUrl() { return (cfg.scope || './') + 'assets/icons/icon-192.png'; }
  function esc(t) { return String(t).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  // for the checks of the system's own tests
  window.AppPwa = { standalone: standalone, secure: secure, browser: mine, help: openHelp, canPrompt: function () { return !!deferred; } };
})();
