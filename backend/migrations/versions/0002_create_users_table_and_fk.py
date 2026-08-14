"""Create users table, user_role enum, and add foreign key on measurements.user_id.

Revision ID: 0002
Revises: 0001
Create Date: 2026-08-14

Summary
-------
Creates:
  * user_role — PostgreSQL ENUM type ('USER')
  * users — User accounts table with UUID primary key, full_name, email, password_hash, role, is_active, timestamps
  * ix_users_email — Unique index on users.email
  * fk_measurements_user_id_users — Foreign key from measurements.user_id to users.id

Design notes
------------
* UUID primary key (gen_random_uuid()) for users table.
* Role ENUM currently contains 'USER'.
* FK from measurements.user_id to users.id without ON DELETE CASCADE,
  preserving health measurement history if user account is deactivated/deleted.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ---------------------------------------------------------------------------
# Revision identifiers
# ---------------------------------------------------------------------------
revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# ---------------------------------------------------------------------------
# Enum definition for user_role
# ---------------------------------------------------------------------------
user_role_enum = postgresql.ENUM(
    "USER",
    name="user_role",
    create_type=False,
)


def upgrade() -> None:
    # 1. Create the user_role ENUM type first
    user_role_enum.create(op.get_bind(), checkfirst=True)

    # 2. Create users table
    op.create_table(
        "users",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
            comment="Primary key UUID for the user account.",
        ),
        sa.Column(
            "full_name",
            sa.String(length=100),
            nullable=False,
            comment="Full name of the user.",
        ),
        sa.Column(
            "email",
            sa.String(length=255),
            nullable=False,
            comment="Unique user email address.",
        ),
        sa.Column(
            "password_hash",
            sa.String(length=255),
            nullable=False,
            comment="Hashed password string (never plaintext).",
        ),
        sa.Column(
            "role",
            postgresql.ENUM(
                "USER",
                name="user_role",
                create_type=False,
            ),
            nullable=False,
            server_default="USER",
            comment="User role (defaults to USER).",
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
            comment="Boolean flag indicating active account state.",
        ),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Account creation timestamp (set by DB on insert).",
        ),
        sa.Column(
            "updated_at",
            sa.TIMESTAMP(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
            comment="Account update timestamp.",
        ),
    )

    # 3. Create unique index on email
    op.create_index(
        "ix_users_email",
        "users",
        ["email"],
        unique=True,
    )

    # 4. Add foreign key from measurements.user_id to users.id
    op.create_foreign_key(
        "fk_measurements_user_id_users",
        source_table="measurements",
        referent_table="users",
        local_cols=["user_id"],
        remote_cols=["id"],
    )


def downgrade() -> None:
    # 1. Drop foreign key constraint
    op.drop_constraint(
        "fk_measurements_user_id_users",
        table_name="measurements",
        type_="foreignkey",
    )

    # 2. Drop index on email
    op.drop_index("ix_users_email", table_name="users")

    # 3. Drop users table
    op.drop_table("users")

    # 4. Drop user_role ENUM type
    user_role_enum.drop(op.get_bind(), checkfirst=True)
