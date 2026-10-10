"""Reconciliation runs and the exception register (Facilities-driven).

NOTE: This router exposes the run/exception framework and listing. The three
full reconciliation engines (inventory as-of custody, invoice arithmetic +
independent cost match, certificate vs hold/event) are specified in
docs/design.md and are the next implementation increment; the endpoints here
record runs and surface findings/exceptions so the UI and contract are stable.
"""
import hashlib
import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.deps import current_user, require_roles
from app.models import AppUser, ExceptionCase, ReconciliationRun

router = APIRouter(tags=["reconciliation"])
_settings = get_settings()


class RunIn(BaseModel):
    run_kind: str  # INVENTORY | INVOICE | CERTIFICATE | DATA_QUALITY
    scope_key: str
    parameters: dict = {}


@router.post("/reconciliations", status_code=201)
def start_run(
    body: RunIn, db: Session = Depends(get_db), user: AppUser = Depends(require_roles("FACILITIES"))
):
    rule_snapshot = {"engine_version": _settings.engine_version}
    fingerprint = hashlib.sha256(
        json.dumps(
            {"kind": body.run_kind, "scope": body.scope_key, "params": body.parameters, "rules": rule_snapshot},
            sort_keys=True,
        ).encode()
    ).hexdigest()

    # Idempotency: same kind + scope + fingerprint returns the existing run.
    existing = db.scalar(
        select(ReconciliationRun).where(
            ReconciliationRun.run_kind == body.run_kind,
            ReconciliationRun.scope_key == body.scope_key,
            ReconciliationRun.input_fingerprint == fingerprint,
        )
    )
    if existing is not None:
        return {"run_id": existing.run_id, "status": existing.status, "deduplicated": True}

    run = ReconciliationRun(
        run_kind=body.run_kind,
        scope_key=body.scope_key,
        input_fingerprint=fingerprint,
        parameters=body.parameters,
        rule_snapshot=rule_snapshot,
        engine_version=_settings.engine_version,
        requested_by=user.user_id,
        status="COMPLETED",
        finished_at=datetime.now(timezone.utc),
        counts={"note": "engine stub — findings produced by engine increment"},
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return {"run_id": run.run_id, "status": run.status, "deduplicated": False}


@router.get("/reconciliations")
def list_runs(db: Session = Depends(get_db), user: AppUser = Depends(require_roles("FACILITIES"))):
    rows = db.scalars(select(ReconciliationRun).order_by(ReconciliationRun.started_at.desc()))
    return [
        {
            "run_id": r.run_id,
            "run_kind": r.run_kind,
            "scope_key": r.scope_key,
            "status": r.status,
            "started_at": r.started_at.isoformat() if r.started_at else None,
        }
        for r in rows
    ]


@router.get("/exceptions")
def list_exceptions(db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    stmt = select(ExceptionCase).order_by(ExceptionCase.last_detected_at.desc())
    # Vendor users see only their own, vendor-redacted exceptions.
    if user.role_code == "VENDOR":
        stmt = stmt.where(ExceptionCase.owner_vendor_id == user.vendor_id)
    elif user.role_code == "BUSINESS":
        stmt = stmt.where(ExceptionCase.visibility == "BUSINESS_SCOPED")
    rows = db.scalars(stmt)
    return [
        {
            "exception_id": e.exception_id,
            "exception_type": e.exception_type,
            "severity": e.severity,
            "owner_role": e.owner_role,
            "status": e.status,
            "subject_reference": e.subject_reference,
        }
        for e in rows
    ]
