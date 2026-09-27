# EduPulse AI — Gemini AI Video Generation Prompts
**Model Target**: Gemini AI Video / Veo 2 / Enterprise Video Generative Engine  
**Standard Output Format**: 16:9 Landscape | 1080p/4K | 24/30 FPS | 8–10 Seconds per Clip  
**Core Rules Enforced in Every Prompt**:
1. *Use uploaded EduPulse screenshot as exact UI reference.*
2. *Preserve the actual interface — do not redesign the interface.*
3. *Do not invent buttons or features; only animate existing elements.*
4. *Smooth professional camera movement with realistic cursor interaction where appropriate.*
5. *Premium EdTech/SaaS visual style: clean lighting, crisp typography, no distorted text, no fake statistics.*

---

## Master Prompt Index

- **Scene 01**: `PROMPT_SCENE_01_THE_PROBLEM`
- **Scene 02**: `PROMPT_SCENE_02_EDUPULSE_BRAND_LOGIN`
- **Scene 03**: `PROMPT_SCENE_03_SCHOOL_ONBOARDING`
- **Scene 04**: `PROMPT_SCENE_04_SCHOOL_COMMAND_CENTER`
- **Scene 05**: `PROMPT_SCENE_05_STUDENT_360_FOLIO`
- **Scene 06**: `PROMPT_SCENE_06_TEACHERS_AND_STAFF`
- **Scene 07**: `PROMPT_SCENE_07_ATTENDANCE_AND_GEOFENCING`
- **Scene 08**: `PROMPT_SCENE_08_SCHOOL_PLANNER`
- **Scene 09**: `PROMPT_SCENE_09_FEES_AND_FINANCE`
- **Scene 10**: `PROMPT_SCENE_10_PAYROLL_AND_EXPENSES`
- **Scene 11**: `PROMPT_SCENE_11_DATA_IMPORTS_WIZARD`
- **Scene 12**: `PROMPT_SCENE_12_REPORTS_AND_ANALYTICS`
- **Scene 13**: `PROMPT_SCENE_13_TEACHER_MOBILE_APP`
- **Scene 14**: `PROMPT_SCENE_14_PARENT_MOBILE_APP`
- **Scene 15**: `PROMPT_SCENE_15_UNIFIED_ECOSYSTEM`
- **Scene 16**: `PROMPT_SCENE_16_FINALE_AND_VISION`

---

### SCENE 01 — The Problem: Fragmented Operations
- **Prompt ID**: `PROMPT_SCENE_01_THE_PROBLEM`
- **Input Screenshot**: `shot_01_problem_fragmentation.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Cinematic product documentary shot, 16:9 landscape, 9 seconds.
Use uploaded reference image as visual base.
Establish a realistic modern school administrative environment with multiple physical and digital pain points: disconnected spreadsheets on desktop monitors, open paper attendance registers, paper receipts, and scattered browser tabs.
Preserve realistic office lighting with a slight desaturated cool tone to convey operational fragmentation.
At 0:03, camera executes a smooth slow dolly forward toward the center.
A sleek, elegant kinetic pulse of deep teal light (#0D9488) gently passes across the screen, subtly dimming the background clutter and introducing clarity.
Crisp, centered, minimalist typographic overlay fades in:
"Managing a modern school is complex." (White Inter SemiBold, 0:01 to 0:04)
transitions smoothly into:
"EduPulse AI changes that." (Glowing Teal #0D9488 Inter Bold, 0:05 to 0:08).
Smooth professional camera movement, high readability, pristine text, zero visual distortion, premium EdTech aesthetic. End with a subtle forward zoom preparing for portal entry.
```
- **Negative Prompt**:
  `blurry text, oversaturated cartoon colors, chaotic camera shake, distorted hands, illegible typography, artificial lens flare.`

---

