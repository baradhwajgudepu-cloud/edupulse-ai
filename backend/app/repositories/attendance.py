import uuid
from typing import List, Optional, Tuple, Dict, Any
from datetime import date, datetime, timezone, timedelta
from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.orm import joinedload
from sqlalchemy.ext.asyncio import AsyncSession

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
from app.models.subject import Subject
from app.models.user import User
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
                joinedload(AttendanceSession.attendances).joinedload(Attendance.student),
                joinedload(AttendanceSession.class_obj),
                joinedload(AttendanceSession.section)
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

    async def get_daily_session_by_class_section_date(
        self,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        attendance_date: date,
        session_type: AttendanceSessionType,
        tenant_id: uuid.UUID
    ) -> Optional[AttendanceSession]:
        stmt = (
            select(AttendanceSession)
            .where(
                AttendanceSession.school_id == school_id,
                AttendanceSession.class_id == class_id,
                AttendanceSession.section_id == section_id,
                AttendanceSession.attendance_date == attendance_date,
                AttendanceSession.session_type == session_type,
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.deleted_at.is_(None)
            )
            .options(
                joinedload(AttendanceSession.attendances).joinedload(Attendance.student),
                joinedload(AttendanceSession.class_obj),
                joinedload(AttendanceSession.section)
            )
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one_or_none()

    async def get_or_create_daily_session(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        attendance_date: date,
        session_type: AttendanceSessionType = AttendanceSessionType.FULL_DAY,
        created_by: Optional[uuid.UUID] = None
    ) -> AttendanceSession:
        existing = await self.get_daily_session_by_class_section_date(
            school_id=school_id,
            class_id=class_id,
            section_id=section_id,
            attendance_date=attendance_date,
            session_type=session_type,
            tenant_id=tenant_id
        )
        if existing:
            return existing

        db_obj = AttendanceSession(
            attendance_date=attendance_date,
            session_type=session_type,
            status=AttendanceSessionStatus.DRAFT,
            settings={},
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            timetable_id=None,
            class_id=class_id,
            section_id=section_id,
            teacher_id=None,
            subject_id=None,
            created_by=created_by
        )
        self.db.add(db_obj)
        await self.db.flush()
        return await self.get_daily_session_by_class_section_date(
            school_id=school_id,
            class_id=class_id,
            section_id=section_id,
            attendance_date=attendance_date,
            session_type=session_type,
            tenant_id=tenant_id
        )

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
            session_type=getattr(obj_in, "session_type", AttendanceSessionType.FULL_DAY),
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
        stmt = (
            select(Attendance)
            .where(
                Attendance.school_id == school_id,
                Attendance.attendance_date == attendance_date,
                Attendance.tenant_id == tenant_id,
                Attendance.deleted_at.is_(None)
            )
            .options(
                joinedload(Attendance.student),
                joinedload(Attendance.class_obj),
                joinedload(Attendance.section)
            )
            .order_by(Attendance.created_at.desc())
        )
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
        timetable_id: Optional[uuid.UUID],
        class_id: uuid.UUID,
        section_id: uuid.UUID,
        teacher_id: Optional[uuid.UUID],
        subject_id: Optional[uuid.UUID],
        attendance_date: date,
        record: StudentAttendanceRecord,
        session_type: AttendanceSessionType = AttendanceSessionType.FULL_DAY,
        created_by: Optional[uuid.UUID] = None
    ) -> Attendance:
        db_obj = Attendance(
            attendance_date=attendance_date,
            session_type=session_type,
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

    # ==================================================
    # Audit Trail Operations
    # ==================================================

    async def create_audit_log(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: uuid.UUID,
        attendance_date: date,
        session_type: str,
        old_status: Optional[str],
        new_status: str,
        action: str,
        changed_by: Optional[uuid.UUID],
        changed_by_role: Optional[str] = None,
        source: str = "MANUAL",
        attendance_id: Optional[uuid.UUID] = None,
        reason: Optional[str] = None,
        audit_metadata: Optional[dict] = None
    ) -> AttendanceAuditLog:
        log_entry = AttendanceAuditLog(
            tenant_id=tenant_id,
            school_id=school_id,
            attendance_id=attendance_id,
            student_id=student_id,
            attendance_date=attendance_date,
            session_type=session_type,
            old_status=old_status,
            new_status=new_status,
            action=action,
            changed_by=changed_by,
            changed_by_role=changed_by_role,
            timestamp=datetime.now(timezone.utc),
            source=source,
            reason=reason,
            audit_metadata=audit_metadata or {}
        )
        self.db.add(log_entry)
        return log_entry

    async def get_audit_logs_paginated(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        student_id: Optional[uuid.UUID] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        action: Optional[str] = None,
        source: Optional[str] = None,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[List[AttendanceAuditLog], int]:
        filters = [
            AttendanceAuditLog.school_id == school_id,
            AttendanceAuditLog.tenant_id == tenant_id,
            AttendanceAuditLog.deleted_at.is_(None)
        ]
        if student_id:
            filters.append(AttendanceAuditLog.student_id == student_id)
        if date_from:
            filters.append(AttendanceAuditLog.attendance_date >= date_from)
        if date_to:
            filters.append(AttendanceAuditLog.attendance_date <= date_to)
        if action:
            filters.append(AttendanceAuditLog.action == action)
        if source:
            filters.append(AttendanceAuditLog.source == source)

        base_query = select(AttendanceAuditLog).where(and_(*filters))
        count_stmt = select(func.count()).select_from(base_query.subquery())
        total = (await self.db.execute(count_stmt)).scalar() or 0

        stmt = (
            base_query.options(
                joinedload(AttendanceAuditLog.student),
                joinedload(AttendanceAuditLog.changed_by_user)
            )
            .order_by(AttendanceAuditLog.timestamp.desc())
            .offset(skip)
            .limit(limit)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all()), total

    # ==================================================
    # Register & Paginated Operations
    # ==================================================

    async def get_register_attendances_paginated(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        student_id: Optional[uuid.UUID] = None,
        attendance_date: Optional[date] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        status: Optional[AttendanceStatus] = None,
        session_type: Optional[AttendanceSessionType] = None,
        search: Optional[str] = None,
        allowed_class_ids: Optional[List[uuid.UUID]] = None,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[List[Attendance], int]:
        filters = [
            Attendance.school_id == school_id,
            Attendance.tenant_id == tenant_id,
            Attendance.deleted_at.is_(None)
        ]
        if academic_year_id:
            filters.append(Attendance.academic_year_id == academic_year_id)
        if class_id:
            filters.append(Attendance.class_id == class_id)
        elif allowed_class_ids is not None:
            filters.append(Attendance.class_id.in_(allowed_class_ids))
        if section_id:
            filters.append(Attendance.section_id == section_id)
        if student_id:
            filters.append(Attendance.student_id == student_id)
        if attendance_date:
            filters.append(Attendance.attendance_date == attendance_date)
        if date_from:
            filters.append(Attendance.attendance_date >= date_from)
        if date_to:
            filters.append(Attendance.attendance_date <= date_to)
        if status:
            filters.append(Attendance.attendance_status == status)
        if session_type:
            filters.append(Attendance.session_type == session_type)

        query = select(Attendance).where(and_(*filters))

        if search and search.strip():
            term = search.strip()
            query = query.join(Student, Attendance.student_id == Student.id).where(
                or_(
                    Student.first_name.ilike(f"%{term}%"),
                    Student.last_name.ilike(f"%{term}%"),
                    Student.admission_number.ilike(f"%{term}%"),
                    func.concat(Student.first_name, ' ', Student.last_name).ilike(f"%{term}%")
                )
            )

        count_stmt = select(func.count()).select_from(query.order_by(None).subquery())
        total = (await self.db.execute(count_stmt)).scalar() or 0

        paged_stmt = (
            query.options(
                joinedload(Attendance.student),
                joinedload(Attendance.class_obj),
                joinedload(Attendance.section),
                joinedload(Attendance.attendance_session)
            )
            .order_by(Attendance.attendance_date.desc(), Attendance.created_at.desc())
            .offset(skip)
            .limit(limit)
        )
        res = await self.db.execute(paged_stmt)
        return list(res.unique().scalars().all()), total

    # ==================================================
    # Dashboard Stats & Alert Evaluation
    # ==================================================

    async def get_dashboard_stats(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        target_date: date,
        academic_year_id: Optional[uuid.UUID] = None,
        allowed_class_ids: Optional[List[uuid.UUID]] = None
    ) -> Dict[str, Any]:
        # Filter for active students
        student_filters = [
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.is_active == True,
            Student.deleted_at.is_(None)
        ]
        if allowed_class_ids is not None:
            student_filters.append(Student.class_id.in_(allowed_class_ids))

        total_students_res = await self.db.execute(
            select(func.count(Student.id)).where(and_(*student_filters))
        )
        total_students = total_students_res.scalar() or 0

        # Attendance counts on target_date
        att_filters = [
            Attendance.school_id == school_id,
            Attendance.tenant_id == tenant_id,
            Attendance.attendance_date == target_date,
            Attendance.deleted_at.is_(None)
        ]
        if allowed_class_ids is not None:
            att_filters.append(Attendance.class_id.in_(allowed_class_ids))

        counts_res = await self.db.execute(
            select(
                Attendance.attendance_status,
                func.count(Attendance.id)
            ).where(and_(*att_filters)).group_by(Attendance.attendance_status)
        )
        status_map = {row[0]: row[1] for row in counts_res.all()}
        present_cnt = status_map.get(AttendanceStatus.PRESENT, 0)
        absent_cnt = status_map.get(AttendanceStatus.ABSENT, 0)
        late_cnt = status_map.get(AttendanceStatus.LATE, 0)
        excused_cnt = status_map.get(AttendanceStatus.EXCUSED, 0)
        half_day_cnt = status_map.get(AttendanceStatus.HALF_DAY, 0)

        effective_present = present_cnt + late_cnt + (half_day_cnt * 0.5)
        marked_total = present_cnt + absent_cnt + late_cnt + excused_cnt + half_day_cnt
        rate = round((effective_present / marked_total * 100.0), 1) if marked_total > 0 else 0.0

        # Class marking status for target_date
        class_filters = [
            Class.school_id == school_id,
            Class.tenant_id == tenant_id,
            Class.is_active == True,
            Class.deleted_at.is_(None)
        ]
        if allowed_class_ids is not None:
            class_filters.append(Class.id.in_(allowed_class_ids))
        classes_res = await self.db.execute(select(Class).where(and_(*class_filters)))
        classes = list(classes_res.scalars().all())

        marked_sessions_res = await self.db.execute(
            select(AttendanceSession.class_id).where(
                AttendanceSession.school_id == school_id,
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.attendance_date == target_date,
                AttendanceSession.status.in_([AttendanceSessionStatus.SUBMITTED, AttendanceSessionStatus.LOCKED]),
                AttendanceSession.deleted_at.is_(None)
            ).distinct()
        )
        marked_class_ids = set(marked_sessions_res.scalars().all())
        classes_marked = sum(1 for c in classes if c.id in marked_class_ids)
        classes_pending = max(0, len(classes) - classes_marked)

        # 7-day daily trend
        daily_trend = []
        for d_offset in range(6, -1, -1):
            past_d = target_date - timedelta(days=d_offset)
            d_filters = [
                Attendance.school_id == school_id,
                Attendance.tenant_id == tenant_id,
                Attendance.attendance_date == past_d,
                Attendance.deleted_at.is_(None)
            ]
            if allowed_class_ids is not None:
                d_filters.append(Attendance.class_id.in_(allowed_class_ids))
            past_res = await self.db.execute(
                select(
                    func.count(Attendance.id),
                    func.count().filter(Attendance.attendance_status.in_([AttendanceStatus.PRESENT, AttendanceStatus.LATE])),
                    func.count().filter(Attendance.attendance_status == AttendanceStatus.ABSENT)
                ).where(and_(*d_filters))
            )
            d_total, d_pres, d_abs = past_res.one()
            d_rate = round((d_pres / d_total * 100.0), 1) if d_total and d_total > 0 else 0.0
            daily_trend.append({
                "date": past_d.isoformat(),
                "percentage": d_rate,
                "present": d_pres or 0,
                "absent": d_abs or 0,
                "total": d_total or 0
            })

        # Class-wise breakdown
        class_wise_stats = []
        for cls in classes:
            c_att_filters = [
                Attendance.school_id == school_id,
                Attendance.tenant_id == tenant_id,
                Attendance.class_id == cls.id,
                Attendance.attendance_date == target_date,
                Attendance.deleted_at.is_(None)
            ]
            c_res = await self.db.execute(
                select(
                    func.count(Attendance.id),
                    func.count().filter(Attendance.attendance_status.in_([AttendanceStatus.PRESENT, AttendanceStatus.LATE]))
                ).where(and_(*c_att_filters))
            )
            c_tot, c_prs = c_res.one()
            c_rate = round((c_prs / c_tot * 100.0), 1) if c_tot and c_tot > 0 else 0.0
            class_wise_stats.append({
                "class_id": str(cls.id),
                "class_name": cls.name,
                "percentage": c_rate,
                "is_marked": cls.id in marked_class_ids,
                "total_marked": c_tot or 0,
                "present": c_prs or 0
            })

        # Low attendance students (<75% in the last 30 days)
        start_30 = target_date - timedelta(days=30)
        low_att_filters = [
            Attendance.school_id == school_id,
            Attendance.tenant_id == tenant_id,
            Attendance.attendance_date >= start_30,
            Attendance.attendance_date <= target_date,
            Attendance.deleted_at.is_(None)
        ]
        if allowed_class_ids is not None:
            low_att_filters.append(Attendance.class_id.in_(allowed_class_ids))

        low_res = await self.db.execute(
            select(
                Attendance.student_id,
                func.count(Attendance.id).label("total_days"),
                func.count().filter(Attendance.attendance_status.in_([AttendanceStatus.PRESENT, AttendanceStatus.LATE])).label("present_days"),
                func.count().filter(Attendance.attendance_status == AttendanceStatus.ABSENT).label("absent_days")
            )
            .where(and_(*low_att_filters))
            .group_by(Attendance.student_id)
            .having(func.count(Attendance.id) >= 5)
        )
        low_attendance_students = []
        student_stats = low_res.all()
        student_ids_to_fetch = [row[0] for row in student_stats if (row[2] / row[1]) < 0.75]
        
        if student_ids_to_fetch:
            st_res = await self.db.execute(
                select(Student).where(Student.id.in_(student_ids_to_fetch[:20]))
            )
            st_map = {s.id: s for s in st_res.scalars().all()}
            for row in student_stats:
                s_id, tot, prs, abs_cnt = row[0], row[1], row[2], row[3]
                s_rate = round((prs / tot * 100.0), 1) if tot > 0 else 0.0
                if s_rate < 75.0 and s_id in st_map:
                    st = st_map[s_id]
                    low_attendance_students.append({
                        "student_id": str(st.id),
                        "student_name": f"{st.first_name} {st.last_name}".strip(),
                        "admission_number": st.admission_number,
                        "percentage": s_rate,
                        "absence_count": abs_cnt
                    })

        return {
            "attendance_date": target_date,
            "attendance_percentage": rate,
            "total_students": total_students,
            "present_count": present_cnt,
            "absent_count": absent_cnt,
            "late_count": late_cnt,
            "excused_count": excused_cnt,
            "half_day_count": half_day_cnt,
            "classes_marked": classes_marked,
            "classes_pending": classes_pending,
            "daily_trend": daily_trend,
            "class_wise_stats": class_wise_stats,
            "monthly_percentage": rate,
            "low_attendance_students": low_attendance_students
        }

    async def evaluate_alerts(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        target_date: date,
        allowed_class_ids: Optional[List[uuid.UUID]] = None
    ) -> List[Dict[str, Any]]:
        alerts = []

        # 1. Unmarked classes for today
        class_filters = [
            Class.school_id == school_id,
            Class.tenant_id == tenant_id,
            Class.is_active == True,
            Class.deleted_at.is_(None)
        ]
        if allowed_class_ids is not None:
            class_filters.append(Class.id.in_(allowed_class_ids))
        classes_res = await self.db.execute(select(Class).where(and_(*class_filters)))
        classes = list(classes_res.scalars().all())

        marked_res = await self.db.execute(
            select(AttendanceSession.class_id).where(
                AttendanceSession.school_id == school_id,
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.attendance_date == target_date,
                AttendanceSession.status.in_([AttendanceSessionStatus.SUBMITTED, AttendanceSessionStatus.LOCKED]),
                AttendanceSession.deleted_at.is_(None)
            ).distinct()
        )
        marked_class_ids = set(marked_res.scalars().all())
        unmarked = [c for c in classes if c.id not in marked_class_ids]
        if unmarked:
            alerts.append({
                "alert_type": "UNMARKED_CLASS",
                "severity": "HIGH",
                "title": f"{len(unmarked)} Class(es) Attendance Pending",
                "message": f"Attendance has not been submitted today for: {', '.join(c.name for c in unmarked[:5])}",
                "entity_id": str(unmarked[0].id) if unmarked else None,
                "details": {"unmarked_classes": [c.name for c in unmarked]}
            })

        # 2. Students absent 3 consecutive days
        three_days_ago = target_date - timedelta(days=3)
        streak_filters = [
            Attendance.school_id == school_id,
            Attendance.tenant_id == tenant_id,
            Attendance.attendance_date >= three_days_ago,
            Attendance.attendance_date <= target_date,
            Attendance.attendance_status == AttendanceStatus.ABSENT,
            Attendance.deleted_at.is_(None)
        ]
        if allowed_class_ids is not None:
            streak_filters.append(Attendance.class_id.in_(allowed_class_ids))

        streak_res = await self.db.execute(
            select(Attendance.student_id, func.count(Attendance.id))
            .where(and_(*streak_filters))
            .group_by(Attendance.student_id)
            .having(func.count(Attendance.id) >= 3)
        )
        streak_students = streak_res.all()
        if streak_students:
            s_ids = [row[0] for row in streak_students]
            st_res = await self.db.execute(select(Student).where(Student.id.in_(s_ids[:10])))
            st_list = list(st_res.scalars().all())
            names = [f"{s.first_name} {s.last_name}".strip() for s in st_list]
            alerts.append({
                "alert_type": "ABSENCE_STREAK",
                "severity": "HIGH",
                "title": f"{len(streak_students)} Student(s) Absent 3+ Consecutive Days",
                "message": f"Critical absence alert for: {', '.join(names[:4])}",
                "entity_id": str(streak_students[0][0]),
                "details": {"student_ids": [str(sid) for sid in s_ids]}
            })

        return alerts
