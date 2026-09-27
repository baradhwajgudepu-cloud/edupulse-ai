import io
import uuid
import pytest
from datetime import date
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from PIL import Image as PILImage

from app.models.tenant import Tenant
from app.models.school import School
from app.models.academic_year import AcademicYear, AcademicYearStatus
from app.models.class_entity import Class, ClassCategory
from app.models.section import Section
from app.models.student import Student, StudentGender, StudentStatus
from app.repositories.tenant import TenantRepository
from app.repositories.school import SchoolRepository
from app.repositories.academic_year import AcademicYearRepository
from app.repositories.class_entity import ClassRepository
from app.repositories.section import SectionRepository
from app.repositories.student import StudentRepository
from app.schemas.tenant import TenantCreate
from app.schemas.school import SchoolCreate, SchoolStatus
from app.schemas.academic_year import AcademicYearCreate
from app.schemas.class_entity import ClassCreate
from app.schemas.section import SectionCreate
from app.schemas.student import StudentCreate


def _generate_test_image(format_name: str = "PNG", size: tuple = (100, 100), color: str = "blue") -> bytes:
    img = PILImage.new("RGB", size, color=color)
    buf = io.BytesIO()
    img.save(buf, format=format_name)
    return buf.getvalue()


@pytest.fixture
async def student_photo_setup(db_session: AsyncSession):
    suffix = uuid.uuid4().hex[:6].lower()
    
    # 1. Tenants
    t_repo = TenantRepository(db_session)
    tenant_a = await t_repo.create(TenantCreate(
        name="Student Photo Tenant A", code=f"sp-a-{suffix}", subdomain=f"sp-a-{suffix}", email=f"a-{suffix}@edu.in"
    ))
    tenant_b = await t_repo.create(TenantCreate(
        name="Student Photo Tenant B", code=f"sp-b-{suffix}", subdomain=f"sp-b-{suffix}", email=f"b-{suffix}@edu.in"
    ))
    await db_session.commit()

    # 2. Schools
    s_repo = SchoolRepository(db_session)
    school_a = await s_repo.create(tenant_a.id, SchoolCreate(
        name="School A", code=f"SA_{suffix.upper()}", board="CBSE", email=f"s-a-{suffix}@edu.in", status=SchoolStatus.ACTIVE
    ))
    school_b = await s_repo.create(tenant_b.id, SchoolCreate(
        name="School B", code=f"SB_{suffix.upper()}", board="CBSE", email=f"s-b-{suffix}@edu.in", status=SchoolStatus.ACTIVE
    ))
    await db_session.commit()

    # 3. Academic Years
    ay_repo = AcademicYearRepository(db_session)
    ay_a = await ay_repo.create(tenant_a.id, school_a.id, AcademicYearCreate(
        name="2026-2027", code="AY2026", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30), status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    ay_b = await ay_repo.create(tenant_b.id, school_b.id, AcademicYearCreate(
        name="2026-2027", code="AY2026", start_date=date(2026, 6, 1), end_date=date(2027, 4, 30), status=AcademicYearStatus.ACTIVE, is_current=True
    ))
    await db_session.commit()

    # 4. Classes & Sections
    c_repo = ClassRepository(db_session)
    class_a = await c_repo.create(tenant_a.id, ClassCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, name="Class 5", code="C5", level=5, category=ClassCategory.PRIMARY, capacity=30
    ))
    class_b = await c_repo.create(tenant_b.id, ClassCreate(
        school_id=school_b.id, academic_year_id=ay_b.id, name="Class 5", code="C5", level=5, category=ClassCategory.PRIMARY, capacity=30
    ))
    await db_session.commit()

    sec_repo = SectionRepository(db_session)
    sec_a = await sec_repo.create(tenant_a.id, SectionCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, name="Sec A", code="SA", capacity=30
    ))
    sec_b = await sec_repo.create(tenant_b.id, SectionCreate(
        school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, name="Sec A", code="SA", capacity=30
    ))
    await db_session.commit()

    # 5. Students
    std_repo = StudentRepository(db_session)
    student_a = await std_repo.create(tenant_a.id, StudentCreate(
        school_id=school_a.id, academic_year_id=ay_a.id, class_id=class_a.id, section_id=sec_a.id,
        admission_number=f"ADM-A-{suffix}", roll_number="1", first_name="Jahnavi", last_name="Avula",
        gender=StudentGender.FEMALE, date_of_birth=date(2015, 5, 10), admission_date=date(2026, 6, 1)
    ))
    student_b = await std_repo.create(tenant_b.id, StudentCreate(
        school_id=school_b.id, academic_year_id=ay_b.id, class_id=class_b.id, section_id=sec_b.id,
        admission_number=f"ADM-B-{suffix}", roll_number="1", first_name="Rohan", last_name="Verma",
        gender=StudentGender.MALE, date_of_birth=date(2015, 8, 20), admission_date=date(2026, 6, 1)
    ))
    await db_session.commit()

    return {
        "tenant_a": tenant_a,
        "tenant_b": tenant_b,
        "school_a": school_a,
        "school_b": school_b,
        "student_a": student_a,
        "student_b": student_b,
        "headers_a": {"X-Tenant-ID": str(tenant_a.id)},
        "headers_b": {"X-Tenant-ID": str(tenant_b.id)},
    }


