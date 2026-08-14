"""Create measurement_results table and signal_quality_level_enum.

Revision ID: 0005
Revises: 0004
Create Date: 2026-08-14

Summary
-------
Creates:
  * signal_quality_level_enum — PostgreSQL ENUM ('LOW', 'FAIR', 'GOOD', 'EXCELLENT')
  * measurement_results — Finalized ML analysis output for a measurement session

Constraints:
  * PRIMARY KEY (id) — independent UUID
  * UNIQUE (measurement_id) — enforces one result per measurement
  * FOREIGN KEY (measurement_id) REFERENCES measurements(id)
  * ix_measurement_results_measurement_id — unique index on measurement_id

Nullable Design
---------------
Only id, measurement_id, rescan_recommended, created_at, and updated_at are
NOT NULL.  All result metric columns (heart_rate_bpm, systolic_bp_mmhg, etc.)
are nullable to accommodate partial ML output and evolving ML contracts.

Design notes
------------
* Independent UUID primary key (gen_random_uuid()) — never equals measurements.id
  or users.id.
* bmi is a historical snapshot captured at measurement time, distinct from the
  derived bmi property on UserProfile.
* analysis JSONB column stores structured interpretation metadata (status
  classifications, messages) — NOT raw numeric metric values.
* model_name, model_version, processed_at allow ML provenance tracking.
* No ON DELETE CASCADE — historical health results must be preserved.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ---------------------------------------------------------------------------
# Revision identifiers
# ---------------------------------------------------------------------------
revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ---------------------------------------------------------------------------
# Enum definition
# ---------------------------------------------------------------------------
signal_quality_level_enum = postgresql.ENUM(
    "LOW",
    "FAIR",
    "GOOD",
    "EXCELLENT",
    name="signal_quality_level_enum",
    create_type=False,
)


def upgrade() -> None:
    # 1. Create signal_quality_level_enum PostgreSQL ENUM type
    signal_quality_level_enum.create(op.get_bind(), checkfirst=True)

    # 2. Create measurement_results table
    op.create_table(
        "measurement_results",
        # ---- Primary Key ----
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            comment="Independent primary key UUID for the measurement result.",
        ),
        # ---- Measurement Reference ----
        sa.Column(
            "measurement_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey(
                "measurements.id",
                name="fk_measurement_results_measurement_id_measurements",
            ),
            nullable=False,
            unique=True,
            comment="UUID of the associated measurement (1:1, UNIQUE).",
        ),
        # ---- Cardiovascular Metrics (nullable) ----
        sa.Column(
            "heart_rate_bpm",
            sa.Numeric(precision=6, scale=2),
            nullable=True,
            comment="Heart rate in beats per minute.",
        ),
        sa.Column(
            "systolic_bp_mmhg",
            sa.Numeric(precision=6, scale=2),
            nullable=True,
            comment="Systolic blood pressure in mmHg.",
        ),
        sa.Column(
            "diastolic_bp_mmhg",
            sa.Numeric(precision=6, scale=2),
            nullable=True,
            comment="Diastolic blood pressure in mmHg.",
        ),
        sa.Column(
            "hrv_ms",
            sa.Numeric(precision=7, scale=2),
            nullable=True,
            comment="Heart rate variability in milliseconds.",
        ),
        # ---- Respiratory & ANS Metrics (nullable) ----
        sa.Column(
            "breathing_rate_bpm",
            sa.Numeric(precision=6, scale=2),
            nullable=True,
            comment="Breathing rate in breaths per minute.",
        ),
        sa.Column(
            "stress_index",
            sa.Numeric(precision=7, scale=3),
            nullable=True,
            comment="Stress index derived from HRV and autonomic activity.",
        ),
        sa.Column(
            "cardiac_workload",
            sa.Numeric(precision=10, scale=2),
            nullable=True,
            comment="Cardiac workload metric.",
        ),
        sa.Column(
            "parasympathetic_activity_percent",
            sa.Numeric(precision=5, scale=2),
            nullable=True,
            comment="Parasympathetic activity as a percentage.",
        ),
        # ---- Body Composition Snapshot (nullable) ----
        sa.Column(
            "bmi",
            sa.Numeric(precision=5, scale=2),
            nullable=True,
            comment="Historical BMI snapshot at time of measurement.",
        ),
        sa.Column(
            "bmi_classification",
            sa.String(length=50),
            nullable=True,
            comment="BMI classification label at time of measurement.",
        ),
        # ---- Signal Quality ----
        sa.Column(
            "signal_quality_score",
            sa.Numeric(precision=5, scale=4),
            nullable=True,
            comment="Signal quality score in range [0.0, 1.0].",
        ),
        sa.Column(
            "signal_quality_level",
            postgresql.ENUM(
                "LOW",
                "FAIR",
                "GOOD",
                "EXCELLENT",
                name="signal_quality_level_enum",
                create_type=False,
            ),
            nullable=True,
            comment="Categorical signal quality level.",
        ),
        sa.Column(
            "rescan_recommended",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="Whether a rescan is recommended.",
        ),
        sa.Column(
            "quality_message",
            sa.Text(),
            nullable=True,
            comment="Optional human-readable quality explanation.",
        ),
        # ---- Analysis JSONB ----
        sa.Column(
            "analysis",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
            comment="JSONB structured interpretation metadata.",
        ),
        # ---- ML Provenance (nullable) ----
        sa.Column(
            "model_name",
            sa.String(length=100),
            nullable=True,
            comment="Name of the ML model that generated this result.",
        ),
        sa.Column(
            "model_version",
            sa.String(length=50),
            nullable=True,
            comment="Version string of the ML model.",
        ),
        sa.Column(
            "processed_at",
            sa.TIMESTAMP(timezone=True),
            nullable=True,
            comment="Timestamp when the ML pipeline completed processing.",
        ),
        # ---- Audit Timestamps ----
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Row creation timestamp.",
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Row update timestamp.",
        ),
    )

    # 3. Create unique index on measurement_id
    op.create_index(
        "ix_measurement_results_measurement_id",
        "measurement_results",
        ["measurement_id"],
        unique=True,
    )


def downgrade() -> None:
    # 1. Drop index
    op.drop_index(
        "ix_measurement_results_measurement_id",
        table_name="measurement_results",
    )

    # 2. Drop table
    op.drop_table("measurement_results")

    # 3. Drop ENUM type
    signal_quality_level_enum.drop(op.get_bind(), checkfirst=True)
