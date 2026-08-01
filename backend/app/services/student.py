import uuid
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy import func, select

from app.models.student import Student, StudentStatus
from app.models.academic_year import AcademicYearStatus
from app.repositories.student import StudentRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.schemas.student import StudentCreate, StudentUpdate

class StudentService:
    """
    Service Layer implementing business validations and lifecycle management for Students.
    """
    def __init__(
        self,
        student_repo: StudentRepository,
        ay_repo: AcademicYearRepository,
        class_repo: ClassRepository,
        section_repo: SectionRepository
    ) -> None:
        self.student_repo = student_repo
        self.ay_repo = ay_repo
        self.class_repo = class_repo
        self.section_repo = section_repo

    async def create_student(
        self,
        tenant_id: uuid.UUID,
        obj_in: StudentCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Student:
        """
        Registers a new Student, validating date bounds, scope matches, duplicate limits, and section capacity.
        """
        current_date = date.today()

        # 1. Date Validation
        if obj_in.date_of_birth >= current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Date of birth must be in the past."
            )

        if obj_in.admission_date > current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Admission date cannot be in the future."
            )

        # 2. Scope verification (Tenant -> School -> AcademicYear)
        ay = await self.ay_repo.get_by_id(obj_in.academic_year_id, obj_in.school_id, tenant_id)
        if not ay:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Academic year not found or school mismatch."
            )

        if ay.status == AcademicYearStatus.ARCHIVED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot register students inside an archived academic year."
            )

        # Class verification
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

        # Section verification
        section_obj = await self.section_repo.get_by_id(obj_in.section_id, obj_in.school_id, tenant_id)
        if not section_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Section not found or school mismatch."
            )

        if section_obj.class_id != obj_in.class_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target section does not belong to the specified class."
            )

        # 3. Duplicate checks
        # Admission number unique per school
        dup_adm = await self.student_repo.get_by_admission_number(obj_in.admission_number, obj_in.school_id, tenant_id)
        if dup_adm:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Student with admission number '{obj_in.admission_number}' already exists in this school."
            )

        # Roll number unique per section
        dup_roll = await self.student_repo.get_by_roll_number(obj_in.roll_number, obj_in.section_id, tenant_id)
        if dup_roll:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Student with roll number '{obj_in.roll_number}' already exists in this section."
            )

        # Aadhaar number unique globally (within tenant)
        if obj_in.aadhaar_number:
            dup_aadhaar = await self.student_repo.get_by_aadhaar_number(obj_in.aadhaar_number, tenant_id)
            if dup_aadhaar:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Student with this Aadhaar number is already registered."
                )

        # 4. Capacity validation check
        stmt = select(func.count(Student.id)).where(
            Student.section_id == obj_in.section_id,
            Student.deleted_at.is_(None)
        )
        res = await self.student_repo.db.execute(stmt)
        active_count = res.scalar() or 0
        if active_count >= section_obj.capacity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot register student because target section capacity has been reached."
            )

        db_obj = await self.student_repo.create(tenant_id, obj_in, created_by=created_by)
        
        # Populate initial timeline
        now = datetime.now(timezone.utc)
        db_obj.admitted_at = now
        db_obj.status = StudentStatus.ACTIVE
        db_obj.is_active = True

        await self.student_repo.db.commit()
        return await self.student_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_student(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: uuid.UUID,
        obj_in: StudentUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Student:
        """
        Modifies student properties, enforcing boundary uniqueness and lifecycle timeline stamps.
        """
        db_obj = await self.student_repo.get_by_id(student_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found."
            )

        # Date validation
        current_date = date.today()
        if obj_in.date_of_birth and obj_in.date_of_birth >= current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Date of birth must be in the past."
            )

        if obj_in.admission_date and obj_in.admission_date > current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Admission date cannot be in the future."
            )

        # Check duplicate admission number in school
        if obj_in.admission_number and obj_in.admission_number != db_obj.admission_number:
            dup_adm = await self.student_repo.get_by_admission_number(obj_in.admission_number, school_id, tenant_id)
            if dup_adm:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Student with admission number '{obj_in.admission_number}' already exists in this school."
                )

        # Check duplicate roll number in section
        if obj_in.roll_number and obj_in.roll_number != db_obj.roll_number:
            dup_roll = await self.student_repo.get_by_roll_number(obj_in.roll_number, db_obj.section_id, tenant_id)
            if dup_roll:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Student with roll number '{obj_in.roll_number}' already exists in this section."
                )

        # Check duplicate Aadhaar
        if obj_in.aadhaar_number and obj_in.aadhaar_number != db_obj.aadhaar_number:
            dup_aadhaar = await self.student_repo.get_by_aadhaar_number(obj_in.aadhaar_number, tenant_id)
            if dup_aadhaar:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Student with this Aadhaar number is already registered."
                )

        update_data = obj_in.model_dump(exclude_unset=True)

        # 5. Lifecycle audit stamps matching status changes
        if "status" in update_data:
            new_status = update_data["status"]
            old_status = db_obj.status
            if new_status != old_status:
                now = datetime.now(timezone.utc)
                if new_status == StudentStatus.ACTIVE:
                    update_data["admitted_at"] = now
                    update_data["is_active"] = True
                elif new_status == StudentStatus.ALUMNI:
                    update_data["graduated_at"] = now
                    update_data["is_active"] = False
                elif new_status == StudentStatus.WITHDRAWN:
                    update_data["withdrawn_at"] = now
                    update_data["is_active"] = False
                elif new_status == StudentStatus.INACTIVE or new_status == StudentStatus.SUSPENDED:
                    update_data["is_active"] = False

        await self.student_repo.update(db_obj, update_data, updated_by=updated_by)
        await self.student_repo.db.commit()
        return await self.student_repo.get_by_id(student_id, school_id, tenant_id)

    async def delete_student(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        student_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Student:
        """
        Soft deletes the student profile, updating status to INACTIVE.
        """
        db_obj = await self.student_repo.get_by_id(student_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found."
            )

        await self.student_repo.soft_delete(db_obj, deleted_by=deleted_by)
        await self.student_repo.db.commit()
        await self.student_repo.db.refresh(db_obj)
        return db_obj
