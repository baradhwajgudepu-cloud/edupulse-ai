import uuid
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.section import Section, SectionStatus
from app.models.academic_year import AcademicYearStatus
from app.repositories.section import SectionRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.schemas.section import SectionCreate, SectionUpdate

class SectionService:
    """
    Service Layer implementing business validations for Section management.
    """
    def __init__(
        self,
        section_repo: SectionRepository,
        ay_repo: AcademicYearRepository,
        class_repo: ClassRepository
    ) -> None:
        self.section_repo = section_repo
        self.ay_repo = ay_repo
        self.class_repo = class_repo

    async def create_section(
        self,
        tenant_id: uuid.UUID,
        obj_in: SectionCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Section:
        """
        Creates a new Section under a Class, validating school, year, and duplicate constraints.
        """
        # 1. Validate Academic Year existence and status
        ay = await self.ay_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Academic year not found or mismatch."
            )

        if ay.status == AcademicYearStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot create sections in an archived academic year."
            )

        # 2. Validate Class existence and its year/school scoping
        class_obj = await self.class_repo.get_by_id(obj_in.class_id, obj_in.school_id, tenant_id)
        if not class_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found or school mismatch."
            )

        if class_obj.academic_year_id != obj_in.academic_year_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target class does not belong to the specified academic year."
            )

        # 3. Check duplicate code inside the class
        existing_code = await self.section_repo.get_by_code(obj_in.code, obj_in.class_id, tenant_id)
        if existing_code:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Section with code '{obj_in.code}' already exists in this class."
            )

        # 4. Check duplicate name inside the class
        existing_name = await self.section_repo.get_by_name(obj_in.name, obj_in.class_id, tenant_id)
        if existing_name:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Section with name '{obj_in.name}' already exists in this class."
            )

        # 5. Enforce capacity bounds
        if obj_in.capacity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Section capacity must be a positive integer."
            )

        db_obj = await self.section_repo.create(tenant_id, obj_in, created_by=created_by)
        await self.section_repo.db.commit()
        return await self.section_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_section(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        section_id: uuid.UUID,
        obj_in: SectionUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Section:
        """
        Modifies section parameters, enforcing uniqueness within the parent class boundary.
        """
        db_obj = await self.section_repo.get_by_id(section_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Section not found."
            )

        # Name collision check inside the class
        if obj_in.name and obj_in.name != db_obj.name:
            dup_name = await self.section_repo.get_by_name(obj_in.name, db_obj.class_id, tenant_id)
            if dup_name:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Section with name '{obj_in.name}' already exists in this class."
                )

        # Code collision check inside the class
        if obj_in.code and obj_in.code != db_obj.code:
            dup_code = await self.section_repo.get_by_code(obj_in.code, db_obj.class_id, tenant_id)
            if dup_code:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Section with code '{obj_in.code}' already exists in this class."
                )

        # Capacity check
        if obj_in.capacity is not None and obj_in.capacity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Section capacity must be a positive integer."
            )

        await self.section_repo.update(db_obj, obj_in, updated_by=updated_by)
        await self.section_repo.db.commit()
        return await self.section_repo.get_by_id(section_id, school_id, tenant_id)

    async def delete_section(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        section_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Section:
        """
        Soft deletes the Section.
        """
        db_obj = await self.section_repo.get_by_id(section_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Section not found."
            )

        await self.section_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.section_repo.db.commit()
        await self.section_repo.db.refresh(db_obj)
        return db_obj
