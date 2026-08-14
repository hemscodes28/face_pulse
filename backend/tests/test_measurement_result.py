"""
face_pulse/backend/tests/test_measurement_result.py
=====================================================
Unit tests for MeasurementResult ORM model and 1:1 Measurement relationship.
(Milestone 3)

Verification Criteria
---------------------
1.  Result creation with valid values.
2.  Result UUID auto-generation.
3.  MeasurementResult.id is independent from Measurement.id.
4.  MeasurementResult.id is independent from User.id.
5.  measurement_id FK references a valid measurement.
6.  Invalid measurement_id rejected by FK constraint.
7.  One Measurement can have exactly one Result (UNIQUE constraint).
8.  Duplicate measurement_id rejected by UNIQUE constraint.
9.  Measurement.result returns the correct MeasurementResult.
10. MeasurementResult.measurement returns the correct Measurement.
11. All numeric metrics store and retrieve correctly.
12. bmi historical snapshot stores correctly.
13. bmi_classification stores correctly.
14. Signal quality fields store correctly.
15. rescan_recommended stores correctly (default False).
16. quality_message stores correctly.
17. JSONB analysis stores and retrieves correctly.
18. model_name stores correctly.
19. model_version stores correctly.
20. processed_at stores correctly.
21. Multiple users can have independent measurement results.
22-25. Existing M1, M2, M2.5, M2.75 tests unaffected (confirmed via full run).

SQLite Limitations Documented
------------------------------
* JSONB is stored as TEXT in SQLite; dict serialisation is handled by SQLAlchemy.
* signal_quality_level_enum stored as VARCHAR in SQLite (no native PG ENUM check).
* gen_random_uuid() does not run in SQLite; Python-side uuid.uuid4 default fires.
* TIMESTAMPTZ offsets are not preserved in SQLite.
PostgreSQL-specific behaviour is validated via DDL compilation tests.
"""

import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.models.measurement import Measurement, MeasurementStatus
from app.models.measurement_result import MeasurementResult, SignalQualityLevel
from app.models.user import User, UserRole


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def make_user(db_session, email: str | None = None) -> User:
    user = User(
        full_name="Result Test User",
        email=email or f"result_user_{uuid.uuid4().hex[:8]}@example.com",
        password_hash="hashed_pw",
        role=UserRole.USER,
    )
    db_session.add(user)
    await db_session.flush()
    await db_session.refresh(user)
    return user


async def make_measurement(db_session, user: User) -> Measurement:
    m = Measurement(user_id=user.id, status=MeasurementStatus.COMPLETED)
    db_session.add(m)
    await db_session.flush()
    await db_session.refresh(m)
    return m


def make_result(measurement: Measurement, **overrides) -> MeasurementResult:
    """Build a MeasurementResult with sensible defaults, allowing overrides."""
    defaults = dict(
        measurement_id=measurement.id,
        heart_rate_bpm=Decimal("72.50"),
        systolic_bp_mmhg=Decimal("120.00"),
        diastolic_bp_mmhg=Decimal("80.00"),
        hrv_ms=Decimal("45.30"),
        breathing_rate_bpm=Decimal("16.00"),
        stress_index=Decimal("2.750"),
        cardiac_workload=Decimal("8700.00"),
        parasympathetic_activity_percent=Decimal("62.50"),
        bmi=Decimal("22.50"),
        bmi_classification="Normal",
        signal_quality_score=Decimal("0.8750"),
        signal_quality_level=SignalQualityLevel.GOOD,
        rescan_recommended=False,
        quality_message="Signal quality is acceptable.",
        analysis={
            "heart_rate": {"status": "NORMAL"},
            "blood_pressure": {"status": "NORMAL"},
            "bmi": {"status": "NORMAL", "message": "BMI is within the normal range."},
        },
        model_name="rPPG-Analyzer",
        model_version="1.2.3",
        processed_at=datetime(2026, 8, 14, 10, 0, 0, tzinfo=timezone.utc),
    )
    defaults.update(overrides)
    return MeasurementResult(**defaults)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_result_creation_and_defaults(db_session):
    """1, 2: MeasurementResult can be created with valid values; UUID auto-generated."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)

    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.id is not None
    assert isinstance(result.id, uuid.UUID)
    assert result.id != uuid.UUID(int=0)
    assert result.measurement_id == measurement.id
    assert result.rescan_recommended is False
    assert result.created_at is not None
    assert result.updated_at is not None


@pytest.mark.asyncio
async def test_result_id_independent_from_measurement_id(db_session):
    """3. MeasurementResult.id != Measurement.id."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()

    assert result.id != measurement.id
    assert isinstance(result.id, uuid.UUID)
    assert isinstance(measurement.id, uuid.UUID)


