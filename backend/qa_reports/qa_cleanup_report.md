# EduPulse AI - QA Cleanup Inventory Report

This report documents all automated QA test records identified in the database that were created by previous automated release-test harness runs. These records will be removed to prepare the environment for the Delhi Public School Hyderabad demonstration dataset.

---

## 1. Inventory to be Removed

| Record Type | Found Count | Criteria / Filter |
| :--- | :--- | :--- |
| **Tenants** | 17 | `name LIKE 'AUTO Tenant%'` or `code LIKE 'edupulse-auto%'` |
| **Schools** | 17 | Scoped under AUTO Tenants or `name LIKE 'AUTO School%'` |
| **Users** | 42 | Linked to AUTO Tenant IDs or email starting with `auto-` / `auto_` |
| **Academic Years** | 11 | Scoped under AUTO Tenants / Schools |
| **Classes** | 28 | Scoped under AUTO Tenants / Schools |
| **Sections** | 28 | Scoped under AUTO Tenants / Schools |
| **Subjects** | 22 | Scoped under AUTO Tenants / Schools |
| **Teachers** | 22 | Scoped under AUTO Tenants / Schools |
| **Teacher Assignments** | 10 | Scoped under AUTO Tenants / Schools |
| **Guardians** | 20 | Scoped under AUTO Tenants / Schools |
| **Students** | 50 | Scoped under AUTO Tenants / Schools |
| **Student-Guardian Links** | 0 | Scoped under AUTO Tenants / Schools |
| **Timetables** | 10 | Scoped under AUTO Tenants / Schools |
| **Syllabuses** | 9 | Scoped under AUTO Tenants / Schools |
| **Examinations** | 8 | Scoped under AUTO Tenants / Schools |
| **Exam Schedules** | 8 | Scoped under AUTO Tenants / Schools |
| **Marks** | 0 | Scoped under AUTO Tenants / Schools |
| **Report Card Publications** | 0 | Scoped under AUTO Tenants / Schools |
| **Attendance Sessions** | 9 | Scoped under AUTO Schools |
| **Attendance Records** | 0 | Scoped under AUTO Tenants / Schools |
| **Fee Types** | 8 | Scoped under AUTO Tenants |
| **Fee Structures** | 8 | Scoped under AUTO Tenants / Schools |
| **Student Fee Assignments** | 8 | Scoped under AUTO Tenants / Schools |
| **Fee Payments** | 0 | Scoped under AUTO Tenants / Schools |
| **Fee Payment Allocations** | 0 | Scoped under AUTO Tenants / Schools |
| **Import Jobs** | 12 | Scoped under AUTO Tenants |
| **Import Job Rows** | 12 | Scoped under AUTO Tenants |
| **Student Import Rows** | 0 | Scoped under AUTO Tenants |
| **Academic Setup Import Rows**| 12 | Scoped under AUTO Tenants |

---

## 2. Proposed Deletion Order

To fully respect foreign-key constraints and prevent referential integrity violations, the deletion script will execute in the following sequential order:

1. `report_card_publications`
2. `marks`
3. `attendance_records` / `attendances`
4. `attendance_sessions`
5. `student_guardians`
6. `student_fee_assignments`
7. `fee_payment_allocations`
8. `fee_payments`
9. `fee_structures`
10. `fee_types`
11. `students`
12. `guardians`
13. `timetables`
14. `teacher_subject_assignments`
15. `teachers`
16. `syllabuses`
17. `exam_schedules`
18. `examinations`
19. `student_import_rows`
20. `academic_setup_import_rows`
21. `import_job_rows`
22. `import_jobs`
23. `sections`
24. `classes`
25. `academic_years`
26. `users` (specifically associated with the 17 AUTO tenants)
27. `schools`
28. `tenants`
