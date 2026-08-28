"""
Admin portal routes - full CRUD for books, users, subscriptions, categories, analytics
Serves Jinja2 templates with server-side rendering
"""

from fastapi import APIRouter, Depends, HTTPException, Request, Form, UploadFile, File
from fastapi.responses import RedirectResponse, HTMLResponse, Response
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from sqlalchemy.orm import selectinload
from typing import Optional
from datetime import datetime, timedelta, timezone
import uuid
import os
import csv
import io
import shutil
import zipfile
import xml.etree.ElementTree as ET
from bs4 import BeautifulSoup

from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.core.security import verify_password, create_access_token, decode_token, get_password_hash
from app.core.csrf import generate_csrf_token, verify_csrf_token, revoke_csrf_tokens
from app.models.user import User
from app.models.book import Book, BookMedia, BookStatus, Chapter
from app.models.content import Category, Author, SubscriptionPlan, UserSubscription, Payment

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
STORAGE_DIR = os.path.join(BASE_DIR, "storage")
AUDIO_DIR = os.path.join(STORAGE_DIR, "audio")
COVERS_DIR = os.path.join(STORAGE_DIR, "covers")
os.makedirs(AUDIO_DIR, exist_ok=True)
os.makedirs(COVERS_DIR, exist_ok=True)

# ---- File validation constants ----
ALLOWED_AUDIO_EXTS = {".mp3", ".m4a", ".wav", ".flac", ".aac", ".ogg"}
ALLOWED_IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def format_number(value):
    try:
        return "{:,.0f}".format(float(value))
    except (ValueError, TypeError):
        return str(value)

templates.env.filters["format_number"] = format_number


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


async def _inject_csrf(context: dict, request: Request) -> dict:
    """Inject CSRF token into template context"""
    if settings.CSRF_ENABLED:
        session_id = request.cookies.get("admin_token", "") or "anonymous"
        context["csrf_token"] = await generate_csrf_token(session_id)
    else:
        context["csrf_token"] = ""
    return context


async def _verify_csrf(request: Request) -> bool:
    """Verify CSRF token from form data against stored session token"""
    if not settings.CSRF_ENABLED:
        return True
    form = await request.form()
    token = form.get("csrf_token", "")
    session_id = request.cookies.get("admin_token", "")
    if not await verify_csrf_token(session_id, token):
        raise HTTPException(status_code=403, detail="CSRF validation failed. Please submit the form again.")
    return True


async def _validate_upload(
    file: UploadFile,
    allowed_exts: set,
    max_size_mb: int,
) -> tuple[str, bytes]:
    """Validate and sanitize an uploaded file. Returns (safe_filename, content)."""
    # Check extension
    original_name = file.filename or ""
    ext = os.path.splitext(original_name)[1].lower()
    if ext not in allowed_exts:
        raise HTTPException(
            status_code=400,
            detail=f"File type '{ext}' is not allowed. Allowed: {', '.join(sorted(allowed_exts))}",
        )

    # Read content with a size cap
    max_bytes = max_size_mb * 1024 * 1024
    content = await file.read(max_bytes + 1)

    # Check size
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"File too large ({len(content) / 1024 / 1024:.1f} MB). Maximum: {max_size_mb} MB",
        )

    # Sanitize filename — UUID + extension only
    safe_name = f"{uuid.uuid4().hex}{ext}"
    return safe_name, content


# ===== AUTH =====

@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    return templates.TemplateResponse(request, "admin/login.html", {"request": request, "error": None})

@router.post("/login")
@limiter.limit("10/minute")
async def login(request: Request, username: str = Form(...), password: str = Form(...),
                db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == username))
    user = result.scalar_one_or_none()
    if not user or not user.is_admin or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(request, "admin/login.html", {"request": request, "error": "Invalid credentials"})
    token = create_access_token(data={"sub": user.id, "type": "admin"})
    resp = RedirectResponse(url="/admin/dashboard", status_code=302)
    resp.set_cookie(key="admin_token", value=token, httponly=True, max_age=3600, path="/admin",
                    samesite="lax")
    return resp

@router.post("/logout")
async def logout(request: Request, _: bool = Depends(_verify_csrf)):
    """Log out of the admin portal"""
    session_id = request.cookies.get("admin_token", "")
    await revoke_csrf_tokens(session_id)
    resp = RedirectResponse(url="/admin/login", status_code=302)
    resp.delete_cookie(key="admin_token", path="/admin")
    return resp

