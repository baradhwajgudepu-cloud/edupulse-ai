import uuid
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.student import Student, StudentStatus
from app.schemas.student import StudentCreate, StudentUpdate

class StudentRepository:
    """
    Repository layer for Student database operations.
    Enforces multi-tenancy boundaries and soft deletion scopes.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_by_id(
        self, student_id: uuid.UUID, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Student]:
        """
        Retrieves a single student by UUID scoped to school and tenant.
        """
        stmt = select(Student).where(
            Student.id == student_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        ).options(
            selectinload(Student.class_obj),
            selectinload(Student.section)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_admission_number(
        self, admission_number: str, school_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Student]:
        """
        Retrieves active student by admission number within school.
        """
        stmt = select(Student).where(
            Student.admission_number == admission_number,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_roll_number(
        self, roll_number: str, section_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[Student]:
        """
        Retrieves active student by roll number within section.
        """
        stmt = select(Student).where(
            Student.roll_number == roll_number,
            Student.section_id == section_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_aadhaar_number(
        self, aadhaar_number: str, tenant_id: uuid.UUID
    ) -> Optional[Student]:
        """
        Retrieves active student by Aadhaar number within the tenant.
        """
        stmt = select(Student).where(
            Student.aadhaar_number == aadhaar_number,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_multi(
        self,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID,
        academic_year_id: Optional[uuid.UUID] = None,
        class_id: Optional[uuid.UUID] = None,
        section_id: Optional[uuid.UUID] = None,
        status: Optional[StudentStatus] = None,
        search: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Student]:
        """
        Retrieves paginated list of students scoped by tenant and school.
        Supports fuzzy searching on name, email, admission_number, roll_number, aadhaar_number, and mobile.
        """
        filters = [
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.deleted_at.is_(None)
        ]

        if academic_year_id:
            filters.append(Student.academic_year_id == academic_year_id)
        if class_id:
            filters.append(Student.class_id == class_id)
        if section_id:
            filters.append(Student.section_id == section_id)
        if status:
            filters.append(Student.status == status)

        if search:
            search_clause = or_(
                Student.first_name.ilike(f"%{search}%"),
                Student.last_name.ilike(f"%{search}%"),
                Student.email.ilike(f"%{search}%"),
                Student.admission_number.ilike(f"%{search}%"),
                Student.roll_number.ilike(f"%{search}%"),
                Student.aadhaar_number.ilike(f"%{search}%"),
                Student.mobile.ilike(f"%{search}%")
            )
            filters.append(search_clause)

        stmt = (
            select(Student)
            .where(and_(*filters))
            .order_by(Student.last_name, Student.first_name)
            .offset(skip)
            .limit(limit)
            .options(
                selectinload(Student.class_obj),
                selectinload(Student.section)
            )
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create(
        self,
        tenant_id: uuid.UUID,
        obj_in: StudentCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Student:
        """
        Creates and returns transient Student entity.
        """
        db_obj = Student(
            first_name=obj_in.first_name,
            middle_name=obj_in.middle_name,
            last_name=obj_in.last_name,
            gender=obj_in.gender,
            date_of_birth=obj_in.date_of_birth,
            blood_group=obj_in.blood_group,
            aadhaar_number=obj_in.aadhaar_number,
            emis_number=obj_in.emis_number,
            mobile=obj_in.mobile,
            email=obj_in.email,
            photo_url=obj_in.photo_url,
            address=obj_in.address,
            medical_information=obj_in.medical_information,
            admission_number=obj_in.admission_number,
            roll_number=obj_in.roll_number,
            admission_date=obj_in.admission_date,
            settings=obj_in.settings,
            ai_metrics=obj_in.ai_metrics,
            tenant_id=tenant_id,
            school_id=obj_in.school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            section_id=obj_in.section_id,
            created_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update(
        self,
        db_obj: Student,
        obj_in: StudentUpdate | dict,
        updated_by: Optional[uuid.UUID] = None
    ) -> Student:
        """
        Updates student properties.
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
        db_obj: Student,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Student:
        """
        Soft deletes student profile.
        """
        now = datetime.now(timezone.utc)
        db_obj.deleted_at = now
        db_obj.status = StudentStatus.INACTIVE
        db_obj.is_active = False
        db_obj.withdrawn_at = now
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj
