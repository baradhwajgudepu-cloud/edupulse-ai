import uuid
import logging
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy import select

from app.models.teacher import Teacher, TeacherStatus
from app.models.user import User, UserStatus
from app.repositories.teacher import TeacherRepository
from app.repositories.school import SchoolRepository
from app.schemas.teacher import TeacherCreate, TeacherUpdate

logger = logging.getLogger(__name__)

class TeacherService:
    """
    Service Layer implementing business validations and updates for Teachers.
    """
    def __init__(
        self,
        teacher_repo: TeacherRepository,
        school_repo: SchoolRepository
    ) -> None:
        self.teacher_repo = teacher_repo
        self.school_repo = school_repo

    async def create_teacher(
        self,
        tenant_id: uuid.UUID,
        obj_in: TeacherCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Creates a new Teacher profile, validating age, joining dates, salary, and uniqueness checks.
        """
        current_date = date.today()

        # 1. Age Validation (Age >= 18)
        dob = obj_in.date_of_birth
        age = current_date.year - dob.year - ((current_date.month, current_date.day) < (dob.month, dob.day))
        if age < 18:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Teacher must be at least 18 years old."
            )

        # Joining Date Validation
        if obj_in.joining_date > current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Joining date cannot be in the future."
            )

        # Scoping Verification
        school = await self.school_repo.get_by_id(obj_in.school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found under the active tenant."
            )

        # Unique Checks within School
        # Employee Code
        dup_emp = await self.teacher_repo.get_by_employee_code(obj_in.employee_code, obj_in.school_id, tenant_id)
        if dup_emp:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Teacher with employee code '{obj_in.employee_code}' already exists in this school."
            )

        # Staff Code
        dup_staff = await self.teacher_repo.get_by_staff_code(obj_in.staff_code, obj_in.school_id, tenant_id)
        if dup_staff:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Teacher with staff code '{obj_in.staff_code}' already exists in this school."
            )

        # Unique Checks within Tenant
        # Mobile
        dup_mob = await self.teacher_repo.get_by_mobile(obj_in.mobile, tenant_id)
        if dup_mob:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Teacher with mobile number '{obj_in.mobile}' already exists."
            )

        # Official Email
        dup_off_email = await self.teacher_repo.get_by_official_email(obj_in.official_email, tenant_id)
        if dup_off_email:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Teacher with official email '{obj_in.official_email}' already exists."
            )

        # Personal Email
        if obj_in.personal_email:
            dup_pers_email = await self.teacher_repo.get_by_personal_email(obj_in.personal_email, tenant_id)
            if dup_pers_email:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Teacher with personal email '{obj_in.personal_email}' already exists."
                )

        # Aadhaar
        if obj_in.aadhaar_number:
            dup_aadhaar = await self.teacher_repo.get_by_aadhaar(obj_in.aadhaar_number, tenant_id)
            if dup_aadhaar:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Teacher with this Aadhaar number already exists."
                )

        # PAN
        if obj_in.pan_number:
            dup_pan = await self.teacher_repo.get_by_pan(obj_in.pan_number, tenant_id)
            if dup_pan:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Teacher with this PAN number already exists."
                )

        db_obj = await self.teacher_repo.create(tenant_id, obj_in, created_by=created_by)
        db_obj.status = TeacherStatus.ACTIVE
        db_obj.is_active = True
        
        await self.teacher_repo.db.commit()

        try:
            from app.services.identity_provisioning import IdentityProvisioningService
            provision_service = IdentityProvisioningService(self.teacher_repo.db)
            await provision_service.provision_teacher(tenant_id, obj_in.school_id, db_obj.id, created_by)
        except Exception as ex:
            logger.error(f"Failed to auto-provision user identity for teacher: {ex}")

        return await self.teacher_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_teacher(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        teacher_id: uuid.UUID,
        obj_in: TeacherUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Updates an existing Teacher record.
        """
        db_obj = await self.teacher_repo.get_by_id(teacher_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found."
            )

        current_date = date.today()

        # Age validation
        if obj_in.date_of_birth:
            dob = obj_in.date_of_birth
            age = current_date.year - dob.year - ((current_date.month, current_date.day) < (dob.month, dob.day))
            if age < 18:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Teacher must be at least 18 years old."
                )

        if obj_in.joining_date and obj_in.joining_date > current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Joining date cannot be in the future."
            )

        # Employee Code uniqueness
        if obj_in.employee_code and obj_in.employee_code != db_obj.employee_code:
            dup_emp = await self.teacher_repo.get_by_employee_code(obj_in.employee_code, school_id, tenant_id)
            if dup_emp:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Teacher with employee code '{obj_in.employee_code}' already exists in this school."
                )

        # Staff Code uniqueness
        if obj_in.staff_code and obj_in.staff_code != db_obj.staff_code:
            dup_staff = await self.teacher_repo.get_by_staff_code(obj_in.staff_code, school_id, tenant_id)
            if dup_staff:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Teacher with staff code '{obj_in.staff_code}' already exists in this school."
                )

        # Tenant uniqueness checks
        if obj_in.mobile and obj_in.mobile != db_obj.mobile:
            dup_mob = await self.teacher_repo.get_by_mobile(obj_in.mobile, tenant_id)
            if dup_mob:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Teacher with mobile number '{obj_in.mobile}' already exists."
                )

        if obj_in.official_email and obj_in.official_email != db_obj.official_email:
            dup_off_email = await self.teacher_repo.get_by_official_email(obj_in.official_email, tenant_id)
            if dup_off_email:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Teacher with official email '{obj_in.official_email}' already exists."
                )

        if obj_in.personal_email and obj_in.personal_email != db_obj.personal_email:
            dup_pers_email = await self.teacher_repo.get_by_personal_email(obj_in.personal_email, tenant_id)
            if dup_pers_email:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Teacher with personal email '{obj_in.personal_email}' already exists."
                )

        if obj_in.aadhaar_number and obj_in.aadhaar_number != db_obj.aadhaar_number:
            dup_aadhaar = await self.teacher_repo.get_by_aadhaar(obj_in.aadhaar_number, tenant_id)
            if dup_aadhaar:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Teacher with this Aadhaar number already exists."
                )

        if obj_in.pan_number and obj_in.pan_number != db_obj.pan_number:
            dup_pan = await self.teacher_repo.get_by_pan(obj_in.pan_number, tenant_id)
            if dup_pan:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Teacher with this PAN number already exists."
                )

        update_data = obj_in.model_dump(exclude_unset=True)
        if "status" in update_data:
            if update_data["status"] == TeacherStatus.INACTIVE or update_data["status"] == TeacherStatus.RETIRED:
                update_data["is_active"] = False
                if db_obj.user_id:
                    stmt = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
                    res = await self.teacher_repo.db.execute(stmt)
                    user = res.scalar_one_or_none()
                    if user:
                        user.status = UserStatus.INACTIVE
                        user.updated_by = updated_by
                        self.teacher_repo.db.add(user)
            else:
                update_data["is_active"] = True
                if db_obj.user_id:
                    stmt = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
                    res = await self.teacher_repo.db.execute(stmt)
                    user = res.scalar_one_or_none()
                    if user:
                        user.status = UserStatus.ACTIVE
                        user.updated_by = updated_by
                        self.teacher_repo.db.add(user)

        await self.teacher_repo.update(db_obj, update_data, updated_by=updated_by)
        await self.teacher_repo.db.commit()
        return await self.teacher_repo.get_by_id(teacher_id, school_id, tenant_id)

    async def delete_teacher(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        teacher_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Soft deletes the Teacher profile.
        """
        db_obj = await self.teacher_repo.get_by_id(teacher_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher not found."
            )

        await self.teacher_repo.soft_delete(db_obj, deleted_by=deleted_by)
        
        if db_obj.user_id:
            stmt = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
            res = await self.teacher_repo.db.execute(stmt)
            user = res.scalar_one_or_none()
            if user:
                user.deleted_at = datetime.now(timezone.utc)
                user.status = UserStatus.INACTIVE
                user.updated_by = deleted_by
                self.teacher_repo.db.add(user)

        await self.teacher_repo.db.commit()
        await self.teacher_repo.db.refresh(db_obj)
        return db_obj

    async def restore_teacher(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        teacher_id: uuid.UUID,
        restored_by: Optional[uuid.UUID] = None
    ) -> Teacher:
        """
        Restores a soft-deleted Teacher and their linked User identity.
        """
        stmt = select(Teacher).where(Teacher.id == teacher_id, Teacher.school_id == school_id, Teacher.tenant_id == tenant_id)
        res = await self.teacher_repo.db.execute(stmt)
        db_obj = res.scalar_one_or_none()
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher not found."
            )

        db_obj.deleted_at = None
        db_obj.status = TeacherStatus.ACTIVE
        db_obj.is_active = True
        db_obj.updated_by = restored_by
        self.teacher_repo.db.add(db_obj)

        if db_obj.user_id:
            stmt_u = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
            res_u = await self.teacher_repo.db.execute(stmt_u)
            user = res_u.scalar_one_or_none()
            if user:
                user.deleted_at = None
                user.status = UserStatus.ACTIVE
                user.updated_by = restored_by
                self.teacher_repo.db.add(user)

        await self.teacher_repo.db.commit()
        await self.teacher_repo.db.refresh(db_obj)
        return db_obj
