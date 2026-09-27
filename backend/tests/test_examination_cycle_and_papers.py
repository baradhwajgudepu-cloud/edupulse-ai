import pytest
import uuid
from datetime import date, time, timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.test_examinations import setup_exam_test_data

@pytest.mark.anyio
async def test_examination_cycle_papers_and_classes_workflow(client: AsyncClient, setup_exam_test_data: dict, db_session: AsyncSession):
    env = setup_exam_test_data
    headers = env["auth_headers"]
    school_id = env["school_a"].id
    ay_id = env["ay_a"].id
    class_a = env["class_a"]
    class_b = env["class_b"]
    subject_a = env["subject_a"]

    # 1. Create an Examination Cycle with multiple participating classes
    start_d = date.today() + timedelta(days=7)
    end_d = start_d + timedelta(days=14)

    create_payload = {
        "school_id": str(school_id),
        "academic_year_id": str(ay_id),
        "exam_name": f"Term 1 Final Cycle {uuid.uuid4().hex[:4]}",
        "exam_type": "QUARTERLY",
        "start_date": start_d.isoformat(),
        "end_date": end_d.isoformat(),
        "description": "Unified school-wide institutional exam cycle",
        "participating_class_ids": [str(class_a.id), str(class_b.id)],
        "settings": {"term": "Q1"}
    }

    res = await client.post("/api/v1/examinations", json=create_payload, headers=headers)
    assert res.status_code == 201
    created_exam = res.json()["data"]
    exam_id = created_exam["id"]
    assert len(created_exam["participating_class_ids"]) == 2

    # 2. Add an Examination Paper to the Cycle
    paper_payload = {
        "subject_id": str(subject_a.id),
        "paper_name": "Mathematics Paper 1",
        "paper_code": "MATH-P1",
        "default_max_marks": 100,
        "default_pass_marks": 35,
        "default_duration_minutes": 180,
        "order_index": 1
    }
    res_p = await client.post(f"/api/v1/examinations/{exam_id}/papers", json=paper_payload, params={"school_id": str(school_id)}, headers=headers)
    assert res_p.status_code == 201
    created_paper = res_p.json()["data"]
    paper_id = created_paper["id"]
    assert created_paper["paper_name"] == "Mathematics Paper 1"

    # 3. Configure Class-Specific Overrides for this Paper (e.g. Class A max 50 marks, pass 18)
    class_configs_payload = {
        "configs": [
            {
                "class_id": str(class_a.id),
                "maximum_marks": 50,
                "pass_marks": 18,
                "duration_minutes": 120
            }
        ]
    }
    res_cfg = await client.post(f"/api/v1/examinations/papers/{paper_id}/classes", json=class_configs_payload, params={"school_id": str(school_id)}, headers=headers)
    assert res_cfg.status_code == 200
    configs = res_cfg.json()["data"]
    assert len(configs) == 1
    assert configs[0]["maximum_marks"] == 50
    assert configs[0]["pass_marks"] == 18

    # 4A. Preview Bulk Timetable with Exclude Weekends = True
    # Choose a Friday start date to test weekend skipping
    fri = start_d
    while fri.weekday() != 4:  # 4 is Friday
        fri += timedelta(days=1)

    preview_req_no_wknd = {
        "school_id": str(school_id),
        "examination_id": exam_id,
        "class_ids": [str(class_a.id)],
        "start_date": fri.isoformat(),
        "gap_days": 1,
        "exclude_weekends": True,
        "scheduling_strategy": "ONE_PAPER_PER_DAY"
    }
    res_prev = await client.post("/api/v1/examinations/schedules/bulk-preview", json=preview_req_no_wknd, headers=headers)
    assert res_prev.status_code == 200
    prev_data = res_prev.json()["data"]
    for slot in prev_data["schedules"]:
        slot_date = date.fromisoformat(slot["exam_date"])
        # With exclude_weekends=True, slots must NEVER be Saturday (5) or Sunday (6)
        assert slot_date.weekday() < 5, f"Slot on {slot_date} fell on weekend (weekday {slot_date.weekday()})"
        assert slot["day_name"] is not None
        assert slot["duration_minutes"] == 120
        assert slot["conflict_status"] == "OK"
        # Verify class override was applied for Class A!
        if slot["class_id"] == str(class_a.id):
            assert slot["max_marks"] == 50, f"Expected 50 marks override, got {slot['max_marks']}"
            assert slot["pass_marks"] == 18, f"Expected 18 pass marks override, got {slot['pass_marks']}"

    # 4B. Preview Bulk Timetable with Exclude Weekends = False (Saturday permitted)
    sat = fri + timedelta(days=1)
    preview_req_with_wknd = {
        "school_id": str(school_id),
        "examination_id": exam_id,
        "class_ids": [str(class_a.id)],
        "start_date": sat.isoformat(),
        "gap_days": 0,
        "exclude_weekends": False,
        "scheduling_strategy": "ONE_PAPER_PER_DAY"
    }
    res_prev_wknd = await client.post("/api/v1/examinations/schedules/bulk-preview", json=preview_req_with_wknd, headers=headers)
    assert res_prev_wknd.status_code == 200
    prev_data_wknd = res_prev_wknd.json()["data"]
    sat_slot = prev_data_wknd["schedules"][0]
    assert date.fromisoformat(sat_slot["exam_date"]).weekday() == 5
    assert sat_slot["day_name"] == "Saturday"

    # 4C. Holiday Conflict Detection
    from app.models.academic_calendar import AcademicCalendarEvent, CalendarEventType, CalendarEventStatus
    holiday_d = fri
    hol = AcademicCalendarEvent(
        school_id=school_id,
        tenant_id=env["tenant_a"].id,
        academic_year_id=ay_id,
        event_date=holiday_d,
        event_type=CalendarEventType.PUBLIC_HOLIDAY,
        title="State Festival Holiday",
        status=CalendarEventStatus.APPROVED
    )
    db_session.add(hol)
    await db_session.commit()

    res_prev_hol = await client.post("/api/v1/examinations/schedules/bulk-preview", json=preview_req_no_wknd, headers=headers)
    assert res_prev_hol.status_code == 200
    hol_data = res_prev_hol.json()["data"]
    assert hol_data["has_conflicts"] is True
    assert hol_data["conflict_count"] > 0
    assert any("Holiday conflict detected" in w for w in hol_data["warnings"])

    # 4D. Confirm Bulk Timetable with Auto-Expansion of End Date
    # Schedules extending past original end_date auto-expand exam.end_date
    sched_payload = [
        {
            "class_id": str(class_a.id),
            "section_id": str(env["sec_a1"].id),
            "subject_id": str(subject_a.id),
            "exam_date": (end_d + timedelta(days=2)).isoformat(),
            "start_time": "09:00:00",
            "end_time": "12:00:00",
            "max_marks": 50,
            "pass_marks": 18
        }
    ]
    res_conf = await client.post(
        "/api/v1/examinations/schedules/bulk-confirm",
        json={"school_id": str(school_id), "examination_id": exam_id, "schedules": sched_payload},
        headers=headers
    )
    assert res_conf.status_code == 201

    # 5. Fetch Examination Details and verify aggregated metrics and extended end_date
    res_det = await client.get(f"/api/v1/examinations/{exam_id}/detail", params={"school_id": str(school_id)}, headers=headers)
    assert res_det.status_code == 200
    detail = res_det.json()["data"]
    assert detail["total_papers_count"] == 1
    assert len(detail["papers"]) == 1
    assert len(detail["participating_class_ids"]) == 2
    assert detail["end_date"] == (end_d + timedelta(days=2)).isoformat()
