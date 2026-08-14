"""
face_pulse/backend/tests/test_user_guardian_relationship.py
=============================================================
Unit tests for the UserGuardian model and relationships (Milestone 2.5).

Verification Criteria
---------------------
1. Guardian relationship can be created.
2. Guardian relationship gets its own UUID (independent identifier).
3. user_id references an existing User.
4. guardian_user_id references an existing User.
5. Both users have role USER (no special GUARDIAN role).
6. user_id != guardian_user_id.
7. Self-guardian relationship is rejected by Check constraint.
8. Duplicate relationship is rejected by Unique constraint.
9. Default status is PENDING.
10. Default share_results is FALSE.
11. Default share_trends is FALSE.
12. Default share_alerts is FALSE.
13. Status transitions between PENDING, ACCEPTED, REJECTED, REVOKED.
14. A user can have multiple guardians.
15. A user can act as guardian for multiple users.
16. Distinct IDs: user.id != guardian_relationship.id.
17. Distinct IDs: user.id != guardian_user.id.
"""

import uuid
import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.models.user import User, UserRole
from app.models.user_guardian import GuardianRelationshipStatus, UserGuardian


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def make_test_user(
    db_session,
    full_name: str = "Test User",
    email: str | None = None,
) -> User:
    """Helper to create and persist a test User."""
    user = User(
        full_name=full_name,
        email=email or f"user_{uuid.uuid4().hex[:8]}@example.com",
        password_hash="hashed_secret_password_123",
        role=UserRole.USER,
    )
    db_session.add(user)
    await db_session.flush()
    await db_session.refresh(user)
    return user


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_guardian_relationship_creation_and_defaults(db_session):
    """1, 2, 3, 4, 5, 9, 10, 11, 12: Creation, UUID, FKs, role=USER, default status (PENDING) and flags (False)."""
    user_a = await make_test_user(db_session, full_name="User A (Owner)")
    user_b = await make_test_user(db_session, full_name="User B (Guardian)")

    # 5. Both accounts have role USER
    assert user_a.role == UserRole.USER
    assert user_b.role == UserRole.USER

    # 1, 3, 4. Create relationship
    rel = UserGuardian(
        user_id=user_a.id,
        guardian_user_id=user_b.id,
    )
    db_session.add(rel)
    await db_session.flush()
    await db_session.refresh(rel)

    # 2. Independent UUID
    assert rel.id is not None
    assert isinstance(rel.id, uuid.UUID)
    assert rel.id != uuid.UUID(int=0)

    # 3, 4. References valid users
    assert rel.user_id == user_a.id
    assert rel.guardian_user_id == user_b.id

    # 9. Default status is PENDING
    assert rel.status == GuardianRelationshipStatus.PENDING
    assert rel.status.value == "PENDING"

    # 10, 11, 12. Default sharing permissions are False
    assert rel.share_results is False
    assert rel.share_trends is False
    assert rel.share_alerts is False

    # Timestamps populated
    assert rel.created_at is not None
    assert rel.updated_at is not None


@pytest.mark.asyncio
async def test_distinct_identifiers_rule(db_session):
    """6, 16, 17: user_id != guardian_user_id, user.id != rel.id."""
    user_a = await make_test_user(db_session, full_name="Owner")
    user_b = await make_test_user(db_session, full_name="Guardian")

    rel = UserGuardian(user_id=user_a.id, guardian_user_id=user_b.id)
    db_session.add(rel)
    await db_session.flush()

    # 6. user_id != guardian_user_id
    assert user_a.id != user_b.id

    # 16 & 17. Independent primary keys
    assert rel.id != user_a.id
    assert rel.id != user_b.id


@pytest.mark.asyncio
async def test_self_guardian_prevented_by_check_constraint(db_session):
    """7. Self-guardian relationship (user_id == guardian_user_id) is rejected."""
    user = await make_test_user(db_session, full_name="Self User")

    rel = UserGuardian(user_id=user.id, guardian_user_id=user.id)
    db_session.add(rel)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_duplicate_relationship_prevented_by_unique_constraint(db_session):
    """8. Duplicate relationship for the same (user_id, guardian_user_id) pair is rejected."""
    user_a = await make_test_user(db_session)
    user_b = await make_test_user(db_session)

    rel1 = UserGuardian(user_id=user_a.id, guardian_user_id=user_b.id)
    db_session.add(rel1)
    await db_session.flush()

    rel2 = UserGuardian(user_id=user_a.id, guardian_user_id=user_b.id)
    db_session.add(rel2)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_status_transitions(db_session):
    """13. Status can transition between PENDING, ACCEPTED, REJECTED, REVOKED."""
    user_a = await make_test_user(db_session)
    user_b = await make_test_user(db_session)

    rel = UserGuardian(user_id=user_a.id, guardian_user_id=user_b.id)
    db_session.add(rel)
    await db_session.flush()
    assert rel.status == GuardianRelationshipStatus.PENDING

    # Transition to ACCEPTED & set sharing permissions
    rel.status = GuardianRelationshipStatus.ACCEPTED
    rel.share_results = True
    rel.share_trends = True
    await db_session.flush()
    await db_session.refresh(rel)
    assert rel.status == GuardianRelationshipStatus.ACCEPTED
    assert rel.share_results is True
    assert rel.share_trends is True
    assert rel.share_alerts is False

    # Transition to REVOKED
    rel.status = GuardianRelationshipStatus.REVOKED
    await db_session.flush()
    await db_session.refresh(rel)
    assert rel.status == GuardianRelationshipStatus.REVOKED


