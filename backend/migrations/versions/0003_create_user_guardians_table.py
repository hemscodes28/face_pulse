"""Create user_guardians table, guardian_relationship_status enum, foreign keys, and constraints.

Revision ID: 0003
Revises: 0002
Create Date: 2026-08-14

Summary
-------
Creates:
  * guardian_relationship_status — PostgreSQL ENUM type ('PENDING', 'ACCEPTED', 'REJECTED', 'REVOKED')
  * user_guardians — Table storing guardian relationships and sharing permission flags
  * ix_user_guardians_user_id — Index on user_id (data owner)
  * ix_user_guardians_guardian_user_id — Index on guardian_user_id (guardian recipient)
  * uq_user_guardians_user_guardian — Unique constraint on (user_id, guardian_user_id) preventing duplicate relationships
  * ck_user_guardians_prevent_self_guardian — CHECK constraint ensuring user_id <> guardian_user_id

Design notes
------------
* Independent UUID primary key (gen_random_uuid()) for user_guardians table.
* FK constraints to users.id for both columns, without ON DELETE CASCADE to preserve metadata.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ---------------------------------------------------------------------------
# Revision identifiers
# ---------------------------------------------------------------------------
revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ---------------------------------------------------------------------------
# Enum definition for guardian_relationship_status
# ---------------------------------------------------------------------------
guardian_relationship_status_enum = postgresql.ENUM(
    "PENDING",
    "ACCEPTED",
    "REJECTED",
    "REVOKED",
    name="guardian_relationship_status",
    create_type=False,
)


def upgrade() -> None:
    # 1. Create the guardian_relationship_status ENUM type first
    guardian_relationship_status_enum.create(op.get_bind(), checkfirst=True)

    # 2. Create user_guardians table
    op.create_table(
        "user_guardians",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            comment="Primary key UUID for the guardian relationship.",
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", name="fk_user_guardians_user_id_users"),
            nullable=False,
            comment="UUID of the data owner account.",
        ),
        sa.Column(
            "guardian_user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", name="fk_user_guardians_guardian_user_id_users"),
            nullable=False,
            comment="UUID of the receiving guardian user account.",
        ),
        sa.Column(
            "status",
            postgresql.ENUM(
                "PENDING",
                "ACCEPTED",
                "REJECTED",
                "REVOKED",
                name="guardian_relationship_status",
                create_type=False,
            ),
            nullable=False,
            server_default="PENDING",
            comment="Current status of the guardian relationship.",
        ),
        sa.Column(
            "share_results",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="Permission flag for viewing completed measurement results.",
        ),
        sa.Column(
            "share_trends",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="Permission flag for viewing historical measurement trends.",
        ),
        sa.Column(
            "share_alerts",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="Permission flag for receiving measurement alerts.",
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Relationship creation timestamp.",
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Relationship update timestamp.",
        ),
        sa.CheckConstraint(
            "user_id <> guardian_user_id",
            name="ck_user_guardians_prevent_self_guardian",
        ),
        sa.UniqueConstraint(
            "user_id",
            "guardian_user_id",
            name="uq_user_guardians_user_guardian",
        ),
    )

    # 3. Create indexes
    op.create_index(
        "ix_user_guardians_user_id",
        "user_guardians",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_guardians_guardian_user_id",
        "user_guardians",
        ["guardian_user_id"],
        unique=False,
    )


def downgrade() -> None:
    # 1. Drop indexes
    op.drop_index("ix_user_guardians_guardian_user_id", table_name="user_guardians")
    op.drop_index("ix_user_guardians_user_id", table_name="user_guardians")

    # 2. Drop table (this also drops constraints defined on the table)
    op.drop_table("user_guardians")

    # 3. Drop guardian_relationship_status ENUM type
    guardian_relationship_status_enum.drop(op.get_bind(), checkfirst=True)
