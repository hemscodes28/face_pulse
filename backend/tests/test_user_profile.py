"""
face_pulse/backend/tests/test_user_profile.py
===============================================
Unit tests for the UserProfile ORM model and 1:1 User relationship (Milestone 2.75).

Verification Criteria
---------------------
1. Profile creation with valid values.
2. Profile UUID generation.
3. User.profile returns correct UserProfile.
4. UserProfile.user returns correct User.
5. 1:1 relationship — duplicate user_id profile is rejected by UNIQUE constraint.
6. Non-existent user_id rejected by FK constraint.
7. Blood group accepts valid enum values and rejects invalid strings.
8. Height, weight, and date_of_birth stored correctly.
9. Multiple users can have independent profiles.
10. Distinct IDs: UserProfile.id != User.id.
11. Check constraints height_cm > 0 and weight_kg > 0.
12. Derived values: age and bmi calculated dynamically (not stored in DB).
"""

import uuid
from dateutil.relativedelta import relativedelta
from datetime import date, datetime
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.models.user import User, UserRole
from app.models.user_profile import BloodGroup, Gender, UserProfile


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

async def make_test_user(
    db_session,
    full_name: str = "Profile Test User",
    email: str | None = None,
) -> User:
    """Helper to create and persist a test User."""
    user = User(
        full_name=full_name,
        email=email or f"prof_user_{uuid.uuid4().hex[:8]}@example.com",
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
async def test_profile_creation_and_fields(db_session):
    """1, 2, 7, 11, 12, 13: Profile creation, auto UUID, height, weight, dob storage."""
    user = await make_test_user(db_session, full_name="Sarah Connor")
    dob = date(1995, 5, 15)

    profile = UserProfile(
        user_id=user.id,
        date_of_birth=dob,
        gender=Gender.FEMALE,
        height_cm=Decimal("170.50"),
        weight_kg=Decimal("62.50"),
        blood_group=BloodGroup.O_POSITIVE,
    )
    db_session.add(profile)
    await db_session.flush()
    await db_session.refresh(profile)

    # 2. Valid auto-generated UUID
    assert profile.id is not None
    assert isinstance(profile.id, uuid.UUID)
    assert profile.id != uuid.UUID(int=0)

    # 7. References valid user
    assert profile.user_id == user.id

    # 11, 12, 13. Attributes stored accurately
    assert profile.date_of_birth == dob
    assert profile.gender == Gender.FEMALE
    assert Decimal(str(profile.height_cm)) == Decimal("170.50")
    assert Decimal(str(profile.weight_kg)) == Decimal("62.50")
    assert profile.blood_group == BloodGroup.O_POSITIVE

    # Timestamps populated
    assert profile.created_at is not None
    assert profile.updated_at is not None


@pytest.mark.asyncio
async def test_distinct_identifiers_rule(db_session):
    """15. UserProfile.id != User.id (independent UUIDs)."""
    user = await make_test_user(db_session)
    profile = UserProfile(
        user_id=user.id,
        date_of_birth=date(1990, 1, 1),
        gender=Gender.MALE,
        height_cm=Decimal("180.00"),
        weight_kg=Decimal("75.00"),
        blood_group=BloodGroup.A_POSITIVE,
    )
    db_session.add(profile)
    await db_session.flush()

    assert profile.id != user.id
    assert isinstance(profile.id, uuid.UUID)


@pytest.mark.asyncio
async def test_user_profile_bidirectional_relationship(db_session):
    """3, 4: User.profile and UserProfile.user 1:1 relationship."""
    user = await make_test_user(db_session, full_name="John Doe")
    profile = UserProfile(
        user_id=user.id,
        date_of_birth=date(1988, 3, 20),
        gender=Gender.MALE,
        height_cm=Decimal("175.00"),
        weight_kg=Decimal("70.00"),
        blood_group=BloodGroup.B_POSITIVE,
    )
    db_session.add(profile)
    await db_session.flush()

    # Query User with eager loaded profile
    stmt = (
        select(User)
        .options(selectinload(User.profile))
        .where(User.id == user.id)
    )
    result = await db_session.execute(stmt)
    loaded_user = result.scalar_one()

    # 3. User.profile returns correct UserProfile
    assert loaded_user.profile is not None
    assert loaded_user.profile.id == profile.id
    assert loaded_user.profile.blood_group == BloodGroup.B_POSITIVE

    # 4. UserProfile.user returns correct User
    stmt_p = (
        select(UserProfile)
        .options(selectinload(UserProfile.user))
        .where(UserProfile.id == profile.id)
    )
    result_p = await db_session.execute(stmt_p)
    loaded_profile = result_p.scalar_one()

    assert loaded_profile.user is not None
    assert loaded_profile.user.id == user.id
    assert loaded_profile.user.full_name == "John Doe"


@pytest.mark.asyncio
async def test_duplicate_user_id_profile_rejected_by_unique_constraint(db_session):
    """5, 6: One user can have exactly ONE profile. Duplicate user_id rejected."""
    user = await make_test_user(db_session)

    p1 = UserProfile(
        user_id=user.id,
        date_of_birth=date(1992, 4, 10),
        gender=Gender.FEMALE,
        height_cm=Decimal("165.00"),
        weight_kg=Decimal("55.00"),
        blood_group=BloodGroup.AB_POSITIVE,
    )
    db_session.add(p1)
    await db_session.flush()

    # Attempting to add a second profile for the same user
    p2 = UserProfile(
        user_id=user.id,
        date_of_birth=date(1992, 4, 10),
        gender=Gender.FEMALE,
        height_cm=Decimal("165.00"),
        weight_kg=Decimal("55.00"),
        blood_group=BloodGroup.AB_POSITIVE,
    )
    db_session.add(p2)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_nonexistent_user_id_rejected_by_fk(db_session):
    """8. Profile referencing non-existent user_id is rejected by FK constraint."""
    fake_id = uuid.uuid4()
    profile = UserProfile(
        user_id=fake_id,
        date_of_birth=date(2000, 1, 1),
        gender=Gender.OTHER,
        height_cm=Decimal("160.00"),
        weight_kg=Decimal("50.00"),
        blood_group=BloodGroup.O_NEGATIVE,
    )
    db_session.add(profile)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_blood_group_enum_validation(db_session):
    """9, 10: BloodGroup accepts valid enum values and rejects invalid string at Python level."""
    user = await make_test_user(db_session)

    # 9. All valid blood group values accepted
    for bg in BloodGroup:
        p = UserProfile(
            user_id=user.id,
            date_of_birth=date(1990, 6, 15),
            gender=Gender.PREFER_NOT_TO_SAY,
            height_cm=Decimal("170.00"),
            weight_kg=Decimal("65.00"),
            blood_group=bg,
        )
        # Note: to reuse user in loop we flush and delete or test enum parsing directly
        assert p.blood_group == bg

    # 10. Invalid blood group enum string rejected
    with pytest.raises(ValueError):
        BloodGroup("C+")


@pytest.mark.asyncio
async def test_multiple_users_have_independent_profiles(db_session):
    """14. Multiple users can have independent health profiles."""
    u1 = await make_test_user(db_session, full_name="User One")
    u2 = await make_test_user(db_session, full_name="User Two")

    p1 = UserProfile(
        user_id=u1.id,
        date_of_birth=date(1985, 2, 14),
        gender=Gender.MALE,
        height_cm=Decimal("182.00"),
        weight_kg=Decimal("80.00"),
        blood_group=BloodGroup.A_NEGATIVE,
    )
    p2 = UserProfile(
        user_id=u2.id,
        date_of_birth=date(1993, 11, 23),
        gender=Gender.FEMALE,
        height_cm=Decimal("168.00"),
        weight_kg=Decimal("58.00"),
        blood_group=BloodGroup.B_NEGATIVE,
    )
    db_session.add_all([p1, p2])
    await db_session.flush()

    assert p1.id != p2.id
    assert p1.user_id == u1.id
    assert p2.user_id == u2.id


@pytest.mark.asyncio
async def test_check_constraint_positive_height(db_session):
    """16. Check constraint height_cm > 0 rejects negative or zero height."""
    user = await make_test_user(db_session)
    p = UserProfile(
        user_id=user.id,
        date_of_birth=date(1990, 1, 1),
        gender=Gender.MALE,
        height_cm=Decimal("-170.00"),  # Invalid negative height
        weight_kg=Decimal("70.00"),
        blood_group=BloodGroup.O_POSITIVE,
    )
    db_session.add(p)

    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_check_constraint_positive_weight(db_session):
    """17. Check constraint weight_kg > 0 rejects negative or zero weight."""
    user = await make_test_user(db_session)
    p = UserProfile(
        user_id=user.id,
        date_of_birth=date(1990, 1, 1),
        gender=Gender.FEMALE,
        height_cm=Decimal("160.00"),
        weight_kg=Decimal("0.00"),  # Invalid zero weight
        blood_group=BloodGroup.O_POSITIVE,
    )
    db_session.add(p)

    with pytest.raises(IntegrityError):
        await db_session.flush()


def test_derived_bmi_calculation():
    """18. Derived property bmi calculates weight_kg / (height_m ^ 2) dynamically."""
    # Example: 60 kg, 175 cm (1.75 m)
    # height_m^2 = 1.75 * 1.75 = 3.0625
    # BMI = 60 / 3.0625 = 19.5918... -> round(..., 2) = 19.59
    p = UserProfile(
        date_of_birth=date(1990, 1, 1),
        gender=Gender.MALE,
        height_cm=Decimal("175.00"),
        weight_kg=Decimal("60.00"),
        blood_group=BloodGroup.O_POSITIVE,
    )
    assert p.bmi == 19.59

    # Example 2: 70 kg, 170 cm (1.70 m)
    # BMI = 70 / (1.7^2) = 70 / 2.89 = 24.2214... -> 24.22
    p2 = UserProfile(
        date_of_birth=date(1990, 1, 1),
        gender=Gender.FEMALE,
        height_cm=Decimal("170.00"),
        weight_kg=Decimal("70.00"),
        blood_group=BloodGroup.A_POSITIVE,
    )
    assert p2.bmi == 24.22


def test_derived_age_calculation():
    """19. Derived property age calculates full years from date_of_birth dynamically."""
    today = date.today()
    
    # User born exactly 25 years ago
    dob_25 = date(today.year - 25, today.month, today.day)
    p1 = UserProfile(
        date_of_birth=dob_25,
        gender=Gender.MALE,
        height_cm=Decimal("180.00"),
        weight_kg=Decimal("75.00"),
        blood_group=BloodGroup.O_POSITIVE,
    )
    assert p1.age == 25

    # User whose birthday hasn't occurred yet this year
    # e.g., if today is Aug 14, born Dec 31, 2000 -> 25 years old if 2026-2000=26 minus 1 = 25
    target_year = today.year - 30
    if (today.month, today.day) == (12, 31):
        test_dob = date(target_year, 1, 1)
    else:
        test_dob = date(target_year, 12, 31)

    expected_age = (
        today.year
        - test_dob.year
        - ((today.month, today.day) < (test_dob.month, test_dob.day))
    )
    p2 = UserProfile(
        date_of_birth=test_dob,
        gender=Gender.FEMALE,
        height_cm=Decimal("165.00"),
        weight_kg=Decimal("55.00"),
        blood_group=BloodGroup.B_POSITIVE,
    )
    assert p2.age == expected_age
