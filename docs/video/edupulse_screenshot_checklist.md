# EduPulse AI — Screenshot Capture Checklist & Operator Playbook

**Target Audience**: Video Producer / Technical Operator / QA Specialist  
**Capture Standards**:
- **Web Portal Viewport**: Full HD `1920 × 1080` (16:9 Landscape) at 100% browser zoom (no scaling).
- **Mobile Apps Viewport**: Standard `1080 × 2400` (20:9) or iPhone 15 Pro resolution `1179 × 2556` framed cleanly.
- **Color Accuracy**: sRGB color space; light theme active unless explicitly capturing dark-slate brand intro.
- **Data Integrity**: Production-grade sample data ("Oakridge International School", Academic Year 2025–26, real names, no "Lorem Ipsum" or "test_test" strings).

---

## Screenshot Inventory Summary

| ID | File Name | Platform | Route / Modal | Primary Scene Target | Status |
|:---|:---|:---|:---|:---|:---|
| **SHOT-01** | `shot_01_problem_fragmentation.png` | Staged Office | Physical / Multi-Screen | Scene 01 | Required |
| **SHOT-02** | `shot_02_edupulse_brand_login.png` | Admin Portal | `/login` | Scene 02 | Required |
| **SHOT-03** | `shot_03_school_onboarding.png` | Admin Portal | `/school-onboarding` | Scene 03 | Required |
| **SHOT-04** | `shot_04_admin_dashboard.png` | Admin Portal | `/dashboard` | Scene 04 | Required |
| **SHOT-05** | `shot_05_student_360_modal.png` | Admin Portal | `Student360Modal` | Scene 05 | Required |
| **SHOT-06** | `shot_06_teachers_staff.png` | Admin Portal | `/teachers` | Scene 06 | Required |
| **SHOT-07** | `shot_07_staff_attendance_geofence.png` | Teacher App | `/staff-attendance` | Scene 07 | Required |
| **SHOT-08** | `shot_08_school_planner.png` | Admin Portal | `/planner/calendar` | Scene 08 | Required |
| **SHOT-09** | `shot_09_fees_management.png` | Admin Portal | `/fees` & `/fees/ledger` | Scene 09 | Required |
| **SHOT-10** | `shot_10_payroll_expenses.png` | Admin Portal | `/fees/salaries` | Scene 10 | Required |
| **SHOT-11** | `shot_11_imports_wizard.png` | Admin Portal | `/bulk-import` | Scene 11 | Required |
| **SHOT-12** | `shot_12_reports_analytics.png` | Admin Portal | `/reports` | Scene 12 | Required |
| **SHOT-13** | `shot_13_teacher_app.png` | Teacher App | `/home` | Scene 13 | Required |
| **SHOT-14** | `shot_14_parent_app.png` | Parent App | `/dashboard` | Scene 14 | Required |
| **SHOT-15** | `shot_15_connected_ecosystem.png` | Multi-Device | Multi-Platform Mockup | Scene 15 | Required |
| **SHOT-16** | `shot_16_edupulse_finale_logo.png` | Brand Asset | `edupulse_logo.png` | Scene 16 | Required |

---

## Detailed Screen-by-Screen Capture Specifications

---

### SHOT-01: Fragmented Operations (The Problem)
- **Target File**: `shot_01_problem_fragmentation.png`
- **Application**: Physical desk or composite screen capture (Pre-EduPulse state)
- **URL / Route**: N/A (Live staging or graphic montage)
- **Target Viewport**: 1920 × 1080 (Landscape)
- **Required State / Data**:
  - Open Excel spreadsheet with highlighted cell errors / missing student IDs.
  - Physical paper register with handwritten attendance marks and red pen corrections.
  - Stacks of paper fee receipts and loose circular printouts.
  - 3 open browser tabs showing disconnected single-purpose tools.
- **Recommended Interaction**: Overhead 45-degree angle shot with natural workplace ambient lighting.
- **What Should Be Visible**: Clear visual contrast between outdated, disjointed paper/spreadsheet methods and the modern clean UI that follows.

---

