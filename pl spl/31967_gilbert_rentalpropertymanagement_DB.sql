-- ============================================================
-- Project: 31967_Gilbert_RentalPropertyManagement_DB
-- Student: Gilbert (ID: 31967/2025)
-- Phase VI: PL/SQL Programming (Procedures, Functions, Package, Cursor)
-- ============================================================

-- ------------------------------------------------------------
-- PACKAGE SPECIFICATION
-- ------------------------------------------------------------
CREATE OR REPLACE PACKAGE rental_pkg AS

    -- Custom exceptions
    e_unit_not_vacant   EXCEPTION;
    e_lease_not_active  EXCEPTION;

    -- Procedure: create a new lease for a vacant unit
    PROCEDURE register_lease (
        p_unit_id       IN NUMBER,
        p_tenant_id     IN NUMBER,
        p_start_date    IN DATE,
        p_end_date      IN DATE,
        p_monthly_rent  IN NUMBER,
        p_deposit       IN NUMBER
    );

    -- Procedure: record a rent payment against an active lease
    PROCEDURE record_payment (
        p_lease_id      IN NUMBER,
        p_amount        IN NUMBER,
        p_method        IN VARCHAR2,
        p_recorded_by   IN VARCHAR2
    );

    -- Function: total amount paid so far for a given lease
    FUNCTION get_total_paid (
        p_lease_id      IN NUMBER
    ) RETURN NUMBER;

    -- Function: count how many months a lease has been running
    FUNCTION get_months_elapsed (
        p_lease_id      IN NUMBER
    ) RETURN NUMBER;

    -- Procedure: print a report of leases with overdue balances (uses a cursor)
    PROCEDURE report_overdue_leases;

END rental_pkg;
/

-- ------------------------------------------------------------
-- PACKAGE BODY
-- ------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY rental_pkg AS

    -- ----------------------------------------------------
    -- Register a new lease
    -- ----------------------------------------------------
    PROCEDURE register_lease (
        p_unit_id       IN NUMBER,
        p_tenant_id     IN NUMBER,
        p_start_date    IN DATE,
        p_end_date      IN DATE,
        p_monthly_rent  IN NUMBER,
        p_deposit       IN NUMBER
    ) IS
        v_status unit.status%TYPE;
    BEGIN
        -- Check the unit is vacant before leasing it out
        SELECT status INTO v_status
        FROM unit
        WHERE unit_id = p_unit_id;

        IF v_status != 'Vacant' THEN
            RAISE e_unit_not_vacant;
        END IF;

        INSERT INTO lease_agreement (
            unit_id, tenant_id, start_date, end_date, monthly_rent, deposit_amount, status
        ) VALUES (
            p_unit_id, p_tenant_id, p_start_date, p_end_date, p_monthly_rent, p_deposit, 'Active'
        );

        UPDATE unit
        SET status = 'Occupied'
        WHERE unit_id = p_unit_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Lease registered successfully for unit ' || p_unit_id);

    EXCEPTION
        WHEN e_unit_not_vacant THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: Unit ' || p_unit_id || ' is not vacant. Current status: ' || v_status);
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: Unit ' || p_unit_id || ' does not exist.');
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
    END register_lease;

    -- ----------------------------------------------------
    -- Record a payment
    -- ----------------------------------------------------
    PROCEDURE record_payment (
        p_lease_id      IN NUMBER,
        p_amount        IN NUMBER,
        p_method        IN VARCHAR2,
        p_recorded_by   IN VARCHAR2
    ) IS
        v_status lease_agreement.status%TYPE;
    BEGIN
        SELECT status INTO v_status
        FROM lease_agreement
        WHERE lease_id = p_lease_id;

        IF v_status != 'Active' THEN
            RAISE e_lease_not_active;
        END IF;

        INSERT INTO payment (lease_id, payment_date, amount, payment_method, recorded_by)
        VALUES (p_lease_id, SYSDATE, p_amount, p_method, p_recorded_by);

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Payment of ' || p_amount || ' recorded for lease ' || p_lease_id);

    EXCEPTION
        WHEN e_lease_not_active THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: Lease ' || p_lease_id || ' is not active. Current status: ' || v_status);
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: Lease ' || p_lease_id || ' does not exist.');
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Unexpected error: ' || SQLERRM);
    END record_payment;

    -- ----------------------------------------------------
    -- Total paid so far for a lease
    -- ----------------------------------------------------
    FUNCTION get_total_paid (
        p_lease_id IN NUMBER
    ) RETURN NUMBER IS
        v_total NUMBER := 0;
    BEGIN
        SELECT NVL(SUM(amount), 0) INTO v_total
        FROM payment
        WHERE lease_id = p_lease_id;

        RETURN v_total;
    END get_total_paid;

    -- ----------------------------------------------------
    -- Months elapsed since lease start
    -- ----------------------------------------------------
    FUNCTION get_months_elapsed (
        p_lease_id IN NUMBER
    ) RETURN NUMBER IS
        v_start DATE;
        v_months NUMBER;
    BEGIN
        SELECT start_date INTO v_start
        FROM lease_agreement
        WHERE lease_id = p_lease_id;

        v_months := TRUNC(MONTHS_BETWEEN(SYSDATE, v_start));
        IF v_months < 1 THEN
            v_months := 1;
        END IF;

        RETURN v_months;
    END get_months_elapsed;

    -- ----------------------------------------------------
    -- Report overdue leases (cursor-based)
    -- Compares expected rent (rent * months elapsed) vs total paid
    -- ----------------------------------------------------
    PROCEDURE report_overdue_leases IS
        CURSOR c_active_leases IS
            SELECT lease_id, tenant_id, monthly_rent
            FROM lease_agreement
            WHERE status = 'Active';

        v_expected   NUMBER;
        v_paid       NUMBER;
        v_balance    NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- Overdue Lease Report ---');

        FOR rec IN c_active_leases LOOP
            v_expected := rec.monthly_rent * get_months_elapsed(rec.lease_id);
            v_paid     := get_total_paid(rec.lease_id);
            v_balance  := v_expected - v_paid;

            IF v_balance > 0 THEN
                DBMS_OUTPUT.PUT_LINE(
                    'Lease ' || rec.lease_id ||
                    ' (Tenant ' || rec.tenant_id || ') is overdue by ' || v_balance
                );
            END IF;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('--- End of Report ---');
    END report_overdue_leases;

END rental_pkg;
/

-- ============================================================
-- TEST CALLS (run these to demonstrate the package works)
-- ============================================================
SET SERVEROUTPUT ON;

-- Try registering a lease on an already-occupied unit (should fail gracefully)
BEGIN
    rental_pkg.register_lease(1, 2, SYSDATE, ADD_MONTHS(SYSDATE, 12), 250000, 500000);
END;
/

-- Record a payment
BEGIN
    rental_pkg.record_payment(1, 250000, 'Cash', 'gilbert_admin');
END;
/

-- Run the overdue report
BEGIN
    rental_pkg.report_overdue_leases;
END;
/