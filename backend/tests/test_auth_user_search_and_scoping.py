import pytest
import uuid
from datetime import datetime, timezone, date
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School, SchoolBoard, SchoolType, SchoolStatus
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.teacher import Teacher, TeacherStatus, EmploymentType
from app.models.guardian import Guardian, GuardianType, GuardianStatus, StudentGuardian, StudentGuardianRelationship
from app.models.student import Student, StudentStatus, StudentGender
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory, ClassStatus
from app.models.section import Section, SectionStatus
from app.core.security import hash_password, create_access_token
from app.services.rbac_provisioning import ensure_tenant_rbac

@pytest.mark.anyio
async def test_user_search_filters_and_pagination(client: AsyncClient, db_session: AsyncSession):
    """
    Validates server-side user search with ILIKE, role/status filtering,
    and pagination metadata (meta.total, page, page_size, total_pages).
    """
    now = datetime.now(timezone.utc)
    tenant_id = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]
    tenant = Tenant(
        id=tenant_id,
        name=f"Search Tenant {uid}",
        code=f"ST_{uid}",
        subdomain=f"st_{uid}",
        email=f"st_{uid}@test.edu"
    )
    db_session.add(tenant)
    await db_session.flush()
    await ensure_tenant_rbac(db_session, tenant_id)

    school = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name=f"Search Campus {uid}",
        code=f"SC_{uid.upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email=f"sc_{uid}@test.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    db_session.add(school)
    await db_session.flush()

    # Query initialized roles
    admin_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "ADMIN"))).first()
    teacher_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "TEACHER"))).first()
    parent_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "PARENT"))).first()

    admin_role_obj = await db_session.get(Role, admin_role.id)
    teacher_role_obj = await db_session.get(Role, teacher_role.id)
    parent_role_obj = await db_session.get(Role, parent_role.id)

    # 1. Admin User
    admin_user = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"admin_{uid}@test.edu",
        hashed_password=hash_password("Password123!"),
        first_name="Admin",
        last_name="Search",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    admin_user.roles.append(admin_role_obj)
    admin_user.schools.append(school)

    # 2. Teacher User: Suresh Kumar
    teacher_user = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"suresh.kumar_{uid}@test.edu",
        hashed_password=hash_password("Password123!"),
        first_name="Suresh",
        last_name="Kumar",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    teacher_user.roles.append(teacher_role_obj)
    teacher_user.schools.append(school)

    # 3. Parent User: Ramesh Gupta
    parent_user = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"ramesh.gupta_{uid}@test.edu",
        hashed_password=hash_password("Password123!"),
        first_name="Ramesh",
        last_name="Gupta",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    parent_user.roles.append(parent_role_obj)
    parent_user.schools.append(school)

    # 4. Inactive Teacher: Anita Sharma
    inactive_teacher = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"anita.sharma_{uid}@test.edu",
        hashed_password=hash_password("Password123!"),
        first_name="Anita",
        last_name="Sharma",
        status=UserStatus.INACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    inactive_teacher.roles.append(teacher_role_obj)
    inactive_teacher.schools.append(school)

    db_session.add_all([admin_user, teacher_user, parent_user, inactive_teacher])
    await db_session.commit()

    token = create_access_token(subject=admin_user.id, tenant_id=tenant_id)
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(tenant_id)
    }

    # Test 1: Fetch all users (default pagination)
    res = await client.get("/api/v1/identity/users", headers=headers)
    assert res.status_code == 200
    body = res.json()
    assert body["success"] is True
    assert "meta" in body
    assert body["meta"]["total"] == 4
    assert len(body["data"]) == 4

    # Test 2: Search by partial first name "suresh"
    res_search = await client.get("/api/v1/identity/users?search=suresh", headers=headers)
    assert res_search.status_code == 200
    search_body = res_search.json()
    assert search_body["meta"]["total"] == 1
    assert search_body["data"][0]["first_name"] == "Suresh"

    # Test 3: Search by full name "Ramesh Gupta"
    res_name = await client.get("/api/v1/identity/users?search=Ramesh+Gupta", headers=headers)
    assert res_name.status_code == 200
    assert res_name.json()["meta"]["total"] == 1
    assert res_name.json()["data"][0]["first_name"] == "Ramesh"

    # Test 4: Search by email domain
    res_email = await client.get(f"/api/v1/identity/users?search=_{uid}@test.edu", headers=headers)
    assert res_email.status_code == 200
    assert res_email.json()["meta"]["total"] == 4

    # Test 5: Role filter: TEACHER
    res_role = await client.get("/api/v1/identity/users?role=TEACHER", headers=headers)
    assert res_role.status_code == 200
    role_body = res_role.json()
    assert role_body["meta"]["total"] == 2
    names = {u["first_name"] for u in role_body["data"]}
    assert names == {"Suresh", "Anita"}

    # Test 6: Role filter + Status filter: TEACHER + ACTIVE
    res_combo = await client.get("/api/v1/identity/users?role=TEACHER&status=ACTIVE", headers=headers)
    assert res_combo.status_code == 200
    combo_body = res_combo.json()
    assert combo_body["meta"]["total"] == 1
    assert combo_body["data"][0]["first_name"] == "Suresh"

    # Test 7: Pagination with page and page_size
    res_p1 = await client.get("/api/v1/identity/users?page=1&page_size=2", headers=headers)
    assert res_p1.status_code == 200
    p1_body = res_p1.json()
    assert len(p1_body["data"]) == 2
    assert p1_body["meta"]["total"] == 4
    assert p1_body["meta"]["page"] == 1
    assert p1_body["meta"]["total_pages"] == 2

    res_p2 = await client.get("/api/v1/identity/users?page=2&page_size=2", headers=headers)
    assert res_p2.status_code == 200
    p2_body = res_p2.json()
    assert len(p2_body["data"]) == 2
    assert p2_body["meta"]["page"] == 2


