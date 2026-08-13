import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.user import User, UserStatus
from app.models.role import Role, school_users
from app.models.permission import Permission
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student, StudentStatus
from app.models.student_import import StudentImportRow
from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus
from app.core.security import create_access_token

@pytest.fixture
async def setup_student_migration_data(db_session: AsyncSession):
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

    # 5. Setup Academic Year, Classes and Sections
    ay = AcademicYear(tenant_id=tenant_a.id, school_id=school_a.id, name="AY 2026-27", code=f"ay-2026-{suffix}", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30), status="ACTIVE", is_current=True)
    db_session.add(ay)
    await db_session.flush()

    class_1 = Class(tenant_id=tenant_a.id, school_id=school_a.id, academic_year_id=ay.id, name="Grade 1", code=f"gr1-{suffix}", level=1, capacity=30, status="ACTIVE", is_active=True)
    db_session.add(class_1)
    await db_session.flush()

    section_a = Section(tenant_id=tenant_a.id, school_id=school_a.id, academic_year_id=ay.id, class_id=class_1.id, name="Section A", code=f"sec-a-{suffix}", capacity=2, status="ACTIVE", is_active=True)
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
async def test_validate_student_migration_success(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    # 1. Create DRAFT ImportJob
    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "students.csv",
        "file_checksum": "checksum_success_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Post CSV to Validate
    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM001,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    
    files = {"file": ("students.csv", csv_content.encode("utf-8-sig"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    assert res_val.status_code == 200
    
    val_data = res_val.json()["data"]
    assert val_data["status"] == "VALIDATED"
    assert val_data["successful_rows"] == 1
    assert val_data["failed_rows"] == 0

    # 3. Verify no Student record was created in database
    stmt_stud = select(Student).where(Student.admission_number == "ADM001")
    res_stud = await db_session.execute(stmt_stud)
    assert res_stud.scalar_one_or_none() is None

    # 4. Verify Staging row exists
    stmt_stg = select(StudentImportRow).where(StudentImportRow.import_job_id == uuid.UUID(job_id))
    res_stg = await db_session.execute(stmt_stg)
    stg_rows = list(res_stg.scalars().all())
    assert len(stg_rows) == 1
    assert stg_rows[0].first_name == "John"
    assert stg_rows[0].validation_status == "valid"
    assert stg_rows[0].created_student_id is None

@pytest.mark.anyio
async def test_validate_student_migration_validation_failures(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]
    tenant_a = data["tenant_a"]

    # Seed an active student to cause conflict
    active_stud = Student(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Alice",
        last_name="Smith",
        gender="FEMALE",
        date_of_birth=date(2015, 4, 1),
        admission_number="ADM_ACTIVE",
        roll_number="99",
        admission_date=date(2026, 6, 1),
        aadhaar_number="123456789012"
    )
    # Seed a soft-deleted student to cause conflict
    deleted_stud = Student(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Bob",
        last_name="Jones",
        gender="MALE",
        date_of_birth=date(2015, 8, 1),
        admission_number="ADM_DELETED",
        roll_number="98",
        admission_date=date(2026, 6, 1),
        deleted_at=datetime.now(timezone.utc)
    )
    db_session.add_all([active_stud, deleted_stud])
    await db_session.commit()

    # 1. Create DRAFT ImportJob
    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "failures.csv",
        "file_checksum": "checksum_fail_123",
        "total_rows": 9,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # 2. Generate failing CSV records
    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id,aadhaar_number\n"
        # 1. Missing first_name
        f",Doe,MALE,2015-05-15,ADM1,2,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        # 2. Invalid gender
        f"John,Doe,INVALID_G,2015-05-15,ADM2,3,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        # 3. Invalid DOB date format
        f"John,Doe,MALE,2015/05/15,ADM3,4,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        # 4. Duplicate admission number within CSV
        f"John,Doe,MALE,2015-05-15,ADM_DUPCSV,5,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_DUPCSV,6,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        # 5. Existing active student conflict
        f"John,Doe,MALE,2015-05-15,ADM_ACTIVE,7,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        # 6. Existing soft-deleted student conflict
        f"John,Doe,MALE,2015-05-15,ADM_DELETED,8,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
        # 7. Aadhaar global duplicate conflict
        f"John,Doe,MALE,2015-05-15,ADM7,9,2026-06-01,{ay.id},{class_1.id},{section_a.id},123456789012\n"
        # 8. Capacity exceeded check (Section capacity is 2; 1 active student exists, valid ADM_DUPCSV is row 2, this row 3 will exceed capacity)
        f"John,Doe,MALE,2015-05-15,ADM8,10,2026-06-01,{ay.id},{class_1.id},{section_a.id},\n"
    )

    files = {"file": ("failures.csv", csv_content.encode("utf-8"), "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    assert res_val.status_code == 200

    val_data = res_val.json()["data"]
    assert val_data["status"] == "VALIDATED"
    # Row 1 (missing field), Row 2 (gender), Row 3 (format), Row 5 (dup admission), Row 6 (active), Row 7 (deleted), Row 8 (aadhaar), Row 9 (capacity) should fail
    # Total failed = 8, successful = 1
    assert val_data["failed_rows"] == 8
    assert val_data["successful_rows"] == 1

    # Retrieve row results and check error codes
    res_rows = await client.get(f"/api/v1/import-jobs/{job_id}/rows", headers=data["p_headers"])
    assert res_rows.status_code == 200
    rows_list = res_rows.json()["data"]

    # Verify matching error codes
    errors = {r["row_number"]: r["error_code"] for r in rows_list if r["status"] == "failed"}
    assert errors[1] == "MISSING_REQUIRED_FIELD"
    assert errors[2] == "INVALID_GENDER"
    assert errors[3] == "INVALID_DATE"
    assert errors[5] == "DUPLICATE_ADMISSION_NUMBER"
    assert errors[6] == "STUDENT_ALREADY_EXISTS"
    assert errors[7] == "SOFT_DELETED_STUDENT_CONFLICT"
    assert errors[8] == "AADHAAR_ALREADY_EXISTS"
    assert errors[9] == "SECTION_CAPACITY_EXCEEDED"

@pytest.mark.anyio
async def test_validate_student_migration_security_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]

    # Create DRAFT ImportJob
    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "isolation.csv",
        "file_checksum": "checksum_iso_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    csv_content = "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date\n"
    files = {"file": ("isolation.csv", csv_content.encode("utf"), "text/csv")}

    # 1. Access from another Tenant B should return 404
    res_tb = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["tb_headers"])
    assert res_tb.status_code == 404

    # 2. Access with Teacher role should return 403 Forbidden
    res_tch = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["t_headers"])
    assert res_tch.status_code == 403

@pytest.mark.anyio
async def test_validate_student_migration_utf8_bom(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "bom.csv",
        "file_checksum": "checksum_bom_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # Prepend UTF-8 BOM bytes EF BB BF
    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_BOM_1,11,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    bom_content = b"\xef\xbb\xbf" + csv_content.encode("utf-8")

    files = {"file": ("bom.csv", bom_content, "text/csv")}
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    assert res_val.status_code == 200
    assert res_val.json()["data"]["status"] == "VALIDATED"
    assert res_val.json()["data"]["successful_rows"] == 1

@pytest.mark.anyio
async def test_validate_student_migration_missing_required_header(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "missing_header.csv",
        "file_checksum": "checksum_missing_header_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job.status_code == 201
    job_id = res_job.json()["data"]["id"]

    # CSV is missing "first_name" column header
    csv_content = "last_name,gender,date_of_birth,admission_number,roll_number,admission_date\n"
    files = {"file": ("missing_header.csv", csv_content.encode("utf-8"), "text/csv")}
    
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    print("DEBUG RESPONSE HEADER status:", res_val.status_code)
    print("DEBUG RESPONSE HEADER body:", res_val.json())
    assert res_val.status_code == 422
    assert "Missing required CSV column headers" in res_val.json()["message"]

@pytest.mark.anyio
async def test_validate_student_migration_class_section_mismatch(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "mismatch.csv",
        "file_checksum": "checksum_mismatch_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    # Supplying mismatching class name and class code
    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,class_name,class_code,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_MIS,12,2026-06-01,{ay.id},{class_1.id},MismatchClass,{class_1.code},{section_a.id}\n"
    )
    files = {"file": ("mismatch.csv", csv_content.encode("utf-8"), "text/csv")}
    
    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    assert res_val.status_code == 200
    
    res_rows = await client.get(f"/api/v1/import-jobs/{job_id}/rows", headers=data["p_headers"])
    rows_list = res_rows.json()["data"]
    print("DEBUG RESPONSE MISMATCH rows:", rows_list)
    assert rows_list[0]["status"] == "failed"
    assert rows_list[0]["error_code"] == "CLASS_SECTION_MISMATCH"

@pytest.mark.anyio
async def test_validate_student_migration_checksum_duplicate(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "dup_check.csv",
        "file_checksum": "checksum_dupcheck_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job_1 = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job_1.status_code == 201

    # Shift status to VALIDATED to ensure active checksum validation locks
    job_id = res_job_1.json()["data"]["id"]
    csv_content = "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date\n"
    files = {"file": ("dup_check.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Attempting to register another job with identical active checksum returns 409 Conflict
    res_job_2 = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    assert res_job_2.status_code == 409

@pytest.mark.anyio
async def test_validate_student_migration_non_destructive(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "destructive_check.csv",
        "file_checksum": "checksum_dest_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_DEST_1,15,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("destructive_check.csv", csv_content.encode("utf-8"), "text/csv")}

    # Get student count before validate
    res_before = await db_session.execute(select(Student))
    count_before = len(res_before.scalars().all())

    res_val = await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    assert res_val.status_code == 200

    # Get student count after validate
    res_after = await db_session.execute(select(Student))
    count_after = len(res_after.scalars().all())

    # Prove validation creates zero student records
    assert count_before == count_after

    # Prove all created_student_id are null
    res_stg = await db_session.execute(select(StudentImportRow).where(StudentImportRow.import_job_id == uuid.UUID(job_id)))
    stg_list = list(res_stg.scalars().all())
    assert len(stg_list) == 1
    assert stg_list[0].created_student_id is None

@pytest.mark.anyio
async def test_execute_single_valid_student(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "single.csv",
        "file_checksum": "checksum_single_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_SINGLE,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("single.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Start execution
    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED"
    assert val_data["successful_rows"] == 1
    assert val_data["failed_rows"] == 0

    # Verify Student is created in DB
    stmt_stud = select(Student).where(Student.admission_number == "ADM_SINGLE")
    res_stud = await db_session.execute(stmt_stud)
    student = res_stud.scalar_one_or_none()
    assert student is not None
    assert student.first_name == "John"

@pytest.mark.anyio
async def test_execute_multiple_valid_students(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    # We must temporarily increase section capacity so both can fit (setup capacity is 2, 0 active initially)
    section_a.capacity = 10
    db_session.add(section_a)
    await db_session.commit()

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "multi.csv",
        "file_checksum": "checksum_multi_123",
        "total_rows": 2,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_M1,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_M2,2,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("multi.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    assert res_start.json()["data"]["status"] == "COMPLETED"
    assert res_start.json()["data"]["successful_rows"] == 2

@pytest.mark.anyio
async def test_execute_100_plus_rows_in_chunks(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    section_a.capacity = 200
    db_session.add(section_a)
    await db_session.commit()

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "chunks.csv",
        "file_checksum": "checksum_chunks_123",
        "total_rows": 105,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_rows = [
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
    ]
    for i in range(105):
        csv_rows.append(f"Student{i},Last{i},MALE,2015-05-15,ADM_CH_{i},{i},2026-06-01,{ay.id},{class_1.id},{section_a.id}\n")
    
    csv_content = "".join(csv_rows)
    files = {"file": ("chunks.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED"
    assert val_data["successful_rows"] == 105

@pytest.mark.anyio
async def test_execute_mixed_success_and_failure(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    section_a.capacity = 10
    db_session.add(section_a)
    await db_session.commit()

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "mixed.csv",
        "file_checksum": "checksum_mixed_123",
        "total_rows": 2,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_MIX_1,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_MIX_2,2,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("mixed.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Create a conflict Student with admission number ADM_MIX_2 AFTER validation
    conflict_student = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Conflict",
        last_name="Smith",
        gender="FEMALE",
        date_of_birth=date(2015, 4, 1),
        admission_number="ADM_MIX_2",
        roll_number="99",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(conflict_student)
    await db_session.commit()

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    # Since 1 succeeded and 1 failed execution, status is COMPLETED_WITH_ERRORS
    assert val_data["status"] == "COMPLETED_WITH_ERRORS"
    assert val_data["successful_rows"] == 1
    assert val_data["failed_rows"] == 1

@pytest.mark.anyio
async def test_execution_failure_does_not_abort_remaining_rows(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    section_a.capacity = 10
    db_session.add(section_a)
    await db_session.commit()

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "abort_test.csv",
        "file_checksum": "checksum_abort_123",
        "total_rows": 3,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    # Row 1 -> Valid, Row 2 -> Mismatched section after validation, Row 3 -> Valid
    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_A1,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_A2,2,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jimmy,Doe,MALE,2015-05-15,ADM_A3,3,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("abort_test.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Create conflict for Row 2 only
    conflict_student = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Conflict",
        last_name="Smith",
        gender="FEMALE",
        date_of_birth=date(2015, 4, 1),
        admission_number="ADM_A2",
        roll_number="99",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(conflict_student)
    await db_session.commit()

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED_WITH_ERRORS"
    assert val_data["successful_rows"] == 2
    assert val_data["failed_rows"] == 1

    # Verify both ADM_A1 and ADM_A3 exist, and ADM_A2 failed staging validation cleanly
    stmt_a1 = select(Student).where(Student.admission_number == "ADM_A1")
    stmt_a3 = select(Student).where(Student.admission_number == "ADM_A3")
    assert (await db_session.execute(stmt_a1)).scalar_one_or_none() is not None
    assert (await db_session.execute(stmt_a3)).scalar_one_or_none() is not None

@pytest.mark.anyio
async def test_student_created_after_validation_is_detected(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "late_conflict.csv",
        "file_checksum": "checksum_late_123",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_LATE,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("late_conflict.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Create late student record in DB directly
    late_student = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Late",
        last_name="Student",
        gender="MALE",
        date_of_birth=date(2015, 5, 15),
        admission_number="ADM_LATE",
        roll_number="1",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(late_student)
    await db_session.commit()

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED_WITH_ERRORS"
    assert val_data["successful_rows"] == 0
    assert val_data["failed_rows"] == 1

@pytest.mark.anyio
async def test_capacity_change_after_validation_is_detected(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    # Limit section capacity to 1
    section_a.capacity = 1
    db_session.add(section_a)
    await db_session.commit()

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "capacity_late.csv",
        "file_checksum": "checksum_cap_late",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_CAP,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("capacity_late.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Create a student in DB directly to consume the 1 capacity slot
    filler_student = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Filler",
        last_name="Stud",
        gender="MALE",
        date_of_birth=date(2015, 5, 15),
        admission_number="ADM_FILLER",
        roll_number="99",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(filler_student)
    await db_session.commit()

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    
    val_data = res_start.json()["data"]
    assert val_data["status"] == "COMPLETED_WITH_ERRORS"
    assert val_data["successful_rows"] == 0
    assert val_data["failed_rows"] == 1

@pytest.mark.anyio
async def test_successful_row_sets_created_student_id(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "create_id.csv",
        "file_checksum": "checksum_create_id",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_CRE_ID,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("create_id.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])

    # Reload staging row to verify created_student_id is populated
    stmt = select(StudentImportRow).where(StudentImportRow.import_job_id == uuid.UUID(job_id))
    res = await db_session.execute(stmt)
    stg_row = res.scalar_one()
    assert stg_row.created_student_id is not None

@pytest.mark.anyio
async def test_successful_import_job_row_sets_entity_id(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "entity_id.csv",
        "file_checksum": "checksum_entity_id",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_ENT_ID,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("entity_id.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])
    await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])

    # Fetch audit row to check entity_id is set
    res_rows = await client.get(f"/api/v1/import-jobs/{job_id}/rows", headers=data["p_headers"])
    rows_list = res_rows.json()["data"]
    assert rows_list[0]["status"] == "success"
    assert rows_list[0]["entity_id"] is not None

@pytest.mark.anyio
async def test_failed_import_job_row_contains_error(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "fail_audit.csv",
        "file_checksum": "checksum_fail_audit",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_FAIL_AUDIT,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("fail_audit.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Cause late conflict to trigger execution failure
    conflict_student = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Conflict",
        last_name="Stud",
        gender="MALE",
        date_of_birth=date(2015, 5, 15),
        admission_number="ADM_FAIL_AUDIT",
        roll_number="1",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(conflict_student)
    await db_session.commit()

    await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])

    res_rows = await client.get(f"/api/v1/import-jobs/{job_id}/rows", headers=data["p_headers"])
    rows_list = res_rows.json()["data"]
    assert rows_list[0]["status"] == "failed"
    assert rows_list[0]["error_code"] == "STUDENT_ALREADY_EXISTS"
    assert rows_list[0]["entity_id"] is None

@pytest.mark.anyio
async def test_execution_counters_are_correct(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    section_a.capacity = 10
    db_session.add(section_a)
    await db_session.commit()

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "counters.csv",
        "file_checksum": "checksum_counters",
        "total_rows": 2,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_C1,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_C2,2,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("counters.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Create late conflict for ADM_C2
    conflict = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Conflict",
        last_name="Stud",
        gender="FEMALE",
        date_of_birth=date(2016, 4, 12),
        admission_number="ADM_C2",
        roll_number="99",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(conflict)
    await db_session.commit()

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    val_data = res_start.json()["data"]

    assert val_data["total_rows"] == 2
    assert val_data["processed_rows"] == 2
    assert val_data["successful_rows"] == 1
    assert val_data["failed_rows"] == 1
    assert val_data["skipped_rows"] == 0

@pytest.mark.anyio
async def test_execution_all_success_results_completed(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "success_terminal.csv",
        "file_checksum": "checksum_succ_term",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_SUCC_TERM,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("success_terminal.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.json()["data"]["status"] == "COMPLETED"

@pytest.mark.anyio
async def test_execution_partial_failure_results_completed_with_errors(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "partial.csv",
        "file_checksum": "checksum_partial",
        "total_rows": 2,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_PARTIAL_1,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jane,Doe,FEMALE,2016-04-12,ADM_PARTIAL_2,2,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("partial.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Late conflict on ADM_PARTIAL_2
    conflict = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Conflict",
        last_name="Stud",
        gender="FEMALE",
        date_of_birth=date(2016, 4, 12),
        admission_number="ADM_PARTIAL_2",
        roll_number="99",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(conflict)
    await db_session.commit()

    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.json()["data"]["status"] == "COMPLETED_WITH_ERRORS"

@pytest.mark.anyio
async def test_execution_fatal_failure_results_failed(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]

    # Register mock job and validate
    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "fatal.csv",
        "file_checksum": "checksum_fatal",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date\n"
    files = {"file": ("fatal.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Simulate database shutdown or query exception by patching the select call conditionally
    from unittest.mock import patch
    original_select = select
    def mock_select(*args, **kwargs):
        if len(args) > 0 and args[0] is StudentImportRow:
            raise Exception("Fatal DB Error")
        return original_select(*args, **kwargs)

    with pytest.raises(Exception) as exc_info:
        with patch("app.services.import_job.select", side_effect=mock_select):
            await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert "Fatal DB Error" in str(exc_info.value)

    # Verify job status transitioned to FAILED in the database
    # Since the db_session might be closed or untracked, we get a fresh session to check
    stmt_job = select(ImportJob).where(ImportJob.id == uuid.UUID(job_id))
    res_job = await db_session.execute(stmt_job)
    job_obj = res_job.scalar_one()
    assert job_obj.status == ImportJobStatus.FAILED
    assert "Fatal DB Error" in job_obj.error_summary

@pytest.mark.anyio
async def test_execution_tenant_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "iso.csv",
        "file_checksum": "checksum_iso",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_ISO,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("iso.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Attempting to start job with Tenant B credentials should return 404
    res_tb = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["tb_headers"])
    assert res_tb.status_code == 404

@pytest.mark.anyio
async def test_execution_school_isolation(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_c = data["school_c"] # School C is in Tenant B

    # Create job in School C context
    job_payload = {
        "school_id": str(school_c.id),
        "import_type": "STUDENTS",
        "source_filename": "sch_iso.csv",
        "file_checksum": "checksum_sch_iso",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["tb_headers"])
    job_id = res_job.json()["data"]["id"]

    # Start it with Tenant A headers
    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 404

@pytest.mark.anyio
async def test_terminal_job_cannot_be_reexecuted(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "reexec.csv",
        "file_checksum": "checksum_reexec",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_REEX,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("reexec.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # First execution -> succeeds and COMPLETED
    await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])

    # Second execution should return 400 Bad Request
    res_start_2 = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start_2.status_code == 400

@pytest.mark.anyio
async def test_execution_does_not_create_duplicates(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "nodup.csv",
        "file_checksum": "checksum_nodup",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_NODUP,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("nodup.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Execution 1
    await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])

    # Check student table count in school
    stmt = select(func.count(Student.id)).where(Student.admission_number == "ADM_NODUP")
    res_count = await db_session.execute(stmt)
    assert res_count.scalar() == 1

@pytest.mark.anyio
async def test_validation_failed_rows_are_not_executed(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "skip_invalid.csv",
        "file_checksum": "checksum_skip_invalid",
        "total_rows": 2,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    # Row 1 -> Valid, Row 2 -> Invalid (missing required gender)
    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_SKIP_OK,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
        f"Jane,Doe,,2016-04-12,ADM_SKIP_ERR,2,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("skip_invalid.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Execution should run and complete
    res_start = await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])
    assert res_start.status_code == 200
    assert res_start.json()["data"]["successful_rows"] == 1
    assert res_start.json()["data"]["failed_rows"] == 1

    # Verify that the invalid student ADM_SKIP_ERR is NOT created
    stmt = select(Student).where(Student.admission_number == "ADM_SKIP_ERR")
    assert (await db_session.execute(stmt)).scalar_one_or_none() is None

@pytest.mark.anyio
async def test_failed_rows_have_null_created_student_id(
    client: AsyncClient,
    db_session: AsyncSession,
    setup_student_migration_data: dict
):
    data = setup_student_migration_data
    school_a = data["school_a"]
    ay = data["ay"]
    class_1 = data["class_1"]
    section_a = data["section_a"]

    job_payload = {
        "school_id": str(school_a.id),
        "import_type": "STUDENTS",
        "source_filename": "null_id.csv",
        "file_checksum": "checksum_null_id",
        "total_rows": 1,
        "job_metadata": {}
    }
    res_job = await client.post("/api/v1/import-jobs", json=job_payload, headers=data["p_headers"])
    job_id = res_job.json()["data"]["id"]

    csv_content = (
        "first_name,last_name,gender,date_of_birth,admission_number,roll_number,admission_date,academic_year_id,class_id,section_id\n"
        f"John,Doe,MALE,2015-05-15,ADM_NULL_ID,1,2026-06-01,{ay.id},{class_1.id},{section_a.id}\n"
    )
    files = {"file": ("null_id.csv", csv_content.encode("utf-8"), "text/csv")}
    await client.post(f"/api/v1/import-jobs/{job_id}/validate", files=files, headers=data["p_headers"])

    # Cause execution failure (duplicate admission number)
    conflict = Student(
        tenant_id=data["tenant_a"].id,
        school_id=school_a.id,
        academic_year_id=ay.id,
        class_id=class_1.id,
        section_id=section_a.id,
        first_name="Conflict",
        last_name="Stud",
        gender="MALE",
        date_of_birth=date(2015, 5, 15),
        admission_number="ADM_NULL_ID",
        roll_number="99",
        admission_date=date(2026, 6, 1)
    )
    db_session.add(conflict)
    await db_session.commit()

    await client.post(f"/api/v1/import-jobs/{job_id}/start", headers=data["p_headers"])

    # Check staging row has NULL created_student_id
    stmt = select(StudentImportRow).where(StudentImportRow.import_job_id == uuid.UUID(job_id))
    res = await db_session.execute(stmt)
    stg_row = res.scalar_one()
    assert stg_row.created_student_id is None


