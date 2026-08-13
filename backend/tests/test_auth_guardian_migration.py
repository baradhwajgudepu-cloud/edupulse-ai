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
from app.models.guardian import Guardian, GuardianStatus, GuardianType, StudentGuardian
from app.models.guardian_import import GuardianImportRow
from app.core.security import create_access_token

@pytest.fixture
async def setup_guardian_migration_data(db_session: AsyncSession):
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

    # 5. Setup existing active and soft-deleted Guardians for conflict tests
    # Active Guardian under Tenant A
    active_g = Guardian(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        guardian_type=GuardianType.FATHER,
        first_name="Active",
        last_name="Father",
        gender="MALE",
        date_of_birth=date(1980, 5, 10),
        mobile="9876543210",
        email="active.father@edupulse.com",
        status=GuardianStatus.ACTIVE,
        is_active=True
    )
    # Soft-deleted Guardian under Tenant A
    soft_deleted_g = Guardian(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        guardian_type=GuardianType.MOTHER,
        first_name="Soft",
        last_name="Mother",
        gender="FEMALE",
        date_of_birth=date(1985, 8, 15),
        mobile="9876543211",
        email="soft.mother@edupulse.com",
        status=GuardianStatus.INACTIVE,
        is_active=False,
        deleted_at=datetime.now(timezone.utc)
    )
    db_session.add_all([active_g, soft_deleted_g])
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
        "active_g": active_g,
        "soft_deleted_g": soft_deleted_g,
        "p_headers": p_headers,
        "t_headers": t_headers,
        "tb_headers": tb_headers,
        "principal_user": principal_user
    }

@pytest.mark.anyio
async def test_validate_guardian_migration_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_success.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Upload and validate valid CSV content
    csv_content = (
        "guardian_id,guardian_type,first_name,middle_name,last_name,gender,date_of_birth,mobile,email,address\n"
        "G_001,FATHER,John,Lee,Doe,MALE,1980-01-01,+1234567890,john.doe@edupulse.com,123 Main St\n"
        "G_002,MOTHER,Mary,,Smith,FEMALE,1982-06-15,9876543212,,456 Oak Rd\n"
    ).encode("utf-8")

    # Capture db count before validation
    stmt_count = select(func.count(Guardian.id))
    res_before = await db_session.execute(stmt_count)
    count_before = res_before.scalar()

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_success.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["status"] == "VALIDATED"
    assert res_data["total_rows"] == 2
    assert res_data["successful_rows"] == 2
    assert res_data["failed_rows"] == 0

    # Ensure no actual Guardian records were created in db (non-destructive check)
    res_after = await db_session.execute(stmt_count)
    count_after = res_after.scalar()
    assert count_before == count_after

    # Verify staging rows inserted
    stmt_staged = select(GuardianImportRow).where(GuardianImportRow.import_job_id == uuid.UUID(job_id))
    res_staged = await db_session.execute(stmt_staged)
    staged_rows = res_staged.scalars().all()
    assert len(staged_rows) == 2
    assert staged_rows[0].source_identifier == "G_001"
    assert staged_rows[0].validation_status == "valid"
    assert staged_rows[0].first_name == "John"
    assert staged_rows[0].address == "123 Main St"
    assert staged_rows[1].source_identifier == "G_002"
    assert staged_rows[1].validation_status == "valid"

    # Verify ImportJobRow audit entries
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id))
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert len(audits) == 2
    assert audits[0].status == "success"
    assert audits[1].status == "success"

