/* G-SMaRT Distribution System - Dispatch Inventory (v4, no build step)
 *
 * The lines of a dispatch: the item, what the source site holds (with its unit, and what it is made of in a tooltip),
 * the Conversion ("As kept", or "Kilos to Crates" for an item kept in crates), the quantity with its unit, and the
 * Crates button: crates on hand are ticked in the crate window (Find figure, dispatch figures); with Kilos to Crates
 * the window fills new crates from a production / expiry group of the loose stock.
 */
(function () {
  'use strict';
  const cfgEl = document.getElementById('dsConfig');
  const table = document.getElementById('dsTable');
  if (!cfgEl || !table) return;
  let cfg = {};
  try { cfg = JSON.parse(cfgEl.textContent || '{}'); } catch (e) { cfg = {}; }
  const tbody = table.querySelector('tbody');
  const fromSite = document.getElementById('fromSite');
  const num = (v) => { const n = parseFloat(String(v == null ? '' : v).replace(/,/g, '')); return isFinite(n) ? n : 0; };
  const r4 = (n) => Math.round(n * 10000) / 10000;
  const esc = (t) => String(t == null ? '' : t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const T = window.QtyTip || { set() {}, figure(el, q, u) { el.textContent = q + ' ' + u; }, units() { return []; }, fig: (v) => String(v) };
  const parseC = (v) => { try { const x = JSON.parse(v || '[]'); return Array.isArray(x) ? x : []; } catch (e) { return []; } };
  const units = cfg.units || {}, crates = cfg.crates || {}, dated = cfg.dated || {};
  const subOf = (tr) => { const n = tr.nextElementSibling; return n && n.classList.contains('tr-lots') ? n : null; };
  const nameOf = (tr) => tr.querySelector('.tr-item').name.replace(/\[item_id\]$/, '');
  const itemOf = (tr) => tr.querySelector('.tr-item').value;
  const siteName = () => { const o = fromSite.options[fromSite.selectedIndex]; return o ? o.textContent.trim() : ''; };
  const fdate = (d) => { if (!d) return '<span class="text-muted">None</span>'; const p = d.split('-'); return p[1] + '/' + p[2] + '/' + p[0]; };
  const hid = (tr, k) => tr.querySelector('[data-' + k + ']');

  // ------------------------------------------------------------------ what the source site holds
  const refresh = (tr) => {
    const out = tr.querySelector('.tr-avail');
    const id = itemOf(tr);
    if (!id) { out.innerHTML = ''; T.set(out, []); return; }
    const site = fromSite.value;
    fetch(cfg.lookup + '&item=' + encodeURIComponent(id) + '&site=' + encodeURIComponent(site), { credentials: 'same-origin', headers: { 'X-Background': '1' } })
      .then((r) => r.json()).then((d) => {
        const back = site === String(cfg.ownSite) ? num(cfg.own && cfg.own[id]) : 0;
        const q = num(d.on_hand) + back;
        const unit = d.unit || (units[id] && units[id].base) || '';
        T.figure(out, q, unit);
        T.set(out, d.detail || [], 'At ' + siteName());
      }).catch(() => {});
  };

  // ------------------------------------------------------------------ the quantity, its unit and its tooltip
  const paintQty = (tr) => {
    const id = itemOf(tr), info = units[id] || null;
    const unitEl = tr.querySelector('.tr-unit'), q = tr.querySelector('.tr-qty');
    const base = info ? info.base : '';
    unitEl.textContent = base || 'unit';
    const list = parseC(hid(tr, 'tr-crates') ? hid(tr, 'tr-crates').value : '');
    const conv = tr.querySelector('.ds-conv');
    const packing = conv && conv.value === 'pack';
    let lines = [];
    let title = '';
    if (list.length) {
      const one = info && info.one ? info.one.toLowerCase() : 'crate';
      const many = info && info.many ? info.many.toLowerCase() : 'crates';
      title = (packing ? 'Packed into ' : 'In ') + list.length + ' ' + (list.length === 1 ? one : many);
      lines = list.slice(0, 12).map((c) => (c.no ? c.no : '#') + ': ' + T.fig(c.qty, base) + ' ' + base + (c.fig ? ' (dispatch ' + c.fig + ')' : ''));
      if (list.length > 12) lines.push('and ' + (list.length - 12) + ' more');
      if (packing && hid(tr, 'pack-lot') && hid(tr, 'pack-lot').dataset.label) lines.push('From: ' + hid(tr, 'pack-lot').dataset.label);
    } else if (info) {
      lines = T.units(num(q.value), info);
    }
    T.set(tr.querySelector('.qty-unit-group'), lines, title);
    total();
  };

  const total = () => {
    const sums = {};
    let crateN = 0;
    tbody.querySelectorAll('tr.tr-main').forEach((tr) => {
      const id = itemOf(tr);
      const q = num(tr.querySelector('.tr-qty').value);
      if (!id || !q) return;
      const u = (units[id] && units[id].base) || 'unit';
      sums[u] = (sums[u] || 0) + q;
      const h = hid(tr, 'tr-crates');
      if (h) crateN += parseC(h.value).length;
    });
    const parts = Object.keys(sums).map((u) => T.fig(sums[u], u) + ' ' + u);
    const el = document.querySelector('[data-ds-total]');
    if (el) el.textContent = parts.length ? parts.join(', ') + (crateN ? ' (' + crateN + (crateN === 1 ? ' crate)' : ' crates)') : '') : '0';
  };

  // ------------------------------------------------------------------ date groups (items with production and expiry dates)
  const lotTotal = (tr) => {
    const sub = subOf(tr);
    if (!sub || sub.hidden) return;
    let sum = 0;
    sub.querySelectorAll('.tr-lot-qty').forEach((inp) => {
      const v = num(inp.value), max = num(inp.dataset.max);
      sum += v;
      const over = v > max + 0.00005;
      inp.classList.toggle('is-invalid', over);
      inp.title = over ? 'Only ' + T.fig(max, '') + ' with these dates at the source site' : '';
    });
    const q = tr.querySelector('.tr-qty');
    q.value = sum > 0 ? String(r4(sum)) : '';
    paintQty(tr);
  };
  const lotSummary = (groups) => {
    if (!groups.length) return '<span class="text-muted small">No stock at the source site</span>';
    const dates = groups.filter((g) => g.prod || g.exp).length;
    return '<span class="small">' + groups.length + ' date group' + (groups.length === 1 ? '' : 's') + (dates < groups.length ? ' (one without dates)' : '') + '</span><span class="tr-lotsum-hint small text-muted">Type the quantities below</span>';
  };
  const lotTable = (tr, groups, keep) => {
    const n = nameOf(tr);
    if (!groups.length) return '<div class="tr-lot-empty">No stock of this item at the source site.</div>';
    return '<table class="table table-sm mb-0 tr-lot-table"><thead><tr><th>Expiry date</th><th>Production date</th><th>Status</th><th class="num">On hand</th><th class="num">Qty to dispatch</th></tr></thead><tbody>'
      + groups.map((g) => {
        const st = !g.prod && !g.exp ? 'No dates' : (g.status === 'expired' ? 'Expired ' + Math.abs(g.days) + ' day(s) ago' : 'Expires in ' + g.days + ' day(s)');
        const cls = g.status === 'expired' ? 'lot-expired-row' : (g.status === 'expiring' ? 'lot-expiring-row' : '');
        return '<tr class="' + cls + '"><td data-label="Expiry date">' + fdate(g.exp) + '</td><td data-label="Production date">' + fdate(g.prod) + '</td><td data-label="Status" class="small">' + esc(st) + '</td>'
          + '<td data-label="On hand" class="num tr-lot-have">' + esc(T.fig(g.qty, '')) + '</td>'
          + '<td data-label="Qty to dispatch"><input class="form-control form-control-sm text-end tr-lot-qty" name="' + esc(n + '[lots][' + g.key + ']') + '" value="' + esc(keep[g.key] || '') + '" data-max="' + g.qty + '" inputmode="decimal" placeholder="0" aria-label="Quantity to dispatch"></td></tr>';
      }).join('') + '</tbody></table>';
  };
  const loadLots = (tr) => {
    const id = itemOf(tr), sub = subOf(tr), cell = tr.querySelector('.tr-lotsum'), q = tr.querySelector('.tr-qty');
    const conv = tr.querySelector('.ds-conv');
    const hasCrates = hid(tr, 'tr-crates') && parseC(hid(tr, 'tr-crates').value).length > 0;
    const on = !!(id && dated[id]) && !(conv && conv.value === 'pack') && !hasCrates;
    tr.classList.toggle('has-lots', !!(id && dated[id]));
    if (!sub) return;
    if (!on) {
      sub.hidden = true;
      if (!(id && dated[id])) { sub.querySelector('.tr-lotbox').innerHTML = ''; if (cell) cell.innerHTML = ''; }
      if (!hasCrates) { q.readOnly = false; q.removeAttribute('tabindex'); }
      return;
    }
    const keep = {};
    sub.querySelectorAll('.tr-lot-qty').forEach((inp) => { const m = inp.name.match(/\[lots\]\[([^\]]*)\]$/); if (m && inp.value) keep[m[1]] = inp.value; });
    q.readOnly = true; q.tabIndex = -1; q.title = 'The total of the date groups below';
    sub.hidden = false;
    fetch(cfg.lotsUrl + '&item_ids=' + id + '&site_id=' + encodeURIComponent(fromSite.value) + (cfg.txn ? '&exclude=' + cfg.txn : ''), { credentials: 'same-origin', headers: { 'X-Background': '1' } })
      .then((r) => r.json()).then((j) => {
        const groups = (j.groups && j.groups[id]) || [];
        sub.querySelector('.tr-lotbox').innerHTML = lotTable(tr, groups, keep);
        if (cell) cell.innerHTML = lotSummary(groups);
        lotTotal(tr);
      }).catch(() => {});
  };

  // ------------------------------------------------------------------ conversion and crates
  const paintC = (tr) => {
    const h = hid(tr, 'tr-crates'), btn = tr.querySelector('[data-tr-crate-open]'), conv = tr.querySelector('.ds-conv');
    if (!h || !btn) { paintQty(tr); return; }
    const id = itemOf(tr), it = crates[id], info = units[id] || {};
    btn.disabled = !it;
    if (conv) {
      conv.disabled = !it;
      if (!it) conv.value = '';
      const opt = conv.querySelector('option[value="pack"]');
      if (opt) opt.textContent = info.conv || 'Kilos to Crates';
    }
    if (!it && h.value) h.value = '';
    const packing = conv && conv.value === 'pack';
    h.toggleAttribute('data-pack-crates', !!packing);
    const list = parseC(h.value), q = tr.querySelector('.tr-qty');
    const lbl = btn.querySelector('[data-crate-label]');
    const one = info.one || 'Crate', many = info.many || 'Crates';
    btn.classList.toggle('has-crates', list.length > 0);
    btn.classList.toggle('is-pack', !!packing);
    btn.classList.toggle('needs-crates', !!packing && !list.length);
    lbl.textContent = list.length ? list.length + ' ' + (list.length === 1 ? one : many).toLowerCase() : (packing ? 'Fill ' + many.toLowerCase() : many);
    btn.title = packing ? 'Put loose stock into ' + many.toLowerCase() + ': pick the date group and type each one\'s dispatch figure' : 'Choose the ' + many.toLowerCase() + ' sent: they keep their numbers and dates';
    if (list.length || packing) {
      const sumQ = r4(list.reduce((a, c) => a + num(c.qty), 0));
      q.value = list.length ? (T.isWeight && T.isWeight(info.base || 'kg') && Math.abs(sumQ * 100 - Math.round(sumQ * 100)) < 1e-6 ? sumQ.toFixed(2) : String(sumQ)) : '';
      q.readOnly = true; q.tabIndex = -1; q.classList.add('qty-from-crates');
      q.title = 'The total of the ' + many.toLowerCase() + ': press the button on the line to change it';
      const sub = subOf(tr); if (sub) sub.hidden = true;
    } else if (q.classList.contains('qty-from-crates')) {
      q.readOnly = false; q.removeAttribute('tabindex'); q.classList.remove('qty-from-crates'); q.title = ''; q.value = '';
      loadLots(tr);
    }
    paintQty(tr);
  };

  /** kilos of each group the other lines of the dispatch already pack (the same item) */
  const othersOf = (tr, id) => {
    const out = {};
    tbody.querySelectorAll('tr.tr-main').forEach((o) => {
      if (o === tr || itemOf(o) !== id) return;
      const conv = o.querySelector('.ds-conv');
      if (!conv || conv.value !== 'pack') return;
      const key = hid(o, 'pack-lot') ? hid(o, 'pack-lot').value : '';
      out[key] = (out[key] || 0) + parseC(hid(o, 'tr-crates').value).reduce((a, c) => a + num(c.qty), 0);
    });
    return out;
  };

  const openC = (tr) => {
    const sel = tr.querySelector('.tr-item'), id = sel.value, it = crates[id], h = hid(tr, 'tr-crates');
    if (!it || !window.CrateWindow) return;
    const conv = tr.querySelector('.ds-conv');
    const packing = conv && conv.value === 'pack';
    const opt = sel.options[sel.selectedIndex];
    const title = opt ? opt.textContent.trim() : 'Crates';
    const url = cfg.cratesUrl + '&item_id=' + encodeURIComponent(id) + '&site_id=' + encodeURIComponent(fromSite.value) + (packing ? '&pack=1' : '') + (cfg.txn ? '&txn=' + cfg.txn : '');
    fetch(url, { credentials: 'same-origin' }).then((r) => r.json()).then((d) => {
      if (d.error) { alert(d.error); return; }
      const base = d.base || it.base || 'kg';
      if (packing) {
        const lotH = hid(tr, 'pack-lot');
        window.CrateWindow.open({ dir: 'pack', title, base, figure: true, container: d.container || 'Crates', container1: d.container1 || 'Crate',
          sub: (d.label || 'Kilos to Crates') + ' at ' + (d.site || 'the source site') + ': the ' + base + ' leave the loose stock and go in the ' + String(d.container || 'crates').toLowerCase() + ', with the dates of the group.',
          groups: d.groups || [], site: d.site, next: d.next || '1', value: h.value, own: h, others: othersOf(tr, id), fixable: d.fixable || 0, why: d.why || '',
          lot: lotH.value, prod: hid(tr, 'pack-prod').value, exp: hid(tr, 'pack-exp').value, defaultCount: 5,
          onSave: (list, tot, extra) => {
            h.value = list.length ? JSON.stringify(list) : '';
            lotH.value = list.length ? extra.lot : ''; lotH.dataset.label = extra.label || '';
            hid(tr, 'pack-prod').value = list.length ? extra.prod : ''; hid(tr, 'pack-exp').value = list.length ? extra.exp : '';
            paintC(tr);
          } });
        return;
      }
      window.CrateWindow.open({ dir: 'out', whole: true, figure: true, title, base, crates: d.crates || [], loose: d.loose, value: h.value,
        sub: 'Choose the crates sent from ' + (d.site || 'the source site') + ', or type each crate\'s figure in Find figure. Each crate goes whole, with its number and dates.',
        onSave: (list) => { h.value = list.length ? JSON.stringify(list) : ''; paintC(tr); } });
    }).catch(() => alert('The crates could not be loaded. Check the connection and try again.'));
  };

  // ------------------------------------------------------------------ events
  tbody.addEventListener('change', (e) => {
    const tr = e.target.closest('tr.tr-main');
    if (e.target.classList.contains('tr-item') && tr) {
      const h = hid(tr, 'tr-crates');
      if (h) { h.value = ''; ['pack-lot', 'pack-prod', 'pack-exp'].forEach((k) => { if (hid(tr, k)) hid(tr, k).value = ''; }); }
      const conv = tr.querySelector('.ds-conv'); if (conv) conv.value = '';
      const q = tr.querySelector('.tr-qty'); q.classList.remove('qty-from-crates'); q.readOnly = false; q.value = '';
      refresh(tr); loadLots(tr); paintC(tr);
    } else if (e.target.classList.contains('ds-conv') && tr) {
      const h = hid(tr, 'tr-crates');
      if (h) { h.value = ''; ['pack-lot', 'pack-prod', 'pack-exp'].forEach((k) => { if (hid(tr, k)) hid(tr, k).value = ''; }); }
      const q = tr.querySelector('.tr-qty');
      if (e.target.value !== 'pack' && q.classList.contains('qty-from-crates')) { q.classList.remove('qty-from-crates'); q.readOnly = false; q.value = ''; }
      paintC(tr);
      loadLots(tr);
      if (e.target.value === 'pack') openC(tr);
    }
  });
  tbody.addEventListener('input', (e) => {
    if (e.target.classList.contains('tr-lot-qty')) { const sub = e.target.closest('tr.tr-lots'); if (sub && sub.previousElementSibling) lotTotal(sub.previousElementSibling); }
    if (e.target.classList.contains('tr-qty')) paintQty(e.target.closest('tr'));
  });
  tbody.addEventListener('click', (e) => {
    const b = e.target.closest('[data-tr-crate-open]'); if (b && !b.disabled) { openC(b.closest('tr')); return; }
    const ins = e.target.closest('.tr-ins'); if (ins) { newRow(ins.closest('tr')); return; }
    const del = e.target.closest('.tr-del');
    if (del) { const tr = del.closest('tr'); const sub = subOf(tr); if (sub) sub.remove(); tr.remove(); total(); }
  });
  fromSite.addEventListener('change', () => tbody.querySelectorAll('tr.tr-main').forEach((tr) => {
    const h = hid(tr, 'tr-crates');
    if (h && h.value) { h.value = ''; ['pack-lot', 'pack-prod', 'pack-exp'].forEach((k) => { if (hid(tr, k)) hid(tr, k).value = ''; }); }
    refresh(tr); paintC(tr); if (tr.classList.contains('has-lots')) loadLots(tr);
  }));
  let seq = 0;
  const newRow = (before) => {
    const tmp = document.createElement('tbody');
    tmp.innerHTML = document.getElementById('dsTpl').innerHTML.replace(/__i__/g, 'n' + Date.now() + '_' + (seq++)).trim();
    const rows = Array.prototype.slice.call(tmp.children);
    rows.forEach((r) => { if (before) tbody.insertBefore(r, before); else tbody.appendChild(r); });
    if (window.AppCombo) window.AppCombo.init(rows[0]);
    paintC(rows[0]);
    return rows[0];
  };
  document.querySelectorAll('.tr-add').forEach((b) => b.addEventListener('click', () => { for (let i = 0; i < (+b.dataset.count || 1); i++) newRow(); }));
  // the lines already on the form (an edit, or a form sent back with a message)
  tbody.querySelectorAll('tr.tr-main').forEach((tr) => { refresh(tr); paintC(tr); if (tr.classList.contains('has-lots')) loadLots(tr); });
  total();
})();
