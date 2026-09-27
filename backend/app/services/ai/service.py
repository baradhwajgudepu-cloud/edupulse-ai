import time
import uuid
import logging
from collections import defaultdict
from typing import Dict, Any, Optional, Tuple
import httpx
from fastapi import HTTPException, status

from app.core.settings import settings
from app.services.ai.interface import AIProvider
from app.services.ai.opensource import OpenSourceAIProvider
from app.services.ai.openrouter import OpenRouterProvider
from app.services.ai.openai import OpenAIProvider
from app.services.ai.gemini import GeminiProvider

logger = logging.getLogger(__name__)

class TokenBucketRateLimiter:
    """
    In-memory Token Bucket rate limiter scoped per key (User ID or client IP).
    """
    def __init__(self, rate_limit: int, period: float = 60.0) -> None:
        self.rate_limit = rate_limit
        self.period = period
        # Stores (current_tokens, last_recharge_timestamp)
        self.buckets = defaultdict(lambda: (float(rate_limit), time.time()))

    def consume(self, key: str) -> bool:
        if self.rate_limit <= 0:
            return True  # Rate limiting disabled

        now = time.time()
        tokens, last_update = self.buckets[key]
        
        # Calculate tokens to add back since last call
        elapsed = now - last_update
        refill_rate = self.rate_limit / self.period
        recharged_tokens = elapsed * refill_rate
        
        current_tokens = min(float(self.rate_limit), tokens + recharged_tokens)
        
        if current_tokens >= 1.0:
            self.buckets[key] = (current_tokens - 1.0, now)
            return True
        
        self.buckets[key] = (current_tokens, now)
        return False


