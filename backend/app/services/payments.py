"""
Payment services - gateway abstraction and order fulfilment.

Supports pay-per-book and subscription plans across three payment
methods: credit/debit card, Orange Money, and MTN Mobile Money.

Gateways run in sandbox mode by default (no real money moves) so the
full checkout flow works end to end locally. Set PAYMENT_MODE=live and
configure provider credentials to enable real charge processing.
"""

from __future__ import annotations

import abc
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.core.security import generate_drm_key
from app.models.content import Payment, SubscriptionPlan, UserSubscription
from app.models.book import UserBook

logger = logging.getLogger(__name__)

# Order expiry (minutes) – a checkout must be paid before this window closes.
ORDER_TTL_MINUTES = 30

# Payment method identifiers used by the API and stored in the DB.
METHOD_CARD = "card"
METHOD_ORANGE_MONEY = "orange_money"
METHOD_MTN_MOMO = "mtn_momo"

# Payment statuses
STATUS_PENDING = "pending"
STATUS_AWAITING = "awaiting_confirmation"
STATUS_COMPLETED = "completed"
STATUS_FAILED = "failed"
STATUS_CANCELLED = "cancelled"
STATUS_EXPIRED = "expired"
STATUS_REFUNDED = "refunded"

VALID_METHODS = {METHOD_CARD, METHOD_ORANGE_MONEY, METHOD_MTN_MOMO}


class PaymentError(Exception):
    """Raised when a payment cannot be processed."""


class PaymentGateway(abc.ABC):
    """Base class for all payment gateways."""

    method: str = ""

    def __init__(self) -> None:
        self.mode = getattr(settings, "PAYMENT_MODE", "sandbox")

    @property
    def is_sandbox(self) -> bool:
        return self.mode != "live"

    @abc.abstractmethod
    async def create_charge(
        self,
        amount: float,
        currency: str,
        reference: str,
        description: str,
        customer: Dict,
        meta: Optional[Dict] = None,
    ) -> Dict:
        """Initiate a charge for the given amount. Returns gateway details."""

    @abc.abstractmethod
    async def verify_charge(self, reference: str) -> Dict:
        """Check the status of a previously initiated charge."""


class CardGateway(PaymentGateway):
    """Credit/Debit card payments via a generic acquiring processor."""

    method = METHOD_CARD

    async def create_charge(self, amount, currency, reference, description,
                            customer, meta=None):
        if self.is_sandbox:
            # Simulate a card that settles after explicit verify.
            return {
                "status": STATUS_AWAITING,
                "gateway_reference": f"card_{reference}",
                "message": "Card charge awaiting confirmation",
            }
        # In live mode this would call a PSP (Stripe/Checkout.com/etc.).
        raise PaymentError(
            "Live card processing is not configured. Set PAYMENT_MODE=sandbox "
            "for the local checkout flow."
        )

    async def verify_charge(self, reference):
        if self.is_sandbox:
            return {"status": STATUS_COMPLETED, "gateway_reference": f"card_{reference}"}
        raise PaymentError("Live card processing is not configured.")


class MobileMoneyGateway(PaymentGateway):
    """Base Mobile Money gateway (Orange Money / MTN MoMo share the flow)."""

    method = ""

    async def create_charge(self, amount, currency, reference, description,
                            customer, meta=None):
        msisdn = (customer or {}).get("phone") or (meta or {}).get("phone")
        if self.is_sandbox:
            logger.info(
                "Sandbox %s charge %s for amount %.2f %s",
                self.method, reference, amount, currency,
            )
            # Mobil money requires the user to approve on their handset; the
            # charge is placed in awaiting state and confirmed by callback.
            return {
                "status": STATUS_AWAITING if msisdn else STATUS_PENDING,
                "gateway_reference": f"{self.method}_{reference}",
                "message": "Confirm the payment on your mobile money wallet" if msisdn
                else "Mobile money charge pending",
            }
        raise PaymentError(f"Live {self.method} is not configured.")

    async def verify_charge(self, reference):
        if self.is_sandbox:
            return {"status": STATUS_COMPLETED, "gateway_reference": f"{self.method}_{reference}"}
        raise PaymentError(f"Live {self.method} is not configured.")


class OrangeMoneyGateway(MobileMoneyGateway):
    method = METHOD_ORANGE_MONEY


class MTNMoMoGateway(MobileMoneyGateway):
    method = METHOD_MTN_MOMO


def get_gateway(method: str) -> PaymentGateway:
    """Return the gateway adapter for a payment method."""
    method = (method or "").lower()
    if method == METHOD_CARD:
        return CardGateway()
    if method == METHOD_ORANGE_MONEY:
        return OrangeMoneyGateway()
    if method == METHOD_MTN_MOMO:
        return MTNMoMoGateway()
    raise PaymentError(f"Unsupported payment method: {method}")


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _plan_expiry(interval: str) -> datetime:
    """Compute the subscription expiry for a plan interval."""
    now = _utcnow().replace(microsecond=0)
    interval = (interval or "").lower()
    if interval == "annual" or interval == "year" or interval == "yearly":
        return now + timedelta(days=365)
    # monthly is the default
    return now + timedelta(days=30)


