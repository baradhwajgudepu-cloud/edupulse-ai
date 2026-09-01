-- ============================================================================
-- EDUPULSE AI — REVERSE-ENGINEERED ONBOARDING DATA EXTRACTION SCRIPT
-- ============================================================================
-- Description: Extracts existing production database records formatted 
--              strictly to match the EduPulse AI School Onboarding Excel
--              importer schema.
-- Parameters:
--   :tenant_id  - Target tenant UUID (e.g. '09f2d4e7-2877-4e42-9e95-e97d52775687')
--   :school_id  - Target school UUID (optional, filters by school)
-- ============================================================================


-- ============================================================================
-- 01. WORKSHEET: school (School Information)
-- ============================================================================
SELECT
    s.code AS school_code,
    s.name AS school_name,
    s.board::text AS board,
    s.school_type::text AS school_type,
    s.email AS email,
    COALESCE(s.phone, '') AS phone,
    s.status::text AS status,
    COALESCE(s.address, '') AS address,
    COALESCE(s.city, '') AS city,
    COALESCE(s.state, '') AS state,
    COALESCE(s.postal_code, '') AS postal_code
FROM schools s
WHERE s.tenant_id = :tenant_id
  AND (:school_id IS NULL OR s.id = :school_id)
ORDER BY s.code;


-- ============================================================================
-- 02. WORKSHEET: academic_years (Academic Structure)
-- ============================================================================
SELECT
    s.code AS school_code,
    ay.code AS academic_year_code,
    ay.name AS academic_year_name,
    TO_CHAR(ay.start_date, 'YYYY-MM-DD') AS start_date,
    TO_CHAR(ay.end_date, 'YYYY-MM-DD') AS end_date,
    ay.status::text AS status,
    CASE WHEN ay.is_current THEN 'true' ELSE 'false' END AS is_current
FROM academic_years ay
JOIN schools s ON ay.school_id = s.id
WHERE ay.tenant_id = :tenant_id
  AND (:school_id IS NULL OR ay.school_id = :school_id)
ORDER BY ay.start_date DESC;


-- ============================================================================
-- 03. WORKSHEET: classes (Grade Levels)
-- ============================================================================
SELECT
    ay.code AS academic_year_code,
    c.code AS class_code,
    c.name AS display_label,
    c.level::text AS level,
    c.category::text AS grade_category,
    c.capacity::text AS max_capacity,
    c.status::text AS status
FROM classes c
JOIN academic_years ay ON c.academic_year_id = ay.id
WHERE c.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR c.school_id = :school_id)
ORDER BY c.level ASC, c.code ASC;


-- ============================================================================
-- 04. WORKSHEET: sections (Sections & Rooms)
-- ============================================================================
SELECT
    c.code AS class_code,
    sec.code AS section_code,
    sec.name AS section_name,
    sec.capacity::text AS capacity,
    COALESCE(sec.room_number, '') AS room_number,
    sec.sort_order::text AS display_sort_order,
    sec.status::text AS status,
    ay.code AS academic_year_code
FROM sections sec
JOIN classes c ON sec.class_id = c.id
JOIN academic_years ay ON sec.academic_year_id = ay.id
WHERE sec.tenant_id = :tenant_id
  AND (:school_id IS NULL OR sec.school_id = :school_id)
ORDER BY c.level ASC, sec.sort_order ASC, sec.code ASC;


-- ============================================================================
-- 05. WORKSHEET: subjects (Subjects Catalog)
-- ============================================================================
SELECT
    sub.subject_code AS subject_code,
    sub.subject_name AS subject_name,
    sub.category::text AS category,
    sub.subject_type::text AS subject_type,
    ay.code AS academic_year_code,
    COALESCE(sub.theory_marks::text, '') AS theory_marks,
    COALESCE(sub.practical_marks::text, '') AS practical_marks,
    COALESCE(sub.pass_marks::text, '') AS pass_marks,
    COALESCE(sub.credit_hours::text, '4') AS credit_hours,
    COALESCE(sub.weekly_periods::text, '4') AS weekly_periods,
    COALESCE(sub.display_order::text, '1') AS display_order
FROM subjects sub
JOIN academic_years ay ON sub.academic_year_id = ay.id
WHERE sub.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR sub.school_id = :school_id)
ORDER BY sub.subject_code ASC;


