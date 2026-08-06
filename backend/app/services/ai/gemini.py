import json
import logging
import asyncio
from typing import Dict, Any, Optional
import httpx
from fastapi import HTTPException, status
from app.services.ai.interface import AIProvider

logger = logging.getLogger(__name__)

class GeminiProvider(AIProvider):
    def __init__(
        self,
        api_key: Optional[str],
        model: Optional[str] = None,
        timeout: float = 30.0,
        retries: int = 3
    ) -> None:
        self.api_key = api_key
        self.model = model or "gemini-1.5-flash"
        self.timeout = timeout
        self.retries = retries

    def _get_url(self) -> str:
        return f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent?key={self.api_key}"

    async def _request_with_retry(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Gemini API Key is not configured."
            )

        url = self._get_url()
        headers = {"Content-Type": "application/json"}
        
        last_exception = None
        for attempt in range(self.retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(url, headers=headers, json=payload)
                    
                    if response.status_code == 200:
                        return response.json()
                    
                    logger.warning(
                        f"Gemini API request failed. Status: {response.status_code}. Response: {response.text}. Attempt {attempt + 1}/{self.retries + 1}"
                    )
                    
                    # If rate limited (429) or server error (5xx), we retry; otherwise raise immediately
                    if response.status_code not in [429, 500, 503]:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"Gemini API error (Status {response.status_code}): {response.text}"
                        )
                    
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"Gemini service unavailable. Status {response.status_code}."
                    )
            except (httpx.RequestError, HTTPException) as e:
                last_exception = e
                if attempt < self.retries:
                    sleep_seconds = 2 ** attempt
                    logger.info(f"Retrying Gemini call in {sleep_seconds}s...")
                    await asyncio.sleep(sleep_seconds)
                else:
                    break
        
        if isinstance(last_exception, HTTPException):
            raise last_exception
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"Gemini API timed out or failed to connect: {str(last_exception)}"
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
                    detail="Gemini API returned no completion candidates."
                )
            text_out = candidates[0]["content"]["parts"][0]["text"]
            return text_out.strip()
        except KeyError as e:
            logger.error(f"Malformed Gemini API response: {res_json}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Malformed Gemini API response payload: Missing key {str(e)}"
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
                "responseMimeType": "application/json"
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
                    detail="Gemini API returned no candidates for JSON completion."
                )
            text_out = candidates[0]["content"]["parts"][0]["text"]
            return json.loads(text_out.strip())
        except (KeyError, ValueError) as e:
            logger.error(f"Failed to compile or parse Gemini JSON response: {res_json}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to generate structured JSON from Gemini provider: {str(e)}"
            )