@pytest.mark.anyio
async def test_validate_guardian_missing_headers(
    client: AsyncClient,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_bad_headers.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Missing mandatory 'mobile' header
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth\n"
        "G_001,FATHER,John,Doe,MALE,1980-01-01\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_bad_headers.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 422
    assert "Missing required CSV column headers" in res_val.json()["message"]

@pytest.mark.anyio
async def test_validate_guardian_field_failures(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_validation_errors.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Raw row validations:
    # Row 1: Missing required field (first_name is empty)
    # Row 2: Invalid guardian_type enum
    # Row 3: Invalid gender enum
    # Row 4: Invalid date_of_birth format
    # Row 5: Date of birth is in the future
    # Row 6: Invalid phone mobile format
    # Row 7: Invalid email format
    # Row 8: Invalid Aadhaar length
    # Row 9: Invalid PAN pattern
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email,aadhaar_number,pan_number\n"
        "G_001,FATHER,,Doe,MALE,1980-01-01,9876543212,test@t.com,,\n"
        "G_002,INVALID_TYPE,Mary,Smith,FEMALE,1982-06-15,9876543212,test@t.com,,\n"
        "G_003,MOTHER,Jane,Smith,INVALID_GENDER,1982-06-15,9876543212,test@t.com,,\n"
        "G_004,MOTHER,Jane,Smith,FEMALE,15-06-1982,9876543212,test@t.com,,\n"
        "G_005,MOTHER,Jane,Smith,FEMALE,2099-06-15,9876543212,test@t.com,,\n"
        "G_006,MOTHER,Jane,Smith,FEMALE,1982-06-15,INVALID_PHONE,test@t.com,,\n"
        "G_007,MOTHER,Jane,Smith,FEMALE,1982-06-15,9876543212,invalid_email,,\n"
        "G_008,MOTHER,Jane,Smith,FEMALE,1982-06-15,9876543212,test@t.com,12345,\n"
        "G_009,MOTHER,Jane,Smith,FEMALE,1982-06-15,9876543212,test@t.com,,12345ABCDE\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_validation_errors.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["status"] == "VALIDATED"
    assert res_data["total_rows"] == 9
    assert res_data["failed_rows"] == 9
    assert res_data["successful_rows"] == 0

    # Query audit rows to verify error codes
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number)
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert len(audits) == 9

    assert audits[0].error_code == "MISSING_REQUIRED_FIELD"
    assert audits[1].error_code == "INVALID_GUARDIAN_TYPE"
    assert audits[2].error_code == "INVALID_GENDER"
    assert audits[3].error_code == "INVALID_FIELD_FORMAT"  # malformed DOB
    assert audits[4].error_code == "INVALID_FIELD_FORMAT"  # future DOB
    assert audits[5].error_code == "INVALID_PHONE"
    assert audits[6].error_code == "INVALID_EMAIL"
    assert audits[7].error_code == "INVALID_FIELD_FORMAT"  # Aadhaar format
    assert audits[8].error_code == "INVALID_FIELD_FORMAT"  # PAN format

@pytest.mark.anyio
async def test_validate_guardian_duplicates_csv(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_duplicates_csv.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # CSV has duplicate mobile numbers and email addresses
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        "G_001,FATHER,John,Doe,MALE,1980-01-01,9876543215,john@test.com\n"
        "G_002,MOTHER,Mary,Smith,FEMALE,1982-06-15,9876543215,mary@test.com\n"
        "G_003,UNCLE,Bob,Smith,MALE,1975-04-10,9876543216,john@test.com\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_duplicates_csv.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["total_rows"] == 3
    assert res_data["failed_rows"] == 2
    assert res_data["successful_rows"] == 1

    # Row 2 and 3 should fail as duplicates
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number)
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert audits[0].status == "success"
    assert audits[1].error_code == "DUPLICATE_ROW"
    assert audits[2].error_code == "DUPLICATE_ROW"

@pytest.mark.anyio
async def test_validate_guardian_db_active_conflict(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    active_g = data["active_g"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_active_conflict.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # CSV mobile matches existing active guardian under Tenant A
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        f"G_100,FATHER,John,Doe,MALE,1980-01-01,{active_g.mobile},new.email@test.com\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_active_conflict.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["failed_rows"] == 1

    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id))
    res_audits = await db_session.execute(stmt_audits)
    audit = res_audits.scalar_one()
    assert audit.error_code == "GUARDIAN_ALREADY_EXISTS"

    # Verify resolved_guardian_id points to existing guardian
    stmt_staged = select(GuardianImportRow).where(GuardianImportRow.import_job_id == uuid.UUID(job_id))
    res_staged = await db_session.execute(stmt_staged)
    staged = res_staged.scalar_one()
    assert staged.resolved_guardian_id == active_g.id

@pytest.mark.anyio
async def test_validate_guardian_db_soft_deleted_conflict(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    soft_deleted_g = data["soft_deleted_g"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_soft_deleted_conflict.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # CSV mobile matches existing soft-deleted guardian
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        f"G_101,MOTHER,Mary,Doe,FEMALE,1985-08-15,{soft_deleted_g.mobile},soft.mother@edupulse.com\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_soft_deleted_conflict.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["failed_rows"] == 1

    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id))
    res_audits = await db_session.execute(stmt_audits)
    audit = res_audits.scalar_one()
    assert audit.error_code == "SOFT_DELETED_GUARDIAN_CONFLICT"

@pytest.mark.anyio
async def test_validate_guardian_tenant_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    active_g = data["active_g"]
    tb_headers = data["tb_headers"]
    school_c = data["school_c"]

    # Create job under Tenant B
    job_in = {
        "school_id": str(school_c.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_tenant_b.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=tb_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Tenant B tries to upload a CSV containing active_g's mobile (which is under Tenant A)
    # This should NOT trigger GUARDIAN_ALREADY_EXISTS since Tenant A's records are isolated from Tenant B
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        f"G_300,FATHER,John,Doe,MALE,1980-01-01,{active_g.mobile},tenantb.john@test.com\n"
    ).encode("utf-8")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_tenant_b.csv", csv_content, "text/csv")},
        headers=tb_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["successful_rows"] == 1
    assert res_data["failed_rows"] == 0

@pytest.mark.anyio
async def test_validate_guardian_utf8_bom_and_blanks(
    client: AsyncClient,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_bom.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Write content starting with UTF-8 BOM, including headers casing with spaces, and trailing empty lines
    csv_content = (
        " guardian_id , GUARDIAN_TYPE , first_name , last_name , gender , date_of_birth , mobile \n"
        "G_001,FATHER,John,Lee,MALE,1980-01-01,9876543213\n"
        ",,,,,,\n"
        "  ,  ,  ,  ,  ,  ,  \n"
    ).encode("utf-8-sig")

    res_val = await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_bom.csv", csv_content, "text/csv")},
        headers=p_headers
    )
    assert res_val.status_code == 200
    res_data = res_val.json()["data"]
    assert res_data["total_rows"] == 1  # Blanks skipped, only 1 valid row
    assert res_data["successful_rows"] == 1
    assert res_data["failed_rows"] == 0


@pytest.mark.anyio
async def test_execute_guardian_migration_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_exec.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Upload and validate
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        "G_E01,FATHER,NewExec,Father,MALE,1980-01-01,9876543220,new.father@exec.com\n"
        "G_E02,MOTHER,NewExec,Mother,FEMALE,1982-06-15,9876543221,new.mother@exec.com\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_exec.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Verify status is VALIDATED before starting
    res_get = await client.get(f"/api/v1/import-jobs/{job_id}", headers=p_headers)
    assert res_get.json()["data"]["status"] == "VALIDATED"

    # Verify no StudentGuardian mapping exists
    stmt_sg_count = select(func.count(StudentGuardian.id))
    res_sg = await db_session.execute(stmt_sg_count)
    sg_before = res_sg.scalar()

    # 3. Start/Execute Job
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED"
    assert res_data["processed_rows"] == 2
    assert res_data["successful_rows"] == 2
    assert res_data["failed_rows"] == 0

    # 4. Verify DB creations
    stmt_g = select(Guardian).where(Guardian.mobile == "9876543220")
    res_g = await db_session.execute(stmt_g)
    g1 = res_g.scalar_one_or_none()
    assert g1 is not None
    assert g1.first_name == "NewExec"
    assert g1.email == "new.father@exec.com"
    assert g1.tenant_id == data["tenant_a"].id
    assert g1.school_id == school_a.id

    stmt_g2 = select(Guardian).where(Guardian.mobile == "9876543221")
    res_g2 = await db_session.execute(stmt_g2)
    g2 = res_g2.scalar_one_or_none()
    assert g2 is not None

    # Verify no StudentGuardian mapping was created
    res_sg_after = await db_session.execute(stmt_sg_count)
    sg_after = res_sg_after.scalar()
    assert sg_before == sg_after

    # Verify staging rows update
    stmt_staged = select(GuardianImportRow).where(GuardianImportRow.import_job_id == uuid.UUID(job_id))
    res_staged = await db_session.execute(stmt_staged)
    staged = res_staged.scalars().all()
    assert len(staged) == 2
    assert staged[0].validation_status == "executed"
    assert staged[0].created_guardian_id == g1.id
    assert staged[1].validation_status == "executed"
    assert staged[1].created_guardian_id == g2.id

    # Verify ImportJobRow audit entries
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number)
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert len(audits) == 2
    assert audits[0].status == "success"
    assert audits[0].entity_id == g1.id
    assert audits[1].status == "success"
    assert audits[1].entity_id == g2.id


@pytest.mark.anyio
async def test_execute_guardian_migration_conflicts_and_mixed(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    active_g = data["active_g"]
    soft_deleted_g = data["soft_deleted_g"]

    # 1. Create Job
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_mixed.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Upload and validate
    # Row 1: Valid new guardian (succeeds)
    # Row 2: Will conflict (active guardian created after validation)
    # Row 3: Will conflict (soft-deleted guardian created after validation)
    # Row 4: Invalid during validation (skipped during execution)
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        "G_M01,FATHER,NewExec,Father,MALE,1980-01-01,9876543230,new.f@test.com\n"
        "G_M02,MOTHER,DupDb,Mobile,FEMALE,1985-01-01,9876543232,dup.m@test.com\n"
        "G_M03,MOTHER,SoftDup,Mother,FEMALE,1985-08-15,9876543233,soft.dup@test.com\n"
        "G_M04,MOTHER,Invalid,Row,INVALID_GENDER,1985-08-15,9876543231,\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_mixed.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Now, AFTER validation but BEFORE execution, create conflicting guardians in database
    active_conflict = Guardian(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        guardian_type=GuardianType.MOTHER,
        first_name="ActiveConflict",
        last_name="G",
        gender="FEMALE",
        date_of_birth=date(1985, 1, 1),
        mobile="9876543232",
        email="dup.m@test.com",
        status=GuardianStatus.ACTIVE,
        is_active=True
    )
    soft_deleted_conflict = Guardian(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        guardian_type=GuardianType.MOTHER,
        first_name="SoftConflict",
        last_name="G",
        gender="FEMALE",
        date_of_birth=date(1985, 8, 15),
        mobile="9876543233",
        email="soft.dup@test.com",
        status=GuardianStatus.INACTIVE,
        is_active=False,
        deleted_at=datetime.now(timezone.utc)
    )
    db_session.add_all([active_conflict, soft_deleted_conflict])
    await db_session.commit()

    # 3. Start execution
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED_WITH_ERRORS"
    assert res_data["processed_rows"] == 3  # Only valid rows 1, 2, 3 were processed
    assert res_data["successful_rows"] == 1  # Only row 1 succeeds
    assert res_data["failed_rows"] == 2  # Row 2 and Row 3 fail execution
    assert res_data["skipped_rows"] == 1  # Row 4 skipped

    # Verify staging statuses
    stmt_staged = select(GuardianImportRow).where(GuardianImportRow.import_job_id == uuid.UUID(job_id)).order_by(GuardianImportRow.row_number)
    res_staged = await db_session.execute(stmt_staged)
    staged = res_staged.scalars().all()
    assert len(staged) == 4

    assert staged[0].validation_status == "executed"
    assert staged[0].created_guardian_id is not None

    assert staged[1].validation_status == "failed_execution"
    assert staged[1].validation_error_code == "GUARDIAN_ALREADY_EXISTS"
    assert staged[1].created_guardian_id is None

    assert staged[2].validation_status == "failed_execution"
    assert staged[2].validation_error_code == "SOFT_DELETED_GUARDIAN_CONFLICT"
    assert staged[2].created_guardian_id is None

    assert staged[3].validation_status == "invalid"  # Stays invalid

    # Verify ImportJobRow audit entries
    stmt_audits = select(ImportJobRow).where(ImportJobRow.import_job_id == uuid.UUID(job_id)).order_by(ImportJobRow.row_number)
    res_audits = await db_session.execute(stmt_audits)
    audits = res_audits.scalars().all()
    assert len(audits) == 4
    assert audits[0].status == "success"
    assert audits[1].status == "failed"
    assert audits[1].error_code == "GUARDIAN_ALREADY_EXISTS"
    assert audits[2].status == "failed"
    assert audits[2].error_code == "SOFT_DELETED_GUARDIAN_CONFLICT"
    assert audits[3].status == "skipped"


@pytest.mark.anyio
async def test_execute_guardian_migration_reuse(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]
    active_g = data["active_g"]

    # Test reuse when the resolved_guardian_id is pre-resolved during validation
    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_reuse.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # Validation will find active_g via mobile match, flag it as error "GUARDIAN_ALREADY_EXISTS" but store resolved_guardian_id
    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        f"G_R01,FATHER,Reuse,Father,MALE,1980-01-01,{active_g.mobile},{active_g.email}\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_reuse.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Let's manually set this row validation_status to 'valid' to see if execution reuses it
    await db_session.execute(
        text("UPDATE guardian_import_rows SET validation_status = 'valid' WHERE import_job_id = :job_id").bindparams(job_id=uuid.UUID(job_id))
    )
    await db_session.commit()

    # Now execute
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED"
    assert res_data["processed_rows"] == 1
    assert res_data["successful_rows"] == 1

    # Check staging row updated with existing guardian ID
    stmt_staged = select(GuardianImportRow).where(GuardianImportRow.import_job_id == uuid.UUID(job_id))
    res_staged = await db_session.execute(stmt_staged)
    staged = res_staged.scalar_one()
    assert staged.validation_status == "executed"
    assert staged.created_guardian_id == active_g.id


@pytest.mark.anyio
async def test_execute_guardian_migration_terminal_protection(
    client: AsyncClient,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_terminal.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email\n"
        "G_T01,FATHER,Terminal,Test,MALE,1980-01-01,9876543240,term@test.com\n"
    ).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_terminal.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # 1. First execution (COMPLETED)
    res_exec1 = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec1.status_code == 200
    assert res_exec1.json()["data"]["status"] == "COMPLETED"

    # 2. Duplicate execution protection (fails with 400)
    res_exec2 = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec2.status_code == 400
    assert "Import job must be in VALIDATED state" in res_exec2.json()["message"]


@pytest.mark.anyio
async def test_execute_guardian_migration_100_plus_chunks(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_guardian_migration_data: dict
):
    data = setup_guardian_migration_data
    school_a = data["school_a"]
    p_headers = data["p_headers"]

    job_in = {
        "school_id": str(school_a.id),
        "import_type": "GUARDIANS",
        "source_filename": "guardians_chunks.csv"
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_in, headers=p_headers)
    job_id = res_job.json()["data"]["id"]

    # Write 105 rows
    lines = ["guardian_id,guardian_type,first_name,last_name,gender,date_of_birth,mobile,email"]
    for i in range(1, 106):
        lines.append(f"G_CH{i},FATHER,Chunk{i},Test,MALE,1980-01-01,9876543{i:03d},chunk{i}@test.com")
    csv_content = "\n".join(lines).encode("utf-8")

    await client.post(
        f"/api/v1/import-jobs/{job_id}/validate",
        files={"file": ("guardians_chunks.csv", csv_content, "text/csv")},
        headers=p_headers
    )

    # Execute
    res_exec = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert res_exec.status_code == 200
    res_data = res_exec.json()["data"]
    assert res_data["status"] == "COMPLETED"
    assert res_data["processed_rows"] == 105
    assert res_data["successful_rows"] == 105
