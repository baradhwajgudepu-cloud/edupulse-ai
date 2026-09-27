import uuid
from typing import Dict, List
from sqlalchemy import select, or_, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.role import Role, role_permissions
from app.models.permission import Permission

ROLE_NAMES_MAP = {
    "ADMIN": "Administrator",
    "PRINCIPAL": "Principal",
    "TEACHER": "Teacher",
    "PARENT": "Parent",
    "STUDENT": "Student",
    "STAFF": "Staff"
}

ROLE_PERMISSIONS_MAP = {
    "ADMIN": [
        # School & Base Structure
        "tenant.read", "school.read", "school.update",
        "academic_year.create", "academic_year.read", "academic_year.update", "academic_year.delete",
        "class.create", "class.read", "class.update", "class.delete", "class.archive", "class.promote",
        "section.create", "section.read", "section.update", "section.delete",
        "subject.create", "subject.read", "subject.update", "subject.delete",
        "syllabus.create", "syllabus.read", "syllabus.update", "syllabus.delete",
        "timetable.create", "timetable.read", "timetable.update", "timetable.delete",
        # Students & Guardians
        "student.create", "student.read", "student.update", "student.delete",
        "guardian.create", "guardian.read", "guardian.update", "guardian.delete",
        # Teachers & Assignments
        "teacher.create", "teacher.read", "teacher.update", "teacher.delete",
        "teacher_subject_assignment.create", "teacher_subject_assignment.read", "teacher_subject_assignment.update", "teacher_subject_assignment.delete",
        # Attendance & Leaves
        "attendance.create", "attendance.read", "attendance.update", "attendance.delete",
        "staff_attendance.create", "staff_attendance.read", "staff_attendance.update", "staff_attendance.admin",
        "teacher_leave.create", "teacher_leave.read", "teacher_leave.review", "teacher_leave.cancel", "teacher_leave.admin",
        # Examinations, Marks & Report Cards
        "exam.create", "exam.read", "exam.update", "exam.delete",
        "marks.create", "marks.read", "marks.update", "marks.delete", "marks.publish",
        "report_card.generate", "report_card.read", "report_card.download", "report_card.publish",
        # Homework
        "homework.create", "homework.read", "homework.update", "homework.delete",
        # Fee Management
        "fee.create", "fee.read", "fee.update", "fee.delete", "fee.pay", "fee.cancel", "fee.report",
        # School Planner & Notifications
        "event.create", "event.read", "event.update", "event.delete", "event.publish",
        "announcement.create", "announcement.read", "announcement.update", "announcement.delete", "announcement.publish",
        "notification.create", "notification.read", "notification.update", "notification.delete", "notification.mark_read",
        # User Management & Identity
        "user.create", "user.read", "user.update",
        "identity.create", "identity.read", "identity.update", "identity.provision", "identity.reset_password",
        "role.create", "role.read", "role.update", "permission.read",
        # Settings & Reports & Intelligence
        "reports.read", "reports.academic.read", "reports.attendance.read", "reports.fees.read", "reports.ai.read", "reports.export",
        "ai.use",
        "settings.read", "settings.update", "settings.school.update", "settings.academic.update", "settings.grading.update", "settings.exam.update", "settings.report_card.update",
        # Migrations
        "migration.create", "migration.read", "migration.execute", "migration.cancel"
    ],
    "PRINCIPAL": [
        # School & Base Structure
        "tenant.read", "school.read", "school.update",
        "academic_year.create", "academic_year.read", "academic_year.update",
        "class.create", "class.read", "class.update", "class.delete", "class.archive", "class.promote",
        "section.create", "section.read", "section.update", "section.delete",
        "subject.create", "subject.read", "subject.update", "subject.delete",
        "syllabus.create", "syllabus.read", "syllabus.update", "syllabus.delete",
        "timetable.create", "timetable.read", "timetable.update", "timetable.delete",
        # Students & Guardians
        "student.create", "student.read", "student.update", "student.delete",
        "guardian.create", "guardian.read", "guardian.update", "guardian.delete",
        # Teachers & Assignments
        "teacher.create", "teacher.read", "teacher.update", "teacher.delete",
        "teacher_subject_assignment.create", "teacher_subject_assignment.read", "teacher_subject_assignment.update", "teacher_subject_assignment.delete",
        # Attendance & Leaves
        "attendance.create", "attendance.read", "attendance.update", "attendance.delete",
        "staff_attendance.create", "staff_attendance.read", "staff_attendance.update", "staff_attendance.admin",
        "teacher_leave.create", "teacher_leave.read", "teacher_leave.review", "teacher_leave.cancel", "teacher_leave.admin",
        # Examinations, Marks & Report Cards
        "exam.create", "exam.read", "exam.update", "exam.delete",
        "marks.create", "marks.read", "marks.update", "marks.delete", "marks.publish",
        "report_card.generate", "report_card.read", "report_card.download", "report_card.publish",
        # Homework
        "homework.create", "homework.read", "homework.update", "homework.delete",
        # Fee Management
        "fee.create", "fee.read", "fee.update", "fee.delete", "fee.pay", "fee.cancel", "fee.report",
        # School Planner & Notifications
        "event.create", "event.read", "event.update", "event.delete", "event.publish",
        "announcement.create", "announcement.read", "announcement.update", "announcement.delete", "announcement.publish",
        "notification.create", "notification.read", "notification.update", "notification.delete", "notification.mark_read",
        # User Management & Identity
        "user.create", "user.read", "user.update",
        "identity.create", "identity.read", "identity.update", "identity.provision", "identity.reset_password",
        "role.read", "permission.read",
        # Settings & Reports & Intelligence
        "reports.read", "reports.academic.read", "reports.attendance.read", "reports.fees.read", "reports.ai.read", "reports.export",
        "ai.use",
        "settings.read", "settings.update", "settings.school.update", "settings.academic.update", "settings.grading.update", "settings.exam.update", "settings.report_card.update",
        # Migrations
        "migration.create", "migration.read", "migration.execute", "migration.cancel"
    ],
    "TEACHER": [
        # Base Academic Permissions
        "academic_year.read", "class.read", "section.read", "subject.read", "teacher.read",
        "teacher_subject_assignment.read", "timetable.read", "student.read",
        "syllabus.read", "syllabus.update",
        # Student Attendance
        "attendance.read", "attendance.create", "attendance.update",
        # Homework
        "homework.read", "homework.create", "homework.update", "homework.delete",
        # Examinations & Marks
        "exam.read", "marks.read", "marks.create", "marks.update", "marks.publish",
        "report_card.read", "report_card.generate",
        # Staff Attendance & Leaves
        "staff_attendance.read", "staff_attendance.create", "staff_attendance.update",
        "teacher_leave.read", "teacher_leave.create", "teacher_leave.cancel",
        # School Planner Read Access
        "event.read", "announcement.read",
        # Notifications
        "notification.read", "notification.mark_read",
        # Fee Read Access
        "fee.read"
    ],
    "PARENT": [
        # Student & Guardian Read Access
        "student.read", "guardian.read",
        # Academics & Attendance Read Access
        "attendance.read", "homework.read", "exam.read", "marks.read",
        "report_card.read", "report_card.download",
        # Fee Read & Online Payment Access
        "fee.read", "fee.pay",
        # Events, Announcements & Notifications Read Access
        "event.read", "announcement.read",
        "notification.read", "notification.mark_read"
    ],
    "STUDENT": [],
    "STAFF": [
        # Migrations
        "migration.read", "migration.create",
        # Notifications
        "notification.read", "notification.mark_read",
        # Fees
        "fee.create", "fee.read", "fee.update", "fee.delete", "fee.pay", "fee.cancel", "fee.report"
    ]
}

