"""
face_pulse/backend/app/core/database.py
=========================================
SQLAlchemy 2.x database infrastructure.

This module exposes:

  Base            — The single DeclarativeBase shared by ALL models.
                    Import and subclass this; never create another Base.

  async_engine    — AsyncEngine connected to DATABASE_URL (asyncpg).
                    Used by the FastAPI application at runtime.

  AsyncSessionLocal — async_sessionmaker producing AsyncSession objects.
                    Inject via FastAPI dependency (get_db).

  sync_engine     — Synchronous engine connected to DATABASE_URL_SYNC.
                    Used ONLY by Alembic; do not use in application code.

  get_db()        — FastAPI dependency that yields an AsyncSession.

Healthcare note
---------------
This module does not log connection strings, credentials, or any
patient-identifiable information. The SQLAlchemy engine echo is
disabled in production to avoid leaking query data to logs.
"""

from collections.abc import AsyncGenerator

from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# ---------------------------------------------------------------------------
# Declarative Base — ONE Base for the entire project.
# All models must inherit from this class.
# ---------------------------------------------------------------------------


class Base(DeclarativeBase):
    """
    Project-wide SQLAlchemy declarative base.

    All ORM models must subclass this.  Importing a model module
    registers its Table in Base.metadata, which is used by Alembic
    for auto-generation.
    """

    pass


# ---------------------------------------------------------------------------
# Async engine — used by the FastAPI application at runtime
# ---------------------------------------------------------------------------
async_engine = create_async_engine(
    settings.DATABASE_URL,
    # echo=False keeps SQL out of logs (important for a healthcare app).
    # Set to True locally for debugging, but never in production.
    echo=False,
    # Pool tuning — conservative defaults; adjust per load profile.
    pool_size=5,
    max_overflow=10,
    pool_pre_ping=True,   # verify connections before use
)

AsyncSessionLocal: async_sessionmaker[AsyncSession] = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    expire_on_commit=False,  # avoids lazy-load errors after commit
)


# ---------------------------------------------------------------------------
# Sync engine — ONLY for Alembic migrations
# ---------------------------------------------------------------------------
sync_engine = create_engine(
    settings.DATABASE_URL_SYNC,
    echo=False,
    pool_pre_ping=True,
)


# ---------------------------------------------------------------------------
# FastAPI dependency
# ---------------------------------------------------------------------------
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI dependency that provides a scoped AsyncSession per request.

    Usage in a route:
        @router.get("/example")
        async def example(db: AsyncSession = Depends(get_db)):
            ...

    The session is automatically closed after the request completes.
    """
    async with AsyncSessionLocal() as session:
        yield session
