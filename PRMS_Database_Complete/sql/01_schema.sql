-- PRMS database design v1. PostgreSQL 16+ recommended.
-- Run ONCE against an empty development database, as the migration owner.
-- This is structural DDL, not a complete workflow implementation. See README.md.
-- Source workbook stays unchanged. Invalid historical evidence goes to raw rows.
BEGIN;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE SCHEMA prms;
SET search_path = prms, public;

-- ORGANIZATION / IDENTITY -----------------------------------------------------
CREATE TABLE business_entity (
    entity_id text PRIMARY KEY,
    entity_name text NOT NULL UNIQUE
);
CREATE TABLE department (
    department_id text PRIMARY KEY,
    entity_id text NOT NULL REFERENCES business_entity,
    department_name text NOT NULL,
    UNIQUE (entity_id, department_id)
);
CREATE TABLE vendor (
    vendor_id text PRIMARY KEY,
    vendor_name text NOT NULL,
    status text NOT NULL CHECK (status IN ('Active','Terminated')),
    contract_start date,
    contract_ref text,
    ops_contact_email text,
    recertification_frequency text NOT NULL DEFAULT 'Quarterly'
);
CREATE TABLE warehouse (
    location_id text PRIMARY KEY,
    vendor_id text NOT NULL REFERENCES vendor,
    location_name text NOT NULL,
    city text NOT NULL,
    capacity_cartons integer CHECK (capacity_cartons >= 0),
    UNIQUE (vendor_id, location_id)
);
CREATE TABLE app_user (
    user_id text PRIMARY KEY,
    full_name text NOT NULL,
    email text NOT NULL,
    role_code text NOT NULL CHECK (role_code IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE')),
    entity_id text REFERENCES business_entity,
    department_id text,
    vendor_id text REFERENCES vendor,
    password_hash text, -- NULL for imported identities until credentials are provisioned
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (entity_id, department_id) REFERENCES department (entity_id, department_id),
    CHECK (
      (role_code = 'BUSINESS' AND entity_id IS NOT NULL AND department_id IS NOT NULL AND vendor_id IS NULL)
      OR (role_code = 'VENDOR' AND entity_id IS NULL AND department_id IS NULL AND vendor_id IS NOT NULL)
      OR (role_code IN ('FACILITIES','COMPLIANCE') AND entity_id IS NULL AND department_id IS NULL AND vendor_id IS NULL)
    )
);
CREATE UNIQUE INDEX app_user_email_ci ON app_user (lower(email));
CREATE TABLE user_session (
    token_hash text PRIMARY KEY, -- store a digest, never the session bearer token
    user_id text NOT NULL REFERENCES app_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    CHECK (expires_at > created_at)
);
CREATE INDEX session_user_idx ON user_session (user_id);

-- REFERENCE DATA: supplied values are seeded separately, never hardcoded here --
CREATE TABLE document_type (
    document_type text PRIMARY KEY,
    base_retention_years integer NOT NULL CHECK (base_retention_years >= 0),
    trigger_event_description text NOT NULL
);
CREATE TABLE archival_policy (
    archival_policy text PRIMARY KEY
);
CREATE TABLE retention_policy (
    policy_id text PRIMARY KEY,
    entity_id text REFERENCES business_entity, -- NULL = supplied global default
    document_type text NOT NULL REFERENCES document_type,
    archival_policy text NOT NULL REFERENCES archival_policy,
    retention_years integer NOT NULL CHECK (retention_years BETWEEN 0 AND 999),
    revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (entity_id, document_type, archival_policy)
    -- Current configuration. All edits must also append before/after values to event_log.
);
CREATE TABLE vendor_rate (
    rate_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id text NOT NULL REFERENCES vendor,
    activity text NOT NULL CHECK (activity IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION','STORAGE')),
    rate_inr numeric(14,2) NOT NULL CHECK (rate_inr >= 0),
    unit text NOT NULL CHECK (unit IN ('PER_CARTON','PER_CARTON_MONTH')),
    effective_from date NOT NULL,
    effective_to date, -- EXCLUSIVE; source inclusive end dates must be converted +1 day
    CHECK (effective_to IS NULL OR effective_to > effective_from),
    CHECK ((activity = 'STORAGE') = (unit = 'PER_CARTON_MONTH')),
    EXCLUDE USING gist (
      vendor_id WITH =, activity WITH =,
      daterange(effective_from, effective_to, '[)') WITH &&
    )
);
CREATE TABLE sla_rule (
    sla_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    vendor_id text REFERENCES vendor, -- NULL = global fallback
    activity text NOT NULL CHECK (activity IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION')),
    business_days integer NOT NULL CHECK (business_days >= 0),
    starts_on text NOT NULL CHECK (starts_on IN ('REQUEST_SUBMITTED','DESTRUCTION_APPROVED')),
    ends_on text NOT NULL CHECK (ends_on IN ('WAREHOUSE_RECEIPT','BUSINESS_DELIVERY','DESTRUCTION_EXECUTED','CERTIFICATE_ISSUED')),
    definition text NOT NULL,
    revision integer NOT NULL DEFAULT 1 CHECK (revision > 0),
    UNIQUE NULLS NOT DISTINCT (vendor_id, activity)
);
CREATE TABLE holiday (
    holiday_date date PRIMARY KEY,
    holiday_name text NOT NULL
);
CREATE TABLE threshold_rule (
    threshold_id text PRIMARY KEY,
    applies_to text NOT NULL,
    threshold_days integer NOT NULL CHECK (threshold_days >= 0),
    day_basis text NOT NULL CHECK (day_basis IN ('CALENDAR','BUSINESS')),
    meaning text NOT NULL
);
CREATE TABLE tax_rule (
    tax_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tax_code text NOT NULL,
    rate_percent numeric(5,2) NOT NULL CHECK (rate_percent BETWEEN 0 AND 100),
    effective_from date NOT NULL,
    effective_to date,
    CHECK (effective_to IS NULL OR effective_to > effective_from),
    EXCLUDE USING gist (tax_code WITH =, daterange(effective_from,effective_to,'[)') WITH &&)
);
CREATE TABLE carton_status (
    status_code text PRIMARY KEY,
    meaning text NOT NULL,
    is_terminal boolean NOT NULL DEFAULT false
);
CREATE TABLE event_type (
    event_type text PRIMARY KEY,
    meaning text NOT NULL,
    changes_custody boolean NOT NULL DEFAULT false,
    expected_role text CHECK (expected_role IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE','SYSTEM')),
    resulting_status text REFERENCES carton_status,
    request_requirement text NOT NULL DEFAULT 'NONE',
    source_definition jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE TABLE lifecycle_transition (
    from_status text NOT NULL REFERENCES carton_status,
    event_type text NOT NULL REFERENCES event_type,
    to_status text NOT NULL REFERENCES carton_status,
    PRIMARY KEY (from_status, event_type)
    -- Service interprets this table; it cannot replace permission/hold/retention checks.
);

-- IMPORT EVIDENCE: preserve every row, including duplicates and bad references --
CREATE TABLE import_batch (
    batch_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_name text NOT NULL,
    source_kind text NOT NULL CHECK (source_kind IN ('WORKBOOK','INVENTORY','INVOICE','CERTIFICATE')),
    vendor_id text REFERENCES vendor,
    sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
    uploaded_by text REFERENCES app_user,
    uploaded_at timestamptz NOT NULL DEFAULT now(),
    source_timezone text NOT NULL DEFAULT 'Asia/Kolkata',
    artifact_uri text,
    UNIQUE NULLS NOT DISTINCT (source_kind, vendor_id, sha256)
);
CREATE TABLE import_row (
    row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id bigint NOT NULL REFERENCES import_batch,
    sheet_name text NOT NULL,
    row_number integer NOT NULL CHECK (row_number > 0),
    raw_values jsonb NOT NULL,
    UNIQUE (batch_id, sheet_name, row_number)
);
CREATE TABLE import_issue (
    issue_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    row_id bigint NOT NULL REFERENCES import_row,
    code text NOT NULL,
    message text NOT NULL,
    disposition text NOT NULL CHECK (disposition IN ('REJECTED','WARNING','DUPLICATE')),
    recorded_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (row_id, code)
);

-- OPERATIONAL PROJECTIONS -----------------------------------------------------
CREATE TABLE carton (
    carton_id text PRIMARY KEY,
    entity_id text NOT NULL,
    department_id text NOT NULL,
    owner_user_id text NOT NULL REFERENCES app_user,
    document_type text NOT NULL REFERENCES document_type,
    archival_policy text NOT NULL REFERENCES archival_policy,
    carton_created_date date NOT NULL,
    retention_trigger_date date, -- deliberately nullable; never invent missing trigger
    declared_file_count integer CHECK (declared_file_count >= 0),
    assigned_vendor_id text NOT NULL REFERENCES vendor,
    barcode text, -- source duplicates are preserved and flagged; live API checks uniqueness
    remarks text,
    source_row_id bigint UNIQUE REFERENCES import_row,
    FOREIGN KEY (entity_id, department_id) REFERENCES department (entity_id, department_id),
    UNIQUE (carton_id, document_type)
);
CREATE INDEX carton_scope_idx ON carton (entity_id, department_id);
CREATE INDEX carton_vendor_idx ON carton (assigned_vendor_id);
CREATE INDEX carton_barcode_idx ON carton (barcode);
CREATE TABLE file_record (
    file_id text PRIMARY KEY,
    carton_id text NOT NULL,
    file_ref text NOT NULL,
    document_type text NOT NULL,
    file_description text,
    document_year integer CHECK (document_year BETWEEN 1000 AND 9999),
    contains_pii boolean NOT NULL DEFAULT true,
    source_row_id bigint UNIQUE REFERENCES import_row,
    FOREIGN KEY (carton_id, document_type) REFERENCES carton (carton_id, document_type)
    -- Mixed-type historical rows stay in import_row with issues; do not silently retag.
);
CREATE INDEX file_carton_idx ON file_record (carton_id);
CREATE TABLE service_request (
    request_id text PRIMARY KEY,
    carton_id text NOT NULL REFERENCES carton,
    request_type text NOT NULL CHECK (request_type IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION')),
    vendor_id text NOT NULL REFERENCES vendor,
    raised_by text NOT NULL REFERENCES app_user,
    raised_at timestamptz NOT NULL,
    request_status text NOT NULL CHECK (request_status IN ('Open','In Progress','Completed','Rejected','Cancelled')),
    destination jsonb, -- structured address/department/warehouse snapshot, validated by API
    vendor_ack_at timestamptz,
    completed_at timestamptz,
    approved_by text REFERENCES app_user,
    approved_at timestamptz,
    rejection_reason text,
    sla_rule_id bigint REFERENCES sla_rule,
    sla_snapshot jsonb, -- start/end definition, days, revision used for this request
    sla_due_date date, -- cached derived deadline, NOT a stored breach flag
    source_row_id bigint UNIQUE REFERENCES import_row,
    UNIQUE (carton_id, request_id),
    CHECK (approved_by IS NULL OR approved_by <> raised_by),
    CHECK ((approved_by IS NULL) = (approved_at IS NULL)),
    CHECK (request_type = 'DESTRUCTION' OR approved_by IS NULL),
    CHECK (vendor_ack_at IS NULL OR vendor_ack_at >= raised_at),
    CHECK (completed_at IS NULL OR completed_at >= raised_at),
    CHECK (approved_at IS NULL OR approved_at >= raised_at),
    CHECK (request_status <> 'Rejected' OR nullif(btrim(rejection_reason),'') IS NOT NULL)
);
CREATE INDEX request_vendor_queue_idx ON service_request (vendor_id, request_status, raised_at);
CREATE INDEX request_carton_idx ON service_request (carton_id, raised_at);

-- ONE CANONICAL EVENT LOG ----------------------------------------------------
CREATE TABLE event_log (
    event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stream_kind text NOT NULL CHECK (stream_kind IN ('CARTON','REFERENCE','USER','CERTIFICATE','EXCEPTION','RECONCILIATION')),
    stream_id text NOT NULL,
    stream_version bigint NOT NULL CHECK (stream_version > 0),
    carton_id text REFERENCES carton,
    request_id text,
    event_type text NOT NULL REFERENCES event_type,
    occurred_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    actor_user_id text REFERENCES app_user,
    actor_role text NOT NULL CHECK (actor_role IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE','SYSTEM')),
    actor_reference text, -- original source identity, e.g. VND-002, not a fabricated user
    channel text NOT NULL CHECK (channel IN ('UI','API','UPLOAD','SCHEDULER','MIGRATION')),
    source_event_id text,
    source_row_id bigint REFERENCES import_row,
    from_location_ref text, -- original office text or warehouse code preserved
    to_location_ref text,
    resulting_status text REFERENCES carton_status, -- NULL for non-state-changing events
    schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0),
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    corrects_event_id bigint REFERENCES event_log,
    idempotency_key text NOT NULL UNIQUE,
    UNIQUE (stream_kind, stream_id, stream_version),
    UNIQUE (carton_id, event_id),
    UNIQUE (source_row_id, event_type),
    FOREIGN KEY (carton_id, request_id) REFERENCES service_request (carton_id, request_id),
    CHECK ((stream_kind = 'CARTON' AND carton_id IS NOT NULL AND stream_id = carton_id)
       OR (stream_kind <> 'CARTON' AND carton_id IS NULL AND request_id IS NULL)),
    CHECK (channel IN ('UPLOAD','MIGRATION','SCHEDULER') OR actor_user_id IS NOT NULL),
    CHECK (jsonb_typeof(payload) = 'object')
);
CREATE INDEX event_replay_idx ON event_log (carton_id, occurred_at, event_id) WHERE carton_id IS NOT NULL;
CREATE INDEX event_request_idx ON event_log (request_id) WHERE request_id IS NOT NULL;
CREATE INDEX event_source_idx ON event_log (source_event_id) WHERE source_event_id IS NOT NULL;

CREATE TABLE carton_state (
    carton_id text PRIMARY KEY REFERENCES carton,
    status_code text NOT NULL REFERENCES carton_status,
    custody text NOT NULL CHECK (custody IN ('BUSINESS','TRANSIT','WAREHOUSE','DESTROYED','UNKNOWN')),
    vendor_id text REFERENCES vendor,
    warehouse_id text,
    active_hold_count integer NOT NULL DEFAULT 0 CHECK (active_hold_count >= 0),
    state_since timestamptz NOT NULL,
    last_event_id bigint NOT NULL,
    version bigint NOT NULL CHECK (version > 0),
    rebuilt_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (carton_id, last_event_id) REFERENCES event_log (carton_id, event_id),
    FOREIGN KEY (vendor_id, warehouse_id) REFERENCES warehouse (vendor_id, location_id),
    CHECK ((custody = 'WAREHOUSE' AND vendor_id IS NOT NULL AND warehouse_id IS NOT NULL)
      OR (custody <> 'WAREHOUSE' AND warehouse_id IS NULL))
);
CREATE INDEX state_dashboard_idx ON carton_state (status_code, vendor_id, warehouse_id);
CREATE TABLE custody_interval (
    interval_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    carton_id text NOT NULL REFERENCES carton,
    custody text NOT NULL CHECK (custody IN ('BUSINESS','TRANSIT','WAREHOUSE','DESTROYED','UNKNOWN')),
    vendor_id text REFERENCES vendor,
    warehouse_id text,
    valid_from timestamptz NOT NULL,
    valid_to timestamptz, -- exclusive; NULL = currently open
    start_event_id bigint NOT NULL,
    end_event_id bigint,
    FOREIGN KEY (carton_id, start_event_id) REFERENCES event_log (carton_id, event_id),
    FOREIGN KEY (carton_id, end_event_id) REFERENCES event_log (carton_id, event_id),
    FOREIGN KEY (vendor_id, warehouse_id) REFERENCES warehouse (vendor_id, location_id),
    CHECK (valid_to IS NULL OR valid_to > valid_from),
    CHECK ((valid_to IS NULL) = (end_event_id IS NULL)),
    CHECK ((custody = 'WAREHOUSE' AND vendor_id IS NOT NULL AND warehouse_id IS NOT NULL)
      OR (custody <> 'WAREHOUSE' AND warehouse_id IS NULL)),
    EXCLUDE USING gist (carton_id WITH =, tstzrange(valid_from,valid_to,'[)') WITH &&)
);
CREATE INDEX custody_billing_idx ON custody_interval (vendor_id, valid_from) WHERE custody = 'WAREHOUSE';
CREATE TABLE legal_hold (
    hold_id text PRIMARY KEY,
    carton_id text NOT NULL REFERENCES carton,
    matter_reference text NOT NULL,
    reason text NOT NULL,
    raised_by text REFERENCES app_user,
    starts_at timestamptz NOT NULL,
    start_precision text NOT NULL DEFAULT 'TIMESTAMP' CHECK (start_precision IN ('DATE','TIMESTAMP')),
    applied_event_id bigint NOT NULL,
    released_at timestamptz,
    release_precision text CHECK (release_precision IN ('DATE','TIMESTAMP')),
    released_by text REFERENCES app_user,
    release_reason text,
    released_event_id bigint,
    source_row_id bigint UNIQUE REFERENCES import_row,
    FOREIGN KEY (carton_id, applied_event_id) REFERENCES event_log (carton_id, event_id),
    FOREIGN KEY (carton_id, released_event_id) REFERENCES event_log (carton_id, event_id),
    CHECK (released_at IS NULL OR released_at >= starts_at),
    CHECK ((released_at IS NULL AND released_event_id IS NULL AND release_precision IS NULL)
       OR (released_at IS NOT NULL AND released_event_id IS NOT NULL AND release_precision IS NOT NULL))
    -- Live release requires actor/reason in service; legacy missing evidence is flagged.
);
CREATE INDEX hold_active_idx ON legal_hold (carton_id, starts_at) WHERE released_at IS NULL;

-- VENDOR DECLARATIONS ARE EVIDENCE, NOT OPERATIONAL MASTER DATA ---------------
CREATE TABLE vendor_declaration (
    declaration_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id bigint NOT NULL REFERENCES import_batch,
    vendor_id text NOT NULL REFERENCES vendor,
    cycle text NOT NULL,
    declared_at timestamptz NOT NULL,
    UNIQUE (batch_id, vendor_id, cycle, declared_at)
);
CREATE TABLE vendor_declaration_item (
    declaration_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    declaration_id bigint NOT NULL REFERENCES vendor_declaration,
    carton_reference text NOT NULL, -- intentionally NO carton FK or deduplication
    declared_location_reference text,
    declared_status text,
    vendor_notes text,
    facility_notes_as_received text,
    source_row_id bigint NOT NULL UNIQUE REFERENCES import_row
);
CREATE INDEX declaration_lookup_idx ON vendor_declaration_item (declaration_id, carton_reference);
CREATE TABLE vendor_invoice (
    invoice_record_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_reference text NOT NULL, -- not globally unique: conflicting source versions remain evidence
    vendor_id text NOT NULL REFERENCES vendor,
    billing_month date NOT NULL CHECK (extract(day FROM billing_month) = 1),
    invoice_date date,
    currency text NOT NULL,
    declared_line_count integer,
    declared_subtotal numeric(18,2),
    declared_tax_rate numeric(7,3),
    declared_tax_amount numeric(18,2),
    declared_total numeric(18,2),
    declared_status text,
    source_row_id bigint NOT NULL UNIQUE REFERENCES import_row
    -- Negative, inconsistent and duplicate financial values remain investigable evidence.
);
CREATE INDEX invoice_period_idx ON vendor_invoice (vendor_id, billing_month);
CREATE TABLE vendor_invoice_line (
    invoice_line_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_record_id bigint REFERENCES vendor_invoice,
    invoice_reference text NOT NULL, -- retained even when parent header is absent/ambiguous
    line_number integer,
    line_type text,
    activity_reference text,
    carton_reference text,
    request_reference text,
    quantity numeric(18,4),
    unit_rate numeric(18,4),
    line_amount numeric(18,2),
    service_period_raw text,
    service_month date CHECK (service_month IS NULL OR extract(day FROM service_month) = 1),
    source_row_id bigint NOT NULL UNIQUE REFERENCES import_row
    -- No UNIQUE(invoice,line_number): duplicate vendor lines must be detected, not discarded.
);
CREATE INDEX invoice_line_header_idx ON vendor_invoice_line (invoice_record_id);
CREATE INDEX invoice_line_request_idx ON vendor_invoice_line (request_reference);
CREATE TABLE certificate_evidence (
    certificate_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    certificate_reference text NOT NULL, -- repeat across carton rows is normal
    carton_reference text NOT NULL, -- deliberately no FK; unknown evidence is still preserved
    vendor_reference text NOT NULL,
    destroyed_on date,
    destruction_location_reference text,
    destruction_method text,
    witnessed_by_reference text,
    issued_on date,
    source_row_id bigint UNIQUE REFERENCES import_row,
    evidence_event_id bigint REFERENCES event_log,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    CHECK (source_row_id IS NOT NULL OR evidence_event_id IS NOT NULL)
    -- Do not CHECK date order/vendor consistency here: those are reconciliation findings.
);
CREATE INDEX certificate_batch_idx ON certificate_evidence (certificate_reference, vendor_reference, destroyed_on);
CREATE INDEX certificate_carton_idx ON certificate_evidence (carton_reference);

-- RECONCILIATION, EXPECTED COSTS AND EXCEPTIONS -------------------------------
CREATE TABLE reconciliation_run (
    run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_kind text NOT NULL CHECK (run_kind IN ('INVENTORY','INVOICE','CERTIFICATE','DATA_QUALITY')),
    scope_key text NOT NULL, -- e.g. vendor + declaration timestamp, invoice record, or date range
    input_fingerprint text NOT NULL, -- input hashes + cutoff + rule snapshot + engine version
    parameters jsonb NOT NULL,
    rule_snapshot jsonb NOT NULL,
    engine_version text NOT NULL,
    requested_by text NOT NULL REFERENCES app_user,
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    status text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
    counts jsonb NOT NULL DEFAULT '{}'::jsonb,
    error_summary text,
    UNIQUE (run_kind, scope_key, input_fingerprint),
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);
CREATE TABLE expected_charge (
    expected_charge_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id bigint NOT NULL REFERENCES reconciliation_run,
    charge_key text NOT NULL,
    carton_id text NOT NULL REFERENCES carton,
    vendor_id text NOT NULL REFERENCES vendor,
    department_id text NOT NULL REFERENCES department,
    service_month date NOT NULL CHECK (extract(day FROM service_month) = 1),
    activity text NOT NULL CHECK (activity IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION','STORAGE')),
    request_id text REFERENCES service_request,
    source_event_id bigint REFERENCES event_log,
    rate_id bigint REFERENCES vendor_rate,
    quantity numeric(18,4) NOT NULL CHECK (quantity >= 0),
    applied_rate numeric(18,4),
    net_amount numeric(18,2),
    calculation_status text NOT NULL CHECK (calculation_status IN ('CALCULATED','MISSING_RATE','INCOMPLETE_EVIDENCE')),
    basis jsonb NOT NULL, -- custody interval/event IDs, policy version and allocation basis
    UNIQUE (run_id, charge_key),
    CHECK (calculation_status <> 'CALCULATED' OR (rate_id IS NOT NULL AND applied_rate IS NOT NULL AND net_amount IS NOT NULL))
    -- Tax is calculated on invoice-period subtotal, rounded once per agreed tax rule.
);
CREATE TABLE exception_case (
    exception_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    stable_key text NOT NULL UNIQUE, -- continuity key, not run ID; see README examples
    exception_type text NOT NULL,
    severity text NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    owner_role text NOT NULL CHECK (owner_role IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE')),
    owner_user_id text REFERENCES app_user,
    owner_vendor_id text REFERENCES vendor,
    carton_id text REFERENCES carton,
    subject_reference text NOT NULL, -- supports unknown carton IDs
    visibility text NOT NULL DEFAULT 'FACILITIES' CHECK (visibility IN ('FACILITIES','COMPLIANCE','BUSINESS_SCOPED','VENDOR_REDACTED')),
    first_detected_at timestamptz NOT NULL,
    last_detected_at timestamptz NOT NULL,
    first_observed_as_of timestamptz NOT NULL,
    last_observed_as_of timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','INVESTIGATING','RESOLVED','ACCEPTED_RISK')),
    resolution_reason text,
    resolved_by text REFERENCES app_user,
    resolved_at timestamptz,
    due_at timestamptz,
    CHECK (last_detected_at >= first_detected_at),
    CHECK (last_observed_as_of >= first_observed_as_of),
    CHECK (status NOT IN ('RESOLVED','ACCEPTED_RISK') OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL AND nullif(btrim(resolution_reason),'') IS NOT NULL))
);
CREATE INDEX exception_queue_idx ON exception_case (status, owner_role, severity);
CREATE TABLE reconciliation_finding (
    finding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id bigint NOT NULL REFERENCES reconciliation_run,
    exception_id bigint NOT NULL REFERENCES exception_case,
    finding_key text NOT NULL,
    observed_as_of timestamptz NOT NULL,
    rule_code text NOT NULL,
    rule_revision text NOT NULL,
    evidence jsonb NOT NULL, -- actual vs expected; IDs of source rows, events and rules
    UNIQUE (run_id, finding_key)
);
CREATE TABLE alert (
    alert_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    carton_id text NOT NULL REFERENCES carton,
    alert_type text NOT NULL,
    dedupe_key text NOT NULL UNIQUE, -- type + subject + policy/episode
    owner_user_id text REFERENCES app_user,
    due_on date,
    state text NOT NULL DEFAULT 'OPEN' CHECK (state IN ('OPEN','ACKNOWLEDGED','RESOLVED','SUPERSEDED')),
    basis jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_evaluated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz
);
CREATE INDEX alert_owner_idx ON alert (owner_user_id, state);

-- APPEND-ONLY PROTECTION: migration owner must not be the runtime login --------
CREATE FUNCTION reject_evidence_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Append-only table %.%: append correction/replacement evidence instead', TG_TABLE_SCHEMA, TG_TABLE_NAME
    USING ERRCODE = '55000';
END;
$$;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'event_log','import_batch','import_row','import_issue',
    'vendor_declaration','vendor_declaration_item','vendor_invoice','vendor_invoice_line',
    'certificate_evidence','reconciliation_finding','expected_charge'
  ] LOOP
    EXECUTE format('CREATE TRIGGER protect_evidence BEFORE UPDATE OR DELETE ON prms.%I FOR EACH ROW EXECUTE FUNCTION prms.reject_evidence_mutation()', t);
    EXECUTE format('CREATE TRIGGER protect_evidence_truncate BEFORE TRUNCATE ON prms.%I FOR EACH STATEMENT EXECUTE FUNCTION prms.reject_evidence_mutation()', t);
  END LOOP;
END;
$$;

-- Retention is a VIEW, not a user-entered field or a stale due-date column.
CREATE VIEW carton_retention AS
SELECT c.carton_id, c.entity_id, c.department_id, c.retention_trigger_date,
       p.policy_id, p.revision AS policy_revision, p.retention_years,
       CASE WHEN c.retention_trigger_date IS NOT NULL AND p.policy_id IS NOT NULL
            THEN (c.retention_trigger_date + make_interval(years => p.retention_years))::date END AS destruction_due_on,
       CASE WHEN c.retention_trigger_date IS NULL THEN 'MISSING_TRIGGER'
            WHEN p.policy_id IS NULL THEN 'MISSING_POLICY' ELSE 'CALCULATED' END AS calculation_status
FROM carton c
LEFT JOIN LATERAL (
  SELECT rp.* FROM retention_policy rp
  WHERE rp.document_type = c.document_type AND rp.archival_policy = c.archival_policy
    AND (rp.entity_id = c.entity_id OR rp.entity_id IS NULL)
  ORDER BY (rp.entity_id IS NOT NULL) DESC LIMIT 1
) p ON true;

REVOKE ALL ON SCHEMA prms FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA prms FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA prms FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA prms FROM PUBLIC;
COMMIT;
