from fastapi import APIRouter, Depends, status, HTTPException
from app.api.dependencies.auth import require_permission, get_current_user
from app.api.dependencies.ai import get_ai_service
from app.services.ai.service import AIService
from app.schemas.ai import AIQueryRequest, AIQueryResponse, AIConfigResponse
from app.schemas.response import APIResponse
from app.models.user import User
from app.core.settings import settings

router = APIRouter()

@router.post(
    "/query",
    response_model=APIResponse[AIQueryResponse],
    status_code=status.HTTP_200_OK,
    summary="Query AI assistant using text prompts or structured schemas"
)
async def query_ai_assistant(
    request: AIQueryRequest,
    current_user: User = Depends(require_permission("ai.use")),
    service: AIService = Depends(get_ai_service)
) -> APIResponse[AIQueryResponse]:
    """
    Exposes direct assistant generation. Scoped per user permission codes and rate-limits.
    Supports text generation or JSON object schema output.
    """
    client_key = str(current_user.id)
    provider_name = settings.AI_PROVIDER
    
    # Resolve running model name
    model_name = settings.AI_MODEL
    if not model_name:
        model_name = service.provider.model

    try:
        if request.response_schema:
            structured = await service.generate_json(
                prompt=request.prompt,
                response_schema=request.response_schema,
                client_key=client_key,
                system_instruction=request.system_instruction,
                temperature=request.temperature
            )
            response_data = AIQueryResponse(
                structured_data=structured,
                provider=provider_name,
                model=model_name
            )
        else:
            txt = await service.generate_text(
                prompt=request.prompt,
                client_key=client_key,
                system_instruction=request.system_instruction,
                temperature=request.temperature,
                max_tokens=request.max_tokens
            )
            response_data = AIQueryResponse(
                text=txt,
                provider=provider_name,
                model=model_name
            )
        
        return APIResponse(
            success=True,
            message="AI response generated successfully.",
            data=response_data
        )
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"An error occurred in the executing AI provider service: {str(e)}"
        )


@router.get(
    "/config",
    response_model=APIResponse[AIConfigResponse],
    status_code=status.HTTP_200_OK,
    summary="Get active AI configurations"
)
async def get_ai_config(
    current_user: User = Depends(get_current_user),
    service: AIService = Depends(get_ai_service)
) -> APIResponse[AIConfigResponse]:
    """
    Returns active configuration metrics. Scoped to authorized active users.
    """
    provider_name = settings.AI_PROVIDER
    model_name = settings.AI_MODEL or service.provider.model
    
    config_data = AIConfigResponse(
        provider=provider_name,
        model=model_name,
        timeout=settings.AI_TIMEOUT,
        rate_limit=settings.AI_RATE_LIMIT_PER_MINUTE
    )
    
    return APIResponse(
        success=True,
        message="AI configurations retrieved successfully.",
        data=config_data
    )
