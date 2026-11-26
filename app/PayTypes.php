<?php
declare(strict_types=1);

/**
 * v9: the payment types (payment_methods) and the General Ledger account each one is linked to.
 *
 * The account chosen for a payment type on Point of Sale > Payment Types & G.L. Accounts (kept in
 * payment_methods.clearing_account_id) is the account debited every time money comes in that way:
 * POS sales, POS returns (credited), customers paying an account balance at the counter, Receive Payments
 * and Enter Sales Receipts. A type with no account uses the module default:
 *   cash          the cash drawer account of the POS terminal at the counter (Deposit to on the other forms)
 *   card          Card Clearing
 *   ewallet       E-wallet Clearing
 *   anything else Undeposited Funds (a check, a bank transfer, a bank not linked yet)
 * At the POS, cash always goes to the terminal's cash drawer account, so the shift's cash count stays right.
 */
final class PayTypes
{
    public const TYPES = ['cash' => 'Cash', 'check' => 'Check', 'bank_transfer' => 'Bank', 'card' => 'Card', 'ewallet' => 'E-wallet',
        'voucher' => 'Gift voucher', 'other' => 'Other'];

    private static ?array $rows = null;

    public static function reset(): void
    {
        self::$rows = null;
    }

    /** Every payment type: [id => row] */
    public static function all(): array
    {
        if (self::$rows === null) {
            self::$rows = [];
            foreach (DB::all('SELECT * FROM payment_methods ORDER BY id') as $r) {
                self::$rows[(int)$r['id']] = $r;
            }
        }
        return self::$rows;
    }

    public static function get(?int $id): ?array
    {
        return $id ? (self::all()[$id] ?? null) : null;
    }

    public static function typeText(string $t): string
    {
        return self::TYPES[$t] ?? ucfirst(str_replace('_', ' ', $t));
    }

    public static function isCheck(?int $id): bool
    {
        $m = self::get($id);
        return $m !== null && $m['method_type'] === 'check';
    }

    /** The G.L. account linked to the payment type (null: none chosen) */
    public static function linked(?int $id): ?int
    {
        $m = self::get($id);
        return $m && $m['clearing_account_id'] ? (int)$m['clearing_account_id'] : null;
    }

    /** The default account a payment type without a link uses (cash: null, the form or the terminal decides) */
    public static function fallback(string $type): ?int
    {
        if ($type === 'cash') {
            return null;
        }
        $key = $type === 'card' ? 'card_clearing' : ($type === 'ewallet' ? 'ewallet_clearing' : 'undeposited_funds');
        return Accts::get($key);
    }

    /** The default account's name, for the page that links the accounts */
    public static function fallbackText(string $type): string
    {
        if ($type === 'cash') {
            return 'The cash drawer of the POS terminal; Deposit to on other forms';
        }
        try {
            $id = self::fallback($type);
        } catch (Throwable $e) {
            return 'Module default account not set';
        }
        $a = $id ? DB::row('SELECT code, name FROM accounts WHERE id = :id', ['id' => $id]) : null;
        return $a ? $a['code'] . ' - ' . $a['name'] : '';
    }

    /**
     * The account money received with this payment type is debited to.
     * $cashAccount: the account cash goes to on that form (the terminal's drawer, or the form's Deposit to).
     * At the POS ($pos), cash always goes to the drawer.
     */
    public static function account(?int $id, ?int $cashAccount = null, bool $pos = false): int
    {
        $m = self::get($id);
        $type = $m['method_type'] ?? 'other';
        if ($type === 'cash' && ($pos || !$m['clearing_account_id'])) {
            return (int)($cashAccount ?: Accts::get('undeposited_funds'));
        }
        return (int)(($m['clearing_account_id'] ?? null) ?: self::fallback($type));
    }

    /**
     * For the forms' scripts: [id => [type, account id linked (0: none), its label]], so choosing a payment type
     * fills in (and locks) the Deposit to account.
     */
    public static function forJs(): array
    {
        $names = DB::pairs("SELECT id, CONCAT(code, ' - ', name) FROM accounts");
        $out = [];
        foreach (self::all() as $id => $m) {
            $gl = (int)($m['clearing_account_id'] ?? 0);
            $out[$id] = ['type' => $m['method_type'], 'gl' => $gl, 'gl_name' => $gl ? (string)($names[$gl] ?? '') : '', 'name' => $m['name']];
        }
        return $out;
    }

    /**
     * The Deposit to account of Receive Payments and Enter Sales Receipts: the payment type's linked account when it has
     * one (it is used every time), else what the form says, else Undeposited Funds.
     */
    public static function depositAccount(?int $id, ?int $chosen): int
    {
        return self::linked($id) ?? ($chosen ?: Accts::get('undeposited_funds'));
    }

    /** The banks a customer's check is commonly drawn on, plus the ones already typed, for the Bank box */
    public static function bankNames(): array
    {
        $list = ['BDO', 'BPI', 'Metrobank', 'Land Bank', 'PNB', 'Security Bank', 'China Bank', 'RCBC', 'UnionBank', 'EastWest', 'BOC',
            'PSBank', 'AUB', 'Gotymebank', 'DBP', 'Maybank', 'Robinsons Bank', 'Sterling Bank', 'PBCOM', 'CTBC'];
        try {
            foreach (DB::column('SELECT DISTINCT bank FROM customer_checks ORDER BY bank LIMIT 200') as $b) {
                if ($b !== '' && !in_array($b, $list, true)) {
                    $list[] = $b;
                }
            }
        } catch (Throwable $e) {
            // the table comes with the 2027_05_03 migration
        }
        return $list;
    }
}
