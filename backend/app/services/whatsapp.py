import abc
import logging
import uuid
import httpx
from typing import Dict, Any, Optional, List

logger = logging.getLogger(__name__)

class WhatsAppProvider(abc.ABC):
    @abc.abstractmethod
    async def send_message(
        self,
        to_phone: str,
        message: str,
        tenant_id: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Sends a standard text message.
        """
        pass

    @abc.abstractmethod
    async def send_template(
        self,
        to_phone: str,
        template_name: str,
        language_code: str,
        components: List[Dict[str, Any]],
        tenant_id: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Sends a template message (required for Meta API).
        """
        pass

    @abc.abstractmethod
    async def get_delivery_status(
        self,
        provider_message_id: str,
        config: Dict[str, Any]
    ) -> str:
        """
        Retrieves status from the provider.
        """
        pass


class MockWhatsAppProvider(WhatsAppProvider):
    async def send_message(
        self,
        to_phone: str,
        message: str,
        tenant_id: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        logger.info(f"[MOCK WHATSAPP] Sending message to {to_phone}: {message}")
        
        # Test controls based on phone number suffixes
        if to_phone.endswith("999"):
            # Temporary/Retryable failure simulation
            return {
                "provider_message_id": None,
                "status": "FAILED",
                "error_code": "TEMP_TIMEOUT",
                "error_message": "Simulated temporary timeout error for testing.",
                "provider": "mock",
                "is_temporary": True
            }
        elif to_phone.endswith("888"):
            # Permanent failure simulation
            return {
                "provider_message_id": None,
                "status": "FAILED",
                "error_code": "PERM_INVALID_NUMBER",
                "error_message": "Simulated permanent invalid number error for testing.",
                "provider": "mock",
                "is_temporary": False
            }

        return {
            "provider_message_id": f"mock-msg-{uuid.uuid4()}",
            "status": "SENT",
            "provider": "mock"
        }

    async def send_template(
        self,
        to_phone: str,
        template_name: str,
        language_code: str,
        components: List[Dict[str, Any]],
        tenant_id: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        logger.info(f"[MOCK WHATSAPP] Sending template '{template_name}' ({language_code}) to {to_phone}. Components: {components}")
        
        if to_phone.endswith("999"):
            return {
                "provider_message_id": None,
                "status": "FAILED",
                "error_code": "TEMP_TIMEOUT",
                "error_message": "Simulated temporary timeout error for testing.",
                "provider": "mock",
                "is_temporary": True
            }
        elif to_phone.endswith("888"):
            return {
                "provider_message_id": None,
                "status": "FAILED",
                "error_code": "PERM_INVALID_NUMBER",
                "error_message": "Simulated permanent invalid number error for testing.",
                "provider": "mock",
                "is_temporary": False
            }

        return {
            "provider_message_id": f"mock-tpl-{uuid.uuid4()}",
            "status": "SENT",
            "provider": "mock"
        }

    async def get_delivery_status(
        self,
        provider_message_id: str,
        config: Dict[str, Any]
    ) -> str:
        return "DELIVERED"


class MetaWhatsAppProvider(WhatsAppProvider):
    async def send_message(
        self,
        to_phone: str,
        message: str,
        tenant_id: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        api_url = config.get("api_url") or "https://graph.facebook.com/v17.0"
        phone_number_id = config.get("phone_number_id")
        access_token = config.get("access_token")

        if not phone_number_id or not access_token:
            logger.error("[META WHATSAPP] Missing credentials for send_message")
            return {
                "status": "FAILED",
                "error_code": "MISSING_CREDENTIALS",
                "error_message": "WhatsApp phone_number_id or access_token not configured.",
                "provider": "meta",
                "is_temporary": False
            }

        url = f"{api_url}/{phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        # Meta Graph API expects phone number without '+'
        clean_phone = to_phone.replace("+", "")
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": clean_phone,
            "type": "text",
            "text": {
                "body": message
            }
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload, timeout=10.0)
                if response.status_code == 200:
                    resp_data = response.json()
                    msg_id = resp_data.get("messages", [{}])[0].get("id")
                    return {
                        "provider_message_id": msg_id,
                        "status": "SENT",
                        "provider": "meta"
                    }
                else:
                    is_temp = response.status_code >= 500 or response.status_code == 408 or response.status_code == 429
                    return {
                        "status": "FAILED",
                        "error_code": str(response.status_code),
                        "error_message": response.text,
                        "provider": "meta",
                        "is_temporary": is_temp
                    }
        except httpx.RequestError as exc:
            return {
                "status": "FAILED",
                "error_code": "NETWORK_ERROR",
                "error_message": str(exc),
                "provider": "meta",
                "is_temporary": True
            }
        except Exception as exc:
            return {
                "status": "FAILED",
                "error_code": "UNKNOWN_ERROR",
                "error_message": str(exc),
                "provider": "meta",
                "is_temporary": False
            }

    async def send_template(
        self,
        to_phone: str,
        template_name: str,
        language_code: str,
        components: List[Dict[str, Any]],
        tenant_id: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        api_url = config.get("api_url") or "https://graph.facebook.com/v17.0"
        phone_number_id = config.get("phone_number_id")
        access_token = config.get("access_token")

        if not phone_number_id or not access_token:
            logger.error("[META WHATSAPP] Missing credentials for send_template")
            return {
                "status": "FAILED",
                "error_code": "MISSING_CREDENTIALS",
                "error_message": "WhatsApp phone_number_id or access_token not configured.",
                "provider": "meta",
                "is_temporary": False
            }

        url = f"{api_url}/{phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        clean_phone = to_phone.replace("+", "")
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": clean_phone,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {
                    "code": language_code
                },
                "components": components
            }
        }

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, headers=headers, json=payload, timeout=10.0)
                if response.status_code == 200:
                    resp_data = response.json()
                    msg_id = resp_data.get("messages", [{}])[0].get("id")
                    return {
                        "provider_message_id": msg_id,
                        "status": "SENT",
                        "provider": "meta"
                    }
                else:
                    is_temp = response.status_code >= 500 or response.status_code == 408 or response.status_code == 429
                    return {
                        "status": "FAILED",
                        "error_code": str(response.status_code),
                        "error_message": response.text,
                        "provider": "meta",
                        "is_temporary": is_temp
                    }
        except httpx.RequestError as exc:
            return {
                "status": "FAILED",
                "error_code": "NETWORK_ERROR",
                "error_message": str(exc),
                "provider": "meta",
                "is_temporary": True
            }
        except Exception as exc:
            return {
                "status": "FAILED",
                "error_code": "UNKNOWN_ERROR",
                "error_message": str(exc),
                "provider": "meta",
                "is_temporary": False
            }

    async def get_delivery_status(
        self,
        provider_message_id: str,
        config: Dict[str, Any]
    ) -> str:
        # Status checks are typically handled via incoming webhooks.
        # This fallback is a stub returning the current status.
        return "SENT"


def get_whatsapp_provider(provider_name: str) -> WhatsAppProvider:
    if provider_name.lower() == "meta":
        return MetaWhatsAppProvider()
    return MockWhatsAppProvider()
