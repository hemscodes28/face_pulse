"""
face_pulse/backend/app/models/measurement_result.py
=====================================================
ORM model for the `measurement_results` table.

Represents the finalized analysis output produced by the ML pipeline
for exactly one measurement session.

Design Principles
-----------------
1. One-to-one relationship with `measurements` (measurement_id is UNIQUE).
2. Primary key `id` is an **independent** UUID — never equal to measurements.id
   or users.id.
3. All result metric columns (heart_rate_bpm, systolic_bp_mmhg, etc.) are
   NULLABLE.  The ML pipeline may produce partial results, and the exact
   output contract may evolve.  Only id, measurement_id, rescan_recommended,
   created_at, and updated_at are NOT NULL.
4. bmi is stored here as a *historical snapshot* associated with this specific
   measurement result.  This is intentionally distinct from the derived bmi
   property on UserProfile, which reflects *current* height/weight.
5. analysis is a JSONB column for structured interpretation metadata (status
   classifications, messages).  Canonical numeric values are stored in their
   dedicated columns — analysis does NOT duplicate them.
6. model_name / model_version / processed_at allow historical results to be
   traced back to the ML model version that produced them.
7. No raw camera frames, rPPG signals, facial landmarks, or ML tensors are
   stored here.  Only finalized analysis output belongs in this table.

See docs/database.md for full design rationale.
"""

import enum
import uuid
from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING, Any

from sqlalchemy import Boolean, Enum as SAEnum, ForeignKey, JSON, Numeric, String
from sqlalchemy import TIMESTAMP, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.measurement import Measurement


# ---------------------------------------------------------------------------
# SignalQualityLevel ENUM
# ---------------------------------------------------------------------------


class SignalQualityLevel(str, enum.Enum):
    """
    Categorical assessment of the rPPG signal quality for a measurement.

    LOW       Signal quality below acceptable threshold; rescan recommended.
    FAIR      Signal quality marginal; results may be less accurate.
    GOOD      Signal quality acceptable; results are reliable.
    EXCELLENT Signal quality optimal; results are highly reliable.
    """

    LOW = "LOW"
    FAIR = "FAIR"
    GOOD = "GOOD"
    EXCELLENT = "EXCELLENT"


signal_quality_level_pg_enum = SAEnum(
    SignalQualityLevel,
    name="signal_quality_level_enum",
    create_constraint=True,
    validate_strings=True,
)


# ---------------------------------------------------------------------------
# MeasurementResult model
# ---------------------------------------------------------------------------


