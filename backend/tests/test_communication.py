import os
import uuid
import pytest
from datetime import date, datetime, timezone
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from unittest.mock import AsyncMock, patch

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentStatus, StudentGender
from app.models.guardian import Guardian, GuardianStatus, GuardianType, StudentGuardian, StudentGuardianRelationship
from app.models.role import Role
from app.models.permission import Permission
from app.models.user import User, UserStatus
from app.models.communication import (
    CommunicationRequest, CommunicationMessage, CommunicationParticipant,
    CommunicationAttachment, CommunicationAuditLog, RequestStatus,
    RequestCategory, RequestPriority, RecipientType, Module
)

from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.repositories.guardian import GuardianRepository, StudentGuardianRepository
from app.repositories.auth import UserRepository, RoleRepository, PermissionRepository, RefreshTokenRepository
from app.services.auth import AuthService

from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate
from app.schemas.guardian import GuardianCreate, StudentGuardianCreate
from app.schemas.auth import UserCreate

@pytest.fixture
async def setup_communication_test_data(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()

    # 1. Tenants
    repo_t = TenantRepository(db_session)
    tenant_a = await repo_t.create(TenantCreate(name="Comm Tenant A", code=f"comm-a-{suffix}", subdomain=f"comm-a-{suffix}", email=f"a-{suffix}@t.com"))
    tenant_b = await repo_t.create(TenantCreate(name="Comm Tenant B", code=f"comm-b-{suffix}", subdomain=f"comm-b-{suffix}", email=f"b-{suffix}@t.com"))
    await db_session.commit()

    # 2. Schools
    repo_s = SchoolRepository(db_session)
    school_a = await repo_s.create(tenant_a.id, SchoolCreate(name="Comm School A", code=f"CA_{suffix.upper()}", board="CBSE", email=f"s-a-{suffix}@a.com", status=SchoolStatus.ACTIVE))
    school_b = await repo_s.create(tenant_b.id, SchoolCreate(name="Comm School B", code=f"CB_{suffix.upper()}", board="CBSE", email=f"s-b-{suffix}@b.com", status=SchoolStatus.ACTIVE))
    await db_session.commit()

    # 3. Academic Year
    repo_ay = AcademicYearRepository(db_session)
    ay_a = await repo_ay.create(tenant_a.id, school_a.id, AcademicYearCreate(school_id=school_a.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_a.status = AcademicYearStatus.ACTIVE
    
    ay_b = await repo_ay.create(tenant_b.id, school_b.id, AcademicYearCreate(school_id=school_b.id, name="Year 2026", code="AY2026", start_date=date(2026, 1, 1), end_date=date(2026, 12, 31), status=AcademicYearStatus.ACTIVE, is_current=True))
    ay_b.status = AcademicYearStatus.ACTIVE
    await db_session.commit()

    # 4. Classes & Sections
    repo_c = ClassRepository(db_session)
    class_a = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Class 8", code="C8", level=8, category=ClassCategory.PRIMARY, capacity=30))
    class_b = await repo_c.create(tenant_b.id, ClassCreate(school_id=school_b.id, academic_year_id=ay_b.id, name="Class 8", code="C8", level=8, category=ClassCategory.PRIMARY, capacity=30))
    await db_session.commit()

    repo_sec = SectionRepository(db_session)
    sec_a = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Sec A", code="SA", capacity=30))
    sec_b = await repo_sec.create(tenant_b.id, SectionCreate(school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Sec B", code="SB", capacity=30))
    await db_session.commit()

    # 5. Students
    repo_std = StudentRepository(db_session)
    student_a = await repo_std.create(tenant_a.id, StudentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
        admission_number="ADM-001", roll_number="R-01", first_name="Rahul", last_name="Kumar",
        gender=StudentGender.MALE, date_of_birth=date(2012, 5, 10), admission_date=date(2026, 6, 1)
    ))
    
    student_b = await repo_std.create(tenant_b.id, StudentCreate(
        school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, section_id=sec_b.id,
        admission_number="ADM-002", roll_number="R-02", first_name="Priya", last_name="Sharma",
        gender=StudentGender.FEMALE, date_of_birth=date(2013, 8, 15), admission_date=date(2026, 6, 1)
    ))

    student_c = await repo_std.create(tenant_a.id, StudentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
        admission_number="ADM-003", roll_number="R-03", first_name="Vikram", last_name="Singh",
        gender=StudentGender.MALE, date_of_birth=date(2012, 11, 20), admission_date=date(2026, 6, 1)
    ))
    await db_session.commit()

    # 6. User Setup (Auth & Roles & Permissions)
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, repo_s)

    # Fetch existing Roles (created automatically by initialize_tenant_rbac)
    stmt_role_p_a = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PARENT")
    role_parent = (await db_session.execute(stmt_role_p_a)).scalar_one()

    stmt_role_t_a = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER")
    role_teacher = (await db_session.execute(stmt_role_t_a)).scalar_one()

    stmt_role_pr_a = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "PRINCIPAL")
    role_principal = (await db_session.execute(stmt_role_pr_a)).scalar_one()

    stmt_role_p_b = select(Role).where(Role.tenant_id == tenant_b.id, Role.code == "PARENT")
    role_parent_b = (await db_session.execute(stmt_role_p_b)).scalar_one()

    await db_session.commit()

    # Guardian Records & Linkage
    guardian_email_a = f"parent-a-{suffix}@gmail.com"
    guardian_repo_a = GuardianRepository(db_session)
    guardian_a = await guardian_repo_a.create(tenant_a.id, GuardianCreate(
        school_id=school_a.id, first_name="John", last_name="Doe", gender=StudentGender.MALE,
        date_of_birth=date(1985, 1, 1), mobile="9876543210", email=guardian_email_a,
        guardian_type=GuardianType.FATHER, status=GuardianStatus.ACTIVE
    ))
    await db_session.commit()

    student_guardian_repo = StudentGuardianRepository(db_session)
    await student_guardian_repo.create(tenant_a.id, StudentGuardianCreate(
        school_id=school_a.id, student_id=student_a.id, guardian_id=guardian_a.id,
        relationship=StudentGuardianRelationship.FATHER, is_primary=True, receives_notifications=True
    ))
    await db_session.commit()

    guardian_email_b = f"parent-b-{suffix}@gmail.com"
    guardian_repo_b = GuardianRepository(db_session)
    guardian_b = await guardian_repo_b.create(tenant_b.id, GuardianCreate(
        school_id=school_b.id, first_name="Mary", last_name="Smith", gender=StudentGender.FEMALE,
        date_of_birth=date(1987, 2, 2), mobile="9876543211", email=guardian_email_b,
        guardian_type=GuardianType.MOTHER, status=GuardianStatus.ACTIVE
    ))
    await db_session.commit()

    await student_guardian_repo.create(tenant_b.id, StudentGuardianCreate(
        school_id=school_b.id, student_id=student_b.id, guardian_id=guardian_b.id,
        relationship=StudentGuardianRelationship.MOTHER, is_primary=True, receives_notifications=True
    ))
    await db_session.commit()

    # User Accounts
    user_p_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=guardian_email_a,
            password="Password123!",
            first_name="John",
            last_name="Doe",
            role_ids=[role_parent.id],
            school_ids=[school_a.id]
        )
    )

    user_t_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=f"teacher-{suffix}@school.edu",
            password="Password123!",
            first_name="T",
            last_name="One",
            role_ids=[role_teacher.id],
            school_ids=[school_a.id]
        )
    )

    # Let's seed class teacher assignment for user_t_a
    # We need a Teacher model first
    from app.models.teacher import Teacher, EmploymentType
    teacher_model = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        user_id=user_t_a.id,
        employee_code=f"EMP_{suffix.upper()}",
        staff_code=f"STF_{suffix.upper()}",
        first_name="T",
        last_name="One",
        gender=StudentGender.MALE,
        date_of_birth=date(1980, 1, 1),
        mobile=f"987654{suffix[:4]}",
        official_email=f"teacher-{suffix}@school.edu",
        joining_date=date(2020, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        designation="TGT",
        status="ACTIVE",
        is_active=True
    )
    db_session.add(teacher_model)
    await db_session.commit()
    await db_session.refresh(teacher_model)

    from app.models.teacher_subject_assignment import TeacherSubjectAssignment
    from app.models.subject import Subject, SubjectCategory, SubjectType
    subject_a = Subject(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        subject_name="Maths",
        subject_code=f"MATH_{suffix.upper()}",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
        is_active=True
    )
    db_session.add(subject_a)
    await db_session.commit()
    await db_session.refresh(subject_a)

    from app.models.teacher_subject_assignment import AssignmentType
    tsa = TeacherSubjectAssignment(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        academic_year_id=ay_a.id,
        teacher_id=teacher_model.id,
        subject_id=subject_a.id,
        class_id=class_a.id,
        section_id=sec_a.id,
        assignment_type=AssignmentType.PRIMARY,
        weekly_periods=4,
        effective_from=date(2026, 1, 1),
        assigned_at=datetime.now(timezone.utc),
        is_class_teacher=True,
        is_active=True
    )
    db_session.add(tsa)
    await db_session.commit()

    user_pr_a = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email=f"principal-{suffix}@school.edu",
            password="Password123!",
            first_name="Pr",
            last_name="One",
            role_ids=[role_principal.id],
            school_ids=[school_a.id]
        )
    )

    user_p_b = await auth_service.create_user(
        tenant_b.id,
        UserCreate(
            email=guardian_email_b,
            password="Password123!",
            first_name="Mary",
            last_name="Smith",
            role_ids=[role_parent_b.id],
            school_ids=[school_b.id]
        )
    )

    # Link guardians to users
    guardian_a.user_id = user_p_a.id
    db_session.add(guardian_a)
    
    guardian_b.user_id = user_p_b.id
    db_session.add(guardian_b)
    await db_session.commit()

    # Generate Auth Tokens
    tokens_parent = await auth_service.create_tokens(user_p_a)
    tokens_teacher = await auth_service.create_tokens(user_t_a)
    tokens_principal = await auth_service.create_tokens(user_pr_a)
    tokens_parent_b = await auth_service.create_tokens(user_p_b)

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "student_a": student_a,
        "student_b": student_b,
        "student_c": student_c,
        "ay_a": ay_a,
        "class_a": class_a,
        "sec_a": sec_a,
        "user_parent": user_p_a,
        "user_teacher": user_t_a,
        "user_principal": user_pr_a,
        "user_parent_b": user_p_b,
        "teacher_model": teacher_model,
        "headers_parent": {"Authorization": f"Bearer {tokens_parent.access_token}", "X-Tenant-ID": str(tenant_a.id)},
        "headers_teacher": {"Authorization": f"Bearer {tokens_teacher.access_token}", "X-Tenant-ID": str(tenant_a.id)},
        "headers_principal": {"Authorization": f"Bearer {tokens_principal.access_token}", "X-Tenant-ID": str(tenant_a.id)},
        "headers_parent_b": {"Authorization": f"Bearer {tokens_parent_b.access_token}", "X-Tenant-ID": str(tenant_b.id)}
    }


