import time
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db

router = APIRouter()

@router.get("/health", status_code=200)
async def system_health_check(request: Request, db: AsyncSession = Depends(get_db)) -> dict:
    """
    Evaluates system metrics, computes API uptime, and verifies PostgreSQL
    connectivity. Returns standard health details.
    """
    timestamp = datetime.now(timezone.utc).isoformat()
    
    # Retrieve start time from app state to calculate uptime
    start_time = getattr(request.app.state, "start_time", None)
    if start_time is not None:
        uptime_seconds = time.time() - start_time
    else:
        uptime_seconds = 0.0
        
    hours = int(uptime_seconds // 3600)
    minutes = int((uptime_seconds % 3600) // 60)
    seconds = int(uptime_seconds % 60)
    uptime_str = f"{hours}h {minutes}m {seconds}s"

    try:
        # Asynchronously verify database availability
        await db.execute(text("SELECT 1"))
        db_status = "healthy"
        status = "healthy"
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"
        status = "degraded"

    return {
        "application": "EduPulse AI",
        "version": "1.0",
        "status": status,
        "database": db_status,
        "uptime": uptime_str,
        "timestamp": timestamp
    }
