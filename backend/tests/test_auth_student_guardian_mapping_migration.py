import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student
from app.models.guardian import Guardian, GuardianStatus, GuardianType, StudentGuardian, StudentGuardianRelationship
from app.models.student_guardian_import import StudentGuardianImportRow
from app.core.security import create_access_token

@pytest.fixture
async def setup_mapping_migration_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenant & Schools
    tenant_a = Tenant(name="Tenant A", code=f"tenant-a-{suffix}", subdomain=f"sub-a-{suffix}", email=f"a-{suffix}@t.com")
    tenant_b = Tenant(name="Tenant B", code=f"tenant-b-{suffix}", subdomain=f"sub-b-{suffix}", email=f"b-{suffix}@t.com")
    db_session.add_all([tenant_a, tenant_b])
    await db_session.flush()

    school_a = School(tenant_id=tenant_a.id, name="School A", code=f"sch-a-{suffix}", email=f"sch-a-{suffix}@t.com", board="CBSE")
    school_c = School(tenant_id=tenant_b.id, name="School C", code=f"sch-c-{suffix}", email=f"sch-c-{suffix}@t.com", board="CBSE")
    db_session.add_all([school_a, school_c])
    await db_session.flush()

    # 2. Setup permissions
    perm_codes = ["migration.read", "migration.create", "migration.execute", "migration.cancel"]
    permissions = {}
    for code in perm_codes:
        stmt = select(Permission).where(Permission.code == code)
        res = await db_session.execute(stmt)
        p = res.scalar_one_or_none()
        if not p:
            p = Permission(name=code.replace(".", " ").title(), code=code, description=f"Permission for {code}")
            db_session.add(p)
            await db_session.flush()
        permissions[code] = p

    # 3. Setup Roles
    principal_role_a = Role(tenant_id=tenant_a.id, name="Principal", code="PRINCIPAL", permissions=list(permissions.values()))
    principal_role_b = Role(tenant_id=tenant_b.id, name="Principal B", code="PRINCIPAL", permissions=list(permissions.values()))
    db_session.add_all([principal_role_a, principal_role_b])
    await db_session.flush()

    # 4. Setup Users
    principal_user = User(tenant_id=tenant_a.id, email=f"principal-{suffix}@edupulse.com", first_name="Pr", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[principal_role_a], schools=[school_a])
    tenant_b_user = User(tenant_id=tenant_b.id, email=f"principal-b-{suffix}@edupulse.com", first_name="B", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[principal_role_b], schools=[school_c])
    db_session.add_all([principal_user, tenant_b_user])
    await db_session.flush()

    # 5. Setup AcademicYear, Class, Section under Tenant A / School A
    ay = AcademicYear(tenant_id=tenant_a.id, school_id=school_a.id, name="2026-2027", code=f"ay-{suffix}", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30))
    db_session.add(ay)
    await db_session.flush()

    cls = Class(tenant_id=tenant_a.id, school_id=school_a.id, name="Class 1", code=f"c1-{suffix}", capacity=30, academic_year_id=ay.id, level=1)
    db_session.add(cls)
    await db_session.flush()

    sec = Section(tenant_id=tenant_a.id, school_id=school_a.id, name="Section A", code=f"sa-{suffix}", capacity=30, class_id=cls.id, academic_year_id=ay.id)
    db_session.add(sec)
    await db_session.flush()

    # 6. Setup Student under Tenant A
    student = Student(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=cls.id,
        section_id=sec.id,
        first_name="John",
        last_name="Doe",
        gender="MALE",
        date_of_birth=date(2018, 5, 10),
        admission_number="STU_001",
        roll_number="1",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(student)

    # Setup Tenant B Student (isolation verification)
    ay_b = AcademicYear(tenant_id=tenant_b.id, school_id=school_c.id, name="2026-2027", code=f"ay-b-{suffix}", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30))
    db_session.add(ay_b)
    await db_session.flush()

    cls_b = Class(tenant_id=tenant_b.id, school_id=school_c.id, name="Class 1", code=f"c1-b-{suffix}", capacity=30, academic_year_id=ay_b.id, level=1)
    db_session.add(cls_b)
    await db_session.flush()

    sec_b = Section(tenant_id=tenant_b.id, school_id=school_c.id, name="Section A", code=f"sa-b-{suffix}", capacity=30, class_id=cls_b.id, academic_year_id=ay_b.id)
    db_session.add(sec_b)
    await db_session.flush()

    student_b = Student(
        tenant_id=tenant_b.id,
        school_id=school_c.id,
        academic_year_id=ay_b.id,
        class_id=cls_b.id,
        section_id=sec_b.id,
        first_name="Jane",
        last_name="B",
        gender="FEMALE",
        date_of_birth=date(2018, 5, 10),
        admission_number="STU_B01",
        roll_number="1",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(student_b)
    await db_session.flush()

    # 7. Setup active, soft-deleted, and existing mapping guardians
    g1 = Guardian(
        tenant_id=tenant_a.id, school_id=school_a.id, guardian_type=GuardianType.FATHER,
        first_name="John", last_name="Doe", gender="MALE", date_of_birth=date(1985, 1, 1),
        mobile="9876543201", email="john.doe@test.com", status=GuardianStatus.ACTIVE, is_active=True
    )
    g2 = Guardian(
        tenant_id=tenant_a.id, school_id=school_a.id, guardian_type=GuardianType.MOTHER,
        first_name="Mary", last_name="Doe", gender="FEMALE", date_of_birth=date(1987, 6, 1),
        mobile="9876543202", email="mary.doe@test.com", status=GuardianStatus.ACTIVE, is_active=True
    )
    g3 = Guardian(
        tenant_id=tenant_a.id, school_id=school_a.id, guardian_type=GuardianType.MOTHER,
        first_name="Grand", last_name="Parent", gender="FEMALE", date_of_birth=date(1960, 1, 1),
        mobile="9876543205", email="grand@test.com", status=GuardianStatus.ACTIVE, is_active=True
    )
    g_soft = Guardian(
        tenant_id=tenant_a.id, school_id=school_a.id, guardian_type=GuardianType.LEGAL_GUARDIAN,
        first_name="Soft", last_name="Deleted", gender="MALE", date_of_birth=date(1980, 1, 1),
        mobile="9876543203", email="soft@test.com", status=GuardianStatus.INACTIVE, is_active=False,
        deleted_at=datetime.now(timezone.utc)
    )
    db_session.add_all([g1, g2, g3, g_soft])
    await db_session.flush()

    # Existing relationship mapping in database (between STU_001 and g1)
    existing_map = StudentGuardian(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        student_id=student.id,
        guardian_id=g1.id,
        relationship=StudentGuardianRelationship.FATHER,
        is_primary=True,
        can_pickup_student=True,
        receives_notifications=True
    )
    db_session.add(existing_map)
    await db_session.flush()

    # 8. Auth Headers
    p_token = create_access_token(subject=principal_user.id, tenant_id=tenant_a.id)
    tb_token = create_access_token(subject=tenant_b_user.id, tenant_id=tenant_b.id)

    p_headers = {"Authorization": f"Bearer {p_token}", "X-Tenant-ID": str(tenant_a.id), "X-School-ID": str(school_a.id)}
    tb_headers = {"Authorization": f"Bearer {tb_token}", "X-Tenant-ID": str(tenant_b.id), "X-School-ID": str(school_c.id)}

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_c": school_c,
        "student": student,
        "student_b": student_b,
        "g1": g1,
        "g2": g2,
        "g_soft": g_soft,
        "existing_map": existing_map,
        "p_headers": p_headers,
        "tb_headers": tb_headers
    }

