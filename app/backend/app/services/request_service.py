"""Service-request lifecycle: pickup, retrieval, return, destruction.

Each state-changing action appends the appropriate carton event atomically and
updates the request projection. Destruction requires independent Compliance
approval and re-checks eligibility (hold + retention + custody) at execution.
"""
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.errors import conflict, forbidden, not_found, unprocessable
from app.models import Carton, CartonState, LegalHold, ServiceRequest
from app.services import event_engine, scope

_REQUEST_EVENT = {
    "PICKUP": "PICKUP_REQUESTED",
    "RETRIEVAL": "RETRIEVAL_REQUESTED",
    "RETURN": "RETURN_REQUESTED",
    "DESTRUCTION": "DESTRUCTION_REQUESTED",
}


def _active_hold(db: Session, carton_id: str) -> LegalHold | None:
    return db.scalar(
        select(LegalHold).where(
            LegalHold.carton_id == carton_id, LegalHold.released_at.is_(None)
        )
    )


def raise_request(db: Session, *, user, carton: Carton, request_id: str, request_type: str) -> ServiceRequest:
    scope.assert_can_raise_for_carton(user, carton)
    if request_type not in _REQUEST_EVENT:
        raise unprocessable(f"Unknown request_type {request_type!r}")

    if request_type == "DESTRUCTION" and _active_hold(db, carton.carton_id) is not None:
        raise conflict("Carton is under an active legal hold; destruction is blocked")

    now = datetime.now(timezone.utc)
    req = ServiceRequest(
        request_id=request_id,
        carton_id=carton.carton_id,
        request_type=request_type,
        vendor_id=carton.assigned_vendor_id,
        raised_by=user.user_id,
        raised_at=now,
        request_status="Open",
    )
    db.add(req)
    db.flush()

    event_engine.append_carton_event(
        db,
        carton_id=carton.carton_id,
        event_type=_REQUEST_EVENT[request_type],
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=now,
        idempotency_key=f"request:{request_id}",
        request_id=request_id,
        payload={"request_type": request_type},
    )
    db.commit()
    db.refresh(req)
    return req


def _load_request(db: Session, request_id: str) -> ServiceRequest:
    req = db.get(ServiceRequest, request_id)
    if req is None:
        raise not_found(f"Request {request_id} not found")
    return req


def vendor_action(
    db: Session, *, user, request_id: str, event_type: str, mark_completed: bool
) -> ServiceRequest:
    """Vendor confirms collection / warehouse receipt / delivery."""
    req = _load_request(db, request_id)
    scope.assert_can_act_on_request(user, req)
    now = datetime.now(timezone.utc)

    event_engine.append_carton_event(
        db,
        carton_id=req.carton_id,
        event_type=event_type,
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=now,
        idempotency_key=f"{event_type}:{request_id}",
        request_id=request_id,
    )
    if req.vendor_ack_at is None:
        req.vendor_ack_at = now
    if mark_completed:
        req.request_status = "Completed"
        req.completed_at = now
    else:
        req.request_status = "In Progress"
    db.commit()
    db.refresh(req)
    return req


def approve_destruction(db: Session, *, user, request_id: str) -> ServiceRequest:
    """Compliance approves. Approver must differ from requester (SoD)."""
    if user.role_code != "COMPLIANCE":
        raise forbidden("Only Compliance can approve destruction")
    req = _load_request(db, request_id)
    if req.request_type != "DESTRUCTION":
        raise unprocessable("Only destruction requests can be approved")
    if req.approved_by is not None:
        raise conflict("Request already approved")
    if req.raised_by == user.user_id:
        raise forbidden("Approver must differ from the requester (separation of duties)")
    if _active_hold(db, req.carton_id) is not None:
        raise conflict("Carton is under an active legal hold; cannot approve destruction")

    now = datetime.now(timezone.utc)
    event_engine.append_carton_event(
        db,
        carton_id=req.carton_id,
        event_type="DESTRUCTION_APPROVED",
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=now,
        idempotency_key=f"approve:{request_id}",
        request_id=request_id,
    )
    req.approved_by = user.user_id
    req.approved_at = now
    req.request_status = "In Progress"
    db.commit()
    db.refresh(req)
    return req


def execute_destruction(db: Session, *, user, request_id: str) -> ServiceRequest:
    """Vendor executes approved destruction. Re-checks hold at execution time."""
    req = _load_request(db, request_id)
    scope.assert_can_act_on_request(user, req)
    if req.approved_by is None:
        raise conflict("Destruction has not been approved")
    # Re-check: a hold applied AFTER approval must still block execution.
    if _active_hold(db, req.carton_id) is not None:
        raise conflict("Carton is under an active legal hold; destruction blocked at execution")

    state = db.get(CartonState, req.carton_id)
    if state is not None and state.custody != "WAREHOUSE":
        raise conflict("Carton must be in warehouse custody to be destroyed")

    now = datetime.now(timezone.utc)
    event_engine.append_carton_event(
        db,
        carton_id=req.carton_id,
        event_type="DESTROYED",
        actor_user_id=user.user_id,
        actor_role=user.role_code,
        channel="API",
        occurred_at=now,
        idempotency_key=f"destroy:{request_id}",
        request_id=request_id,
    )
    req.request_status = "Completed"
    req.completed_at = now
    db.commit()
    db.refresh(req)
    return req


def list_vendor_queue(db: Session, vendor_id: str) -> list[ServiceRequest]:
    return list(
        db.scalars(
            select(ServiceRequest)
            .where(ServiceRequest.vendor_id == vendor_id)
            .order_by(ServiceRequest.raised_at.desc())
        )
    )
