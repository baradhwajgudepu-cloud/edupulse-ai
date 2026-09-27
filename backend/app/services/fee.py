import uuid
import os
import io
import logging
from datetime import date, datetime, timezone, timedelta
from decimal import Decimal
from typing import List, Optional, Tuple, Dict, Union
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from fastapi import HTTPException, status
from sqlalchemy import select, func, and_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.models.fee import (
    FeeType, Scholarship, FeeStructure, FineRule,
    StudentFeeAssignment, FeePayment, FeePaymentAllocation, FeeReceipt,
    ConcessionType, PaymentMethod, PaymentStatus, FeeAssignmentStatus, FineType
)
from app.models.student import Student, StudentStatus
from app.models.class_entity import Class
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.models.section import Section
from app.repositories.fee import FeeRepository
from app.services.notification import NotificationService
from app.schemas.fee import (
    FeeTypeCreate, FeeTypeUpdate, ScholarshipCreate, ScholarshipUpdate,
    FeeStructureCreate, FeeStructureUpdate, FineRuleCreate, FineRuleUpdate,
    StudentFeeAssignmentCreate, FeePaymentCreate, FeePaymentUpdate, PaymentCancelRequest
)

logger = logging.getLogger(__name__)

def _generate_pdf_receipt(
    pdf_path: Union[str, io.BytesIO],
    receipt_number: str,
    school_name: str,
    student_name: str,
    academic_year_name: str,
    payment_date: str,
    payment_method: str,
    transaction_reference: Optional[str],
    allocations: list,
    total_amount_paid: Decimal,
    school_address: Optional[str] = None,
    school_phone: Optional[str] = None,
    school_email: Optional[str] = None,
    admission_number: Optional[str] = None,
    class_name: Optional[str] = None,
    section_name: Optional[str] = None,
    total_outstanding_remaining: Optional[Decimal] = None
):
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=36,
        rightMargin=36,
        topMargin=36,
        bottomMargin=36
    )
    styles = getSampleStyleSheet()
    
    primary_color = colors.HexColor('#1E3A8A')
    secondary_color = colors.HexColor('#2563EB')
    dark_neutral = colors.HexColor('#1F2937')
    muted_neutral = colors.HexColor('#4B5563')
    light_bg = colors.HexColor('#F8FAFC')
    border_color = colors.HexColor('#CBD5E1')
    header_bg = colors.HexColor('#E2E8F0')
    success_bg = colors.HexColor('#DCFCE7')

    school_title_style = ParagraphStyle(
        'SchoolTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=18,
        leading=22,
        textColor=primary_color,
        alignment=1,
        spaceAfter=4
    )

    school_subtitle_style = ParagraphStyle(
        'SchoolSubtitle',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=muted_neutral,
        alignment=1,
        spaceAfter=8
    )

    doc_title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=secondary_color,
        alignment=1,
        spaceAfter=14
    )

    label_style = ParagraphStyle(
        'LabelStyle',
        parent=styles['BodyText'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=13,
        textColor=dark_neutral
    )

    value_style = ParagraphStyle(
        'ValueStyle',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=dark_neutral
    )

    section_header_style = ParagraphStyle(
        'SectionHeader',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=14,
        textColor=primary_color,
        spaceBefore=12,
        spaceAfter=6
    )

    story = [
        Paragraph(school_name.upper(), school_title_style),
    ]

    contact_parts = []
    if school_address:
        contact_parts.append(school_address)
    if school_phone:
        contact_parts.append(f"Phone: {school_phone}")
    if school_email:
        contact_parts.append(f"Email: {school_email}")
    contact_str = " | ".join(contact_parts) if contact_parts else "Affiliated Educational Institution"
    story.append(Paragraph(contact_str, school_subtitle_style))
    story.append(Paragraph("FEE PAYMENT RECEIPT", doc_title_style))

    student_class_str = f"{class_name or ''} {section_name or ''}".strip()
    meta_data = [
        [
            Paragraph("<b>Receipt No:</b>", label_style), Paragraph(receipt_number, value_style),
            Paragraph("<b>Payment Date:</b>", label_style), Paragraph(payment_date, value_style)
        ],
        [
            Paragraph("<b>Student Name:</b>", label_style), Paragraph(student_name, value_style),
            Paragraph("<b>Academic Year:</b>", label_style), Paragraph(academic_year_name, value_style)
        ],
        [
            Paragraph("<b>Admission No:</b>", label_style), Paragraph(admission_number or "N/A", value_style),
            Paragraph("<b>Class / Section:</b>", label_style), Paragraph(student_class_str or "N/A", value_style)
        ],
        [
            Paragraph("<b>Payment Mode:</b>", label_style), Paragraph(payment_method.replace('_', ' '), value_style),
            Paragraph("<b>Transaction Ref:</b>", label_style), Paragraph(transaction_reference or "N/A", value_style)
        ]
    ]

    meta_table = Table(meta_data, colWidths=[90, 180, 100, 170])
    meta_table.setStyle(TableStyle([
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BACKGROUND', (0,0), (-1,-1), light_bg),
        ('BOX', (0,0), (-1,-1), 0.5, border_color),
        ('INNERGRID', (0,0), (-1,-1), 0.5, border_color),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 10))

    story.append(Paragraph("FEE ALLOCATION BREAKDOWN", section_header_style))

    has_details = allocations and isinstance(allocations[0], dict)
    if has_details:
        alloc_headers = [
            Paragraph("<b>Fee Component</b>", label_style),
            Paragraph("<b>Assigned (₹)</b>", label_style),
            Paragraph("<b>Concession (₹)</b>", label_style),
            Paragraph("<b>Late Fine (₹)</b>", label_style),
            Paragraph("<b>Paid Now (₹)</b>", label_style),
            Paragraph("<b>Remaining (₹)</b>", label_style),
        ]
        alloc_rows = []
        for item in allocations:
            alloc_rows.append([
                Paragraph(str(item.get("name", "Fee")), value_style),
                Paragraph(f"{float(item.get('assigned', 0)):,.2f}", value_style),
                Paragraph(f"{float(item.get('discount', 0)):,.2f}", value_style),
                Paragraph(f"{float(item.get('fine', 0)):,.2f}", value_style),
                Paragraph(f"<b>{float(item.get('paid', 0)):,.2f}</b>", value_style),
                Paragraph(f"{float(item.get('remaining', 0)):,.2f}", value_style),
            ])
        alloc_rows.append([
            Paragraph("<b>TOTAL PAID</b>", label_style),
            Paragraph("", value_style),
            Paragraph("", value_style),
            Paragraph("", value_style),
            Paragraph(f"<b>₹ {float(total_amount_paid):,.2f}</b>", label_style),
            Paragraph("", value_style),
        ])
        alloc_table = Table([alloc_headers] + alloc_rows, colWidths=[150, 75, 75, 70, 85, 85])
    else:
        alloc_headers = [
            Paragraph("<b>Fee Component</b>", label_style),
            Paragraph("<b>Amount Allocated (₹)</b>", label_style)
        ]
        alloc_rows = []
        for item in allocations:
            name = item[0] if isinstance(item, (list, tuple)) else str(item)
            amt = item[1] if isinstance(item, (list, tuple)) else Decimal("0.00")
            alloc_rows.append([
                Paragraph(str(name), value_style),
                Paragraph(f"₹ {float(amt):,.2f}", value_style)
            ])
        alloc_rows.append([
            Paragraph("<b>Total Amount Paid:</b>", label_style),
            Paragraph(f"<b>₹ {float(total_amount_paid):,.2f}</b>", label_style)
        ])
        alloc_table = Table([alloc_headers] + alloc_rows, colWidths=[350, 190])

    alloc_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), header_bg),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, border_color),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
        ('BACKGROUND', (0,-1), (-1,-1), success_bg),
    ]))
    story.append(alloc_table)

    if total_outstanding_remaining is not None:
        story.append(Spacer(1, 8))
        bal_text = f"<b>Total Outstanding Balance After This Payment: ₹ {float(total_outstanding_remaining):,.2f}</b>"
        story.append(Paragraph(bal_text, ParagraphStyle('Bal', parent=value_style, fontSize=9, textColor=primary_color)))

    story.append(Spacer(1, 30))

    sig_data = [
        [
            Paragraph("_______________________________<br/><b>Student / Parent Signature</b>", ParagraphStyle('S1', parent=value_style, alignment=0)),
            Paragraph("_______________________________<br/><b>Cashier / Authorized Signatory</b>", ParagraphStyle('S2', parent=value_style, alignment=2))
        ]
    ]
    sig_table = Table(sig_data, colWidths=[270, 270])
    sig_table.setStyle(TableStyle([
        ('ALIGN', (0,0), (0,0), 'LEFT'),
        ('ALIGN', (1,0), (1,0), 'RIGHT'),
        ('VALIGN', (0,0), (-1,-1), 'BOTTOM'),
    ]))
    story.append(sig_table)
    story.append(Spacer(1, 14))

    footer_style = ParagraphStyle(
        'FooterStyle',
        parent=styles['BodyText'],
        fontName='Helvetica-Oblique',
        fontSize=8,
        textColor=muted_neutral,
        alignment=1
    )
    story.append(Paragraph("This is an electronically generated official receipt issued by EduPulse AI School Management System.", footer_style))

    doc.build(story)

