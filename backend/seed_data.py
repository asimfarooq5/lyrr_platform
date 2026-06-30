"""
LYRR Platform - Seed Data Script
Populates the database with sample books, chapters, and sync data
Run: alembic upgrade head && python seed_data.py
"""

import asyncio
import json
import random
import uuid
from datetime import datetime, timedelta

from app.core.database import AsyncSessionLocal, init_db
from app.models.book import Book, Chapter, BookMedia, UserBook, BookStatus, Language
from app.models.user import User
from app.core.security import get_password_hash

SAMPLE_BOOKS = [
    {
        "title": "The Great Gatsby",
        "author": "F. Scott Fitzgerald",
        "description": "A story of the mysteriously wealthy Jay Gatsby and his love for the beautiful Daisy Buchanan.",
        "language": "en",
        "duration": 14400,
        "word_count": 47000,
        "is_featured": True,
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


def generate_words(count: int) -> list:
    """Generate paragraph with word IDs"""
    words = []
    for i in range(count):
        word = random.choice(LOREM_WORDS)
        words.append({"id": f"w{i:04d}", "text": word})
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
    await init_db()

    async with AsyncSessionLocal() as session:
        # Create admin user
        admin = User(
            email="admin@lyrr.app",
            hashed_password=get_password_hash("admin123"),
            is_active=True,
            is_verified=True,
            is_admin=True,
        )
        session.add(admin)

        # Create demo user
        demo = User(
            email="demo@lyrr.app",
            hashed_password=get_password_hash("demo123"),
            is_active=True,
            is_verified=True,
            is_admin=False,
        )
        session.add(demo)
        await session.flush()

        # Create books
        for i, book_data in enumerate(SAMPLE_BOOKS):
            book_id = str(uuid.uuid4())
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

                # Add media entry
                media_duration = int(len(words_in_chapter) * 0.33)
                media = BookMedia(
                    id=str(uuid.uuid4()),
                    book_id=book_id,
                    audio_url=f"https://audio.lyrr.app/books/{book_id}/{chapter_id}.mp3",
                    format="mp3",
                    quality="high",
                    duration=media_duration,
                    size_bytes=media_duration * 16000,
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
        print(f"   Admin: admin@lyrr.app / admin123")
        print(f"   Demo:  demo@lyrr.app / demo123")


if __name__ == "__main__":
    asyncio.run(seed())
