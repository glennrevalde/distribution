<?php
declare(strict_types=1);

/**
 * v9: "Customer paying an account balance" on the POS Register and the FB POS.
 * 1. the customer; 2. the outstanding invoices, ticked; 3. the payment: amount, payment type and reference, or a
 * check's date, number and bank. Posted with do=payment to the register (PosPayments::receive).
 * Needs: $methods (the active payment types), $apWrap ('card' or 'plain').
 */
$apWrap = $apWrap ?? 'card';
$apBack = is_post() && p('do') === 'payment';
$apInit = $apBack ? [
    'customer' => (string)p('pay_customer_id'), 'amount' => (string)p('pay_amount'), 'method' => (string)p('pay_method_id'),
    'ref' => (string)p('pay_ref'), 'inv' => array_values(array_map('intval', (array)($_POST['pay_inv'] ?? []))),
] : null;
$apCash = 0;
foreach ($methods as $m) {
    if ($m['method_type'] === 'cash') {
        $apCash = (int)$m['id'];
        break;
    }
}
$apMethod = $apBack ? (int)p('pay_method_id') : $apCash;
?>
<form method="post" class="<?= $apWrap === 'card' ? 'card mt-3 ' : '' ?>acct-pay" id="acctPay" data-api="<?= h(url('api.lookup', ['what' => 'open_invoices'])) ?>" novalidate>
  <?= csrf_field() ?><input type="hidden" name="do" value="payment">
  <?php if ($apWrap === 'card'): ?><div class="card-header small fw-semibold">Customer paying an account balance</div><?php endif; ?>
  <div class="<?= $apWrap === 'card' ? 'card-body' : '' ?> ap-body">
    <label class="form-label" for="apCust">Customer</label>
    <select class="form-select form-select-sm" name="pay_customer_id" id="apCust" data-combo data-combo-placeholder="Type the customer's name"><?= options(Lookup::customers(false), $apInit['customer'] ?? null, 'Choose the customer…') ?></select>

    <div class="ap-inv" id="apInv" hidden>
      <div class="ap-inv-head">
        <span class="ap-inv-title">Outstanding invoices</span>
        <span class="ap-bal">Balance <strong id="apBal">0.00</strong></span>
      </div>
      <div class="ap-loading" id="apLoading" hidden><span class="spinner-border spinner-border-sm"></span> Looking up the invoices…</div>
      <label class="ap-all" id="apAllBox" hidden><input class="form-check-input" type="checkbox" id="apAll"> Pay all of them</label>
      <div class="ap-list" id="apList" role="group" aria-label="Outstanding invoices"></div>
      <div class="ap-empty" id="apEmpty" hidden>No outstanding invoices. A payment received now is kept as a credit for the customer.</div>
      <div class="ap-hint" id="apHint">Tick the invoices being paid.</div>
    </div>

    <div class="ap-pay" id="apPay" hidden>
      <div class="ap-pay-title">Payment</div>
      <div class="row g-2">
        <div class="col-6"><label class="form-label" for="apAmt">Amount</label>
          <input class="form-control form-control-sm text-end ap-amt" name="pay_amount" id="apAmt" inputmode="decimal" autocomplete="off" value="<?= h($apInit['amount'] ?? '') ?>"></div>
        <div class="col-6"><label class="form-label" for="apMethod">Payment type</label>
          <select class="form-select form-select-sm" name="pay_method_id" id="apMethod" data-no-combo>
            <?php foreach ($methods as $m): ?><option value="<?= (int)$m['id'] ?>" data-type="<?= h($m['method_type']) ?>"<?= (int)$m['id'] === $apMethod ? ' selected' : '' ?>><?= h($m['name']) ?></option><?php endforeach; ?>
          </select></div>
        <div class="col-12 ap-ref" id="apRefBox"><input class="form-control form-control-sm" name="pay_ref" id="apRef" maxlength="60" placeholder="Reference / approval no." value="<?= h($apInit['ref'] ?? '') ?>" aria-label="Reference"></div>
      </div>
      <div class="ap-check" id="apCheck" hidden>
        <div class="row g-2">
          <div class="col-6"><label class="form-label" for="apChkDate">Check date</label><input class="form-control form-control-sm" type="date" name="chk_date" id="apChkDate" value="<?= h($apBack ? (string)p('chk_date') : today()) ?>"></div>
          <div class="col-6"><label class="form-label" for="apChkNo">Check number</label><input class="form-control form-control-sm" name="chk_no" id="apChkNo" maxlength="40" inputmode="numeric" autocomplete="off" value="<?= h($apBack ? (string)p('chk_no') : '') ?>"></div>
          <div class="col-12"><label class="form-label" for="apChkBank">Bank</label><input class="form-control form-control-sm" name="chk_bank" id="apChkBank" maxlength="80" list="apBanks" autocomplete="off" value="<?= h($apBack ? (string)p('chk_bank') : '') ?>"></div>
        </div>
        <datalist id="apBanks"><?php foreach (PayTypes::bankNames() as $bn): ?><option value="<?= h($bn) ?>"><?php endforeach; ?></datalist>
      </div>
      <div class="ap-note" id="apNote" hidden></div>
      <div class="ap-pdc" id="apPdc" hidden><i class="bi bi-calendar2-event"></i> <span>Post-dated: only the check is received now. It is recorded as payment on <strong id="apPdcDate"></strong>, and is on your shift report as Receipt of Post Dated Check.</span></div>
      <button class="btn btn-success w-100 mt-2" type="submit" id="apGo"><i class="bi bi-cash-coin"></i> <span>Receive payment</span></button>
    </div>
  </div>
