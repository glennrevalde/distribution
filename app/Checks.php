<?php
declare(strict_types=1);

/**
 * v9: the checks customers pay with, at the POS (a customer paying an account balance) and on Receive Payments.
 *
 * Every check is kept in customer_checks with its bank, number, date and amount.
 *   A check dated on or before the day it is received is a payment at once: the payment is recorded and posted.
 *   A post-dated check is not a payment yet. Only its receipt is kept: the cashier's reports list it as "Receipt of
 *   Post Dated Check", with its details, and it waits as Pending. The invoices it is meant for are kept with it. On
 *   the check's date the payment is recorded (dated the check's date) and applied to those invoices, and its journal
 *   entries are made. This is done the first time anyone opens the system that day (index.php), on the Check
 *   Registry, and by "Record payment" there.
 *
 * Status (Check Registry): Pending (post-dated), On Date (its date has come: recorded as a payment), Cleared (deposited
 * and honored), Returned (deposited and dishonored). A returned check puts the amount back on the customer's account
 * with a statement charge ("Returned check"), credited to the bank account it was deposited to (or to the account the
 * payment went to, when it was never deposited).
 */
final class Checks
{
    public const STATUSES = ['pending' => 'Pending', 'on_date' => 'On Date', 'cleared' => 'Cleared', 'returned' => 'Returned'];
    public const STATUS_HELP = [
        'pending'  => 'The check is post-dated',
        'on_date'  => 'The date of the check is on or before today',
        'cleared'  => 'Deposited to the bank and honored',
        'returned' => 'Deposited to the bank and dishonored',
    ];

    private static ?bool $ready = null;

    /** Whether the table is there (the 2027_05_03 migration) */
    public static function ready(): bool
    {
        if (self::$ready === null) {
            try {
                DB::value('SELECT COUNT(*) FROM customer_checks WHERE 1 = 0');
                self::$ready = true;
            } catch (Throwable $e) {
                self::$ready = false;
            }
        }
        return self::$ready;
    }

    public static function postDated(string $checkDate, ?string $on = null): bool
    {
        return $checkDate > ($on ?? today());
    }

    /** The status a check shows: a pending check whose date has come is On Date (its payment is due to be recorded) */
    public static function status(array $c): string
    {
        if ($c['status'] === 'pending') {
            return $c['check_date'] <= today() ? 'on_date' : 'pending';
        }
        return (string)$c['status'];
    }

    public static function statusText(string $s): string
    {
        return self::STATUSES[$s] ?? ucfirst($s);
    }

    /** "BPI no. 104233, dated 12/05/2026" */
    public static function describe(array $c): string
    {
        return trim($c['bank'] . ' no. ' . $c['check_no']) . ', dated ' . fdate($c['check_date']);
    }

    public static function ackNo(int $id): string
    {
        return 'PDC-' . str_pad((string)$id, 6, '0', STR_PAD_LEFT);
    }

    /**
     * The check details posted with a form: chk_date, chk_no, chk_bank (POS: the same names). Fails when one is missing.
     * Returns [check_date, check_no, bank].
     */
    public static function fromPost(string $prefix = 'chk_'): array
    {
        $date = pdate($prefix . 'date');
        $no = mb_substr(trim((string)p($prefix . 'no')), 0, 40);
        $bank = mb_substr(trim((string)p($prefix . 'bank')), 0, 80);
        if (!$date) {
            fail('Enter the check date.');
        }
        if ($no === '') {
            fail('Enter the check number.');
        }
        if ($bank === '') {
            fail('Enter the bank the check is drawn on.');
        }
        if ($date > date('Y-m-d', strtotime(today() . ' +1 year'))) {
            fail('The check date is more than a year away. Check the date.');
        }
        return [$date, $no, $bank];
    }