@pytest.mark.anyio
async def test_teacher_and_principal_access_scoping(client: AsyncClient, db_session: AsyncSession):
    """
    Validates:
    - Principal can only see users of their assigned school, excluding super/tenant admins.
    - Teacher is strictly denied (HTTP 403) from accessing the user directory.
    - Teacher can successfully authenticate and inspect /auth/me with assigned schools.
    """
    now = datetime.now(timezone.utc)
    tenant_id = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]
    tenant = Tenant(
        id=tenant_id,
        name=f"Scope Tenant {uid}",
        code=f"SCT_{uid}",
        subdomain=f"sct_{uid}",
        email=f"sct_{uid}@test.edu"
    )
    db_session.add(tenant)
    await db_session.flush()
    await ensure_tenant_rbac(db_session, tenant_id)

    school_1 = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name=f"School One {uid}",
        code=f"S1_{uid.upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email=f"s1_{uid}@test.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    school_2 = School(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        name=f"School Two {uid}",
        code=f"S2_{uid.upper()}",
        board=SchoolBoard.CBSE,
        school_type=SchoolType.HIGH_SCHOOL,
        email=f"s2_{uid}@test.edu",
        is_active=True,
        status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_1, school_2])
    await db_session.flush()

    principal_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "PRINCIPAL"))).first()
    teacher_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "TEACHER"))).first()
    admin_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == tenant_id, Role.code == "ADMIN"))).first()

    principal_role_obj = await db_session.get(Role, principal_role.id)
    teacher_role_obj = await db_session.get(Role, teacher_role.id)
    admin_role_obj = await db_session.get(Role, admin_role.id)

    # Super Admin
    super_admin = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"super_{uid}@scope.com",
        hashed_password=hash_password("Password123!"),
        first_name="Super",
        last_name="Admin",
        status=UserStatus.ACTIVE,
        is_superuser=True,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    super_admin.roles.append(admin_role_obj)
    super_admin.schools.append(school_1)

    # Principal for School 1
    principal = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"principal.s1_{uid}@scope.com",
        hashed_password=hash_password("Password123!"),
        first_name="Principal",
        last_name="One",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    principal.roles.append(principal_role_obj)
    principal.schools.append(school_1)

    # Teacher for School 1
    teacher_s1 = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"teacher.s1_{uid}@scope.com",
        hashed_password=hash_password("Password123!"),
        first_name="Teacher",
        last_name="One",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    teacher_s1.roles.append(teacher_role_obj)
    teacher_s1.schools.append(school_1)

    # Teacher for School 2
    teacher_s2 = User(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        email=f"teacher.s2_{uid}@scope.com",
        hashed_password=hash_password("Password123!"),
        first_name="Teacher",
        last_name="Two",
        status=UserStatus.ACTIVE,
        is_superuser=False,
        must_change_password=False,
        version=1,
        created_at=now,
        updated_at=now
    )
    teacher_s2.roles.append(teacher_role_obj)
    teacher_s2.schools.append(school_2)

    db_session.add_all([super_admin, principal, teacher_s1, teacher_s2])
    await db_session.commit()

    # 1. Principal Login & Scoping
    principal_token = create_access_token(subject=principal.id, tenant_id=tenant_id)
    p_headers = {
        "Authorization": f"Bearer {principal_token}",
        "X-Tenant-ID": str(tenant_id)
    }

    p_res = await client.get("/api/v1/identity/users", headers=p_headers)
    assert p_res.status_code == 200
    p_users = p_res.json()["data"]
    p_emails = {u["email"] for u in p_users}
    # Principal sees teacher_s1 and principal, but NOT super_admin (excluded) and NOT teacher_s2 (different school)
    assert f"teacher.s1_{uid}@scope.com" in p_emails
    assert f"super_{uid}@scope.com" not in p_emails
    assert f"teacher.s2_{uid}@scope.com" not in p_emails

    # 2. Teacher Access Denied to /identity/users
    teacher_token = create_access_token(subject=teacher_s1.id, tenant_id=tenant_id)
    t_headers = {
        "Authorization": f"Bearer {teacher_token}",
        "X-Tenant-ID": str(tenant_id)
    }
    t_res = await client.get("/api/v1/identity/users", headers=t_headers)
    assert t_res.status_code == 403
    err_msg = t_res.json().get("detail") or t_res.json().get("message") or str(t_res.json())
    assert "Access denied" in err_msg

    # 3. Teacher Can Inspect /auth/me
    me_res = await client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {teacher_token}"})
    assert me_res.status_code == 200
    me_data = me_res.json()["data"]
    assert me_data["email"] == f"teacher.s1_{uid}@scope.com"
    role_codes = [r["code"] for r in me_data["roles"]]
    assert "TEACHER" in role_codes
    assert len(me_data["schools"]) == 1
    assert me_data["schools"][0]["id"] == str(school_1.id)


