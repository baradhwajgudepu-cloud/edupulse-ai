import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.user import User, UserStatus
from app.models.role import Role
from app.models.permission import Permission
from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.models.academic_setup_import import AcademicSetupImportRow
from app.core.security import create_access_token

@pytest.fixture
async def setup_setup_migration_data(db_session: AsyncSession):
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

    # 2. Setup standard migration permissions
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

    # 3. Setup Roles per Tenant A and Tenant B
    principal_role_a = Role(tenant_id=tenant_a.id, name="Principal", code="PRINCIPAL", permissions=list(permissions.values()))
    teacher_role_a = Role(tenant_id=tenant_a.id, name="Teacher", code="TEACHER")
    principal_role_b = Role(tenant_id=tenant_b.id, name="Principal B", code="PRINCIPAL", permissions=list(permissions.values()))
    
    db_session.add_all([principal_role_a, teacher_role_a, principal_role_b])
    await db_session.flush()

    # 4. Setup Users
    principal_user = User(tenant_id=tenant_a.id, email=f"principal-{suffix}@edupulse.com", first_name="Pr", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[principal_role_a], schools=[school_a])
    teacher_user = User(tenant_id=tenant_a.id, email=f"teacher-{suffix}@edupulse.com", first_name="Tch", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[teacher_role_a], schools=[school_a])
    tenant_b_user = User(tenant_id=tenant_b.id, email=f"principal-b-{suffix}@edupulse.com", first_name="B", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[principal_role_b], schools=[school_c])

    db_session.add_all([principal_user, teacher_user, tenant_b_user])
    await db_session.flush()

    # 5. Setup existing Academic Year, Classes and Sections for resolution testing
    ay = AcademicYear(tenant_id=tenant_a.id, school_id=school_a.id, name="AY 2026-27", code="AY2026-2027", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30), status="ACTIVE", is_current=True)
    db_session.add(ay)
    await db_session.flush()

    class_1 = Class(tenant_id=tenant_a.id, school_id=school_a.id, academic_year_id=ay.id, name="Class 8", code="CLASS_8", level=8, capacity=120, status="ACTIVE", is_active=True)
    db_session.add(class_1)
    await db_session.flush()

    section_a = Section(tenant_id=tenant_a.id, school_id=school_a.id, academic_year_id=ay.id, class_id=class_1.id, name="Section A", code="SEC_A", capacity=40, status="ACTIVE", is_active=True)
    db_session.add(section_a)
    await db_session.flush()

    # 6. Auth Headers
    p_token = create_access_token(subject=principal_user.id, tenant_id=tenant_a.id)
    t_token = create_access_token(subject=teacher_user.id, tenant_id=tenant_a.id)
    tb_token = create_access_token(subject=tenant_b_user.id, tenant_id=tenant_b.id)

    p_headers = {"Authorization": f"Bearer {p_token}", "X-Tenant-ID": str(tenant_a.id), "X-School-ID": str(school_a.id)}
    t_headers = {"Authorization": f"Bearer {t_token}", "X-Tenant-ID": str(tenant_a.id), "X-School-ID": str(school_a.id)}
    tb_headers = {"Authorization": f"Bearer {tb_token}", "X-Tenant-ID": str(tenant_b.id), "X-School-ID": str(school_c.id)}

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_c": school_c,
        "ay": ay,
        "class_1": class_1,
        "section_a": section_a,
        "p_headers": p_headers,
        "t_headers": t_headers,
        "tb_headers": tb_headers,
        "principal_user": principal_user
    }

