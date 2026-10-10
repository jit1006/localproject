"""Retention reads from the carton_retention VIEW (never a stored due date)."""
from sqlalchemy import text
from sqlalchemy.orm import Session


def carton_retention(db: Session, carton_id: str) -> dict | None:
    row = db.execute(
        text(
            """
            SELECT carton_id, retention_trigger_date, policy_id, policy_revision,
                   retention_years, destruction_due_on, calculation_status
            FROM prms.carton_retention WHERE carton_id = :cid
            """
        ),
        {"cid": carton_id},
    ).mappings().first()
    return dict(row) if row else None


def retention_overview(db: Session, limit: int = 200) -> list[dict]:
    rows = db.execute(
        text(
            """
            SELECT carton_id, retention_trigger_date, destruction_due_on, calculation_status
            FROM prms.carton_retention
            ORDER BY destruction_due_on NULLS LAST
            LIMIT :lim
            """
        ),
        {"lim": limit},
    ).mappings().all()
    return [dict(r) for r in rows]
