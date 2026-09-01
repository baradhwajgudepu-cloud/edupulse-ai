import pytest
import uuid
from datetime import date, time, timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.examination import ExamStatus, ExamTypeCategory

from tests.test_examinations import setup_exam_test_data

@pytest.mark.anyio
async def test_exam_types_crud(client: AsyncClient, setup_exam_test_data: dict):
    env = setup_exam_test_data
    headers = env["auth_headers"]
    school_id = env["school_a"].id

    # 1. List default exam types
    res_list = await client.get(
        "/api/v1/examinations/types",
        params={"school_id": str(school_id)},
        headers=headers
    )
    assert res_list.status_code == 200
    types = res_list.json()["data"]
    assert len(types) >= 5

    # 2. Create custom exam type
    code = f"CUSTOM_{uuid.uuid4().hex[:6].upper()}"
    res_create = await client.post(
        "/api/v1/examinations/types",
        json={
            "name": "Mid-Term Diagnostic Test",
            "code": code,
            "description": "Custom diagnostic evaluation",
            "category": "SCHOLASTIC",
            "default_weightage": 40.0,
            "school_id": str(school_id),
            "is_active": True
        },
        headers=headers
    )
    assert res_create.status_code == 201
    created_type = res_create.json()["data"]
    type_id = created_type["id"]
    assert created_type["code"] == code

    # 3. Update exam type
    res_update = await client.put(
        f"/api/v1/examinations/types/{type_id}",
        params={"school_id": str(school_id)},
        json={"name": "Updated Diagnostic Test", "default_weightage": 45.0},
        headers=headers
    )
    assert res_update.status_code == 200
    assert res_update.json()["data"]["name"] == "Updated Diagnostic Test"
    assert res_update.json()["data"]["default_weightage"] == 45.0

    # 4. Delete unreferenced exam type
    res_del = await client.delete(
        f"/api/v1/examinations/types/{type_id}",
        params={"school_id": str(school_id)},
        headers=headers
    )
    assert res_del.status_code == 200


@pytest.mark.anyio
async def test_exam_status_strict_state_machine(client: AsyncClient, setup_exam_test_data: dict):
    env = setup_exam_test_data
    headers = env["auth_headers"]
    school_id = env["school_a"].id

    # 1. Create draft exam
    today = date.today()
    res_create = await client.post(
        "/api/v1/examinations",
        json={
            "school_id": str(school_id),
            "exam_name": f"State Machine Test Exam {uuid.uuid4().hex[:6]}",
            "exam_type": "UNIT_TEST",
            "start_date": (today + timedelta(days=10)).isoformat(),
            "end_date": (today + timedelta(days=20)).isoformat(),
            "description": "Test exam for state machine",
            "participating_class_ids": []
        },
        headers=headers
    )
    assert res_create.status_code == 201
    exam = res_create.json()["data"]
    exam_id = exam["id"]
    assert exam["status"] == "DRAFT"

    # 2. Invalid jump from DRAFT directly to PUBLISHED without override -> Should FAIL 422
    res_invalid = await client.put(
        f"/api/v1/examinations/{exam_id}/status",
        params={"school_id": str(school_id)},
        json={"new_status": "PUBLISHED", "is_administrative_override": False},
        headers=headers
    )
    assert res_invalid.status_code == 422

    # 3. Override without justification reason -> Should FAIL 422
    res_no_reason = await client.put(
        f"/api/v1/examinations/{exam_id}/status",
        params={"school_id": str(school_id)},
        json={"new_status": "SCHEDULED", "is_administrative_override": True, "reason": ""},
        headers=headers
    )
    assert res_no_reason.status_code == 422

    # 4. Valid Admin Override with reason -> Should SUCCEED
    res_override = await client.put(
        f"/api/v1/examinations/{exam_id}/status",
        params={"school_id": str(school_id)},
        json={
            "new_status": "SCHEDULED",
            "is_administrative_override": True,
            "reason": "Administrative emergency scheduling"
        },
        headers=headers
    )
    assert res_override.status_code == 200
    assert res_override.json()["data"]["status"] == "SCHEDULED"


@pytest.mark.anyio
async def test_bulk_timetable_preview(client: AsyncClient, setup_exam_test_data: dict):
    env = setup_exam_test_data
    headers = env["auth_headers"]
    school_id = env["school_a"].id
    class_id = env["class_a"].id

    # 1. Create master exam
    today = date.today()
    res_create = await client.post(
        "/api/v1/examinations",
        json={
            "school_id": str(school_id),
            "exam_name": f"Bulk Timetable Exam {uuid.uuid4().hex[:6]}",
            "exam_type": "UNIT_TEST",
            "start_date": (today + timedelta(days=30)).isoformat(),
            "end_date": (today + timedelta(days=45)).isoformat(),
            "description": "Bulk timetable testing"
        },
        headers=headers
    )
    assert res_create.status_code == 201
    exam = res_create.json()["data"]
    exam_id = exam["id"]

    # 2. Preview generation with active class -> Returns preview response structure
    res_preview = await client.post(
        "/api/v1/examinations/schedules/bulk-preview",
        json={
            "school_id": str(school_id),
            "examination_id": exam_id,
            "class_ids": [str(class_id)],
            "start_date": (today + timedelta(days=31)).isoformat(),
            "gap_days": 1,
            "start_time": "09:00:00",
            "duration_minutes": 180,
            "exclude_weekends": True,
            "max_marks": 100,
            "pass_marks": 35
        },
        headers=headers
    )
    assert res_preview.status_code == 200
    assert "total_slots" in res_preview.json()["data"]