-- ============================================================================
-- 06. WORKSHEET: teachers (Teachers Roster)
-- ============================================================================
SELECT
    t.staff_code AS teacher_code,
    t.first_name AS first_name,
    t.last_name AS last_name,
    t.gender::text AS gender,
    TO_CHAR(t.date_of_birth, 'YYYY-MM-DD') AS date_of_birth,
    t.mobile AS mobile,
    t.official_email AS email,
    t.employee_code AS employee_code,
    COALESCE(t.designation, 'TGT') AS designation,
    TO_CHAR(t.joining_date, 'YYYY-MM-DD') AS joining_date,
    t.status::text AS status,
    COALESCE(t.middle_name, '') AS middle_name,
    COALESCE(t.employment_type::text, 'FULL_TIME') AS employment_type
FROM teachers t
WHERE t.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR t.school_id = :school_id)
ORDER BY t.staff_code ASC;


-- ============================================================================
-- 07. WORKSHEET: guardians (Parents & Guardians)
-- ============================================================================
SELECT
    COALESCE(g.settings->>'guardian_code', 'GRD' || LPAD(g.id::text, 6, '0')) AS guardian_code,
    g.first_name AS first_name,
    g.last_name AS last_name,
    g.gender::text AS gender,
    TO_CHAR(g.date_of_birth, 'YYYY-MM-DD') AS date_of_birth,
    g.mobile AS mobile,
    COALESCE(g.email, '') AS email,
    g.guardian_type::text AS guardian_type,
    g.status::text AS status
FROM guardians g
WHERE g.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR g.school_id = :school_id)
ORDER BY guardian_code ASC;


-- ============================================================================
-- 08. WORKSHEET: students (Students Register)
-- ============================================================================
SELECT
    stu.admission_number AS admission_number,
    stu.first_name AS first_name,
    stu.last_name AS last_name,
    stu.gender::text AS gender,
    TO_CHAR(stu.date_of_birth, 'YYYY-MM-DD') AS date_of_birth,
    TO_CHAR(stu.admission_date, 'YYYY-MM-DD') AS admission_date,
    stu.roll_number AS roll_number,
    ay.code AS academic_year_code,
    c.code AS class_code,
    sec.code AS section_code,
    stu.status::text AS status
FROM students stu
JOIN academic_years ay ON stu.academic_year_id = ay.id
JOIN classes c ON stu.class_id = c.id
JOIN sections sec ON stu.section_id = sec.id
WHERE stu.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR stu.school_id = :school_id)
ORDER BY c.level ASC, sec.code ASC, stu.roll_number::int ASC;


-- ============================================================================
-- 09. WORKSHEET: student_guardians (Student-Guardian Links)
-- ============================================================================
SELECT
    stu.admission_number AS admission_number,
    COALESCE(g.settings->>'guardian_code', 'GRD' || LPAD(g.id::text, 6, '0')) AS guardian_code,
    sg.relationship::text AS relationship,
    CASE WHEN sg.is_primary THEN 'true' ELSE 'false' END AS is_primary,
    CASE WHEN sg.authorized_for_pickup THEN 'true' ELSE 'false' END AS authorized_for_pickup,
    CASE WHEN sg.receives_notifications THEN 'true' ELSE 'false' END AS receives_notifications
FROM student_guardians sg
JOIN students stu ON sg.student_id = stu.id
JOIN guardians g ON sg.guardian_id = g.id
WHERE sg.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR sg.school_id = :school_id)
ORDER BY stu.admission_number ASC;


-- ============================================================================
-- 10. WORKSHEET: teacher_assignments (Teacher Assignments)
-- ============================================================================
SELECT
    t.staff_code AS teacher_code,
    sub.subject_code AS subject_code,
    c.code AS class_code,
    sec.code AS section_code,
    ay.code AS academic_year_code,
    tsa.assignment_type::text AS assignment_type,
    tsa.weekly_periods::text AS weekly_periods,
    TO_CHAR(tsa.effective_from, 'YYYY-MM-DD') AS effective_from
FROM teacher_subject_assignments tsa
JOIN teachers t ON tsa.teacher_id = t.id
JOIN subjects sub ON tsa.subject_id = sub.id
JOIN classes c ON tsa.class_id = c.id
JOIN sections sec ON tsa.section_id = sec.id
JOIN academic_years ay ON tsa.academic_year_id = ay.id
WHERE tsa.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR tsa.school_id = :school_id)
ORDER BY c.level ASC, sec.code ASC, sub.subject_code ASC;


