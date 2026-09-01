# EduPulse AI — School Onboarding Workbook Specification

This document defines the exact field-by-field reverse-engineered specification for the EduPulse AI School Onboarding workflow in the Admin Portal (`apps/admin_portal`). Every widget is mapped directly to its underlying PostgreSQL database tables and API DTO representations.

---

## Widget 1 — School Information

* **UI Screen / Step**: 1. School Information
* **Worksheet Name / Key**: `school`
* **Target REST Endpoint**: `POST /api/v1/schools`
* **Primary Database Table**: `schools`
* **Composite Keys & Uniqueness**: `schools.code` per tenant

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| School Code | `school_code` / `code` | Yes | String | `school_code` | `schools.code` | Alphanumeric (e.g., `SCH001`) | `s.code AS school_code` |
| School Name | `school_name` / `name` | Yes | String | `school_name` | `schools.name` | Text string | `s.name AS school_name` |
| Board | `board` | Yes | String | `board` | `schools.board` | `CBSE`, `ICSE`, `SSC`, `STATE`, `IB`, `IGCSE`, `CAMBRIDGE`, `OTHER` | `s.board::text AS board` |
| School Type | `school_type` | Yes | String | `school_type` | `schools.school_type` | `PRIMARY`, `HIGH_SCHOOL`, `JR_COLLEGE`, `DEGREE_COLLEGE`, `UNIVERSITY`, `OTHER` | `s.school_type::text AS school_type` |
| Email | `email` | Yes | String | `email` | `schools.email` | Valid email format | `s.email AS email` |
| Phone | `phone` | Yes | String | `phone` | `schools.phone` | Phone number string | `s.phone AS phone` |
| Status | `status` | Yes | String | `status` | `schools.status` | `ACTIVE`, `INACTIVE`, `SUSPENDED` | `s.status::text AS status` |
| Address | `address` | No | String | `address` | `schools.address` | Text string | `s.address AS address` |
| City | `city` | No | String | `city` | `schools.city` | Text string | `s.city AS city` |
| State | `state` | No | String | `state` | `schools.state` | Text string | `s.state AS state` |
| Postal Code | `postal_code` | No | String | `postal_code` | `schools.postal_code` | Alphanumeric / PIN digits | `s.postal_code AS postal_code` |

---

## Widget 2 — Academic Structure