@pytest.mark.anyio
async def test_validate_mapping_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    g2 = data["g2"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_success.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Upload and validate
    # Mapping STU_001 to g2 (since g1 is already mapped in DB, matching g1 would raise MAPPING_ALREADY_EXISTS)
    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary,can_pickup_student,receives_notifications\n"
        f"STU_001,{g2.mobile},MOTHER,false,true,true\n"
    ).encode("utf-8")

    # Capture database count before validation to prove non-destructive nature
    stmt_count = select(func.count(StudentGuardian.id))
    count_before = (await db_session.execute(stmt_count)).scalar()

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_success.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["status"] == "VALIDATED"
    assert res_data["total_rows"] == 1
    assert res_data["successful_rows"] == 1
    assert res_data["failed_rows"] == 0

    # Prove no mappings were created in database
    count_after = (await db_session.execute(stmt_count)).scalar()
    assert count_before == count_after

    # Verify staging rows inserted
    stmt_staged = select(StudentGuardianImportRow).where(StudentGuardianImportRow.import_job_id == uuid.UUID(job_id))
    res_staged = await db_session.execute(stmt_staged)
    staged = res_staged.scalars().all()
    assert len(staged) == 1
    assert staged[0].validation_status == "valid"
    assert staged[0].resolved_student_id == data["student"].id
    assert staged[0].resolved_guardian_id == g2.id

    # Verify ImportJobRow audit entries
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id))
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert len(audits) == 1
    assert audits[0].status == "success"

