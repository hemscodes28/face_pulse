"""Create user_profiles table, gender_enum, blood_group_enum, FKs, and check constraints.

Revision ID: 0004
Revises: 0003
Create Date: 2026-08-14

Summary
-------
Creates:
  * gender_enum — PostgreSQL ENUM ('MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY')
  * blood_group_enum — PostgreSQL ENUM ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
  * user_profiles — Table storing 1:1 user health profile attributes
  * ix_user_profiles_user_id — Unique index on user_profiles.user_id
  * ck_user_profiles_positive_height — CHECK constraint (height_cm > 0)
  * ck_user_profiles_positive_weight — CHECK constraint (weight_kg > 0)

Design notes
------------
* Independent UUID primary key (gen_random_uuid()) for user_profiles.
* FK user_id -> users.id with UNIQUE constraint enforcing 1:1 relationship.
* No permanent database columns for age or BMI (derived dynamically).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ---------------------------------------------------------------------------
# Revision identifiers
# ---------------------------------------------------------------------------
revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ---------------------------------------------------------------------------
# Enum definitions
# ---------------------------------------------------------------------------
gender_enum = postgresql.ENUM(
    "MALE",
    "FEMALE",
    "OTHER",
    "PREFER_NOT_TO_SAY",
    name="gender_enum",
    create_type=False,
)

blood_group_enum = postgresql.ENUM(
    "A+",
    "A-",
    "B+",
    "B-",
    "AB+",
    "AB-",
    "O+",
    "O-",
    name="blood_group_enum",
    create_type=False,
)


def upgrade() -> None:
    # 1. Create PostgreSQL ENUM types first
    gender_enum.create(op.get_bind(), checkfirst=True)
    blood_group_enum.create(op.get_bind(), checkfirst=True)

    # 2. Create user_profiles table
    op.create_table(
        "user_profiles",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            comment="Primary key UUID for the user health profile.",
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", name="fk_user_profiles_user_id_users"),
            nullable=False,
            unique=True,
            comment="UUID of the associated user (1:1 relationship).",
        ),
        sa.Column(
            "date_of_birth",
            sa.Date(),
            nullable=False,
            comment="User date of birth.",
        ),
        sa.Column(
            "gender",
            postgresql.ENUM(
                "MALE",
                "FEMALE",
                "OTHER",
                "PREFER_NOT_TO_SAY",
                name="gender_enum",
                create_type=False,
            ),
            nullable=False,
            comment="Gender representation for health context.",
        ),
        sa.Column(
            "height_cm",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            comment="Height in centimeters (must be > 0).",
        ),
        sa.Column(
            "weight_kg",
            sa.Numeric(precision=5, scale=2),
            nullable=False,
            comment="Weight in kilograms (must be > 0).",
        ),
        sa.Column(
            "blood_group",
            postgresql.ENUM(
                "A+",
                "A-",
                "B+",
                "B-",
                "AB+",
                "AB-",
                "O+",
                "O-",
                name="blood_group_enum",
                create_type=False,
            ),
            nullable=False,
            comment="ABO/Rh blood group category.",
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Profile creation timestamp.",
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Profile update timestamp.",
        ),
        sa.CheckConstraint(
            "height_cm > 0",
            name="ck_user_profiles_positive_height",
        ),
        sa.CheckConstraint(
            "weight_kg > 0",
            name="ck_user_profiles_positive_weight",
        ),
    )

    # 3. Create index on user_id
    op.create_index(
        "ix_user_profiles_user_id",
        "user_profiles",
        ["user_id"],
        unique=True,
    )


def downgrade() -> None:
    # 1. Drop index
    op.drop_index("ix_user_profiles_user_id", table_name="user_profiles")

    # 2. Drop user_profiles table
    op.drop_table("user_profiles")

    # 3. Drop ENUM types
    blood_group_enum.drop(op.get_bind(), checkfirst=True)
    gender_enum.drop(op.get_bind(), checkfirst=True)
