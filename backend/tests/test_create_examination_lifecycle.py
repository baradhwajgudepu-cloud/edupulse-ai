import uuid
import pytest
from datetime import date
from httpx import AsyncClient

from app.models.examination import ExamType
from tests.test_examinations import setup_exam_test_data  # re-use complete fixture


@pytest.mark.anyio
async def test_create_valid_examination_with_internal_assessment(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Quarterly Internal Assessment",
        "exam_type": "INTERNAL_ASSESSMENT",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }

    # 1. Create valid examination -> 201
    resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp.status_code == 201
    res = resp.json()["data"]

    # 2. Current school is correctly assigned
    assert res["school_id"] == str(school_id)

    # 3. Current academic year is correctly assigned
    assert res["academic_year_id"] == str(ay_id)

    # 4. Valid exam type is accepted and matches
    assert res["exam_type"] == "INTERNAL_ASSESSMENT"
    assert res["exam_name"] == "Quarterly Internal Assessment"
    assert res["status"] == "DRAFT"

    # Class scope is populated
    assert str(data["class_a"].id) in res["participating_class_ids"]


@pytest.mark.anyio
async def test_all_new_exam_types_accepted(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    # Test all newly added enum values
    new_types = ["WEEKLY_TEST", "FINAL", "PRACTICAL", "CUSTOM"]
    for idx, et in enumerate(new_types):
        payload = {
            "school_id": str(school_id),
            "academic_year_id": str(ay_id),
            "exam_name": f"Test Exam Cycle {et} {idx}",
            "exam_type": et,
            "start_date": "2026-09-15",
            "end_date": "2026-09-20",
            "target_scope": "ALL_CLASSES",
            "schedules": []
        }
        resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
        assert resp.status_code == 201, f"Failed for type {et}: {resp.text}"
        assert resp.json()["data"]["exam_type"] == et


@pytest.mark.anyio
async def test_invalid_exam_type_returns_4xx(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Invalid Type Exam",
        "exam_type": "NON_EXISTENT_TYPE",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "schedules": []
    }
    resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp.status_code in (400, 422)


@pytest.mark.anyio
async def test_start_date_after_end_date_returns_4xx(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Inverted Dates Exam",
        "exam_type": "INTERNAL_ASSESSMENT",
        "start_date": "2026-09-15",
        "end_date": "2026-09-10",
        "schedules": []
    }
    resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp.status_code in (400, 422)
    assert "end_date must be after start_date" in resp.text


@pytest.mark.anyio
async def test_auto_resolve_academic_year_when_omitted(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    payload = {
        "school_id": str(school_id),
        # academic_year_id intentionally omitted
        "exam_name": "Auto Resolved AY Exam",
        "exam_type": "INTERNAL_ASSESSMENT",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "schedules": []
    }
    resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp.status_code == 201
    assert resp.json()["data"]["academic_year_id"] == str(ay_id)


@pytest.mark.anyio
async def test_wrong_tenant_or_school_rejected(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]  # user belonging to tenant_a and school_a
    unauthorized_school_id = str(data["school_b"].id)

    payload = {
        "school_id": unauthorized_school_id,
        "exam_name": "Cross School Forbidden Exam",
        "exam_type": "INTERNAL_ASSESSMENT",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "schedules": []
    }
    resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp.status_code in (403, 404, 422)


@pytest.mark.anyio
async def test_duplicate_examination_rejected(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Unique Term Exam 2026",
        "exam_type": "INTERNAL_ASSESSMENT",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }
    resp1 = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp1.status_code == 201

    # Second submission with identical parameters
    resp2 = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert resp2.status_code in (400, 422)
    assert "already exists" in resp2.json()["message"]


@pytest.mark.anyio
async def test_created_exam_retrieval_and_downstream_integration(client: AsyncClient, setup_exam_test_data) -> None:
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = data["school_a"].id
    ay_id = data["ay_a"].id

    # 1. Create exam
    payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": "Downstream Integrated Exam",
        "exam_type": "INTERNAL_ASSESSMENT",
        "start_date": "2026-09-01",
        "end_date": "2026-09-10",
        "target_scope": "ALL_CLASSES",
        "schedules": []
    }
    create_resp = await client.post("/api/v1/examinations/wizard", json=payload, headers=headers)
    assert create_resp.status_code == 201
    exam_id = create_resp.json()["data"]["id"]

    # 2. Retrieve Exam by ID
    get_resp = await client.get(f"/api/v1/examinations/{exam_id}?school_id={school_id}", headers=headers)
    assert get_resp.status_code == 200
    assert get_resp.json()["data"]["id"] == exam_id

    # 3. Available in Examinations list for Marks Management & Import
    list_resp = await client.get(f"/api/v1/examinations?school_id={school_id}", headers=headers)
    assert list_resp.status_code == 200
    exam_ids = [e["id"] for e in list_resp.json()["data"]]
    assert exam_id in exam_ids

    # 4. Usable by Exam Question Mapping
    q_payload = {
        "question_number": "Q1",
        "question_text": "Describe cell division.",
        "chapter_name": "Cytology",
        "subject_id": str(data["subject_a"].id),
        "max_marks": 5.0,
        "question_difficulty": "EASY",
        "question_type": "SHORT"
    }
    q_resp = await client.post(
        f"/api/v1/examinations/{exam_id}/questions?school_id={school_id}&academic_year_id={ay_id}",
        json=q_payload,
        headers=headers
    )
    assert q_resp.status_code == 201
    assert q_resp.json()["data"]["question_number"] == "Q1"

    # Verify questions list
    ql_resp = await client.get(
        f"/api/v1/examinations/{exam_id}/questions?school_id={school_id}&academic_year_id={ay_id}",
        headers=headers
    )
    assert ql_resp.status_code == 200
    assert len(ql_resp.json()["data"]) == 1