@pytest.mark.anyio
async def test_complete_communication_lifecycle(client: AsyncClient, setup_communication_test_data, db_session) -> None:
    headers_parent = setup_communication_test_data["headers_parent"]
    headers_teacher = setup_communication_test_data["headers_teacher"]
    headers_principal = setup_communication_test_data["headers_principal"]
    headers_parent_b = setup_communication_test_data["headers_parent_b"]

    student_a_id = str(setup_communication_test_data["student_a"].id)
    student_b_id = str(setup_communication_test_data["student_b"].id)

    # 1. Parent creates request (recipient CLASS_TEACHER to test auto-resolution)
    payload = {
        "student_id": student_a_id,
        "recipient_type": "CLASS_TEACHER",
        "category": "ACADEMIC",
        "subject": "Regarding Math homework delay",
        "priority": "NORMAL",
        "message": "Dear teacher, Rahul needs an extra day for the assignment due to fever."
    }

    resp = await client.post("/api/v1/communication/requests", json=payload, headers=headers_parent)
    assert resp.status_code == 201
    res_data = resp.json()["data"]
    assert res_data["subject"] == "Regarding Math homework delay"
    assert res_data["status"] == "OPEN"
    request_id = res_data["id"]

    # 2. Parent can only select own child (fails for student B due to tenant isolation)
    payload_invalid = {
        "student_id": student_b_id,
        "recipient_type": "TEACHER",
        "category": "ACADEMIC",
        "subject": "Intruder parent",
        "priority": "HIGH",
        "message": "I shouldn't be allowed to post this."
    }
    resp_invalid = await client.post("/api/v1/communication/requests", json=payload_invalid, headers=headers_parent)
    assert resp_invalid.status_code == 404

    # 2b. Same tenant, but not parent's child (fails with 403)
    student_c_id = str(setup_communication_test_data["student_c"].id)
    payload_invalid_403 = {
        "student_id": student_c_id,
        "recipient_type": "TEACHER",
        "category": "ACADEMIC",
        "subject": "Same tenant intruder",
        "priority": "HIGH",
        "message": "I shouldn't be allowed to post this."
    }
    resp_invalid_403 = await client.post("/api/v1/communication/requests", json=payload_invalid_403, headers=headers_parent)
    assert resp_invalid_403.status_code == 403

    # 3. Parent cannot access another parent's request
    resp_detail_invalid = await client.get(f"/api/v1/communication/requests/{request_id}", headers=headers_parent_b)
    assert resp_detail_invalid.status_code in [403, 404]

    # 4. Class teacher auto-resolution check
    # The assignee of request_id should be the teacher user user_t_a
    db_req = await db_session.get(CommunicationRequest, uuid.UUID(request_id))
    assert db_req.assigned_to_id == setup_communication_test_data["user_teacher"].id

    # 5. Teacher receives request (GET /requests)
    resp_list = await client.get("/api/v1/communication/requests", headers=headers_teacher)
    assert resp_list.status_code == 200
    list_data = resp_list.json()["data"]
    assert len(list_data) >= 1
    assert any(r["id"] == request_id for r in list_data)

    # 6. Teacher replies
    reply_payload = {"message": "Sure, I have extended it. Please submit by Friday."}
    resp_reply = await client.post(f"/api/v1/communication/requests/{request_id}/messages", json=reply_payload, headers=headers_teacher)
    assert resp_reply.status_code == 201
    reply_data = resp_reply.json()["data"]
    assert reply_data["sender_role"] == "TEACHER"

    # 7. Parent receives reply (unread count and detail checking)
    resp_detail = await client.get(f"/api/v1/communication/requests/{request_id}", headers=headers_parent)
    assert resp_detail.status_code == 200
    detail_data = resp_detail.json()["data"]
    assert len(detail_data["messages"]) == 2
    assert detail_data["messages"][1]["message"] == "Sure, I have extended it. Please submit by Friday."

    # 8. Teacher updates status to IN_PROGRESS
    status_payload = {"status": "IN_PROGRESS"}
    resp_status = await client.patch(f"/api/v1/communication/requests/{request_id}/status", json=status_payload, headers=headers_teacher)
    assert resp_status.status_code == 200
    assert resp_status.json()["data"]["status"] == "IN_PROGRESS"

    # 9. Teacher escalates
    resp_esc = await client.post(f"/api/v1/communication/requests/{request_id}/escalate", headers=headers_teacher)
    assert resp_esc.status_code == 200
    assert resp_esc.json()["data"]["status"] == "ESCALATED"

    # 10. Principal receives escalation
    resp_pr_list = await client.get("/api/v1/communication/requests?status=ESCALATED", headers=headers_principal)
    assert resp_pr_list.status_code == 200
    assert len(resp_pr_list.json()["data"]) >= 1

    # 11. Principal replies
    resp_pr_reply = await client.post(f"/api/v1/communication/requests/{request_id}/messages", json={"message": "I will review this as Principal."}, headers=headers_principal)
    assert resp_pr_reply.status_code == 201

    # 12. Principal assigns teacher
    assignee_id = str(setup_communication_test_data["user_teacher"].id)
    resp_assign = await client.post(f"/api/v1/communication/requests/{request_id}/assign", json={"assignee_id": assignee_id}, headers=headers_principal)
    assert resp_assign.status_code == 200
    assert resp_assign.json()["data"]["assigned_to_id"] == assignee_id

    # Try assigning teacher from another school/tenant (should fail validation)
    user_p_b_id = str(setup_communication_test_data["user_parent_b"].id)
    resp_assign_invalid = await client.post(f"/api/v1/communication/requests/{request_id}/assign", json={"assignee_id": user_p_b_id}, headers=headers_principal)
    assert resp_assign_invalid.status_code == 400

    # 13. Resolve
    resp_resolve = await client.post(f"/api/v1/communication/requests/{request_id}/resolve", headers=headers_principal)
    assert resp_resolve.status_code == 200
    assert resp_resolve.json()["data"]["status"] == "RESOLVED"

    # 14. Reopen
    resp_reopen = await client.post(f"/api/v1/communication/requests/{request_id}/reopen", headers=headers_principal)
    assert resp_reopen.status_code == 200
    assert resp_reopen.json()["data"]["status"] == "REOPENED"

    # 15. Invalid state transitions (reopened cannot transition directly to ACKNOWLEDGED, must go to IN_PROGRESS or RESOLVED)
    resp_invalid_trans = await client.patch(f"/api/v1/communication/requests/{request_id}/status", json={"status": "ACKNOWLEDGED"}, headers=headers_teacher)
    assert resp_invalid_trans.status_code == 400

    # 16. Attachment validation (upload valid text file)
    # Get last message id
    stmt_msg = select(CommunicationMessage).where(CommunicationMessage.request_id == uuid.UUID(request_id)).order_by(CommunicationMessage.created_at.desc())
    msg_res = await db_session.execute(stmt_msg)
    latest_msg = msg_res.scalars().first()
    
    files = {"file": ("test.txt", b"Attachment content here", "text/plain")}
    data = {"message_id": str(latest_msg.id)}
    
    resp_attach = await client.post("/api/v1/communication/attachments", data=data, files=files, headers=headers_principal)
    assert resp_attach.status_code == 201
    attachment_id = resp_attach.json()["data"]["id"]

    # Try uploading invalid extension/mime
    files_invalid = {"file": ("test.exe", b"executable payload", "application/x-msdownload")}
    resp_attach_invalid = await client.post("/api/v1/communication/attachments", data=data, files=files_invalid, headers=headers_principal)
    assert resp_attach_invalid.status_code == 400

    # 17. Unauthorized attachment download (cross-tenant user gets 404 due to isolation)
    resp_dl_invalid = await client.get(f"/api/v1/communication/attachments/{attachment_id}", headers=headers_parent_b)
    assert resp_dl_invalid.status_code == 404

    # Authorized attachment download
    resp_dl_valid = await client.get(f"/api/v1/communication/attachments/{attachment_id}", headers=headers_parent)
    assert resp_dl_valid.status_code == 200
    assert resp_dl_valid.content == b"Attachment content here"

    # 18. Unread counts
    resp_unread = await client.get("/api/v1/communication/unread-count", headers=headers_parent)
    assert resp_unread.status_code == 200
    assert "unread_count" in resp_unread.json()["data"]

    # 19. Audit logs (check if audit log table has CREATE, REPLY, STATUS_CHANGE/UPDATED, ESCALATE, ASSIGN, ATTACHMENT_UPLOAD, REOPEN, RESOLVE)
    stmt_audit = select(CommunicationAuditLog).where(CommunicationAuditLog.request_id == uuid.UUID(request_id))
    audit_res = await db_session.execute(stmt_audit)
    audit_logs = audit_res.scalars().all()
    actions = {al.action for al in audit_logs}
    assert "REQUEST_CREATED" in actions or "CREATE" in actions
    assert "REPLY_ADDED" in actions or "REPLY" in actions
    assert "ESCALATE" in actions
    assert "REQUEST_ASSIGNED" in actions or "ASSIGN" in actions
    assert "ATTACHMENT_UPLOAD" in actions or "ATTACHMENT_UPLOADED" in actions
    assert "STATUS_UPDATED" in actions


