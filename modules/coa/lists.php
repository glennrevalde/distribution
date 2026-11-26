<?php
declare(strict_types=1);

$pageKey = 'coa.lists';
$accounts = Accts::all();
// table => [title, [field => [label, type, options]]]
$lists = [
    'terms' => ['Payment terms', [
        'name' => ['Name', 'text'], 'net_days' => ['Net days', 'int'], 'discount_pct' => ['Early-payment discount %', 'num'],
        'discount_days' => ['Discount if paid within (days)', 'int'], 'is_active' => ['Active', 'bool'],
    ]],
    'tax_codes' => ['Tax codes', [
        'code' => ['Code', 'text'], 'name' => ['Name', 'text'], 'rate' => ['Rate %', 'num'],
        'sales_account_id' => ['Output tax account', 'select', $accounts], 'purchase_account_id' => ['Input tax account', 'select', $accounts], 'is_active' => ['Active', 'bool'],
    ]],
    'payment_methods' => ['Payment methods', [
        'name' => ['Name', 'text'],
        'method_type' => ['Type', 'select', PayTypes::TYPES],
        // v9: the account debited every time money comes in this way (Point of Sale > Payment Types & G.L. Accounts)
        'clearing_account_id' => ['G.L. account', 'select', $accounts], 'show_in_pos' => ['POS payment option', 'bool'], 'is_active' => ['Active', 'bool'],
    ]],
    'price_levels' => ['Price levels', ['name' => ['Name', 'text'], 'adjust_pct' => ['Adjust standard price by %', 'num'], 'is_active' => ['Active', 'bool']]],
    'sales_reps' => ['Sales representatives', array_merge([
        'name' => ['Name', 'text'], 'initials' => ['Initials', 'text'],
    ], SalesReps::ready() ? ['rep_type' => ['Kind', 'select', SalesReps::TYPES]] : [], [
        'user_id' => ['Linked user', 'select', Lookup::users()],
        'commission_pct' => ['Commission %', 'num'], 'is_active' => ['Active', 'bool'],
    ])],
    'customer_types' => ['Customer types', ['name' => ['Name', 'text']]],
    'item_categories' => ['Item categories', ['name' => ['Name', 'text']]],
    'billing_groups' => ['Billing groups', ['name' => ['Name', 'text']]],
];
$tab = array_key_exists(g('tab'), $lists) ? g('tab') : 'terms';
// v2: "Add new sales representative" from a drop-down opens this list's form in a window (QuickAdd)
$popup = QuickAdd::popup() && $tab === 'sales_reps';
[$title, $fields] = $lists[$tab];
$edit = gint('id') ? DB::row("SELECT * FROM `$tab` WHERE id = :id", ['id' => gint('id')]) : null;

handle_post(function () use ($tab, $fields, $edit, $pageKey, $title) {
    Access::require($pageKey, $edit ? 'edit' : 'create');
    $d = [];
    foreach ($fields as $f => [$label, $type]) {
        switch ($type) {
            case 'int':
                $d[$f] = (int)p($f, '0');
                break;
            case 'num':
                $d[$f] = pnum($f);
                break;
            case 'bool':
                $d[$f] = p($f, '0') === '1' ? 1 : 0;
                break;
            case 'select':
                $v = p($f);
                $d[$f] = $v === '' ? null : (ctype_digit((string)$v) ? (int)$v : $v);
                break;
            default:
                $d[$f] = mb_substr(trim((string)p($f)), 0, 80);
        }
    }
    if (($d['name'] ?? $d['code'] ?? '') === '') {
        fail('Enter a name.');
    }
    if ($tab === 'sales_reps' && isset($d['rep_type']) && !isset(SalesReps::TYPES[(string)$d['rep_type']])) {
        $d['rep_type'] = 'sales_rep';
    }
    // v2: one person, one sales representative (each is also a customer, so a second entry would split their shortages)
    if ($tab === 'sales_reps' && DB::value('SELECT 1 FROM sales_reps WHERE LOWER(name) = LOWER(:n)' . ($edit ? ' AND id <> :id' : ''), $edit ? ['n' => $d['name'], 'id' => $edit['id']] : ['n' => $d['name']])) {
        fail($d['name'] . ' is already on the Sales Rep list. Choose them from the list, or give the new person a different name.');
    }
    if ($edit) {
        DB::update($tab, $d, 'id = :id', ['id' => $edit['id']]);
        Audit::log('edit', 'coa', $tab, (int)$edit['id'], $d['name'] ?? $d['code'], ['before' => $edit, 'after' => $d, 'page_key' => $pageKey]);
    } else {
        $id = DB::insert($tab, $d);
        Audit::log('create', 'coa', $tab, $id, $d['name'] ?? $d['code'], ['snapshot' => $d, 'page_key' => $pageKey]);
    }
    // v2: every sales representative, van salesman and cashier is also a customer (shortages are charged to them)
    if ($tab === 'sales_reps') {
        $rid = (int)($edit['id'] ?? $id);
        if ((int)($d['is_active'] ?? 1) === 1) {
            SalesReps::ensureCustomer($rid);
        }
        if ($edit && ($cid = (int)DB::value('SELECT customer_id FROM sales_reps WHERE id = :id', ['id' => $rid]))) {
            // the employee's customer follows a new name (it is the same person)
            $cname = (string)DB::value('SELECT name FROM customers WHERE id = :c', ['c' => $cid]);
            if ($cname === (string)$edit['name'] && $d['name'] !== $edit['name'] && !DB::value('SELECT 1 FROM customers WHERE name = :n AND id <> :c', ['n' => $d['name'], 'c' => $cid])) {
                DB::update('customers', ['name' => $d['name']], 'id = :id', ['id' => $cid]);
            }
        }
        QuickAdd::finish('rep', $rid);
    }
    flash('success', $title . ' updated.');
    redirect_after_save(url($pageKey, ['tab' => $tab]), url($pageKey, ['tab' => $tab, 'id' => $edit['id'] ?? ($id ?? null)]));
});

