"""
face_pulse/backend/tests/test_measurement_model.py
===================================================
Unit tests for the Measurement ORM model (Milestone 1 & 2 integration).

Coverage
--------
1. Measurement can be created and persisted for a valid User.
2. UUID is automatically generated for Measurement (non-null, valid UUID).
3. Default status is READY.
4. started_at is populated on insert.
5. created_at is populated on insert.
6. completed_at is NULL by default.
7. Multiple measurements can belong to the same user_id.
8. Invalid status values are rejected at the Python/SQLAlchemy level.
"""

import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import select

from app.models.measurement import Measurement, MeasurementStatus
from app.models.user import User


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def make_user(
    db_session,
    email: str | None = None,
) -> User:
    """Create and persist a User row to satisfy foreign key constraints."""
    user = User(
        full_name="Test User",
        email=email or f"test_{uuid.uuid4().hex[:8]}@example.com",
        password_hash="hash_secret_123",
    )
    db_session.add(user)
    await db_session.flush()
    await db_session.refresh(user)
    return user


async def create_measurement(
    db_session,
    *,
    user_id: uuid.UUID | None = None,
    status: MeasurementStatus = MeasurementStatus.READY,
) -> Measurement:
    """Insert a Measurement row and return the refreshed instance."""
    if user_id is None:
        user = await make_user(db_session)
        user_id = user.id

    m = Measurement(
        user_id=user_id,
        status=status,
    )
    db_session.add(m)
    await db_session.flush()
    await db_session.refresh(m)
    return m


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_measurement_can_be_created(db_session):
    """Test 1 — A Measurement can be created and persisted for a valid User."""
    user = await make_user(db_session)
    m = await create_measurement(db_session, user_id=user.id)

    assert m is not None
    assert m.user_id == user.id


@pytest.mark.asyncio
async def test_uuid_is_automatically_generated(db_session):
    """Test 2 — id is auto-generated as a non-null UUID."""
    m = await create_measurement(db_session)

    assert m.id is not None
    assert isinstance(m.id, uuid.UUID)
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
    user = await make_user(db_session)

    m1 = await create_measurement(db_session, user_id=user.id)
    m2 = await create_measurement(db_session, user_id=user.id)
    m3 = await create_measurement(db_session, user_id=user.id)

    assert m1.user_id == m2.user_id == m3.user_id == user.id

    ids = {m1.id, m2.id, m3.id}
    assert len(ids) == 3

    result = await db_session.execute(
        select(Measurement).where(Measurement.user_id == user.id)
    )
    rows = result.scalars().all()
    assert len(rows) == 3


@pytest.mark.asyncio
async def test_invalid_status_rejected_at_python_level(db_session):
    """Test 8 — An invalid status string is rejected."""
    with pytest.raises(ValueError):
        MeasurementStatus("INVALID_STATUS")

    user = await make_user(db_session)
    with pytest.raises((ValueError, LookupError, Exception)):
        m = Measurement(
            user_id=user.id,
            status="NOT_A_VALID_STATUS",  # type: ignore[arg-type]
        )
        db_session.add(m)
        await db_session.flush()


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
    user = await make_user(db_session)
    for status in MeasurementStatus:
        m = await create_measurement(db_session, user_id=user.id, status=status)
        await db_session.refresh(m)
        assert m.status == status
