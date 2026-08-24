import pytest
import uuid
import os
from decimal import Decimal
from datetime import date, time, datetime, timezone, timedelta
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School, SchoolStatus
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender
from app.models.teacher import Teacher, EmploymentType
from app.models.subject import Subject, SubjectCategory, SubjectType
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.guardian import Guardian, StudentGuardian, StudentGuardianRelationship, GuardianType
from app.models.user import User, UserStatus
from app.models.role import Role, user_roles, school_users
from app.models.permission import Permission
from app.models.examination import Examination, ExamStatus, ExamType
from app.models.school_event import SchoolEvent, EventStatus, EventAudience
from app.models.announcement import Announcement, AnnouncementStatus, AnnouncementAudienceType
from app.models.fee import FeeType, FeeStructure, StudentFeeAssignment, FeePayment, FeeReceipt, PaymentStatus, PaymentMethod

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.guardian import GuardianCreate
from app.schemas.auth import UserCreate

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.subject import SubjectRepository
from app.repositories.teacher_subject_assignment import TeacherSubjectAssignmentRepository
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService


@pytest.fixture
async def setup_rc2_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenants A & B
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(
        TenantCreate(name="RC2 Tenant A", code=f"rc2-a-{suffix}", subdomain=f"rc2-a-{suffix}", email=f"rc2-a-{suffix}@t.com")
    )
    tenant_b = await repo_t.create(
        TenantCreate(name="RC2 Tenant B", code=f"rc2-b-{suffix}", subdomain=f"rc2-b-{suffix}", email=f"rc2-b-{suffix}@t.com")
    )
    await db_session.commit()

    # 2. School A & A2 (Tenant A), and School B (Tenant B)
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(
        tenant_a.id,
        SchoolCreate(name="RC2 School A", code=f"SC_A_{suffix.upper()}", address="A St", city="Blr", state="KA", country="IN", pin_code="560001", board="CBSE", email=f"sch-a-{suffix}@a.com", status=SchoolStatus.ACTIVE)
    )
    school_a2 = await repo_s.create(
        tenant_a.id,
        SchoolCreate(name="RC2 School A2", code=f"SC_A2_{suffix.upper()}", address="A2 St", city="Blr", state="KA", country="IN", pin_code="560001", board="CBSE", email=f"sch-a2-{suffix}@a.com", status=SchoolStatus.ACTIVE)
    )
    school_b = await repo_s.create(
        tenant_b.id,
        SchoolCreate(name="RC2 School B", code=f"SC_B_{suffix.upper()}", address="B St", city="Blr", state="KA", country="IN", pin_code="560001", board="CBSE", email=f"sch-b-{suffix}@b.com", status=SchoolStatus.ACTIVE)
    )
    await db_session.commit()

    # 3. Academic Years
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(
        tenant_a.id, school_a.id,
        AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True)
    )
    ay_a2 = await repo_ay.create(
        tenant_a.id, school_a2.id,
        AcademicYearCreate(school_id=school_a2.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True)
    )
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(
        tenant_a.id,
        ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Grade 10", code="G10", level=10, category=ClassCategory.HIGH, capacity=40)
    )
    class_a2 = await repo_c.create(
        tenant_a.id,
        ClassCreate(school_id=school_a2.id, academic_year_id=ay_a2.id, name="Grade 10", code="G10", level=10, category=ClassCategory.HIGH, capacity=40)
    )
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(
        tenant_a.id,
        SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Sec A", code="SEC_A", capacity=40)
    )
    sec_a2 = await repo_sec.create(
        tenant_a.id,
        SectionCreate(school_id=school_a2.id, academic_year_id=ay_a2.id, class_id=class_a2.id, name="Sec A2", code="SEC_A2", capacity=40)
    )
    await db_session.commit()

    # 5. Students
    repo_stud = StudentRepository(db_session)
    stud_a = await repo_stud.create(
        tenant_a.id,
        StudentCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id, admission_number=f"ADM-A-{suffix}", first_name="Student", last_name="A", gender=StudentGender.MALE, date_of_birth=date(2010, 1, 1), admission_date=date(2026, 1, 1), roll_number="1")
    )
    stud_a2 = await repo_stud.create(
        tenant_a.id,
        StudentCreate(school_id=school_a2.id, academic_year_id=ay_a2.id, class_id=class_a2.id, section_id=sec_a2.id, admission_number=f"ADM-A2-{suffix}", first_name="Student", last_name="A2", gender=StudentGender.FEMALE, date_of_birth=date(2010, 1, 1), admission_date=date(2026, 1, 1), roll_number="2")
    )
    await db_session.commit()

    # 6. Guardians
    repo_guard = GuardianRepository(db_session)
    guard_a = await repo_guard.create(
        tenant_a.id,
        GuardianCreate(school_id=school_a.id, guardian_type=GuardianType.FATHER, first_name="Parent", last_name="A", gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile=f"+919999{suffix[:4]}", email=f"parent-a-{suffix}@t.com")
    )
    guard_a2 = await repo_guard.create(
        tenant_a.id,
        GuardianCreate(school_id=school_a2.id, guardian_type=GuardianType.FATHER, first_name="Parent", last_name="A2", gender=StudentGender.MALE, date_of_birth=date(1980, 1, 1), mobile=f"+918888{suffix[:4]}", email=f"parent-a2-{suffix}@t.com")
    )
    await db_session.commit()

    # Link Students & Guardians
    sg_a = StudentGuardian(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        student_id=stud_a.id,
        guardian_id=guard_a.id,
        relationship=StudentGuardianRelationship.FATHER,
        is_primary=True,
        receives_notifications=True
    )
    sg_a2 = StudentGuardian(
        tenant_id=tenant_a.id,
        school_id=school_a2.id,
        student_id=stud_a2.id,
        guardian_id=guard_a2.id,
        relationship=StudentGuardianRelationship.FATHER,
        is_primary=True,
        receives_notifications=True
    )
    db_session.add(sg_a)
    db_session.add(sg_a2)
    await db_session.commit()

    # 7. Permissions Seeding (including fee, report card, exam)
    for p_code, p_name in [
        ("fee.read", "Read Fee"),
        ("fee.create", "Create Fee"),
        ("fee.report", "Fee Report"),
        ("announcement.create", "Create Announcement"),
        ("announcement.publish", "Publish Announcement"),
        ("announcement.read", "Read Announcement")
    ]:
        stmt_exist = select(Permission).where(Permission.code == p_code)
        res_exist = await db_session.execute(stmt_exist)
        if not res_exist.scalar_one_or_none():
            p_obj = Permission(id=uuid.uuid4(), name=p_name, code=p_code, description=p_name)
            db_session.add(p_obj)
    await db_session.commit()

    stmt_p = select(Permission)
    res_p = await db_session.execute(stmt_p)
    all_perms = list(res_p.scalars().all())

    # Roles creation
    admin_role = Role(name="Admin", code="ADMIN", is_system=True, tenant_id=tenant_a.id)
    admin_role.permissions = all_perms
    db_session.add(admin_role)

    principal_role = Role(name="Principal", code="PRINCIPAL", is_system=True, tenant_id=tenant_a.id)
    principal_role.permissions = [p for p in all_perms if not p.code.startswith("tenant.")]
    db_session.add(principal_role)

    teacher_role = Role(name="Teacher", code="TEACHER", is_system=True, tenant_id=tenant_a.id)
    teacher_role.permissions = [p for p in all_perms if p.code in ["exam.read", "report_card.read", "report_card.generate", "fee.read", "announcement.publish", "announcement.create"]]
    db_session.add(teacher_role)

    parent_role = Role(name="Parent", code="PARENT", is_system=True, tenant_id=tenant_a.id)
    parent_role.permissions = [p for p in all_perms if p.code in ["exam.read", "report_card.read", "fee.read"]]
    db_session.add(parent_role)
    await db_session.commit()

    # 8. Create Users
    repo_u = UserRepository(db_session)
    repo_r = RoleRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(repo_u, repo_r, PermissionRepository(db_session), refresh_repo, repo_s)

    # Principal for School A
    principal_user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=f"principal-a-{suffix}@a.com",
            password="SecurePassword123!",
            first_name="Principal",
            last_name="A",
            role_ids=[principal_role.id],
            school_ids=[school_a.id]
        )
    )

    # Principal for School A2
    principal_user_a2 = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=f"principal-a2-{suffix}@a.com",
            password="SecurePassword123!",
            first_name="Principal",
            last_name="A2",
            role_ids=[principal_role.id],
            school_ids=[school_a2.id]
        )
    )

    # Parent for Student A
    parent_user_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=f"parent-a-{suffix}@t.com",
            password="SecurePassword123!",
            first_name="Parent",
            last_name="A",
            role_ids=[parent_role.id],
            school_ids=[school_a.id]
        )
    )

    # Parent for Student A2
    parent_user_a2 = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=f"parent-a2-{suffix}@t.com",
            password="SecurePassword123!",
            first_name="Parent",
            last_name="A2",
            role_ids=[parent_role.id],
            school_ids=[school_a2.id]
        )
    )

    # Link guardians to users
    guard_a.user_id = parent_user_a.id
    db_session.add(guard_a)
    guard_a2.user_id = parent_user_a2.id
    db_session.add(guard_a2)

    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_a2": school_a2,
        "school_b": school_b,
        "ay_a": ay_a,
        "ay_a2": ay_a2,
        "class_a": class_a,
        "sec_a": sec_a,
        "stud_a": stud_a,
        "stud_a2": stud_a2,
        "parent_user_a": parent_user_a,
        "parent_user_a2": parent_user_a2,
        "principal_user_a": principal_user_a,
        "principal_user_a2": principal_user_a2,
        "auth_service": auth_service,
    }


