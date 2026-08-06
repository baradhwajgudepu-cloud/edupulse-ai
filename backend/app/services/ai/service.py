import time
import uuid
import logging
from collections import defaultdict
from typing import Dict, Any, Optional
from fastapi import HTTPException, status

from app.core.settings import settings
from app.services.ai.interface import AIProvider
from app.services.ai.gemini import GeminiProvider
from app.services.ai.openai import OpenAIProvider

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
    """
    def __init__(
        self,
        provider: Optional[AIProvider] = None,
        rate_limiter: Optional[TokenBucketRateLimiter] = None
    ) -> None:
        if provider:
            self.provider = provider
        else:
            provider_name = settings.AI_PROVIDER.lower()
            if provider_name == "openai":
                self.provider = OpenAIProvider(
                    api_key=settings.OPENAI_API_KEY,
                    model=settings.AI_MODEL,
                    timeout=settings.AI_TIMEOUT,
                    retries=settings.AI_RETRIES
                )
            elif provider_name == "gemini":
                self.provider = GeminiProvider(
                    api_key=settings.GEMINI_API_KEY,
                    model=settings.AI_MODEL,
                    timeout=settings.AI_TIMEOUT,
                    retries=settings.AI_RETRIES
                )
            else:
                raise ValueError(f"Unsupported AI Provider configured: '{provider_name}'")

        if rate_limiter:
            self.limiter = rate_limiter
        else:
            self.limiter = TokenBucketRateLimiter(
                rate_limit=settings.AI_RATE_LIMIT_PER_MINUTE,
                period=60.0
            )

    def _enforce_rate_limit(self, client_key: str) -> None:
        if not self.limiter.consume(client_key):
            logger.warning(f"Rate limit exceeded for client key: {client_key}")
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded. Please try again later."
            )

    async def generate_text(
        self,
        prompt: str,
        client_key: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        """
        Rate-limited proxy generating text completions from the configured AI provider.
        """
        self._enforce_rate_limit(client_key)
        return await self.provider.generate_text(
            prompt=prompt,
            system_instruction=system_instruction,
            temperature=temperature,
            max_tokens=max_tokens
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
        Rate-limited proxy generating structured JSON schema completions from the configured AI provider.
        """
        self._enforce_rate_limit(client_key)
        return await self.provider.generate_json(
            prompt=prompt,
            response_schema=response_schema,
            system_instruction=system_instruction,
            temperature=temperature
        )