async def ensure_tenant_rbac(session: AsyncSession, tenant_id: uuid.UUID) -> None:
    """
    Idempotently verifies and repairs the required tenant RBAC state.
    Creates missing system roles, seeds missing permission mappings,
    and preserves existing mappings without deleting any.
    """
    # 1. Fetch all system permissions from the database
    stmt_perms = select(Permission).where(Permission.deleted_at.is_(None))
    res_perms = await session.execute(stmt_perms)
    db_permissions = {p.code: p for p in res_perms.scalars().all()}

    # 2. Iterate through each system role and initialize it
    for code, name in ROLE_NAMES_MAP.items():
        # Check if the role already exists for this tenant
        stmt_role = select(Role).where(
            Role.tenant_id == tenant_id,
            Role.code == code,
            Role.deleted_at.is_(None)
        )
        
        res_role = await session.execute(stmt_role)
        role = res_role.scalar_one_or_none()

        if not role:
            role = Role(
                name=name,
                code=code,
                description=f"System-default {name} role",
                tenant_id=tenant_id,
                is_system=True
            )
            session.add(role)
            # Flush to generate role ID before mapping permissions
            await session.flush()
        
        # 3. Query existing permission mappings via join query to avoid lazy load issues
        stmt_existing = select(Permission.code).join(
            role_permissions,
            Permission.id == role_permissions.c.permission_id
        ).where(role_permissions.c.role_id == role.id)
        
        res_existing = await session.execute(stmt_existing)
        existing_codes = set(res_existing.scalars().all())

        intended_codes = ROLE_PERMISSIONS_MAP.get(code, [])
        
        # 4. Insert missing role-permission associations directly into the join table
        for p_code in intended_codes:
            if p_code in db_permissions and p_code not in existing_codes:
                stmt_insert = role_permissions.insert().values(
                    role_id=role.id,
                    permission_id=db_permissions[p_code].id
                )
                await session.execute(stmt_insert)

    # Flush all changes to database in this transaction block
    await session.flush()

async def initialize_tenant_rbac(session: AsyncSession, tenant_id: uuid.UUID) -> None:
    """
    Used during tenant creation to initialize all default system roles and permissions.
    """
    await ensure_tenant_rbac(session, tenant_id)