@pytest.mark.anyio
async def test_rc2_school_isolation_exams_and_report_cards(client: AsyncClient, setup_rc2_test_data: dict) -> None:
    data = setup_rc2_test_data
    auth_service = data["auth_service"]

    # Login Principal A
    tokens_p_a = await auth_service.create_tokens(data["principal_user_a"])
    headers_p_a = {
        "Authorization": f"Bearer {tokens_p_a.access_token}",
        "X-Tenant-ID": str(data["tenant_a"].id)
    }

    # 1. Principal A lists exams for School A -> ALLOW
    res_list_a = await client.get(
        f"/api/v1/examinations?school_id={data['school_a'].id}",
        headers=headers_p_a
    )
    assert res_list_a.status_code == 200

    # 2. Principal A lists exams for School A2 (cross-school) -> DENY (403)
    res_list_a2 = await client.get(
        f"/api/v1/examinations?school_id={data['school_a2'].id}",
        headers=headers_p_a
    )
    assert res_list_a2.status_code == 403

    # 3. Principal A generates report card for School A2 -> DENY (403)
    gen_payload = {
        "school_id": str(data["school_a2"].id),
        "student_id": str(data["stud_a2"].id),
        "teacher_remarks": "Doing great."
    }
    res_gen = await client.post(
        "/api/v1/report-cards/generate",
        json=gen_payload,
        headers=headers_p_a
    )
    assert res_gen.status_code == 403


