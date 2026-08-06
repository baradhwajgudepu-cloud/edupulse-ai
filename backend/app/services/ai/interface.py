import uuid
from typing import Dict, Any, List, Optional

class AIProvider:
    """
    Interface for AI providers (e.g. Gemini, OpenAI).
    Ensures callers remain decoupling from provider-specific SDK payloads.
    """
    async def generate_text(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None
    ) -> str:
        """
        Generates generic text content based on the prompt.
        """
        raise NotImplementedError("AIProvider subclasses must implement generate_text")

    async def generate_json(
        self,
        prompt: str,
        response_schema: Dict[str, Any],
        system_instruction: Optional[str] = None,
        temperature: float = 0.2
    ) -> Dict[str, Any]:
        """
        Generates structured JSON data conforming to the response_schema.
        """
        raise NotImplementedError("AIProvider subclasses must implement generate_json")
