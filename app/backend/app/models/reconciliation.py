"""Reconciliation runs and the single exception register."""
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, String, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class ReconciliationRun(Base):
    __tablename__ = "reconciliation_run"
    run_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    run_kind: Mapped[str] = mapped_column(String, nullable=False)
    scope_key: Mapped[str] = mapped_column(String, nullable=False)
    input_fingerprint: Mapped[str] = mapped_column(String, nullable=False)
    parameters: Mapped[dict] = mapped_column(JSONB, nullable=False)
    rule_snapshot: Mapped[dict] = mapped_column(JSONB, nullable=False)
    engine_version: Mapped[str] = mapped_column(String, nullable=False)
    requested_by: Mapped[str] = mapped_column(ForeignKey("app_user.user_id"), nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(String, nullable=False, server_default="RUNNING")
    counts: Mapped[dict] = mapped_column(JSONB, nullable=False, server_default=text("'{}'::jsonb"))
    error_summary: Mapped[str | None] = mapped_column(String)


class ExceptionCase(Base):
    __tablename__ = "exception_case"
    exception_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    stable_key: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    exception_type: Mapped[str] = mapped_column(String, nullable=False)
    severity: Mapped[str] = mapped_column(String, nullable=False)
    owner_role: Mapped[str] = mapped_column(String, nullable=False)
    owner_user_id: Mapped[str | None] = mapped_column(String)
    owner_vendor_id: Mapped[str | None] = mapped_column(String)
    carton_id: Mapped[str | None] = mapped_column(String)
    subject_reference: Mapped[str] = mapped_column(String, nullable=False)
    visibility: Mapped[str] = mapped_column(String, nullable=False, server_default="FACILITIES")
    first_detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_detected_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    first_observed_as_of: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_observed_as_of: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, server_default="OPEN")
    resolution_reason: Mapped[str | None] = mapped_column(String)
    resolved_by: Mapped[str | None] = mapped_column(String)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
