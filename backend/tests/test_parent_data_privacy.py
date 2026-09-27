import pytest
import uuid
from unittest.mock import MagicMock, AsyncMock
from fastapi import HTTPException
from app.services.marks import MarksService
from app.api.v1.endpoints.report_cards import verify_student_access

@pytest.mark.anyio
async def test_parent_unauthorized_student_access_rejected():
    """Verify that a parent attempting to access an unlinked student's marks is rejected."""
    mock_repo = MagicMock()
    mock_repo.db = MagicMock()
    mock_repo.db.execute = AsyncMock()

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
    student_id = uuid.uuid4()
    parent_user = MagicMock()
    parent_user.id = uuid.uuid4()
    parent_user.email = "parent@example.com"
    parent_user.is_superuser = False
    parent_user.roles = [MagicMock(code="PARENT")]

    # Mock no active guardian relationship found for this parent & student
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    mock_repo.db.execute.return_value = mock_res

    with pytest.raises(HTTPException) as exc_info:
        await service.get_parent_student_marks(tenant_id, school_id, student_id, parent_user)

    assert exc_info.value.status_code == 403
    assert "Access denied" in exc_info.value.detail

@pytest.mark.anyio
async def test_parent_report_card_unauthorized_access_rejected():
    """Verify that a parent attempting to access an unlinked student's report cards is rejected."""
    mock_db = MagicMock()
    mock_db.execute = AsyncMock()

    student_id = uuid.uuid4()
    section_id = uuid.uuid4()
    parent_user = MagicMock()
    parent_user.id = uuid.uuid4()
    parent_user.email = "parent2@example.com"
    parent_user.is_superuser = False
    parent_user.roles = [MagicMock(code="PARENT")]

    # Mock no guardian mapping found
    mock_res = MagicMock()
    mock_res.scalar.return_value = None
    mock_db.execute.return_value = mock_res

    with pytest.raises(HTTPException) as exc_info:
        await verify_student_access(
            current_user=parent_user,
            student_id=student_id,
            section_id=section_id,
            db=mock_db
        )

    assert exc_info.value.status_code == 403
    assert "Access denied" in exc_info.value.detail

@pytest.mark.anyio
async def test_parent_report_card_authorized_access_allowed():
    """Verify that a verified parent successfully passes verify_student_access."""
    mock_db = MagicMock()
    mock_db.execute = AsyncMock()

    student_id = uuid.uuid4()
    section_id = uuid.uuid4()
    parent_user = MagicMock()
    parent_user.id = uuid.uuid4()
    parent_user.email = "parent.verified@example.com"
    parent_user.is_superuser = False
    parent_user.roles = [MagicMock(code="PARENT")]

    # Mock guardian mapping found
    mock_res = MagicMock()
    mock_res.scalar.return_value = 1
    mock_db.execute.return_value = mock_res

    # Should not raise any exception
    await verify_student_access(
        current_user=parent_user,
        student_id=student_id,
        section_id=section_id,
        db=mock_db
    )

@pytest.mark.anyio
async def test_admin_bypass_student_access():
    """Verify that an admin or superuser bypasses parent student guardian link checks."""
    mock_db = MagicMock()
    mock_db.execute = AsyncMock()

    student_id = uuid.uuid4()
    section_id = uuid.uuid4()
    admin_user = MagicMock()
    admin_user.id = uuid.uuid4()
    admin_user.email = "admin@example.com"
    admin_user.is_superuser = True
    admin_user.roles = [MagicMock(code="SUPER_ADMIN")]

    # Should pass without DB guardian query
    await verify_student_access(
        current_user=admin_user,
        student_id=student_id,
        section_id=section_id,
        db=mock_db
    )
    mock_db.execute.assert_not_called()