    public static function load(int $id): ?array
    {
        return DB::row(
            'SELECT c.*, cu.name AS customer_name, u.full_name AS received_by_name, pm.name AS method_name, t.txn_no AS payment_no, t.is_voided AS payment_void,
                    tm.name AS terminal_name, rt.txn_no AS return_no, rt.is_voided AS return_void
               FROM customer_checks c JOIN customers cu ON cu.id = c.customer_id
               LEFT JOIN users u ON u.id = c.created_by LEFT JOIN payment_methods pm ON pm.id = c.payment_method_id
               LEFT JOIN transactions t ON t.id = c.payment_txn_id LEFT JOIN pos_terminals tm ON tm.id = c.terminal_id
               LEFT JOIN transactions rt ON rt.id = c.return_txn_id
              WHERE c.id = :id',
            ['id' => $id]
        );
    }

    /** The check a payment was made with (null: none) */
    public static function forPayment(int $txnId): ?array
    {
        if (!self::ready()) {
            return null;
        }
        $id = DB::value('SELECT id FROM customer_checks WHERE payment_txn_id = :t ORDER BY id DESC LIMIT 1', ['t' => $txnId]);
        return $id ? self::load((int)$id) : null;
    }

    /** The invoices a post-dated check is to pay: [[id, amount]] */
    public static function applyList(array $c): array
    {
        $out = [];
        foreach ((array)(json_decode((string)($c['apply_json'] ?? ''), true) ?: []) as $a) {
            if (is_array($a) && (int)($a['id'] ?? 0) > 0 && (float)($a['amount'] ?? 0) > 0) {
                $out[] = ['id' => (int)$a['id'], 'amount' => r2((float)$a['amount'])];
            }
        }
        return $out;
    }

    /**
     * A post-dated check received: kept as Pending, nothing posted. $d: customer_id, bank, check_no, check_date, amount,
     * source (pos / payment), terminal_id, pos_shift_id, site_id, payment_method_id, account_id, class_id, memo,
     * apply ([[id, amount]]), received_date. Returns the check's id.
     */
    public static function receivePostDated(array $d): int
    {
        $amount = r2((float)$d['amount']);
        if ($amount <= 0) {
            fail('Enter the amount of the check.');
        }
        if (!self::postDated((string)$d['check_date'])) {
            fail('This check is not post-dated.');
        }
        $applied = r2(array_sum(array_column($d['apply'] ?? [], 'amount')));
        if ($applied > $amount + 0.004) {
            fail('The invoices chosen (' . money($applied) . ') are more than the check (' . money($amount) . ').');
        }
        self::assertUnique((int)$d['customer_id'], (string)$d['bank'], (string)$d['check_no']);
        $id = DB::insert('customer_checks', [
            'customer_id' => (int)$d['customer_id'], 'payment_txn_id' => null, 'source' => $d['source'] ?? 'payment',
            'terminal_id' => $d['terminal_id'] ?? null, 'pos_shift_id' => $d['pos_shift_id'] ?? null, 'site_id' => $d['site_id'] ?? null,
            'bank' => $d['bank'], 'check_no' => $d['check_no'], 'check_date' => $d['check_date'], 'amount' => $amount,
            'received_date' => $d['received_date'] ?? today(), 'status' => 'pending',
            'payment_method_id' => $d['payment_method_id'] ?? null, 'account_id' => $d['account_id'] ?? null, 'class_id' => $d['class_id'] ?? null,
            'memo' => isset($d['memo']) ? mb_substr((string)$d['memo'], 0, 255) : null,
            'apply_json' => json_encode(array_values($d['apply'] ?? [])),
            'created_by' => Auth::id(),
        ]);
        $c = self::load($id);
        Audit::log('pdc_receive', $d['source'] === 'pos' ? 'pos' : 'cust', 'customer_check', $id, self::ackNo($id), [
            'page_key' => $d['source'] === 'pos' ? 'pos.register' : 'cust.payments', 'amount' => $amount,
            'reason' => 'Receipt of post-dated check ' . self::describe($c) . ' from ' . $c['customer_name'] . '; the payment is recorded on ' . fdate($c['check_date']),
            'site_id' => $d['site_id'] ?? null, 'terminal_id' => $d['terminal_id'] ?? null,
        ]);
        return $id;
    }

