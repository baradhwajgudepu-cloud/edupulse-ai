import uuid
import logging
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy import select

from app.models.guardian import Guardian, StudentGuardian, GuardianStatus
from app.models.user import User, UserStatus
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.student import StudentRepository
from app.repositories.school import SchoolRepository
from app.schemas.guardian import GuardianCreate, GuardianUpdate, StudentGuardianCreate, StudentGuardianUpdate

logger = logging.getLogger(__name__)

class GuardianService:
    """
    Service Layer implementing business validations and updates for Guardians and mapping configurations.
    """
    def __init__(
        self,
        guardian_repo: GuardianRepository,
        student_guardian_repo: StudentGuardianRepository,
        student_repo: StudentRepository,
        school_repo: SchoolRepository
    ) -> None:
        self.guardian_repo = guardian_repo
        self.student_guardian_repo = student_guardian_repo
        self.student_repo = student_repo
        self.school_repo = school_repo

    # ==========================================
    # Guardian Management
    # ==========================================

    async def create_guardian(
        self,
        tenant_id: uuid.UUID,
        obj_in: GuardianCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Creates a new Guardian, validating date of birth and ensuring unique mobile, email, Aadhaar, and PAN.
        """
        current_date = date.today()

        # Date of birth boundary
        if obj_in.date_of_birth >= current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Date of birth must be in the past."
            )

        # Scoping verification
        school = await self.school_repo.get_by_id(obj_in.school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found under the active tenant."
            )

        # Idempotency and Self-Healing Pre-check
        existing_guardian = await self.guardian_repo.get_by_mobile(obj_in.mobile, tenant_id)
        if not existing_guardian and obj_in.email:
            existing_guardian = await self.guardian_repo.get_by_email(obj_in.email, tenant_id)

        if existing_guardian:
            # Verify security boundary and school mapping
            if (existing_guardian.tenant_id != tenant_id or 
                existing_guardian.school_id != obj_in.school_id):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Guardian profile already exists in another school or tenant context."
                )

            # Check if this is a duplicate conflict rather than an idempotent match
            if (
                (obj_in.email and existing_guardian.email and existing_guardian.email != obj_in.email) or
                (obj_in.aadhaar_number and existing_guardian.aadhaar_number and existing_guardian.aadhaar_number != obj_in.aadhaar_number) or
                (obj_in.pan_number and existing_guardian.pan_number and existing_guardian.pan_number != obj_in.pan_number)
            ):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Guardian with mobile '{obj_in.mobile}' already exists with different details."
                )

            from app.services.identity_provisioning import IdentityProvisioningService
            provision_service = IdentityProvisioningService(self.guardian_repo.db)
            user = await provision_service.provision_guardian(tenant_id, obj_in.school_id, existing_guardian.id, created_by)

            # Re-fetch with user loaded to prevent lazy load exceptions
            retrieved_guardian = await self.guardian_repo.get_by_id(existing_guardian.id, obj_in.school_id, tenant_id)

            from app.core.settings import settings
            if settings.DEBUG and hasattr(user, "temp_password") and user.temp_password and retrieved_guardian:
                from app.schemas.auth import ProvisioningCredentialResponse
                retrieved_guardian.credentials = ProvisioningCredentialResponse(
                    user_id=user.id,
                    email=user.email,
                    login_id=user.login_id,
                    temporary_password=user.temp_password,
                    role="PARENT"
                )
            return retrieved_guardian

        # Unique checks within the tenant boundary
        dup_mob = await self.guardian_repo.get_by_mobile(obj_in.mobile, tenant_id)
        if dup_mob:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Guardian with mobile number '{obj_in.mobile}' already exists."
            )

        if obj_in.email:
            dup_email = await self.guardian_repo.get_by_email(obj_in.email, tenant_id)
            if dup_email:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Guardian with email '{obj_in.email}' already exists."
                )

        if obj_in.aadhaar_number:
            dup_aadhaar = await self.guardian_repo.get_by_aadhaar(obj_in.aadhaar_number, tenant_id)
            if dup_aadhaar:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Guardian with this Aadhaar number already exists."
                )

        if obj_in.pan_number:
            dup_pan = await self.guardian_repo.get_by_pan(obj_in.pan_number, tenant_id)
            if dup_pan:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Guardian with this PAN number already exists."
                )

        db_obj = await self.guardian_repo.create(tenant_id, obj_in, created_by=created_by)
        db_obj.status = GuardianStatus.ACTIVE
        db_obj.is_active = True
        
        # Flush to DB to retrieve guardian ID before provisioning user
        await self.guardian_repo.db.flush()

        from app.services.identity_provisioning import IdentityProvisioningService
        provision_service = IdentityProvisioningService(self.guardian_repo.db)
        user = await provision_service.provision_guardian(tenant_id, obj_in.school_id, db_obj.id, created_by)

        from app.core.settings import settings
        credentials_data = None
        if settings.DEBUG and hasattr(user, "temp_password") and user.temp_password:
            from app.schemas.auth import ProvisioningCredentialResponse
            credentials_data = ProvisioningCredentialResponse(
                user_id=user.id,
                email=user.email,
                login_id=user.login_id,
                temporary_password=user.temp_password,
                role="PARENT"
            )

        await self.guardian_repo.db.commit()
        retrieved_guardian = await self.guardian_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)
        if retrieved_guardian and credentials_data:
            retrieved_guardian.credentials = credentials_data
        return retrieved_guardian

    async def update_guardian(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        guardian_id: uuid.UUID,
        obj_in: GuardianUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Updates an existing Guardian record.
        """
        db_obj = await self.guardian_repo.get_by_id(guardian_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guardian not found."
            )

        current_date = date.today()
        if obj_in.date_of_birth and obj_in.date_of_birth >= current_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Date of birth must be in the past."
            )

        # Unique checks
        if obj_in.mobile and obj_in.mobile != db_obj.mobile:
            dup_mob = await self.guardian_repo.get_by_mobile(obj_in.mobile, tenant_id)
            if dup_mob:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Guardian with mobile number '{obj_in.mobile}' already exists."
                )

        if obj_in.email and obj_in.email != db_obj.email:
            dup_email = await self.guardian_repo.get_by_email(obj_in.email, tenant_id)
            if dup_email:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Guardian with email '{obj_in.email}' already exists."
                )

        if obj_in.aadhaar_number and obj_in.aadhaar_number != db_obj.aadhaar_number:
            dup_aadhaar = await self.guardian_repo.get_by_aadhaar(obj_in.aadhaar_number, tenant_id)
            if dup_aadhaar:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Guardian with this Aadhaar number already exists."
                )

        if obj_in.pan_number and obj_in.pan_number != db_obj.pan_number:
            dup_pan = await self.guardian_repo.get_by_pan(obj_in.pan_number, tenant_id)
            if dup_pan:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Guardian with this PAN number already exists."
                )

        update_data = obj_in.model_dump(exclude_unset=True)
        if "status" in update_data:
            if update_data["status"] == GuardianStatus.INACTIVE:
                update_data["is_active"] = False
                if db_obj.user_id:
                    stmt = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
                    res = await self.guardian_repo.db.execute(stmt)
                    user = res.scalar_one_or_none()
                    if user:
                        user.status = UserStatus.INACTIVE
                        user.updated_by = updated_by
                        self.guardian_repo.db.add(user)
            else:
                update_data["is_active"] = True
                if db_obj.user_id:
                    stmt = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
                    res = await self.guardian_repo.db.execute(stmt)
                    user = res.scalar_one_or_none()
                    if user:
                        user.status = UserStatus.ACTIVE
                        user.updated_by = updated_by
                        self.guardian_repo.db.add(user)

        await self.guardian_repo.update(db_obj, update_data, updated_by=updated_by)
        await self.guardian_repo.db.commit()
        return await self.guardian_repo.get_by_id(guardian_id, school_id, tenant_id)

    async def delete_guardian(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        guardian_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Soft deletes the Guardian profile.
        """
        db_obj = await self.guardian_repo.get_by_id(guardian_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guardian not found."
            )

        await self.guardian_repo.soft_delete(db_obj, deleted_by=deleted_by)
        
        if db_obj.user_id:
            stmt = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
            res = await self.guardian_repo.db.execute(stmt)
            user = res.scalar_one_or_none()
            if user:
                user.deleted_at = datetime.now(timezone.utc)
                user.status = UserStatus.INACTIVE
                user.updated_by = deleted_by
                self.guardian_repo.db.add(user)

        await self.guardian_repo.db.commit()
        await self.guardian_repo.db.refresh(db_obj)
        return db_obj

    async def restore_guardian(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        guardian_id: uuid.UUID,
        restored_by: Optional[uuid.UUID] = None
    ) -> Guardian:
        """
        Restores a soft-deleted Guardian and their linked User identity.
        """
        stmt = select(Guardian).where(Guardian.id == guardian_id, Guardian.school_id == school_id, Guardian.tenant_id == tenant_id)
        res = await self.guardian_repo.db.execute(stmt)
        db_obj = res.scalar_one_or_none()
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guardian not found."
            )

        db_obj.deleted_at = None
        db_obj.status = GuardianStatus.ACTIVE
        db_obj.is_active = True
        db_obj.updated_by = restored_by
        self.guardian_repo.db.add(db_obj)

        if db_obj.user_id:
            stmt_u = select(User).where(User.id == db_obj.user_id, User.tenant_id == tenant_id)
            res_u = await self.guardian_repo.db.execute(stmt_u)
            user = res_u.scalar_one_or_none()
            if user:
                user.deleted_at = None
                user.status = UserStatus.ACTIVE
                user.updated_by = restored_by
                self.guardian_repo.db.add(user)

        await self.guardian_repo.db.commit()
        await self.guardian_repo.db.refresh(db_obj)
        return db_obj

    # ==========================================
    # Student Guardian Mapping Management
    # ==========================================

    async def assign_student_guardian(
        self,
        tenant_id: uuid.UUID,
        obj_in: StudentGuardianCreate
    ) -> StudentGuardian:
        """
        Assigns a Guardian to a Student, enforcing boundary match, duplicate checks, and primary limit rules.
        """
        # 1. Verify student exists under same tenant and school
        student = await self.student_repo.get_by_id(obj_in.student_id, obj_in.school_id, tenant_id)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student not found under this school/tenant context."
            )

        # 2. Verify guardian exists under same tenant and school
        guardian = await self.guardian_repo.get_by_id(obj_in.guardian_id, obj_in.school_id, tenant_id)
        if not guardian:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Guardian not found under this school/tenant context."
            )

        # 3. Check duplicate assignments
        existing = await self.student_guardian_repo.get_mapping(obj_in.student_id, obj_in.guardian_id, tenant_id)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This student is already mapped to this guardian."
            )

        # 4. Check primary guardian limit
        if obj_in.is_primary:
            primary_mapping = await self.student_guardian_repo.get_primary_mapping(obj_in.student_id, tenant_id)
            if primary_mapping:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A primary guardian has already been assigned to this student."
                )

        db_obj = await self.student_guardian_repo.create(tenant_id, obj_in)
        await self.student_guardian_repo.db.commit()
        return await self.student_guardian_repo.get_by_id(db_obj.id, obj_in.school_id, tenant_id)

    async def update_student_guardian(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        mapping_id: uuid.UUID,
        obj_in: StudentGuardianUpdate
    ) -> StudentGuardian:
        """
        Updates mapping configuration.
        """
        db_obj = await self.student_guardian_repo.get_by_id(mapping_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student-guardian mapping record not found."
            )

        if obj_in.is_primary is True and not db_obj.is_primary:
            # Verify no other active primary mapping exists for the student
            primary_mapping = await self.student_guardian_repo.get_primary_mapping(db_obj.student_id, tenant_id)
            if primary_mapping and primary_mapping.id != db_obj.id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="A primary guardian has already been assigned to this student."
                )

        await self.student_guardian_repo.update(db_obj, obj_in)
        await self.student_guardian_repo.db.commit()
        return await self.student_guardian_repo.get_by_id(mapping_id, school_id, tenant_id)

    async def remove_student_guardian(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        mapping_id: uuid.UUID
    ) -> StudentGuardian:
        """
        Soft deletes mapping configuration.
        """
        db_obj = await self.student_guardian_repo.get_by_id(mapping_id, school_id, tenant_id)
        if not db_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Student-guardian mapping record not found."
            )

        await self.student_guardian_repo.soft_delete(db_obj)
        await self.student_guardian_repo.db.commit()
        await self.student_guardian_repo.db.refresh(db_obj)
        return db_obj