@pytest.mark.anyio
async def test_rc2_parent_child_fee_ledger_and_receipt_idor(client: AsyncClient, setup_rc2_test_data: dict, db_session: AsyncSession) -> None:
    data = setup_rc2_test_data
    auth_service = data["auth_service"]

    # Login Parent A
    tokens_parent_a = await auth_service.create_tokens(data["parent_user_a"])
    headers_parent_a = {
        "Authorization": f"Bearer {tokens_parent_a.access_token}",
        "X-Tenant-ID": str(data["tenant_a"].id)
    }

    # Setup fee structure and receipt for Student A
    fee_type = FeeType(
        tenant_id=data["tenant_a"].id,
        name="Tuition",
        code="TUIT"
    )
    db_session.add(fee_type)
    await db_session.flush()

    structure = FeeStructure(
        tenant_id=data["tenant_a"].id,
        school_id=data["school_a"].id,
        academic_year_id=data["ay_a"].id,
        fee_type_id=fee_type.id,
        amount=Decimal("10000.00"),
        due_date=date(2026, 12, 31)
    )
    db_session.add(structure)
    await db_session.flush()

    payment = FeePayment(
        tenant_id=data["tenant_a"].id,
        academic_year_id=data["ay_a"].id,
        student_id=data["stud_a"].id,
        payment_date=datetime.now(timezone.utc),
        amount_paid=Decimal("5000.00"),
        payment_method=PaymentMethod.CASH,
        status=PaymentStatus.COMPLETED
    )
    db_session.add(payment)
    await db_session.flush()

    # Create dummy pdf file path
    dummy_pdf_dir = "storage/private/receipts"
    os.makedirs(dummy_pdf_dir, exist_ok=True)
    dummy_pdf_path = os.path.join(dummy_pdf_dir, f"rc2_receipt_{uuid.uuid4().hex[:6]}.pdf")
    with open(dummy_pdf_path, "w") as f:
        f.write("Dummy PDF receipt content")

    receipt = FeeReceipt(
        tenant_id=data["tenant_a"].id,
        payment_id=payment.id,
        receipt_number="REC-10001",
        pdf_path=dummy_pdf_path
    )
    db_session.add(receipt)
    await db_session.commit()

    # 1. Parent A reads Student A's ledger -> ALLOW
    res_ledger_a = await client.get(
        f"/api/v1/fees/ledgers/{data['stud_a'].id}",
        headers=headers_parent_a
    )
    assert res_ledger_a.status_code == 200

    # 2. Parent A reads Student A2's ledger -> DENY (403)
    res_ledger_a2 = await client.get(
        f"/api/v1/fees/ledgers/{data['stud_a2'].id}",
        headers=headers_parent_a
    )
    assert res_ledger_a2.status_code == 403

    # 3. Parent A downloads Student A's receipt -> ALLOW (fixes original report vs. read gap)
    res_receipt_a = await client.get(
        f"/api/v1/fees/receipts/{receipt.receipt_number}/download",
        headers=headers_parent_a
    )
    assert res_receipt_a.status_code == 200

    # Clean up physical receipt file
    if os.path.exists(dummy_pdf_path):
        os.remove(dummy_pdf_path)


