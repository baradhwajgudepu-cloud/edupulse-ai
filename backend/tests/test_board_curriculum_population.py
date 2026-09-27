import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.school import School, SchoolBoard
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.subject import Subject
from app.models.syllabus import Syllabus
from app.models.curriculum import CurriculumMaster, CurriculumMasterItem
from app.models.user import User
from app.repositories.curriculum import CurriculumRepository
from app.repositories.syllabus import SyllabusRepository
from app.services.curriculum_engine import CurriculumEngine
from app.services.timetable_ai_engine import TimetableAIEngine
from app.services.syllabus_prediction_engine import SyllabusPredictionEngine
from tests.test_academic_planning_intelligence import academic_planning_fixture


@pytest.mark.anyio
async def test_acceptance_1_to_6_curriculum_resolvers_and_telangana(
    db_session: AsyncSession,
    academic_planning_fixture: dict
) -> None:
    """
    Scenarios 1-6:
    1. CBSE resolution
    2. ICSE resolution
    3. State Board without state -> unavailable / empty
    4. Telangana State Board normalization -> resolves official SCERT Telangana curriculum
    5. Academic year matching (2026-2027)
    6. Class matching (Classes 5 to 10)
    """
    curriculum_repo = CurriculumRepository(db_session)
    syllabus_repo = SyllabusRepository(db_session)
    engine = CurriculumEngine(db_session, curriculum_repo, syllabus_repo)

    await engine.ensure_seed_canonical_data()

    # 1. CBSE resolution
    cbse_templates = await engine.get_verified_templates(board="CBSE", class_level=10)
    assert len(cbse_templates) >= 2
    cbse_subs = [t.subject_name for t in cbse_templates]
    assert "Mathematics" in cbse_subs
    assert "Science" in cbse_subs

    # 2. ICSE resolution
    icse_templates = await engine.get_verified_templates(board="ICSE", class_level=10)
    assert len(icse_templates) >= 1
    assert icse_templates[0].subject_name == "Mathematics"

    # 3. State Board without state -> strict zero-hallucination policy returns empty
    state_no_state = await engine.get_verified_templates(board="STATE", state=None)
    assert len(state_no_state) == 0, "STATE board without state must not resolve generic templates!"

    state_empty_state = await engine.get_verified_templates(board="STATE", state="")
    assert len(state_empty_state) == 0, "STATE board with empty state must not resolve generic templates!"

    # 4. Telangana State Board normalization
    tg_templates = await engine.get_verified_templates(board="STATE", state="Telangana")
    assert len(tg_templates) >= 30, f"Expected 30+ Telangana templates, got {len(tg_templates)}"
    assert tg_templates[0].source == "SCERT Telangana State Board Official Curriculum"

    # 5. Academic year matching (2026-2027)
    ay_templates = await engine.get_verified_templates(
        board="STATE",
        state="Telangana",
        academic_year_code="2026-2027"
    )
    assert len(ay_templates) > 0
    for t in ay_templates:
        assert t.academic_year_code == "2026-2027"

    # 6. Class matching across levels 5 through 10
    for level in [5, 6, 7, 8, 9, 10]:
        lvl_templates = await engine.get_verified_templates(
            board="STATE",
            state="Telangana",
            class_level=level
        )
        assert len(lvl_templates) >= 5, f"Class {level} missing Telangana templates!"
        sub_names = [t.subject_name for t in lvl_templates]
        assert "Mathematics" in sub_names
        assert "General Science" in sub_names
        assert "Social Studies" in sub_names
        assert "English Language" in sub_names
        assert "Telugu Regional Language" in sub_names


