# EduPulse AI — Final School Onboarding Excel Workbook Structure

This document provides the exact workbook structure and sheet specifications required by the EduPulse AI School Onboarding Center.

---

## Sheet 1 — `school` (School Information)

### Exact Column Order:
1. `school_code`
2. `school_name`
3. `board`
4. `school_type`
5. `email`
6. `phone`
7. `status`
8. `address`
9. `city`
10. `state`
11. `postal_code`

* **Required Fields**: `school_code`, `school_name`, `board`, `school_type`, `email`, `phone`, `status`
* **Optional Fields**: `address`, `city`, `state`, `postal_code`

### Example Valid Row:
```csv
SCH001,EduPulse Demonstration Academy,CBSE,HIGH_SCHOOL,contact@edupulse.edu,+91-9876543210,ACTIVE,Plot 42 Knowledge Corridor,Hyderabad,Telangana,500081
```

---

## Sheet 2 — `academic_years` (Academic Structure)

### Exact Column Order:
1. `school_code`
2. `academic_year_code`
3. `academic_year_name`
4. `start_date`
5. `end_date`
6. `status`
7. `is_current`

* **Required Fields**: `school_code`, `academic_year_code`, `academic_year_name`, `start_date`, `end_date`, `status`, `is_current`
* **Optional Fields**: None

### Example Valid Row:
```csv
SCH001,AY2025-2026,Academic Year 2025-2026,2025-06-01,2026-04-30,ACTIVE,true
```

---

## Sheet 3 — `classes` (Grade Levels)

### Exact Column Order:
1. `academic_year_code`
2. `class_code`
3. `display_label`
4. `level`
5. `grade_category`
6. `max_capacity`
7. `status`

* **Required Fields**: `academic_year_code`, `class_code`, `display_label`, `level`, `grade_category`, `max_capacity`, `status`
* **Optional Fields**: None

### Example Valid Rows:
```csv
AY2025-2026,C5,Class 5,5,MIDDLE,60,ACTIVE
AY2025-2026,C6,Class 6,6,MIDDLE,60,ACTIVE
AY2025-2026,C7,Class 7,7,MIDDLE,60,ACTIVE
AY2025-2026,C8,Class 8,8,MIDDLE,60,ACTIVE
AY2025-2026,C9,Class 9,9,HIGH,60,ACTIVE
AY2025-2026,C10,Class 10,10,HIGH,60,ACTIVE
```

---

## Sheet 4 — `sections` (Sections & Rooms)

### Exact Column Order:
1. `class_code`
2. `section_code`
3. `section_name`
4. `capacity`
5. `room_number`
6. `display_sort_order`
7. `status`
8. `academic_year_code`

* **Required Fields**: `class_code`, `section_code`, `section_name`, `capacity`, `room_number`, `display_sort_order`, `status`
* **Optional / Supported Fields**: `academic_year_code`

### Example Valid Rows:
```csv
C5,A,Section A,30,101,1,ACTIVE,AY2025-2026
C5,B,Section B,30,102,2,ACTIVE,AY2025-2026
C10,A,Section A,30,201,1,ACTIVE,AY2025-2026
C10,B,Section B,30,202,2,ACTIVE,AY2025-2026
```

---

## Sheet 5 — `subjects` (Subjects Catalog)

### Exact Column Order:
1. `subject_code`
2. `subject_name`
3. `category`
4. `subject_type`
5. `academic_year_code`
6. `theory_marks`
7. `practical_marks`
8. `pass_marks`
9. `credit_hours`
10. `weekly_periods`
11. `display_order`

* **Required Fields**: `subject_code`, `subject_name`, `category`, `subject_type`, `academic_year_code`
* **Optional Fields**: `theory_marks`, `practical_marks`, `pass_marks`, `credit_hours`, `weekly_periods`, `display_order`

