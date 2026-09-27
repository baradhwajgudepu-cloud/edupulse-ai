import logging
from typing import Dict, Any, Optional
from app.services.ai.opensource import (
    OpenSourceAIProvider,
    clean_schema_for_llm,
    extract_json_payload,
    redact_secrets
)

logger = logging.getLogger(__name__)

# Preserve legacy function reference for existing test suites
_clean_schema = clean_schema_for_llm


class OpenRouterProvider(OpenSourceAIProvider):
    """
    OpenRouter AI Provider acting as an OpenAI-compatible gateway to free open-weight models.
    Inherits all capabilities (schema inlining, reasoning tag stripping, response_format fallback retry)
    directly from OpenSourceAIProvider.
    """
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
        timeout: float = 60.0,
        retries: int = 3
    ) -> None:
        super().__init__(
            api_key=api_key,
            base_url=base_url,
            model=model,
            timeout=timeout,
            retries=retries
        )
        self.provider_name = "openrouter"
