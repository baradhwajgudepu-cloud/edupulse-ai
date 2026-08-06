import uuid
import logging
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.attendance import AttendanceSession, Attendance, AttendanceSessionStatus, AttendanceStatus, AttendanceSource, AttendanceReason
from app.models.student import Student
from app.models.timetable import Timetable
from app.models.user import User
from app.repositories.attendance import AttendanceRepository
from app.repositories.student import StudentRepository
from app.repositories.timetable import TimetableRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.attendance import AttendanceSessionCreate, AttendanceSessionUpdate, BulkAttendanceMark, StudentAttendanceRecord, AttendanceCorrectionUpdate
from app.services.notification import NotificationService

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
        await self.attendance_repo.db.commit()
        await self.attendance_repo.db.refresh(log_obj)
        return log_obj

