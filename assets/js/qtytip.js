/* G-SMaRT Distribution System - quantities with their unit, and what they are made of (v4, no build step)
 *
 * Transfer Inventory and Dispatch Inventory show every quantity with its unit after it (1,783.53 kg). When the item
 * has two or more units (crates and loose kilos, packs and boxes of 20), hovering the quantity - or tapping it on a
 * phone - shows what it is made of in a tooltip: "In 52 crates: 683.53 kg", "Loose: 1,100.00 kg", "= 4.40 box".
 *
 *   QtyTip.set(element, lines, title)   lines [] takes the tooltip away
 *   QtyTip.figure(element, qty, unit)   writes "1,783.53 kg" into the element
 *   QtyTip.units(qty, info)             the lines for a quantity of an item: info = {base, units: [[code, factor]]}
 */
(function () {
  'use strict';
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const num = (v) => { const n = parseFloat(String(v == null ? '' : v).replace(/,/g, '')); return isFinite(n) ? n : 0; };
  const isWeight = (b) => { const t = String(b || '').trim().toLowerCase(); return /^(kg|kgs|kilo|kilos|kilogram|kilograms|g|lb|lbs)$/.test(t) || t.indexOf('kilo') >= 0; };
  /** weights always with two decimals (12.30 kg); counts as they are (40 pack) */
  const fig = (v, unit) => {
    const n = Math.round(num(v) * 10000) / 10000;
    return isWeight(unit) || unit === ''
      ? n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
      : n.toLocaleString('en-US', { maximumFractionDigits: 4 });
  };

  function set(el, lines, title) {
    if (!el) return;
    const B = window.bootstrap && window.bootstrap.Tooltip;
    const old = B ? B.getInstance(el) : null;
    if (old) old.dispose();
    const on = !!(lines && lines.length);
    el.classList.toggle('has-qty-tip', on);
    if (!on) {
      if (el.dataset.qtTab) { el.removeAttribute('tabindex'); delete el.dataset.qtTab; }
      el.removeAttribute('title');
      el.removeAttribute('aria-label');
      return;
    }
    const html = (title ? '<div class="qt-title">' + esc(title) + '</div>' : '') + lines.map((l) => '<div class="qt-line">' + esc(l) + '</div>').join('');
    // a figure that is not a form field can still be reached by the keyboard, and tapped on a phone
    if (!el.matches('input, select, textarea, button, a') && !el.hasAttribute('tabindex')) { el.tabIndex = 0; el.dataset.qtTab = '1'; }
    el.setAttribute('aria-label', (title ? title + '. ' : '') + lines.join('. '));
    if (B) {
      new B(el, { title: html, html: true, trigger: 'hover focus', placement: 'top', customClass: 'qty-tooltip', container: 'body' });
    } else {
      el.title = (title ? title + '\n' : '') + lines.join('\n');
    }
  }

  function figure(el, qty, unit) {
    if (!el) return;
    el.innerHTML = '<span class="qty-fig">' + esc(fig(qty, unit)) + '</span>' + (unit ? ' <span class="qty-unit">' + esc(unit) + '</span>' : '');
  }

  function units(qty, info) {
    const out = [];
    if (!info || !(info.units || []).length || !num(qty)) return out;
    info.units.forEach((u) => {
      const f = num(u[1]);
      if (f > 0) out.push('= ' + (Math.round(num(qty) / f * 100) / 100).toLocaleString('en-US', { maximumFractionDigits: 2 }) + ' ' + u[0] + ' (' + fig(f, info.base) + ' ' + info.base + ' each)');
    });
    return out;
  }

  window.QtyTip = { set, figure, units, fig, isWeight };
})();
