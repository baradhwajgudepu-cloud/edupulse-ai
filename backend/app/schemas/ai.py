from typing import Dict, Any, Optional
from pydantic import BaseModel, Field

class AIQueryRequest(BaseModel):
    """
    Schema representing an AI assistant request payload.
    """
    prompt: str = Field(..., min_length=1, description="The user query or context to analyze.")
    system_instruction: Optional[str] = Field(None, description="System persona or directive instructions.")
    temperature: float = Field(0.7, ge=0.0, le=2.0, description="Sampling temperature.")
    max_tokens: Optional[int] = Field(None, gt=0, description="Optional token completion boundary limit.")
    response_schema: Optional[Dict[str, Any]] = Field(None, description="If provided, output will be structured conforming to this JSON schema.")


class AIQueryResponse(BaseModel):
    """
    Schema representing AI generated content.
    """
    text: Optional[str] = Field(None, description="Raw generated text result.")
    structured_data: Optional[Dict[str, Any]] = Field(None, description="Generated structured JSON object, populated if response_schema was passed.")
    provider: str = Field(..., description="The executing AI provider.")
    model: str = Field(..., description="The executing model name.")


class AIConfigResponse(BaseModel):
    """
    Details of active AI service settings.
    """
    provider: str = Field(..., description="Active configured AI provider (e.g. Gemini, OpenAI).")
    model: str = Field(..., description="Active configured model code name.")
    timeout: float = Field(..., description="Configured timeout window limit in seconds.")
    rate_limit: int = Field(..., description="Maximum allowed queries per minute.")
