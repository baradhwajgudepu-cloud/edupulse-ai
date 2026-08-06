import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.subject import Subject, SubjectStatus, SubjectCategory, SubjectType
from app.models.role import Role
from app.models.permission import Permission
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.subject import SubjectRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.subject import SubjectCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_subject_test_data(db_session):
    """
    Sets up common testing context:
    - Tenant A, School A, Academic Year A (ACTIVE), Academic Year A2 (ARCHIVED)
    - Tenant B, School B, Academic Year B (ACTIVE)
    - Super Admin user with credentials mapped to School A
    """
    suffix = uuid.uuid4().hex[:6].upper()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Tenant A", code=f"tenant-a-{suffix.lower()}", subdomain=f"t-a-{suffix.lower()}", email=f"a-{suffix.lower()}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Tenant B", code=f"tenant-b-{suffix.lower()}", subdomain=f"t-b-{suffix.lower()}", email=f"b-{suffix.lower()}@t.com"))

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="School A", code=f"SCH_A_{suffix}", board="CBSE", email=f"s-a-{suffix.lower()}@a.com"))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="School B", code=f"SCH_B_{suffix}", board="CBSE", email=f"s-b-{suffix.lower()}@b.com"))
    await db_session.commit()

    # Pre-create Academic Years
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id,
        school_a.id,
        AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31")
    )
    ay_a.status = AcademicYearStatus.ACTIVE

    ay_a_archived = await repo_ay.create(
        tenant_a.id,
        school_a.id,
        AcademicYearCreate(name="2025", code="AY2025", start_date="2025-01-01", end_date="2025-12-31")
    )
    ay_a_archived.status = AcademicYearStatus.ARCHIVED

    ay_b = await repo_ay.create(
        tenant_b.id,
        school_b.id,
        AcademicYearCreate(name="2026", code="AY2026", start_date="2026-01-01", end_date="2026-12-31")
    )
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # User Setup
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    role_a = Role(name="Super Admin", code="SUPER_ADMIN", is_system=True, tenant_id=tenant_a.id)
    role_a.permissions = all_perms
    db_session.add(role_a)

    user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="Admin", last_name="User")
    )
    user_a.roles.append(role_a)

    # Map user to School A
    await db_session.execute(
        text("INSERT INTO school_users (user_id, school_id) VALUES (:u, :s)"),
        {"u": str(user_a.id), "s": str(school_a.id)}
    )
    await db_session.commit()

    tokens = await auth_service.create_tokens(user_a)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "ay_a": ay_a,
        "ay_a_archived": ay_a_archived,
        "ay_b": ay_b,
        "user_a": user_a,
        "auth_headers": {
            "Authorization": f"Bearer {tokens.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_subject_crud_flow(client: AsyncClient, setup_subject_test_data, db_session) -> None:
    """
    Verifies Subject CRUD endpoints:
    - POST create subject
    - GET list subjects
    - GET fetch subject details
    - PUT update subject details
    - DELETE soft-delete subject
    """
    data = setup_subject_test_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    headers = data["auth_headers"]

    # 1. Create Subject
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "subject_code": "PHY-101",
        "subject_name": "Physics Fundamentals",
        "short_name": "PHY",
        "category": "CORE",
        "subject_type": "THEORY_PRACTICAL",
        "description": "Intro to Physics",
        "credit_hours": 4,
        "weekly_periods": 5,
        "theory_marks": 70,
        "practical_marks": 30,
        "pass_marks": 40,
        "display_color": "#FF5733",
        "display_order": 1,
        "settings": {"grading": "CBSE"},
        "ai_metrics": {
            "difficulty_score": 7.5
        }
    }
    resp = await client.post("/api/v1/subjects", json=payload, headers=headers)
    assert resp.status_code == 201
    subject_id = resp.json()["data"]["id"]
    assert resp.json()["data"]["subject_name"] == "Physics Fundamentals"
    assert resp.json()["data"]["display_color"] == "#FF5733"
    assert resp.json()["data"]["status"] == "ACTIVE"

    # 2. Get list of subjects
    resp_list = await client.get(f"/api/v1/subjects?school_id={school_id}", headers=headers)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) >= 1

    # 3. Get subject details
    resp_get = await client.get(f"/api/v1/subjects/{subject_id}?school_id={school_id}", headers=headers)
    assert resp_get.status_code == 200
    assert resp_get.json()["data"]["subject_code"] == "PHY-101"

    # 4. Update subject details
    update_payload = {
        "subject_name": "Modern Physics",
        "status": "INACTIVE"
    }
    resp_put = await client.put(f"/api/v1/subjects/{subject_id}?school_id={school_id}", json=update_payload, headers=headers)
    assert resp_put.status_code == 200
    assert resp_put.json()["data"]["subject_name"] == "Modern Physics"
    assert resp_put.json()["data"]["status"] == "INACTIVE"
    assert resp_put.json()["data"]["is_active"] is False

    # 5. Delete subject profile
    resp_del = await client.delete(f"/api/v1/subjects/{subject_id}?school_id={school_id}", headers=headers)
    assert resp_del.status_code == 200
    assert resp_del.json()["data"]["deleted_at"] is not None

    # Verify soft-deleted subject is omitted from fetch
    resp_del_get = await client.get(f"/api/v1/subjects/{subject_id}?school_id={school_id}", headers=headers)
    assert resp_del_get.status_code == 404

