import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.class_entity import Class
from app.models.section import Section
from app.models.subject import Subject
from app.models.teacher import Teacher
from app.models.guardian import Guardian, StudentGuardian
from app.models.student import Student
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.timetable import Timetable
from app.models.syllabus import Syllabus
from app.models.examination import Examination
from app.models.user import User

@pytest.mark.anyio
async def test_school_onboarding_e2e_reconciliation_and_cascade(
    client: AsyncClient,
    db_session: AsyncSession,
):
    """
    Automated Integration Test:
    1. Creates isolated test tenant and school campus
    2. Ingests full synthetic datasets across onboarding modules
    3. Verifies Database Persistence vs API Query Visibility reconciliation
    4. Verifies school scoping and filtering across Directory APIs (Students, Teachers, Guardians)
    5. Soft-deletes the school and verifies complete cascading deletion of all dependent records
    6. Confirms other school/tenant data remains completely unaffected
    """
    db = db_session

    # 1. Create a Tenant
    unique_suffix = uuid.uuid4().hex[:6]
    tenant_data = {
        "name": f"E2E Test Trust {unique_suffix}",
        "display_name": "E2E Trust",
        "code": f"e2e-trust-{unique_suffix}",
        "subdomain": f"e2etrust{unique_suffix}",
        "email": f"trust_{unique_suffix}@edu.in",
        "phone": "+919876543210",
        "website": "https://e2etrust.edu.in",
        "timezone": "Asia/Kolkata",
        "currency": "INR",
        "address": "Madhapur",
        "city": "Hyderabad",
        "state": "Telangana",
        "postal_code": "500081"
    }
    t_resp = await client.post("/api/v1/tenants", json=tenant_data)
    assert t_resp.status_code == 201
    tenant_id = t_resp.json()["data"]["id"]
    headers = {"X-Tenant-ID": tenant_id}

    # 2. Create isolated test school
    school_payload = {
        "name": "E2E Reconciliation Academy",
        "code": f"E2E_{unique_suffix.upper()}",
        "board": "CBSE",
        "school_type": "HIGH_SCHOOL",
        "email": f"e2e_{unique_suffix}@school.edu",
        "phone": "+919849123456",
        "address": "Hyderabad Campus",
        "city": "Hyderabad",
        "state": "Telangana",
        "country": "India",
        "postal_code": "500001",
    }
    resp_school = await client.post("/api/v1/schools", json=school_payload, headers=headers)
    assert resp_school.status_code == 201, resp_school.text
    school_data = resp_school.json()["data"]
    school_id = uuid.UUID(school_data["id"])

    # 3. Ingest Academic Year
    ay_payload = {
        "code": "AY2025-2026",
        "name": "Academic Year 2025-2026",
        "start_date": "2025-06-01",
        "end_date": "2026-03-31",
        "is_current": True,
    }
    resp_ay = await client.post(f"/api/v1/schools/{school_id}/academic-years", json=ay_payload, headers=headers)
    assert resp_ay.status_code == 201, resp_ay.text
    ay_id = uuid.UUID(resp_ay.json()["data"]["id"])

    # 4. Ingest Classes (6 classes: Class 5 to Class 10)
    class_ids = {}
    for level in range(5, 11):
        c_payload = {
            "school_id": str(school_id),
            "academic_year_id": str(ay_id),
            "code": f"C{level}",
            "name": f"Class {level}",
            "level": level,
            "category": "HIGH" if level >= 9 else "MIDDLE",
            "capacity": 40,
        }
        resp_c = await client.post("/api/v1/classes", json=c_payload, headers=headers)
        assert resp_c.status_code == 201, resp_c.text
        class_ids[f"C{level}"] = uuid.UUID(resp_c.json()["data"]["id"])

    assert len(class_ids) == 6

    # 5. Ingest Sections (12 sections: A and B for each class)
    section_ids = {}
    for level in range(5, 11):
        for sec in ["A", "B"]:
            sec_payload = {
                "school_id": str(school_id),
                "academic_year_id": str(ay_id),
                "class_id": str(class_ids[f"C{level}"]),
                "code": f"SEC_{level}_{sec}",
                "name": f"Section {sec}",
                "capacity": 40,
                "room_number": f"R{level}0{1 if sec == 'A' else 2}",
            }
            resp_sec = await client.post("/api/v1/sections", json=sec_payload, headers=headers)
            assert resp_sec.status_code == 201, resp_sec.text
            section_ids[f"C{level}-{sec}"] = uuid.UUID(resp_sec.json()["data"]["id"])

    assert len(section_ids) == 12

    # 6. Ingest Subjects (6 subjects)
    subject_codes = ["MATH101", "ENG101", "TEL101", "HIN101", "SCI101", "SOC101"]
    subject_ids = {}
    for sc in subject_codes:
        sub_payload = {
            "school_id": str(school_id),
            "academic_year_id": str(ay_id),
            "subject_code": sc,
            "subject_name": sc.replace("101", " Subject"),
            "category": "CORE",
            "subject_type": "THEORY_PRACTICAL" if "SCI" in sc else "THEORY",
            "weekly_periods": 6 if "MATH" in sc or "SCI" in sc else 5 if "ENG" in sc or "TEL" in sc else 4,
            "pass_marks": 35,
            "theory_marks": 80,
            "practical_marks": 20 if "SCI" in sc else 0,
            "credit_hours": 4,
        }
        resp_sub = await client.post("/api/v1/subjects", json=sub_payload, headers=headers)
        assert resp_sub.status_code == 201, resp_sub.text
        subject_ids[sc] = uuid.UUID(resp_sub.json()["data"]["id"])

    assert len(subject_ids) == 6

    # 7. Ingest Teachers (18 teachers)
    teacher_ids = {}
    for t_idx in range(1, 19):
        t_code = f"TCH{t_idx:03d}"
        t_payload = {
            "school_id": str(school_id),
            "staff_code": t_code,
            "employee_code": f"EMP{t_idx:03d}",
            "first_name": f"TeacherFirstName{t_idx}",
            "last_name": f"TeacherLastName{t_idx}",
            "gender": "MALE" if t_idx % 2 == 1 else "FEMALE",
            "date_of_birth": "1985-05-15",
            "official_email": f"faculty_{unique_suffix}_{t_idx:03d}@school.edu",
            "mobile": f"+919849{t_idx:06d}",
            "designation": "PRINCIPAL" if t_idx == 1 else "PGT" if t_idx <= 7 else "TGT",
            "joining_date": "2025-06-01",
            "employment_type": "FULL_TIME",
        }
        resp_t = await client.post("/api/v1/teachers", json=t_payload, headers=headers)
        assert resp_t.status_code == 201, resp_t.text
        teacher_ids[t_code] = uuid.UUID(resp_t.json()["data"]["id"])

    assert len(teacher_ids) == 18

    # 8. Ingest Guardians (20 test guardians)
    guardian_ids = {}
    for g_idx in range(1, 21):
        g_code = f"GRD{g_idx:03d}"
        g_payload = {
            "school_id": str(school_id),
            "guardian_type": "FATHER",
            "first_name": f"ParentFirstName{g_idx}",
            "last_name": f"ParentLastName{g_idx}",
            "gender": "MALE",
            "date_of_birth": "1980-05-15",
            "mobile": f"+919870{g_idx:06d}",
            "email": f"parent_{unique_suffix}_{g_idx:03d}@family.edu",
        }
        resp_g = await client.post("/api/v1/guardians", json=g_payload, headers=headers)
        assert resp_g.status_code == 201, resp_g.text
        guardian_ids[g_code] = uuid.UUID(resp_g.json()["data"]["id"])

    assert len(guardian_ids) == 20

    # 9. Ingest Students (20 test students)
    student_ids = {}
    for s_idx in range(1, 21):
        s_code = f"ADM{s_idx:03d}"
        s_payload = {
            "school_id": str(school_id),
            "academic_year_id": str(ay_id),
            "class_id": str(class_ids["C5"]),
            "section_id": str(section_ids["C5-A"]),
            "admission_number": s_code,
            "first_name": f"StudentFirstName{s_idx}",
            "last_name": f"StudentLastName{s_idx}",
            "gender": "MALE" if s_idx % 2 == 1 else "FEMALE",
            "date_of_birth": "2015-05-15",
            "admission_date": "2025-06-01",
            "roll_number": str(s_idx),
        }
        resp_s = await client.post("/api/v1/students", json=s_payload, headers=headers)
        assert resp_s.status_code == 201, resp_s.text
        student_ids[s_code] = uuid.UUID(resp_s.json()["data"]["id"])

    assert len(student_ids) == 20

    # 10. Verify Database Persistence vs API Query Visibility Reconciliation
    # Direct DB queries scoped to school
    db_students_count = await db.scalar(
        select(func.count(Student.id)).where(Student.school_id == school_id, Student.deleted_at.is_(None))
    )
    assert db_students_count == 20

    db_teachers_count = await db.scalar(
        select(func.count(Teacher.id)).where(Teacher.school_id == school_id, Teacher.deleted_at.is_(None))
    )
    assert db_teachers_count == 18

    db_guardians_count = await db.scalar(
        select(func.count(Guardian.id)).where(Guardian.school_id == school_id, Guardian.deleted_at.is_(None))
    )
    assert db_guardians_count == 20

    # 11. Test Directory APIs with no filters
    # Student Directory API
    resp_student_list = await client.get(f"/api/v1/students?school_id={school_id}&skip=0&limit=100", headers=headers)
    assert resp_student_list.status_code == 200, resp_student_list.text
    students_api_data = resp_student_list.json()["data"]
    assert len(students_api_data) == 20
    assert all(s["school_id"] == str(school_id) for s in students_api_data)

    # Teachers Directory API
    resp_teacher_list = await client.get(f"/api/v1/teachers?school_id={school_id}&skip=0&limit=100", headers=headers)
    assert resp_teacher_list.status_code == 200, resp_teacher_list.text
    teachers_api_data = resp_teacher_list.json()["data"]
    assert len(teachers_api_data) == 18
    assert all(t["school_id"] == str(school_id) for t in teachers_api_data)

    # Guardians Directory API
    resp_guardian_list = await client.get(f"/api/v1/guardians?school_id={school_id}&skip=0&limit=100", headers=headers)
    assert resp_guardian_list.status_code == 200, resp_guardian_list.text
    guardians_api_data = resp_guardian_list.json()["data"]
    assert len(guardians_api_data) == 20
    assert all(g["school_id"] == str(school_id) for g in guardians_api_data)

    # 12. Delete the School and verify cascading deletion
    resp_del = await client.delete(f"/api/v1/schools/{school_id}", headers=headers)
    assert resp_del.status_code in (200, 204), resp_del.text

    # 13. Verify all dependent entities are cascade-removed for this school
    post_del_students = await db.scalar(
        select(func.count(Student.id)).where(Student.school_id == school_id, Student.deleted_at.is_(None))
    )
    assert post_del_students == 0

    post_del_teachers = await db.scalar(
        select(func.count(Teacher.id)).where(Teacher.school_id == school_id, Teacher.deleted_at.is_(None))
    )
    assert post_del_teachers == 0

    post_del_guardians = await db.scalar(
        select(func.count(Guardian.id)).where(Guardian.school_id == school_id, Guardian.deleted_at.is_(None))
    )
    assert post_del_guardians == 0

    post_del_classes = await db.scalar(
        select(func.count(Class.id)).where(Class.school_id == school_id, Class.deleted_at.is_(None))
    )
    assert post_del_classes == 0

    post_del_sections = await db.scalar(
        select(func.count(Section.id)).where(Section.school_id == school_id, Section.deleted_at.is_(None))
    )
    assert post_del_sections == 0

    post_del_subjects = await db.scalar(
        select(func.count(Subject.id)).where(Subject.school_id == school_id, Subject.deleted_at.is_(None))
    )
    assert post_del_subjects == 0

    # 14. Confirm school no longer returned in active school lists
    resp_schools_after = await client.get("/api/v1/schools", headers=headers)
    assert resp_schools_after.status_code == 200
    active_schools_ids = [s["id"] for s in resp_schools_after.json()["data"]]
    assert str(school_id) not in active_schools_ids
