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
from sqlalchemy.exc import IntegrityError

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
    """Credit/Debit card payments via Stripe."""

    method = METHOD_CARD

    # Stripe uses zero-decimal amounts for these currencies (no "cents").
    _ZERO_DECIMAL_CURRENCIES = {"xaf", "xof", "jpy", "krw", "vnd"}

    def _stripe_amount(self, amount: float, currency: str) -> int:
        if currency.lower() in self._ZERO_DECIMAL_CURRENCIES:
            return int(round(amount))
        return int(round(amount * 100))

    async def create_charge(self, amount, currency, reference, description,
                            customer, meta=None):
        if self.is_sandbox:
            # Simulate a card that settles after explicit verify.
            return {
                "status": STATUS_AWAITING,
                "gateway_reference": f"card_{reference}",
                "message": "Card charge awaiting confirmation",
            }
        if not settings.STRIPE_SECRET_KEY:
            raise PaymentError("Live card processing requires STRIPE_SECRET_KEY to be set.")

        import stripe
        from starlette.concurrency import run_in_threadpool

        stripe.api_key = settings.STRIPE_SECRET_KEY
        try:
            intent = await run_in_threadpool(
                stripe.PaymentIntent.create,
                amount=self._stripe_amount(amount, currency),
                currency=currency.lower(),
                description=description,
                metadata={"reference": reference, **(meta or {})},
                receipt_email=(customer or {}).get("email"),
            )
        except Exception as exc:
            raise PaymentError(f"Stripe charge failed: {exc}") from exc

        return {
            "status": STATUS_AWAITING,
            "gateway_reference": intent["id"],
            "client_secret": intent["client_secret"],
            "message": "Confirm the card payment using the returned client secret",
        }

    async def verify_charge(self, reference):
        if self.is_sandbox:
            return {"status": STATUS_COMPLETED, "gateway_reference": f"card_{reference}"}
        if not settings.STRIPE_SECRET_KEY:
            raise PaymentError("Live card processing requires STRIPE_SECRET_KEY to be set.")

        import stripe
        from starlette.concurrency import run_in_threadpool

        stripe.api_key = settings.STRIPE_SECRET_KEY
        try:
            intent = await run_in_threadpool(stripe.PaymentIntent.retrieve, reference)
        except Exception as exc:
            raise PaymentError(f"Stripe verification failed: {exc}") from exc

        status_map = {
            "succeeded": STATUS_COMPLETED,
            "processing": STATUS_AWAITING,
            "requires_payment_method": STATUS_FAILED,
            "requires_action": STATUS_AWAITING,
            "canceled": STATUS_CANCELLED,
        }
        return {
            "status": status_map.get(intent["status"], STATUS_PENDING),
            "gateway_reference": intent["id"],
        }


