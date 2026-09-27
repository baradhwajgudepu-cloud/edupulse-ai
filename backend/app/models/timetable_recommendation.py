import uuid
from typing import Optional, Dict, Any
from sqlalchemy import String, Integer, Boolean, ForeignKey, Index, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.dialects.postgresql import JSONB

from app.db.base import Base
from app.db.mixins import BaseModelMixin

class TimetableRecommendation(Base, BaseModelMixin):
    """
    SQLAlchemy model representing an AI generated Timetable recommendation or adaptive adjustment suggestion.
    Recommendations are transparent, advisory, and strictly require school staff/principal review before publishing.
    """
    __tablename__ = "timetable_recommendations"

    recommendation_type: Mapped[str] = mapped_column(String(50), default="INITIAL_GENERATION", nullable=False)
    status: Mapped[str] = mapped_column(String(30), default="SUGGESTED", nullable=False)

    suggested_slots: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    rationale: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    risk_factors: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )
    audit_trail: Mapped[dict] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"), default=dict, server_default="{}", nullable=False
    )

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("schools.id", ondelete="CASCADE"), nullable=False, index=True
    )
    academic_year_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("academic_years.id", ondelete="CASCADE"), nullable=False, index=True
    )
    class_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("classes.id", ondelete="CASCADE"), nullable=False, index=True
    )
    section_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sections.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Relationships
    tenant = relationship("Tenant")
    school = relationship("School")
    academic_year = relationship("AcademicYear")
    class_obj = relationship("Class")
    section = relationship("Section")

    __mapper_args__ = {
        "version_id_col": version
    }

    __table_args__ = (
        Index("ix_timetable_recs_sec_status", "section_id", "status"),
        Index("ix_timetable_recs_school_ay", "school_id", "academic_year_id"),
    )
