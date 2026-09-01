import pytest
from fastapi import HTTPException
from app.models.marks import MarksStatus
from app.services.marks import MarksService

def test_marks_state_machine_legal_transitions():
    """Verify that all legal state transitions succeed without error."""
    service = MarksService(None, None, None, None, None, None, None)
    
    # Legal transitions
    legal_pairs = [
        (MarksStatus.DRAFT, MarksStatus.SUBMITTED),
        (MarksStatus.RETURNED, MarksStatus.SUBMITTED),
        (MarksStatus.SUBMITTED, MarksStatus.UNDER_REVIEW),
        (MarksStatus.SUBMITTED, MarksStatus.APPROVED),
        (MarksStatus.SUBMITTED, MarksStatus.RETURNED),
        (MarksStatus.UNDER_REVIEW, MarksStatus.APPROVED),
        (MarksStatus.UNDER_REVIEW, MarksStatus.RETURNED),
        (MarksStatus.APPROVED, MarksStatus.PUBLISHED),
        (MarksStatus.PUBLISHED, MarksStatus.LOCKED),
        # Self transitions for idempotency
        (MarksStatus.DRAFT, MarksStatus.DRAFT),
        (MarksStatus.SUBMITTED, MarksStatus.SUBMITTED),
        (MarksStatus.UNDER_REVIEW, MarksStatus.UNDER_REVIEW),
        (MarksStatus.APPROVED, MarksStatus.APPROVED),
        (MarksStatus.PUBLISHED, MarksStatus.PUBLISHED),
        (MarksStatus.LOCKED, MarksStatus.LOCKED),
    ]
    
    for current_st, target_st in legal_pairs:
        # Should not raise exception
        service._validate_marks_transition(current_st, target_st)

def test_marks_state_machine_illegal_transitions():
    """Verify that all illegal state transitions are rejected with HTTP 422."""
    service = MarksService(None, None, None, None, None, None, None)
    
    illegal_pairs = [
        (MarksStatus.DRAFT, MarksStatus.APPROVED),
        (MarksStatus.DRAFT, MarksStatus.PUBLISHED),
        (MarksStatus.DRAFT, MarksStatus.LOCKED),
        (MarksStatus.RETURNED, MarksStatus.PUBLISHED),
        (MarksStatus.RETURNED, MarksStatus.APPROVED),
        (MarksStatus.RETURNED, MarksStatus.LOCKED),
        (MarksStatus.SUBMITTED, MarksStatus.PUBLISHED),
        (MarksStatus.SUBMITTED, MarksStatus.LOCKED),
        (MarksStatus.UNDER_REVIEW, MarksStatus.PUBLISHED),
        (MarksStatus.UNDER_REVIEW, MarksStatus.LOCKED),
        (MarksStatus.APPROVED, MarksStatus.DRAFT),
        (MarksStatus.APPROVED, MarksStatus.SUBMITTED),
        (MarksStatus.APPROVED, MarksStatus.LOCKED),
        (MarksStatus.PUBLISHED, MarksStatus.DRAFT),
        (MarksStatus.PUBLISHED, MarksStatus.SUBMITTED),
        (MarksStatus.PUBLISHED, MarksStatus.APPROVED),
        (MarksStatus.LOCKED, MarksStatus.DRAFT),
        (MarksStatus.LOCKED, MarksStatus.SUBMITTED),
        (MarksStatus.LOCKED, MarksStatus.APPROVED),
        (MarksStatus.LOCKED, MarksStatus.PUBLISHED),
    ]
    
    for current_st, target_st in illegal_pairs:
        with pytest.raises(HTTPException) as exc_info:
            service._validate_marks_transition(current_st, target_st)
        assert exc_info.value.status_code == 422
        assert "Illegal workflow transition" in exc_info.value.detail