    /** One customer, one bank, one check number: a check is not entered twice */
    private static function assertUnique(int $customerId, string $bank, string $no, int $exceptId = 0): void
    {
        $dup = DB::row(
            "SELECT c.id, c.check_date FROM customer_checks c LEFT JOIN transactions t ON t.id = c.payment_txn_id
              WHERE c.customer_id = :c AND c.bank = :b AND c.check_no = :n AND c.id <> :x AND (c.payment_txn_id IS NULL OR t.is_voided = 0)
              LIMIT 1",
            ['c' => $customerId, 'b' => $bank, 'n' => $no, 'x' => $exceptId]
        );
        if ($dup) {
            fail('Check ' . $bank . ' no. ' . $no . ' of this customer is already on the Check Registry (dated ' . fdate($dup['check_date']) . ').');
        }
    }

    /**
     * A payment made with a check dated on or before the payment: the check is kept with the payment (On Date).
     * Called after the payment is saved; an edited payment updates its check.
     */
    public static function attach(int $paymentId, array $d): int
    {
        $t = Txn::load($paymentId);
        $have = self::forPayment($paymentId);
        if ($have) {
            $same = $have['bank'] === $d['bank'] && $have['check_no'] === $d['check_no'] && $have['check_date'] === $d['check_date']
                && abs((float)$have['amount'] - (float)$t['total']) < 0.005 && (int)$have['customer_id'] === (int)$t['customer_id'];
            if (!$same && in_array($have['status'], ['cleared', 'returned'], true)) {
                fail('The check of this payment is marked ' . self::statusText($have['status']) . ' on Customer Checks, so its details and amount stay as they are. Undo that there first.');
            }
            if ($have['bank'] !== $d['bank'] || $have['check_no'] !== $d['check_no']) {
                self::assertUnique((int)$t['customer_id'], (string)$d['bank'], (string)$d['check_no'], (int)$have['id']);
            }
            DB::update('customer_checks', ['customer_id' => (int)$t['customer_id'], 'bank' => $d['bank'], 'check_no' => $d['check_no'],
                'check_date' => $d['check_date'], 'amount' => r2((float)$t['total']), 'payment_method_id' => $t['payment_method_id'],
                'account_id' => $t['account_id']], 'id = :id', ['id' => $have['id']]);
            return (int)$have['id'];
        }
        self::assertUnique((int)$t['customer_id'], (string)$d['bank'], (string)$d['check_no']);
        return DB::insert('customer_checks', [
            'customer_id' => (int)$t['customer_id'], 'payment_txn_id' => $paymentId, 'source' => $t['terminal_id'] ? 'pos' : 'payment',
            'terminal_id' => $t['terminal_id'], 'pos_shift_id' => $t['pos_shift_id'], 'site_id' => $t['site_id'],
            'bank' => $d['bank'], 'check_no' => $d['check_no'], 'check_date' => $d['check_date'], 'amount' => r2((float)$t['total']),
            'received_date' => $d['received_date'] ?? $t['txn_date'], 'status' => 'on_date', 'recorded_at' => date('Y-m-d H:i:s'),
            'payment_method_id' => $t['payment_method_id'], 'account_id' => $t['account_id'], 'class_id' => $t['class_id'] ?? null,
            'memo' => $t['memo'], 'created_by' => Auth::id(),
        ]);
    }