@pytest.mark.anyio
async def test_validate_mapping_missing_headers(
    client: AsyncClient,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_missing_headers.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Missing mandatory 'relationship' column header
    csv_content = (
        "student_admission_number,guardian_id\n"
        "STU_001,9876543201\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_missing_headers.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 422
    assert "Missing required CSV column headers" in res_val.json()["message"]

@pytest.mark.anyio
async def test_validate_mapping_validation_failures(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    g1 = data["g1"]
    g_soft = data["g_soft"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_errors.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Rows details:
    # Row 1: Missing required field (student_admission_number blank)
    # Row 2: Invalid relationship type
    # Row 3: Student not found
    # Row 4: Guardian not found
    # Row 5: Duplicate CSV mapping
    # Row 6: Duplicate CSV mapping (part of duplicate tracking check)
    # Row 7: Mapping already exists in DB (STU_001 already mapped to g1 in setup)
    # Row 8: Primary guardian limit exceeded (STU_001 already has primary mapping to g1 in DB, mapping to g2 with is_primary=true fails)
    # Row 9: Guardian is soft-deleted
    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary\n"
        f",9876543201,FATHER,false\n"
        f"STU_001,9876543201,INVALID_RELATIONSHIP,false\n"
        f"NON_EXISTENT_STU,9876543201,FATHER,false\n"
        f"STU_001,9876543299,FATHER,false\n"
        f"STU_001,9876543202,MOTHER,false\n"
        f"STU_001,9876543202,MOTHER,false\n"
        f"STU_001,{g1.mobile},FATHER,false\n"
        f"STU_001,9876543205,MOTHER,true\n"
        f"STU_001,{g_soft.mobile},GUARDIAN,false\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_errors.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["total_rows"] == 9
    assert res_data["failed_rows"] == 8
    assert res_data["successful_rows"] == 1

    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number)
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()

    assert audits[0].error_code == "MISSING_REQUIRED_FIELD"
    assert audits[1].error_code == "INVALID_RELATIONSHIP_TYPE"
    assert audits[2].error_code == "STUDENT_NOT_FOUND"
    assert audits[3].error_code == "GUARDIAN_NOT_FOUND"
    assert audits[4].status == "success" or audits[4].error_code == "DUPLICATE_ROW"  # Row 5 (the first of the duplicate pair)
    assert audits[5].error_code == "DUPLICATE_ROW"  # Row 6 (second of duplicate pair)
    assert audits[6].error_code == "MAPPING_ALREADY_EXISTS"
    assert audits[7].error_code == "PRIMARY_GUARDIAN_LIMIT_EXCEEDED"
    assert audits[8].error_code == "GUARDIAN_NOT_FOUND"  # Soft-deleted guardian behaves as not found

@pytest.mark.anyio
async def test_validate_mapping_tenant_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    tb_headers = data["tb_headers"]
    school_c = data["school_c"]

    # Tenant B tries to map Tenant A's student STU_001
    job_in = {
        "school_id": str(school_c.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_isolation.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=tb_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary\n"
        "STU_001,9876543201,FATHER,false\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_isolation.csv", csv_content, "text/csv")},
        headers=tb_headers
    )
    assert res_val.status_code == 200
    assert res_val.json()["data"]["failed_rows"] == 1

    # Should report STUDENT_NOT_FOUND because STU_001 belongs to Tenant A
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id))
    res_db = await db_session.execute(stmt_audits)
    audits = res_db.scalars().all()
    assert len(audits) == 1
    assert audits[0].error_code == "STUDENT_NOT_FOUND"


@pytest.mark.anyio
async def test_validate_mapping_utf8_bom_and_blanks(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    g2 = data["g2"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_bom.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Write content starting with UTF-8 BOM, including headers casing with spaces, and trailing empty lines
    csv_content = (
        " student_admission_number , guardian_id , relationship , is_primary \n"
        f"STU_001,{g2.mobile},MOTHER,false\n"
        ",,,\n"
        "  ,  ,  ,  \n"
    ).encode("utf-8-sig")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_bom.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["total_rows"] == 1  # Blanks skipped, only 1 valid row
    assert res_data["successful_rows"] == 1
    assert res_data["failed_rows"] == 0


@pytest.mark.anyio
async def test_execute_mapping_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    g2 = data["g2"]
    student = data["student"]

    # Create & validate job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_exec.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary,can_pickup_student,receives_notifications\n"
        f"STU_001,{g2.mobile},MOTHER,false,true,true\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_exec.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Execute
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED"
    assert res_data["processed_rows"] == 1
    assert res_data["successful_rows"] == 1
    assert res_data["failed_rows"] == 0
    assert res_data["skipped_rows"] == 0

    # Verify staging updated
    stmt_staged = select(StudentGuardianImportRow).where(StudentGuardianImportRow.import_job_id == uuid.UUID(job_id))
    res_staged = await db_session.execute(stmt_staged)
    staged = res_staged.scalars().all()
    assert len(staged) == 1
    assert staged[0].validation_status == "executed"
    assert staged[0].created_mapping_id is not None

    # Verify audit row
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id))
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert len(audits) == 1
    assert audits[0].status == "success"
    assert audits[0].entity_id == staged[0].created_mapping_id

    # Verify mapping in database
    stmt_map = select(StudentGuardian).where(StudentGuardian.id == staged[0].created_mapping_id)
    res_map = await db_session.execute(stmt_map)
    mapping = res_map.scalar_one_or_none()
    assert mapping is not None
    assert mapping.student_id == student.id
    assert mapping.guardian_id == g2.id
    assert mapping.relationship == StudentGuardianRelationship.MOTHER
    assert mapping.is_primary is False
    assert mapping.can_pickup_student is True
    assert mapping.receives_notifications is True