@pytest.mark.anyio
async def test_validate_academic_setup_migration_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Upload valid CSV content
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section B,SEC_B,40\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 9,CLASS_9,9,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    val_data = res_val.json()["data"]
    assert val_data["status"] == "VALIDATED"
    assert val_data["total_rows"] == 3
    assert val_data["failed_rows"] == 0

    # 3. Verify zero AcademicYear/Class/Section records were created in database
    # (Since this is validation only, no new DB records should be created)
    stmt_ay = select(AcademicYear).where(AcademicYear.name == "2026-2027")
    res_ay = await db_session.execute(stmt_ay)
    assert res_ay.scalar_one_or_none() is None

    # 4. Verify Staging rows exist and resolved IDs are populated for existing entities
    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id)).order_by(AcademicSetupImportRow.row_number.asc())
    res_stg = await db_session.execute(stmt_stg)
    stg_rows = list(res_stg.scalars().all())
    assert len(stg_rows) == 3

    # Row 1 corresponds to existing Academic Year (AY 2026-27), Class (Class 8), Section (Section A)
    assert stg_rows[0].row_number == 1
    assert stg_rows[0].academic_year_id == data["ay"].id
    assert stg_rows[0].class_id == data["class_1"].id
    assert stg_rows[0].section_id == data["section_a"].id
    assert stg_rows[0].validation_status == "valid"

    # Row 2 corresponds to existing Academic Year, existing Class, but NEW Section B
    assert stg_rows[1].row_number == 2
    assert stg_rows[1].academic_year_id == data["ay"].id
    assert stg_rows[1].class_id == data["class_1"].id
    assert stg_rows[1].section_id is None
    assert stg_rows[1].validation_status == "valid"

    # Row 3 corresponds to existing Academic Year, but NEW Class 9, NEW Section A
    assert stg_rows[2].row_number == 3
    assert stg_rows[2].academic_year_id == data["ay"].id
    assert stg_rows[2].class_id is None
    assert stg_rows[2].section_id is None
    assert stg_rows[2].validation_status == "valid"

@pytest.mark.anyio
async def test_validate_academic_setup_migration_validation_errors(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_err.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Upload invalid CSV content
    # Row 1: Invalid dates (start >= end) -> INVALID_ACADEMIC_PERIOD
    # Row 2: Invalid class level -> INVALID_LEVEL_FORMAT
    # Row 3: Invalid class capacity -> INVALID_CAPACITY
    # Row 4: Duplicate leaf combo (same AY, class, section code as Row 2) -> DUPLICATE_ROW
    # Row 5: Existing Academic Year but mismatch dates -> ACADEMIC_YEAR_DATE_MISMATCH
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "AY Err 1,AY2028,2028-06-01,2028-05-01,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
        "AY Err 2,AY2029,2029-06-01,2030-04-30,Class 8,CLASS_8,-1,120,Section A,SEC_A,40\n"
        "AY Err 3,AY2030,2030-06-01,2031-04-30,Class 8,CLASS_8,8,-5,Section A,SEC_A,40\n"
        "AY Err 2,AY2029,2029-06-01,2030-04-30,Class 8,CLASS_8,-1,120,Section A,SEC_A,40\n"
        "AY 2026-27,AY2026-2027,2026-06-01,2027-05-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup_err.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    val_data = res_val.json()["data"]
    assert val_data["status"] == "VALIDATED"
    assert val_data["total_rows"] == 5
    assert val_data["failed_rows"] == 5

    # Verify staging row validation errors
    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id)).order_by(AcademicSetupImportRow.row_number.asc())
    res_stg = await db_session.execute(stmt_stg)
    stg_rows = list(res_stg.scalars().all())
    assert len(stg_rows) == 5

    assert stg_rows[0].validation_status == "invalid"
    assert stg_rows[0].validation_error_code == "INVALID_ACADEMIC_PERIOD"

    assert stg_rows[1].validation_status == "invalid"
    assert stg_rows[1].validation_error_code == "INVALID_LEVEL_FORMAT"

    assert stg_rows[2].validation_status == "invalid"
    assert stg_rows[2].validation_error_code == "INVALID_CAPACITY"

    assert stg_rows[3].validation_status == "invalid"
    assert stg_rows[3].validation_error_code == "DUPLICATE_ROW"

    assert stg_rows[4].validation_status == "invalid"
    assert stg_rows[4].validation_error_code == "ACADEMIC_YEAR_DATE_MISMATCH"

@pytest.mark.anyio
async def test_validate_academic_setup_migration_tenant_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    tb_headers = data["tb_headers"]

    # 1. Create Job in Tenant A
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_iso.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Try validating the job using Tenant B headers -> 404 Not Found (due to isolation)
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup_iso.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    
    res_val_b = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=tb_headers)
    assert res_val_b.status_code == 404

    # 3. Validate using Tenant A headers -> 200 OK
    res_val_a = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val_a.status_code == 200

