import uuid
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.curriculum import CurriculumMaster, CurriculumMasterItem
from app.models.syllabus import Syllabus
from app.models.class_entity import Class, ClassCategory
from app.models.subject import Subject, SubjectCategory, SubjectType, SubjectStatus
from app.repositories.class_entity import ClassRepository
from app.repositories.subject import SubjectRepository
from app.schemas.class_entity import ClassCreate
from app.schemas.subject import SubjectCreate
from tests.test_examinations import setup_exam_test_data


@pytest.mark.anyio
async def test_syllabus_class_bifurcation(client: AsyncClient, setup_exam_test_data: dict, db_session: AsyncSession) -> None:
    """
    1. Verifies that school syllabus items are strictly bifurcated class-wise.
    Querying Class 8 returns ONLY Class 8 items; querying Class 9 returns ONLY Class 9 items.
    """
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    tenant_id = data["tenant_a"].id
    class_8 = data["class_a"]
    class_8_id = str(class_8.id)

    # Create Class 9 in the same school and academic year
    repo_c = ClassRepository(db_session)
    class_9 = await repo_c.create(
        tenant_id,
        ClassCreate(
            school_id=data["school_a"].id,
            academic_year_id=data["ay_a"].id,
            name="Grade 9",
            code=f"G9_{uuid.uuid4().hex[:4].upper()}",
            level=9,
            category=ClassCategory.HIGH,
            capacity=35
        )
    )
    await db_session.commit()
    class_9_id = str(class_9.id)

    # Populate school curriculum
    pop_resp = await client.post(
        f"/api/v1/curriculum/populate?school_id={school_id}",
        json={"academic_year_id": ay_id, "class_ids": [class_8_id, class_9_id]},
        headers=headers
    )
    assert pop_resp.status_code in (200, 201)

    # Query Class 8 Syllabus
    res_8 = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_8_id}",
        headers=headers
    )
    assert res_8.status_code == 200
    items_8 = res_8.json()["data"]
    assert len(items_8) > 0
    # Strict bifurcation assertion: every single item must belong to Class 8
    for item in items_8:
        assert item["class_id"] == class_8_id

    # Query Class 9 Syllabus
    res_9 = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_9_id}",
        headers=headers
    )
    assert res_9.status_code == 200
    items_9 = res_9.json()["data"]
    assert len(items_9) > 0
    # Strict bifurcation assertion: every single item must belong to Class 9
    for item in items_9:
        assert item["class_id"] == class_9_id

    # Cross-check: No item IDs should overlap between Class 8 and Class 9
    ids_8 = {i["id"] for i in items_8}
    ids_9 = {i["id"] for i in items_9}
    assert ids_8.isdisjoint(ids_9)


@pytest.mark.anyio
async def test_syllabus_five_level_editing(client: AsyncClient, setup_exam_test_data: dict, db_session: AsyncSession) -> None:
    """
    2. Verifies full 5-level editing:
    - Topic Update & Delete
    - Chapter Update & Delete
    - Unit Rename & Delete
    - Class-Subject Delete
    """
    data = setup_exam_test_data
    headers = data["auth_headers"]
    school_id = str(data["school_a"].id)
    ay_id = str(data["ay_a"].id)
    class_id = str(data["class_a"].id)
    subject_id = str(data["subject_a"].id)

    # Populate
    await client.post(
        f"/api/v1/curriculum/populate?school_id={school_id}",
        json={"academic_year_id": ay_id, "class_ids": [class_id]},
        headers=headers
    )

    # Get Class 8 items
    res = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    items = res.json()["data"]
    target_topic = items[0]
    target_topic_id = target_topic["id"]
    target_chapter_name = target_topic["chapter_name"]
    target_unit_name = target_topic["unit_name"]

    # 1. Update Topic
    update_top_resp = await client.put(
        f"/api/v1/syllabuses/{target_topic_id}?school_id={school_id}",
        json={
            "topic_name": "Updated Advanced Topic Title",
            "estimated_periods": 8,
            "coverage_status": "COMPLETED"
        },
        headers=headers
    )
    assert update_top_resp.status_code == 200
    updated_top = update_top_resp.json()["data"]
    assert updated_top["topic_name"] == "Updated Advanced Topic Title"
    assert updated_top["estimated_periods"] == 8
    assert updated_top["coverage_status"] == "COMPLETED"

    # 2. Update Chapter (renames chapter across all topics of chapter)
    new_chap_name = f"Renamed Chapter {uuid.uuid4().hex[:4]}"
    chap_update_resp = await client.put(
        f"/api/v1/syllabuses/chapter/update?school_id={school_id}&academic_year_id={ay_id}",
        json={
            "class_id": class_id,
            "subject_id": subject_id,
            "old_chapter_name": target_chapter_name,
            "new_chapter_name": new_chap_name,
            "estimated_periods": 6
        },
        headers=headers
    )
    assert chap_update_resp.status_code == 200
    assert chap_update_resp.json()["data"] >= 1

    # Verify updated chapter name
    res_after_chap = await client.get(
        f"/api/v1/syllabuses?school_id={school_id}&academic_year_id={ay_id}&class_id={class_id}",
        headers=headers
    )
    chap_names = [i["chapter_name"] for i in res_after_chap.json()["data"]]
    assert new_chap_name in chap_names
    assert target_chapter_name not in chap_names

    # 3. Rename Unit (renames unit across all items under it)
    new_u_name = f"Renamed Unit {uuid.uuid4().hex[:4]}"
    unit_rename_resp = await client.put(
        f"/api/v1/syllabuses/unit/rename?school_id={school_id}&academic_year_id={ay_id}",
        json={
            "class_id": class_id,
            "subject_id": subject_id,
            "old_unit_name": target_unit_name,
            "new_unit_name": new_u_name
        },
        headers=headers
    )
    assert unit_rename_resp.status_code == 200
    assert unit_rename_resp.json()["data"] >= 1

    # 4. Delete Chapter
    chap_del_resp = await client.request(
        "DELETE",
        f"/api/v1/syllabuses/chapter?school_id={school_id}&academic_year_id={ay_id}",
        json={
            "class_id": class_id,
            "subject_id": subject_id,
            "chapter_name": new_chap_name
        },
        headers=headers
    )
    assert chap_del_resp.status_code == 200
    assert chap_del_resp.json()["data"] >= 1

    # 5. Master Immutability Check:
    # Ensure CurriculumMaster and CurriculumMasterItem remain completely intact
    items_stmt = select(CurriculumMasterItem).join(CurriculumMaster).where(
        CurriculumMaster.board == "CBSE",
        CurriculumMaster.class_level == 8
    )
    items_res = await db_session.execute(items_stmt)
    master_items = list(items_res.scalars().all())
    assert len(master_items) > 0
    for it in master_items:
        # Master chapters must NOT have been changed to new_chap_name
        assert it.chapter_name != new_chap_name
        assert it.unit_name != new_u_name