@pytest.mark.anyio
async def test_rc2_notification_naive_timezone_scheduling(client: AsyncClient, setup_rc2_test_data: dict, db_session: AsyncSession) -> None:
    data = setup_rc2_test_data
    auth_service = data["auth_service"]

    # Login Principal A
    tokens_p_a = await auth_service.create_tokens(data["principal_user_a"])
    headers_p_a = {
        "Authorization": f"Bearer {tokens_p_a.access_token}",
        "X-Tenant-ID": str(data["tenant_a"].id)
    }

    # Create scheduled notification targeted to parents with naive datetime string
    naive_dt_str = "2026-10-15T09:00:00"
    notification_payload = {
        "notification_type": "GENERAL",
        "priority": "NORMAL",
        "title": "RC2 Scheduled Broadcast",
        "message": "This is a scheduled event.",
        "target_role": "PARENT",
        "school_id": str(data["school_a"].id),
        "scheduled_at": naive_dt_str,
        "event_type": "ANNOUNCEMENT"
    }

    res_create = await client.post(
        "/api/v1/notifications",
        json=notification_payload,
        headers=headers_p_a
    )
    assert res_create.status_code == 201
    
    # Query notification to verify scheduled_at was stored as timezone-aware UTC
    from app.models.notification import Notification
    stmt = select(Notification).where(
        Notification.tenant_id == data["tenant_a"].id,
        Notification.school_id == data["school_a"].id,
        Notification.event_type == "ANNOUNCEMENT"
    )
    res = await db_session.execute(stmt)
    notifications = res.scalars().all()
    
    assert len(notifications) > 0
    for notif in notifications:
        assert notif.scheduled_at is not None
        # In SQLite, the datetime is retrieved as timezone-naive but matches the converted UTC time (03:30:00)
        assert notif.scheduled_at.hour == 3
        assert notif.scheduled_at.minute == 30
