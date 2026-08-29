import asyncio
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional
from app.core.settings import settings

logger = logging.getLogger(__name__)

class EmailService:
    """
    Asynchronous email dispatch service with SMTP support and development safety fallbacks.
    """
    def __init__(self):
        self.host = settings.SMTP_HOST
        self.port = settings.SMTP_PORT
        self.username = settings.SMTP_USERNAME
        self.password = settings.SMTP_PASSWORD
        self.from_email = settings.SMTP_FROM_EMAIL
        self.from_name = settings.SMTP_FROM_NAME
        self.use_tls = settings.SMTP_USE_TLS
        self.frontend_base_url = settings.FRONTEND_BASE_URL.rstrip("/")

    @property
    def is_configured(self) -> bool:
        return bool(self.host and self.from_email)

    async def send_password_reset_email(
        self, to_email: str, recipient_name: str, reset_token: str
    ) -> bool:
        """
        Dispatches a secure password reset email with EduPulse AI branding.
        """
        reset_url = f"{self.frontend_base_url}/reset-password?token={reset_token}"
        expire_minutes = settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES

        subject = "EduPulse AI — Password Reset Instructions"

        text_content = f"""Hello {recipient_name},

We received a request to reset your password for your EduPulse AI account.

To choose a new password, please visit the following link:
{reset_url}

This link is valid for {expire_minutes} minutes and can only be used once.

If you did not request this password reset, please ignore this email. Your password will remain unchanged.

Best regards,
The EduPulse AI Team
"""

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>EduPulse AI Password Reset</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; margin: 0; padding: 0; }}
    .container {{ max-width: 580px; margin: 40px auto; background-color: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }}
    .header {{ background-color: #0f172a; padding: 32px 40px; text-align: center; }}
    .header h1 {{ color: #ffffff; margin: 0; font-size: 22px; font-weight: 700; letter-spacing: 0.5px; }}
    .content {{ padding: 40px; }}
    .greeting {{ font-size: 16px; font-weight: 600; color: #0f172a; margin-bottom: 16px; }}
    .message {{ font-size: 15px; line-height: 1.6; color: #475569; margin-bottom: 28px; }}
    .btn-container {{ text-align: center; margin: 32px 0; }}
    .btn {{ display: inline-block; background-color: #2563eb; color: #ffffff !important; font-size: 15px; font-weight: 600; text-decoration: none; padding: 14px 32px; border-radius: 8px; box-shadow: 0 2px 4px rgba(37, 99, 235, 0.2); }}
    .btn:hover {{ background-color: #1d4ed8; }}
    .notice {{ background-color: #f1f5f9; border-left: 4px solid #64748b; padding: 14px 18px; border-radius: 4px; font-size: 13px; color: #475569; line-height: 1.5; margin: 24px 0; }}
    .footer {{ background-color: #f8fafc; padding: 24px 40px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>EduPulse AI</h1>
    </div>
    <div class="content">
      <div class="greeting">Hello {recipient_name},</div>
      <div class="message">
        We received a request to reset your password for your EduPulse AI account. Click the button below to set a new password:
      </div>
      <div class="btn-container">
        <a href="{reset_url}" class="btn" target="_blank">Reset Password</a>
      </div>
      <div class="notice">
        <strong>Security Notice:</strong> This link is valid for <strong>{expire_minutes} minutes</strong> and can only be used once. If you did not make this request, you can safely disregard this email.
      </div>
      <div class="message" style="font-size: 13px; color: #64748b;">
        If the button above does not work, copy and paste this link into your browser:<br>
        <a href="{reset_url}" style="color: #2563eb; word-break: break-all;">{reset_url}</a>
      </div>
    </div>
    <div class="footer">
      &copy; EduPulse AI. Secure Cloud Education Management. All rights reserved.
    </div>
  </div>
</body>
</html>
"""

        return await self._send_email_async(
            to_email=to_email,
            subject=subject,
            text_body=text_content,
            html_body=html_content
        )

    async def _send_email_async(
        self, to_email: str, subject: str, text_body: str, html_body: Optional[str] = None
    ) -> bool:
        """
        Executes asynchronous SMTP dispatch in threadpool executor.
        """
        if not self.is_configured:
            if settings.DEBUG:
                logger.info(
                    f"[EMAIL DISPATCH SIMULATION (DEBUG)] To: {to_email} | Subject: {subject}"
                )
            else:
                logger.warning(
                    f"SMTP is not configured. Email to {to_email} could not be dispatched."
                )
            return True

        loop = asyncio.get_running_loop()
        try:
            return await loop.run_in_executor(
                None, self._send_smtp_sync, to_email, subject, text_body, html_body
            )
        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {str(e)}")
            return False

    def _send_smtp_sync(
        self, to_email: str, subject: str, text_body: str, html_body: Optional[str] = None
    ) -> bool:
        """
        Synchronous SMTP transmission implementation.
        """
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{self.from_name} <{self.from_email}>"
        msg["To"] = to_email

        msg.attach(MIMEText(text_body, "plain", "utf-8"))
        if html_body:
            msg.attach(MIMEText(html_body, "html", "utf-8"))

        server = None
        try:
            if self.port == 465:
                server = smtplib.SMTP_SSL(self.host, self.port, timeout=10)
            else:
                server = smtplib.SMTP(self.host, self.port, timeout=10)
                if self.use_tls:
                    server.starttls()

            if self.username and self.password:
                server.login(self.username, self.password)

            server.sendmail(self.from_email, [to_email], msg.as_string())
            return True
        finally:
            if server:
                try:
                    server.quit()
                except Exception:
                    pass

email_service = EmailService()