@pytest.mark.anyio
async def test_upload_student_photo_success(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_id = ctx["student_a"].id
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    png_bytes = _generate_test_image("PNG", size=(200, 200), color="teal")
    files = {"file": ("student_dp.png", png_bytes, "image/png")}

    res = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files=files,
        headers=headers
    )
    assert res.status_code == 200, f"Expected 200: {res.text}"
    body = res.json()
    assert body["success"] is True
    data = body["data"]
    assert data["photo_url"] is not None
    assert f"/api/v1/students/{student_id}/photo?school_id={school_id}" in data["photo_url"]
    assert "photo_storage_key" in data["settings"]
    assert f"students/{student_id}/photo/" in data["settings"]["photo_storage_key"]


@pytest.mark.anyio
async def test_get_student_photo_streaming(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_id = ctx["student_a"].id
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    # 1. 404 when no photo has been uploaded yet
    res_404 = await client.get(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        headers=headers
    )
    assert res_404.status_code == 404

    # 2. Upload PNG photo
    png_bytes = _generate_test_image("PNG", size=(150, 150), color="purple")
    files = {"file": ("avatar.png", png_bytes, "image/png")}
    res_up = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files=files,
        headers=headers
    )
    assert res_up.status_code == 200

    # 3. Stream photo back
    res_stream = await client.get(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        headers=headers
    )
    assert res_stream.status_code == 200
    assert res_stream.headers["content-type"] in ["image/png", "image/jpeg", "image/webp"]
    assert len(res_stream.content) > 0


@pytest.mark.anyio
async def test_replace_student_photo(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_id = ctx["student_a"].id
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    # 1. Upload initial photo
    img1 = _generate_test_image("JPEG", (100, 100), "red")
    res1 = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files={"file": ("photo1.jpg", img1, "image/jpeg")},
        headers=headers
    )
    assert res1.status_code == 200
    key1 = res1.json()["data"]["settings"]["photo_storage_key"]

    # 2. Replace with new photo
    img2 = _generate_test_image("PNG", (120, 120), "green")
    res2 = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files={"file": ("photo2.png", img2, "image/png")},
        headers=headers
    )
    assert res2.status_code == 200
    key2 = res2.json()["data"]["settings"]["photo_storage_key"]
    assert key1 != key2


@pytest.mark.anyio
async def test_delete_student_photo(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_id = ctx["student_a"].id
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    # 1. Upload photo
    img = _generate_test_image("PNG", (100, 100), "cyan")
    await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files={"file": ("dp.png", img, "image/png")},
        headers=headers
    )

    # 2. Delete photo
    del_res = await client.delete(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        headers=headers
    )
    assert del_res.status_code == 200
    data = del_res.json()["data"]
    assert data["photo_url"] is None
    assert "photo_storage_key" not in data["settings"]

    # 3. GET should return 404 now
    get_res = await client.get(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        headers=headers
    )
    assert get_res.status_code == 404


@pytest.mark.anyio
async def test_invalid_photo_file_rejected(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_id = ctx["student_a"].id
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    # 1. Invalid extension
    res1 = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files={"file": ("document.pdf", b"%PDF-1.4...", "application/pdf")},
        headers=headers
    )
    assert res1.status_code == 400

    # 2. Corrupt image data with .png extension
    res2 = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files={"file": ("fake.png", b"this is not a valid png image stream", "image/png")},
        headers=headers
    )
    assert res2.status_code == 400


