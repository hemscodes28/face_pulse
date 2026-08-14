"""
face_pulse/backend/app/core/config.py
======================================
Application configuration loaded from environment variables.

Uses pydantic-settings so values can be supplied via:
  - A .env file in the backend/ working directory
  - Actual environment variables (CI, Docker, production)

Never hardcode credentials here.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Central settings for the Face Pulse backend.

    DATABASE_URL      — Async PostgreSQL URL (asyncpg) used by the app.
    DATABASE_URL_SYNC — Sync PostgreSQL URL (psycopg2) used only by Alembic.
    TEST_DATABASE_URL — Optional override for test runs.
    """

    # -------------------------------------------------------------------
    # Database
    # -------------------------------------------------------------------
    DATABASE_URL: str = (
        "postgresql+asyncpg://face_pulse_user:change_me@localhost:5432/face_pulse"
    )
    DATABASE_URL_SYNC: str = (
        "postgresql+psycopg2://face_pulse_user:change_me@localhost:5432/face_pulse"
    )
    TEST_DATABASE_URL: str = "sqlite+aiosqlite:///./test.db"

    # -------------------------------------------------------------------
    # Pydantic-settings config
    # -------------------------------------------------------------------
    model_config = SettingsConfigDict(
        env_file=".env",          # load from .env when present
        env_file_encoding="utf-8",
        case_sensitive=True,      # env vars are case-sensitive on Linux
        extra="ignore",           # ignore unrecognised env vars
    )


# ---------------------------------------------------------------------------
# Module-level singleton — import this everywhere:
#   from app.core.config import settings
# ---------------------------------------------------------------------------
settings = Settings()
