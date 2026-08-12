import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, ConfigDict, Field

from app.models.import_job import ImportType, ImportJobStatus

class ImportJobCreate(BaseModel):
    school_id: uuid.UUID
    import_type: ImportType
    source_filename: str = Field(..., max_length=255)
    file_checksum: Optional[str] = Field(None, max_length=64)
    total_rows: int = Field(0, ge=0)
    job_metadata: Dict[str, Any] = Field(default_factory=dict)

class ImportJobResponse(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    school_id: uuid.UUID
    import_type: ImportType
    status: ImportJobStatus
    source_filename: str
    file_checksum: Optional[str] = None
    
    total_rows: int
    processed_rows: int
    successful_rows: int
    failed_rows: int
    skipped_rows: int
    
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_summary: Optional[str] = None
    job_metadata: Dict[str, Any]
    
    created_at: datetime
    updated_at: datetime
    created_by: Optional[uuid.UUID] = None

    model_config = ConfigDict(from_attributes=True)

class ImportJobRowCreate(BaseModel):
    row_number: int = Field(..., ge=1)
    status: str = Field(..., max_length=50)
    error_code: Optional[str] = Field(None, max_length=100)
    error_message: Optional[str] = Field(None, max_length=1000)
    source_identifier: Optional[str] = Field(None, max_length=255)
    entity_id: Optional[uuid.UUID] = None
    row_metadata: Dict[str, Any] = Field(default_factory=dict)

class ImportJobRowResponse(BaseModel):
    id: uuid.UUID
    import_job_id: uuid.UUID
    row_number: int
    status: str
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    source_identifier: Optional[str] = None
    entity_id: Optional[uuid.UUID] = None
    row_metadata: Dict[str, Any]
    
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class ImportJobRowCreateBulk(BaseModel):
    rows: List[ImportJobRowCreate]