@pytest.mark.anyio
async def test_photo_file_size_rejected(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_id = ctx["student_a"].id
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    # Generate oversized payload > 5MB
    large_bytes = b"0" * (5 * 1024 * 1024 + 1024)
    files = {"file": ("large.png", large_bytes, "image/png")}

    res = await client.post(
        f"/api/v1/students/{student_id}/photo?school_id={school_id}",
        files=files,
        headers=headers
    )
    assert res.status_code == 400
    assert "smaller than 5 MB" in res.text


@pytest.mark.anyio
async def test_tenant_and_school_isolation(client: AsyncClient, student_photo_setup):
    ctx = student_photo_setup
    student_a_id = ctx["student_a"].id
    school_a_id = ctx["school_a"].id
    school_b_id = ctx["school_b"].id
    headers_b = ctx["headers_b"]

    png_bytes = _generate_test_image("PNG")
    files = {"file": ("dp.png", png_bytes, "image/png")}

    # Tenant B tries to upload photo for Student in Tenant A -> Rejected
    res_cross = await client.post(
        f"/api/v1/students/{student_a_id}/photo?school_id={school_a_id}",
        files=files,
        headers=headers_b
    )
    assert res_cross.status_code in [403, 404]

    # Tenant A tries with wrong school ID -> Rejected
    res_wrong_school = await client.post(
        f"/api/v1/students/{student_a_id}/photo?school_id={school_b_id}",
        files=files,
        headers=ctx["headers_a"]
    )
    assert res_wrong_school.status_code in [403, 404]


@pytest.mark.anyio
async def test_student_photo_update_preserves_placement(client: AsyncClient, student_photo_setup):
    """
    Verifies that changing/updating a student profile photo does NOT touch or duplicate academic placement.
    """
    ctx = student_photo_setup
    student = ctx["student_a"]
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    initial_ay = str(student.academic_year_id)
    initial_class = str(student.class_id)
    initial_sec = str(student.section_id)

    # Upload photo
    png_bytes = _generate_test_image("PNG", (120, 120), "green")
    files = {"file": ("new_dp.png", png_bytes, "image/png")}
    res = await client.post(
        f"/api/v1/students/{student.id}/photo?school_id={school_id}",
        files=files,
        headers=headers
    )
    assert res.status_code == 200
    data = res.json()["data"]

    # Verify placement is completely unchanged
    assert data["academic_year_id"] == initial_ay
    assert data["class_id"] == initial_class
    assert data["section_id"] == initial_sec
    assert data["photo_url"] is not None


@pytest.mark.anyio
async def test_student_photo_removal_preserves_placement(client: AsyncClient, student_photo_setup):
    """
    Verifies that removing a student photo clears photo_url while leaving academic placement unchanged.
    """
    ctx = student_photo_setup
    student = ctx["student_a"]
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    initial_ay = str(student.academic_year_id)
    initial_class = str(student.class_id)
    initial_sec = str(student.section_id)

    # First ensure student has a photo
    png_bytes = _generate_test_image("PNG")
    await client.post(
        f"/api/v1/students/{student.id}/photo?school_id={school_id}",
        files={"file": ("dp.png", png_bytes, "image/png")},
        headers=headers
    )

    # Delete photo
    res_del = await client.delete(
        f"/api/v1/students/{student.id}/photo?school_id={school_id}",
        headers=headers
    )
    assert res_del.status_code == 200
    del_data = res_del.json()["data"]
    assert del_data["photo_url"] is None
    assert del_data["academic_year_id"] == initial_ay
    assert del_data["class_id"] == initial_class
    assert del_data["section_id"] == initial_sec


@pytest.mark.anyio
async def test_student_profile_update_with_same_placement_is_idempotent(client: AsyncClient, student_photo_setup):
    """
    Verifies that PUT /students/{id} containing the student's existing academic placement
    succeeds idempotently without raising 'Student is already assigned to this class and section'.
    """
    ctx = student_photo_setup
    student = ctx["student_a"]
    school_id = ctx["school_a"].id
    headers = ctx["headers_a"]

    # Payload includes the student's current placement along with profile attribute changes
    payload = {
        "academic_year_id": str(student.academic_year_id),
        "class_id": str(student.class_id),
        "section_id": str(student.section_id),
        "first_name": "UpdatedName",
        "mobile": "+919876543210"
    }

    res = await client.put(
        f"/api/v1/students/{student.id}?school_id={school_id}",
        json=payload,
        headers=headers
    )
    assert res.status_code == 200
    data = res.json()["data"]
    assert data["first_name"] == "UpdatedName"
    assert data["mobile"] == "+919876543210"
    assert data["academic_year_id"] == str(student.academic_year_id)
    assert data["class_id"] == str(student.class_id)
    assert data["section_id"] == str(student.section_id)

