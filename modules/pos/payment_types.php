<?php
declare(strict_types=1);

/**
 * Point of Sale > Payment Types & G.L. Accounts (v9)
 *
 * Every payment type (Cash, Check, BPI, Metrobank, EastWest, Gotymebank, BOC, GCash ...) with the General Ledger account
 * it is linked to. The account is the one debited every time money comes in that way: POS sales (and credited by
 * POS returns), customers paying an account balance at the counter, Receive Payments and Enter Sales Receipts.
 * A type without an account uses the module default (PayTypes). The account is kept in payment_methods.clearing_account_id.
 */
$pageKey = 'pos.payment_types';
$types = PayTypes::TYPES;
$accounts = Accts::all();

handle_post(function () use ($pageKey, $types, $accounts) {
    $rows = PayTypes::all();
    $changes = 0;
    $seen = [];
    $plan = [];
    foreach (Access::can($pageKey, 'edit') ? (array)($_POST['pt'] ?? []) : [] as $id => $r) {
        $id = (int)$id;
        if (!isset($rows[$id]) || !is_array($r)) {
            continue;
        }
        $d = [
            'name' => mb_substr(trim((string)($r['name'] ?? '')), 0, 60),
            'method_type' => (string)($r['type'] ?? $rows[$id]['method_type']),
            'clearing_account_id' => ($r['gl'] ?? '') !== '' ? (int)$r['gl'] : null,
            'show_in_pos' => !empty($r['pos']) ? 1 : 0,
            'is_active' => !empty($r['active']) ? 1 : 0,
        ];
        $plan[$id] = $d;
    }
    $new = (array)($_POST['new'] ?? []);
    $newName = mb_substr(trim((string)($new['name'] ?? '')), 0, 60);
    foreach ($plan + ($newName !== '' ? [0 => ['name' => $newName]] : []) as $id => $d) {
        if ($d['name'] === '') {
            fail('Every payment type needs a name' . (isset($rows[$id]) ? ' (it was ' . $rows[$id]['name'] . ')' : '') . '.');
        }
        $k = mb_strtolower($d['name']);
        if (isset($seen[$k])) {
            fail('Two payment types are named "' . $d['name'] . '". Give each its own name.');
        }
        $seen[$k] = true;
    }
    foreach ($plan as $id => $d) {
        if (!isset($types[$d['method_type']])) {
            fail('Choose the kind of payment for ' . $d['name'] . '.');
        }
        if ($d['clearing_account_id'] !== null && !isset($accounts[$d['clearing_account_id']])) {
            fail('Choose an active account of the Chart of Accounts for ' . $d['name'] . '.');
        }
    }
    if ($plan && !array_filter($plan, fn($d) => $d['method_type'] === 'cash' && $d['is_active'] === 1)) {
        fail('Keep one active Cash payment type: the POS Register takes cash, and gives change, with it.');
    }
    DB::tx(function () use ($plan, $rows, $pageKey, $new, $newName, $types, $accounts, &$changes) {
        foreach ($plan as $id => $d) {
            $before = $rows[$id];
            $diff = [];
            foreach ($d as $f => $v) {
                if ((string)$before[$f] !== (string)$v) {
                    $diff[] = $f;
                }
            }
            if (!$diff) {
                continue;
            }
            Access::require($pageKey, 'edit');
            DB::update('payment_methods', $d, 'id = :id', ['id' => $id]);
            Audit::log('edit', 'pos', 'payment_method', $id, $d['name'], ['before' => $before, 'after' => $d, 'page_key' => $pageKey,
                'reason' => in_array('clearing_account_id', $diff, true)
                    ? 'G.L. account: ' . ($d['clearing_account_id'] ? $accounts[$d['clearing_account_id']] : 'none (module default)') : null]);
            $changes++;
        }
        if ($newName !== '') {
            Access::require($pageKey, 'create');
            $type = isset($types[(string)($new['type'] ?? '')]) ? (string)$new['type'] : 'bank_transfer';
            $gl = ($new['gl'] ?? '') !== '' && isset($accounts[(int)$new['gl']]) ? (int)$new['gl'] : null;
            $d = ['name' => $newName, 'method_type' => $type, 'clearing_account_id' => $gl, 'show_in_pos' => !empty($new['pos']) ? 1 : 0, 'is_active' => 1];
            $nid = DB::insert('payment_methods', $d);
            Audit::log('create', 'pos', 'payment_method', $nid, $newName, ['snapshot' => $d, 'page_key' => $pageKey]);
            $changes++;
        }
    });
    PayTypes::reset();
    flash($changes ? 'success' : 'info', $changes ? 'Payment types saved.' : 'Nothing was changed.');
    redirect(url($pageKey));
});

