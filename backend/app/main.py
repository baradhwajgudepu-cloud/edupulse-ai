import time
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.settings import settings
from app.core.logging import setup_logging, logger
from app.api.router import api_router
from app.api.exceptions.handlers import setup_exception_handlers
from app.api.middlewares.logging import RequestLoggingMiddleware

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Log starting timestamp for health uptime calculations
    app.state.start_time = time.time()
    
    # Configure structlog
    setup_logging()
    
    logger.info("Starting up EduPulse AI backend foundation...")
    yield
    logger.info("Shutting down EduPulse AI backend foundation...")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend services foundation for the EduPulse AI application.",
    openapi_url=f"{settings.API_PREFIX}/openapi.json",
    docs_url=f"{settings.API_PREFIX}/docs",
    redoc_url=f"{settings.API_PREFIX}/redoc",
    lifespan=lifespan
)

# Request logging middleware
app.add_middleware(RequestLoggingMiddleware)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[str(origin) for origin in settings.CORS_ORIGINS],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Bind standardized exception handlers
setup_exception_handlers(app)

# Include main router registry under the configured prefix
app.include_router(api_router, prefix=settings.API_PREFIX)