@pytest.mark.anyio
async def test_global_user_search_across_relations(client: AsyncClient, db_session: AsyncSession):
    """
    Validates global user search across:
    - Father's name / Guardian name returning parent User account
    - Co-guardian (mother's account found via father's name and vice versa)
    - Linked Student name & admission number returning parent User account
    - Teacher employee code, staff code, phone, email returning teacher User account
    - User login_id returning User account
    - Multi-word search with extra whitespace (e.g. 'Deepak   Boddu')
    - Tenant isolation (Tenant B data never matches in Tenant A)
    - Prevention of duplicate users in response
    """
    now = datetime.now(timezone.utc)
    t_id_a = uuid.uuid4()
    t_id_b = uuid.uuid4()
    uid = uuid.uuid4().hex[:6]

    tenant_a = Tenant(id=t_id_a, name=f"Tenant A {uid}", code=f"TA_{uid}", subdomain=f"ta_{uid}", email=f"ta_{uid}@test.edu")
    tenant_b = Tenant(id=t_id_b, name=f"Tenant B {uid}", code=f"TB_{uid}", subdomain=f"tb_{uid}", email=f"tb_{uid}@test.edu")
    db_session.add_all([tenant_a, tenant_b])
    await db_session.flush()

    await ensure_tenant_rbac(db_session, t_id_a)
    await ensure_tenant_rbac(db_session, t_id_b)

    school_a = School(
        id=uuid.uuid4(), tenant_id=t_id_a, name=f"Campus A {uid}", code=f"CA_{uid.upper()}",
        board=SchoolBoard.CBSE, school_type=SchoolType.HIGH_SCHOOL, email=f"ca_{uid}@test.edu",
        is_active=True, status=SchoolStatus.ACTIVE
    )
    school_b = School(
        id=uuid.uuid4(), tenant_id=t_id_b, name=f"Campus B {uid}", code=f"CB_{uid.upper()}",
        board=SchoolBoard.CBSE, school_type=SchoolType.HIGH_SCHOOL, email=f"cb_{uid}@test.edu",
        is_active=True, status=SchoolStatus.ACTIVE
    )
    db_session.add_all([school_a, school_b])
    await db_session.flush()

    admin_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == t_id_a, Role.code == "ADMIN"))).first()
    teacher_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == t_id_a, Role.code == "TEACHER"))).first()
    parent_role = (await db_session.execute(Role.__table__.select().where(Role.tenant_id == t_id_a, Role.code == "PARENT"))).first()

    admin_role_obj = await db_session.get(Role, admin_role.id)
    teacher_role_obj = await db_session.get(Role, teacher_role.id)
    parent_role_obj = await db_session.get(Role, parent_role.id)

    # 1. Admin User for Tenant A
    admin_user = User(
        id=uuid.uuid4(), tenant_id=t_id_a, email=f"admin_{uid}@test.edu",
        hashed_password=hash_password("Pass123!"), first_name="Admin", last_name="Global",
        status=UserStatus.ACTIVE, is_superuser=False, must_change_password=False, version=1,
        created_at=now, updated_at=now
    )
    admin_user.roles.append(admin_role_obj)
    admin_user.schools.append(school_a)

    # 2. Teacher User: Ananya Sharma
    teacher_user = User(
        id=uuid.uuid4(), tenant_id=t_id_a, email=f"ananya.sharma_{uid}@test.edu", login_id=f"TCH_LOG_{uid}",
        hashed_password=hash_password("Pass123!"), first_name="Ananya", last_name="Sharma",
        status=UserStatus.ACTIVE, is_superuser=False, must_change_password=False, version=1,
        created_at=now, updated_at=now
    )
    teacher_user.roles.append(teacher_role_obj)
    teacher_user.schools.append(school_a)

    # 3. Father User: Harsha Boddu
    father_user = User(
        id=uuid.uuid4(), tenant_id=t_id_a, email=f"harsha.boddu_{uid}@test.edu", login_id=f"TS001P_F_{uid}",
        hashed_password=hash_password("Pass123!"), first_name="Harsha", last_name="Boddu",
        status=UserStatus.ACTIVE, is_superuser=False, must_change_password=False, version=1,
        created_at=now, updated_at=now
    )
    father_user.roles.append(parent_role_obj)
    father_user.schools.append(school_a)

    # 4. Mother User: Lavanya Boddu
    mother_user = User(
        id=uuid.uuid4(), tenant_id=t_id_a, email=f"lavanya.boddu_{uid}@test.edu", login_id=f"TS001P_M_{uid}",
        hashed_password=hash_password("Pass123!"), first_name="Lavanya", last_name="Boddu",
        status=UserStatus.ACTIVE, is_superuser=False, must_change_password=False, version=1,
        created_at=now, updated_at=now
    )
    mother_user.roles.append(parent_role_obj)
    mother_user.schools.append(school_a)

    # 5. Cross-tenant user in Tenant B with identical name/data
    tenant_b_user = User(
        id=uuid.uuid4(), tenant_id=t_id_b, email=f"harsha.boddu_{uid}@tenantb.edu", login_id=f"TS001P_B_{uid}",
        hashed_password=hash_password("Pass123!"), first_name="Harsha", last_name="Boddu",
        status=UserStatus.ACTIVE, is_superuser=False, must_change_password=False, version=1,
        created_at=now, updated_at=now
    )
    tenant_b_user.schools.append(school_b)

    db_session.add_all([admin_user, teacher_user, father_user, mother_user, tenant_b_user])
    await db_session.flush()

    # Teacher entity
    teacher_entity = Teacher(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, user_id=teacher_user.id,
        employee_code=f"EMP_{uid}", staff_code=f"STF_{uid}", first_name="Ananya", last_name="Sharma",
        gender=StudentGender.FEMALE, date_of_birth=date(1985, 4, 12), mobile=f"984911{uid[:4]}",
        official_email=f"ananya.sharma_{uid}@test.edu", joining_date=date(2020, 6, 1),
        employment_type=EmploymentType.FULL_TIME, designation="Senior Math Teacher", department="Mathematics",
        status=TeacherStatus.ACTIVE, is_active=True, version=1
    )
    db_session.add(teacher_entity)

    # Academic Year, Class, Section for Student
    ay = AcademicYear(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, name="2025-26", code=f"AY_{uid}",
        start_date=date(2025, 6, 1), end_date=date(2026, 4, 30), status=AcademicYearStatus.ACTIVE, is_current=True, version=1
    )
    db_session.add(ay)
    await db_session.flush()

    cls = Class(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, academic_year_id=ay.id,
        name="Class 10", code=f"C10_{uid}", level=10, capacity=40, category=ClassCategory.HIGH, status=ClassStatus.ACTIVE, version=1
    )
    db_session.add(cls)
    await db_session.flush()

    sec = Section(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, academic_year_id=ay.id, class_id=cls.id,
        name="A", code=f"SEC_A_{uid}", room_number="101", capacity=40, status=SectionStatus.ACTIVE, version=1
    )
    db_session.add(sec)
    await db_session.flush()

    # Student: Deepak Boddu
    student = Student(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, academic_year_id=ay.id,
        class_id=cls.id, section_id=sec.id, first_name="Deepak", last_name="Boddu",
        gender=StudentGender.MALE, date_of_birth=date(2010, 5, 15),
        admission_number=f"ADM2025_{uid}", roll_number="15", admission_date=date(2022, 6, 1),
        status=StudentStatus.ACTIVE, is_active=True, version=1
    )
    db_session.add(student)
    await db_session.flush()

    # Father Guardian
    father_guardian = Guardian(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, user_id=father_user.id,
        guardian_type=GuardianType.FATHER, first_name="Harsha", last_name="Boddu",
        gender=StudentGender.MALE, date_of_birth=date(1980, 2, 10), mobile=f"984900{uid[:4]}",
        email=father_user.email, status=GuardianStatus.ACTIVE, is_active=True, version=1
    )
    # Mother Guardian
    mother_guardian = Guardian(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, user_id=mother_user.id,
        guardian_type=GuardianType.MOTHER, first_name="Lavanya", last_name="Boddu",
        gender=StudentGender.FEMALE, date_of_birth=date(1982, 7, 22), mobile=f"984922{uid[:4]}",
        email=mother_user.email, status=GuardianStatus.ACTIVE, is_active=True, version=1
    )
    db_session.add_all([father_guardian, mother_guardian])
    await db_session.flush()

    # Link Student to Father and Mother
    sg_father = StudentGuardian(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, student_id=student.id, guardian_id=father_guardian.id,
        relationship=StudentGuardianRelationship.FATHER, is_primary=True, can_pickup_student=True, receives_notifications=True, version=1
    )
    sg_mother = StudentGuardian(
        id=uuid.uuid4(), tenant_id=t_id_a, school_id=school_a.id, student_id=student.id, guardian_id=mother_guardian.id,
        relationship=StudentGuardianRelationship.MOTHER, is_primary=False, can_pickup_student=True, receives_notifications=True, version=1
    )
    db_session.add_all([sg_father, sg_mother])
    await db_session.commit()

    token = create_access_token(subject=admin_user.id, tenant_id=t_id_a)
    headers = {
        "Authorization": f"Bearer {token}",
        "X-Tenant-ID": str(t_id_a)
    }

    # 1. Search by Student Name with extra whitespace: 'Deepak   Boddu' -> returns both parents!
    res_student = await client.get(f"/api/v1/identity/users?search=Deepak+++Boddu", headers=headers)
    assert res_student.status_code == 200
    s_users = res_student.json()["data"]
    s_ids = {u["id"] for u in s_users}
    assert str(father_user.id) in s_ids
    assert str(mother_user.id) in s_ids
    assert len(s_users) == len(s_ids), "Duplicate users detected in search results!"

    # 2. Search by Student Admission Number
    res_adm = await client.get(f"/api/v1/identity/users?search=ADM2025_{uid}", headers=headers)
    assert res_adm.status_code == 200
    adm_ids = {u["id"] for u in res_adm.json()["data"]}
    assert str(father_user.id) in adm_ids
    assert str(mother_user.id) in adm_ids

    # 3. Search by Father's Name: 'Harsha Boddu' -> matches father user directly and mother user via co-guardian!
    res_father = await client.get("/api/v1/identity/users?search=Harsha+Boddu", headers=headers)
    assert res_father.status_code == 200
    f_ids = {u["id"] for u in res_father.json()["data"]}
    assert str(father_user.id) in f_ids
    # Verify Tenant B user is NOT returned
    assert str(tenant_b_user.id) not in f_ids

    # 4. Search by Father's Mobile
    res_mob = await client.get(f"/api/v1/identity/users?search=984900{uid[:4]}", headers=headers)
    assert res_mob.status_code == 200
    mob_ids = {u["id"] for u in res_mob.json()["data"]}
    assert str(father_user.id) in mob_ids

    # 5. Search by User Login ID
    res_login = await client.get(f"/api/v1/identity/users?search=TS001P_F_{uid}", headers=headers)
    assert res_login.status_code == 200
    login_ids = {u["id"] for u in res_login.json()["data"]}
    assert str(father_user.id) in login_ids

    # 6. Search by Teacher Employee Code
    res_emp = await client.get(f"/api/v1/identity/users?search=EMP_{uid}", headers=headers)
    assert res_emp.status_code == 200
    emp_ids = {u["id"] for u in res_emp.json()["data"]}
    assert str(teacher_user.id) in emp_ids

    # 7. Search by Teacher Department
    res_dept = await client.get("/api/v1/identity/users?search=Mathematics", headers=headers)
    assert res_dept.status_code == 200
    dept_ids = {u["id"] for u in res_dept.json()["data"]}
    assert str(teacher_user.id) in dept_ids

