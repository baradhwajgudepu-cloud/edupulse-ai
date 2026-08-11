import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import List, Optional, Tuple
from sqlalchemy import select, and_, or_, func, update
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.fee import (
    FeeType, Scholarship, FeeStructure, FineRule,
    StudentFeeAssignment, FeePayment, FeePaymentAllocation, FeeReceipt,
    FeeAssignmentStatus, PaymentStatus
)
from app.schemas.fee import (
    FeeTypeCreate, FeeTypeUpdate, ScholarshipCreate, ScholarshipUpdate,
    FeeStructureCreate, FeeStructureUpdate, FineRuleCreate, FineRuleUpdate
)

class FeeRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # --- FEE TYPE CRUD ---
    async def get_fee_type_by_id(self, id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[FeeType]:
        stmt = select(FeeType).where(
            FeeType.id == id,
            FeeType.tenant_id == tenant_id,
            FeeType.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_fee_type_by_code(self, code: str, tenant_id: uuid.UUID) -> Optional[FeeType]:
        stmt = select(FeeType).where(
            func.lower(FeeType.code) == code.lower(),
            FeeType.tenant_id == tenant_id,
            FeeType.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def list_fee_types(self, tenant_id: uuid.UUID) -> List[FeeType]:
        stmt = select(FeeType).where(
            FeeType.tenant_id == tenant_id,
            FeeType.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create_fee_type(
        self, tenant_id: uuid.UUID, obj_in: FeeTypeCreate, created_by: Optional[uuid.UUID] = None
    ) -> FeeType:
        db_obj = FeeType(
            tenant_id=tenant_id,
            name=obj_in.name,
            code=obj_in.code,
            description=obj_in.description,
            is_system=obj_in.is_system or False,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update_fee_type(self, db_obj: FeeType, obj_in: FeeTypeUpdate | dict, updated_by: Optional[uuid.UUID] = None) -> FeeType:
        update_data = obj_in if isinstance(obj_in, dict) else obj_in.model_dump(exclude_unset=True)
        for field in update_data:
            setattr(db_obj, field, update_data[field])
        db_obj.updated_by = updated_by
        db_obj.updated_at = datetime.now(timezone.utc)
        self.db.add(db_obj)
        return db_obj

    async def delete_fee_type(self, db_obj: FeeType, deleted_by: Optional[uuid.UUID] = None) -> FeeType:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj

    # --- SCHOLARSHIP CRUD ---
    async def get_scholarship_by_id(self, id: uuid.UUID, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None) -> Optional[Scholarship]:
        stmt = select(Scholarship).where(
            Scholarship.id == id,
            Scholarship.tenant_id == tenant_id,
            Scholarship.deleted_at.is_(None)
        )
        if school_id is not None:
            stmt = stmt.where(Scholarship.school_id == school_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_scholarship_by_name(self, tenant_id: uuid.UUID, school_id: uuid.UUID, name: str) -> Optional[Scholarship]:
        stmt = select(Scholarship).where(
            Scholarship.tenant_id == tenant_id,
            Scholarship.school_id == school_id,
            func.lower(Scholarship.name) == name.lower().strip(),
            Scholarship.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def list_scholarships(self, tenant_id: uuid.UUID, school_id: Optional[uuid.UUID] = None) -> List[Scholarship]:
        stmt = select(Scholarship).where(
            Scholarship.tenant_id == tenant_id,
            Scholarship.deleted_at.is_(None)
        )
        if school_id is not None:
            stmt = stmt.where(Scholarship.school_id == school_id)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create_scholarship(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: ScholarshipCreate, created_by: Optional[uuid.UUID] = None
    ) -> Scholarship:
        db_obj = Scholarship(
            tenant_id=tenant_id,
            school_id=school_id,
            name=obj_in.name,
            concession_type=obj_in.concession_type,
            value=obj_in.value,
            description=obj_in.description,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update_scholarship(self, db_obj: Scholarship, obj_in: ScholarshipUpdate | dict, updated_by: Optional[uuid.UUID] = None) -> Scholarship:
        update_data = obj_in if isinstance(obj_in, dict) else obj_in.model_dump(exclude_unset=True)
        for field in update_data:
            setattr(db_obj, field, update_data[field])
        db_obj.updated_by = updated_by
        db_obj.updated_at = datetime.now(timezone.utc)
        self.db.add(db_obj)
        return db_obj

    async def delete_scholarship(self, db_obj: Scholarship, deleted_by: Optional[uuid.UUID] = None) -> Scholarship:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj

    # --- FEE STRUCTURE CRUD ---
    async def get_fee_structure_by_comb(
        self,
        tenant_id: uuid.UUID,
        school_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        class_id: Optional[uuid.UUID],
        fee_type_id: uuid.UUID
    ) -> Optional[FeeStructure]:
        stmt = select(FeeStructure).where(
            FeeStructure.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            FeeStructure.academic_year_id == academic_year_id,
            FeeStructure.class_id == class_id,
            FeeStructure.fee_type_id == fee_type_id,
            FeeStructure.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_fee_structure_by_id(self, id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[FeeStructure]:
        stmt = select(FeeStructure).where(
            FeeStructure.id == id,
            FeeStructure.tenant_id == tenant_id,
            FeeStructure.deleted_at.is_(None)
        ).options(
            selectinload(FeeStructure.fine_rule)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def list_fee_structures(self, tenant_id: uuid.UUID, school_id: uuid.UUID) -> List[FeeStructure]:
        stmt = select(FeeStructure).where(
            FeeStructure.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            FeeStructure.deleted_at.is_(None)
        ).options(
            selectinload(FeeStructure.fine_rule)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def create_fee_structure(
        self, tenant_id: uuid.UUID, school_id: uuid.UUID, obj_in: FeeStructureCreate, created_by: Optional[uuid.UUID] = None
    ) -> FeeStructure:
        db_obj = FeeStructure(
            tenant_id=tenant_id,
            school_id=school_id,
            fee_type_id=obj_in.fee_type_id,
            academic_year_id=obj_in.academic_year_id,
            class_id=obj_in.class_id,
            amount=obj_in.amount,
            due_date=obj_in.due_date,
            description=obj_in.description,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update_fee_structure(self, db_obj: FeeStructure, obj_in: FeeStructureUpdate | dict, updated_by: Optional[uuid.UUID] = None) -> FeeStructure:
        update_data = obj_in if isinstance(obj_in, dict) else obj_in.model_dump(exclude_unset=True)
        # Exclude nested fine_rule updates (handled in service)
        update_data.pop("fine_rule", None)
        for field in update_data:
            setattr(db_obj, field, update_data[field])
        db_obj.updated_by = updated_by
        db_obj.updated_at = datetime.now(timezone.utc)
        self.db.add(db_obj)
        return db_obj

    async def delete_fee_structure(self, db_obj: FeeStructure, deleted_by: Optional[uuid.UUID] = None) -> FeeStructure:
        db_obj.deleted_at = datetime.now(timezone.utc)
        db_obj.updated_by = deleted_by
        self.db.add(db_obj)
        return db_obj

    # --- FINE RULE CRUD ---
    async def get_fine_rule_by_structure_id(self, fee_structure_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[FineRule]:
        stmt = select(FineRule).where(
            FineRule.fee_structure_id == fee_structure_id,
            FineRule.tenant_id == tenant_id,
            FineRule.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_fine_rule(
        self, tenant_id: uuid.UUID, fee_structure_id: uuid.UUID, obj_in: FineRuleCreate, created_by: Optional[uuid.UUID] = None
    ) -> FineRule:
        db_obj = FineRule(
            tenant_id=tenant_id,
            fee_structure_id=fee_structure_id,
            grace_period_days=obj_in.grace_period_days,
            fine_type=obj_in.fine_type,
            fine_value=obj_in.fine_value,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def update_fine_rule(self, db_obj: FineRule, obj_in: FineRuleUpdate | dict, updated_by: Optional[uuid.UUID] = None) -> FineRule:
        update_data = obj_in if isinstance(obj_in, dict) else obj_in.model_dump(exclude_unset=True)
        for field in update_data:
            setattr(db_obj, field, update_data[field])
        db_obj.updated_by = updated_by
        db_obj.updated_at = datetime.now(timezone.utc)
        self.db.add(db_obj)
        return db_obj

    # --- STUDENT FEE ASSIGNMENTS ---
    async def get_fee_assignment_by_id(self, id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[StudentFeeAssignment]:
        stmt = select(StudentFeeAssignment).where(
            StudentFeeAssignment.id == id,
            StudentFeeAssignment.tenant_id == tenant_id,
            StudentFeeAssignment.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_student_fee_assignments(self, student_id: uuid.UUID, tenant_id: uuid.UUID) -> List[StudentFeeAssignment]:
        stmt = select(StudentFeeAssignment).where(
            StudentFeeAssignment.student_id == student_id,
            StudentFeeAssignment.tenant_id == tenant_id,
            StudentFeeAssignment.deleted_at.is_(None)
        ).options(
            selectinload(StudentFeeAssignment.fee_structure).selectinload(FeeStructure.fee_type),
            selectinload(StudentFeeAssignment.scholarship)
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_assignment_by_student_and_structure(
        self, student_id: uuid.UUID, fee_structure_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Optional[StudentFeeAssignment]:
        stmt = select(StudentFeeAssignment).where(
            StudentFeeAssignment.student_id == student_id,
            StudentFeeAssignment.fee_structure_id == fee_structure_id,
            StudentFeeAssignment.tenant_id == tenant_id,
            StudentFeeAssignment.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_fee_assignment(
        self,
        tenant_id: uuid.UUID,
        student_id: uuid.UUID,
        fee_structure_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        assigned_amount: Decimal,
        discount_amount: Decimal,
        scholarship_id: Optional[uuid.UUID] = None,
        created_by: Optional[uuid.UUID] = None
    ) -> StudentFeeAssignment:
        db_obj = StudentFeeAssignment(
            tenant_id=tenant_id,
            student_id=student_id,
            fee_structure_id=fee_structure_id,
            academic_year_id=academic_year_id,
            assigned_amount=assigned_amount,
            scholarship_id=scholarship_id,
            discount_amount=discount_amount,
            fine_amount=Decimal("0.00"),
            paid_amount=Decimal("0.00"),
            status=FeeAssignmentStatus.UNPAID,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    # --- FEE PAYMENTS & ALLOCATIONS ---
    async def get_payment_by_id(self, payment_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[FeePayment]:
        stmt = select(FeePayment).where(
            FeePayment.id == payment_id,
            FeePayment.tenant_id == tenant_id,
            FeePayment.deleted_at.is_(None)
        ).options(
            selectinload(FeePayment.allocations).selectinload(FeePaymentAllocation.assignment),
            selectinload(FeePayment.receipt)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_payment(
        self,
        tenant_id: uuid.UUID,
        student_id: uuid.UUID,
        academic_year_id: uuid.UUID,
        amount_paid: Decimal,
        payment_method: str,
        transaction_reference: Optional[str] = None,
        remarks: Optional[str] = None,
        created_by: Optional[uuid.UUID] = None
    ) -> FeePayment:
        db_obj = FeePayment(
            tenant_id=tenant_id,
            student_id=student_id,
            academic_year_id=academic_year_id,
            amount_paid=amount_paid,
            payment_method=payment_method,
            status=PaymentStatus.COMPLETED,
            transaction_reference=transaction_reference,
            remarks=remarks,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def create_payment_allocation(
        self, payment_id: uuid.UUID, assignment_id: uuid.UUID, amount_allocated: Decimal
    ) -> FeePaymentAllocation:
        db_obj = FeePaymentAllocation(
            payment_id=payment_id,
            assignment_id=assignment_id,
            amount_allocated=amount_allocated
        )
        self.db.add(db_obj)
        return db_obj

    # --- FEE RECEIPTS ---
    async def get_next_receipt_number(self, tenant_id: uuid.UUID) -> str:
        year = datetime.now().year
        stmt = select(func.count(FeeReceipt.id)).where(FeeReceipt.tenant_id == tenant_id)
        res = await self.db.execute(stmt)
        count = res.scalar() or 0
        return f"RCPT-{year}-{count+1:06d}"

    async def create_receipt(
        self,
        tenant_id: uuid.UUID,
        payment_id: uuid.UUID,
        receipt_number: str,
        pdf_path: Optional[str] = None,
        created_by: Optional[uuid.UUID] = None
    ) -> FeeReceipt:
        db_obj = FeeReceipt(
            tenant_id=tenant_id,
            payment_id=payment_id,
            receipt_number=receipt_number,
            pdf_path=pdf_path,
            created_by=created_by,
            updated_by=created_by
        )
        self.db.add(db_obj)
        return db_obj

    async def get_receipt_by_number(self, receipt_number: str, tenant_id: uuid.UUID) -> Optional[FeeReceipt]:
        stmt = select(FeeReceipt).where(
            FeeReceipt.receipt_number == receipt_number,
            FeeReceipt.tenant_id == tenant_id,
            FeeReceipt.deleted_at.is_(None)
        ).options(
            selectinload(FeeReceipt.payment).selectinload(FeePayment.allocations).selectinload(FeePaymentAllocation.assignment)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_receipt_by_payment_id(self, payment_id: uuid.UUID, tenant_id: uuid.UUID) -> Optional[FeeReceipt]:
        stmt = select(FeeReceipt).where(
            FeeReceipt.payment_id == payment_id,
            FeeReceipt.tenant_id == tenant_id,
            FeeReceipt.deleted_at.is_(None)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    # --- REPORTS & ANALYTICS ---
    async def get_student_ledger(self, student_id: uuid.UUID, tenant_id: uuid.UUID) -> dict:
        # Load assignments
        assignments = await self.get_student_fee_assignments(student_id, tenant_id)
        
        # Load scholarships applied
        scholarship_ids = [a.scholarship_id for a in assignments if a.scholarship_id]
        scholarships = []
        if scholarship_ids:
            stmt_s = select(Scholarship).where(
                Scholarship.id.in_(scholarship_ids),
                Scholarship.tenant_id == tenant_id,
                Scholarship.deleted_at.is_(None)
            )
            res_s = await self.db.execute(stmt_s)
            scholarships = list(res_s.scalars().all())

        # Load payments
        stmt_p = select(FeePayment).where(
            FeePayment.student_id == student_id,
            FeePayment.tenant_id == tenant_id,
            FeePayment.deleted_at.is_(None)
        ).options(
            selectinload(FeePayment.allocations),
            selectinload(FeePayment.receipt)
        ).order_by(FeePayment.payment_date.desc())
        res_p = await self.db.execute(stmt_p)
        payments = list(res_p.scalars().all())

        # Balance calculations
        assigned_sum = sum(a.assigned_amount for a in assignments)
        fine_sum = sum(a.fine_amount for a in assignments)
        discount_sum = sum(a.discount_amount for a in assignments)
        
        # Only sum COMPLETED payments
        paid_sum = sum(a.paid_amount for a in assignments)
        
        closing_balance = assigned_sum + fine_sum - discount_sum - paid_sum

        return {
            "student_id": student_id,
            "opening_balance": Decimal("0.00"),
            "assignments": assignments,
            "scholarships": scholarships,
            "payments": payments,
            "closing_balance": closing_balance
        }

    async def get_daily_collection(self, tenant_id: uuid.UUID, school_id: uuid.UUID, day: date) -> Decimal:
        # Query total active payments on a specific day
        stmt = select(func.sum(FeePayment.amount_paid)).join(
            StudentFeeAssignment, StudentFeeAssignment.student_id == FeePayment.student_id
        ).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).where(
            FeePayment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            func.date(FeePayment.payment_date) == day,
            FeePayment.status == PaymentStatus.COMPLETED,
            FeePayment.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return Decimal(res.scalar() or "0.00")

    async def get_monthly_collection(self, tenant_id: uuid.UUID, school_id: uuid.UUID, year: int, month: int) -> Decimal:
        stmt = select(func.sum(FeePayment.amount_paid)).join(
            StudentFeeAssignment, StudentFeeAssignment.student_id == FeePayment.student_id
        ).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).where(
            FeePayment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            func.extract('year', FeePayment.payment_date) == year,
            func.extract('month', FeePayment.payment_date) == month,
            FeePayment.status == PaymentStatus.COMPLETED,
            FeePayment.deleted_at.is_(None)
        )
        res = await self.db.execute(stmt)
        return Decimal(res.scalar() or "0.00")

    async def get_pending_assignments(self, tenant_id: uuid.UUID, school_id: uuid.UUID) -> List[StudentFeeAssignment]:
        stmt = select(StudentFeeAssignment).join(
            FeeStructure, FeeStructure.id == StudentFeeAssignment.fee_structure_id
        ).where(
            StudentFeeAssignment.tenant_id == tenant_id,
            FeeStructure.school_id == school_id,
            StudentFeeAssignment.status.in_([FeeAssignmentStatus.UNPAID, FeeAssignmentStatus.PARTIALLY_PAID]),
            StudentFeeAssignment.deleted_at.is_(None)
        ).options(
            selectinload(StudentFeeAssignment.student),
            selectinload(StudentFeeAssignment.fee_structure).selectinload(FeeStructure.fee_type)
        )
        res = await self.db.execute(stmt)
        return list(res.scalars().all())
