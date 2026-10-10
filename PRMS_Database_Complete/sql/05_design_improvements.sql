-- PRMS design improvements v1.1 — ADDITIVE migration. PostgreSQL 16+.
-- Run ONCE after 01_schema.sql (order: 01 -> 02 -> 05 -> 04), as the migration owner.
--
-- This migration is purely additive: it creates indexes and comments only. It does
-- NOT alter, drop or rename any existing table, column, constraint or trigger, so the
-- reference seed (02) and the synthetic constraint checks (04) remain valid unchanged.
--
-- Rationale: 01_schema.sql already models the domain correctly (keys, scope CHECKs,
-- exclusion constraints, append-only triggers, half-open ranges, the retention view).
-- The gaps addressed here are read-path access patterns that the brief's required
-- screens and the <2s list/filter target depend on, plus documentation of design intent.
BEGIN;
SET search_path = prms, public;

-- 1. Business "my requests" / department queue.
--    SERVICE_REQUEST is already indexed by (vendor_id,status,raised_at) for the vendor
--    queue and by (carton_id,raised_at) for carton history, but a Business user's own
--    request list filters by raiser. Partial-free btree keeps it simple.
CREATE INDEX IF NOT EXISTS request_raiser_idx
    ON service_request (raised_by, request_status, raised_at);

-- 2. Compliance destruction approval queue: approvals filter on destruction requests
--    awaiting an independent approver. request_type is constrained to DESTRUCTION here.
CREATE INDEX IF NOT EXISTS request_approval_queue_idx
    ON service_request (request_status, raised_at)
    WHERE request_type = 'DESTRUCTION';

-- 3. Facilities "what is in this warehouse" occupancy view. state_dashboard_idx leads
--    with status_code; a warehouse-first index serves per-location drilldown directly.
CREATE INDEX IF NOT EXISTS state_warehouse_idx
    ON carton_state (warehouse_id, status_code)
    WHERE warehouse_id IS NOT NULL;

-- 4. Alert dashboards: "due soon / overdue" lists scan open alerts by due date.
--    alert_owner_idx covers the per-user view; this covers the estate-wide due list.
CREATE INDEX IF NOT EXISTS alert_due_idx
    ON alert (state, due_on)
    WHERE state IN ('OPEN', 'ACKNOWLEDGED');

-- 5. Exception register drilldown by carton. exception_queue_idx leads with status;
--    carton-first lookup supports "show all exceptions for this carton".
CREATE INDEX IF NOT EXISTS exception_carton_idx
    ON exception_case (carton_id)
    WHERE carton_id IS NOT NULL;

-- 6. Vendor-scoped exception visibility: a vendor user sees only their own owned,
--    vendor-redacted exceptions. Supports that scoped filter without a full scan.
CREATE INDEX IF NOT EXISTS exception_vendor_idx
    ON exception_case (owner_vendor_id, status)
    WHERE owner_vendor_id IS NOT NULL;

-- 7. Certificate reconciliation joins certificate evidence back to the carton it
--    claims to destroy. certificate_carton_idx already exists on carton_reference;
--    this adds the destruction-date dimension used in date-mismatch findings.
CREATE INDEX IF NOT EXISTS certificate_destroyed_idx
    ON certificate_evidence (destroyed_on)
    WHERE destroyed_on IS NOT NULL;

-- 8. Expected-charge review groups independently calculated costs by vendor+period,
--    which is exactly how invoice reconciliation Pass 2 compares against invoice lines.
CREATE INDEX IF NOT EXISTS expected_charge_period_idx
    ON expected_charge (vendor_id, service_month);

-- 9. Reconciliation finding lookup by the exception it rolls up into (continuity view).
CREATE INDEX IF NOT EXISTS finding_exception_idx
    ON reconciliation_finding (exception_id);

-- 10. Session cleanup / active-session checks filter on expiry of non-revoked tokens.
CREATE INDEX IF NOT EXISTS session_expiry_idx
    ON user_session (expires_at)
    WHERE revoked_at IS NULL;

-- Documentation of design intent captured in the catalog (visible via \d+ and tooling).
COMMENT ON TABLE event_log IS
    'Single canonical append-only event log for all streams (carton, reference, user, '
    'certificate, exception, reconciliation). Projections are rebuilt from this; it is '
    'the only source of audit truth. Protected by the protect_evidence trigger.';
COMMENT ON TABLE carton_state IS
    'Rebuildable projection of current status/custody/holds per carton. Never an '
    'independent source of truth: derived by replaying event_log in occurred_at order.';
COMMENT ON VIEW carton_retention IS
    'Computes destruction_due_on from the applicable retention_policy (entity-specific '
    'override preferred over global default). Reports MISSING_TRIGGER / MISSING_POLICY '
    'rather than inventing a date. Policy edits recompute with no code change.';
COMMENT ON COLUMN vendor_rate.effective_to IS
    'EXCLUSIVE upper bound. Source inclusive end dates must be converted to +1 day on '
    'import. Enforced non-overlapping per (vendor_id, activity) by a gist EXCLUDE.';
COMMENT ON COLUMN event_log.resulting_status IS
    'NULL means the event did not change status (e.g. LEGAL_HOLD_APPLIED), NOT unknown '
    'or deleted. Replay must preserve the prior status across such events.';

COMMIT;
