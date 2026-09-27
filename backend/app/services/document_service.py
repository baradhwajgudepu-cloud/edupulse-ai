import os
import uuid
import hmac
import hashlib
import secrets
import time
from datetime import date, datetime, timedelta, timezone
from typing import Optional, Tuple, List, Dict, Any
from sqlalchemy import select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.settings import settings
from app.models.school_administration import (
    SchoolDocument, DocumentAccessLog, DocumentCategory, ConfidentialityLevel, DocumentAction
)
from app.schemas.school_administration import (
    DocumentExpiryAlert, DocumentExpiryMonitorResponse
)
from app.services.storage import get_storage_service


TOKEN_SECRET = getattr(settings, "SECRET_KEY", "edupulse-super-secret-doc-vault-key-2026")
UNLOCK_TOKEN_TTL_SECONDS = 900  # 15 minutes


class DocumentService:
    """
    Secure Document Management Service.
    Enforces PBKDF2-SHA256 salted hashing for protected files,
    time-limited HMAC unlock tokens, access audit logging, and AI expiry monitoring.
    """

    @staticmethod
    def hash_passcode(passcode: str, salt: Optional[str] = None) -> Tuple[str, str]:
        if not salt:
            salt = secrets.token_hex(16)
        key = hashlib.pbkdf2_hmac(
            'sha256',
            passcode.encode('utf-8'),
            salt.encode('utf-8'),
            100000
        )
        return salt, key.hex()

    @classmethod
    def verify_passcode(cls, passcode: str, salt: str, expected_hash: str) -> bool:
        _, computed = cls.hash_passcode(passcode, salt)
        return hmac.compare_digest(computed, expected_hash)

    @staticmethod
    def generate_unlock_token(document_id: uuid.UUID, user_id: Optional[uuid.UUID] = None) -> str:
        expiry = int(time.time()) + UNLOCK_TOKEN_TTL_SECONDS
        payload = f"{document_id}:{user_id or 'anon'}:{expiry}"
        sig = hmac.new(TOKEN_SECRET.encode(), payload.encode(), hashlib.sha256).hexdigest()
        return f"{payload}:{sig}"

    @staticmethod
    def verify_unlock_token(token: str, document_id: uuid.UUID) -> bool:
        try:
            parts = token.split(":")
            if len(parts) != 4:
                return False
            token_doc_id_str, user_id_str, expiry_str, sig = parts
            if token_doc_id_str != str(document_id):
                return False
            if int(expiry_str) < int(time.time()):
                return False
            payload = f"{token_doc_id_str}:{user_id_str}:{expiry_str}"
            expected_sig = hmac.new(TOKEN_SECRET.encode(), payload.encode(), hashlib.sha256).hexdigest()
            return hmac.compare_digest(sig, expected_sig)
        except Exception:
            return False

    @staticmethod
    async def log_access(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        document_id: uuid.UUID,
        action: DocumentAction,
        user_id: Optional[uuid.UUID] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> DocumentAccessLog:
        log_entry = DocumentAccessLog(
            tenant_id=tenant_id,
            school_id=school_id,
            document_id=document_id,
            user_id=user_id,
            action=action,
            ip_address=ip_address,
            user_agent=user_agent
        )
        db.add(log_entry)
        await db.flush()
        return log_entry

    @classmethod
    async def monitor_document_expiries(
        cls,
        db: AsyncSession,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID
    ) -> DocumentExpiryMonitorResponse:
        """
        AI Document Expiry Monitoring:
        Scans all active school documents, calculates days remaining,
        identifies expiring or expired documents, and checks mandatory compliance categories.
        """
        today = date.today()
        stmt = select(SchoolDocument).where(
            SchoolDocument.tenant_id == tenant_id,
            SchoolDocument.school_id == school_id,
            SchoolDocument.is_archived == False,
            SchoolDocument.deleted_at.is_(None)
        )
        docs = list((await db.execute(stmt)).scalars().all())

        alerts: List[DocumentExpiryAlert] = []
        expiring_count = 0
        expired_count = 0

        categories_present = set()
        for doc in docs:
            categories_present.add(doc.category)
            if doc.expiry_date:
                days_left = (doc.expiry_date - today).days
                if days_left < 0:
                    expired_count += 1
                    alerts.append(
                        DocumentExpiryAlert(
                            document_id=doc.id,
                            title=doc.title,
                            category=doc.category,
                            document_number=doc.document_number,
                            expiry_date=doc.expiry_date,
                            days_remaining=days_left,
                            is_expired=True,
                            recommended_action=f"Urgent: Certificate expired {abs(days_left)} days ago. Request immediate renewal from issuing authority."
                        )
                    )
                elif days_left <= 60:
                    expiring_count += 1
                    alerts.append(
                        DocumentExpiryAlert(
                            document_id=doc.id,
                            title=doc.title,
                            category=doc.category,
                            document_number=doc.document_number,
                            expiry_date=doc.expiry_date,
                            days_remaining=days_left,
                            is_expired=False,
                            recommended_action=f"Warning: Document expires in {days_left} days. Prepare renewal application and dispatch to inspection board."
                        )
                    )

        # Check mandatory regulatory categories
        mandatory_categories = [
            (DocumentCategory.FIRE_SAFETY, "Fire Safety No Objection Certificate (NOC)"),
            (DocumentCategory.BUILDING, "Building Structural Safety & Fitness Certificate"),
            (DocumentCategory.GOVERNMENT, "School Government Recognition / UDISE+ Certificate"),
            (DocumentCategory.AFFILIATION, "Board Affiliation Order")
        ]
        missing_mandatory = []
        for cat_enum, cat_label in mandatory_categories:
            if cat_enum not in categories_present:
                missing_mandatory.append(cat_label)

        # Sort alerts: expired first, then ascending days remaining
        alerts.sort(key=lambda a: a.days_remaining)

        return DocumentExpiryMonitorResponse(
            total_monitored=len(docs),
            expiring_soon_count=expiring_count,
            expired_count=expired_count,
            alerts=alerts,
            missing_mandatory_categories=missing_mandatory
        )
