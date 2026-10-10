"""Carton registration and file indexing."""
from datetime import date, datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.errors import conflict, forbidden
from app.models import Carton, FileRecord
from app.services import event_engine


def register_carton(
    db: Session,
    *,
    user,
    carton_id: str,
    document_type: str,
    archival_policy: str,
    carton_created_date: date,
    assigned_vendor_id: str,
    retention_trigger_date: date | None = None,
    declared_file_count: int | None = None,
    barcode: str | None = None,
    remarks: str | None = None,
) -> Carton:
    if user.role_code != "BUSINESS":
        raise forbidden("Only Business users register cartons")

    if db.get(Carton, carton_id) is not None:
        raise conflict(f"Carton {carton_id} already exists")

    carton = Carton(
        carton_id=carton_id,
        entity_id=user.entity_id,
        department_id=user.department_id,
        owner_user_id=user.user_id,
        document_type=document_type,
        archival_policy=archival_policy,
        carton_created_date=carton_created_date,
        retention_trigger_date=retention_trigger_date,
        declared_file_count=declared_file_count,
        assigned_vendor_id=assigned_vendor_id,
        barcode=barcode,
        remarks=remarks,
    )
    db.add(carton)
    db.flush()

    event_engine.append_carton_event(
        db,
        carton_id=carton_id,
        event_type="CARTON_CREATED",
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=datetime.now(timezone.utc),
        idempotency_key=f"create:{carton_id}",
        payload={"document_type": document_type, "archival_policy": archival_policy},
    )
    db.commit()
    db.refresh(carton)
    return carton


def index_file(
    db: Session,
    *,
    user,
    carton: Carton,
    file_id: str,
    file_ref: str,
    document_type: str,
    file_description: str | None = None,
    document_year: int | None = None,
    contains_pii: bool = True,
) -> FileRecord:
    if db.get(FileRecord, file_id) is not None:
        raise conflict(f"File {file_id} already exists")
    rec = FileRecord(
        file_id=file_id,
        carton_id=carton.carton_id,
        file_ref=file_ref,
        document_type=document_type,
        file_description=file_description,
        document_year=document_year,
        contains_pii=contains_pii,
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


def list_files(db: Session, carton_id: str) -> list[FileRecord]:
    return list(db.scalars(select(FileRecord).where(FileRecord.carton_id == carton_id)))