    /** A payment no longer paid by check (edited to another payment type): its check leaves the registry */
    public static function detach(int $paymentId): void
    {
        $c = self::forPayment($paymentId);
        if (!$c) {
            return;
        }
        if (in_array($c['status'], ['cleared', 'returned'], true)) {
            fail('The check of this payment is marked ' . self::statusText($c['status']) . ' on the Check Registry. Undo that first.');
        }
        DB::run('DELETE FROM customer_checks WHERE id = :id', ['id' => $c['id']]);
    }

    /** Edits that would undo what the Check Registry records are stopped (Txn::blockers) */
    public static function blockers(array $t): array
    {
        if (!self::ready()) {
            return [];
        }
        $out = [];
        if ($t['txn_type'] === 'payment') {
            $c = DB::row("SELECT status FROM customer_checks WHERE payment_txn_id = :t AND status = 'returned' LIMIT 1", ['t' => $t['id']]);
            if ($c) {
                $out[] = 'Its check is marked Returned on the Check Registry. Undo that there first.';
            }
        }
        if ($t['txn_type'] === 'statement_charge' && DB::value('SELECT 1 FROM customer_checks WHERE return_txn_id = :t LIMIT 1', ['t' => $t['id']])) {
            $out[] = 'It is the charge of a returned check. Undo "Returned" on the Check Registry instead.';
        }
        return $out;
    }

    // ------------------------------------------------------------------ recording post-dated checks on their date

    /**
     * Records the payments of the post-dated checks whose date has come. $auto: called on its own (index.php, the
     * registry); checks of a site this user may not record for wait for someone who may. Returns the checks recorded,
     * and (by reference) the ones that could not be, with the reason.
     */
    public static function postDue(bool $auto = true, array &$failed = []): array
    {
        if (!self::ready()) {
            return [];
        }
        $done = [];
        $rows = DB::all("SELECT * FROM customer_checks WHERE status = 'pending' AND payment_txn_id IS NULL AND check_date <= :d ORDER BY check_date, id LIMIT 100", ['d' => today()]);
        foreach ($rows as $c) {
            if ($auto && $c['site_id'] && !Access::siteAllowed((int)$c['site_id'])) {
                continue;
            }
            try {
                $done[] = ['id' => (int)$c['id'], 'txn_id' => self::record((int)$c['id'], null, $auto)];
            } catch (Throwable $e) {
                $failed[(int)$c['id']] = $e->getMessage();
                DB::update('customer_checks', ['status_note' => mb_substr('Not recorded: ' . $e->getMessage(), 0, 255)], 'id = :id', ['id' => $c['id']]);
            }
        }
        return $done;
    }

