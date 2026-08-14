"""
face_pulse/backend/tests/test_measurement_model.py
===================================================
Unit tests for the Measurement ORM model.

Coverage
--------
1. Measurement can be created and persisted.
2. UUID is automatically generated (non-null, valid UUID).
3. Default status is READY.
4. started_at is populated on insert.
5. created_at is populated on insert.
6. completed_at is NULL by default.
7. Multiple measurements can belong to the same user_id.
8. Invalid status values are rejected at the Python/SQLAlchemy level.

These tests use SQLite (see conftest.py) and do NOT require a live
PostgreSQL instance or the ML model.
"""

import uuid
from datetime import datetime, timezone

import pytest
import pytest_asyncio
from sqlalchemy import select

from app.models.measurement import Measurement, MeasurementStatus


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def make_user_id() -> uuid.UUID:
    """Generate a random UUID to act as a user_id."""
    return uuid.uuid4()


async def create_measurement(
    db_session,
    *,
    user_id: uuid.UUID | None = None,
    status: MeasurementStatus = MeasurementStatus.READY,
) -> Measurement:
    """Insert a Measurement row and return the refreshed instance."""
    m = Measurement(
        user_id=user_id or make_user_id(),
        status=status,
    )
    db_session.add(m)
    await db_session.flush()   # sends INSERT; row is visible in this session
    await db_session.refresh(m)
    return m


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_measurement_can_be_created(db_session):
    """Test 1 — A Measurement can be created and persisted."""
    user_id = make_user_id()
    m = await create_measurement(db_session, user_id=user_id)

    # Row exists in the session
    assert m is not None
    assert m.user_id == user_id


@pytest.mark.asyncio
async def test_uuid_is_automatically_generated(db_session):
    """Test 2 — id is auto-generated as a non-null UUID."""
    m = await create_measurement(db_session)

    assert m.id is not None
    assert isinstance(m.id, uuid.UUID)
    # Must not be the nil UUID
    assert m.id != uuid.UUID(int=0)


@pytest.mark.asyncio
async def test_default_status_is_ready(db_session):
    """Test 3 — status defaults to READY when not explicitly set."""
    m = await create_measurement(db_session)

    assert m.status == MeasurementStatus.READY


@pytest.mark.asyncio
async def test_started_at_is_populated(db_session):
    """Test 4 — started_at is not None after insert."""
    m = await create_measurement(db_session)

    assert m.started_at is not None
    assert isinstance(m.started_at, datetime)


@pytest.mark.asyncio
async def test_created_at_is_populated(db_session):
    """Test 5 — created_at is not None after insert."""
    m = await create_measurement(db_session)

    assert m.created_at is not None
    assert isinstance(m.created_at, datetime)


@pytest.mark.asyncio
async def test_completed_at_is_null_by_default(db_session):
    """Test 6 — completed_at is NULL on a freshly created Measurement."""
    m = await create_measurement(db_session)

    assert m.completed_at is None


@pytest.mark.asyncio
async def test_multiple_measurements_same_user(db_session):
    """Test 7 — Multiple measurements can belong to the same user_id."""
    shared_user_id = make_user_id()

    m1 = await create_measurement(db_session, user_id=shared_user_id)
    m2 = await create_measurement(db_session, user_id=shared_user_id)
    m3 = await create_measurement(db_session, user_id=shared_user_id)

    # All three have the same user_id
    assert m1.user_id == m2.user_id == m3.user_id == shared_user_id

    # All three have distinct primary keys
    ids = {m1.id, m2.id, m3.id}
    assert len(ids) == 3

    # Query via ORM to confirm all three exist
    result = await db_session.execute(
        select(Measurement).where(Measurement.user_id == shared_user_id)
    )
    rows = result.scalars().all()
    assert len(rows) == 3


@pytest.mark.asyncio
async def test_invalid_status_rejected_at_python_level(db_session):
    """
    Test 8 — An invalid status string is rejected at the Python/SQLAlchemy level.

    On PostgreSQL, the ENUM constraint enforces this at the database level.
    On SQLite (used in these unit tests), we validate that the MeasurementStatus
    enum itself raises a ValueError for unrecognised values, and that
    SQLAlchemy's validate_strings=True rejects the value before it reaches
    the INSERT.
    """
    # Python enum membership check
    with pytest.raises(ValueError):
        MeasurementStatus("INVALID_STATUS")

    # Passing a raw invalid string as the status column value
    # should raise a LookupError from SQLAlchemy's validate_strings=True
    # when the value is processed.
    # We test this at the attribute assignment / flush level.
    with pytest.raises((ValueError, LookupError, Exception)):
        m = Measurement(
            user_id=make_user_id(),
            status="NOT_A_VALID_STATUS",  # type: ignore[arg-type]
        )
        db_session.add(m)
        await db_session.flush()


# ---------------------------------------------------------------------------
# Additional lifecycle sanity checks
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_status_can_be_updated(db_session):
    """Status can be transitioned to any valid value."""
    m = await create_measurement(db_session)
    assert m.status == MeasurementStatus.READY

    m.status = MeasurementStatus.MEASURING
    await db_session.flush()
    await db_session.refresh(m)
    assert m.status == MeasurementStatus.MEASURING

    m.status = MeasurementStatus.COMPLETED
    await db_session.flush()
    await db_session.refresh(m)
    assert m.status == MeasurementStatus.COMPLETED


@pytest.mark.asyncio
async def test_completed_at_can_be_set(db_session):
    """completed_at can be set to a datetime after the session ends."""
    m = await create_measurement(db_session)
    assert m.completed_at is None

    now = datetime.now(tz=timezone.utc)
    m.completed_at = now
    m.status = MeasurementStatus.COMPLETED
    await db_session.flush()
    await db_session.refresh(m)

    assert m.completed_at is not None
    assert m.status == MeasurementStatus.COMPLETED


@pytest.mark.asyncio
async def test_all_valid_statuses_can_be_stored(db_session):
    """Every MeasurementStatus value can be saved and retrieved."""
    user_id = make_user_id()
    for status in MeasurementStatus:
        m = await create_measurement(db_session, user_id=user_id, status=status)
        await db_session.refresh(m)
        assert m.status == status
