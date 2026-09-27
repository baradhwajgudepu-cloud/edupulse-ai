import uuid
from datetime import date, datetime
import pytest
from app.models.attendance import Attendance, AttendanceStatus, AttendanceSessionType, AttendanceSource, AttendanceReason
from app.models.student import Student, StudentGender, StudentStatus
from app.models.class_entity import Class
from app.models.section import Section
from app.schemas.attendance import AttendanceResponse

def test_attendance_model_properties_with_student():
    student = Student(
        id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        class_id=uuid.uuid4(),
        section_id=uuid.uuid4(),
        first_name="Vikram",
        middle_name=None,
        last_name="Katta",
        gender=StudentGender.MALE,
        date_of_birth=date(2010, 5, 12),
        admission_number="ADM20265347",
        roll_number="17",
        admission_date=date(2024, 6, 1),
        status=StudentStatus.ACTIVE,
        is_active=True
    )

    attendance = Attendance(
        id=uuid.uuid4(),
        tenant_id=student.tenant_id,
        school_id=student.school_id,
        academic_year_id=student.academic_year_id,
        attendance_session_id=uuid.uuid4(),
        student_id=student.id,
        class_id=student.class_id,
        section_id=student.section_id,
        attendance_date=date(2026, 9, 15),
        session_type=AttendanceSessionType.FULL_DAY,
        attendance_status=AttendanceStatus.PRESENT,
        attendance_source=AttendanceSource.MANUAL,
        attendance_reason=AttendanceReason.UNKNOWN,
        is_active=True,
        settings={},
        ai_metrics={},
        version=1,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    attendance.student = student

    # Check model properties
    assert attendance.student_name == "Vikram Katta"
    assert attendance.admission_number == "ADM20265347"
    assert attendance.roll_number == "17"

    # Check Pydantic response validation & serialization
    response = AttendanceResponse.model_validate(attendance)
    data = response.model_dump(mode="json")

    assert data["student_id"] == str(student.id)
    assert data["student_name"] == "Vikram Katta"
    assert data["admission_number"] == "ADM20265347"
    assert data["roll_number"] == "17"
    assert data["status"] == "PRESENT"
    assert data["attendance_status"] == "PRESENT"

def test_attendance_model_properties_without_student():
    attendance = Attendance(
        id=uuid.uuid4(),
        tenant_id=uuid.uuid4(),
        school_id=uuid.uuid4(),
        academic_year_id=uuid.uuid4(),
        attendance_session_id=uuid.uuid4(),
        student_id=uuid.uuid4(),
        class_id=uuid.uuid4(),
        section_id=uuid.uuid4(),
        attendance_date=date(2026, 9, 15),
        session_type=AttendanceSessionType.FULL_DAY,
        attendance_status=AttendanceStatus.ABSENT,
        attendance_source=AttendanceSource.MANUAL,
        attendance_reason=AttendanceReason.UNKNOWN,
        is_active=True,
        settings={},
        ai_metrics={},
        version=1,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow()
    )
    attendance.student = None

    assert attendance.student_name is None
    assert attendance.admission_number is None
    assert attendance.roll_number is None

    response = AttendanceResponse.model_validate(attendance)
    data = response.model_dump(mode="json")

    assert data["student_name"] is None
    assert data["admission_number"] is None
    assert data["roll_number"] is None
    assert data["status"] == "ABSENT"
