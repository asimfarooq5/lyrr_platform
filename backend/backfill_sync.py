"""Backfill sync data (word timestamps) for existing chapters.
Run this after seed_data.py to add sync timing data to all chapters.
"""

import asyncio
import random

from app.core.database import AsyncSessionLocal, init_db
from app.models.book import Book, Chapter


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


async def backfill_sync():
    await init_db()
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            Chapter.__table__.select().where(Chapter.sync_data.is_(None))
        )
        chapters = result.fetchall()
        updated = 0

        for row in chapters:
            content = row.content
            if not content:
                continue
            
            # Extract all words from paragraphs
            all_words = []
            for para in content:
                all_words.extend(para.get("words", []))
            
            if not all_words:
                continue
            
            sync_data = generate_sync_data(all_words)
            
            await session.execute(
                Chapter.__table__.update()
                .where(Chapter.__table__.c.id == row.id)
                .values(sync_data=sync_data)
            )
            updated += 1
            print(f"  ✓ {row.title or row.id}: {len(all_words)} words, {len(sync_data)} sync entries")

        await session.commit()
        print(f"\n✅ Backfilled sync data for {updated} chapters")


if __name__ == "__main__":
    asyncio.run(backfill_sync())
