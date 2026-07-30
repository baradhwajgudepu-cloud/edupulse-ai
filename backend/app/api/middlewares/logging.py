import time
import uuid
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.logging import logger

class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """
    Middleware to intercept incoming requests and log details such as method,
    path, response status, duration, and a trace ID for log correlation.
    """
    async def dispatch(self, request: Request, call_next) -> Response:
        # Generate or capture correlation ID
        trace_id = request.headers.get("X-Trace-ID", str(uuid.uuid4()))
        
        start_time = time.perf_counter()
        
        logger.info(
            "Request started",
            trace_id=trace_id,
            method=request.method,
            path=request.url.path,
            client_host=request.client.host if request.client else None
        )
        
        try:
            response = await call_next(request)
            process_time = time.perf_counter() - start_time
            
            # Attach metadata to headers
            response.headers["X-Trace-ID"] = trace_id
            response.headers["X-Process-Time"] = f"{process_time:.4f}s"
            
            logger.info(
                "Request completed",
                trace_id=trace_id,
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                duration=f"{process_time:.4f}s"
            )
            return response
        except Exception as e:
            process_time = time.perf_counter() - start_time
            logger.error(
                "Request failed",
                trace_id=trace_id,
                method=request.method,
                path=request.url.path,
                duration=f"{process_time:.4f}s",
                error=str(e)
            )
            raise
