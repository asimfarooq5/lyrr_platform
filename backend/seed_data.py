"""
LYRR Platform - Seed Data Script
Populates the database with sample books, chapters, and sync data
Run: alembic upgrade head && python seed_data.py
"""

import asyncio
import itertools
import json
import math
import os
import random
import struct
import sys
import uuid
import wave
from datetime import datetime, timedelta

from sqlalchemy import select

from app.core.database import AsyncSessionLocal, init_db
from app.models.book import Book, Chapter, BookMedia, UserBook, BookStatus, Language
from app.models.content import SubscriptionPlan
from app.models.user import User
from app.core.security import get_password_hash
from app.core.config import settings

STORAGE_DIR = os.path.join(os.path.dirname(__file__), "storage")
COVERS_DIR = os.path.join(STORAGE_DIR, "covers")
AUDIO_DIR = os.path.join(STORAGE_DIR, "audio")
os.makedirs(COVERS_DIR, exist_ok=True)
os.makedirs(AUDIO_DIR, exist_ok=True)

# Deterministic per-book accent colors so covers look distinct, not random.
_COVER_PALETTE = [
    (0x6B, 0x4E, 0xFF), (0x00, 0xD9, 0xC0), (0xFF, 0x6B, 0x6B),
    (0xFF, 0xB4, 0x00), (0x3B, 0x82, 0xF6), (0x10, 0xB9, 0x81),
]


def generate_cover(book_id: str, title: str, author: str) -> str | None:
    """Render a designed placeholder cover and return its filename.

    Not a flat colour swatch: a vertical gradient, a soft vignette, a rule
    above the title and a tracked author line — so seeded/demo books look like
    real covers in the Store and in the admin table.

    Returns ``None`` when Pillow is not installed — covers are cosmetic and
    the app falls back to a placeholder, so seeding must not fail over it.
    """
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("   (Pillow not installed — skipping generated covers)")
        return None

    base = _COVER_PALETTE[abs(hash(book_id)) % len(_COVER_PALETTE)]
    width, height = 800, 1200
    img = Image.new("RGB", (width, height), base)
    draw = ImageDraw.Draw(img)

    def mix(c, other, t):
        return tuple(int(c[i] + (other[i] - c[i]) * t) for i in range(3))

    # Vertical gradient: darker at the top, lighter toward the bottom.
    dark = mix(base, (0, 0, 0), 0.38)
    light = mix(base, (255, 255, 255), 0.16)
    for y in range(height):
        t = y / height
        # ease so the dark band stays at the top third
        tt = t ** 1.6
        draw.line([(0, y), (width, y)], fill=mix(dark, light, tt))

    # Soft radial vignette in the top-right for depth.
    for r in range(420, 0, -12):
        alpha = (1 - r / 420) * 0.16
        col = mix(base, (255, 255, 255), alpha)
        draw.ellipse(
            [width - 120 - r, -120 - r, width - 120 + r, -120 + r],
            fill=col,
        )

    # Inner border frame.
    margin = 46
    draw.rectangle(
        [margin, margin, width - margin, height - margin],
        outline=mix(base, (255, 255, 255), 0.45), width=2,
    )

    def load_font(path, size):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            return ImageFont.load_default()

    title_font = load_font("DejaVuSans-Bold.ttf", 62)
    rule_font = load_font("DejaVuSans.ttf", 34)
    author_font = load_font("DejaVuSans.ttf", 30)

    def wrap(text, font, max_width):
        words, lines, current = text.split(), [], ""
        for w in words:
            trial = f"{current} {w}".strip()
            if draw.textlength(trial, font=font) <= max_width:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = w
        if current:
            lines.append(current)
        return lines

    inset = margin + 56
    max_text_width = width - inset * 2

    title_lines = wrap(title, title_font, max_text_width)[:5]
    line_h = 78
    block_h = len(title_lines) * line_h
    y = (height - block_h) / 2 - 40

    for line in title_lines:
        w = draw.textlength(line, font=title_font)
        # subtle drop shadow for legibility over the gradient
        draw.text(((width - w) / 2 + 2, y + 2), line, font=title_font,
                  fill=mix(base, (0, 0, 0), 0.25))
        draw.text(((width - w) / 2, y), line, font=title_font, fill="white")
        y += line_h

    # Short rule dividing title and author.
    rule_w = 96
    draw.line(
        [(width - rule_w) / 2, y + 26, (width + rule_w) / 2, y + 26],
        fill=mix(base, (255, 255, 255), 0.6), width=3,
    )

    author_text = (author or "").upper()
    for line in wrap(author_text, author_font, max_text_width)[:2]:
        w = draw.textlength(line, font=author_font)
        draw.text(((width - w) / 2, y + 60), line, font=author_font,
                  fill=mix(base, (255, 255, 255), 0.82))
        y += 42

    # Small wordmark at the bottom.
    mark = "LYRR"
    w = draw.textlength(mark, font=rule_font)
    draw.text(((width - w) / 2, height - margin - 68), mark,
              font=rule_font, fill=mix(base, (255, 255, 255), 0.55))

    filename = f"{book_id}.jpg"
    img.save(os.path.join(COVERS_DIR, filename), "JPEG", quality=88)
    return filename


