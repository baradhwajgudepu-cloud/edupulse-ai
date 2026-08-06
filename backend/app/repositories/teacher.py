import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.teacher import Teacher, TeacherStatus
from app.schemas.teacher import TeacherCreate, TeacherUpdate

class TeacherRepository:
    """
    Repository layer for Teacher database operations.
    Enforces multi-tenancy boundaries and soft deletion.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, teacher_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves a single teacher by UUID scoped to school and tenant.
        """
        stmt = select(Teacher).where(
            Teacher.id == teacher_id,
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_employee_code(
        self, employee_code: str, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by employee code scoped to school and tenant.
        """
        stmt = select(Teacher).where(
            Teacher.employee_code == employee_code,
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_staff_code(
        self, staff_code: str, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by staff code scoped to school and tenant.
        """
        stmt = select(Teacher).where(
            Teacher.staff_code == staff_code,
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_mobile(
        self, mobile: str, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by mobile scoped to tenant.
        """
        stmt = select(Teacher).where(
            Teacher.mobile == mobile,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_official_email(
        self, email: str, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by official email scoped to tenant.
        """
        stmt = select(Teacher).where(
            Teacher.official_email == email,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_personal_email(
        self, email: str, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by personal email scoped to tenant.
        """
        stmt = select(Teacher).where(
            Teacher.personal_email == email,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_aadhaar(
        self, aadhaar: str, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by Aadhaar scoped to tenant.
        """
        stmt = select(Teacher).where(
            Teacher.aadhaar_number == aadhaar,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_pan(
        self, pan: str, tenant_id: uuid.UUID
    ) -> Optional[Teacher]:
        """
        Retrieves active teacher by PAN scoped to tenant.
        """
        stmt = select(Teacher).where(
            Teacher.pan_number == pan,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        department: Optional[str] = None,
        designation: Optional[str] = None,
        status: Optional[TeacherStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Teacher]:
        """
        Retrieves paginated list of teachers scoped by tenant and school.
        Supports fuzzy searching on names, emails, mobile, codes, Aadhaar, and PAN.
        """
        filters = [
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        ]

        if department:
            filters.append(Teacher.department.ilike(f"%{department}%"))
        if designation:
            filters.append(Teacher.designation.ilike(f"%{designation}%"))
        if status:
            filters.append(Teacher.status == status)

        if search:
            search_clause = or_(
                Teacher.first_name.ilike(f"%{search}%"),
                Teacher.last_name.ilike(f"%{search}%"),
                Teacher.mobile.ilike(f"%{search}%"),
                Teacher.official_email.ilike(f"%{search}%"),
                Teacher.personal_email.ilike(f"%{search}%"),
                Teacher.employee_code.ilike(f"%{search}%"),
                Teacher.staff_code.ilike(f"%{search}%"),
                Teacher.aadhaar_number.ilike(f"%{search}%"),
                Teacher.pan_number.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            select(Teacher)
            .where(and_(*filters))
            .order_by(Teacher.last_name, Teacher.first_name)
            .offset(skip)
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: TeacherCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Creates and returns transient Teacher entity.
        """
        db_obj = Teacher(
            employee_code=obj_in.employee_code,
            staff_code=obj_in.staff_code,
            first_name=obj_in.first_name,
            middle_name=obj_in.middle_name,
            last_name=obj_in.last_name,
            gender=obj_in.gender,
            date_of_birth=obj_in.date_of_birth,
            blood_group=obj_in.blood_group,
            aadhaar_number=obj_in.aadhaar_number,
            pan_number=obj_in.pan_number,
            mobile=obj_in.mobile,
            alternate_mobile=obj_in.alternate_mobile,
            official_email=obj_in.official_email,
            personal_email=obj_in.personal_email,
            emergency_contact_name=obj_in.emergency_contact_name,
            emergency_contact_mobile=obj_in.emergency_contact_mobile,
            emergency_contact_relation=obj_in.emergency_contact_relation,
            photo_url=obj_in.photo_url,
            address=obj_in.address,
            qualification=obj_in.qualification,
            specialization=obj_in.specialization,
            experience_years=obj_in.experience_years,
            joining_date=obj_in.joining_date,
            date_of_confirmation=obj_in.date_of_confirmation,
            date_of_resignation=obj_in.date_of_resignation,
            date_of_retirement=obj_in.date_of_retirement,
            employment_type=obj_in.employment_type,
            designation=obj_in.designation,
            department=obj_in.department,
            salary=obj_in.salary,
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
        db_obj: Teacher,
        obj_in: TeacherUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Updates teacher details.
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
        db_obj: Teacher,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Soft deletes teacher.
        """
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.status = TeacherStatus.INACTIVE
        db_obj.is_active = False
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