class FeeService:
    def __init__(self, fee_repo: FeeRepository, notification_service: NotificationService, storage_service = None) -> None:
        self.fee_repo = fee_repo
        self.notification_service = notification_service
        from app.services.storage import get_storage_service
        self.storage_service = storage_service or get_storage_service()

    # --- FEE TYPE CRUD ---
    async def get_fee_type(self, id: uuid.UUID, tenant_id: uuid.UUID) -> FeeType:
        db_obj = await self.fee_repo.get_fee_type_by_id(id, tenant_id)
        if not db_obj:
            raise HTTPException(status_code=404, detail="Fee Type not found.")
        return db_obj

    async def list_fee_types(self, tenant_id: uuid.UUID) -> List[FeeType]:
        return await self.fee_repo.list_fee_types(tenant_id)

    async def create_fee_type(
        self, tenant_id: uuid.UUID, obj_in: FeeTypeCreate, current_user_id: Optional[uuid.UUID] = None
    ) -> FeeType:
        # Check code uniqueness
        existing = await self.fee_repo.get_fee_type_by_code(obj_in.code, tenant_id)
        if existing:
            raise HTTPException(status_code=400, detail=f"Fee Type with code '{obj_in.code}' already exists.")
        
        db_obj = await self.fee_repo.create_fee_type(tenant_id, obj_in, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(db_obj)
        return db_obj

    async def update_fee_type(
        self, id: uuid.UUID, tenant_id: uuid.UUID, obj_in: FeeTypeUpdate, current_user_id: Optional[uuid.UUID] = None
    ) -> FeeType:
        db_obj = await self.get_fee_type(id, tenant_id)
        updated = await self.fee_repo.update_fee_type(db_obj, obj_in, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(updated)
        return updated

    async def delete_fee_type(
        self, id: uuid.UUID, tenant_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> FeeType:
        db_obj = await self.get_fee_type(id, tenant_id)
        deleted = await self.fee_repo.delete_fee_type(db_obj, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(deleted)
        return deleted

    # --- SCHOLARSHIP CRUD ---
    async def get_scholarship(self, id: uuid.UUID, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None) -> Scholarship:
        db_obj = await self.fee_repo.get_scholarship_by_id(id, tenant_id, school_id)
        if not db_obj:
            raise HTTPException(status_code=404, detail="Scholarship not found.")
        return db_obj

    async def list_scholarships(self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None) -> List[Scholarship]:
        return await self.fee_repo.list_scholarships(tenant_id, school_id)

    async def create_scholarship(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ScholarshipCreate, current_user_id: Optional[uuid.UUID] = None
    ) -> Scholarship:
        # Check duplicate name case-insensitively within tenant & school
        existing = await self.fee_repo.get_scholarship_by_name(tenant_id, school_id, obj_in.name)
        if existing:
            raise HTTPException(status_code=409, detail="Scholarship with the same name already exists.")

        db_obj = await self.fee_repo.create_scholarship(tenant_id, school_id, obj_in, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(db_obj)
        return db_obj

    async def update_scholarship(
        self, id: uuid.UUID, tenant_id: uuid.UUID, obj_in: ScholarshipUpdate, current_user_id: Optional[uuid.UUID] = None
    ) -> Scholarship:
        db_obj = await self.get_scholarship(id, tenant_id)
        
        # Check duplicate name if updated
        if obj_in.name is not None:
            existing = await self.fee_repo.get_scholarship_by_name(tenant_id, db_obj.school_id, obj_in.name)
            if existing and existing.id != id:
                raise HTTPException(status_code=409, detail="Scholarship with the same name already exists.")

        # Business rules validation on concession value combined state
        new_value = obj_in.value if obj_in.value is not None else db_obj.value
        new_type = obj_in.concession_type if obj_in.concession_type is not None else db_obj.concession_type
        if new_value <= 0:
            raise HTTPException(status_code=422, detail="Value must be greater than zero.")
        if new_type == ConcessionType.PERCENTAGE and (new_value < 1.0 or new_value > 100.0):
            raise HTTPException(status_code=422, detail="Percentage scholarship values must be between 1 and 100 inclusive.")

        updated = await self.fee_repo.update_scholarship(db_obj, obj_in, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(updated)
        return updated

    async def delete_scholarship(
        self, id: uuid.UUID, tenant_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> Scholarship:
        db_obj = await self.get_scholarship(id, tenant_id)
        deleted = await self.fee_repo.delete_scholarship(db_obj, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(deleted)
        return deleted

    # --- FEE STRUCTURE CRUD ---
    async def get_fee_structure(self, id: uuid.UUID, tenant_id: uuid.UUID) -> FeeStructure:
        db_obj = await self.fee_repo.get_fee_structure_by_id(id, tenant_id)
        if not db_obj:
            raise HTTPException(status_code=404, detail="Fee Structure not found.")
        return db_obj

    async def list_fee_structures(self, tenant_id: uuid.UUID, school_id: uuid.UUID) -> List[FeeStructure]:
        return await self.fee_repo.list_fee_structures(tenant_id, school_id)

    async def create_fee_structure(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: FeeStructureCreate, current_user_id: Optional[uuid.UUID] = None
    ) -> FeeStructure:
        # Verify Fee Type
        await self.get_fee_type(obj_in.fee_type_id, tenant_id)

        # Check if active fee structure already exists for this combination
        existing = await self.fee_repo.get_fee_structure_by_comb(
            tenant_id=tenant_id,
            school_id=school_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            fee_type_id=obj_in.fee_type_id
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Fee Structure already exists for this class, academic year and fee type."
            )

        try:
            # Create Fee Structure
            db_obj = await self.fee_repo.create_fee_structure(tenant_id, school_id, obj_in, current_user_id)
            
            # Flush to generate ID and check DB constraints
            await self.fee_repo.db.flush()

            # Create nested Fine Rule if present
            if obj_in.fine_rule:
                await self.fee_repo.create_fine_rule(tenant_id, db_obj.id, obj_in.fine_rule, current_user_id)
                await self.fee_repo.db.flush()

            await self.fee_repo.db.commit()
            
            # Auto-propagate fee structure to eligible students in the class
            try:
                await self.propagate_class_fee_structure(tenant_id, db_obj.id, current_user_id)
            except Exception as pe:
                logger.warning(f"Auto-propagation for fee structure {db_obj.id} encountered: {pe}")

            return await self.get_fee_structure(db_obj.id, tenant_id)
        except IntegrityError as e:
            await self.fee_repo.db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Fee Structure already exists for this class, academic year and fee type."
            )
        except Exception as e:
            await self.fee_repo.db.rollback()
            raise e

    async def update_fee_structure(
        self, id: uuid.UUID, tenant_id: uuid.UUID, obj_in: FeeStructureUpdate, current_user_id: Optional[uuid.UUID] = None
    ) -> FeeStructure:
        db_obj = await self.get_fee_structure(id, tenant_id)
        
        # Check if the combination is changing and would cause a duplicate (if fields are editable)
        new_fee_type_id = getattr(obj_in, "fee_type_id", None)
        new_class_id = getattr(obj_in, "class_id", None)
        new_academic_year_id = getattr(obj_in, "academic_year_id", None)

        if (new_fee_type_id is not None or new_class_id is not None or new_academic_year_id is not None):
            check_fee_type_id = new_fee_type_id if new_fee_type_id is not None else db_obj.fee_type_id
            check_class_id = new_class_id if new_class_id is not None else db_obj.class_id
            check_academic_year_id = new_academic_year_id if new_academic_year_id is not None else db_obj.academic_year_id

            existing = await self.fee_repo.get_fee_structure_by_comb(
                tenant_id=tenant_id,
                school_id=db_obj.school_id,
                academic_year_id=check_academic_year_id,
                class_id=check_class_id,
                fee_type_id=check_fee_type_id
            )
            if existing and existing.id != id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Fee Structure already exists for this class, academic year and fee type."
                )

        try:
            updated = await self.fee_repo.update_fee_structure(db_obj, obj_in, current_user_id)
            
            # Handle fine rule nested update
            if obj_in.fine_rule:
                existing_rule = await self.fee_repo.get_fine_rule_by_structure_id(db_obj.id, tenant_id)
                if existing_rule:
                    await self.fee_repo.update_fine_rule(existing_rule, obj_in.fine_rule, current_user_id)
                else:
                    # Create one
                    rule_create = FineRuleCreate(
                        grace_period_days=obj_in.fine_rule.grace_period_days or 0,
                        fine_type=obj_in.fine_rule.fine_type or FineType.FIXED,
                        fine_value=obj_in.fine_rule.fine_value or 0.0
                    )
                    await self.fee_repo.create_fine_rule(tenant_id, db_obj.id, rule_create, current_user_id)
                await self.fee_repo.db.flush()

            await self.fee_repo.db.commit()
            return await self.get_fee_structure(db_obj.id, tenant_id)
        except IntegrityError as e:
            await self.fee_repo.db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Fee Structure already exists for this class, academic year and fee type."
            )
        except Exception as e:
            await self.fee_repo.db.rollback()
            raise e

    async def delete_fee_structure(
        self, id: uuid.UUID, tenant_id: uuid.UUID, current_user_id: Optional[uuid.UUID] = None
    ) -> FeeStructure:
        db_obj = await self.get_fee_structure(id, tenant_id)
        deleted = await self.fee_repo.delete_fee_structure(db_obj, current_user_id)
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(deleted)
        return deleted
    async def propagate_class_fee_structure(
        self,
        tenant_id: uuid.UUID,
        fee_structure_id: uuid.UUID,
        current_user_id: Optional[uuid.UUID] = None
    ) -> int:
        """
        Propagates a fee structure to all eligible active students in the target class
        (or school if class_id is None). Idempotent: preserves existing assignments,
        concessions, and payment histories.
        """
        fee_structure = await self.get_fee_structure(fee_structure_id, tenant_id)

        # Query active enrolled students
        conditions = [
            Student.tenant_id == tenant_id,
            Student.school_id == fee_structure.school_id,
            Student.deleted_at.is_(None),
            Student.status == StudentStatus.ACTIVE
        ]
        if fee_structure.class_id is not None:
            conditions.append(Student.class_id == fee_structure.class_id)
        if fee_structure.academic_year_id is not None:
            conditions.append(Student.academic_year_id == fee_structure.academic_year_id)

        stmt_students = select(Student).where(and_(*conditions))
        res_students = await self.fee_repo.db.execute(stmt_students)
        students = res_students.scalars().all()

        assigned_count = 0
        for student in students:
            # Check existing assignment idempotently
            stmt_existing = select(StudentFeeAssignment).where(
                StudentFeeAssignment.student_id == student.id,
                StudentFeeAssignment.fee_structure_id == fee_structure.id,
                StudentFeeAssignment.tenant_id == tenant_id
            )
            res_existing = await self.fee_repo.db.execute(stmt_existing)
            existing = res_existing.scalar_one_or_none()

            if not existing:
                new_assignment = StudentFeeAssignment(
                    id=uuid.uuid4(),
                    tenant_id=tenant_id,
                    academic_year_id=fee_structure.academic_year_id,
                    student_id=student.id,
                    fee_structure_id=fee_structure.id,
                    assigned_amount=fee_structure.amount,
                    paid_amount=Decimal("0.00"),
                    discount_amount=Decimal("0.00"),
                    fine_amount=Decimal("0.00"),
                    status=FeeAssignmentStatus.UNPAID,
                    created_by=current_user_id,
                    version=1
                )
                self.fee_repo.db.add(new_assignment)
                assigned_count += 1

        if assigned_count > 0:
            await self.fee_repo.db.commit()

        logger.info(f"Propagated fee structure {fee_structure_id} to {assigned_count} students (out of {len(students)} eligible).")
        return assigned_count

    # --- STUDENT FEE ASSIGNMENTS ---
    async def assign_fee(
        self, tenant_id: uuid.UUID, obj_in: StudentFeeAssignmentCreate, current_user_id: Optional[uuid.UUID] = None
    ) -> StudentFeeAssignment:
        # Check student exists
        stmt_st = select(Student).where(Student.id == obj_in.student_id, Student.tenant_id == tenant_id, Student.deleted_at.is_(None))
        res_st = await self.fee_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        # Check fee structure exists
        fee_structure = await self.get_fee_structure(obj_in.fee_structure_id, tenant_id)

        # Check duplicate
        existing = await self.fee_repo.get_assignment_by_student_and_structure(obj_in.student_id, obj_in.fee_structure_id, tenant_id)
        if existing:
            raise HTTPException(status_code=400, detail="Fee is already assigned to this student.")

        # Calculate discount using Scholarship if present
        discount_amount = Decimal("0.00")
        if obj_in.scholarship_id:
            scholarship = await self.get_scholarship(obj_in.scholarship_id, tenant_id)
            s_value = Decimal(str(scholarship.value))
            fs_amount = Decimal(str(fee_structure.amount))
            if scholarship.concession_type == ConcessionType.FIXED:
                discount_amount = s_value
            elif scholarship.concession_type == ConcessionType.PERCENTAGE:
                discount_amount = fs_amount * (s_value / Decimal("100.0"))
            # Ensure discount doesn't exceed fee amount
            discount_amount = min(discount_amount, fs_amount)

        # Create Assignment
        db_obj = await self.fee_repo.create_fee_assignment(
            tenant_id=tenant_id,
            student_id=obj_in.student_id,
            fee_structure_id=obj_in.fee_structure_id,
            academic_year_id=fee_structure.academic_year_id,
            assigned_amount=fee_structure.amount,
            discount_amount=discount_amount,
            scholarship_id=obj_in.scholarship_id,
            created_by=current_user_id
        )
        
        await self.fee_repo.db.commit()
        await self.fee_repo.db.refresh(db_obj)

        # Retrieve school details for notifications
        school_id = fee_structure.school_id

        # Trigger notification
        try:
            # Load fee type name
            fee_type = await self.fee_repo.get_fee_type_by_id(fee_structure.fee_type_id, tenant_id)
            fee_name = fee_type.name if fee_type else "Fee"
            await self.notification_service.notify_fee_due(
                tenant_id=tenant_id,
                school_id=school_id,
                student_id=obj_in.student_id,
                fee_name=fee_name,
                amount=float(db_obj.assigned_amount - db_obj.discount_amount),
                due_date=fee_structure.due_date
            )
        except Exception as ne:
            logger.error(f"Failed to send fee assignment notification: {str(ne)}")

        return db_obj

    # --- COLLECT PAYMENT & ALLOCATIONS ---
    async def collect_payment(
        self, tenant_id: uuid.UUID, obj_in: FeePaymentCreate, current_user_id: Optional[uuid.UUID] = None
    ) -> FeePayment:
        total_payment_amount = Decimal(str(obj_in.allocations[0].amount_allocated)) if len(obj_in.allocations) == 1 else sum((Decimal(str(alloc.amount_allocated)) for alloc in obj_in.allocations), Decimal("0.00"))
        
        # Verify allocations are correct
        allocations_to_create = []
        assignments_to_update = []
        student_id = obj_in.student_id
        school_id = None

        today = date.today()

        for alloc in obj_in.allocations:
            assignment = await self.fee_repo.get_fee_assignment_by_id(alloc.assignment_id, tenant_id)
            if not assignment:
                raise HTTPException(status_code=404, detail=f"Student Fee Assignment {alloc.assignment_id} not found.")
            if assignment.student_id != student_id:
                raise HTTPException(status_code=400, detail="Assignment student mismatch.")
            if assignment.status == FeeAssignmentStatus.PAID:
                raise HTTPException(status_code=400, detail="Cannot allocate payment to already completed assignment.")

            # Load fee structure to check due date and fine rules
            structure = await self.fee_repo.get_fee_structure_by_id(assignment.fee_structure_id, tenant_id)
            if not school_id and structure:
                school_id = structure.school_id

            # Apply Late Fine automatically if applicable
            if structure and structure.fine_rule and today > (structure.due_date + timedelta(days=structure.fine_rule.grace_period_days)):
                fine_rule = structure.fine_rule
                current_unpaid = Decimal(str(assignment.assigned_amount)) - Decimal(str(assignment.discount_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.paid_amount))
                
                calculated_fine = Decimal("0.00")
                if fine_rule.fine_type == FineType.FIXED:
                    calculated_fine = Decimal(str(fine_rule.fine_value))
                elif fine_rule.fine_type == FineType.PERCENTAGE:
                    calculated_fine = current_unpaid * (Decimal(str(fine_rule.fine_value)) / Decimal("100.0"))
                elif fine_rule.fine_type == FineType.DAILY_FIXED:
                    days_overdue = (today - structure.due_date).days
                    calculated_fine = Decimal(str(fine_rule.fine_value)) * Decimal(days_overdue)

                # Apply fine to assignment
                assignment.fine_amount = Decimal(str(assignment.fine_amount)) + calculated_fine
                logger.info(f"Applied automated late fine of {calculated_fine} to assignment {assignment.id}")

            # Re-evaluate remaining unpaid amount
            outstanding_amount = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - Decimal(str(assignment.paid_amount))
            
            # Reject Overpayments
            alloc_allocated = Decimal(str(alloc.amount_allocated))
            if alloc_allocated > outstanding_amount:
                raise HTTPException(
                    status_code=400,
                    detail=f"Payment allocation ({alloc_allocated}) exceeds outstanding balance ({outstanding_amount}) for fee structure. Overpayments are rejected."
                )

            allocations_to_create.append((assignment, alloc_allocated))

        # Check duplicate transaction reference if supplied
        if obj_in.transaction_reference and obj_in.transaction_reference.strip():
            ref_clean = obj_in.transaction_reference.strip()
            stmt_dup = select(FeePayment).where(
                FeePayment.tenant_id == tenant_id,
                FeePayment.student_id == student_id,
                FeePayment.transaction_reference == ref_clean,
                FeePayment.status != PaymentStatus.CANCELLED,
                FeePayment.deleted_at.is_(None)
            )
            res_dup = await self.fee_repo.db.execute(stmt_dup)
            if res_dup.scalar_one_or_none():
                raise HTTPException(
                    status_code=400,
                    detail=f"Payment with transaction reference '{ref_clean}' is already recorded for this student."
                )

        # Create Fee Payment Transaction
        payment = await self.fee_repo.create_payment(
            tenant_id=tenant_id,
            student_id=student_id,
            academic_year_id=obj_in.academic_year_id,
            amount_paid=total_payment_amount,
            payment_method=obj_in.payment_method.value,
            transaction_reference=obj_in.transaction_reference,
            remarks=obj_in.remarks,
            created_by=current_user_id
        )
        
        # Flush to populate payment.id
        await self.fee_repo.db.flush()

        # Process allocations and status updates
        for assignment, allocated_amount in allocations_to_create:
            # Create allocation row
            await self.fee_repo.create_payment_allocation(payment.id, assignment.id, allocated_amount)

            # Update paid amount
            assignment.paid_amount = Decimal(str(assignment.paid_amount)) + allocated_amount

            # Recalculate status
            outstanding = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - Decimal(str(assignment.paid_amount))
            if outstanding <= Decimal("0.00"):
                assignment.status = FeeAssignmentStatus.PAID
            else:
                assignment.status = FeeAssignmentStatus.PARTIALLY_PAID
            
            self.fee_repo.db.add(assignment)

        # Generate receipt
        receipt_number = await self.fee_repo.get_next_receipt_number(tenant_id)
        
        # Load School Name, Student Name, Academic Year Name, Class, Section
        stmt_st = select(Student).where(Student.id == student_id, Student.tenant_id == tenant_id)
        res_st = await self.fee_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}".strip() if student else "Unknown Student"
        adm_no = student.admission_number if student else None

        class_name = None
        section_name = None
        if student and student.class_id:
            stmt_c = select(Class).where(Class.id == student.class_id)
            res_c = await self.fee_repo.db.execute(stmt_c)
            c_obj = res_c.scalar_one_or_none()
            if c_obj:
                class_name = c_obj.name
        if student and student.section_id:
            stmt_sec = select(Section).where(Section.id == student.section_id)
            res_sec = await self.fee_repo.db.execute(stmt_sec)
            sec_obj = res_sec.scalar_one_or_none()
            if sec_obj:
                section_name = sec_obj.name

        school_name = "EduPulse School"
        school_address = None
        school_phone = None
        school_email = None
        if school_id:
            stmt_sch = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
            res_sch = await self.fee_repo.db.execute(stmt_sch)
            school = res_sch.scalar_one_or_none()
            if school:
                school_name = school.name
                school_address = f"{school.address or ''}, {school.city or ''}, {school.state or ''}".strip(', ')
                school_phone = school.phone
                school_email = school.email

        stmt_ay = select(AcademicYear).where(AcademicYear.id == obj_in.academic_year_id, AcademicYear.tenant_id == tenant_id)
        res_ay = await self.fee_repo.db.execute(stmt_ay)
        ay = res_ay.scalar_one_or_none()
        ay_name = ay.name if ay else "Unknown Year"

        # Prepare detailed allocations breakdown for PDF
        pdf_allocations = []
        total_remaining = Decimal("0.00")
        for assignment, allocated_amount in allocations_to_create:
            structure = await self.fee_repo.get_fee_structure_by_id(assignment.fee_structure_id, tenant_id)
            fee_type_name = "Fee Component"
            if structure:
                fee_type = await self.fee_repo.get_fee_type_by_id(structure.fee_type_id, tenant_id)
                if fee_type:
                    fee_type_name = fee_type.name
            rem = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - Decimal(str(assignment.paid_amount))
            rem = max(Decimal("0.00"), rem)
            total_remaining += rem
            pdf_allocations.append({
                "name": fee_type_name,
                "assigned": Decimal(str(assignment.assigned_amount)),
                "discount": Decimal(str(assignment.discount_amount)),
                "fine": Decimal(str(assignment.fine_amount)),
                "paid": allocated_amount,
                "remaining": rem
            })

        # Generate ReportLab PDF Receipt in-memory
        payment_date_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        buf = io.BytesIO()
        try:
            _generate_pdf_receipt(
                pdf_path=buf,
                receipt_number=receipt_number,
                school_name=school_name,
                student_name=student_name,
                academic_year_name=ay_name,
                payment_date=payment_date_str,
                payment_method=obj_in.payment_method.value,
                transaction_reference=obj_in.transaction_reference,
                allocations=pdf_allocations,
                total_amount_paid=total_payment_amount,
                school_address=school_address,
                school_phone=school_phone,
                school_email=school_email,
                admission_number=adm_no,
                class_name=class_name,
                section_name=section_name,
                total_outstanding_remaining=total_remaining
            )
            pdf_bytes = buf.getvalue()
        except Exception as e:
            logger.error(f"Failed to generate PDF receipt: {str(e)}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to generate PDF receipt.")

        # Persist locally and upload to storage
        pdf_path = f"receipts/{receipt_number}.pdf"
        try:
            os.makedirs(os.path.dirname(pdf_path), exist_ok=True)
            with open(pdf_path, "wb") as f:
                f.write(pdf_bytes)
        except Exception as fe:
            logger.warning(f"Could not save local receipt {pdf_path}: {fe}")

        receipts_dir = os.path.join("static", "receipts")
        os.makedirs(receipts_dir, exist_ok=True)
        local_path = os.path.join(receipts_dir, f"{receipt_number}.pdf")
        try:
            with open(local_path, "wb") as f:
                f.write(pdf_bytes)
        except Exception as fe:
            logger.warning(f"Could not save local receipt {local_path}: {fe}")

        await self.storage_service.upload(pdf_bytes, pdf_path, "application/pdf")

        # Create Receipt record
        receipt = await self.fee_repo.create_receipt(
            tenant_id=tenant_id,
            payment_id=payment.id,
            receipt_number=receipt_number,
            pdf_path=pdf_path,
            created_by=current_user_id
        )

        await self.fee_repo.db.commit()

        # Trigger notification
        if school_id:
            try:
                await self.notification_service.notify_fee_paid(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    student_id=student_id,
                    amount_paid=total_payment_amount,
                    receipt_number=receipt_number
                )
            except Exception as ne:
                logger.error(f"Failed to send fee payment notification: {str(ne)}")

        return await self.fee_repo.get_payment_by_id(payment.id, tenant_id)

    async def list_payments(
        self,
        tenant_id: uuid.UUID,
        school_id: Optional[uuid.UUID] = None,
        student_id: Optional[uuid.UUID] = None,
        academic_year_id: Optional[uuid.UUID] = None,
        payment_method: Optional[PaymentMethod] = None,
        payment_status: Optional[PaymentStatus] = None,
        skip: int = 0,
        limit: int = 50
    ) -> Tuple[List[FeePayment], int]:
        return await self.fee_repo.list_payments(
            tenant_id=tenant_id,
            school_id=school_id,
            student_id=student_id,
            academic_year_id=academic_year_id,
            payment_method=payment_method.value if payment_method else None,
            payment_status=payment_status.value if payment_status else None,
            skip=skip,
            limit=limit
        )

    async def update_payment(
        self,
        payment_id: uuid.UUID,
        tenant_id: uuid.UUID,
        obj_in: FeePaymentUpdate,
        current_user_id: Optional[uuid.UUID] = None
    ) -> FeePayment:
        payment = await self.fee_repo.get_payment_by_id(payment_id, tenant_id)
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found.")
        if payment.status == PaymentStatus.CANCELLED:
            raise HTTPException(status_code=400, detail="Cannot edit a cancelled payment.")

        if obj_in.payment_method is not None:
            payment.payment_method = obj_in.payment_method.value
        if obj_in.transaction_reference is not None:
            payment.transaction_reference = obj_in.transaction_reference.strip() if obj_in.transaction_reference.strip() else None
        if obj_in.remarks is not None:
            payment.remarks = obj_in.remarks.strip() if obj_in.remarks.strip() else None

        # If amount_paid is modified
        if obj_in.amount_paid is not None and obj_in.amount_paid != payment.amount_paid:
            diff = Decimal(str(obj_in.amount_paid)) - Decimal(str(payment.amount_paid))
            if len(payment.allocations) == 1:
                alloc = payment.allocations[0]
                assignment = alloc.assignment
                if not assignment:
                    assignment = await self.fee_repo.get_fee_assignment_by_id(alloc.assignment_id, tenant_id)
                new_allocated = Decimal(str(alloc.amount_allocated)) + diff
                max_allowable = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - (Decimal(str(assignment.paid_amount)) - Decimal(str(alloc.amount_allocated)))
                if new_allocated > max_allowable:
                    raise HTTPException(status_code=400, detail=f"Updated amount ({new_allocated}) exceeds outstanding due ({max_allowable}).")
                if new_allocated <= 0:
                    raise HTTPException(status_code=400, detail="Updated payment amount must be greater than zero.")

                assignment.paid_amount = Decimal(str(assignment.paid_amount)) + diff
                outstanding = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - Decimal(str(assignment.paid_amount))
                if outstanding <= Decimal("0.00"):
                    assignment.status = FeeAssignmentStatus.PAID
                else:
                    assignment.status = FeeAssignmentStatus.PARTIALLY_PAID

                alloc.amount_allocated = new_allocated
                payment.amount_paid = Decimal(str(obj_in.amount_paid))
                self.fee_repo.db.add(assignment)
                self.fee_repo.db.add(alloc)

        payment.updated_by = current_user_id
        payment.updated_at = datetime.now(timezone.utc)
        self.fee_repo.db.add(payment)
        await self.fee_repo.db.commit()

        if payment.receipt:
            await self.regenerate_receipt_pdf(payment.receipt.receipt_number, tenant_id)

        return await self.fee_repo.get_payment_by_id(payment.id, tenant_id)

    async def regenerate_receipt_pdf(self, receipt_number: str, tenant_id: uuid.UUID) -> bytes:
        receipt = await self.fee_repo.get_receipt_by_number(receipt_number, tenant_id)
        if not receipt:
            raise HTTPException(status_code=404, detail="Receipt not found.")
        payment = receipt.payment
        if not payment:
            payment = await self.fee_repo.get_payment_by_id(receipt.payment_id, tenant_id)
            if not payment:
                raise HTTPException(status_code=404, detail="Payment for receipt not found.")

        # Student & School details
        stmt_st = select(Student).where(Student.id == payment.student_id, Student.tenant_id == tenant_id)
        res_st = await self.fee_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}".strip() if student else "Unknown Student"
        adm_no = student.admission_number if student else None

        class_name = None
        section_name = None
        if student and student.class_id:
            stmt_c = select(Class).where(Class.id == student.class_id)
            res_c = await self.fee_repo.db.execute(stmt_c)
            c_obj = res_c.scalar_one_or_none()
            if c_obj:
                class_name = c_obj.name
        if student and student.section_id:
            stmt_sec = select(Section).where(Section.id == student.section_id)
            res_sec = await self.fee_repo.db.execute(stmt_sec)
            sec_obj = res_sec.scalar_one_or_none()
            if sec_obj:
                section_name = sec_obj.name

        school_id = student.school_id if student else None
        school_name = "EduPulse School"
        school_address = None
        school_phone = None
        school_email = None
        if school_id:
            stmt_sch = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
            res_sch = await self.fee_repo.db.execute(stmt_sch)
            school = res_sch.scalar_one_or_none()
            if school:
                school_name = school.name
                school_address = f"{school.address or ''}, {school.city or ''}, {school.state or ''}".strip(', ')
                school_phone = school.phone
                school_email = school.email

        stmt_ay = select(AcademicYear).where(AcademicYear.id == payment.academic_year_id, AcademicYear.tenant_id == tenant_id)
        res_ay = await self.fee_repo.db.execute(stmt_ay)
        ay = res_ay.scalar_one_or_none()
        ay_name = ay.name if ay else "Unknown Year"

        pdf_allocations = []
        total_remaining = Decimal("0.00")
        for alloc in payment.allocations:
            assignment = alloc.assignment
            if not assignment:
                assignment = await self.fee_repo.get_fee_assignment_by_id(alloc.assignment_id, tenant_id)
            fee_type_name = "Fee Component"
            if assignment:
                structure = await self.fee_repo.get_fee_structure_by_id(assignment.fee_structure_id, tenant_id)
                if structure:
                    ft = await self.fee_repo.get_fee_type_by_id(structure.fee_type_id, tenant_id)
                    if ft:
                        fee_type_name = ft.name
                rem = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - Decimal(str(assignment.paid_amount))
                rem = max(Decimal("0.00"), rem)
                total_remaining += rem
                pdf_allocations.append({
                    "name": fee_type_name,
                    "assigned": Decimal(str(assignment.assigned_amount)),
                    "discount": Decimal(str(assignment.discount_amount)),
                    "fine": Decimal(str(assignment.fine_amount)),
                    "paid": alloc.amount_allocated,
                    "remaining": rem,
                })
            else:
                pdf_allocations.append({
                    "name": fee_type_name,
                    "assigned": alloc.amount_allocated,
                    "discount": Decimal("0.00"),
                    "fine": Decimal("0.00"),
                    "paid": alloc.amount_allocated,
                    "remaining": Decimal("0.00"),
                })

        payment_date_str = payment.payment_date.strftime("%Y-%m-%d %H:%M:%S") if hasattr(payment.payment_date, 'strftime') else str(payment.payment_date)

        buf = io.BytesIO()
        try:
            _generate_pdf_receipt(
                pdf_path=buf,
                receipt_number=receipt_number,
                school_name=school_name,
                student_name=student_name,
                academic_year_name=ay_name,
                payment_date=payment_date_str,
                payment_method=payment.payment_method.value if hasattr(payment.payment_method, 'value') else str(payment.payment_method),
                transaction_reference=payment.transaction_reference,
                allocations=pdf_allocations,
                total_amount_paid=payment.amount_paid,
                school_address=school_address,
                school_phone=school_phone,
                school_email=school_email,
                admission_number=adm_no,
                class_name=class_name,
                section_name=section_name,
                total_outstanding_remaining=total_remaining
            )
            pdf_bytes = buf.getvalue()
        except Exception as e:
            logger.error(f"Failed to regenerate PDF receipt: {str(e)}", exc_info=True)
            raise HTTPException(status_code=500, detail="Failed to regenerate PDF receipt.")

        pdf_path = f"receipts/{receipt_number}.pdf"
        try:
            os.makedirs(os.path.dirname(pdf_path), exist_ok=True)
            with open(pdf_path, "wb") as f:
                f.write(pdf_bytes)
        except Exception as fe:
            logger.warning(f"Could not save local receipt {pdf_path}: {fe}")

        receipts_dir = os.path.join("static", "receipts")
        os.makedirs(receipts_dir, exist_ok=True)
        local_path = os.path.join(receipts_dir, f"{receipt_number}.pdf")
        try:
            with open(local_path, "wb") as f:
                f.write(pdf_bytes)
        except Exception as fe:
            logger.warning(f"Could not save local receipt {local_path}: {fe}")

        await self.storage_service.upload(pdf_bytes, pdf_path, "application/pdf")
        if receipt.pdf_path != pdf_path:
            receipt.pdf_path = pdf_path
            self.fee_repo.db.add(receipt)
            await self.fee_repo.db.commit()

        return pdf_bytes

    # --- REVERT PAYMENT / CANCELLATION ---
    async def cancel_payment(
        self, payment_id: uuid.UUID, tenant_id: uuid.UUID, obj_in: PaymentCancelRequest, current_user_id: Optional[uuid.UUID] = None
    ) -> FeePayment:
        payment = await self.fee_repo.get_payment_by_id(payment_id, tenant_id)
        if not payment:
            raise HTTPException(status_code=404, detail="Payment not found.")
        if payment.status == PaymentStatus.CANCELLED:
            raise HTTPException(status_code=400, detail="Payment is already cancelled.")

        # 1. Update Payment Status to Cancelled
        payment.status = PaymentStatus.CANCELLED
        payment.cancel_reason = obj_in.cancel_reason
        payment.cancelled_by = current_user_id
        payment.cancelled_at = datetime.now(timezone.utc)
        self.fee_repo.db.add(payment)

        school_id = None

        # 2. Revert allocations on StudentFeeAssignments
        for alloc in payment.allocations:
            assignment = alloc.assignment
            # Reduce paid amount
            alloc_amt = Decimal(str(alloc.amount_allocated))
            assignment.paid_amount = Decimal(str(assignment.paid_amount)) - alloc_amt

            # Recalculate status
            outstanding = Decimal(str(assignment.assigned_amount)) + Decimal(str(assignment.fine_amount)) - Decimal(str(assignment.discount_amount)) - Decimal(str(assignment.paid_amount))
            if assignment.paid_amount <= Decimal("0.00"):
                assignment.status = FeeAssignmentStatus.UNPAID
            elif outstanding <= Decimal("0.00"):
                assignment.status = FeeAssignmentStatus.PAID
            else:
                assignment.status = FeeAssignmentStatus.PARTIALLY_PAID

            self.fee_repo.db.add(assignment)

            # Fetch school_id for notification
            if not school_id:
                structure = await self.fee_repo.get_fee_structure_by_id(assignment.fee_structure_id, tenant_id)
                if structure:
                    school_id = structure.school_id

        # 3. Retrieve receipt number
        receipt = await self.fee_repo.get_receipt_by_payment_id(payment.id, tenant_id)
        receipt_number = receipt.receipt_number if receipt else "Unknown"

        await self.fee_repo.db.commit()

        # Trigger cancellation notification
        if school_id:
            try:
                await self.notification_service.notify_fee_cancelled(
                    tenant_id=tenant_id,
                    school_id=school_id,
                    student_id=payment.student_id,
                    amount_reversed=float(payment.amount_paid),
                    receipt_number=receipt_number
                )
            except Exception as ne:
                logger.error(f"Failed to send payment cancellation notification: {str(ne)}")

        return await self.fee_repo.get_payment_by_id(payment.id, tenant_id)

    # --- REPORTS & ANALYTICS ---
    async def get_student_ledger(self, student_id: uuid.UUID, tenant_id: uuid.UUID) -> dict:
        # Verify student exists
        stmt_st = select(Student).where(Student.id == student_id, Student.tenant_id == tenant_id, Student.deleted_at.is_(None))
        res_st = await self.fee_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        return await self.fee_repo.get_student_ledger(student_id, tenant_id)

    async def get_dashboard_metrics(self, tenant_id: uuid.UUID, school_id: uuid.UUID) -> dict:
        today = date.today()
        # Today collection
        today_col = await self.fee_repo.get_daily_collection(tenant_id, school_id, today)
        # Monthly collection
        month_col = await self.fee_repo.get_monthly_collection(tenant_id, school_id, today.year, today.month)

        # Pending dues
        pending_assignments = await self.fee_repo.get_pending_assignments(tenant_id, school_id)
        pending_dues = sum((Decimal(str(a.assigned_amount)) + Decimal(str(a.fine_amount)) - Decimal(str(a.discount_amount)) - Decimal(str(a.paid_amount)) for a in pending_assignments), Decimal("0.00"))

        # Collection %: paid / assigned
        # Query total assigned
        stmt_total = select(func.sum(StudentFeeAssignment.assigned_amount), func.sum(StudentFeeAssignment.paid_amount)).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).where(
            StudentFeeAssignment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            StudentFeeAssignment.deleted_at.is_(None)
        )
        res_total = await self.fee_repo.db.execute(stmt_total)
        first_row = res_total.first()
        tot_assigned, tot_paid = first_row if first_row else (Decimal("0.00"), Decimal("0.00"))
        
        tot_assigned = Decimal(str(tot_assigned or "0.00"))
        tot_paid = Decimal(str(tot_paid or "0.00"))
        col_pct = (tot_paid / tot_assigned * Decimal("100.0")) if tot_assigned > Decimal("0.00") else Decimal("100.0")

        # Defaulters count: unique student count with unpaid overdue fees
        stmt_def = select(func.count(func.distinct(StudentFeeAssignment.student_id))).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).where(
            StudentFeeAssignment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            StudentFeeAssignment.status.in_([FeeAssignmentStatus.UNPAID, FeeAssignmentStatus.PARTIALLY_PAID]),
            FeeStructure.due_date < today,
            StudentFeeAssignment.deleted_at.is_(None)
        )
        res_def = await self.fee_repo.db.execute(stmt_def)
        defaulters = res_def.scalar() or 0

        # Outstanding per class
        stmt_class = select(
            Class.id,
            Class.name,
            func.sum(StudentFeeAssignment.assigned_amount + StudentFeeAssignment.fine_amount - StudentFeeAssignment.discount_amount - StudentFeeAssignment.paid_amount)
        ).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).join(
            Class, Class.id == FeeStructure.class_id
        ).where(
            StudentFeeAssignment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            StudentFeeAssignment.deleted_at.is_(None)
        ).group_by(Class.id, Class.name)
        res_class = await self.fee_repo.db.execute(stmt_class)
        top_outstanding = [{"class_id": row[0], "class_name": row[1], "outstanding_amount": Decimal(str(row[2])) if row[2] is not None else Decimal("0.00")} for row in res_class.all()]

        return {
            "today_collection": today_col,
            "month_collection": month_col,
            "pending_dues": pending_dues,
            "collection_percentage": round(col_pct, 2),
            "defaulters_count": defaulters,
            "top_outstanding_classes": top_outstanding
        }

    # --- AI ALGORITHMS ---
    async def get_default_risk(self, student_id: uuid.UUID, tenant_id: uuid.UUID) -> dict:
        ledger = await self.fee_repo.get_student_ledger(student_id, tenant_id)
        assignments = ledger["assignments"]
        
        # Simple AI risk score algorithm
        overdue_count = 0
        total_outstanding = ledger["closing_balance"]
        
        today = date.today()
        for assign in assignments:
            if assign.status in [FeeAssignmentStatus.UNPAID, FeeAssignmentStatus.PARTIALLY_PAID]:
                structure = await self.fee_repo.get_fee_structure_by_id(assign.fee_structure_id, tenant_id)
                if structure and structure.due_date < today:
                    overdue_count += 1

        if total_outstanding == Decimal("0.00"):
            probability = Decimal("0.02")
            payment_score = 98
            risk_level = "LOW"
        elif overdue_count > 0:
            # Overdue fee = high risk
            probability = Decimal("0.85")
            payment_score = 35
            risk_level = "HIGH"
        else:
            # Unpaid but not overdue
            probability = Decimal("0.25")
            payment_score = 75
            risk_level = "MEDIUM"

        return {
            "student_id": student_id,
            "default_risk_probability": probability,
            "payment_score": payment_score,
            "risk_level": risk_level
        }

    async def get_collection_analytics(self, tenant_id: uuid.UUID, school_id: uuid.UUID) -> dict:
        today = date.today()
        # Mock next 30 days predicted collection based on outstanding dues + collection velocity
        pending_assignments = await self.fee_repo.get_pending_assignments(tenant_id, school_id)
        pending_dues = sum((Decimal(str(a.assigned_amount)) + Decimal(str(a.fine_amount)) - Decimal(str(a.discount_amount)) - Decimal(str(a.paid_amount)) for a in pending_assignments), Decimal("0.00"))
        
        # Assume AI predicts school will collect 70% of current outstanding dues in the next 30 days
        predicted = round(pending_dues * Decimal("0.70"), 2)
        
        # Trends representation
        historical = {
            "Day 5": round(predicted * Decimal("0.2"), 2),
            "Day 15": round(predicted * Decimal("0.5"), 2),
            "Day 25": round(predicted * Decimal("0.8"), 2),
            "Day 30": predicted
        }

        return {
            "predicted_collection_next_30_days": predicted,
            "historical_trend": historical
        }

    async def import_payments(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        payments: List[Any],
        current_user_id: Optional[uuid.UUID] = None
    ) -> dict:
        from app.schemas.fee import FeePaymentAllocationCreate
        
        results = []
        success_count = 0
        failed_count = 0

        for idx, row in enumerate(payments):
            adm = row.admission_number
            code = row.fee_type_code
            amount = row.amount
            pay_date = row.payment_date
            pay_method = row.payment_method
            ref_num = row.reference_number

            try:
                # 1. Verify student exists within tenant and school
                stmt_st = select(Student).where(
                    Student.admission_number == adm,
                    Student.school_id == school_id,
                    Student.tenant_id == tenant_id,
                    Student.deleted_at.is_(None)
                )
                res_st = await self.fee_repo.db.execute(stmt_st)
                student = res_st.scalar_one_or_none()
                if not student:
                    raise ValueError(f"Student with admission number '{adm}' not found in this school.")

                # 2. Verify fee type exists
                stmt_ft = select(FeeType).where(
                    FeeType.code == code,
                    FeeType.tenant_id == tenant_id,
                    FeeType.deleted_at.is_(None)
                )
                res_ft = await self.fee_repo.db.execute(stmt_ft)
                fee_type = res_ft.scalar_one_or_none()
                if not fee_type:
                    raise ValueError(f"Fee Type with code '{code}' not found.")

                # 3. Find assignment
                stmt_assign = select(StudentFeeAssignment).join(
                    FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
                ).where(
                    StudentFeeAssignment.student_id == student.id,
                    StudentFeeAssignment.tenant_id == tenant_id,
                    FeeStructure.fee_type_id == fee_type.id,
                    FeeStructure.academic_year_id == academic_year_id,
                    StudentFeeAssignment.deleted_at.is_(None)
                )
                res_assign = await self.fee_repo.db.execute(stmt_assign)
                assignment = res_assign.scalar_one_or_none()
                if not assignment:
                    raise ValueError(f"Fee structure for '{code}' is not assigned to this student.")

                # 4. Construct FeePaymentCreate
                obj_in = FeePaymentCreate(
                    student_id=student.id,
                    academic_year_id=academic_year_id,
                    payment_method=pay_method,
                    transaction_reference=ref_num,
                    remarks=f"Imported payment for {code}",
                    allocations=[
                        FeePaymentAllocationCreate(
                            assignment_id=assignment.id,
                            amount_allocated=amount
                        )
                    ]
                )

                # 5. Call collect_payment
                payment = await self.collect_payment(tenant_id, obj_in, current_user_id)

                results.append({
                    "row_index": idx,
                    "admission_number": adm,
                    "fee_type_code": code,
                    "success": True,
                    "payment_id": payment.id
                })
                success_count += 1
            except Exception as e:
                # Rollback current transaction if failed
                await self.fee_repo.db.rollback()
                
                # Extract error message
                err_msg = str(e)
                if hasattr(e, "detail"):
                    err_msg = e.detail
                elif hasattr(e, "message"):
                    err_msg = e.message

                results.append({
                    "row_index": idx,
                    "admission_number": adm,
                    "fee_type_code": code,
                    "success": False,
                    "error": err_msg
                })
                failed_count += 1

        return {
            "total_processed": len(payments),
            "success_count": success_count,
            "failed_count": failed_count,
            "results": results
        }

    async def get_outstanding_report(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        class_id: Optional[uuid.UUID] = None,
        only_defaulters: bool = False
    ) -> List[dict]:
        today = date.today()
        stmt = select(
            StudentFeeAssignment,
            Student,
            Class,
            Section,
            FeeStructure,
            FeeType
        ).join(
            Student, Student.id == StudentFeeAssignment.student_id
        ).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).join(
            Class, Class.id == FeeStructure.class_id
        ).join(
            Section, Section.id == Student.section_id
        ).join(
            FeeType, FeeType.id == FeeStructure.fee_type_id
        ).where(
            StudentFeeAssignment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            StudentFeeAssignment.deleted_at.is_(None)
        )

        # Filter by class
        if class_id:
            stmt = stmt.where(FeeStructure.class_id == class_id)

        # Filter by defaulters (due_date passed and status is UNPAID or PARTIALLY_PAID)
        if only_defaulters:
            stmt = stmt.where(
                FeeStructure.due_date < today,
                StudentFeeAssignment.status.in_([FeeAssignmentStatus.UNPAID, FeeAssignmentStatus.PARTIALLY_PAID])
            )

        # Filter out fully paid assignments (outstanding > 0)
        stmt = stmt.where(
            (StudentFeeAssignment.assigned_amount + StudentFeeAssignment.fine_amount - StudentFeeAssignment.discount_amount - StudentFeeAssignment.paid_amount) > 0
        )

        res = await self.fee_repo.db.execute(stmt)
        items = []
        for row in res.all():
            assign, student, cls, sec, struct, ftype = row
            student_name = f"{student.first_name} {student.last_name}"
            outstanding = Decimal(str(assign.assigned_amount)) + Decimal(str(assign.fine_amount)) - Decimal(str(assign.discount_amount)) - Decimal(str(assign.paid_amount))

            items.append({
                "assignment_id": assign.id,
                "academic_year_id": assign.academic_year_id,
                "student_id": student.id,
                "student_name": student_name,
                "admission_number": student.admission_number,
                "class_id": cls.id,
                "class_name": cls.name,
                "section_id": sec.id,
                "section_name": sec.name,
                "fee_structure_id": struct.id,
                "fee_type_id": ftype.id,
                "fee_type_name": ftype.name,
                "assigned_amount": assign.assigned_amount,
                "discount_amount": assign.discount_amount,
                "fine_amount": assign.fine_amount,
                "paid_amount": assign.paid_amount,
                "outstanding_amount": outstanding,
                "due_date": struct.due_date,
                "status": assign.status
            })
        return items
