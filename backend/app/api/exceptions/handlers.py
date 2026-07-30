from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.schemas.response import APIResponse
from app.core.logging import logger

async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Catches all unhandled system exceptions and returns a 500 error within the standard API response structure.
    """
    logger.exception(
        "Unhandled error occurred during request processing",
        path=request.url.path,
        method=request.method,
        error=str(exc)
    )
    
    response_data = APIResponse[None](
        success=False,
        message="Internal server error occurred.",
        data=None
    ).model_dump()
    
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=response_data
    )

async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """
    Formats HTTPExceptions to follow the standard response structure.
    """
    logger.warning(
        "HTTP Exception raised",
        path=request.url.path,
        method=request.method,
        status_code=exc.status_code,
        detail=exc.detail
    )
    
    response_data = APIResponse[None](
        success=False,
        message=str(exc.detail),
        data=None
    ).model_dump()
    
    return JSONResponse(
        status_code=exc.status_code,
        content=response_data
    )

async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    Catches Pydantic RequestValidationErrors and formats them into a clean, human-readable message.
    """
    errors = exc.errors()
    logger.info(
        "Validation failure on request",
        path=request.url.path,
        method=request.method,
        errors=errors
    )
    
    error_msgs = []
    for err in errors:
        # Extract location of error (e.g. body -> name) and message
        loc = " -> ".join(str(l) for l in err.get("loc", []))
        msg = err.get("msg", "Invalid value")
        error_msgs.append(f"[{loc}]: {msg}")
    
    readable_message = "Validation error: " + ("; ".join(error_msgs) if error_msgs else "Invalid input data")
    
    response_data = APIResponse(
        success=False,
        message=readable_message,
        data={"errors": errors}
    ).model_dump()
    
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=response_data
    )

def setup_exception_handlers(app: FastAPI) -> None:
    """
    Binds standard exceptions to custom handlers on the FastAPI app instance.
    """
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, global_exception_handler)
