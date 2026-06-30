"""
Admin portal routes - Jinja2 templates served by FastAPI
"""

from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from typing import Optional
from datetime import datetime, timedelta
import uuid

from app.core.database import get_db
from app.core.security import verify_password, create_access_token, decode_token
from app.models.user import User
from app.models.book import Book
from app.models.sync import SyncCheckpoint

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")


async def _get_admin(request: Request, db: AsyncSession) -> Optional[User]:
    token = request.cookies.get("admin_token")
    if not token:
        return None
    try:
        payload = decode_token(token)
        if payload and payload.get("type") == "admin":
            result = await db.execute(select(User).where(User.id == payload["sub"]))
            user = result.scalar_one_or_none()
            if user and user.is_admin:
                return user
    except Exception:
        pass
    return None


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    return templates.TemplateResponse("admin/login.html", {"request": request, "error": None})


@router.post("/login")
async def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.email == username))
    user = result.scalar_one_or_none()

    if not user or not user.is_admin or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(
            "admin/login.html",
            {"request": request, "error": "Invalid credentials or not an admin"},
        )

    token = create_access_token(data={"sub": user.id, "type": "admin"})
    resp = RedirectResponse(url="/admin/dashboard", status_code=302)
    resp.set_cookie(key="admin_token", value=token, httponly=True, max_age=3600, path="/admin")
    return resp


@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")

    user_count = await db.scalar(select(func.count(User.id))) or 0
    book_count = await db.scalar(select(func.count(Book.id))) or 0
    yesterday = datetime.utcnow() - timedelta(hours=24)
    sync_count = await db.scalar(
        select(func.count(SyncCheckpoint.id)).where(SyncCheckpoint.last_sync_at >= yesterday)
    ) or 0

    return templates.TemplateResponse("admin/dashboard.html", {
        "request": request,
        "page": "dashboard",
        "stats": {"total_books": book_count, "total_users": user_count, "syncs_today": sync_count},
    })


@router.get("/books", response_class=HTMLResponse)
async def books_page(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")

    result = await db.execute(select(Book).order_by(Book.created_at.desc()).limit(100))
    books = result.scalars().all()

    return templates.TemplateResponse("admin/books.html", {
        "request": request,
        "page": "books",
        "books": books,
    })


@router.post("/books")
async def create_book(
    request: Request,
    title: str = Form(...),
    author: str = Form(...),
    description: str = Form(""),
    language: str = Form("en"),
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")

    book = Book(
        id=str(uuid.uuid4()),
        title=title,
        author=author,
        description=description,
        language=language,
        status="published",
    )
    db.add(book)
    await db.commit()
    return RedirectResponse(url="/admin/books", status_code=302)


@router.post("/books/{book_id}/delete")
async def delete_book(
    book_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")

    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if book:
        await db.delete(book)
        await db.commit()
    return RedirectResponse(url="/admin/books", status_code=302)


@router.get("/users", response_class=HTMLResponse)
async def users_page(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")

    result = await db.execute(select(User).order_by(User.created_at.desc()).limit(100))
    users = result.scalars().all()

    return templates.TemplateResponse("admin/users.html", {
        "request": request,
        "page": "users",
        "users": [
            {
                "email": u.email,
                "is_active": u.is_active,
                "is_admin": u.is_admin,
                "is_verified": u.is_verified,
                "created_at": str(u.created_at) if u.created_at else "",
            }
            for u in users
        ],
    })
