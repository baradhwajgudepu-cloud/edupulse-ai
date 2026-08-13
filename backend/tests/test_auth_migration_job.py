import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles, school_users
from app.models.permission import Permission
from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.core.security import create_access_token
from app.api.dependencies.import_job import get_import_job_service

@pytest.fixture
async def setup_migration_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenant & Schools
    tenant_a = Tenant(name="Tenant A", code=f"tenant-a-{suffix}", subdomain=f"sub-a-{suffix}", email=f"a-{suffix}@t.com")
    tenant_b = Tenant(name="Tenant B", code=f"tenant-b-{suffix}", subdomain=f"sub-b-{suffix}", email=f"b-{suffix}@t.com")
    db_session.add_all([tenant_a, tenant_b])
    await db_session.flush()

    school_a = School(tenant_id=tenant_a.id, name="School A", code=f"sch-a-{suffix}", email=f"sch-a-{suffix}@t.com", board="CBSE")
    school_b = School(tenant_id=tenant_a.id, name="School B", code=f"sch-b-{suffix}", email=f"sch-b-{suffix}@t.com", board="CBSE")
    school_c = School(tenant_id=tenant_b.id, name="School C", code=f"sch-c-{suffix}", email=f"sch-c-{suffix}@t.com", board="CBSE")
    db_session.add_all([school_a, school_b, school_c])
    await db_session.flush()

    # 2. Setup standard migration permissions (should be seeded, but query or insert to ensure consistency)
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
    staff_role_a = Role(tenant_id=tenant_a.id, name="Staff", code="STAFF", permissions=[permissions["migration.read"], permissions["migration.create"]])
    teacher_role_a = Role(tenant_id=tenant_a.id, name="Teacher", code="TEACHER")
    
    principal_role_b = Role(tenant_id=tenant_b.id, name="Principal B", code="PRINCIPAL", permissions=list(permissions.values()))
    
    db_session.add_all([principal_role_a, staff_role_a, teacher_role_a, principal_role_b])
    await db_session.flush()

    # 4. Setup Users with inline roles & schools
    principal_user = User(tenant_id=tenant_a.id, email=f"principal-{suffix}@edupulse.com", first_name="Pr", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[principal_role_a], schools=[school_a])
    staff_user = User(tenant_id=tenant_a.id, email=f"staff-{suffix}@edupulse.com", first_name="St", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[staff_role_a], schools=[school_a])
    teacher_user = User(tenant_id=tenant_a.id, email=f"teacher-{suffix}@edupulse.com", first_name="Tch", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[teacher_role_a], schools=[school_a])
    tenant_b_user = User(tenant_id=tenant_b.id, email=f"principal-b-{suffix}@edupulse.com", first_name="B", last_name="User", hashed_password="hashed_pwd", is_superuser=False, status=UserStatus.ACTIVE, roles=[principal_role_b], schools=[school_c])

    db_session.add_all([principal_user, staff_user, teacher_user, tenant_b_user])
    await db_session.flush()

    # 5. Create headers / Auth tokens
    p_token = create_access_token(subject=principal_user.id, tenant_id=tenant_a.id)
    s_token = create_access_token(subject=staff_user.id, tenant_id=tenant_a.id)
    t_token = create_access_token(subject=teacher_user.id, tenant_id=tenant_a.id)
    tb_token = create_access_token(subject=tenant_b_user.id, tenant_id=tenant_b.id)

    p_headers = {"Authorization": f"Bearer {p_token}", "X-Tenant-ID": str(tenant_a.id), "X-School-ID": str(school_a.id)}
    s_headers = {"Authorization": f"Bearer {s_token}", "X-Tenant-ID": str(tenant_a.id), "X-School-ID": str(school_a.id)}
    t_headers = {"Authorization": f"Bearer {t_token}", "X-Tenant-ID": str(tenant_a.id), "X-School-ID": str(school_a.id)}
    tb_headers = {"Authorization": f"Bearer {tb_token}", "X-Tenant-ID": str(tenant_b.id), "X-School-ID": str(school_c.id)}

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "school_c": school_c,
        "principal_user": principal_user,
        "p_headers": p_headers,
        "s_headers": s_headers,
        "t_headers": t_headers,
        "tb_headers": tb_headers
    }

