import json
import uuid
import pytest
import httpx
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient, Response, Request
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.core.settings import settings
from app.services.ai.openrouter import OpenRouterProvider, _clean_schema, extract_json_payload, redact_secrets
from app.services.ai.service import AIService
from app.services.ai.gemini import GeminiProvider
from app.schemas.teacher_ai import HomeworkGenerationResponse, QuestionsGenerationResponse
from app.api.dependencies.auth import get_current_user
from app.api.dependencies.ai import get_ai_service
from tests.test_teacher_ai import setup_teacher_ai_data


# -----------------------------------------------------------------------------
# Unit Tests: Schema Dereferencing & Prompt Sanitization
# -----------------------------------------------------------------------------

def test_openrouter_schema_cleaner_inlines_pydantic_defs() -> None:
    """Ensure Pydantic v2 $defs and $ref are recursively inlined for OpenRouter schemas."""
    schema = HomeworkGenerationResponse.model_json_schema()
    cleaned = _clean_schema(schema)

    # Must strip root $defs / definitions
    assert "$defs" not in cleaned
    assert "definitions" not in cleaned

    # Must have properties
    assert "properties" in cleaned
    questions_prop = cleaned["properties"].get("questions", {})
    assert "items" in questions_prop

    items = questions_prop["items"]
    # $ref must be replaced with the actual definition
    assert "$ref" not in items
    assert "properties" in items
    assert "text" in items["properties"]
    assert "marks" in items["properties"]
    assert "difficulty" in items["properties"]


def test_openrouter_extract_json_payload_with_reasoning_tags() -> None:
    """Verify <think> and <thought> reasoning tokens are cleanly stripped."""
    raw_response = (
        "<think>\n"
        "The user wants 2 multiple choice questions on photosynthesis.\n"
        "Let's prepare the JSON payload.\n"
        "</think>\n"
        "```json\n"
        '{"title": "Photosynthesis", "questions": [{"text": "Where does photosynthesis occur?", "marks": 2}]}\n'
        "```"
    )
    extracted = extract_json_payload(raw_response)
    assert extracted["title"] == "Photosynthesis"
    assert len(extracted["questions"]) == 1
    assert extracted["questions"][0]["marks"] == 2


def test_openrouter_redact_secrets() -> None:
    """Verify that OpenRouter API keys and Bearer tokens are scrubbed from text."""
    secret_key = "sk-or-v1-abcdef1234567890abcdef1234567890"
    log_text = f"Failed call with key {secret_key}"
    redacted = redact_secrets(log_text, secret_key)

    assert secret_key not in redacted
    assert "[REDACTED_API_KEY]" in redacted

    # Test pattern scrubbing for Bearer tokens
    bearer_log = "Authorization: Bearer sk-or-v1-unknownsecret12345678"
    redacted_bearer = redact_secrets(bearer_log)
    assert "unknownsecret" not in redacted_bearer
    assert "[REDACTED_CREDENTIAL]" in redacted_bearer


# -----------------------------------------------------------------------------
# Unit Tests: OpenRouterProvider HTTP Handling & Fallbacks
# -----------------------------------------------------------------------------

@pytest.mark.anyio
async def test_openrouter_generate_json_success() -> None:
    """Verify successful OpenRouter JSON generation with authorization header and model."""
    mock_payload = {
        "id": "gen-123",
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": json.dumps({
                        "title": "Algebra Fundamentals",
                        "description": "Solve for x",
                        "learning_objective": "Linear equations",
                        "difficulty": "EASY",
                        "estimated_minutes": 20,
                        "questions": [
                            {
                                "text": "Solve 2x + 4 = 10",
                                "marks": 5,
                                "difficulty": "EASY",
                                "choices": None,
                                "answer_key": "x = 3"
                            }
                        ]
                    })
                }
            }
        ]
    }

    dummy_key = "sk-or-v1-mocked-key-for-test-only"
    provider = OpenRouterProvider(api_key=dummy_key, model="openrouter/free")

    async def mock_post(url, headers=None, json=None, timeout=None):
        assert headers["Authorization"] == f"Bearer {dummy_key}"
        assert json["model"] == "openrouter/free"
        assert json["response_format"] == {"type": "json_object"}
        return Response(status_code=200, json=mock_payload, request=Request("POST", url))

    with patch("httpx.AsyncClient.post", side_effect=mock_post):
        result = await provider.generate_json(
            prompt="Generate homework on Algebra",
            response_schema=HomeworkGenerationResponse.model_json_schema()
        )
        assert result["title"] == "Algebra Fundamentals"
        assert len(result["questions"]) == 1
        assert result["questions"][0]["marks"] == 5


