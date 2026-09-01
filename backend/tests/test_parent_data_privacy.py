import pytest
import uuid
from unittest.mock import MagicMock, AsyncMock
from fastapi import HTTPException
from app.services.marks import MarksService

@pytest.mark.anyio
async def test_parent_unauthorized_student_access_rejected():
    """Verify that a parent attempting to access an unlinked student is rejected."""
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
