# Queries Explanation

**Project:** Rental Property Management System
**Database:** 31967_Gilbert_RentalPropertyManagement_DB
**Student:** Gilbert (ID: 31967/2025)

This document explains, in plain language, what every SQL script, PL/SQL object, and trigger in this project does and why it exists.

---

## 1. Table Creation Queries (Phase V)

All 9 tables are created with `CREATE TABLE` statements in `sql/Phase5_Tables.sql`, in dependency order (a table can only reference another table that already exists).

**Why the constraints matter:**
- `PRIMARY KEY` — guarantees every row has a unique identifier (e.g. `unit_id`)
- `FOREIGN KEY` — enforces that a value like `unit.property_id` must match a real row in `PROPERTY`; this is what keeps the data connected and prevents "orphan" records
- `CHECK` — restricts a column to a fixed set of valid values (e.g. `unit.status` can only be `'Vacant'`, `'Occupied'`, or `'Maintenance'`) so bad data can never be entered
- `NOT NULL` / `UNIQUE` — enforce required fields and prevent duplicates (e.g. two tenants can't share a `national_id`)

Sample data is inserted after the tables exist, giving realistic Kigali-context rows to query and demo against immediately.

---

## 2. PL/SQL Package: `RENTAL_PKG` (Phase VI)

Found in `plsql/Phase6_PLSQL.sql`. This package groups related procedures and functions together, which is cleaner and more maintainable than separate standalone objects.

### `register_lease` (procedure)
**What it does:** Creates a new lease agreement for a tenant on a specific unit.
**Why it's not just an INSERT statement:** Before inserting, it checks the unit's current status. If the unit isn't `'Vacant'`, it raises a custom exception (`e_unit_not_vacant`) instead of letting bad data in. After a successful insert, it also updates the unit's status to `'Occupied'` — two related changes handled safely together, with a `COMMIT` only if both succeed, or a `ROLLBACK` if anything fails.

### `record_payment` (procedure)
**What it does:** Logs a rent payment against a lease.
**Why it checks first:** It confirms the lease is `'Active'` before recording a payment — you shouldn't be able to record rent against a lease that's already terminated. Same pattern: custom exception (`e_lease_not_active`) if the check fails.

### `get_total_paid` (function)
**What it does:** Adds up every payment ever made against a given lease and returns the total. Used internally by the overdue report, but can also be called directly, e.g.:
```sql
SELECT rental_pkg.get_total_paid(1) FROM DUAL;
```

### `get_months_elapsed` (function)
**What it does:** Calculates how many months have passed since a lease's `start_date`, using Oracle's built-in `MONTHS_BETWEEN`. This is the basis for figuring out how much rent *should* have been paid by now.

### `report_overdue_leases` (procedure, uses a cursor)
**What it does:** Loops through every active lease using an explicit cursor (`c_active_leases`), and for each one, calculates expected rent (`monthly_rent × months elapsed`) versus what's actually been paid (via `get_total_paid`). Any lease with a positive balance gets printed as overdue.
**Why a cursor is needed here:** A single SQL query can't easily loop through rows one at a time and run a calculation function against each — a cursor is exactly the tool for "go through these rows one by one and do something with each."

---

## 3. Triggers (Phase VII)

Found in `plsql/Phase7_Triggers.sql`.

### `trg_restrict_payment_dml` (simple trigger — business rule)
**What it does:** Fires automatically before any INSERT, UPDATE, or DELETE on the `PAYMENT` table. It checks today's day name and whether today is listed in `PUBLIC_HOLIDAY`. If today is a weekday (Mon–Fri) or a holiday, it blocks the operation with a custom error (`ORA-20001` or `ORA-20002`).
**Why this is a trigger and not application logic:** A trigger enforces the rule at the database level — no matter what application, script, or user tries to bypass it, the database itself refuses the operation. This is the "security control" the assignment specifically asks for.

### `trg_audit_unit` (simple trigger — auditing)
**What it does:** Fires after any INSERT, UPDATE, or DELETE on `UNIT`. It writes a new row into `AUDIT_LOG` capturing: which table changed, what operation happened, who did it (`USER`, Oracle's built-in current-session username), when (`SYSTIMESTAMP`), and the before/after values.
**Why this matters:** This is what makes every change traceable — if a unit's rent or status changes, there's a permanent record of exactly who changed it and what it was before.

### `trg_audit_lease_compound` (compound trigger — auditing)
**What it does:** Same auditing purpose as above, but for `LEASE_AGREEMENT`, built as a **compound trigger** — a single trigger object with multiple timing sections (`BEFORE STATEMENT`, `AFTER EACH ROW`, `AFTER STATEMENT`).
**Why compound instead of simple:** Instead of writing to `AUDIT_LOG` one row at a time as each row changes, it collects all the changes in memory during the statement and writes them all at once at the end. This is more efficient for statements that affect many rows at once (e.g. a bulk update), and demonstrates the compound trigger structure specifically required by the assignment.

---

## 4. How to See It All Working

Run this after the trigger script to see the audit trail in action:
```sql
SELECT * FROM audit_log ORDER BY action_timestamp DESC;
```

Run this to see the overdue-lease report:
```sql
BEGIN
    rental_pkg.report_overdue_leases;
END;
/
```

Try inserting a payment on a weekday to see the business rule block it in real time — this is a good live-demo moment since it shows the trigger enforcing the rule without any extra code needed at the point of insert.
