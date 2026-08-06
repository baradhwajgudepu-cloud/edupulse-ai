import uuid
import os
import logging
from datetime import date, datetime, timezone, timedelta
from decimal import Decimal
from typing import List, Optional, Tuple, Dict
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from fastapi import HTTPException, status
from sqlalchemy import select, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.models.fee import (
    FeeType, Scholarship, FeeStructure, FineRule,
    StudentFeeAssignment, FeePayment, FeePaymentAllocation, FeeReceipt,
    ConcessionType, PaymentMethod, PaymentStatus, FeeAssignmentStatus, FineType
)
from app.models.student import Student
from app.models.class_entity import Class
from app.models.school import School
from app.models.academic_year import AcademicYear
from app.repositories.fee import FeeRepository
from app.services.notification import NotificationService
from app.schemas.fee import (
    FeeTypeCreate, FeeTypeUpdate, ScholarshipCreate, ScholarshipUpdate,
    FeeStructureCreate, FeeStructureUpdate, FineRuleCreate, FineRuleUpdate,
    StudentFeeAssignmentCreate, FeePaymentCreate, PaymentCancelRequest
)

logger = logging.getLogger(__name__)

def _generate_pdf_receipt(
    pdf_path: str,
    receipt_number: str,
    school_name: str,
    student_name: str,
    academic_year_name: str,
    payment_date: str,
    payment_method: str,
    transaction_reference: Optional[str],
    allocations: list,
    total_amount_paid: Decimal
):
    doc = SimpleDocTemplate(pdf_path, pagesize=letter)
    styles = getSampleStyleSheet()
    
    # Custom Styles
    title_style = ParagraphStyle(
        'ReceiptTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=colors.HexColor('#1A237E'),
        alignment=1, # Center
        spaceAfter=15
    )
    
    label_style = ParagraphStyle(
        'LabelStyle',
        parent=styles['BodyText'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#333333')
    )
    
    value_style = ParagraphStyle(
        'ValueStyle',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#222222')
    )
    
    section_title_style = ParagraphStyle(
        'SectionTitle',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor('#0D47A1'),
        spaceBefore=15,
        spaceAfter=5
    )

    story = [
        Paragraph(school_name, title_style),
        Paragraph("FEE PAYMENT RECEIPT", ParagraphStyle('Sub', parent=title_style, fontSize=14, leading=18, spaceAfter=20)),
        Spacer(1, 10)
    ]
    
    # Metadata Table
    metadata_data = [
        [Paragraph("<b>Receipt Number:</b>", label_style), Paragraph(receipt_number, value_style),
         Paragraph("<b>Date:</b>", label_style), Paragraph(payment_date, value_style)],
        [Paragraph("<b>Student Name:</b>", label_style), Paragraph(student_name, value_style),
         Paragraph("<b>Academic Year:</b>", label_style), Paragraph(academic_year_name, value_style)],
        [Paragraph("<b>Payment Method:</b>", label_style), Paragraph(payment_method, value_style),
         Paragraph("<b>Reference:</b>", label_style), Paragraph(transaction_reference or "N/A", value_style)]
    ]
    
    meta_table = Table(metadata_data, colWidths=[100, 150, 100, 150])
    meta_table.setStyle(TableStyle([
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
    ]))
    
    story.append(meta_table)
    story.append(Spacer(1, 20))
    story.append(Paragraph("Allocation Details", section_title_style))
    
    # Allocations Table
    alloc_headers = [Paragraph("<b>Fee Type</b>", label_style), Paragraph("<b>Amount Allocated (INR)</b>", label_style)]
    alloc_rows = [[Paragraph(item[0], value_style), Paragraph(f"{float(item[1]):.2f}", value_style)] for item in allocations]
    
    # Total row
    alloc_rows.append([
        Paragraph("<b>Total Amount Paid:</b>", label_style),
        Paragraph(f"<b>{float(total_amount_paid):.2f}</b>", label_style)
    ])
    
    alloc_table_data = [alloc_headers] + alloc_rows
    alloc_table = Table(alloc_table_data, colWidths=[300, 200])
    alloc_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#E8EAF6')),
        ('GRID', (0,0), (-1,-1), 1, colors.HexColor('#BDBDBD')),
        ('PADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BACKGROUND', (0,-1), (-1,-1), colors.HexColor('#C8E6C9')),
    ]))
    
    story.append(alloc_table)
    doc.build(story)

class FeeService:
    def __init__(self, fee_repo: FeeRepository, notification_service: NotificationService) -> None:
        self.fee_repo = fee_repo
        self.notification_service = notification_service

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
        
        # Load School Name, Student Name, Academic Year Name
        stmt_st = select(Student).where(Student.id == student_id, Student.tenant_id == tenant_id)
        res_st = await self.fee_repo.db.execute(stmt_st)
        student = res_st.scalar_one_or_none()
        student_name = f"{student.first_name} {student.last_name}" if student else "Unknown Student"

        school_name = "Unknown School"
        if school_id:
            stmt_sch = select(School).where(School.id == school_id, School.tenant_id == tenant_id)
            res_sch = await self.fee_repo.db.execute(stmt_sch)
            school = res_sch.scalar_one_or_none()
            if school:
                school_name = school.name

        stmt_ay = select(AcademicYear).where(AcademicYear.id == obj_in.academic_year_id, AcademicYear.tenant_id == tenant_id)
        res_ay = await self.fee_repo.db.execute(stmt_ay)
        ay = res_ay.scalar_one_or_none()
        ay_name = ay.name if ay else "Unknown Year"

        # Prepare allocations details for PDF
        pdf_allocations = []
        for assignment, allocated_amount in allocations_to_create:
            structure = await self.fee_repo.get_fee_structure_by_id(assignment.fee_structure_id, tenant_id)
            fee_type_name = "Fee"
            if structure:
                fee_type = await self.fee_repo.get_fee_type_by_id(structure.fee_type_id, tenant_id)
                if fee_type:
                    fee_type_name = fee_type.name
            pdf_allocations.append((fee_type_name, allocated_amount))

        # Generate ReportLab PDF Receipt
        receipts_dir = os.path.join("static", "receipts")
        os.makedirs(receipts_dir, exist_ok=True)
        pdf_filename = f"{receipt_number}.pdf"
        pdf_path = os.path.join(receipts_dir, pdf_filename)
        
        # Format dates
        payment_date_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        try:
            _generate_pdf_receipt(
                pdf_path=pdf_path,
                receipt_number=receipt_number,
                school_name=school_name,
                student_name=student_name,
                academic_year_name=ay_name,
                payment_date=payment_date_str,
                payment_method=obj_in.payment_method.value,
                transaction_reference=obj_in.transaction_reference,
                allocations=pdf_allocations,
                total_amount_paid=total_payment_amount
            )
        except Exception as e:
            logger.error(f"Failed to generate PDF receipt file: {str(e)}")
            raise HTTPException(status_code=500, detail="Failed to generate PDF receipt.")

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
        ).group_by(Class.name)
        res_class = await self.fee_repo.db.execute(stmt_class)
        top_outstanding = [{"class_name": row[0], "outstanding_amount": Decimal(str(row[1])) if row[1] is not None else Decimal("0.00")} for row in res_class.all()]

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