### SCENE 02 — EduPulse AI Brand & Portal Entry
- **Prompt ID**: `PROMPT_SCENE_02_EDUPULSE_BRAND_LOGIN`
- **Input Screenshot**: `shot_02_edupulse_brand_login.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Cinematic enterprise SaaS product video, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference.
Preserve the actual interface: authentic EduPulse logo mark, clean authentication card, institution dropdown, email and password input fields, and teal CTA button.
Do not redesign the interface. Do not invent buttons or features.
Camera begins with a slow, majestic cinematic push-in onto the EduPulse AI brand emblem against a dark slate (#0F172A) studio environment with soft diffuse ambient lighting.
The camera seamlessly floats forward into the web browser interface. A sleek, semi-transparent modern cursor enters from the lower right, moves smoothly to the "Sign In" button, and clicks.
The button displays a crisp micro-interaction feedback ripple in teal (#0D9488), and the portal cleanly transitions as the shell unlocks.
On-screen typography:
"EDUPULSE AI" (0:01 to 0:04, bold modern uppercase)
followed by "The Intelligent Operating System for Modern Schools" (0:04 to 0:08, clean slate-400 subtitle).
Pristine vector text, zero UI warping, studio-grade enterprise software aesthetic.
```
- **Negative Prompt**:
  `redesigned buttons, fake logos, misaligned login inputs, blurry interface, low resolution, warped text, cartoonish styling.`

---

### SCENE 03 — School Onboarding & Progressive Setup
- **Prompt ID**: `PROMPT_SCENE_03_SCHOOL_ONBOARDING`
- **Input Screenshot**: `shot_03_school_onboarding.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Professional SaaS software showcase, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the School Onboarding Center (/school-onboarding).
Preserve the actual interface exactly as designed: school profile card showing campus name "Oakridge International School", uploaded school crest logo, auto-generated school code badge "OAK-2026", verified principal credentials card, and the progressive configuration checklist steps (Academic Structure, Grade Levels, Sections, Teachers Roster, Students Register).
Do not redesign the interface. Do not invent buttons or features.
Camera executes a silky-smooth horizontal tracking shot from left to right across the onboarding workflow.
A realistic cursor hovers over the Principal Login card, highlighting the verified administrator status badge, then smoothly moves to the progressive checklist.
Checklist icons smoothly transition with a subtle emerald green checkmark animation (#059669) to show progressive readiness.
On-screen text:
"Rapid Campus Provisioning" (0:01 to 0:04)
"Progressive Setup That Grows With Your Institution" (0:05 to 0:08).
High readability, crisp labels, clean transitions, zero distorted text.
```
- **Negative Prompt**:
  `hallucinated UI cards, distorted checklist icons, blurry text, artificial dashboard stats, low-res textures, stuttering pan.`

---

### SCENE 04 — School Command Center
- **Prompt ID**: `PROMPT_SCENE_04_SCHOOL_COMMAND_CENTER`
- **Input Screenshot**: `shot_04_admin_dashboard.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
High-end SaaS product walkthrough video, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Admin Dashboard (/dashboard).
Preserve the actual interface: Welcome header banner with school name and date, the 5 Primary KPI Cards (Students: 1,240, Teachers: 84, Today's Attendance: 96.4%, Term Fee Collection: 88.2%, Operational Alerts: 3), interactive attendance bar chart, and Needs Attention operational feed.
Do not redesign the interface. Do not invent buttons or features. No fake statistics.
Camera begins with an elevated wide perspective of the full dashboard on a high-resolution display, then performs a gentle slow zoom-in toward the 5 Primary KPI cards.
A natural cursor glides across the attendance metric card, briefly hovering over the attendance trend chart to trigger a crisp tooltip reading "Today: 96.4% Present".
Subtle realistic UI lighting with soft ambient shadows beneath the cards.
On-screen text:
"School Command Center" (0:01 to 0:04)
"Students • Teachers • Attendance • Fees • Operations" (0:05 to 0:08).
Flawless text clarity, steady motion, premium enterprise aesthetic.
```
- **Negative Prompt**:
  `redesigned dashboard, imaginary charts, illegible metric numbers, morphing cards, jerky camera movement, cartoon graphics.`

---

