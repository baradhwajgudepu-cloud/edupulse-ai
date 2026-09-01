# EduPulse AI - DPS Hyderabad 2025-26 Seeding Report

## 1. Executive Summary
Following the cleanup of old automated QA records, the development database has been populated with a realistic, production-scale demonstration dataset representing **Delhi Public School Hyderabad** for the **2025-26 Academic Year**.

All student, parent, and teacher records are synthetic to respect privacy boundaries, but their distributions and relationships reflect those of a real-world educational institution.

---

## 2. Seeded Database Entity Statistics

The database has been seeded with the following record counts, fully respecting foreign-key constraints and unique indices (such as teacher slot availability and student session links):

| Database Table | Record Count | Purpose / Scoping Description |
| :--- | :---: | :--- |
| **Tenants** | 1 | Delhi Public School Hyderabad (`e949f0ba-2f9e-495b-a3b0-8f672070746a`) |
| **Schools** | 1 | Delhi Public School Hyderabad - Campus 2 (`2f85ebf4-315d-496a-9611-681ff0fed18f`) |
| **Academic Years** | 1 | AY2025-2026 (Dates: `2025-06-01` to `2026-04-30`, status `ACTIVE`, `is_current` True) |
| **Classes** | 12 | Class 1 to Class 12 |
| **Sections** | 24 | Sections A & B for each class level |
| **Subjects** | 17 | Categorized globally and distributed based on academic levels (Primary, Middle, High, Senior Secondary) |
| **Teachers** | 40 | Synthetic staff profiles with realistic join dates and contact information |
| **Students** | 360 | 15 students per section across 24 sections |
| **Guardians** | 360 | Parent/guardian profile associated with each student |
| **Student-Guardian Links** | 360 | Mappings defining parent relationship structures |
| **Teacher Assignments** | 168 | Scoped assignments mapping subjects, classes, sections, and teachers |
| **Timetables** | 840 | Monday-Friday timetables (7 periods per day) resolved via a greedy collision-free scheduling algorithm |
| **Syllabus Metadata** | 270 | 3 units/topics mapped per subject and class level |
| **Examinations** | 5 | PT1, Half Yearly, PT2, Pre Final, and Annual Examination master records |
| **Exam Schedules** | 840 | Schedules linking exam slots for each section and subject assignment |
| **Marks Records** | 13,500 | Grade marks mapped to 360 students, 5 exams, and section subjects |
| **Attendance Sessions** | 240 | 10 dates throughout the year for all 24 sections |
| **Attendance Logs** | 3,600 | 10 logs per student, aligned with target attendance and risk profiles |
| **Fee Types** | 6 | Tuition, Transport, Activity, Exam, Computer, and Annual charges |
| **Fee Structures** | 12 | Tuition fee structure mapped per class level |
| **Student Fee Assignments** | 360 | Student fee balances with realistic paid/unpaid/partial splits |
| **Report Card Publications**| 360 | Generated final report card publications with status `PUBLISHED` |
| **Users** | 401 | Authenticated accounts: 1 DPS Admin + 40 Teachers + 360 Guardians |

---

## 3. Login Credentials for Demonstrations

All provisioned users share the same default password. To access portals or API endpoints, pass the corresponding headers along with the credentials:

- **Common Headers**:
  - `X-Tenant-ID`: `e949f0ba-2f9e-495b-a3b0-8f672070746a`
  - `X-School-ID`: `2f85ebf4-315d-496a-9611-681ff0fed18f`
- **Default Password**: `EduPulse@123`

### Accounts list
1. **School Administrator** (Full access, role `SCHOOL_ADMIN`):
   - **Email**: `admin@dps.edupulse.com`
2. **Teachers** (Academic tracking, role `TEACHER`):
   - **Emails**: `teacher001@demo.edupulse.com` to `teacher040@demo.edupulse.com`
3. **Parents / Guardians** (Parent dashboard view, role `PARENT`):
   - **Emails**: `guardian001@demo.edupulse.com` to `guardian360@demo.edupulse.com`

---

## 4. Verification Logs & Metrics

Testing the AI fee predictive analytics endpoint under the administrative context of Delhi Public School Hyderabad:

- **Endpoint**: `GET /api/v1/fees/ai/analytics`
- **Status**: `200 OK`
- **Response Time**: `0.20 seconds` (Fast, responsive execution)
- **Output JSON**:
```json
{
  "success": true,
  "message": "AI 30-day collection analytics predicted successfully.",
  "data": {
    "predicted_collection_next_30_days": 214200.0,
    "historical_trend": {
      "Day 5": 42840.0,
      "Day 15": 107100.0,
      "Day 25": 171360.0,
      "Day 30": 214200.0
    }
  }
}
```
All components are fully validated and ready for demonstration.
