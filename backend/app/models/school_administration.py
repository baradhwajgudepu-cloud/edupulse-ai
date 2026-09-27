import uuid
import enum
from datetime import date, datetime, timezone
from typing import Optional, List, Dict, Any
from sqlalchemy import (
    String, Integer, Boolean, ForeignKey, UniqueConstraint, Index, Date, DateTime, JSON, Text, Uuid, Enum as SQLEnum, func
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
from app.db.mixins import BaseModelMixin, TenantMixin


class RecognitionAuthorityLevel(str, enum.Enum):
    CENTRAL = "CENTRAL"
    STATE = "STATE"
    OTHER = "OTHER"


class RecognitionType(str, enum.Enum):
    AFFILIATION = "AFFILIATION"
    RECOGNITION = "RECOGNITION"
    NOC = "NOC"
    REGISTRATION = "REGISTRATION"
    OTHER = "OTHER"


class RecognitionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    EXPIRED = "EXPIRED"
    PENDING = "PENDING"
    RENEWAL_IN_PROGRESS = "RENEWAL_IN_PROGRESS"


class UdiseVerificationStatus(str, enum.Enum):
    UNVERIFIED = "UNVERIFIED"
    PENDING_REVIEW = "PENDING_REVIEW"
    VERIFIED = "VERIFIED"
    REJECTED = "REJECTED"


class DocumentCategory(str, enum.Enum):
    GOVERNMENT = "GOVERNMENT"
    RECOGNITION = "RECOGNITION"
    AFFILIATION = "AFFILIATION"
    CERTIFICATE = "CERTIFICATE"
    SCHOOL_REGISTRATION = "SCHOOL_REGISTRATION"
    FIRE_SAFETY = "FIRE_SAFETY"
    BUILDING = "BUILDING"
    TRANSPORT = "TRANSPORT"
    STAFF = "STAFF"
    FINANCIAL = "FINANCIAL"
    OTHER = "OTHER"


class ConfidentialityLevel(str, enum.Enum):
    STANDARD = "STANDARD"
    CONFIDENTIAL = "CONFIDENTIAL"
    HIGHLY_CONFIDENTIAL = "HIGHLY_CONFIDENTIAL"


class DocumentAction(str, enum.Enum):
    VIEW = "VIEW"
    DOWNLOAD = "DOWNLOAD"
    UPLOAD = "UPLOAD"
    REPLACE = "REPLACE"
    ARCHIVE = "ARCHIVE"
    UNLOCK_SUCCESS = "UNLOCK_SUCCESS"
    UNLOCK_FAILED = "UNLOCK_FAILED"
    DELETE = "DELETE"


class ComplianceCategory(str, enum.Enum):
    RTE = "RTE"
    FIRE_SAFETY = "FIRE_SAFETY"
    WATER_SANITATION = "WATER_SANITATION"
    BUILDING_SAFETY = "BUILDING_SAFETY"
    DISABILITY_ACCESS = "DISABILITY_ACCESS"
    LAND_INFRASTRUCTURE = "LAND_INFRASTRUCTURE"
    HEALTH_HYGIENE = "HEALTH_HYGIENE"
    OTHER = "OTHER"


class ComplianceStatus(str, enum.Enum):
    VERIFIED = "VERIFIED"
    PENDING_VERIFICATION = "PENDING_VERIFICATION"
    MISSING_EVIDENCE = "MISSING_EVIDENCE"
    EXPIRING_SOON = "EXPIRING_SOON"
    EXPIRED = "EXPIRED"
    NON_COMPLIANT = "NON_COMPLIANT"
    NOT_APPLICABLE = "NOT_APPLICABLE"


class SchoolProfile(Base, BaseModelMixin, TenantMixin):
    """
    Comprehensive School Profile & Compliance entity.
    1-to-1 extension of School campus.
    """
    __tablename__ = "school_profiles"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
        index=True
    )

    # Basic & Category Details
    school_category: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # e.g., Co-Educational Day School
    management_type: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # e.g., Private Unaided, Model School Society
    school_level: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)     # e.g., Secondary & Senior Secondary
    established_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    medium_of_instruction: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, default="English")
    gender_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="Co-Education")
    minority_status: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, default="Non-Minority")
    area_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="Urban")
    school_photo_url: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    school_motto: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Administration Contacts & Schedule
    correspondent_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    headmaster_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    management_contact: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    emergency_contact: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    school_working_hours: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, default="08:30 AM - 04:00 PM")
    office_working_hours: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, default="09:00 AM - 05:00 PM")
    morning_assembly_time: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="08:45 AM")
    lunch_time: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, default="12:30 PM - 01:15 PM")

    # Infrastructure & Facilities Indicators
    total_capacity: Mapped[int] = mapped_column(Integer, default=1000, server_default="1000", nullable=False)
    current_capacity: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    total_sections_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    has_transport: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_hostel: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_library: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    has_laboratory: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    has_sports_facilities: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    has_smart_classrooms: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_computer_lab: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    has_medical_room: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_cctv: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_fire_safety: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_water_sanitation: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    has_electricity_backup: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    has_accessibility_ramps: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    # UDISE+ Government Compliance & Audit
    udise_status: Mapped[str] = mapped_column(String(50), default="CONFIGURED", server_default="CONFIGURED", nullable=False)
    udise_verification_status: Mapped[UdiseVerificationStatus] = mapped_column(
        SQLEnum(UdiseVerificationStatus, native_enum=False),
        default=UdiseVerificationStatus.UNVERIFIED,
        server_default="UNVERIFIED",
        nullable=False
    )
    udise_verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    udise_verified_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    udise_notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Dynamic custom field values key-value store
    custom_values: Mapped[dict] = mapped_column(JSON, default=dict, server_default="{}", nullable=False)

    # Relationships
    school = relationship("School", backref="profile")
    verified_by_user = relationship("User", foreign_keys=[udise_verified_by])


