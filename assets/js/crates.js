/* G-SMaRT Distribution System - the crate window (no build step)
 *
 * Lines of an item kept in crates carry their crates in a hidden field (JSON):
 *   receiving  [{id?, no, pcs, qty, prod, exp}]  one row per crate typed as it comes off the truck
 *   selling    [{id, qty, no}]                    crates chosen from the open crates of the site
 *   adjusting  [{id, qty, no}, {id: 'loose', qty}] v3: each crate's difference (+ put in, - taken out) and the loose stock's
 *   packing    [{no, pcs, qty, fig}]               v4: loose kilos (packs) put into new crates (Dispatch Inventory,
 *                                                  Convert Kilos to Crates), from one production / expiry group
 * The line's quantity is the total kilos (or packs) of its crates; the price stays per kilo.
 * v4: a "dispatch figure" is a weight typed as a whole number, as the scale reads and as the warehouse calls it out:
 * 1330 is 13.30 kg (packs and pieces are counted as typed). A figure with a decimal point is taken as it is.
 * "Find figure" narrows the open crates to the weights that start with what is typed; Enter takes the first one.
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
  // v4: dispatch figures
  const isWeight = (b) => { const t = String(b || 'kg').trim().toLowerCase(); return /^(kg|kgs|kilo|kilos|kilogram|kilograms|g|gram|grams|lb|lbs)$/.test(t) || t.indexOf('kilo') >= 0; };
  const figToQty = (v, base) => {
    const t = String(v == null ? '' : v).replace(/[,\s]/g, '');
    if (t === '' || !/^\d*\.?\d*$/.test(t) || t === '.') return null;
    if (t.indexOf('.') >= 0) return q2(parseFloat(t) || 0);
    const n = parseInt(t, 10) || 0;
    return isWeight(base) ? q2(n / 100) : n;
  };
  const qtyToFig = (q, base) => (isWeight(base) ? String(Math.round(num(q) * 100)) : String(q2(q)));
  const figDigits = (q, base) => (isWeight(base) ? String(Math.round(num(q) * 100)) : String(q2(q)).replace('.', ''));

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
      // a box the user is already typing in keeps the focus
      const a = document.activeElement;
      if (a && a !== modal && modal.contains(a) && a.matches('input, select, textarea')) return;
      const f = modal.querySelector(state && state.dir === 'in' ? 'input[data-c="qty"]' : (state && state.dir === 'adjust' ? 'input[data-cw-new]'
        : (state && state.dir === 'pack' ? 'input[data-c="fig"]' : 'input[data-cw-fig]')));
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
    modal.classList.toggle('is-pack', opt.dir === 'pack');
    modal.classList.toggle('has-figure', !!opt.figure);
    modal.querySelector('[data-cw-save]').innerHTML = '<i class="bi bi-check-lg"></i> ' + (opt.dir === 'adjust' ? 'Save adjustment' : (opt.dir === 'pack' ? 'Save ' + esc(String(opt.container || 'crates').toLowerCase()) : 'Save crates'));
    if (opt.dir === 'in') renderIn(parse(opt.value)); else if (opt.dir === 'adjust') renderAdjust(parse(opt.value)); else if (opt.dir === 'pack') renderPack(parse(opt.value)); else renderOut(parse(opt.value));
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
    tb.querySelectorAll('tr[data-id]').forEach((tr) => { if (tr.dataset.id) { const n = tr.querySelector('input[data-c="no"]'); if (n) n.dataset.own = '1'; } });
    if (!list.length) addIn(state.defaultCount || 5);
  }

  /** the next free crate number: after every number on the page and the one the system suggests */
  function nextNo() {
    let max = num(state.next) - 1;
    document.querySelectorAll('input[data-f="crates"], input[data-pack-crates]').forEach((h) => { if (h === state.own) return; parse(h.value).forEach((c) => { if (/^\d+$/.test(String(c.no || ''))) max = Math.max(max, num(c.no)); }); });
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

  /**
   * v4: a crate number typed over carries on below it: the crates after it that were numbered by the system get the
   * next numbers (205, 206, 207 ...) up to the next crate whose number was typed by hand.
   */
  function chainNumbers(el) {
    el.dataset.own = '1';
    const v = el.value.trim();
    if (!/^\d+$/.test(v)) return;
    let n = parseInt(v, 10);
    for (let tr = el.closest('tr').nextElementSibling; tr; tr = tr.nextElementSibling) {
      const f = tr.querySelector('input[data-c="no"]');
      if (!f || f.dataset.own === '1') break;
      n++;
      if (f.value !== String(n)) { f.value = String(n); tr.classList.remove('row-copied'); void tr.offsetWidth; tr.classList.add('row-copied'); }
    }
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
    const pick = {}, figOf = {};
    chosen.forEach((c) => { pick[c.id] = c.qty; if (c.fig) figOf[c.id] = c.fig; });
    const crates = state.crates || [];
    const whole = !!state.whole;
    const fig = !!state.figure && whole;
    const base = state.base || 'kg';
    let html = '<div class="crate-tools"><input class="form-control form-control-sm crate-find" type="search" placeholder="Find a crate number" data-cw-find aria-label="Find a crate number">'
      + '<div class="crate-figfind"><input class="form-control form-control-sm" type="search" inputmode="decimal" placeholder="Find figure' + (isWeight(base) ? ', e.g. 1330' : '') + '" data-cw-fig aria-label="Find a crate by its ' + esc(base) + '" title="Type the ' + esc(base) + ' as the scale reads' + (isWeight(base) ? ' (1330 for 13.30)' : '') + ': the crates with a weight like it stay on the list. Enter takes the first one."><span class="crate-figcount" data-cw-figcount aria-live="polite"></span></div>'
      + '<button type="button" class="btn btn-sm btn-outline-primary" data-cw-oldest title="Tick the crates with the earliest expiry date first"><i class="bi bi-sort-up"></i> Oldest first</button>'
      + '<label class="crate-need">' + (whole ? 'Crates' : esc(state.base || 'kg')) + ' needed <input class="form-control form-control-sm" inputmode="decimal" data-cw-need></label>'
      + '<span class="crate-hint">' + (whole ? 'The line is in crates: each crate goes whole.' : 'Tick a crate and type the ' + esc(state.base || 'kg') + ' taken from it; what is left stays in the crate.')
      + (state.loose != null ? ' Loose stock here: ' + fq(state.loose) + ' ' + esc(state.base || 'kg') + '.' : '') + '</span></div>';
    if (!crates.length) {
      html += '<div class="crate-empty">No open crate of this item at this site. Receive it in crates first, or sell it in ' + esc(state.base || 'kg') + ' from loose stock.</div>';
    } else {
      html += '<div class="table-responsive"><table class="table table-sm crate-table crate-pick' + (fig ? ' has-dfig' : '') + '"><thead><tr><th></th><th>Crate no.</th><th class="num">Heads</th><th class="num">Left (' + esc(state.base || 'kg') + ')</th>'
        + (fig ? '<th class="num crate-dfig-h" title="The weight as the scale reads it at dispatch, as a whole number: 1330 for 13.30">Dispatch</th>' : '')
        + '<th>Production</th><th>Expiry</th><th class="num">Take</th></tr></thead><tbody data-cw-rows>';
      crates.forEach((c) => {
        const on = Object.prototype.hasOwnProperty.call(pick, c.id);
        const take = on ? (whole ? c.qty : pick[c.id]) : '';
        const expCls = c.days === null ? '' : (c.days < 0 ? ' is-expired' : (c.days <= 3 ? ' is-near' : ''));
        const df = on && fig && figOf[c.id] ? String(figOf[c.id]) : '';
        html += '<tr data-id="' + c.id + '" data-left="' + c.qty + '" data-no="' + esc(c.no) + '" data-digits="' + esc(figDigits(c.qty, base)) + '" class="' + (on ? 'is-picked' : '') + '">'
          + '<td><input type="checkbox" class="form-check-input" data-cw-tick' + (on ? ' checked' : '') + ' aria-label="Take crate ' + esc(c.no) + '"></td>'
          + '<td class="crate-no">' + esc(c.no) + '</td><td class="num crate-heads" data-label="Heads">' + (c.pcs ? fq(c.pcs).replace(/\.00$/, '') : '') + '</td><td class="num crate-left" data-label="' + esc(state.base || 'kg') + '">' + fq(c.qty) + '</td>'
          + (fig ? '<td class="num crate-dfig" data-label="Dispatch"><input class="form-control form-control-sm text-end" inputmode="decimal" data-cw-dfig value="' + esc(df) + '" placeholder="' + esc(qtyToFig(c.qty, base)) + '" aria-label="Dispatch figure of crate ' + esc(c.no) + '"><small data-cw-dconv></small></td>' : '')
          + '<td class="crate-prod" data-label="Prod.">' + esc(fdate(c.prod)) + '</td><td class="crate-exp' + expCls + '" data-label="Exp.">' + esc(fdate(c.exp)) + (c.days !== null ? '<small>' + (c.days < 0 ? 'expired' : c.days + 'd left') + '</small>' : '') + '</td>'
          + '<td class="num crate-tk" data-label="Take"><input class="form-control form-control-sm text-end crate-take" inputmode="decimal" data-cw-take value="' + esc(take === '' ? '' : q2(take)) + '"' + (whole ? ' readonly tabindex="-1"' : '') + ' aria-label="Take from crate ' + esc(c.no) + '"></td></tr>';
      });
      html += '</tbody><tfoot><tr><th></th><th>Totals</th><th></th><th class="num crate-left" data-label="Left" data-cw-left></th>' + (fig ? '<th></th>' : '') + '<th colspan="2"></th><th class="num crate-tk" data-label="Taken" data-cw-kg>0.00</th></tr></tfoot></table></div>';
    }
    body.innerHTML = html;
    body.querySelectorAll('[data-cw-dfig]').forEach((i) => { if (i.value !== '') dispatchFig(i); });
  }

  /** v4: a dispatch figure typed on an open crate: it must be the crate's own weight (a crate goes whole) */
  function dispatchFig(el) {
    const tr = el.closest('tr');
    const left = num(tr.dataset.left), base = state.base || 'kg';
    const q = figToQty(el.value, base);
    const conv = tr.querySelector('[data-cw-dconv]');
    const tick = tr.querySelector('[data-cw-tick]'), take = tr.querySelector('[data-cw-take]');
    if (el.value.trim() === '' || q === null) {
      el.classList.remove('is-invalid', 'is-valid'); el.title = '';
      if (conv) conv.textContent = el.value.trim() === '' ? '' : 'not a figure';
      return;
    }
    const ok = Math.abs(q - left) <= 0.005;
    if (conv) conv.textContent = '= ' + fq(q) + ' ' + base;
    el.classList.toggle('is-invalid', !ok);
    el.classList.toggle('is-valid', ok);
    el.title = ok ? '' : 'Crate ' + tr.dataset.no + ' holds ' + fq(left) + ' ' + base + '. A crate goes whole: weigh it again, or adjust the crate first.';
    tick.checked = true; tr.classList.add('is-picked'); take.value = q2(left);
  }

  /** v4: the open crates narrowed to a crate number and to a figure (the weights that start with the digits typed) */
  function filterRows() {
    const fEl = modal.querySelector('[data-cw-find]'), gEl = modal.querySelector('[data-cw-fig]');
    const f = fEl ? fEl.value.trim().toLowerCase() : '';
    const g = gEl ? gEl.value.trim() : '';
    const digits = g.replace(/[^\d]/g, '').replace(/^0+(?=\d)/, '');
    const plain = g.replace(/,/g, '');
    let n = 0, first = null;
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      let show = f === '' || String(tr.dataset.no || '').toLowerCase().indexOf(f) >= 0;
      let exact = false;
      if (show && g !== '' && tr.dataset.digits !== undefined) {
        const left = num(tr.dataset.left);
        const shown = fq(left).replace(/,/g, '');
        show = (digits !== '' && String(tr.dataset.digits).indexOf(digits) === 0) || (plain.indexOf('.') >= 0 && shown.indexOf(plain) === 0);
        const q = figToQty(g, state.base || 'kg');
        exact = show && q !== null && Math.abs(q - left) <= 0.005;
      }
      tr.hidden = !show;
      tr.classList.toggle('is-exact', exact && g !== '');
      if (show) { n++; if (!first || (exact && !first.classList.contains('is-exact'))) first = tr; }
    });
    const cnt = modal.querySelector('[data-cw-figcount]');
    if (cnt) cnt.textContent = g === '' ? '' : (n ? n + (n === 1 ? ' crate' : ' crates') : 'none');
    return first;
  }

  /** v4: Enter in Find figure takes the best crate shown (the exact weight first) and clears the box for the next figure */
  function takeFound() {
    const gEl = modal.querySelector('[data-cw-fig]');
    const typed = gEl.value.trim();
    let pick = null;
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      if (tr.hidden || tr.querySelector('[data-cw-tick]').checked) return;
      if (!pick || (tr.classList.contains('is-exact') && !pick.classList.contains('is-exact'))) pick = tr;
    });
    if (!pick) return;
    const tick = pick.querySelector('[data-cw-tick]'), take = pick.querySelector('[data-cw-take]');
    tick.checked = true; pick.classList.add('is-picked');
    if (take.value === '' || state.whole) take.value = q2(pick.dataset.left);
    const df = pick.querySelector('[data-cw-dfig]');
    if (df && typed !== '') { df.value = typed.replace(/[,\s]/g, ''); dispatchFig(df); }
    gEl.value = '';
    filterRows();
    pick.scrollIntoView({ block: 'nearest' });
    pick.classList.remove('row-copied'); void pick.offsetWidth; pick.classList.add('row-copied');
    totals();
  }

  function readOut() {
    const out = [];
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const tick = tr.querySelector('[data-cw-tick]');
      if (!tick || !tick.checked) return;
      const left = num(tr.dataset.left);
      const take = state.whole ? left : Math.min(left, q2(tr.querySelector('[data-cw-take]').value));
      const df = tr.querySelector('[data-cw-dfig]');
      const c = { id: num(tr.dataset.id), qty: q2(take), no: tr.dataset.no };
      if (df && df.value.trim() !== '') c.fig = df.value.trim();
      if (take > 0) out.push(c);
    });
    return out;
  }

  // ------------------------------------------------------------------ v4 packing: loose stock put into new crates
  function packRow(c, i) {
    return '<tr>'
      + '<td class="crate-seq">' + (i + 1) + '</td>'
      + '<td><input class="form-control form-control-sm" data-c="no" value="' + esc(c.no || '') + '"' + (c.own ? ' data-own="1"' : '') + ' aria-label="Crate number"></td>'
      + '<td class="num"><input class="form-control form-control-sm text-end" inputmode="decimal" data-c="pcs" value="' + esc(c.pcs ? c.pcs : '') + '" aria-label="Heads"></td>'
      + '<td class="num"><input class="form-control form-control-sm text-end crate-fig" inputmode="decimal" data-c="fig" value="' + esc(c.fig || '') + '" aria-label="Dispatch figure"></td>'
      + '<td class="num"><input class="form-control form-control-sm text-end crate-kg" inputmode="decimal" data-c="qty" value="' + esc(c.qty ? q2(c.qty) : '') + '" aria-label="Weight"></td>'
      + '<td class="text-end"><button type="button" class="btn btn-sm btn-link text-danger p-0" data-cw-del title="Remove this crate" aria-label="Remove this crate"><i class="bi bi-x-lg"></i></button></td></tr>';
  }

  function renderPack(list) {
    const body = modal.querySelector('[data-cw-body]');
    const base = esc(state.base || 'kg');
    const one = esc(String(state.container1 || 'Crate').toLowerCase());
    const groups = state.groups || [];
    if (!state.lot && groups.length) state.lot = groups[0].key;
    let html = '';
    if (!groups.length) {
      body.innerHTML = '<div class="crate-empty">No loose stock of this item at ' + esc(state.site || 'this site') + ' to put into ' + esc(String(state.container || 'crates').toLowerCase()) + '.</div>';
      return;
    }
    const dated = groups.some((g) => g.dated);
    html += '<div class="pack-groups"><div class="pack-groups-head">' + (dated ? 'Production / expiry group the ' + base + ' come from' : 'Loose stock here') + '</div><div class="pack-group-list" role="radiogroup">';
    groups.forEach((g) => {
      const st = g.status === 'expired' ? ' is-expired' : (g.status === 'expiring' ? ' is-near' : '');
      html += '<label class="pack-group' + st + (g.key === state.lot ? ' is-on' : '') + '"><input type="radio" class="form-check-input" name="cwPackLot" value="' + esc(g.key) + '" data-cw-lot' + (g.key === state.lot ? ' checked' : '') + '>'
        + '<span class="pack-group-text"><strong>' + (g.dated ? (g.exp ? 'Exp. ' + esc(fdate(g.exp)) : 'No expiry') + (g.prod ? '<small>Prod. ' + esc(fdate(g.prod)) + '</small>' : '') : esc(g.label)) + '</strong>'
        + '<span class="pack-group-qty">' + fq(g.qty) + ' ' + base + ' loose</span></span></label>';
    });
    html += '</div>';
    const cur = groups.find((g) => g.key === state.lot) || groups[0];
    html += '<div class="pack-dates"' + (cur && cur.dated ? ' hidden' : '') + '><label>Production date<input type="date" class="form-control form-control-sm" data-cw-pprod value="' + esc(state.prod || '') + '"></label>'
      + '<label>Expiry date<input type="date" class="form-control form-control-sm" data-cw-pexp value="' + esc(state.exp || '') + '"></label>'
      + '<span class="crate-hint">These ' + base + ' have no dates on file: the dates typed here go on every ' + one + ', and on the ' + base + ' put into it.</span></div></div>';
    html += '<div class="crate-tools"><div class="crate-add"><label class="visually-hidden" for="cwAddN">' + esc(state.container || 'Crates') + ' to add</label>'
      + '<input id="cwAddN" class="form-control form-control-sm" type="number" min="1" max="200" value="' + (list.length ? 1 : (state.defaultCount || 5)) + '">'
      + '<button type="button" class="btn btn-sm btn-outline-primary" data-cw-padd><i class="bi bi-plus-lg"></i> Add ' + esc(String(state.container || 'crates').toLowerCase()) + '</button></div>'
      + '<span class="crate-hint">Type each ' + one + '\'s weight as the scale reads it' + (isWeight(state.base) ? ', as a whole number: <strong>1330</strong> is 13.30 ' + base + ' (a figure with a decimal point is taken as it is)' : '') + '. Enter goes to the next ' + one
      + '. Numbers follow on from the last ' + one + '; typing over a number carries on from it.</span></div>';
    html += '<div class="table-responsive"><table class="table table-sm crate-table crate-pack"><thead><tr><th>Seq</th><th>' + esc(state.container1 || 'Crate') + ' no.</th><th class="num">Heads</th><th class="num">Dispatch</th><th class="num">Weight (' + base + ')</th><th></th></tr></thead><tbody data-cw-rows></tbody>'
      + '<tfoot><tr><th></th><th>Totals</th><th class="num" data-cw-pcs>0</th><th></th><th class="num" data-cw-kg>0.00</th><th></th></tr>'
      + '<tr class="pack-left"><th colspan="4">Left loose in the group after</th><th class="num" data-cw-after></th><th></th></tr></tfoot></table></div>';
    body.innerHTML = html;
    const tb = body.querySelector('[data-cw-rows]');
    tb.innerHTML = list.map((c, i) => packRow(Object.assign({ own: 1 }, c), i)).join('');
    if (!list.length) addPack(state.defaultCount || 5);
  }

  function addPack(n) {
    const tb = modal.querySelector('[data-cw-rows]');
    if (!tb) return;
    const last = tb.querySelector('tr:last-child');
    const pcs = last ? last.querySelector('[data-c="pcs"]').value : '';
    for (let k = 0; k < n; k++) {
      const i = tb.querySelectorAll('tr').length;
      tb.insertAdjacentHTML('beforeend', packRow({ no: nextNo(), pcs: pcs }, i));
      const tr = tb.lastElementChild;
      tr.classList.add('row-new');
      setTimeout(() => tr.classList.remove('row-new'), 1200);
    }
    renumber();
    totals();
  }

  function readPack() {
    const out = [];
    modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => {
      const g = (k) => tr.querySelector('[data-c="' + k + '"]').value.trim();
      const qty = q2(g('qty'));
      if (!qty) return;
      const c = { no: g('no'), pcs: num(g('pcs')), qty: qty };
      if (g('fig') !== '') c.fig = g('fig');
      out.push(c);
    });
    return out;
  }

  /** the group chosen, and how much of it is left once these crates are filled */
  function packLeft() {
    const g = (state.groups || []).find((x) => x.key === state.lot);
    const used = readPack().reduce((a, c) => a + c.qty, 0) + num(state.others && state.others[state.lot]);
    return g ? q2(num(g.qty) - used) : 0;
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
          + '<td class="crate-prod" data-label="Prod.">' + esc(fdate(c.prod)) + '</td><td class="crate-exp' + expCls + '" data-label="Exp.">' + esc(fdate(c.exp)) + (c.days !== null && c.days !== undefined ? '<small>' + (c.days < 0 ? 'expired' : c.days + 'd left') + '</small>' : '') + '</td>')
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
    if (state.dir === 'pack') {
      readPack().forEach((c) => { kg += c.qty; pcs += num(c.pcs); n++; });
      const p = modal.querySelector('[data-cw-pcs]'); if (p) p.textContent = fq(pcs).replace(/\.00$/, '');
      const a = modal.querySelector('[data-cw-after]');
      if (a) { const left = packLeft(); a.textContent = fq(left) + ' ' + (state.base || 'kg'); a.closest('tr').classList.toggle('is-over', left < -0.00005); }
    } else if (state.dir === 'in') {
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
    const one = state.dir === 'pack' ? String(state.container1 || 'crate').toLowerCase() : 'crate';
    const many = state.dir === 'pack' ? String(state.container || 'crates').toLowerCase() : 'crates';
    modal.querySelector('[data-cw-count]').textContent = n + ' ' + (n === 1 ? one : many);
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
    if (state && (state.dir === 'in' || state.dir === 'pack') && el.matches('input[data-c="no"]') && e.type === 'input') chainNumbers(el);
    if (state && state.dir === 'in' && el.matches('input[data-c]') && el.dataset.c !== 'no') carryDown(el);
    if (state && state.dir === 'pack') {
      if (el.matches('input[data-c="fig"]')) {
        const tr = el.closest('tr'), q = figToQty(el.value, state.base);
        const w = tr.querySelector('[data-c="qty"]');
        w.value = q === null ? (el.value.trim() === '' ? '' : w.value) : (q > 0 ? (isWeight(state.base) ? q.toFixed(2) : String(q)) : '');
        el.classList.toggle('is-invalid', el.value.trim() !== '' && q === null);
      } else if (el.matches('input[data-c="qty"]') && e.type === 'input') {
        const f = el.closest('tr').querySelector('[data-c="fig"]');
        f.value = el.value.trim() === '' ? '' : qtyToFig(el.value, state.base); f.classList.remove('is-invalid');
      } else if (el.matches('input[data-c="pcs"]') && e.type === 'input') {
        el.dataset.own = '1';
        for (let n = el.closest('tr').nextElementSibling; n; n = n.nextElementSibling) {
          const f = n.querySelector('[data-c="pcs"]');
          if (f && f.dataset.own !== '1') f.value = el.value;
        }
      } else if (el.matches('[data-cw-lot]')) {
        state.lot = el.value;
        modal.querySelectorAll('.pack-group').forEach((l) => l.classList.toggle('is-on', l.querySelector('input').checked));
        const g = (state.groups || []).find((x) => x.key === state.lot);
        const d = modal.querySelector('.pack-dates'); if (d) d.hidden = !!(g && g.dated);
      }
    }
    if (el.matches('[data-cw-dfig]')) dispatchFig(el);
    if (state && state.dir === 'adjust' && el.matches('[data-cw-new], [data-cw-diff]')) adjustInput(el);
    if (el.matches('[data-cw-tick]')) {
      const tr = el.closest('tr');
      const take = tr.querySelector('[data-cw-take]');
      tr.classList.toggle('is-picked', el.checked);
      if (el.checked && take.value === '') take.value = q2(tr.dataset.left);
      if (!el.checked && !state.whole) take.value = '';
      const df = tr.querySelector('[data-cw-dfig]');
      if (!el.checked && df) { df.value = ''; df.classList.remove('is-invalid', 'is-valid'); const c = tr.querySelector('[data-cw-dconv]'); if (c) c.textContent = ''; }
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
      if (state.dir === 'out') filterRows();
      else {
        const f = el.value.trim().toLowerCase();
        modal.querySelectorAll('[data-cw-rows] tr').forEach((tr) => { tr.hidden = f !== '' && String(tr.dataset.no).toLowerCase().indexOf(f) < 0; });
      }
    }
    if (el.matches('[data-cw-fig]')) filterRows();
    totals();
  }

  function onClick(e) {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.hasAttribute('data-cw-add')) addIn(Math.max(1, Math.min(200, num(modal.querySelector('#cwAddN').value) || 1)));
    if (b.hasAttribute('data-cw-padd')) addPack(Math.max(1, Math.min(200, num(modal.querySelector('#cwAddN').value) || 1)));
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
    if (el.matches && el.matches('[data-cw-fig]')) {
      e.preventDefault();
      takeFound();
      return;
    }
    if (el.matches && el.matches('[data-cw-dfig]')) {
      // Enter goes to the dispatch figure of the next crate shown
      e.preventDefault();
      let next = el.closest('tr').nextElementSibling;
      while (next && next.hidden) next = next.nextElementSibling;
      const f = next && next.querySelector('[data-cw-dfig]');
      if (f) { f.focus(); f.select(); }
      return;
    }
    if (state && state.dir === 'pack' && el.matches && el.matches('input[data-c="fig"], input[data-c="qty"]')) {
      e.preventDefault();
      const key = el.dataset.c;
      let next = el.closest('tr').nextElementSibling;
      if (!next) { addPack(1); next = modal.querySelector('[data-cw-rows] tr:last-child'); }
      const f = next && next.querySelector('input[data-c="' + key + '"]');
      if (f) { f.focus(); f.select(); }
      return;
    }
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
    if (state.dir === 'out' && modal.querySelector('[data-cw-dfig].is-invalid')) {
      alert('A dispatch figure is not the weight of its crate (marked in red). A crate goes whole: correct the figure, or untick the crate.');
      return;
    }
    if (state.dir === 'pack') {
      const list = readPack();
      if (!(state.groups || []).length) { hide(); return; }
      if (modal.querySelector('input[data-c="fig"].is-invalid')) { alert('A dispatch figure is not a number (marked in red).'); return; }
      const seen = {};
      for (const c of list) {
        const k = String(c.no).toLowerCase();
        if (k && seen[k]) { alert('Number ' + c.no + ' is typed twice.'); return; }
        seen[k] = 1;
      }
      if (packLeft() < -0.00005) { alert('The ' + (state.container || 'crates').toLowerCase() + ' hold more than the loose stock of the group chosen. Lower the weights, or choose another group.'); return; }
      const pp = modal.querySelector('[data-cw-pprod]'), pe = modal.querySelector('[data-cw-pexp]');
      const g = (state.groups || []).find((x) => x.key === state.lot) || {};
      const extra = { lot: state.lot || '', prod: g.dated ? '' : (pp ? pp.value : ''), exp: g.dated ? '' : (pe ? pe.value : ''), label: g.label || '' };
      if (extra.prod && extra.exp && extra.exp < extra.prod) { alert('The expiry date is before the production date.'); return; }
      const total = q2(list.reduce((a, c) => a + num(c.qty), 0));
      if (state.onSave) state.onSave(list, { qty: total, count: list.length }, extra);
      hide();
      return;
    }
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

  window.CrateWindow = { open, fq, figToQty, isWeight };

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
