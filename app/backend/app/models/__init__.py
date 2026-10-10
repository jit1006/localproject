"""SQLAlchemy ORM models mapping the authoritative prms schema.

The schema is defined and owned by PRMS_Database_Complete/sql/01_schema.sql.
These models mirror a working subset of those tables; they do NOT create or
alter the schema (the migration owner does that). Keep column names and types
in sync with the SQL — the SQL is the source of truth.
"""
from app.models.base import Base
from app.models.identity import AppUser, BusinessEntity, Department, UserSession, Vendor, Warehouse
from app.models.reference import (
    ArchivalPolicy,
    CartonStatus,
    DocumentType,
    EventType,
    Holiday,
    LifecycleTransition,
    RetentionPolicy,
    SlaRule,
    VendorRate,
)
from app.models.records import Carton, FileRecord, ServiceRequest
from app.models.events import CartonState, CustodyInterval, EventLog, LegalHold
from app.models.reconciliation import ExceptionCase, ReconciliationRun

__all__ = [
    "Base",
    "AppUser",
    "BusinessEntity",
    "Department",
    "UserSession",
    "Vendor",
    "Warehouse",
    "ArchivalPolicy",
    "CartonStatus",
    "DocumentType",
    "EventType",
    "Holiday",
    "LifecycleTransition",
    "RetentionPolicy",
    "SlaRule",
    "VendorRate",
    "Carton",
    "FileRecord",
    "ServiceRequest",
    "CartonState",
    "CustodyInterval",
    "EventLog",
    "LegalHold",
    "ExceptionCase",
    "ReconciliationRun",
]
