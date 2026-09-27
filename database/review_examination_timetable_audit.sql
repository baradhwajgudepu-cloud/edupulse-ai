-- ============================================================================
-- EDUPULSE AI — PRODUCTION AUDIT & VERIFICATION SCRIPT (REVIEW-ONLY)
-- ============================================================================
-- SAFETY DIRECTIVE:
--   This script contains STRICTLY READ-ONLY (SELECT) statements.
--   It executes NO mutations, updates, insertions, or schema alterations.
-- ============================================================================

-- 1. AUDIT: Active Examinations & Class Schedule Scope
SELECT 
    e.id AS examination_id,
    e.name AS examination_name,
    e.code AS exam_code,
    e.term,
    e.status,
    e.start_date,
    e.end_date,
    COUNT(DISTINCT es.class_id) AS scheduled_classes_count,
    COUNT(DISTINCT es.id) AS total_papers_scheduled
FROM examinations e
LEFT JOIN exam_schedules es ON e.id = es.examination_id AND es.deleted_at IS NULL
WHERE e.deleted_at IS NULL
GROUP BY e.id, e.name, e.code, e.term, e.status, e.start_date, e.end_date
ORDER BY e.start_date DESC;


-- 2. AUDIT: Examination Dropdown & Class Filtering Integrity
SELECT 
    e.id AS examination_id,
    e.name AS examination_name,
    c.id AS class_id,
    c.name AS class_name,
    sec.id AS section_id,
    sec.name AS section_name,
    sub.subject_name,
    es.exam_date,
    es.start_time,
    es.end_time,
    es.max_marks
FROM examinations e
JOIN exam_schedules es ON e.id = es.examination_id AND es.deleted_at IS NULL
JOIN classes c ON es.class_id = c.id
LEFT JOIN sections sec ON es.section_id = sec.id
LEFT JOIN subjects sub ON es.subject_id = sub.id
WHERE e.deleted_at IS NULL
ORDER BY e.name, c.level, sec.name, es.exam_date;


-- 3. AUDIT: Bulk Marks Upload & Grading Records
SELECT 
    m.examination_id,
    e.name AS exam_name,
    m.class_id,
    c.name AS class_name,
    m.section_id,
    sec.name AS section_name,
    m.subject_id,
    sub.subject_name,
    COUNT(m.id) AS total_marks_records,
    COUNT(CASE WHEN m.status = 'PUBLISHED' THEN 1 END) AS published_count,
    COUNT(CASE WHEN m.status = 'SUBMITTED' THEN 1 END) AS submitted_count,
    COUNT(CASE WHEN m.status = 'DRAFT' THEN 1 END) AS draft_count,
    ROUND(AVG(m.marks_obtained), 2) AS average_score
FROM marks m
JOIN examinations e ON m.examination_id = e.id
JOIN classes c ON m.class_id = c.id
LEFT JOIN sections sec ON m.section_id = sec.id
LEFT JOIN subjects sub ON m.subject_id = sub.id
WHERE m.deleted_at IS NULL
GROUP BY m.examination_id, e.name, m.class_id, c.name, m.section_id, sec.name, m.subject_id, sub.subject_name
ORDER BY e.name, c.name, sec.name;


-- 4. AUDIT: Bulk Import Jobs History
SELECT 
    ij.id AS job_id,
    ij.tenant_id,
    ij.school_id,
    ij.job_type,
    ij.status,
    ij.total_records,
    ij.processed_records,
    ij.successful_records,
    ij.failed_records,
    ij.error_summary,
    ij.created_at,
    ij.completed_at
FROM import_jobs ij
WHERE ij.job_type IN ('MARKS', 'EXAM_MARKS', 'BULK_MARKS', 'TIMETABLE')
   OR ij.job_type IS NULL
ORDER BY ij.created_at DESC
LIMIT 50;


-- 5. AUDIT: Timetable Scheduling & Teacher Conflict Check
SELECT 
    t1.school_id,
    t1.day_of_week,
    t1.start_time,
    t1.end_time,
    t1.teacher_id,
    COUNT(*) AS overlapping_slots_count
FROM timetables t1
WHERE t1.deleted_at IS NULL
  AND t1.teacher_id IS NOT NULL
GROUP BY t1.school_id, t1.day_of_week, t1.start_time, t1.end_time, t1.teacher_id
HAVING COUNT(*) > 1;


-- 6. AUDIT: Timetable Room Conflict Check
SELECT 
    t1.school_id,
    t1.day_of_week,
    t1.start_time,
    t1.end_time,
    t1.room_number,
    COUNT(*) AS overlapping_rooms_count
FROM timetables t1
WHERE t1.deleted_at IS NULL
  AND t1.room_number IS NOT NULL
  AND t1.room_number <> ''
GROUP BY t1.school_id, t1.day_of_week, t1.start_time, t1.end_time, t1.room_number
HAVING COUNT(*) > 1;
