import uuid
from datetime import date
from typing import List, Optional
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.teacher_leave import TeacherLeave, LeaveStatus, LeaveType

class TeacherLeaveRepository:
    """
    Repository for TeacherLeave database operations.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(self, leave_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[TeacherLeave]:
        """
        Fetches a teacher leave record by its ID, enforcing tenant isolation.
        """
        stmt = select(TeacherLeave).where(
            and_(
                TeacherLeave.id == leave_id,
                TeacherLeave.tenant_id == tenant_id,
                TeacherLeave.deleted_at.is_(None)
            )
        ).options(
            selectinload(TeacherLeave.teacher),
            selectinload(TeacherLeave.school)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one_or_none()

    async def get_by_teacher(self, teacher_id: uuid.UUID, tenant_id: uuid.UUID) -> List[TeacherLeave]:
        """
        Fetches all leave records for a specific teacher, ordered by requested_at descending.
        """
        stmt = select(TeacherLeave).where(
            and_(
                TeacherLeave.teacher_id == teacher_id,
                TeacherLeave.tenant_id == tenant_id,
                TeacherLeave.deleted_at.is_(None)
            )
        ).order_by(
            TeacherLeave.requested_at.desc()
        ).options(
            selectinload(TeacherLeave.teacher)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def list_leaves(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status: Optional[LeaveStatus] = None,
        leave_type: Optional[LeaveType] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[TeacherLeave]:
        """
        Lists leaves with options for Principal/Admin filtering, enforcing tenant boundary.
        """
        conditions = [
            TeacherLeave.school_id == school_id,
            TeacherLeave.tenant_id == tenant_id,
            TeacherLeave.deleted_at.is_(None)
        ]
        if status:
            conditions.append(TeacherLeave.status == status)
        if leave_type:
            conditions.append(TeacherLeave.leave_type == leave_type)
        if start_date:
            conditions.append(TeacherLeave.end_date >= start_date)
        if end_date:
            conditions.append(TeacherLeave.start_date <= end_date)

        stmt = select(TeacherLeave).where(
            and_(*conditions)
        ).order_by(
            TeacherLeave.requested_at.desc()
        ).offset(skip).limit(limit).options(
            selectinload(TeacherLeave.teacher)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def create(self, db_obj: TeacherLeave) -> TeacherLeave:
        """
        Saves a new leave request.
        """
        self.db.add(db_obj)
        return db_obj

    async def update(self, db_obj: TeacherLeave) -> TeacherLeave:
        """
        Updates an existing leave request.
        """
        self.db.add(db_obj)
        return db_obj

    async def find_overlapping(
        self, teacher_id: uuid.UUID, start_date: date, end_date: date, tenant_id: uuid.UUID
    ) -> List[TeacherLeave]:
        """
        Checks for any existing PENDING or APPROVED leave request for the teacher that overlaps the date range.
        """
        stmt = select(TeacherLeave).where(
            and_(
                TeacherLeave.teacher_id == teacher_id,
                TeacherLeave.tenant_id == tenant_id,
                TeacherLeave.deleted_at.is_(None),
                TeacherLeave.status.in_([LeaveStatus.PENDING, LeaveStatus.APPROVED]),
                TeacherLeave.start_date <= end_date,
                TeacherLeave.end_date >= start_date
            )
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_pending_requests(self, tenant_id: uuid.UUID) -> List[TeacherLeave]:
        """
        Retrieves all pending leave requests within a tenant.
        """
        stmt = select(TeacherLeave).where(
            and_(
                TeacherLeave.tenant_id == tenant_id,
                TeacherLeave.status == LeaveStatus.PENDING,
                TeacherLeave.deleted_at.is_(None)
            )
        ).options(selectinload(TeacherLeave.teacher))
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def get_teacher_leave_history(
        self,
        teacher_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status: Optional[LeaveStatus] = None,
        leave_type: Optional[LeaveType] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[TeacherLeave]:
        """
        Fetches leave history for a specific teacher with filters, enforcing tenant boundary.
        """
        conditions = [
            TeacherLeave.teacher_id == teacher_id,
            TeacherLeave.tenant_id == tenant_id,
            TeacherLeave.deleted_at.is_(None)
        ]
        if status:
            conditions.append(TeacherLeave.status == status)
        if leave_type:
            conditions.append(TeacherLeave.leave_type == leave_type)
        if start_date:
            conditions.append(TeacherLeave.end_date >= start_date)
        if end_date:
            conditions.append(TeacherLeave.start_date <= end_date)

        stmt = select(TeacherLeave).where(
            and_(*conditions)
        ).order_by(
            TeacherLeave.requested_at.desc()
        ).offset(skip).limit(limit).options(
            selectinload(TeacherLeave.teacher),
            selectinload(TeacherLeave.school)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())
