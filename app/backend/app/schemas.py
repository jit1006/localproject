"""Pydantic request/response models for the HTTP API."""
from datetime import date
from pydantic import BaseModel, EmailStr, Field


# ---- auth ----
class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class UserOut(BaseModel):
    user_id: str
    full_name: str
    email: str
    role_code: str
    entity_id: str | None = None
    department_id: str | None = None
    vendor_id: str | None = None


# ---- cartons ----
class CartonCreateIn(BaseModel):
    carton_id: str
    document_type: str
    archival_policy: str
    carton_created_date: date
    assigned_vendor_id: str
    retention_trigger_date: date | None = None
    declared_file_count: int | None = Field(default=None, ge=0)
    barcode: str | None = None
    remarks: str | None = None


class CartonOut(BaseModel):
    carton_id: str
    entity_id: str
    department_id: str
    document_type: str
    archival_policy: str
    assigned_vendor_id: str
    retention_trigger_date: date | None = None
    declared_file_count: int | None = None
    barcode: str | None = None


class FileCreateIn(BaseModel):
    file_id: str
    file_ref: str
    document_type: str
    file_description: str | None = None
    document_year: int | None = Field(default=None, ge=1000, le=9999)
    contains_pii: bool = True


# ---- requests ----
class RequestCreateIn(BaseModel):
    request_id: str
    carton_id: str
    request_type: str  # PICKUP | RETRIEVAL | RETURN | DESTRUCTION


class RequestOut(BaseModel):
    request_id: str
    carton_id: str
    request_type: str
    vendor_id: str
    request_status: str
    approved_by: str | None = None


# ---- holds ----
class HoldApplyIn(BaseModel):
    hold_id: str
    carton_id: str
    matter_reference: str
    reason: str


class HoldReleaseIn(BaseModel):
    reason: str
