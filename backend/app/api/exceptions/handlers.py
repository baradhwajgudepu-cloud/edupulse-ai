from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.schemas.response import APIResponse
from app.core.logging import logger

def _inject_cors_headers(request: Request, response: JSONResponse) -> None:
    """
    Ensures error responses (4xx, 5xx) retain CORS headers for allowed origins,
    preventing browsers from obscuring server errors with CORS network errors.
    """
    origin = request.headers.get("origin")
    if not origin:
        return
    import re
    from app.core.settings import settings
    is_allowed = False
    if origin in settings.cors_origins_list:
        is_allowed = True
    elif settings.CORS_ORIGIN_REGEX and re.match(settings.CORS_ORIGIN_REGEX, origin):
        is_allowed = True

    if is_allowed:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Expose-Headers"] = (
            "Content-Length, Content-Range, X-Trace-ID, X-Process-Time, "
            "x-trace-id, x-process-time, X-Tenant-ID, X-School-ID, Content-Disposition"
        )


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
    
    response = JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=response_data
    )
    _inject_cors_headers(request, response)
    return response

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
    
    response = JSONResponse(
        status_code=exc.status_code,
        content=response_data
    )
    _inject_cors_headers(request, response)
    return response

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
    
    # Sanitize errors to ensure they are JSON-serializable (Pydantic v2 custom validators include raw ValueError exceptions in ctx)
    sanitized_errors = []
    for err in errors:
        sanitized_err = err.copy()
        if "ctx" in sanitized_err and isinstance(sanitized_err["ctx"], dict):
            ctx_clean = {}
            for k, v in sanitized_err["ctx"].items():
                if isinstance(v, Exception):
                    ctx_clean[k] = str(v)
                else:
                    ctx_clean[k] = v
            sanitized_err["ctx"] = ctx_clean
        sanitized_errors.append(sanitized_err)
    
    response_data = APIResponse(
        success=False,
        message=readable_message,
        data={"errors": sanitized_errors}
    ).model_dump()
    
    response = JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=response_data
    )
    _inject_cors_headers(request, response)
    return response

def setup_exception_handlers(app: FastAPI) -> None:
    """
    Binds standard exceptions to custom handlers on the FastAPI app instance.
    """
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, global_exception_handler)
    app.add_exception_handler(status.HTTP_500_INTERNAL_SERVER_ERROR, global_exception_handler)