### Example Valid Rows:
```csv
MATH101,Mathematics,CORE,THEORY_PRACTICAL,AY2025-2026,80,20,33,4,5,1
ENG101,English Language,LANGUAGE,THEORY,AY2025-2026,100,0,33,4,4,2
SCI101,General Science,CORE,THEORY_PRACTICAL,AY2025-2026,70,30,33,4,5,3
SOC101,Social Studies,CORE,THEORY,AY2025-2026,100,0,33,4,4,4
HIN101,Hindi Second Language,LANGUAGE,THEORY,AY2025-2026,100,0,33,3,3,5
COMP101,Computer Applications,CORE,PRACTICAL,AY2025-2026,0,100,35,3,3,6
```

---

## Sheet 6 — `teachers` (Teachers Roster)

### Exact Column Order:
1. `teacher_code`
2. `first_name`
3. `last_name`
4. `gender`
5. `date_of_birth`
6. `mobile`
7. `email`
8. `employee_code`
9. `designation`
10. `joining_date`
11. `status`
12. `middle_name`
13. `employment_type`

* **Required Fields**: `teacher_code`, `first_name`, `last_name`, `gender`, `date_of_birth`, `mobile`, `email`, `employee_code`, `designation`, `joining_date`, `status`
* **Optional Fields**: `middle_name`, `employment_type`

### Example Valid Rows:
```csv
TCH001,Ananya,Sharma,FEMALE,1985-05-14,9876543211,ananya.sharma@school.edu,EMP001,PGT,2018-06-01,ACTIVE,,FULL_TIME
TCH002,Rajesh,Verma,MALE,1982-11-23,9876543212,rajesh.verma@school.edu,EMP002,TGT,2019-06-01,ACTIVE,Kumar,FULL_TIME
```

---

## Sheet 7 — `guardians` (Parents & Guardians)

### Exact Column Order:
1. `guardian_code`
2. `first_name`
3. `last_name`
4. `gender`
5. `date_of_birth`
6. `mobile`
7. `email`
8. `guardian_type`
9. `status`

* **Required Fields**: `guardian_code`, `first_name`, `last_name`, `gender`, `date_of_birth`, `mobile`, `email`, `guardian_type`, `status`
* **Optional Fields**: None

### Example Valid Rows:
```csv
GRD001,Suresh,Rao,MALE,1980-04-12,9876500001,suresh.rao@example.com,FATHER,ACTIVE
GRD002,Kavitha,Rao,FEMALE,1983-09-28,9876500002,kavitha.rao@example.com,MOTHER,ACTIVE
```

---

## Sheet 8 — `students` (Students Register)

### Exact Column Order:
1. `admission_number`
2. `first_name`
3. `last_name`
4. `gender`
5. `date_of_birth`
6. `admission_date`
7. `roll_number`
8. `academic_year_code`
9. `class_code`
10. `section_code`
11. `status`

* **Required Fields**: `admission_number`, `first_name`, `last_name`, `gender`, `date_of_birth`, `admission_date`, `roll_number`, `academic_year_code`, `class_code`, `section_code`, `status`
* **Optional Fields**: None

### Example Valid Rows:
```csv
ADM2025001,Aarav,Rao,MALE,2014-06-15,2025-06-01,1,AY2025-2026,C5,A,ACTIVE
ADM2025002,Diya,Patel,FEMALE,2014-08-20,2025-06-01,2,AY2025-2026,C5,A,ACTIVE
ADM2025031,Rohan,Gupta,MALE,2014-03-10,2025-06-01,1,AY2025-2026,C5,B,ACTIVE
ADM2025331,Vikram,Reddy,MALE,2009-02-18,2025-06-01,1,AY2025-2026,C10,B,ACTIVE
```

---

## Sheet 9 — `student_guardians` (Student-Guardian Links)

### Exact Column Order:
1. `admission_number`
2. `guardian_code`
3. `relationship`
4. `is_primary`
5. `authorized_for_pickup`
6. `receives_notifications`

