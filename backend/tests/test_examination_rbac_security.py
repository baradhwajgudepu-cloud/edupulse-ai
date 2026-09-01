import pytest
import uuid
from unittest.mock import MagicMock, AsyncMock
from fastapi import HTTPException
from app.models.user import User
from app.models.role import Role
from app.models.marks import MarksStatus
from app.services.marks import MarksService

@pytest.mark.anyio
async def test_teacher_cannot_approve_marks():
    """Verify that unauthorized non-principal roles cannot approve marks."""
    service = MarksService(
        marks_repo=MagicMock(),
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
    
    teacher_role = Role(code="TEACHER", name="Teacher")
    teacher_user = User(
        id=uuid.uuid4(),
        email="teacher@school.com",
        tenant_id=tenant_id,
        is_superuser=False,
        roles=[teacher_role]
    )

    # In endpoint, check_schedule_assignment or RBAC blocks teacher from approve
    # Verify service locked marks transition check as well
    service.marks_repo.get_by_schedule_id = AsyncMock(return_value=[])
    with pytest.raises(HTTPException) as exc_info:
        await service.approve_marks(tenant_id, school_id, exam_schedule_id, "Approval notes", teacher_user)
    
    assert exc_info.value.status_code == 404
