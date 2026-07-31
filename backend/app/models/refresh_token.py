import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, ForeignKey, Boolean, DateTime, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin

class RefreshToken(Base, BaseModelMixin):
    """
    SQLAlchemy Model representing User Refresh Sessions.
    Stores cryptographically secure hashes of refresh tokens.
    """
    token_hash: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_revoked: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    created_by_ip: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    user: Mapped["User"] = relationship("User")

    version: Mapped[int] = mapped_column(default=1, nullable=False)

    __table_args__ = (
        Index("ix_refresh_tokens_token_hash_revoked", "token_hash", "is_revoked"),
    )

    __mapper_args__ = {
        "version_id_col": version
    }

from app.models.user import User  # noqa: F401