### SCENE 05 — Student 360 Folio
- **Prompt ID**: `PROMPT_SCENE_05_STUDENT_360_FOLIO`
- **Input Screenshot**: `shot_05_student_360_modal.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Enterprise software interface animation, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Student 360 Modal (Student360Modal).
Preserve the actual interface: centered modal dialog with rounded corners, student profile header (Aarav Sharma, ADM-2024-089, Class 10-A), and the 8 distinct tabs: Overview, Academic, Attendance, Homework, Fees, Guardian, Reports, Activity.
Do not redesign the interface. Do not invent buttons or features.
Camera is positioned in a straight-on, crystal-clear focus on the modal window.
Realistic cursor interaction: cursor clicks on the "Academic" tab; the panel smoothly reveals academic grades and GPA curve; cursor then glides to click the "Attendance" tab, displaying the monthly attendance calendar heatmap; then clicks the "Fees" tab showing paid receipts and zero balance.
Tab indicator smoothly slides underneath each selected tab with genuine Flutter-like precision.
On-screen text:
"Student 360 Folio" (0:01 to 0:04)
"Academic • Attendance • Financial • Family" (0:05 to 0:08).
Crisp typography, pristine numbers, clean slate/teal theme, no blurry text.
```
- **Negative Prompt**:
  `hallucinated tabs, missing student photo, distorted text, fake student names, flashing screen, random popups, low contrast.`

---

### SCENE 06 — Teachers & Staff Ecosystem
- **Prompt ID**: `PROMPT_SCENE_06_TEACHERS_AND_STAFF`
- **Input Screenshot**: `shot_06_teachers_staff.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Premium EdTech SaaS interface showcase, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for Teachers & Staff (/teachers).
Preserve the actual interface: Top segmented filter control (All Staff, Teaching Staff, Non-Teaching Staff), search bar, and grid of faculty profile cards displaying teacher avatars, department badges (Mathematics, Science, English), designations (Senior Faculty, HOD), and Active status chips.
Do not redesign the interface. Do not invent buttons or features.
Camera executes a slow, elegant diagonal pan from the upper-left filter bar across the faculty cards.
The cursor smoothly clicks the "Teaching Staff" filter tab, causing the cards to re-filter instantaneously with a subtle fade-in animation.
The cursor then hovers over a senior faculty card, displaying class teacher assignments (Class 10-A, Class 9-B).
On-screen text:
"Faculty & Personnel Management" (0:01 to 0:04)
"Departments • Designations • Class Assignments" (0:05 to 0:08).
Professional camera movement, immaculate font rendering, realistic enterprise software responsiveness.
```
- **Negative Prompt**:
  `redesigned cards, distorted staff photos, garbled teacher names, blurry pills, erratic cursor movements, AI hallucinations.`

---

### SCENE 07 — Attendance & Geofencing
- **Prompt ID**: `PROMPT_SCENE_07_ATTENDANCE_AND_GEOFENCING`
- **Input Screenshot**: `shot_07_staff_attendance_geofence.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Modern mobile product demonstration, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Teacher App Staff Attendance screen (/staff-attendance).
Preserve the actual interface: mobile phone screen displaying "Today's Attendance", formatted date, GeofenceStatusBanner indicating "Inside Campus Boundary (Accuracy: 4m)", GPS status card with latitude/longitude, and the large teal "Check In" action button.
Do not redesign the interface. Do not invent buttons or features. Only show capabilities implemented in the application.
Framed cleanly on a high-end smartphone against a soft, tasteful modern school architectural background with shallow depth of field.
The geofence location status chip pulses emerald green (#059669).
A finger taps the "Check In" button. The button exhibits realistic tactile depression, followed by an immediate smooth transition into "Checked In at 08:14 AM" with a green verification checkmark.
On-screen text:
"Verified Location Attendance" (0:01 to 0:04)
"Configurable School Geofencing Perimeter" (0:05 to 0:08).
Crystal clear mobile UI, sharp readable text, fluid natural touch interaction.
```
- **Negative Prompt**:
  `distorted phone chassis, fake 3D holographic maps, cartoon geofences, blurry button text, glitchy tap animation, unrecognizable UI.`

