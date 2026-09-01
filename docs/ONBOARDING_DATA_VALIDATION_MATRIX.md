# EduPulse AI — School Onboarding Data Validation Matrix

This matrix provides the complete validation constraints, data formatting rules, enum values, and foreign-key dependencies enforced across all worksheets by the EduPulse AI School Onboarding engine (`apps/admin_portal`).

| Worksheet | Column | Required | Validation Rules & Constraints | Example Valid Value |
|---|---|---|---|---|
| `school` | `school_code` | YES | Alphanumeric; Primary Key; unique across tenant | `SCH001` |
| `school` | `school_name` | YES | Non-empty text string | `EduPulse Demonstration Academy` |
| `school` | `board` | YES | Enum: `CBSE`, `ICSE`, `SSC`, `STATE`, `IB`, `IGCSE`, `CAMBRIDGE`, `OTHER` | `CBSE` |
| `school` | `school_type` | YES | Enum: `PRIMARY`, `HIGH_SCHOOL`, `JR_COLLEGE`, `DEGREE_COLLEGE`, `UNIVERSITY`, `OTHER` | `HIGH_SCHOOL` |
| `school` | `email` | YES | Regex: `^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$` | `contact@school.edu` |
| `school` | `phone` | YES | 10-15 digit string | `+91-9876543210` |
| `school` | `status` | YES | Enum: `ACTIVE`, `INACTIVE` | `ACTIVE` |
| `school` | `address` | NO | Text string | `Plot 42 Knowledge Corridor` |
| `school` | `city` | NO | Text string | `Hyderabad` |
| `school` | `state` | NO | Text string | `Telangana` |
| `school` | `postal_code` | NO | 6-digit PIN / Postal string | `500081` |
| `academic_years` | `school_code` | YES | Foreign Key $\rightarrow$ `school.school_code` | `SCH001` |
| `academic_years` | `academic_year_code` | YES | Regex: `^AY[0-9]{4}(?:-[0-9]{4})?$`; Primary Key | `AY2025-2026` |
| `academic_years` | `academic_year_name` | YES | Text string | `Academic Year 2025-2026` |
| `academic_years` | `start_date` | YES | Format: `YYYY-MM-DD` | `2025-06-01` |
| `academic_years` | `end_date` | YES | Format: `YYYY-MM-DD` (must be $>$ `start_date`) | `2026-04-30` |
| `academic_years` | `status` | YES | Enum: `UPCOMING`, `ACTIVE`, `COMPLETED`, `ARCHIVED` | `ACTIVE` |
| `academic_years` | `is_current` | YES | Boolean: `true`, `false`, `yes`, `no` | `true` |
| `classes` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `classes` | `class_code` | YES | Alphanumeric; Primary Key per academic session | `C5` |
| `classes` | `display_label` | YES | Text string | `Class 5` |
| `classes` | `level` | YES | Positive integer ($> 0$) | `5` |
| `classes` | `grade_category` | YES | Enum: `PRE_PRIMARY`, `PRIMARY`, `MIDDLE`, `HIGH` | `MIDDLE` |
| `classes` | `max_capacity` | YES | Positive integer ($> 0$) | `60` |
| `classes` | `status` | YES | Enum: `ACTIVE`, `INACTIVE` | `ACTIVE` |
| `sections` | `class_code` | YES | Foreign Key $\rightarrow$ `classes.class_code` | `C5` |
| `sections` | `section_code` | YES | Alphanumeric; unique per `class_code` | `A` |
| `sections` | `section_name` | YES | Text string | `Section A` |
| `sections` | `capacity` | YES | Positive integer ($> 0$) | `30` |
| `sections` | `room_number` | YES | Alphanumeric room string | `101` |
| `sections` | `display_sort_order` | YES | Positive integer ($> 0$) | `1` |
| `sections` | `status` | YES | Enum: `ACTIVE`, `INACTIVE` | `ACTIVE` |
| `sections` | `academic_year_code` | NO | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `subjects` | `subject_code` | YES | Alphanumeric; Primary Key per academic session | `MATH101` |
| `subjects` | `subject_name` | YES | Text string | `Mathematics` |
| `subjects` | `category` | YES | Enum: `CORE`, `ELECTIVE`, `LANGUAGE`, `OPTIONAL`, `LAB`, `SPORTS`, `ARTS`, `CO_CURRICULAR` | `CORE` |
| `subjects` | `subject_type` | YES | Enum: `THEORY`, `PRACTICAL`, `THEORY_PRACTICAL` | `THEORY_PRACTICAL` |
| `subjects` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `subjects` | `theory_marks` | NO | Integer ($0$ to $100$); $0$ if `subject_type == PRACTICAL` | `80` |
| `subjects` | `practical_marks` | NO | Integer ($0$ to $100$); $0$ if `subject_type == THEORY` | `20` |
| `subjects` | `pass_marks` | NO | Integer $\le$ `theory_marks + practical_marks` | `33` |
| `subjects` | `credit_hours` | NO | Positive integer | `4` |
| `subjects` | `weekly_periods` | NO | Positive integer | `5` |
| `subjects` | `display_order` | NO | Positive integer | `1` |
| `teachers` | `teacher_code` | YES | Alphanumeric; Primary Key | `TCH001` |
| `teachers` | `first_name` | YES | Legal first name | `Ananya` |
| `teachers` | `last_name` | YES | Legal surname | `Sharma` |
| `teachers` | `gender` | YES | Enum: `MALE`, `FEMALE`, `OTHER` | `FEMALE` |
| `teachers` | `date_of_birth` | YES | Format: `YYYY-MM-DD` | `1985-05-14` |
| `teachers` | `mobile` | YES | 10-digit mobile number | `9876543211` |
| `teachers` | `email` | YES | Valid email format (unique login ID) | `ananya.sharma@school.edu` |
| `teachers` | `employee_code` | YES | HR / Staff payroll ID | `EMP001` |
| `teachers` | `designation` | YES | Enum: `PRT`, `TGT`, `PGT`, `HOD`, `PRINCIPAL` | `PGT` |
| `teachers` | `joining_date` | YES | Format: `YYYY-MM-DD` | `2018-06-01` |
| `teachers` | `status` | YES | Enum: `ACTIVE`, `INACTIVE`, `ON_LEAVE`, `RETIRED` | `ACTIVE` |
| `teachers` | `middle_name` | NO | Text string | `Kumar` |
| `teachers` | `employment_type` | NO | Enum: `FULL_TIME`, `PART_TIME`, `CONTRACT`, `VISITING` | `FULL_TIME` |
| `guardians` | `guardian_code` | YES | Alphanumeric; Primary Key | `GRD001` |
| `guardians` | `first_name` | YES | Given name | `Suresh` |
| `guardians` | `last_name` | YES | Family name | `Rao` |
| `guardians` | `gender` | YES | Enum: `MALE`, `FEMALE`, `OTHER` | `MALE` |
| `guardians` | `date_of_birth` | YES | Format: `YYYY-MM-DD` | `1980-04-12` |
| `guardians` | `mobile` | YES | 10-digit mobile number (SMS login) | `9876500001` |
| `guardians` | `email` | YES | Valid email format | `suresh.rao@example.com` |
| `guardians` | `guardian_type` | YES | Enum: `FATHER`, `MOTHER`, `LEGAL_GUARDIAN`, `GRANDPARENT`, `UNCLE`, `AUNT`, `OTHER` | `FATHER` |
| `guardians` | `status` | YES | Enum: `ACTIVE`, `INACTIVE` | `ACTIVE` |
| `students` | `admission_number` | YES | Alphanumeric; Primary Key | `ADM2025001` |
| `students` | `first_name` | YES | Given name | `Aarav` |
| `students` | `last_name` | YES | Family name | `Rao` |
| `students` | `gender` | YES | Enum: `MALE`, `FEMALE`, `OTHER` | `MALE` |
| `students` | `date_of_birth` | YES | Format: `YYYY-MM-DD` | `2014-06-15` |
| `students` | `admission_date` | YES | Format: `YYYY-MM-DD` | `2025-06-01` |
| `students` | `roll_number` | YES | Positive integer | `1` |
| `students` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `students` | `class_code` | YES | Foreign Key $\rightarrow$ `classes.class_code` | `C5` |
| `students` | `section_code` | YES | Foreign Key $\rightarrow$ `sections.section_code` | `A` |
| `students` | `status` | YES | Enum: `ACTIVE`, `INACTIVE` | `ACTIVE` |
| `student_guardians` | `admission_number` | YES | Foreign Key $\rightarrow$ `students.admission_number` | `ADM2025001` |
| `student_guardians` | `guardian_code` | YES | Foreign Key $\rightarrow$ `guardians.guardian_code` | `GRD001` |
| `student_guardians` | `relationship` | YES | Enum: `FATHER`, `MOTHER`, `GUARDIAN`, `GRANDPARENT`, `RELATIVE`, `OTHER` | `FATHER` |
| `student_guardians` | `is_primary` | YES | Boolean: `true`, `false`, `yes`, `no` | `true` |
| `student_guardians` | `authorized_for_pickup` | YES | Boolean: `true`, `false`, `yes`, `no` | `true` |
| `student_guardians` | `receives_notifications` | YES | Boolean: `true`, `false`, `yes`, `no` | `true` |
| `teacher_assignments` | `teacher_code` | YES | Foreign Key $\rightarrow$ `teachers.teacher_code` | `TCH001` |
| `teacher_assignments` | `subject_code` | YES | Foreign Key $\rightarrow$ `subjects.subject_code` | `MATH101` |
| `teacher_assignments` | `class_code` | YES | Foreign Key $\rightarrow$ `classes.class_code` | `C5` |
| `teacher_assignments` | `section_code` | YES | Foreign Key $\rightarrow$ `sections.section_code` | `A` |
| `teacher_assignments` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `teacher_assignments` | `assignment_type` | NO | Enum: `PRIMARY`, `SECONDARY`, `SUBSTITUTE` | `PRIMARY` |
| `teacher_assignments` | `weekly_periods` | NO | Positive integer (Defaults to `4`) | `5` |
| `teacher_assignments` | `effective_from` | NO | Format: `YYYY-MM-DD` | `2025-06-01` |
| `timetable` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `timetable` | `day_of_week` | YES | Enum: `MONDAY`, `TUESDAY`, `WEDNESDAY`, `THURSDAY`, `FRIDAY`, `SATURDAY`, `SUNDAY` | `MONDAY` |
| `timetable` | `period_number` | YES | Integer: $1$ to $10$ | `1` |
| `timetable` | `start_time` | YES | Format: `HH:MM` or `HH:MM:SS` | `09:00:00` |
| `timetable` | `end_time` | YES | Format: `HH:MM` or `HH:MM:SS` (must be $>$ `start_time`) | `09:45:00` |
| `timetable` | `class_code` | YES | Foreign Key $\rightarrow$ `classes.class_code` | `C5` |
| `timetable` | `section_code` | YES | Foreign Key $\rightarrow$ `sections.section_code` | `A` |
| `timetable` | `subject_code` | YES | Foreign Key $\rightarrow$ `subjects.subject_code` | `MATH101` |
| `timetable` | `teacher_code` | YES | Foreign Key $\rightarrow$ `teachers.teacher_code` | `TCH001` |
| `timetable` | `room_number` | YES | Alphanumeric room string | `101` |
| `timetable` | `period_type` | YES | Enum: `REGULAR`, `LAB`, `SPORTS`, `LIBRARY`, `BREAK`, `EXAM` | `REGULAR` |
| `syllabus` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `syllabus` | `class_code` | YES | Foreign Key $\rightarrow$ `classes.class_code` | `C10` |
| `syllabus` | `subject_code` | YES | Foreign Key $\rightarrow$ `subjects.subject_code` | `MATH101` |
| `syllabus` | `syllabus_code` | YES | Alphanumeric; Primary Key per subject/class | `SYL_C10_M_01` |
| `syllabus` | `unit_name` | YES | Text string | `Algebra` |
| `syllabus` | `chapter_name` | YES | Text string | `Quadratic Equations` |
| `syllabus` | `topic_name` | YES | Text string | `Standard Form and Factorization` |
| `syllabus` | `description` | NO | Text string | `Introduction to quadratic expressions` |
| `syllabus` | `sequence_order` | NO | Positive integer ($> 0$) | `1` |
| `exams` | `academic_year_code` | YES | Foreign Key $\rightarrow$ `academic_years.academic_year_code` | `AY2025-2026` |
| `exams` | `exam_code` | YES | Alphanumeric; Primary Key | `EXAM_Q1_C5_MATH` |
| `exams` | `exam_name` | YES | Text string | `Quarterly Examination - Class 5 Math` |
| `exams` | `exam_type` | YES | Enum: `UNIT_TEST`, `MONTHLY`, `QUARTERLY`, `HALF_YEARLY`, `PRE_FINAL`, `ANNUAL`, `SUPPLEMENTARY` | `QUARTERLY` |
| `exams` | `class_code` | YES | Foreign Key $\rightarrow$ `classes.class_code` | `C5` |
| `exams` | `subject_code` | YES | Foreign Key $\rightarrow$ `subjects.subject_code` | `MATH101` |
| `exams` | `exam_date` | YES | Format: `YYYY-MM-DD` | `2025-09-15` |
| `exams` | `maximum_marks` | YES | Positive integer ($> 0$) | `100` |
| `exams` | `duration_minutes` | YES | Positive integer ($> 0$) | `180` |
