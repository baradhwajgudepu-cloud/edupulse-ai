# SQL Verification Report - Fee Structure Module

This report documents the verification of the database-level uniqueness constraints and index integrity on the target PostgreSQL database server.

---

## 1. Active Unique Constraint Definition

The database unique constraint enforces that active fee structures (where `deleted_at IS NULL`) are unique for the combination `(tenant_id, school_id, academic_year_id, class_id, fee_type_id)`.

### PostgreSQL Schema Check:
```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fee_structures' AND indexname = 'uq_fee_structure_active';
```

### Resulting DDL:
```sql
CREATE UNIQUE INDEX uq_fee_structure_active ON public.fee_structures USING btree (tenant_id, school_id, academic_year_id, class_id, fee_type_id) WHERE (deleted_at IS NULL);
```

---

## 2. Duplicate Validation Execution

Executing a duplicate records scan against `fee_structures` table:

```sql
SELECT 
    fee_type_id,
    academic_year_id,
    class_id,
    school_id,
    COUNT(*)
FROM fee_structures
WHERE deleted_at IS NULL
GROUP BY 
    fee_type_id,
    academic_year_id,
    class_id,
    school_id
HAVING COUNT(*) > 1;
```

**Result**:
- Number of duplicate rows returned: **0**
- Verification: **PASSED**. No active duplicate records exist, confirming the Alembic migration deduplication and the unique index are active.

---

## 3. Transaction Rollback & Isolation Check

- **Action**: Bypassing API level checks to manually insert duplicate combination rows:
  ```python
  dup_db = FeeStructure(
      tenant_id=tenant_id,
      school_id=school_id,
      fee_type_id=fee_type_id,
      academic_year_id=ay_id,
      class_id=cl_id,
      amount=6000.0,
      due_date=date.today()
  )
  db_session.add(dup_db)
  await db_session.commit()
  ```
- **Constraint Response**:
  - `sqlalchemy.exc.IntegrityError: (psycopg2.errors.UniqueViolation) duplicate key value violates unique constraint "uq_fee_structure_active"`
- **Rollback Verification**:
  - `await db_session.rollback()` executed cleanly.
  - Verification: **PASSED**.

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
