import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.guardian import Guardian, GuardianStatus, StudentGuardian, StudentGuardianRelationship
from app.models.user import User
from app.schemas.guardian import GuardianCreate, GuardianUpdate, StudentGuardianCreate, StudentGuardianUpdate

class GuardianRepository:
    """
    Repository layer for Guardian database operations.
    Enforces multi-tenancy limits and soft deletion.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, guardian_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Guardian]:
        """
        Retrieves a single guardian by UUID scoped to school and tenant.
        """
        stmt = select(Guardian).where(
            Guardian.id == guardian_id,
            Guardian.school_id == school_id,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        ).options(
            selectinload(Guardian.students),
            selectinload(Guardian.user)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_mobile(
        self, mobile: str, tenant_id: uuid.UUID
    ) -> Optional[Guardian]:
        """
        Retrieves active guardian by mobile within the tenant.
        """
        stmt = select(Guardian).where(
            Guardian.mobile == mobile,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email(
        self, email: str, tenant_id: uuid.UUID
    ) -> Optional[Guardian]:
        """
        Retrieves active guardian by email within the tenant.
        """
        stmt = select(Guardian).where(
            Guardian.email == email,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_aadhaar(
        self, aadhaar: str, tenant_id: uuid.UUID
    ) -> Optional[Guardian]:
        """
        Retrieves active guardian by Aadhaar within the tenant.
        """
        stmt = select(Guardian).where(
            Guardian.aadhaar_number == aadhaar,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_pan(
        self, pan: str, tenant_id: uuid.UUID
    ) -> Optional[Guardian]:
        """
        Retrieves active guardian by PAN within the tenant.
        """
        stmt = select(Guardian).where(
            Guardian.pan_number == pan,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        status: Optional[GuardianStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Guardian]:
        """
        Retrieves paginated list of guardians scoped by tenant and school.
        Supports fuzzy searching on names, mobile, email, Aadhaar, PAN, and Parent Login ID.
        """
        filters = [
            Guardian.school_id == school_id,
            Guardian.tenant_id == tenant_id,
            Guardian.deleted_at.is_(None)
        ]

        if status:
            filters.append(Guardian.status == status)

        stmt = select(Guardian)
        if search:
            stmt = stmt.outerjoin(User, Guardian.user_id == User.id)
            search_clause = or_(
                Guardian.first_name.ilike(f"%{search}%"),
                Guardian.last_name.ilike(f"%{search}%"),
                Guardian.mobile.ilike(f"%{search}%"),
                Guardian.email.ilike(f"%{search}%"),
                Guardian.aadhaar_number.ilike(f"%{search}%"),
                Guardian.pan_number.ilike(f"%{search}%"),
                User.login_id.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            stmt.where(and_(*filters))
            .order_by(Guardian.last_name, Guardian.first_name)
            .offset(skip)
            .limit(limit)
            .options(
                selectinload(Guardian.students),
                selectinload(Guardian.user)
            )
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: GuardianCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Creates and returns transient Guardian entity.
        """
        db_obj = Guardian(
            guardian_type=obj_in.guardian_type,
            first_name=obj_in.first_name,
            middle_name=obj_in.middle_name,
            last_name=obj_in.last_name,
            gender=obj_in.gender,
            date_of_birth=obj_in.date_of_birth,
            aadhaar_number=obj_in.aadhaar_number,
            pan_number=obj_in.pan_number,
            occupation=obj_in.occupation,
            qualification=obj_in.qualification,
            organization=obj_in.organization,
            annual_income=obj_in.annual_income,
            mobile=obj_in.mobile,
            alternate_mobile=obj_in.alternate_mobile,
            email=obj_in.email,
            emergency_contact_name=obj_in.emergency_contact_name,
            emergency_contact_mobile=obj_in.emergency_contact_mobile,
            photo_url=obj_in.photo_url,
            address=obj_in.address,
            communication_preferences=obj_in.communication_preferences,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Guardian,
        obj_in: GuardianUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Updates guardian details.
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
        db_obj: Guardian,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Soft deletes guardian.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = GuardianStatus.INACTIVE
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj


class StudentGuardianRepository:
    """
    Repository layer for StudentGuardian mapping table.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, mapping_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[StudentGuardian]:
        """
        Retrieves mapping by ID.
        """
        stmt = select(StudentGuardian).where(
            StudentGuardian.id == mapping_id,
            StudentGuardian.school_id == school_id,
            StudentGuardian.tenant_id == tenant_id,
            StudentGuardian.deleted_at.is_(None)
        ).options(
            selectinload(StudentGuardian.student),
            selectinload(StudentGuardian.guardian)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_mapping(
        self, student_id: uuid.UUID, guardian_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[StudentGuardian]:
        """
        Retrieves active student-guardian mapping.
        """
        stmt = select(StudentGuardian).where(
            StudentGuardian.student_id == student_id,
            StudentGuardian.guardian_id == guardian_id,
            StudentGuardian.tenant_id == tenant_id,
            StudentGuardian.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_primary_mapping(
        self, student_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[StudentGuardian]:
        """
        Retrieves primary active mapping for a student.
        """
        stmt = select(StudentGuardian).where(
            StudentGuardian.student_id == student_id,
            StudentGuardian.is_primary == True,
            StudentGuardian.tenant_id == tenant_id,
            StudentGuardian.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_student_guardians(
        self, student_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[StudentGuardian]:
        """
        Lists active guardian mappings for a student.
        """
        stmt = (
            select(StudentGuardian)
            .where(
                StudentGuardian.student_id == student_id,
                StudentGuardian.tenant_id == tenant_id,
                StudentGuardian.deleted_at.is_(None)
            )
            .options(selectinload(StudentGuardian.guardian))
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_guardian_students(
        self, guardian_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> List[StudentGuardian]:
        """
        Lists active student mappings for a guardian.
        """
        stmt = (
            select(StudentGuardian)
            .where(
                StudentGuardian.guardian_id == guardian_id,
                StudentGuardian.tenant_id == tenant_id,
                StudentGuardian.deleted_at.is_(None)
            )
            .options(selectinload(StudentGuardian.student))
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: StudentGuardianCreate
    ) -> StudentGuardian:
        """
        Creates and returns transient mapping.
        """
        db_obj = StudentGuardian(
            student_id=obj_in.student_id,
            guardian_id=obj_in.guardian_id,
            relationship=obj_in.relationship,
            is_primary=obj_in.is_primary,
            can_pickup_student=obj_in.can_pickup_student,
            receives_notifications=obj_in.receives_notifications,
            tenant_id=tenant_id,
            school_id=obj_in.school_id
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: StudentGuardian,
        obj_in: StudentGuardianUpdate | dict
    ) -> StudentGuardian:
        """
        Updates mapping details.
        """
        if isinstance(obj_in, dict):
            update_data = obj_in
        else:
            update_data = obj_in.model_dump(exclude_unset=True)

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        self.db.add(db_obj)
        return db_obj

    async def soft_delete(
        self,
        db_obj: StudentGuardian
    ) -> StudentGuardian:
        """
        Soft deletes mapping.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        self.db.add(db_obj)
        return db_obj
