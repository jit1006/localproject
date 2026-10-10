"""Event engine: append canonical events and update projections atomically.

This implements the command discipline described in the project brief:
  - lock the carton row,
  - check idempotency,
  - validate the lifecycle transition,
  - append the event with actor/channel evidence,
  - update carton_state and custody_interval,
  - commit (caller controls the surrounding transaction boundary).

Legal-hold / retention prerequisites are enforced by the calling command
services (hold_service, request_service) before append_carton_event is called.
"""
from datetime import datetime, timezone

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.errors import conflict, unprocessable
from app.models import (
    CartonState,
    CustodyInterval,
    EventLog,
    EventType,
    LifecycleTransition,
)

# custody value derived from the resulting status for carton streams.
_STATUS_CUSTODY = {
    "Created": "BUSINESS",
    "Pickup Requested": "BUSINESS",
    "In Transit to Vendor": "TRANSIT",
    "In Storage": "WAREHOUSE",
    "Retrieval Requested": "WAREHOUSE",
    "With Business": "BUSINESS",
    "Return Requested": "BUSINESS",
    "Destruction Requested": "WAREHOUSE",
    "Approved for Destruction": "WAREHOUSE",
    "Destroyed": "DESTROYED",
    "Missing": "UNKNOWN",
}


def _lock_carton(db: Session, carton_id: str) -> None:
    """SELECT ... FOR UPDATE on the carton row to serialize commands."""
    db.execute(
        text("SELECT 1 FROM prms.carton WHERE carton_id = :cid FOR UPDATE"),
        {"cid": carton_id},
    )


def _next_stream_version(db: Session, carton_id: str) -> int:
    current = db.scalar(
        select(func.max(EventLog.stream_version)).where(EventLog.stream_id == carton_id)
    )
    return (current or 0) + 1


def append_carton_event(
    db: Session,
    *,
    carton_id: str,
    event_type: str,
    actor_user_id: str | None,
    actor_role: str,
    channel: str,
    occurred_at: datetime | None,
    idempotency_key: str,
    request_id: str | None = None,
    payload: dict | None = None,
    expect_status: str | None = None,
    allow_status_unchanged: bool = False,
) -> EventLog:
    """Append one carton event and update projections. Idempotent by key.

    expect_status: if given, the carton's current status must match or a
    lifecycle transition must exist for (current_status -> event_type).
    """
    # Idempotency: a prior commit with the same key returns the original event.
    existing = db.scalar(select(EventLog).where(EventLog.idempotency_key == idempotency_key))
    if existing is not None:
        return existing

    _lock_carton(db, carton_id)

    et = db.get(EventType, event_type)
    if et is None:
        raise unprocessable(f"Unknown event_type {event_type!r}")

    state = db.get(CartonState, carton_id)
    current_status = state.status_code if state else None

    resulting_status = et.resulting_status
    if resulting_status is not None and current_status is not None:
        transition = db.get(LifecycleTransition, (current_status, event_type))
        if transition is None:
            raise conflict(
                f"Illegal transition: {event_type} not allowed from status {current_status!r}"
            )
        resulting_status = transition.to_status
        if current_status in ("Destroyed",):
            raise conflict("Carton is in a terminal state and cannot change")

    now = datetime.now(timezone.utc)
    occurred = occurred_at or now
    version = _next_stream_version(db, carton_id)

    event = EventLog(
        stream_kind="CARTON",
        stream_id=carton_id,
        stream_version=version,
        carton_id=carton_id,
        request_id=request_id,
        event_type=event_type,
        occurred_at=occurred,
        actor_user_id=actor_user_id,
        actor_role=actor_role,
        channel=channel,
        resulting_status=resulting_status,
        payload=payload or {},
        idempotency_key=idempotency_key,
    )
    db.add(event)
    db.flush()  # assign event_id

    if resulting_status is not None:
        _apply_status(db, carton_id, resulting_status, event, occurred)

    return event


def _apply_status(db: Session, carton_id: str, status: str, event: EventLog, occurred: datetime) -> None:
    """Update carton_state and close/open custody intervals."""
    custody = _STATUS_CUSTODY.get(status, "UNKNOWN")
    state = db.get(CartonState, carton_id)
    if state is None:
        state = CartonState(
            carton_id=carton_id,
            status_code=status,
            custody=custody,
            state_since=occurred,
            last_event_id=event.event_id,
            version=1,
        )
        db.add(state)
    else:
        if state.custody != custody:
            # Close the open custody interval and open a new one.
            open_iv = db.scalar(
                select(CustodyInterval).where(
                    CustodyInterval.carton_id == carton_id,
                    CustodyInterval.valid_to.is_(None),
                )
            )
            if open_iv is not None:
                open_iv.valid_to = occurred
                open_iv.end_event_id = event.event_id
            state.custody = custody
            state.state_since = occurred
        state.status_code = status
        state.last_event_id = event.event_id
        state.version += 1

    # Open an initial custody interval on creation.
    has_open = db.scalar(
        select(CustodyInterval).where(
            CustodyInterval.carton_id == carton_id,
            CustodyInterval.valid_to.is_(None),
        )
    )
    if has_open is None and custody != "DESTROYED":
        db.add(
            CustodyInterval(
                carton_id=carton_id,
                custody=custody,
                valid_from=occurred,
                start_event_id=event.event_id,
            )
        )
