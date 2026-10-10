"""Reference / configuration tables (seeded, edited via audited service commands)."""
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class DocumentType(Base):
    __tablename__ = "document_type"
    document_type: Mapped[str] = mapped_column(String, primary_key=True)
    base_retention_years: Mapped[int] = mapped_column(Integer, nullable=False)
    trigger_event_description: Mapped[str] = mapped_column(String, nullable=False)


class ArchivalPolicy(Base):
    __tablename__ = "archival_policy"
    archival_policy: Mapped[str] = mapped_column(String, primary_key=True)


class RetentionPolicy(Base):
    __tablename__ = "retention_policy"
    policy_id: Mapped[str] = mapped_column(String, primary_key=True)
    entity_id: Mapped[str | None] = mapped_column(String)
    document_type: Mapped[str] = mapped_column(ForeignKey("document_type.document_type"), nullable=False)
    archival_policy: Mapped[str] = mapped_column(ForeignKey("archival_policy.archival_policy"), nullable=False)
    retention_years: Mapped[int] = mapped_column(Integer, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("1"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))


class VendorRate(Base):
    __tablename__ = "vendor_rate"
    rate_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    vendor_id: Mapped[str] = mapped_column(ForeignKey("vendor.vendor_id"), nullable=False)
    activity: Mapped[str] = mapped_column(String, nullable=False)
    rate_inr: Mapped[Decimal] = mapped_column(Numeric(14, 2), nullable=False)
    unit: Mapped[str] = mapped_column(String, nullable=False)
    effective_from: Mapped[date] = mapped_column(Date, nullable=False)
    effective_to: Mapped[date | None] = mapped_column(Date)  # EXCLUSIVE upper bound


class SlaRule(Base):
    __tablename__ = "sla_rule"
    sla_rule_id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    vendor_id: Mapped[str | None] = mapped_column(String)
    activity: Mapped[str] = mapped_column(String, nullable=False)
    business_days: Mapped[int] = mapped_column(Integer, nullable=False)
    starts_on: Mapped[str] = mapped_column(String, nullable=False)
    ends_on: Mapped[str] = mapped_column(String, nullable=False)
    definition: Mapped[str] = mapped_column(String, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("1"))


class Holiday(Base):
    __tablename__ = "holiday"
    holiday_date: Mapped[date] = mapped_column(Date, primary_key=True)
    holiday_name: Mapped[str] = mapped_column(String, nullable=False)


class CartonStatus(Base):
    __tablename__ = "carton_status"
    status_code: Mapped[str] = mapped_column(String, primary_key=True)
    meaning: Mapped[str] = mapped_column(String, nullable=False)
    is_terminal: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))


class EventType(Base):
    __tablename__ = "event_type"
    event_type: Mapped[str] = mapped_column(String, primary_key=True)
    meaning: Mapped[str] = mapped_column(String, nullable=False)
    changes_custody: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    expected_role: Mapped[str | None] = mapped_column(String)
    resulting_status: Mapped[str | None] = mapped_column(String)
    request_requirement: Mapped[str] = mapped_column(String, nullable=False, server_default="NONE")


class LifecycleTransition(Base):
    __tablename__ = "lifecycle_transition"
    from_status: Mapped[str] = mapped_column(ForeignKey("carton_status.status_code"), primary_key=True)
    event_type: Mapped[str] = mapped_column(ForeignKey("event_type.event_type"), primary_key=True)
    to_status: Mapped[str] = mapped_column(ForeignKey("carton_status.status_code"), nullable=False)