@pytest.mark.anyio
async def test_execute_mapping_primary_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_c = data["school_c"]
    tb_headers = data["tb_headers"]
    
    # Create Tenant B Guardian
    suffix = uuid.uuid4().hex[:6]
    g_b = Guardian(
        tenant_id=data["tenant_b"].id, school_id=school_c.id, guardian_type=GuardianType.FATHER,
        first_name="JaneFather", last_name="B", gender="MALE", date_of_birth=date(1985, 1, 1),
        mobile=f"9000000{suffix}", email=f"father-{suffix}@t.com", status=GuardianStatus.ACTIVE, is_active=True
    )
    db_session.add(g_b)
    await db_session.commit()

    # Create & validate job
    job_in = {
        "school_id": str(school_c.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_prim.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=tb_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary\n"
        f"STU_B01,{g_b.mobile},FATHER,true\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_prim.csv", csv_content, "text/csv")},
        headers=tb_headers
    )

    # Execute
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=tb_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED"
    assert res_data["successful_rows"] == 1

    # Verify primary flag in DB
    stmt_map = select(StudentGuardian).where(StudentGuardian.student_id == data["student_b"].id)
    res_map = await db_session.execute(stmt_map)
    mapping = res_map.scalar_one_or_none()
    assert mapping is not None
    assert mapping.is_primary is True


@pytest.mark.anyio
async def test_execute_mapping_failures_and_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    g1 = data["g1"]
    g2 = data["g2"]

    # Create temporary student records
    student_temp = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=data["student"].academic_year_id,
        class_id=data["student"].class_id,
        section_id=data["student"].section_id,
        first_name="Temp", last_name="Student", gender="MALE", date_of_birth=date(2018, 5, 10),
        admission_number="STU_TEMP", roll_number="10", admission_date=date(2026, 6, 1)
    )
    student_no_primary = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=data["student"].academic_year_id,
        class_id=data["student"].class_id,
        section_id=data["student"].section_id,
        first_name="No", last_name="Primary", gender="MALE", date_of_birth=date(2018, 5, 10),
        admission_number="STU_NO_PRIMARY", roll_number="11", admission_date=date(2026, 6, 1)
    )
    db_session.add_all([student_temp, student_no_primary])

    # We will soft-delete g_temp after validation
    suffix = uuid.uuid4().hex[:6]
    g_temp = Guardian(
        tenant_id=data["tenant_a"].id, school_id=school_a.id, guardian_type=GuardianType.OTHER,
        first_name="Temp", last_name="G", gender="FEMALE", date_of_birth=date(1990, 1, 1),
        mobile=f"9555550{suffix}", email=f"temp-{suffix}@t.com", status=GuardianStatus.ACTIVE, is_active=True
    )
    db_session.add(g_temp)
    await db_session.commit()

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_mixed.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary\n"
        f"STU_TEMP,{g2.mobile},MOTHER,false\n"  # Will be soft-deleted before execute -> STUDENT_NOT_FOUND
        f"STU_001,{g_temp.mobile},OTHER,false\n"  # Will be soft-deleted before execute -> GUARDIAN_NOT_FOUND
        f"STU_001,{g2.mobile},MOTHER,false\n"  # Direct insert mapping in DB before execute -> MAPPING_ALREADY_EXISTS
        f"STU_NO_PRIMARY,{g2.mobile},MOTHER,true\n"  # Direct primary mapping to g1 in DB before execute -> PRIMARY_GUARDIAN_LIMIT_EXCEEDED
        f"STU_001,,MOTHER,false\n"  # Validation-invalid (skipped)
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_mixed.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # 1. Soft-delete student_temp in DB
    student_temp.deleted_at = datetime.now(timezone.utc)
    db_session.add(student_temp)

    # 2. Soft-delete g_temp in DB
    g_temp.deleted_at = datetime.now(timezone.utc)
    g_temp.status = GuardianStatus.INACTIVE
    g_temp.is_active = False
    db_session.add(g_temp)

    # 3. Create mapping STU_001 <-> g2 in DB
    m1 = StudentGuardian(
        tenant_id=data["tenant_a"].id, school_id=school_a.id,
        student_id=data["student"].id, guardian_id=g2.id,
        relationship=StudentGuardianRelationship.MOTHER, is_primary=False
    )
    db_session.add(m1)

    # 4. Create primary mapping for STU_NO_PRIMARY <-> g1 in DB
    m2 = StudentGuardian(
        tenant_id=data["tenant_a"].id, school_id=school_a.id,
        student_id=student_no_primary.id, guardian_id=g1.id,
        relationship=StudentGuardianRelationship.FATHER, is_primary=True
    )
    db_session.add(m2)
    await db_session.commit()

    # Execute
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED_WITH_ERRORS"
    assert res_data["processed_rows"] == 4  # 4 valid rows attempted
    assert res_data["successful_rows"] == 0
    assert res_data["failed_rows"] == 4
    assert res_data["skipped_rows"] == 1

    # Verify audit codes
    stmt_audits = select(ImportJobRow).where(
        and_(ImportJobRow.import_job_id == uuid.UUID(job_id), ImportJobRow.status == "failed")
    ).order_by(ImportJobRow.row_number)
    res_audits = await db_session.execute(stmt_audits)
    failed_audits = res_audits.scalars().all()
    
    assert failed_audits[0].error_code == "STUDENT_NOT_FOUND"
    assert failed_audits[1].error_code == "GUARDIAN_NOT_FOUND"
    assert failed_audits[2].error_code == "MAPPING_ALREADY_EXISTS"
    assert failed_audits[3].error_code == "PRIMARY_GUARDIAN_LIMIT_EXCEEDED"