@pytest.mark.anyio
async def test_communication_analytics_rbac(client: AsyncClient, setup_communication_test_data) -> None:
    headers_parent = setup_communication_test_data["headers_parent"]
    headers_principal = setup_communication_test_data["headers_principal"]

    # 1. Parent tries to get analytics (should be forbidden)
    resp_parent = await client.get("/api/v1/communication/analytics", headers=headers_parent)
    assert resp_parent.status_code == 403

    # 2. Principal gets analytics (should succeed)
    resp_principal = await client.get("/api/v1/communication/analytics", headers=headers_principal)
    assert resp_principal.status_code == 200
    data = resp_principal.json()["data"]
    assert "total_requests" in data
    assert "open_count" in data


@pytest.mark.anyio
async def test_communication_ai_insights(client: AsyncClient, setup_communication_test_data) -> None:
    headers_parent = setup_communication_test_data["headers_parent"]
    headers_teacher = setup_communication_test_data["headers_teacher"]
    student_a_id = str(setup_communication_test_data["student_a"].id)

    # 1. Create a communication request
    payload = {
        "student_id": student_a_id,
        "recipient_type": "TEACHER",
        "category": "ACADEMIC",
        "subject": "Regarding Math homework delay",
        "priority": "NORMAL",
        "message": "Dear teacher, Rahul needs an extra day for the assignment due to fever."
    }
    resp = await client.post("/api/v1/communication/requests", json=payload, headers=headers_parent)
    assert resp.status_code == 201
    request_id = resp.json()["data"]["id"]

    # Mock the LLM service generate_json method
    mock_ai_json = {
        "sentiment": "Neutral/Polite",
        "escalation_risk": "Low",
        "reply_suggestions": [
            "Thank you for informing. Wish Rahul a speedy recovery! I've extended the deadline.",
            "Sure, please submit it once he is feeling better."
        ]
    }

    # Patch the generate_json method in AIService to return the mock payload
    with patch("app.services.ai.service.AIService.generate_json", new_callable=AsyncMock) as mock_generate_json:
        mock_generate_json.return_value = mock_ai_json

        # Get AI insights as teacher
        resp_insights = await client.get(f"/api/v1/communication/requests/{request_id}/ai-insights", headers=headers_teacher)
        assert resp_insights.status_code == 200
        insights_data = resp_insights.json()["data"]
        assert insights_data["sentiment"] == "Neutral/Polite"
        assert insights_data["escalation_risk"] == "Low"
        assert len(insights_data["reply_suggestions"]) == 2
        mock_generate_json.assert_called_once()