class CampayGateway(PaymentGateway):
    """Mobile Money collection via CamPay (MTN + Orange, Cameroon).

    CamPay is the aggregator used for both carriers: the phone number
    determines the operator, so MTN and Orange share this one integration.
    Docs: https://demo.campay.net/en/developer/

    Flow:
      1. POST /token/            -> short-lived bearer token
      2. POST /collect/          -> prompts the payer on their handset; returns
                                    a ``reference`` (UUID4)
      3. GET  /transaction/{ref}/ -> PENDING | SUCCESSFUL | FAILED
      4. Webhook (configured in the CamPay app) notifies on settle.
    """

    # CamPay expects the MSISDN with country code and no "+", e.g. 2376XXXXXXXX.
    _COUNTRY_CODE = "237"

    def _normalise_phone(self, raw: Optional[str]) -> Optional[str]:
        if not raw:
            return None
        digits = "".join(ch for ch in str(raw) if ch.isdigit())
        if not digits:
            return None
        if digits.startswith(self._COUNTRY_CODE):
            return digits
        if digits.startswith("0"):
            digits = digits[1:]
        return f"{self._COUNTRY_CODE}{digits}"

    async def _get_token(self, client) -> str:
        """Return a bearer token: the permanent app token if set, else one
        minted from the app username/password."""
        if settings.CAMPAY_PERMANENT_TOKEN:
            return settings.CAMPAY_PERMANENT_TOKEN
        if not (settings.CAMPAY_USERNAME and settings.CAMPAY_PASSWORD):
            raise PaymentError(
                "CamPay requires CAMPAY_PERMANENT_TOKEN or "
                "CAMPAY_USERNAME + CAMPAY_PASSWORD."
            )
        resp = await client.post(
            f"{settings.CAMPAY_BASE_URL}/token/",
            json={
                "username": settings.CAMPAY_USERNAME,
                "password": settings.CAMPAY_PASSWORD,
            },
        )
        resp.raise_for_status()
        return resp.json()["token"]

    async def create_charge(self, amount, currency, reference, description,
                            customer, meta=None):
        phone = self._normalise_phone(
            (customer or {}).get("phone") or (meta or {}).get("phone")
        )
        if self.is_sandbox:
            logger.info("Sandbox %s charge %s for amount %.2f %s (phone=%s)",
                        self.method, reference, amount, currency, phone)
            return {
                "status": STATUS_AWAITING if phone else STATUS_PENDING,
                "gateway_reference": f"{self.method}_{reference}",
                "message": "Confirm the payment on your mobile money wallet"
                           if phone else "A phone number is required",
            }

        if not phone:
            raise PaymentError("A phone number is required for mobile money.")

        import httpx
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                token = await self._get_token(client)
                resp = await client.post(
                    f"{settings.CAMPAY_BASE_URL}/collect/",
                    headers={
                        "Authorization": f"Token {token}",
                        "Content-Type": "application/json",
                    },
                    json={
                        # CamPay rejects decimals — send an integer string.
                        "amount": str(int(round(amount))),
                        "currency": currency,
                        "from": phone,
                        "description": description or "LYRR purchase",
                        # Idempotency key: re-using it returns the first result.
                        "external_reference": reference,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PaymentError(f"CamPay charge failed: {exc}") from exc

        gateway_reference = data.get("reference")
        if not gateway_reference:
            raise PaymentError("CamPay did not return a transaction reference.")

        return {
            "status": STATUS_AWAITING,
            "gateway_reference": gateway_reference,
            "message": "Approve the payment prompt on your phone",
        }

    async def verify_charge(self, reference):
        """Look up a CamPay transaction by its reference."""
        if self.is_sandbox:
            return {"status": STATUS_COMPLETED,
                    "gateway_reference": f"{self.method}_{reference}"}

        import httpx
        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                token = await self._get_token(client)
                resp = await client.get(
                    f"{settings.CAMPAY_BASE_URL}/transaction/{reference}/",
                    headers={
                        "Authorization": f"Token {token}",
                        "Content-Type": "application/json",
                    },
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PaymentError(f"CamPay verification failed: {exc}") from exc

        # CamPay: PENDING | SUCCESSFUL | FAILED
        status_map = {
            "SUCCESSFUL": STATUS_COMPLETED,
            "SUCCESS": STATUS_COMPLETED,
            "FAILED": STATUS_FAILED,
            "PENDING": STATUS_AWAITING,
        }
        return {
            "status": status_map.get(str(data.get("status", "")).upper(), STATUS_PENDING),
            "gateway_reference": data.get("reference", reference),
            "operator": data.get("operator"),
            "reason": data.get("reason"),
        }


class OrangeMoneyGateway(CampayGateway):
    """Orange Money via CamPay (operator is derived from the phone number)."""

    method = METHOD_ORANGE_MONEY


class MTNMoMoGateway(CampayGateway):
    """MTN Mobile Money via CamPay (operator is derived from the phone number)."""

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
        # Live-mode gateways return client-side checkout data the app needs
        # to finish the payment (Stripe client_secret, Orange payment_url).
        extra = {k: v for k, v in result.items()
                 if k in ("client_secret", "payment_url") and v}
        if extra:
            payment.payment_metadata = {**(payment.payment_metadata or {}), **extra}
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
    """Create/refresh the UserBook license for a purchased book.

    (user_id, book_id) is unique, so a concurrent grant is caught and turned
    into an update rather than raising.
    """
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
        try:
            async with db.begin_nested():
                db.add(user_book)
        except IntegrityError:
            # Lost the race — the row now exists; fall back to updating it.
            user_book = (await db.execute(
                select(UserBook).where(
                    UserBook.user_id == user_id, UserBook.book_id == book_id
                )
            )).scalar_one()
            user_book.license_type = "purchase"
            user_book.expires_at = None
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