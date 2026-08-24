import pytest
import uuid
from datetime import date, time
from httpx import AsyncClient
from app.models.school_event import SchoolEvent, EventAudience, EventStatus
from app.models.examination import Examination, ExamSchedule, ExamStatus, ExamType
from app.models.permission import Permission
from app.models.role import Role
from app.repositories.auth import UserRepository
from app.services.auth import AuthService
from app.main import app
from app.api.dependencies.auth import get_current_user
from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

# Import the fixture from test_examinations
from tests.test_examinations import setup_exam_test_data

@pytest.mark.anyio
async def test_calendar_feed_and_security(client: AsyncClient, setup_exam_test_data, db_session: AsyncSession) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    tenant_id = data["tenant_a"].id

    # 1. Ensure event.read permission exists
    stmt_perm = select(Permission).where(Permission.code == "event.read")
    res_perm = await db_session.execute(stmt_perm)
    event_read_perm = res_perm.scalar_one_or_none()
    if not event_read_perm:
        event_read_perm = Permission(
            id=uuid.uuid4(),
            name="Read Event",
            code="event.read",
            description="Allows viewing events"
        )
        db_session.add(event_read_perm)
        await db_session.commit()

    # Load mock admin's role and append permission
    stmt_role = select(Role).where(Role.code == "SUPER_ADMIN", Role.tenant_id == tenant_id).options(selectinload(Role.permissions))
    res_role = await db_session.execute(stmt_role)
    admin_role = res_role.scalar_one_or_none()
    if admin_role and event_read_perm not in admin_role.permissions:
        admin_role.permissions.append(event_read_perm)
        await db_session.commit()

    # Dependency override to use the seeded user from the database
    async def mock_admin():
        return data["user_admin"]

    app.dependency_overrides[get_current_user] = mock_admin

    try:
        # 2. Verify Empty Calendar
        resp_empty = await client.get(
            f"/api/v1/calendar/feed?school_id={school_id}&start_date=2026-08-01&end_date=2026-08-31",
            headers=headers
        )
        assert resp_empty.status_code == 200
        assert len(resp_empty.json()["data"]) == 0

        # 3. Seed a School Event and a Holiday
        event1 = SchoolEvent(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=data["ay_a"].id,
            event_name="UAT Science Fair",
            description="Fair event",
            event_date=date(2026, 8, 15),
            start_time=time(9, 0),
            end_time=time(12, 0),
            venue="Auditorium",
            target_audience=EventAudience.ALL,
            status=EventStatus.PUBLISHED,
            is_holiday=False
        )
        holiday = SchoolEvent(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=data["ay_a"].id,
            event_name="Independence Day",
            description="National holiday",
            event_date=date(2026, 8, 15),
            start_time=time(0, 0),
            end_time=time(23, 59),
            venue="Campus",
            target_audience=EventAudience.ALL,
            status=EventStatus.PUBLISHED,
            is_holiday=True
        )
        db_session.add(event1)
        db_session.add(holiday)
        await db_session.commit()

        # 4. Seed an Examination with Schedule
        exam = Examination(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=data["ay_a"].id,
            exam_name="Term 1 - Science",
            exam_type=ExamType.UNIT_TEST,
            start_date=date(2026, 8, 10),
            end_date=date(2026, 8, 20),
            status=ExamStatus.PUBLISHED
        )
        db_session.add(exam)
        await db_session.commit()

        sched = ExamSchedule(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=data["ay_a"].id,
            exam_id=exam.id,
            class_id=data["class_a"].id,
            section_id=data["sec_a1"].id,
            subject_id=data["subject_a"].id,
            teacher_subject_assignment_id=data["tsa_a"].id,
            exam_date=date(2026, 8, 12),
            start_time=time(9, 0),
            end_time=time(11, 0),
            max_marks=100,
            pass_marks=35,
            room_number="Room 101"
        )
        db_session.add(sched)
        await db_session.commit()

        # 5. Fetch consolidated mixed calendar feed
        resp_filled = await client.get(
            f"/api/v1/calendar/feed?school_id={school_id}&start_date=2026-08-01&end_date=2026-08-31",
            headers=headers
        )
        assert resp_filled.status_code == 200
        feed = resp_filled.json()["data"]
        assert len(feed) == 3

        # Sorted by date, then start_time
        assert feed[0]["type"] == "EXAMINATION"
        assert feed[0]["title"] == "Term 1 - Science: Mathematics"
        assert feed[1]["type"] == "HOLIDAY"
        assert feed[1]["title"] == "Independence Day"
        assert feed[2]["type"] == "EVENT"
        assert feed[2]["title"] == "UAT Science Fair"

        # 6. Security: Unauthorized school returns 403
        unauth_school_id = data["school_b"].id
        resp_unauth = await client.get(
            f"/api/v1/calendar/feed?school_id={unauth_school_id}&start_date=2026-08-01&end_date=2026-08-31",
            headers=headers
        )
        assert resp_unauth.status_code == 403

    finally:
        # Clear override
        if get_current_user in app.dependency_overrides:
            del app.dependency_overrides[get_current_user]

    # Clean up test events
    await db_session.execute(delete(SchoolEvent))
    await db_session.execute(delete(ExamSchedule))
    await db_session.execute(delete(Examination))
    await db_session.commit()
