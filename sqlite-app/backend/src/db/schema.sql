-- PRMS schema — SQLite translation of PRMS_Database_Complete/sql/01_schema.sql.
-- SQLite 3.40+. Apply once to an empty database file.
--
-- WHAT CHANGED vs the authoritative PostgreSQL schema, and WHY:
--   * No schema namespace ("prms."): SQLite has one namespace per file.
--   * text/int/numeric -> TEXT/INTEGER/REAL (money kept as TEXT to preserve exact
--     decimal strings; never use REAL/float for currency arithmetic).
--   * timestamptz/date -> TEXT storing ISO-8601 strings (UTC "...Z" for instants,
--     "YYYY-MM-DD" for dates). SQLite has no native date types.
--   * jsonb -> TEXT holding JSON; validated with json_valid() CHECKs.
--   * GENERATED ALWAYS AS IDENTITY -> INTEGER PRIMARY KEY AUTOINCREMENT.
--   * gist EXCLUDE (non-overlapping rate/custody ranges) -> NOT representable in
--     SQLite; enforced in the application layer (services) + documented here.
--   * Partial / expression indexes mostly supported by SQLite 3.40 and kept.
--   * UNIQUE NULLS NOT DISTINCT -> emulated with a UNIQUE index over
--     COALESCE(col,'<NULL>') where the Postgres version treats NULLs as equal.
--   * Append-only evidence triggers -> implemented as BEFORE UPDATE/DELETE
--     triggers that RAISE(ABORT), mirroring the Postgres protect_evidence trigger.
-- The domain (tables, keys, lifecycle, single event log, projections) is preserved.

PRAGMA foreign_keys = ON;

-- ORGANIZATION / IDENTITY ----------------------------------------------------
CREATE TABLE business_entity (
    entity_id   TEXT PRIMARY KEY,
    entity_name TEXT NOT NULL UNIQUE
);

CREATE TABLE department (
    department_id   TEXT PRIMARY KEY,
    entity_id       TEXT NOT NULL REFERENCES business_entity(entity_id),
    department_name TEXT NOT NULL,
    UNIQUE (entity_id, department_id)
);

CREATE TABLE vendor (
    vendor_id                 TEXT PRIMARY KEY,
    vendor_name               TEXT NOT NULL,
    status                    TEXT NOT NULL CHECK (status IN ('Active','Terminated')),
    contract_start            TEXT,
    contract_ref              TEXT,
    ops_contact_email         TEXT,
    recertification_frequency TEXT NOT NULL DEFAULT 'Quarterly'
);

CREATE TABLE warehouse (
    location_id      TEXT PRIMARY KEY,
    vendor_id        TEXT NOT NULL REFERENCES vendor(vendor_id),
    location_name    TEXT NOT NULL,
    city             TEXT NOT NULL,
    capacity_cartons INTEGER CHECK (capacity_cartons >= 0),
    UNIQUE (vendor_id, location_id)
);

