import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.settings import settings
from app.services.email import email_service

print("=== EMAIL / SMTP CONFIGURATION ===")
print(f"SMTP_HOST:         {settings.SMTP_HOST}")
print(f"SMTP_PORT:         {settings.SMTP_PORT}")
print(f"SMTP_USERNAME:     {settings.SMTP_USERNAME}")
print(f"SMTP_PASSWORD:     {'***MASKED***' if settings.SMTP_PASSWORD else None}")
print(f"SMTP_FROM_EMAIL:   {settings.SMTP_FROM_EMAIL}")
print(f"SMTP_FROM_NAME:    {settings.SMTP_FROM_NAME}")
print(f"SMTP_USE_TLS:      {settings.SMTP_USE_TLS}")
print(f"DEBUG Mode:        {settings.DEBUG}")
print(f"is_configured:     {email_service.is_configured}")

print("\n=== FRONTEND URL CONFIGURATION ===")
print(f"FRONTEND_BASE_URL: {settings.FRONTEND_BASE_URL}")
print(f"Email service base:{email_service.frontend_base_url}")

sample_token = "SAMPLE_SECURITY_TOKEN_123"
sample_reset_url = f"{email_service.frontend_base_url}/reset-password?token={sample_token}"
print(f"Sample Reset URL:  {sample_reset_url}")