@pytest.mark.anyio
async def test_openrouter_response_format_400_retry() -> None:
    """Verify fallback retry without response_format when model rejects json_object mode."""
    dummy_key = "sk-or-v1-mocked-key-for-test-only"
    provider = OpenRouterProvider(api_key=dummy_key, model="openrouter/free", retries=1)

    call_count = 0

    async def mock_post(url, headers=None, json=None, timeout=None):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # First attempt: rejected because response_format is unsupported by the free model
            assert "response_format" in json
            return Response(
                status_code=400,
                json={"error": {"message": "'response_format' is not supported by this model"}},
                request=Request("POST", url)
            )
        else:
            # Second attempt: retried without response_format
            assert "response_format" not in json
            return Response(
                status_code=200,
                json={
                    "choices": [
                        {
                            "message": {
                                "role": "assistant",
                                "content": '{"title": "Fallback Success", "description": "Works", "learning_objective": "obj", "difficulty": "EASY", "estimated_minutes": 10, "questions": []}'
                            }
                        }
                    ]
                },
                request=Request("POST", url)
            )

    with patch("httpx.AsyncClient.post", side_effect=mock_post):
        result = await provider.generate_json(
            prompt="Test prompt",
            response_schema=HomeworkGenerationResponse.model_json_schema()
        )
        assert result["title"] == "Fallback Success"
        assert call_count == 2


@pytest.mark.anyio
async def test_openrouter_quota_error_handling() -> None:
    """Verify HTTP 402 / 429 quota exhaustion maps to 502 AI_QUOTA_EXCEEDED."""
    dummy_key = "sk-or-v1-mocked-key-for-test-only"
    provider = OpenRouterProvider(api_key=dummy_key, model="openrouter/free", retries=0)

    async def mock_post_402(url, headers=None, json=None, timeout=None):
        return Response(
            status_code=402,
            json={"error": {"message": "Insufficient credits remaining"}},
            request=Request("POST", url)
        )

    with patch("httpx.AsyncClient.post", side_effect=mock_post_402):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_json("prompt", {})
        assert exc_info.value.status_code == 502
        assert "AI_QUOTA_EXCEEDED" in exc_info.value.detail
        assert dummy_key not in exc_info.value.detail


@pytest.mark.anyio
async def test_openrouter_model_not_found_handling() -> None:
    """Verify HTTP 404 model not found maps to 502 AI_MODEL_NOT_AVAILABLE without retries."""
    dummy_key = "sk-or-v1-mocked-key-for-test-only"
    provider = OpenRouterProvider(api_key=dummy_key, model="nonexistent/model", retries=2)

    async def mock_post_404(url, headers=None, json=None, timeout=None):
        return Response(
            status_code=404,
            json={"error": {"message": "Model not found"}},
            request=Request("POST", url)
        )

    with patch("httpx.AsyncClient.post", side_effect=mock_post_404):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_json("prompt", {})
        assert exc_info.value.status_code == 502
        assert "AI_MODEL_NOT_AVAILABLE" in exc_info.value.detail


@pytest.mark.anyio
async def test_openrouter_timeout_handling() -> None:
    """Verify network timeout raises HTTP 504 with AI_NETWORK_ERROR."""
    dummy_key = "sk-or-v1-mocked-key-for-test-only"
    provider = OpenRouterProvider(api_key=dummy_key, model="openrouter/free", retries=0)

    async def mock_post_timeout(url, headers=None, json=None, timeout=None):
        raise httpx.ReadTimeout("Read timed out", request=Request("POST", url))

    with patch("httpx.AsyncClient.post", side_effect=mock_post_timeout):
        with pytest.raises(HTTPException) as exc_info:
            await provider.generate_json("prompt", {})
        assert exc_info.value.status_code == 504
        assert "AI_NETWORK_ERROR" in exc_info.value.detail


# -----------------------------------------------------------------------------
# Integration / Provider Switching Tests
# -----------------------------------------------------------------------------

def test_gemini_provider_remains_available() -> None:
    """Verify that Gemini provider remains fully configurable and functional when AI_PROVIDER=gemini."""
    with patch("app.core.settings.settings.AI_PROVIDER", "gemini"), \
         patch("app.core.settings.settings.GEMINI_API_KEY", "gemini-secret-test-key"), \
         patch("app.core.settings.settings.AI_MODEL", "gemini-1.5-flash"):
        
        service = AIService()
        assert isinstance(service.provider, GeminiProvider)
        assert service.provider.api_key == "gemini-secret-test-key"
        assert service.provider.model == "gemini-1.5-flash"