### SHOT-02: EduPulse Brand Login
- **Target File**: `shot_02_edupulse_brand_login.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/login` (Route: `AppRoutes.login`)
- **Source File**: `apps/admin_portal/lib/features/auth/presentation/pages/login_screen.dart`
- **Target Viewport**: 1920 × 1080 (Chrome / Edge, full screen)
- **Authenticated Role**: Unauthenticated (Public portal entry)
- **Required State / Data**:
  - EduPulse AI vector mark displayed clearly at the top of the auth card.
  - Institution selector populated or preset to `"Oakridge International School"`.
  - Email field showing placeholder or sample login: `admin@oakridge.edu.in`.
  - "Remember Me" checked, vibrant Teal (`#0D9488`) "Sign In" button enabled.
- **Recommended Interaction**: Static capture with cursor positioned cleanly hovering over the "Sign In" button (displaying the hover state).
- **What Should Be Visible**: Clean card elevation, subtle background slate gradient, pristine brand typography, zero input error borders.

---

### SHOT-03: School Onboarding Center
- **Target File**: `shot_03_school_onboarding.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/school-onboarding` (Route: `AppRoutes.schoolOnboarding`)
- **Source File**: `apps/admin_portal/lib/features/bulk_import/presentation/pages/school_onboarding_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `TENANT_ADMIN` or `SUPER_ADMIN`
- **Required State / Data**:
  - Campus Name: `"Oakridge International School"`
  - School Code: Auto-generated badge `"OAK-2026"`
  - School Board: `"CBSE"`
  - School Logo: Official uploaded school crest in preview widget.
  - Principal Provisioning Card: Principal Username `principal.oakridge@edupulse.ai` with verified status.
  - Progressive Setup Checklist: 17 steps visible, with Academic Structure, Classes, Sections, and Teachers marked with green checks, and Students in active review.
- **Recommended Interaction**: Checklist expanded at Step 4 (Sections & Rooms) or Step 6 (Teachers Roster).
- **What Should Be Visible**: Both the top school information card and the left/right progressive onboarding pipeline.

---

### SHOT-04: Admin School Command Center
- **Target File**: `shot_04_admin_dashboard.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/dashboard` (Route: `AppRoutes.dashboard`)
- **Source File**: `apps/admin_portal/lib/features/dashboard/presentation/dashboard_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `SCHOOL_ADMIN`
- **Required State / Data**:
  - Welcome Banner: `"Good morning, Administrator — Oakridge International School (CBSE)"`.
  - **5 Primary KPI Cards**:
    1. *Active Students*: `1,240` (with `+24 this term` trend)
    2. *Teaching Faculty*: `84` (with `100% active` badge)
    3. *Today's Attendance*: `96.4%` (with `+1.2% vs yesterday`)
    4. *Term Fee Collection*: `88.2%` (`₹37.7L / ₹42.8L`)
    5. *Operational Alerts*: `3` (Clean amber chip)
  - Visual Analytics Section: Real-time attendance bar chart and fee collection trend chart loaded.
  - Needs Attention Section: 2 actionable items (e.g., "3 Teacher leave requests pending", "1 fee receipt approval").
- **Recommended Interaction**: Cursor hovering over the Attendance KPI card to showcase the micro-interaction.
- **What Should Be Visible**: The full top fold of the dashboard down to the charts grid without excessive white space.

---

### SHOT-05: Student 360 Folio Modal
- **Target File**: `shot_05_student_360_modal.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/students` (Open `Student360Modal` for a student)
- **Source File**: `apps/admin_portal/lib/features/students/presentation/widgets/student_360_modal.dart`
- **Target Viewport**: 1920 × 1080 (Centered modal dialog, 1100 × 820)
- **Authenticated Role**: `ADMIN` / `SCHOOL_ADMIN`
- **Required State / Data**:
  - Student: `"Aarav Sharma"` | Roll No: `14` | Admission: `ADM-2024-089` | Class: `Grade 10-A`
  - High-res student avatar portrait.
  - Tab Bar visible: `Overview`, `Academic`, `Attendance`, `Homework`, `Fees`, `Guardian`, `Reports`, `Activity`.
  - Active Tab: Either `Overview` showing complete student bio, blood group, emergency contact, and father's name, or `Academic` showing Term 1 score (92.4% - A1).
- **Recommended Interaction**: Focus on the active modal window with the background students directory softly dimmed.
- **What Should Be Visible**: The complete 8 tabs across the modal top bar, student header chips, and clean data cards inside the folio body.

---

