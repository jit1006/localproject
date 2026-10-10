"""Carton registration, file indexing, history and retention."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import current_user, require_roles
from app.errors import not_found
from app.models import AppUser, Carton
from app.schemas import CartonCreateIn, CartonOut, FileCreateIn
from app.services import carton_service, history_service, retention_service, scope

router = APIRouter(prefix="/cartons", tags=["cartons"])


def _get_carton(db: Session, carton_id: str, user: AppUser) -> Carton:
    carton = db.get(Carton, carton_id)
    if carton is None:
        raise not_found(f"Carton {carton_id} not found")
    scope.assert_can_view_carton(user, carton)
    return carton


@router.post("", response_model=CartonOut, status_code=201)
def create_carton(
    body: CartonCreateIn,
    db: Session = Depends(get_db),
    user: AppUser = Depends(require_roles("BUSINESS")),
):
    carton = carton_service.register_carton(
        db,
        user=user,
        carton_id=body.carton_id,
        document_type=body.document_type,
        archival_policy=body.archival_policy,
        carton_created_date=body.carton_created_date,
        assigned_vendor_id=body.assigned_vendor_id,
        retention_trigger_date=body.retention_trigger_date,
        declared_file_count=body.declared_file_count,
        barcode=body.barcode,
        remarks=body.remarks,
    )
    return CartonOut.model_validate(carton, from_attributes=True)


@router.get("/{carton_id}", response_model=CartonOut)
def get_carton(carton_id: str, db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    carton = _get_carton(db, carton_id, user)
    return CartonOut.model_validate(carton, from_attributes=True)


@router.post("/{carton_id}/files", status_code=201)
def add_file(
    carton_id: str,
    body: FileCreateIn,
    db: Session = Depends(get_db),
    user: AppUser = Depends(require_roles("BUSINESS")),
):
    carton = _get_carton(db, carton_id, user)
    scope.assert_can_raise_for_carton(user, carton)
    rec = carton_service.index_file(
        db,
        user=user,
        carton=carton,
        file_id=body.file_id,
        file_ref=body.file_ref,
        document_type=body.document_type,
        file_description=body.file_description,
        document_year=body.document_year,
        contains_pii=body.contains_pii,
    )
    return {"file_id": rec.file_id}


@router.get("/{carton_id}/files")
def list_files(carton_id: str, db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    carton = _get_carton(db, carton_id, user)
    # Vendor users never see carton contents.
    if user.role_code == "VENDOR":
        from app.errors import forbidden

        raise forbidden("Vendor users cannot view carton contents")
    files = carton_service.list_files(db, carton.carton_id)
    return [
        {
            "file_id": f.file_id,
            "file_ref": f.file_ref,
            "document_type": f.document_type,
            "file_description": f.file_description,
            "document_year": f.document_year,
        }
        for f in files
    ]


@router.get("/{carton_id}/history")
def history(carton_id: str, db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    _get_carton(db, carton_id, user)
    return {
        "state": history_service.carton_state(db, carton_id),
        "events": history_service.carton_history(db, carton_id),
    }


@router.get("/{carton_id}/retention")
def retention(carton_id: str, db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    _get_carton(db, carton_id, user)
    result = retention_service.carton_retention(db, carton_id)
    if result is None:
        raise not_found("No retention row for carton")
    return result
