"""Legal holds. Only Compliance applies/releases. Holds block destruction but
permit otherwise-valid retrieval/return/movement.
"""
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.errors import conflict, forbidden, not_found
from app.models import CartonState, LegalHold
from app.services import event_engine


def apply_hold(
    db: Session, *, user, carton_id: str, hold_id: str, matter_reference: str, reason: str
) -> LegalHold:
    if user.role_code != "COMPLIANCE":
        raise forbidden("Only Compliance can apply legal holds")
    if db.get(LegalHold, hold_id) is not None:
        raise conflict(f"Hold {hold_id} already exists")

    now = datetime.now(timezone.utc)
    event = event_engine.append_carton_event(
        db,
        carton_id=carton_id,
        event_type="LEGAL_HOLD_APPLIED",
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=now,
        idempotency_key=f"hold-apply:{hold_id}",
        payload={"matter_reference": matter_reference, "reason": reason},
    )
    hold = LegalHold(
        hold_id=hold_id,
        carton_id=carton_id,
        matter_reference=matter_reference,
        reason=reason,
        raised_by=user.user_id,
        starts_at=now,
        applied_event_id=event.event_id,
    )
    db.add(hold)

    state = db.get(CartonState, carton_id)
    if state is not None:
        state.active_hold_count += 1
    db.commit()
    db.refresh(hold)
    return hold


def release_hold(db: Session, *, user, hold_id: str, reason: str) -> LegalHold:
    if user.role_code != "COMPLIANCE":
        raise forbidden("Only Compliance can release legal holds")
    hold = db.get(LegalHold, hold_id)
    if hold is None:
        raise not_found(f"Hold {hold_id} not found")
    if hold.released_at is not None:
        raise conflict("Hold already released")

    now = datetime.now(timezone.utc)
    event = event_engine.append_carton_event(
        db,
        carton_id=hold.carton_id,
        event_type="LEGAL_HOLD_RELEASED",
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=now,
        idempotency_key=f"hold-release:{hold_id}",
        payload={"reason": reason},
    )
    hold.released_at = now
    hold.release_precision = "TIMESTAMP"
    hold.released_by = user.user_id
    hold.release_reason = reason
    hold.released_event_id = event.event_id

    state = db.get(CartonState, hold.carton_id)
    if state is not None and state.active_hold_count > 0:
        state.active_hold_count -= 1
    db.commit()
    db.refresh(hold)
    return hold


def list_holds(db: Session, *, active_only: bool = False) -> list[LegalHold]:
    stmt = select(LegalHold).order_by(LegalHold.starts_at.desc())
    if active_only:
        stmt = stmt.where(LegalHold.released_at.is_(None))
    return list(db.scalars(stmt))