@pytest.mark.anyio
async def test_validate_academic_setup_migration_mismatch_conflicts(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    tenant_a = data["tenant_a"]

    # Seed conflicting entities
    # 1. Conflicting Academic Year
    ay2 = AcademicYear(tenant_id=tenant_a.id, school_id=school_a.id, name="AY 2027-28", code="AY2027-2028", start_date=date(2027, 6, 1), end_date=date(2028, 4, 30), status="ACTIVE", is_current=False)
    db_session.add(ay2)
    await db_session.flush()

    # 2. Conflicting Class under AY1
    class_2 = Class(tenant_id=tenant_a.id, school_id=school_a.id, academic_year_id=data["ay"].id, name="Class 9", code="CLASS_9", level=9, capacity=120, status="ACTIVE", is_active=True)
    db_session.add(class_2)
    await db_session.flush()

    # 3. Conflicting Section under Class 1
    section_2 = Section(tenant_id=tenant_a.id, school_id=school_a.id, academic_year_id=data["ay"].id, class_id=data["class_1"].id, name="Section B", code="SEC_B", capacity=40, status="ACTIVE", is_active=True)
    db_session.add(section_2)
    await db_session.flush()
    await db_session.commit()

    # Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_conflicts.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # CSV triggers mismatches
    # Row 1: academic_year_code conflicts (maps to AY2027-28, but name is AY 2026-27)
    # Row 2: class_code conflicts (maps to CLASS_9, but name is Class 8)
    # Row 3: section_code conflicts (maps to SEC_B, but name is Section A)
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "AY 2026-27,AY2027-2028,2027-06-01,2028-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
        "AY 2026-27,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_9,8,120,Section A,SEC_A,40\n"
        "AY 2026-27,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_B,40\n"
    )
    files = {"file": ("academic_setup_conflicts.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id)).order_by(AcademicSetupImportRow.row_number.asc())
    res_stg = await db_session.execute(stmt_stg)
    stg_rows = list(res_stg.scalars().all())
    assert len(stg_rows) == 3

    assert stg_rows[0].validation_error_code == "ACADEMIC_YEAR_CODE_CONFLICT"
    assert stg_rows[1].validation_error_code == "CLASS_CODE_CONFLICT"
    assert stg_rows[2].validation_error_code == "SECTION_CODE_CONFLICT"

@pytest.mark.anyio
async def test_validate_academic_setup_migration_required_header_failure(
    client: AsyncClient,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_missing_hdr.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # Missing class_level and section_capacity headers
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_capacity,section_name,section_code\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,120,Section A,SEC_A\n"
    )
    files = {"file": ("academic_setup_missing_hdr.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 422
    assert "Missing required CSV column headers" in res_val.json()["message"]


@pytest.mark.anyio
async def test_validate_academic_setup_migration_blank_rows(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_blanks.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # CSV has blank lines and blank rows
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
        "  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  \n"
        "\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section B,SEC_B,40\n"
    )
    files = {"file": ("academic_setup_blanks.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    val_data = res_val.json()["data"]
    assert val_data["total_rows"] == 2
    assert val_data["failed_rows"] == 0

    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id))
    res_stg = await db_session.execute(stmt_stg)
    assert len(res_stg.scalars().all()) == 2

@pytest.mark.anyio
async def test_validate_academic_setup_migration_non_destructive_and_audit(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # Get counts before validation
    ay_count_before = (await db_session.execute(select(func.count()).select_from(AcademicYear))).scalar()
    class_count_before = (await db_session.execute(select(func.count()).select_from(Class))).scalar()
    section_count_before = (await db_session.execute(select(func.count()).select_from(Section))).scalar()

    # Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_audit.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
        "AY Err,AY9999,2026-06-01,2026-05-01,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup_audit.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    # Get counts after validation
    ay_count_after = (await db_session.execute(select(func.count()).select_from(AcademicYear))).scalar()
    class_count_after = (await db_session.execute(select(func.count()).select_from(Class))).scalar()
    section_count_after = (await db_session.execute(select(func.count()).select_from(Section))).scalar()

    # Assert non-destructive database constraint count verification
    assert ay_count_after == ay_count_before
    assert class_count_after == class_count_before
    assert section_count_after == section_count_before

    # Verify ImportJobRow audit entries
    stmt_audit = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number.asc())
    res_audit = await db_session.execute(stmt_audit)
    audit_rows = list(res_audit.scalars().all())
    assert len(audit_rows) == 2

    assert audit_rows[0].row_number == 1
    assert audit_rows[0].status == "success"

    assert audit_rows[1].row_number == 2
    assert audit_rows[1].status == "failed"
    assert audit_rows[1].error_code == "INVALID_ACADEMIC_PERIOD"

@pytest.mark.anyio
async def test_execute_academic_setup_migration_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_exec.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # CSV contains:
    # Row 1: Existing Year + Existing Class + Existing Section (Case A)
    # Row 2: Existing Year + Existing Class + NEW Section B (Case B)
    # Row 3: Existing Year + NEW Class 9 + NEW Section A (Case C)
    # Row 4: NEW Year 2028 + NEW Class 10 + NEW Section A (Case D)
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section B,SEC_B,40\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 9,CLASS_9,9,120,Section A,SEC_A,40\n"
        "2028-2029,AY2028-2029,2028-06-01,2029-04-30,Class 10,CLASS_10,10,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup_exec.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    
    # Validate first
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    # Execute
    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED"
    assert val_data["processed_rows"] == 4
    assert val_data["successful_rows"] == 4
    assert val_data["failed_rows"] == 0
    assert val_data["skipped_rows"] == 0

    # Verify entities were created
    # Academic Year 2028-2029 created
    stmt_ay = select(AcademicYear).where(
        and_(
            AcademicYear.code == "AY2028-2029",
            AcademicYear.school_id == school_a.id
        )
    )
    ay_2028 = (await db_session.execute(stmt_ay)).scalar_one()
    assert ay_2028.tenant_id == uuid.UUID(p_headers["X-Tenant-ID"])

    # Class 9 & Class 10 created
    stmt_cls9 = select(Class).where(
        and_(
            Class.code == "CLASS_9",
            Class.school_id == school_a.id
        )
    )
    cls_9 = (await db_session.execute(stmt_cls9)).scalar_one()
    assert cls_9.academic_year_id == data["ay"].id

    stmt_cls10 = select(Class).where(
        and_(
            Class.code == "CLASS_10",
            Class.school_id == school_a.id
        )
    )
    cls_10 = (await db_session.execute(stmt_cls10)).scalar_one()
    assert cls_10.academic_year_id == ay_2028.id

    # Section B of Class 8 created
    stmt_secb = select(Section).where(
        and_(
            Section.code == "SEC_B",
            Section.school_id == school_a.id
        )
    )
    sec_b = (await db_session.execute(stmt_secb)).scalar_one()
    assert sec_b.class_id == data["class_1"].id


    # Verify staging rows update
    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id)).order_by(AcademicSetupImportRow.row_number.asc())
    stg_rows = list((await db_session.execute(stmt_stg)).scalars().all())
    assert len(stg_rows) == 4

    assert stg_rows[0].validation_status == "executed"
    assert stg_rows[0].created_academic_year_id == data["ay"].id
    assert stg_rows[0].created_class_id == data["class_1"].id
    assert stg_rows[0].created_section_id == data["section_a"].id

    assert stg_rows[1].validation_status == "executed"
    assert stg_rows[1].created_academic_year_id == data["ay"].id
    assert stg_rows[1].created_class_id == data["class_1"].id
    assert stg_rows[1].created_section_id == sec_b.id

    assert stg_rows[2].validation_status == "executed"
    assert stg_rows[2].created_academic_year_id == data["ay"].id
    assert stg_rows[2].created_class_id == cls_9.id
    assert stg_rows[2].created_section_id is not None

    assert stg_rows[3].validation_status == "executed"
    assert stg_rows[3].created_academic_year_id == ay_2028.id
    assert stg_rows[3].created_class_id == cls_10.id
    assert stg_rows[3].created_section_id is not None

    # Verify ImportJobRow audit entries
    stmt_audit = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number.asc())
    audit_rows = list((await db_session.execute(stmt_audit)).scalars().all())
    assert len(audit_rows) == 4
    for a in audit_rows:
        assert a.status == "success"
        assert a.entity_id is not None

@pytest.mark.anyio
async def test_execute_academic_setup_migration_partial_failure_and_blanks(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # Archive the Academic Year AY 2026-27 to trigger runtime creation failure for Class under it
    data["ay"].status = "ARCHIVED"
    db_session.add(data["ay"])
    await db_session.commit()

    # Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_fail.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # CSV has:
    # Row 1: NEW Class 9 under archived Year -> should FAIL during execution
    # Row 2: NEW Year 2028 + NEW Class 10 + NEW Section A -> should SUCCEED
    # Row 3: Invalid Level (marked invalid during validation) -> should BE SKIPPED (not executed)
    # Row 4: Completely blank line -> should BE SKIPPED (ignored)
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 9,CLASS_9,9,120,Section A,SEC_A,40\n"
        "2028-2029,AY2028-2029,2028-06-01,2029-04-30,Class 10,CLASS_10,10,120,Section A,SEC_A,40\n"
        "2028-2029,AY2028-2029,2028-06-01,2029-04-30,Class 11,CLASS_11,-5,120,Section A,SEC_A,40\n"
        "  ,  ,  ,  ,  ,  ,  ,  ,  ,  ,  \n"
    )
    files = {"file": ("academic_setup_fail.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    
    # Validate
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    # Execute
    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_start.status_code == 200

    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED_WITH_ERRORS"
    assert val_data["processed_rows"] == 2
    assert val_data["successful_rows"] == 1
    assert val_data["failed_rows"] == 1
    assert val_data["skipped_rows"] == 1

    # Check staging row status
    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id)).order_by(AcademicSetupImportRow.row_number.asc())
    stg_rows = list((await db_session.execute(stmt_stg)).scalars().all())
    assert len(stg_rows) == 3

    assert stg_rows[0].validation_status == "failed_execution"
    assert stg_rows[0].validation_error_code == "CLASS_CREATION_FAILED"

    assert stg_rows[1].validation_status == "executed"
    assert stg_rows[1].created_academic_year_id is not None

    assert stg_rows[2].validation_status == "invalid"

@pytest.mark.anyio
async def test_execute_academic_setup_migration_race_condition(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    tenant_a = data["tenant_a"]

    # Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_race.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # CSV has new Year 2035
    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2035-2036,AY2035-2036,2035-06-01,2036-04-30,Class 10,CLASS_10,10,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup_race.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    
    # Validate
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    # Race condition: Academic Year created concurrently
    ay_race = AcademicYear(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        name="2035-2036",
        code="AY2035-2036",
        start_date=date(2035, 6, 1),
        end_date=date(2036, 4, 30),
        status="ACTIVE"
    )
    db_session.add(ay_race)
    await db_session.commit()

    # Execute
    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_start.status_code == 200

    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED"
    assert val_data["successful_rows"] == 1

    # Verify staging row ID resolves to ay_race.id
    stmt_stg = select(AcademicSetupImportRow).where(AcademicSetupImportRow.import_job_id == uuid.UUID(job_id))
    stg_row = (await db_session.execute(stmt_stg)).scalar_one()
    assert stg_row.created_academic_year_id == ay_race.id

@pytest.mark.anyio
async def test_execute_academic_setup_migration_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_setup_migration_data: dict
):
    data = setup_setup_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    tb_headers = data["tb_headers"]

    # Create Job under Tenant A
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "ACADEMIC_SETUP",
        "source_filename": "academic_setup_iso_exec.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "academic_year_name,academic_year_code,start_date,end_date,class_name,class_code,class_level,class_capacity,section_name,section_code,section_capacity\n"
        "2026-2027,AY2026-2027,2026-06-01,2027-04-30,Class 8,CLASS_8,8,120,Section A,SEC_A,40\n"
    )
    files = {"file": ("academic_setup_iso_exec.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=p_headers)
    assert res_val.status_code == 200

    # Start Job using Tenant B's headers -> must return 404
    res_start_b = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=tb_headers)
    assert res_start_b.status_code == 404

