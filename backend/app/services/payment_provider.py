import uuid
from abc import ABC, abstractmethod
from decimal import Decimal
from typing import Dict, Any, Optional
from fastapi import HTTPException, status

from app.models.school import School

class PaymentProviderException(Exception):
    """Base exception for payment provider operations."""
    pass

class PaymentOrder:
    def __init__(
        self,
        order_id: str,
        amount: Decimal,
        currency: str,
        gateway_name: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> None:
        self.order_id = order_id
        self.amount = amount
        self.currency = currency
        self.gateway_name = gateway_name
        self.metadata = metadata or {}

class PaymentVerificationResult:
    def __init__(
        self,
        success: bool,
        payment_id: str,
        amount: Decimal,
        gateway_name: str,
        raw_response: Dict[str, Any],
        error_message: Optional[str] = None
    ) -> None:
        self.success = success
        self.payment_id = payment_id
        self.amount = amount
        self.gateway_name = gateway_name
        self.raw_response = raw_response
        self.error_message = error_message

class PaymentProvider(ABC):
    """
    Abstract contract for pluggable payment gateways (Razorpay, Stripe, Cashfree, etc.).
    Release 2.0 provides this architectural foundation with strict feature flagging.
    """
    @abstractmethod
    async def create_order(
        self,
        amount: Decimal,
        currency: str,
        student_id: uuid.UUID,
        school_id: uuid.UUID,
        metadata: Optional[Dict[str, Any]] = None
    ) -> PaymentOrder:
        pass

    @abstractmethod
    async def verify_payment(
        self,
        payload: Dict[str, Any],
        signature: Optional[str] = None
    ) -> PaymentVerificationResult:
        pass

    @abstractmethod
    async def refund(
        self,
        payment_id: str,
        amount: Decimal,
        reason: Optional[str] = None
    ) -> Dict[str, Any]:
        pass

class OfflineMockPaymentProvider(PaymentProvider):
    """
    Stub offline payment provider used when online payments are feature-flagged off
    or running in mock sandbox tests.
    """
    async def create_order(
        self,
        amount: Decimal,
        currency: str,
        student_id: uuid.UUID,
        school_id: uuid.UUID,
        metadata: Optional[Dict[str, Any]] = None
    ) -> PaymentOrder:
        return PaymentOrder(
            order_id=f"mock_ord_{uuid.uuid4().hex[:12]}",
            amount=amount,
            currency=currency,
            gateway_name="OFFLINE_MOCK",
            metadata=metadata
        )

    async def verify_payment(
        self,
        payload: Dict[str, Any],
        signature: Optional[str] = None
    ) -> PaymentVerificationResult:
        return PaymentVerificationResult(
            success=True,
            payment_id=f"mock_pay_{uuid.uuid4().hex[:12]}",
            amount=Decimal(str(payload.get("amount", "0.00"))),
            gateway_name="OFFLINE_MOCK",
            raw_response=payload
        )

    async def refund(
        self,
        payment_id: str,
        amount: Decimal,
        reason: Optional[str] = None
    ) -> Dict[str, Any]:
        return {
            "status": "REFUNDED",
            "refund_id": f"mock_rf_{uuid.uuid4().hex[:12]}",
            "payment_id": payment_id,
            "amount": str(amount),
            "reason": reason
        }

def assert_online_payments_enabled(school: School) -> None:
    """
    Enforces the Release 2.0 safety rule:
    Online fee payments are strictly disabled by default.
    Only permitted if explicitly set in school settings JSON.
    """
    settings = school.settings or {}
    if not settings.get("online_fee_payment_enabled", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Online payments are currently unavailable for this school."
        )

def get_payment_provider(school: School) -> PaymentProvider:
    """
    Resolves the appropriate payment provider instance for a school.
    Guards with feature-flag validation.
    """
    assert_online_payments_enabled(school)
    # When enabled in a future release, gateway configuration is read from school.settings
    return OfflineMockPaymentProvider()
