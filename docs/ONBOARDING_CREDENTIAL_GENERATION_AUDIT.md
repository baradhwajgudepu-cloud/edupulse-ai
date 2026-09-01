# EduPulse AI — School Onboarding Credential Generation & Dry-Run Audit

This report documents the architectural, security, credential-generation, and dry-run audit of the EduPulse AI School Onboarding engine (`apps/admin_portal` and `backend/app/services/`).

---

## 1. Teacher Account Creation Flow

* **Source Files**:
  - Endpoint: [`backend/app/api/v1/endpoints/teachers.py`](file:///d:/EDU_PULSE_AI/backend/app/api/v1/endpoints/teachers.py)
  - Service: [`backend/app/services/teacher.py`](file:///d:/EDU_PULSE_AI/backend/app/services/teacher.py) (`create_teacher`)
  - Identity Provisioning: [`backend/app/services/identity_provisioning.py`](file:///d:/EDU_PULSE_AI/backend/app/services/identity_provisioning.py) (`provision_teacher`)
  - Security: [`backend/app/core/security.py`](file:///d:/EDU_PULSE_AI/backend/app/core/security.py) (`generate_secure_temp_password`, `hash_password`)
* **Pipeline Execution**:
  1. **Validation**: Enforces age $\ge 18$, past joining date, valid school context, and uniqueness of `employee_code`, `staff_code`, `mobile`, `official_email`, `aadhaar_number`, and `pan_number`.
  2. **Teacher Profile Insertion**: Inserts `Teacher` record in database with status `ACTIVE`.
  3. **User Record Creation**: `IdentityProvisioningService.provision_teacher` creates a corresponding `User` account:
     - `User.email` = `teacher.official_email` (mandatory login identifier).
     - `User.must_change_password` = `True`.
     - `User.roles` mapped to system role `TEACHER`.
     - `User.schools` linked to target `school_id`.
  4. **Password Generation & Hashing**:
     - When `settings.DEBUG == True`: Default temporary password `"EduPulse@123"` is assigned.
     - In Production (`settings.DEBUG == False`): `generate_secure_temp_password()` generates a 12-character cryptographically secure password with mixed casing, digits, and special symbols.
     - Password is immediately hashed using **Argon2id** (`ph.hash(password)`) and stored in `User.hashed_password`.
     - Plaintext password is **never stored** in the database.
  5. **Response Envelope**: If `settings.DEBUG == True`, the transient `temporary_password` is attached to the API response object for client-side export.

---

## 2. Guardian Account Creation Flow

* **Source Files**:
  - Endpoint: [`backend/app/api/v1/endpoints/guardians.py`](file:///d:/EDU_PULSE_AI/backend/app/api/v1/endpoints/guardians.py)
  - Service: [`backend/app/services/guardian.py`](file:///d:/EDU_PULSE_AI/backend/app/services/guardian.py) (`create_guardian`)
  - Identity Provisioning: [`backend/app/services/identity_provisioning.py`](file:///d:/EDU_PULSE_AI/backend/app/services/identity_provisioning.py) (`provision_guardian`, `_generate_parent_login_id`)
* **Pipeline Execution**:
  1. **Validation**: Checks `mobile` format, `email` syntax, and school scoping.
  2. **Parent Login ID Generation**:
     - Uses database table `parent_login_sequences` with row-level locking (`with_for_update()`).
     - Formats sequential string: `{SCHOOL_CODE}P{000001}` (e.g. `TS001P000001`, `TS001P000002`).
  3. **User Record Creation**:
     - `User.login_id` = generated sequential Parent Login ID.
     - `User.email` = `guardian.email` (if blank, falls back to `guardian.{mobile}@edupulse.local`).
     - `User.roles` mapped to system role `PARENT`.
     - `User.must_change_password` = `True`.
  4. **Password Generation**: Generated and hashed via Argon2id.
  5. **Mobile Login Support**: Parents can authenticate via `/auth/login` using either their generated `login_id` or registered `email`.

---

## 3. Student Account Behavior

* **Audit Finding**: **Students DO NOT receive User accounts.**
* **Source Files**: [`backend/app/services/student.py`](file:///d:/EDU_PULSE_AI/backend/app/services/student.py), [`backend/app/models/student.py`](file:///d:/EDU_PULSE_AI/backend/app/models/student.py)
* **Details**:
  - `students` table does not have a `user_id` foreign key.
  - `StudentService.create_student` registers the student profile, roll number, and section enrollment without calling `IdentityProvisioningService`.
  - Student authentication is not supported or required in the current system version (students interact via parent portal / physical attendance).

---

## 4. Summary of Login ID & Password Generation Rules

| Entity | Primary Login Identifier | Fallback Login Identifier | Password Complexity | Hashing Algorithm |
|---|---|---|---|---|
| **Teacher** | `official_email` (e.g. `ananya.reddy@telanganaschool.edu`) | `employee_code` (in app) | 12 chars (Upper, Lower, Digit, Symbol) | Argon2id |
| **Guardian** | `login_id` (e.g. `TS001P000001`) | `email` / `mobile` | 12 chars (Upper, Lower, Digit, Symbol) | Argon2id |
| **Principal** | `email` (e.g. `principal.ts001@telanganaschool.edu`) | None | 12 chars (Upper, Lower, Digit, Symbol) | Argon2id |
| **Student** | None (No Account) | None | N/A | N/A |

---

## 5. Completion Report & Credential Visibility

* **UI Screen**: Step 16 — Completion Summary Report ([`school_onboarding_screen.dart:L1650-L1825`](file:///d:/EDU_PULSE_AI/edupulse_flutter/apps/admin_portal/lib/features/bulk_import/presentation/pages/school_onboarding_screen.dart))
* **Capabilities**:

| Entity | Import Count Tracked | Account Created Tracked | Login ID Available | Temporary Password Available | Downloadable CSV |
|---|---|---|---|---|---|
| **Teachers** | YES | YES | YES (`official_email`) | YES (in Debug / API response) | YES (`uat_credentials_export.csv`) |
| **Guardians** | YES | YES | YES (`TS001P000001`...) | YES (in Debug / API response) | YES (`uat_credentials_export.csv`) |
| **Principal** | YES | YES | YES (`email`) | YES (in Debug / API response) | YES (`uat_credentials_export.csv`) |
| **Students** | YES | N/A | NO (No Account) | NO | N/A |

---

## 6. Duplicate Import Safety Audit

| Entity | Scenario | Behavior | Resolution / Handling |
|---|---|---|---|
| **Teacher** | Same `official_email` under same school | Self-healing idempotency | Re-attaches existing User, returns existing teacher profile without error. |
| **Teacher** | Same `employee_code` or `mobile` under different teacher | **REJECT (HTTP 409)** | Explicit conflict error detail returned. |
| **Guardian** | Same `email` / `mobile` under same guardian | Self-healing idempotency | Resolves existing profile and returns existing `login_id`. |
| **Guardian** | Same `email` under different guardian | **REJECT (HTTP 409)** | Conflict error returned to prevent account hijacking. |
| **Student** | Same `admission_number` in school | **REJECT (HTTP 409)** | Refuses duplicate registration; onboarding skips or reports conflict. |
| **Student** | Same `roll_number` in same section | **REJECT (HTTP 409)** | Duplicate roll number blocked at repository boundary. |
| **Assignments** | Same Teacher-Subject-Section combination | **REJECT (HTTP 409)** | Resolves existing assignment ID without breaking downstream timetable. |

---

## 7. Controlled Dry-Run Validation Audit

* **Workbook Tested**: [`data/TELANGANA_SCHOOL_ONBOARDING_WORKBOOK.xlsx`](file:///d:/EDU_PULSE_AI/data/TELANGANA_SCHOOL_ONBOARDING_WORKBOOK.xlsx)
* **Execution Mode**: Parse & Validate Only (Zero Database Writes)
* **Results**:

```text
=================================================================
TELANGANA SCHOOL ONBOARDING WORKBOOK — DRY-RUN AUDIT RESULTS
=================================================================
Sheet: school               | Total: 1    | Valid: 1    | Invalid: 0 
Sheet: academic_years       | Total: 1    | Valid: 1    | Invalid: 0 
Sheet: classes              | Total: 6    | Valid: 6    | Invalid: 0 
Sheet: sections             | Total: 12   | Valid: 12   | Invalid: 0 
Sheet: subjects             | Total: 6    | Valid: 6    | Invalid: 0 
Sheet: teachers             | Total: 18   | Valid: 18   | Invalid: 0 
Sheet: guardians            | Total: 360  | Valid: 360  | Invalid: 0 
Sheet: students             | Total: 360  | Valid: 360  | Invalid: 0 
Sheet: student_guardians    | Total: 360  | Valid: 360  | Invalid: 0 
Sheet: teacher_assignments  | Total: 72   | Valid: 72   | Invalid: 0 
Sheet: timetable            | Total: 360  | Valid: 360  | Invalid: 0 
Sheet: syllabus             | Total: 114  | Valid: 114  | Invalid: 0 
Sheet: exams                | Total: 36   | Valid: 36   | Invalid: 0 
-----------------------------------------------------------------
TOTAL ROWS AUDITED  : 1,706
TOTAL VALID ROWS    : 1,706
TOTAL INVALID ROWS  : 0
COMPLIANCE RATE     : 100.00%
-----------------------------------------------------------------
```

---

## 8. Production Scale Account Creation Estimate

When this dataset is imported into the target school context:

| Entity Type | Input Dataset Rows | Authentication User Accounts Created | Roles Provisioned |
|---|---|---|---|
| **School & Academic Structure** | 2 | 0 | None |
| **Classes & Sections** | 18 | 0 | None |
| **Subjects & Curriculum** | 120 | 0 | None |
| **Teachers** | 18 | **18** | `TEACHER` |
| **Guardians (Parents)** | 360 | **360** | `PARENT` |
| **Students** | 360 | **0** | None |
| **Mappings & Schedules** | 828 | 0 | None |
| **Principal (Optional Wizard Step)**| 1 | **1** | `PRINCIPAL` |
| **TOTAL USER ACCOUNTS** | — | **379 User Accounts** | — |

---

## 9. Credential Recovery Risk Classification

**Classification**: **`PARTIALLY SAFE`** *(in Debug / UAT mode)* $\longrightarrow$ **`RISK IN PRODUCTION RELEASE`**

### Technical Risk Analysis:
1. **Password Hashing**: Passwords generated during onboarding are hashed immediately with Argon2id and stored in `User.hashed_password`. They cannot be decrypted or reverse-engineered from the database.
2. **API Visibility**: When `settings.DEBUG == True`, the temporary password is returned in the API response JSON for each teacher and parent creation call, enabling the Admin Portal to export `uat_credentials_export.csv`.
3. **Production Risk (`DEBUG == False`)**: In a strict production environment with `DEBUG = False`, the backend omits `temporary_password` from the JSON response to prevent credential interception over the wire. If automated email/SMS distribution is not active, newly generated passwords will be unrecoverable from the UI after import.

---

## 10. Recommended Mitigation Prior to Production Release
1. Ensure the platform administrator downloads the generated `uat_credentials_export.csv` immediately upon completion at Step 16.
2. For production rollouts with `DEBUG = False`, verify that the transactional email/SMS onboarding notification worker is operational so that magic setup links / password reset links are dispatched directly to teacher and parent devices.

---

## FINAL GATE

**`SAFE ONLY AFTER CREDENTIAL EXPORT VERIFICATION`**