async def create_checkout(
    db: AsyncSession,
    *,
    user_id: str,
    method: str,
    item_type: str,            # "book" or "subscription"
    book_id: Optional[str] = None,
    plan_id: Optional[str] = None,
    customer: Optional[Dict] = None,
    metadata: Optional[Dict] = None,
) -> Payment:
    """Create a pending Payment (checkout) for a book or subscription plan.

    Returns the Payment row; the client then displays payment instructions
    and the stored callback/verify path settles the order.
    """
    if method not in VALID_METHODS:
        raise PaymentError(f"Unsupported payment method: {method}")

    item_type = (item_type or "").lower()
    description = None
    amount: Optional[float] = None
    currency = getattr(settings, "PAYMENT_CURRENCY", "XAF")

    if item_type == "book":
        if not book_id:
            raise PaymentError("book_id is required for a book checkout")
        # Load book price
        from app.models.book import Book
        result = await db.execute(select(Book).where(Book.id == book_id))
        book = result.scalar_one_or_none()
        if not book:
            raise PaymentError("Book not found")
        amount = getattr(book, "price", None) or getattr(settings, "DEFAULT_BOOK_PRICE", 0.0)
        description = f"Purchase: {book.title}"
    elif item_type == "subscription":
        if not plan_id:
            raise PaymentError("plan_id is required for a subscription checkout")
        result = await db.execute(
            select(SubscriptionPlan).where(
                SubscriptionPlan.id == plan_id
            )
        )
        plan = result.scalar_one_or_none()
        if not plan or not plan.is_active:
            raise PaymentError("Subscription plan not found or inactive")
        amount = plan.price
        currency = plan.currency or currency
        description = f"Subscription: {plan.name} ({plan.interval})"
    else:
        raise PaymentError("item_type must be 'book' or 'subscription'")

    reference = f"LYRR{uuid.uuid4().hex[:16].upper()}"

    payment = Payment(
        user_id=user_id,
        amount=amount,
        currency=currency,
        method=method,
        status=STATUS_PENDING,
        reference=reference,
        description=description,
        item_type=item_type,
        book_id=book_id,
        plan_id=plan_id,
        payment_metadata=metadata or {},
    )
    db.add(payment)
    await db.commit()
    await db.refresh(payment)
    return payment


async def initiate_payment(
    db: AsyncSession,
    *,
    user_id: str,
    method: str,
    item_type: str,
    book_id: Optional[str] = None,
    plan_id: Optional[str] = None,
    phone: Optional[str] = None,
) -> Payment:
    """Create a checkout and ask the gateway to initiate a charge.

    Returns the Payment with gateway status applied.
    """
    payment = await create_checkout(
        db,
        user_id=user_id,
        method=method,
        item_type=item_type,
        book_id=book_id,
        plan_id=plan_id,
        customer={"phone": phone} if phone else None,
    )
    if not payment.reference:
        raise PaymentError("Failed to create payment")

    gateway = get_gateway(method)
    try:
        result = await gateway.create_charge(
            amount=payment.amount,
            currency=payment.currency,
            reference=payment.reference,
            description=payment.description or "",
            customer={"phone": phone} if phone else {},
            meta={"phone": phone} if phone else {},
        )
        status = result.get("status", STATUS_PENDING)
        payment.status = status
        payment.gateway_reference = result.get("gateway_reference")
        # For card sandbox settlement, auto-complete so checkout works offline.
        if method == METHOD_CARD and status == STATUS_AWAITING and payment.is_auto_confirmable():
            payment.status = STATUS_COMPLETED
            await complete_payment(db, payment, auto=True)
            return payment
        await db.commit()
        await db.refresh(payment)
        return payment
    except PaymentError as exc:
        payment.status = STATUS_FAILED
        await db.commit()
        await db.refresh(payment)
        raise exc


async def complete_payment(
    db: AsyncSession,
    payment: Payment,
    *,
    auto: bool = False,
) -> Payment:
    """Settle a payment and grant the associated entitlement (book or subscription).

    Idempotent: if the payment is already completed, nothing changes.
    """
    if payment.status == STATUS_COMPLETED:
        return payment

    payment.status = STATUS_COMPLETED
    if getattr(payment, "completed_at", None) is None:
        payment.completed_at = _utcnow()

    if payment.item_type == "book" and payment.book_id:
        await _grant_book_access(db, payment.user_id, payment.book_id)
    elif payment.item_type == "subscription" and payment.plan_id:
        await _grant_subscription(db, payment.user_id, payment.plan_id)

    await db.commit()
    await db.refresh(payment)
    return payment


async def _grant_book_access(db: AsyncSession, user_id: str, book_id: str) -> None:
    """Create/refresh the UserBook license for a purchased book."""
    result = await db.execute(
        select(UserBook).where(
            UserBook.user_id == user_id, UserBook.book_id == book_id
        )
    )
    user_book = result.scalar_one_or_none()
    if not user_book:
        user_book = UserBook(
            user_id=user_id,
            book_id=book_id,
            license_key=generate_drm_key(book_id, user_id, "payment"),
            license_type="purchase",
            expires_at=None,
        )
        db.add(user_book)
    else:
        user_book.license_type = "purchase"
        user_book.expires_at = None
        user_book.license_key = user_book.license_key or generate_drm_key(
            book_id, user_id, "payment"
        )


async def _grant_subscription(db: AsyncSession, user_id: str, plan_id: str) -> None:
    """Create or extend a user subscription from a plan."""
    result = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id)
    )
    plan = result.scalar_one_or_none()
    if not plan:
        return

    # Find an active subscription for this plan to extend, else create new.
    result = await db.execute(
        select(UserSubscription).where(
            UserSubscription.user_id == user_id,
            UserSubscription.status == "active",
        ).order_by(UserSubscription.expires_at.desc()).limit(1)
    )
    active = result.scalars().first()

    if active:
        base = active.expires_at if active.expires_at and active.expires_at > _utcnow() else _utcnow()
        new_expiry = base + timedelta(days=365 if (plan.interval or "monthly").lower() in ("annual", "year", "yearly") else 30)
        active.expires_at = new_expiry
    else:
        from app.models.content import UserSubscription as _US
        sub = _US(
            user_id=user_id,
            plan_id=plan_id,
            status="active",
            expires_at=_plan_expiry(plan.interval),
        )
        db.add(sub)