### SHOT-06: Teachers & Staff Management
- **Target File**: `shot_06_teachers_staff.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/teachers` (Route: `AppRoutes.teachers`)
- **Source File**: `apps/admin_portal/lib/features/teachers/presentation/pages/teachers_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `SCHOOL_ADMIN`
- **Required State / Data**:
  - Filter bar: `All Staff (96)`, `Teaching Staff (84)`, `Non-Teaching Staff (12)`.
  - Active tab: `Teaching Staff`.
  - Search bar: Placeholder `"Search by name, employee code, department..."`.
  - Faculty Grid: 6–8 realistic teacher profile cards visible:
    - Example 1: `Mrs. Priya Rao` — Head of Mathematics, M.Sc. B.Ed., Class 10-A Class Teacher.
    - Example 2: `Dr. Vikram Malhotra` — Department of Physics, Ph.D., Senior Faculty.
    - Example 3: `Ms. Ananya Sen` — Department of English Literature, M.A. B.Ed.
  - Badges: `ACTIVE` status pills (emerald green `#059669`), verified contact chips.
- **Recommended Interaction**: Card view active, cursor hovering near department filter pill.
- **What Should Be Visible**: The rich card grid showing faculty avatars, subjects, class allocations, and contact action buttons.

---

### SHOT-07: Staff Attendance + Geofencing
- **Target File**: `shot_07_staff_attendance_geofence.png`
- **Application**: Teacher App (Mobile)
- **URL / Route**: Mobile screen `/staff-attendance` (Route: `AppRoutes.staffAttendance`)
- **Source File**: `apps/teacher_app/lib/features/staff_attendance/presentation/pages/staff_attendance_screen.dart`
- **Target Viewport**: 1080 × 2400 (Mobile portrait)
- **Authenticated Role**: `TEACHER` (`priya.rao@oakridge.edu.in`)
- **Required State / Data**:
  - Header: `"Today's Attendance"` with current formatted date (`Tuesday, 22 September 2026`).
  - `GeofenceStatusBanner`: Emerald green banner reading `"Inside Campus Boundary (Accuracy: 4m)"`.
  - Action Button: Large verified `"Check In"` button in Teal (`#0D9488`).
  - Location Status Card: Latitude, Longitude, Distance from school center (`18 meters`), campus geofence radius (`150m`).
- **Recommended Interaction**: Pre-check-in state with active location boundary verified, ready for tap.
- **What Should Be Visible**: The full mobile viewport with pristine status banner, GPS coordinates card, and prominent check-in action.

---

### SHOT-08: School Planner & Operational Calendar
- **Target File**: `shot_08_school_planner.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/planner/calendar` (Route: `AppRoutes.plannerCalendar`)
- **Source File**: `apps/admin_portal/lib/features/planner/presentation/pages/planner_calendar_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `PRINCIPAL`
- **Required State / Data**:
  - Month View: Current academic month.
  - Color-Coded Event Chips:
    - Indigo: `"Mid-Term Examination — Mathematics (Grade 10)"`
    - Amber: `"Staff Leave — 2 Faculty On Leave"`
    - Teal: `"Circular #042 — Science Exhibition Registration"`
    - Emerald: `"Annual Athletic Meet 2026"`
  - Right Drawer / Sidebar: "Today's Schedule & Leave Approvals" listing 2 approved events and 1 pending circular.
- **Recommended Interaction**: Month grid filled with realistic schedule entries, one popover chip active.
- **What Should Be Visible**: The full calendar grid showing clean contrast between operational categories and clear day cells.

---

### SHOT-09: Fees & Financial Operations
- **Target File**: `shot_09_fees_management.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/fees` (Route: `AppRoutes.fees`)
- **Source File**: `apps/admin_portal/lib/features/fees/presentation/pages/fees_dashboard_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `ACCOUNTANT`
- **Required State / Data**:
  - Top Metrics Cards:
    - *Total Billed*: `₹42,80,000`
    - *Total Collected*: `₹37,75,000` (`88.2%`)
    - *Outstanding Dues*: `₹5,05,000`
    - *Online vs Cash Ratio*: `78% Digital`
  - Fee Allocation Bar: Tuition (65%), Transportation (20%), Lab/Library (15%).
  - Action Button: `"Record Payment"`, `"Export Defaulters"`, `"Assign Fee Structure"`.
  - Bottom Tab: Student Ledgers preview showing recent transactions with receipt reference numbers.
