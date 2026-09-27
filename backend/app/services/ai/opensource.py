import json
import logging
import asyncio
import re
import uuid
from typing import Dict, Any, Optional
import httpx
from fastapi import HTTPException, status

from app.services.ai.interface import AIProvider
from app.core.settings import settings

logger = logging.getLogger(__name__)

_API_KEY_PATTERN = re.compile(
    r'(?:sk-or-v1-[0-9A-Za-z\-_]+|key=[0-9A-Za-z\-_]+|Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*)',
    re.IGNORECASE
)

def redact_secrets(text: Any, secret: Optional[str] = None) -> str:
    """
    Scrub API keys, tokens, and authorization credentials from logs and error messages.
    """
    if not isinstance(text, str):
        text = str(text)
    if secret and len(secret) > 4:
        text = text.replace(secret, "[REDACTED_API_KEY]")
    return _API_KEY_PATTERN.sub("[REDACTED_CREDENTIAL]", text)


def clean_schema_for_llm(schema: Dict[str, Any], root_defs: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Recursively resolve $ref pointers inline from $defs/definitions so that open-weight
    LLMs receive completely flattened, self-contained property definitions for nested models
    (such as GeneratedQuestion inside HomeworkGenerationResponse).
    """
    if not isinstance(schema, dict):
        return schema

    if root_defs is None:
        root_defs = schema.get("$defs") or schema.get("definitions") or {}

    if "$ref" in schema:
        ref_path = schema["$ref"]
        ref_key = ref_path.split("/")[-1]
        if ref_key in root_defs:
            resolved = dict(root_defs[ref_key])
            return clean_schema_for_llm(resolved, root_defs)

    cleaned = {}
    allowed_keys = ["type", "description", "properties", "required", "items", "enum"]

    for k, v in schema.items():
        if k in ("$defs", "definitions"):
            continue
        elif k == "properties" and isinstance(v, dict):
            cleaned[k] = {prop_name: clean_schema_for_llm(prop_val, root_defs) for prop_name, prop_val in v.items()}
        elif k == "anyOf" and isinstance(v, list):
            non_null = [item for item in v if isinstance(item, dict) and item.get("type") != "null"]
            if len(non_null) == 1:
                cleaned.update(clean_schema_for_llm(non_null[0], root_defs))
            else:
                cleaned[k] = [clean_schema_for_llm(item, root_defs) if isinstance(item, dict) else item for item in v]
        elif k in allowed_keys:
            if isinstance(v, dict):
                cleaned[k] = clean_schema_for_llm(v, root_defs)
            elif isinstance(v, list):
                cleaned[k] = [clean_schema_for_llm(item, root_defs) if isinstance(item, dict) else item for item in v]
            else:
                cleaned[k] = v

    return cleaned


def extract_json_payload(raw_text: str) -> Dict[str, Any]:
    """
    Resiliently extracts and parses JSON from raw model text.
    Strips reasoning tags (<think>...</think>, <thought>...</thought>) only when present,
    strips markdown code blocks, and searches for outer bracket boundaries {...}.
    """
    text = raw_text.strip()

    # Strip reasoning tags emitted by reasoning models (e.g. DeepSeek-R1) only when present
    if "<think>" in text:
        text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    if "<thought>" in text:
        text = re.sub(r'<thought>.*?</thought>', '', text, flags=re.DOTALL).strip()

    # Strip markdown fences if present
    if text.startswith("```"):
        lines = text.split("\n")
        if len(lines) > 1:
            lines = lines[1:]
        if lines and lines[-1].strip().endswith("```"):
            lines[-1] = lines[-1].rstrip("`").strip()
            if not lines[-1]:
                lines.pop()
        text = "\n".join(lines).strip()

    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass

    # Secondary fallback: search for outermost { ... }
    start_idx = text.find("{")
    end_idx = text.rfind("}")
    if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
        extracted = text[start_idx:end_idx + 1]
        try:
            parsed = json.loads(extracted)
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError as decode_err:
            raise ValueError(f"Malformed JSON extracted between braces: {str(decode_err)}")

    raise ValueError("No valid JSON object found in model output")


class OpenSourceAIProvider(AIProvider):
    """
    Open-Source AI Provider using an OpenAI-compatible gateway (e.g. OpenRouter free models,
    vLLM, Ollama, or self-hosted OpenAI-compatible inference servers).
    
    Treats the gateway as an OpenAI-compatible bridge to free open-weight models
    (such as Meta Llama 3, DeepSeek R1, Mistral, Qwen under openrouter/free).
    Never initializes or calls Gemini under any circumstances.
    """
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
        timeout: float = 60.0,
        retries: int = 3
    ) -> None:
        self.api_key = (
            api_key
            or getattr(settings, "OPENSOURCE_API_KEY", None)
            or getattr(settings, "OPENROUTER_API_KEY", None)
        )
        raw_base = (
            base_url
            or getattr(settings, "OPENSOURCE_BASE_URL", None)
            or getattr(settings, "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
        )
        self.base_url = raw_base.rstrip("/")
        self.model = (
            model
            or getattr(settings, "OPENSOURCE_MODEL", None)
            or getattr(settings, "OPENROUTER_MODEL", None)
            or getattr(settings, "AI_MODEL", "openrouter/free")
            or "openrouter/free"
        )
        self.timeout = timeout
        self.retries = retries
        self.provider_name = "opensource"

    def _get_chat_url(self) -> str:
        return f"{self.base_url}/chat/completions"

    async def _request_with_retry(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI_CONFIGURATION_ERROR: Open-source AI provider API key is not configured. Service currently unavailable."
            )

        correlation_id = str(uuid.uuid4())[:8]
        url = self._get_chat_url()
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }

        last_exception: Optional[Exception] = None
        for attempt in range(self.retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(url, headers=headers, json=payload)

                    if response.status_code == 200:
                        return response.json()

                    logger.warning(
                        "Open-source AI gateway non-200 response: model=%s status=%d correlation_id=%s attempt=%d/%d",
                        self.model, response.status_code, correlation_id, attempt + 1, self.retries + 1
                    )

                    error_msg = ""
                    try:
                        err_json = response.json()
                        error_obj = err_json.get("error", {})
                        if isinstance(error_obj, dict):
                            error_msg = error_obj.get("message", "")
                        elif isinstance(error_obj, str):
                            error_msg = error_obj
                    except Exception:
                        error_msg = response.text

                    sanitized_reason = redact_secrets(error_msg, self.api_key) if error_msg else f"HTTP {response.status_code}"

                    # 400: Invalid request or unsupported parameter -> DO NOT RETRY
                    if response.status_code == 400:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_REQUEST_INVALID: Open-source gateway rejected request format: {sanitized_reason}. Service currently unavailable."
                        )

                    # 401: Unauthorized / Invalid API Key -> DO NOT RETRY
                    if response.status_code == 401:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_CONFIGURATION_ERROR: Open-source gateway authentication failed: {sanitized_reason}. Service currently unavailable."
                        )

                    # 402 / 403: Insufficient credits or payment required -> DO NOT RETRY
                    if response.status_code in (402, 403):
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_QUOTA_EXCEEDED: Open-source gateway credits depleted or payment required: {sanitized_reason}. Service currently unavailable."
                        )

                    # 404: Model unavailable or not found -> DO NOT RETRY
                    if response.status_code == 404:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_MODEL_NOT_AVAILABLE: Open-source model '{self.model}' is unavailable or not found: {sanitized_reason}. Service currently unavailable."
                        )

                    # 429: Rate limit
                    if response.status_code == 429:
                        if "credit" in sanitized_reason.lower() or "quota" in sanitized_reason.lower():
                            raise HTTPException(
                                status_code=status.HTTP_502_BAD_GATEWAY,
                                detail=f"AI_QUOTA_EXCEEDED: Open-source provider quota depleted: {sanitized_reason}. Service currently unavailable."
                            )
                        retry_after_str = response.headers.get("Retry-After")
                        sleep_seconds = None
                        if retry_after_str:
                            try:
                                sleep_seconds = float(retry_after_str)
                            except ValueError:
                                pass
                        if sleep_seconds is not None and sleep_seconds > 10.0:
                            raise HTTPException(
                                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                                detail=f"AI_RATE_LIMIT_EXCEEDED: Rate limit exceeded. Retry after {sleep_seconds}s."
                            )
                        if attempt >= self.retries:
                            raise HTTPException(
                                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                                detail=f"AI_RATE_LIMIT_EXCEEDED: Open-source gateway rate limit exceeded: {sanitized_reason}."
                            )

                    # 500 / 502 / 503 / 504 / 520+ Upstream server errors -> retry with exponential backoff
                    if response.status_code in (500, 502, 503, 504, 520, 521, 522, 524):
                        if attempt >= self.retries:
                            raise HTTPException(
                                status_code=status.HTTP_502_BAD_GATEWAY,
                                detail=f"AI_UPSTREAM_UNAVAILABLE: Open-source gateway service error (HTTP {response.status_code}): {sanitized_reason}."
                            )

            except (httpx.TimeoutException, httpx.ConnectError, httpx.ReadError) as net_err:
                last_exception = net_err
                logger.warning(
                    "Open-source gateway connection error: %s (attempt %d/%d) correlation_id=%s",
                    redact_secrets(str(net_err), self.api_key), attempt + 1, self.retries + 1, correlation_id
                )
                if attempt >= self.retries:
                    raise HTTPException(
                        status_code=status.HTTP_504_GATEWAY_TIMEOUT if isinstance(net_err, httpx.TimeoutException) else status.HTTP_502_BAD_GATEWAY,
                        detail=f"AI_TIMEOUT: Open-source API request timed out (AI_NETWORK_ERROR): {redact_secrets(str(net_err), self.api_key)}." if isinstance(net_err, httpx.TimeoutException) else f"AI_UPSTREAM_UNAVAILABLE: Network connection failed (AI_NETWORK_ERROR): {redact_secrets(str(net_err), self.api_key)}."
                    )
            except HTTPException:
                raise
            except Exception as e:
                last_exception = e
                logger.error(
                    "Open-source gateway unhandled exception: %s (attempt %d/%d) correlation_id=%s",
                    redact_secrets(str(e), self.api_key), attempt + 1, self.retries + 1, correlation_id, exc_info=True
                )
                if attempt >= self.retries:
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"AI_UPSTREAM_UNAVAILABLE: Open-source gateway communication failure: {redact_secrets(str(e), self.api_key)}."
                    )

            sleep_duration = min(2.0 ** attempt, 8.0)
            logger.info("Retrying open-source AI request in %.1fs (attempt %d/%d)...", sleep_duration, attempt + 1, self.retries + 1)
            await asyncio.sleep(sleep_duration)

        if isinstance(last_exception, HTTPException):
            raise last_exception
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI_UPSTREAM_UNAVAILABLE: Open-source AI provider service currently unavailable."
        )

    async def generate_text(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        messages = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})
        messages.append({"role": "user", "content": prompt})

        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature
        }
        if max_tokens:
            payload["max_tokens"] = max_tokens

        res_json = await self._request_with_retry(payload)
        choices = res_json.get("choices", [])
        if not choices:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI_RESPONSE_INVALID: Open-source gateway returned no completion choices."
            )
        msg = choices[0].get("message", {})
        content = msg.get("content", "")
        if not content:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI_RESPONSE_INVALID: Open-source gateway returned empty completion text."
            )
        return content.strip()

    async def generate_json(
        self,
        prompt: str,
        response_schema: Dict[str, Any],
        system_instruction: Optional[str] = None,
        temperature: float = 0.2
    ) -> Dict[str, Any]:
        cleaned_schema = clean_schema_for_llm(response_schema)
        schema_json = json.dumps(cleaned_schema)

        instructions = system_instruction or "You are an expert curriculum and assessment designer."
        instructions += (
            f"\n\nCRITICAL OUTPUT REQUIREMENT:\n"
            f"You MUST return ONLY a valid JSON object matching this JSON Schema. "
            f"Do not wrap your output in conversational text, markdown intros, or explanations.\n"
            f"Schema:\n{schema_json}"
        )

        messages = [
            {"role": "system", "content": instructions},
            {"role": "user", "content": prompt}
        ]

        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "response_format": {"type": "json_object"}
        }

        # If targeting OpenRouter with openrouter/free, provide generative open-weight fallback models
        if "openrouter.ai" in self.base_url:
            payload["models"] = [self.model, "nex-agi/nex-n2.5-mini:free"]

        current_payload = payload
        attempts = 0
        max_attempts = 3

        while attempts < max_attempts:
            attempts += 1
            try:
                res_json = await self._request_with_retry(current_payload)
            except HTTPException as http_exc:
                # Free open-weight models routed via OpenRouter may reject response_format: {"type": "json_object"}.
                # Fall back to prompting without response_format and rely on schema instructions and robust JSON extraction.
                detail_str = str(http_exc.detail).lower()
                if "response_format" in detail_str or "json_object" in detail_str or "response format" in detail_str:
                    logger.info("Model '%s' does not support response_format; retrying with prompt instructions only", self.model)
                    current_payload = {k: v for k, v in current_payload.items() if k != "response_format"}
                    res_json = await self._request_with_retry(current_payload)
                else:
                    raise

            choices = res_json.get("choices", [])
            if not choices:
                if attempts < max_attempts:
                    logger.warning("No choices returned on attempt %d; retrying...", attempts)
                    await asyncio.sleep(0.5)
                    continue
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_RESPONSE_INVALID: Open-source gateway returned no completion choices for JSON response."
                )

            msg = choices[0].get("message", {})
            content = msg.get("content", "")
            if not content:
                if attempts < max_attempts:
                    logger.warning("Empty content returned on attempt %d; retrying...", attempts)
                    await asyncio.sleep(0.5)
                    continue
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_RESPONSE_INVALID: Open-source gateway returned empty JSON content."
                )

            try:
                parsed = extract_json_payload(content)
                return parsed
            except Exception as parse_err:
                logger.warning(
                    "Attempt %d/%d failed to parse structured JSON from model response: %s | Raw content: %s",
                    attempts, max_attempts, str(parse_err), redact_secrets(content[:300], self.api_key)
                )
                if attempts < max_attempts:
                    await asyncio.sleep(0.5)
                    continue

                logger.error(
                    "Failed to parse structured JSON from model response: %s | Raw content: %s",
                    str(parse_err), redact_secrets(content[:500], self.api_key), exc_info=True
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"AI_RESPONSE_INVALID: Model returned malformed output: {str(parse_err)}"
                )
