<?php
declare(strict_types=1);

/**
 * v9: a customer paying an account balance at the POS counter (POS Register and FB POS).
 *
 * The cashier chooses the customer, then the outstanding invoices being paid, then the payment: amount, payment type
 * and reference, or the check's date, number and bank. The amount goes to the invoices ticked, in the order listed
 * (oldest due first); what is over stays with the customer as a credit.
 * A check dated on or before today is a payment at once. A post-dated check is only received: it waits on Customer
 * Checks and is listed on the cashier's reports as Receipt of Post Dated Check; on its date the payment is recorded.
 */
final class PosPayments
{
    /** The customer's outstanding invoices and charges, for the counter: [balance, docs] */
    public static function openDocs(int $customerId): array
    {
        $pdc = Checks::pendingFor($customerId);
        $docs = [];
        foreach (Balances::openReceivables($customerId) as $d) {
            $docs[] = [
                'id' => (int)$d['id'], 'type' => Txn::label($d['txn_type']), 'no' => (string)$d['txn_no'], 'date' => fdate($d['txn_date']),
                'due' => $d['due_date'] ? fdate($d['due_date']) : '', 'overdue' => $d['due_date'] && $d['due_date'] < today(),
                'total' => r2((float)$d['total']), 'open' => r2((float)$d['open_balance']),
                'job' => (int)$d['customer_id'] !== $customerId ? (string)$d['customer_name'] : '',
                'pdc' => isset($pdc[(int)$d['id']]) ? ['amount' => $pdc[(int)$d['id']][0], 'text' => $pdc[(int)$d['id']][1]] : null,
            ];
        }
        $credits = Balances::customerCredits($customerId);
        return [
            'balance' => r2(Balances::customerBalance($customerId)),
            'credits' => r2(array_sum(array_column($credits, 'remaining'))),
            'docs' => $docs,
        ];
    }

    /**
     * The payment posted from the counter's form. $base: the sale header of the counter (site, terminal, shift, class).
     * Returns ['kind' => 'payment', 'id' => txn id] or ['kind' => 'check', 'id' => customer_checks id] (post-dated).
     */
    public static function receive(array $terminal, array $shift, array $base): array
    {
        $cid = pint('pay_customer_id');
        $amt = r2(pnum('pay_amount'));
        $pm = pint('pay_method_id');
        if (!$cid) {
            fail('Choose the customer paying.');
        }
        $method = PayTypes::get($pm);
        if (!$method || (int)$method['is_active'] !== 1) {
            fail('Choose the payment type.');
        }
        if ($amt <= 0) {
            fail('Enter the amount received.');
        }
        // the invoices ticked, in the order of the list (due date, oldest first)
        $open = [];
        foreach (Balances::openReceivables($cid) as $d) {
            $open[(int)$d['id']] = $d;
        }
        $picked = array_values(array_unique(array_map('intval', (array)($_POST['pay_inv'] ?? []))));
        foreach ($picked as $tid) {
            if (!isset($open[$tid])) {
                fail('One of the invoices ticked is no longer open for this customer. Choose the customer again.');
            }
        }
        if ($open && !$picked) {
            fail('Tick the invoices being paid.');
        }
        $apps = [];
        $left = $amt;
        foreach (array_keys($open) as $tid) {
            if (!in_array($tid, $picked, true) || $left <= 0.004) {
                continue;
            }
            $use = r2(min($left, (float)$open[$tid]['open_balance']));
            $apps[] = ['target_txn_id' => $tid, 'amount' => $use];
            $left = r2($left - $use);
        }
        $cashAcct = (int)$terminal['cash_account_id'];
        $acct = PayTypes::account($pm, $cashAcct, true);
        $classId = $base['class_id'] ?? null;

        if ($method['method_type'] === 'check' && Checks::ready()) {
            [$chkDate, $chkNo, $chkBank] = Checks::fromPost();
            if (Checks::postDated($chkDate)) {
                $id = Checks::receivePostDated([
                    'customer_id' => $cid, 'source' => 'pos', 'terminal_id' => (int)$terminal['id'], 'pos_shift_id' => (int)$shift['id'],
                    'site_id' => (int)$terminal['site_id'], 'bank' => $chkBank, 'check_no' => $chkNo, 'check_date' => $chkDate, 'amount' => $amt,
                    'received_date' => today(), 'payment_method_id' => $pm, 'account_id' => $acct, 'class_id' => $classId,
                    'memo' => 'Received at ' . $terminal['name'],
                    'apply' => array_map(fn($x) => ['id' => $x['target_txn_id'], 'amount' => $x['amount']], $apps),
                ]);
                return ['kind' => 'check', 'id' => $id];
            }
            $ref = $chkNo;
        } else {
            $ref = mb_substr(trim((string)p('pay_ref')), 0, 60) ?: null;
        }
        $id = DB::tx(function () use ($base, $cid, $acct, $pm, $amt, $ref, $terminal, $apps, $method, &$chkDate, &$chkNo, &$chkBank) {
            // array_merge, not "+": the customer paying is the one chosen on this form, not the sale's customer
            $id = Txn::save('payment', array_merge($base, [
                'customer_id' => $cid, 'account_id' => $acct, 'account2_id' => Accts::get('ar'), 'payment_method_id' => $pm,
                'total' => $amt, 'ref_no' => $ref, 'memo' => 'Payment at ' . $terminal['name'], 'receipt_no' => Pos::nextReceipt((int)$terminal['id']),
                'payee_name' => null,
            ]), [], null, ['keep_totals' => true, 'applications' => $apps]);
            if ($method['method_type'] === 'check' && Checks::ready()) {
                Checks::attach($id, ['check_date' => $chkDate, 'check_no' => $chkNo, 'bank' => $chkBank, 'received_date' => today()]);
            }
            return $id;
        });
        return ['kind' => 'payment', 'id' => $id];
    }
}