- **Recommended Interaction**: Full dashboard view with collection progress bar at 88.2%.
- **What Should Be Visible**: High-precision currency metrics, collection progress bars, and ledger transaction summary.

---

### SHOT-10: Staff Salaries & Expenses
- **Target File**: `shot_10_payroll_expenses.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/fees/salaries` (Route: `AppRoutes.salaries`)
- **Source File**: `apps/admin_portal/lib/features/fees/presentation/pages/salaries_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `ACCOUNTANT`
- **Required State / Data**:
  - Month/Year Selector: `September 2026`.
  - Payroll Table Columns:
    `Staff Code` | `Staff Name` | `Department` | `Base Salary` | `Allowances` | `Deductions` | `Net Salary` | `Status`
  - Sample Records:
    - `EMP-0101` | Priya Rao | Mathematics | ₹55,000 | ₹8,000 | ₹3,500 | ₹59,500 | `PAID` (Green)
    - `EMP-0102` | Vikram Malhotra | Physics | ₹62,000 | ₹9,500 | ₹4,200 | ₹67,300 | `PAID` (Green)
    - `EMP-0103` | Rajesh Kumar | Administration | ₹40,000 | ₹5,000 | ₹2,500 | ₹42,500 | `PENDING` (Amber)
- **Recommended Interaction**: Table scrolled to show 5–6 rows with clear net calculation columns.
- **What Should Be Visible**: Clean transparent arithmetic across allowances, deductions, and net disbursed amounts.

---

### SHOT-11: Data Imports Wizard
- **Target File**: `shot_11_imports_wizard.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/bulk-import` (Route: `AppRoutes.bulkImport`)
- **Source File**: `apps/admin_portal/lib/features/bulk_import/presentation/pages/bulk_import_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `DATA_MANAGER`
- **Required State / Data**:
  - File Card: `Oakridge_Students_2026.xlsx` (`450 rows detected, 18 columns`).
  - Column Mapping Table:
    - Source `student_name` → Target `Full Name` (Matched)
    - Source `dob` → Target `Date of Birth` (Matched)
    - Source `gender` → Target `Gender` (Matched)
    - Source `guardian_mobile` → Target `Primary Guardian Phone` (Matched)
  - Pre-Import Validation Status: `Validation Passed — 450 of 450 records valid (0 Errors)`.
  - Primary Action: Glowing Teal `"Commit Import"` button.
- **Recommended Interaction**: Validation progress bar at 100% with green checkmarks alongside mapped columns.
- **What Should Be Visible**: The intuitive mapping interface and live tabular preview showing clean imported fields.

---

### SHOT-12: Reports & Analytics Dashboard
- **Target File**: `shot_12_reports_analytics.png`
- **Application**: Admin Portal Web
- **URL / Route**: `http://localhost:port/#/reports` (Route: `AppRoutes.reports`)
- **Source File**: `apps/admin_portal/lib/features/reports/presentation/pages/reports_dashboard_screen.dart`
- **Target Viewport**: 1920 × 1080
- **Authenticated Role**: `ADMIN` / `PRINCIPAL`
- **Required State / Data**:
  - 5 Tab Headers: `Executive Overview`, `Academic`, `Examinations`, `Attendance`, `Fees`.
  - Active Tab: `Academic` or `Executive Overview`.
  - Visual Charts:
    - Class-wise academic GPA distribution (Bar chart).
    - Attendance compliance by grade (Grade 1 to 12 comparative bars).
    - Fee realization timeline chart.
  - Action Bar: `"Export as PDF"` and `"Export Excel"` buttons enabled.
- **Recommended Interaction**: Full dashboard displaying charts without empty data states.
- **What Should Be Visible**: Polished, production-grade business intelligence charts and institutional summary metrics.

---

