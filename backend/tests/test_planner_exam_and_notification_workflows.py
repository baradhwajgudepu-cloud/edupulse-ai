import uuid
import pytest
from datetime import date, datetime, timedelta, timezone
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.role import Role
from app.models.user import User, UserStatus
from app.models.notification import NotificationTargetRole, NotificationType, NotificationPriority
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate


@pytest.mark.anyio
async def test_planner_exam_and_notification_workflows(client: AsyncClient, db_session: AsyncSession):
    # 1. Seed Tenant, School, and Active Academic Year
    suffix = uuid.uuid4().hex[:6]
    t_repo = TenantRepository(db_session)
    tenant = await t_repo.create(
        TenantCreate(
            name="Planner Test Tenant",
            code=f"plan-{suffix}",
            subdomain=f"plan-{suffix}",
            email=f"plan-{suffix}@edu.in"
        )
    )
    await db_session.commit()

    s_repo = SchoolRepository(db_session)
    school = await s_repo.create(
        tenant.id,
        SchoolCreate(
            name="Planner Model School",
            code=f"SCH_{suffix.upper()}",
            board="CBSE",
            email=f"school-{suffix}@edu.in",
            status=SchoolStatus.ACTIVE
        )
    )
    await db_session.commit()

    ay_repo = AcademicYearRepository(db_session)
    ay = await ay_repo.create(
        tenant_id=tenant.id,
        school_id=school.id,
        obj_in=AcademicYearCreate(
            name="2026-2027",
            code="AY2026",
            start_date=date(2026, 6, 1),
            end_date=date(2027, 4, 30),
            status=AcademicYearStatus.ACTIVE,
            is_current=True
        )
    )
    await db_session.commit()

    headers = {
        "X-Tenant-ID": str(tenant.id)
    }

    # ==========================================
    # 2. TEST: Notification Creation (No existing users in role)
    # ==========================================
    notif_payload = {
        "school_id": str(school.id),
        "title": "Annual Sports Day Notice",
        "message": "All parents and students are invited to the campus grounds.",
        "target_role": "PARENT",
        "priority": "NORMAL",
        "notification_type": "GENERAL"
    }

    res = await client.post("/api/v1/notifications", json=notif_payload, headers=headers)
    assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.text}"
    notif_data = res.json()["data"]
    assert notif_data["title"] == "Annual Sports Day Notice"
    assert notif_data["target_role"] == "PARENT"
    assert notif_data["published_at"] is not None
    notif_id_1 = notif_data["id"]

    # ==========================================
    # 3. TEST: Notification Scheduling & Immediate Publish
    # ==========================================
    future_time = (datetime.now(timezone.utc) + timedelta(days=5)).isoformat()
    scheduled_payload = {
        "school_id": str(school.id),
        "title": "Scheduled Campus Maintenance",
        "message": "Power outage scheduled for Saturday.",
        "target_role": "STAFF",
        "priority": "HIGH",
        "notification_type": "GENERAL",
        "scheduled_at": future_time
    }

    res_sched = await client.post("/api/v1/notifications", json=scheduled_payload, headers=headers)
    assert res_sched.status_code == 201, f"Expected 201, got {res_sched.status_code}: {res_sched.text}"
    sched_data = res_sched.json()["data"]
    assert sched_data["published_at"] is None
    notif_id_2 = sched_data["id"]

    # Publish the scheduled notification
    res_pub = await client.post(f"/api/v1/notifications/{notif_id_2}/publish?school_id={school.id}", headers=headers)
    assert res_pub.status_code == 200, f"Expected 200, got {res_pub.status_code}: {res_pub.text}"
    published_data = res_pub.json()["data"]
    assert published_data["published_at"] is not None

    # ==========================================
    # 4. TEST: Query School Notifications with school_id
    # ==========================================
    res_list = await client.get(f"/api/v1/notifications?school_id={school.id}", headers=headers)
    assert res_list.status_code == 200, f"Expected 200: {res_list.text}"
    items = res_list.json()["data"]
    item_ids = [item["id"] for item in items]
    assert notif_id_1 in item_ids
    assert notif_id_2 in item_ids

    # ==========================================
    # 5. TEST: Examination Wizard Creation (Academic Year Auto-Resolution)
    # ==========================================
    exam_payload = {
        "school_id": str(school.id),
        "exam_name": "Formative Cycle 1",
        "exam_type": "UNIT_TEST",
        "start_date": "2026-08-01",
        "end_date": "2026-08-10",
        "description": "Standard school planner unit test",
        "schedules": []
    }

    res_exam = await client.post("/api/v1/examinations/wizard", json=exam_payload, headers=headers)
    assert res_exam.status_code == 201, f"Expected 201, got {res_exam.status_code}: {res_exam.text}"
    exam_data = res_exam.json()["data"]
    assert exam_data["exam_name"] == "Formative Cycle 1"
    assert exam_data["exam_type"] == "UNIT_TEST"
    assert exam_data["status"] == "DRAFT"
    assert exam_data["academic_year_id"] == str(ay.id)
    exam_id = exam_data["id"]

    # ==========================================
    # 6. TEST: Publish Examination Schedule
    # ==========================================
    res_pub_exam = await client.post(f"/api/v1/examinations/{exam_id}/publish?school_id={school.id}", headers=headers)
    assert res_pub_exam.status_code == 200, f"Expected 200: {res_pub_exam.text}"
    pub_exam_data = res_pub_exam.json()["data"]
    assert pub_exam_data["status"] == "PUBLISHED"
