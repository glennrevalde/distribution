/*
 * G-SMaRT Distribution System: the service worker of the installable app (see app/Pwa.php).
 *
 * - Pages are NEVER cached: they hold the company's private data. Every page comes from the server.
 * - With no connection, a page that cannot be opened shows offline.html instead of the browser's error.
 * - Only assets/ is cached (stylesheets, scripts, fonts, icons), so the app opens quickly.
 * - POST requests (saves, log-ins, uploads), downloads and exports, other sites and everything else go
 *   straight to the network, untouched.
 *
 * Change VERSION when offline.html changes, so the new one is fetched; the cached assets follow their own
 * ?v= numbers by themselves.
 */
'use strict';

const VERSION = 'gsd-pwa-1';
const ASSET_CACHE = VERSION + '-assets';
const OFFLINE_CACHE = VERSION + '-offline';
const BASE = new URL('./', self.location).pathname;                 // /gsmart-distribution/ or /
const OFFLINE_URL = BASE + 'offline.html';
// offline.html and what it shows, kept from the start
const PRECACHE = [
  OFFLINE_URL,
  BASE + 'assets/icons/icon-192.png',
  BASE + 'assets/fonts/barlow-latin-400-normal.woff2',
  BASE + 'assets/fonts/barlow-semi-condensed-latin-700-normal.woff2'
];
const ASSET_TYPES = /\.(css|js|woff2?|ttf|otf|eot|svg|png|ico|webp|gif)$/i;
const DOWNLOAD_TYPES = /\.(csv|xlsx?|pdf|zip|sql|txt|docx?|json|xml|eml)$/i;
const DOWNLOAD_PARAMS = ['export', 'pdf', 'dl', 'download', 'file'];
const DOWNLOAD_ACTIONS = ['download', 'file', 'photo', 'attachment', 'backup', 'export'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(OFFLINE_CACHE)
      .then((cache) => cache.addAll(PRECACHE.map((u) => new Request(u, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.indexOf(VERSION + '-') !== 0).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

/** a file being downloaded or exported: left to the browser */
function isDownload(url) {
  if (DOWNLOAD_TYPES.test(url.pathname)) return true;
  if (DOWNLOAD_PARAMS.some((k) => url.searchParams.get(k))) return true;
  return DOWNLOAD_ACTIONS.indexOf(url.searchParams.get('a') || '') >= 0;
}

/** a stylesheet, script, font or icon of assets/ */
function isAsset(url) {
  return url.pathname.indexOf(BASE + 'assets/') === 0 && ASSET_TYPES.test(url.pathname);
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;                       // saves, log-ins and uploads
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;        // other sites
  if (req.headers.has('range')) return;                   // partial downloads (media)
  if (isDownload(url)) return;                            // exports, PDFs, attachments, backups

  if (req.mode === 'navigate') {
    // a page: always from the server and never kept; offline.html when the server cannot be reached
    event.respondWith(
      fetch(req).catch(() => caches.match(OFFLINE_URL).then((r) => r || new Response(
        '<!doctype html><meta charset="utf-8"><title>No internet connection</title><p>No internet connection. Check the connection and try again.</p>',
        { status: 503, headers: { 'Content-Type': 'text/html; charset=utf-8' } })))
    );
    return;
  }

  if (isAsset(url)) {
    event.respondWith(fromAssets(event, req, url));
  }
  // anything else (data loaded by the pages, reports, pictures of records): the network, nothing kept
});

/**
 * Assets: a versioned file (?v=...) never changes, so a cached copy is used as it is; an unversioned one is shown
 * from the cache and refreshed behind it. A new version replaces the old one in the cache. Offline, any cached
 * version of the file is better than none.
 */
function fromAssets(event, req, url) {
  return caches.open(ASSET_CACHE).then((cache) => cache.match(req).then((hit) => {
    if (hit && url.searchParams.has('v')) return hit;
    const fresh = fetch(req).then((res) => {
      if (res && res.ok && res.type === 'basic') {
        const copy = res.clone();
        event.waitUntil(cache.keys()
          .then((keys) => Promise.all(keys
            .filter((k) => { const u = new URL(k.url); return u.pathname === url.pathname && u.search !== url.search; })
            .map((k) => cache.delete(k))))
          .then(() => cache.put(req, copy)));
      }
      return res;
    });
    if (hit) {
      event.waitUntil(fresh.catch(() => null));
      return hit;
    }
    return fresh.catch(() => caches.match(req, { ignoreSearch: true }).then((r) => r || Response.error()));
  }));
}