@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    stats = {
        "users": (await db.scalar(select(func.count(User.id)))) or 0,
        "books": (await db.scalar(select(func.count(Book.id)))) or 0,
        "subscriptions": (await db.scalar(select(func.count(UserSubscription.id)))) or 0,
    }
    payments = (await db.execute(select(Payment).where(Payment.status == "completed"))).scalars().all()
    stats["revenue"] = int(sum(p.amount for p in payments))
    stats["revenue_month"] = int(sum(
        p.amount for p in payments
        if p.created_at and p.created_at > datetime.now(timezone.utc) - timedelta(days=30)
    ))
    ctx = {"request": request, "page": "dashboard", "stats": stats}
    return templates.TemplateResponse(request, "admin/dashboard.html", await _inject_csrf(ctx, request))

# ===== BOOKS =====

@router.get("/books", response_class=HTMLResponse)
async def books_page(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(Book).options(selectinload(Book.media)).order_by(Book.created_at.desc()).limit(100))
    books = result.scalars().all()
    ctx = {"request": request, "page": "books", "books": books}
    return templates.TemplateResponse(request, "admin/books.html", await _inject_csrf(ctx, request))

@router.post("/books")
async def create_book(request: Request, title: str = Form(...), author: str = Form(""),
                      description: str = Form(""), language: str = Form("en"),
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    book = Book(id=str(uuid.uuid4()), title=title, author=author or "Unknown",
                description=description, language=language, status=BookStatus.PUBLISHED)
    db.add(book)
    await db.commit()
    return RedirectResponse(url="/admin/books", status_code=302)

@router.get("/books/{book_id}")
async def edit_book_page(book_id: str, request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(Book).options(selectinload(Book.media)).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if not book:
        return RedirectResponse(url="/admin/books")
    ctx = {"request": request, "page": "books", "book": book}
    return templates.TemplateResponse(request, "admin/book_detail.html", await _inject_csrf(ctx, request))

@router.post("/books/{book_id}")
async def update_book(book_id: str, request: Request, title: str = Form(...),
                      author: str = Form(""), description: str = Form(""),
                      book_type: str = Form("fiction"),
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if not book:
        return RedirectResponse(url="/admin/books")
    book.title = title
    book.author = author or book.author
    book.description = description
    book.book_type = book_type
    await db.commit()
    return RedirectResponse(url=f"/admin/books/{book_id}", status_code=302)

@router.post("/books/{book_id}/cover")
async def upload_cover(book_id: str, request: Request, file: UploadFile = File(...),
                       db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    
    safe_name, content = await _validate_upload(file, ALLOWED_IMAGE_EXTS, settings.MAX_COVER_SIZE_MB)
    filename = f"{book_id}-{safe_name}"
    path = os.path.join(COVERS_DIR, filename)
    with open(path, "wb") as f:
        f.write(content)

    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if not book:
        return RedirectResponse(url="/admin/books")
    book.cover_url = f"/media/covers/{filename}"
    await db.commit()
    return RedirectResponse(url=f"/admin/books/{book_id}", status_code=302)

@router.post("/books/{book_id}/audio")
async def upload_audio(book_id: str, request: Request, file: UploadFile = File(...),
                       db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    
    safe_name, content = await _validate_upload(file, ALLOWED_AUDIO_EXTS, settings.MAX_UPLOAD_SIZE_MB)
    filename = f"{book_id}-{safe_name}"
    path = os.path.join(AUDIO_DIR, filename)
    with open(path, "wb") as f:
        f.write(content)

    media = BookMedia(
        id=str(uuid.uuid4()), book_id=book_id,
        audio_url=f"/media/audio/{filename}",
        format=os.path.splitext(safe_name)[1].lstrip("."),
        size_bytes=len(content),
        is_encrypted=False,
    )
    db.add(media)
    await db.commit()
    return RedirectResponse(url=f"/admin/books/{book_id}", status_code=302)

@router.post("/books/{book_id}/audio/{media_id}/delete")
async def delete_audio(book_id: str, media_id: str, request: Request,
                        db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(BookMedia).where(BookMedia.id == media_id, BookMedia.book_id == book_id))
    media = result.scalar_one_or_none()
    if media:
        fname = os.path.basename(media.audio_url) if media.audio_url else ""
        fpath = os.path.join(AUDIO_DIR, fname)
        if os.path.exists(fpath):
            os.remove(fpath)
        await db.delete(media)
        await db.commit()
    return RedirectResponse(url=f"/admin/books/{book_id}", status_code=302)

@router.post("/books/{book_id}/delete")
async def delete_book_route(book_id: str, request: Request,
                             db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(Book).where(Book.id == book_id))
    book = result.scalar_one_or_none()
    if book:
        await db.delete(book)
        await db.commit()
    return RedirectResponse(url="/admin/books", status_code=302)


@router.post("/books/{book_id}/upload-epub")
async def upload_epub(book_id: str, request: Request, file: UploadFile = File(...),
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    """Upload an EPUB file and extract chapters/content"""
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")

    MAX_EPUB_SIZE = 50 * 1024 * 1024  # 50 MB hard cap
    content = await file.read(MAX_EPUB_SIZE + 1)
    if len(content) > MAX_EPUB_SIZE:
        return RedirectResponse(url=f"/admin/books/{book_id}?error=epub_too_large", status_code=302)

    epub_dir = os.path.join(BASE_DIR, "storage", "epub_temp", uuid.uuid4().hex)
    os.makedirs(epub_dir, exist_ok=True)

    def _safe_join(base: str, *parts: str) -> str:
        """Join path parts and ensure the result stays inside base (zip-slip guard)."""
        target = os.path.realpath(os.path.join(base, *parts))
        base_real = os.path.realpath(base)
        if not target.startswith(base_real + os.sep) and target != base_real:
            raise ValueError(f"Path escapes extraction directory: {os.path.join(*parts)}")
        return target

    def _parse_xml_safe(path: str) -> ET.ElementTree:
        """Parse XML. Python's ElementTree never resolves external entities, so
        it is not vulnerable to XXE; this wrapper documents that guarantee."""
        return ET.parse(path)

    try:
        # Extract EPUB (it's a ZIP) — sanitize every entry path
        epub_path = _safe_join(epub_dir, "book.epub")
        with open(epub_path, "wb") as f:
            f.write(content)

        with zipfile.ZipFile(epub_path, "r") as zf:
            for member in zf.infolist():
                member_path = _safe_join(epub_dir, member.filename)
                if member.is_dir():
                    os.makedirs(member_path, exist_ok=True)
                    continue
                os.makedirs(os.path.dirname(member_path), exist_ok=True)
                with zf.open(member) as src, open(member_path, "wb") as dst:
                    shutil.copyfileobj(src, dst, length=1024 * 1024)

        # Parse container.xml to find the OPF
        container_path = os.path.join(epub_dir, "META-INF", "container.xml")
        if not os.path.exists(container_path):
            return RedirectResponse(url=f"/admin/books/{book_id}?error=invalid_epub", status_code=302)

        tree = _parse_xml_safe(container_path)
        rootfs = tree.getroot()
        ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
        rootfile = rootfs.find(".//c:rootfile", ns)
        if rootfile is None:
            return RedirectResponse(url=f"/admin/books/{book_id}?error=no_opf", status_code=302)

        opf_path = _safe_join(epub_dir, rootfile.get("full-path", ""))
        if not os.path.exists(opf_path):
            return RedirectResponse(url=f"/admin/books/{book_id}?error=opf_not_found", status_code=302)

        result = await db.execute(select(Book).where(Book.id == book_id))
        book = result.scalar_one_or_none()
        if not book:
            return RedirectResponse(url="/admin/books", status_code=302)

        # Parse OPF
        opf_dir = os.path.dirname(opf_path)
        opf_tree = _parse_xml_safe(opf_path)
        opf_root = opf_tree.getroot()
        pkg_ns = {"p": "http://www.idpf.org/2007/opf"}

        spine = opf_root.find(".//p:spine", pkg_ns) or opf_root.find("spine")
        if spine is None:
            return RedirectResponse(url=f"/admin/books/{book_id}?error=no_spine", status_code=302)

        manifest = {}
        for item in (opf_root.findall(".//p:item", pkg_ns) or opf_root.findall("item")):
            item_id = item.get("id", "")
            item_href = item.get("href", "")
            manifest[item_id] = item_href

        # Update book metadata from OPF
        metadata = opf_root.find(".//p:metadata", pkg_ns) or opf_root.find("metadata")
        if metadata is not None:
            dc_ns = {"dc": "http://purl.org/dc/elements/1.1/"}
            title_el = metadata.find("dc:title", dc_ns) or metadata.find("title")
            if title_el is not None and title_el.text:
                book.title = title_el.text[:255]
            author_el = metadata.find("dc:creator", dc_ns) or metadata.find("creator")
            if author_el is not None and author_el.text:
                book.author = author_el.text[:255]

        # Extract cover image if available
        cover_href = None
        for meta in (opf_root.findall(".//p:meta", pkg_ns) or opf_root.findall("meta")):
            if meta.get("name", "").lower() == "cover":
                cover_id = meta.get("content", "")
                if cover_id in manifest:
                    cover_href = manifest[cover_id]
                    break

        if not cover_href:
            for item_id, href in manifest.items():
                if "cover" in href.lower() and href.endswith((".jpg", ".png", ".jpeg")):
                    cover_href = href
                    break

        if cover_href:
            cover_path = _safe_join(opf_dir, cover_href)
            if os.path.exists(cover_path):
                ext = os.path.splitext(cover_href)[1]
                cover_filename = f"{book_id}{ext}"
                cover_dest = os.path.join(COVERS_DIR, cover_filename)
                shutil.copy2(cover_path, cover_dest)
                book.cover_url = f"/media/covers/{cover_filename}"

        # Delete existing chapters
        existing = await db.execute(select(Chapter).where(Chapter.book_id == book_id))
        for ch in existing.scalars().all():
            await db.delete(ch)

        # Parse each spine item as a chapter
        word_count = 0
        word_id_counter = 0
        for idx, itemref in enumerate(spine):
            idref = itemref.get("idref", "")
            if idref not in manifest:
                continue
            href = manifest[idref]
            if not href.endswith((".html", ".xhtml", ".htm", ".xml")):
                continue

            content_path = _safe_join(opf_dir, href)
            if not os.path.exists(content_path):
                continue

            with open(content_path, "r", encoding="utf-8", errors="replace") as fh:
                html_content = fh.read(5 * 1024 * 1024)  # 5 MB cap per chapter

            soup = BeautifulSoup(html_content, "lxml")
            paragraphs = []
            for tag in soup.find_all(["p", "h1", "h2", "h3", "h4", "h5", "h6", "div"]):
                text = tag.get_text(strip=True)
                if not text:
                    continue
                words = text.split()
                if len(words) < 3:
                    continue
                para_words = []
                for w in words:
                    wid = f"w{word_id_counter:06d}"
                    para_words.append({"id": wid, "text": w})
                    word_id_counter += 1
                paragraphs.append({"words": para_words})

            if not paragraphs:
                continue

            word_count += sum(len(p["words"]) for p in paragraphs)

            chapter_title = f"Chapter {idx + 1}"
            title_tag = soup.find("title")
            if title_tag and title_tag.get_text(strip=True):
                chapter_title = title_tag.get_text(strip=True)[:255]

            chapter = Chapter(
                id=str(uuid.uuid4()),
                book_id=book_id,
                title=chapter_title,
                order_index=idx,
                content=paragraphs,
            )
            db.add(chapter)

        if not book.title or book.title == "Unknown":
            book.title = "Unknown Title"
        if not book.author or book.author == "Unknown":
            book.author = "Unknown Author"

        book.word_count = word_count
        book.status = BookStatus.PUBLISHED
        await db.commit()

    except Exception as e:
        print(f"EPUB parse error: {e}")
    finally:
        shutil.rmtree(epub_dir, ignore_errors=True)

    return RedirectResponse(url=f"/admin/books/{book_id}", status_code=302)

# ===== USERS =====

@router.get("/users", response_class=HTMLResponse)
async def users_page(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(User).order_by(User.created_at.desc()).limit(100))
    users = result.scalars().all()
    ctx = {"request": request, "page": "users",
        "users": [{"id": u.id, "email": u.email, "is_active": u.is_active,
                    "is_admin": u.is_admin, "is_verified": u.is_verified,
                    "created_at": str(u.created_at)[:10] if u.created_at else ""} for u in users]}
    return templates.TemplateResponse(request, "admin/users.html", await _inject_csrf(ctx, request))

@router.post("/users/create")
async def create_user(request: Request, email: str = Form(...), password: str = Form(...),
                      is_admin: bool = Form(False),
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    existing = await db.execute(select(User).where(User.email == email))
    if existing.scalar_one_or_none():
        return RedirectResponse(url="/admin/users?error=exists", status_code=302)
    user = User(id=str(uuid.uuid4()), email=email, hashed_password=get_password_hash(password),
                is_verified=True, is_admin=is_admin)
    db.add(user)
    await db.commit()
    return RedirectResponse(url="/admin/users", status_code=302)

@router.post("/users/{user_id}/toggle")
async def toggle_user(user_id: str, request: Request,
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user:
        user.is_active = not user.is_active
        await db.commit()
    return RedirectResponse(url="/admin/users", status_code=302)

@router.post("/users/{user_id}/delete")
async def delete_user_route(user_id: str, request: Request,
                            db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user and not user.is_admin:
        await db.delete(user)
        await db.commit()
    return RedirectResponse(url="/admin/users", status_code=302)

# ===== SUBSCRIPTIONS =====

@router.get("/subscriptions", response_class=HTMLResponse)
async def subscriptions_page(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    plans = (await db.execute(select(SubscriptionPlan).order_by(SubscriptionPlan.price))).scalars().all()
    user_subs = (await db.execute(select(UserSubscription).order_by(UserSubscription.created_at.desc()).limit(50))).scalars().all()
    ctx = {"request": request, "page": "subscriptions", "plans": plans, "user_subs": user_subs}
    return templates.TemplateResponse(request, "admin/subscriptions.html", await _inject_csrf(ctx, request))

@router.post("/subscriptions/plan")
async def create_plan(request: Request, name: str = Form(...), description: str = Form(""),
                      price: float = Form(...), interval: str = Form("monthly"),
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    plan = SubscriptionPlan(id=str(uuid.uuid4()), name=name, description=description,
                            price=price, interval=interval, is_active=True)
    db.add(plan)
    await db.commit()
    return RedirectResponse(url="/admin/subscriptions", status_code=302)

@router.post("/subscriptions/plan/{plan_id}/toggle")
async def toggle_plan(plan_id: str, request: Request,
                      db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id))
    plan = result.scalar_one_or_none()
    if plan:
        plan.is_active = not plan.is_active
        await db.commit()
    return RedirectResponse(url="/admin/subscriptions", status_code=302)

# ===== CATEGORIES =====

@router.get("/categories", response_class=HTMLResponse)
async def categories_page(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    cats = (await db.execute(select(Category))).scalars().all()
    ctx = {"request": request, "page": "categories", "categories": cats}
    return templates.TemplateResponse(request, "admin/categories.html", await _inject_csrf(ctx, request))

@router.post("/categories")
async def create_category(request: Request, name: str = Form(...), description: str = Form(""),
                          db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    cat = Category(id=str(uuid.uuid4()), name=name, slug=name.lower().replace(" ", "-"))
    db.add(cat)
    await db.commit()
    return RedirectResponse(url="/admin/categories", status_code=302)

@router.post("/categories/{cat_id}/delete")
async def delete_category(cat_id: str, request: Request,
                          db: AsyncSession = Depends(get_db), _: bool = Depends(_verify_csrf)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    result = await db.execute(select(Category).where(Category.id == cat_id))
    cat = result.scalar_one_or_none()
    if cat:
        await db.delete(cat)
        await db.commit()
    return RedirectResponse(url="/admin/categories", status_code=302)

# ===== ANALYTICS =====

@router.get("/analytics", response_class=HTMLResponse)
async def analytics_page(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    stats = {
        "users": (await db.scalar(select(func.count(User.id)))) or 0,
        "books": (await db.scalar(select(func.count(Book.id)))) or 0,
    }
    payments = (await db.execute(select(Payment).where(Payment.status == "completed"))).scalars().all()
    stats["revenue"] = int(sum(p.amount for p in payments))
    stats["payments"] = len(payments)
    books = (await db.execute(select(Book).order_by(Book.created_at.desc()).limit(5))).scalars().all()
    stats["popular"] = [{"title": b.title, "author": b.author} for b in books]
    ctx = {"request": request, "page": "analytics", "stats": stats}
    return templates.TemplateResponse(request, "admin/analytics.html", await _inject_csrf(ctx, request))

@router.get("/analytics/export")
async def export_analytics(request: Request, db: AsyncSession = Depends(get_db)):
    admin = await _get_admin(request, db)
    if not admin:
        return RedirectResponse(url="/admin/login")
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Metric", "Value"])
    writer.writerow(["Total Users", (await db.scalar(select(func.count(User.id)))) or 0])
    writer.writerow(["Total Books", (await db.scalar(select(func.count(Book.id)))) or 0])
    writer.writerow(["Active Subscriptions", (await db.scalar(select(func.count(UserSubscription.id)).where(UserSubscription.status == "active"))) or 0])
    payments = (await db.execute(select(Payment).where(Payment.status == "completed"))).scalars().all()
    writer.writerow(["Total Revenue", sum(p.amount for p in payments)])
    writer.writerow(["", ""])
    writer.writerow(["Recent Payments"])
    writer.writerow(["ID", "Amount", "Method", "Status", "Date"])
    for p in payments[-20:]:
        writer.writerow([p.id, p.amount, p.method, p.status, str(p.created_at)[:19]])
    return Response(content=output.getvalue(), media_type="text/csv",
                    headers={"Content-Disposition": "attachment; filename=lyrr_analytics.csv"})