@pytest.mark.asyncio
async def test_result_id_independent_from_user_id(db_session):
    """4. MeasurementResult.id != User.id."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()

    assert result.id != user.id


@pytest.mark.asyncio
async def test_measurement_id_references_valid_measurement(db_session):
    """5. measurement_id FK correctly references an existing measurement."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()

    assert result.measurement_id == measurement.id


@pytest.mark.asyncio
async def test_invalid_measurement_id_rejected(db_session):
    """6. measurement_id referencing a non-existent measurement is rejected by FK."""
    fake_measurement_id = uuid.uuid4()
    result = MeasurementResult(
        measurement_id=fake_measurement_id,
        rescan_recommended=False,
    )
    db_session.add(result)
    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_one_measurement_one_result_unique_constraint(db_session):
    """7, 8. One measurement can have exactly one result; duplicate rejected."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)

    r1 = make_result(measurement)
    db_session.add(r1)
    await db_session.flush()

    # Second result for same measurement must be rejected
    r2 = make_result(measurement)
    db_session.add(r2)
    with pytest.raises(IntegrityError):
        await db_session.flush()


@pytest.mark.asyncio
async def test_measurement_result_relationship(db_session):
    """9. Measurement.result returns the correct MeasurementResult."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()

    stmt = (
        select(Measurement)
        .options(selectinload(Measurement.result))
        .where(Measurement.id == measurement.id)
    )
    loaded = (await db_session.execute(stmt)).scalar_one()

    assert loaded.result is not None
    assert loaded.result.id == result.id
    assert loaded.result.heart_rate_bpm == Decimal("72.50")


@pytest.mark.asyncio
async def test_result_measurement_relationship(db_session):
    """10. MeasurementResult.measurement returns the correct Measurement."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()

    stmt = (
        select(MeasurementResult)
        .options(selectinload(MeasurementResult.measurement))
        .where(MeasurementResult.id == result.id)
    )
    loaded = (await db_session.execute(stmt)).scalar_one()

    assert loaded.measurement is not None
    assert loaded.measurement.id == measurement.id
    assert loaded.measurement.user_id == user.id


@pytest.mark.asyncio
async def test_all_numeric_metrics_store_correctly(db_session):
    """11. All numeric metric columns store and retrieve accurately."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement)
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert Decimal(str(result.heart_rate_bpm)) == Decimal("72.50")
    assert Decimal(str(result.systolic_bp_mmhg)) == Decimal("120.00")
    assert Decimal(str(result.diastolic_bp_mmhg)) == Decimal("80.00")
    assert Decimal(str(result.hrv_ms)) == Decimal("45.30")
    assert Decimal(str(result.breathing_rate_bpm)) == Decimal("16.00")
    assert Decimal(str(result.stress_index)) == Decimal("2.750")
    assert Decimal(str(result.cardiac_workload)) == Decimal("8700.00")
    assert Decimal(str(result.parasympathetic_activity_percent)) == Decimal("62.50")


@pytest.mark.asyncio
async def test_bmi_historical_snapshot_stores_correctly(db_session):
    """12, 13. bmi and bmi_classification store correctly as historical snapshot."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement, bmi=Decimal("27.80"), bmi_classification="Overweight")
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert Decimal(str(result.bmi)) == Decimal("27.80")
    assert result.bmi_classification == "Overweight"


@pytest.mark.asyncio
async def test_signal_quality_fields_store_correctly(db_session):
    """14. Signal quality fields store and retrieve accurately."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(
        measurement,
        signal_quality_score=Decimal("0.4200"),
        signal_quality_level=SignalQualityLevel.LOW,
        rescan_recommended=True,
        quality_message="Signal quality is below acceptable threshold.",
    )
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert Decimal(str(result.signal_quality_score)) == Decimal("0.4200")
    assert result.signal_quality_level == SignalQualityLevel.LOW
    assert result.rescan_recommended is True
    assert result.quality_message == "Signal quality is below acceptable threshold."