def test_openrouter_provider_initialized_as_primary() -> None:
    """Verify that OpenRouterProvider is initialized when AI_PROVIDER=openrouter."""
    with patch("app.core.settings.settings.AI_PROVIDER", "openrouter"), \
         patch("app.core.settings.settings.OPENROUTER_API_KEY", "sk-or-v1-test-key"), \
         patch("app.core.settings.settings.OPENROUTER_MODEL", "openrouter/free"):
        
        service = AIService()
        assert isinstance(service.provider, OpenRouterProvider)
        assert service.provider.api_key == "sk-or-v1-test-key"
        assert service.provider.model == "openrouter/free"


@pytest.mark.anyio
async def test_teacher_generate_homework_endpoint_with_openrouter(client: AsyncClient, setup_teacher_ai_data) -> None:
    """Verify /api/v1/teacher-ai/generate-homework endpoint functions end-to-end with OpenRouter provider."""
    data = setup_teacher_ai_data

    mock_homework_data = {
        "title": "Light and Optics OpenRouter",
        "description": "Read Chapter 4 and solve exercises.",
        "learning_objective": "Understand rays and lenses.",
        "difficulty": "EASY",
        "estimated_minutes": 25,
        "questions": [
            {
                "text": "What is the unit of power of a lens?",
                "marks": 5,
                "difficulty": "EASY",
                "choices": ["Dioptre", "Watt", "Joule", "Meter"],
                "answer_key": "Dioptre"
            }
        ]
    }

    dummy_key = "sk-or-v1-mocked-test-key"
    provider = OpenRouterProvider(api_key=dummy_key, model="openrouter/free")
    provider._request_with_retry = AsyncMock(return_value={
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": json.dumps(mock_homework_data)
                }
            }
        ]
    })

    ai_service = AIService(provider=provider)
    app.dependency_overrides[get_ai_service] = lambda: ai_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(data["subject_sci"].id),
            "topic": "Light and Optics",
            "difficulty": "EASY",
            "number_of_questions": 1,
            "marks": 5
        }
        res = await client.post("/api/v1/teacher-ai/generate-homework", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        json_resp = res.json()
        assert json_resp["success"] is True
        assert json_resp["data"]["title"] == "Light and Optics OpenRouter"
        assert len(json_resp["data"]["questions"]) == 1
        assert json_resp["data"]["questions"][0]["text"] == "What is the unit of power of a lens?"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_teacher_generate_questions_endpoint_with_openrouter(client: AsyncClient, setup_teacher_ai_data) -> None:
    """Verify /api/v1/teacher-ai/generate-questions endpoint functions end-to-end with OpenRouter provider."""
    data = setup_teacher_ai_data

    mock_questions_data = {
        "questions": [
            {
                "text": "Explain the law of conservation of momentum.",
                "marks": 5,
                "difficulty": "MEDIUM",
                "choices": None,
                "answer_key": "Total momentum of an isolated system remains constant."
            }
        ]
    }

    dummy_key = "sk-or-v1-mocked-test-key"
    provider = OpenRouterProvider(api_key=dummy_key, model="openrouter/free")
    provider._request_with_retry = AsyncMock(return_value={
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": json.dumps(mock_questions_data)
                }
            }
        ]
    })

    ai_service = AIService(provider=provider)
    app.dependency_overrides[get_ai_service] = lambda: ai_service
    app.dependency_overrides[get_current_user] = lambda: data["user_t1"]

    try:
        payload = {
            "class_id": str(data["class_8"].id),
            "section_id": str(data["section_a"].id),
            "subject_id": str(data["subject_sci"].id),
            "topic": "Conservation of Momentum",
            "difficulty": "MEDIUM",
            "number_of_questions": 1,
            "marks": 5
        }
        res = await client.post("/api/v1/teacher-ai/generate-questions", json=payload, headers=data["auth_headers_t1"])
        assert res.status_code == 200
        json_resp = res.json()
        assert json_resp["success"] is True
        assert len(json_resp["data"]["questions"]) == 1
        assert "conservation of momentum" in json_resp["data"]["questions"][0]["text"].lower()
    finally:
        app.dependency_overrides.clear()