---

### SCENE 08 — School Planner & Operational Coordination
- **Prompt ID**: `PROMPT_SCENE_08_SCHOOL_PLANNER`
- **Input Screenshot**: `shot_08_school_planner.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Enterprise operational software video, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the School Planner Calendar (/planner/calendar).
Preserve the actual interface: full interactive monthly calendar grid with categorized event badges (Examinations in Indigo, Teacher Leaves in Amber, Circulars in Teal, Events in Emerald), navigation bar, and daily schedule side drawer.
Do not redesign the interface. Do not invent buttons or features.
Camera begins with a slow pan across the calendar grid, highlighting operational synchronization across the school month.
Cursor navigates smoothly to an event chip titled "Term 2 Mid-Term Examination", clicks gently to open a clean popover card displaying exam timing, room assignment, and invigilator details.
On-screen text:
"School Planner" (0:01 to 0:04)
"Plan. Approve. Publish. Coordinate." (0:05 to 0:08).
Smooth professional camera glide, razor-sharp calendar grid lines, clear legible event typography.
```
- **Negative Prompt**:
  `redesigned calendar, distorted day numbers, illegible event labels, jerky camera movement, fake holographic widgets.`

---

### SCENE 09 — Fees & Financial Operations
- **Prompt ID**: `PROMPT_SCENE_09_FEES_AND_FINANCE`
- **Input Screenshot**: `shot_09_fees_management.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
High-end financial SaaS product video, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Fees Dashboard & Ledgers (/fees, /fees/ledger).
Preserve the actual interface: Collection summary metrics (Total Billed, Total Collected, Outstanding Balance), fee head allocation progress bars, and the student ledger data table with date, fee head (Tuition, Transport, Lab), debit, credit, and balance columns.
Do not redesign the interface. Do not invent buttons or features.
Camera executes a slow, steady tracking shot across the financial KPI summary down to the student ledger table.
A cursor clicks the "Record Payment" button, revealing a clean modal dialog. The cursor enters an amount, confirms allocation, and triggers the generated PDF fee receipt voucher with real-time balance update.
On-screen text:
"Connected Financial Operations" (0:01 to 0:04)
"Fee Assignment • Payments • Ledgers • Instant Receipts" (0:05 to 0:08).
Crisp numbers, transparent monetary calculations, pristine UI borders, enterprise financial clarity.
```
- **Negative Prompt**:
  `blurry numbers, fake currency symbols, distorted tables, hallucinated invoice layouts, low resolution, shaky movement.`

---

### SCENE 10 — Payroll & Expenses
- **Prompt ID**: `PROMPT_SCENE_10_PAYROLL_AND_EXPENSES`
- **Input Screenshot**: `shot_10_payroll_expenses.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Institutional administrative software showcase, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for Staff Salaries & Expenses (/fees/salaries, /fees/expenses).
Preserve the actual interface: Monthly staff payroll table with columns for Staff Name, Staff Code, Base Salary, Allowances, Deductions, Net Salary, and Payment Status (green PAID chip, amber PENDING chip); adjacent expenses overview card with categorized campus disbursements.
Do not redesign the interface. Do not invent buttons or features.
Camera performs a gentle vertical scroll down the payroll register, showcasing clean mathematical breakdown across faculty members.
The cursor hovers over a Net Salary figure, highlighting the transparent deduction and allowance tooltips.
On-screen text:
"Institutional Payroll & Expense Tracking" (0:01 to 0:04)
"Base Salary • Allowances • Deductions • Net Calculations" (0:05 to 0:08).
Smooth scrolling, high readability, steady exposure, authentic SaaS aesthetic.
```
- **Negative Prompt**:
  `inaccurate payroll columns, morphing spreadsheet cells, blurry text, distorted status badges, jittery scroll, AI artifacts.`

---

