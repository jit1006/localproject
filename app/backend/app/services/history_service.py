"""Readable carton history derived from the canonical event log."""
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import CartonState, EventLog


def carton_history(db: Session, carton_id: str) -> list[dict]:
    rows = db.scalars(
        select(EventLog)
        .where(EventLog.carton_id == carton_id)
        .order_by(EventLog.occurred_at.asc(), EventLog.event_id.asc())
    )
    out = []
    for e in rows:
        out.append(
            {
                "eventId": e.event_id,
                "eventType": e.event_type,
                "occurredAt": e.occurred_at.isoformat() if e.occurred_at else None,
                "actorRole": e.actor_role,
                "actorUserId": e.actor_user_id,
                "resultingStatus": e.resulting_status,
                "requestId": e.request_id,
                "payload": e.payload,
            }
        )
    return out


def carton_state(db: Session, carton_id: str) -> dict | None:
    s = db.get(CartonState, carton_id)
    if s is None:
        return None
    return {
        "cartonId": s.carton_id,
        "status": s.status_code,
        "custody": s.custody,
        "vendorId": s.vendor_id,
        "warehouseId": s.warehouse_id,
        "activeHoldCount": s.active_hold_count,
        "stateSince": s.state_since.isoformat() if s.state_since else None,
        "version": s.version,
    }
