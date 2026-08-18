import uuid
from datetime import date, datetime
from typing import Optional
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.staff_attendance import StaffAttendance

class StaffAttendanceRepository:
    """
    Repository for StaffAttendance database operations.
    Enforces multi-tenancy and scoped querying boundaries.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_date(
        self, teacher_id: uuid.UUID, attendance_date: date, tenant_id: uuid.UUID
    ) -> Optional[StaffAttendance]:
        """
        Retrieves a teacher's staff attendance record for a specific date within tenant scope.
        """
        stmt = select(StaffAttendance).where(
            StaffAttendance.teacher_id == teacher_id,
            StaffAttendance.attendance_date == attendance_date,
            StaffAttendance.tenant_id == tenant_id,
            StaffAttendance.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create(self, db_obj: StaffAttendance) -> StaffAttendance:
        """
        Saves a new staff attendance record.
        """
        self.db.add(db_obj)
        return db_obj

    async def update(self, db_obj: StaffAttendance) -> StaffAttendance:
        """
        Saves changes to an existing staff attendance record.
        """
        self.db.add(db_obj)
        return db_obj

    async def get_history(
        self,
        teacher_id: uuid.UUID,
        tenant_id: uuid.UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> list[StaffAttendance]:
        """
        Retrieves a list of staff attendance records for a specific teacher with optional date filters.
        """
        stmt = select(StaffAttendance).where(
            StaffAttendance.teacher_id == teacher_id,
            StaffAttendance.tenant_id == tenant_id,
            StaffAttendance.deleted_at.is_(None)
        )
        if start_date:
            stmt = stmt.where(StaffAttendance.attendance_date >= start_date)
        if end_date:
            stmt = stmt.where(StaffAttendance.attendance_date <= end_date)
            
        stmt = stmt.order_by(StaffAttendance.attendance_date.desc()).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())
