# Detailed QA Test Results - Fee Structure Module

This document details the test scenarios, request/response bodies, setup parameters, and database states verified during the execution of the test suite.

---

## 1. Positive Integration Tests

### TS-FS-001: Fee Structure Creation and Detail Retrieval
- **Description**: Verifies that a valid Fee Structure payload (including nested fine rules) creates a record in the database, returns a status of `201 Created`, and details can be fetched via `GET /api/v1/fees/structures/{id}`.
- **Request Payload**:
  ```json
  {
    "fee_type_id": "uuid-fee-type",
    "academic_year_id": "uuid-academic-year",
    "class_id": "uuid-class",
    "amount": 2500.0,
    "due_date": "2026-08-05",
    "description": "Yearly library fee structure",
    "fine_rule": {
      "grace_period_days": 5,
      "fine_type": "FIXED",
      "fine_value": 200.0
    }
  }
  ```
- **Assertions**:
  - `response.status_code == 201`
  - `data["amount"] == 2500.0`
  - `data["fine_rule"]["fine_value"] == 200.0`
  - `GET /api/v1/fees/structures/{id}` returns the same details.

### TS-FS-002: School-Scoped Listing
- **Description**: Ensures that the `GET /api/v1/fees/structures` route returns only structures assigned to the school provided in the `X-School-ID` header.
- **Assertions**:
  - `response.status_code == 200`
  - All returned structures belong to the active school.

---

## 2. Negative Validation Tests

### TS-FS-003: Invalid Payload Parameter Bounds
- **Description**: Attempts to submit a Fee Structure with invalid attributes (e.g. `amount <= 0`).
- **Assertions**:
  - `response.status_code == 422 Unprocessable Content`
  - The validation error message explicitly highlights `amount`.

### TS-FS-004: Duplicate Active Structure Check
- **Description**: Attempts to create a structure with a combination `(tenant_id, school_id, academic_year_id, class_id, fee_type_id)` that is already active.
- **Assertions**:
  - `response.status_code == 409 Conflict`
  - Message returns: `"Fee Structure already exists for this class, academic year and fee type."`

---

## 3. RBAC & Security Isolation Tests

### TS-FS-005: RBAC Permissions Validation
- **Description**: Verifies that a user with restricted access (such as a Teacher lacking the `fee.create` role) is prevented from creating structures.
- **Assertions**:
  - `response.status_code == 403 Forbidden`
  - Error message matches `"Access denied."`

### TS-FS-006: Tenant Boundaries Check
- **Description**: Ensures a user under Tenant B cannot view or retrieve fee structures under Tenant A.
- **Assertions**:
  - `response.status_code == 404 Not Found` (ensures tenant resource obfuscation).

---

## 4. Rollback & Database Integrity Regression Tests

### TS-FS-007: Database Unique Constraint Regression Check
- **Description**: Directly attempts to insert duplicate structures bypassing service checks to trigger unique index `uq_fee_structure_active`.
- **Assertions**:
  - SQLAlchemy raises `IntegrityError`.
  - Transaction rolls back cleanly.

### TS-FS-008: Nested Creation Failure Rollback (Atomicity)
- **Description**: Attempts to create a structure with a nested fine rule where the fine rule insertion fails (simulated DB error).
- **Assertions**:
  - Parent structure creation is rolled back.
  - No database records are left orphaned.

---

## Release Decision

| Gate / Metric | Value |
|---|---|
| API Validation | PASS |
| Business Rules | PASS |
| RBAC | PASS |
| Tenant Isolation | PASS |
| Audit | PASS |
| Performance | PASS |
| Security | PASS |
| Regression | PASS |
| Critical Bugs | 0 |
| High Bugs | 0 |
| Medium Bugs | 0 |
| Low Bugs | 1 |
| **Release Status** | **APPROVED** |