CREATE TABLE app_user (
    user_id       TEXT PRIMARY KEY,
    full_name     TEXT NOT NULL,
    email         TEXT NOT NULL,
    role_code     TEXT NOT NULL CHECK (role_code IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE')),
    entity_id     TEXT REFERENCES business_entity(entity_id),
    department_id TEXT,
    vendor_id     TEXT REFERENCES vendor(vendor_id),
    password_hash TEXT,                    -- NULL for imported identities until provisioned
    is_active     INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    FOREIGN KEY (entity_id, department_id) REFERENCES department (entity_id, department_id),
    CHECK (
      (role_code = 'BUSINESS'  AND entity_id IS NOT NULL AND department_id IS NOT NULL AND vendor_id IS NULL)
   OR (role_code = 'VENDOR'    AND entity_id IS NULL AND department_id IS NULL AND vendor_id IS NOT NULL)
   OR (role_code IN ('FACILITIES','COMPLIANCE') AND entity_id IS NULL AND department_id IS NULL AND vendor_id IS NULL)
    )
);
CREATE UNIQUE INDEX app_user_email_ci ON app_user (lower(email));

CREATE TABLE user_session (
    token_hash TEXT PRIMARY KEY,           -- SHA-256 digest, never the raw bearer token
    user_id    TEXT NOT NULL REFERENCES app_user(user_id),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    CHECK (expires_at > created_at)
);
CREATE INDEX session_user_idx ON user_session (user_id);

-- REFERENCE DATA (seeded separately) -----------------------------------------
CREATE TABLE document_type (
    document_type             TEXT PRIMARY KEY,
    base_retention_years      INTEGER NOT NULL CHECK (base_retention_years >= 0),
    trigger_event_description TEXT NOT NULL
);

CREATE TABLE archival_policy (
    archival_policy TEXT PRIMARY KEY
);

CREATE TABLE retention_policy (
    policy_id       TEXT PRIMARY KEY,
    entity_id       TEXT REFERENCES business_entity(entity_id),  -- NULL = global default
    document_type   TEXT NOT NULL REFERENCES document_type(document_type),
    archival_policy TEXT NOT NULL REFERENCES archival_policy(archival_policy),
    retention_years INTEGER NOT NULL CHECK (retention_years BETWEEN 0 AND 999),
    revision        INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
-- UNIQUE NULLS NOT DISTINCT (entity_id, document_type, archival_policy):
CREATE UNIQUE INDEX retention_policy_uq
  ON retention_policy (COALESCE(entity_id,'<GLOBAL>'), document_type, archival_policy);

CREATE TABLE vendor_rate (
    rate_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id      TEXT NOT NULL REFERENCES vendor(vendor_id),
    activity       TEXT NOT NULL CHECK (activity IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION','STORAGE')),
    rate_inr       TEXT NOT NULL,          -- decimal string; app validates >= 0
    unit           TEXT NOT NULL CHECK (unit IN ('PER_CARTON','PER_CARTON_MONTH')),
    effective_from TEXT NOT NULL,
    effective_to   TEXT,                   -- EXCLUSIVE upper bound; source inclusive +1 day
    CHECK (effective_to IS NULL OR effective_to > effective_from),
    CHECK ((activity = 'STORAGE') = (unit = 'PER_CARTON_MONTH'))
    -- NON-OVERLAP per (vendor_id, activity): enforced in services (rateRepo.assertNoOverlap).
);
CREATE INDEX vendor_rate_lookup ON vendor_rate (vendor_id, activity, effective_from);

CREATE TABLE sla_rule (
    sla_rule_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id     TEXT REFERENCES vendor(vendor_id),  -- NULL = global fallback
    activity      TEXT NOT NULL CHECK (activity IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION')),
    business_days INTEGER NOT NULL CHECK (business_days >= 0),
    starts_on     TEXT NOT NULL CHECK (starts_on IN ('REQUEST_SUBMITTED','DESTRUCTION_APPROVED')),
    ends_on       TEXT NOT NULL CHECK (ends_on IN ('WAREHOUSE_RECEIPT','BUSINESS_DELIVERY','DESTRUCTION_EXECUTED','CERTIFICATE_ISSUED')),
    definition    TEXT NOT NULL,
    revision      INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0)
);
CREATE UNIQUE INDEX sla_rule_uq ON sla_rule (COALESCE(vendor_id,'<GLOBAL>'), activity);

CREATE TABLE holiday (
    holiday_date TEXT PRIMARY KEY,
    holiday_name TEXT NOT NULL
);

CREATE TABLE threshold_rule (
    threshold_id   TEXT PRIMARY KEY,
    applies_to     TEXT NOT NULL,
    threshold_days INTEGER NOT NULL CHECK (threshold_days >= 0),
    day_basis      TEXT NOT NULL CHECK (day_basis IN ('CALENDAR','BUSINESS')),
    meaning        TEXT NOT NULL
);

CREATE TABLE tax_rule (
    tax_rule_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    tax_code       TEXT NOT NULL,
    rate_percent   TEXT NOT NULL,          -- decimal string 0..100
    effective_from TEXT NOT NULL,
    effective_to   TEXT,
    CHECK (effective_to IS NULL OR effective_to > effective_from)
    -- NON-OVERLAP per tax_code: enforced in services.
);

CREATE TABLE carton_status (
    status_code TEXT PRIMARY KEY,
    meaning     TEXT NOT NULL,
    is_terminal INTEGER NOT NULL DEFAULT 0 CHECK (is_terminal IN (0,1))
);

CREATE TABLE event_type (
    event_type          TEXT PRIMARY KEY,
    meaning             TEXT NOT NULL,
    changes_custody     INTEGER NOT NULL DEFAULT 0 CHECK (changes_custody IN (0,1)),
    expected_role       TEXT CHECK (expected_role IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE','SYSTEM')),
    resulting_status    TEXT REFERENCES carton_status(status_code),
    request_requirement TEXT NOT NULL DEFAULT 'NONE',
    source_definition   TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(source_definition))
);

CREATE TABLE lifecycle_transition (
    from_status TEXT NOT NULL REFERENCES carton_status(status_code),
    event_type  TEXT NOT NULL REFERENCES event_type(event_type),
    to_status   TEXT NOT NULL REFERENCES carton_status(status_code),
    PRIMARY KEY (from_status, event_type)
);

-- IMPORT EVIDENCE ------------------------------------------------------------
CREATE TABLE import_batch (
    batch_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    source_name     TEXT NOT NULL,
    source_kind     TEXT NOT NULL CHECK (source_kind IN ('WORKBOOK','INVENTORY','INVOICE','CERTIFICATE')),
    vendor_id       TEXT REFERENCES vendor(vendor_id),
    sha256          TEXT NOT NULL CHECK (sha256 GLOB '[0-9a-f]*' AND length(sha256) = 64),
    uploaded_by     TEXT REFERENCES app_user(user_id),
    uploaded_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    source_timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    artifact_uri    TEXT
);
CREATE UNIQUE INDEX import_batch_uq
  ON import_batch (source_kind, COALESCE(vendor_id,'<NA>'), sha256);

CREATE TABLE import_row (
    row_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id   INTEGER NOT NULL REFERENCES import_batch(batch_id),
    sheet_name TEXT NOT NULL,
    row_number INTEGER NOT NULL CHECK (row_number > 0),
    raw_values TEXT NOT NULL CHECK (json_valid(raw_values)),
    UNIQUE (batch_id, sheet_name, row_number)
);

CREATE TABLE import_issue (
    issue_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    row_id      INTEGER NOT NULL REFERENCES import_row(row_id),
    code        TEXT NOT NULL,
    message     TEXT NOT NULL,
    disposition TEXT NOT NULL CHECK (disposition IN ('REJECTED','WARNING','DUPLICATE')),
    recorded_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE (row_id, code)
);

-- OPERATIONAL PROJECTIONS ----------------------------------------------------
CREATE TABLE carton (
    carton_id              TEXT PRIMARY KEY,
    entity_id              TEXT NOT NULL,
    department_id          TEXT NOT NULL,
    owner_user_id          TEXT NOT NULL REFERENCES app_user(user_id),
    document_type          TEXT NOT NULL REFERENCES document_type(document_type),
    archival_policy        TEXT NOT NULL REFERENCES archival_policy(archival_policy),
    carton_created_date    TEXT NOT NULL,
    retention_trigger_date TEXT,                       -- nullable; never invent
    declared_file_count    INTEGER CHECK (declared_file_count >= 0),
    assigned_vendor_id     TEXT NOT NULL REFERENCES vendor(vendor_id),
    barcode                TEXT,
    remarks                TEXT,
    source_row_id          INTEGER UNIQUE REFERENCES import_row(row_id),
    FOREIGN KEY (entity_id, department_id) REFERENCES department (entity_id, department_id),
    UNIQUE (carton_id, document_type)
);
CREATE INDEX carton_scope_idx   ON carton (entity_id, department_id);
CREATE INDEX carton_vendor_idx  ON carton (assigned_vendor_id);
CREATE INDEX carton_barcode_idx ON carton (barcode);

CREATE TABLE file_record (
    file_id          TEXT PRIMARY KEY,
    carton_id        TEXT NOT NULL,
    file_ref         TEXT NOT NULL,
    document_type    TEXT NOT NULL,
    file_description TEXT,
    document_year    INTEGER CHECK (document_year BETWEEN 1000 AND 9999),
    contains_pii     INTEGER NOT NULL DEFAULT 1 CHECK (contains_pii IN (0,1)),
    source_row_id    INTEGER UNIQUE REFERENCES import_row(row_id),
    FOREIGN KEY (carton_id, document_type) REFERENCES carton (carton_id, document_type)
);
CREATE INDEX file_carton_idx ON file_record (carton_id);

CREATE TABLE service_request (
    request_id      TEXT PRIMARY KEY,
    carton_id       TEXT NOT NULL REFERENCES carton(carton_id),
    request_type    TEXT NOT NULL CHECK (request_type IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION')),
    vendor_id       TEXT NOT NULL REFERENCES vendor(vendor_id),
    raised_by       TEXT NOT NULL REFERENCES app_user(user_id),
    raised_at       TEXT NOT NULL,
    request_status  TEXT NOT NULL CHECK (request_status IN ('Open','In Progress','Completed','Rejected','Cancelled')),
    destination     TEXT CHECK (destination IS NULL OR json_valid(destination)),
    vendor_ack_at   TEXT,
    completed_at    TEXT,
    approved_by     TEXT REFERENCES app_user(user_id),
    approved_at     TEXT,
    rejection_reason TEXT,
    sla_rule_id     INTEGER REFERENCES sla_rule(sla_rule_id),
    sla_snapshot    TEXT CHECK (sla_snapshot IS NULL OR json_valid(sla_snapshot)),
    sla_due_date    TEXT,
    source_row_id   INTEGER UNIQUE REFERENCES import_row(row_id),
    UNIQUE (carton_id, request_id),
    CHECK (approved_by IS NULL OR approved_by <> raised_by),
    CHECK ((approved_by IS NULL) = (approved_at IS NULL)),
    CHECK (request_type = 'DESTRUCTION' OR approved_by IS NULL),
    CHECK (vendor_ack_at IS NULL OR vendor_ack_at >= raised_at),
    CHECK (completed_at IS NULL OR completed_at >= raised_at),
    CHECK (approved_at IS NULL OR approved_at >= raised_at),
    CHECK (request_status <> 'Rejected' OR (rejection_reason IS NOT NULL AND trim(rejection_reason) <> ''))
);
CREATE INDEX request_vendor_queue_idx ON service_request (vendor_id, request_status, raised_at);
CREATE INDEX request_carton_idx       ON service_request (carton_id, raised_at);
CREATE INDEX request_raiser_idx       ON service_request (raised_by, request_status, raised_at);

-- ONE CANONICAL EVENT LOG ----------------------------------------------------
CREATE TABLE event_log (
    event_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    stream_kind      TEXT NOT NULL CHECK (stream_kind IN ('CARTON','REFERENCE','USER','CERTIFICATE','EXCEPTION','RECONCILIATION')),
    stream_id        TEXT NOT NULL,
    stream_version   INTEGER NOT NULL CHECK (stream_version > 0),
    carton_id        TEXT REFERENCES carton(carton_id),
    request_id       TEXT,
    event_type       TEXT NOT NULL REFERENCES event_type(event_type),
    occurred_at      TEXT NOT NULL,
    recorded_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    actor_user_id    TEXT REFERENCES app_user(user_id),
    actor_role       TEXT NOT NULL CHECK (actor_role IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE','SYSTEM')),
    actor_reference  TEXT,
    channel          TEXT NOT NULL CHECK (channel IN ('UI','API','UPLOAD','SCHEDULER','MIGRATION')),
    source_event_id  TEXT,
    source_row_id    INTEGER REFERENCES import_row(row_id),
    from_location_ref TEXT,
    to_location_ref  TEXT,
    resulting_status TEXT REFERENCES carton_status(status_code),  -- NULL = unchanged
    schema_version   INTEGER NOT NULL DEFAULT 1 CHECK (schema_version > 0),
    payload          TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(payload)),
    corrects_event_id INTEGER REFERENCES event_log(event_id),
    idempotency_key  TEXT NOT NULL UNIQUE,
    UNIQUE (stream_kind, stream_id, stream_version),
    UNIQUE (carton_id, event_id),
    CHECK ((stream_kind = 'CARTON' AND carton_id IS NOT NULL AND stream_id = carton_id)
       OR  (stream_kind <> 'CARTON' AND carton_id IS NULL AND request_id IS NULL)),
    CHECK (channel IN ('UPLOAD','MIGRATION','SCHEDULER') OR actor_user_id IS NOT NULL)
);
CREATE INDEX event_replay_idx ON event_log (carton_id, occurred_at, event_id);
CREATE INDEX event_request_idx ON event_log (request_id);
CREATE UNIQUE INDEX event_source_row_type_uq
  ON event_log (source_row_id, event_type) WHERE source_row_id IS NOT NULL;

CREATE TABLE carton_state (
    carton_id        TEXT PRIMARY KEY REFERENCES carton(carton_id),
    status_code      TEXT NOT NULL REFERENCES carton_status(status_code),
    custody          TEXT NOT NULL CHECK (custody IN ('BUSINESS','TRANSIT','WAREHOUSE','DESTROYED','UNKNOWN')),
    vendor_id        TEXT REFERENCES vendor(vendor_id),
    warehouse_id     TEXT,
    active_hold_count INTEGER NOT NULL DEFAULT 0 CHECK (active_hold_count >= 0),
    state_since      TEXT NOT NULL,
    last_event_id    INTEGER NOT NULL,
    version          INTEGER NOT NULL CHECK (version > 0),
    rebuilt_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    FOREIGN KEY (vendor_id, warehouse_id) REFERENCES warehouse (vendor_id, location_id),
    CHECK ((custody = 'WAREHOUSE' AND vendor_id IS NOT NULL AND warehouse_id IS NOT NULL)
       OR  (custody <> 'WAREHOUSE' AND warehouse_id IS NULL))
);
CREATE INDEX state_dashboard_idx ON carton_state (status_code, vendor_id, warehouse_id);

CREATE TABLE custody_interval (
    interval_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    carton_id      TEXT NOT NULL REFERENCES carton(carton_id),
    custody        TEXT NOT NULL CHECK (custody IN ('BUSINESS','TRANSIT','WAREHOUSE','DESTROYED','UNKNOWN')),
    vendor_id      TEXT,
    warehouse_id   TEXT,
    valid_from     TEXT NOT NULL,
    valid_to       TEXT,                    -- exclusive; NULL = currently open
    start_event_id INTEGER NOT NULL,
    end_event_id   INTEGER,
    CHECK (valid_to IS NULL OR valid_to > valid_from),
    CHECK ((valid_to IS NULL) = (end_event_id IS NULL))
    -- NON-OVERLAP per carton: enforced in services (one open interval at a time).
);
CREATE INDEX custody_billing_idx ON custody_interval (vendor_id, valid_from);

CREATE TABLE legal_hold (
    hold_id           TEXT PRIMARY KEY,
    carton_id         TEXT NOT NULL REFERENCES carton(carton_id),
    matter_reference  TEXT NOT NULL,
    reason            TEXT NOT NULL,
    raised_by         TEXT REFERENCES app_user(user_id),
    starts_at         TEXT NOT NULL,
    start_precision   TEXT NOT NULL DEFAULT 'TIMESTAMP' CHECK (start_precision IN ('DATE','TIMESTAMP')),
    applied_event_id  INTEGER NOT NULL,
    released_at       TEXT,
    release_precision TEXT CHECK (release_precision IN ('DATE','TIMESTAMP')),
    released_by       TEXT REFERENCES app_user(user_id),
    release_reason    TEXT,
    released_event_id INTEGER,
    source_row_id     INTEGER UNIQUE REFERENCES import_row(row_id),
    CHECK (released_at IS NULL OR released_at >= starts_at),
    CHECK ((released_at IS NULL AND released_event_id IS NULL AND release_precision IS NULL)
        OR (released_at IS NOT NULL AND released_event_id IS NOT NULL AND release_precision IS NOT NULL))
);
CREATE INDEX hold_active_idx ON legal_hold (carton_id, starts_at) WHERE released_at IS NULL;

-- VENDOR EVIDENCE (not operational master data) ------------------------------
CREATE TABLE vendor_declaration (
    declaration_id INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id       INTEGER NOT NULL REFERENCES import_batch(batch_id),
    vendor_id      TEXT NOT NULL REFERENCES vendor(vendor_id),
    cycle          TEXT NOT NULL,
    declared_at    TEXT NOT NULL,
    UNIQUE (batch_id, vendor_id, cycle, declared_at)
);

CREATE TABLE vendor_declaration_item (
    declaration_item_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    declaration_id             INTEGER NOT NULL REFERENCES vendor_declaration(declaration_id),
    carton_reference           TEXT NOT NULL,     -- intentionally NO carton FK
    declared_location_reference TEXT,
    declared_status            TEXT,
    vendor_notes               TEXT,
    facility_notes_as_received TEXT,
    source_row_id              INTEGER NOT NULL UNIQUE REFERENCES import_row(row_id)
);
CREATE INDEX declaration_lookup_idx ON vendor_declaration_item (declaration_id, carton_reference);

CREATE TABLE vendor_invoice (
    invoice_record_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_reference   TEXT NOT NULL,
    vendor_id           TEXT NOT NULL REFERENCES vendor(vendor_id),
    billing_month       TEXT NOT NULL CHECK (substr(billing_month,9,2) = '01'),
    invoice_date        TEXT,
    currency            TEXT NOT NULL,
    declared_line_count INTEGER,
    declared_subtotal   TEXT,
    declared_tax_rate   TEXT,
    declared_tax_amount TEXT,
    declared_total      TEXT,
    declared_status     TEXT,
    source_row_id       INTEGER NOT NULL UNIQUE REFERENCES import_row(row_id)
);
CREATE INDEX invoice_period_idx ON vendor_invoice (vendor_id, billing_month);

CREATE TABLE vendor_invoice_line (
    invoice_line_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_record_id  INTEGER REFERENCES vendor_invoice(invoice_record_id),
    invoice_reference  TEXT NOT NULL,
    line_number        INTEGER,
    line_type          TEXT,
    activity_reference TEXT,
    carton_reference   TEXT,
    request_reference  TEXT,
    quantity           TEXT,
    unit_rate          TEXT,
    line_amount        TEXT,
    service_period_raw TEXT,
    service_month      TEXT CHECK (service_month IS NULL OR substr(service_month,9,2) = '01'),
    source_row_id      INTEGER NOT NULL UNIQUE REFERENCES import_row(row_id)
);
CREATE INDEX invoice_line_header_idx  ON vendor_invoice_line (invoice_record_id);
CREATE INDEX invoice_line_request_idx ON vendor_invoice_line (request_reference);

CREATE TABLE certificate_evidence (
    certificate_row_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    certificate_reference          TEXT NOT NULL,
    carton_reference               TEXT NOT NULL,     -- deliberately no FK
    vendor_reference               TEXT NOT NULL,
    destroyed_on                   TEXT,
    destruction_location_reference TEXT,
    destruction_method             TEXT,
    witnessed_by_reference         TEXT,
    issued_on                      TEXT,
    source_row_id                  INTEGER UNIQUE REFERENCES import_row(row_id),
    evidence_event_id              INTEGER REFERENCES event_log(event_id),
    recorded_at                    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    CHECK (source_row_id IS NOT NULL OR evidence_event_id IS NOT NULL)
);
CREATE INDEX certificate_batch_idx  ON certificate_evidence (certificate_reference, vendor_reference, destroyed_on);
CREATE INDEX certificate_carton_idx ON certificate_evidence (carton_reference);

-- RECONCILIATION / EXCEPTIONS ------------------------------------------------
CREATE TABLE reconciliation_run (
    run_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    run_kind          TEXT NOT NULL CHECK (run_kind IN ('INVENTORY','INVOICE','CERTIFICATE','DATA_QUALITY')),
    scope_key         TEXT NOT NULL,
    input_fingerprint TEXT NOT NULL,
    parameters        TEXT NOT NULL CHECK (json_valid(parameters)),
    rule_snapshot     TEXT NOT NULL CHECK (json_valid(rule_snapshot)),
    engine_version    TEXT NOT NULL,
    requested_by      TEXT NOT NULL REFERENCES app_user(user_id),
    started_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    finished_at       TEXT,
    status            TEXT NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
    counts            TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(counts)),
    error_summary     TEXT,
    UNIQUE (run_kind, scope_key, input_fingerprint),
    CHECK (finished_at IS NULL OR finished_at >= started_at)
);

CREATE TABLE expected_charge (
    expected_charge_id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id             INTEGER NOT NULL REFERENCES reconciliation_run(run_id),
    charge_key         TEXT NOT NULL,
    carton_id          TEXT NOT NULL REFERENCES carton(carton_id),
    vendor_id          TEXT NOT NULL REFERENCES vendor(vendor_id),
    department_id      TEXT NOT NULL REFERENCES department(department_id),
    service_month      TEXT NOT NULL CHECK (substr(service_month,9,2) = '01'),
    activity           TEXT NOT NULL CHECK (activity IN ('PICKUP','RETRIEVAL','RETURN','DESTRUCTION','STORAGE')),
    request_id         TEXT REFERENCES service_request(request_id),
    source_event_id    INTEGER REFERENCES event_log(event_id),
    rate_id            INTEGER REFERENCES vendor_rate(rate_id),
    quantity           TEXT NOT NULL,
    applied_rate       TEXT,
    net_amount         TEXT,
    calculation_status TEXT NOT NULL CHECK (calculation_status IN ('CALCULATED','MISSING_RATE','INCOMPLETE_EVIDENCE')),
    basis              TEXT NOT NULL CHECK (json_valid(basis)),
    UNIQUE (run_id, charge_key),
    CHECK (calculation_status <> 'CALCULATED' OR (rate_id IS NOT NULL AND applied_rate IS NOT NULL AND net_amount IS NOT NULL))
);
CREATE INDEX expected_charge_period_idx ON expected_charge (vendor_id, service_month);

CREATE TABLE exception_case (
    exception_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    stable_key          TEXT NOT NULL UNIQUE,
    exception_type      TEXT NOT NULL,
    severity            TEXT NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    owner_role          TEXT NOT NULL CHECK (owner_role IN ('BUSINESS','FACILITIES','VENDOR','COMPLIANCE')),
    owner_user_id       TEXT REFERENCES app_user(user_id),
    owner_vendor_id     TEXT REFERENCES vendor(vendor_id),
    carton_id           TEXT REFERENCES carton(carton_id),
    subject_reference   TEXT NOT NULL,
    visibility          TEXT NOT NULL DEFAULT 'FACILITIES' CHECK (visibility IN ('FACILITIES','COMPLIANCE','BUSINESS_SCOPED','VENDOR_REDACTED')),
    first_detected_at   TEXT NOT NULL,
    last_detected_at    TEXT NOT NULL,
    first_observed_as_of TEXT NOT NULL,
    last_observed_as_of  TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','INVESTIGATING','RESOLVED','ACCEPTED_RISK')),
    resolution_reason   TEXT,
    resolved_by         TEXT REFERENCES app_user(user_id),
    resolved_at         TEXT,
    due_at              TEXT,
    CHECK (last_detected_at >= first_detected_at),
    CHECK (last_observed_as_of >= first_observed_as_of),
    CHECK (status NOT IN ('RESOLVED','ACCEPTED_RISK')
        OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL AND resolution_reason IS NOT NULL AND trim(resolution_reason) <> ''))
);
CREATE INDEX exception_queue_idx   ON exception_case (status, owner_role, severity);
CREATE INDEX exception_carton_idx  ON exception_case (carton_id);
CREATE INDEX exception_vendor_idx  ON exception_case (owner_vendor_id, status);

CREATE TABLE reconciliation_finding (
    finding_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id         INTEGER NOT NULL REFERENCES reconciliation_run(run_id),
    exception_id   INTEGER NOT NULL REFERENCES exception_case(exception_id),
    finding_key    TEXT NOT NULL,
    observed_as_of TEXT NOT NULL,
    rule_code      TEXT NOT NULL,
    rule_revision  TEXT NOT NULL,
    evidence       TEXT NOT NULL CHECK (json_valid(evidence)),
    UNIQUE (run_id, finding_key)
);
CREATE INDEX finding_exception_idx ON reconciliation_finding (exception_id);

CREATE TABLE alert (
    alert_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    carton_id         TEXT NOT NULL REFERENCES carton(carton_id),
    alert_type        TEXT NOT NULL,
    dedupe_key        TEXT NOT NULL UNIQUE,
    owner_user_id     TEXT REFERENCES app_user(user_id),
    due_on            TEXT,
    state             TEXT NOT NULL DEFAULT 'OPEN' CHECK (state IN ('OPEN','ACKNOWLEDGED','RESOLVED','SUPERSEDED')),
    basis             TEXT NOT NULL CHECK (json_valid(basis)),
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    last_evaluated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    resolved_at       TEXT
);
CREATE INDEX alert_owner_idx ON alert (owner_user_id, state);
CREATE INDEX alert_due_idx   ON alert (state, due_on);

-- APPEND-ONLY PROTECTION (mirrors Postgres protect_evidence trigger) ---------
-- Evidence tables reject UPDATE/DELETE; corrections are appended as new rows.
CREATE TRIGGER protect_event_log_upd BEFORE UPDATE ON event_log
  BEGIN SELECT RAISE(ABORT, 'append-only: event_log cannot be updated'); END;
CREATE TRIGGER protect_event_log_del BEFORE DELETE ON event_log
  BEGIN SELECT RAISE(ABORT, 'append-only: event_log cannot be deleted'); END;
CREATE TRIGGER protect_import_row_upd BEFORE UPDATE ON import_row
  BEGIN SELECT RAISE(ABORT, 'append-only: import_row cannot be updated'); END;
CREATE TRIGGER protect_import_row_del BEFORE DELETE ON import_row
  BEGIN SELECT RAISE(ABORT, 'append-only: import_row cannot be deleted'); END;
CREATE TRIGGER protect_cert_upd BEFORE UPDATE ON certificate_evidence
  BEGIN SELECT RAISE(ABORT, 'append-only: certificate_evidence cannot be updated'); END;
CREATE TRIGGER protect_cert_del BEFORE DELETE ON certificate_evidence
  BEGIN SELECT RAISE(ABORT, 'append-only: certificate_evidence cannot be deleted'); END;
CREATE TRIGGER protect_finding_upd BEFORE UPDATE ON reconciliation_finding
  BEGIN SELECT RAISE(ABORT, 'append-only: reconciliation_finding cannot be updated'); END;
CREATE TRIGGER protect_finding_del BEFORE DELETE ON reconciliation_finding
  BEGIN SELECT RAISE(ABORT, 'append-only: reconciliation_finding cannot be deleted'); END;

-- RETENTION as a VIEW (never a stored due date). SQLite date math via date().
CREATE VIEW carton_retention AS
SELECT c.carton_id, c.entity_id, c.department_id, c.retention_trigger_date,
       p.policy_id, p.policy_revision, p.retention_years,
       CASE WHEN c.retention_trigger_date IS NOT NULL AND p.policy_id IS NOT NULL
            THEN date(c.retention_trigger_date, '+' || p.retention_years || ' years')
       END AS destruction_due_on,
       CASE WHEN c.retention_trigger_date IS NULL THEN 'MISSING_TRIGGER'
            WHEN p.policy_id IS NULL THEN 'MISSING_POLICY'
            ELSE 'CALCULATED' END AS calculation_status
FROM carton c
LEFT JOIN (
  -- choose entity-specific policy over global default (ordered pick per carton)
  SELECT rp.policy_id, rp.revision AS policy_revision, rp.retention_years,
         rp.document_type, rp.archival_policy, rp.entity_id
  FROM retention_policy rp
) p
  ON p.document_type = c.document_type
 AND p.archival_policy = c.archival_policy
 AND (p.entity_id = c.entity_id OR p.entity_id IS NULL)
 AND p.policy_id = (
    SELECT rp2.policy_id FROM retention_policy rp2
    WHERE rp2.document_type = c.document_type
      AND rp2.archival_policy = c.archival_policy
      AND (rp2.entity_id = c.entity_id OR rp2.entity_id IS NULL)
    ORDER BY (rp2.entity_id IS NOT NULL) DESC
    LIMIT 1
 );
