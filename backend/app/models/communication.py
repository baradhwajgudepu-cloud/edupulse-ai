import uuid
import enum
from datetime import datetime
from typing import Optional, List
from sqlalchemy import String, Integer, Boolean, ForeignKey, UniqueConstraint, Enum as SQLEnum, Text, DateTime, text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin

class RequestStatus(str, enum.Enum):
    OPEN = "OPEN"
    ACKNOWLEDGED = "ACKNOWLEDGED"
    IN_PROGRESS = "IN_PROGRESS"
    WAITING_FOR_PARENT = "WAITING_FOR_PARENT"
    ESCALATED = "ESCALATED"
    PRINCIPAL_REVIEW = "PRINCIPAL_REVIEW"
    RESOLVED = "RESOLVED"
    REOPENED = "REOPENED"

class RequestPriority(str, enum.Enum):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    URGENT = "URGENT"

class RequestCategory(str, enum.Enum):
    ATTENDANCE = "ATTENDANCE"
    ACADEMIC = "ACADEMIC"
    FEES = "FEES"
    TRANSPORT = "TRANSPORT"
    LEAVE = "LEAVE"
    EXAMINATION = "EXAMINATION"
    REPORT_CARD = "REPORT_CARD"
    HOMEWORK = "HOMEWORK"
    BEHAVIOUR = "BEHAVIOUR"
    HEALTH = "HEALTH"
    GENERAL = "GENERAL"
    OTHER = "OTHER"

class RecipientType(str, enum.Enum):
    CLASS_TEACHER = "CLASS_TEACHER"
    PRINCIPAL = "PRINCIPAL"
    TEACHER = "TEACHER"
    PARENT = "PARENT"

class Module(str, enum.Enum):
    ATTENDANCE = "ATTENDANCE"
    ACADEMIC = "ACADEMIC"
    FEES = "FEES"
    RESULTS = "RESULTS"
    REPORT_CARD = "REPORT_CARD"
    LEAVE = "LEAVE"
    GENERAL = "GENERAL"

class CommunicationRequest(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a structured communication/request from a parent, teacher, or principal.
    """
    __tablename__ = "communication_requests"

    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    creator_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    assigned_to_id: Mapped[Optional[uuid.UUID]] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    
    recipient_type: Mapped[RecipientType] = mapped_column(
        SQLEnum(RecipientType, name="recipienttype"),
        nullable=False
    )
    category: Mapped[RequestCategory] = mapped_column(
        SQLEnum(RequestCategory, name="requestcategory"),
        nullable=False,
        index=True
    )
    module: Mapped[Optional[Module]] = mapped_column(
        SQLEnum(Module, name="communicationmodule"),
        nullable=True,
        index=True
    )
    
    reference_type: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    reference_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
    subject: Mapped[str] = mapped_column(String(200), nullable=False)
    priority: Mapped[RequestPriority] = mapped_column(
        SQLEnum(RequestPriority, name="requestpriority"),
        nullable=False,
        index=True
    )
    status: Mapped[RequestStatus] = mapped_column(
        SQLEnum(RequestStatus, name="requeststatus"),
        nullable=False,
        default=RequestStatus.OPEN,
        index=True
    )
    
    resolved_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    student = relationship("Student")
    creator = relationship("User", foreign_keys=[creator_id])
    assigned_to = relationship("User", foreign_keys=[assigned_to_id])

    messages: Mapped[List["CommunicationMessage"]] = relationship(
        "CommunicationMessage",
        back_populates="request",
        cascade="all, delete-orphan",
        order_by="CommunicationMessage.created_at.asc()"
    )
    
    participants: Mapped[List["CommunicationParticipant"]] = relationship(
        "CommunicationParticipant",
        back_populates="request",
        cascade="all, delete-orphan"
    )
    
    audit_logs: Mapped[List["CommunicationAuditLog"]] = relationship(
        "CommunicationAuditLog",
        back_populates="request",
        cascade="all, delete-orphan"
    )

    __mapper_args__ = {
        "version_id_col": version
    }

class CommunicationParticipant(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a participant attached to a communication request.
    """
    __tablename__ = "communication_participants"

    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True)
    request_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("communication_requests.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    role: Mapped[str] = mapped_column(String(50), nullable=False) # PARENT, TEACHER, PRINCIPAL
    last_read_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)

    request = relationship("CommunicationRequest", back_populates="participants")
    user = relationship("User")

class CommunicationMessage(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an individual message inside a communication request.
    """
    __tablename__ = "communication_messages"

    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True)
    request_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("communication_requests.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_role: Mapped[str] = mapped_column(String(50), nullable=False) # PARENT, TEACHER, PRINCIPAL
    message: Mapped[str] = mapped_column(Text, nullable=False)

    request = relationship("CommunicationRequest", back_populates="messages")
    sender = relationship("User")
    
    attachments: Mapped[List["CommunicationAttachment"]] = relationship(
        "CommunicationAttachment",
        back_populates="message_obj",
        cascade="all, delete-orphan"
    )

class CommunicationAttachment(Base, BaseModelMixin):
    """
    SQLAlchemy model representing a file attachment associated with a message.
    """
    __tablename__ = "communication_attachments"

    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True)
    message_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("communication_messages.id", ondelete="CASCADE"), nullable=False, index=True)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_type: Mapped[str] = mapped_column(String(100), nullable=False)
    file_size: Mapped[int] = mapped_column(Integer, nullable=False)
    file_url: Mapped[str] = mapped_column(String(500), nullable=False)
    uploaded_by_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    message_obj = relationship("CommunicationMessage", back_populates="attachments")
    uploaded_by = relationship("User")

class CommunicationAuditLog(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an audit log entry for a communication request lifecycle events.
    """
    __tablename__ = "communication_audit_logs"

    tenant_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    school_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True)
    request_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("communication_requests.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False) # CREATE, REPLY, STATUS_CHANGE, ESCALATE, ASSIGN, ATTACHMENT_UPLOAD, REOPEN, RESOLVE
    details: Mapped[str] = mapped_column(Text, nullable=False)

    request = relationship("CommunicationRequest", back_populates="audit_logs")
    user = relationship("User")
