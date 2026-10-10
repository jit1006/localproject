"""Service-request actions: raise, acknowledge/collect/receive/deliver, approve, destroy."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import current_user, require_roles
from app.errors import not_found
from app.models import AppUser, Carton
from app.schemas import RequestCreateIn, RequestOut
from app.services import request_service, scope

router = APIRouter(prefix="/requests", tags=["requests"])


@router.post("", response_model=RequestOut, status_code=201)
def raise_request(
    body: RequestCreateIn,
    db: Session = Depends(get_db),
    user: AppUser = Depends(require_roles("BUSINESS")),
):
    carton = db.get(Carton, body.carton_id)
    if carton is None:
        raise not_found(f"Carton {body.carton_id} not found")
    scope.assert_can_raise_for_carton(user, carton)
    req = request_service.raise_request(
        db, user=user, carton=carton, request_id=body.request_id, request_type=body.request_type
    )
    return RequestOut.model_validate(req, from_attributes=True)


@router.get("/queue", response_model=list[RequestOut])
def vendor_queue(db: Session = Depends(get_db), user: AppUser = Depends(require_roles("VENDOR"))):
    rows = request_service.list_vendor_queue(db, user.vendor_id)
    return [RequestOut.model_validate(r, from_attributes=True) for r in rows]


@router.post("/{request_id}/acknowledge", response_model=RequestOut)
def acknowledge(request_id: str, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("VENDOR"))):
    req = request_service.vendor_action(
        db, user=user, request_id=request_id, event_type="REQUEST_ACKNOWLEDGED", mark_completed=False
    )
    return RequestOut.model_validate(req, from_attributes=True)


@router.post("/{request_id}/collect", response_model=RequestOut)
def collect(request_id: str, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("VENDOR"))):
    req = request_service.vendor_action(
        db, user=user, request_id=request_id, event_type="PICKED_UP_BY_VENDOR", mark_completed=False
    )
    return RequestOut.model_validate(req, from_attributes=True)


@router.post("/{request_id}/receive", response_model=RequestOut)
def receive(request_id: str, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("VENDOR"))):
    req = request_service.vendor_action(
        db, user=user, request_id=request_id, event_type="RECEIVED_AT_WAREHOUSE", mark_completed=True
    )
    return RequestOut.model_validate(req, from_attributes=True)


@router.post("/{request_id}/deliver", response_model=RequestOut)
def deliver(request_id: str, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("VENDOR"))):
    req = request_service.vendor_action(
        db, user=user, request_id=request_id, event_type="DELIVERED_TO_BUSINESS", mark_completed=True
    )
    return RequestOut.model_validate(req, from_attributes=True)


@router.post("/{request_id}/approve", response_model=RequestOut)
def approve(request_id: str, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("COMPLIANCE"))):
    req = request_service.approve_destruction(db, user=user, request_id=request_id)
    return RequestOut.model_validate(req, from_attributes=True)


@router.post("/{request_id}/destroy", response_model=RequestOut)
def destroy(request_id: str, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("VENDOR"))):
    req = request_service.execute_destruction(db, user=user, request_id=request_id)
    return RequestOut.model_validate(req, from_attributes=True)
