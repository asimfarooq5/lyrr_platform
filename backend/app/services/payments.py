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


class OrangeMoneyGateway(PaymentGateway):
    """Orange Money Web Payment API (api.orange.com)."""

    method = METHOD_ORANGE_MONEY

    async def _get_access_token(self, client) -> str:
        import base64
        creds = base64.b64encode(
            f"{settings.ORANGE_MONEY_CLIENT_ID}:{settings.ORANGE_MONEY_CLIENT_SECRET}".encode()
        ).decode()
        resp = await client.post(
            f"{settings.ORANGE_MONEY_API_BASE}/oauth/v3/token",
            headers={"Authorization": f"Basic {creds}",
                     "Content-Type": "application/x-www-form-urlencoded"},
            data={"grant_type": "client_credentials"},
        )
        resp.raise_for_status()
        return resp.json()["access_token"]

    async def create_charge(self, amount, currency, reference, description,
                            customer, meta=None):
        msisdn = (customer or {}).get("phone") or (meta or {}).get("phone")
        if self.is_sandbox:
            logger.info("Sandbox orange_money charge %s for amount %.2f %s",
                        reference, amount, currency)
            return {
                "status": STATUS_AWAITING if msisdn else STATUS_PENDING,
                "gateway_reference": f"orange_money_{reference}",
                "message": "Confirm the payment on your Orange Money wallet" if msisdn
                else "Mobile money charge pending",
            }
        if not (settings.ORANGE_MONEY_CLIENT_ID and settings.ORANGE_MONEY_CLIENT_SECRET
                and settings.ORANGE_MONEY_MERCHANT_KEY):
            raise PaymentError(
                "Live Orange Money requires ORANGE_MONEY_CLIENT_ID/CLIENT_SECRET/MERCHANT_KEY."
            )

        import httpx
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                token = await self._get_access_token(client)
                resp = await client.post(
                    f"{settings.ORANGE_MONEY_API_BASE}/orange-money-webpay/v1/webpayment",
                    headers={"Authorization": f"Bearer {token}",
                             "Content-Type": "application/json", "Accept": "application/json"},
                    json={
                        "merchant_key": settings.ORANGE_MONEY_MERCHANT_KEY,
                        "currency": currency,
                        "order_id": reference,
                        "amount": amount,
                        "return_url": f"{settings.FRONTEND_URL}/payments/return",
                        "cancel_url": f"{settings.FRONTEND_URL}/payments/cancel",
                        "notif_url": f"{settings.FRONTEND_URL}/api/v1/payments/webhook/orange_money",
                        "lang": "en",
                        "reference": reference,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PaymentError(f"Orange Money charge failed: {exc}") from exc

        return {
            "status": STATUS_AWAITING,
            "gateway_reference": data.get("pay_token"),
            "payment_url": data.get("payment_url"),
            "message": "Complete the payment at the returned payment_url",
        }

    async def verify_charge(self, reference):
        if self.is_sandbox:
            return {"status": STATUS_COMPLETED, "gateway_reference": f"orange_money_{reference}"}
        if not (settings.ORANGE_MONEY_CLIENT_ID and settings.ORANGE_MONEY_CLIENT_SECRET):
            raise PaymentError("Live Orange Money is not configured.")

        import httpx
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                token = await self._get_access_token(client)
                resp = await client.get(
                    f"{settings.ORANGE_MONEY_API_BASE}/orange-money-webpay/v1/transactionstatus",
                    headers={"Authorization": f"Bearer {token}"},
                    params={"order_id": reference, "amount": None, "pay_token": reference},
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PaymentError(f"Orange Money verification failed: {exc}") from exc

        status_map = {"SUCCESS": STATUS_COMPLETED, "FAILED": STATUS_FAILED,
                      "EXPIRED": STATUS_EXPIRED, "PENDING": STATUS_AWAITING}
        return {
            "status": status_map.get(data.get("status"), STATUS_PENDING),
            "gateway_reference": reference,
        }


class MTNMoMoGateway(PaymentGateway):
    """MTN Mobile Money Collection API (momodeveloper.mtn.com)."""

    method = METHOD_MTN_MOMO

    async def _get_access_token(self, client) -> str:
        import base64
        creds = base64.b64encode(
            f"{settings.MTN_MOMO_API_USER}:{settings.MTN_MOMO_API_KEY}".encode()
        ).decode()
        resp = await client.post(
            f"{settings.MTN_MOMO_API_BASE}/collection/token/",
            headers={"Authorization": f"Basic {creds}",
                     "Ocp-Apim-Subscription-Key": settings.MTN_MOMO_SUBSCRIPTION_KEY},
        )
        resp.raise_for_status()
        return resp.json()["access_token"]

    async def create_charge(self, amount, currency, reference, description,
                            customer, meta=None):
        msisdn = (customer or {}).get("phone") or (meta or {}).get("phone")
        if self.is_sandbox:
            logger.info("Sandbox mtn_momo charge %s for amount %.2f %s",
                        reference, amount, currency)
            return {
                "status": STATUS_AWAITING if msisdn else STATUS_PENDING,
                "gateway_reference": f"mtn_momo_{reference}",
                "message": "Confirm the payment on your MTN MoMo wallet" if msisdn
                else "Mobile money charge pending",
            }
        if not (settings.MTN_MOMO_SUBSCRIPTION_KEY and settings.MTN_MOMO_API_USER
                and settings.MTN_MOMO_API_KEY):
            raise PaymentError(
                "Live MTN MoMo requires MTN_MOMO_SUBSCRIPTION_KEY/API_USER/API_KEY."
            )
        if not msisdn:
            raise PaymentError("A phone number is required for MTN Mobile Money.")

        import httpx
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                token = await self._get_access_token(client)
                headers = {
                    "Authorization": f"Bearer {token}",
                    "X-Reference-Id": reference,
                    "X-Target-Environment": settings.MTN_MOMO_TARGET_ENV,
                    "Ocp-Apim-Subscription-Key": settings.MTN_MOMO_SUBSCRIPTION_KEY,
                    "Content-Type": "application/json",
                }
                resp = await client.post(
                    f"{settings.MTN_MOMO_API_BASE}/collection/v1_0/requesttopay",
                    headers=headers,
                    json={
                        "amount": str(amount),
                        "currency": currency,
                        "externalId": reference,
                        "payer": {"partyIdType": "MSISDN", "partyId": msisdn},
                        "payerMessage": description or "LYRR purchase",
                        "payeeNote": description or "LYRR purchase",
                    },
                )
                resp.raise_for_status()
        except httpx.HTTPError as exc:
            raise PaymentError(f"MTN MoMo charge failed: {exc}") from exc

        return {
            "status": STATUS_AWAITING,
            "gateway_reference": reference,  # MTN echoes back X-Reference-Id
            "message": "Approve the payment prompt on your phone",
        }

    async def verify_charge(self, reference):
        if self.is_sandbox:
            return {"status": STATUS_COMPLETED, "gateway_reference": f"mtn_momo_{reference}"}
        if not (settings.MTN_MOMO_SUBSCRIPTION_KEY and settings.MTN_MOMO_API_USER
                and settings.MTN_MOMO_API_KEY):
            raise PaymentError("Live MTN MoMo is not configured.")

        import httpx
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                token = await self._get_access_token(client)
                resp = await client.get(
                    f"{settings.MTN_MOMO_API_BASE}/collection/v1_0/requesttopay/{reference}",
                    headers={
                        "Authorization": f"Bearer {token}",
                        "X-Target-Environment": settings.MTN_MOMO_TARGET_ENV,
                        "Ocp-Apim-Subscription-Key": settings.MTN_MOMO_SUBSCRIPTION_KEY,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise PaymentError(f"MTN MoMo verification failed: {exc}") from exc

        status_map = {"SUCCESSFUL": STATUS_COMPLETED, "FAILED": STATUS_FAILED,
                      "PENDING": STATUS_AWAITING}
        return {
            "status": status_map.get(data.get("status"), STATUS_PENDING),
            "gateway_reference": reference,
        }


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