</form>
<script>
(function () {
  const form = document.getElementById('acctPay');
  if (!form) return;
  const init = <?= json_encode($apInit) ?>;
  const today = <?= json_encode(today()) ?>;
  const $ = (id) => document.getElementById(id);
  const cust = $('apCust'), inv = $('apInv'), list = $('apList'), pay = $('apPay'), amt = $('apAmt'), method = $('apMethod');
  const { num, r2, fmt } = AppFmt;
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  let docs = [], typed = false, req = 0;
  const picked = () => docs.filter((d) => { const c = list.querySelector('input[value="' + d.id + '"]'); return c && c.checked; });
  const dmy = (iso) => { const p = String(iso).split('-'); return p.length === 3 ? p[1] + '/' + p[2] + '/' + p[0] : iso; };

  function load(keep) {
    const id = cust.value;
    docs = [];
    list.innerHTML = '';
    inv.hidden = !id;
    pay.hidden = true;
    if (!id) return;
    $('apLoading').hidden = false;
    $('apEmpty').hidden = true;
    $('apAllBox').hidden = true;
    $('apHint').hidden = true;
    const mine = ++req;
    fetch(form.dataset.api + '&customer=' + encodeURIComponent(id), { credentials: 'same-origin', headers: { 'Accept': 'application/json' } })
      .then((r) => r.json()).then((j) => {
        if (mine !== req) return;
        $('apLoading').hidden = true;
        docs = j.docs || [];
        $('apBal').textContent = fmt(j.balance || 0);
        list.innerHTML = docs.map((d) => '<label class="ap-doc' + (d.overdue ? ' is-overdue' : '') + '">'
          + '<input class="form-check-input" type="checkbox" name="pay_inv[]" value="' + d.id + '">'
          + '<span class="ap-doc-main"><span class="ap-doc-no">' + esc(d.no) + '</span><span class="ap-doc-type">' + esc(d.type) + (d.job ? ', ' + esc(d.job) : '') + '</span>'
          + '<span class="ap-doc-dates">' + esc(d.date) + (d.due ? ', due ' + esc(d.due) : '') + '</span>'
          + (d.pdc ? '<span class="ap-doc-pdc"><i class="bi bi-calendar2-event"></i> ' + esc(d.pdc.text) + '</span>' : '') + '</span>'
          + '<span class="ap-doc-amt"><span class="ap-doc-open">' + fmt(d.open) + '</span>' + (Math.abs(d.open - d.total) > 0.004 ? '<span class="ap-doc-total">of ' + fmt(d.total) + '</span>' : '') + '</span></label>').join('');
        $('apEmpty').hidden = docs.length > 0;
        $('apAllBox').hidden = docs.length < 2;
        $('apHint').hidden = docs.length === 0;
        if (keep && init && init.inv) init.inv.forEach((v) => { const c = list.querySelector('input[value="' + v + '"]'); if (c) c.checked = true; });
        typed = !!(keep && init && init.amount);
        paint(!typed);
      }).catch(() => { $('apLoading').hidden = true; list.innerHTML = '<div class="ap-empty">The invoices could not be looked up. Check the connection and choose the customer again.</div>'; });
  }

  function paint(fill) {
    const sel = picked();
    const sum = r2(sel.reduce((s, d) => s + d.open, 0));
    pay.hidden = docs.length > 0 && sel.length === 0;
    $('apHint').hidden = docs.length === 0 || sel.length > 0;
    list.querySelectorAll('.ap-doc').forEach((l) => l.classList.toggle('is-on', l.querySelector('input').checked));
    const all = $('apAll');
    if (all) all.checked = docs.length > 0 && sel.length === docs.length;
    if (fill || !typed) { amt.value = sum > 0 ? sum.toFixed(2) : ''; typed = false; }
    // what the amount does to the invoices ticked, oldest first
    const a = num(amt.value);
    const note = $('apNote');
    let text = '';
    if (sel.length && a > 0) {
      let left = a; const part = [];
      sel.forEach((d) => { const use = Math.min(left, d.open); if (use > 0.004 && use < d.open - 0.004) part.push(d.no + ' (' + fmt(use) + ' of ' + fmt(d.open) + ')'); left = r2(left - use); });
      if (a < sum - 0.004) text = 'Less than the invoices ticked: they are paid oldest first' + (part.length ? ', ' + part.join(', ') + ' in part' : '') + '.';
      else if (a > sum + 0.004) text = fmt(r2(a - sum)) + ' more than the invoices ticked: it is kept as a credit for the customer.';
    }
    note.textContent = text;
    note.hidden = text === '';
    kind();
  }

  function kind() {
    const o = method.options[method.selectedIndex];
    const isCheck = !!(o && o.dataset.type === 'check');
    $('apCheck').hidden = !isCheck;
    $('apRefBox').hidden = isCheck;
    ['apChkDate', 'apChkNo', 'apChkBank'].forEach((id) => { $(id).disabled = !isCheck; });
    const d = $('apChkDate').value;
    const pdc = isCheck && d > today;
    $('apPdc').hidden = !pdc;
    if (pdc) $('apPdcDate').textContent = dmy(d);
    $('apGo').querySelector('span').textContent = pdc ? 'Receive post-dated check' : 'Receive payment';
  }

  cust.addEventListener('change', () => load(false));
  list.addEventListener('change', () => paint(true));
  $('apAll').addEventListener('change', (e) => { list.querySelectorAll('input').forEach((c) => { c.checked = e.target.checked; }); paint(true); });
  amt.addEventListener('input', () => { typed = amt.value.trim() !== ''; paint(false); });
  method.addEventListener('change', kind);
  $('apChkDate').addEventListener('input', kind);
  form.addEventListener('submit', (e) => {
    const err = !cust.value ? 'Choose the customer paying.'
      : (docs.length && !picked().length ? 'Tick the invoices being paid.'
      : (!(num(amt.value) > 0) ? 'Enter the amount received.'
      : (!$('apCheck').hidden && (!$('apChkDate').value || !$('apChkNo').value.trim() || !$('apChkBank').value.trim()) ? 'Enter the check date, number and bank.' : '')));
    if (err) {
      e.preventDefault();
      const note = $('apNote');
      note.textContent = err; note.hidden = false; note.classList.add('is-error');
      setTimeout(() => note.classList.remove('is-error'), 2500);
    }
  });
  if (init && init.customer) load(true);
  kind();
})();
</script>