@pytest.mark.anyio
async def test_create_import_job(client: AsyncClient, setup_migration_test_data: dict):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id
    
    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "students_onboarding.csv",
        "file_checksum": "hash_123456",
        "total_rows": 150,
        "job_metadata": {"created_by_role": "principal"}
    }

    res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    assert res.status_code == 201
    body = res.json()
    assert body["success"] is True
    assert body["data"]["status"] == "DRAFT"
    assert body["data"]["source_filename"] == "students_onboarding.csv"
    assert body["data"]["file_checksum"] == "hash_123456"
    assert body["data"]["total_rows"] == 150

@pytest.mark.anyio
async def test_get_import_job(client: AsyncClient, setup_migration_test_data: dict):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    # Create first
    payload = {
        "school_id": str(school_id),
        "import_type": "FEE_MASTERS",
        "source_filename": "fees.csv",
        "file_checksum": "hash_fees",
        "total_rows": 50,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = create_res.json()["data"]["id"]

    # Get details
    get_res = await client.get(f"/api/v1/import-jobs/{job_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["data"]["id"] == job_id

@pytest.mark.anyio
async def test_list_jobs(client: AsyncClient, setup_migration_test_data: dict):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    # Create multiple
    for i in range(3):
        payload = {
            "school_id": str(school_id),
            "import_type": "PAYMENTS",
            "source_filename": f"payments_{i}.csv",
            "file_checksum": f"checksum_{i}",
            "total_rows": 10 * i,
            "job_metadata": {}
        }
        await client.post("/api/v1/import-jobs", json=payload, headers=headers)

    # List
    list_res = await client.get(f"/api/v1/import-jobs?school_id={school_id}&import_type=PAYMENTS", headers=headers)
    assert list_res.status_code == 200
    assert len(list_res.json()["data"]) >= 3

@pytest.mark.anyio
async def test_tenant_isolation(client: AsyncClient, setup_migration_test_data: dict):
    headers_a = setup_migration_test_data["p_headers"]
    headers_b = setup_migration_test_data["tb_headers"]
    school_a = setup_migration_test_data["school_a"].id

    # Create job in Tenant A
    payload = {
        "school_id": str(school_a),
        "import_type": "GUARDIANS",
        "source_filename": "guardians.csv",
        "file_checksum": "checksum_guardians",
        "total_rows": 25,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers_a)
    job_id = create_res.json()["data"]["id"]

    # Try to access from Tenant B principal
    get_res = await client.get(f"/api/v1/import-jobs/{job_id}", headers=headers_b)
    assert get_res.status_code == 404

@pytest.mark.anyio
async def test_school_isolation(client: AsyncClient, setup_migration_test_data: dict):
    headers_a = setup_migration_test_data["p_headers"]
    school_b = setup_migration_test_data["school_b"].id

    list_res = await client.get(f"/api/v1/import-jobs?school_id={school_b}", headers=headers_a)
    assert list_res.status_code == 200

@pytest.mark.anyio
async def test_rbac_permissions(client: AsyncClient, setup_migration_test_data: dict):
    p_headers = setup_migration_test_data["p_headers"]
    s_headers = setup_migration_test_data["s_headers"]
    t_headers = setup_migration_test_data["t_headers"]
    school_id = setup_migration_test_data["school_a"].id

    # 1. Staff (has migration.read, migration.create)
    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "students_staff.csv",
        "file_checksum": "checksum_staff_students",
        "total_rows": 100,
        "job_metadata": {}
    }
    staff_res = await client.post("/api/v1/import-jobs", json=payload, headers=s_headers)
    assert staff_res.status_code == 201
    job_id = staff_res.json()["data"]["id"]

    # Staff tries to execute (migration.execute is Principal only) -> returns 403 Forbidden
    start_res = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=s_headers)
    assert start_res.status_code == 403

    # Principal tries to execute -> works (after validating state transition)
    # If we call start directly on a DRAFT job -> returns 400 Bad Request
    start_draft = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=p_headers)
    assert start_draft.status_code == 400

    # 2. Teacher (has no migration permissions) -> returns 403
    t_res = await client.post("/api/v1/import-jobs", json=payload, headers=t_headers)
    assert t_res.status_code == 403