    /**
     * The payment of a post-dated check, recorded on the check's date (or $date) and applied to the invoices chosen
     * when it was received, as far as they are still open; the rest stays with the customer as a credit.
     */
    public static function record(int $id, ?string $date = null, bool $auto = false): int
    {
        return DB::tx(function () use ($id, $date, $auto) {
            $c = DB::row('SELECT * FROM customer_checks WHERE id = :id FOR UPDATE', ['id' => $id]);
            if (!$c || $c['status'] !== 'pending' || $c['payment_txn_id']) {
                fail('This check is not waiting to be recorded.');
            }
            if ($c['check_date'] > today()) {
                fail('The check is dated ' . fdate($c['check_date']) . '. Its payment is recorded on that date.');
            }
            $date = $date ?: (string)$c['check_date'];
            if ($date < $c['check_date']) {
                fail('A check is not recorded as a payment before its date (' . fdate($c['check_date']) . ').');
            }
            $customerId = (int)$c['customer_id'];
            $open = [];
            foreach (Balances::openReceivables($customerId) as $d) {
                $open[(int)$d['id']] = (float)$d['open_balance'];
            }
            $apps = [];
            $left = (float)$c['amount'];
            foreach (self::applyList($c) as $a) {
                if ($left <= 0.004 || !isset($open[$a['id']])) {
                    continue;
                }
                $use = r2(min($a['amount'], $open[$a['id']], $left));
                if ($use > 0.004) {
                    $apps[] = ['target_txn_id' => $a['id'], 'amount' => $use];
                    $left = r2($left - $use);
                }
            }
            $methodId = $c['payment_method_id'] ? (int)$c['payment_method_id']
                : ((int)DB::value("SELECT id FROM payment_methods WHERE method_type = 'check' ORDER BY is_active DESC, id LIMIT 1") ?: null);
            $h = [
                'txn_date' => $date, 'customer_id' => $customerId, 'ref_no' => $c['check_no'], 'payment_method_id' => $methodId,
                'account_id' => (int)($c['account_id'] ?: PayTypes::account($methodId)), 'account2_id' => Accts::get('ar'),
                'memo' => mb_substr('Post-dated check ' . $c['bank'] . ' no. ' . $c['check_no'] . ($c['memo'] ? ' / ' . $c['memo'] : ''), 0, 255),
                'total' => r2((float)$c['amount']), 'discount_amount' => 0, 'withholding_amount' => 0,
                // set here, so the class of whatever form is being posted when this runs is not taken
                'class_id' => $c['class_id'] ? (int)$c['class_id'] : null,
            ];
            if ($c['source'] === 'pos' && $c['terminal_id']) {
                // a counter payment, but not of a shift: the cash of the shift it was received in does not change
                $h['terminal_id'] = (int)$c['terminal_id'];
                $h['site_id'] = $c['site_id'] ? (int)$c['site_id'] : null;
            }
            $txnId = Txn::save('payment', $h, [], null, ['keep_totals' => true, 'applications' => $apps, 'audit_action' => 'pdc_record',
                'reason' => 'Post-dated check ' . self::ackNo($id) . ' reached its date' . ($auto ? ' (recorded automatically)' : '')]);
            // the payment is the cashier's who took the check
            if ($c['created_by']) {
                DB::update('transactions', ['created_by' => (int)$c['created_by']], 'id = :id', ['id' => $txnId]);
            }
            DB::update('customer_checks', ['payment_txn_id' => $txnId, 'status' => 'on_date', 'recorded_at' => date('Y-m-d H:i:s'), 'status_note' => null,
                'account_id' => $h['account_id'], 'payment_method_id' => $methodId], 'id = :id', ['id' => $id]);
            return $txnId;
        });
    }

    /** A post-dated check not recorded yet can be taken off the registry (given back, replaced, entered by mistake) */
    public static function remove(int $id, string $reason): void
    {
        $c = self::load($id);
        if (!$c || $c['status'] !== 'pending' || $c['payment_txn_id']) {
            fail('Only a post-dated check whose payment is not recorded yet can be removed.');
        }
        if (trim($reason) === '') {
            fail('Enter the reason for removing the check.');
        }
        DB::run('DELETE FROM customer_checks WHERE id = :id', ['id' => $id]);
        Audit::log('pdc_remove', 'cust', 'customer_check', $id, self::ackNo($id), ['page_key' => 'cust.checks', 'amount' => $c['amount'],
            'reason' => $reason . ' / ' . self::describe($c) . ', ' . $c['customer_name'], 'snapshot' => $c]);
    }

    // ------------------------------------------------------------------ deposited: cleared or returned

    /** The deposit the check's payment went to the bank on: [id, txn_no, txn_date, account_id] or null */
    public static function deposit(?int $paymentId): ?array
    {
        if (!$paymentId) {
            return null;
        }
        return DB::row(
            "SELECT d.id, d.txn_type, d.txn_no, d.txn_date, d.account_id FROM transaction_lines l JOIN transactions d ON d.id = l.txn_id
              WHERE l.ref_txn_id = :p AND d.txn_type = 'deposit' AND d.is_voided = 0 ORDER BY d.id DESC LIMIT 1",
            ['p' => $paymentId]
        );
    }

