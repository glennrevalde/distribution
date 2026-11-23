/* G-SMaRT Distribution System - the crate window (no build step)
 *
 * Lines of an item kept in crates carry their crates in a hidden field (JSON):
 *   receiving  [{id?, no, pcs, qty, prod, exp}]  one row per crate typed as it comes off the truck
 *   selling    [{id, qty, no}]                    crates chosen from the open crates of the site
 *   adjusting  [{id, qty, no}, {id: 'loose', qty}] v3: each crate's difference (+ put in, - taken out) and the loose stock's
 * The line's quantity is the total kilos (or packs) of its crates; the price stays per kilo.
 * window.CrateWindow.open() is used by the POS Register too.
 */
(function () {
  'use strict';
  const F = window.AppFmt || { num: (v) => parseFloat(String(v).replace(/,/g, '')) || 0 };
  const num = F.num;
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const q2 = (v) => (Math.round((num(v) + Number.EPSILON) * 10000) / 10000);
  const fq = (v) => q2(v).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 3 });
  const fdate = (d) => { if (!d) return ''; const p = String(d).split('-'); return p.length === 3 ? p[1] + '/' + p[2] + '/' + p[0] : d; };
  const parse = (s) => { try { const v = JSON.parse(s || '[]'); return Array.isArray(v) ? v : []; } catch (e) { return []; } };

  // ------------------------------------------------------------------ the window (one per page)
  let modal = null, bsModal = null, state = null;

  function build() {
    if (modal) return;
    modal = document.createElement('div');
    modal.className = 'modal fade crate-modal';
    modal.id = 'crateModal';
    modal.tabIndex = -1;
    modal.setAttribute('aria-hidden', 'true');
    modal.innerHTML = '<div class="modal-dialog modal-xl modal-dialog-scrollable modal-fullscreen-md-down"><div class="modal-content">'
      + '<div class="modal-header crate-head"><div class="crate-title"><h5 class="modal-title" data-cw-title></h5><div class="crate-sub" data-cw-sub></div></div>'
      + '<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button></div>'
      + '<div class="modal-body" data-cw-body></div>'
      + '<div class="modal-footer crate-foot"><div class="scale-readout" aria-live="polite"><span class="scale-digits" data-cw-total>0.00</span><span class="scale-unit" data-cw-unit>kg</span><span class="scale-count" data-cw-count></span></div>'
      + '<div class="crate-foot-btns"><button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">Close</button>'
      + '<button type="button" class="btn btn-primary" data-cw-save><i class="bi bi-check-lg"></i> Save crates</button></div></div>'
      + '</div></div>';
    document.body.appendChild(modal);
    bsModal = window.bootstrap ? new window.bootstrap.Modal(modal) : null;
    modal.querySelector('[data-cw-save]').addEventListener('click', save);
    modal.addEventListener('input', onInput);
    modal.addEventListener('change', onInput);
    modal.addEventListener('click', onClick);
    modal.addEventListener('keydown', onKey);
    modal.addEventListener('shown.bs.modal', () => {
      const f = modal.querySelector(state && state.dir === 'in' ? 'input[data-c="qty"]' : (state && state.dir === 'adjust' ? 'input[data-cw-new]' : 'input[data-cw-find]'));
      if (f) f.focus();
    });
  }

  function show() { if (bsModal) bsModal.show(); else modal.style.display = 'block'; }
  function hide() { if (bsModal) bsModal.hide(); else modal.style.display = 'none'; }

  /**
   * opt: dir ('in' | 'out'), title, sub, base ('kg'), whole (crates go whole), value (the saved list),
   *      crates (open crates, for 'out'), loose, next (next crate number, for 'in'), onSave(list, totals)
   */
  function open(opt) {
    build();
    state = Object.assign({ list: [] }, opt);
    modal.querySelector('[data-cw-title]').textContent = opt.title || 'Crates';
    modal.querySelector('[data-cw-sub]').textContent = opt.sub || '';
    modal.querySelector('[data-cw-unit]').textContent = opt.base || 'kg';
    modal.classList.toggle('is-adjust', opt.dir === 'adjust');
    modal.querySelector('[data-cw-save]').innerHTML = '<i class="bi bi-check-lg"></i> ' + (opt.dir === 'adjust' ? 'Save adjustment' : 'Save crates');
    if (opt.dir === 'in') renderIn(parse(opt.value)); else if (opt.dir === 'adjust') renderAdjust(parse(opt.value)); else renderOut(parse(opt.value));
    // the quantity keyed in before the item (POS): the oldest crates are ticked for it
    if (opt.dir === 'out' && num(opt.need) > 0 && !parse(opt.value).length) {
      const n = modal.querySelector('[data-cw-need]');
      if (n) { n.value = opt.need; pickOldest(); }
    }
    totals();
    show();
  }

  // ------------------------------------------------------------------ receiving: one row per crate
  function inRow(c, i) {
    return '<tr data-id="' + esc(c.id || '') + '">'
      + '<td class="crate-seq">' + (i + 1) + '</td>'
      + '<td><input class="form-control form-control-sm" data-c="no" value="' + esc(c.no || '') + '" aria-label="Crate number"></td>'
      + '<td class="num"><input class="form-control form-control-sm text-end" inputmode="decimal" data-c="pcs" value="' + esc(c.pcs ? c.pcs : '') + '" aria-label="Heads"></td>'
      + '<td class="num"><input class="form-control form-control-sm text-end crate-kg" inputmode="decimal" data-c="qty" value="' + esc(c.qty ? c.qty : '') + '" aria-label="Weight"></td>'
      + '<td><input type="date" class="form-control form-control-sm" data-c="prod" value="' + esc(c.prod || '') + '" aria-label="Production date"></td>'
      + '<td><input type="date" class="form-control form-control-sm" data-c="exp" value="' + esc(c.exp || '') + '" aria-label="Expiry date"></td>'
      + '<td class="text-end"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-cw-del title="Remove this crate" aria-label="Remove this crate"><i class="bi bi-x-lg"></i></button></td></tr>';
  }

  function renderIn(list) {
    const body = modal.querySelector('[data-cw-body]');
    body.innerHTML = '<div class="crate-tools"><div class="crate-add"><label class="visually-hidden" for="cwAddN">Crates to add</label>'
      + '<input id="cwAddN" class="form-control form-control-sm" type="number" min="1" max="200" value="' + (list.length ? 1 : (state.defaultCount || 5)) + '">'
      + '<button type="button" class="btn btn-sm btn-outline-primary" data-cw-add><i class="bi bi-plus-lg"></i> Add crates</button></div>'
      + '<button type="button" class="btn btn-sm btn-outline-secondary" data-cw-rep title="Copy the heads and the dates of the first crate to the crates below it"><i class="bi bi-files"></i> Replicate</button>'
      + '<span class="crate-hint">Type each crate\'s weight as it comes off the scale; Enter moves to the next crate. Heads and dates typed on a crate are copied to the crates below it (not the weight); change any of them as needed.</span></div>'
      + '<div class="table-responsive"><table class="table table-sm crate-table"><thead><tr><th>Seq</th><th>Crate no.</th><th class="num">Heads</th><th class="num">Weight (' + esc(state.base || 'kg') + ')</th>'
      + '<th>Production date</th><th>Expiry date</th><th></th></tr></thead><tbody data-cw-rows></tbody>'
      + '<tfoot><tr><th></th><th>Totals</th><th class="num" data-cw-pcs>0</th><th class="num" data-cw-kg>0.00</th><th colspan="3"></th></tr></tfoot></table></div>';
    const tb = body.querySelector('[data-cw-rows]');
    tb.innerHTML = list.map(inRow).join('');
    // crates already saved keep their own heads and dates: typing above them does not change them
    tb.querySelectorAll('input[data-c="pcs"], input[data-c="prod"], input[data-c="exp"]').forEach((i) => { if (i.value !== '') i.dataset.own = '1'; });
    if (!list.length) addIn(state.defaultCount || 5);
  }

  /** the next free crate number: after every number on the page and the one the system suggests */
  function nextNo() {
    let max = num(state.next) - 1;
    document.querySelectorAll('input[data-f="crates"]').forEach((h) => parse(h.value).forEach((c) => { if (/^\d+$/.test(String(c.no || ''))) max = Math.max(max, num(c.no)); }));
    modal.querySelectorAll('input[data-c="no"]').forEach((i) => { if (/^\d+$/.test(i.value.trim())) max = Math.max(max, num(i.value)); });
    return String(max + 1);
  }

  function addIn(n) {
    const tb = modal.querySelector('[data-cw-rows]');
    // a new crate starts with the heads and dates of the crate above it (never its weight)
    const last = tb.querySelector('tr:last-child');
    const tpl = last ? { pcs: last.querySelector('[data-c="pcs"]').value, prod: last.querySelector('[data-c="prod"]').value, exp: last.querySelector('[data-c="exp"]').value } : { prod: state.today || '' };
    for (let k = 0; k < n; k++) {
      const i = tb.querySelectorAll('tr').length;
      tb.insertAdjacentHTML('beforeend', inRow({ no: nextNo(), pcs: tpl.pcs || '', prod: tpl.prod || '', exp: tpl.exp || '' }, i));
      const tr = tb.lastElementChild;
      tr.classList.add('row-new');
      setTimeout(() => tr.classList.remove('row-new'), 1200);
    }
    renumber();
    totals();
  }

  function renumber() {
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr, i) => { const s = tr.querySelector('.crate-seq'); if (s) s.textContent = i + 1; });
  }

  function replicate() {
    const rows = modal.querySelectorAll('[data-cw-rows] tr');
    if (!rows.length) return;
    const g = (tr, k) => tr.querySelector('[data-c="' + k + '"]');
    const src = rows[0];
    rows.forEach((tr, i) => {
      if (i === 0) return;
      ['pcs', 'prod', 'exp'].forEach((k) => { g(tr, k).value = g(src, k).value; delete g(tr, k).dataset.own; });
      if (g(tr, 'qty').value === '') g(tr, 'qty').value = g(src, 'qty').value;
      tr.classList.remove('row-new'); void tr.offsetWidth; tr.classList.add('row-new');
    });
    totals();
  }

  function readIn() {
    const out = [];
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const g = (k) => tr.querySelector('[data-c="' + k + '"]').value.trim();
      const qty = q2(g('qty'));
      if (!qty && !g('no')) return;
      const c = { no: g('no'), pcs: num(g('pcs')), qty: qty, prod: g('prod'), exp: g('exp') };
      if (tr.dataset.id) c.id = num(tr.dataset.id);
      out.push(c);
    });
    return out;
  }

  // ------------------------------------------------------------------ selling: open crates to choose from
  function renderOut(chosen) {
    const body = modal.querySelector('[data-cw-body]');
    const pick = {};
    chosen.forEach((c) => { pick[c.id] = c.qty; });
    const crates = state.crates || [];
    const whole = !!state.whole;
    let html = '<div class="crate-tools"><input class="form-control form-control-sm crate-find" type="search" placeholder="Find a crate number" data-cw-find aria-label="Find a crate number">'
      + '<button type="button" class="btn btn-sm btn-outline-primary" data-cw-oldest title="Tick the crates with the earliest expiry date first"><i class="bi bi-sort-up"></i> Oldest first</button>'
      + '<label class="crate-need">' + (whole ? 'Crates' : esc(state.base || 'kg')) + ' needed <input class="form-control form-control-sm" inputmode="decimal" data-cw-need></label>'
      + '<span class="crate-hint">' + (whole ? 'The line is in crates: each crate goes whole.' : 'Tick a crate and type the ' + esc(state.base || 'kg') + ' taken from it; what is left stays in the crate.')
      + (state.loose != null ? ' Loose stock here: ' + fq(state.loose) + ' ' + esc(state.base || 'kg') + '.' : '') + '</span></div>';
    if (!crates.length) {
      html += '<div class="crate-empty">No open crate of this item at this site. Receive it in crates first, or sell it in ' + esc(state.base || 'kg') + ' from loose stock.</div>';
    } else {
      html += '<div class="table-responsive"><table class="table table-sm crate-table crate-pick"><thead><tr><th></th><th>Crate no.</th><th class="num">Heads</th><th class="num">Left (' + esc(state.base || 'kg') + ')</th>'
        + '<th>Production</th><th>Expiry</th><th class="num">Take</th></tr></thead><tbody data-cw-rows>';
      crates.forEach((c) => {
        const on = Object.prototype.hasOwnProperty.call(pick, c.id);
        const take = on ? (whole ? c.qty : pick[c.id]) : '';
        const expCls = c.days === null ? '' : (c.days < 0 ? ' is-expired' : (c.days <= 3 ? ' is-near' : ''));
        html += '<tr data-id="' + c.id + '" data-left="' + c.qty + '" data-no="' + esc(c.no) + '" class="' + (on ? 'is-picked' : '') + '">'
          + '<td><input type="checkbox" class="form-check-input" data-cw-tick' + (on ? ' checked' : '') + ' aria-label="Take crate ' + esc(c.no) + '"></td>'
          + '<td class="crate-no">' + esc(c.no) + '</td><td class="num">' + (c.pcs ? fq(c.pcs).replace(/\.00$/, '') : '') + '</td><td class="num">' + fq(c.qty) + '</td>'
          + '<td>' + esc(fdate(c.prod)) + '</td><td class="crate-exp' + expCls + '">' + esc(fdate(c.exp)) + (c.days !== null ? '<small>' + (c.days < 0 ? 'expired' : c.days + 'd left') + '</small>' : '') + '</td>'
          + '<td class="num"><input class="form-control form-control-sm text-end crate-take" inputmode="decimal" data-cw-take value="' + esc(take === '' ? '' : q2(take)) + '"' + (whole ? ' readonly tabindex="-1"' : '') + ' aria-label="Take from crate ' + esc(c.no) + '"></td></tr>';
      });
      html += '</tbody><tfoot><tr><th></th><th>Totals</th><th></th><th class="num" data-cw-left></th><th colspan="2"></th><th class="num" data-cw-kg>0.00</th></tr></tfoot></table></div>';
    }
    body.innerHTML = html;
  }

  function readOut() {
    const out = [];
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const tick = tr.querySelector('[data-cw-tick]');
      if (!tick || !tick.checked) return;
      const left = num(tr.dataset.left);
      const take = state.whole ? left : Math.min(left, q2(tr.querySelector('[data-cw-take]').value));
      if (take > 0) out.push({ id: num(tr.dataset.id), qty: q2(take), no: tr.dataset.no });
    });
    return out;
  }

  function pickOldest() {
    const need = num(modal.querySelector('[data-cw-need]').value);
    let left = need > 0 ? need : (state.whole ? 1 : 0);
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const tick = tr.querySelector('[data-cw-tick]'), take = tr.querySelector('[data-cw-take]');
      const crateLeft = num(tr.dataset.left);
      if (left <= 0.00005) { tick.checked = false; take.value = ''; tr.classList.remove('is-picked'); return; }
      tick.checked = true; tr.classList.add('is-picked');
      if (state.whole) { take.value = q2(crateLeft); left -= 1; } else { const t = Math.min(crateLeft, left); take.value = q2(t); left = q2(left - t); }
    });
    totals();
  }

  // ------------------------------------------------------------------ adjusting: each crate's own new weight (v3)
  const sign = (v) => (v > 0.00005 ? '+' : '') + fq(v);
  function adjRow(c, d, isLoose) {
    const left = num(c.qty);
    const nw = d === undefined || d === null || Math.abs(d) < 0.00005 ? '' : q2(left + d);
    const expCls = c.days === null || c.days === undefined ? '' : (c.days < 0 ? ' is-expired' : (c.days <= 3 ? ' is-near' : ''));
    return '<tr data-id="' + esc(c.id) + '" data-left="' + left + '" data-max="' + (isLoose ? '' : num(c.qin)) + '" data-no="' + esc(isLoose ? '' : c.no) + '" class="' + (isLoose ? 'crate-loose' : '') + (nw !== '' ? ' is-picked' : '') + '">'
      + (isLoose
        ? '<td class="crate-no crate-loose-name">Loose<small>not in a crate</small></td><td></td><td></td><td></td>'
        : '<td class="crate-no">' + esc(c.no) + '</td><td class="num">' + (c.pcs ? fq(c.pcs).replace(/\.00$/, '') : '') + '</td>'
          + '<td>' + esc(fdate(c.prod)) + '</td><td class="crate-exp' + expCls + '">' + esc(fdate(c.exp)) + (c.days !== null && c.days !== undefined ? '<small>' + (c.days < 0 ? 'expired' : c.days + 'd left') + '</small>' : '') + '</td>')
      + '<td class="num crate-now">' + fq(left) + (isLoose ? '' : '<small>of ' + fq(c.qin) + '</small>') + '</td>'
      + '<td class="num"><input class="form-control form-control-sm text-end" inputmode="decimal" data-cw-new value="' + esc(nw) + '" placeholder="' + esc(fq(left)) + '" aria-label="New weight of ' + (isLoose ? 'the loose stock' : 'crate ' + esc(c.no)) + '"></td>'
      + '<td class="num"><input class="form-control form-control-sm text-end" inputmode="decimal" data-cw-diff value="' + esc(nw === '' ? '' : sign(d)) + '" aria-label="Adjustment of ' + (isLoose ? 'the loose stock' : 'crate ' + esc(c.no)) + '"></td></tr>';
  }

  function renderAdjust(saved) {
    const body = modal.querySelector('[data-cw-body]');
    const set = {};
    saved.forEach((c) => { set[String(c.id)] = num(c.qty); });
    const crates = state.crates || [];
    const base = esc(state.base || 'kg');
    let html = '<div class="crate-tools"><input class="form-control form-control-sm crate-find" type="search" placeholder="Find a crate number" data-cw-find aria-label="Find a crate number">'
      + '<button type="button" class="btn btn-sm btn-outline-secondary" data-cw-zero title="Every crate shown, and the loose stock, down to 0"><i class="bi bi-0-circle"></i> All to zero</button>'
      + '<button type="button" class="btn btn-sm btn-outline-secondary" data-cw-clear title="Clear what was typed"><i class="bi bi-eraser"></i> Clear</button>'
      + '<span class="crate-hint">Type the weight each crate has now, or its difference (-0.35). Crates left blank stay as they are. A crate can go down to 0, or back up to what it came in with.</span></div>';
    html += '<div class="table-responsive"><table class="table table-sm crate-table crate-adjust"><thead><tr><th>Crate no.</th><th class="num">Heads</th><th>Production</th><th>Expiry</th>'
      + '<th class="num">Now (' + base + ')</th><th class="num">New weight</th><th class="num">Adjust +/-</th></tr></thead><tbody data-cw-rows>';
    crates.forEach((c) => { html += adjRow(c, set[String(c.id)], false); });
    html += adjRow({ id: 'loose', qty: state.loose || 0 }, set.loose, true);
    html += '</tbody><tfoot><tr><th colspan="4">Totals</th><th class="num" data-cw-left></th><th class="num" data-cw-newt></th><th class="num" data-cw-kg>0.00</th></tr></tfoot></table></div>';
    if (!crates.length) html += '<div class="crate-empty mt-2">No open crate of this item at this site: only its loose stock can be adjusted here.</div>';
    body.innerHTML = html;
    checkAdj();
  }

  /** a crate below 0, or above what it came in with, is marked (and Save refuses it) */
  function checkAdj() {
    let bad = 0;
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const nIn = tr.querySelector('[data-cw-new]');
      const v = nIn.value.trim() === '' ? null : num(nIn.value);
      const max = tr.dataset.max === '' ? null : num(tr.dataset.max);
      const wrong = v !== null && (v < -0.00005 || (max !== null && v > max + 0.00005));
      nIn.classList.toggle('is-invalid', wrong);
      nIn.title = wrong ? (v < 0 ? 'A weight cannot be below 0' : 'It came in with ' + fq(max) + ': it cannot be put above that') : '';
      tr.classList.toggle('is-picked', v !== null && Math.abs(v - num(tr.dataset.left)) > 0.00005);
      if (wrong) bad++;
    });
    return bad;
  }

  function readAdjust() {
    const out = [];
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const nIn = tr.querySelector('[data-cw-new]');
      if (nIn.value.trim() === '') return;
      const d = q2(num(nIn.value) - num(tr.dataset.left));
      if (Math.abs(d) < 0.00005) return;
      out.push(tr.dataset.id === 'loose' ? { id: 'loose', qty: d } : { id: num(tr.dataset.id), qty: d, no: tr.dataset.no });
    });
    return out;
  }

  function adjustInput(el) {
    const tr = el.closest('tr');
    const left = num(tr.dataset.left);
    const nIn = tr.querySelector('[data-cw-new]'), dIn = tr.querySelector('[data-cw-diff]');
    if (el === nIn) {
      dIn.value = nIn.value.trim() === '' ? '' : sign(q2(num(nIn.value) - left));
    } else if (el === dIn) {
      nIn.value = dIn.value.trim() === '' ? '' : String(q2(left + num(dIn.value)));
    }
    checkAdj();
  }

  function adjustAll(zero) {
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      if (tr.hidden) return;
      const nIn = tr.querySelector('[data-cw-new]'), dIn = tr.querySelector('[data-cw-diff]');
      if (zero) {
        if (Math.abs(num(tr.dataset.left)) < 0.00005) return;
        nIn.value = '0'; dIn.value = sign(q2(-num(tr.dataset.left)));
      } else { nIn.value = ''; dIn.value = ''; }
    });
    checkAdj();
    totals();
  }

  // ------------------------------------------------------------------ events
  function totals() {
    if (state.dir === 'adjust') {
      let d = 0, n = 0, now = 0, after = 0;
      const list = readAdjust();
      list.forEach((c) => { d += c.qty; if (c.id !== 'loose') n++; });
      modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => { now += num(tr.dataset.left); });
      after = now + d;
      const l = modal.querySelector('[data-cw-left]'); if (l) l.textContent = fq(now);
      const nt = modal.querySelector('[data-cw-newt]'); if (nt) nt.textContent = fq(after);
      const k = modal.querySelector('[data-cw-kg]'); if (k) { k.textContent = sign(q2(d)); k.classList.toggle('neg', d < -0.00005); }
      const t = modal.querySelector('[data-cw-total]');
      const old = t.textContent;
      t.textContent = sign(q2(d));
      if (old !== t.textContent) { t.classList.remove('tick'); void t.offsetWidth; t.classList.add('tick'); }
      const loose = list.some((c) => c.id === 'loose');
      modal.querySelector('[data-cw-count]').textContent = n + (n === 1 ? ' crate' : ' crates') + (loose ? ' + loose' : '') + ' changed';
      return;
    }
    let kg = 0, pcs = 0, n = 0;
    if (state.dir === 'in') {
      readIn().forEach((c) => { kg += c.qty; pcs += num(c.pcs); n++; });
      const p = modal.querySelector('[data-cw-pcs]'); if (p) p.textContent = fq(pcs).replace(/\.00$/, '');
    } else {
      readOut().forEach((c) => { kg += c.qty; n++; });
      const l = modal.querySelector('[data-cw-left]');
      if (l) l.textContent = fq((state.crates || []).reduce((a, c) => a + num(c.qty), 0));
    }
    const k = modal.querySelector('[data-cw-kg]'); if (k) k.textContent = fq(kg);
    const t = modal.querySelector('[data-cw-total]');
    const old = t.textContent;
    t.textContent = fq(kg);
    if (old !== t.textContent) { t.classList.remove('tick'); void t.offsetWidth; t.classList.add('tick'); }
    modal.querySelector('[data-cw-count]').textContent = n + (n === 1 ? ' crate' : ' crates');
  }

  /**
   * Receiving: the heads, production date and expiry date typed on a crate go down to the crates below it that have not
   * been typed on themselves; a weight typed gives the next crate this crate's heads and dates. The weight is never
   * copied. Every copied value can still be changed (and is then the crate's own).
   */
  function carryDown(el) {
    const k = el.dataset.c, tr = el.closest('tr');
    if (!tr) return;
    const pop = (row) => { row.classList.remove('row-copied'); void row.offsetWidth; row.classList.add('row-copied'); };
    if (k === 'pcs' || k === 'prod' || k === 'exp') {
      el.dataset.own = '1';
      for (let n = tr.nextElementSibling; n; n = n.nextElementSibling) {
        const f = n.querySelector('[data-c="' + k + '"]');
        if (f && f.dataset.own !== '1' && f.value !== el.value) { f.value = el.value; pop(n); }
      }
    } else if (k === 'qty' && el.value.trim() !== '') {
      const n = tr.nextElementSibling;
      if (!n) return;
      let copied = false;
      ['pcs', 'prod', 'exp'].forEach((c) => {
        const src = tr.querySelector('[data-c="' + c + '"]'), f = n.querySelector('[data-c="' + c + '"]');
        if (src && f && f.dataset.own !== '1' && src.value !== '' && f.value !== src.value) { f.value = src.value; copied = true; }
      });
      if (copied) pop(n);
    }
  }

  function onInput(e) {
    const el = e.target;
    if (state && state.dir === 'in' && el.matches('input[data-c]')) carryDown(el);
    if (state && state.dir === 'adjust' && el.matches('[data-cw-new], [data-cw-diff]')) adjustInput(el);
    if (el.matches('[data-cw-tick]')) {
      const tr = el.closest('tr');
      const take = tr.querySelector('[data-cw-take]');
      tr.classList.toggle('is-picked', el.checked);
      if (el.checked && take.value === '') take.value = q2(tr.dataset.left);
      if (!el.checked && !state.whole) take.value = '';
    }
    if (el.matches('[data-cw-take]')) {
      const tr = el.closest('tr');
      const tick = tr.querySelector('[data-cw-tick]');
      const v = num(el.value), left = num(tr.dataset.left);
      if (v > left) el.value = q2(left);
      tick.checked = v > 0;
      tr.classList.toggle('is-picked', v > 0);
    }
    if (el.matches('[data-cw-find]')) {
      const f = el.value.trim().toLowerCase();
      modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => { tr.hidden = f !== '' && String(tr.dataset.no).toLowerCase().indexOf(f) < 0; });
    }
    totals();
  }

  function onClick(e) {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.hasAttribute('data-cw-add')) addIn(Math.max(1, Math.min(200, num(modal.querySelector('#cwAddN').value) || 1)));
    if (b.hasAttribute('data-cw-rep')) replicate();
    if (b.hasAttribute('data-cw-oldest')) pickOldest();
    if (b.hasAttribute('data-cw-zero')) adjustAll(true);
    if (b.hasAttribute('data-cw-clear')) adjustAll(false);
    if (b.hasAttribute('data-cw-del')) { b.closest('tr').remove(); renumber(); totals(); }
  }

  /** Enter in a weight box goes to the next crate's weight (a new crate at the end), as fast as the scale reads */
  function onKey(e) {
    if (e.key !== 'Enter') return;
    const el = e.target;
    if (el.matches && el.matches('input[data-c="qty"]')) {
      e.preventDefault();
      let next = el.closest('tr').nextElementSibling;
      if (!next) { addIn(1); next = modal.querySelector('[data-cw-rows] tr:last-child'); }
      const f = next && next.querySelector('input[data-c="qty"]');
      if (f) { f.focus(); f.select(); }
    } else if (el.matches && el.matches('[data-cw-new], [data-cw-diff]')) {
      // Enter goes to the same box of the next crate
      e.preventDefault();
      const key = el.matches('[data-cw-new]') ? '[data-cw-new]' : '[data-cw-diff]';
      let next = el.closest('tr').nextElementSibling;
      while (next && next.hidden) next = next.nextElementSibling;
      const f = next && next.querySelector(key);
      if (f) { f.focus(); f.select(); }
    } else if (el.matches && el.matches('input:not([type=search])')) {
      e.preventDefault();
    }
  }

  function save() {
    if (state.dir === 'adjust' && checkAdj()) { alert('A weight is below 0, or above what its crate came in with. Correct the boxes marked in red.'); return; }
    const list = state.dir === 'in' ? readIn() : (state.dir === 'adjust' ? readAdjust() : readOut());
    if (state.dir === 'in') {
      const seen = {};
      for (const c of list) {
        if (!(c.qty > 0)) { alert('Type the weight of crate ' + (c.no || '') + '.'); return; }
        const k = String(c.no).toLowerCase();
        if (k && seen[k]) { alert('Crate number ' + c.no + ' is typed twice.'); return; }
        seen[k] = 1;
        if (c.prod && c.exp && c.exp < c.prod) { alert('The expiry date of crate ' + c.no + ' is before its production date.'); return; }
      }
    }
    const total = q2(list.reduce((a, c) => a + num(c.qty), 0));
    if (state.onSave) state.onSave(list, { qty: total, count: list.length });
    hide();
  }

  window.CrateWindow = { open, fq };

  // ------------------------------------------------------------------ the line grids of the transaction forms
  function initGrid(table) {
    const dir = table.dataset.crates;
    const items = table._gridItems || JSON.parse(table.dataset.items || '{}');
    const form = table.closest('form');
    const field = (tr, k) => tr.querySelector('[data-f="' + k + '"]');
    const itemOf = (tr) => { const s = field(tr, 'item_id'); return s ? (table._gridItems || items)[s.value] : null; };
    const unitIsCrate = (tr) => { const u = field(tr, 'uom_id'); const o = u && u.options[u.selectedIndex]; return !!(o && o.dataset.v === '1'); };
    const siteOf = (tr) => {
      const rs = tr.querySelector('select[name$="[site_id]"]');
      if (rs && rs.value) return rs.value;
      const hs = form && form.querySelector('select[name="site_id"]');
      if (hs && hs.value) return hs.value;
      return table.dataset.cratesSite || '';
    };

    function paint(tr) {
      const it = itemOf(tr);
      const btn = tr.querySelector('[data-crate-open]');
      const hid = field(tr, 'crates');
      const qtyF = field(tr, 'qty');
      if (!btn || !hid) return;
      const can = !!(it && it.crate);
      btn.disabled = !can;
      if (!can && hid.value) hid.value = '';
      const list = parse(hid.value);
      const crateUnit = unitIsCrate(tr);
      const lbl = btn.querySelector('[data-crate-label]');
      if (list.length) {
        const kg = list.reduce((a, c) => a + num(c.qty), 0);
        lbl.textContent = list.length + (list.length === 1 ? ' crate' : ' crates');
        btn.title = list.length + (list.length === 1 ? ' crate, ' : ' crates, ') + fq(kg) + ' ' + ((it && it.crate && it.crate.base) || 'kg') + '. Press to change.';
        btn.classList.add('has-crates');
      } else {
        lbl.textContent = 'Crates';
        btn.classList.remove('has-crates');
      }
      btn.classList.toggle('needs-crates', can && crateUnit && !list.length);
      if (qtyF) {
        const lock = can && (crateUnit || list.length > 0);
        qtyF.readOnly = lock;
        qtyF.classList.toggle('qty-from-crates', lock);
        if (lock) qtyF.title = 'The total of the crates: press Crates to change it';
        else qtyF.removeAttribute('title');
      }
    }

    function openFor(tr) {
      const it = itemOf(tr);
      if (!it || !it.crate) return;
      const hid = field(tr, 'crates');
      const crateUnit = unitIsCrate(tr);
      const base = it.crate.base || 'kg';
      const site = siteOf(tr);
      const done = (list, tot) => {
        hid.value = list.length ? JSON.stringify(list) : '';
        // crates typed on a receiving line in kilos: the line goes into crates
        if (dir === 'in' && list.length && !crateUnit) {
          const u = field(tr, 'uom_id');
          if (u) { u.value = String(it.crate.unit_id); u.dispatchEvent(new Event('change', { bubbles: true })); }
        }
        const qtyF = field(tr, 'qty');
        if (qtyF) {
          qtyF.value = list.length ? String(tot.qty) : (crateUnit ? '' : qtyF.value);
          qtyF.dispatchEvent(new Event('input', { bubbles: true }));
        }
        paint(tr);
      };
      const title = (it.code ? it.code + ' ' : '') + (it.name || '');
      if (dir === 'in') {
        open({ dir: 'in', title, sub: 'Crates received, one row per crate. Weights in ' + base + '.', base, value: hid.value, next: table.dataset.crateNext || '1',
          defaultCount: 5,
          today: (form && form.querySelector('[name="txn_date"]') || {}).value || '', onSave: done });
        return;
      }
      if (!site) { alert('Choose the inventory site first.'); return; }
      const url = table.dataset.cratesUrl + '&item_id=' + encodeURIComponent(it.id || field(tr, 'item_id').value) + '&site_id=' + encodeURIComponent(site)
        + (table.dataset.cratesTxn ? '&txn=' + table.dataset.cratesTxn : '');
      fetch(url, { credentials: 'same-origin' }).then((r) => r.json()).then((d) => {
        if (d.error) { alert(d.error); return; }
        open({ dir: 'out', title, sub: (crateUnit ? 'Choose the crates sold' : 'Choose the crate the ' + base + ' come from') + (d.site ? ' at ' + d.site : '') + '.',
          base, whole: crateUnit, crates: d.crates || [], loose: d.loose, value: hid.value, onSave: done });
      }).catch(() => alert('The open crates could not be loaded. Check the connection and try again.'));
    }

    table.addEventListener('click', (e) => {
      const b = e.target.closest('[data-crate-open]');
      if (b && !b.disabled) openFor(b.closest('tr'));
    });
    table.addEventListener('change', (e) => {
      const f = e.target.dataset && e.target.dataset.f;
      const tr = e.target.closest('tr');
      if (!tr || !f) return;
      if (f === 'item_id') {
        const hid = field(tr, 'crates');
        if (hid) hid.value = '';
        if (unitIsCrate(tr)) { const q = field(tr, 'qty'); if (q) { q.value = ''; q.dispatchEvent(new Event('input', { bubbles: true })); } }
        paint(tr);
      } else if (f === 'uom_id') {
        const hid = field(tr, 'crates');
        // a sale switched between crates and kilos chooses its crates again
        if (dir === 'out' && hid && hid.value) { hid.value = ''; }
        paint(tr);
        if (unitIsCrate(tr) && !parse(hid && hid.value).length) {
          const q = field(tr, 'qty'); if (q) { q.value = ''; q.dispatchEvent(new Event('input', { bubbles: true })); }
          openFor(tr);
        }
      } else if (/\[site_id\]$/.test(e.target.name || '') && dir === 'out') {
        const hid = field(tr, 'crates');
        if (hid && hid.value) { hid.value = ''; paint(tr); }
      }
    });
    // the head site changes: crates chosen at the old site no longer apply
    const headSite = form && form.querySelector('select[name="site_id"]');
    if (headSite && dir === 'out') {
      headSite.addEventListener('change', () => table.querySelectorAll('tbody tr').forEach((tr) => { const h = field(tr, 'crates'); if (h && h.value) { h.value = ''; paint(tr); } }));
    }
    table.addEventListener('grid:row-added', (e) => paint(e.target));
    document.addEventListener('gs:quickadd', () => setTimeout(() => table.querySelectorAll('tbody tr').forEach(paint), 50));
    table.querySelectorAll('tbody tr').forEach(paint);
  }

  document.querySelectorAll('table.line-grid[data-crates]').forEach(initGrid);
})();
