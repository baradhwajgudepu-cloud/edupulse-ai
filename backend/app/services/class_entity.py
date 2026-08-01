import uuid
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.class_entity import Class, ClassStatus
from app.models.academic_year import AcademicYearStatus
from app.repositories.class_entity import ClassRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.class_entity import ClassCreate, ClassUpdate

class ClassService:
    """
    Service Layer implementing business rules for Class management.
    """
    def __init__(
        self,
        class_repo: ClassRepository,
        ay_repo: AcademicYearRepository
    ) -> None:
        self.class_repo = class_repo
        self.ay_repo = ay_repo

    async def create_class(
        self,
        tenant_id: uuid.UUID,
        obj_in: ClassCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Creates a new class, performing academic year validations, code/name uniqueness checks,
        and capacity validation.
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
                detail="Cannot create classes in an archived academic year."
            )

        # 2. Prevent duplicate codes within the same Academic Year
        existing_code = await self.class_repo.get_by_code(obj_in.code, obj_in.academic_year_id, tenant_id)
        if existing_code:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Class with code '{obj_in.code}' already exists in this academic year."
            )

        # 3. Prevent duplicate names within the same Academic Year
        existing_name = await self.class_repo.get_by_name(obj_in.name, obj_in.academic_year_id, tenant_id)
        if existing_name:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Class with name '{obj_in.name}' already exists in this academic year."
            )

        # 4. Enforce capacity bounds
        if obj_in.capacity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class capacity must be a positive integer."
            )

        # 5. Delegate to repository
        db_obj = await self.class_repo.create(tenant_id, obj_in, created_by=created_by)
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        obj_in: ClassUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Modifies class attributes, verifying name and code uniqueness.
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        # Name duplicate check
        if obj_in.name and obj_in.name != db_obj.name:
            dup_name = await self.class_repo.get_by_name(obj_in.name, db_obj.academic_year_id, tenant_id)
            if dup_name:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Class with name '{obj_in.name}' already exists in this academic year."
                )

        # Code duplicate check
        if obj_in.code and obj_in.code != db_obj.code:
            dup_code = await self.class_repo.get_by_code(obj_in.code, db_obj.academic_year_id, tenant_id)
            if dup_code:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Class with code '{obj_in.code}' already exists in this academic year."
                )

        # Capacity validation
        if obj_in.capacity is not None and obj_in.capacity <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Class capacity must be a positive integer."
            )

        await self.class_repo.update(db_obj, obj_in, updated_by=updated_by)
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(class_id, school_id, tenant_id)

    async def delete_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Soft deletes the Class. Blocked if sections exist (mock placeholder checked via settings).
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        # Check active sections count or mock settings validation check
        from sqlalchemy import func, select
        from app.models.section import Section
        stmt_sec = select(func.count(Section.id)).where(
            Section.class_id == class_id,
            Section.deleted_at.is_(None)
        )
        res_sec = await self.class_repo.db.execute(stmt_sec)
        sections_count = res_sec.scalar() or 0
        
        mock_check = db_obj.settings and db_obj.settings.get("sections_exist") is True
        if sections_count > 0 or mock_check:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete class because sections are currently assigned."
            )

        await self.class_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.class_repo.db.commit()
        await self.class_repo.db.refresh(db_obj)
        return db_obj

    async def archive_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        updated_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Transitions class status to ARCHIVED.
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        db_obj.status = ClassStatus.ARCHIVED
        db_obj.is_active = False
        db_obj.updated_by = updated_by
        
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(class_id, school_id, tenant_id)

    async def promote_class(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: uuid.UUID,
        updated_by: Optional[uuid.UUID] = None
    ) -> Class:
        """
        Mock promotion routine to execute promotion mapping checks.
        """
        db_obj = await self.class_repo.get_by_id(class_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Class not found."
            )

        # Placeholders for future automated promotion logic checks...
        db_obj.settings["last_promotion_execution"] = str(uuid.uuid4())
        db_obj.updated_by = updated_by
        
        await self.class_repo.db.commit()
        return await self.class_repo.get_by_id(class_id, school_id, tenant_id)