    /** Where the check's money is now: the bank account it was deposited to, or the account the payment went to */
    public static function moneyAccount(array $c): int
    {
        $dep = self::deposit($c['payment_txn_id'] ? (int)$c['payment_txn_id'] : null);
        if ($dep) {
            return (int)$dep['account_id'];
        }
        $t = $c['payment_txn_id'] ? Txn::load((int)$c['payment_txn_id']) : null;
        return (int)($t['account_id'] ?? 0) ?: Accts::get('undeposited_funds');
    }

    private static function recorded(int $id): array
    {
        $c = self::load($id);
        if (!$c) {
            fail('Check not found.');
        }
        if (!$c['payment_txn_id'] || (int)$c['payment_void'] === 1) {
            fail('The payment of this check is not recorded' . ($c['payment_txn_id'] ? ' (it was voided)' : ' yet') . '.');
        }
        return $c;
    }

    /** Deposited and honored */
    public static function markCleared(int $id, string $date, string $note = ''): void
    {
        $c = self::recorded($id);
        if ($c['status'] !== 'on_date') {
            fail('Only a check that is On Date can be marked Cleared.');
        }
        if ($date < $c['check_date']) {
            fail('A check cannot clear before its date (' . fdate($c['check_date']) . ').');
        }
        DB::update('customer_checks', ['status' => 'cleared', 'cleared_date' => $date, 'status_note' => $note !== '' ? mb_substr($note, 0, 255) : null,
            'status_by' => Auth::id()], 'id = :id', ['id' => $id]);
        Audit::log('check_cleared', 'cust', 'customer_check', $id, self::describe($c), ['page_key' => 'cust.checks', 'amount' => $c['amount'],
            'reason' => 'Cleared ' . fdate($date) . ($note !== '' ? ': ' . $note : '') . ' / ' . $c['customer_name']]);
    }

    /**
     * Deposited and dishonored: the amount goes back on the customer's account with a statement charge, credited to the
     * bank account the check was deposited to. Returns the charge's id.
     */
    public static function markReturned(int $id, string $date, string $note = ''): int
    {
        return DB::tx(function () use ($id, $date, $note) {
            $c = self::recorded($id);
            if (!in_array($c['status'], ['on_date', 'cleared'], true)) {
                fail('Only a check that is On Date or Cleared can be marked Returned.');
            }
            if ($date < $c['check_date']) {
                fail('A check cannot be returned before its date (' . fdate($c['check_date']) . ').');
            }
            $text = 'Returned check ' . $c['bank'] . ' no. ' . $c['check_no'] . ' dated ' . fdate($c['check_date']) . ($note !== '' ? ': ' . $note : '');
            $amount = r2((float)$c['amount']);
            $cust = DB::row('SELECT * FROM customers WHERE id = :id', ['id' => $c['customer_id']]);
            $chargeId = Txn::save('statement_charge', [
                'txn_date' => $date, 'due_date' => $date, 'customer_id' => (int)$c['customer_id'], 'account_id' => Accts::get('ar'),
                'ref_no' => $c['check_no'], 'memo' => mb_substr($text, 0, 255), 'class_id' => $c['class_id'] ? (int)$c['class_id'] : null,
                'billing_address' => $cust['billing_address'] ?? null,
            ], [[
                'line_kind' => 'item', 'item_id' => null, 'account_id' => self::moneyAccount($c), 'description' => mb_substr($text, 0, 255),
                'qty' => 1, 'rate' => $amount, 'amount' => $amount, 'tax_amount' => 0, 'customer_id' => (int)$c['customer_id'],
            ]], null, ['audit_action' => 'check_returned', 'reason' => $text]);
            DB::update('customer_checks', ['status' => 'returned', 'returned_date' => $date, 'return_txn_id' => $chargeId,
                'status_note' => $note !== '' ? mb_substr($note, 0, 255) : null, 'status_by' => Auth::id()], 'id = :id', ['id' => $id]);
            Audit::log('check_returned', 'cust', 'customer_check', $id, self::describe($c), ['page_key' => 'cust.checks', 'amount' => $amount,
                'reason' => $text . ' / ' . $c['customer_name']]);
            return $chargeId;
        });
    }