* **Required Fields**: `admission_number`, `guardian_code`, `relationship`, `is_primary`, `authorized_for_pickup`, `receives_notifications`
* **Optional Fields**: None

### Example Valid Rows:
```csv
ADM2025001,GRD001,FATHER,true,true,true
ADM2025001,GRD002,MOTHER,false,true,true
```

---

## Sheet 10 — `teacher_assignments` (Teacher Assignments)

### Exact Column Order:
1. `teacher_code`
2. `subject_code`
3. `class_code`
4. `section_code`
5. `academic_year_code`
6. `assignment_type`
7. `weekly_periods`
8. `effective_from`

* **Required Fields**: `teacher_code`, `subject_code`, `class_code`, `section_code`, `academic_year_code`
* **Optional Fields**: `assignment_type`, `weekly_periods`, `effective_from`

### Example Valid Rows:
```csv
TCH001,MATH101,C5,A,AY2025-2026,PRIMARY,5,2025-06-01
TCH001,MATH101,C5,B,AY2025-2026,PRIMARY,5,2025-06-01
TCH002,ENG101,C5,A,AY2025-2026,PRIMARY,4,2025-06-01
```

---

## Sheet 11 — `timetable` (Timetable Slots)

### Exact Column Order:
1. `academic_year_code`
2. `day_of_week`
3. `period_number`
4. `start_time`
5. `end_time`
6. `class_code`
7. `section_code`
8. `subject_code`
9. `teacher_code`
10. `room_number`
11. `period_type`

* **Required Fields**: All 11 columns
* **Optional Fields**: None

### Example Valid Rows:
```csv
AY2025-2026,MONDAY,1,09:00:00,09:45:00,C5,A,MATH101,TCH001,101,REGULAR
AY2025-2026,MONDAY,2,09:45:00,10:30:00,C5,A,ENG101,TCH002,101,REGULAR
AY2025-2026,MONDAY,3,10:45:00,11:30:00,C5,A,SCI101,TCH001,101,LAB
```

---

## Sheet 12 — `syllabus` (Syllabus Metadata)

### Exact Column Order:
1. `academic_year_code`
2. `class_code`
3. `subject_code`
4. `syllabus_code`
5. `unit_name`
6. `chapter_name`
7. `topic_name`
8. `description`
9. `sequence_order`

* **Required Fields**: `academic_year_code`, `class_code`, `subject_code`, `syllabus_code`, `unit_name`, `chapter_name`, `topic_name`
* **Optional Fields**: `description`, `sequence_order`

### Example Valid Rows:
```csv
AY2025-2026,C10,MATH101,SYL_C10_M_01,Algebra,Quadratic Equations,Standard Form and Factorization,Introduction to quadratic expressions,1
AY2025-2026,C10,MATH101,SYL_C10_M_02,Algebra,Quadratic Equations,Quadratic Formula and Discriminant,Derivation and roots calculation,2
```

---

## Sheet 13 — `exams` (Exams & Documents)

### Exact Column Order:
1. `academic_year_code`
2. `exam_code`
3. `exam_name`
4. `exam_type`
5. `class_code`
6. `subject_code`
7. `exam_date`
8. `maximum_marks`
9. `duration_minutes`

* **Required Fields**: All 9 columns
* **Optional Fields**: None

### Example Valid Rows:
```csv
AY2025-2026,EXAM_Q1_C5_MATH,Quarterly Examination - Class 5 Math,QUARTERLY,C5,MATH101,2025-09-15,100,180
AY2025-2026,EXAM_Q1_C5_ENG,Quarterly Examination - Class 5 English,QUARTERLY,C5,ENG101,2025-09-16,100,180
AY2025-2026,EXAM_Q1_C10_MATH,Quarterly Examination - Class 10 Math,QUARTERLY,C10,MATH101,2025-09-15,100,180
```
