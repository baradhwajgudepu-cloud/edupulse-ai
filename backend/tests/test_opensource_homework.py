import pytest
import uuid
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import Response, Request, TimeoutException, ConnectError
from fastapi import HTTPException

from app.services.ai.opensource import OpenSourceAIProvider, clean_schema_for_llm, extract_json_payload, redact_secrets
from app.services.ai.service import AIService
from app.services.ai.gemini import GeminiProvider
from app.schemas.teacher_ai import HomeworkGenerationResponse, GeneratedQuestion
from app.api.v1.endpoints.teacher_ai import normalize_homework_response, normalize_questions_response


def test_clean_schema_inlines_pydantic_defs():
    schema = HomeworkGenerationResponse.model_json_schema()
    cleaned = clean_schema_for_llm(schema)
    assert "$defs" not in cleaned
    assert "properties" in cleaned
    assert "questions" in cleaned["properties"]
    assert "items" in cleaned["properties"]["questions"]
    q_props = cleaned["properties"]["questions"]["items"]["properties"]
    assert "text" in q_props
    assert "marks" in q_props
    assert "difficulty" in q_props


def test_extract_json_payload_strips_reasoning_tags():
    raw_with_think = """
    <think>
    Thinking about the physics homework questions for Grade 9.
    Topic: Newton's Laws.
    </think>
    ```json
    {
      "title": "Laws of Motion Homework",
      "description": "Solve the problems based on Newton's Laws.",
      "learning_objective": "Understand F=ma",
      "difficulty": "MEDIUM",
      "estimated_minutes": 25,
      "questions": [
        {"text": "State Newton's first law", "marks": 2, "difficulty": "EASY"}
      ]
    }
    ```
    """
    extracted = extract_json_payload(raw_with_think)
    assert extracted["title"] == "Laws of Motion Homework"
    assert len(extracted["questions"]) == 1


def test_redact_secrets_protects_credentials():
    secret_key = "sk-or-v1-abc123def456ghi789jkl012"
    raw_log = f"Failed to connect using key {secret_key} and Bearer eyJhbGciOiJIUzI1NiJ9.test"
    scrubbed = redact_secrets(raw_log, secret_key)
    assert secret_key not in scrubbed
    assert "[REDACTED_API_KEY]" in scrubbed or "[REDACTED_CREDENTIAL]" in scrubbed


def test_provider_selection_opensource():
    """Verify AI_PROVIDER=opensource selects OpenSourceAIProvider and does not select Gemini."""
    with patch("app.core.settings.settings.AI_PROVIDER", "opensource"), \
         patch("app.core.settings.settings.OPENROUTER_API_KEY", "test_key"), \
         patch("app.core.settings.settings.AI_MODEL", "openrouter/free"):
        service = AIService()
        assert isinstance(service.provider, OpenSourceAIProvider)
        assert not isinstance(service.provider, GeminiProvider)
        assert service.provider.provider_name == "opensource"
        # Verify fallback provider is None (Gemini is NEVER used as fallback)
        assert service.fallback_provider is None


def test_gemini_never_used_as_fallback_for_opensource():
    """Verify that when primary provider is OpenSource, no fallback to Gemini occurs."""
    mock_provider = AsyncMock(spec=OpenSourceAIProvider)
    mock_provider.provider_name = "opensource"
    mock_provider.generate_json.side_effect = HTTPException(status_code=502, detail="AI_UPSTREAM_UNAVAILABLE")

    service = AIService(provider=mock_provider, fallback_provider=None)

    with pytest.raises(HTTPException) as exc_info:
        import asyncio
        asyncio.run(service.generate_json("test prompt", {}, "client_1"))

    assert exc_info.value.status_code == 502
    assert "AI_UPSTREAM_UNAVAILABLE" in exc_info.value.detail
    assert service.fallback_provider is None


def test_five_questions_two_marks_equals_ten_total():
    """Verify that 5 questions with 2 marks each produce total_marks = 10."""
    raw_homework = {
        "title": "Math Fractions",
        "description": "Practice fractions",
        "learning_objective": "Addition of fractions",
        "difficulty": "MEDIUM",
        "estimated_minutes": 20,
        "questions": [
            {"text": "1/2 + 1/4 = ?", "marks": 2, "difficulty": "EASY"},
            {"text": "2/3 + 1/6 = ?", "marks": 2, "difficulty": "EASY"},
            {"text": "3/5 + 2/5 = ?", "marks": 2, "difficulty": "MEDIUM"},
            {"text": "5/8 - 1/4 = ?", "marks": 2, "difficulty": "MEDIUM"},
            {"text": "4/7 + 2/7 = ?", "marks": 2, "difficulty": "HARD"}
        ]
    }

    normalized = normalize_homework_response(
        raw_homework,
        fallback_difficulty="MEDIUM",
        target_marks=10,
        question_count=5
    )

    validated = HomeworkGenerationResponse.model_validate(normalized)
    assert len(validated.questions) == 5
    for q in validated.questions:
        assert q.marks == 2
    assert validated.total_marks == 10
    assert sum(q.marks for q in validated.questions) == 10


def test_normalization_derives_two_marks_when_missing():
    """Verify missing marks default to 2 when 5 questions and 10 marks are requested."""
    raw_homework = {
        "title": "Science Quiz",
        "questions": [
            {"text": "Question 1"},
            {"text": "Question 2"},
            {"text": "Question 3"},
            {"text": "Question 4"},
            {"text": "Question 5"}
        ]
    }

    normalized = normalize_homework_response(
        raw_homework,
        fallback_difficulty="EASY",
        target_marks=10,
        question_count=5
    )

    validated = HomeworkGenerationResponse.model_validate(normalized)
    assert len(validated.questions) == 5
    for q in validated.questions:
        assert q.marks == 2
    assert validated.total_marks == 10


@pytest.mark.anyio
async def test_opensource_missing_config_error():
    with patch("app.core.settings.settings.OPENSOURCE_API_KEY", None), \
         patch("app.core.settings.settings.OPENROUTER_API_KEY", None):
        provider = OpenSourceAIProvider(api_key=None)
        with pytest.raises(HTTPException) as exc_info:
            await provider._request_with_retry({"model": "openrouter/free"})
        assert exc_info.value.status_code == 503
        assert "AI_CONFIGURATION_ERROR" in exc_info.value.detail


@pytest.mark.anyio
async def test_opensource_timeout_error():
    provider = OpenSourceAIProvider(api_key="test_key", retries=0)
    req = Request("POST", "https://openrouter.ai/api/v1/chat/completions")

    with patch("httpx.AsyncClient.post", side_effect=TimeoutException("Connection timed out", request=req)):
        with pytest.raises(HTTPException) as exc_info:
            await provider._request_with_retry({"model": "openrouter/free"})
        assert exc_info.value.status_code == 504
        assert "AI_TIMEOUT" in exc_info.value.detail
