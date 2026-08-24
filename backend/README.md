# EduPulse AI - Backend Foundation

This is the production-ready backend foundation for **EduPulse AI**, built with **Python 3.14**, **FastAPI**, **SQLAlchemy 2.x (Async/asyncpg)**, **Alembic**, and **Pydantic v2**.

---

## Tech Stack
- **Framework**: [FastAPI](https://fastapi.tiangolo.com/)
- **Database ORM**: [SQLAlchemy 2.x Async](https://docs.sqlalchemy.org/en/20/)
- **Database Driver**: [asyncpg](https://magicstack.github.io/asyncpg/)
- **Settings Management**: [Pydantic Settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- **Structured Logging**: [structlog](https://www.structlog.org/)
- **Migrations**: [Alembic](https://alembic.sqlalchemy.org/)

---

## Folder Structure

```text
backend/
    app/
        api/
            dependencies/    # Shared API dependencies (e.g. pagination, tenants)
            exceptions/      # Custom exceptions and error handlers
            middlewares/     # CORS, structured request logging middleware
            v1/
                endpoints/   # Version 1 API endpoints
            router.py        # Main API router registry
        core/
            settings.py      # App configuration using Pydantic Settings
            security.py      # Placeholders for JWT, Password hashing, RBAC
            logging.py       # Structlog setup (JSON/Console outputs)
            constants.py     # System constants
        db/
            base.py          # SQLAlchemy DeclarativeBase with custom naming conventions
            session.py       # Async engine & sessionmaker config
            mixins.py        # Reusable base mixins (BaseModelMixin, TenantMixin)
        models/              # Database ORM models (empty placeholder)
        schemas/             # Pydantic schemas (empty placeholder)
        repositories/        # Repository pattern interfaces (empty placeholder)
        services/            # Business logic layer (empty placeholder)
        utils/               # System helpers & utilities
        constants/           # Business domain constants
        main.py              # FastAPI entry point & setup
    alembic/                 # Database migrations folder
    tests/                   # Pytest suite
    .env                     # Local environment settings
    .env.example             # Template for environments
    requirements.txt         # Project package requirements
```

---

## Key Features & Standards Implemented

### 1. Database Model Mixins & Automatic Pluralization
- **`BaseModelMixin`**: Automatically injects a UUID primary key, timezone-aware `created_at` / `updated_at`, `deleted_at` (soft delete), and audit columns `created_by` / `updated_by`.
- **`TenantMixin`**: Injects a `tenant_id` column to support multi-tenant isolation.
- **Naming Standards**: The custom `Base` declarative class automatically pluralizes and converts model names from PascalCase to snake_case for PostgreSQL tables (e.g., `AcademicYear` becomes table `academic_years`).

### 2. Standard API Response Wrapper
Every API response (success and error alike) adheres to a standardized structure:
```json
{
    "success": true,
    "message": "Operation successful",
    "data": { ... }
}
```

### 3. Asynchronous Database Architecture
Utilizes `asyncpg` and SQLAlchemy's `AsyncSession` injected via FastAPI `Depends(get_db)`. Database connections and statements run asynchronously to handle high concurrency.

### 4. Structured Production Logging
Configured via `structlog`. Outputs JSON to standard output in production/debug-off mode and colorized, pretty-printed outputs in development.

---

## Getting Started

### Prerequisites
- Python 3.12+ (Optimized for Python 3.14)
- PostgreSQL Database running locally or remotely

### 1. Installation
Create a virtual environment and install dependencies:
```bash
python -m venv venv
venv\Scripts\activate  # On Windows
pip install -r requirements.txt
```

### 2. Run the Application
Start the development server:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
The server will start at `http://0.0.0.0:8000` (accessible locally and on your Wi-Fi network via `http://192.168.31.132:8000`).

### 3. Check System Health
Access the custom health check endpoint at:
`http://127.0.0.1:8000/api/v1/system/health` (or `http://192.168.31.132:8000/api/v1/system/health`)

It verifies:
- API online status and version info.
- System uptime.
- PostgreSQL database ping connectivity.

---

## Database Migrations (Alembic)

To initialize or generate migrations:
```bash
# Generate a migration script
alembic revision --autogenerate -m "Initial schema"

# Upgrade database to latest revision
alembic upgrade head
```

---

## Running Tests
Run tests with `pytest`:
```bash
pytest tests/
```
