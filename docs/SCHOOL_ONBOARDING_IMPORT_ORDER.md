# EduPulse AI — School Onboarding Import Dependency Order

This document explains the topological dependency order required by the EduPulse AI School Onboarding engine to import school datasets without foreign-key violations or dangling references.

---

## Topological Dependency Graph

```text
[01. School Information] (Root Tenant Entity)
    │
    ├──► [02. Academic Structure] (Session Context)
    │        │
    │        ├──► [03. Grade Levels (Classes)]
    │        │        │
    │        │        ├──► [04. Sections & Rooms]
    │        │        │        │
    │        │        │        └──► [08. Students Register] ◄──┐
    │        │        │                     │                  │
    │        │        │                     └──► [09. Student-Guardian Links]
    │        │        │                                        ▲
    │        │        │                                        │
    │        │        │                             [07. Parents & Guardians]
    │        │        │
    │        │        └──► [10. Teacher Assignments] ◄── [06. Teachers Roster]
    │        │                     ▲
    │        │                     │
    │        └──► [05. Subjects Catalog]
    │                 │            │
    │                 │            └──► [11. Timetable Slots]
    │                 │
    │                 ├──► [12. Syllabus Metadata]
    │                 │
    │                 └──► [13. Exams & Documents]
```

---

## Step-by-Step Execution Sequence & Dependency Rationale

### Step 1: `school` (School Information)
* **Why it must come first**: The School record is the tenant sub-boundary. All database records (`academic_years`, `teachers`, `students`, `classes`) enforce a mandatory `school_id` foreign key.
* **IDs / Maps Created**: `school_code` $\rightarrow$ `school_id` (UUID).
* **Downstream Availability**: Establishes the active school context for all downstream entities.

---

### Step 2: `academic_years` (Academic Structure)
* **Why it must come before academic entities**: Grade levels, sections, subjects, timetables, and student enrollments are strictly scoped by academic session.
* **Prerequisite**: `school_code` from Step 1.
* **IDs / Maps Created**: `academic_year_code` $\rightarrow$ `academic_year_id` (UUID).
* **Downstream Availability**: Unlocks Class creation, Subject cataloging, and Student cohort assignment.

---

### Step 3: `classes` (Grade Levels)
* **Why it must come before sections & subjects**: Sections belong to a parent Class level, and syllabus/exam scopes require class level definitions.
* **Prerequisite**: `academic_year_code` from Step 2.
* **IDs / Maps Created**: `class_code` $\rightarrow$ `class_id` (UUID).
* **Downstream Availability**: Enables creation of Sections and Class-scoped Teacher Assignments.

---

### Step 4: `sections` (Sections & Rooms)
* **Why it must come before student registration**: Students cannot be registered without being assigned to a physical classroom section (`section_id`).
* **Prerequisite**: `class_code` from Step 3, `academic_year_code` from Step 2.
* **IDs / Maps Created**: `class_code-section_code` $\rightarrow$ `section_id` (UUID).
* **Downstream Availability**: Enables Student roster import, room allocation, and section timetable scheduling.

---

### Step 5: `subjects` (Subjects Catalog)
* **Why it must come before assignments & exams**: Academic curriculum master data (codes, types, marks weighting) must exist before allocating teachers or scheduling exams.
* **Prerequisite**: `academic_year_code` from Step 2.
* **IDs / Maps Created**: `subject_code` $\rightarrow$ `subject_id` (UUID).
* **Downstream Availability**: Enables Teacher-Subject assignments, Syllabus units, Timetable slots, and Exam definitions.

---

### Step 6: `teachers` (Teachers Roster)
* **Why it must come before assignments**: Staff profiles and portal accounts must exist before assigning teaching workloads.
* **Prerequisite**: `school_code` from Step 1.
* **IDs / Maps Created**: `teacher_code` $\rightarrow$ `teacher_id` (UUID) + User Authentication Credentials.
* **Downstream Availability**: Enables Teacher-Subject assignments and Timetable educator mapping.

---

### Step 7: `guardians` (Parents & Guardians)
* **Why it must come before links**: Parent identities and communication profiles must be registered before establishing relationships to students.
* **Prerequisite**: `school_code` from Step 1.
* **IDs / Maps Created**: `guardian_code` $\rightarrow$ `guardian_id` (UUID) + Parent Portal Credentials.
* **Downstream Availability**: Enables Student-Guardian Link creation in Step 9.

---

### Step 8: `students` (Students Register)
* **Why it must come before guardian links**: Student profile records must exist with admission numbers before linking guardians or recording attendance/marks.
* **Prerequisite**: `academic_year_code` (Step 2), `class_code` (Step 3), `section_code` (Step 4).
* **IDs / Maps Created**: `admission_number` $\rightarrow$ `student_id` (UUID).
* **Downstream Availability**: Unlocks Student-Guardian mappings and examination candidate lists.

---

### Step 9: `student_guardians` (Student-Guardian Links)
* **Why it must come after students and guardians**: Maps the N:M relationship between students and authorized guardians.
* **Prerequisite**: `admission_number` from Step 8, `guardian_code` from Step 7.
* **IDs / Maps Created**: `student_id` $\leftrightarrow$ `guardian_id` link record.
* **Downstream Availability**: Enables Parent App authorization, pickup authorization, and emergency notification routing.

---

### Step 10: `teacher_assignments` (Teacher Assignments)
* **Why it must come after teachers, subjects, classes, sections**: Maps which educator teaches which subject in which section.
* **Prerequisite**: `teacher_code` (Step 6), `subject_code` (Step 5), `class_code` (Step 3), `section_code` (Step 4), `academic_year_code` (Step 2).
* **IDs / Maps Created**: `teacher_code-subject_code-class_code-section_code` $\rightarrow$ `teacher_subject_assignment_id` (UUID).
* **Downstream Availability**: Required by Timetable slots and Exam scheduling.

---

### Step 11: `timetable` (Timetable Slots)
* **Why it must come after teacher assignments**: Timetable slots link directly to the resolved `teacher_subject_assignment_id`.
* **Prerequisite**: `teacher_assignments` (Step 10), `sections` (Step 4), `academic_years` (Step 2).
* **IDs / Maps Created**: `timetable_id` (UUID).
* **Downstream Availability**: Populates Teacher and Student weekly class schedules.

---

### Step 12: `syllabus` (Syllabus Metadata)
* **Why it must come after academic setup & subjects**: Syllabus units and chapters are categorized under specific subject and class offerings.
* **Prerequisite**: `academic_year_code` (Step 2), `class_code` (Step 3), `subject_code` (Step 5).
* **IDs / Maps Created**: `syllabus_code` $\rightarrow$ `syllabus_id` (UUID).
* **Downstream Availability**: Enables lesson planning and curriculum progress tracking.

---

### Step 13: `exams` (Exams & Documents)
* **Why it must come after academic setup & subjects**: Examination master schedules evaluate specific classes and subjects.
* **Prerequisite**: `academic_year_code` (Step 2), `class_code` (Step 3), `subject_code` (Step 5).
* **IDs / Maps Created**: `exam_code` $\rightarrow$ `examination_id` (UUID) + `exam_schedule_id` (UUID).
* **Downstream Availability**: Unlocks marks entry, grading sheets, and report card generation.

---

## Interactive Stages (No Worksheets)

* **Step 14: Pre-Import Validation**: Audits data integrity and enforces cross-sheet foreign-key consistency before database commits.
* **Step 15: Executing Import Job**: Runs synchronous batch execution across REST endpoints with concurrency handling.
* **Step 16: Completion Summary Report**: Emits audit logs and exports teacher/parent initial login credentials.
