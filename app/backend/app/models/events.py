"""Canonical event log and its rebuildable projections."""
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class EventLog(Base):
    __tablename__ = "event_log"
    event_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    stream_kind: Mapped[str] = mapped_column(String, nullable=False)
    stream_id: Mapped[str] = mapped_column(String, nullable=False)
    stream_version: Mapped[int] = mapped_column(BigInteger, nullable=False)
    carton_id: Mapped[str | None] = mapped_column(String)
    request_id: Mapped[str | None] = mapped_column(String)
    event_type: Mapped[str] = mapped_column(ForeignKey("event_type.event_type"), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))
    actor_user_id: Mapped[str | None] = mapped_column(String)
    actor_role: Mapped[str] = mapped_column(String, nullable=False)
    actor_reference: Mapped[str | None] = mapped_column(String)
    channel: Mapped[str] = mapped_column(String, nullable=False)
    source_event_id: Mapped[str | None] = mapped_column(String)
    source_row_id: Mapped[int | None] = mapped_column(BigInteger)
    from_location_ref: Mapped[str | None] = mapped_column(String)
    to_location_ref: Mapped[str | None] = mapped_column(String)
    resulting_status: Mapped[str | None] = mapped_column(String)
    schema_version: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("1"))
    payload: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    corrects_event_id: Mapped[int | None] = mapped_column(BigInteger)
    idempotency_key: Mapped[str] = mapped_column(String, nullable=False, unique=True)


class CartonState(Base):
    __tablename__ = "carton_state"
    carton_id: Mapped[str] = mapped_column(ForeignKey("carton.carton_id"), primary_key=True)
    status_code: Mapped[str] = mapped_column(String, nullable=False)
    custody: Mapped[str] = mapped_column(String, nullable=False)
    vendor_id: Mapped[str | None] = mapped_column(String)
    warehouse_id: Mapped[str | None] = mapped_column(String)
    active_hold_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    state_since: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_event_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    version: Mapped[int] = mapped_column(BigInteger, nullable=False)
    rebuilt_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))


class CustodyInterval(Base):
    __tablename__ = "custody_interval"
    interval_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    carton_id: Mapped[str] = mapped_column(String, nullable=False)
    custody: Mapped[str] = mapped_column(String, nullable=False)
    vendor_id: Mapped[str | None] = mapped_column(String)
    warehouse_id: Mapped[str | None] = mapped_column(String)
    valid_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    valid_to: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    start_event_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    end_event_id: Mapped[int | None] = mapped_column(BigInteger)


class LegalHold(Base):
    __tablename__ = "legal_hold"
    hold_id: Mapped[str] = mapped_column(String, primary_key=True)
    carton_id: Mapped[str] = mapped_column(String, nullable=False)
    matter_reference: Mapped[str] = mapped_column(String, nullable=False)
    reason: Mapped[str] = mapped_column(String, nullable=False)
    raised_by: Mapped[str | None] = mapped_column(String)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    start_precision: Mapped[str] = mapped_column(String, nullable=False, server_default="TIMESTAMP")
    applied_event_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    released_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    release_precision: Mapped[str | None] = mapped_column(String)
    released_by: Mapped[str | None] = mapped_column(String)
    release_reason: Mapped[str | None] = mapped_column(String)
    released_event_id: Mapped[int | None] = mapped_column(BigInteger)
    source_row_id: Mapped[int | None] = mapped_column(BigInteger)
