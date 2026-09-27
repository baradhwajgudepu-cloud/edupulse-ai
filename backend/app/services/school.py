import base64
import io
import re
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Any, Dict
from fastapi import HTTPException, status
from sqlalchemy import select, func

from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.tenant import Tenant, TenantStatus
from app.models.user import User, UserStatus
from app.repositories.school import SchoolRepository
from app.schemas.school import (
    SchoolCreate, SchoolUpdate,
    QuickSchoolOnboardingRequest, QuickSchoolOnboardingResponse,
    SchoolSetupProgressResponse, SetupStepItem
)

class SchoolService:
    """
    Service Layer containing business validations for Schools.
    Validates composite uniqueness (code, email) within the scope of a tenant,
    and global uniqueness for registry identifiers (UDISE).
    """
    def __init__(self, repo: SchoolRepository) -> None:
        self.repo = repo

    async def get_school(self, school_id: uuid.UUID, tenant_id: uuid.UUID) -> School:
        """
        Retrieves a single school by UUID within tenant scope, or raises a 404 error if not found.
        """
        school = await self.repo.get_by_id(school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found under the active tenant scope."
            )
        return school

    async def list_schools(
        self,
        tenant_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100,
        status_filter: Optional[SchoolStatus] = None,
        board: Optional[SchoolBoard] = None,
        is_active: Optional[bool] = None
    ) -> List[School]:
        """
        Lists active schools scoped by tenant.
        """
        return await self.repo.get_multi(
            tenant_id=tenant_id,
            skip=skip,
            limit=limit,
            status=status_filter,
            board=board,
            is_active=is_active
        )

    async def create_school(
        self,
        tenant_id: uuid.UUID,
        obj_in: SchoolCreate,
        created_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Registers a new school campus under tenant_id, checking unique constraints.
        """
        if not obj_in.code or not obj_in.code.strip():
            obj_in.code = await self.generate_unique_school_code(obj_in.name)

        if obj_in.board is None:
            obj_in.board = SchoolBoard.OTHER
        if obj_in.school_type is None:
            obj_in.school_type = SchoolType.OTHER

        # Validate composite (tenant_id, code) uniqueness
        if await self.repo.get_by_code(tenant_id, obj_in.code):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"School code '{obj_in.code}' is already registered under this tenant."
            )

        # Validate composite (tenant_id, email) uniqueness
        if await self.repo.get_by_email(tenant_id, obj_in.email):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"School contact email '{obj_in.email}' is already registered under this tenant."
            )

        # Validate global UDISE uniqueness if provided
        if obj_in.udise_code:
            if await self.repo.get_by_udise(obj_in.udise_code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School UDISE code '{obj_in.udise_code}' is already registered globally."
                )

        return await self.repo.create(tenant_id, obj_in, created_by=created_by)

    async def update_school(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        obj_in: SchoolUpdate,
        updated_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Modifies properties of an existing School, verifying unique constraint changes.
        """
        school = await self.get_school(school_id, tenant_id)

        # Validate code uniqueness if changing
        if obj_in.code is not None and obj_in.code != school.code:
            if await self.repo.get_by_code(tenant_id, obj_in.code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School code '{obj_in.code}' is already registered under this tenant."
                )

        # Validate email uniqueness if changing
        if obj_in.email is not None and obj_in.email != school.email:
            if await self.repo.get_by_email(tenant_id, obj_in.email):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School contact email '{obj_in.email}' is already registered under this tenant."
                )

        # Validate UDISE uniqueness if changing
        if obj_in.udise_code is not None and obj_in.udise_code != school.udise_code:
            if await self.repo.get_by_udise(obj_in.udise_code):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"School UDISE code '{obj_in.udise_code}' is already registered globally."
                )

        updated_school = await self.repo.update(school, obj_in, updated_by=updated_by)
        if "latitude" in obj_in.model_fields_set or "longitude" in obj_in.model_fields_set or "geofence_radius_meters" in obj_in.model_fields_set:
            settings_copy = dict(updated_school.settings or {})
            gf = dict(settings_copy.get("geofence", {}))
            gf["latitude"] = updated_school.latitude
            gf["longitude"] = updated_school.longitude
            gf["radius_meters"] = updated_school.geofence_radius_meters
            if "enabled" not in gf:
                gf["enabled"] = bool(updated_school.latitude is not None and updated_school.longitude is not None)
            gf["updated_at"] = datetime.now(timezone.utc).isoformat()
            if updated_by:
                gf["updated_by"] = str(updated_by)
            settings_copy["geofence"] = gf
            updated_school.settings = settings_copy
            await self.repo.db.commit()
            await self.repo.db.refresh(updated_school)
        return updated_school

    async def delete_school(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        deleted_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Soft-deletes the selected school.
        """
        school = await self.get_school(school_id, tenant_id)
        return await self.repo.soft_delete(school, deleted_by=deleted_by)

    async def update_logo(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        logo_url: Optional[str],
        logo_storage_key: Optional[str] = None
    ) -> School:
        """
        Updates the logo_url and internal logo_storage_key for a school within tenant scope.
        """
        school = await self.get_school(school_id, tenant_id)
        school.logo_url = logo_url
        settings_copy = dict(school.settings or {})
        branding = dict(settings_copy.get("branding", {}))
        if logo_storage_key:
            branding["logo_storage_key"] = logo_storage_key
            branding["logo_updated_at"] = datetime.now(timezone.utc).isoformat()
        else:
            branding.pop("logo_storage_key", None)
            branding.pop("logo_updated_at", None)
        settings_copy["branding"] = branding
        school.settings = settings_copy
        await self.repo.db.commit()
        await self.repo.db.refresh(school)
        return school

    async def update_geofence(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        enabled: bool,
        latitude: Optional[float],
        longitude: Optional[float],
        radius_meters: int,
        updated_by: Optional[uuid.UUID] = None
    ) -> School:
        """
        Updates the geofence configuration (coords, radius, and enabled status in settings) for a school.
        """
        school = await self.get_school(school_id, tenant_id)
        school.latitude = latitude
        school.longitude = longitude
        school.geofence_radius_meters = radius_meters

        settings_copy = dict(school.settings or {})
        now_iso = datetime.now(timezone.utc).isoformat()
        settings_copy["geofence"] = {
            "enabled": enabled,
            "latitude": latitude,
            "longitude": longitude,
            "radius_meters": radius_meters,
            "updated_at": now_iso,
            "updated_by": str(updated_by) if updated_by else None
        }
        school.settings = settings_copy
        school.updated_by = updated_by
        await self.repo.db.commit()
        await self.repo.db.refresh(school)
        return school

    async def generate_unique_school_code(self, school_name: str) -> str:
        """
        Generates a globally unique, collision-safe school code across the entire database.
        Extracts uppercase initials or prefix (e.g. Telangana Model School -> TS001,
        Delhi Public School -> DPS001, fallback -> SCH000001).
        Ensures global uniqueness against the entire School table.
        """
        words = re.findall(r'[a-zA-Z0-9]+', school_name)
        if len(words) >= 2:
            prefix = "".join(w[0].upper() for w in words[:3])
        elif len(words) == 1 and len(words[0]) >= 2:
            prefix = words[0][:3].upper()
        else:
            prefix = "SCH"

        # Check existing codes globally across the entire School table
        stmt = select(School.code).where(School.code.like(f"{prefix}%"))
        res = await self.repo.db.execute(stmt)
        existing_codes = set(res.scalars().all())

        pad_len = 6 if prefix == "SCH" else 3
        for i in range(1, 100000):
            candidate = f"{prefix}{i:0{pad_len}d}"
            if candidate not in existing_codes:
                return candidate

        return f"SCH{uuid.uuid4().hex[:6].upper()}"

    async def _is_tenant_email_taken(self, email: str) -> bool:
        stmt = select(Tenant.id).where(func.lower(Tenant.email) == email.lower())
        res = await self.repo.db.execute(stmt)
        return res.scalar_one_or_none() is not None

    async def onboard_school_quick(
        self,
        data: QuickSchoolOnboardingRequest,
        storage_service: Optional[Any] = None
    ) -> QuickSchoolOnboardingResponse:
        """
        Executes atomic quick onboarding for a new School and Tenant:
        1. Derives unique tenant code & subdomain from school name.
        2. Resolves board and school_type without hardcoded CBSE/HIGH_SCHOOL defaults.
        3. Creates Tenant.
        4. Seeds Tenant RBAC roles (ensure_tenant_rbac).
        5. Uploads and links logo if provided.
        6. Creates School with globally unique school code.
        7. Provisions Principal user with Argon2id password hash, role PRINCIPAL, and campus association.
        8. Generates authoritative JWT access token matching tenant boundary.
        9. Commits atomically. If any error occurs, rolls back cleanly.
        """
        school_name = data.school_name.strip()
        principal_name = data.principal_name.strip()
        principal_email = data.principal_email.strip().lower()
        principal_password = data.principal_password.strip()

        # Check global email uniqueness across active users
        stmt_user_chk = select(User.id).where(
            func.lower(User.email) == principal_email,
            User.deleted_at.is_(None)
        )
        res_u = await self.repo.db.execute(stmt_user_chk)
        if res_u.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Email '{principal_email}' is already registered in EduPulse. Please use another email or log in."
            )

        # Generate unique tenant slug and code
        clean_slug = re.sub(r'[^a-zA-Z0-9]', '', school_name)[:10].lower()
        if not clean_slug:
            clean_slug = "school"
        rand_suffix = uuid.uuid4().hex[:6].lower()
        tenant_code = f"TNT_{clean_slug.upper()}_{rand_suffix.upper()}"
        subdomain = f"{clean_slug}{rand_suffix}"

        # Tenant email must be globally unique
        if await self._is_tenant_email_taken(principal_email):
            tenant_email = f"{subdomain}@tenants.edupulse.local"
        else:
            tenant_email = principal_email

        # Determine School Code (Globally unique, collision-safe)
        if data.school_code and data.school_code.strip():
            school_code = data.school_code.strip().upper()
        else:
            school_code = await self.generate_unique_school_code(school_name)

        # Resolve board (Do NOT default to CBSE; if omitted, keep unconfigured)
        board_configured = bool(data.board and data.board.strip())
        if board_configured:
            board_raw = data.board.strip().upper()
            if board_raw in SchoolBoard.__members__:
                board_enum = SchoolBoard[board_raw]
            else:
                board_enum = SchoolBoard.OTHER
            board_display = data.board.strip()
        else:
            board_enum = SchoolBoard.OTHER
            board_display = "Not Configured"

        # Resolve school type (Do NOT default to HIGH_SCHOOL; if omitted, keep unconfigured)
        type_configured = bool(data.school_type and data.school_type.strip())
        if type_configured:
            type_raw = data.school_type.strip().upper()
            if type_raw in SchoolType.__members__:
                type_enum = SchoolType[type_raw]
            else:
                type_enum = SchoolType.OTHER
            type_display = data.school_type.strip()
        else:
            type_enum = SchoolType.OTHER
            type_display = "Not Configured"

        settings_dict = dict(data.custom_fields or {})
        settings_dict["board_configured"] = board_configured
        settings_dict["school_type_configured"] = type_configured
        settings_dict["custom_school_type"] = type_display
        settings_dict["custom_board"] = board_display
        settings_dict["setup_progress"] = {
            "school_profile": True,
            "principal_account": True,
            "academic_year": False,
            "classes": False,
            "teachers": False,
            "students": False,
            "fees": False,
            "attendance": False
        }

        try:
            # 1. Create Tenant
            tenant = Tenant(
                name=school_name,
                display_name=school_name,
                code=tenant_code,
                subdomain=subdomain,
                email=tenant_email,
                phone=data.phone,
                website=data.website,
                address=data.address,
                city=data.city,
                state=data.state,
                postal_code=data.postal_code,
                is_active=True,
                status=TenantStatus.ACTIVE,
                timezone="Asia/Kolkata",
                currency="INR",
                settings={"onboarding_version": "2.0"}
            )
            self.repo.db.add(tenant)
            await self.repo.db.flush()

            # 2. Seed Tenant RBAC
            from app.services.rbac_provisioning import ensure_tenant_rbac
            await ensure_tenant_rbac(self.repo.db, tenant.id)

            # 3. Handle optional Logo
            school_id = uuid.uuid4()
            logo_url = None
            if data.logo_base64 and storage_service:
                try:
                    logo_raw = data.logo_base64
                    if "," in logo_raw:
                        logo_raw = logo_raw.split(",", 1)[1]
                    img_bytes = base64.b64decode(logo_raw)
                    if 0 < len(img_bytes) <= 5 * 1024 * 1024:
                        from PIL import Image as PILImage
                        proc_img = PILImage.open(io.BytesIO(img_bytes))
                        proc_img.thumbnail((1024, 1024))
                        out_buf = io.BytesIO()
                        proc_img.save(out_buf, format="PNG", optimize=True)
                        processed_bytes = out_buf.getvalue()
                        storage_path = f"tenants/{tenant.id}/schools/{school_id}/branding/{uuid.uuid4().hex}.png"
                        await storage_service.upload(processed_bytes, storage_path, content_type="image/png")
                        logo_url = f"/api/v1/schools/{school_id}/logo"
                        settings_dict["branding"] = {
                            "logo_storage_key": storage_path,
                            "logo_updated_at": datetime.now(timezone.utc).isoformat()
                        }
                except Exception:
                    pass

            # 4. Create School
            school = School(
                id=school_id,
                tenant_id=tenant.id,
                name=school_name,
                display_name=school_name,
                code=school_code,
                board=board_enum,
                school_type=type_enum,
                email=principal_email,
                phone=data.phone,
                address=data.address,
                city=data.city,
                state=data.state,
                postal_code=data.postal_code,
                website=data.website,
                principal_name=principal_name,
                logo_url=logo_url,
                is_active=True,
                status=SchoolStatus.ACTIVE,
                settings=settings_dict,
                version=1
            )
            self.repo.db.add(school)
            await self.repo.db.flush()

            # 5. Provision Principal
            name_parts = principal_name.split(" ", 1)
            p_first = name_parts[0]
            p_last = name_parts[1] if len(name_parts) > 1 else ""

            from app.services.identity_provisioning import IdentityProvisioningService
            id_service = IdentityProvisioningService(self.repo.db)
            principal_user = await id_service.provision_principal(
                tenant_id=tenant.id,
                school_id=school.id,
                email=principal_email,
                first_name=p_first,
                last_name=p_last,
                phone=data.phone,
                password=principal_password
            )

            # 6. Generate JWT Access Token with authoritative tenant and school context
            from app.core.security import create_access_token
            access_token = create_access_token(
                subject=str(principal_user.id),
                tenant_id=str(tenant.id)
            )

            await self.repo.db.commit()

            return QuickSchoolOnboardingResponse(
                tenant_id=str(tenant.id),
                tenant_name=tenant.name,
                tenant_code=tenant.code,
                subdomain=tenant.subdomain,
                school_id=str(school.id),
                school_name=school.name,
                school_code=school.code,
                board=board_display,
                school_type=type_display,
                logo_url=logo_url,
                principal_id=str(principal_user.id),
                principal_name=f"{principal_user.first_name} {principal_user.last_name}".strip(),
                principal_email=principal_user.email,
                access_token=access_token,
                token_type="bearer",
                status="ACTIVE",
                message="School created and activated successfully. Principal account provisioned."
            )
        except Exception as exc:
            await self.repo.db.rollback()
            raise exc

    async def get_school_setup_progress(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID
    ) -> SchoolSetupProgressResponse:
        """
        Dynamically evaluates and returns the completion status of the 8 progressive setup modules.
        Non-blocking: school operations remain fully usable regardless of completion percentage.
        """
        school = await self.get_school(school_id, tenant_id)

        from app.models.academic_year import AcademicYear
        from app.models.class_entity import Class
        from app.models.teacher import Teacher
        from app.models.student import Student
        from app.models.fee import FeeStructure
        from app.models.attendance import AttendanceSession

        has_ay = (await self.repo.db.execute(
            select(func.count(AcademicYear.id)).where(
                AcademicYear.school_id == school_id,
                AcademicYear.tenant_id == tenant_id,
                AcademicYear.deleted_at.is_(None)
            )
        )).scalar() > 0

        has_classes = (await self.repo.db.execute(
            select(func.count(Class.id)).where(
                Class.school_id == school_id,
                Class.tenant_id == tenant_id,
                Class.deleted_at.is_(None)
            )
        )).scalar() > 0

        has_teachers = (await self.repo.db.execute(
            select(func.count(Teacher.id)).where(
                Teacher.school_id == school_id,
                Teacher.tenant_id == tenant_id,
                Teacher.deleted_at.is_(None)
            )
        )).scalar() > 0

        has_students = (await self.repo.db.execute(
            select(func.count(Student.id)).where(
                Student.school_id == school_id,
                Student.tenant_id == tenant_id,
                Student.deleted_at.is_(None)
            )
        )).scalar() > 0

        has_fees = (await self.repo.db.execute(
            select(func.count(FeeStructure.id)).where(
                FeeStructure.school_id == school_id,
                FeeStructure.tenant_id == tenant_id,
                FeeStructure.deleted_at.is_(None)
            )
        )).scalar() > 0

        has_attendance = (await self.repo.db.execute(
            select(func.count(AttendanceSession.id)).where(
                AttendanceSession.school_id == school_id,
                AttendanceSession.tenant_id == tenant_id,
                AttendanceSession.deleted_at.is_(None)
            )
        )).scalar() > 0

        from app.models.syllabus import Syllabus
        has_curriculum = (await self.repo.db.execute(
            select(func.count(Syllabus.id)).where(
                Syllabus.school_id == school_id,
                Syllabus.tenant_id == tenant_id,
                Syllabus.deleted_at.is_(None)
            )
        )).scalar() > 0

        steps = [
            SetupStepItem(
                step_key="school_profile",
                title="School Profile",
                description="Institution branding, affiliation, principal designation, and campus details",
                is_completed=True,
                route=f"/schools/{school_id}",
                action_label="View Profile"
            ),
            SetupStepItem(
                step_key="principal_account",
                title="Principal Account",
                description="Authenticated administrator credentials and tenant authorization",
                is_completed=True,
                route="/users",
                action_label="Manage Users"
            ),
            SetupStepItem(
                step_key="academic_year",
                title="Academic Year & Session",
                description="Operating calendar, session dates, and instructional terms",
                is_completed=has_ay,
                route=f"/schools/{school_id}/academic-years",
                action_label="Configure Year"
            ),
            SetupStepItem(
                step_key="classes_sections",
                title="Classes & Sections",
                description="Grade levels, academic streams, and classroom sections",
                is_completed=has_classes,
                route="/classes",
                action_label="Add Classes"
            ),
            SetupStepItem(
                step_key="curriculum_syllabus",
                title="Curriculum & Syllabus",
                description="Board-aligned official syllabus, chapters, and curriculum topics",
                is_completed=has_curriculum,
                route="/school-setup",
                action_label="Review & Edit Syllabus" if has_curriculum else "Auto-Populate Syllabus"
            ),
            SetupStepItem(
                step_key="teachers_staff",
                title="Teachers & Faculty Staff",
                description="Faculty roster, departments, specializations, and staff accounts",
                is_completed=has_teachers,
                route="/teachers",
                action_label="Add / Import Teachers"
            ),
            SetupStepItem(
                step_key="students_guardians",
                title="Students & Enrollments",
                description="Student roster, admission numbers, and parent/guardian contacts",
                is_completed=has_students,
                route="/students",
                action_label="Add / Import Students"
            ),
            SetupStepItem(
                step_key="fee_configuration",
                title="Fee Structure & Schedules",
                description="Tuition fees, payment terms, concessions, and collection rules",
                is_completed=has_fees,
                route="/fees",
                action_label="Configure Fees"
            ),
            SetupStepItem(
                step_key="attendance_configuration",
                title="Attendance & Timetable",
                description="Daily attendance sessions, periods, biometric rules, and notifications",
                is_completed=has_attendance,
                route="/attendance",
                action_label="Configure Attendance"
            )
        ]

        completed_count = sum(1 for s in steps if s.is_completed)
        progress_percentage = int((completed_count / len(steps)) * 100)

        return SchoolSetupProgressResponse(
            school_id=str(school.id),
            school_name=school.name,
            completed_count=completed_count,
            total_steps=len(steps),
            progress_percentage=progress_percentage,
            steps=steps
        )