def generate_audio_tone(filename_stub: str, seconds: int = 12, frequency: float = 220.0) -> tuple[str, int]:
    """Create a short audible WAV tone and return (filename, duration_seconds).

    This is a placeholder for real narration audio: it proves the full
    upload -> storage -> stream -> playback pipeline works end to end
    without needing real audio files or bloating disk on a constrained
    demo host (a few seconds per chapter vs. hours of real narration).
    """
    sample_rate = 22050
    n_samples = sample_rate * seconds
    filename = f"{filename_stub}.wav"
    path = os.path.join(AUDIO_DIR, filename)

    with wave.open(path, "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        frames = bytearray()
        for i in range(n_samples):
            t = i / sample_rate
            # Gentle fade in/out so it doesn't click, two-tone chime pattern.
            envelope = min(1.0, t * 4, (seconds - t) * 4)
            tone = frequency if (i // sample_rate) % 2 == 0 else frequency * 1.5
            # Loud enough to be clearly audible on a phone speaker at normal
            # volume (previous 3000 amplitude was too quiet to notice — an
            # easy "no sound" false alarm).
            sample = int(18000 * envelope * math.sin(2 * math.pi * tone * t))
            frames += struct.pack("<h", sample)
        wav_file.writeframes(bytes(frames))

    return filename, seconds

# Admin/demo credentials come from the environment; the defaults below are
# for LOCAL DEVELOPMENT ONLY. The script refuses to run with them in production.
SEED_ADMIN_EMAIL = os.environ.get("SEED_ADMIN_EMAIL", "admin@lyrr.app")
SEED_ADMIN_PASSWORD = os.environ.get("SEED_ADMIN_PASSWORD", "admin123")
SEED_DEMO_EMAIL = os.environ.get("SEED_DEMO_EMAIL", "demo@lyrr.app")
SEED_DEMO_PASSWORD = os.environ.get("SEED_DEMO_PASSWORD", "demo123")

SAMPLE_BOOKS = [
    {
        "title": "The Great Gatsby",
        "author": "F. Scott Fitzgerald",
        "description": "A story of the mysteriously wealthy Jay Gatsby and his love for the beautiful Daisy Buchanan.",
        "language": "en",
        "duration": 14400,
        "word_count": 47000,
        "is_featured": True,
        "price": 1500.0,
        "chapters": [
            {"title": "Chapter 1", "order": 1, "words": 50},
            {"title": "Chapter 2", "order": 2, "words": 45},
            {"title": "Chapter 3", "order": 3, "words": 55},
        ]
    },
    {
        "title": "Cien Años de Soledad",
        "author": "Gabriel García Márquez",
        "description": "La historia de la familia Buendía en el pueblo Macondo.",
        "language": "es",
        "duration": 28800,
        "word_count": 86000,
        "is_featured": True,
        "price": 2500.0,
        "chapters": [
            {"title": "Capítulo 1", "order": 1, "words": 60},
            {"title": "Capítulo 2", "order": 2, "words": 48},
        ]
    },
    {
        "title": "Le Petit Prince",
        "author": "Antoine de Saint-Exupéry",
        "description": "Un conte poétique et philosophique sous l'apparence d'un conte pour enfants.",
        "language": "fr",
        "duration": 7200,
        "word_count": 16000,
        "is_featured": True,
        "chapters": [
            {"title": "Chapitre 1", "order": 1, "words": 35},
            {"title": "Chapitre 2", "order": 2, "words": 40},
            {"title": "Chapitre 3", "order": 3, "words": 30},
        ]
    },
    {
        "title": "Die Verwandlung",
        "author": "Franz Kafka",
        "description": "Die Geschichte des Handlungsreisenden Gregor Samsa, der eines Morgens als Insekt erwacht.",
        "language": "de",
        "duration": 10800,
        "word_count": 22000,
        "is_featured": False,
        "chapters": [
            {"title": "Kapitel 1", "order": 1, "words": 42},
            {"title": "Kapitel 2", "order": 2, "words": 38},
        ]
    },
    {
        "title": "Dom Casmurro",
        "author": "Machado de Assis",
        "description": "Um romance que narra a história de Bentinho e Capitu.",
        "language": "pt",
        "duration": 16200,
        "word_count": 38000,
        "is_featured": False,
        "chapters": [
            {"title": "Capítulo 1", "order": 1, "words": 44},
            {"title": "Capítulo 2", "order": 2, "words": 36},
        ]
    },
    {
        "title": "The Art of War",
        "author": "Sun Tzu",
        "description": "An ancient Chinese military treatise that has become a classic of strategy and philosophy.",
        "language": "en",
        "duration": 5400,
        "word_count": 6000,
        "is_featured": True,
        "chapters": [
            {"title": "Laying Plans", "order": 1, "words": 30},
            {"title": "Waging War", "order": 2, "words": 25},
            {"title": "Attack by Stratagem", "order": 3, "words": 28},
        ]
    },
]

LOREM_WORDS = [
    "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing",
    "elit", "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore",
    "et", "dolore", "magna", "aliqua", "enim", "ad", "minim", "veniam",
    "quis", "nostrud", "exercitation", "ullamco", "laboris", "nisi", "ut",
    "aliquip", "ex", "ea", "commodo", "consequat", "duis", "aute", "irure",
    "dolor", "in", "reprehenderit", "in", "voluptate", "velit", "esse",
    "cillum", "dolore", "eu", "fugiat", "nulla", "pariatur", "excepteur",
    "sint", "occaecat", "cupidatat", "non", "proident", "sunt", "in", "culpa",
    "qui", "officia", "deserunt", "mollit", "anim", "id", "est", "laborum"
]


_word_id_counter = itertools.count()


def generate_words(count: int) -> list:
    """Generate paragraph with word IDs.

    IDs come from a process-wide counter, not a per-call index — the reader
    highlights every word whose id matches the current playhead, so reusing
    "w0000", "w0001", ... in each paragraph made every paragraph's Nth word
    light up simultaneously instead of just the one being read.
    """
    words = []
    for _ in range(count):
        word = random.choice(LOREM_WORDS)
        words.append({"id": f"w{next(_word_id_counter):06d}", "text": word})
    return words


def generate_sync_data(words: list, base_time: float = 0.0) -> list:
    """Generate timestamp sync data for words"""
    sync = []
    current_time = base_time
    for word in words:
        duration = random.uniform(0.15, 0.5)
        sync.append({
            "id": word["id"],
            "start": round(current_time, 3),
            "end": round(current_time + duration, 3),
        })
        current_time += duration
    return sync


async def seed():
    # Refuse to run with default credentials in production environments
    if settings.ENVIRONMENT == "production" and (
        SEED_ADMIN_PASSWORD == "admin123" or SEED_DEMO_PASSWORD == "demo123"
    ):
        print(
            "Refusing to seed with default credentials in production.\n"
            "Set SEED_ADMIN_PASSWORD / SEED_DEMO_PASSWORD environment variables."
        )
        sys.exit(1)

    await init_db()

    async with AsyncSessionLocal() as session:
        # Create admin user (idempotent — re-running seed must not crash)
        existing_admin = (await session.execute(
            select(User).where(User.email == SEED_ADMIN_EMAIL)
        )).scalar_one_or_none()
        if existing_admin:
            admin = existing_admin
            admin.hashed_password = get_password_hash(SEED_ADMIN_PASSWORD)
            print(f"   Admin user already exists: {SEED_ADMIN_EMAIL}")
        else:
            admin = User(
                email=SEED_ADMIN_EMAIL,
                hashed_password=get_password_hash(SEED_ADMIN_PASSWORD),
                is_active=True,
                is_verified=True,
                is_admin=True,
            )
            session.add(admin)

        # Create demo user (idempotent)
        existing_demo = (await session.execute(
            select(User).where(User.email == SEED_DEMO_EMAIL)
        )).scalar_one_or_none()
        if existing_demo:
            demo = existing_demo
            demo.hashed_password = get_password_hash(SEED_DEMO_PASSWORD)
            print(f"   Demo user already exists: {SEED_DEMO_EMAIL}")
        else:
            demo = User(
                email=SEED_DEMO_EMAIL,
                hashed_password=get_password_hash(SEED_DEMO_PASSWORD),
                is_active=True,
                is_verified=True,
                is_admin=False,
            )
            session.add(demo)
        await session.flush()

        # Create subscription plans (FRS §10: monthly / annual)
        existing_plans = await session.execute(select(SubscriptionPlan))
        if existing_plans.scalars().first() is None:
            session.add_all([
                SubscriptionPlan(
                    name="Monthly",
                    description="30 days of unlimited reading and listening",
                    price=2000.0,
                    currency="XAF",
                    interval="monthly",
                    is_active=True,
                ),
                SubscriptionPlan(
                    name="Annual",
                    description="12 months of unlimited reading and listening",
                    price=20000.0,
                    currency="XAF",
                    interval="annual",
                    is_active=True,
                ),
            ])
            await session.flush()
            print("   Subscription plans created (Monthly 2000 XAF, Annual 20000 XAF)")

        # Create books
        for i, book_data in enumerate(SAMPLE_BOOKS):
            # Skip a title that is already present so re-running seed is safe.
            existing_book = (await session.execute(
                select(Book).where(Book.title == book_data["title"])
            )).scalar_one_or_none()
            if existing_book:
                print(f"   Book already exists, skipping: {book_data['title']}")
                continue

            book_id = str(uuid.uuid4())
            cover_filename = generate_cover(book_id, book_data["title"], book_data["author"])
            book = Book(
                id=book_id,
                title=book_data["title"],
                author=book_data["author"],
                description=book_data["description"],
                language=book_data["language"],
                duration=book_data["duration"],
                word_count=book_data["word_count"],
                status=BookStatus.PUBLISHED,
                is_featured=book_data["is_featured"],
                price=book_data.get("price"),
                cover_url=f"/media/covers/{cover_filename}" if cover_filename else None,
                drm_enabled=False,
            )
            session.add(book)

            # Create chapters with content
            total_words_so_far = 0
            for ch in book_data["chapters"]:
                chapter_id = str(uuid.uuid4())
                paragraphs = []
                words_in_chapter = []
                words_remaining = ch["words"]

                while words_remaining > 0:
                    n = min(random.randint(5, 12), words_remaining)
                    para_words = generate_words(n)
                    words_in_chapter.extend(para_words)
                    paragraphs.append({"words": para_words})
                    words_remaining -= n

                sync_data = generate_sync_data(words_in_chapter, base_time=total_words_so_far * 0.33)

                chapter = Chapter(
                    id=chapter_id,
                    book_id=book_id,
                    title=ch["title"],
                    order_index=ch["order"],
                    content=paragraphs,
                    sync_data=sync_data,
                )
                session.add(chapter)

                # Add media entry - a short real audio clip so playback
                # actually works, instead of a placeholder domain that was
                # never a real server (audio.lyrr.app never existed).
                audio_filename, real_duration = generate_audio_tone(f"{book_id}-{chapter_id}")
                media = BookMedia(
                    id=str(uuid.uuid4()),
                    book_id=book_id,
                    audio_url=f"/media/audio/{audio_filename}",
                    format="wav",
                    quality="high",
                    duration=real_duration,
                    size_bytes=os.path.getsize(os.path.join(AUDIO_DIR, audio_filename)),
                    is_ai_narrated=True,
                    voice_id="pNInz6obpgDQGcFmaJgB",
                    is_encrypted=False,
                )
                session.add(media)
                total_words_so_far += ch["words"]

            # Demo user has purchased first book
            if i == 0:
                demo_book = UserBook(
                    id=str(uuid.uuid4()),
                    user_id=demo.id,
                    book_id=book_id,
                    license_key=str(uuid.uuid4()),
                    license_type="purchase",
                    purchased_at=datetime.utcnow(),
                )
                session.add(demo_book)

            print(f"  ✓ {book_data['title']} ({book_data['language']})")

        await session.commit()
        print(f"\n✅ Seeded {len(SAMPLE_BOOKS)} books successfully")
        print(f"   Admin: {SEED_ADMIN_EMAIL} / {SEED_ADMIN_PASSWORD}")
        print(f"   Demo:  {SEED_DEMO_EMAIL} / {SEED_DEMO_PASSWORD}")


if __name__ == "__main__":
    asyncio.run(seed())
