<?php
declare(strict_types=1);

/**
 * Distribution (v2): the sales representatives list also holds the van salesmen and the cashiers, the people who
 * answer for the stock of a van or an outlet.
 *
 * Every one of them is also a customer ("the employee as a customer", customer type Employee): a shortage found when a
 * van's stock is closed (Inventory Transfer Closing), or an adjustment of stock short that is put on a cashier or a
 * sales representative, is charged to that customer as a receivable at cost. It is collected with Receive Payments,
 * where the name shows with what the person is (sales representative, van salesman, cashier).
 */
final class SalesReps
{
    public const TYPES = ['sales_rep' => 'Sales representative', 'van' => 'Van salesman', 'cashier' => 'Cashier'];

    private static array $ready = [];
    private static ?array $byCustomer = null;

    public static function ready(): bool
    {
        $db = DB::databaseName();
        if (!isset(self::$ready[$db])) {
            try {
                DB::value('SELECT COUNT(rep_type) + COUNT(customer_id) FROM sales_reps WHERE 1 = 0');
                self::$ready[$db] = true;
            } catch (Throwable $e) {
                self::$ready[$db] = false;
            }
        }
        return self::$ready[$db];
    }

    public static function typeText(?string $type): string
    {
        return self::TYPES[(string)$type] ?? self::TYPES['sales_rep'];
    }

    /** Active people: id => "Name (Van salesman)", for the "Charged to" and "Sales rep / cashier" boxes */
    public static function pickers(): array
    {
        if (!self::ready()) {
            return DB::pairs('SELECT id, name FROM sales_reps WHERE is_active = 1 ORDER BY name');
        }
        $out = [];
        foreach (DB::all('SELECT id, name, rep_type FROM sales_reps WHERE is_active = 1 ORDER BY name') as $r) {
            $out[(int)$r['id']] = $r['name'] . ' (' . self::typeText($r['rep_type']) . ')';
        }
        return $out;
    }

    public static function row(?int $id): ?array
    {
        return $id ? DB::row('SELECT * FROM sales_reps WHERE id = :id', ['id' => $id]) : null;
    }

    /** The customer type "Employee" (made the first time it is needed) */
    public static function employeeType(): int
    {
        $id = DB::value("SELECT id FROM customer_types WHERE name = 'Employee' LIMIT 1");
        return $id ? (int)$id : DB::insert('customer_types', ['name' => 'Employee']);
    }

    /**
     * The employee as a customer: the customer linked to the person, made (or linked, when a customer of that name of
     * type Employee is not linked to anyone yet) the first time it is needed. Returns the customer id.
     */
    public static function ensureCustomer(int $repId): ?int
    {
        if (!self::ready()) {
            return null;
        }
        $r = self::row($repId);
        if (!$r) {
            return null;
        }
        if ($r['customer_id'] && DB::value('SELECT id FROM customers WHERE id = :c', ['c' => $r['customer_id']])) {
            return (int)$r['customer_id'];
        }
        $type = self::employeeType();
        $name = trim((string)$r['name']);
        $same = DB::row('SELECT c.id, c.customer_type_id FROM customers c
                          WHERE c.name = :n AND c.parent_id IS NULL AND NOT EXISTS (SELECT 1 FROM sales_reps s WHERE s.customer_id = c.id) LIMIT 1', ['n' => $name]);
        if ($same && (int)$same['customer_type_id'] === $type) {
            $cid = (int)$same['id'];
        } else {
            $cname = $same || DB::value('SELECT 1 FROM customers WHERE name = :n', ['n' => $name]) ? $name . ' (employee)' : $name;
            if (DB::value('SELECT 1 FROM customers WHERE name = :n', ['n' => $cname])) {
                $cname = $name . ' (employee ' . (int)$r['id'] . ')';
            }
            $terms = DB::value("SELECT id FROM terms WHERE net_days = 0 AND is_active = 1 ORDER BY id LIMIT 1");
            $cid = DB::insert('customers', [
                'name' => mb_substr($cname, 0, 120), 'customer_type_id' => $type, 'sales_rep_id' => (int)$r['id'], 'terms_id' => $terms ?: null,
                'notes' => self::typeText($r['rep_type']) . ' of the company. Shortages charged to them are collected with Receive Payments.',
                'is_active' => 1,
            ]);
            Audit::log('create', 'cust', 'customer', $cid, $cname, ['page_key' => 'coa.lists',
                'reason' => 'The employee as a customer, for the shortages charged to ' . $name . ' (' . self::typeText($r['rep_type']) . ')']);
        }
        DB::update('sales_reps', ['customer_id' => $cid], 'id = :id', ['id' => (int)$r['id']]);
        self::$byCustomer = null;
        return $cid;
    }

    /** Every active person gets their customer (the shortage pages and Receive Payments list them all) */
    public static function ensureAll(): void
    {
        if (!self::ready()) {
            return;
        }
        foreach (DB::column('SELECT id FROM sales_reps WHERE is_active = 1 AND (customer_id IS NULL OR customer_id NOT IN (SELECT id FROM customers))') as $id) {
            self::ensureCustomer((int)$id);
        }
    }

    /** customer id => ['id', 'name', 'rep_type'] of the person it belongs to */
    public static function byCustomer(): array
    {
        if (self::$byCustomer !== null) {
            return self::$byCustomer;
        }
        self::$byCustomer = [];
        if (self::ready()) {
            foreach (DB::all('SELECT id, name, rep_type, customer_id FROM sales_reps WHERE customer_id IS NOT NULL') as $r) {
                self::$byCustomer[(int)$r['customer_id']] = $r;
            }
        }
        return self::$byCustomer;
    }

    /**
     * The customer list of a box where employees are told apart: "Maria Santos (Sales representative)". The person's
     * customer keeps its place in the alphabetical list.
     */
    public static function labelCustomers(array $customers): array
    {
        $map = self::byCustomer();
        foreach ($customers as $id => $label) {
            if (isset($map[(int)$id]) && !str_contains((string)$label, '(' . self::typeText($map[(int)$id]['rep_type']) . ')')) {
                $customers[$id] = $label . ' (' . self::typeText($map[(int)$id]['rep_type']) . ')';
            }
        }
        return $customers;
    }
}
