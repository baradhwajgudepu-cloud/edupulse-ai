import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.subject import Subject, SubjectStatus, SubjectCategory
from app.schemas.subject import SubjectCreate, SubjectUpdate

class SubjectRepository:
    """
    Repository layer for Subject database operations.
    Enforces multi-tenancy boundaries, school boundaries, and soft deletions.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, subject_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Subject]:
        """
        Retrieves a single subject by ID scoped to school and tenant.
        """
        stmt = select(Subject).where(
            Subject.id == subject_id,
            Subject.school_id == school_id,
            Subject.tenant_id == tenant_id,
            Subject.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(
        self, subject_code: str, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Subject]:
        """
        Retrieves active subject by code scoped to academic year and tenant.
        """
        stmt = select(Subject).where(
            Subject.subject_code == subject_code,
            Subject.academic_year_id == academic_year_id,
            Subject.tenant_id == tenant_id,
            Subject.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_name(
        self, subject_name: str, academic_year_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Subject]:
        """
        Retrieves active subject by name scoped to academic year and tenant.
        """
        stmt = select(Subject).where(
            Subject.subject_name == subject_name,
            Subject.academic_year_id == academic_year_id,
            Subject.tenant_id == tenant_id,
            Subject.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        category: Optional[SubjectCategory] = None,
        status: Optional[SubjectStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Subject]:
        """
        Retrieves paginated list of subjects scoped by tenant and school.
        Supports fuzzy searching on subject_name, subject_code, and short_name.
        """
        filters = [
            Subject.school_id == school_id,
            Subject.tenant_id == tenant_id,
            Subject.deleted_at.is_(None)
        ]

        if academic_year_id:
            filters.append(Subject.academic_year_id == academic_year_id)
        if category:
            filters.append(Subject.category == category)
        if status:
            filters.append(Subject.status == status)

        if search:
            search_clause = or_(
                Subject.subject_name.ilike(f"%{search}%"),
                Subject.subject_code.ilike(f"%{search}%"),
                Subject.short_name.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            select(Subject)
            .where(and_(*filters))
            .order_by(Subject.display_order, Subject.subject_name)
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: SubjectCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Subject:
        """
        Creates and returns transient Subject entity.
        """
        db_obj = Subject(
            subject_code=obj_in.subject_code,
            subject_name=obj_in.subject_name,
            short_name=obj_in.short_name,
            category=obj_in.category,
            subject_type=obj_in.subject_type,
            description=obj_in.description,
            credit_hours=obj_in.credit_hours,
            weekly_periods=obj_in.weekly_periods,
            theory_marks=obj_in.theory_marks,
            practical_marks=obj_in.practical_marks,
            pass_marks=obj_in.pass_marks,
            display_color=obj_in.display_color,
            display_order=obj_in.display_order,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Subject,
        obj_in: SubjectUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Subject:
        """
        Updates subject details.
        """
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        db_obj.updated_by = updated_by
        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: Subject,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Subject:
        """
        Soft deletes subject.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = SubjectStatus.ARCHIVED
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
