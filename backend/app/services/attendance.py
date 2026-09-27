import uuid
import io
import csv
import time
import logging
from datetime import date, datetime, timezone, timedelta
from typing import List, Optional, Tuple, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy import select, and_, or_, func, text

from app.models.attendance import (
    AttendanceSession, Attendance, AttendanceAuditLog,
    AttendanceSessionStatus, AttendanceStatus, AttendanceSource, AttendanceReason,
    AttendanceSessionType, AttendanceAction
)
from app.models.student import Student
from app.models.timetable import Timetable
from app.models.class_entity import Class
from app.models.section import Section
from app.models.teacher import Teacher
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.user import User
from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.repositories.attendance import AttendanceRepository
from app.repositories.student import StudentRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.attendance import (
    AttendanceSessionCreate, AttendanceSessionUpdate, BulkAttendanceMark,
    StudentAttendanceRecord, AttendanceCorrectionUpdate, DailyAttendanceMarkRequest,
    BulkValidateRowPreview, BulkAttendanceChunkRequest, BulkAttendanceChunkResponse,
    BulkAttendanceChunkTiming
)
from app.services.notification import NotificationService
from app.utils.spreadsheet_reader import read_spreadsheet, normalize_header

logger = logging.getLogger(__name__)

class AttendanceService:
    """
    Service Layer implementing business validations and bulk submissions for Student Attendance.
    """
    def __init__(
        self,
        attendance_repo: AttendanceRepository,
        student_repo: StudentRepository,
        timetable_repo: TimetableRepository,
        academic_year_repo: AcademicYearRepository,
        notification_service: NotificationService
    ) -> None:
        self.attendance_repo = attendance_repo
        self.student_repo = student_repo
        self.timetable_repo = timetable_repo
        self.academic_year_repo = academic_year_repo
        self.notification_service = notification_service

    async def create_session(
        self,
        tenant_id: uuid.UUID,
        obj_in: AttendanceSessionCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> AttendanceSession:
        """
        Starts a new attendance marking session for a timetable slot and date.
        """
        # Validate Academic Year
        ay = await self.academic_year_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Academic year not found.")

        # Date range check
        if obj_in.attendance_date < ay.start_date or obj_in.attendance_date > ay.end_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Attendance date must fall within the selected academic year start and end dates."
            )

        # Validate Timetable Slot
        timetable = await self.timetable_repo.get_by_id(obj_in.timetable_id, obj_in.school_id, tenant_id)
        if not timetable or not timetable.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Target timetable slot is not active or not found."
            )

        # Ensure no active session already exists for this slot + date
        existing_session = await self.attendance_repo.get_session_by_slot(
            obj_in.timetable_id, obj_in.attendance_date, tenant_id
        )
        if existing_session:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Attendance Session already exists for this timetable slot and date."
            )

        db_obj = await self.attendance_repo.create_session(
            tenant_id=tenant_id,
            obj_in=obj_in,
            class_id=timetable.class_id,
            section_id=timetable.section_id,
            teacher_id=timetable.teacher_id,
            subject_id=timetable.subject_id,
            created_by=created_by
        )
        await self.attendance_repo.db.commit()
        return await self.attendance_repo.get_session_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def bulk_mark_attendance(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        session_id: uuid.UUID,
        obj_in: BulkAttendanceMark,
        current_user: User
    ) -> AttendanceSession:
        """
        Marks attendance for multiple students under the session in a single database transaction.
        Checks lock statuses and pupil class placement mismatches.
        """
        session_obj = await self.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance session not found."
            )

        # Verify Lock status
        if session_obj.status == AttendanceSessionStatus.LOCKED:
            # Check roles: Admin, Principal or Super Admin are allowed to bypass lock.
            is_admin = current_user.is_superuser
            for role in current_user.roles:
                if role.code in ["SUPER_ADMIN", "ADMIN", "PRINCIPAL"]:
                    is_admin = True
                    break
            if not is_admin:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="This attendance session is locked and cannot be updated."
                )

        # 1. In-memory validation phase (avoid partial fails)
        student_records = {}
        for rec in obj_in.records:
            student = await self.student_repo.get_by_id(rec.student_id, school_id, tenant_id)
            if not student or not student.is_active:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Student {rec.student_id} not found or inactive."
                )
            
            # Placement boundary check
            if student.class_id != session_obj.class_id or student.section_id != session_obj.section_id:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Student {student.first_name} {student.last_name} does not belong to this class/section."
                )

            student_records[rec.student_id] = rec

        # 2. Database transaction write phase
        now_dt = datetime.now(timezone.utc)
        
        # Load existing marked logs under the session to avoid duplicate conflicts
        existing_logs = {log.student_id: log for log in session_obj.attendances}

        for student_id, rec in student_records.items():
            if student_id in existing_logs:
                # Update existing log
                log_obj = existing_logs[student_id]
                log_obj.attendance_status = rec.attendance_status
                log_obj.attendance_source = rec.attendance_source
                log_obj.attendance_reason = rec.attendance_reason
                log_obj.remarks = rec.remarks
                log_obj.updated_by = current_user.id
                self.attendance_repo.db.add(log_obj)
            else:
                # Add new attendance record, checking unique slot constraints first
                dup_check = await self.attendance_repo.get_duplicate_attendance(
                    student_id, session_obj.timetable_id, session_obj.attendance_date, tenant_id
                )
                if dup_check:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="Attendance already marked for this student for this timetable slot on this date."
                    )

                await self.attendance_repo.create_attendance(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=session_obj.academic_year_id,
                    session_id=session_obj.id,
                    student_id=student_id,
                    timetable_id=session_obj.timetable_id,
                    class_id=session_obj.class_id,
                    section_id=session_obj.section_id,
                    teacher_id=session_obj.teacher_id,
                    subject_id=session_obj.subject_id,
                    attendance_date=session_obj.attendance_date,
                    record=rec,
                    created_by=current_user.id
                )

        # Update Session marked metadata
        session_obj.status = obj_in.attendance_session_status or AttendanceSessionStatus.SUBMITTED
        session_obj.marked_by = current_user.id
        session_obj.marked_at = now_dt
        session_obj.updated_by = current_user.id
        self.attendance_repo.db.add(session_obj)

        await self.attendance_repo.db.commit()

        # Trigger notifications for each student record marked
        for student_id, rec in student_records.items():
            try:
                await self.notification_service.notify_attendance(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    student_id=student_id,
                    attendance_date=session_obj.attendance_date,
                    status_val=rec.attendance_status.value
                )
            except Exception as ne:
                logger.error(f"Failed to send attendance notification: {str(ne)}", exc_info=True)

        self.attendance_repo.db.expire(session_obj)
        return await self.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)

    async def lock_session(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        session_id: uuid.UUID,
        current_user: User
    ) -> AttendanceSession:
        """
        Locks an attendance session, blocking all future teacher modifications.
        Only Admin/Principal users are allowed.
        """
        # Role check
        is_admin = current_user.is_superuser
        for role in current_user.roles:
            if role.code in ["SUPER_ADMIN", "ADMIN", "PRINCIPAL"]:
                is_admin = True
                break
        if not is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only Principal or Administrator roles can lock/unlock attendance sessions."
            )

        session_obj = await self.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance session not found."
            )

        session_obj.status = AttendanceSessionStatus.LOCKED
        session_obj.updated_by = current_user.id
        self.attendance_repo.db.add(session_obj)
        await self.attendance_repo.db.commit()
        self.attendance_repo.db.expire(session_obj)
        return await self.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)

    async def delete_session(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        session_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> AttendanceSession:
        """
        Soft deletes the attendance session and all child logs.
        """
        session_obj = await self.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance session not found."
            )

        await self.attendance_repo.soft_delete_session(session_obj, deleted_by=deleted_by)
        await self.attendance_repo.db.commit()
        await self.attendance_repo.db.refresh(session_obj)
        session_obj.attendances = []
        return session_obj

    async def correct_student_attendance(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        session_id: uuid.UUID,
        student_id: uuid.UUID,
        obj_in: AttendanceCorrectionUpdate,
        current_user: User
    ) -> Attendance:
        """
        Corrects a student's individual attendance status under an unlocked session.
        Records previous status audit logs in the settings JSONB column.
        """
        session_obj = await self.attendance_repo.get_session_by_id(session_id, school_id, tenant_id)
        if not session_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance session not found."
            )

        # Locked checks (superuser bypass permitted)
        if session_obj.status == AttendanceSessionStatus.LOCKED:
            is_admin = current_user.is_superuser
            for role in current_user.roles:
                if role.code in ["SUPER_ADMIN", "ADMIN", "PRINCIPAL"]:
                    is_admin = True
                    break
            if not is_admin:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="This attendance session is locked and cannot be updated."
                )

        # Load individual attendance log
        log_obj = await self.attendance_repo.get_attendance_by_session_student(session_id, student_id, tenant_id)
        if not log_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attendance record not found for student in this session."
            )

        prev_status = log_obj.attendance_status
        new_status = obj_in.attendance_status

        # Compile audit entry
        audit_entry = {
            "previous_status": prev_status.value,
            "new_status": new_status.value,
            "updated_by": str(current_user.id),
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "reason_for_change": obj_in.correction_reason
        }

        # Save to settings["audit_logs"]
        settings_dict = dict(log_obj.settings or {})
        audit_logs = settings_dict.setdefault("audit_logs", [])
        audit_logs.append(audit_entry)
        log_obj.settings = settings_dict

        # Update other fields
        log_obj.attendance_status = new_status
        log_obj.attendance_source = obj_in.attendance_source or log_obj.attendance_source
        log_obj.attendance_reason = obj_in.attendance_reason or log_obj.attendance_reason
        log_obj.remarks = obj_in.remarks
        log_obj.updated_by = current_user.id

        self.attendance_repo.db.add(log_obj)

        role_code = self.get_user_role_code(current_user)
        await self.attendance_repo.create_audit_log(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student_id,
            attendance_date=session_obj.attendance_date,
            session_type=session_obj.session_type.value if hasattr(session_obj.session_type, 'value') else str(session_obj.session_type),
            old_status=prev_status.value if hasattr(prev_status, 'value') else str(prev_status),
            new_status=new_status.value if hasattr(new_status, 'value') else str(new_status),
            action=AttendanceAction.UPDATE.value,
            changed_by=current_user.id,
            changed_by_role=role_code,
            source=log_obj.attendance_source.value if hasattr(log_obj.attendance_source, 'value') else str(log_obj.attendance_source),
            attendance_id=log_obj.id,
            reason=obj_in.correction_reason
        )

        await self.attendance_repo.db.commit()
        await self.attendance_repo.db.refresh(log_obj)
        return log_obj

    # ==================================================
    # Role Scoping & Access Control Helpers
    # ==================================================

    def get_user_role_code(self, user: User) -> str:
        if user.is_superuser:
            return "SUPER_ADMIN"
        for r in getattr(user, "roles", []):
            code = getattr(r, "code", "")
            if code in ["SUPER_ADMIN", "SYSTEM_ADMIN"]:
                return "SUPER_ADMIN"
            if code in ["TENANT_ADMIN", "ADMIN", "CHAIRMAN"]:
                return "TENANT_ADMIN"
            if code in ["PRINCIPAL", "SCHOOL_ADMIN"]:
                return "PRINCIPAL"
            if code == "TEACHER":
                return "TEACHER"
            if code in ["PARENT", "GUARDIAN"]:
                return "PARENT"
        return "USER"

    async def get_teacher_assigned_classes(
        self, current_user: User, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[uuid.UUID]:
        teacher_stmt = select(Teacher).where(
            Teacher.user_id == current_user.id,
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        teacher_res = await self.attendance_repo.db.execute(teacher_stmt)
        teacher = teacher_res.scalar_one_or_none()
        if not teacher:
            return []

        assign_stmt = select(TeacherSubjectAssignment.class_id).where(
            TeacherSubjectAssignment.teacher_id == teacher.id,
            TeacherSubjectAssignment.school_id == school_id,
            TeacherSubjectAssignment.tenant_id == tenant_id,
            TeacherSubjectAssignment.deleted_at.is_(None)
        ).distinct()
        assign_res = await self.attendance_repo.db.execute(assign_stmt)
        class_ids = set(assign_res.scalars().all())

        tt_stmt = select(Timetable.class_id).where(
            Timetable.teacher_id == teacher.id,
            Timetable.school_id == school_id,
            Timetable.tenant_id == tenant_id,
            Timetable.deleted_at.is_(None)
        ).distinct()
        tt_res = await self.attendance_repo.db.execute(tt_stmt)
        class_ids.update(tt_res.scalars().all())

        return list(class_ids)

    async def verify_teacher_class_access(
        self, current_user: User, school_id: uuid.UUID, class_id: uuid.UUID, section_id: Optional[uuid.UUID], tenant_id: uuid.UUID
    ) -> None:
        role = self.get_user_role_code(current_user)
        if role in ["SUPER_ADMIN", "TENANT_ADMIN", "PRINCIPAL"]:
            return
        if role == "TEACHER":
            assigned_classes = await self.get_teacher_assigned_classes(current_user, school_id, tenant_id)
            if class_id not in assigned_classes:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. You are not assigned to this class."
                )
            if section_id:
                teacher_stmt = select(Teacher).where(
                    Teacher.user_id == current_user.id,
                    Teacher.school_id == school_id,
                    Teacher.tenant_id == tenant_id,
                    Teacher.deleted_at.is_(None)
                )
                t_res = await self.attendance_repo.db.execute(teacher_stmt)
                teacher = t_res.scalar_one_or_none()
                if not teacher:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Access denied. No active teacher profile found for user."
                    )

                assign_stmt = select(TeacherSubjectAssignment).where(
                    TeacherSubjectAssignment.teacher_id == teacher.id,
                    TeacherSubjectAssignment.school_id == school_id,
                    TeacherSubjectAssignment.tenant_id == tenant_id,
                    TeacherSubjectAssignment.class_id == class_id,
                    TeacherSubjectAssignment.section_id == section_id,
                    TeacherSubjectAssignment.deleted_at.is_(None)
                )
                res_asg = await self.attendance_repo.db.execute(assign_stmt)
                has_assignment = res_asg.scalar_one_or_none() is not None

                if not has_assignment:
                    tt_stmt = select(Timetable).where(
                        Timetable.teacher_id == teacher.id,
                        Timetable.school_id == school_id,
                        Timetable.tenant_id == tenant_id,
                        Timetable.class_id == class_id,
                        Timetable.section_id == section_id,
                        Timetable.deleted_at.is_(None)
                    )
                    res_tt = await self.attendance_repo.db.execute(tt_stmt)
                    has_assignment = res_tt.scalar_one_or_none() is not None

                if not has_assignment:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Access denied. You are not assigned to this class and section."
                    )
            return
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Unauthorized role for attendance operation."
        )

    # ==================================================
    # Manual Daily Attendance Marking
    # ==================================================

    async def mark_daily_attendance(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: DailyAttendanceMarkRequest,
        current_user: User
    ) -> AttendanceSession:
        role = self.get_user_role_code(current_user)
        if role == "PARENT":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Parents do not have permission to mark attendance."
            )
        
        await self.verify_teacher_class_access(
            current_user=current_user,
            school_id=school_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            tenant_id=tenant_id
        )

        if obj_in.attendance_date > date.today():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Future attendance dates are not permitted according to policy."
            )

        session_obj = await self.attendance_repo.get_or_create_daily_session(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            attendance_date=obj_in.attendance_date,
            session_type=obj_in.session_type,
            created_by=current_user.id
        )

        if session_obj.status == AttendanceSessionStatus.LOCKED and role not in ["SUPER_ADMIN", "TENANT_ADMIN", "PRINCIPAL"]:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="This attendance session is locked and cannot be edited by teachers."
            )

        att_stmt = select(Attendance).where(
            Attendance.attendance_session_id == session_obj.id,
            Attendance.deleted_at.is_(None)
        )
        att_res = await self.attendance_repo.db.execute(att_stmt)
        existing_logs = {log.student_id: log for log in att_res.scalars().all()}
        now_dt = datetime.now(timezone.utc)

        student_ids = [rec.student_id for rec in obj_in.records]
        if student_ids:
            st_stmt = select(Student).where(
                Student.id.in_(student_ids),
                Student.school_id == school_id,
                Student.tenant_id == tenant_id,
                Student.is_active == True,
                Student.deleted_at.is_(None)
            )
            st_res = await self.attendance_repo.db.execute(st_stmt)
            valid_students = {s.id: s for s in st_res.scalars().all()}

            for rec in obj_in.records:
                if rec.student_id not in valid_students:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Student {rec.student_id} not found or inactive in this school campus."
                    )
                st = valid_students[rec.student_id]
                if st.class_id != obj_in.class_id or st.section_id != obj_in.section_id:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Student {st.first_name} {st.last_name} ({st.admission_number}) is not in Class {obj_in.class_id} / Section {obj_in.section_id}."
                    )

        for rec in obj_in.records:
            if rec.student_id in existing_logs:
                log_obj = existing_logs[rec.student_id]
                old_status = log_obj.attendance_status
                new_status = rec.attendance_status

                if old_status != new_status or log_obj.remarks != rec.remarks:
                    log_obj.attendance_status = new_status
                    log_obj.attendance_source = rec.attendance_source or obj_in.attendance_source
                    log_obj.attendance_reason = rec.attendance_reason
                    log_obj.remarks = rec.remarks
                    log_obj.updated_by = current_user.id
                    self.attendance_repo.db.add(log_obj)

                    await self.attendance_repo.create_audit_log(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        student_id=rec.student_id,
                        attendance_date=obj_in.attendance_date,
                        session_type=obj_in.session_type.value if hasattr(obj_in.session_type, 'value') else str(obj_in.session_type),
                        old_status=old_status.value if hasattr(old_status, 'value') else str(old_status),
                        new_status=new_status.value if hasattr(new_status, 'value') else str(new_status),
                        action=AttendanceAction.UPDATE.value,
                        changed_by=current_user.id,
                        changed_by_role=role,
                        source=obj_in.attendance_source.value if hasattr(obj_in.attendance_source, 'value') else str(obj_in.attendance_source),
                        attendance_id=log_obj.id,
                        reason="Manual attendance update"
                    )
            else:
                new_log = await self.attendance_repo.create_attendance(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=obj_in.academic_year_id,
                    session_id=session_obj.id,
                    student_id=rec.student_id,
                    timetable_id=None,
                    class_id=obj_in.class_id,
                    section_id=obj_in.section_id,
                    teacher_id=None,
                    subject_id=None,
                    attendance_date=obj_in.attendance_date,
                    record=rec,
                    session_type=obj_in.session_type,
                    created_by=current_user.id
                )
                await self.attendance_repo.create_audit_log(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    student_id=rec.student_id,
                    attendance_date=obj_in.attendance_date,
                    session_type=obj_in.session_type.value if hasattr(obj_in.session_type, 'value') else str(obj_in.session_type),
                    old_status=None,
                    new_status=rec.attendance_status.value if hasattr(rec.attendance_status, 'value') else str(rec.attendance_status),
                    action=AttendanceAction.CREATE.value,
                    changed_by=current_user.id,
                    changed_by_role=role,
                    source=obj_in.attendance_source.value if hasattr(obj_in.attendance_source, 'value') else str(obj_in.attendance_source),
                    attendance_id=new_log.id,
                    reason="Manual attendance marking"
                )

        session_obj.status = AttendanceSessionStatus.SUBMITTED
        session_obj.marked_by = current_user.id
        session_obj.marked_at = now_dt
        target_session_id = session_obj.id
        self.attendance_repo.db.add(session_obj)

        await self.attendance_repo.db.commit()
        return await self.attendance_repo.get_session_by_id(target_session_id, school_id, tenant_id)

    # ==================================================
    # Bulk Excel / CSV Upload & Validation
    # ==================================================

    async def validate_bulk_attendance(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        file_bytes: bytes,
        filename: str,
        current_user: User
    ) -> Dict[str, Any]:
        role = self.get_user_role_code(current_user)
        if role not in ["SUPER_ADMIN", "TENANT_ADMIN", "PRINCIPAL"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only Principal and Administrator roles can upload attendance in bulk."
            )

        try:
            _, _, raw_rows = read_spreadsheet(file_bytes, filename)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Failed to parse spreadsheet file: {str(e)}"
            )

        if not raw_rows or len(raw_rows) < 2:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Spreadsheet contains no data rows (header row + at least 1 record required)."
            )

        header_row = [normalize_header(str(c)) for c in raw_rows[0]]
        
        # Determine column indexes
        col_adm = -1
        col_name = -1
        col_class = -1
        col_sec = -1
        col_date = -1
        col_sess = -1
        col_status = -1

        for idx, h in enumerate(header_row):
            if any(k in h for k in ["admission", "adm_no", "student_id"]):
                col_adm = idx
            elif any(k in h for k in ["name", "student_name"]):
                col_name = idx
            elif h in ["class", "class_name", "grade"]:
                col_class = idx
            elif h in ["section", "section_name", "sec"]:
                col_sec = idx
            elif any(k in h for k in ["date", "attendance_date"]):
                col_date = idx
            elif any(k in h for k in ["session", "session_type"]):
                col_sess = idx
            elif any(k in h for k in ["status", "attendance_status"]):
                col_status = idx

        if col_adm == -1:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Mandatory column 'Admission Number' not found in spreadsheet."
            )
        if col_date == -1:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Mandatory column 'Date' not found in spreadsheet."
            )
        if col_status == -1:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Mandatory column 'Status' not found in spreadsheet."
            )

        # Cache students in school
        students_res = await self.attendance_repo.db.execute(
            select(Student).where(
                Student.school_id == school_id,
                Student.tenant_id == tenant_id,
                Student.deleted_at.is_(None)
            )
        )
        students = list(students_res.scalars().all())
        students_by_adm = {
            s.admission_number.strip().lower(): s for s in students if s.admission_number
        }

        # Cache classes and sections
        classes_res = await self.attendance_repo.db.execute(
            select(Class).where(
                Class.school_id == school_id,
                Class.tenant_id == tenant_id,
                Class.deleted_at.is_(None)
            )
        )
        classes_by_name = {c.name.strip().lower(): c for c in classes_res.scalars().all()}

        sections_res = await self.attendance_repo.db.execute(
            select(Section).where(
                Section.school_id == school_id,
                Section.tenant_id == tenant_id,
                Section.deleted_at.is_(None)
            )
        )
        sections_by_name = {(s.class_id, s.name.strip().lower()): s for s in sections_res.scalars().all()}

        # Cache existing attendance records in database
        existing_att_res = await self.attendance_repo.db.execute(
            select(Attendance).where(
                Attendance.school_id == school_id,
                Attendance.tenant_id == tenant_id,
                Attendance.deleted_at.is_(None)
            )
        )
        existing_att_map = {
            (a.student_id, a.attendance_date, a.session_type): a
            for a in existing_att_res.scalars().all()
        }

        valid_count = 0
        invalid_count = 0
        duplicate_count = 0
        conflict_count = 0

        preview_rows = []
        errors = []
        seen_in_file = set()

        job_id = uuid.uuid4()
        import_job = ImportJob(
            id=job_id,
            tenant_id=tenant_id,
            school_id=school_id,
            import_type=ImportType.ATTENDANCE,
            status=ImportJobStatus.VALIDATED,
            source_filename=filename,
            total_rows=len(raw_rows) - 1,
            created_by=current_user.id,
            job_metadata={"academic_year_id": str(academic_year_id)}
        )
        self.attendance_repo.db.add(import_job)

        today_dt = date.today()
        status_enum_values = {e.value for e in AttendanceStatus}

        for r_idx, row in enumerate(raw_rows[1:], start=2):
            if not any(str(c).strip() for c in row if c is not None):
                continue
            raw_adm = str(row[col_adm]).strip() if col_adm < len(row) else ""
            raw_name = str(row[col_name]).strip() if col_name >= 0 and col_name < len(row) else ""
            raw_class = str(row[col_class]).strip() if col_class >= 0 and col_class < len(row) else ""
            raw_sec = str(row[col_sec]).strip() if col_sec >= 0 and col_sec < len(row) else ""
            raw_date = str(row[col_date]).strip() if col_date < len(row) else ""
            raw_sess = str(row[col_sess]).strip().upper() if col_sess >= 0 and col_sess < len(row) else "FULL_DAY"
            raw_status = str(row[col_status]).strip().upper() if col_status < len(row) else ""

            if not raw_sess:
                raw_sess = "FULL_DAY"

            row_errors = []
            parsed_date = None
            student_obj = None

            # Validate Admission Number
            if not raw_adm:
                row_errors.append("Admission Number is missing.")
            else:
                student_obj = students_by_adm.get(raw_adm.lower())
                if not student_obj:
                    row_errors.append(f"Student with admission number '{raw_adm}' not found in this school campus.")
                elif not student_obj.is_active:
                    row_errors.append(f"Student '{raw_adm}' is inactive.")

            # Validate Date
            if not raw_date:
                row_errors.append("Date is missing.")
            else:
                # Try parsing multiple date formats
                for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d/%m/%Y", "%Y/%m/%d"):
                    try:
                        parsed_date = datetime.strptime(raw_date[:10], fmt).date()
                        break
                    except ValueError:
                        continue
                if not parsed_date:
                    row_errors.append(f"Invalid date format '{raw_date}'. Expected YYYY-MM-DD or DD/MM/YYYY.")
                elif parsed_date > today_dt:
                    row_errors.append(f"Date '{raw_date}' is in the future. Future attendance is prohibited.")

            # Validate Status
            if not raw_status:
                row_errors.append("Attendance Status is missing.")
            elif raw_status not in status_enum_values:
                row_errors.append(f"Invalid status '{raw_status}'. Allowed: {', '.join(sorted(status_enum_values))}")

            # Validate Session
            if raw_sess not in ["FULL_DAY", "MORNING", "AFTERNOON", "PERIOD"]:
                row_errors.append(f"Invalid session '{raw_sess}'. Allowed: FULL_DAY, MORNING, AFTERNOON")

            # Check class/section match if supplied
            if student_obj and raw_class:
                target_cls = classes_by_name.get(raw_class.lower())
                if target_cls and student_obj.class_id != target_cls.id:
                    row_errors.append(f"Student does not belong to class '{raw_class}'.")

            # Categorize row
            v_status = "VALID"
            conflict_existing_status = None

            if row_errors:
                v_status = "INVALID"
                invalid_count += 1
                errors.append(f"Row {r_idx}: {'; '.join(row_errors)}")
            elif student_obj and parsed_date:
                file_key = (student_obj.id, parsed_date, raw_sess)
                if file_key in seen_in_file:
                    v_status = "DUPLICATE"
                    duplicate_count += 1
                    row_errors.append("Duplicate entry inside this file for same student, date, and session.")
                else:
                    seen_in_file.add(file_key)
                    # Check DB conflict
                    if file_key in existing_att_map:
                        v_status = "CONFLICT"
                        conflict_count += 1
                        conflict_existing_status = existing_att_map[file_key].attendance_status.value
                    else:
                        valid_count += 1

            # Build preview row
            preview_row = BulkValidateRowPreview(
                row_number=r_idx,
                admission_number=raw_adm,
                student_name=raw_name or (f"{student_obj.first_name} {student_obj.last_name}".strip() if student_obj else ""),
                class_name=raw_class,
                section_name=raw_sec,
                attendance_date=parsed_date.isoformat() if parsed_date else raw_date,
                session=raw_sess,
                status=raw_status,
                validation_status=v_status,
                error_message="; ".join(row_errors) if row_errors else None,
                conflict_existing_status=conflict_existing_status
            )
            preview_rows.append(preview_row)

            # Record in ImportJobRow
            job_row = ImportJobRow(
                import_job_id=job_id,
                row_number=r_idx,
                status=v_status.lower(),
                error_code="VALIDATION_ERROR" if row_errors else None,
                error_message="; ".join(row_errors) if row_errors else None,
                source_identifier=raw_adm,
                entity_id=student_obj.id if student_obj else None,
                row_metadata={
                    "admission_number": raw_adm,
                    "student_name": raw_name,
                    "class_name": raw_class,
                    "section_name": raw_sec,
                    "attendance_date": parsed_date.isoformat() if parsed_date else raw_date,
                    "session": raw_sess,
                    "status": raw_status,
                    "validation_status": v_status,
                    "conflict_existing_status": conflict_existing_status
                }
            )
            self.attendance_repo.db.add(job_row)

        import_job.successful_rows = valid_count
        import_job.failed_rows = invalid_count
        import_job.skipped_rows = duplicate_count
        await self.attendance_repo.db.commit()

        return {
            "job_id": job_id,
            "filename": filename,
            "total_rows": len(raw_rows) - 1,
            "valid_rows": valid_count,
            "invalid_rows": invalid_count,
            "duplicate_rows": duplicate_count,
            "conflict_rows": conflict_count,
            "preview_rows": preview_rows[:50],  # Return first 50 for preview table
            "errors": errors[:50]
        }

    async def import_attendance_chunk(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: BulkAttendanceChunkRequest,
        current_user: User
    ) -> BulkAttendanceChunkResponse:
        role = self.get_user_role_code(current_user)
        if role not in ["SUPER_ADMIN", "TENANT_ADMIN", "PRINCIPAL"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only Principal and Administrator roles can execute bulk attendance imports."
            )
        if obj_in.school_id != school_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="School ID mismatch in chunk payload."
            )
        if current_user.tenant_id != tenant_id and role != "SUPER_ADMIN":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cross-tenant attendance import prohibited."
            )

        # Academic Year Resolution
        academic_year_id = obj_in.academic_year_id
        if not academic_year_id:
            ay_res = await self.academic_year_repo.get_current_year(school_id, tenant_id)
            if not ay_res:
                ay_res = await self.academic_year_repo.get_active_year(school_id, tenant_id)
            if ay_res:
                academic_year_id = ay_res.id

        now_dt = datetime.now(timezone.utc)

        try:
            # 1. Idempotency & Batch Completion State Check
            job_stmt = select(ImportJob).where(
                ImportJob.id == obj_in.import_id,
                ImportJob.tenant_id == tenant_id,
                ImportJob.school_id == school_id,
                ImportJob.deleted_at.is_(None)
            )
            job_res = await self.attendance_repo.db.execute(job_stmt)
            import_job = job_res.scalar_one_or_none()

            if not import_job:
                import_job = ImportJob(
                    id=obj_in.import_id,
                    tenant_id=tenant_id,
                    school_id=school_id,
                    import_type=ImportType.ATTENDANCE,
                    status=ImportJobStatus.RUNNING,
                    source_filename=obj_in.filename or "attendance.csv",
                    total_rows=obj_in.total_rows,
                    processed_rows=0,
                    successful_rows=0,
                    failed_rows=0,
                    skipped_rows=0,
                    started_at=now_dt,
                    created_by=current_user.id,
                    job_metadata={
                        "academic_year_id": str(academic_year_id) if academic_year_id else None,
                        "batches": {},
                        "idempotency_keys": {},
                        "timings": []
                    }
                )
                self.attendance_repo.db.add(import_job)
                await self.attendance_repo.db.flush()
            else:
                if not isinstance(import_job.job_metadata, dict):
                    import_job.job_metadata = {}
                if "batches" not in import_job.job_metadata:
                    import_job.job_metadata["batches"] = {}
                if "idempotency_keys" not in import_job.job_metadata:
                    import_job.job_metadata["idempotency_keys"] = {}
                if "timings" not in import_job.job_metadata:
                    import_job.job_metadata["timings"] = []

            batch_key = str(obj_in.batch_index)
            existing_batches = import_job.job_metadata.get("batches", {})
            if batch_key in existing_batches and existing_batches[batch_key].get("status") == "COMMITTED":
                logger.info(f"[BulkAttendanceImport] Idempotent hit: Batch {obj_in.batch_index} of {obj_in.import_id} was already committed.")
                cached = existing_batches[batch_key]
                t_data = cached.get("timing", {})
                return BulkAttendanceChunkResponse(
                    import_id=obj_in.import_id,
                    batch_index=obj_in.batch_index,
                    total_batches=obj_in.total_batches,
                    total_rows=cached.get("total_rows", len(obj_in.records)),
                    imported_rows=cached.get("imported_rows", 0),
                    skipped_rows=cached.get("skipped_rows", 0),
                    failed_rows=cached.get("failed_rows", 0),
                    status="ALREADY_COMMITTED",
                    timing=BulkAttendanceChunkTiming(**t_data) if t_data else None,
                    errors=[]
                )

            # 2. Session Resolution (Batch SQL Query)
            t0 = time.perf_counter()
            unique_dates = {rec.attendance_date for rec in obj_in.records}
            unique_classes = {rec.class_id for rec in obj_in.records}
            unique_sections = {rec.section_id for rec in obj_in.records}

            sess_stmt = select(AttendanceSession).where(
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.school_id == school_id,
                AttendanceSession.class_id.in_(unique_classes),
                AttendanceSession.section_id.in_(unique_sections),
                AttendanceSession.attendance_date.in_(unique_dates),
                AttendanceSession.deleted_at.is_(None)
            )
            sess_res = await self.attendance_repo.db.execute(sess_stmt)
            existing_sessions = sess_res.scalars().all()

            session_map: Dict[Tuple[uuid.UUID, uuid.UUID, date, str], AttendanceSession] = {}
            for s in existing_sessions:
                st_val = s.session_type.value if hasattr(s.session_type, 'value') else str(s.session_type)
                session_map[(s.class_id, s.section_id, s.attendance_date, st_val)] = s

            # Bulk create missing sessions preserving uploaded session_type (MORNING)
            new_sessions = []
            needed_sessions = {
                (rec.class_id, rec.section_id, rec.attendance_date, rec.session_type)
                for rec in obj_in.records
            }
            for k in needed_sessions:
                if k not in session_map:
                    cls_id, sec_id, att_date, sess_type_str = k
                    st_enum = AttendanceSessionType[sess_type_str] if sess_type_str in AttendanceSessionType.__members__ else AttendanceSessionType.MORNING
                    new_s = AttendanceSession(
                        id=uuid.uuid4(),
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=academic_year_id,
                        class_id=cls_id,
                        section_id=sec_id,
                        attendance_date=att_date,
                        session_type=st_enum,
                        status=AttendanceSessionStatus.SUBMITTED,
                        settings={"session_type": sess_type_str},
                        created_by=current_user.id
                    )
                    new_sessions.append(new_s)
                    session_map[k] = new_s

            if new_sessions:
                self.attendance_repo.db.add_all(new_sessions)
                await self.attendance_repo.db.flush()
            t_session = (time.perf_counter() - t0) * 1000

            # 3. Existing Attendance Lookup (Batch SQL Query)
            t1 = time.perf_counter()
            session_ids = [s.id for s in session_map.values()]
            student_ids = {rec.student_id for rec in obj_in.records}

            att_stmt = select(Attendance).where(
                Attendance.tenant_id == tenant_id,
                Attendance.school_id == school_id,
                Attendance.attendance_session_id.in_(session_ids),
                Attendance.student_id.in_(student_ids),
                Attendance.deleted_at.is_(None)
            )
            att_res = await self.attendance_repo.db.execute(att_stmt)
            existing_attendances = att_res.scalars().all()

            att_map: Dict[Tuple[uuid.UUID, uuid.UUID], Attendance] = {
                (a.attendance_session_id, a.student_id): a for a in existing_attendances
            }
            t_att_lookup = (time.perf_counter() - t1) * 1000

            # 4. Process Rows & Conflict Resolution
            t2 = time.perf_counter()
            imported_count = 0
            skipped_count = 0
            failed_count = 0
            errors: List[str] = []

            new_attendance_records: List[Attendance] = []
            audit_log_records: List[AttendanceAuditLog] = []

            for rec in obj_in.records:
                sess_key = (rec.class_id, rec.section_id, rec.attendance_date, rec.session_type)
                session_obj = session_map.get(sess_key)
                if not session_obj:
                    failed_count += 1
                    errors.append(f"Row {rec.row_number}: Could not resolve session.")
                    continue

                existing_att = att_map.get((session_obj.id, rec.student_id))
                target_status = AttendanceStatus[rec.attendance_status] if rec.attendance_status in AttendanceStatus.__members__ else AttendanceStatus.PRESENT
                target_sess_type = AttendanceSessionType[rec.session_type] if rec.session_type in AttendanceSessionType.__members__ else AttendanceSessionType.MORNING
                target_reason = AttendanceReason[rec.attendance_reason] if rec.attendance_reason and rec.attendance_reason in AttendanceReason.__members__ else AttendanceReason.UNKNOWN

                if existing_att:
                    if obj_in.conflict_strategy == "SKIP_EXISTING":
                        skipped_count += 1
                        continue
                    elif obj_in.conflict_strategy == "REPLACE_EXISTING":
                        old_status_val = existing_att.attendance_status.value if hasattr(existing_att.attendance_status, 'value') else str(existing_att.attendance_status)
                        old_reason_val = existing_att.attendance_reason.value if hasattr(existing_att.attendance_reason, 'value') else str(existing_att.attendance_reason)
                        old_remarks_val = existing_att.remarks

                        existing_att.attendance_status = target_status
                        existing_att.attendance_reason = target_reason
                        existing_att.attendance_source = AttendanceSource.IMPORT
                        existing_att.remarks = rec.remarks or f"Bulk Import Replace ({str(obj_in.import_id)[:8]})"
                        existing_att.updated_by = current_user.id
                        self.attendance_repo.db.add(existing_att)

                        audit = AttendanceAuditLog(
                            id=uuid.uuid4(),
                            tenant_id=tenant_id,
                            school_id=school_id,
                            attendance_id=existing_att.id,
                            student_id=rec.student_id,
                            attendance_date=rec.attendance_date,
                            session_type=rec.session_type,
                            old_status=old_status_val,
                            new_status=target_status.value,
                            action=AttendanceAction.IMPORT.value,
                            changed_by=current_user.id,
                            changed_by_role=role,
                            timestamp=now_dt,
                            source=AttendanceSource.IMPORT.value,
                            reason=f"Bulk Import REPLACE_EXISTING (Batch {obj_in.batch_index})",
                            audit_metadata={
                                "import_id": str(obj_in.import_id),
                                "batch_index": obj_in.batch_index,
                                "old_values": {
                                    "status": old_status_val,
                                    "reason": old_reason_val,
                                    "remarks": old_remarks_val,
                                },
                                "new_values": {
                                    "status": target_status.value,
                                    "reason": target_reason.value,
                                    "remarks": rec.remarks,
                                }
                            }
                        )
                        audit_log_records.append(audit)
                        imported_count += 1
                else:
                    new_att_id = uuid.uuid4()
                    new_att = Attendance(
                        id=new_att_id,
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=academic_year_id,
                        attendance_session_id=session_obj.id,
                        student_id=rec.student_id,
                        timetable_id=None,
                        class_id=rec.class_id,
                        section_id=rec.section_id,
                        teacher_id=None,
                        subject_id=None,
                        attendance_date=rec.attendance_date,
                        session_type=target_sess_type,
                        attendance_status=target_status,
                        attendance_source=AttendanceSource.IMPORT,
                        attendance_reason=target_reason,
                        remarks=rec.remarks or f"Bulk imported ({str(obj_in.import_id)[:8]})",
                        created_by=current_user.id
                    )
                    new_attendance_records.append(new_att)
                    att_map[(session_obj.id, rec.student_id)] = new_att

                    audit = AttendanceAuditLog(
                        id=uuid.uuid4(),
                        tenant_id=tenant_id,
                        school_id=school_id,
                        attendance_id=new_att_id,
                        student_id=rec.student_id,
                        attendance_date=rec.attendance_date,
                        session_type=rec.session_type,
                        old_status=None,
                        new_status=target_status.value,
                        action=AttendanceAction.IMPORT.value,
                        changed_by=current_user.id,
                        changed_by_role=role,
                        timestamp=now_dt,
                        source=AttendanceSource.IMPORT.value,
                        reason=f"Bulk Import Insert (Batch {obj_in.batch_index})",
                        audit_metadata={
                            "import_id": str(obj_in.import_id),
                            "batch_index": obj_in.batch_index,
                            "new_values": {
                                "status": target_status.value,
                                "reason": target_reason.value,
                                "remarks": rec.remarks,
                            }
                        }
                    )
                    audit_log_records.append(audit)
                    imported_count += 1

            t_insert_update = (time.perf_counter() - t2) * 1000

            # 5. Bulk Add & Audit Logging
            t3 = time.perf_counter()
            if new_attendance_records:
                self.attendance_repo.db.add_all(new_attendance_records)
            if audit_log_records:
                self.attendance_repo.db.add_all(audit_log_records)
            t_audit = (time.perf_counter() - t3) * 1000

            # 6. Commit & Update ImportJob
            t4 = time.perf_counter()
            for s in session_map.values():
                s.status = AttendanceSessionStatus.SUBMITTED
                self.attendance_repo.db.add(s)

            b_meta = {
                "status": "COMMITTED",
                "batch_index": obj_in.batch_index,
                "total_rows": len(obj_in.records),
                "imported_rows": imported_count,
                "skipped_rows": skipped_count,
                "failed_rows": failed_count,
                "committed_at": datetime.now(timezone.utc).isoformat(),
                "timing": {
                    "session_resolution_ms": round(t_session, 2),
                    "attendance_lookup_ms": round(t_att_lookup, 2),
                    "insert_update_ms": round(t_insert_update, 2),
                    "audit_ms": round(t_audit, 2),
                    "commit_ms": 0.0,
                    "total_batch_ms": 0.0
                }
            }

            updated_meta = dict(import_job.job_metadata or {})
            batches_dict = dict(updated_meta.get("batches", {}))
            batches_dict[batch_key] = b_meta
            updated_meta["batches"] = batches_dict

            idemp_dict = dict(updated_meta.get("idempotency_keys", {}))
            idemp_dict[obj_in.idempotency_key] = obj_in.batch_index
            updated_meta["idempotency_keys"] = idemp_dict

            import_job.job_metadata = updated_meta
            import_job.processed_rows += len(obj_in.records)
            import_job.successful_rows += imported_count
            import_job.skipped_rows += skipped_count
            import_job.failed_rows += failed_count

            committed_batches_count = len(batches_dict)
            if committed_batches_count >= obj_in.total_batches:
                import_job.status = (
                    ImportJobStatus.COMPLETED
                    if import_job.failed_rows == 0
                    else ImportJobStatus.COMPLETED_WITH_ERRORS
                )
                import_job.completed_at = datetime.now(timezone.utc)
            else:
                import_job.status = ImportJobStatus.PARTIAL

            self.attendance_repo.db.add(import_job)
            await self.attendance_repo.db.commit()
            t_commit = (time.perf_counter() - t4) * 1000

            total_batch_ms = t_session + t_att_lookup + t_insert_update + t_audit + t_commit
            b_meta["timing"]["commit_ms"] = round(t_commit, 2)
            b_meta["timing"]["total_batch_ms"] = round(total_batch_ms, 2)

            timing_obj = BulkAttendanceChunkTiming(
                session_resolution_ms=round(t_session, 2),
                attendance_lookup_ms=round(t_att_lookup, 2),
                insert_update_ms=round(t_insert_update, 2),
                audit_ms=round(t_audit, 2),
                commit_ms=round(t_commit, 2),
                total_batch_ms=round(total_batch_ms, 2)
            )

            logger.info(
                f"[BulkAttendanceImport] Batch {obj_in.batch_index}/{obj_in.total_batches} "
                f"committed ({len(obj_in.records)} rows) in {total_batch_ms:.1f}ms: "
                f"session={t_session:.1f}ms, att_lookup={t_att_lookup:.1f}ms, "
                f"process={t_insert_update:.1f}ms, audit={t_audit:.1f}ms, commit={t_commit:.1f}ms"
            )

            return BulkAttendanceChunkResponse(
                import_id=obj_in.import_id,
                batch_index=obj_in.batch_index,
                total_batches=obj_in.total_batches,
                total_rows=len(obj_in.records),
                imported_rows=imported_count,
                skipped_rows=skipped_count,
                failed_rows=failed_count,
                status="COMMITTED",
                timing=timing_obj,
                errors=errors
            )

        except Exception as e:
            await self.attendance_repo.db.rollback()
            logger.error(f"[BulkAttendanceImport] Batch {obj_in.batch_index} database transaction failed: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Batch {obj_in.batch_index} database transaction failed: {str(e)}"
            )

    async def execute_bulk_attendance_import(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        job_id: uuid.UUID,
        conflict_strategy: str,
        current_user: User
    ) -> Dict[str, Any]:
        role = self.get_user_role_code(current_user)
        if role not in ["SUPER_ADMIN", "TENANT_ADMIN", "PRINCIPAL"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only Principal and Administrator roles can execute bulk attendance imports."
            )

        job_stmt = select(ImportJob).where(
            ImportJob.id == job_id,
            ImportJob.tenant_id == tenant_id,
            ImportJob.school_id == school_id,
            ImportJob.deleted_at.is_(None)
        )
        job_res = await self.attendance_repo.db.execute(job_stmt)
        import_job = job_res.scalar_one_or_none()
        if not import_job:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Import job not found."
            )

        rows_stmt = select(ImportJobRow).where(
            ImportJobRow.import_job_id == job_id
        ).order_by(ImportJobRow.row_number.asc())
        rows_res = await self.attendance_repo.db.execute(rows_stmt)
        job_rows = list(rows_res.scalars().all())

        ay_id_str = import_job.job_metadata.get("academic_year_id")
        academic_year_id = uuid.UUID(ay_id_str) if ay_id_str else None
        if not academic_year_id:
            ay_res = await self.academic_year_repo.get_current_or_latest(school_id, tenant_id)
            if ay_res:
                academic_year_id = ay_res.id

        imported_count = 0
        skipped_count = 0
        failed_count = 0
        conflict_count = 0

        for row in job_rows:
            meta = row.row_metadata or {}
            v_status = meta.get("validation_status", "").upper()

            if v_status == "INVALID" or v_status == "DUPLICATE":
                failed_count += 1
                continue

            if v_status == "CONFLICT":
                conflict_count += 1
                if conflict_strategy == "SKIP_EXISTING":
                    skipped_count += 1
                    row.status = "skipped"
                    self.attendance_repo.db.add(row)
                    continue

            # Process VALID or REPLACE_EXISTING conflict row
            try:
                student_id = row.entity_id
                if not student_id:
                    failed_count += 1
                    continue

                att_date = datetime.strptime(meta["attendance_date"], "%Y-%m-%d").date()
                sess_type = AttendanceSessionType(meta.get("session", "FULL_DAY"))
                att_status = AttendanceStatus(meta["status"])

                st_obj = await self.student_repo.get_by_id(student_id, school_id, tenant_id)
                if not st_obj:
                    failed_count += 1
                    continue

                # Ensure session exists
                session_obj = await self.attendance_repo.get_or_create_daily_session(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=academic_year_id or st_obj.academic_year_id,
                    class_id=st_obj.class_id,
                    section_id=st_obj.section_id,
                    attendance_date=att_date,
                    session_type=sess_type,
                    created_by=current_user.id
                )

                # Check if existing log
                existing_log_res = await self.attendance_repo.db.execute(
                    select(Attendance).where(
                        Attendance.student_id == student_id,
                        Attendance.attendance_date == att_date,
                        Attendance.session_type == sess_type,
                        Attendance.tenant_id == tenant_id,
                        Attendance.deleted_at.is_(None)
                    )
                )
                existing_log = existing_log_res.scalar_one_or_none()

                if existing_log:
                    old_s = existing_log.attendance_status
                    existing_log.attendance_status = att_status
                    existing_log.attendance_source = AttendanceSource.IMPORT
                    existing_log.updated_by = current_user.id
                    self.attendance_repo.db.add(existing_log)

                    await self.attendance_repo.create_audit_log(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        student_id=student_id,
                        attendance_date=att_date,
                        session_type=sess_type.value,
                        old_status=old_s.value,
                        new_status=att_status.value,
                        action=AttendanceAction.IMPORT.value,
                        changed_by=current_user.id,
                        changed_by_role=role,
                        source=AttendanceSource.IMPORT.value,
                        attendance_id=existing_log.id,
                        reason=f"Bulk Excel Import (Batch {job_id})"
                    )
                else:
                    rec = StudentAttendanceRecord(
                        student_id=student_id,
                        attendance_status=att_status,
                        attendance_source=AttendanceSource.IMPORT,
                        attendance_reason=AttendanceReason.UNKNOWN,
                        remarks=f"Imported via batch {str(job_id)[:8]}"
                    )
                    new_log = await self.attendance_repo.create_attendance(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=academic_year_id or st_obj.academic_year_id,
                        session_id=session_obj.id,
                        student_id=student_id,
                        timetable_id=None,
                        class_id=st_obj.class_id,
                        section_id=st_obj.section_id,
                        teacher_id=None,
                        subject_id=None,
                        attendance_date=att_date,
                        record=rec,
                        session_type=sess_type,
                        created_by=current_user.id
                    )
                    await self.attendance_repo.create_audit_log(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        student_id=student_id,
                        attendance_date=att_date,
                        session_type=sess_type.value,
                        old_status=None,
                        new_status=att_status.value,
                        action=AttendanceAction.IMPORT.value,
                        changed_by=current_user.id,
                        changed_by_role=role,
                        source=AttendanceSource.IMPORT.value,
                        attendance_id=new_log.id,
                        reason=f"Bulk Excel Import (Batch {job_id})"
                    )

                session_obj.status = AttendanceSessionStatus.SUBMITTED
                self.attendance_repo.db.add(session_obj)

                row.status = "success"
                self.attendance_repo.db.add(row)
                imported_count += 1

            except Exception as row_err:
                logger.error(f"Error importing row {row.row_number}: {str(row_err)}", exc_info=True)
                row.status = "failed"
                row.error_message = str(row_err)
                self.attendance_repo.db.add(row)
                failed_count += 1

        import_job.successful_rows = imported_count
        import_job.skipped_rows = skipped_count
        import_job.failed_rows = failed_count
        import_job.status = ImportJobStatus.COMPLETED if failed_count == 0 else ImportJobStatus.COMPLETED_WITH_ERRORS
        import_job.completed_at = datetime.now(timezone.utc)
        self.attendance_repo.db.add(import_job)

        await self.attendance_repo.db.commit()

        return {
            "job_id": job_id,
            "status": import_job.status.value,
            "total_rows": len(job_rows),
            "imported_rows": imported_count,
            "skipped_rows": skipped_count,
            "failed_rows": failed_count,
            "conflict_rows": conflict_count,
            "message": f"Bulk attendance import finished. {imported_count} imported, {skipped_count} skipped, {failed_count} failed."
        }

    # ==================================================
    # Template & Error Report Generation
    # ==================================================

    def generate_csv_template(self) -> str:
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "Admission Number",
            "Student Name",
            "Class",
            "Section",
            "Date",
            "Session",
            "Status"
        ])
        writer.writerow(["ADM-2026-001", "Aarav Sharma", "Grade 8", "A", date.today().isoformat(), "FULL_DAY", "PRESENT"])
        writer.writerow(["ADM-2026-002", "Diya Patel", "Grade 8", "A", date.today().isoformat(), "FULL_DAY", "ABSENT"])
        writer.writerow(["ADM-2026-003", "Rohan Verma", "Grade 8", "A", date.today().isoformat(), "FULL_DAY", "LATE"])
        writer.writerow(["ADM-2026-004", "Ananya Reddy", "Grade 8", "A", date.today().isoformat(), "FULL_DAY", "EXCUSED"])
        writer.writerow(["ADM-2026-005", "Vivaan Gupta", "Grade 8", "A", date.today().isoformat(), "FULL_DAY", "HALF_DAY"])
        return output.getvalue()

    async def get_import_job_errors_csv(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, job_id: uuid.UUID
    ) -> str:
        job_stmt = select(ImportJob).where(
            ImportJob.id == job_id,
            ImportJob.tenant_id == tenant_id,
            ImportJob.school_id == school_id,
            ImportJob.deleted_at.is_(None)
        )
        job_res = await self.attendance_repo.db.execute(job_stmt)
        if not job_res.scalar_one_or_none():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Import job not found.")

        rows_stmt = select(ImportJobRow).where(
            ImportJobRow.import_job_id == job_id,
            ImportJobRow.status.in_(["failed", "invalid", "duplicate"])
        ).order_by(ImportJobRow.row_number.asc())
        rows_res = await self.attendance_repo.db.execute(rows_stmt)
        rows = list(rows_res.scalars().all())

        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Row Number", "Admission Number", "Status", "Error Code", "Error Details"])
        for r in rows:
            writer.writerow([r.row_number, r.source_identifier or "", r.status, r.error_code or "", r.error_message or ""])
        return output.getvalue()