class MeasurementResult(Base):
    """
    ORM representation of the `measurement_results` table.

    Each row holds the finalized ML analysis output for one measurement session.
    The 1:1 relationship to measurements is enforced at the database level via
    UNIQUE constraint on measurement_id.

    Columns
    -------
    id                              Independent UUID primary key.
    measurement_id                  UUID FK → measurements.id (UNIQUE, NOT NULL).

    -- Cardiovascular Metrics --
    heart_rate_bpm                  Heart rate in beats per minute (nullable).
    systolic_bp_mmhg                Systolic blood pressure in mmHg (nullable).
    diastolic_bp_mmhg               Diastolic blood pressure in mmHg (nullable).
    hrv_ms                          Heart rate variability in milliseconds (nullable).

    -- Respiratory / ANS Metrics --
    breathing_rate_bpm              Breathing rate in breaths per minute (nullable).
    stress_index                    Stress index value (nullable).
    cardiac_workload                Cardiac workload metric (nullable).
    parasympathetic_activity_percent  Parasympathetic activity as percentage (nullable).

    -- Body Composition Snapshot --
    bmi                             Historical BMI snapshot at time of measurement (nullable).
    bmi_classification              BMI classification label at time of measurement (nullable).

    -- Signal Quality --
    signal_quality_score            Quality score in range 0.0–1.0 (nullable).
    signal_quality_level            Categorical quality level enum (nullable).
    rescan_recommended              Whether a rescan is advised (NOT NULL, default FALSE).
    quality_message                 Optional human-readable quality explanation (nullable).

    -- Analysis Interpretation --
    analysis                        JSONB structured interpretation metadata (nullable).

    -- ML Provenance --
    model_name                      Name of the ML model used (nullable).
    model_version                   Version string of the ML model (nullable).
    processed_at                    When the ML pipeline completed processing (nullable).

    -- Audit Timestamps --
    created_at                      Row creation timestamp (NOT NULL, DB default).
    updated_at                      Row update timestamp (NOT NULL, DB default).

    Relationships
    -------------
    measurement   Many-to-one (1:1 enforced by UNIQUE) back to Measurement.
    """

    __tablename__ = "measurement_results"

    # ------------------------------------------------------------------
    # Primary key — independent UUID
    # ------------------------------------------------------------------
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=func.gen_random_uuid(),
        comment="Independent primary key UUID for the measurement result.",
    )

    # ------------------------------------------------------------------
    # Measurement reference — 1:1 enforced by UNIQUE
    # ------------------------------------------------------------------
    measurement_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("measurements.id"),
        unique=True,
        nullable=False,
        index=True,
        comment=(
            "UUID of the associated measurement session. "
            "UNIQUE enforces one result per measurement."
        ),
    )

    # ------------------------------------------------------------------
    # Cardiovascular Metrics (nullable — ML contract may evolve)
    # ------------------------------------------------------------------
    heart_rate_bpm: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 2),
        nullable=True,
        comment="Heart rate in beats per minute.",
    )

    systolic_bp_mmhg: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 2),
        nullable=True,
        comment="Systolic blood pressure in millimeters of mercury.",
    )

    diastolic_bp_mmhg: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 2),
        nullable=True,
        comment="Diastolic blood pressure in millimeters of mercury.",
    )

    hrv_ms: Mapped[Decimal | None] = mapped_column(
        Numeric(7, 2),
        nullable=True,
        comment="Heart rate variability in milliseconds.",
    )

    # ------------------------------------------------------------------
    # Respiratory & Autonomic Nervous System Metrics (nullable)
    # ------------------------------------------------------------------
    breathing_rate_bpm: Mapped[Decimal | None] = mapped_column(
        Numeric(6, 2),
        nullable=True,
        comment="Breathing rate in breaths per minute.",
    )

    stress_index: Mapped[Decimal | None] = mapped_column(
        Numeric(7, 3),
        nullable=True,
        comment="Stress index derived from HRV and autonomic activity.",
    )

    cardiac_workload: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 2),
        nullable=True,
        comment="Cardiac workload metric (product of HR and systolic BP).",
    )

    parasympathetic_activity_percent: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 2),
        nullable=True,
        comment="Parasympathetic nervous system activity as a percentage.",
    )

    # ------------------------------------------------------------------
    # Body Composition Snapshot (nullable)
    # Historical BMI associated with this specific measurement result.
    # Distinct from UserProfile.bmi which is derived from current height/weight.
    # ------------------------------------------------------------------
    bmi: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 2),
        nullable=True,
        comment=(
            "Historical BMI snapshot at time of this measurement. "
            "Distinct from the derived UserProfile.bmi property."
        ),
    )

    bmi_classification: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="BMI classification label (e.g. 'Normal', 'Overweight') at time of measurement.",
    )

    # ------------------------------------------------------------------
    # Signal Quality (rescan_recommended is NOT NULL)
    # ------------------------------------------------------------------
    signal_quality_score: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 4),
        nullable=True,
        comment="Signal quality score in range [0.0, 1.0]; 4 decimal places.",
    )

    signal_quality_level: Mapped[SignalQualityLevel | None] = mapped_column(
        signal_quality_level_pg_enum,
        nullable=True,
        comment="Categorical signal quality level: LOW, FAIR, GOOD, or EXCELLENT.",
    )

    rescan_recommended: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default="false",
        comment="Whether the ML pipeline recommends a rescan due to low quality.",
    )

    quality_message: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Optional human-readable explanation of signal quality.",
    )

    # ------------------------------------------------------------------
    # Structured Interpretation (JSON — nullable)
    # SQLAlchemy JSON type renders as JSONB in the Alembic migration for
    # PostgreSQL, and as JSON/TEXT in SQLite for unit tests.
    # Contains classification statuses and messages, NOT raw metric values.
    # ------------------------------------------------------------------
    analysis: Mapped[dict[str, Any] | None] = mapped_column(
        JSON,
        nullable=True,
        comment=(
            "JSON structured interpretation metadata. "
            "Contains status classifications and messages for each metric. "
            "Does NOT duplicate canonical numeric values. "
            "Stored as JSONB in PostgreSQL via Alembic migration."
        ),
    )

    # ------------------------------------------------------------------
    # ML Model Provenance (nullable)
    # ------------------------------------------------------------------
    model_name: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Name of the ML model that generated this result.",
    )

    model_version: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Version string of the ML model (e.g. '1.2.3').",
    )

    processed_at: Mapped[datetime | None] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=True,
        comment="Timestamp when the ML pipeline completed processing.",
    )

    # ------------------------------------------------------------------
    # Audit Timestamps (NOT NULL)
    # ------------------------------------------------------------------
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        comment="Row creation timestamp (set by DB on insert).",
    )

    updated_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
        comment="Row update timestamp.",
    )

    # ------------------------------------------------------------------
    # Relationship
    # ------------------------------------------------------------------
    measurement: Mapped["Measurement"] = relationship(
        "Measurement",
        back_populates="result",
    )

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<MeasurementResult id={self.id} "
            f"measurement_id={self.measurement_id} "
            f"hr={self.heart_rate_bpm}>"
        )
