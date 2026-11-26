/* G-SMaRT Distribution System - Dispatch Inventory (v4, no build step)
 *
 * The lines of a dispatch: the item, what the source site holds (with its unit, and what it is made of in a tooltip),
 * the Conversion ("As kept", or "Kilos to Crates" for an item kept in crates), the quantity with its unit, and the
 * Crates button: crates on hand are ticked in the crate window (Find figure, dispatch figures); with Kilos to Crates
 * the window fills new crates from a production / expiry group of the loose stock.
 *
 * v8: many sites to one. "From sites" is a list of sites to tick; each line chooses one of them (its marker shows
 * beside it) and takes its stock, date groups and crates from that site. "Stock at the sites" lists what the sites
 * ticked hold, item by item with the site's marker, filtered by item code or name; the markers above the list show or
 * hide a site's rows, and Add puts the item on a line with that site.
 */
(function () {
  'use strict';
  const cfgEl = document.getElementById('dsConfig');
  const table = document.getElementById('dsTable');
  if (!cfgEl || !table) return;
  let cfg = {};
  try { cfg = JSON.parse(cfgEl.textContent || '{}'); } catch (e) { cfg = {}; }
  const tbody = table.querySelector('tbody');
  const num = (v) => { const n = parseFloat(String(v == null ? '' : v).replace(/,/g, '')); return isFinite(n) ? n : 0; };
  const r4 = (n) => Math.round(n * 10000) / 10000;
  const esc = (t) => String(t == null ? '' : t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const T = window.QtyTip || { set() {}, figure(el, q, u) { el.textContent = q + ' ' + u; }, units() { return []; }, fig: (v) => String(v) };
  const parseC = (v) => { try { const x = JSON.parse(v || '[]'); return Array.isArray(x) ? x : []; } catch (e) { return []; } };
  const units = cfg.units || {}, crates = cfg.crates || {}, dated = cfg.dated || {};
  const marks = cfg.marks || {}, siteNames = cfg.sites || {};
  const subOf = (tr) => { const n = tr.nextElementSibling; return n && n.classList.contains('tr-lots') ? n : null; };
  const nameOf = (tr) => tr.querySelector('.tr-item').name.replace(/\[item_id\]$/, '');
  const itemOf = (tr) => tr.querySelector('.tr-item').value;
  const fdate = (d) => { if (!d) return '<span class="text-muted">None</span>'; const p = d.split('-'); return p[1] + '/' + p[2] + '/' + p[0]; };
  const hid = (tr, k) => tr.querySelector('[data-' + k + ']');
  const markCls = (id) => 'sm-' + (marks[id] != null ? marks[id] : 0);
  const markHtml = (id) => '<span class="site-mark ' + markCls(id) + '" aria-hidden="true"></span>';

  // ------------------------------------------------------------------ v8: the sites the stock comes from
  const fromWrap = document.querySelector('[data-ds-sites]');
  const toSite = document.getElementById('toSite');
  const boxes = () => (fromWrap ? Array.prototype.slice.call(fromWrap.querySelectorAll('input[name="from_sites[]"]')) : []);
  const chosen = () => boxes().filter((b) => b.checked && !b.disabled).map((b) => b.value);
  const siteOf = (tr) => { const s = tr.querySelector('.ds-site'); return s && s.value ? s.value : (chosen()[0] || ''); };
  const siteName = (tr) => siteNames[siteOf(tr)] || 'the source site';
  const paintFrom = () => {
    if (!fromWrap) return;
    const ids = chosen();
    const names = ids.map((id) => siteNames[id] || '');
    fromWrap.querySelector('[data-ds-sites-text]').textContent = !names.length ? 'Choose the sites' : (names.length <= 2 ? names.join(' and ') : names[0] + ' and ' + (names.length - 1) + ' more');
    fromWrap.querySelector('[data-ds-sites-marks]').innerHTML = ids.map(markHtml).join('');
    table.classList.toggle('ds-many', ids.length > 1);
  };
  /** the lines' From site lists follow the sites ticked; a line on a site no longer ticked moves to the first one */
  const syncLineSites = () => {
    const ids = chosen();
    const opts = ids.map((id) => '<option value="' + esc(id) + '">' + esc(siteNames[id] || id) + '</option>').join('');
    tbody.querySelectorAll('tr.tr-main').forEach((tr) => {
      const sel = tr.querySelector('.ds-site');
      if (!sel) return;
      const was = sel.value;
      sel.innerHTML = opts;
      if (ids.indexOf(was) >= 0) { sel.value = was; return; }
      sel.value = ids[0] || '';
      siteChanged(tr);
    });
  };

  // ------------------------------------------------------------------ what the source site holds
  const refresh = (tr) => {
    const out = tr.querySelector('.tr-avail');
    const id = itemOf(tr);
    if (!id) { out.innerHTML = ''; T.set(out, []); return; }
    const site = siteOf(tr);
    fetch(cfg.lookup + '&item=' + encodeURIComponent(id) + '&site=' + encodeURIComponent(site), { credentials: 'same-origin', headers: { 'X-Background': '1' } })
      .then((r) => r.json()).then((d) => {
        if (siteOf(tr) !== site || itemOf(tr) !== id) return;
        const back = num(cfg.own && cfg.own[site] && cfg.own[site][id]);
        const q = num(d.on_hand) + back;
        const unit = d.unit || (units[id] && units[id].base) || '';
        T.figure(out, q, unit);
        T.set(out, d.detail || [], 'At ' + siteName(tr));
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

  /** the total of each unit, and (v8) what each site gives when the stock comes from more than one */
  const total = () => {
    const sums = {}, bySite = {}, order = [];
    let crateN = 0;
    tbody.querySelectorAll('tr.tr-main').forEach((tr) => {
      const id = itemOf(tr);
      const q = num(tr.querySelector('.tr-qty').value);
      if (!id || !q) return;
      const u = (units[id] && units[id].base) || 'unit';
      const s = siteOf(tr);
      sums[u] = (sums[u] || 0) + q;
      if (!bySite[s]) { bySite[s] = { u: {}, n: 0 }; order.push(s); }
      bySite[s].u[u] = (bySite[s].u[u] || 0) + q;
      const h = hid(tr, 'tr-crates');
      const n = h ? parseC(h.value).length : 0;
      crateN += n; bySite[s].n += n;
    });
    const text = (u, n) => { const parts = Object.keys(u).map((k) => T.fig(u[k], k) + ' ' + k); return parts.join(', ') + (n ? ' (' + n + (n === 1 ? ' crate)' : ' crates)') : ''); };
    const el = document.querySelector('[data-ds-total]');
    if (el) el.textContent = Object.keys(sums).length ? text(sums, crateN) : '0';
    const per = document.querySelector('[data-ds-total-sites]');
    if (per) {
      per.innerHTML = order.length > 1 ? order.map((s) => '<div class="ds-total-site">' + markHtml(s) + '<span class="ds-total-site-name">From ' + esc(siteNames[s] || '') + '</span><span class="ds-total-site-q">' + esc(text(bySite[s].u, bySite[s].n)) + '</span></div>').join('') : '';
    }
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
      inp.title = over ? 'Only ' + T.fig(max, '') + ' with these dates at ' + siteName(tr) : '';
    });
    const q = tr.querySelector('.tr-qty');
    q.value = sum > 0 ? String(r4(sum)) : '';
    paintQty(tr);
  };
  const lotSummary = (groups, tr) => {
    if (!groups.length) return '<span class="text-muted small">' + (crates[itemOf(tr)] ? 'No loose stock at ' + esc(siteName(tr)) + ': send its crates' : 'No stock at ' + esc(siteName(tr))) + '</span>';
    const dates = groups.filter((g) => g.prod || g.exp).length;
    return '<span class="small">' + groups.length + ' date group' + (groups.length === 1 ? '' : 's') + (dates < groups.length ? ' (one without dates)' : '') + '</span><span class="tr-lotsum-hint small text-muted">Type the quantities below</span>';
  };
  const lotTable = (tr, groups, keep) => {
    const n = nameOf(tr);
    if (!groups.length) return '<div class="tr-lot-empty">' + (crates[itemOf(tr)] ? 'No loose stock of this item at ' + esc(siteName(tr)) + ': it is all in crates. Press <strong>Crates</strong> on the line to send them whole, or choose another site.' : 'No stock of this item at ' + esc(siteName(tr)) + '.') + '</div>';
    return '<table class="table table-sm mb-0 tr-lot-table"><thead><tr><th>Expiry date</th><th>Production date</th><th>Status</th><th class="num">On hand</th><th class="num">Qty to dispatch</th></tr></thead><tbody>'
      + groups.map((g) => {
        const st = !g.prod && !g.exp ? 'No dates' : (g.status === 'expired' ? 'Expired ' + Math.abs(g.days) + ' day(s) ago' : 'Expires in ' + g.days + ' day(s)');
        const cls = g.status === 'expired' ? 'lot-expired-row' : (g.status === 'expiring' ? 'lot-expiring-row' : '');
        return '<tr class="' + cls + '"><td data-label="Expiry date">' + fdate(g.exp) + '</td><td data-label="Production date">' + fdate(g.prod) + '</td><td data-label="Status" class="small">' + esc(st) + '</td>'
          + '<td data-label="On hand" class="num tr-lot-have">' + esc(T.fig(g.qty, '')) + '</td>'
          + '<td data-label="Qty to dispatch"><input class="form-control form-control-sm text-end tr-lot-qty" name="' + esc(n + '[lots][' + g.key + ']') + '" value="' + esc(keep[g.key] || '') + '" data-max="' + g.qty + '" inputmode="decimal" placeholder="0" aria-label="Quantity to dispatch"></td></tr>';
      }).join('') + '</tbody></table>';
  };
  const loadLots = (tr, fresh) => {
    const id = itemOf(tr), sub = subOf(tr), cell = tr.querySelector('.tr-lotsum'), q = tr.querySelector('.tr-qty');
    const conv = tr.querySelector('.ds-conv');
    const hasCrates = hid(tr, 'tr-crates') && parseC(hid(tr, 'tr-crates').value).length > 0;
    const on = !!(id && dated[id]) && !(conv && conv.value === 'pack') && !hasCrates;
    tr.classList.toggle('has-lots', !!(id && dated[id]));
    if (!sub) return;
    if (!on) {
      sub.hidden = true;
      if (!(id && dated[id])) { sub.querySelector('.tr-lotbox').innerHTML = ''; if (cell) cell.innerHTML = ''; }
      else if (cell && (hasCrates || (conv && conv.value === 'pack'))) {
        cell.innerHTML = '<span class="small text-muted">' + (conv && conv.value === 'pack' ? 'The crates take the dates of the group they are filled from' : 'Each crate goes with its own dates') + '</span>';
      }
      if (!hasCrates) { q.readOnly = false; q.removeAttribute('tabindex'); }
      return;
    }
    const keep = {};
    if (!fresh) sub.querySelectorAll('.tr-lot-qty').forEach((inp) => { const m = inp.name.match(/\[lots\]\[([^\]]*)\]$/); if (m && inp.value) keep[m[1]] = inp.value; });
    q.readOnly = true; q.tabIndex = -1; q.title = 'The total of the date groups below';
    sub.hidden = false;
    const site = siteOf(tr);
    fetch(cfg.lotsUrl + '&item_ids=' + id + '&site_id=' + encodeURIComponent(site) + (cfg.txn ? '&exclude=' + cfg.txn : ''), { credentials: 'same-origin', headers: { 'X-Background': '1' } })
      .then((r) => r.json()).then((j) => {
        if (siteOf(tr) !== site || itemOf(tr) !== id) return;
        const groups = (j.groups && j.groups[id]) || [];
        sub.querySelector('.tr-lotbox').innerHTML = lotTable(tr, groups, keep);
        if (cell) cell.innerHTML = lotSummary(groups, tr);
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
    const cell = tr.querySelector('.tr-lotsum');
    if (cell && dated[id] && (list.length || packing)) {
      cell.innerHTML = '<span class="small text-muted">' + (packing ? 'The crates take the dates of the group they are filled from' : 'Each crate goes with its own dates') + '</span>';
    }
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

  /** kilos of each group the other lines of the dispatch already pack (the same item, at the same site) */
  const othersOf = (tr, id) => {
    const out = {};
    const site = siteOf(tr);
    tbody.querySelectorAll('tr.tr-main').forEach((o) => {
      if (o === tr || itemOf(o) !== id || siteOf(o) !== site) return;
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
    const url = cfg.cratesUrl + '&item_id=' + encodeURIComponent(id) + '&site_id=' + encodeURIComponent(siteOf(tr)) + (packing ? '&pack=1' : '') + (cfg.txn ? '&txn=' + cfg.txn : '');
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

  /** v8: a line moved to another site: its marker, what that site holds, its date groups; crates chosen are let go */
  function siteChanged(tr) {
    const mark = tr.querySelector('[data-ds-mark]');
    if (mark) mark.className = 'site-mark ' + markCls(siteOf(tr));
    const h = hid(tr, 'tr-crates');
    if (h && h.value) { h.value = ''; ['pack-lot', 'pack-prod', 'pack-exp'].forEach((k) => { if (hid(tr, k)) hid(tr, k).value = ''; }); }
    refresh(tr); paintC(tr); if (tr.classList.contains('has-lots')) loadLots(tr, true);
  }

  // ------------------------------------------------------------------ events
  tbody.addEventListener('change', (e) => {
    const tr = e.target.closest('tr.tr-main');
    if (e.target.classList.contains('tr-item') && tr) {
      const h = hid(tr, 'tr-crates');
      if (h) { h.value = ''; ['pack-lot', 'pack-prod', 'pack-exp'].forEach((k) => { if (hid(tr, k)) hid(tr, k).value = ''; }); }
      const conv = tr.querySelector('.ds-conv'); if (conv) conv.value = '';
      const q = tr.querySelector('.tr-qty'); q.classList.remove('qty-from-crates'); q.readOnly = false; q.value = '';
      refresh(tr); loadLots(tr, true); paintC(tr);
    } else if (e.target.classList.contains('ds-site') && tr) {
      siteChanged(tr);
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
  let seq = 0;
  const newRow = (before) => {
    const tmp = document.createElement('tbody');
    tmp.innerHTML = document.getElementById('dsTpl').innerHTML.replace(/__i__/g, 'n' + Date.now() + '_' + (seq++)).trim();
    const rows = Array.prototype.slice.call(tmp.children);
    rows.forEach((r) => { if (before) tbody.insertBefore(r, before); else tbody.appendChild(r); });
    if (window.AppCombo) window.AppCombo.init(rows[0]);
    // a new line takes the sites ticked now, and the site of the line above it
    const sel = rows[0].querySelector('.ds-site');
    if (sel) {
      sel.innerHTML = chosen().map((id) => '<option value="' + esc(id) + '">' + esc(siteNames[id] || id) + '</option>').join('');
      const prev = rows[0].previousElementSibling && rows[0].previousElementSibling.classList.contains('tr-lots') ? rows[0].previousElementSibling.previousElementSibling : rows[0].previousElementSibling;
      if (prev && prev.classList.contains('tr-main') && prev.querySelector('.ds-site')) sel.value = prev.querySelector('.ds-site').value;
      const mark = rows[0].querySelector('[data-ds-mark]'); if (mark) mark.className = 'site-mark ' + markCls(siteOf(rows[0]));
    }
    paintC(rows[0]);
    return rows[0];
  };
  document.querySelectorAll('.tr-add').forEach((b) => b.addEventListener('click', () => { for (let i = 0; i < (+b.dataset.count || 1); i++) newRow(); }));

  // ------------------------------------------------------------------ v8: From sites and To site
  if (fromWrap) {
    fromWrap.addEventListener('change', (e) => {
      if (!e.target.matches('input[name="from_sites[]"]')) return;
      if (!chosen().length) { e.target.checked = true; return; }     // one site at least
      paintFrom(); syncLineSites(); loadStock(); total();
    });
    const all = fromWrap.querySelector('[data-ds-sites-all]');
    if (all) all.addEventListener('click', () => { boxes().forEach((b) => { if (!b.disabled) b.checked = true; }); paintFrom(); syncLineSites(); loadStock(); total(); });
    const first = fromWrap.querySelector('[data-ds-sites-first]');
    if (first) first.addEventListener('click', () => { let one = false; boxes().forEach((b) => { b.checked = !b.disabled && !one; if (b.checked) one = true; }); paintFrom(); syncLineSites(); loadStock(); total(); });
  }
  /** the To site can not be a site the stock comes from */
  const paintTo = () => {
    if (!toSite || !fromWrap) return;
    let lost = false;
    boxes().forEach((b) => {
      const isTo = b.value === toSite.value;
      if (isTo && b.checked) { b.checked = false; lost = true; }
      b.disabled = isTo;
      const opt = b.closest('.ds-site-opt');
      opt.classList.toggle('is-to', isTo);
      const note = opt.querySelector('.ds-site-note'); if (note) note.textContent = isTo ? 'the To site' : '';
    });
    if (!chosen().length) { const free = boxes().find((b) => !b.disabled); if (free) free.checked = true; }
    if (lost) { paintFrom(); syncLineSites(); loadStock(); total(); }
  };
  if (toSite) toSite.addEventListener('change', paintTo);

  // ------------------------------------------------------------------ v8: Stock at the sites
  const panel = document.getElementById('dsStock');
  const body = panel ? panel.querySelector('[data-ds-stock-body]') : null;
  const legend = panel ? panel.querySelector('[data-ds-legend]') : null;
  const filter = panel ? panel.querySelector('[data-ds-filter]') : null;
  const stock = { rows: [], more: false, lots: true, hidden: {}, seq: 0, timer: 0 };
  const daysText = (r) => r.status === 'expired' ? 'expired ' + Math.abs(r.days) + (Math.abs(r.days) === 1 ? ' day' : ' days') + ' ago' : (r.days === 0 ? 'expires today' : r.days + (r.days === 1 ? ' day' : ' days') + ' left');
  const paintLegend = () => {
    if (!legend) return;
    legend.innerHTML = chosen().map((id) => {
      const n = stock.rows.filter((r) => String(r.site_id) === id).length;
      const off = !!stock.hidden[id];
      return '<button type="button" class="ds-legend-item' + (off ? ' is-off' : '') + '" data-ds-legend-site="' + esc(id) + '" aria-pressed="' + (off ? 'false' : 'true') + '" title="' + (off ? 'Show' : 'Hide') + ' the stock of ' + esc(siteNames[id] || '') + '">'
        + markHtml(id) + '<span class="ds-legend-name">' + esc(siteNames[id] || '') + '</span><span class="ds-legend-n">' + n + (stock.more ? '+' : '') + '</span></button>';
    }).join('');
  };
  const paintStock = () => {
    if (!body) return;
    paintLegend();
    const rows = stock.rows.filter((r) => !stock.hidden[String(r.site_id)]);
    const q = filter ? filter.value.trim() : '';
    if (!rows.length) {
      body.innerHTML = '<div class="ds-stock-empty">' + (q ? 'No stock matches “' + esc(q) + '” at the sites shown.' : (stock.rows.length ? 'The sites with stock are hidden: press their names above to show them.' : 'No stock on hand at the sites chosen.')) + '</div>';
      return;
    }
    let last = '';
    body.innerHTML = '<div class="table-responsive"><table class="table table-sm mb-0 ds-stock-table"><thead><tr><th>Site</th><th>Item</th><th class="num">On hand</th><th class="num">In crates</th><th class="num">Loose</th>' + (stock.lots ? '<th>Earliest expiry</th>' : '') + '<th><span class="visually-hidden">Add</span></th></tr></thead><tbody>'
      + rows.map((r) => {
        const first = String(r.item_id) !== last; last = String(r.item_id);
        const cls = (first ? 'is-first ' : '') + (r.status === 'expired' ? 'lot-expired-row' : (r.status === 'expiring' ? 'lot-expiring-row' : ''));
        const u = r.unit || '';
        const exp = r.exp ? '<span class="ds-exp">' + fdate(r.exp) + '</span><span class="ds-exp-days">' + esc(daysText(r)) + '</span>' : (r.dated ? '<span class="text-muted">No dates on file</span>' : '<span class="text-muted">Not kept for this item</span>');
        return '<tr class="' + cls + '"><td data-label="Site"><span class="site-tag">' + markHtml(r.site_id) + '<span>' + esc(siteNames[r.site_id] || '') + '</span></span></td>'
          + '<td data-label="Item" class="ds-stock-item"><strong>' + esc(r.code) + '</strong><span>' + esc(r.name) + '</span></td>'
          + '<td class="num" data-label="On hand">' + esc(T.fig(r.on_hand, u)) + ' <small>' + esc(u) + '</small></td>'
          + '<td class="num" data-label="In crates">' + (r.crates ? esc(T.fig(r.in_crates, u)) + ' <small>' + esc(u) + ', ' + r.crates + (r.crates === 1 ? ' crate' : ' crates') + '</small>' : '<span class="text-muted">None</span>') + '</td>'
          + '<td class="num" data-label="Loose">' + esc(T.fig(r.loose, u)) + ' <small>' + esc(u) + '</small></td>'
          + (stock.lots ? '<td data-label="Earliest expiry" class="ds-stock-exp">' + exp + '</td>' : '')
          + '<td class="ds-stock-act"><button type="button" class="btn btn-sm btn-outline-primary" data-ds-add data-item="' + r.item_id + '" data-site="' + r.site_id + '" aria-label="Add ' + esc(r.code) + ' from ' + esc(siteNames[r.site_id] || '') + ' to the dispatch"><i class="bi bi-plus-lg"></i><span>Add</span></button></td></tr>';
      }).join('') + '</tbody></table></div>'
      + (stock.more ? '<div class="ds-stock-more">Only the first 300 rows are listed: filter by item code or name to find the others.</div>' : '');
  };
  const loadStock = () => {
    if (!body || !cfg.siteStock) return;
    const ids = chosen();
    if (!ids.length) { stock.rows = []; paintStock(); return; }
    const mine = ++stock.seq;
    body.classList.add('is-loading');
    fetch(cfg.siteStock + '&sites=' + ids.join(',') + '&q=' + encodeURIComponent(filter ? filter.value.trim() : ''), { credentials: 'same-origin', headers: { 'X-Background': '1' } })
      .then((r) => r.json()).then((d) => {
        if (mine !== stock.seq) return;
        stock.rows = d.rows || []; stock.more = !!d.more; stock.lots = d.lots !== false;
        body.classList.remove('is-loading');
        paintStock();
      }).catch(() => { body.classList.remove('is-loading'); body.innerHTML = '<div class="ds-stock-empty">The stock could not be loaded. Check the connection and try again.</div>'; });
  };
  /** Add: the item on the first empty line (or a new one), from that site */
  const addLine = (itemId, siteId) => {
    let tr = Array.prototype.find.call(tbody.querySelectorAll('tr.tr-main'), (x) => !itemOf(x));
    if (!tr) tr = newRow();
    const sel = tr.querySelector('.ds-site');
    if (sel) { sel.value = String(siteId); const mark = tr.querySelector('[data-ds-mark]'); if (mark) mark.className = 'site-mark ' + markCls(String(siteId)); }
    const it = tr.querySelector('.tr-item');
    it.value = String(itemId);
    it.dispatchEvent(new Event('change', { bubbles: true }));
    tr.classList.add('ds-just-added');
    setTimeout(() => tr.classList.remove('ds-just-added'), 1400);
    const q = tr.querySelector('.tr-qty');
    if (q && !q.readOnly) setTimeout(() => q.focus(), 60);
    tr.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  };
  if (panel) {
    body.addEventListener('click', (e) => { const b = e.target.closest('[data-ds-add]'); if (b) addLine(b.dataset.item, b.dataset.site); });
    legend.addEventListener('click', (e) => {
      const b = e.target.closest('[data-ds-legend-site]'); if (!b) return;
      const id = b.dataset.dsLegendSite;
      stock.hidden[id] = !stock.hidden[id];
      paintStock();
    });
    if (filter) {
      filter.addEventListener('input', () => { clearTimeout(stock.timer); stock.timer = setTimeout(loadStock, 250); });
      filter.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); clearTimeout(stock.timer); loadStock(); } });
    }
    const tg = panel.querySelector('[data-ds-stock-toggle]');
    const setOpen = (open) => {
      body.hidden = !open;
      panel.classList.toggle('is-closed', !open);
      tg.setAttribute('aria-expanded', open ? 'true' : 'false');
      tg.querySelector('span').textContent = open ? 'Hide' : 'Show';
      tg.querySelector('i').className = 'bi bi-chevron-' + (open ? 'up' : 'down');
      try { localStorage.setItem('ds.stock.open', open ? '1' : '0'); } catch (e) { /* storage off */ }
    };
    tg.addEventListener('click', () => setOpen(body.hidden));
    let keep = '1';
    try { keep = localStorage.getItem('ds.stock.open') || '1'; } catch (e) { keep = '1'; }
    if (keep === '0') setOpen(false);
  }

  // the lines already on the form (an edit, or a form sent back with a message)
  paintFrom();
  paintTo();
  tbody.querySelectorAll('tr.tr-main').forEach((tr) => { refresh(tr); paintC(tr); if (tr.classList.contains('has-lots')) loadLots(tr); });
  loadStock();
  total();
})();
