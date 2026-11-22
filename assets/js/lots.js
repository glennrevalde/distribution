/*
 * v43: production and expiry dates on the item lines of the transaction forms (app/Lots.php).
 *
 *  table.line-grid[data-lots="in"]   stock coming in: two date boxes per line. Choosing an item on a line copies the
 *                                    dates of the line above; typing dates on a line fills the lines below that have
 *                                    an item and no dates yet, and so on. Every date stays editable.
 *  table.line-grid[data-lots="out"]  stock going out: the date group to take the stock from, with the quantity at the
 *                                    line's site, or "First in, first out". The groups are asked for when the item or
 *                                    the site changes (api.lots). v44: a quantity past what is left of the chosen
 *                                    group is marked (a sale may not take more than the balance of a date group).
 * Lines of items that keep no dates have the boxes switched off.
 */
(function () {
  'use strict';
  var cache = {};

  function items(table) {
    if (!table._lotItems) {
      try { table._lotItems = JSON.parse(table.dataset.items || '{}'); } catch (e) { table._lotItems = {}; }
    }
    return table._lotItems;
  }
  function field(tr, f) { return tr.querySelector('[data-f="' + f + '"]'); }
  function tracked(table, tr) {
    var sel = field(tr, 'item_id');
    var it = sel ? items(table)[sel.value] : null;
    return !!(it && it.lot);
  }
  function siteOf(table, tr) {
    var own = tr.querySelector('select[name$="[site_id]"]');
    if (own && own.value) return own.value;
    var form = table.closest('form');
    var head = form ? form.querySelector('select[name="site_id"]') : null;
    if (head && head.value) return head.value;
    return table.dataset.lotsSite || '';
  }
  function setOn(table, tr) {
    var on = tracked(table, tr);
    tr.querySelectorAll('.col-lot, .col-lotpick').forEach(function (td) {
      td.classList.toggle('lot-off', !on);
      td.querySelectorAll('input, select').forEach(function (el) { el.disabled = !on; });
    });
    return on;
  }

  // ---------------------------------------------------------------- coming in: dates copied down
  function datesOf(tr) {
    var p = field(tr, 'production_date'), e = field(tr, 'expiry_date');
    return [p ? p.value : '', e ? e.value : ''];
  }
  function copyFromAbove(table, tr) {
    var d = datesOf(tr);
    if (d[0] || d[1]) return;
    var prev = tr.previousElementSibling;
    while (prev) {
      var pd = datesOf(prev);
      if (tracked(table, prev) && (pd[0] || pd[1])) {
        field(tr, 'production_date').value = pd[0];
        field(tr, 'expiry_date').value = pd[1];
        tr.dataset.lotCopied = '1';
        return;
      }
      prev = prev.previousElementSibling;
    }
  }
  function copyDown(table, tr) {
    var d = datesOf(tr);
    var next = tr.nextElementSibling;
    while (next) {
      if (tracked(table, next)) {
        var nd = datesOf(next);
        // a line given its own dates stops the copying
        if ((nd[0] || nd[1]) && next.dataset.lotCopied !== '1') break;
        field(next, 'production_date').value = d[0];
        field(next, 'expiry_date').value = d[1];
        next.dataset.lotCopied = '1';
      }
      next = next.nextElementSibling;
    }
  }

  // ---------------------------------------------------------------- going out: the date groups of the site
  function load(table, ids, site, done) {
    var key = site + ':' + (table.dataset.lotsTxn || '');
    cache[key] = cache[key] || {};
    var want = ids.filter(function (id) { return id && !(id in cache[key]); });
    if (!want.length) { done(cache[key]); return; }
    var url = table.dataset.lotsUrl + '&item_ids=' + want.join(',') + '&site_id=' + encodeURIComponent(site)
      + (table.dataset.lotsTxn ? '&exclude=' + table.dataset.lotsTxn : '');
    fetch(url, { credentials: 'same-origin', headers: { 'X-Background': '1' } })
      .then(function (r) { return r.json(); })
      .then(function (j) {
        want.forEach(function (id) { cache[key][id] = (j.groups && j.groups[id]) || []; });
        done(cache[key]);
      })
      .catch(function () { done(cache[key]); });
  }
  function fill(table, tr, groups) {
    var sel = field(tr, 'lot');
    if (!sel) return;
    var cur = sel.value;
    var item = field(tr, 'item_id').value;
    var list = groups[item] || [];
    var html = '<option value="">First in, first out</option>';
    var seen = cur === '';
    list.forEach(function (g) {
      var on = g.key === cur;
      if (on) seen = true;
      html += '<option value="' + g.key + '"' + (on ? ' selected' : '') + ' data-status="' + g.status + '">' + esc(g.text) + '</option>';
    });
    if (!seen) {
      var old = sel.querySelector('option[value="' + cur.replace(/"/g, '') + '"]');
      html += '<option value="' + esc(cur) + '" selected>' + esc(old ? old.textContent : cur) + '</option>';
    }
    sel.innerHTML = html;
    mark(sel);
  }
  function mark(sel) {
    var o = sel.options[sel.selectedIndex];
    var st = o ? o.getAttribute('data-status') : '';
    sel.classList.toggle('lot-expired', st === 'expired');
    sel.classList.toggle('lot-expiring', st === 'expiring');
  }
  function refreshOut(table, rows, keepChoice) {
    var bySite = {};
    rows.forEach(function (tr) {
      if (!setOn(table, tr)) return;
      var site = siteOf(table, tr);
      if (!site) return;
      if (!keepChoice) { var s = field(tr, 'lot'); if (s) s.value = ''; }
      (bySite[site] = bySite[site] || []).push(tr);
    });
    Object.keys(bySite).forEach(function (site) {
      var ids = bySite[site].map(function (tr) { return field(tr, 'item_id').value; });
      load(table, ids, site, function (groups) { bySite[site].forEach(function (tr) { fill(table, tr, groups); }); checkQty(table); });
    });
  }
  // v44: a sale takes at most the balance of a date group: the quantity of a line that goes past what is left of its
  // group (after the lines above it) is marked; the server refuses it on saving
  function checkQty(table) {
    if (table.dataset.lots !== 'out') return;
    var used = {};
    Array.prototype.slice.call(table.tBodies[0].rows).forEach(function (tr) {
      var q = field(tr, 'qty'), sel = field(tr, 'lot'), item = field(tr, 'item_id');
      if (!q) return;
      var over = false, tip = '';
      if (sel && item && sel.value && !sel.disabled) {
        var site = siteOf(table, tr);
        var groups = (cache[site + ':' + (table.dataset.lotsTxn || '')] || {})[item.value] || [];
        var g = groups.filter(function (x) { return x.key === sel.value; })[0];
        var k = item.value + '#' + sel.value + '@' + site;
        var have = (g ? +g.qty : 0) - (used[k] || 0);
        var n = parseFloat(String(q.value || '').replace(/,/g, '')) || 0;
        if (n > have + 0.00005) { over = true; tip = 'Only ' + Math.max(0, Math.round(have * 10000) / 10000) + ' left with these dates. Put the rest on another line with another expiry date.'; }
        used[k] = (used[k] || 0) + n;
      }
      q.classList.toggle('lot-over', over);
      if (over) q.title = tip; else if (q.classList.contains('lot-titled')) q.title = '';
      q.classList.toggle('lot-titled', over);
    });
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); }

  // ---------------------------------------------------------------- wiring
  function init(table) {
    var mode = table.dataset.lots;
    var rows = function () { return Array.prototype.slice.call(table.tBodies[0].rows); };
    rows().forEach(function (tr) { setOn(table, tr); });
    if (mode === 'out') {
      // the groups shown for the lines already there are refreshed in the background (the quantity may have moved)
      table.querySelectorAll('[data-f="lot"]').forEach(mark);
    }
    table.addEventListener('change', function (e) {
      var tr = e.target.closest('tr');
      if (!tr || !tr.parentNode || tr.parentNode.tagName !== 'TBODY') return;
      var f = e.target.dataset.f;
      if (f === 'item_id') {
        var on = setOn(table, tr);
        if (mode === 'in' && on) copyFromAbove(table, tr);
        if (mode === 'out') refreshOut(table, [tr], false);
      } else if (mode === 'in' && (f === 'production_date' || f === 'expiry_date')) {
        tr.dataset.lotCopied = '';
        copyDown(table, tr);
      } else if (mode === 'out' && f === 'lot') {
        mark(e.target);
        checkQty(table);
      } else if (mode === 'out' && f === 'qty') {
        checkQty(table);
      } else if (mode === 'out' && e.target.name && /\[site_id\]$/.test(e.target.name)) {
        refreshOut(table, [tr], false);
      }
    });
    if (mode === 'out') {
      table.addEventListener('input', function (e) { if (e.target.dataset && e.target.dataset.f === 'qty') checkQty(table); });
      var form = table.closest('form');
      var head = form ? form.querySelector('select[name="site_id"]') : null;
      if (head) head.addEventListener('change', function () { setTimeout(function () { refreshOut(table, rows(), false); }, 0); });
    }
  }
  function boot() { document.querySelectorAll('table.line-grid[data-lots]').forEach(init); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
  window.AppLots = { refresh: function (table) { refreshOut(table, Array.prototype.slice.call(table.tBodies[0].rows), true); } };
})();
