from fastapi import APIRouter
from app.api.v1.endpoints import health, tenants, schools, academic_years, auth, classes, sections, students, guardians, student_guardians, teachers, subjects, teacher_subject_assignments, timetables, attendances, homeworks, examinations, marks, report_cards, ai, notifications, syllabuses, teacher_ai

api_router = APIRouter()

# Include system-level endpoints (e.g. system/health)
api_router.include_router(health.router, prefix="/system", tags=["system"])
api_router.include_router(health.router, prefix="", tags=["system"])

# Include authentication & RBAC endpoints (no prefix, endpoints themselves have prefix)
api_router.include_router(auth.router, prefix="", tags=["auth"])

# Include tenants endpoints
api_router.include_router(tenants.router, prefix="/tenants", tags=["tenants"])

# Include schools endpoints
api_router.include_router(schools.router, prefix="/schools", tags=["schools"])

# Include academic_years endpoints (using school path parameters)
api_router.include_router(academic_years.router, prefix="/schools/{school_id}/academic-years", tags=["academic_years"])

# Include classes endpoints
api_router.include_router(classes.router, prefix="/classes", tags=["classes"])

# Include sections endpoints
api_router.include_router(sections.router, prefix="/sections", tags=["sections"])

# Include students endpoints
api_router.include_router(students.router, prefix="/students", tags=["students"])

# Include guardians endpoints
api_router.include_router(guardians.router, prefix="/guardians", tags=["guardians"])

# Include student_guardians endpoints
api_router.include_router(student_guardians.router, prefix="/student-guardians", tags=["student-guardians"])

# Include teachers endpoints
api_router.include_router(teachers.router, prefix="/teachers", tags=["teachers"])

# Include subjects endpoints
api_router.include_router(subjects.router, prefix="/subjects", tags=["subjects"])

# Include teacher_subject_assignments endpoints
api_router.include_router(teacher_subject_assignments.router, prefix="/teacher-subject-assignments", tags=["teacher-subject-assignments"])

# Include timetables endpoints
api_router.include_router(timetables.router, prefix="/timetables", tags=["timetables"])

# Include attendances endpoints
api_router.include_router(attendances.router, prefix="/attendances", tags=["attendances"])

# Include homeworks endpoints
api_router.include_router(homeworks.router, prefix="/homeworks", tags=["homeworks"])

# Include examinations endpoints
api_router.include_router(examinations.router, prefix="/examinations", tags=["examinations"])

# Include marks endpoints
api_router.include_router(marks.router, prefix="/marks", tags=["marks"])

# Include report-cards endpoints
api_router.include_router(report_cards.router, prefix="/report-cards", tags=["report-cards"])

# Include ai endpoints
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])

# Include teacher-ai endpoints
api_router.include_router(teacher_ai.router, prefix="/teacher-ai", tags=["teacher-ai"])

# Include notifications endpoints
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])

# Include notification preferences endpoints
api_router.include_router(notifications.preferences_router, prefix="/notification-preferences", tags=["notification-preferences"])

# Include identity provisioning endpoints
from app.api.v1.endpoints import identity
api_router.include_router(identity.router, prefix="/identity", tags=["identity"])

# Include staff attendance endpoints
from app.api.v1.endpoints import staff_attendance
api_router.include_router(staff_attendance.router, prefix="/staff-attendance", tags=["staff-attendance"])

# Include fee management endpoints
from app.api.v1.endpoints import fee
api_router.include_router(fee.router, prefix="/fees", tags=["fees"])

# Include import-jobs endpoints
from app.api.v1.endpoints import import_jobs
api_router.include_router(import_jobs.router, prefix="/import-jobs", tags=["import-jobs"])

# Include syllabus metadata endpoints
api_router.include_router(syllabuses.router, prefix="/syllabuses", tags=["syllabuses"])

# Include reports endpoints
from app.api.v1.endpoints import reports
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])

# Include teacher-leaves endpoints
from app.api.v1.endpoints import teacher_leave
api_router.include_router(teacher_leave.router, prefix="/teacher-leaves", tags=["teacher-leaves"])


# Include communication endpoints
from app.api.v1.endpoints import communication
api_router.include_router(communication.router, prefix="/communication", tags=["communication"])

# Include events, announcements, calendar feed, and action-items endpoints
from app.api.v1.endpoints import events, announcements, calendar, action_items, ai_intelligence
api_router.include_router(events.router, prefix="/events", tags=["events"])
api_router.include_router(announcements.router, prefix="/announcements", tags=["announcements"])
api_router.include_router(calendar.router, prefix="/calendar", tags=["calendar"])
api_router.include_router(action_items.router, prefix="/principal", tags=["principal"])
api_router.include_router(ai_intelligence.router, prefix="/ai-intelligence", tags=["ai-intelligence"])