@pytest.mark.asyncio
async def test_status_can_be_rejected(db_session):
    """13b. Status can transition to REJECTED."""
    user_a = await make_test_user(db_session)
    user_b = await make_test_user(db_session)

    rel = UserGuardian(user_id=user_a.id, guardian_user_id=user_b.id)
    db_session.add(rel)
    await db_session.flush()

    rel.status = GuardianRelationshipStatus.REJECTED
    await db_session.flush()
    await db_session.refresh(rel)
    assert rel.status == GuardianRelationshipStatus.REJECTED


@pytest.mark.asyncio
async def test_user_can_have_multiple_guardians(db_session):
    """14. A single user (data owner) can have multiple guardians."""
    owner = await make_test_user(db_session, full_name="Data Owner")
    g1 = await make_test_user(db_session, full_name="Guardian 1")
    g2 = await make_test_user(db_session, full_name="Guardian 2")

    rel1 = UserGuardian(
        user_id=owner.id,
        guardian_user_id=g1.id,
        status=GuardianRelationshipStatus.ACCEPTED,
        share_results=True,
    )
    rel2 = UserGuardian(
        user_id=owner.id,
        guardian_user_id=g2.id,
        status=GuardianRelationshipStatus.PENDING,
    )
    db_session.add_all([rel1, rel2])
    await db_session.flush()

    # Query owner via ORM relationship
    stmt = (
        select(User)
        .options(selectinload(User.guardian_relationships))
        .where(User.id == owner.id)
    )
    result = await db_session.execute(stmt)
    loaded_owner = result.scalar_one()

    assert len(loaded_owner.guardian_relationships) == 2
    guardian_user_ids = {r.guardian_user_id for r in loaded_owner.guardian_relationships}
    assert guardian_user_ids == {g1.id, g2.id}


@pytest.mark.asyncio
async def test_user_can_be_guardian_for_multiple_users(db_session):
    """15. A single user can act as guardian for multiple data owners."""
    guardian = await make_test_user(db_session, full_name="Shared Guardian")
    owner1 = await make_test_user(db_session, full_name="Owner 1")
    owner2 = await make_test_user(db_session, full_name="Owner 2")

    rel1 = UserGuardian(
        user_id=owner1.id,
        guardian_user_id=guardian.id,
        status=GuardianRelationshipStatus.ACCEPTED,
    )
    rel2 = UserGuardian(
        user_id=owner2.id,
        guardian_user_id=guardian.id,
        status=GuardianRelationshipStatus.ACCEPTED,
    )
    db_session.add_all([rel1, rel2])
    await db_session.flush()

    # Query guardian via owned_guardians ORM relationship
    stmt = (
        select(User)
        .options(selectinload(User.owned_guardians))
        .where(User.id == guardian.id)
    )
    result = await db_session.execute(stmt)
    loaded_guardian = result.scalar_one()

    assert len(loaded_guardian.owned_guardians) == 2
    owner_user_ids = {r.user_id for r in loaded_guardian.owned_guardians}
    assert owner_user_ids == {owner1.id, owner2.id}


@pytest.mark.asyncio
async def test_invalid_user_id_rejected_by_fk(db_session):
    """Non-existent user_id is rejected by Foreign Key constraint."""
    valid_user = await make_test_user(db_session)
    fake_user_id = uuid.uuid4()

    rel = UserGuardian(user_id=fake_user_id, guardian_user_id=valid_user.id)
    db_session.add(rel)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_invalid_guardian_user_id_rejected_by_fk(db_session):
    """Non-existent guardian_user_id is rejected by Foreign Key constraint."""
    valid_user = await make_test_user(db_session)
    fake_guardian_id = uuid.uuid4()

    rel = UserGuardian(user_id=valid_user.id, guardian_user_id=fake_guardian_id)
    db_session.add(rel)

    with pytest.raises(IntegrityError):
        await db_session.flush()