@pytest.mark.asyncio
async def test_rescan_recommended_default_false(db_session):
    """15. rescan_recommended defaults to False when not explicitly set."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = MeasurementResult(measurement_id=measurement.id)
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.rescan_recommended is False


@pytest.mark.asyncio
async def test_quality_message_nullable(db_session):
    """16. quality_message is nullable; result without message is valid."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement, quality_message=None)
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.quality_message is None


@pytest.mark.asyncio
async def test_jsonb_analysis_stores_and_retrieves_correctly(db_session):
    """17. JSONB analysis column stores and retrieves structured data correctly."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    analysis_payload = {
        "heart_rate": {"status": "ELEVATED"},
        "blood_pressure": {"status": "NORMAL"},
        "bmi": {"status": "OVERWEIGHT", "message": "Consider lifestyle adjustments."},
        "stress": {"status": "HIGH", "score": 3.5},
    }
    result = make_result(measurement, analysis=analysis_payload)
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.analysis is not None
    assert result.analysis["heart_rate"]["status"] == "ELEVATED"
    assert result.analysis["bmi"]["message"] == "Consider lifestyle adjustments."
    assert result.analysis["stress"]["score"] == 3.5


@pytest.mark.asyncio
async def test_analysis_nullable(db_session):
    """17b. analysis JSONB column is nullable."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = make_result(measurement, analysis=None)
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.analysis is None


@pytest.mark.asyncio
async def test_ml_provenance_fields_store_correctly(db_session):
    """18, 19, 20. model_name, model_version, processed_at store correctly."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    ts = datetime(2026, 8, 14, 12, 30, 0, tzinfo=timezone.utc)
    result = make_result(
        measurement,
        model_name="FacePulse-ML",
        model_version="2.0.0-beta",
        processed_at=ts,
    )
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.model_name == "FacePulse-ML"
    assert result.model_version == "2.0.0-beta"
    assert result.processed_at is not None


@pytest.mark.asyncio
async def test_multiple_users_independent_results(db_session):
    """21. Multiple users can each have their own independent measurement results."""
    u1 = await make_user(db_session)
    u2 = await make_user(db_session)
    m1 = await make_measurement(db_session, u1)
    m2 = await make_measurement(db_session, u2)

    r1 = make_result(m1, heart_rate_bpm=Decimal("65.00"))
    r2 = make_result(m2, heart_rate_bpm=Decimal("88.00"))
    db_session.add_all([r1, r2])
    await db_session.flush()

    assert r1.id != r2.id
    assert r1.measurement_id == m1.id
    assert r2.measurement_id == m2.id
    assert r1.heart_rate_bpm == Decimal("65.00")
    assert r2.heart_rate_bpm == Decimal("88.00")


@pytest.mark.asyncio
async def test_partial_result_with_null_metrics(db_session):
    """Nullable metrics: result with only required fields is valid."""
    user = await make_user(db_session)
    measurement = await make_measurement(db_session, user)
    result = MeasurementResult(
        measurement_id=measurement.id,
        rescan_recommended=True,
        quality_message="Insufficient signal quality. Please rescan.",
    )
    db_session.add(result)
    await db_session.flush()
    await db_session.refresh(result)

    assert result.heart_rate_bpm is None
    assert result.systolic_bp_mmhg is None
    assert result.bmi is None
    assert result.analysis is None
    assert result.model_name is None
    assert result.rescan_recommended is True


def test_signal_quality_level_enum_values():
    """Signal quality levels contain exactly the four expected values."""
    values = {level.value for level in SignalQualityLevel}
    assert values == {"LOW", "FAIR", "GOOD", "EXCELLENT"}


def test_invalid_signal_quality_level_rejected():
    """Invalid signal quality level string is rejected at Python level."""
    with pytest.raises(ValueError):
        SignalQualityLevel("UNKNOWN")
