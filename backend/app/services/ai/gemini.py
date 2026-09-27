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
    r'(?:AIza[0-9A-Za-z\-_]{35}|key=[0-9A-Za-z\-_]+|Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*)',
    re.IGNORECASE
)

def redact_secrets(text: Any, secret: Optional[str] = None) -> str:
    if not isinstance(text, str):
        text = str(text)
    if secret and len(secret) > 4:
        text = text.replace(secret, "[REDACTED_API_KEY]")
    return _API_KEY_PATTERN.sub("[REDACTED_CREDENTIAL]", text)

def _clean_schema(schema: Dict[str, Any]) -> Dict[str, Any]:
    if not isinstance(schema, dict):
        return schema
    
    cleaned = {}
    allowed_keys = ["type", "description", "properties", "required", "items", "enum"]
    
    for k, v in schema.items():
        if k == "properties" and isinstance(v, dict):
            cleaned[k] = {prop_name: _clean_schema(prop_val) for prop_name, prop_val in v.items()}
        elif k in allowed_keys:
            if isinstance(v, dict):
                cleaned[k] = _clean_schema(v)
            elif isinstance(v, list):
                cleaned[k] = [_clean_schema(item) if isinstance(item, dict) else item for item in v]
            else:
                cleaned[k] = v
                
    return cleaned