### SHOT-13: Teacher Mobile App Experience
- **Target File**: `shot_13_teacher_app.png`
- **Application**: Teacher App (Mobile)
- **URL / Route**: Mobile screen `/home` (Route: `AppRoutes.home`)
- **Source File**: `apps/teacher_app/lib/features/shell/presentation/pages/home_screen.dart`
- **Target Viewport**: 1080 × 2400 (Mobile portrait)
- **Authenticated Role**: `TEACHER` (`Priya Rao`)
- **Required State / Data**:
  - Welcome Banner: `"Good morning, Priya Rao"` with teacher avatar and `Academic Year 2025-26`.
  - Timetable Card: `"Period 2: Grade 10-A Mathematics (09:30 AM – 10:15 AM) — Room 204"`.
  - Quick Action Buttons: `Mark Attendance`, `Assign Homework`, `Enter Marks`, `Apply Leave`.
  - Pending Tasks Card: `"2 Homework Submissions to Review"`.
- **Recommended Interaction**: Clean mobile home screen with today's timetable prominently featured.
- **What Should Be Visible**: The teacher's daily hub showing actionable classroom tools and schedule.

---

### SHOT-14: Parent Mobile App Experience
- **Target File**: `shot_14_parent_app.png`
- **Application**: Parent App (Mobile)
- **URL / Route**: Mobile screen `/dashboard` (Route: `AppRoutes.dashboard`)
- **Source File**: `apps/parent_app/lib/features/dashboard/presentation/pages/dashboard_screen.dart`
- **Target Viewport**: 1080 × 2400 (Mobile portrait)
- **Authenticated Role**: `PARENT` (`Sunil Sharma`, Guardian of Aarav Sharma)
- **Required State / Data**:
  - Child Card: `"Aarav Sharma — Grade 10-A (Roll No: 14)"`.
  - 4 Key Metrics:
    - *Attendance*: `97%` (Green)
    - *Due Fees*: `₹0` (All cleared)
    - *Pending Homework*: `1 Assignment` (Due Tomorrow)
    - *Latest Result*: `A+` (Mathematics Term 1)
  - Quick Shortcuts: `Pay Fees`, `Attendance Calendar`, `Homework`, `Report Cards`.
- **Recommended Interaction**: Active child profile view with all 4 metric cards populated.
- **What Should Be Visible**: The family-centric dashboard demonstrating effortless transparency for parents.

---

### SHOT-15: Connected Multi-Role Ecosystem
- **Target File**: `shot_15_connected_ecosystem.png`
- **Application**: Multi-Device Composite (Admin Desktop + Principal Tablet + Teacher Mobile + Parent Mobile)
- **URL / Route**: Composite render of `AppRoutes.dashboard` across all 4 apps
- **Target Viewport**: 1920 × 1080 (3D device arrangement)
- **Required State / Data**:
  - Desktop Monitor (Center-Left): Admin Portal Command Center (`/dashboard`).
  - Tablet Screen (Center-Right): Principal App Executive Overview (`/dashboard`).
  - Mobile Device 1 (Foreground-Left): Teacher App Timetable (`/home`).
  - Mobile Device 2 (Foreground-Right): Parent App Child Dashboard (`/dashboard`).
  - All screens showing synchronized data for `"Oakridge International School"`.
- **Recommended Interaction**: Perspective studio layout with subtle soft shadows beneath devices.
- **What Should Be Visible**: The cohesive visual design system (Teal, Slate, White) unifying all 4 user roles into one platform.

---

### SHOT-16: EduPulse Finale Logo & Vision
- **Target File**: `shot_16_edupulse_finale_logo.png`
- **Application**: Brand Identity Canvas
- **Source File**: `packages/edupulse_assets/assets/branding/edupulse_logo.png`
- **Target Viewport**: 1920 × 1080 (Deep slate canvas `#0F172A`)
- **Required State / Data**:
  - Authentic high-resolution EduPulse AI vector logo centered.
  - Subtitle: `"The Intelligent Operating System for Modern Schools"`.
  - 4 Pillars: `"Manage • Connect • Analyze • Grow"`.
- **What Should Be Visible**: Flawless brand geometry, crisp contrast, premium corporate finish.

---

## Operator Quality Verification Checklist

- [ ] All browser screenshots captured at exactly `1920 × 1080` without OS scrollbars or browser bookmarks bar.
- [ ] All mobile screenshots captured at native resolution without status bar clutter (clean battery 100%, Wi-Fi full).
- [ ] No test placeholders (no `foo`, `bar`, `asdf`, `test user`).
- [ ] Consistent institution branding across all shots: `"Oakridge International School"`.
- [ ] File names exactly match the required prompt references (`shot_01` through `shot_16`).
