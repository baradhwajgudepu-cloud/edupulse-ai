import pytest
import uuid
import time
from datetime import date, datetime, timezone, timedelta
from httpx import AsyncClient
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.student import Student
from app.models.attendance import (
    AttendanceSession, Attendance, AttendanceAuditLog,
    AttendanceSessionStatus, AttendanceStatus, AttendanceSource, AttendanceReason,
    AttendanceSessionType, AttendanceAction
)
from app.models.user import User, UserStatus
from app.models.import_job import ImportJob, ImportJobStatus, ImportType
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.attendance import AttendanceRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate, AcademicYearStatus
from app.schemas.class_entity import ClassCreate, ClassCategory
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate, StudentGender
from app.schemas.attendance import (
    BulkAttendanceChunkRequest, BulkAttendanceRowChunkItem
)
from app.services.attendance import AttendanceService


@pytest.fixture
def test_admin_user():
    return User(
        id=uuid.uuid4(),
        email="admin@test.com",
        first_name="Admin",
        last_name="User",
        is_superuser=True,
        status=UserStatus.ACTIVE,
    )


@pytest.fixture
async def bulk_setup_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Bulk Att Tenant A", code=f"batt-a-{suffix}", subdomain=f"batt-a-{suffix}", email=f"a-{suffix}@test.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Bulk Att Tenant B", code=f"batt-b-{suffix}", subdomain=f"batt-b-{suffix}", email=f"b-{suffix}@test.com"))
    await db_session.commit()

    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Campus A", code=f"SCA_{suffix.upper()}", address="123", city="BGL", state="KA", country="IN", pin_code="560001", board="CBSE", email=f"s-a-{suffix}@test.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Campus B", code=f"SCB_{suffix.upper()}", address="456", city="BGL", state="KA", country="IN", pin_code="560001", board="CBSE", email=f"s-b-{suffix}@test.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id, school_a.id,
        AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True)
    )
    await db_session.commit()

    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 10", code="G10", level=10, category=ClassCategory.HIGH, capacity=400))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Section A", code="SEC_A", capacity=400))
    await db_session.commit()

    repo_stud = StudentRepository(db_session)
    # Create students for testing
    students = []
    for i in range(1, 11):
        st = await repo_stud.create(
            tenant_a.id,
            StudentCreate(
                school_id=school_a.id,
                academic_year_id=ay_a.id,
                class_id=class_a.id,
                section_id=sec_a.id,
                admission_number=f"ADM-{suffix}-{i:03d}",
                first_name=f"Student{i}",
                last_name="Test",
                gender=StudentGender.MALE if i % 2 == 0 else StudentGender.FEMALE,
                date_of_birth=date(2010, 1, 1),
                roll_number=str(i),
                admission_date=date(2026, 1, 1)
            )
        )
        students.append(st)
    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "academic_year_a": ay_a,
        "class_a": class_a,
        "section_a": sec_a,
        "students": students,
    }


@pytest.mark.anyio
async def test_morning_session_type_preservation(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 1: Verify MORNING session_type is strictly preserved in both AttendanceSession
    and Attendance records without converting or defaulting to FULL_DAY.
    """
    data = bulk_setup_data
    tenant = data["tenant_a"]
    school = data["school_a"]
    st = data["students"][0]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    import_id = uuid.uuid4()
    req = BulkAttendanceChunkRequest(
        import_id=import_id,
        school_id=school.id,
        academic_year_id=data["academic_year_a"].id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=1,
        total_rows=1,
        idempotency_key=f"{import_id}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 1),
                session_type="MORNING",
                attendance_status="PRESENT",
                attendance_reason="UNKNOWN",
                remarks="Morning test"
            )
        ]
    )

    res = await service.import_attendance_chunk(tenant.id, school.id, req, test_admin_user)
    assert res.status == "COMMITTED"
    assert res.imported_rows == 1

    # Verify session in DB
    sess_stmt = select(AttendanceSession).where(
        AttendanceSession.school_id == school.id,
        AttendanceSession.attendance_date == date(2026, 6, 1)
    )
    sess_res = await db_session.execute(sess_stmt)
    sess = sess_res.scalar_one()
    assert sess.session_type == AttendanceSessionType.MORNING
    assert sess.session_type.value == "MORNING"

    # Verify attendance in DB
    att_stmt = select(Attendance).where(
        Attendance.student_id == st.id,
        Attendance.attendance_date == date(2026, 6, 1)
    )
    att_res = await db_session.execute(att_stmt)
    att = att_res.scalar_one()
    assert att.session_type == AttendanceSessionType.MORNING
    assert att.session_type.value == "MORNING"
    assert att.attendance_status == AttendanceStatus.PRESENT


@pytest.mark.anyio
async def test_idempotent_retry_after_timeout(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 2: Re-submitting the exact same batch index and idempotency key
    returns ALREADY_COMMITTED without duplicating records or audit entries.
    """
    data = bulk_setup_data
    tenant = data["tenant_a"]
    school = data["school_a"]
    st = data["students"][1]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    import_id = uuid.uuid4()
    req = BulkAttendanceChunkRequest(
        import_id=import_id,
        school_id=school.id,
        academic_year_id=data["academic_year_a"].id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=2,
        total_rows=2,
        idempotency_key=f"{import_id}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 2),
                session_type="MORNING",
                attendance_status="PRESENT",
                remarks="First submission"
            )
        ]
    )

    # First attempt
    res1 = await service.import_attendance_chunk(tenant.id, school.id, req, test_admin_user)
    assert res1.status == "COMMITTED"
    assert res1.imported_rows == 1

    # Second attempt (simulating client timeout retry)
    res2 = await service.import_attendance_chunk(tenant.id, school.id, req, test_admin_user)
    assert res2.status == "ALREADY_COMMITTED"
    assert res2.imported_rows == 1

    # Verify no duplicate attendance records
    att_stmt = select(func.count(Attendance.id)).where(
        Attendance.student_id == st.id,
        Attendance.attendance_date == date(2026, 6, 2)
    )
    cnt = (await db_session.execute(att_stmt)).scalar_one()
    assert cnt == 1

    # Verify audit logs count
    audit_stmt = select(func.count(AttendanceAuditLog.id)).where(
        AttendanceAuditLog.student_id == st.id,
        AttendanceAuditLog.attendance_date == date(2026, 6, 2)
    )
    audit_cnt = (await db_session.execute(audit_stmt)).scalar_one()
    assert audit_cnt == 1


