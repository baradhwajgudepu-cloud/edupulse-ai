import asyncio
import os
import sys
from logging.config import fileConfig

# Add root folder to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# Import our custom declarative base, models, and settings
from app.db.base import Base
from app.models.tenant import Tenant  # noqa: F401
from app.models.school import School  # noqa: F401
from app.models.academic_year import AcademicYear  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.role import Role  # noqa: F401
from app.models.permission import Permission  # noqa: F401
from app.models.refresh_token import RefreshToken  # noqa: F401
from app.models.class_entity import Class  # noqa: F401
from app.models.section import Section  # noqa: F401
from app.models.student import Student  # noqa: F401
from app.models.guardian import Guardian, StudentGuardian  # noqa: F401
from app.models.teacher import Teacher  # noqa: F401
from app.models.subject import Subject  # noqa: F401
from app.models.teacher_subject_assignment import TeacherSubjectAssignment  # noqa: F401
from app.models.timetable import Timetable  # noqa: F401
from app.models.attendance import AttendanceSession, Attendance  # noqa: F401
from app.models.homework import Homework  # noqa: F401
from app.models.examination import ExamTemplate, Examination, ExamSchedule  # noqa: F401
from app.models.marks import Marks  # noqa: F401
from app.models.report_card import ReportCardPublication  # noqa: F401
from app.models.notification import Notification, NotificationPreference  # noqa: F401
from app.models.fee import (
    FeeType, Scholarship, FeeStructure, FineRule,
    StudentFeeAssignment, FeePayment, FeePaymentAllocation, FeeReceipt
)  # noqa: F401
from app.models.import_job import ImportJob, ImportJobRow, ImportType, ImportJobStatus  # noqa: F401
from app.models.student_import import StudentImportRow  # noqa: F401
from app.models.academic_setup_import import AcademicSetupImportRow  # noqa: F401
from app.models.guardian_import import GuardianImportRow  # noqa: F401
from app.models.student_guardian_import import StudentGuardianImportRow  # noqa: F401
from app.core.settings import settings

# This is the Alembic Config object, which provides access to the .ini file values.
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Metadata object for autogenerate support
target_metadata = Base.metadata

# Inject Settings database URL into Alembic's config (escape percent signs for configparser)
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL.replace("%", "%%"))


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL and not an Engine.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection) -> None:
    """Helper to run migrations inside a connection transaction block."""
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    Uses an async engine and associates a connection with the context.
    """
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
