import uuid
import pytest
from datetime import date
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.syllabus import Syllabus
from app.models.role import Role
from app.models.permission import Permission

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.subject import SubjectRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.subject import SubjectCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_syllabus_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Create Tenants
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Syllabus Tenant A", code=f"syll-a-{suffix}", subdomain=f"syll-a-{suffix}", email=f"a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Syllabus Tenant B", code=f"syll-b-{suffix}", subdomain=f"syll-b-{suffix}", email=f"b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Create Schools
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Syllabus School A", code=f"SC_A_{suffix.upper()}", address="123 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Syllabus School B", code=f"SC_B_{suffix.upper()}", address="456 Street", city="Bangalore", state="Karnataka", country="India", pin_code="560001", board="CBSE", email=f"s-b-{suffix}@b.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Years
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(school_id=school_b.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 8", code="G8", level=8, category=ClassCategory.MIDDLE, capacity=35))
    class_b = await repo_c.create(tenant_b.id, ClassCreate(school_id=school_b.id, academic_year_id=ay_b.id, name="Grade 8", code="G8_B", level=8, category=ClassCategory.MIDDLE, capacity=35))
    await db_session.commit()

    # 5. Subjects
    repo_sub = SubjectRepository(db_session)
    subject_a = await repo_sub.create(tenant_a.id, SubjectCreate(school_id=school_a.id, academic_year_id=ay_a.id, subject_code=f"MATH-{suffix.upper()}", subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    subject_a.status = SubjectStatus.ACTIVE
    subject_b = await repo_sub.create(tenant_b.id, SubjectCreate(school_id=school_b.id, academic_year_id=ay_b.id, subject_code=f"MATH-{suffix.upper()}", subject_name="Mathematics", category=SubjectCategory.CORE, subject_type=SubjectType.THEORY))
    subject_b.status = SubjectStatus.ACTIVE
    await db_session.commit()

    # 6. User and Roles Setup
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

    user_admin = await auth_service.create_user(
        tenant_a.id,
        UserCreate(email=f"admin-{suffix}@a.com", password="Password123!", first_name="School", last_name="Admin")
    )
    user_admin.roles.append(role_a)
    await db_session.commit()

    tokens_a = await auth_service.create_tokens(user_admin)

    return {
        "tenant_a": tenant_a, "tenant_b": tenant_b,
        "school_a": school_a, "school_b": school_b,
        "ay_a": ay_a, "ay_b": ay_b,
        "class_a": class_a, "class_b": class_b,
        "subject_a": subject_a, "subject_b": subject_b,
        "auth_headers": {
            "Authorization": f"Bearer {tokens_a.access_token}",
            "X-Tenant-ID": str(tenant_a.id)
        }
    }

@pytest.mark.anyio
async def test_syllabus_crud_and_isolation(client: AsyncClient, setup_syllabus_test_data) -> None:
    data = setup_syllabus_test_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a"].id)
    subject_id = str(data["subject_a"].id)

    # 1. Create a Syllabus Entry
    syllabus_payload = {
        "class_id": class_id,
        "subject_id": subject_id,
        "syllabus_code": "SYLL_MATH_8_U1",
        "unit_name": "Unit 1",
        "chapter_name": "Rational Numbers",
        "topic_name": "Multiplication Property",
        "description": "Introduction to rational multiplication",
        "sequence_order": 1
    }

    res = await client.post(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}",
        json=syllabus_payload,
        headers=headers
    )
    assert res.status_code == 201
    res_data = res.json()
    assert res_data["success"] is True
    assert res_data["data"]["syllabus_code"] == "SYLL_MATH_8_U1"
    syllabus_id_str = res_data["data"]["id"]

    # 2. Verify duplicate prevention (Uniqueness check returns 409 Conflict)
    res_dup = await client.post(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}",
        json=syllabus_payload,
        headers=headers
    )
    assert res_dup.status_code == 409

    # 3. Get Single Entry
    res_get = await client.get(
        f"/api/v1/syllabuses/{syllabus_id_str}?school_id={school_id}",
        headers=headers
    )
    assert res_get.status_code == 200
    assert res_get.json()["data"]["chapter_name"] == "Rational Numbers"

    # 4. List syllabus entries
    res_list = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    assert res_list.status_code == 200
    assert len(res_list.json()["data"]) == 1

    # 5. List with non-matching subject filters returns empty
    res_list_empty = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&subject_id={str(uuid.uuid4())}",
        headers=headers
    )
    assert res_list_empty.status_code == 200
    assert len(res_list_empty.json()["data"]) == 0

    # 6. Update entry
    res_update = await client.put(
        f"/api/v1/syllabuses/{syllabus_id_str}?school_id={school_id}",
        json={"topic_name": "Advanced Multiplication Property", "sequence_order": 2},
        headers=headers
    )
    assert res_update.status_code == 200
    assert res_update.json()["data"]["topic_name"] == "Advanced Multiplication Property"
    assert res_update.json()["data"]["sequence_order"] == 2

    # 7. Cross-tenant or Cross-school isolation validation (Tenant B tries to access Tenant A's syllabus)
    headers_tenant_b = headers.copy()
    headers_tenant_b["X-Tenant-ID"] = str(data["tenant_b"].id)
    
    res_isolate = await client.get(
        f"/api/v1/syllabuses/{syllabus_id_str}?school_id={str(data['school_b'].id)}",
        headers=headers_tenant_b
    )
    # Since it's scoped, it will not find it (404)
    assert res_isolate.status_code == 404

    # 8. Soft Delete
    res_del = await client.delete(
        f"/api/v1/syllabuses/{syllabus_id_str}?school_id={school_id}",
        headers=headers
    )
    assert res_del.status_code == 200

    # 9. Get details of soft-deleted returns 404
    res_get_deleted = await client.get(
        f"/api/v1/syllabuses/{syllabus_id_str}?school_id={school_id}",
        headers=headers
    )
    assert res_get_deleted.status_code == 404
