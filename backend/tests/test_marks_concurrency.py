import pytest
import uuid
from datetime import date
from unittest.mock import MagicMock, AsyncMock
from fastapi import HTTPException
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.examination import ExamSchedule
from app.models.student import Student
from app.schemas.marks import BulkMarksEntry, SingleMarkEntry
from app.services.marks import MarksService

@pytest.mark.anyio
async def test_marks_optimistic_locking_conflict():
    """Verify that updating a mark with a stale version raises HTTP 409 Conflict."""
    mock_repo = MagicMock()
    mock_repo.db = MagicMock()
    mock_repo.db.execute = AsyncMock()
    mock_repo.db.commit = AsyncMock()
    mock_repo.db.rollback = AsyncMock()

    service = MarksService(
        marks_repo=mock_repo,
        schedule_repo=MagicMock(),
        exam_repo=MagicMock(),
        student_repo=MagicMock(),
        tsa_repo=MagicMock(),
        school_repo=MagicMock(),
        notification_service=MagicMock(),
    )

    tenant_id = uuid.uuid4()
    school_id = uuid.uuid4()
    exam_schedule_id = uuid.uuid4()
    student_id = uuid.uuid4()
    user_id = uuid.uuid4()

    user = MagicMock()
    user.id = user_id
    user.is_superuser = False
    user.roles = []

    # Mock schedule
    sched = ExamSchedule(
        id=exam_schedule_id,
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=uuid.uuid4(),
        exam_id=uuid.uuid4(),
        class_id=uuid.uuid4(),
        section_id=uuid.uuid4(),
        subject_id=uuid.uuid4(),
        max_marks=100.0,
        pass_marks=35.0,
    )
    service.schedule_repo.get_by_id = AsyncMock(return_value=sched)

    # Mock examination
    from app.models.examination import Examination, ExamStatus, ExamType
    exam = Examination(
        id=sched.exam_id,
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=sched.academic_year_id,
        status=ExamStatus.DRAFT,
        exam_name="Term 1",
        exam_type=ExamType.UNIT_TEST,
        start_date=date.today(),
        end_date=date.today(),
    )

    # Mock student
    student = Student(
        id=student_id,
        tenant_id=tenant_id,
        school_id=school_id,
        class_id=sched.class_id,
        section_id=sched.section_id,
        first_name="Alice",
        last_name="Test",
        roll_number="101",
        is_active=True,
    )
    mock_res_s = MagicMock()
    mock_res_s.scalar_one_or_none.return_value = sched
    mock_res_e = MagicMock()
    mock_res_e.scalar_one_or_none.return_value = exam
    mock_res_tsa = MagicMock()
    mock_res_tsa.scalars.return_value.first.return_value = None
    mock_res_st = MagicMock()
    mock_res_st.scalar_one_or_none.return_value = student
    mock_repo.db.execute.side_effect = [mock_res_s, mock_res_e, mock_res_tsa, mock_res_st]

    # Mock existing mark with version 5
    db_mark = Marks(
        id=uuid.uuid4(),
        tenant_id=tenant_id,
        school_id=school_id,
        academic_year_id=sched.academic_year_id,
        examination_id=sched.exam_id,
        exam_schedule_id=exam_schedule_id,
        student_id=student_id,
        maximum_marks=100.0,
        marks_obtained=80.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.DRAFT,
        version=5,
        audit_history=[],
    )
    mock_repo.get_by_student_and_schedule = AsyncMock(return_value=db_mark)

    # Teacher submits update with stale version 4 (mismatch)
    obj_in = BulkMarksEntry(
        exam_schedule_id=exam_schedule_id,
        marks=[
            SingleMarkEntry(
                student_id=student_id,
                marks_obtained=85.0,
                result_status=ExamResult.PRESENT,
                remarks="Updated score",
                version=4, # Stale version!
            )
        ],
    )

    with pytest.raises(HTTPException) as exc_info:
        await service.bulk_save_marks(tenant_id, school_id, obj_in, user, autosave=False)

    assert exc_info.value.status_code == 409
    assert exc_info.value.detail["code"] == "MARKS_CONFLICT"