@pytest.mark.anyio
async def test_communication_negative_relationships(client: AsyncClient, setup_communication_test_data, db_session: AsyncSession) -> None:
    headers_parent = setup_communication_test_data["headers_parent"]
    headers_teacher = setup_communication_test_data["headers_teacher"]
    headers_parent_b = setup_communication_test_data["headers_parent_b"]
    tenant_a = setup_communication_test_data["tenant_a"]
    school_a = setup_communication_test_data["school_a"]
    ay_a = setup_communication_test_data["ay_a"]
    
    from app.repositories.class_entity import ClassRepository
    from app.repositories.section import SectionRepository
    from app.repositories.student import StudentRepository
    from app.schemas.class_entity import ClassCreate
    from app.schemas.section import SectionCreate
    from app.schemas.student import StudentCreate
    
    repo_c = ClassRepository(db_session)
    repo_sec = SectionRepository(db_session)
    repo_std = StudentRepository(db_session)
    
    class_other = await repo_c.create(tenant_a.id, ClassCreate(school_id=school_a.id, academic_year_id=ay_a.id, name="Class 9", code="C9", level=9, category=ClassCategory.PRIMARY, capacity=30))
    await db_session.flush()
    sec_other = await repo_sec.create(tenant_a.id, SectionCreate(school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_other.id, name="Sec C", code="SC", capacity=30))
    await db_session.commit()
    
    student_other = await repo_std.create(tenant_a.id, StudentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_other.id, section_id=sec_other.id,
        admission_number="ADM-999", roll_number="R-99", first_name="Unauthorized", last_name="Student",
        gender=StudentGender.MALE, date_of_birth=date(2012, 5, 10), admission_date=date(2026, 6, 1)
    ))
    await db_session.commit()
    
    # A. Teacher tries to create a thread for student_other (should fail with 403)
    payload_teach = {
        "student_id": str(student_other.id),
        "recipient_type": "PARENT",
        "category": "GENERAL",
        "subject": "Unauthorized access test",
        "priority": "NORMAL",
        "message": "Teacher trying to message parent of student they do not teach."
    }
    resp_teach = await client.post("/api/v1/communication/requests", json=payload_teach, headers=headers_teacher)
    assert resp_teach.status_code == 403
    
    # B. Parent tries to create a thread for student_other (should fail with 403 as they are not the guardian of student_other)
    payload_parent = {
        "student_id": str(student_other.id),
        "recipient_type": "TEACHER",
        "category": "GENERAL",
        "subject": "Unauthorized parent message",
        "priority": "NORMAL",
        "message": "Parent trying to message about another child."
    }
    resp_parent = await client.post("/api/v1/communication/requests", json=payload_parent, headers=headers_parent)
    assert resp_parent.status_code == 403

    # C. Create a valid request for student_a by parent_a
    student_a_id = str(setup_communication_test_data["student_a"].id)
    payload_valid = {
        "student_id": student_a_id,
        "recipient_type": "TEACHER",
        "category": "GENERAL",
        "subject": "Valid request",
        "priority": "NORMAL",
        "message": "Hello class teacher."
    }
    resp_valid = await client.post("/api/v1/communication/requests", json=payload_valid, headers=headers_parent)
    assert resp_valid.status_code == 201
    request_id = resp_valid.json()["data"]["id"]

    # D. Cross-tenant access check: Parent B from Tenant B tries to get details of Parent A's request
    resp_cross_tenant = await client.get(f"/api/v1/communication/requests/{request_id}", headers=headers_parent_b)
    assert resp_cross_tenant.status_code == 404

    # E. Create another teacher who does NOT teach student_a
    from app.schemas.auth import UserCreate
    role_teacher_stmt = select(Role).where(Role.tenant_id == tenant_a.id, Role.code == "TEACHER")
    role_teacher = (await db_session.execute(role_teacher_stmt)).scalar_one()
    
    user_repo = UserRepository(db_session)
    role_repo = RoleRepository(db_session)
    perm_repo = PermissionRepository(db_session)
    refresh_repo = RefreshTokenRepository(db_session)
    auth_service = AuthService(user_repo, role_repo, perm_repo, refresh_repo, SchoolRepository(db_session))
    
    user_t2 = await auth_service.create_user(
        tenant_a.id,
        UserCreate(
            email="teacher2@school.edu",
            password="Password123!",
            first_name="T",
            last_name="Two",
            role_ids=[role_teacher.id],
            school_ids=[school_a.id]
        )
    )
    from app.models.teacher import Teacher, EmploymentType
    teacher_model2 = Teacher(
        tenant_id=tenant_a.id,
        school_id=school_a.id,
        user_id=user_t2.id,
        employee_code="EMP_T2",
        staff_code="STF_T2",
        first_name="T",
        last_name="Two",
        gender=StudentGender.FEMALE,
        date_of_birth=date(1985, 1, 1),
        mobile="9876543222",
        official_email="teacher2@school.edu",
        joining_date=date(2021, 1, 1),
        employment_type=EmploymentType.FULL_TIME,
        status="ACTIVE",
        is_active=True
    )
    db_session.add(teacher_model2)
    await db_session.commit()
    
    tokens_t2 = await auth_service.create_tokens(user_t2)
    headers_t2 = {"Authorization": f"Bearer {tokens_t2.access_token}", "X-Tenant-ID": str(tenant_a.id)}
    
    # F. Teacher 2 (who does not teach student_a) tries to view the request_id (should return 403)
    resp_t2_view = await client.get(f"/api/v1/communication/requests/{request_id}", headers=headers_t2)
    assert resp_t2_view.status_code == 403
    
    # G. Teacher 2 tries to reply to the request_id (should return 403)
    resp_t2_reply = await client.post(f"/api/v1/communication/requests/{request_id}/messages", json={"message": "Unauthorized reply"}, headers=headers_t2)
    assert resp_t2_reply.status_code == 403
