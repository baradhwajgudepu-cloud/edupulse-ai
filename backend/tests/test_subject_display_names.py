import uuid
import pytest
from datetime import date, time, datetime, timezone

from app.models.subject import Subject, SubjectCategory, SubjectType
from app.models.marks import Marks, MarksStatus, ExamResult
from app.models.examination import ExamSchedule
from app.schemas.marks import (
    MarksResponse,
    SmartMissingSummary,
    MarksReviewQueueItem,
    ParentTimetableSlot,
    ParentSubjectMarkItem,
)
from app.schemas.examination import BulkTimetablePreviewItem, ExamScheduleResponse
from app.schemas.report_card import ReportCardSubjectMarkRow, ExamSubjectMark


def test_subject_model_name_property():
    """Verify Subject.name property returns subject_name for backwards compatibility."""
    sub = Subject(
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        subject_name="Mathematics",
        subject_code="MATH101",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY,
    )
    assert sub.subject_name == "Mathematics"
    assert sub.name == "Mathematics"
    assert sub.subject_code == "MATH101"


def test_marks_model_subject_properties():
    """Verify Marks model dynamically accesses subject_name and subject_code."""
    sub = Subject(
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        subject_name="English Language",
        subject_code="ENG101",
        category=SubjectCategory.LANGUAGE,
        subject_type=SubjectType.THEORY,
    )
    mark = Marks(
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        examination_id=uuid.uuid4(),
        exam_schedule_id=uuid.uuid4(),
        student_id=uuid.uuid4(),
        teacher_subject_assignment_id=uuid.uuid4(),
        teacher_id=uuid.uuid4(),
        subject_id=uuid.uuid4(),
        class_id=uuid.uuid4(),
        section_id=uuid.uuid4(),
        maximum_marks=100,
        marks_obtained=88.5,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.DRAFT,
    )
    # When subject relationship is unset
    assert mark.subject_name is None
    assert mark.subject_code is None

    # When subject relationship is attached
    mark.subject = sub
    assert mark.subject_name == "English Language"
    assert mark.subject_code == "ENG101"


def test_marks_response_serialization():
    """Verify MarksResponse serializes subject_name and subject_code via from_attributes."""
    sub = Subject(
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        subject_name="Science",
        subject_code="SCI101",
        category=SubjectCategory.CORE,
        subject_type=SubjectType.THEORY_PRACTICAL,
    )
    m_id = uuid.uuid4()
    mark = Marks(
        id=m_id,
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        examination_id=uuid.uuid4(),
        exam_schedule_id=uuid.uuid4(),
        student_id=uuid.uuid4(),
        teacher_subject_assignment_id=uuid.uuid4(),
        teacher_id=uuid.uuid4(),
        subject_id=uuid.uuid4(),
        class_id=uuid.uuid4(),
        section_id=uuid.uuid4(),
        maximum_marks=100,
        marks_obtained=95.0,
        result_status=ExamResult.PRESENT,
        status=MarksStatus.APPROVED,
        settings={"bulk_entry": True},
        ai_metrics={},
        audit_history=[],
        is_active=True,
        version=1,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    mark.subject = sub

    resp = MarksResponse.model_validate(mark)
    assert resp.subject_name == "Science"
    assert resp.subject_code == "SCI101"
    dump = resp.model_dump()
    assert dump["subject_name"] == "Science"
    assert dump["subject_code"] == "SCI101"


def test_smart_missing_summary_schema():
    """Verify SmartMissingSummary carries subject_id, subject_name, and subject_code."""
    sub_id = uuid.uuid4()
    summary = SmartMissingSummary(
        total_students=10,
        entered_count=8,
        missing_count=2,
        subject_id=sub_id,
        subject_name="Social Studies",
        subject_code="SOC101",
    )
    assert summary.subject_id == sub_id
    assert summary.subject_name == "Social Studies"
    assert summary.subject_code == "SOC101"


def test_marks_review_queue_item_schema():
    """Verify MarksReviewQueueItem includes subject_code alongside subject_name."""
    item = MarksReviewQueueItem(
        exam_schedule_id=uuid.uuid4(),
        examination_id=uuid.uuid4(),
        exam_name="Term 1",
        class_id=uuid.uuid4(),
        class_name="Grade 10",
        section_id=uuid.uuid4(),
        section_name="A",
        subject_id=uuid.uuid4(),
        subject_name="Physics",
        subject_code="PHY101",
        exam_date="2026-10-15",
        max_marks=100,
        pass_marks=35,
        total_students=30,
        entered_count=30,
        missing_count=0,
        pass_count=28,
        fail_count=2,
        absent_count=0,
        pass_percentage=93.3,
        batch_status=MarksStatus.SUBMITTED,
    )
    assert item.subject_name == "Physics"
    assert item.subject_code == "PHY101"


def test_parent_timetable_slot_schema():
    """Verify ParentTimetableSlot includes subject_code."""
    slot = ParentTimetableSlot(
        exam_schedule_id=uuid.uuid4(),
        examination_id=uuid.uuid4(),
        exam_name="Half Yearly",
        exam_type="SCHOLASTIC",
        subject_id=uuid.uuid4(),
        subject_name="Chemistry",
        subject_code="CHEM101",
        exam_date="2026-10-16",
        start_time="09:00",
        end_time="12:00",
        max_marks=100,
        pass_marks=35,
    )
    assert slot.subject_name == "Chemistry"
    assert slot.subject_code == "CHEM101"


def test_bulk_timetable_preview_item_schema():
    """Verify BulkTimetablePreviewItem includes subject_code."""
    item = BulkTimetablePreviewItem(
        class_id=uuid.uuid4(),
        class_name="Grade 10",
        section_id=uuid.uuid4(),
        section_name="B",
        subject_id=uuid.uuid4(),
        subject_name="Biology",
        subject_code="BIO101",
        exam_date=date(2026, 10, 17),
        start_time=time(9, 0),
        end_time=time(12, 0),
        max_marks=100,
        pass_marks=35,
    )
    assert item.subject_name == "Biology"
    assert item.subject_code == "BIO101"


def test_report_card_subject_mark_row_schema():
    """Verify ReportCardSubjectMarkRow supports subject_id, subject_name, and subject_code."""
    sub_id = uuid.uuid4()
    row = ReportCardSubjectMarkRow(
        subject_id=sub_id,
        subject_name="Mathematics",
        subject_code="MATH101",
        maximum_marks=100,
        marks_obtained=92.0,
        result_status="PRESENT",
        grade="A+",
        remarks="Excellent",
    )
    assert row.subject_id == sub_id
    assert row.subject_name == "Mathematics"
    assert row.subject_code == "MATH101"
    # Verify UUID is not embedded in subject_name
    assert str(sub_id) not in row.subject_name


def test_exam_subject_mark_schema():
    """Verify ExamSubjectMark supports subject_id, subject_name, and subject_code."""
    sub_id = uuid.uuid4()
    mark = ExamSubjectMark(
        subject_id=sub_id,
        subject_name="History",
        subject_code="HIST101",
        max_marks=100,
        marks_obtained=75.0,
        grade="B",
        status="PRESENT",
    )
    assert mark.subject_id == sub_id
    assert mark.subject_name == "History"
    assert mark.subject_code == "HIST101"
    assert str(sub_id) not in mark.subject_name
