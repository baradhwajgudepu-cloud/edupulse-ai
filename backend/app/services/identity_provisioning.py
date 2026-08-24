import uuid
import logging
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone
from sqlalchemy import select, and_, or_, func, text
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.models.user import User, UserStatus
from app.models.role import Role, user_roles
from app.models.teacher import Teacher
from app.models.guardian import Guardian
from app.models.school import School
from app.models.parent_login_sequence import ParentLoginSequence
from app.core.security import hash_password, generate_secure_temp_password
from app.core.settings import settings
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

    async def _get_role(self, tenant_id: uuid.UUID, role_code: str, role_name: str) -> Role:
        """
        Helper method to fetch or create a role within a tenant.
        """
        stmt_r = select(Role).where(
            Role.tenant_id == tenant_id,
            or_(func.upper(Role.code) == role_code.upper(), func.upper(Role.name) == role_name.upper()),
            Role.deleted_at.is_(None)
        )
        res_r = await self.db.execute(stmt_r)
        role = res_r.scalar_one_or_none()
        if not role:
            role = Role(
                tenant_id=tenant_id,
                name=role_name,
                code=role_code,
                is_system=True,
                version=1
            )
            self.db.add(role)
            await self.db.flush()
        return role

    async def _generate_parent_login_id(self, tenant_id: uuid.UUID, school_id: uuid.UUID, school_code: str) -> str:
        """
        Generates a unique sequential Parent Login ID using a tenant-school-scoped sequence counter with row locking.
        """
        prefix = school_code.upper().strip()
        
        stmt_seq = select(ParentLoginSequence).where(
            ParentLoginSequence.tenant_id == tenant_id,
            ParentLoginSequence.school_id == school_id
        ).with_for_update()
        
        res_seq = await self.db.execute(stmt_seq)
        seq_obj = res_seq.scalar_one_or_none()
        
        if not seq_obj:
            try:
                async with self.db.begin_nested():
                    seq_obj = ParentLoginSequence(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        prefix=prefix,
                        next_sequence=1
                    )
                    self.db.add(seq_obj)
                    await self.db.flush()
            except Exception:
                # Re-query if concurrent insert happened
                res_seq = await self.db.execute(stmt_seq)
                seq_obj = res_seq.scalar_one()

        current_seq = seq_obj.next_sequence
        seq_obj.next_sequence += 1
        self.db.add(seq_obj)
        await self.db.flush()
        
        return f"{prefix}P{current_seq:06d}"

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

        # Email checking
        if not teacher.official_email or not teacher.official_email.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Official email is required for identity provisioning."
            )

        # Retrieve school and role
        stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
        res_sc = await self.db.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()
        if not school:
            raise HTTPException(status_code=404, detail="School not found.")

        role = await self._get_role(tenant_id, "TEACHER", "Teacher")

        # Check if already provisioned
        if teacher.user_id:
            stmt_u = select(User).where(User.id == teacher.user_id, User.tenant_id == tenant_id).options(
                selectinload(User.roles).selectinload(Role.permissions), selectinload(User.schools)
            )
            res_u = await self.db.execute(stmt_u)
            existing_user = res_u.scalar_one_or_none()
            if existing_user:
                # Self-heal missing role or school
                needs_update = False
                if role not in existing_user.roles:
                    existing_user.roles.append(role)
                    needs_update = True
                if school not in existing_user.schools:
                    existing_user.schools.append(school)
                    needs_update = True
                if needs_update:
                    self.db.add(existing_user)
                    await self.db.flush()
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
            
            # Self-heal role/school mappings
            needs_update = False
            if role not in dup_user.roles:
                dup_user.roles.append(role)
                needs_update = True
            if school not in dup_user.schools:
                dup_user.schools.append(school)
                needs_update = True
            if needs_update:
                self.db.add(dup_user)
                await self.db.flush()

            teacher.user_id = dup_user.id
            self.db.add(teacher)
            await self.db.commit()
            return await self._get_loaded_user(dup_user.id)

        # Generate password
        if settings.DEBUG:
            temp_pwd = "EduPulse@123"
        else:
            temp_pwd = generate_secure_temp_password()

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

        new_user.schools.append(school)
        new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        # Link teacher
        teacher.user_id = new_user.id
        self.db.add(teacher)
        
        await self.db.commit()

        # Set transient password attribute for UAT responses
        user_loaded = await self._get_loaded_user(new_user.id)
        user_loaded.temp_password = temp_pwd
        return user_loaded

    async def provision_guardian(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, guardian_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> User:
        """
        Creates an authenticated User account for a Guardian profile if not already provisioned.
        Generates and assigns a sequence-based Parent Login ID.
        """
        # Load guardian
        stmt_g = select(Guardian).where(Guardian.id == guardian_id, Guardian.tenant_id == tenant_id)
        res_g = await self.db.execute(stmt_g)
        guardian = res_g.scalar_one_or_none()
        if not guardian:
            raise HTTPException(status_code=404, detail="Guardian profile not found.")

        # Load school
        stmt_sc = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
        res_sc = await self.db.execute(stmt_sc)
        school = res_sc.scalar_one_or_none()
        if not school:
            raise HTTPException(status_code=404, detail="School not found.")

        if not school.code or not school.code.strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"School code is missing for school '{school.name}'. Cannot generate Parent Login ID."
            )

        role = await self._get_role(tenant_id, "PARENT", "Parent")

        # Check if already provisioned
        if guardian.user_id:
            stmt_u = select(User).where(User.id == guardian.user_id, User.tenant_id == tenant_id).options(
                selectinload(User.roles).selectinload(Role.permissions), selectinload(User.schools)
            )
            res_u = await self.db.execute(stmt_u)
            existing_user = res_u.scalar_one_or_none()
            if existing_user:
                # Validate tenant isolation
                if existing_user.tenant_id != tenant_id:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Guardian user belongs to a different tenant context."
                    )
                # Self-heal missing fields
                needs_update = False
                if not existing_user.login_id:
                    existing_user.login_id = await self._generate_parent_login_id(tenant_id, school_id, school.code)
                    needs_update = True
                if role not in existing_user.roles:
                    existing_user.roles.append(role)
                    needs_update = True
                if school not in existing_user.schools:
                    existing_user.schools.append(school)
                    needs_update = True
                if needs_update:
                    self.db.add(existing_user)
                    await self.db.flush()
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
            
            # Self-heal role/school mappings and login ID
            needs_update = False
            if not dup_user.login_id:
                dup_user.login_id = await self._generate_parent_login_id(tenant_id, school_id, school.code)
                needs_update = True
            if role not in dup_user.roles:
                dup_user.roles.append(role)
                needs_update = True
            if school not in dup_user.schools:
                dup_user.schools.append(school)
                needs_update = True
            if needs_update:
                self.db.add(dup_user)
                await self.db.flush()

            guardian.user_id = dup_user.id
            self.db.add(guardian)
            await self.db.commit()
            return await self._get_loaded_user(dup_user.id)

        # Generate Login ID
        login_id = await self._generate_parent_login_id(tenant_id, school_id, school.code)

        # Generate password
        if settings.DEBUG:
            temp_pwd = "EduPulse@123"
        else:
            temp_pwd = generate_secure_temp_password()

        hashed = hash_password(temp_pwd)
        new_user = User(
            email=email,
            login_id=login_id,
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

        new_user.schools.append(school)
        new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        # Link guardian
        guardian.user_id = new_user.id
        self.db.add(guardian)
        
        await self.db.commit()

        # Set transient password attribute for UAT responses
        user_loaded = await self._get_loaded_user(new_user.id)
        user_loaded.temp_password = temp_pwd
        return user_loaded

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

        role = await self._get_role(tenant_id, "PRINCIPAL", "Principal")

        if settings.DEBUG:
            temp_pwd = "EduPulse@123"
        else:
            temp_pwd = generate_secure_temp_password()

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
        new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        await self.db.commit()

        user_loaded = await self._get_loaded_user(new_user.id)
        user_loaded.temp_password = temp_pwd
        return user_loaded

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

        role = await self._get_role(tenant_id, "STAFF", "Staff")

        if settings.DEBUG:
            temp_pwd = "EduPulse@123"
        else:
            temp_pwd = generate_secure_temp_password()

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
        new_user.roles.append(role)

        self.db.add(new_user)
        await self.db.flush()

        await self.db.commit()

        user_loaded = await self._get_loaded_user(new_user.id)
        user_loaded.temp_password = temp_pwd
        return user_loaded

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
        
        if settings.DEBUG:
            temp_pwd = "EduPulse@123"
        else:
            temp_pwd = generate_secure_temp_password()

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
