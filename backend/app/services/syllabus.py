import uuid
from typing import Optional
from fastapi import HTTPException, status

from app.models.syllabus import Syllabus
from app.models.user import User
from app.schemas.syllabus import SyllabusCreate, SyllabusUpdate
from app.repositories.syllabus import SyllabusRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.subject import SubjectRepository

class SyllabusService:
    """
    Service Layer implementing business rules and hierarchy validations for Syllabus management.
    """
    def __init__(
        self,
        syllabus_repo: SyllabusRepository,
        school_repo: SchoolRepository,
        academic_year_repo: AcademicYearRepository,
        class_repo: ClassRepository,
        subject_repo: SubjectRepository
    ) -> None:
        self.syllabus_repo = syllabus_repo
        self.school_repo = school_repo
        self.academic_year_repo = academic_year_repo
        self.class_repo = class_repo
        self.subject_repo = subject_repo

    async def create_syllabus_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        obj_in: SyllabusCreate,
        current_user: User
    ) -> Syllabus:
        """
        Validates references hierarchy and uniqueness, and creates a Syllabus record.
        """
        # 1. School check under tenant
        school = await self.school_repo.get_by_id(school_id, tenant_id)
        if not school or not school.is_active:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active school entity not found."
            )

        # 2. Academic year check under school/tenant
        ay = await self.academic_year_repo.get_by_id(academic_year_id, school_id, tenant_id)
        if not ay or ay.status.value != "ACTIVE":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Active academic year entity not found."
            )

        # 3. Class check under school/tenant
        class_obj = await self.class_repo.get_by_id(obj_in.class_id, school_id, tenant_id)
        if not class_obj or class_obj.academic_year_id != academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class not found or academic year mismatch."
            )

        # 4. Subject check under school/tenant
        subject_obj = await self.subject_repo.get_by_id(obj_in.subject_id, school_id, tenant_id)
        if not subject_obj or subject_obj.academic_year_id != academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Subject not found or academic year mismatch."
            )

        # 5. Duplicate Code Check
        dup = await self.syllabus_repo.get_by_code(
            syllabus_code=obj_in.syllabus_code,
            academic_year_id=academic_year_id,
            class_id=obj_in.class_id,
            subject_id=obj_in.subject_id,
            tenant_id=tenant_id
        )
        if dup:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Syllabus entry with code '{obj_in.syllabus_code}' already exists for this class and subject in this academic year."
            )

        db_obj = await self.syllabus_repo.create(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=academic_year_id,
            obj_in=obj_in,
            created_by=current_user.id
        )
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(db_obj)
        return db_obj

    async def update_syllabus_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        obj_in: SyllabusUpdate,
        current_user: User
    ) -> Syllabus:
        """
        Updates details of a Syllabus entry.
        """
        db_obj = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Syllabus entry not found."
            )

        updated_obj = await self.syllabus_repo.update(db_obj, obj_in, updated_by=current_user.id)
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(updated_obj)
        return updated_obj

    async def delete_syllabus_entry(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        syllabus_id: uuid.UUID,
        current_user: User
    ) -> Syllabus:
        """
        Soft deletes a Syllabus entry.
        """
        db_obj = await self.syllabus_repo.get_by_id(syllabus_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Syllabus entry not found."
            )

        deleted_obj = await self.syllabus_repo.soft_delete(db_obj, deleted_by=current_user.id)
        await self.syllabus_repo.db.commit()
        await self.syllabus_repo.db.refresh(deleted_obj)
        return deleted_obj
