from app.services.ai.service import AIService

# Reused singleton instance to preserve rate limiting token recharge state across HTTP requests
_ai_service_instance = None

def get_ai_service() -> AIService:
    """
    Dependency provider returning the singleton AIService orchestrator.
    """
    global _ai_service_instance
    if _ai_service_instance is None:
        _ai_service_instance = AIService()
    return _ai_service_instance