### SCENE 11 — Data Imports Wizard
- **Prompt ID**: `PROMPT_SCENE_11_DATA_IMPORTS_WIZARD`
- **Input Screenshot**: `shot_11_imports_wizard.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Technical enterprise SaaS product walkthrough, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Bulk Import Screen (/bulk-import).
Preserve the actual interface: File upload area displaying the uploaded file "Oakridge_Students_2026.xlsx", column schema mapping dropdowns (Source Column mapped to EduPulse Field), and tabular live preview table with validation badges (100% Validated, 0 Schema Errors).
Do not redesign the interface. Do not invent buttons or features.
Camera glides horizontally across the column mapping controls down into the live validated data preview.
A smooth cursor maps the final column "Admission Number" via a clean dropdown, causing the validation progress indicator to fill smoothly to 100% green.
The teal "Execute Import" button activates with a subtle pulse.
On-screen text:
"Flexible Data Imports" (0:01 to 0:04)
"Excel & CSV • Schema Mapping • Pre-Import Validation" (0:05 to 0:08).
Pristine grid lines, crystal clear text in every table cell, smooth camera translation.
```
- **Negative Prompt**:
  `warped spreadsheet cells, unreadable headers, distorted dropdown menus, low resolution, messy UI elements.`

---

### SCENE 12 — Reports & Institutional Analytics
- **Prompt ID**: `PROMPT_SCENE_12_REPORTS_AND_ANALYTICS`
- **Input Screenshot**: `shot_12_reports_analytics.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Cinematic business intelligence SaaS animation, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Reports & Analytics Dashboard (/reports).
Preserve the actual interface: 5 Category Tabs (Executive Overview, Academic, Examinations, Attendance, Fees), academic performance bell curve, attendance trends bar chart, and export action bar (Download PDF, Export Excel).
Do not redesign the interface. Do not invent buttons or features. No fake statistics.
Camera begins with a slight 3D perspective tilt across the analytics dashboard, then pans smoothly across the academic metrics.
A cursor gently hovers over the class grade distribution chart, triggering an elegant data tooltip showing average GPA and pass rate.
Cursor then moves to the "Export Report" button with a crisp hover state.
On-screen text:
"Executive Analytics & Reports" (0:01 to 0:04)
"Actionable Operational & Academic Insights" (0:05 to 0:08).
Crisp vector chart lines, vibrant yet professional colors (Teal #0D9488, Slate #0F172A, Amber #D97706), razor-sharp text.
```
- **Negative Prompt**:
  `blurry charts, illegible data axes, distorted labels, hallucinatory graphs, erratic rotation, oversaturated colors.`

---

### SCENE 13 — Teacher Mobile App
- **Prompt ID**: `PROMPT_SCENE_13_TEACHER_MOBILE_APP`
- **Input Screenshot**: `shot_13_teacher_app.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Mobile product commercial video, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Teacher App Home Screen (/home).
Preserve the actual interface: smartphone screen showing greeting "Good morning, Mrs. Priya Rao", today's class schedule card ("Grade 10-A Mathematics - 09:30 AM"), quick action shortcuts (Mark Attendance, New Homework, Enter Marks), and recent announcements.
Do not redesign the interface. Do not invent buttons or features.
Camera shows a modern educator's perspective holding the phone in portrait orientation within a naturally lit classroom background with subtle bokeh.
A natural finger tap touches the "New Homework" card. The card opens into a clean modal with subject, class selection, due date picker, and file attachment preview.
On-screen text:
"EduPulse Teacher App" (0:01 to 0:04)
"Daily Timetable • Quick Attendance • Homework • Marks" (0:05 to 0:08).
Flawless mobile UI rendering, natural realistic finger gestures, sharp typography, premium mobile application styling.
```
- **Negative Prompt**:
  `distorted hand, unnatural finger movement, warped smartphone screen, low-res interface, fake mobile OS chrome.`

---

