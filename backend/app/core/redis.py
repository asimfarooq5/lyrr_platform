"""
Redis cache configuration
"""

import redis.asyncio as redis
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Redis client
redis_client: redis.Redis | None = None


async def init_redis():
    """Initialize Redis connection"""
    global redis_client
    try:
        redis_client = redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True
        )
        await redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.warning(f"Redis connection failed: {e}. Caching disabled.")
        redis_client = None


async def close_redis():
    """Close Redis connection"""
    global redis_client
    if redis_client:
        await redis_client.close()
        redis_client = None
        logger.info("Redis connection closed")


async def get_redis() -> redis.Redis | None:
    """Get Redis client"""
    return redis_client