@pytest.mark.anyio
async def test_subject_business_validations(client: AsyncClient, setup_subject_test_data, db_session) -> None:
    """
    Verifies Subject business validations:
    - Block duplicates per year
    - Archived year validation
    - Marks bounds constraints
    - Theory/Practical constraint rules
    """
    data = setup_subject_test_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    archived_ay_id = data["ay_a_archived"].id
    headers = data["auth_headers"]

    # Pre-create a subject
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "subject_code": "MAT-101",
        "subject_name": "Mathematics 101",
        "category": "CORE",
        "subject_type": "THEORY",
        "theory_marks": 100,
        "practical_marks": 0,
        "pass_marks": 35
    }
    resp = await client.post("/api/v1/subjects", json=payload, headers=headers)
    assert resp.status_code == 201

    # 1. Duplicate code in same year -> fails
    payload_dup_code = {**payload, "subject_name": "Different Name"}
    resp = await client.post("/api/v1/subjects", json=payload_dup_code, headers=headers)
    assert resp.status_code == 409

    # 2. Duplicate name in same year -> fails
    payload_dup_name = {**payload, "subject_code": "MAT-102"}
    resp = await client.post("/api/v1/subjects", json=payload_dup_name, headers=headers)
    assert resp.status_code == 409

    # 3. Create inside archived academic year -> fails
    payload_archived = {**payload, "subject_code": "MAT-103", "subject_name": "Maths Archived", "academic_year_id": str(archived_ay_id)}
    resp = await client.post("/api/v1/subjects", json=payload_archived, headers=headers)
    assert resp.status_code == 422

    # 4. Pass marks exceeding total marks -> fails
    payload_bad_pass = {**payload, "subject_code": "MAT-104", "subject_name": "Maths Exceed", "pass_marks": 101}
    resp = await client.post("/api/v1/subjects", json=payload_bad_pass, headers=headers)
    assert resp.status_code == 422

    # 5. Theory subject having practical marks > 0 -> fails
    payload_theory_prac = {**payload, "subject_code": "MAT-105", "subject_name": "Theory Prac", "subject_type": "THEORY", "practical_marks": 20}
    resp = await client.post("/api/v1/subjects", json=payload_theory_prac, headers=headers)
    assert resp.status_code == 422

    # 6. Practical subject having theory marks > 0 -> fails
    payload_prac_theory = {**payload, "subject_code": "MAT-106", "subject_name": "Prac Theory", "subject_type": "PRACTICAL", "theory_marks": 50}
    resp = await client.post("/api/v1/subjects", json=payload_prac_theory, headers=headers)
    assert resp.status_code == 422

