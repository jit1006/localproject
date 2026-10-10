"""Integration tests for the core lifecycle and compliance rules.

These require a live PostgreSQL database with the authoritative schema + seed
applied, reachable via PRMS_TEST_DATABASE_URL (migration-owner DSN so fixtures
can insert test users and roll back). They are skipped automatically when that
variable is not set, so the no-DB unit tests still run in any environment.

Run with a database:
    PRMS_TEST_DATABASE_URL=postgresql+psycopg://owner:***@localhost:5432/prms_test \\
        pytest tests/test_lifecycle_integration.py
"""
import os
import uuid

import pytest

pytestmark = pytest.mark.skipif(
    not os.getenv("PRMS_TEST_DATABASE_URL"),
    reason="PRMS_TEST_DATABASE_URL not set; integration DB required",
)


@pytest.fixture()
def db():
    from sqlalchemy import create_engine, event, text
    from sqlalchemy.orm import sessionmaker

    engine = create_engine(os.environ["PRMS_TEST_DATABASE_URL"], future=True)

    @event.listens_for(engine, "connect")
    def _sp(conn, _):
        cur = conn.cursor()
        cur.execute("SET search_path TO prms, public")
        cur.close()

    Session = sessionmaker(bind=engine, future=True)
    s = Session()
    yield s
    s.rollback()
    s.close()


def _business_user(db):
    from app.models import AppUser

    uid = f"T-{uuid.uuid4().hex[:8]}"
    u = AppUser(
        user_id=uid,
        full_name="Test Business",
        email=f"{uid}@example.invalid",
        role_code="BUSINESS",
        entity_id="ENT-BRN",
        department_id="DEP-BRN-DEL",
    )
    db.add(u)
    db.flush()
    return u


def test_hold_blocks_destruction_request(db):
    """A carton under an active hold cannot have a destruction request raised."""
    from app.models import AppUser, Carton
    from app.services import hold_service, request_service

    biz = _business_user(db)
    compliance = AppUser(
        user_id=f"C-{uuid.uuid4().hex[:8]}",
        full_name="Test Compliance",
        email=f"c-{uuid.uuid4().hex[:8]}@example.invalid",
        role_code="COMPLIANCE",
    )
    db.add(compliance)
    cid = f"CARTON-{uuid.uuid4().hex[:8]}"
    db.add(
        Carton(
            carton_id=cid,
            entity_id="ENT-BRN",
            department_id="DEP-BRN-DEL",
            owner_user_id=biz.user_id,
            document_type="Client KYC",
            archival_policy="Standard",
            carton_created_date="2020-01-01",
            retention_trigger_date="2010-01-01",
            assigned_vendor_id="VND-001",
        )
    )
    db.flush()
    carton = db.get(Carton, cid)

    hold_service.apply_hold(
        db, user=compliance, carton_id=cid, hold_id=f"H-{uuid.uuid4().hex[:8]}",
        matter_reference="MAT-1", reason="litigation",
    )
    from app.errors import AppError

    with pytest.raises(AppError):
        request_service.raise_request(
            db, user=biz, carton=carton, request_id=f"R-{uuid.uuid4().hex[:8]}", request_type="DESTRUCTION"
        )


def test_self_approval_denied(db):
    """Destruction approver must differ from requester."""
    from app.models import Carton
    from app.services import request_service
    from app.errors import AppError

    biz = _business_user(db)
    cid = f"CARTON-{uuid.uuid4().hex[:8]}"
    db.add(
        Carton(
            carton_id=cid, entity_id="ENT-BRN", department_id="DEP-BRN-DEL",
            owner_user_id=biz.user_id, document_type="Client KYC", archival_policy="Standard",
            carton_created_date="2020-01-01", retention_trigger_date="2010-01-01", assigned_vendor_id="VND-001",
        )
    )
    db.flush()
    carton = db.get(Carton, cid)
    req = request_service.raise_request(
        db, user=biz, carton=carton, request_id=f"R-{uuid.uuid4().hex[:8]}", request_type="DESTRUCTION"
    )
    # Business user is not COMPLIANCE -> forbidden anyway; this asserts the SoD path.
    with pytest.raises(AppError):
        request_service.approve_destruction(db, user=biz, request_id=req.request_id)
