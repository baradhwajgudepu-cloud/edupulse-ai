import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status

from app.models.subject import Subject, SubjectStatus, SubjectType
from app.models.academic_year import AcademicYearStatus
from app.repositories.subject import SubjectRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.subject import SubjectCreate, SubjectUpdate

class SubjectService:
    """
    Service Layer implementing business validations and updates for Subjects.
    """
    def __init__(
        self,
        subject_repo: SubjectRepository,
        school_repo: SchoolRepository,
        academic_year_repo: AcademicYearRepository
    ) -> None:
        self.subject_repo = subject_repo
        self.school_repo = school_repo
        self.academic_year_repo = academic_year_repo

    async def create_subject(
        self,
        tenant_id: uuid.UUID,
        obj_in: SubjectCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Subject:
        """
        Registers a new subject after validating academic year status, duplicate codes, and marks logic.
        """
        # 1. School existence check
        school = await self.school_repo.get_by_id(obj_in.school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found under the active tenant."
            )

        # 2. Academic Year existence & status check
        ay = await self.academic_year_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Academic year not found in this school."
            )
        if ay.status == AcademicYearStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Cannot register subjects inside an archived academic year."
            )

        # 3. Marks validation
        theory = obj_in.theory_marks or 0
        practical = obj_in.practical_marks or 0
        pass_m = obj_in.pass_marks or 0

        # Type checks
        if obj_in.subject_type == SubjectType.THEORY and practical > 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Theory-only subjects cannot have practical marks."
            )
        if obj_in.subject_type == SubjectType.PRACTICAL and theory > 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Practical-only subjects cannot have theory marks."
            )

        if pass_m > (theory + practical):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Passing marks cannot exceed total theory and practical marks."
            )

        # 4. Duplicate checks within active academic year
        dup_code = await self.subject_repo.get_by_code(obj_in.subject_code, obj_in.academic_year_id, tenant_id)
        if dup_code:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Subject with code '{obj_in.subject_code}' already exists in this academic year."
            )

        dup_name = await self.subject_repo.get_by_name(obj_in.subject_name, obj_in.academic_year_id, tenant_id)
        if dup_name:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Subject with name '{obj_in.subject_name}' already exists in this academic year."
            )

        db_obj = await self.subject_repo.create(tenant_id, obj_in, created_by=created_by)
        db_obj.status = SubjectStatus.ACTIVE
        db_obj.is_active = True

        await self.subject_repo.db.commit()
        return await self.subject_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_subject(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        subject_id: uuid.UUID,
        obj_in: SubjectUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Subject:
        """
        Updates an existing Subject record.
        """
        db_obj = await self.subject_repo.get_by_id(subject_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject catalog profile not found."
            )

        # Marks constraints
        theory = obj_in.theory_marks if obj_in.theory_marks is not None else db_obj.theory_marks
        practical = obj_in.practical_marks if obj_in.practical_marks is not None else db_obj.practical_marks
        pass_m = obj_in.pass_marks if obj_in.pass_marks is not None else db_obj.pass_marks
        sub_type = obj_in.subject_type if obj_in.subject_type is not None else db_obj.subject_type

        if sub_type == SubjectType.THEORY and practical > 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Theory-only subjects cannot have practical marks."
            )
        if sub_type == SubjectType.PRACTICAL and theory > 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Practical-only subjects cannot have theory marks."
            )

        if pass_m > (theory + practical):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Passing marks cannot exceed total theory and practical marks."
            )

        # Duplicate checks
        if obj_in.subject_code and obj_in.subject_code != db_obj.subject_code:
            dup_code = await self.subject_repo.get_by_code(obj_in.subject_code, db_obj.academic_year_id, tenant_id)
            if dup_code:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Subject with code '{obj_in.subject_code}' already exists in this academic year."
                )

        if obj_in.subject_name and obj_in.subject_name != db_obj.subject_name:
            dup_name = await self.subject_repo.get_by_name(obj_in.subject_name, db_obj.academic_year_id, tenant_id)
            if dup_name:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Subject with name '{obj_in.subject_name}' already exists in this academic year."
                )

        update_data = obj_in.model_dump(exclude_unset=True)
        if "status" in update_data:
            if update_data["status"] == SubjectStatus.INACTIVE or update_data["status"] == SubjectStatus.ARCHIVED:
                update_data["is_active"] = False
            else:
                update_data["is_active"] = True

        await self.subject_repo.update(db_obj, update_data, updated_by=updated_by)
        await self.subject_repo.db.commit()
        return await self.subject_repo.get_by_id(subject_id, school_id, tenant_id)

    async def delete_subject(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        subject_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Subject:
        """
        Soft deletes the Subject profile.
        """
        db_obj = await self.subject_repo.get_by_id(subject_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Subject not found."
            )

        await self.subject_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.subject_repo.db.commit()
        await self.subject_repo.db.refresh(db_obj)
        return db_obj
