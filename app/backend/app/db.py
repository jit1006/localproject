"""Database engine and session management (SQLAlchemy 2.0)."""
from collections.abc import Iterator

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.config import get_settings

_settings = get_settings()

engine = create_engine(
    _settings.database_url,
    pool_pre_ping=True,
    future=True,
)


@event.listens_for(engine, "connect")
def _set_search_path(dbapi_connection, _record):
    """Pin search_path to the prms schema for every pooled connection."""
    cur = dbapi_connection.cursor()
    try:
        cur.execute(f"SET search_path TO {_settings.db_schema}, public")
    finally:
        cur.close()


SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False, future=True)


def get_db() -> Iterator[Session]:
    """FastAPI dependency that yields a request-scoped session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