@pytest.mark.anyio
async def test_execute_mapping_chunk_and_protection(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    
    # Create 105 active guardians and write them to CSV
    guardians = []
    suffix = uuid.uuid4().hex[:4]
    for i in range(105):
        g = Guardian(
            tenant_id=data["tenant_a"].id, school_id=school_a.id, guardian_type=GuardianType.OTHER,
            first_name=f"Guard{i}", last_name="M", gender="FEMALE", date_of_birth=date(1990, 1, 1),
            mobile=f"9000{suffix}{i:03d}", email=f"g{i}-{suffix}@t.com", status=GuardianStatus.ACTIVE, is_active=True
        )
        guardians.append(g)
        db_session.add(g)
    await db_session.commit()

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_105.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_rows = ["student_admission_number,guardian_id,relationship,is_primary"]
    for g in guardians:
        csv_rows.append(f"STU_001,{g.mobile},OTHER,false")
    csv_content = "\n".join(csv_rows).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_105.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Execute
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED"
    assert res_data["processed_rows"] == 105
    assert res_data["successful_rows"] == 105

    # Try executing again (terminal state protection)
    res_exec_again = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec_again.status_code == 400
    assert "Import job must be in VALIDATED state" in res_exec_again.json()["message"]


@pytest.mark.anyio
async def test_execute_mapping_fatal_failure(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_mapping_migration_data: dict
):
    data = setup_mapping_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    g2 = data["g2"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIAN_MAPPING",
        "source_filename": "mapping_fatal.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "student_admission_number,guardian_id,relationship,is_primary\n"
        f"STU_001,{g2.mobile},MOTHER,false\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("mapping_fatal.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Cause database commit to fail dramatically by patching the select call conditionally
    from unittest.mock import patch
    original_select = select
    def mock_select(*args, **kwargs):
        if len(args) > 0 and args[0] is StudentGuardianImportRow:
            raise Exception("Simulated DB Fatal Error")
        return original_select(*args, **kwargs)

    with pytest.raises(Exception) as exc_info:
        with patch("app.services.import_job.select", side_effect=mock_select):
            await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert "Simulated DB Fatal Error" in str(exc_info.value)

    # Verify status is FAILED in the DB
    stmt = select(ImportJob).where(ImportJob.id == uuid.UUID(job_id))
    res = await db_session.execute(stmt)
    job = res.scalar_one()
    assert job.status == ImportJobStatus.FAILED
    assert "Simulated DB Fatal Error" in job.error_summary