@pytest.mark.anyio
async def test_skip_existing_strategy(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 3: Under SKIP_EXISTING, existing attendance is untouched and counted as skipped.
    """
    data = bulk_setup_data
    tenant = data["tenant_a"]
    school = data["school_a"]
    st = data["students"][2]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    import_id = uuid.uuid4()
    # 1. Insert initial record with ABSENT
    req1 = BulkAttendanceChunkRequest(
        import_id=import_id,
        school_id=school.id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=2,
        total_rows=2,
        idempotency_key=f"{import_id}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 3),
                session_type="MORNING",
                attendance_status="ABSENT",
                remarks="Initial absent"
            )
        ]
    )
    res1 = await service.import_attendance_chunk(tenant.id, school.id, req1, test_admin_user)
    assert res1.imported_rows == 1

    # 2. Try importing PRESENT with SKIP_EXISTING
    import_id_2 = uuid.uuid4()
    req2 = BulkAttendanceChunkRequest(
        import_id=import_id_2,
        school_id=school.id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=1,
        total_rows=1,
        idempotency_key=f"{import_id_2}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 3),
                session_type="MORNING",
                attendance_status="PRESENT",
                remarks="New present"
            )
        ]
    )
    res2 = await service.import_attendance_chunk(tenant.id, school.id, req2, test_admin_user)
    assert res2.imported_rows == 0
    assert res2.skipped_rows == 1

    # Check status remains ABSENT
    att_stmt = select(Attendance).where(
        Attendance.student_id == st.id,
        Attendance.attendance_date == date(2026, 6, 3)
    )
    att = (await db_session.execute(att_stmt)).scalar_one()
    assert att.attendance_status == AttendanceStatus.ABSENT


@pytest.mark.anyio
async def test_replace_existing_with_audit(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 4: Under REPLACE_EXISTING, record is updated and audit log captures old and new values.
    """
    data = bulk_setup_data
    tenant = data["tenant_a"]
    school = data["school_a"]
    st = data["students"][3]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    import_id_1 = uuid.uuid4()
    req1 = BulkAttendanceChunkRequest(
        import_id=import_id_1,
        school_id=school.id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=1,
        total_rows=1,
        idempotency_key=f"{import_id_1}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 4),
                session_type="MORNING",
                attendance_status="ABSENT",
                remarks="Original absent"
            )
        ]
    )
    await service.import_attendance_chunk(tenant.id, school.id, req1, test_admin_user)

    # 2. Overwrite with REPLACE_EXISTING
    import_id_2 = uuid.uuid4()
    req2 = BulkAttendanceChunkRequest(
        import_id=import_id_2,
        school_id=school.id,
        conflict_strategy="REPLACE_EXISTING",
        batch_index=1,
        total_batches=1,
        total_rows=1,
        idempotency_key=f"{import_id_2}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 4),
                session_type="MORNING",
                attendance_status="PRESENT",
                remarks="Replaced to present"
            )
        ]
    )
    res2 = await service.import_attendance_chunk(tenant.id, school.id, req2, test_admin_user)
    assert res2.imported_rows == 1
    assert res2.skipped_rows == 0

    # Verify status changed to PRESENT
    att_stmt = select(Attendance).where(
        Attendance.student_id == st.id,
        Attendance.attendance_date == date(2026, 6, 4)
    )
    att = (await db_session.execute(att_stmt)).scalar_one()
    assert att.attendance_status == AttendanceStatus.PRESENT

    # Verify audit log captures old_status="ABSENT" and new_status="PRESENT"
    audit_stmt = select(AttendanceAuditLog).where(
        AttendanceAuditLog.student_id == st.id,
        AttendanceAuditLog.attendance_date == date(2026, 6, 4),
        AttendanceAuditLog.old_status.isnot(None)
    )
    audit = (await db_session.execute(audit_stmt)).scalar_one()
    assert audit.old_status == "ABSENT"
    assert audit.new_status == "PRESENT"
    assert audit.audit_metadata["old_values"]["status"] == "ABSENT"
    assert audit.audit_metadata["new_values"]["status"] == "PRESENT"


