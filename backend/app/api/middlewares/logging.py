import time
import uuid
from app.core.logging import logger

class RequestLoggingMiddleware:
    """
    ASGI Middleware to intercept incoming HTTP/WebSocket requests and log details 
    such as method, path, response status, duration, and a trace ID for log correlation.
    """
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            start_time = time.perf_counter()
            
            # Extract headers
            headers_dict = {}
            for k, v in scope.get("headers", []):
                headers_dict[k.lower()] = v
                
            trace_id = headers_dict.get(b"x-trace-id", b"").decode("utf-8")
            if not trace_id:
                trace_id = str(uuid.uuid4())
                
            method = scope.get("method", "GET")
            path = scope.get("path", "")
            
            client = scope.get("client")
            client_host = client[0] if client else None

            # Redact Authorization bearer token in logs for security
            auth_val = headers_dict.get(b"authorization")
            if auth_val:
                logger.info(
                    "Request started",
                    trace_id=trace_id,
                    method=method,
                    path=path,
                    client_host=client_host,
                    authorization="Bearer ***REDACTED***"
                )
            else:
                logger.info(
                    "Request started",
                    trace_id=trace_id,
                    method=method,
                    path=path,
                    client_host=client_host
                )

            status_code = [500]

            async def send_wrapper(message):
                if message["type"] == "http.response.start":
                    status_code[0] = message["status"]
                    process_time = time.perf_counter() - start_time
                    
                    # Convert headers to list of lists to allow mutation
                    headers = list(message.get("headers", []))
                    headers.append((b"x-trace-id", trace_id.encode("utf-8")))
                    headers.append((b"x-process-time", f"{process_time:.4f}s".encode("utf-8")))
                    message["headers"] = headers
                    
                await send(message)

            try:
                await self.app(scope, receive, send_wrapper)
                process_time = time.perf_counter() - start_time
                logger.info(
                    "Request completed",
                    trace_id=trace_id,
                    method=method,
                    path=path,
                    status_code=status_code[0],
                    duration=f"{process_time:.4f}s"
                )
            except Exception as e:
                process_time = time.perf_counter() - start_time
                logger.error(
                    "Request failed",
                    trace_id=trace_id,
                    method=method,
                    path=path,
                    duration=f"{process_time:.4f}s",
                    error=str(e)
                )
                raise
            return

        elif scope["type"] == "websocket":
            start_time = time.perf_counter()
            
            headers_dict = {}
            for k, v in scope.get("headers", []):
                headers_dict[k.lower()] = v
                
            trace_id = headers_dict.get(b"x-trace-id", b"").decode("utf-8")
            if not trace_id:
                trace_id = str(uuid.uuid4())
                
            path = scope.get("path", "")
            client = scope.get("client")
            client_host = client[0] if client else None

            logger.info(
                "WebSocket connection started",
                trace_id=trace_id,
                path=path,
                client_host=client_host
            )

            try:
                await self.app(scope, receive, send)
                process_time = time.perf_counter() - start_time
                logger.info(
                    "WebSocket connection completed",
                    trace_id=trace_id,
                    path=path,
                    duration=f"{process_time:.4f}s"
                )
            except Exception as e:
                process_time = time.perf_counter() - start_time
                logger.error(
                    "WebSocket connection failed",
                    trace_id=trace_id,
                    path=path,
                    duration=f"{process_time:.4f}s",
                    error=str(e)
                )
                raise
            return

        else:
            await self.app(scope, receive, send)