* **UI Screen / Step**: 2. Academic Structure
* **Worksheet Name / Key**: `academic_years`
* **Target REST Endpoint**: `POST /api/v1/schools/{school_id}/academic-years`
* **Primary Database Table**: `academic_years`
* **Required Joins**: `schools ON academic_years.school_id = schools.id`
* **Foreign Key Dependencies**: `School (school_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| School Code | `school_code` | Yes | String | `school_code` | `schools.code` | Valid parent school code | `s.code AS school_code` |
| Academic Year Code | `academic_year_code` / `code` | Yes | String | `academic_year_code` | `academic_years.code` | Pattern `^AY[0-9]{4}(?:-[0-9]{4})?$` (e.g. `AY2025-2026`) | `ay.code AS academic_year_code` |
| Academic Year Name | `academic_year_name` / `name` | Yes | String | `academic_year_name` | `academic_years.name` | Display label (e.g. `Academic Year 2025-2026`) | `ay.name AS academic_year_name` |
| Start Date | `start_date` | Yes | Date | `start_date` | `academic_years.start_date` | `YYYY-MM-DD` | `TO_CHAR(ay.start_date, 'YYYY-MM-DD') AS start_date` |
| End Date | `end_date` | Yes | Date | `end_date` | `academic_years.end_date` | `YYYY-MM-DD` | `TO_CHAR(ay.end_date, 'YYYY-MM-DD') AS end_date` |
| Status | `status` | Yes | String | `status` | `academic_years.status` | `UPCOMING`, `ACTIVE`, `COMPLETED`, `ARCHIVED` | `ay.status::text AS status` |
| Is Current | `is_current` | Yes | Boolean | `is_current` | `academic_years.is_current` | `true`, `false` | `CASE WHEN ay.is_current THEN 'true' ELSE 'false' END AS is_current` |

---

## Widget 3 — Grade Levels (Classes)

* **UI Screen / Step**: 3. Grade Levels (Classes)
* **Worksheet Name / Key**: `classes`
* **Target REST Endpoint**: `POST /api/v1/classes`
* **Primary Database Table**: `classes`
* **Required Joins**: `academic_years ON classes.academic_year_id = academic_years.id`, `schools ON classes.school_id = schools.id`
* **Foreign Key Dependencies**: `Academic Year (academic_year_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Parent academic session code | `ay.code AS academic_year_code` |
| Class Code | `class_code` / `code` | Yes | String | `class_code` | `classes.code` | Alphanumeric (e.g., `C5`, `C6`, `GRADE_10`) | `c.code AS class_code` |
| Display Label | `display_label` / `name` | Yes | String | `display_label` | `classes.name` | Display title (e.g., `Class 5`, `Grade 10`) | `c.name AS display_label` |
| Level | `level` | Yes | Integer | `level` | `classes.level` | Positive integer (e.g., `5`, `6`, `10`) | `c.level::text AS level` |
| Grade Category | `grade_category` / `category` | Yes | String | `grade_category` | `classes.category` | `PRE_PRIMARY`, `PRIMARY`, `MIDDLE`, `HIGH`, `HIGHER_SECONDARY`, `OTHER` | `c.category::text AS grade_category` |
| Max Capacity | `max_capacity` / `capacity` | Yes | Integer | `max_capacity` | `classes.capacity` | Positive integer (e.g., `40`, `60`) | `c.capacity::text AS max_capacity` |
| Status | `status` | Yes | String | `status` | `classes.status` | `ACTIVE`, `INACTIVE`, `ARCHIVED` | `c.status::text AS status` |

---

## Widget 4 — Sections & Rooms

* **UI Screen / Step**: 4. Sections & Rooms
* **Worksheet Name / Key**: `sections`
* **Target REST Endpoint**: `POST /api/v1/sections`
* **Primary Database Table**: `sections`
* **Required Joins**: `classes ON sections.class_id = classes.id`, `academic_years ON sections.academic_year_id = academic_years.id`
* **Foreign Key Dependencies**: `Class (class_code)`, `Academic Year (academic_year_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Class Code | `class_code` | Yes | String | `class_code` | `classes.code` | Parent class code | `c.code AS class_code` |
| Section Code | `section_code` / `code` | Yes | String | `section_code` | `sections.code` | Alphanumeric (e.g., `A`, `B`, `SEC_A`) | `sec.code AS section_code` |
| Section Name | `section_name` / `name` | Yes | String | `section_name` | `sections.name` | Display title (e.g., `Section A`) | `sec.name AS section_name` |
| Capacity | `capacity` | Yes | Integer | `capacity` | `sections.capacity` | Positive integer (e.g., `30`, `35`) | `sec.capacity::text AS capacity` |
| Room Number | `room_number` | Yes | String | `room_number` | `sections.room_number` | Alphanumeric room code (e.g., `101`, `R-204`) | `COALESCE(sec.room_number, '') AS room_number` |
| Display Sort Order | `display_sort_order` / `sort_order` | Yes | Integer | `display_sort_order` | `sections.sort_order` | Positive integer (`1`, `2`, `3`) | `sec.sort_order::text AS display_sort_order` |
| Status | `status` | Yes | String | `status` | `sections.status` | `ACTIVE`, `INACTIVE` | `sec.status::text AS status` |
| Academic Year Code | `academic_year_code` | No (Supported) | String | `academic_year_code` | `academic_years.code` | Academic session code | `ay.code AS academic_year_code` |

---

## Widget 5 — Subjects Catalog

* **UI Screen / Step**: 5. Subjects Catalog
* **Worksheet Name / Key**: `subjects`
* **Target REST Endpoint**: `POST /api/v1/subjects`
* **Primary Database Table**: `subjects`
* **Required Joins**: `academic_years ON subjects.academic_year_id = academic_years.id`
* **Foreign Key Dependencies**: `Academic Year (academic_year_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Subject Code | `subject_code` | Yes | String | `subject_code` | `subjects.subject_code` | Unique alphanumeric code (e.g., `MATH101`, `ENG05`) | `sub.subject_code AS subject_code` |
| Subject Name | `subject_name` | Yes | String | `subject_name` | `subjects.subject_name` | Display title (e.g., `Mathematics`) | `sub.subject_name AS subject_name` |
| Category | `category` | Yes | String | `category` | `subjects.category` | `CORE`, `ELECTIVE`, `LANGUAGE`, `OPTIONAL`, `LAB`, `SPORTS`, `ARTS`, `CO_CURRICULAR` | `sub.category::text AS category` |
| Subject Type | `subject_type` | Yes | String | `subject_type` | `subjects.subject_type` | `THEORY`, `PRACTICAL`, `THEORY_PRACTICAL` | `sub.subject_type::text AS subject_type` |
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Parent academic session code | `ay.code AS academic_year_code` |
| Theory Marks | `theory_marks` | No | Integer | `theory_marks` | `subjects.theory_marks` | `0` to `100` | `COALESCE(sub.theory_marks::text, '') AS theory_marks` |
| Practical Marks | `practical_marks` | No | Integer | `practical_marks` | `subjects.practical_marks` | `0` to `100` | `COALESCE(sub.practical_marks::text, '') AS practical_marks` |
| Pass Marks | `pass_marks` | No | Integer | `pass_marks` | `subjects.pass_marks` | Positive integer (e.g., `33`, `35`) | `COALESCE(sub.pass_marks::text, '') AS pass_marks` |
| Credit Hours | `credit_hours` | No | Integer | `credit_hours` | `subjects.credit_hours` | Positive integer (e.g., `4`) | `COALESCE(sub.credit_hours::text, '') AS credit_hours` |
| Weekly Periods | `weekly_periods` | No | Integer | `weekly_periods` | `subjects.weekly_periods` | Positive integer (e.g., `4`, `5`) | `COALESCE(sub.weekly_periods::text, '') AS weekly_periods` |
| Display Order | `display_order` | No | Integer | `display_order` | `subjects.display_order` | Positive integer | `COALESCE(sub.display_order::text, '') AS display_order` |

---

## Widget 6 — Teachers Roster

* **UI Screen / Step**: 6. Teachers Roster
* **Worksheet Name / Key**: `teachers`
* **Target REST Endpoint**: `POST /api/v1/teachers`
* **Primary Database Table**: `teachers`
* **Required Joins**: `schools ON teachers.school_id = schools.id`
* **Foreign Key Dependencies**: `School (school_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Teacher Code | `teacher_code` / `staff_code` | Yes | String | `teacher_code` | `teachers.staff_code` | Alphanumeric (e.g., `TCH001`, `EMP101`) | `t.staff_code AS teacher_code` |
| First Name | `first_name` | Yes | String | `first_name` | `teachers.first_name` | Legal first name | `t.first_name AS first_name` |
| Last Name | `last_name` | Yes | String | `last_name` | `teachers.last_name` | Legal last name | `t.last_name AS last_name` |
| Gender | `gender` | Yes | String | `gender` | `teachers.gender` | `MALE`, `FEMALE`, `OTHER` | `t.gender::text AS gender` |
| Date of Birth | `date_of_birth` | Yes | Date | `date_of_birth` | `teachers.date_of_birth` | `YYYY-MM-DD` | `TO_CHAR(t.date_of_birth, 'YYYY-MM-DD') AS date_of_birth` |
| Mobile | `mobile` | Yes | String | `mobile` | `teachers.mobile` | 10-digit mobile number | `t.mobile AS mobile` |
| Email | `email` / `official_email` | Yes | String | `email` | `teachers.official_email` | Official email address | `t.official_email AS email` |
| Employee Code | `employee_code` | Yes | String | `employee_code` | `teachers.employee_code` | Payroll/HR code | `t.employee_code AS employee_code` |
| Designation | `designation` | Yes | String | `designation` | `teachers.designation` | `PRT`, `TGT`, `PGT`, `HOD`, `PRINCIPAL` | `COALESCE(t.designation, 'TGT') AS designation` |
| Joining Date | `joining_date` | Yes | Date | `joining_date` | `teachers.joining_date` | `YYYY-MM-DD` | `TO_CHAR(t.joining_date, 'YYYY-MM-DD') AS joining_date` |
| Status | `status` | Yes | String | `status` | `teachers.status` | `ACTIVE`, `INACTIVE`, `ON_LEAVE`, `RETIRED` | `t.status::text AS status` |
| Middle Name | `middle_name` | No | String | `middle_name` | `teachers.middle_name` | Optional middle name | `COALESCE(t.middle_name, '') AS middle_name` |
| Employment Type | `employment_type` | No | String | `employment_type` | `teachers.employment_type` | `FULL_TIME`, `PART_TIME`, `CONTRACT`, `VISITING` | `COALESCE(t.employment_type::text, '') AS employment_type` |

---

## Widget 7 — Parents & Guardians

* **UI Screen / Step**: 7. Parents & Guardians
* **Worksheet Name / Key**: `guardians`
* **Target REST Endpoint**: `POST /api/v1/guardians`
* **Primary Database Table**: `guardians`
* **Required Joins**: `schools ON guardians.school_id = schools.id`
* **Foreign Key Dependencies**: `School (school_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Guardian Code | `guardian_code` | Yes | String | `guardian_code` | Derived / `guardians.id` | Alphanumeric (e.g., `GRD001`, `PAR001`) | `COALESCE(g.settings->>'guardian_code', 'GRD' || LPAD(g.id::text, 6, '0')) AS guardian_code` |
| First Name | `first_name` | Yes | String | `first_name` | `guardians.first_name` | Given name | `g.first_name AS first_name` |
| Last Name | `last_name` | Yes | String | `last_name` | `guardians.last_name` | Family name | `g.last_name AS last_name` |
| Gender | `gender` | Yes | String | `gender` | `guardians.gender` | `MALE`, `FEMALE`, `OTHER` | `g.gender::text AS gender` |
| Date of Birth | `date_of_birth` | Yes | Date | `date_of_birth` | `guardians.date_of_birth` | `YYYY-MM-DD` | `TO_CHAR(g.date_of_birth, 'YYYY-MM-DD') AS date_of_birth` |
| Mobile | `mobile` | Yes | String | `mobile` | `guardians.mobile` | 10-digit mobile number | `g.mobile AS mobile` |
| Email | `email` | Yes | String | `email` | `guardians.email` | Valid email address | `COALESCE(g.email, '') AS email` |
| Guardian Type | `guardian_type` | Yes | String | `guardian_type` | `guardians.guardian_type` | `FATHER`, `MOTHER`, `LEGAL_GUARDIAN`, `GRANDPARENT`, `UNCLE`, `AUNT`, `OTHER` | `g.guardian_type::text AS guardian_type` |
| Status | `status` | Yes | String | `status` | `guardians.status` | `ACTIVE`, `INACTIVE` | `g.status::text AS status` |

---

## Widget 8 — Students Register

* **UI Screen / Step**: 8. Students Register
* **Worksheet Name / Key**: `students`
* **Target REST Endpoint**: `POST /api/v1/students`
* **Primary Database Table**: `students`
* **Required Joins**: `academic_years ON students.academic_year_id = academic_years.id`, `classes ON students.class_id = classes.id`, `sections ON students.section_id = sections.id`
* **Foreign Key Dependencies**: `Academic Year (academic_year_code)`, `Class (class_code)`, `Section (section_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Admission Number | `admission_number` | Yes | String | `admission_number` | `students.admission_number` | Unique admission number (e.g. `ADM2025001`) | `stu.admission_number AS admission_number` |
| First Name | `first_name` | Yes | String | `first_name` | `students.first_name` | Student given name | `stu.first_name AS first_name` |
| Last Name | `last_name` | Yes | String | `last_name` | `students.last_name` | Student family name | `stu.last_name AS last_name` |
| Gender | `gender` | Yes | String | `gender` | `students.gender` | `MALE`, `FEMALE`, `OTHER` | `stu.gender::text AS gender` |
| Date of Birth | `date_of_birth` | Yes | Date | `date_of_birth` | `students.date_of_birth` | `YYYY-MM-DD` | `TO_CHAR(stu.date_of_birth, 'YYYY-MM-DD') AS date_of_birth` |
| Admission Date | `admission_date` | Yes | Date | `admission_date` | `students.admission_date` | `YYYY-MM-DD` | `TO_CHAR(stu.admission_date, 'YYYY-MM-DD') AS admission_date` |
| Roll Number | `roll_number` | Yes | Integer | `roll_number` | `students.roll_number` | Positive integer (e.g. `1`, `24`) | `stu.roll_number AS roll_number` |
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Active session code | `ay.code AS academic_year_code` |
| Class Code | `class_code` | Yes | String | `class_code` | `classes.code` | Enrolled grade level | `c.code AS class_code` |
| Section Code | `section_code` | Yes | String | `section_code` | `sections.code` | Enrolled section | `sec.code AS section_code` |
| Status | `status` | Yes | String | `status` | `students.status` | `ACTIVE`, `INACTIVE`, `SUSPENDED`, `WITHDRAWN`, `ALUMNI` | `stu.status::text AS status` |

---

## Widget 9 — Student-Guardian Links

* **UI Screen / Step**: 9. Student-Guardian Links
* **Worksheet Name / Key**: `student_guardians`
* **Target REST Endpoint**: `POST /api/v1/student-guardians`
* **Primary Database Table**: `student_guardians`
* **Required Joins**: `students ON student_guardians.student_id = students.id`, `guardians ON student_guardians.guardian_id = guardians.id`
* **Foreign Key Dependencies**: `Student (admission_number)`, `Guardian (guardian_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Admission Number | `admission_number` / `student_id` | Yes | String | `admission_number` | `students.admission_number` | Valid student admission number | `stu.admission_number AS admission_number` |
| Guardian Code | `guardian_code` / `guardian_id` | Yes | String | `guardian_code` | Derived / `guardians.id` | Valid guardian code | `COALESCE(g.settings->>'guardian_code', 'GRD' || LPAD(g.id::text, 6, '0')) AS guardian_code` |
| Relationship | `relationship` | Yes | String | `relationship` | `student_guardians.relationship` | `FATHER`, `MOTHER`, `GUARDIAN`, `GRANDPARENT`, `RELATIVE`, `OTHER` | `sg.relationship::text AS relationship` |
| Is Primary | `is_primary` | Yes | Boolean | `is_primary` | `student_guardians.is_primary` | `true`, `false`, `yes`, `no` | `CASE WHEN sg.is_primary THEN 'true' ELSE 'false' END AS is_primary` |
| Authorized For Pickup | `authorized_for_pickup` | Yes | Boolean | `authorized_for_pickup` | `student_guardians.authorized_for_pickup` | `true`, `false`, `yes`, `no` | `CASE WHEN sg.authorized_for_pickup THEN 'true' ELSE 'false' END AS authorized_for_pickup` |
| Receives Notifications | `receives_notifications` | Yes | Boolean | `receives_notifications` | `student_guardians.receives_notifications` | `true`, `false`, `yes`, `no` | `CASE WHEN sg.receives_notifications THEN 'true' ELSE 'false' END AS receives_notifications` |

---

## Widget 10 — Teacher Assignments

* **UI Screen / Step**: 10. Teacher Assignments
* **Worksheet Name / Key**: `teacher_assignments`
* **Target REST Endpoint**: `POST /api/v1/teacher-subject-assignments`
* **Primary Database Table**: `teacher_subject_assignments`
* **Required Joins**: `teachers`, `subjects`, `classes`, `sections`, `academic_years`
* **Foreign Key Dependencies**: `Teacher (teacher_code)`, `Subject (subject_code)`, `Class (class_code)`, `Section (section_code)`, `Academic Year (academic_year_code)`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Teacher Code | `teacher_code` | Yes | String | `teacher_code` | `teachers.staff_code` | Assigned teacher code | `t.staff_code AS teacher_code` |
| Subject Code | `subject_code` | Yes | String | `subject_code` | `subjects.subject_code` | Assigned subject code | `sub.subject_code AS subject_code` |
| Class Code | `class_code` | Yes | String | `class_code` | `classes.code` | Assigned class code | `c.code AS class_code` |
| Section Code | `section_code` | Yes | String | `section_code` | `sections.code` | Assigned section code | `sec.code AS section_code` |
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Active session code | `ay.code AS academic_year_code` |
| Assignment Type | `assignment_type` | No | String | `assignment_type` | `teacher_subject_assignments.assignment_type` | `PRIMARY`, `SECONDARY`, `SUBSTITUTE` | `tsa.assignment_type::text AS assignment_type` |
| Weekly Periods | `weekly_periods` | No | Integer | `weekly_periods` | `teacher_subject_assignments.weekly_periods` | Positive integer (e.g., `4`, `6`) | `tsa.weekly_periods::text AS weekly_periods` |
| Effective From | `effective_from` | No | Date | `effective_from` | `teacher_subject_assignments.effective_from` | `YYYY-MM-DD` | `TO_CHAR(tsa.effective_from, 'YYYY-MM-DD') AS effective_from` |

---

## Widget 11 — Timetable Slots

* **UI Screen / Step**: 11. Timetable Slots
* **Worksheet Name / Key**: `timetable`
* **Target REST Endpoint**: `POST /api/v1/timetables`
* **Primary Database Table**: `timetables`
* **Required Joins**: `academic_years`, `classes`, `sections`, `teacher_subject_assignments`, `teachers`, `subjects`
* **Foreign Key Dependencies**: `Academic Year`, `Class`, `Section`, `Teacher Assignment`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Session context code | `ay.code AS academic_year_code` |
| Day of Week | `day_of_week` | Yes | String | `day_of_week` | `timetables.day_of_week` | `MONDAY`, `TUESDAY`, `WEDNESDAY`, `THURSDAY`, `FRIDAY`, `SATURDAY`, `SUNDAY` | `tt.day_of_week::text AS day_of_week` |
| Period Number | `period_number` | Yes | Integer | `period_number` | `timetables.period_number` | Positive integer (1-10) | `tt.period_number::text AS period_number` |
| Start Time | `start_time` | Yes | Time | `start_time` | `timetables.start_time` | `HH:MM` or `HH:MM:SS` (e.g. `09:00:00`) | `TO_CHAR(tt.start_time, 'HH24:MI:SS') AS start_time` |
| End Time | `end_time` | Yes | Time | `end_time` | `timetables.end_time` | `HH:MM` or `HH:MM:SS` (e.g. `09:45:00`) | `TO_CHAR(tt.end_time, 'HH24:MI:SS') AS end_time` |
| Class Code | `class_code` | Yes | String | `class_code` | `classes.code` | Target class code | `c.code AS class_code` |
| Section Code | `section_code` | Yes | String | `section_code` | `sections.code` | Target section code | `sec.code AS section_code` |
| Subject Code | `subject_code` | Yes | String | `subject_code` | `subjects.subject_code` | Target subject code | `sub.subject_code AS subject_code` |
| Teacher Code | `teacher_code` | Yes | String | `teacher_code` | `teachers.staff_code` | Scheduled teacher code | `t.staff_code AS teacher_code` |
| Room Number | `room_number` | Yes | String | `room_number` | `timetables.room_number` | Room number / Lab identifier | `COALESCE(tt.room_number, sec.room_number, '101') AS room_number` |
| Period Type | `period_type` | Yes | String | `period_type` | `timetables.period_type` | `REGULAR`, `LAB`, `SPORTS`, `LIBRARY`, `BREAK`, `EXAM` | `tt.period_type::text AS period_type` |

---

## Widget 12 — Syllabus Metadata

* **UI Screen / Step**: 12. Syllabus Metadata
* **Worksheet Name / Key**: `syllabus`
* **Target REST Endpoint**: `POST /api/v1/syllabuses`
* **Primary Database Table**: `syllabuses`
* **Required Joins**: `academic_years`, `classes`, `subjects`
* **Foreign Key Dependencies**: `Academic Year`, `Class`, `Subject`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Session context code | `ay.code AS academic_year_code` |
| Class Code | `class_code` | Yes | String | `class_code` | `classes.code` | Grade level code | `c.code AS class_code` |
| Subject Code | `subject_code` | Yes | String | `subject_code` | `subjects.subject_code` | Subject identifier | `sub.subject_code AS subject_code` |
| Syllabus Code | `syllabus_code` | Yes | String | `syllabus_code` | `syllabuses.syllabus_code` | Alphanumeric (e.g. `SYL_C10_M_01`) | `syl.syllabus_code AS syllabus_code` |
| Unit Name | `unit_name` | Yes | String | `unit_name` | `syllabuses.unit_name` | Unit title (e.g., `Algebra`) | `syl.unit_name AS unit_name` |
| Chapter Name | `chapter_name` | Yes | String | `chapter_name` | `syllabuses.chapter_name` | Chapter title | `syl.chapter_name AS chapter_name` |
| Topic Name | `topic_name` | Yes | String | `topic_name` | `syllabuses.topic_name` | Topic title | `syl.topic_name AS topic_name` |
| Description | `description` | No | String | `description` | `syllabuses.description` | Text details | `COALESCE(syl.description, '') AS description` |
| Sequence Order | `sequence_order` | No | Integer | `sequence_order` | `syllabuses.sequence_order` | Positive integer (e.g. `1`, `2`) | `syl.sequence_order::text AS sequence_order` |

---

## Widget 13 — Exams & Documents

* **UI Screen / Step**: 13. Exams & Documents
* **Worksheet Name / Key**: `exams`
* **Target REST Endpoint**: `POST /api/v1/examinations`
* **Primary Database Table**: `examinations` (joined with `exam_schedules`)
* **Required Joins**: `academic_years`, `classes`, `subjects`
* **Foreign Key Dependencies**: `Academic Year`, `Class`, `Subject`

| UI Label | Backend Field | Required | Type | Excel Column | Database Source | Allowed Values / Formats | Extraction SQL Expression |
|---|---|---|---|---|---|---|---|
| Academic Year Code | `academic_year_code` | Yes | String | `academic_year_code` | `academic_years.code` | Academic session code | `ay.code AS academic_year_code` |
| Exam Code | `exam_code` | Yes | String | `exam_code` | `examinations.settings->>'exam_code'` | Alphanumeric (e.g. `EXAM_Q1_C10_M`) | `COALESCE(e.settings->>'exam_code', 'EXAM_' || e.exam_type || '_' || c.code || '_' || sub.subject_code) AS exam_code` |
| Exam Name | `exam_name` | Yes | String | `exam_name` | `examinations.exam_name` | Display title (e.g. `Quarterly Examination - Math`) | `e.exam_name AS exam_name` |
| Exam Type | `exam_type` | Yes | String | `exam_type` | `examinations.exam_type` | `UNIT_TEST`, `MONTHLY`, `QUARTERLY`, `HALF_YEARLY`, `PRE_FINAL`, `ANNUAL`, `SUPPLEMENTARY` | `e.exam_type::text AS exam_type` |
| Class Code | `class_code` | Yes | String | `class_code` | `classes.code` | Grade level code | `c.code AS class_code` |
| Subject Code | `subject_code` | Yes | String | `subject_code` | `subjects.subject_code` | Subject code | `sub.subject_code AS subject_code` |
| Exam Date | `exam_date` | Yes | Date | `exam_date` | `examinations.start_date` / `exam_schedules.exam_date` | `YYYY-MM-DD` | `TO_CHAR(COALESCE(es.exam_date, e.start_date), 'YYYY-MM-DD') AS exam_date` |
| Maximum Marks | `maximum_marks` | Yes | Integer | `maximum_marks` | `exam_schedules.max_marks` | Positive integer (e.g. `100`, `50`) | `COALESCE(es.max_marks, 100)::text AS maximum_marks` |
| Duration Minutes | `duration_minutes` | Yes | Integer | `duration_minutes` | `examinations.settings->>'duration_minutes'` | Positive integer (e.g. `180`, `90`) | `COALESCE(e.settings->>'duration_minutes', '180') AS duration_minutes` |