    /** Cleared or Returned taken back: On Date again (a returned check's charge is voided) */
    public static function undo(int $id, string $reason): void
    {
        DB::tx(function () use ($id, $reason) {
            $c = self::load($id);
            if (!$c || !in_array($c['status'], ['cleared', 'returned'], true)) {
                fail('Only a Cleared or Returned check can be set back to On Date.');
            }
            if (trim($reason) === '') {
                fail('Enter the reason.');
            }
            if ($c['status'] === 'returned' && $c['return_txn_id'] && (int)$c['return_void'] !== 1) {
                // the charge may be voided now that the check no longer blocks it
                DB::update('customer_checks', ['return_txn_id' => null], 'id = :id', ['id' => $id]);
                Txn::void((int)$c['return_txn_id'], 'Returned check set back to On Date: ' . $reason);
            }
            DB::update('customer_checks', ['status' => 'on_date', 'cleared_date' => null, 'returned_date' => null, 'return_txn_id' => null,
                'status_note' => null, 'status_by' => Auth::id()], 'id = :id', ['id' => $id]);
            Audit::log('check_undo', 'cust', 'customer_check', $id, self::describe($c), ['page_key' => 'cust.checks', 'amount' => $c['amount'],
                'reason' => self::statusText($c['status']) . ' undone: ' . $reason]);
        });
    }

    // ------------------------------------------------------------------ lists

    /**
     * The Check Registry: f = from, to (by check date, or received date with by=received), customer_id, status
     * (pending, on_date, cleared, returned), q (bank or check number), source (pos / payment).
     */
    public static function registry(array $f): array
    {
        if (!self::ready()) {
            return [];
        }
        $by = ($f['by'] ?? '') === 'received' ? 'c.received_date' : 'c.check_date';
        $w = ['(c.payment_txn_id IS NULL OR t.is_voided = 0)'];
        $p = [];
        if (!empty($f['from'])) {
            $w[] = "$by >= :f";
            $p['f'] = $f['from'];
        }
        if (!empty($f['to'])) {
            $w[] = "$by <= :t";
            $p['t'] = $f['to'];
        }
        if (!empty($f['customer_id'])) {
            $w[] = '(c.customer_id = :c OR cu.parent_id = :c2)';
            $p['c'] = (int)$f['customer_id'];
            $p['c2'] = (int)$f['customer_id'];
        }
        if (!empty($f['source']) && in_array($f['source'], ['pos', 'payment'], true)) {
            $w[] = 'c.source = :src';
            $p['src'] = $f['source'];
        }
        if (!empty($f['user_id'])) {
            $w[] = 'c.created_by = :u';
            $p['u'] = (int)$f['user_id'];
        }
        $q = trim((string)($f['q'] ?? ''));
        if ($q !== '') {
            $w[] = '(c.bank LIKE :q OR c.check_no LIKE :q2 OR cu.name LIKE :q3)';
            $p['q'] = $p['q2'] = $p['q3'] = '%' . $q . '%';
        }
        $st = (string)($f['status'] ?? '');
        if ($st === 'pending') {
            $w[] = "c.status = 'pending' AND c.check_date > :td";
            $p['td'] = today();
        } elseif ($st === 'on_date') {
            $w[] = "(c.status = 'on_date' OR (c.status = 'pending' AND c.check_date <= :td))";
            $p['td'] = today();
        } elseif (in_array($st, ['cleared', 'returned'], true)) {
            $w[] = 'c.status = :st';
            $p['st'] = $st;
        }
        $siteIds = Access::siteIds();
        if ($siteIds !== null) {
            [$sin, $sp] = DB::in('cks', $siteIds ?: [0]);
            $w[] = "(c.site_id IS NULL OR c.site_id IN $sin)";
            $p += $sp;
        }
        $rows = DB::all(
            "SELECT c.*, cu.name AS customer_name, u.full_name AS received_by_name, t.txn_no AS payment_no, t.txn_type AS payment_type,
                    rt.txn_no AS return_no, tm.name AS terminal_name
               FROM customer_checks c JOIN customers cu ON cu.id = c.customer_id
               LEFT JOIN transactions t ON t.id = c.payment_txn_id LEFT JOIN transactions rt ON rt.id = c.return_txn_id
               LEFT JOIN users u ON u.id = c.created_by LEFT JOIN pos_terminals tm ON tm.id = c.terminal_id
              WHERE " . implode(' AND ', $w) . "
              ORDER BY c.check_date, cu.name, c.id",
            $p
        );
        foreach ($rows as &$r) {
            $r['shown'] = self::status($r);
        }
        return $rows;
    }

