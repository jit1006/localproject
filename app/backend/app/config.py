"""Application configuration, loaded from environment / .env.

Never hardcode credentials. The runtime database login must be a
non-owner, non-superuser role (see PRMS_Database_Complete/sql/03_runtime_grants.sql).
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_prefix="PRMS_", extra="ignore"
    )

    # PostgreSQL DSN for the runtime (non-owner) login.
    # Example: postgresql+psycopg://prms_app:***@localhost:5432/prms
    database_url: str = "postgresql+psycopg://prms_app:change-me@localhost:5432/prms"

    # Search path schema created by sql/01_schema.sql.
    db_schema: str = "prms"

    # Session signing secret. MUST be overridden in every real environment.
    session_secret: str = "dev-only-insecure-secret-change-me"
    session_ttl_minutes: int = 480  # 8 hours
    session_cookie_name: str = "prms_session"
    secure_cookies: bool = False  # set true behind HTTPS in production

    # CORS origin for the Vite dev server.
    frontend_origin: str = "http://localhost:5173"

    engine_version: str = "prms-recon-0.1.0"
    environment: str = "development"


@lru_cache
def get_settings() -> Settings:
    return Settings()
