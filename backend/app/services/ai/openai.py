import json
import logging
import asyncio
from typing import Dict, Any, Optional
import httpx
from fastapi import HTTPException, status
from app.services.ai.interface import AIProvider

logger = logging.getLogger(__name__)

class OpenAIProvider(AIProvider):
    def __init__(
        self,
        api_key: Optional[str],
        model: Optional[str] = None,
        timeout: float = 30.0,
        retries: int = 3
    ) -> None:
        self.api_key = api_key
        self.model = model or "gpt-4o-mini"
        self.timeout = timeout
        self.retries = retries

    def _get_url(self) -> str:
        return "https://api.openai.com/v1/chat/completions"

    async def _request_with_retry(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        if not self.api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="OpenAI API Key is not configured."
            )

        url = self._get_url()
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self.api_key}"
        }
        
        last_exception = None
        for attempt in range(self.retries + 1):
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.post(url, headers=headers, json=payload)
                    
                    if response.status_code == 200:
                        return response.json()
                    
                    logger.warning(
                        f"OpenAI API request failed. Status: {response.status_code}. Response: {response.text}. Attempt {attempt + 1}/{self.retries + 1}"
                    )
                    
                    if response.status_code not in [429, 500, 503]:
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail=f"OpenAI API error (Status {response.status_code}): {response.text}"
                        )
                    
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail=f"OpenAI service unavailable. Status {response.status_code}."
                    )
            except (httpx.RequestError, HTTPException) as e:
                last_exception = e
                if attempt < self.retries:
                    sleep_seconds = 2 ** attempt
                    logger.info(f"Retrying OpenAI call in {sleep_seconds}s...")
                    await asyncio.sleep(sleep_seconds)
                else:
                    break
        
        if isinstance(last_exception, HTTPException):
            raise last_exception
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail=f"OpenAI API timed out or failed to connect: {str(last_exception)}"
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

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature
        }
        
        if max_tokens:
            payload["max_tokens"] = max_tokens

        res_json = await self._request_with_retry(payload)
        
        try:
            choices = res_json.get("choices", [])
            if not choices:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="OpenAI API returned no completion choices."
                )
            text_out = choices[0]["message"]["content"]
            return text_out.strip()
        except KeyError as e:
            logger.error(f"Malformed OpenAI API response: {res_json}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Malformed OpenAI API response payload: Missing key {str(e)}"
            )

    async def generate_json(
        self,
        prompt: str,
        response_schema: Dict[str, Any],
        system_instruction: Optional[str] = None,
        temperature: float = 0.2
    ) -> Dict[str, Any]:
        messages = []
        if system_instruction:
            messages.append({"role": "system", "content": system_instruction})
        
        # Explicit instruction to return JSON
        prompt_structured = f"{prompt}\nReturn JSON strictly matching this schema: {json.dumps(response_schema)}"
        messages.append({"role": "user", "content": prompt_structured})

        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "response_format": {"type": "json_object"}
        }

        res_json = await self._request_with_retry(payload)
        
        try:
            choices = res_json.get("choices", [])
            if not choices:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="OpenAI API returned no choices for JSON completion."
                )
            text_out = choices[0]["message"]["content"]
            return json.loads(text_out.strip())
        except (KeyError, ValueError) as e:
            logger.error(f"Failed to compile or parse OpenAI JSON response: {res_json}", exc_info=True)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to generate structured JSON from OpenAI provider: {str(e)}"
            )
