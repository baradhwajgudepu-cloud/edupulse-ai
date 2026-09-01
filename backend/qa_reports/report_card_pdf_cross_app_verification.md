# QA Verification Report: Report Card PDF Generation & Security Controls

## Overview
This report documents the verification and testing of the production-quality PDF report card generation system and role-based access control (RBAC) boundaries implemented for the EduPulse AI platform.

The dynamic PDF report card generator uses the **ReportLab** library to compile beautiful, publication-grade academic transcripts from live database records, featuring structured tables, academic summaries, progress trends, teacher remarks, signatures, and page-numbered footers.

---

## 1. Professional PDF Layout Components
The generated PDF dynamically constructs a multi-column document with the following distinct sections:

1. **Academic Banner**: Clean header displaying the school name and active academic year (e.g., `DELHI PUBLIC SCHOOL HYDERABAD - CAMPUS 2`, `AY 2025-26`).
2. **Student Identity Card**: A structured metadata table containing key details:
   - Student Name: `Vihaan Rao`
   - Admission Number: `10003`
   - Class & Section: `Class 4 - 4-A`
   - Roll Number
   - Attendance (Present / Total sessions)
   - Parent/Guardian Name (dynamically retrieved Father's Name: `Vikram Rao`)
   - Class Teacher Name: `Anita Sharma`
3. **Marks Matrix Table**: A grid mapping subjects (Mathematics, Science, English, etc.) against examinations. It calculates:
   - Maximum Marks
   - Marks Obtained
   - Percentage per subject
   - Subject Grade according to tenant grading policy
4. **Summary & Promotion Recommendation**: A highlights card displaying:
   - Overall Weighted Percentage
   - Overall Grade
   - Promotion Status (e.g., `PROMOTED` / `RETAINED`)
5. **AI Insights & Remarks**: Narrative and structured recommendations compiled on the fly.
6. **Signatures Block**: Two-column signature lines for the `Class Teacher` and `Principal`.
7. **Verification Footer**: Features a public verification URL utilizing the publication's unique UUID signature and dynamic page counts (`Page X of Y`).

---

## 2. Dynamic Data Flow & Self-Healing
The download endpoint (`/api/v1/report-cards/download/{student_id}`) includes a **self-healing compilation layer**:
- If a client requests a PDF and the file is missing or corrupted, the system automatically retrieves live marks, attendance records, remarks, and school details.
- It rebuilds the professional ReportLab PDF on the fly and saves it locally in the tenant's static directory.
- Subsequent requests serve the cached file immediately to conserve CPU cycles.

---

## 3. Strict Access Security Matrix
Security checks are enforced on `/preview/{student_id}`, `/history/{student_id}`, `/download/{student_id}`, and `/student/{student_id}` endpoints:

| Role | Target | Access Level | Expected Status |
| :--- | :--- | :--- | :--- |
| **Super Admin / Platform Admin** | Any Student | Full Access | `200 OK` |
| **Linked Parent** (e.g., Vikram Rao -> Vihaan Rao) | Linked Child | Read & Download | `200 OK` |
| **Unlinked Parent** | Other Student | Banned | `403 Forbidden` |
| **Assigned Teacher** | Student in Assigned Section | Read & Download | `200 OK` |
| **Unassigned Teacher** | Student in Unassigned Section | Banned | `403 Forbidden` |

---

## 4. Automated Verification Results
The test suite in [`test_report_cards.py`](file:///d:/EDU_PULSE_AI/backend/tests/test_report_cards.py) was executed using Pytest:

```bash
pytest backend/tests/test_report_cards.py
```

### Test Trajectory Details:
- **`test_single_and_bulk_class_generation`**: Passed. Verified that bulk generation successfully processes an entire class, compiling professional PDFs for each student.
- **`test_report_card_missing_data_warnings`**: Passed. Validated warning checks when grades or attendance metrics are incomplete.
- **`test_pdf_download_and_verification`**: Passed. Asserted that the download endpoint correctly serves valid PDF binary streams (`%PDF-`).
- **`test_report_card_security_restrictions`**: Passed. Proved that parent-child linkages and teacher section assignments are strictly verified, rejecting unauthorized requests with a `403 Forbidden` error.

**Result**: `7 passed, 2 warnings in 76.06s`

---

## 5. Modified Source Files
- **Service Layer**: [`report_card.py`](file:///d:/EDU_PULSE_AI/backend/app/services/report_card.py) — Handles the layout engine, table rendering, dynamic text wrapping, page counts, and eager loading of relationships.
- **API Endpoint Layer**: [`report_cards.py`](file:///d:/EDU_PULSE_AI/backend/app/api/v1/endpoints/report_cards.py) — Implements `verify_student_access` role-based validations.
- **Test Suite**: [`test_report_cards.py`](file:///d:/EDU_PULSE_AI/backend/tests/test_report_cards.py) — Automates verification of generation, download, self-healing, and security scopes.