### SCENE 14 — Parent Mobile App
- **Prompt ID**: `PROMPT_SCENE_14_PARENT_MOBILE_APP`
- **Input Screenshot**: `shot_14_parent_app.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Mobile product commercial video, 16:9 landscape, 9 seconds.
Use uploaded EduPulse screenshot as exact UI reference for the Parent App Dashboard (/dashboard).
Preserve the actual interface: mobile phone screen showing child profile header ("Aarav Sharma - Class 10-A"), 4 summary metric tiles (Attendance: 97%, Due Fees: ₹0, Pending Homework: 1, Grade: A+), quick actions, and recent circular feed.
Do not redesign the interface. Do not invent buttons or features.
Camera captures a smooth 3D orbiting glide around a premium smartphone.
A finger taps on the "Attendance" metric tile, smoothly expanding the interactive daily timeline showing verified arrival time and class attendance status.
A gentle tap on "Pay Fees" displays instant payment confirmation and zero outstanding dues.
On-screen text:
"EduPulse Parent App" (0:01 to 0:04)
"Real-Time Attendance • Homework • Instant Fee Pay • Progress" (0:05 to 0:08).
Crystal clear fonts, vibrant authentic UI colors, warm natural ambient lighting, enterprise EdTech quality.
```
- **Negative Prompt**:
  `blurry numbers, distorted phone frame, unnatural touch interactions, fake interface widgets, low contrast.`

---

### SCENE 15 — Unified Multi-Role Ecosystem
- **Prompt ID**: `PROMPT_SCENE_15_UNIFIED_ECOSYSTEM`
- **Input Screenshot**: `shot_15_connected_ecosystem.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Cinematic technology ecosystem commercial, 16:9 landscape, 9 seconds.
Use uploaded composite reference screenshot showing EduPulse across multiple real devices: Admin Web Portal on a 27-inch desktop monitor, Principal App on a tablet, Teacher App on a smartphone, and Parent App on a smartphone.
Preserve the actual interfaces on each device. Do not redesign any screen. Do not invent buttons or features.
Camera begins with a slow, cinematic pull-back in an elegant modern school environment, bringing all four synchronized screens into harmonious 3D perspective.
Subtle, elegant glowing teal data connection streams (#0D9488) rhythmically pulse between the desktop portal and mobile devices, visually conveying real-time institutional synchronization.
On-screen text:
"One Connected Ecosystem" (0:01 to 0:04)
"Admin • Principal • Teachers • Parents • Students" (0:05 to 0:08).
Studio-grade lighting, crisp screen contents across all devices, inspiring technology harmony.
```
- **Negative Prompt**:
  `distorted device screens, warped monitors, disconnected gadgets, blurry text on displays, chaotic lighting, low resolution.`

---

### SCENE 16 — Finale & Strategic Brand Vision
- **Prompt ID**: `PROMPT_SCENE_16_FINALE_AND_VISION`
- **Input Screenshot**: `shot_16_edupulse_finale_logo.png`
- **Clip Duration**: 9 Seconds
- **Aspect Ratio**: 16:9 Landscape

```text
Cinematic brand finale video, 16:9 landscape, 9 seconds.
Use uploaded official EduPulse logo as exact graphic reference.
Preserve the exact EduPulse brand emblem and color values (Teal #0D9488, Deep Teal #0F766E, Crisp White).
The EduPulse AI emblem is centered on an immaculate deep slate canvas (#0F172A) with a gentle volumetric light sweep casting soft teal reflections across the contours of the logo.
Camera executes a majestic, slow cinematic zoom toward the emblem.
Typographic text animates in with pristine tracking and elegance:
"EDUPULSE AI" (0:01 to 0:03, bold uppercase Inter)
"The Intelligent Operating System for Modern Schools" (0:03 to 0:06, clean subheader)
"Manage. Connect. Analyze. Grow." (0:06 to 0:09, glowing accent pillars).
Smooth slow-motion push, high contrast, immaculate typography, concluding with an elegant fade to black.
```
- **Negative Prompt**:
  `distorted logo mark, misspelled company name, jagged edges, low resolution, cheap 3D beveling, flashing artifacts.`