@pytest.mark.anyio
async def test_valid_state_transitions(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "students_transitions.csv",
        "file_checksum": "checksum_trans",
        "total_rows": 100,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Load from DB to transition manually
    stmt = select(ImportJob).where(ImportJob.id == job_id)
    res = await db_session.execute(stmt)
    job = res.scalar_one()

    # DRAFT -> VALIDATING
    job.status = ImportJobStatus.VALIDATING
    await db_session.commit()

    # VALIDATING -> VALIDATED
    job.status = ImportJobStatus.VALIDATED
    await db_session.commit()

    # VALIDATED -> RUNNING/COMPLETED (via /start API)
    start_res = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=headers)
    assert start_res.status_code == 200
    assert start_res.json()["data"]["status"] in ["RUNNING", "COMPLETED"]
    assert start_res.json()["data"]["started_at"] is not None

@pytest.mark.anyio
async def test_invalid_state_transitions(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "students_invalid.csv",
        "file_checksum": "checksum_invalid",
        "total_rows": 100,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Try to start DRAFT job directly -> returns 400 Bad Request
    start_res = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=headers)
    assert start_res.status_code == 400

@pytest.mark.anyio
async def test_checksum_duplicate_detection(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "students_dup.csv",
        "file_checksum": "checksum_dup",
        "total_rows": 100,
        "job_metadata": {}
    }
    await client.post("/api/v1/import-jobs", json=payload, headers=headers)

    # Transition to VALIDATING (making it active)
    stmt = select(ImportJob).where(ImportJob.file_checksum == "checksum_dup")
    res = await db_session.execute(stmt)
    job = res.scalar_one()
    job.status = ImportJobStatus.VALIDATING
    await db_session.commit()

    # Try to create a second job with the same checksum -> returns 409 Conflict
    dup_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    assert dup_res.status_code == 409

    # Change first job status to COMPLETED (terminal state)
    job.status = ImportJobStatus.COMPLETED
    await db_session.commit()

    # Now creation of same checksum should succeed
    ok_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    assert ok_res.status_code == 201

