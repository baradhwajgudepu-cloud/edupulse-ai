import uuid
from typing import List, Optional
from datetime import date, datetime, timezone
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attendance import AttendanceSession, Attendance, AttendanceSessionStatus, AttendanceStatus
from app.models.student import Student
from app.models.timetable import Timetable
from app.models.class_entity import Class
from app.models.section import Section
from app.models.teacher import Teacher
from app.models.subject import Subject
from app.schemas.attendance import AttendanceSessionCreate, AttendanceSessionUpdate, StudentAttendanceRecord

class AttendanceRepository:
    """
    Repository layer for AttendanceSession and Attendance database operations.
    Enforces multi-tenancy and soft delete scoping.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # ==================================================
    # Attendance Session Operations
    # ==================================================

    async def get_session_by_id(
        self, session_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[AttendanceSession]:
        stmt = (
            select(AttendanceSession)
            .where(
                AttendanceSession.id == session_id,
                AttendanceSession.school_id == school_id,
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.deleted_at.is_(None)
            )
            .options(
                joinedload(AttendanceSession.attendances).joinedload(Attendance.student)
            )
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def get_session_by_slot(
        self, timetable_id: uuid.UUID, attendance_date: date, tenant_id: uuid.UUID
    ) -> Optional[AttendanceSession]:
        stmt = (
            select(AttendanceSession)
            .where(
                AttendanceSession.timetable_id == timetable_id,
                AttendanceSession.attendance_date == attendance_date,
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.deleted_at.is_(None)
            )
            .options(
                joinedload(AttendanceSession.attendances).joinedload(Attendance.student)
            )
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def get_multi_sessions(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        attendance_date: Optional[date] = None,
        status: Optional[AttendanceSessionStatus] = None,
        teacher_id: Optional[uuid.UUID] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[AttendanceSession]:
        filters = [
            AttendanceSession.school_id == school_id,
            AttendanceSession.tenant_id == tenant_id,
            AttendanceSession.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(AttendanceSession.academic_year_id == academic_year_id)
        if class_id:
            filters.append(AttendanceSession.class_id == class_id)
        if section_id:
            filters.append(AttendanceSession.section_id == section_id)
        if attendance_date:
            filters.append(AttendanceSession.attendance_date == attendance_date)
        if status:
            filters.append(AttendanceSession.status == status)
        if teacher_id:
            filters.append(AttendanceSession.teacher_id == teacher_id)

        stmt = (
            select(AttendanceSession)
            .where(and_(*filters))
            .options(
                joinedload(AttendanceSession.timetable),
                joinedload(AttendanceSession.class_obj),
                joinedload(AttendanceSession.section),
                joinedload(AttendanceSession.attendances).joinedload(Attendance.student)
            )
            .order_by(AttendanceSession.attendance_date.desc(), AttendanceSession.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.unique().scalars().all())

    async def create_session(
        self,
        tenant_id: uuid.UUID,
        obj_in: AttendanceSessionCreate,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        teacher_id: Optional[uuid.UUID],
        subject_id: Optional[uuid.UUID],
        created_by: Optional[uuid.UUID] = None
    ) -> AttendanceSession:
        db_obj = AttendanceSession(
            attendance_date=obj_in.attendance_date,
            status=AttendanceSessionStatus.DRAFT,
            settings=obj_in.settings,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            timetable_id=obj_in.timetable_id,
            class_id=class_id,
            section_id=section_id,
            teacher_id=teacher_id,
            subject_id=subject_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update_session(
        self,
        db_obj: AttendanceSession,
        update_data: dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> AttendanceSession:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete_session(
        self,
        db_obj: AttendanceSession,
        deleted_by: Optional[uuid.UUID] = None
    ) -> AttendanceSession:
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        
        # Soft delete child attendances as well
        stmt = select(Attendance).where(
            Attendance.attendance_session_id == db_obj.id,
            Attendance.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        child_records = res.scalars().all()
        for record in child_records:
            record.deleted_at = now
            record.is_active = False
            record.updated_by = deleted_by
            self.db.add(record)

        self.db.add(db_obj)
        return db_obj

    # ==================================================
    # Individual Attendance Operations
    # ==================================================

    async def get_attendance_by_id(
        self, attendance_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Attendance]:
        stmt = select(Attendance).where(
            Attendance.id == attendance_id,
            Attendance.school_id == school_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_attendance_by_session_student(
        self, session_id: uuid.UUID, student_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Attendance]:
        stmt = select(Attendance).where(
            Attendance.attendance_session_id == session_id,
            Attendance.student_id == student_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_duplicate_attendance(
        self,
        student_id: uuid.UUID,
        timetable_id: uuid.UUID,
        attendance_date: date,
        tenant_id: uuid.UUID
    ) -> Optional[Attendance]:
        stmt = select(Attendance).where(
            Attendance.student_id == student_id,
            Attendance.timetable_id == timetable_id,
            Attendance.attendance_date == attendance_date,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_student_attendance(
        self, student_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Attendance]:
        stmt = select(Attendance).where(
            Attendance.student_id == student_id,
            Attendance.academic_year_id == academic_year_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ).order_by(Attendance.attendance_date.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_class_attendance(
        self, class_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Attendance]:
        stmt = select(Attendance).where(
            Attendance.class_id == class_id,
            Attendance.academic_year_id == academic_year_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ).order_by(Attendance.attendance_date.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_section_attendance(
        self, class_id: uuid.UUID, section_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Attendance]:
        stmt = select(Attendance).where(
            Attendance.class_id == class_id,
            Attendance.section_id == section_id,
            Attendance.academic_year_id == academic_year_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ).order_by(Attendance.attendance_date.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_teacher_attendance(
        self, teacher_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Attendance]:
        stmt = select(Attendance).where(
            Attendance.teacher_id == teacher_id,
            Attendance.academic_year_id == academic_year_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ).order_by(Attendance.attendance_date.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_subject_attendance(
        self, subject_id: uuid.UUID, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[Attendance]:
        stmt = select(Attendance).where(
            Attendance.subject_id == subject_id,
            Attendance.academic_year_id == academic_year_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ).order_by(Attendance.attendance_date.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_daily_attendance(
        self, school_id: uuid.UUID, attendance_date: date, tenant_id: uuid.UUID
    ) -> List[Attendance]:
        stmt = select(Attendance).where(
            Attendance.school_id == school_id,
            Attendance.attendance_date == attendance_date,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ).order_by(Attendance.created_at.desc())
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_multi_attendances(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        student_id: Optional[uuid.UUID] = None,
        timetable_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        attendance_date: Optional[date] = None,
        status: Optional[AttendanceStatus] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Attendance]:
        filters = [
            Attendance.school_id == school_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(Attendance.academic_year_id == academic_year_id)
        if student_id:
            filters.append(Attendance.student_id == student_id)
        if timetable_id:
            filters.append(Attendance.timetable_id == timetable_id)
        if class_id:
            filters.append(Attendance.class_id == class_id)
        if section_id:
            filters.append(Attendance.section_id == section_id)
        if attendance_date:
            filters.append(Attendance.attendance_date == attendance_date)
        if status:
            filters.append(Attendance.attendance_status == status)

        stmt = (
            select(Attendance)
            .where(and_(*filters))
            .options(
                joinedload(Attendance.student),
                joinedload(Attendance.class_obj),
                joinedload(Attendance.section)
            )
            .order_by(Attendance.attendance_date.desc(), Attendance.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create_attendance(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        session_id: uuid.UUID,
        student_id: uuid.UUID,
        timetable_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        teacher_id: Optional[uuid.UUID],
        subject_id: Optional[uuid.UUID],
        attendance_date: date,
        record: StudentAttendanceRecord,
        created_by: Optional[uuid.UUID] = None
    ) -> Attendance:
        db_obj = Attendance(
            attendance_date=attendance_date,
            attendance_status=record.attendance_status,
            attendance_source=record.attendance_source,
            attendance_reason=record.attendance_reason,
            remarks=record.remarks,
            parent_viewed=False,
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            attendance_session_id=session_id,
            student_id=student_id,
            timetable_id=timetable_id,
            class_id=class_id,
            section_id=section_id,
            teacher_id=teacher_id,
            subject_id=subject_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update_attendance(
        self,
        db_obj: Attendance,
        update_data: dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Attendance:
        for field, value in update_data.items():
            setattr(db_obj, field, value)
        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete_attendance(
        self,
        db_obj: Attendance,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Attendance:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
