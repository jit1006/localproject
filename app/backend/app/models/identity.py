"""Organization / identity tables."""
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class BusinessEntity(Base):
    __tablename__ = "business_entity"
    entity_id: Mapped[str] = mapped_column(String, primary_key=True)
    entity_name: Mapped[str] = mapped_column(String, nullable=False, unique=True)


class Department(Base):
    __tablename__ = "department"
    department_id: Mapped[str] = mapped_column(String, primary_key=True)
    entity_id: Mapped[str] = mapped_column(ForeignKey("business_entity.entity_id"), nullable=False)
    department_name: Mapped[str] = mapped_column(String, nullable=False)


class Vendor(Base):
    __tablename__ = "vendor"
    vendor_id: Mapped[str] = mapped_column(String, primary_key=True)
    vendor_name: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False)
    contract_ref: Mapped[str | None] = mapped_column(String)
    ops_contact_email: Mapped[str | None] = mapped_column(String)
    recertification_frequency: Mapped[str] = mapped_column(String, nullable=False, server_default="Quarterly")


class Warehouse(Base):
    __tablename__ = "warehouse"
    location_id: Mapped[str] = mapped_column(String, primary_key=True)
    vendor_id: Mapped[str] = mapped_column(ForeignKey("vendor.vendor_id"), nullable=False)
    location_name: Mapped[str] = mapped_column(String, nullable=False)
    city: Mapped[str] = mapped_column(String, nullable=False)
    capacity_cartons: Mapped[int | None] = mapped_column(Integer)


class AppUser(Base):
    __tablename__ = "app_user"
    user_id: Mapped[str] = mapped_column(String, primary_key=True)
    full_name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[str] = mapped_column(String, nullable=False)
    role_code: Mapped[str] = mapped_column(String, nullable=False)
    entity_id: Mapped[str | None] = mapped_column(String)
    department_id: Mapped[str | None] = mapped_column(String)
    vendor_id: Mapped[str | None] = mapped_column(String)
    password_hash: Mapped[str | None] = mapped_column(String)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))


class UserSession(Base):
    __tablename__ = "user_session"
    token_hash: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("app_user.user_id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
