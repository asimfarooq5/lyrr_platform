"""
Payment endpoints - checkout, history, subscriptions, and callbacks.

Implements the FRS Payment Module:
    - Pay-per-book access
    - Monthly / annual subscription plans
    - Credit/Debit card, Orange Money, MTN Mobile Money
    - Complete payment history
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import List, Optional
from pydantic import BaseModel, Field
from datetime import datetime

from app.core.database import get_db
from app.api.v1.endpoints.auth import get_current_active_user
from app.models.user import User
from app.models.content import Payment, SubscriptionPlan, UserSubscription
from app.models.book import Book
from app.services import payments as payment_service

router = APIRouter()


# ---- Schemas ----

class CheckoutRequest(BaseModel):
    method: str = Field(..., description="card, orange_money, or mtn_momo")
    item_type: str = Field(..., description="'book' or 'subscription'")
    book_id: Optional[str] = None
    plan_id: Optional[str] = None
    phone: Optional[str] = None


class ConfirmRequest(BaseModel):
    # In sandbox mode no gateway payload is required; in live mode a
    # gateway webhook would deliver this.
    gateway_reference: Optional[str] = None


class SubscriptionResponse(BaseModel):
    id: str
    name: str
    description: Optional[str]
    price: float
    currency: str
    interval: str
    is_active: bool

    class Config:
        from_attributes = True


class PaymentResponse(BaseModel):
    id: str
    amount: float
    currency: str
    method: str
    status: str
    reference: str
    description: Optional[str] = None
    item_type: Optional[str] = None
    book_id: Optional[str] = None
    plan_id: Optional[str] = None
    gateway_reference: Optional[str] = None
    created_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ---- Endpoints ----

@router.get("/subscriptions", response_model=List[SubscriptionResponse])
async def list_subscription_plans(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """List available subscription tiers (monthly / annual)."""
    result = await db.execute(
        select(SubscriptionPlan)
        .where(SubscriptionPlan.is_active == True)  # noqa: E712
        .order_by(SubscriptionPlan.price)
    )
    return result.scalars().all()


@router.get("/methods")
async def list_payment_methods():
    """List supported payment methods for the mobile app UI."""
    return {
        "methods": [
            {
                "id": "card",
                "name": "Credit / Debit Card",
                "requires_phone": False,
            },
            {
                "id": "orange_money",
                "name": "Orange Money",
                "requires_phone": True,
            },
            {
                "id": "mtn_momo",
                "name": "MTN Mobile Money",
                "requires_phone": True,
            },
        ]
    }


@router.post("/checkout", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def checkout(
    data: CheckoutRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Initiate a payment for a book or a subscription plan.

    For card payments in sandbox mode the charge settles immediately and the
    entitlement (book license or subscription) is granted. For mobile money the
    payment is placed awaiting confirmation on the handset.
    """
    method = (data.method or "").lower()
    if method not in payment_service.VALID_METHODS:
        raise HTTPException(status_code=400, detail=f"Unsupported method: {data.method}")

    # Quick duplicate guard
    result = await db.execute(
        select(Payment).where(
            Payment.user_id == current_user.id,
            Payment.status == payment_service.STATUS_PENDING,
        ).order_by(desc(Payment.created_at)).limit(1)
    )
    existing = result.scalars().first()
    if existing:
        # Reuse an open pending order for the same item to avoid duplicates
        same_item = (data.item_type == existing.item_type)
        if same_item and (
            (data.item_type == "book" and existing.book_id == data.book_id)
            or (data.item_type == "subscription" and existing.plan_id == data.plan_id)
        ):
            return existing

    try:
        payment = await payment_service.initiate_payment(
            db,
            user_id=current_user.id,
            method=method,
            item_type=data.item_type,
            book_id=data.book_id,
            plan_id=data.plan_id,
            phone=data.phone,
        )
    except payment_service.PaymentError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    return payment


@router.get("/history", response_model=List[PaymentResponse])
async def payment_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get the current user's complete payment history."""
    result = await db.execute(
        select(Payment)
        .where(Payment.user_id == current_user.id)
        .order_by(desc(Payment.created_at))
    )
    return result.scalars().all()


@router.get("/{payment_id}", response_model=PaymentResponse)
async def get_payment(
    payment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Get a single payment's live status."""
    result = await db.execute(
        select(Payment).where(
            Payment.id == payment_id,
            Payment.user_id == current_user.id,
        )
    )
    payment = result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    return payment


@router.post("/{payment_id}/confirm", response_model=PaymentResponse)
async def confirm_payment(
    payment_id: str,
    data: ConfirmRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Confirm a pending payment (mobile money approval callback).

    In sandbox mode this completes the order and grants the entitlement,
    simulating the notification a mobile money gateway sends on approval.
    """
    result = await db.execute(
        select(Payment).where(
            Payment.id == payment_id,
            Payment.user_id == current_user.id,
        )
    )
    payment = result.scalar_one_or_none()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")

    if payment.status == payment_service.STATUS_COMPLETED:
        return payment

    if payment.status in (payment_service.STATUS_FAILED, payment_service.STATUS_CANCELLED, payment_service.STATUS_EXPIRED):
        raise HTTPException(status_code=400, detail=f"Payment is {payment.status}")

    await payment_service.complete_payment(db, payment)
    return payment