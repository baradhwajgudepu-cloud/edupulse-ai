import uuid
from datetime import date, datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from app.models.school_administration import (
    RecognitionAuthorityLevel, RecognitionType, RecognitionStatus,
    UdiseVerificationStatus, DocumentCategory, ConfidentialityLevel, DocumentAction,
    ComplianceCategory, ComplianceStatus
)


class SchoolProfileBase(BaseModel):
    school_category: Optional[str] = None
    management_type: Optional[str] = None
    school_level: Optional[str] = None
    established_year: Optional[int] = None
    medium_of_instruction: Optional[str] = "English"
    gender_type: Optional[str] = "Co-Education"
    minority_status: Optional[str] = "Non-Minority"
    area_type: Optional[str] = "Urban"
    school_photo_url: Optional[str] = None
    school_motto: Optional[str] = None

    correspondent_name: Optional[str] = None
    headmaster_name: Optional[str] = None
    management_contact: Optional[str] = None
    emergency_contact: Optional[str] = None
    school_working_hours: Optional[str] = "08:30 AM - 04:00 PM"
    office_working_hours: Optional[str] = "09:00 AM - 05:00 PM"
    morning_assembly_time: Optional[str] = "08:45 AM"
    lunch_time: Optional[str] = "12:30 PM - 01:15 PM"

    total_capacity: int = 1000
    current_capacity: int = 0
    total_sections_count: int = 0
    has_transport: bool = False
    has_hostel: bool = False
    has_library: bool = True
    has_laboratory: bool = True
    has_sports_facilities: bool = True
    has_smart_classrooms: bool = False
    has_computer_lab: bool = True
    has_medical_room: bool = False
    has_cctv: bool = False
    has_fire_safety: bool = False
    has_water_sanitation: bool = True
    has_electricity_backup: bool = False
    has_accessibility_ramps: bool = False

    custom_values: Dict[str, Any] = Field(default_factory=dict)


class SchoolProfileUpdate(SchoolProfileBase):
    pass


class SchoolProfileResponse(SchoolProfileBase):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    school_name: str
    school_code: str
    board: str
    school_type: str
    email: str
    phone: Optional[str] = None
    website: Optional[str] = None
    principal_name: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    postal_code: Optional[str] = None
    logo_url: Optional[str] = None

    udise_code: Optional[str] = None
    udise_status: str
    udise_verification_status: UdiseVerificationStatus
    udise_verified_at: Optional[datetime] = None
    udise_verified_by_name: Optional[str] = None
    udise_notes: Optional[str] = None

    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class UdiseVerifyRequest(BaseModel):
    is_verified: bool
    notes: Optional[str] = None


class SchoolRecognitionCreate(BaseModel):
    authority_level: RecognitionAuthorityLevel
    authority_name: str
    recognition_type: RecognitionType
    recognition_number: str
    certificate_number: Optional[str] = None
    proceedings_order_number: Optional[str] = None
    issue_date: Optional[date] = None
    valid_from: Optional[date] = None
    valid_until: Optional[date] = None
    status: RecognitionStatus = RecognitionStatus.ACTIVE
    document_id: Optional[uuid.UUID] = None
    remarks: Optional[str] = None


class SchoolRecognitionUpdate(BaseModel):
    authority_level: Optional[RecognitionAuthorityLevel] = None
    authority_name: Optional[str] = None
    recognition_type: Optional[RecognitionType] = None
    recognition_number: Optional[str] = None
    certificate_number: Optional[str] = None
    proceedings_order_number: Optional[str] = None
    issue_date: Optional[date] = None
    valid_from: Optional[date] = None
    valid_until: Optional[date] = None
    status: Optional[RecognitionStatus] = None
    document_id: Optional[uuid.UUID] = None
    remarks: Optional[str] = None


class SchoolRecognitionResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    authority_level: RecognitionAuthorityLevel
    authority_name: str
    recognition_type: RecognitionType
    recognition_number: str
    certificate_number: Optional[str] = None
    proceedings_order_number: Optional[str] = None
    issue_date: Optional[date] = None
    valid_from: Optional[date] = None
    valid_until: Optional[date] = None
    status: RecognitionStatus
    document_id: Optional[uuid.UUID] = None
    document_title: Optional[str] = None
    remarks: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SchoolCustomFieldCreate(BaseModel):
    field_name: str
    field_key: str
    field_type: str = "TEXT"  # TEXT, NUMBER, DATE, BOOLEAN, DROPDOWN, PHONE, EMAIL
    field_options: Optional[List[str]] = Field(default_factory=list)
    is_required: bool = False
    visible_to_principal: bool = True
    visible_to_teachers: bool = False
    visible_to_parents: bool = False


class SchoolCustomFieldResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    field_name: str
    field_key: str
    field_type: str
    field_options: Optional[List[str]] = None
    is_required: bool
    visible_to_principal: bool
    visible_to_teachers: bool
    visible_to_parents: bool
    created_at: datetime

    class Config:
        from_attributes = True


class SchoolDocumentCreate(BaseModel):
    category: DocumentCategory
    title: str
    issuing_authority: Optional[str] = None
    document_number: Optional[str] = None
    file_name: str
    file_path: str
    file_size_bytes: int = 0
    content_type: str = "application/pdf"
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    confidentiality_level: ConfidentialityLevel = ConfidentialityLevel.STANDARD
    is_password_protected: bool = False
    passcode: Optional[str] = None  # Plaintext provided during creation/update only, never stored or returned
    remarks: Optional[str] = None


