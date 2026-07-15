# Phase II: Business Process Modeling

**Project:** Rental Property Management System
**Database:** 31967_Gilbert_RentalPropertyManagement_DB
**Student:** Gilbert (ID: 31967/2025)

## 1. System Scope

This system manages the full rental lifecycle for a property management office acting on behalf of landlords. It covers registering properties and units, onboarding tenants, creating and tracking lease agreements, recording rent payments, and handling maintenance requests. It does not cover accounting/tax reporting or property sales — only rental operations.

## 2. Actors

- **Landlord** — owns one or more properties; registers properties with the office and receives visibility into occupancy and revenue.
- **Property Manager** — the primary system user; creates property/unit records, signs tenants to leases, records payments, and assigns maintenance work.
- **Tenant** — applies to rent a unit, pays rent, and reports maintenance issues.
- **Maintenance Staff** — receives assigned maintenance requests and resolves them.
- **System** — automatically enforces business rules (e.g. blocking transactions on weekdays/holidays) and logs every data-changing action to the audit trail.

## 3. Workflow (Start to End)

1. **Property registration** — A landlord registers a property with the property manager, providing basic details (address, type).
2. **Property and unit setup** — The manager creates the property record in the system and adds its individual rentable units (apartments, shops, offices), each marked as vacant.
3. **Tenant application** — A prospective tenant applies for a specific vacant unit.
4. **Lease creation** — The manager reviews the application and creates a lease agreement linking the tenant to the unit, recording the agreed rent, start date, and end date. The unit's status changes to occupied.
5. **Rent collection** — Each month, the tenant pays rent. The manager records the payment against the active lease. The system's business rule blocks any payment record from being inserted, updated, or deleted during weekdays or public holidays, restricting these operations to weekends/non-holiday days only.
6. **Maintenance handling** — If a tenant reports an issue with their unit, the manager assigns it to maintenance staff, who resolve it and update its status to closed.
7. **Lease renewal or termination** — As a lease nears its end date, the manager decides whether to renew it (creating a new lease term) or terminate it, which returns the unit to vacant status.

Throughout this workflow, every insert, update, and delete on core tables is automatically recorded in the audit log, capturing which user made the change, when, and what changed — supporting the auditing and security requirement of the project.

## 4. Why This Workflow Fits a Real-World Need

Manual, paper- or spreadsheet-based rental management breaks down as the number of units grows: rent payments get missed, lease renewals are forgotten, and there is no single source of truth on occupancy or revenue. This system directly addresses each of those gaps through structured data, automated business rules, and full auditability.
