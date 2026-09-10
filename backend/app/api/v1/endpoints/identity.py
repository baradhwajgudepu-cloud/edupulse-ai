import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import select, func, or_, and_, distinct, exists, String
from sqlalchemy.orm import selectinload, aliased

from app.api.dependencies.auth import get_current_user, require_permission
from app.api.dependencies.common import get_tenant_id, verify_school_access
from app.api.dependencies.identity import get_identity_service
from app.db.session import get_db
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User, UserStatus
from app.models.role import Role, school_users, user_roles
from app.models.school import School
from app.models.teacher import Teacher
from app.models.guardian import Guardian, StudentGuardian
from app.models.student import Student
from app.services.identity_provisioning import IdentityProvisioningService
from app.schemas.response import APIResponse
from app.schemas.auth import UserResponse
from app.schemas.identity import (
    IdentityProvisionStatusResponse,
    IdentityResetPasswordResponse,
    PrincipalProvisionRequest
)

router = APIRouter()


@router.post(
    "/provision/teacher/{teacher_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Teacher"
)
async def provision_teacher(
    teacher_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the specified Teacher.
    """
    await verify_school_access(current_user, school_id, db)
    user = await service.provision_teacher(tenant_id, school_id, teacher_id, current_user.id)
    return APIResponse(
        success=True,
        message="Teacher user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/provision/guardian/{guardian_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Guardian"
)
async def provision_guardian(
    guardian_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the specified Guardian.
    """
    await verify_school_access(current_user, school_id, db)
    user = await service.provision_guardian(tenant_id, school_id, guardian_id, current_user.id)
    return APIResponse(
        success=True,
        message="Guardian user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/provision/principal",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision an authenticated user account for a Principal"
)
async def provision_principal_account(
    req: PrincipalProvisionRequest,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Provisions an authenticated system User account with the PRINCIPAL role for the specified School.
    """
    await verify_school_access(current_user, req.school_id, db)
    user = await service.provision_principal(
        tenant_id=tenant_id,
        school_id=req.school_id,
        email=req.email,
        first_name=req.first_name,
        last_name=req.last_name,
        phone=req.phone,
        password=req.password,
        current_user_id=current_user.id
    )
    return APIResponse(
        success=True,
        message="Principal user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/provision/principal/{principal_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Principal (legacy)"
)
async def provision_principal(
    principal_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the Principal by ID.
    """
    await verify_school_access(current_user, school_id, db)
    user = await service.provision_principal(
        tenant_id=tenant_id,
        school_id=school_id,
        principal_id=principal_id,
        current_user_id=current_user.id
    )
    return APIResponse(
        success=True,
        message="Principal user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )


@router.post(
    "/provision/staff/{staff_id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Provision a user account for a Staff member"
)
async def provision_staff(
    staff_id: uuid.UUID,
    school_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.provision")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Manually provisions an authenticated system User account for the Staff member.
    """
    await verify_school_access(current_user, school_id, db)
    user = await service.provision_staff(tenant_id, school_id, staff_id, current_user.id)
    return APIResponse(
        success=True,
        message="Staff user account provisioned successfully.",
        data=UserResponse.model_validate(user)
    )


def _build_global_user_search_condition(search: str, tenant_id: uuid.UUID):
    """
    Builds a comprehensive, case-insensitive partial search filter across:
    - User: first_name, middle_name (if present), last_name, email, login_id, concatenated full-name variations.
    - Multi-word / tokenized full name matching (e.g. 'Deepak Boddu', extra whitespace handled).
    - Teacher: employee_code, staff_code, names, phones, emails, designation, department.
    - Guardian: names, phones, email, guardian_type, aadhaar_number.
    - Linked Student: names, admission_number, roll_number, mobile, email, aadhaar_number.
    - Co-guardian: other guardians of the same student(s) (e.g. father's name for mother's account or vice versa).
    - Direct student account linkage (email / admission_number).
    - Role: name and code.
    - School: name and code.
    Enforces strict tenant isolation across all subqueries.
    Uses SQL EXISTS to avoid JOIN row duplication and preserve pagination.
    """
    clean_search = " ".join(search.strip().split())
    term = f"%{clean_search}%"
    tokens = clean_search.split()

    conditions = [
        # 1. Direct User columns
        User.first_name.ilike(term),
        User.last_name.ilike(term),
        User.email.ilike(term),
        User.login_id.ilike(term),
        func.concat(User.first_name, ' ', User.last_name).ilike(term),
        func.concat(User.last_name, ' ', User.first_name).ilike(term),
    ]

    if hasattr(User, 'middle_name'):
        conditions.extend([
            getattr(User, 'middle_name').ilike(term),
            func.concat(User.first_name, ' ', getattr(User, 'middle_name'), ' ', User.last_name).ilike(term),
        ])

    if len(tokens) > 1:
        token_conds = [
            or_(
                User.first_name.ilike(f"%{tok}%"),
                User.last_name.ilike(f"%{tok}%"),
                User.email.ilike(f"%{tok}%"),
                User.login_id.ilike(f"%{tok}%"),
                func.concat(User.first_name, ' ', User.last_name).ilike(f"%{tok}%"),
                func.concat(User.last_name, ' ', User.first_name).ilike(f"%{tok}%"),
            )
            for tok in tokens
        ]
        conditions.append(and_(*token_conds))

    # 2. Teacher Subquery
    teacher_clauses = [
        Teacher.employee_code.ilike(term),
        Teacher.staff_code.ilike(term),
        Teacher.first_name.ilike(term),
        Teacher.last_name.ilike(term),
        Teacher.middle_name.ilike(term),
        func.concat(Teacher.first_name, ' ', Teacher.last_name).ilike(term),
        func.concat(Teacher.first_name, ' ', func.coalesce(Teacher.middle_name, ''), ' ', Teacher.last_name).ilike(term),
        Teacher.mobile.ilike(term),
        Teacher.alternate_mobile.ilike(term),
        Teacher.official_email.ilike(term),
        Teacher.personal_email.ilike(term),
        Teacher.designation.ilike(term),
        Teacher.department.ilike(term),
    ]
    if len(tokens) > 1:
        teacher_clauses.append(
            and_(*[
                or_(
                    Teacher.first_name.ilike(f"%{tok}%"),
                    Teacher.last_name.ilike(f"%{tok}%"),
                    Teacher.middle_name.ilike(f"%{tok}%"),
                    Teacher.employee_code.ilike(f"%{tok}%"),
                    Teacher.staff_code.ilike(f"%{tok}%"),
                    Teacher.designation.ilike(f"%{tok}%"),
                    func.concat(Teacher.first_name, ' ', Teacher.last_name).ilike(f"%{tok}%"),
                )
                for tok in tokens
            ])
        )
    teacher_subq = exists(
        select(1).select_from(Teacher).where(
            Teacher.user_id == User.id,
            Teacher.tenant_id == tenant_id,
            or_(*teacher_clauses)
        )
    )
    conditions.append(teacher_subq)

    # 3. Guardian Subquery
    guardian_clauses = [
        Guardian.first_name.ilike(term),
        Guardian.last_name.ilike(term),
        Guardian.middle_name.ilike(term),
        func.concat(Guardian.first_name, ' ', Guardian.last_name).ilike(term),
        func.concat(Guardian.first_name, ' ', func.coalesce(Guardian.middle_name, ''), ' ', Guardian.last_name).ilike(term),
        Guardian.mobile.ilike(term),
        Guardian.alternate_mobile.ilike(term),
        Guardian.email.ilike(term),
        Guardian.aadhaar_number.ilike(term),
        func.cast(Guardian.guardian_type, String).ilike(term),
    ]
    if len(tokens) > 1:
        guardian_clauses.append(
            and_(*[
                or_(
                    Guardian.first_name.ilike(f"%{tok}%"),
                    Guardian.last_name.ilike(f"%{tok}%"),
                    Guardian.middle_name.ilike(f"%{tok}%"),
                    func.concat(Guardian.first_name, ' ', Guardian.last_name).ilike(f"%{tok}%"),
                )
                for tok in tokens
            ])
        )
    guardian_subq = exists(
        select(1).select_from(Guardian).where(
            Guardian.user_id == User.id,
            Guardian.tenant_id == tenant_id,
            or_(*guardian_clauses)
        )
    )
    conditions.append(guardian_subq)

    # 4. Students of Guardian Subquery
    student_clauses = [
        Student.first_name.ilike(term),
        Student.last_name.ilike(term),
        Student.middle_name.ilike(term),
        func.concat(Student.first_name, ' ', Student.last_name).ilike(term),
        func.concat(Student.first_name, ' ', func.coalesce(Student.middle_name, ''), ' ', Student.last_name).ilike(term),
        Student.admission_number.ilike(term),
        Student.roll_number.ilike(term),
        Student.mobile.ilike(term),
        Student.email.ilike(term),
        Student.aadhaar_number.ilike(term),
        Student.emis_number.ilike(term),
    ]
    if len(tokens) > 1:
        student_clauses.append(
            and_(*[
                or_(
                    Student.first_name.ilike(f"%{tok}%"),
                    Student.last_name.ilike(f"%{tok}%"),
                    Student.middle_name.ilike(f"%{tok}%"),
                    Student.admission_number.ilike(f"%{tok}%"),
                    Student.roll_number.ilike(f"%{tok}%"),
                    func.concat(Student.first_name, ' ', Student.last_name).ilike(f"%{tok}%"),
                )
                for tok in tokens
            ])
        )
    student_of_guardian_subq = exists(
        select(1).select_from(Guardian)
        .join(StudentGuardian, and_(StudentGuardian.guardian_id == Guardian.id, StudentGuardian.tenant_id == tenant_id))
        .join(Student, and_(Student.id == StudentGuardian.student_id, Student.tenant_id == tenant_id))
        .where(
            Guardian.user_id == User.id,
            Guardian.tenant_id == tenant_id,
            or_(*student_clauses)
        )
    )
    conditions.append(student_of_guardian_subq)

    # 5. Co-guardians (e.g. searching father's name when mother is user or vice versa)
    other_sg = aliased(StudentGuardian)
    other_g = aliased(Guardian)
    coguardian_clauses = [
        other_g.first_name.ilike(term),
        other_g.last_name.ilike(term),
        other_g.middle_name.ilike(term),
        func.concat(other_g.first_name, ' ', other_g.last_name).ilike(term),
        func.concat(other_g.first_name, ' ', func.coalesce(other_g.middle_name, ''), ' ', other_g.last_name).ilike(term),
        other_g.mobile.ilike(term),
        other_g.alternate_mobile.ilike(term),
        other_g.email.ilike(term),
        func.cast(other_g.guardian_type, String).ilike(term),
    ]
    if len(tokens) > 1:
        coguardian_clauses.append(
            and_(*[
                or_(
                    other_g.first_name.ilike(f"%{tok}%"),
                    other_g.last_name.ilike(f"%{tok}%"),
                    other_g.middle_name.ilike(f"%{tok}%"),
                    func.concat(other_g.first_name, ' ', other_g.last_name).ilike(f"%{tok}%"),
                )
                for tok in tokens
            ])
        )
    coguardian_subq = exists(
        select(1).select_from(Guardian)
        .join(StudentGuardian, and_(StudentGuardian.guardian_id == Guardian.id, StudentGuardian.tenant_id == tenant_id))
        .join(other_sg, and_(other_sg.student_id == StudentGuardian.student_id, other_sg.tenant_id == tenant_id))
        .join(other_g, and_(other_g.id == other_sg.guardian_id, other_g.tenant_id == tenant_id))
        .where(
            Guardian.user_id == User.id,
            Guardian.tenant_id == tenant_id,
            or_(*coguardian_clauses)
        )
    )
    conditions.append(coguardian_subq)

    # 6. Direct student and student's guardians match (if user account is directly linked to student)
    student_direct_subq = exists(
        select(1).select_from(Student).where(
            Student.tenant_id == tenant_id,
            or_(
                and_(Student.email.is_not(None), Student.email == User.email),
                and_(Student.admission_number.is_not(None), Student.admission_number == User.login_id)
            ),
            or_(*student_clauses)
        )
    )
    conditions.append(student_direct_subq)

    student_guardian_direct_subq = exists(
        select(1).select_from(Student)
        .join(StudentGuardian, and_(StudentGuardian.student_id == Student.id, StudentGuardian.tenant_id == tenant_id))
        .join(Guardian, and_(Guardian.id == StudentGuardian.guardian_id, Guardian.tenant_id == tenant_id))
        .where(
            Student.tenant_id == tenant_id,
            or_(
                and_(Student.email.is_not(None), Student.email == User.email),
                and_(Student.admission_number.is_not(None), Student.admission_number == User.login_id)
            ),
            or_(*guardian_clauses)
        )
    )
    conditions.append(student_guardian_direct_subq)

    # 7. Role Subquery
    role_subq = exists(
        select(1).select_from(user_roles)
        .join(Role, Role.id == user_roles.c.role_id)
        .where(
            user_roles.c.user_id == User.id,
            or_(
                Role.name.ilike(term),
                Role.code.ilike(term)
            )
        )
    )
    conditions.append(role_subq)

    # 8. School Subquery
    school_subq = exists(
        select(1).select_from(school_users)
        .join(School, School.id == school_users.c.school_id)
        .where(
            school_users.c.user_id == User.id,
            School.tenant_id == tenant_id,
            or_(
                School.name.ilike(term),
                School.code.ilike(term)
            )
        )
    )
    conditions.append(school_subq)

    return or_(*conditions)

@router.get(
    "/users",
    response_model=APIResponse[List[UserResponse]],
    status_code=status.HTTP_200_OK,
    summary="List and search users"
)
async def list_users(
    search: Optional[str] = Query(None, description="Global search query across directory attributes and relations"),
    role: Optional[str] = Query(None, description="Filter by role code or name (e.g. TEACHER, PARENT, PRINCIPAL)"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status (ACTIVE, INACTIVE, SUSPENDED, LOCKED)"),
    school_id: Optional[uuid.UUID] = Query(None, description="Filter by affiliated school ID"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    page: Optional[int] = Query(None, ge=1),
    page_size: Optional[int] = Query(None, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[List[UserResponse]]:
    """
    Lists and searches users belonging to the active tenant.
    Supports server-side search across first name, last name, and email with ILIKE,
    role filtering, status filtering, school affiliation filtering, and pagination metadata.
    Enforces strict multi-tenant and campus isolation:
    - Platform and Tenant Admins: tenant-wide scope (or school-filtered if school_id is provided).
    - Principals: scoped strictly to assigned school(s), excluding platform administrators.
    - Teachers: rejected with HTTP 403 Forbidden.
    """
    if page is not None:
        eff_page_size = page_size or limit or 20
        skip = (page - 1) * eff_page_size
        limit = eff_page_size
    elif page_size is not None:
        limit = page_size

    user_permissions = {p.code for r in current_user.roles for p in r.permissions}
    is_platform_or_tenant_admin = current_user.is_superuser or any(
        r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "ADMIN", "CHAIRMAN"] for r in current_user.roles
    )
    is_principal = any(r.code in ["PRINCIPAL", "SCHOOL_ADMIN"] for r in current_user.roles)

    if not is_platform_or_tenant_admin and not is_principal and "identity.read" not in user_permissions:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Insufficient permissions to view user directory."
        )

    stmt = select(User).where(
        User.tenant_id == tenant_id,
        User.deleted_at.is_(None)
    )

    if not is_platform_or_tenant_admin:
        user_school_ids = [s.id for s in current_user.schools]
        if not user_school_ids:
            return APIResponse(
                success=True,
                message="No users found for unassigned school context.",
                data=[],
                meta={
                    "total": 0,
                    "skip": skip,
                    "limit": limit,
                    "page": (skip // limit) + 1 if limit > 0 else 1,
                    "page_size": limit,
                    "total_pages": 0
                }
            )
        # If school_id was specified by Principal, verify it belongs to their schools
        if school_id is not None:
            if school_id not in user_school_ids:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied. Specified school is outside your authorized context."
                )
            stmt = stmt.where(User.id.in_(select(school_users.c.user_id).where(school_users.c.school_id == school_id)))
        else:
            # Filter to users belonging to any of principal's schools
            school_user_subq = select(school_users.c.user_id).where(school_users.c.school_id.in_(user_school_ids))
            stmt = stmt.where(User.id.in_(school_user_subq))

        # Exclude platform super admins and tenant admins
        admin_user_subq = select(user_roles.c.user_id).join(Role, Role.id == user_roles.c.role_id).where(
            Role.code.in_(["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "ADMIN"])
        )
        stmt = stmt.where(User.id.not_in(admin_user_subq))
        stmt = stmt.where(User.is_superuser.is_(False))
    else:
        # Platform/Tenant admin: filter by school_id if provided
        if school_id is not None:
            stmt = stmt.where(User.id.in_(select(school_users.c.user_id).where(school_users.c.school_id == school_id)))

    # Global Search filter (multi-attribute, case-insensitive partial search across all directory attributes and relations)
    if search and search.strip():
        stmt = stmt.where(_build_global_user_search_condition(search, tenant_id))

    # Role filter
    if role and role.strip():
        role_term = role.strip().upper()
        role_subq = select(user_roles.c.user_id).join(Role, Role.id == user_roles.c.role_id).where(
            or_(
                func.upper(Role.code) == role_term,
                func.upper(Role.name) == role_term
            )
        )
        stmt = stmt.where(User.id.in_(role_subq))

    # Status filter
    if status_filter and status_filter.strip():
        st_val = status_filter.strip().upper()
        stmt = stmt.where(User.status == st_val)

    # Compute total count for pagination before offset/limit
    count_stmt = select(func.count()).select_from(stmt.order_by(None).subquery())
    count_res = await db.execute(count_stmt)
    total_count = count_res.scalar_one() or 0

    # Retrieve paginated items
    stmt = stmt.order_by(User.created_at.desc(), User.id.desc()).offset(skip).limit(limit).options(
        selectinload(User.roles).selectinload(Role.permissions),
        selectinload(User.schools)
    )
    res = await db.execute(stmt)
    users = list(res.scalars().all())

    total_pages = (total_count + limit - 1) // limit if limit > 0 else 1
    current_page = (skip // limit) + 1 if limit > 0 else 1

    return APIResponse(
        success=True,
        message="Users list retrieved successfully.",
        data=[UserResponse.model_validate(u) for u in users],
        meta={
            "total": total_count,
            "skip": skip,
            "limit": limit,
            "page": current_page,
            "page_size": limit,
            "total_pages": total_pages,
        }
    )

@router.get(
    "/users/{id}",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve user details"
)
async def get_user_details(
    id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[UserResponse]:
    """
    Retrieves user profile details by ID.
    Enforces school scoping for Principal accounts.
    """
    user_permissions = {p.code for r in current_user.roles for p in r.permissions}
    is_platform_or_tenant_admin = current_user.is_superuser or any(
        r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN", "CHAIRMAN"] for r in current_user.roles
    )
    is_principal = any(r.code == "PRINCIPAL" for r in current_user.roles)

    if not is_platform_or_tenant_admin and not is_principal and "identity.read" not in user_permissions:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. Insufficient permissions to view user details."
        )

    stmt = select(User).where(
        User.id == id,
        User.tenant_id == tenant_id,
        User.deleted_at.is_(None)
    ).options(
        selectinload(User.roles).selectinload(Role.permissions),
        selectinload(User.schools)
    )
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found.")

    if not is_platform_or_tenant_admin:
        principal_school_ids = {s.id for s in current_user.schools}
        target_school_ids = {s.id for s in user.schools}
        if not principal_school_ids.intersection(target_school_ids):
            raise HTTPException(status_code=403, detail="Access denied. User belongs to another school context.")
        if any(r.code in ["SUPER_ADMIN", "SYSTEM_ADMIN", "TENANT_ADMIN"] for r in user.roles):
            raise HTTPException(status_code=403, detail="Access denied. Cannot view platform administrators.")

    return APIResponse(
        success=True,
        message="User details retrieved successfully.",
        data=UserResponse.model_validate(user)
    )

@router.put(
    "/users/{id}/activate",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Activate user account"
)
async def activate_user(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Activates a provisioned User account.
    """
    user = await service.activate_user(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User account activated successfully.",
        data=UserResponse.model_validate(user)
    )

@router.put(
    "/users/{id}/deactivate",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Deactivate user account"
)
async def deactivate_user(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Deactivates a provisioned User account.
    """
    user = await service.deactivate_user(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User account deactivated successfully.",
        data=UserResponse.model_validate(user)
    )

@router.post(
    "/users/{id}/reset-password",
    response_model=APIResponse[IdentityResetPasswordResponse],
    status_code=status.HTTP_200_OK,
    summary="Reset user password"
)
async def reset_password(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.reset_password")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[IdentityResetPasswordResponse]:
    """
    Resets the User's credentials to a temporary hashed password.
    """
    # Fetch email first
    stmt = select(User.email).where(User.id == id, User.tenant_id == tenant_id)
    res = await db.execute(stmt)
    email = res.scalar_one_or_none()
    if not email:
        raise HTTPException(status_code=404, detail="User not found.")

    temp_pwd = await service.reset_password(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User password reset successfully.",
        data=IdentityResetPasswordResponse(email=email, temporary_password=temp_pwd)
    )

@router.post(
    "/users/{id}/unlock",
    response_model=APIResponse[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Unlock user account"
)
async def unlock_user(
    id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.update")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[UserResponse]:
    """
    Unlocks a blocked or locked user account.
    """
    user = await service.unlock_user(tenant_id, id, current_user.id)
    return APIResponse(
        success=True,
        message="User account unlocked successfully.",
        data=UserResponse.model_validate(user)
    )

@router.get(
    "/provision/status/{entity_id}",
    response_model=APIResponse[IdentityProvisionStatusResponse],
    status_code=status.HTTP_200_OK,
    summary="Get provision status"
)
async def get_provision_status(
    entity_id: uuid.UUID,
    current_user: User = Depends(require_permission("identity.read")),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    service: IdentityProvisioningService = Depends(get_identity_service)
) -> APIResponse[IdentityProvisionStatusResponse]:
    """
    Checks the status details of user provisioning on a teacher or guardian profile.
    """
    status_data = await service.get_provision_status(tenant_id, entity_id)
    return APIResponse(
        success=True,
        message="Provision status retrieved successfully.",
        data=status_data
    )


from app.api.dependencies.auth import get_current_user
from app.schemas.identity import IdentityMeResponse
from app.repositories.teacher import TeacherRepository
from app.schemas.teacher import TeacherResponse

@router.get(
    "/me",
    response_model=APIResponse[IdentityMeResponse],
    status_code=status.HTTP_200_OK,
    summary="Get current user identity details"
)
async def get_identity_me(
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db)
) -> APIResponse[IdentityMeResponse]:
    """
    Retrieves the identity details for the authenticated user session (including Teacher details if applicable).
    """
    teacher_repo = TeacherRepository(db)
    teacher = await teacher_repo.get_by_user_id(current_user.id, tenant_id)
    
    teacher_data = None
    if teacher:
        teacher_data = TeacherResponse.model_validate(teacher)
        
    return APIResponse(
        success=True,
        message="Identity profile retrieved successfully.",
        data=IdentityMeResponse(
            user=UserResponse.model_validate(current_user),
            teacher=teacher_data
        )
    )