class SchoolDocumentUpdate(BaseModel):
    category: Optional[DocumentCategory] = None
    title: Optional[str] = None
    issuing_authority: Optional[str] = None
    document_number: Optional[str] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    confidentiality_level: Optional[ConfidentialityLevel] = None
    is_password_protected: Optional[bool] = None
    passcode: Optional[str] = None
    remarks: Optional[str] = None


class SchoolDocumentResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    category: DocumentCategory
    title: str
    issuing_authority: Optional[str] = None
    document_number: Optional[str] = None
    file_name: str
    file_path: str
    file_size_bytes: int
    content_type: str
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    confidentiality_level: ConfidentialityLevel
    is_password_protected: bool
    is_archived: bool
    remarks: Optional[str] = None
    uploaded_by: Optional[uuid.UUID] = None
    uploaded_by_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    is_expiring_soon: bool = False
    is_expired: bool = False
    days_until_expiry: Optional[int] = None

    class Config:
        from_attributes = True


class DocumentUnlockRequest(BaseModel):
    passcode: str


class DocumentUnlockResponse(BaseModel):
    document_id: uuid.UUID
    is_unlocked: bool
    unlock_token: Optional[str] = None
    message: str


class DocumentAccessLogResponse(BaseModel):
    id: uuid.UUID
    document_id: uuid.UUID
    document_title: Optional[str] = None
    user_id: Optional[uuid.UUID] = None
    user_name: Optional[str] = None
    action: DocumentAction
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class DocumentExpiryAlert(BaseModel):
    document_id: uuid.UUID
    title: str
    category: DocumentCategory
    document_number: Optional[str] = None
    expiry_date: date
    days_remaining: int
    is_expired: bool
    recommended_action: str


class DocumentExpiryMonitorResponse(BaseModel):
    total_monitored: int
    expiring_soon_count: int
    expired_count: int
    alerts: List[DocumentExpiryAlert]
    missing_mandatory_categories: List[str]


class ComplianceDashboardResponse(BaseModel):
    school_id: uuid.UUID
    school_name: str
    udise_code: Optional[str] = None
    udise_configured: bool
    udise_verification_status: Optional[UdiseVerificationStatus] = UdiseVerificationStatus.UNVERIFIED
    udise_verified_at: Optional[datetime] = None

    total_recognitions: int
    active_recognitions: int
    central_recognitions_count: int
    state_recognitions_count: int

    total_documents: int
    confidential_documents_count: int
    expiring_documents_count: int
    expired_documents_count: int

    payroll_policy_configured: bool
    payroll_ready: bool
    teachers_count: int
    pending_payroll_count: int
    approved_payroll_count: int


class ComplianceRequirementResponse(BaseModel):
    id: uuid.UUID
    code: str
    title: str
    category: str
    applicable_authority: str
    statutory_reference: str
    requirement_description: str
    what_school_must_maintain: str
    required_documents: List[str]
    field_schema: Dict[str, Any]
    default_validity_months: Optional[int] = None
    renewal_reminder_days: int = 60
    mandatory: bool = True
    sort_order: int = 0
    is_active: bool = True

    class Config:
        from_attributes = True


class ComplianceDocumentSummary(BaseModel):
    id: uuid.UUID
    title: str
    file_name: str
    file_path: str
    content_type: str
    file_size_bytes: int
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    issuing_authority: Optional[str] = None
    document_number: Optional[str] = None

    class Config:
        from_attributes = True


class ComplianceAuditLogResponse(BaseModel):
    id: uuid.UUID
    record_id: uuid.UUID
    action: str
    actor_id: Optional[uuid.UUID] = None
    actor_name: Optional[str] = None
    actor_role: Optional[str] = None
    changes: Dict[str, Any] = Field(default_factory=dict)
    notes: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ComplianceRecordResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    requirement_id: uuid.UUID
    requirement: ComplianceRequirementResponse
    status: str
    certificate_number: Optional[str] = None
    issuing_authority: Optional[str] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    last_inspection_date: Optional[date] = None
    next_renewal_date: Optional[date] = None
    primary_document_id: Optional[uuid.UUID] = None
    primary_document: Optional[ComplianceDocumentSummary] = None
    supporting_document_ids: List[str] = Field(default_factory=list)
    supporting_documents: List[ComplianceDocumentSummary] = Field(default_factory=list)
    photo_evidence_urls: List[str] = Field(default_factory=list)
    specific_data: Dict[str, Any] = Field(default_factory=dict)
    missing_items: List[str] = Field(default_factory=list)
    verification_status: str
    verified_at: Optional[datetime] = None
    verified_by: Optional[uuid.UUID] = None
    verified_by_name: Optional[str] = None
    verification_notes: Optional[str] = None
    remarks: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    days_until_expiry: Optional[int] = None
    is_expired: bool = False
    is_expiring_soon: bool = False

    class Config:
        from_attributes = True


class ComplianceRecordUpdate(BaseModel):
    certificate_number: Optional[str] = None
    issuing_authority: Optional[str] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    last_inspection_date: Optional[date] = None
    next_renewal_date: Optional[date] = None
    primary_document_id: Optional[uuid.UUID] = None
    supporting_document_ids: Optional[List[str]] = None
    photo_evidence_urls: Optional[List[str]] = None
    specific_data: Optional[Dict[str, Any]] = None
    remarks: Optional[str] = None


class ComplianceVerificationRequest(BaseModel):
    status: str  # VERIFIED or REJECTED
    notes: Optional[str] = None


class ComplianceDashboardSummary(BaseModel):
    school_id: uuid.UUID
    total_requirements: int
    verified_count: int
    pending_verification_count: int
    missing_evidence_count: int
    expiring_soon_count: int
    expired_count: int
    non_compliant_count: int
    not_applicable_count: int
    compliance_percentage: float
    items: List[ComplianceRecordResponse]