class SchoolRecognition(Base, BaseModelMixin, TenantMixin):
    """
    Flexible State, Central, and Regulatory Recognition / Affiliation record.
    """
    __tablename__ = "school_recognitions"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    authority_level: Mapped[RecognitionAuthorityLevel] = mapped_column(
        SQLEnum(RecognitionAuthorityLevel, native_enum=False),
        nullable=False
    )
    authority_name: Mapped[str] = mapped_column(String(255), nullable=False)  # e.g., CBSE, Telangana DSE
    recognition_type: Mapped[RecognitionType] = mapped_column(
        SQLEnum(RecognitionType, native_enum=False),
        nullable=False
    )
    recognition_number: Mapped[str] = mapped_column(String(100), nullable=False)
    certificate_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    proceedings_order_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    
    issue_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    valid_from: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    valid_until: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    
    status: Mapped[RecognitionStatus] = mapped_column(
        SQLEnum(RecognitionStatus, native_enum=False),
        default=RecognitionStatus.ACTIVE,
        server_default="ACTIVE",
        nullable=False
    )

    document_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        nullable=True
    )
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    school = relationship("School", backref="recognitions")


class SchoolCustomField(Base, BaseModelMixin, TenantMixin):
    """
    Configurable custom field schema definition per school.
    """
    __tablename__ = "school_custom_fields"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    field_name: Mapped[str] = mapped_column(String(100), nullable=False)
    field_key: Mapped[str] = mapped_column(String(100), nullable=False)
    field_type: Mapped[str] = mapped_column(String(50), nullable=False)  # TEXT, NUMBER, DATE, BOOLEAN, DROPDOWN, PHONE, EMAIL
    field_options: Mapped[Optional[list]] = mapped_column(JSON, default=list, server_default="[]", nullable=True)
    is_required: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    visible_to_principal: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    visible_to_teachers: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    visible_to_parents: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)

    school = relationship("School", backref="custom_fields")

    __table_args__ = (
        UniqueConstraint("school_id", "field_key", name="uq_school_custom_field_key"),
    )


class SchoolDocument(Base, BaseModelMixin, TenantMixin):
    """
    Secure Document Repository for official records and certificates.
    """
    __tablename__ = "school_documents"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    category: Mapped[DocumentCategory] = mapped_column(
        SQLEnum(DocumentCategory, native_enum=False),
        nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    document_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    issuing_authority: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(1024), nullable=False)
    file_size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    content_type: Mapped[str] = mapped_column(String(100), default="application/pdf", nullable=False)
    issue_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    expiry_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    confidentiality_level: Mapped[ConfidentialityLevel] = mapped_column(
        SQLEnum(ConfidentialityLevel, native_enum=False),
        default=ConfidentialityLevel.STANDARD,
        server_default="STANDARD",
        nullable=False
    )

    is_password_protected: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    passcode_salt: Mapped[Optional[str]] = mapped_column(String(64), nullable=True)
    passcode_hash: Mapped[Optional[str]] = mapped_column(String(128), nullable=True)

    is_archived: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    uploaded_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    school = relationship("School", backref="documents")
    uploader = relationship("User", foreign_keys=[uploaded_by])