$rows = PayTypes::all();
// how often each type was used: POS tenders, payments and sales receipts (so a type in use is not removed by mistake)
$used = DB::pairs("SELECT payment_method_id, COUNT(*) FROM pos_tenders GROUP BY payment_method_id");
foreach (DB::pairs("SELECT payment_method_id, COUNT(*) FROM transactions WHERE payment_method_id IS NOT NULL AND txn_type IN ('payment','sales_receipt') GROUP BY payment_method_id") as $mid => $n) {
    $used[$mid] = ($used[$mid] ?? 0) + (int)$n;
}
$canEdit = Access::can($pageKey, 'edit');
$canAdd = Access::can($pageKey, 'create');
$posted = $_POST['pt'] ?? null;
$unlinked = array_filter($rows, fn($m) => (int)$m['is_active'] === 1 && $m['method_type'] !== 'cash' && !$m['clearing_account_id']);

layout_start('Payment Types & G.L. Accounts', ['actions' => page_link('pos.terminals', [], 'POS Terminals', 'btn-outline-secondary', 'pc-display')
    . ' ' . page_link('cust.checks', [], 'Customer Checks', 'btn-outline-secondary', 'card-checklist')]);
?>
<form method="post" class="pt-page"><?= csrf_field() ?>
<div class="pt-layout">
  <div class="card pt-card">
    <div class="card-header d-flex flex-wrap justify-content-between align-items-center gap-2">
      <span class="fw-semibold">Payment types</span>
      <span class="small text-muted"><?= count($rows) ?> types, <?= count($rows) - count($unlinked) ?> linked to an account</span>
    </div>
    <div class="table-responsive pt-wrap">
    <table class="table table-sm align-middle mb-0 pt-table">
      <thead><tr><th class="c-name">Payment type</th><th class="c-type">Kind</th><th class="c-gl">G.L. account debited</th><th class="c-pos">On the POS</th><th class="c-act">Active</th></tr></thead>
      <tbody>
      <?php foreach ($rows as $id => $m):
          $v = is_array($posted[$id] ?? null) ? $posted[$id] : null;
          $name = $v['name'] ?? $m['name'];
          $type = $v['type'] ?? $m['method_type'];
          $gl = $v ? (string)($v['gl'] ?? '') : (string)($m['clearing_account_id'] ?? '');
          $pos = $v ? !empty($v['pos']) : (int)$m['show_in_pos'] === 1;
          $act = $v ? !empty($v['active']) : (int)$m['is_active'] === 1;
          $n = (int)($used[$id] ?? 0);
      ?>
        <tr class="<?= $act ? '' : 'is-off' ?>" data-pt-row>
          <td class="c-name" data-label="Payment type">
            <input class="form-control form-control-sm fw-semibold" name="pt[<?= (int)$id ?>][name]" value="<?= h($name) ?>" maxlength="60" required<?= $canEdit ? '' : ' readonly' ?> aria-label="Name">
            <div class="pt-used"><?= $n ? 'Used ' . number_format($n) . ' time' . ($n === 1 ? '' : 's') : 'Not used yet' ?></div></td>
          <td class="c-type" data-label="Kind"><select class="form-select form-select-sm" name="pt[<?= (int)$id ?>][type]" data-no-combo data-pt-type<?= $canEdit ? '' : ' disabled' ?> aria-label="Kind of payment"><?= options($types, $type) ?></select></td>
          <td class="c-gl" data-label="G.L. account debited">
            <select class="form-select form-select-sm" name="pt[<?= (int)$id ?>][gl]" data-combo data-combo-placeholder="Module default account" data-pt-gl<?= $canEdit ? '' : ' disabled' ?> aria-label="G.L. account"><?= options($accounts, $gl, 'Module default account') ?></select>
            <div class="pt-default" data-pt-default>
              <?php if ($gl === ''): ?><span class="<?= $type !== 'cash' ? 'pt-warn' : '' ?>"><?= $type !== 'cash' ? 'Not linked: ' : '' ?><?= h(PayTypes::fallbackText($type)) ?></span><?php endif; ?>
            </div></td>
          <td class="c-pos" data-label="On the POS"><div class="form-check form-switch m-0"><input class="form-check-input" type="checkbox" role="switch" name="pt[<?= (int)$id ?>][pos]" value="1"<?= checked($pos) ?><?= $canEdit ? '' : ' disabled' ?> aria-label="Offered on the POS Register"></div></td>
          <td class="c-act" data-label="Active"><div class="form-check form-switch m-0"><input class="form-check-input" type="checkbox" role="switch" name="pt[<?= (int)$id ?>][active]" value="1"<?= checked($act) ?><?= $canEdit ? '' : ' disabled' ?> aria-label="Active"></div></td>
        </tr>
      <?php endforeach; ?>
      <?php if ($canAdd): $nv = is_array($_POST['new'] ?? null) ? $_POST['new'] : []; ?>
        <tr class="pt-new" data-pt-row>
          <td class="c-name" data-label="New payment type"><input class="form-control form-control-sm" name="new[name]" value="<?= h($nv['name'] ?? '') ?>" maxlength="60" placeholder="Add a payment type" aria-label="New payment type"></td>
          <td class="c-type" data-label="Kind"><select class="form-select form-select-sm" name="new[type]" data-no-combo data-pt-type aria-label="Kind of payment"><?= options($types, $nv['type'] ?? 'bank_transfer') ?></select></td>
          <td class="c-gl" data-label="G.L. account debited"><select class="form-select form-select-sm" name="new[gl]" data-combo data-combo-placeholder="Module default account" data-pt-gl aria-label="G.L. account"><?= options($accounts, $nv['gl'] ?? '', 'Module default account') ?></select>
            <div class="pt-default" data-pt-default></div></td>
          <td class="c-pos" data-label="On the POS"><div class="form-check form-switch m-0"><input class="form-check-input" type="checkbox" role="switch" name="new[pos]" value="1"<?= checked(!empty($nv['pos']) || !$nv) ?> aria-label="Offered on the POS Register"></div></td>
          <td class="c-act" data-label=""></td>
        </tr>
      <?php endif; ?>
      </tbody>
    </table>
    </div>
    <?php if ($canEdit || $canAdd): ?>
    <div class="card-body pt-actions"><button class="btn btn-primary btn-sm" name="save" value="1"><i class="bi bi-check-lg"></i> Save payment types</button>
      <span class="small text-muted">Changes apply to payments received from now on. A sale already recorded keeps the account it went to.</span></div>
    <?php endif; ?>
  </div>

  <aside class="pt-aside">
    <div class="card"><div class="card-body small">
      <h2 class="h6 mb-2">Where the account is used</h2>
      <p class="mb-2">Every time a payment of a type comes in, its account is debited:</p>
      <ul class="pt-uses mb-3">
        <li>sales on the POS Register and the FB POS (a return credits it)</li>
        <li>customers paying an account balance at the counter</li>
        <li>Customers &gt; Receive Payments and Enter Sales Receipts: <em>Deposit to</em> follows the account and cannot be changed there</li>
      </ul>
      <h2 class="h6 mb-2">With no account chosen</h2>
      <ul class="pt-uses mb-3">
        <li>Cash: the cash drawer account of the POS terminal (cash at the counter always goes to the drawer)</li>
        <li>Card: <?= h(PayTypes::fallbackText('card')) ?></li>
        <li>E-wallet: <?= h(PayTypes::fallbackText('ewallet')) ?></li>
        <li>Check, bank and the rest: <?= h(PayTypes::fallbackText('check')) ?></li>
      </ul>
      <h2 class="h6 mb-2">Checks</h2>
      <p class="mb-0">A payment type of the kind Check asks for the check date, number and bank. A post-dated check is not a payment until its date; it is kept on <?= safe_link('cust.checks', [], 'Customer Checks') ?> and in the <?= safe_link('rpt.check_registry', [], 'Check Registry') ?>.</p>
    </div></div>
  </aside>
</div>
</form>
<script>
(function () {
  // the default account a row falls back to, shown under an empty G.L. account
  const fallback = <?= json_encode(array_map(fn($t) => PayTypes::fallbackText($t), array_combine(array_keys($types), array_keys($types)))) ?>;
  document.querySelectorAll('[data-pt-row]').forEach((tr) => {
    const type = tr.querySelector('[data-pt-type]');
    const gl = tr.querySelector('[data-pt-gl]');
    const box = tr.querySelector('[data-pt-default]');
    if (!type || !gl || !box) return;
    const paint = () => {
      if (gl.value) { box.textContent = ''; return; }
      const t = type.value;
      box.innerHTML = '';
      const s = document.createElement('span');
      if (t !== 'cash') s.className = 'pt-warn';
      s.textContent = (t !== 'cash' ? 'Not linked: ' : '') + (fallback[t] || '');
      box.appendChild(s);
    };
    type.addEventListener('change', paint);
    gl.addEventListener('change', paint);
  });
})();
</script>
<?php
layout_end();