class GeminiProvider(AIProvider):
    def __init__(
        self,
        api_key: Optional[str],
        model: Optional[str] = None,
        api_version: Optional[str] = None,
        timeout: float = 30.0,
        retries: int = 3
    ) -> None:
        self.api_key = api_key
        raw_model = model or getattr(settings, "AI_MODEL", "gemini-3.6-flash") or "gemini-3.6-flash"
        self.model = raw_model.replace("models/", "")
        self.api_version = api_version or getattr(settings, "AI_API_VERSION", "v1beta") or "v1beta"
        self.timeout = timeout
        self.retries = retries
        self._model_verified = False

    def _get_url(self) -> str:
        # API key is sent via x-goog-api-key header, NEVER via query parameter
        return f"https://generativelanguage.googleapis.com/{self.api_version}/models/{self.model}:generateContent"

    def _get_capability_url(self) -> str:
        return f"https://generativelanguage.googleapis.com/{self.api_version}/models/{self.model}"

    async def verify_model_support(self, client: Optional[httpx.AsyncClient] = None) -> bool:
        """
        Verify model availability and capability with Google API before execution.
        Caches the verification result on success.
        """
        if self._model_verified:
            return True

        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI_CONFIGURATION_ERROR: Gemini API Key is not configured. Service currently unavailable."
            )

        correlation_id = str(uuid.uuid4())[:8]
        url = self._get_capability_url()
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key
        }

        should_close = False
        if client is None:
            client = httpx.AsyncClient(timeout=10.0)
            should_close = True

        try:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                methods = data.get("supportedGenerationMethods", [])
                if "generateContent" in methods:
                    self._model_verified = True
                    return True
                logger.error(
                    "AI Model capability check failed: provider=gemini model=%s api_version=%s methods=%s correlation_id=%s",
                    self.model, self.api_version, methods, correlation_id
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"AI_MODEL_NOT_AVAILABLE: Gemini model '{self.model}' does not support generateContent for API version '{self.api_version}'. Service currently unavailable."
                )
            elif resp.status_code == 404:
                logger.error(
                    "AI Model not found: provider=gemini model=%s api_version=%s status=404 correlation_id=%s",
                    self.model, self.api_version, correlation_id
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"AI_MODEL_NOT_AVAILABLE: Gemini model '{self.model}' is not found for API version '{self.api_version}'. Service currently unavailable."
                )
            elif resp.status_code in (401, 403):
                logger.error(
                    "AI Authentication error during model check: provider=gemini model=%s status=%d correlation_id=%s",
                    self.model, resp.status_code, correlation_id
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_CONFIGURATION_ERROR: Gemini API key or project credentials unauthorized. Service currently unavailable."
                )
            # For 429 or other upstream status codes during model capability probe, proceed to request attempt
            return True
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(
                "AI Model capability check non-fatal error: %s correlation_id=%s",
                redact_secrets(str(e), self.api_key), correlation_id
            )
            return True
        finally:
            if should_close:
                await client.aclose()

    async def _request_with_retry(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI_CONFIGURATION_ERROR: Gemini API Key is not configured. Service currently unavailable."
            )

        correlation_id = str(uuid.uuid4())[:8]
        url = self._get_url()
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key
        }

        # Validate model support before generation
        await self.verify_model_support()

        last_exception: Optional[Exception] = None
        for attempt in range(self.retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(url, headers=headers, json=payload)

                    if response.status_code == 200:
                        return response.json()

                    logger.warning(
                        "Gemini API non-200 response: provider=gemini model=%s api_version=%s status=%d correlation_id=%s attempt=%d/%d",
                        self.model, self.api_version, response.status_code, correlation_id, attempt + 1, self.retries + 1
                    )

                    error_msg = ""
                    try:
                        err_json = response.json()
                        error_msg = err_json.get("error", {}).get("message", "")
                    except Exception:
                        pass
                    sanitized_reason = redact_secrets(error_msg, self.api_key) if error_msg else f"HTTP {response.status_code}"

                    # 400: Invalid request or schema -> DO NOT RETRY
                    if response.status_code == 400:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_REQUEST_INVALID: Gemini rejected request format: {sanitized_reason}. Service currently unavailable."
                        )

                    # 401/403: Invalid credentials or forbidden -> DO NOT RETRY
                    if response.status_code in (401, 403):
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_CONFIGURATION_ERROR: Gemini authentication failed: {sanitized_reason}. Service currently unavailable."
                        )

                    # 404: Model not found -> DO NOT RETRY
                    if response.status_code == 404:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_MODEL_NOT_AVAILABLE: Gemini model '{self.model}' is not supported or not found: {sanitized_reason}. Service currently unavailable."
                        )

                    # 429: Rate limit or Quota
                    if response.status_code == 429:
                        if "prepayment" in sanitized_reason.lower() or "quota" in sanitized_reason.lower() or "depleted" in sanitized_reason.lower():
                            raise HTTPException(
                                status_code=status.HTTP_502_BAD_GATEWAY,
                                detail=f"AI_QUOTA_EXCEEDED: Gemini quota or prepayment credits depleted: {sanitized_reason}. Service currently unavailable."
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
                                status_code=status.HTTP_502_BAD_GATEWAY,
                                detail=f"AI_QUOTA_EXCEEDED: Gemini rate limit exceeded. Retry after {int(sleep_seconds)}s. Service currently unavailable."
                            )
                        if attempt < self.retries:
                            wait_time = sleep_seconds if sleep_seconds is not None else (2 ** attempt)
                            logger.info("Retrying Gemini 429: wait=%ss attempt=%d/%d correlation_id=%s", wait_time, attempt + 1, self.retries, correlation_id)
                            await asyncio.sleep(wait_time)
                            continue
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_QUOTA_EXCEEDED: Gemini rate limit exceeded: {sanitized_reason}. Service currently unavailable."
                        )

                    # 500, 502, 503, 504: Upstream transient failure -> Bounded exponential backoff
                    if response.status_code in (500, 502, 503, 504):
                        if attempt < self.retries:
                            sleep_seconds = 2 ** attempt
                            logger.info("Retrying Gemini upstream error: status=%d wait=%ss attempt=%d/%d correlation_id=%s", response.status_code, sleep_seconds, attempt + 1, self.retries, correlation_id)
                            await asyncio.sleep(sleep_seconds)
                            continue
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"AI_UPSTREAM_UNAVAILABLE: Gemini service unavailable. Status {response.status_code}. Service currently unavailable."
                        )

                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"AI_UPSTREAM_UNAVAILABLE: Gemini upstream error (Status {response.status_code}): {sanitized_reason}. Service currently unavailable."
                    )

            except HTTPException:
                raise
            except httpx.TimeoutException as e:
                last_exception = e
                logger.warning("Gemini API timeout: attempt=%d/%d correlation_id=%s", attempt + 1, self.retries + 1, correlation_id)
                if attempt < self.retries:
                    await asyncio.sleep(2 ** attempt)
                    continue
                raise HTTPException(
                    status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                    detail="AI_UPSTREAM_UNAVAILABLE: Gemini API request timed out. Service currently unavailable."
                )
            except httpx.RequestError as e:
                last_exception = e
                logger.warning("Gemini network error: attempt=%d/%d correlation_id=%s", attempt + 1, self.retries + 1, correlation_id)
                if attempt < self.retries:
                    await asyncio.sleep(2 ** attempt)
                    continue
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_UPSTREAM_UNAVAILABLE: Network connection to Gemini failed. Service currently unavailable."
                )

        if isinstance(last_exception, HTTPException):
            raise last_exception
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI_UPSTREAM_UNAVAILABLE: Gemini service is currently unavailable."
        )

    async def generate_text(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        payload = {
            "contents": [
                {
                    "parts": [{"text": prompt}]
                }
            ],
            "generationConfig": {
                "temperature": temperature
            }
        }
        
        if system_instruction:
            payload["systemInstruction"] = {
                "parts": [{"text": system_instruction}]
            }
            
        if max_tokens:
            payload["generationConfig"]["maxOutputTokens"] = max_tokens

        res_json = await self._request_with_retry(payload)
        
        try:
            candidates = res_json.get("candidates", [])
            if not candidates:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_UPSTREAM_UNAVAILABLE: Gemini API returned no completion candidates. Service currently unavailable."
                )
            text_out = candidates[0]["content"]["parts"][0]["text"]
            return text_out.strip()
        except KeyError as e:
            logger.error("Malformed Gemini API response: missing key %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI_UPSTREAM_UNAVAILABLE: Malformed Gemini API response payload. Service currently unavailable."
            )

    async def generate_json(
        self,
        prompt: str,
        response_schema: Dict[str, Any],
        system_instruction: Optional[str] = None,
        temperature: float = 0.2
    ) -> Dict[str, Any]:
        payload = {
            "contents": [
                {
                    "parts": [{"text": prompt}]
                }
            ],
            "generationConfig": {
                "temperature": temperature,
                "responseMimeType": "application/json",
                "responseSchema": _clean_schema(response_schema)
            }
        }
        
        if system_instruction:
            payload["systemInstruction"] = {
                "parts": [{"text": system_instruction}]
            }

        res_json = await self._request_with_retry(payload)
        
        try:
            candidates = res_json.get("candidates", [])
            if not candidates:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_UPSTREAM_UNAVAILABLE: Gemini API returned no candidates for JSON completion. Service currently unavailable."
                )
            text_out = candidates[0]["content"]["parts"][0]["text"]
            return json.loads(text_out.strip())
        except (KeyError, ValueError) as e:
            logger.error("Failed to parse Gemini JSON response: %s", str(e))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI_REQUEST_INVALID: Failed to generate valid structured JSON from Gemini provider. Service currently unavailable."
            )