$rows = DB::all("SELECT * FROM `$tab` ORDER BY " . (isset($fields['name']) ? 'name' : 'id'));
if ($popup) {
    // the window over a transaction: the form only (Cancel closes the window)
    Access::require($pageKey, 'create');
    layout_start('New sales representative', ['no_title' => true]);
    ?>
    <form method="post" class="card qa-list-form"><div class="card-body row g-2"><?= csrf_field() ?>
      <?= input_field('name', 'Name', fv('name', null, (string)g('prefill')), ['class' => 'col-md-6', 'required' => true, 'extra' => 'autofocus maxlength="80"']) ?>
      <?= input_field('initials', 'Initials', fv('initials'), ['class' => 'col-6 col-md-3', 'extra' => 'maxlength="10"']) ?>
      <?= input_field('commission_pct', 'Commission %', fv('commission_pct', null, '0'), ['class' => 'col-6 col-md-3']) ?>
      <?php if (SalesReps::ready()): ?><?= select_field('rep_type', 'Kind', SalesReps::TYPES, fv('rep_type', null, 'sales_rep'), ['class' => 'col-md-6', 'no_add' => true]) ?><?php endif; ?>
      <?= select_field('user_id', 'Linked user (optional)', Lookup::users(), fv('user_id'), ['blank' => '', 'class' => 'col-md-6', 'no_add' => true]) ?>
      <input type="hidden" name="is_active" value="1">
      <p class="col-12 small text-muted mb-1">Saved, the person is put in the box you came from. They are also added as a customer of type Employee, so that a shortage can be charged to them and collected with Receive Payments.</p>
      <div class="col-12"><?= save_buttons('Save') ?></div>
    </div></form>
    <?php
    layout_end();
    return;
}
layout_start('Terms, Tax Codes & Other Lists');
?>
<ul class="nav nav-tabs mb-3">
  <?php foreach ($lists as $k => [$t]): ?><li class="nav-item"><a class="nav-link <?= $k === $tab ? 'active' : '' ?>" href="<?= h(url($pageKey, ['tab' => $k])) ?>"><?= h($t) ?></a></li><?php endforeach; ?>
</ul>
<?php if ($tab === 'payment_methods'): ?>
<div class="small text-muted mb-2"><i class="bi bi-info-circle"></i> The G.L. account of each payment type, and where it is used, is also set on <?= safe_link('pos.payment_types', [], 'Point of Sale > Payment Types & G.L. Accounts') ?>.</div>
<?php endif; ?>
<?php if ($tab === 'item_categories'): ?>
<div class="small text-muted mb-2"><i class="bi bi-info-circle"></i> Categories can also be deleted or merged, with their item counts, on <?= safe_link('inv.categories', [], 'Inventory > Category List') ?>.</div>
<?php endif; ?>
<div class="row g-3">
  <div class="col-lg-7"><div class="card"><div class="table-responsive"><table class="table table-sm table-tight table-hover mb-0">
    <thead><tr><?php foreach ($fields as [$label]): ?><th><?= h($label) ?></th><?php endforeach; ?><th></th></tr></thead>
    <?php foreach ($rows as $r): ?>
      <tr><?php foreach ($fields as $f => $def): $v = $r[$f]; ?>
        <td class="small"><?php
            if ($def[1] === 'bool') { echo (int)$v ? 'Yes' : 'No'; }
            elseif ($def[1] === 'select') { echo h($def[2][$v] ?? ''); }
            elseif ($def[1] === 'num') { echo h((float)$v); }
            else { echo h($v); } ?></td>
      <?php endforeach; ?>
        <td><?= Access::can($pageKey, 'edit') ? '<a href="' . h(url($pageKey, ['tab' => $tab, 'id' => $r['id']])) . '">Edit</a>' : '' ?></td></tr>
    <?php endforeach; ?>
  </table></div></div></div>
  <div class="col-lg-5">
  <?php if (Access::can($pageKey, $edit ? 'edit' : 'create')): ?>
    <form method="post" class="card"><div class="card-header"><?= $edit ? 'Edit' : 'Add' ?> — <?= h($title) ?></div><div class="card-body row g-2">
      <?= csrf_field() ?>
      <?php foreach ($fields as $f => $def): ?>
        <?php if ($def[1] === 'bool'): ?><?= check_field($f, $def[0], fv($f, $edit, 1), 'col-md-6') ?>
        <?php elseif ($def[1] === 'select'): ?><?= select_field($f, $def[0], $def[2], fv($f, $edit), ['blank' => '', 'class' => 'col-md-6']) ?>
        <?php else: ?><?= input_field($f, $def[0], fv($f, $edit, $def[1] === 'text' ? '' : '0'), ['class' => 'col-md-6']) ?><?php endif; ?>
      <?php endforeach; ?>
      <div class="col-12"><?= save_buttons('Save', $edit ? url($pageKey, ['tab' => $tab]) : null, Access::can($pageKey, 'create')) ?></div>
    </div></form>
  <?php endif; ?>
  </div>
</div>
<?php
layout_end();