    /**
     * What the customer's post-dated checks not recorded yet are meant to pay: [invoice id => [amount, text]]
     * (shown beside the outstanding invoices, so an invoice is not paid twice by mistake)
     */
    public static function pendingFor(int $customerId): array
    {
        if (!self::ready()) {
            return [];
        }
        $out = [];
        foreach (DB::all("SELECT * FROM customer_checks WHERE customer_id = :c AND status = 'pending' AND payment_txn_id IS NULL ORDER BY check_date", ['c' => $customerId]) as $c) {
            foreach (self::applyList($c) as $a) {
                $out[$a['id']][0] = r2(($out[$a['id']][0] ?? 0) + $a['amount']);
                $out[$a['id']][1] = trim(($out[$a['id']][1] ?? '') . ' ' . 'Post-dated check ' . $c['bank'] . ' no. ' . $c['check_no'] . ' (' . fdate($c['check_date']) . ', ' . money($a['amount']) . ')');
            }
        }
        return $out;
    }

    /** The post-dated checks received in a POS shift (the cashier's Receipt of Post Dated Check) */
    public static function pdcForShift(int $shiftId): array
    {
        if (!self::ready()) {
            return [];
        }
        return DB::all(
            'SELECT c.*, cu.name AS customer_name FROM customer_checks c JOIN customers cu ON cu.id = c.customer_id
              WHERE c.pos_shift_id = :s AND c.check_date > c.received_date ORDER BY c.id',
            ['s' => $shiftId]
        );
    }

    /**
     * The post-dated checks received in a period, by who received them (POS and Receive Payments): the cashier's /
     * user's Receipt of Post Dated Check. f: from, to, user_id, terminal_id, site_id.
     */
    public static function pdcReceived(array $f): array
    {
        if (!self::ready()) {
            return [];
        }
        $w = ['c.check_date > c.received_date', 'c.received_date BETWEEN :f AND :t'];
        $p = ['f' => $f['from'], 't' => $f['to']];
        if (!empty($f['user_id'])) {
            $w[] = 'c.created_by = :u';
            $p['u'] = (int)$f['user_id'];
        }
        if (!empty($f['terminal_id'])) {
            $w[] = 'c.terminal_id = :tm';
            $p['tm'] = (int)$f['terminal_id'];
        }
        if (!empty($f['site_id'])) {
            $w[] = 'c.site_id = :s';
            $p['s'] = (int)$f['site_id'];
        }
        return DB::all(
            'SELECT c.*, cu.name AS customer_name, u.full_name AS received_by_name FROM customer_checks c JOIN customers cu ON cu.id = c.customer_id
               LEFT JOIN users u ON u.id = c.created_by
              LEFT JOIN transactions t ON t.id = c.payment_txn_id
              WHERE ' . implode(' AND ', $w) . ' AND (c.payment_txn_id IS NULL OR t.is_voided = 0)
              ORDER BY c.received_date, c.id',
            $p
        );
    }
}
