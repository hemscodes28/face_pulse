"""
face_pulse/backend/tests/test_user_measurement_relationship.py
================================================================
Unit tests for the User model and 1:N Measurement relationship (Milestone 2).

Verification criteria:
1. User creation (with full_name, email, password_hash).
2. Automatic User UUID generation.
3. Default role is UserRole.USER ('USER').
4. Default is_active is TRUE.
5. User email uniqueness is enforced.
6. Measurement creation for a User.
7. Measurement.user returns the correct User.
8. User.measurements returns all owned measurements.
9. One User can have multiple Measurements.
10. Measurement IDs are unique and independent from user.id.
11. Measurement referencing a nonexistent user is rejected by FK constraint.
12. All User and Measurement IDs are distinct.
"""

import uuid
import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload
from sqlalchemy import select

from app.models.user import User, UserRole
from app.models.measurement import Measurement, MeasurementStatus


@pytest.mark.asyncio
async def test_user_creation_and_defaults(db_session):
    """1, 2, 3, 4: User creation, UUID generation, default role (USER), default is_active (True)."""
    user = User(
        full_name="Dr. Clara Oswald",
        email="clara@example.com",
        password_hash="hashed_secret_password_123",
    )
    db_session.add(user)
    await db_session.flush()
    await db_session.refresh(user)

    # 1 & 2. Valid User created with auto UUID
    assert user.id is not None
    assert isinstance(user.id, uuid.UUID)
    assert user.id != uuid.UUID(int=0)
    assert user.full_name == "Dr. Clara Oswald"
    assert user.email == "clara@example.com"
    assert user.password_hash == "hashed_secret_password_123"

    # 3. Default role is USER
    assert user.role == UserRole.USER
    assert user.role.value == "USER"

    # 4. Default is_active is True
    assert user.is_active is True

    # Timestamps populated
    assert user.created_at is not None
    assert user.updated_at is not None


@pytest.mark.asyncio
async def test_user_email_uniqueness(db_session):
    """5. User email uniqueness is enforced at database level."""
    u1 = User(
        full_name="User One",
        email="duplicate@example.com",
        password_hash="hash1",
    )
    db_session.add(u1)
    await db_session.flush()

    u2 = User(
        full_name="User Two",
        email="duplicate@example.com",
        password_hash="hash2",
    )
    db_session.add(u2)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_measurement_creation_for_user(db_session):
    """6. Measurement creation for a User."""
    user = User(
        full_name="Jane Doe",
        email="jane.doe@example.com",
        password_hash="secure_password_hash",
    )
    db_session.add(user)
    await db_session.flush()

    measurement = Measurement(
        user_id=user.id,
        status=MeasurementStatus.READY,
    )
    db_session.add(measurement)
    await db_session.flush()
    await db_session.refresh(measurement)

    assert measurement.user_id == user.id
    assert measurement.id is not None
    assert isinstance(measurement.id, uuid.UUID)


@pytest.mark.asyncio
async def test_measurement_user_relationship(db_session):
    """7. measurement.user returns the correct User."""
    user = User(
        full_name="Rel Test User",
        email="rel_user@example.com",
        password_hash="pass_hash",
    )
    db_session.add(user)
    await db_session.flush()

    measurement = Measurement(user_id=user.id)
    db_session.add(measurement)
    await db_session.flush()

    stmt = (
        select(Measurement)
        .options(selectinload(Measurement.user))
        .where(Measurement.id == measurement.id)
    )
    result = await db_session.execute(stmt)
    loaded_measurement = result.scalar_one()

    assert loaded_measurement.user is not None
    assert loaded_measurement.user.id == user.id
    assert loaded_measurement.user.email == "rel_user@example.com"
    assert loaded_measurement.user.full_name == "Rel Test User"


@pytest.mark.asyncio
async def test_user_measurements_relationship(db_session):
    """8. user.measurements returns all owned measurements."""
    user = User(
        full_name="List Owner",
        email="list_owner@example.com",
        password_hash="pass_hash",
    )
    db_session.add(user)
    await db_session.flush()

    m1 = Measurement(user_id=user.id)
    m2 = Measurement(user_id=user.id)
    db_session.add_all([m1, m2])
    await db_session.flush()

    stmt = (
        select(User)
        .options(selectinload(User.measurements))
        .where(User.id == user.id)
    )
    result = await db_session.execute(stmt)
    loaded_user = result.scalar_one()

    assert len(loaded_user.measurements) == 2
    retrieved_ids = {m.id for m in loaded_user.measurements}
    assert retrieved_ids == {m1.id, m2.id}


@pytest.mark.asyncio
async def test_one_user_multiple_measurements_unique_ids(db_session):
    """9, 10: One User can have multiple Measurements, all with unique Measurement IDs."""
    user = User(
        full_name="Multi Measurement User",
        email="multi_m@example.com",
        password_hash="pass_hash",
    )
    db_session.add(user)
    await db_session.flush()

    m1 = Measurement(user_id=user.id)
    m2 = Measurement(user_id=user.id)
    m3 = Measurement(user_id=user.id)
    db_session.add_all([m1, m2, m3])
    await db_session.flush()

    # All three reference the same user.id
    assert m1.user_id == m2.user_id == m3.user_id == user.id

    # All three IDs are completely unique from each other and from user.id
    measurement_ids = {m1.id, m2.id, m3.id}
    assert len(measurement_ids) == 3
    assert user.id not in measurement_ids


@pytest.mark.asyncio
async def test_measurement_nonexistent_user_rejected(db_session):
    """11. A Measurement referencing a nonexistent user is rejected by FK constraint."""
    nonexistent_id = uuid.uuid4()
    measurement = Measurement(user_id=nonexistent_id)
    db_session.add(measurement)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_user_id_and_measurement_id_always_distinct(db_session):
    """Confirm user.id != measurement.id architectural invariant."""
    user = User(
        full_name="Distinct Check",
        email="distinct@example.com",
        password_hash="pass_hash",
    )
    db_session.add(user)
    await db_session.flush()

    measurement = Measurement(user_id=user.id)
    db_session.add(measurement)
    await db_session.flush()

    assert user.id != measurement.id
    assert measurement.user_id == user.id