@pytest.mark.anyio
async def test_terminal_state_protection(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    # Create job
    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "terminal.csv",
        "file_checksum": "checksum_term",
        "total_rows": 10,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Load and set to CANCELLED (terminal state)
    stmt = select(ImportJob).where(ImportJob.id == job_id)
    res = await db_session.execute(stmt)
    job = res.scalar_one()
    job.status = ImportJobStatus.CANCELLED
    await db_session.commit()

    # Try to cancel it again -> 400 Bad Request
    cancel_res = await client.post(f"/api/v1/import-jobs/{job_id}/cancel", headers=headers)
    assert cancel_res.status_code == 400

@pytest.mark.anyio
async def test_cancel_behavior(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "to_cancel.csv",
        "file_checksum": "checksum_cancel",
        "total_rows": 10,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Cancel DRAFT job
    cancel_res = await client.post(f"/api/v1/import-jobs/{job_id}/cancel", headers=headers)
    assert cancel_res.status_code == 200
    assert cancel_res.json()["data"]["status"] == "CANCELLED"
    assert cancel_res.json()["data"]["completed_at"] is not None

@pytest.mark.anyio
async def test_row_result_creation(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "rows_test.csv",
        "file_checksum": "checksum_rows",
        "total_rows": 5,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Transition to RUNNING
    stmt = select(ImportJob).where(ImportJob.id == job_id)
    res = await db_session.execute(stmt)
    job = res.scalar_one()
    job.status = ImportJobStatus.RUNNING
    await db_session.commit()

    # Post row results
    row_payload = {
        "rows": [
            {"row_number": 1, "status": "success", "source_identifier": "ADM001", "row_metadata": {}},
            {"row_number": 2, "status": "failed", "error_code": "ERR_FORMAT", "error_message": "Invalid date", "source_identifier": "ADM002", "row_metadata": {}},
            {"row_number": 3, "status": "skipped", "source_identifier": "ADM003", "row_metadata": {}}
        ]
    }
    rows_res = await client.post(f"/api/v1/import-jobs/{job_id}/rows", json=row_payload, headers=headers)
    assert rows_res.status_code == 201
    assert len(rows_res.json()["data"]) == 3

    # Check updated stats in parent job details
    get_res = await client.get(f"/api/v1/import-jobs/{job_id}", headers=headers)
    job_body = get_res.json()["data"]
    assert job_body["processed_rows"] == 3
    assert job_body["successful_rows"] == 1
    assert job_body["failed_rows"] == 1
    assert job_body["skipped_rows"] == 1

@pytest.mark.anyio
async def test_row_result_pagination(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers = setup_migration_test_data["p_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "rows_pag.csv",
        "file_checksum": "checksum_pag",
        "total_rows": 10,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Set to RUNNING
    stmt = select(ImportJob).where(ImportJob.id == job_id)
    res = await db_session.execute(stmt)
    job = res.scalar_one()
    job.status = ImportJobStatus.RUNNING
    await db_session.commit()

    # Post 5 rows
    row_payload = {
        "rows": [{"row_number": idx, "status": "success", "source_identifier": f"ADM{idx}"} for idx in range(1, 6)]
    }
    await client.post(f"/api/v1/import-jobs/{job_id}/rows", json=row_payload, headers=headers)

    # Get rows with limit=2
    get_rows = await client.get(f"/api/v1/import-jobs/{job_id}/rows?skip=1&limit=2", headers=headers)
    assert get_rows.status_code == 200
    rows_data = get_rows.json()["data"]
    assert len(rows_data) == 2
    assert rows_data[0]["row_number"] == 2
    assert rows_data[1]["row_number"] == 3

@pytest.mark.anyio
async def test_row_result_isolation(client: AsyncClient, setup_migration_test_data: dict, db_session: AsyncSession):
    headers_a = setup_migration_test_data["p_headers"]
    headers_b = setup_migration_test_data["tb_headers"]
    school_id = setup_migration_test_data["school_a"].id

    payload = {
        "school_id": str(school_id),
        "import_type": "STUDENTS",
        "source_filename": "rows_iso.csv",
        "file_checksum": "checksum_iso",
        "total_rows": 5,
        "job_metadata": {}
    }
    create_res = await client.post("/api/v1/import-jobs", json=payload, headers=headers_a)
    job_id = uuid.UUID(create_res.json()["data"]["id"])

    # Set to RUNNING
    stmt = select(ImportJob).where(ImportJob.id == job_id)
    res = await db_session.execute(stmt)
    job = res.scalar_one()
    job.status = ImportJobStatus.RUNNING
    await db_session.commit()

    # Try to post row outcomes from Tenant B -> 404 Not Found (since job lookup is scoped by tenant)
    row_payload = {
        "rows": [{"row_number": 1, "status": "success", "source_identifier": "ADM001"}]
    }
    iso_res = await client.post(f"/api/v1/import-jobs/{job_id}/rows", json=row_payload, headers=headers_b)
    assert iso_res.status_code == 404

    # Try to view row outcomes from Tenant B -> 404 Not Found
    get_res = await client.get(f"/api/v1/import-jobs/{job_id}/rows", headers=headers_b)
    assert get_res.status_code == 404
