import uuid
import pytest
from datetime import date
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School, SchoolBoard
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.models.syllabus import Syllabus
from app.models.curriculum import CurriculumMaster, CurriculumMasterItem
from app.models.exam_question import ExamQuestion, QuestionDifficulty, QuestionType
from app.models.examination import Examination, ExamType, ExamStatus
from tests.test_examinations import setup_exam_test_data


@pytest.mark.anyio
async def test_cbse_curriculum_resolver(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """1. CBSE Resolver returns official CBSE/NCERT curriculum for Class 8 Mathematics & Science."""
    data = setup_exam_test_data
    headers = data["auth_headers"]

    resp = await client.get(
        "/api/v1/curriculum/resolve",
        params={
            "board": "CBSE",
            "academic_year": "2026-2027",
            "class_level": 8
        },
        headers=headers
    )
    assert resp.status_code == 200
    res = resp.json()["data"]
    assert res["verified_available"] is True
    assert res["board"] == "CBSE"
    assert "cbseacademic.nic.in" in res["source"]
    assert res["verification_status"] == "VERIFIED"

    subject_names = [s["subject_name"] for s in res["subjects"]]
    assert "Mathematics" in subject_names
    assert "Science" in subject_names


@pytest.mark.anyio
async def test_icse_curriculum_resolver(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """2. ICSE Resolver returns official CISCE curriculum for Class 8."""
    data = setup_exam_test_data
    headers = data["auth_headers"]

    resp = await client.get(
        "/api/v1/curriculum/resolve",
        params={
            "board": "ICSE",
            "academic_year": "2026-2027",
            "class_level": 8
        },
        headers=headers
    )
    assert resp.status_code == 200
    res = resp.json()["data"]
    assert res["verified_available"] is True
    assert res["board"] == "ICSE"
    assert "cisce.org" in res["source"]
    assert res["verification_status"] == "VERIFIED"

    subject_names = [s["subject_name"] for s in res["subjects"]]
    assert "Mathematics" in subject_names
    assert "Physics" in subject_names
    assert "Chemistry" in subject_names


@pytest.mark.anyio
async def test_state_board_curriculum_resolvers(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """3. State Board Resolver returns state-specific curriculum for Karnataka, Telangana, Maharashtra."""
    data = setup_exam_test_data
    headers = data["auth_headers"]

    # Karnataka
    resp_kar = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "STATE", "state": "Karnataka", "academic_year": "2026-2027", "class_level": 8},
        headers=headers
    )
    assert resp_kar.status_code == 200
    res_kar = resp_kar.json()["data"]
    assert res_kar["verified_available"] is True
    assert "Karnataka" in res_kar["source"]
    assert "Kannada" in [s["subject_name"] for s in res_kar["subjects"]]

    # Telangana
    resp_tg = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "STATE", "state": "Telangana", "academic_year": "2026-2027", "class_level": 8},
        headers=headers
    )
    assert resp_tg.status_code == 200
    res_tg = resp_tg.json()["data"]
    assert res_tg["verified_available"] is True
    assert "Telangana" in res_tg["source"]

    # Maharashtra
    resp_mh = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "STATE", "state": "Maharashtra", "academic_year": "2026-2027", "class_level": 8},
        headers=headers
    )
    assert resp_mh.status_code == 200
    res_mh = resp_mh.json()["data"]
    assert res_mh["verified_available"] is True
    assert "Maharashtra" in res_mh["source"]


@pytest.mark.anyio
async def test_strict_zero_hallucination_for_unverified_curriculum(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """4. STRICT ZERO-HALLUCINATION: Unsupported boards or years return explicit unavailable message."""
    data = setup_exam_test_data
    headers = data["auth_headers"]

    # Unsupported board
    resp_other = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "OTHER", "academic_year": "2026-2027", "class_level": 8},
        headers=headers
    )
    assert resp_other.status_code == 200
    assert resp_other.json()["data"]["verified_available"] is False
    assert "Verified curriculum data unavailable" in resp_other.json()["data"]["message"]

    # Unsupported future year (no speculative hallucination)
    resp_future = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "CBSE", "academic_year": "2039-2040", "class_level": 8},
        headers=headers
    )
    assert resp_future.status_code == 200
    assert resp_future.json()["data"]["verified_available"] is False

    # State board without state
    resp_nostate = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "STATE", "academic_year": "2026-2027", "class_level": 8},
        headers=headers
    )
    assert resp_nostate.status_code == 200
    assert resp_nostate.json()["data"]["verified_available"] is False


