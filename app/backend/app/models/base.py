"""Declarative base pinned to the prms schema."""
from sqlalchemy.orm import DeclarativeBase

from app.config import get_settings

_schema = get_settings().db_schema


class Base(DeclarativeBase):
    metadata_schema = _schema
    # Tables set schema explicitly via __table_args__ where needed; search_path
    # is also pinned per-connection in db.py.
