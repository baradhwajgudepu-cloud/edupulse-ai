# EduPulse AI Release Test Report

- **Run ID**: AUTO-20260817-225959-C12B67
- **Date/Time**: 2026-08-17T17:33:04.823238+00:00
- **Backend URL**: http://127.0.0.1:8000
- **Overall Status**: **PASS**

## Automated Seeding & Execution Phases

| Phase | Status | Duration | Details |
| :--- | :--- | :--- | :--- |
| 1 - Backend Health Check | **PASS** | 0.57s | Healthy |
| 2 - SUPER_ADMIN Authentication | **PASS** | 0.93s | Login & /auth/me tenant_id=null verified |
| 3 - Tenant CRUD & Platform Listing | **PASS** | 0.09s | Tenant b2ba1879-52a8-47ec-b024-f7438d477e78 created & listed |
| 4 - School CRUD scoped under Tenant | **PASS** | 0.05s | School a2073fc9-2877-4d6b-84c2-ec5bbf87392c created & verified |
| 5 - Academic Structure (AY/Classes/Sections/Subjects) | **PASS** | 1.05s | Created AY, Class 1-2, Section A-B, English/Math subjects |
| 6 - Teachers & Subject Assignments | **PASS** | 2.16s | Created 2 teachers + 1 assignment |
| 7 - Guardians Seeding | **PASS** | 0.39s | Created 2 guardians |
| 8 - Students & Guardian Links | **PASS** | 0.38s | Created 5 students + 1 guardian link |
| 10 - Timetable Structure Setup | **PASS** | 0.16s | Timetable period registered |
| 9 - Attendance Sessions & Record Marking | **PASS** | 0.50s | Created session & marked all 5 students |
| 11 - Syllabus Creation & Conflict Validation | **PASS** | 0.62s | Syllabus created & duplicate validation verified |
| 12 - Examination Wizard | **PASS** | 0.40s | Exam 5eb2f1bb-a9c1-4da2-93f8-db5ed6dccdca and schedule 1f28ca4c-9c68-4059-9089-4c870e22dfd2 created |
| 13 - Fee Schema & Assignments | **PASS** | 0.22s | Fee structures assigned successfully |
| 14 - Marks Bulk Entry | **PASS** | 0.22s | Seeded and published marks for all 5 student records |
| 15 - Report Card & Approval Workflows | **PASS** | 0.71s | Generated and approved report card 8f75fcb8-59c1-46e5-b967-84bc7a7a96e6 |
| 16 - Spreadsheet Onboarding (Validation, Idempotency & Run) | **PASS** | 0.92s | Academic setup migration executed and repeated idempotently |
| 22 - Tenant Isolation Validations | **PASS** | 0.06s | Verified cross-tenant restrictions return 403/404 |
| 23 - RBAC Controls Sanity Verification | **PASS** | 0.52s | RBAC boundary validation verified successfully |
| 24 - Session Context & Token Restoration | **PASS** | 0.01s | Active X-Tenant-ID & X-School-ID context verified |
| 28 - Direct DB Integrity & Foreign Keys | **PASS** | 0.25s | DB queries validated persistence & relationships |
| 26 - Flutter Analyze & Specific Test Suites | **PASS** | 173.03s | Flutter static analyzer and 6 regression test files executed |
| 29 - Controlled Resource Cleanup | **PASS** | 0.69s | Deleted all records created during this run |

| Playwright E2E | **PENDING** | - | Not configured in execution environment |

## Database Persistence Checks
- **Tenant record verified**: PASS
- **School to Tenant foreign key verified**: PASS
- **Student count verified**: PASS

## Tenant Isolation & Security
- **Cross-tenant query restriction**: PASS
- **RBAC API security verification**: PASS

## Onboarding Validation
- **Idempotency re-run verified**: PASS
- **Duplicate syllabus conflict check**: PASS

## Flutter Static Analysis & Tests
- **Flutter static analysis (flutter analyze)**: **FAIL/WARNING** (code 1)

### Flutter Widget Regression Tests

| Test Suite File | Status | Output Summary |
| :--- | :--- | :--- |
| `report_card_management_feature_test.dart` | **PASS** | ansition does not crash 00:06 +15: Report Card Dropdown Assertion and Lifecycle Tests TEST 10: Class 1 -> Class 2 transition clears old section 00:06 +16: Report Card Dropdown Assertion and Lifecycle Tests TEST 11: Academic Year 2025-26 -> 2026-27 clears dependent state 00:07 +17: All tests passed!  |
| `school_onboarding_test.dart` | **PASS** | : 0 [DIAGNOSTIC] SYLLABUS LOOKUP: requested academic_year_code = AY4099 | available parent keys = [AY4099, AY2027-2028, AY2028-2029] | resolved values = {AY4099: ay_resolved_id_123, AY2027-2028: ay_resolved_id_ck, AY2028-2029: ay_resolved_id_cl} 00:03 +74: (tearDownAll) 00:03 +74: All tests passed!  |
| `tenant_management_test.dart` | **PASS** | 3. Active school is cleared after tenant switch 00:00 +3: Tenant Management Tests 4. Tenant creation validation rules 00:00 +4: Tenant Management Tests 5. Duplicate tenant/code handling (HTTP 409 conflict) 00:00 +5: Tenant Management Tests 6. Clean-state Integration Flow 00:00 +6: All tests passed!  |
| `student_management_test.dart` | **PASS** | ovider - Empty page shifts pagination skip offset backward 00:10 +18: Student Management Provider and Mutation Audit Tests Student Directory - Bulk Delete Optimization tests Widget - confirmation dialog, cancel prevents deletion, and selection updates on success/failure 00:10 +19: All tests passed!  |
| `onboarding_context_lifecycle_test.dart` | **PASS** | erver code.[0m [38;5;196m│ ⛔ [0m [38;5;196m│ ⛔ Response: {success: false, message: X-Tenant-ID header is missing., data: null}[0m [38;5;196m└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────[0m 00:00 +11: All tests passed!  |
| `onboarding_approval_widget_test.dart` | **PASS** | : requested academic_year_code = AY2026 | available parent keys = [AY4099, AY2027-2028, AY2028-2029, AY2026] | resolved values = {AY4099: ay_resolved_id_123, AY2027-2028: ay_resolved_id_ck, AY2028-2029: ay_resolved_id_cl, AY2026: resolved_mock_id} 00:04 +1: (tearDownAll) 00:04 +1: All tests passed!  |
