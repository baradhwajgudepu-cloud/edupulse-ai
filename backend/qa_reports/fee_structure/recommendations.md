# Recommendations - Fee Structure Module

This document outlines practical engineering recommendations to enhance the reliability, security, and maintainability of the Fee Structure module and transaction layers.

---

## 1. Implement Automatic Transaction Middleware
- **Observation**: Currently, transaction rollbacks (`db.rollback()`) are handled explicitly inside the service layer catch blocks.
- **Recommendation**: Introduce a FastAPI middleware (or database dependency yield handler) that automatically executes a rollback if any exception propagates out of the endpoint handler, ensuring transactional safety even for unhandled errors:
  ```python
  @app.middleware("http")
  async def db_session_middleware(request: Request, call_next):
      response = Response("Internal server error", status_code=500)
      try:
          request.state.db = SessionLocal()
          response = await call_next(request)
          await request.state.db.commit()
      except Exception as e:
          await request.state.db.rollback()
          raise e
      finally:
          await request.state.db.close()
      return response
  ```

---

## 2. Standardize Testing Patterns to Avoid Expired Session Attributes
- **Observation**: Accessing model attributes (like `tenant.id`) in async tests after `db_session.commit()` or `db_session.rollback()` triggers lazy-loading `MissingGreenlet` errors.
- **Recommendation**: Establish a standard testing guideline to extract and assign scalar variables (e.g. `tenant_id = tenant.id`) immediately during test setup. Never reference model instances after commit or rollback.

---

## 3. Handle Null Class Fallback in Assignments
- **Observation**: If `class_id` in `FeeStructure` is NULL, it indicates that the structure applies globally to all classes.
- **Recommendation**: Ensure that the student assignment service contains proper fallback lookup queries so that when looking up a student's assigned fees, it correctly queries both the student's specific class ID *and* the fallback global class (i.e. `class_id IS NULL`) fee structures.

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
