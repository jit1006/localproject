"""Records / workflow projections: carton, file_record, service_request."""
from datetime import date, datetime

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Carton(Base):
    __tablename__ = "carton"
    carton_id: Mapped[str] = mapped_column(String, primary_key=True)
    entity_id: Mapped[str] = mapped_column(String, nullable=False)
    department_id: Mapped[str] = mapped_column(String, nullable=False)
    owner_user_id: Mapped[str] = mapped_column(ForeignKey("app_user.user_id"), nullable=False)
    document_type: Mapped[str] = mapped_column(String, nullable=False)
    archival_policy: Mapped[str] = mapped_column(String, nullable=False)
    carton_created_date: Mapped[date] = mapped_column(Date, nullable=False)
    retention_trigger_date: Mapped[date | None] = mapped_column(Date)
    declared_file_count: Mapped[int | None] = mapped_column(Integer)
    assigned_vendor_id: Mapped[str] = mapped_column(String, nullable=False)
    barcode: Mapped[str | None] = mapped_column(String)
    remarks: Mapped[str | None] = mapped_column(String)
    source_row_id: Mapped[int | None] = mapped_column(BigInteger)


class FileRecord(Base):
    __tablename__ = "file_record"
    file_id: Mapped[str] = mapped_column(String, primary_key=True)
    carton_id: Mapped[str] = mapped_column(String, nullable=False)
    file_ref: Mapped[str] = mapped_column(String, nullable=False)
    document_type: Mapped[str] = mapped_column(String, nullable=False)
    file_description: Mapped[str | None] = mapped_column(String)
    document_year: Mapped[int | None] = mapped_column(Integer)
    contains_pii: Mapped[bool] = mapped_column(default=True)
    source_row_id: Mapped[int | None] = mapped_column(BigInteger)


class ServiceRequest(Base):
    __tablename__ = "service_request"
    request_id: Mapped[str] = mapped_column(String, primary_key=True)
    carton_id: Mapped[str] = mapped_column(ForeignKey("carton.carton_id"), nullable=False)
    request_type: Mapped[str] = mapped_column(String, nullable=False)
    vendor_id: Mapped[str] = mapped_column(ForeignKey("vendor.vendor_id"), nullable=False)
    raised_by: Mapped[str] = mapped_column(ForeignKey("app_user.user_id"), nullable=False)
    raised_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    request_status: Mapped[str] = mapped_column(String, nullable=False)
    destination: Mapped[dict | None] = mapped_column(JSONB)
    vendor_ack_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    approved_by: Mapped[str | None] = mapped_column(String)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    rejection_reason: Mapped[str | None] = mapped_column(String)
    sla_rule_id: Mapped[int | None] = mapped_column(BigInteger)
    sla_snapshot: Mapped[dict | None] = mapped_column(JSONB)
    sla_due_date: Mapped[date | None] = mapped_column(Date)
    source_row_id: Mapped[int | None] = mapped_column(BigInteger)