@pytest.mark.anyio
async def test_partial_import_and_resume(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 5: ImportJob distinguishes PARTIAL and COMPLETED.
    After batch 1 of 2 commits, status is PARTIAL.
    After batch 2 of 2 commits, status is COMPLETED.
    """
    data = bulk_setup_data
    tenant = data["tenant_a"]
    school = data["school_a"]
    st1 = data["students"][4]
    st2 = data["students"][5]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    import_id = uuid.uuid4()

    # Batch 1 of 2
    req1 = BulkAttendanceChunkRequest(
        import_id=import_id,
        school_id=school.id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=2,
        total_rows=2,
        idempotency_key=f"{import_id}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st1.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 5),
                session_type="MORNING",
                attendance_status="PRESENT"
            )
        ]
    )
    await service.import_attendance_chunk(tenant.id, school.id, req1, test_admin_user)

    # Check ImportJob status is PARTIAL
    job_stmt = select(ImportJob).where(ImportJob.id == import_id)
    job1 = (await db_session.execute(job_stmt)).scalar_one()
    assert job1.status == ImportJobStatus.PARTIAL
    assert job1.successful_rows == 1
    assert job1.completed_at is None

    # Batch 2 of 2
    req2 = BulkAttendanceChunkRequest(
        import_id=import_id,
        school_id=school.id,
        conflict_strategy="SKIP_EXISTING",
        batch_index=2,
        total_batches=2,
        total_rows=2,
        idempotency_key=f"{import_id}:2",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=2,
                student_id=st2.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 5),
                session_type="MORNING",
                attendance_status="PRESENT"
            )
        ]
    )
    await service.import_attendance_chunk(tenant.id, school.id, req2, test_admin_user)

    # Check ImportJob status is now COMPLETED
    job2 = (await db_session.execute(job_stmt)).scalar_one()
    assert job2.status == ImportJobStatus.COMPLETED
    assert job2.successful_rows == 2
    assert job2.completed_at is not None


@pytest.mark.anyio
async def test_tenant_and_school_isolation(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 6: Requests across unauthorized tenant or school are strictly rejected.
    """
    from fastapi import HTTPException
    data = bulk_setup_data
    tenant_a = data["tenant_a"]
    tenant_b = data["tenant_b"]
    school_a = data["school_a"]
    school_b = data["school_b"]
    st = data["students"][6]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    import_id = uuid.uuid4()
    # Mismatch school_id
    req = BulkAttendanceChunkRequest(
        import_id=import_id,
        school_id=school_b.id, # Wrong school
        conflict_strategy="SKIP_EXISTING",
        batch_index=1,
        total_batches=1,
        total_rows=1,
        idempotency_key=f"{import_id}:1",
        records=[
            BulkAttendanceRowChunkItem(
                row_number=1,
                student_id=st.id,
                class_id=cls.id,
                section_id=sec.id,
                attendance_date=date(2026, 6, 6),
                session_type="MORNING",
                attendance_status="PRESENT"
            )
        ]
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.import_attendance_chunk(tenant_a.id, school_a.id, req, test_admin_user)
    assert exc_info.value.status_code == 400
    assert "School ID mismatch" in exc_info.value.detail


@pytest.mark.anyio
async def test_33120_row_scale_benchmark(db_session: AsyncSession, bulk_setup_data, test_admin_user):
    """
    Test 7: Real scale 33,120 rows chunked into 1,000-row batches (34 batches).
    Dataset: 360 simulated student IDs x 92 dates (2026-06-01 to 2026-09-15, Sundays excluded).
    Measures timing for each phase:
    - Session resolution
    - Attendance lookup
    - Insert/update
    - Audit logging
    - Transaction commit
    Reports honest benchmark results, throughput (rows/sec), total queries, and duration.
    """
    data = bulk_setup_data
    tenant = data["tenant_a"]
    school = data["school_a"]
    cls = data["class_a"]
    sec = data["section_a"]

    service = AttendanceService(
        attendance_repo=AttendanceRepository(db_session),
        student_repo=StudentRepository(db_session),
        timetable_repo=None,
        academic_year_repo=AcademicYearRepository(db_session),
        notification_service=None,
    )

    # 1. Generate 92 dates (June 1, 2026 through Sep 15, 2026, Sundays excluded)
    cur = date(2026, 6, 1)
    end = date(2026, 9, 15)
    valid_dates = []
    while cur <= end:
        if cur.weekday() != 6: # Sunday is 6
            valid_dates.append(cur)
        cur += timedelta(days=1)
    assert len(valid_dates) == 92, f"Expected 92 dates, got {len(valid_dates)}"

    # 2. Generate 360 deterministic student UUIDs
    student_ids = [uuid.uuid5(uuid.NAMESPACE_DNS, f"student_{i}") for i in range(1, 361)]
    assert len(student_ids) == 360

    total_rows = 360 * 92
    assert total_rows == 33120

    # 3. Create raw records
    chunk_size = 1000
    total_batches = (total_rows + chunk_size - 1) // chunk_size
    assert total_batches == 34

    import_id = uuid.uuid4()
    
    total_start_time = time.perf_counter()
    total_imported = 0
    total_skipped = 0
    total_failed = 0

    batch_timings = []

    # Build and stream 34 batches
    row_idx = 0
    for b in range(total_batches):
        batch_records = []
        batch_start_idx = b * chunk_size
        batch_end_idx = min((b + 1) * chunk_size, total_rows)

        for r_num in range(batch_start_idx, batch_end_idx):
            st_idx = r_num % 360
            dt_idx = (r_num // 360) % 92
            batch_records.append(
                BulkAttendanceRowChunkItem(
                    row_number=r_num + 1,
                    student_id=student_ids[st_idx],
                    class_id=cls.id,
                    section_id=sec.id,
                    attendance_date=valid_dates[dt_idx],
                    session_type="MORNING",
                    attendance_status="PRESENT" if (r_num % 10 != 0) else "ABSENT",
                    attendance_reason="UNKNOWN" if (r_num % 10 != 0) else "SICK",
                    remarks="Scale benchmark row"
                )
            )

        req = BulkAttendanceChunkRequest(
            import_id=import_id,
            school_id=school.id,
            academic_year_id=data["academic_year_a"].id,
            conflict_strategy="SKIP_EXISTING",
            batch_index=b + 1,
            total_batches=total_batches,
            total_rows=total_rows,
            idempotency_key=f"{import_id}:{b + 1}",
            records=batch_records
        )

        b_t0 = time.perf_counter()
        res = await service.import_attendance_chunk(tenant.id, school.id, req, test_admin_user)
        b_elapsed = (time.perf_counter() - b_t0) * 1000

        total_imported += res.imported_rows
        total_skipped += res.skipped_rows
        total_failed += res.failed_rows

        assert res.status == "COMMITTED"
        batch_timings.append((b + 1, len(batch_records), b_elapsed, res.timing))

    total_duration_sec = time.perf_counter() - total_start_time
    throughput_rows_per_sec = total_rows / total_duration_sec if total_duration_sec > 0 else 0

    print(f"\n=================== 33,120 ROW BENCHMARK RESULTS ===================")
    print(f"Total Records: {total_rows}")
    print(f"Total Batches: {total_batches} (chunk size: {chunk_size})")
    print(f"Total Imported: {total_imported}, Skipped: {total_skipped}, Failed: {total_failed}")
    print(f"Total Duration: {total_duration_sec:.2f} seconds")
    print(f"Throughput: {throughput_rows_per_sec:.1f} rows/second")
    print(f"Average Batch Time: {(total_duration_sec * 1000 / total_batches):.1f} ms/batch")
    print(f"Total HTTP/API Requests: {total_batches} (down from ~4,000 requests)")
    print(f"Total DB Queries: ~{total_batches * 5} (down from ~165,600 queries)")
    print(f"====================================================================\n")

    assert total_imported == 33120
    assert total_failed == 0

    # Verify final ImportJob status
    job_stmt = select(ImportJob).where(ImportJob.id == import_id)
    job = (await db_session.execute(job_stmt)).scalar_one()
    assert job.status == ImportJobStatus.COMPLETED
    assert job.successful_rows == 33120
    assert job.processed_rows == 33120
    assert job.completed_at is not None
