import os
from typing import List
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from urllib.parse import quote_plus

# Resolve absolute path to the backend folder containing .env files
BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
env_file_path = os.path.join(BACKEND_DIR, ".env")
env_local_file_path = os.path.join(BACKEND_DIR, ".env.local")

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(env_file_path, env_local_file_path),
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )

    PROJECT_NAME: str = "EduPulse AI"
    VERSION: str = "1.0"
    DEBUG: bool = True
    API_PREFIX: str = "/api/v1"

    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://localhost:11500",
        "http://127.0.0.1:11500"
    ]
    EDUPULSE_CORS_ORIGINS: List[str] | None = None

    # Security and JWT configurations
    SECRET_KEY: str = "SUPER_SECRET_KEY_FOR_LOCAL_DEV_CHANGE_IN_PRODUCTION"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080
    ENABLE_BOOTSTRAP: bool = False

    @field_validator("CORS_ORIGINS", "EDUPULSE_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: str | List[str] | None) -> List[str] | None:
        if v is None:
            return None
        if isinstance(v, str):
            import json
            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    return parsed
            except Exception:
                pass
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v

    @property
    def cors_origins_list(self) -> List[str]:
        origins = list(self.CORS_ORIGINS)
        if self.EDUPULSE_CORS_ORIGINS:
            origins.extend(self.EDUPULSE_CORS_ORIGINS)
        return list(dict.fromkeys(origins))

    # PostgreSQL Database settings
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "Gudepu@84"
    POSTGRES_DB: str = "edupulse_db"
    
    DATABASE_URL: str | None = None

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def assemble_db_connection(cls, v: str | None, info) -> str:
        if isinstance(v, str) and v:
            return v
        
        data = info.data
        server = data.get("POSTGRES_SERVER", "localhost")
        port = data.get("POSTGRES_PORT", 5432)
        user = data.get("POSTGRES_USER", "postgres")
        password = quote_plus(data.get("POSTGRES_PASSWORD", "Gudepu@84"))
        db = data.get("POSTGRES_DB", "edupulse_db")
        
        return f"postgresql+asyncpg://{user}:{password}@{server}:{port}/{db}"

    # AI Service Settings
    AI_ENABLED: bool = True
    AI_PROVIDER: str = "gemini"
    GEMINI_API_KEY: str | None = None
    OPENAI_API_KEY: str | None = None
    AI_MODEL: str | None = None
    AI_TIMEOUT: float = 60.0
    AI_RETRIES: int = 3
    AI_RATE_LIMIT_PER_MINUTE: int = 20
    GCS_BUCKET_NAME: str | None = None

    # WhatsApp API configurations
    WHATSAPP_ENABLED: bool = False
    WHATSAPP_PROVIDER: str = "mock"
    WHATSAPP_API_URL: str | None = None
    WHATSAPP_ACCESS_TOKEN: str | None = None
    WHATSAPP_PHONE_NUMBER_ID: str | None = None
    WHATSAPP_BUSINESS_ACCOUNT_ID: str | None = None

    # Super Admin Bootstrap Settings (Values read from environment only; no hardcoded credentials)
    SUPER_ADMIN_EMAIL: str | None = None
    SUPER_ADMIN_INITIAL_PASSWORD: str | None = None
    SUPER_ADMIN_FIRST_NAME: str = "Super"
    SUPER_ADMIN_LAST_NAME: str = "Admin"


    # SMTP & Email Delivery Settings
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_FROM_EMAIL: str = "noreply@edupulse.com"
    SMTP_FROM_NAME: str = "EduPulse AI"
    SMTP_USE_TLS: bool = True

    # Frontend Recovery Settings
    FRONTEND_BASE_URL: str = "https://edupulse-ai-17221.web.app"
    PASSWORD_RESET_TOKEN_EXPIRE_MINUTES: int = 30

    # Password Recovery Rate Limiting Settings
    PASSWORD_RESET_RATE_LIMIT_PER_IP: int = 10
    PASSWORD_RESET_RATE_LIMIT_PER_EMAIL: int = 5
    PASSWORD_RESET_RATE_LIMIT_WINDOW_MINUTES: int = 15
settings = Settings()
