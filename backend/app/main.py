# Monkeypatch email_validator to tolerate .local domains in Pydantic EmailStr validation
import email_validator
from email_validator import validate_email, ValidatedEmail

class PatchedValidatedEmail(ValidatedEmail):
    def __init__(self, original_validated, local_part, domain):
        self.__dict__.update(original_validated.__dict__)
        self._email = f"{local_part}@{domain}"
        self._domain = domain

    @property
    def email(self):
        return self._email

    @property
    def domain(self):
        return self._domain

    @property
    def ascii_email(self):
        return self._email

    @property
    def ascii_domain(self):
        return self._domain

    @property
    def normalized(self):
        return self._email

original_validate = validate_email

def patched_validate_email(email, *args, **kwargs):
    is_local = False
    if isinstance(email, str) and email.lower().endswith(".local"):
        is_local = True
        email_to_validate = email[:-6] + ".com"
    else:
        email_to_validate = email

    try:
        validated = original_validate(email_to_validate, *args, **kwargs)
        if is_local:
            local_part = email.split("@")[0]
            domain = email.split("@")[1]
            return PatchedValidatedEmail(validated, local_part, domain)
        return validated
    except Exception as e:
        raise e

email_validator.validate_email = patched_validate_email

import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi

from app.core.settings import settings
from app.core.logging import setup_logging, logger
from app.api.router import api_router
from app.api.exceptions.handlers import setup_exception_handlers
from app.api.middlewares.logging import RequestLoggingMiddleware
import app.models


async def seed_reports_settings_permissions():
    from app.models.permission import Permission
    from app.models.role import Role
    from sqlalchemy import select
    from app.db.session import AsyncSessionLocal
    import uuid

    new_perms = [
        {"name": "Read Reports", "code": "reports.read", "description": "Allows viewing reports"},
        {"name": "Read Academic Reports", "code": "reports.academic.read", "description": "Allows viewing academic reports"},
        {"name": "Read Attendance Reports", "code": "reports.attendance.read", "description": "Allows viewing attendance reports"},
        {"name": "Read Fees Reports", "code": "reports.fees.read", "description": "Allows viewing fees reports"},
        {"name": "Read AI Reports", "code": "reports.ai.read", "description": "Allows viewing AI reports"},
        {"name": "Export Reports", "code": "reports.export", "description": "Allows exporting reports"},
        {"name": "Read Settings", "code": "settings.read", "description": "Allows viewing settings"},
        {"name": "Update Settings", "code": "settings.update", "description": "Allows updating settings"},
        {"name": "Update School Settings", "code": "settings.school.update", "description": "Allows updating school settings"},
        {"name": "Update Academic Settings", "code": "settings.academic.update", "description": "Allows updating academic settings"},
        {"name": "Update Grading Settings", "code": "settings.grading.update", "description": "Allows updating grading settings"},
        {"name": "Update Exam Settings", "code": "settings.exam.update", "description": "Allows updating exam settings"},
        {"name": "Update Report Card Settings", "code": "settings.report_card.update", "description": "Allows updating report card settings"},
    ]

    async with AsyncSessionLocal() as session:
        try:
            # 1. Insert permissions if they don't exist
            for perm in new_perms:
                stmt = select(Permission).where(Permission.code == perm["code"])
                res = await session.execute(stmt)
                db_perm = res.scalar_one_or_none()
                if not db_perm:
                    db_perm = Permission(id=uuid.uuid4(), name=perm["name"], code=perm["code"], description=perm["description"])
                    session.add(db_perm)
            await session.commit()

            # 2. Map all new permissions to ADMIN roles
            stmt_p = select(Permission).where(Permission.code.in_([p["code"] for p in new_perms]))
            res_p = await session.execute(stmt_p)
            db_perms = list(res_p.scalars().all())

            from sqlalchemy.orm import selectinload
            stmt_r = select(Role).where(Role.code.like("%ADMIN%")).options(selectinload(Role.permissions))
            res_r = await session.execute(stmt_r)
            admin_roles = res_r.scalars().all()

            for role in admin_roles:
                existing_perm_ids = {p.id for p in role.permissions}
                for perm in db_perms:
                    if perm.id not in existing_perm_ids:
                        role.permissions.append(perm)
            await session.commit()
        except Exception as e:
            await session.rollback()
            import logging
            logging.getLogger("uvicorn").error(f"Error seeding reports and settings permissions: {e}")


async def sync_tenant_rbac_permissions():
    from app.models.tenant import Tenant
    from app.services.rbac_provisioning import ensure_tenant_rbac
    from app.db.session import AsyncSessionLocal
    from sqlalchemy import select

    async with AsyncSessionLocal() as session:
        try:
            stmt_t = select(Tenant)
            res_t = await session.execute(stmt_t)
            tenants = res_t.scalars().all()
            for tenant in tenants:
                await ensure_tenant_rbac(session, tenant.id)
            await session.commit()
        except Exception as e:
            await session.rollback()
            import logging
            logging.getLogger("uvicorn").error(f"Error syncing tenant RBAC permissions: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.start_time = time.time()

    setup_logging()

    logger.info("Starting up EduPulse AI backend foundation...")
    try:
        await seed_reports_settings_permissions()
    except Exception as e:
        logger.error(f"Failed to seed reports and settings permissions during startup: {e}")

    try:
        await sync_tenant_rbac_permissions()
    except Exception as e:
        logger.error(f"Failed to sync tenant RBAC permissions during startup: {e}")

    # Start background scheduled notification worker
    from app.db.session import AsyncSessionLocal
    from app.services.notification import run_scheduled_notification_worker
    import asyncio
    app.state.scheduled_worker_task = asyncio.create_task(
        run_scheduled_notification_worker(AsyncSessionLocal)
    )

    yield

    logger.info("Shutting down EduPulse AI backend foundation...")
    if hasattr(app.state, "scheduled_worker_task"):
        app.state.scheduled_worker_task.cancel()
        try:
            await app.state.scheduled_worker_task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend services foundation for the EduPulse AI application.",
    openapi_url="/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)


def custom_openapi():

    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )

    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
        }
    }

    for path in openapi_schema["paths"].values():
        for operation in path.values():
            operation["security"] = [{"BearerAuth": []}]

    app.openapi_schema = openapi_schema

    return app.openapi_schema


app.openapi = custom_openapi


app.add_middleware(RequestLoggingMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[str(origin) for origin in settings.cors_origins_list],
    allow_origin_regex=settings.CORS_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
    allow_headers=["*"],
    expose_headers=[
        "Content-Length",
        "Content-Range",
        "X-Trace-ID",
        "X-Process-Time",
        "x-trace-id",
        "x-process-time",
        "X-Tenant-ID",
        "X-School-ID",
        "Content-Disposition",
    ],
    max_age=86400,
)

setup_exception_handlers(app)

app.include_router(api_router, prefix=settings.API_PREFIX)
# Dev CORS update reload trigger - recycle pool