class DocumentAccessLog(Base, BaseModelMixin, TenantMixin):
    """
    Immutable access audit log for all document interactions.
    """
    __tablename__ = "document_access_logs"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    document_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("school_documents.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    action: Mapped[DocumentAction] = mapped_column(
        SQLEnum(DocumentAction, native_enum=False),
        nullable=False
    )
    ip_address: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    document = relationship("SchoolDocument", backref="access_logs")
    user = relationship("User", foreign_keys=[user_id])


class SchoolComplianceRequirement(Base, BaseModelMixin):
    """
    Standard statutory compliance requirement master catalogue.
    Global/system catalogue defining legal mandates, actionable guidance,
    required documents, and dynamic form schemas.
    """
    __tablename__ = "school_compliance_requirements"

    code: Mapped[str] = mapped_column(String(100), unique=True, nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    category: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    applicable_authority: Mapped[str] = mapped_column(String(255), nullable=False)
    statutory_reference: Mapped[str] = mapped_column(String(255), nullable=False)
    requirement_description: Mapped[str] = mapped_column(Text, nullable=False)
    what_school_must_maintain: Mapped[str] = mapped_column(Text, nullable=False)
    required_documents: Mapped[list] = mapped_column(JSON, default=list, server_default="[]", nullable=False)
    field_schema: Mapped[dict] = mapped_column(JSON, default=dict, server_default="{}", nullable=False)
    default_validity_months: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    renewal_reminder_days: Mapped[int] = mapped_column(Integer, default=60, server_default="60", nullable=False)
    mandatory: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true", nullable=False)


class SchoolComplianceRecord(Base, BaseModelMixin, TenantMixin):
    """
    School-specific compliance status, submissions, and evidence linkage.
    """
    __tablename__ = "school_compliance_records"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    requirement_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("school_compliance_requirements.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    status: Mapped[str] = mapped_column(
        String(50),
        default=ComplianceStatus.MISSING_EVIDENCE.value,
        server_default="MISSING_EVIDENCE",
        nullable=False,
        index=True
    )
    certificate_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    issuing_authority: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    issue_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    expiry_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    last_inspection_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    next_renewal_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)

    primary_document_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("school_documents.id", ondelete="SET NULL"),
        nullable=True
    )
    supporting_document_ids: Mapped[list] = mapped_column(JSON, default=list, server_default="[]", nullable=False)
    photo_evidence_urls: Mapped[list] = mapped_column(JSON, default=list, server_default="[]", nullable=False)
    specific_data: Mapped[dict] = mapped_column(JSON, default=dict, server_default="{}", nullable=False)
    missing_items: Mapped[list] = mapped_column(JSON, default=list, server_default="[]", nullable=False)

    verification_status: Mapped[str] = mapped_column(
        String(50),
        default="UNVERIFIED",
        server_default="UNVERIFIED",
        nullable=False
    )
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    verified_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    verification_notes: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    __table_args__ = (
        UniqueConstraint("school_id", "requirement_id", name="uq_school_compliance_record"),
    )

    requirement = relationship("SchoolComplianceRequirement", backref="records")
    school = relationship("School", backref="compliance_records")
    primary_document = relationship("SchoolDocument", foreign_keys=[primary_document_id])
    verifier = relationship("User", foreign_keys=[verified_by])


class ComplianceAuditLog(Base, BaseModelMixin, TenantMixin):
    """
    Immutable audit trail for compliance submissions, document links, and verification events.
    """
    __tablename__ = "compliance_audit_logs"

    school_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("schools.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    record_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("school_compliance_records.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False)  # CREATED, UPDATED, DOCUMENT_UPLOADED, VERIFIED, REJECTED
    actor_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )
    actor_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    actor_role: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    changes: Mapped[dict] = mapped_column(JSON, default=dict, server_default="{}", nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    record = relationship("SchoolComplianceRecord", backref="audit_logs")
    school = relationship("School")
    actor = relationship("User", foreign_keys=[actor_id])

