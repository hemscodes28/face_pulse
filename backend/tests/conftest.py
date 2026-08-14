"""
face_pulse/backend/tests/conftest.py
=====================================
Shared pytest fixtures for the Face Pulse backend test suite.

Test database strategy
----------------------
Tests use SQLite (via aiosqlite) so they run without a live PostgreSQL
instance.  This covers model/ORM logic correctly.

SQLite limitations to be aware of:
  * The measurement_status ENUM is stored as VARCHAR in SQLite.
    The CHECK CONSTRAINT that enforces allowed values is not emitted
    by SQLAlchemy for SQLite (it is emitted for PostgreSQL).
    So the enum-rejection tests check at the Python/SQLAlchemy level.
  * gen_random_uuid() is a PostgreSQL function.  In tests we rely on
    the Python-side `default=uuid.uuid4` instead.

For integration tests against a real PostgreSQL, set TEST_DATABASE_URL
to a postgresql+asyncpg:// URL in your .env (or CI environment).
"""

import asyncio
import os
import uuid
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.database import Base
from app.models.measurement import Measurement, MeasurementStatus  # noqa: F401

# ---------------------------------------------------------------------------
# Test database URL
# ---------------------------------------------------------------------------
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL", "sqlite+aiosqlite:///./test.db"
)

# ---------------------------------------------------------------------------
# pytest-asyncio configuration
# ---------------------------------------------------------------------------
pytest_plugins = ["pytest_asyncio"]


# ---------------------------------------------------------------------------
# Engine — created once per test session
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture(scope="session")
async def engine():
    """
    Create an async test engine.

    For SQLite: enables WAL mode and foreign key enforcement.
    For PostgreSQL: connects directly.
    """
    _engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,  # keep test output clean
    )

    # SQLite-specific pragmas for better behaviour
    if TEST_DATABASE_URL.startswith("sqlite"):
        @event.listens_for(_engine.sync_engine, "connect")
        def set_sqlite_pragmas(dbapi_conn, _conn_record):
            cursor = dbapi_conn.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.close()

    # Create all tables
    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield _engine

    # Teardown — drop all tables and dispose engine
    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await _engine.dispose()


# ---------------------------------------------------------------------------
# Session factory — new session per test function
# ---------------------------------------------------------------------------
@pytest_asyncio.fixture
async def db_session(engine) -> AsyncGenerator[AsyncSession, None]:
    """
    Yield a fresh AsyncSession for each test.

    Uses a nested transaction (savepoint) so that each test is isolated
    and rolls back automatically after completion — no test data leaks.
    """
    async with engine.connect() as conn:
        await conn.begin()
        # Create a savepoint for rollback isolation
        await conn.begin_nested()

        session_factory = async_sessionmaker(
            bind=conn,
            class_=AsyncSession,
            expire_on_commit=False,
        )
        async with session_factory() as session:
            yield session

        # Roll back to the savepoint — removes all test data
        await conn.rollback()