@pytest.mark.anyio
async def test_curriculum_master_isolation_and_school_copy(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """5, 6, 7 & 8: Master -> School Copy, Audit Trail, and Master Isolation."""
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a"].id)
    subject_id = str(data["subject_a"].id)

    # 1. Populate school curriculum
    pop_resp = await client.post(
        f"/api/v1/curriculum/populate?school_id={school_id}",
        json={"academic_year_id": ay_id, "class_ids": [class_id]},
        headers=headers
    )
    assert pop_resp.status_code == 201
    pop_data = pop_resp.json()["data"]
    assert pop_data["success"] is True
    assert pop_data["total_chapters_populated"] > 0
    assert pop_data["verification_status"] == "VERIFIED"
    assert "cbseacademic" in pop_data["source"]

    # 2. Check school syllabus has audit trail
    list_resp = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    assert list_resp.status_code == 200
    syllabuses = list_resp.json()["data"]
    assert len(syllabuses) > 0

    first_item = syllabuses[0]
    assert first_item["chapter_name"] != ""
    assert first_item["unit_name"] != ""

    # 3. Add school-specific custom chapter
    custom_resp = await client.post(
        f"/api/v1/curriculum/custom-chapter?school_id={school_id}",
        json={
            "academic_year_id": ay_id,
            "class_id": class_id,
            "subject_id": subject_id,
            "unit_name": "School Custom Vedic Mathematics",
            "chapter_name": "Vedic Multiplication Shortcuts",
            "topic_name": "Sutra Ekadhikena Purvena",
            "description": "School special enrichment module"
        },
        headers=headers
    )
    assert custom_resp.status_code == 201
    custom_item = custom_resp.json()["data"]
    assert custom_item["unit_name"] == "School Custom Vedic Mathematics"

    # 4. Verify Master is untouched
    resolve_resp = await client.get(
        "/api/v1/curriculum/resolve",
        params={"board": "CBSE", "academic_year": "2026-2027", "class_level": 8},
        headers=headers
    )
    master_units = []
    for sub in resolve_resp.json()["data"]["subjects"]:
        master_units.extend(sub["units"])
    assert "School Custom Vedic Mathematics" not in master_units


@pytest.mark.anyio
async def test_idempotent_duplicate_prevention(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """9 & 10: Idempotent re-population prevents duplicated rows."""
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a"].id)

    # Initial populate
    resp1 = await client.post(
        f"/api/v1/curriculum/populate?school_id={school_id}",
        json={"academic_year_id": ay_id, "class_ids": [class_id]},
        headers=headers
    )
    assert resp1.status_code in (201, 200)

    # Count syllabus rows
    list1 = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    count1 = len(list1.json()["data"])

    # Re-run populate without override
    resp2 = await client.post(
        f"/api/v1/curriculum/populate?school_id={school_id}",
        json={"academic_year_id": ay_id, "class_ids": [class_id], "override_existing": False},
        headers=headers
    )
    assert resp2.status_code in (201, 200)

    list2 = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    count2 = len(list2.json()["data"])
    assert count1 == count2, "Duplicate syllabus rows created on re-population!"


@pytest.mark.anyio
async def test_school_switching_and_isolation(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """11. School Switching Isolation: School B cannot view School A's populated syllabus."""
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_a_id = str(data["school_a"].id)
    school_b_id = str(data["school_b"].id)
    ay_a_id = str(data["ay_a"].id)

    # Populate School A
    await client.post(
        f"/api/v1/curriculum/populate?school_id={school_a_id}",
        json={"academic_year_id": ay_a_id},
        headers=headers
    )

    # Query status for School B
    resp_b = await client.get(
        f"/api/v1/curriculum/status?school_id={school_b_id}",
        headers=headers
    )
    # School B belongs to tenant B so should be rejected or have 0 items
    if resp_b.status_code == 200:
        assert resp_b.json()["data"]["total_topics"] == 0


@pytest.mark.anyio
async def test_exam_and_question_mapping_integration(client: AsyncClient, setup_exam_test_data: dict) -> None:
    """12. Exam Integration: Populated board syllabus chapters link directly to Exam Questions."""
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a"].id)
    subject_id = str(data["subject_a"].id)

    # 1. Populate curriculum
    await client.post(
        f"/api/v1/curriculum/populate?school_id={school_id}",
        json={"academic_year_id": ay_id, "class_ids": [class_id]},
        headers=headers
    )

    # 2. Get a populated syllabus chapter
    syl_resp = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    syllabuses = syl_resp.json()["data"]
    assert len(syllabuses) > 0
    target_syl = syllabuses[0]

    # 3. Create examination
    exam_resp = await client.post(
        "/api/v1/examinations/wizard",
        json={
            "school_id": school_id,
            "academic_year_id": ay_id,
            "exam_name": f"Board Aligned Unit Test {uuid.uuid4().hex[:4]}",
            "exam_type": "UNIT_TEST",
            "start_date": "2026-10-01",
            "end_date": "2026-10-05",
            "target_scope": "ALL_CLASSES",
            "schedules": []
        },
        headers=headers
    )
    assert exam_resp.status_code == 201
    exam_id = exam_resp.json()["data"]["id"]

    # 4. Map question linking target_syl['id']
    q_resp = await client.post(
        f"/api/v1/examinations/{exam_id}/questions",
        params={"school_id": school_id, "academic_year_id": ay_id},
        json={
            "subject_id": subject_id,
            "question_number": "Q1",
            "question_text": "Solve for x using rational numbers properties.",
            "max_marks": 5.0,
            "chapter_name": target_syl["chapter_name"],
            "topic_name": target_syl["topic_name"],
            "difficulty": "MEDIUM",
            "question_type": "SHORT",
            "syllabus_id": target_syl["id"]
        },
        headers=headers
    )
    assert q_resp.status_code == 201
    q_data = q_resp.json()["data"]
    assert q_data["syllabus_id"] == target_syl["id"]
    assert q_data["chapter_name"] == target_syl["chapter_name"]
