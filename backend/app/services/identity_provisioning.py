import uuid
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.models.user import User, UserStatus
from app.models.role import Role, user_roles
from app.models.teacher import Teacher
from app.models.guardian import Guardian
from app.models.school import School
from app.core.security import hash_password
from app.schemas.identity import IdentityProvisionStatusResponse

logger = logging.getLogger(__name__)

class IdentityProvisioningService:
    """
    Service Layer responsible for User Provisioning, Lifecycle, and Identity Linkage.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def _get_loaded_user(self, user_id: uuid.UUID) -> User:
        """
        Helper method to fetch a user with all relationships eagerly loaded.
        """
        stmt = select(User).where(User.id == user_id).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        res = await self.db.execute(stmt)
        return res.scalar_one()

    async def provision_teacher(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, teacher_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> User:
        """
        Creates an authenticated User account for a Teacher profile if not already provisioned.
        """
        # Load teacher
        stmt_t = select(Teacher).where(Teacher.id == teacher_id, Teacher.tenant_id == tenant_id)
        res_t = await self.db.execute(stmt_t)
        teacher = res_t.scalar_one_or_none()
        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher profile not found.")

        # Check if already provisioned
        if teacher.user_id:
            stmt_u = select(User).where(User.id == teacher.user_id, User.tenant_id == tenant_id).options(
                selectinload(User.roles).selectinload(Role.permissions), selectinload(User.schools)
            )
            res_u = await self.db.execute(stmt_u)
            existing_user = res_u.scalar_one_or_none()
            if existing_user:
                return existing_user

        # Email uniqueness check
        stmt_dup = select(User).where(
            User.tenant_id == tenant_id,
            func.lower(User.email) == teacher.official_email.lower(),
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        res_dup = await self.db.execute(stmt_dup)
        dup_user = res_dup.scalar_one_or_none()

        if dup_user:
            stmt_link_check = select(Teacher).where(Teacher.user_id == dup_user.id, Teacher.id != teacher.id)
            res_link_check = await self.db.execute(stmt_link_check)
            linked_other = res_link_check.scalar_one_or_none()
            if linked_other:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Email '{teacher.official_email}' is already associated with another user/teacher identity."
                )
            
            teacher.user_id = dup_user.id
            self.db.add(teacher)
            await self.db.commit()
            return await self._get_loaded_user(dup_user.id)

        # Retrieve school and role before creating user to avoid lazy load MissingGreenlet
        stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
        res_sc = await self.db.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()

        stmt_r = select(Role).where(
            Role.tenant_id == tenant_id,
            or_(func.upper(Role.code) == "TEACHER", func.upper(Role.name) == "TEACHER"),
            Role.deleted_at.is_(None)
        )
        res_r = await self.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()
        if not role:
            role = Role(
                tenant_id=tenant_id,
                name="Teacher",
                code="TEACHER",
                is_system=True,
                version=1
            )
            self.db.add(role)
            await self.db.flush()

        # Create transient new user
        temp_pwd = "EduPulse@123"
        hashed = hash_password(temp_pwd)
        new_user = User(
            email=teacher.official_email,
            hashed_password=hashed,
            first_name=teacher.first_name,
            last_name=teacher.last_name,
            status=UserStatus.ACTIVE,
            is_superuser=False,
            must_change_password=True,
            tenant_id=tenant_id,
            version=1,
            created_by=current_user_id
        )

        if school:
            new_user.schools.append(school)
        if role:
            new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        # Link teacher
        teacher.user_id = new_user.id
        self.db.add(teacher)
        
        await self.db.commit()
        return await self._get_loaded_user(new_user.id)

    async def provision_guardian(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, guardian_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> User:
        """
        Creates an authenticated User account for a Guardian profile if not already provisioned.
        """
        # Load guardian
        stmt_g = select(Guardian).where(Guardian.id == guardian_id, Guardian.tenant_id == tenant_id)
        res_g = await self.db.execute(stmt_g)
        guardian = res_g.scalar_one_or_none()
        if not guardian:
            raise HTTPException(status_code=404, detail="Guardian profile not found.")

        # Check if already provisioned
        if guardian.user_id:
            stmt_u = select(User).where(User.id == guardian.user_id, User.tenant_id == tenant_id).options(
                selectinload(User.roles).selectinload(Role.permissions), selectinload(User.schools)
            )
            res_u = await self.db.execute(stmt_u)
            existing_user = res_u.scalar_one_or_none()
            if existing_user:
                return existing_user

        # Resolve email
        email = guardian.email
        if not email:
            if guardian.mobile:
                email = f"guardian.{guardian.mobile}@edupulse.local"
            else:
                email = f"guardian.{guardian.id.hex[:8]}@edupulse.local"

        # Email uniqueness check
        stmt_dup = select(User).where(
            User.tenant_id == tenant_id,
            func.lower(User.email) == email.lower(),
            User.deleted_at.is_(None)
        ).options(
            selectinload(User.roles).selectinload(Role.permissions),
            selectinload(User.schools)
        )
        res_dup = await self.db.execute(stmt_dup)
        dup_user = res_dup.scalar_one_or_none()

        if dup_user:
            stmt_link_check = select(Guardian).where(Guardian.user_id == dup_user.id, Guardian.id != guardian.id)
            res_link_check = await self.db.execute(stmt_link_check)
            linked_other = res_link_check.scalar_one_or_none()
            if linked_other:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Email/Mobile is already associated with another parent identity."
                )
            
            guardian.user_id = dup_user.id
            self.db.add(guardian)
            await self.db.commit()
            return await self._get_loaded_user(dup_user.id)

        # Retrieve school and role before creating user to avoid lazy load MissingGreenlet
        stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
        res_sc = await self.db.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()

        stmt_r = select(Role).where(
            Role.tenant_id == tenant_id,
            or_(func.upper(Role.code) == "PARENT", func.upper(Role.name) == "PARENT"),
            Role.deleted_at.is_(None)
        )
        res_r = await self.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()
        if not role:
            role = Role(
                tenant_id=tenant_id,
                name="Parent",
                code="PARENT",
                is_system=True,
                version=1
            )
            self.db.add(role)
            await self.db.flush()

        # Create transient new user
        temp_pwd = "EduPulse@123"
        hashed = hash_password(temp_pwd)
        new_user = User(
            email=email,
            hashed_password=hashed,
            first_name=guardian.first_name,
            last_name=guardian.last_name,
            status=UserStatus.ACTIVE,
            is_superuser=False,
            must_change_password=True,
            tenant_id=tenant_id,
            version=1,
            created_by=current_user_id
        )

        if school:
            new_user.schools.append(school)
        if role:
            new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        # Link guardian
        guardian.user_id = new_user.id
        self.db.add(guardian)
        
        await self.db.commit()
        return await self._get_loaded_user(new_user.id)

    async def provision_principal(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, principal_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> User:
        """
        Creates an authenticated User account with the PRINCIPAL role.
        """
        email = f"principal.{principal_id.hex[:6]}@edupulse.local"

        stmt_dup = select(User).where(
            User.tenant_id == tenant_id,
            func.lower(User.email) == email.lower(),
            User.deleted_at.is_(None)
        ).options(selectinload(User.roles).selectinload(Role.permissions), selectinload(User.schools))
        res_dup = await self.db.execute(stmt_dup)
        dup_user = res_dup.scalar_one_or_none()

        if dup_user:
            return await self._get_loaded_user(dup_user.id)

        stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
        res_sc = await self.db.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()

        stmt_r = select(Role).where(
            Role.tenant_id == tenant_id,
            or_(func.upper(Role.code) == "PRINCIPAL", func.upper(Role.name) == "PRINCIPAL"),
            Role.deleted_at.is_(None)
        )
        res_r = await self.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()
        if not role:
            role = Role(
                tenant_id=tenant_id,
                name="Principal",
                code="PRINCIPAL",
                is_system=True,
                version=1
            )
            self.db.add(role)
            await self.db.flush()

        temp_pwd = "EduPulse@123"
        hashed = hash_password(temp_pwd)
        new_user = User(
            email=email,
            hashed_password=hashed,
            first_name="Principal",
            last_name="User",
            status=UserStatus.ACTIVE,
            is_superuser=False,
            must_change_password=True,
            tenant_id=tenant_id,
            version=1,
            created_by=current_user_id
        )

        if school:
            new_user.schools.append(school)
        if role:
            new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        await self.db.commit()
        return await self._get_loaded_user(new_user.id)

    async def provision_staff(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, staff_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> User:
        """
        Creates an authenticated User account with the STAFF role.
        """
        email = f"staff.{staff_id.hex[:6]}@edupulse.local"

        stmt_dup = select(User).where(
            User.tenant_id == tenant_id,
            func.lower(User.email) == email.lower(),
            User.deleted_at.is_(None)
        ).options(selectinload(User.roles).selectinload(Role.permissions), selectinload(User.schools))
        res_dup = await self.db.execute(stmt_dup)
        dup_user = res_dup.scalar_one_or_none()

        if dup_user:
            return await self._get_loaded_user(dup_user.id)

        stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
        res_sc = await self.db.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()

        stmt_r = select(Role).where(
            Role.tenant_id == tenant_id,
            or_(func.upper(Role.code) == "STAFF", func.upper(Role.name) == "STAFF"),
            Role.deleted_at.is_(None)
        )
        res_r = await self.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()
        if not role:
            role = Role(
                tenant_id=tenant_id,
                name="Staff",
                code="STAFF",
                is_system=True,
                version=1
            )
            self.db.add(role)
            await self.db.flush()

        temp_pwd = "EduPulse@123"
        hashed = hash_password(temp_pwd)
        new_user = User(
            email=email,
            hashed_password=hashed,
            first_name="Staff",
            last_name="User",
            status=UserStatus.ACTIVE,
            is_superuser=False,
            must_change_password=True,
            tenant_id=tenant_id,
            version=1,
            created_by=current_user_id
        )

        if school:
            new_user.schools.append(school)
        if role:
            new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        await self.db.commit()
        return await self._get_loaded_user(new_user.id)

    async def activate_user(self, tenant_id: uuid.UUID, user_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None) -> User:
        stmt = select(User).where(User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None))
        res = await self.db.execute(stmt)
        user = res.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=404, detail="User not found.")
        user.status = UserStatus.ACTIVE
        user.updated_by = current_user_id
        await self.db.commit()
        return await self._get_loaded_user(user.id)

    async def deactivate_user(self, tenant_id: uuid.UUID, user_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None) -> User:
        stmt = select(User).where(User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None))
        res = await self.db.execute(stmt)
        user = res.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=404, detail="User not found.")
        user.status = UserStatus.INACTIVE
        user.updated_by = current_user_id
        await self.db.commit()
        return await self._get_loaded_user(user.id)

    async def reset_password(self, tenant_id: uuid.UUID, user_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None) -> str:
        stmt = select(User).where(User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None))
        res = await self.db.execute(stmt)
        user = res.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=404, detail="User not found.")
        
        temp_pwd = "EduPulse@123"
        user.hashed_password = hash_password(temp_pwd)
        user.must_change_password = True
        user.failed_login_attempts = 0
        if user.status == UserStatus.LOCKED:
            user.status = UserStatus.ACTIVE
            user.locked_until = None
        user.updated_by = current_user_id
        await self.db.commit()
        return temp_pwd

    async def unlock_user(self, tenant_id: uuid.UUID, user_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None) -> User:
        stmt = select(User).where(User.id == user_id, User.tenant_id == tenant_id, User.deleted_at.is_(None))
        res = await self.db.execute(stmt)
        user = res.scalar_one_or_none()
        if not user:
            raise HTTPException(status_code=404, detail="User not found.")
        user.status = UserStatus.ACTIVE
        user.failed_login_attempts = 0
        user.locked_until = None
        user.updated_by = current_user_id
        await self.db.commit()
        return await self._get_loaded_user(user.id)

    async def get_provision_status(
        self, tenant_id: uuid.UUID, entity_id: uuid.UUID
    ) -> IdentityProvisionStatusResponse:
        # Check Teacher
        stmt_t = select(Teacher).where(Teacher.id == entity_id, Teacher.tenant_id == tenant_id)
        res_t = await self.db.execute(stmt_t)
        teacher = res_t.scalar_one_or_none()
        if teacher:
            return IdentityProvisionStatusResponse(
                is_provisioned=teacher.user_id is not None,
                user_id=teacher.user_id,
                email=teacher.official_email
            )

        # Check Guardian
        stmt_g = select(Guardian).where(Guardian.id == entity_id, Guardian.tenant_id == tenant_id)
        res_g = await self.db.execute(stmt_g)
        guardian = res_g.scalar_one_or_none()
        if guardian:
            return IdentityProvisionStatusResponse(
                is_provisioned=guardian.user_id is not None,
                user_id=guardian.user_id,
                email=guardian.email or f"guardian.{guardian.mobile}@edupulse.local"
            )

        raise HTTPException(status_code=404, detail="Entity profile not found.")
