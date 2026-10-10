"""Legal-hold register (Compliance only for writes)."""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import current_user, require_roles
from app.models import AppUser
from app.schemas import HoldApplyIn, HoldReleaseIn
from app.services import hold_service

router = APIRouter(prefix="/holds", tags=["holds"])


@router.get("")
def list_holds(active_only: bool = False, db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    rows = hold_service.list_holds(db, active_only=active_only)
    return [
        {
            "hold_id": h.hold_id,
            "carton_id": h.carton_id,
            "matter_reference": h.matter_reference,
            "reason": h.reason,
            "starts_at": h.starts_at.isoformat() if h.starts_at else None,
            "released_at": h.released_at.isoformat() if h.released_at else None,
        }
        for h in rows
    ]


@router.post("", status_code=201)
def apply_hold(
    body: HoldApplyIn, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("COMPLIANCE"))
):
    hold = hold_service.apply_hold(
        db,
        user=user,
        carton_id=body.carton_id,
        hold_id=body.hold_id,
        matter_reference=body.matter_reference,
        reason=body.reason,
    )
    return {"hold_id": hold.hold_id}


@router.post("/{hold_id}/release")
def release_hold(
    hold_id: str,
    body: HoldReleaseIn,
    db: Session = Depends(get_db),
    user: AppUser = Depends(require_roles("COMPLIANCE")),
):
    hold = hold_service.release_hold(db, user=user, hold_id=hold_id, reason=body.reason)
    return {"hold_id": hold.hold_id, "released_at": hold.released_at.isoformat()}
