"""Role-scoped dashboard aggregates and reference-data reads."""
from fastapi import APIRouter, Depends
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import current_user
from app.models import Carton, CartonState, ServiceRequest, Vendor
from app.models import AppUser

router = APIRouter(tags=["dashboard"])


@router.get("/dashboard")
def dashboard(db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    """Counts scoped to the caller's role/row scope."""
    carton_q = select(func.count()).select_from(Carton)
    request_q = select(func.count()).select_from(ServiceRequest)

    if user.role_code == "BUSINESS":
        carton_q = carton_q.where(
            Carton.entity_id == user.entity_id, Carton.department_id == user.department_id
        )
        request_q = request_q.where(ServiceRequest.raised_by == user.user_id)
    elif user.role_code == "VENDOR":
        carton_q = carton_q.where(Carton.assigned_vendor_id == user.vendor_id)
        request_q = request_q.where(ServiceRequest.vendor_id == user.vendor_id)

    by_status = db.execute(
        text(
            """
            SELECT cs.status_code, count(*) AS n
            FROM prms.carton_state cs
            JOIN prms.carton c ON c.carton_id = cs.carton_id
            WHERE (:role <> 'BUSINESS' OR (c.entity_id = :eid AND c.department_id = :did))
              AND (:role <> 'VENDOR' OR c.assigned_vendor_id = :vid)
            GROUP BY cs.status_code
            ORDER BY n DESC
            """
        ),
        {
            "role": user.role_code,
            "eid": user.entity_id,
            "did": user.department_id,
            "vid": user.vendor_id,
        },
    ).mappings().all()

    return {
        "role": user.role_code,
        "totalCartons": db.scalar(carton_q),
        "totalRequests": db.scalar(request_q),
        "cartonsByStatus": [dict(r) for r in by_status],
    }


@router.get("/reference-data/vendors")
def vendors(db: Session = Depends(get_db), user: AppUser = Depends(current_user)):
    rows = db.scalars(select(Vendor).order_by(Vendor.vendor_id))
    return [{"vendor_id": v.vendor_id, "vendor_name": v.vendor_name, "status": v.status} for v in rows]