-- ============================================================================
-- 11. WORKSHEET: timetable (Timetable Slots)
-- ============================================================================
SELECT
    ay.code AS academic_year_code,
    tt.day_of_week::text AS day_of_week,
    tt.period_number::text AS period_number,
    TO_CHAR(tt.start_time, 'HH24:MI:SS') AS start_time,
    TO_CHAR(tt.end_time, 'HH24:MI:SS') AS end_time,
    c.code AS class_code,
    sec.code AS section_code,
    sub.subject_code AS subject_code,
    t.staff_code AS teacher_code,
    COALESCE(tt.room_number, sec.room_number, '101') AS room_number,
    tt.period_type::text AS period_type
FROM timetables tt
JOIN academic_years ay ON tt.academic_year_id = ay.id
JOIN classes c ON tt.class_id = c.id
JOIN sections sec ON tt.section_id = sec.id
JOIN teacher_subject_assignments tsa ON tt.teacher_subject_assignment_id = tsa.id
JOIN teachers t ON tsa.teacher_id = t.id
JOIN subjects sub ON tsa.subject_id = sub.id
WHERE tt.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR tt.school_id = :school_id)
ORDER BY c.level ASC, sec.code ASC, tt.day_of_week ASC, tt.period_number ASC;


-- ============================================================================
-- 12. WORKSHEET: syllabus (Syllabus Metadata)
-- ============================================================================
SELECT
    ay.code AS academic_year_code,
    c.code AS class_code,
    sub.subject_code AS subject_code,
    syl.syllabus_code AS syllabus_code,
    syl.unit_name AS unit_name,
    syl.chapter_name AS chapter_name,
    syl.topic_name AS topic_name,
    COALESCE(syl.description, '') AS description,
    syl.sequence_order::text AS sequence_order
FROM syllabuses syl
JOIN academic_years ay ON syl.academic_year_id = ay.id
JOIN classes c ON syl.class_id = c.id
JOIN subjects sub ON syl.subject_id = sub.id
WHERE syl.school_id IN (SELECT id FROM schools WHERE tenant_id = :tenant_id)
  AND (:school_id IS NULL OR syl.school_id = :school_id)
ORDER BY c.level ASC, sub.subject_code ASC, syl.sequence_order ASC;


-- ============================================================================
-- 13. WORKSHEET: exams (Exams & Documents)
-- ============================================================================
SELECT
    ay.code AS academic_year_code,
    COALESCE(e.settings->>'exam_code', 'EXAM_' || e.exam_type || '_' || c.code || '_' || sub.subject_code) AS exam_code,
    e.exam_name AS exam_name,
    e.exam_type::text AS exam_type,
    c.code AS class_code,
    sub.subject_code AS subject_code,
    TO_CHAR(COALESCE(es.exam_date, e.start_date), 'YYYY-MM-DD') AS exam_date,
    COALESCE(es.max_marks, 100)::text AS maximum_marks,
    COALESCE(e.settings->>'duration_minutes', '180') AS duration_minutes
FROM examinations e
JOIN academic_years ay ON e.academic_year_id = ay.id
LEFT JOIN exam_schedules es ON es.exam_id = e.id
LEFT JOIN classes c ON es.class_id = c.id
LEFT JOIN subjects sub ON es.subject_id = sub.id
WHERE e.tenant_id = :tenant_id
  AND (:school_id IS NULL OR e.school_id = :school_id)
ORDER BY e.start_date ASC, c.level ASC, sub.subject_code ASC;


-- ============================================================================
-- 14. SUPPLEMENTAL: Marks Data Extraction (Quarterly / Term Evaluation)
-- ============================================================================
SELECT
    stu.admission_number AS admission_number,
    stu.first_name || ' ' || stu.last_name AS student_name,
    c.code AS class_code,
    sec.code AS section_code,
    sub.subject_code AS subject_code,
    e.exam_name AS exam_name,
    e.exam_type::text AS exam_type,
    m.maximum_marks::text AS maximum_marks,
    m.marks_obtained::text AS marks_obtained,
    COALESCE(m.grade, '') AS grade,
    m.result_status::text AS result_status,
    COALESCE(m.remarks, '') AS remarks
FROM marks m
JOIN students stu ON m.student_id = stu.id
JOIN examinations e ON m.examination_id = e.id
JOIN classes c ON m.class_id = c.id
JOIN sections sec ON m.section_id = sec.id
JOIN subjects sub ON m.subject_id = sub.id
WHERE m.tenant_id = :tenant_id
  AND (:school_id IS NULL OR m.school_id = :school_id)
ORDER BY c.level ASC, sec.code ASC, stu.admission_number ASC, sub.subject_code ASC;