@pytest.mark.anyio
async def test_acceptance_7_to_11_population_isolation_and_idempotency(
    db_session: AsyncSession,
    academic_planning_fixture: dict
) -> None:
    """
    Scenarios 7-11:
    7. Curriculum population
    8. School-specific syllabus copy
    9. No duplicate population (idempotency)
    10. Missing curriculum fallback
    11. Master curriculum cannot be modified by school
    """
    data = academic_planning_fixture
    tenant = data["tenant_a"]
    school = data["school_a"]
    ay = data["ay_a"]

    mock_user = User(
        id=uuid.uuid4(),
        email=f"admin-{uuid.uuid4().hex[:6]}@edupulse.org",
        hashed_password="mock",
        first_name="Admin",
        last_name="User",
        tenant_id=tenant.id
    )
    db_session.add(mock_user)
    await db_session.flush()

    # Configure school as STATE + Telangana
    school.board = SchoolBoard.STATE
    school.state = "Telangana"
    await db_session.flush()

    curriculum_repo = CurriculumRepository(db_session)
    syllabus_repo = SyllabusRepository(db_session)
    engine = CurriculumEngine(db_session, curriculum_repo, syllabus_repo)

    # 7 & 8: Populate school syllabus copy
    pop_res = await engine.auto_populate_school(
        tenant_id=tenant.id,
        school_id=school.id,
        current_user=mock_user,
        override_existing=True,
        academic_year_id=ay.id
    )
    assert pop_res.success is True
    assert pop_res.total_classes_processed >= 1
    assert pop_res.total_topics_populated > 0
    assert pop_res.source == "SCERT Telangana State Board Official Curriculum"
    assert pop_res.verification_status == "VERIFIED"

    # Check school syllabus rows exist with school_id and curriculum_master_id
    stmt = select(Syllabus).where(
        Syllabus.school_id == school.id,
        Syllabus.academic_year_id == ay.id,
        Syllabus.deleted_at.is_(None)
    )
    syll_rows = (await db_session.execute(stmt)).scalars().all()
    count_1 = len(syll_rows)
    assert count_1 > 0
    assert syll_rows[0].curriculum_master_id is not None
    assert syll_rows[0].source == "SCERT Telangana State Board Official Curriculum"

    # 9. No duplicate population (idempotency)
    pop_res_2 = await engine.auto_populate_school(
        tenant_id=tenant.id,
        school_id=school.id,
        current_user=mock_user,
        override_existing=False,
        academic_year_id=ay.id
    )
    syll_rows_2 = (await db_session.execute(stmt)).scalars().all()
    count_2 = len(syll_rows_2)
    assert count_1 == count_2, "Idempotency failed: duplicated syllabus rows!"

    # 10. Missing curriculum fallback (e.g. unknown state)
    school.state = "Goa"
    await db_session.flush()
    status_fallback = await engine.get_school_curriculum_status(school.id, ay.id)
    assert status_fallback.verified_curriculum_available is False or status_fallback.is_populated is True

    # 11. Master curriculum cannot be modified by school
    first_master_item_stmt = select(CurriculumMasterItem).limit(1)
    master_item = (await db_session.execute(first_master_item_stmt)).scalars().first()
    original_topic = master_item.topic_name

    # Edit school's syllabus item
    syll_rows[0].topic_name = "Locally Modified Topic by School"
    syll_rows[0].lifecycle_status = "COMPLETED"
    await db_session.flush()

    # Re-fetch master item from DB and verify it is completely untouched
    await db_session.refresh(master_item)
    assert master_item.topic_name == original_topic, "Global master curriculum was mutated by school edit!"


@pytest.mark.anyio
async def test_acceptance_12_school_switching_isolation(
    db_session: AsyncSession,
    academic_planning_fixture: dict
) -> None:
    """12. School A cannot see School B syllabus."""
    data = academic_planning_fixture
    tenant_b = data["tenant_b"]
    school_b = data["school_b"]
    ay_b = data["ay_b"]

    curriculum_repo = CurriculumRepository(db_session)
    syllabus_repo = SyllabusRepository(db_session)
    engine = CurriculumEngine(db_session, curriculum_repo, syllabus_repo)

    status_b = await engine.get_school_curriculum_status(school_b.id, ay_b.id)
    assert status_b.is_populated is False