@pytest.mark.anyio
async def test_subject_fuzzy_searches(client: AsyncClient, setup_subject_test_data, db_session) -> None:
    """
    Verifies fuzzy searching subjects works.
    """
    data = setup_subject_test_data
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id
    headers = data["auth_headers"]

    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "subject_code": "ENG-202",
        "subject_name": "Advanced English Literature",
        "short_name": "LIT",
        "category": "LANGUAGE",
        "subject_type": "THEORY"
    }
    resp = await client.post("/api/v1/subjects", json=payload, headers=headers)
    assert resp.status_code == 201

    # Search short name
    resp_search = await client.get(f"/api/v1/subjects?school_id={school_id}&search=LIT", headers=headers)
    assert resp_search.status_code == 200
    assert len(resp_search.json()["data"]) == 1

@pytest.mark.anyio
async def test_subject_tenant_isolation(client: AsyncClient, setup_subject_test_data, db_session) -> None:
    """
    Verifies that Subject records remain isolated within tenant boundaries.
    """
    data = setup_subject_test_data
    school_b = data["school_b"].id
    ay_b = data["ay_b"].id
    headers_a = data["auth_headers"]

    # Pre-create subject under Tenant B
    repo_s = SubjectRepository(db_session)
    sub_b = await repo_s.create(
        tenant_id=data["tenant_b"].id,
        obj_in=SubjectCreate(
            school_id=school_b,
            academic_year_id=ay_b,
            subject_code="BIO-101",
            subject_name="Biology",
            category="CORE",
            subject_type="THEORY_PRACTICAL",
            theory_marks=60,
            practical_marks=40,
            pass_marks=35
        )
    )
    await db_session.commit()

    # Tenant A attempts to fetch Tenant B's subject details -> should fail with 401/404
    resp = await client.get(f"/api/v1/subjects/{sub_b.id}?school_id={school_b}", headers=headers_a)
    assert resp.status_code in [401, 404]

    # Tenant A attempts to list subjects under School B -> returns empty list 200 OK
    resp_list = await client.get(f"/api/v1/subjects?school_id={school_b}", headers=headers_a)
    assert resp_list.status_code == 200
    assert len(resp_list.json()["data"]) == 0

@pytest.mark.anyio
async def test_subject_concurrency_control_occ(setup_subject_test_data, db_session) -> None:
    """
    Verifies optimistic concurrency locking on Subjects.
    """
    from sqlalchemy.ext.asyncio import async_sessionmaker
    from sqlalchemy.orm.exc import StaleDataError

    data = setup_subject_test_data
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id
    ay_id = data["ay_a"].id

    # 1. Create subject in Session A
    repo_a = SubjectRepository(db_session)
    sub_obj = await repo_a.create(
        tenant_id=tenant_id,
        obj_in=SubjectCreate(
            school_id=school_id,
            academic_year_id=ay_id,
            subject_code="CHEM-101",
            subject_name="Chemistry",
            category="CORE",
            subject_type="THEORY"
        )
    )
    await repo_a.db.commit()
    await repo_a.db.refresh(sub_obj)
    assert sub_obj.version == 1

    # 2. Load subject in Session B
    async_session_b = async_sessionmaker(
        bind=db_session.bind,
        class_=AsyncSession,
        expire_on_commit=False
    )
    async with async_session_b() as session_b:
        repo_b = SubjectRepository(session_b)
        sub_obj_b = await repo_b.get_by_id(sub_obj.id, school_id, tenant_id)
        assert sub_obj_b.version == 1

        # 3. Modify and commit in Session A
        sub_obj.subject_name = "Chem Organic"
        await repo_a.db.commit()
        await repo_a.db.refresh(sub_obj)
        assert sub_obj.version == 2

        # 4. Attempt update in Session B -> should raise StaleDataError
        sub_obj_b.subject_name = "Chem Inorganic"
        with pytest.raises(StaleDataError):
            await repo_b.db.commit()

        await repo_b.db.close()