class AIService:
    """
    Orchestration service routing prompts to configured AI providers with built-in rate-limiting.
    Primary provider is OpenSourceAIProvider (OpenAI-compatible gateway to open-weight models).
    Never initializes or calls Gemini as a fallback.
    """
    def __init__(
        self,
        provider: Optional[AIProvider] = None,
        rate_limiter: Optional[TokenBucketRateLimiter] = None,
        fallback_provider: Optional[AIProvider] = None
    ) -> None:
        if provider:
            self.provider = provider
        else:
            provider_name = settings.AI_PROVIDER.lower()
            if provider_name == "openrouter":
                self.provider = OpenRouterProvider(
                    api_key=getattr(settings, "OPENROUTER_API_KEY", None) or getattr(settings, "OPENSOURCE_API_KEY", None),
                    model=getattr(settings, "OPENROUTER_MODEL", None) or getattr(settings, "OPENSOURCE_MODEL", None) or getattr(settings, "AI_MODEL", "openrouter/free") or "openrouter/free",
                    base_url=getattr(settings, "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
                    timeout=settings.AI_TIMEOUT,
                    retries=settings.AI_RETRIES
                )
            elif provider_name == "opensource":
                self.provider = OpenSourceAIProvider(
                    api_key=getattr(settings, "OPENSOURCE_API_KEY", None) or getattr(settings, "OPENROUTER_API_KEY", None),
                    model=getattr(settings, "OPENSOURCE_MODEL", None) or getattr(settings, "OPENROUTER_MODEL", None) or getattr(settings, "AI_MODEL", "openrouter/free") or "openrouter/free",
                    base_url=getattr(settings, "OPENSOURCE_BASE_URL", None) or getattr(settings, "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1"),
                    timeout=settings.AI_TIMEOUT,
                    retries=settings.AI_RETRIES
                )
            elif provider_name == "openai":
                self.provider = OpenAIProvider(
                    api_key=settings.OPENAI_API_KEY,
                    model=settings.AI_MODEL,
                    timeout=settings.AI_TIMEOUT,
                    retries=settings.AI_RETRIES
                )
            elif provider_name == "gemini":
                # Historical backward compatibility only; never selected in production
                self.provider = GeminiProvider(
                    api_key=settings.GEMINI_API_KEY,
                    model=settings.AI_MODEL,
                    api_version=getattr(settings, "AI_API_VERSION", "v1beta"),
                    timeout=settings.AI_TIMEOUT,
                    retries=settings.AI_RETRIES
                )
            else:
                raise ValueError(f"Unsupported AI Provider configured: '{provider_name}'")

        # Explicit fallback provider: Open-source provider never falls back to Gemini or paid services
        if fallback_provider:
            self.fallback_provider: Optional[AIProvider] = fallback_provider
        else:
            self.fallback_provider = None

        if rate_limiter:
            self.limiter = rate_limiter
        else:
            self.limiter = TokenBucketRateLimiter(
                rate_limit=settings.AI_RATE_LIMIT_PER_MINUTE,
                period=60.0
            )

    def _enforce_rate_limit(self, client_key: str) -> None:
        if not self.limiter.consume(client_key):
            logger.warning("Rate limit exceeded for client key: %s", client_key)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later."
            )

    def _is_transient_or_quota_failure(self, exc: Exception) -> Tuple[bool, str]:
        """
        Determines if an exception qualifies for fallback.
        Never falls back if fallback_provider is None or if primary is already open-source.
        Never falls back to Gemini.
        """
        if self.fallback_provider is None:
            return False, ""
        if isinstance(self.provider, (OpenSourceAIProvider, OpenRouterProvider)):
            return False, ""
        if isinstance(exc, (httpx.TimeoutException, httpx.ConnectError, httpx.NetworkError)):
            return True, "upstream_unavailable_fallback"

        if isinstance(exc, HTTPException):
            if exc.status_code in (
                status.HTTP_400_BAD_REQUEST,
                status.HTTP_401_UNAUTHORIZED,
                status.HTTP_403_FORBIDDEN,
                422
            ):
                return False, ""

            detail_str = str(exc.detail) if exc.detail else ""

            if "AI_REQUEST_INVALID" in detail_str:
                return False, ""
            if "AI_CONFIGURATION_ERROR" in detail_str and ("key" in detail_str.lower() or "unauthorized" in detail_str.lower()):
                return False, ""

            if exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS or "AI_QUOTA_EXCEEDED" in detail_str:
                return True, "quota_fallback"

            lower_detail = detail_str.lower()
            if any(term in lower_detail for term in ["quota", "prepayment", "depleted", "resource_exhausted"]):
                return True, "quota_fallback"

            if exc.status_code in (
                status.HTTP_502_BAD_GATEWAY,
                status.HTTP_503_SERVICE_UNAVAILABLE,
                status.HTTP_504_GATEWAY_TIMEOUT
            ):
                return True, "upstream_unavailable_fallback"
            if "AI_UPSTREAM_UNAVAILABLE" in detail_str or "AI_MODEL_NOT_AVAILABLE" in detail_str:
                return True, "upstream_unavailable_fallback"

        return False, ""

    def _get_provider_name(self, provider: Any) -> str:
        if isinstance(provider, OpenSourceAIProvider):
            return getattr(provider, "provider_name", "opensource")
        elif isinstance(provider, OpenRouterProvider):
            return "openrouter"
        elif isinstance(provider, GeminiProvider):
            return "gemini"
        elif isinstance(provider, OpenAIProvider):
            return "openai"
        return getattr(provider, "provider_name", "unknown")

    def _get_model_name(self, provider: Any) -> str:
        return getattr(provider, "model", "unknown") or "unknown"

    async def generate_text(
        self,
        prompt: str,
        client_key: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        """
        Rate-limited text completions using configured open-source AI provider.
        """
        self._enforce_rate_limit(client_key)
        start_time = time.time()
        primary_provider_name = self._get_provider_name(self.provider)
        primary_model = self._get_model_name(self.provider)

        try:
            result = await self.provider.generate_text(
                prompt=prompt,
                system_instruction=system_instruction,
                temperature=temperature,
                max_tokens=max_tokens
            )
            duration_ms = int((time.time() - start_time) * 1000)
            logger.info(
                "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                primary_provider_name, primary_model, duration_ms, "success"
            )
            return result
        except Exception as exc:
            should_fallback, category = self._is_transient_or_quota_failure(exc)
            if not should_fallback or not self.fallback_provider:
                raise exc

            fb_start = time.time()
            fb_provider_name = self._get_provider_name(self.fallback_provider)
            fb_model_name = self._get_model_name(self.fallback_provider)
            try:
                result = await self.fallback_provider.generate_text(
                    prompt=prompt,
                    system_instruction=system_instruction,
                    temperature=temperature,
                    max_tokens=max_tokens
                )
                duration_ms = int((time.time() - fb_start) * 1000)
                logger.info(
                    "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                    fb_provider_name, fb_model_name, duration_ms, category
                )
                return result
            except HTTPException as fb_exc:
                if fb_exc.status_code == status.HTTP_503_SERVICE_UNAVAILABLE and "AI_CONFIGURATION_ERROR" in str(fb_exc.detail):
                    raise fb_exc
                duration_ms = int((time.time() - fb_start) * 1000)
                logger.error(
                    "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                    fb_provider_name, fb_model_name, duration_ms, "both_failed"
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_SERVICE_UNAVAILABLE: AI analysis service is temporarily unavailable. Please try again later."
                )
            except Exception:
                duration_ms = int((time.time() - fb_start) * 1000)
                logger.error(
                    "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                    fb_provider_name, fb_model_name, duration_ms, "both_failed"
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_SERVICE_UNAVAILABLE: AI analysis service is temporarily unavailable. Please try again later."
                )

    async def generate_json(
        self,
        prompt: str,
        response_schema: Dict[str, Any],
        client_key: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.2
    ) -> Dict[str, Any]:
        """
        Rate-limited structured JSON completions using configured open-source AI provider.
        """
        self._enforce_rate_limit(client_key)
        start_time = time.time()
        primary_provider_name = self._get_provider_name(self.provider)
        primary_model = self._get_model_name(self.provider)

        try:
            result = await self.provider.generate_json(
                prompt=prompt,
                response_schema=response_schema,
                system_instruction=system_instruction,
                temperature=temperature
            )
            duration_ms = int((time.time() - start_time) * 1000)
            logger.info(
                "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                primary_provider_name, primary_model, duration_ms, "success"
            )
            return result
        except Exception as exc:
            should_fallback, category = self._is_transient_or_quota_failure(exc)
            if not should_fallback or not self.fallback_provider:
                raise exc

            fb_start = time.time()
            fb_provider_name = self._get_provider_name(self.fallback_provider)
            fb_model_name = self._get_model_name(self.fallback_provider)
            try:
                result = await self.fallback_provider.generate_json(
                    prompt=prompt,
                    response_schema=response_schema,
                    system_instruction=system_instruction,
                    temperature=temperature
                )
                duration_ms = int((time.time() - fb_start) * 1000)
                logger.info(
                    "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                    fb_provider_name, fb_model_name, duration_ms, category
                )
                return result
            except HTTPException as fb_exc:
                if fb_exc.status_code == status.HTTP_503_SERVICE_UNAVAILABLE and "AI_CONFIGURATION_ERROR" in str(fb_exc.detail):
                    raise fb_exc
                duration_ms = int((time.time() - fb_start) * 1000)
                logger.error(
                    "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                    fb_provider_name, fb_model_name, duration_ms, "both_failed"
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_SERVICE_UNAVAILABLE: AI analysis service is temporarily unavailable. Please try again later."
                )
            except Exception:
                duration_ms = int((time.time() - fb_start) * 1000)
                logger.error(
                    "AI Request Metrics: provider=%s, model=%s, duration_ms=%d, category=%s",
                    fb_provider_name, fb_model_name, duration_ms, "both_failed"
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="AI_SERVICE_UNAVAILABLE: AI analysis service is temporarily unavailable. Please try again later."
                )