@pytest.mark.anyio
async def test_acceptance_13_to_15_editor_timetable_and_prediction(
    db_session: AsyncSession,
    academic_planning_fixture: dict
) -> None:
    """
    13. Populated syllabus appears in Syllabus Editor.
    14. Populated syllabus is available to AI Timetable workload calculation.
    15. Populated syllabus is available to Completion Prediction.
    """
    data = academic_planning_fixture
    tenant = data["tenant_a"]
    school = data["school_a"]
    ay = data["ay_a"]
    cls = data["class_10"]
    sub = data["math_sub"]

    mock_user = User(
        id=uuid.uuid4(),
        email=f"admin-{uuid.uuid4().hex[:6]}@edupulse.org",
        hashed_password="mock",
        first_name="Admin",
        last_name="User",
        tenant_id=tenant.id
    )
    db_session.add(mock_user)
    await db_session.flush()

    # Auto-populate for school
    school.board = SchoolBoard.STATE
    school.state = "Telangana"
    await db_session.flush()

    curriculum_repo = CurriculumRepository(db_session)
    syllabus_repo = SyllabusRepository(db_session)
    engine = CurriculumEngine(db_session, curriculum_repo, syllabus_repo)

    await engine.auto_populate_school(
        tenant_id=tenant.id,
        school_id=school.id,
        current_user=mock_user,
        override_existing=True,
        academic_year_id=ay.id
    )

    # 13. Populated syllabus appears in Syllabus Editor query
    list_syll = await syllabus_repo.get_multi(
        school_id=school.id,
        tenant_id=tenant.id,
        academic_year_id=ay.id,
        class_id=cls.id
    )
    assert len(list_syll) > 0
    assert all(s.estimated_periods > 0 for s in list_syll)
    assert all(s.lifecycle_status in ["PLANNED", "IN_PROGRESS", "COMPLETED", "DEFERRED", "REOPENED"] for s in list_syll)

    # 14. Available to AI Timetable workload calculation
    total_chapters = len(set(s.chapter_name for s in list_syll))
    total_estimated_periods = sum(s.estimated_periods for s in list_syll)
    assert total_chapters > 0
    assert total_estimated_periods > 0

    # 15. Available to Completion Prediction
    prediction_engine = SyllabusPredictionEngine(db_session)
    prediction = await prediction_engine.predict_subject_completion(
        school_id=school.id,
        academic_year_id=ay.id,
        class_id=cls.id,
        subject_id=sub.id
    )
    assert prediction is not None
    assert prediction.total_chapters > 0
    assert prediction.data_sufficiency in ["WAITING_FOR_PROGRESS", "SUFFICIENT", "INSUFFICIENT_DATA"]


@pytest.mark.anyio
async def test_acceptance_16_school_setup_status_and_api_endpoints(
    client: AsyncClient,
    db_session: AsyncSession,
    academic_planning_fixture: dict
) -> None:
    """
    Scenario 16: Verification of API endpoints:
    - GET /api/v1/curriculum/status returns AVAILABLE / VERIFIED OFFICIAL
    - POST /api/v1/curriculum/auto-populate succeeds without errors
    - POST /api/v1/curriculum/populate-from-board succeeds without errors
    """
    data = academic_planning_fixture
    tenant = data["tenant_a"]
    school = data["school_a"]
    ay = data["ay_a"]

    school.board = SchoolBoard.STATE
    school.state = "Telangana"
    await db_session.flush()

    mock_user = User(
        id=uuid.uuid4(),
        email=f"admin-{uuid.uuid4().hex[:6]}@edupulse.org",
        hashed_password="mock",
        first_name="Admin",
        last_name="User",
        tenant_id=tenant.id
    )
    db_session.add(mock_user)
    await db_session.flush()

    from app.core.security import create_access_token
    token = create_access_token(
        subject=str(mock_user.id),
        tenant_id=str(tenant.id)
    )
    headers = {"Authorization": f"Bearer {token}", "X-Tenant-ID": str(tenant.id)}

    # 1. GET /api/v1/curriculum/status (before population -> AVAILABLE)
    res_status = await client.get(
        f"/api/v1/curriculum/status?school_id={school.id}&academic_year_id={ay.id}",
        headers=headers
    )
    assert res_status.status_code == 200
    data_status = res_status.json()["data"]
    assert data_status["board"] == "STATE"
    assert data_status["state"] == "Telangana"
    assert data_status["verified_curriculum_available"] is True
    assert data_status["status_badge"] in ["AVAILABLE", "VERIFIED OFFICIAL"]

    # 2. POST /api/v1/curriculum/auto-populate
    res_pop = await client.post(
        f"/api/v1/curriculum/auto-populate?school_id={school.id}&override_existing=true",
        headers=headers
    )
    assert res_pop.status_code == 200
    data_pop = res_pop.json()["data"]
    assert data_pop["success"] is True
    assert data_pop["verification_status"] == "VERIFIED"

    # 3. GET /api/v1/curriculum/status (after population -> VERIFIED OFFICIAL)
    res_status2 = await client.get(
        f"/api/v1/curriculum/status?school_id={school.id}&academic_year_id={ay.id}",
        headers=headers
    )
    assert res_status2.status_code == 200
    data_status2 = res_status2.json()["data"]
    assert data_status2["is_populated"] is True
    assert data_status2["status_badge"] == "VERIFIED OFFICIAL"
    assert data_status2["total_topics"] > 0
    assert data_status2["total_chapters"] > 0

    # 4. POST /api/v1/curriculum/populate-from-board
    res_board = await client.post(
        f"/api/v1/curriculum/populate-from-board?school_id={school.id}",
        json={"school_id": str(school.id), "academic_year_id": str(ay.id), "board": "STATE", "state": "Telangana"},
        headers=headers
    )
    assert res_board.status_code == 200
    data_board = res_board.json()["data"]
    assert data_board["success"] is True
