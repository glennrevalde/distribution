/* G-SMaRT Distribution System - small touches of the interface (no build step)
 *  - the conveyor along the top while the next page loads, after a click on a link or a save
 *  - "/" puts the cursor in the search box
 */
(function () {
  'use strict';
  const root = document.documentElement;
  const leaving = () => root.classList.add('is-leaving');
  const settle = () => root.classList.remove('is-leaving');

  document.addEventListener('click', (e) => {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const a = e.target.closest && e.target.closest('a[href]');
    if (!a || a.target === '_blank' || a.hasAttribute('download') || a.hasAttribute('data-bs-toggle')) return;
    const href = a.getAttribute('href') || '';
    if (href === '' || href.charAt(0) === '#' || /^(javascript|mailto|tel):/i.test(href)) return;
    try {
      const u = new URL(a.href, window.location.href);
      if (u.origin !== window.location.origin) return;
      if (u.pathname === window.location.pathname && u.search === window.location.search && u.hash) return;
    } catch (err) { return; }
    leaving();
  });
  // a form that is really sent (not stopped by a question or a check) starts the conveyor
  document.addEventListener('submit', (e) => {
    const f = e.target;
    if (f.target === '_blank') return;
    setTimeout(() => { if (!e.defaultPrevented) leaving(); }, 0);
  });
  window.addEventListener('pageshow', settle);
  window.addEventListener('pagehide', () => setTimeout(settle, 0));

  document.addEventListener('keydown', (e) => {
    if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
    const t = e.target;
    if (t && (t.isContentEditable || /^(input|textarea|select)$/i.test(t.tagName))) return;
    const box = document.querySelector('.app-search input[type=search]');
    if (box && box.offsetParent !== null) { e.preventDefault(); box.focus(); }
  });
})();
