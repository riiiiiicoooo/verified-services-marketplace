"""
Database Connection Management — Central persistence layer for Verified Services Marketplace.

Provides:
- PostgreSQL/async connection pooling with asyncpg
- SQLAlchemy session management for ORM operations
- Health check utilities
- Graceful error handling and connection recovery
"""

import logging
import os
from contextlib import asynccontextmanager
from typing import Optional

try:
    import asyncpg
    HAS_ASYNCPG = True
except ImportError:
    HAS_ASYNCPG = False

try:
    from sqlalchemy import create_engine, text
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
    from sqlalchemy.orm import sessionmaker
    HAS_SQLALCHEMY = True
except ImportError:
    HAS_SQLALCHEMY = False

logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://localhost/marketplace")
DATABASE_POOL_SIZE = int(os.getenv("DATABASE_POOL_SIZE", "20"))
DATABASE_MAX_OVERFLOW = int(os.getenv("DATABASE_MAX_OVERFLOW", "10"))
DATABASE_POOL_TIMEOUT = int(os.getenv("DATABASE_POOL_TIMEOUT", "30"))
DATABASE_POOL_RECYCLE = int(os.getenv("DATABASE_POOL_RECYCLE", "3600"))

# Asyncpg connection pool
db_pool: Optional[asyncpg.Pool] = None

# SQLAlchemy async engine
async_engine = None
AsyncSessionLocal = None


async def init_asyncpg_pool() -> Optional[asyncpg.Pool]:
    """
    Initialize asyncpg connection pool for high-performance async queries.

    Returns:
        asyncpg.Pool or None if initialization fails
    """
    global db_pool

    if not HAS_ASYNCPG:
        logger.warning("asyncpg not installed; async database layer unavailable")
        return None

    try:
        db_pool = await asyncpg.create_pool(
            DATABASE_URL,
            min_size=5,
            max_size=DATABASE_POOL_SIZE,
            max_cached_statement_lifetime=DATABASE_POOL_RECYCLE,
            max_cacheable_statement_size=15000,
            command_timeout=DATABASE_POOL_TIMEOUT,
        )
        logger.info("asyncpg connection pool initialized: %s (size: %d)", DATABASE_URL, DATABASE_POOL_SIZE)
        return db_pool
    except Exception as e:
        logger.error("Failed to initialize asyncpg pool: %s", str(e))
        db_pool = None
        return None


async def init_sqlalchemy() -> Optional:
    """
    Initialize SQLAlchemy async engine for ORM operations.

    Returns:
        AsyncSession factory or None if initialization fails
    """
    global async_engine, AsyncSessionLocal

    if not HAS_SQLALCHEMY:
        logger.warning("SQLAlchemy not installed; ORM layer unavailable")
        return None

    try:
        # Convert postgresql:// to postgresql+asyncpg:// for async driver
        async_db_url = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://")

        async_engine = create_async_engine(
            async_db_url,
            poolclass=__import__("sqlalchemy.ext.asyncio", fromlist=["AsyncPool"]).AsyncPool,
            pool_size=DATABASE_POOL_SIZE,
            max_overflow=DATABASE_MAX_OVERFLOW,
            pool_timeout=DATABASE_POOL_TIMEOUT,
            pool_recycle=DATABASE_POOL_RECYCLE,
            pool_pre_ping=True,
            echo=False,
        )

        AsyncSessionLocal = sessionmaker(
            async_engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )

        logger.info("SQLAlchemy async engine initialized")
        return AsyncSessionLocal
    except Exception as e:
        logger.error("Failed to initialize SQLAlchemy: %s", str(e))
        async_engine = None
        AsyncSessionLocal = None
        return None


def get_asyncpg_pool() -> Optional[asyncpg.Pool]:
    """
    Get asyncpg connection pool.

    Returns:
        asyncpg.Pool or None if not initialized
    """
    return db_pool


def get_sessionmaker():
    """
    Get SQLAlchemy AsyncSession factory.

    Returns:
        sessionmaker or None if not initialized
    """
    return AsyncSessionLocal


@asynccontextmanager
async def get_async_session():
    """
    Context manager for async database sessions.

    Usage:
        async with get_async_session() as session:
            result = await session.execute(...)
            await session.commit()
    """
    if not AsyncSessionLocal:
        raise RuntimeError("AsyncSession factory not initialized")

    session = AsyncSessionLocal()
    try:
        yield session
        await session.commit()
    except Exception as e:
        await session.rollback()
        logger.error("Database transaction failed: %s", str(e))
        raise
    finally:
        await session.close()


async def execute_query(query: str, *args) -> Optional[list]:
    """
    Execute raw SQL query using asyncpg pool.

    Args:
        query: SQL query string
        *args: Query parameters

    Returns:
        List of result rows or None on error
    """
    if not db_pool:
        logger.warning("asyncpg pool not initialized")
        return None

    try:
        async with db_pool.acquire() as conn:
            results = await conn.fetch(query, *args)
            return results
    except Exception as e:
        logger.error("Query execution failed: %s", str(e))
        return None


async def check_database() -> bool:
    """Check database connectivity via asyncpg pool."""
    if not db_pool:
        logger.warning("asyncpg pool not initialized")
        return False

    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        logger.debug("Database health check passed")
        return True
    except Exception as e:
        logger.error("Database health check failed: %s", str(e))
        return False


async def shutdown():
    """Shutdown database connections."""
    global db_pool, async_engine, AsyncSessionLocal

    # Close asyncpg pool
    if db_pool:
        try:
            await db_pool.close()
            logger.info("asyncpg connection pool closed")
        except Exception as e:
            logger.error("Error closing asyncpg pool: %s", str(e))
        finally:
            db_pool = None

    # Dispose async engine
    if async_engine:
        try:
            await async_engine.dispose()
            logger.info("SQLAlchemy async engine disposed")
        except Exception as e:
            logger.error("Error disposing SQLAlchemy engine: %s", str(e))
        finally:
            async_engine = None
            AsyncSessionLocal = None
