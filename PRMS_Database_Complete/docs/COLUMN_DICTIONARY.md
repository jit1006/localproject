# PRMS column dictionary

Generated from `01_schema.sql`. SQL is authoritative for composite constraints, indexes and trigger behavior.

## business_entity

| Column | PostgreSQL definition |
|---|---|
| `entity_id` | `entity_id text PRIMARY KEY` |
| `entity_name` | `entity_name text NOT NULL UNIQUE` |

## department

| Column | PostgreSQL definition |
|---|---|
| `department_id` | `department_id text PRIMARY KEY` |
| `entity_id` | `entity_id text NOT NULL REFERENCES business_entity` |
| `department_name` | `department_name text NOT NULL` |

## vendor

| Column | PostgreSQL definition |
|---|---|
| `vendor_id` | `vendor_id text PRIMARY KEY` |
| `vendor_name` | `vendor_name text NOT NULL` |
| `status` | `status text NOT NULL CHECK (status IN ('Active', 'Terminated'))` |
| `contract_start` | `contract_start date` |
| `contract_ref` | `contract_ref text` |
| `ops_contact_email` | `ops_contact_email text` |
| `recertification_frequency` | `recertification_frequency text NOT NULL DEFAULT 'Quarterly'` |

## warehouse

| Column | PostgreSQL definition |
|---|---|
| `location_id` | `location_id text PRIMARY KEY` |
| `vendor_id` | `vendor_id text NOT NULL REFERENCES vendor` |
| `location_name` | `location_name text NOT NULL` |
| `city` | `city text NOT NULL` |
| `capacity_cartons` | `capacity_cartons integer CHECK (capacity_cartons >= 0)` |

## app_user

| Column | PostgreSQL definition |
|---|---|
| `user_id` | `user_id text PRIMARY KEY` |
| `full_name` | `full_name text NOT NULL` |
| `email` | `email text NOT NULL` |
| `role_code` | `role_code text NOT NULL CHECK (role_code IN ('BUSINESS', 'FACILITIES', 'VENDOR', 'COMPLIANCE'))` |
| `entity_id` | `entity_id text REFERENCES business_entity` |
| `department_id` | `department_id text` |
| `vendor_id` | `vendor_id text REFERENCES vendor` |
| `password_hash` | `password_hash text` |
| `is_active` | `is_active boolean NOT NULL DEFAULT TRUE` |
| `created_at` | `created_at timestamptz NOT NULL DEFAULT now()` |

## user_session

| Column | PostgreSQL definition |
|---|---|
| `token_hash` | `token_hash text PRIMARY KEY` |
| `user_id` | `user_id text NOT NULL REFERENCES app_user` |
| `created_at` | `created_at timestamptz NOT NULL DEFAULT now()` |
| `expires_at` | `expires_at timestamptz NOT NULL` |
| `revoked_at` | `revoked_at timestamptz` |

## document_type

| Column | PostgreSQL definition |
|---|---|
| `document_type` | `document_type text PRIMARY KEY` |
| `base_retention_years` | `base_retention_years integer NOT NULL CHECK (base_retention_years >= 0)` |
| `trigger_event_description` | `trigger_event_description text NOT NULL` |

## archival_policy

| Column | PostgreSQL definition |
|---|---|
| `archival_policy` | `archival_policy text PRIMARY KEY` |

## retention_policy

| Column | PostgreSQL definition |
|---|---|
| `policy_id` | `policy_id text PRIMARY KEY` |
| `entity_id` | `entity_id text REFERENCES business_entity` |
| `document_type` | `document_type text NOT NULL REFERENCES document_type` |
| `archival_policy` | `archival_policy text NOT NULL REFERENCES archival_policy` |
| `retention_years` | `retention_years integer NOT NULL CHECK (retention_years BETWEEN 0 AND 999)` |
| `revision` | `revision integer NOT NULL DEFAULT 1 CHECK (revision > 0)` |
| `updated_at` | `updated_at timestamptz NOT NULL DEFAULT now()` |

## vendor_rate

| Column | PostgreSQL definition |
|---|---|
| `rate_id` | `rate_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `vendor_id` | `vendor_id text NOT NULL REFERENCES vendor` |
| `activity` | `activity text NOT NULL CHECK (activity IN ('PICKUP', 'RETRIEVAL', 'RETURN', 'DESTRUCTION', 'STORAGE'))` |
| `rate_inr` | `rate_inr numeric(14, 2) NOT NULL CHECK (rate_inr >= 0)` |
| `unit` | `unit text NOT NULL CHECK (unit IN ('PER_CARTON', 'PER_CARTON_MONTH'))` |
| `effective_from` | `effective_from date NOT NULL` |
| `effective_to` | `effective_to date` |

## sla_rule

| Column | PostgreSQL definition |
|---|---|
| `sla_rule_id` | `sla_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `vendor_id` | `vendor_id text REFERENCES vendor` |
| `activity` | `activity text NOT NULL CHECK (activity IN ('PICKUP', 'RETRIEVAL', 'RETURN', 'DESTRUCTION'))` |
| `business_days` | `business_days integer NOT NULL CHECK (business_days >= 0)` |
| `starts_on` | `starts_on text NOT NULL CHECK (starts_on IN ('REQUEST_SUBMITTED', 'DESTRUCTION_APPROVED'))` |
| `ends_on` | `ends_on text NOT NULL CHECK (ends_on IN ('WAREHOUSE_RECEIPT', 'BUSINESS_DELIVERY', 'DESTRUCTION_EXECUTED', 'CERTIFICATE_ISSUED'))` |
| `definition` | `definition text NOT NULL` |
| `revision` | `revision integer NOT NULL DEFAULT 1 CHECK (revision > 0)` |

## holiday

| Column | PostgreSQL definition |
|---|---|
| `holiday_date` | `holiday_date date PRIMARY KEY` |
| `holiday_name` | `holiday_name text NOT NULL` |

## threshold_rule

| Column | PostgreSQL definition |
|---|---|
| `threshold_id` | `threshold_id text PRIMARY KEY` |
| `applies_to` | `applies_to text NOT NULL` |
| `threshold_days` | `threshold_days integer NOT NULL CHECK (threshold_days >= 0)` |
| `day_basis` | `day_basis text NOT NULL CHECK (day_basis IN ('CALENDAR', 'BUSINESS'))` |
| `meaning` | `meaning text NOT NULL` |

## tax_rule

| Column | PostgreSQL definition |
|---|---|
| `tax_rule_id` | `tax_rule_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `tax_code` | `tax_code text NOT NULL` |
| `rate_percent` | `rate_percent numeric(5, 2) NOT NULL CHECK (rate_percent BETWEEN 0 AND 100)` |
| `effective_from` | `effective_from date NOT NULL` |
| `effective_to` | `effective_to date` |

## carton_status

| Column | PostgreSQL definition |
|---|---|
| `status_code` | `status_code text PRIMARY KEY` |
| `meaning` | `meaning text NOT NULL` |
| `is_terminal` | `is_terminal boolean NOT NULL DEFAULT FALSE` |

## event_type

| Column | PostgreSQL definition |
|---|---|
| `event_type` | `event_type text PRIMARY KEY` |
| `meaning` | `meaning text NOT NULL` |
| `changes_custody` | `changes_custody boolean NOT NULL DEFAULT FALSE` |
| `expected_role` | `expected_role text CHECK (expected_role IN ('BUSINESS', 'FACILITIES', 'VENDOR', 'COMPLIANCE', 'SYSTEM'))` |
| `resulting_status` | `resulting_status text REFERENCES carton_status` |
| `request_requirement` | `request_requirement text NOT NULL DEFAULT 'NONE'` |
| `source_definition` | `source_definition jsonb NOT NULL DEFAULT CAST('{}' AS jsonb)` |

## lifecycle_transition

| Column | PostgreSQL definition |
|---|---|
| `from_status` | `from_status text NOT NULL REFERENCES carton_status` |
| `event_type` | `event_type text NOT NULL REFERENCES event_type` |
| `to_status` | `to_status text NOT NULL REFERENCES carton_status` |

## import_batch

| Column | PostgreSQL definition |
|---|---|
| `batch_id` | `batch_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `source_name` | `source_name text NOT NULL` |
| `source_kind` | `source_kind text NOT NULL CHECK (source_kind IN ('WORKBOOK', 'INVENTORY', 'INVOICE', 'CERTIFICATE'))` |
| `vendor_id` | `vendor_id text REFERENCES vendor` |
| `sha256` | `sha256 text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$')` |
| `uploaded_by` | `uploaded_by text REFERENCES app_user` |
| `uploaded_at` | `uploaded_at timestamptz NOT NULL DEFAULT now()` |
| `source_timezone` | `source_timezone text NOT NULL DEFAULT 'Asia/Kolkata'` |
| `artifact_uri` | `artifact_uri text` |

## import_row

| Column | PostgreSQL definition |
|---|---|
| `row_id` | `row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `batch_id` | `batch_id bigint NOT NULL REFERENCES import_batch` |
| `sheet_name` | `sheet_name text NOT NULL` |
| `row_number` | `row_number integer NOT NULL CHECK (row_number > 0)` |
| `raw_values` | `raw_values jsonb NOT NULL` |

## import_issue

| Column | PostgreSQL definition |
|---|---|
| `issue_id` | `issue_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `row_id` | `row_id bigint NOT NULL REFERENCES import_row` |
| `code` | `code text NOT NULL` |
| `message` | `message text NOT NULL` |
| `disposition` | `disposition text NOT NULL CHECK (disposition IN ('REJECTED', 'WARNING', 'DUPLICATE'))` |
| `recorded_at` | `recorded_at timestamptz NOT NULL DEFAULT now()` |

## carton

| Column | PostgreSQL definition |
|---|---|
| `carton_id` | `carton_id text PRIMARY KEY` |
| `entity_id` | `entity_id text NOT NULL` |
| `department_id` | `department_id text NOT NULL` |
| `owner_user_id` | `owner_user_id text NOT NULL REFERENCES app_user` |
| `document_type` | `document_type text NOT NULL REFERENCES document_type` |
| `archival_policy` | `archival_policy text NOT NULL REFERENCES archival_policy` |
| `carton_created_date` | `carton_created_date date NOT NULL` |
| `retention_trigger_date` | `retention_trigger_date date` |
| `declared_file_count` | `declared_file_count integer CHECK (declared_file_count >= 0)` |
| `assigned_vendor_id` | `assigned_vendor_id text NOT NULL REFERENCES vendor` |
| `barcode` | `barcode text` |
| `remarks` | `remarks text` |
| `source_row_id` | `source_row_id bigint UNIQUE REFERENCES import_row` |

## file_record

| Column | PostgreSQL definition |
|---|---|
| `file_id` | `file_id text PRIMARY KEY` |
| `carton_id` | `carton_id text NOT NULL` |
| `file_ref` | `file_ref text NOT NULL` |
| `document_type` | `document_type text NOT NULL` |
| `file_description` | `file_description text` |
| `document_year` | `document_year integer CHECK (document_year BETWEEN 1000 AND 9999)` |
| `contains_pii` | `contains_pii boolean NOT NULL DEFAULT TRUE` |
| `source_row_id` | `source_row_id bigint UNIQUE REFERENCES import_row` |

## service_request

| Column | PostgreSQL definition |
|---|---|
| `request_id` | `request_id text PRIMARY KEY` |
| `carton_id` | `carton_id text NOT NULL REFERENCES carton` |
| `request_type` | `request_type text NOT NULL CHECK (request_type IN ('PICKUP', 'RETRIEVAL', 'RETURN', 'DESTRUCTION'))` |
| `vendor_id` | `vendor_id text NOT NULL REFERENCES vendor` |
| `raised_by` | `raised_by text NOT NULL REFERENCES app_user` |
| `raised_at` | `raised_at timestamptz NOT NULL` |
| `request_status` | `request_status text NOT NULL CHECK (request_status IN ('Open', 'In Progress', 'Completed', 'Rejected', 'Cancelled'))` |
| `destination` | `destination jsonb` |
| `vendor_ack_at` | `vendor_ack_at timestamptz` |
| `completed_at` | `completed_at timestamptz` |
| `approved_by` | `approved_by text REFERENCES app_user` |
| `approved_at` | `approved_at timestamptz` |
| `rejection_reason` | `rejection_reason text` |
| `sla_rule_id` | `sla_rule_id bigint REFERENCES sla_rule` |
| `sla_snapshot` | `sla_snapshot jsonb` |
| `sla_due_date` | `sla_due_date date` |
| `source_row_id` | `source_row_id bigint UNIQUE REFERENCES import_row` |

## event_log

| Column | PostgreSQL definition |
|---|---|
| `event_id` | `event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `stream_kind` | `stream_kind text NOT NULL CHECK (stream_kind IN ('CARTON', 'REFERENCE', 'USER', 'CERTIFICATE', 'EXCEPTION', 'RECONCILIATION'))` |
| `stream_id` | `stream_id text NOT NULL` |
| `stream_version` | `stream_version bigint NOT NULL CHECK (stream_version > 0)` |
| `carton_id` | `carton_id text REFERENCES carton` |
| `request_id` | `request_id text` |
| `event_type` | `event_type text NOT NULL REFERENCES event_type` |
| `occurred_at` | `occurred_at timestamptz NOT NULL` |
| `recorded_at` | `recorded_at timestamptz NOT NULL DEFAULT now()` |
| `actor_user_id` | `actor_user_id text REFERENCES app_user` |
| `actor_role` | `actor_role text NOT NULL CHECK (actor_role IN ('BUSINESS', 'FACILITIES', 'VENDOR', 'COMPLIANCE', 'SYSTEM'))` |
| `actor_reference` | `actor_reference text` |
| `channel` | `channel text NOT NULL CHECK (channel IN ('UI', 'API', 'UPLOAD', 'SCHEDULER', 'MIGRATION'))` |
| `source_event_id` | `source_event_id text` |
| `source_row_id` | `source_row_id bigint REFERENCES import_row` |
| `from_location_ref` | `from_location_ref text` |
| `to_location_ref` | `to_location_ref text` |
| `resulting_status` | `resulting_status text REFERENCES carton_status` |
| `schema_version` | `schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0)` |
| `payload` | `payload jsonb NOT NULL DEFAULT CAST('{}' AS jsonb)` |
| `corrects_event_id` | `corrects_event_id bigint REFERENCES event_log` |
| `idempotency_key` | `idempotency_key text NOT NULL UNIQUE` |

## carton_state

| Column | PostgreSQL definition |
|---|---|
| `carton_id` | `carton_id text PRIMARY KEY REFERENCES carton` |
| `status_code` | `status_code text NOT NULL REFERENCES carton_status` |
| `custody` | `custody text NOT NULL CHECK (custody IN ('BUSINESS', 'TRANSIT', 'WAREHOUSE', 'DESTROYED', 'UNKNOWN'))` |
| `vendor_id` | `vendor_id text REFERENCES vendor` |
| `warehouse_id` | `warehouse_id text` |
| `active_hold_count` | `active_hold_count integer NOT NULL DEFAULT 0 CHECK (active_hold_count >= 0)` |
| `state_since` | `state_since timestamptz NOT NULL` |
| `last_event_id` | `last_event_id bigint NOT NULL` |
| `version` | `version bigint NOT NULL CHECK (version > 0)` |
| `rebuilt_at` | `rebuilt_at timestamptz NOT NULL DEFAULT now()` |

## custody_interval

| Column | PostgreSQL definition |
|---|---|
| `interval_id` | `interval_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `carton_id` | `carton_id text NOT NULL REFERENCES carton` |
| `custody` | `custody text NOT NULL CHECK (custody IN ('BUSINESS', 'TRANSIT', 'WAREHOUSE', 'DESTROYED', 'UNKNOWN'))` |
| `vendor_id` | `vendor_id text REFERENCES vendor` |
| `warehouse_id` | `warehouse_id text` |
| `valid_from` | `valid_from timestamptz NOT NULL` |
| `valid_to` | `valid_to timestamptz` |
| `start_event_id` | `start_event_id bigint NOT NULL` |
| `end_event_id` | `end_event_id bigint` |

## legal_hold

| Column | PostgreSQL definition |
|---|---|
| `hold_id` | `hold_id text PRIMARY KEY` |
| `carton_id` | `carton_id text NOT NULL REFERENCES carton` |
| `matter_reference` | `matter_reference text NOT NULL` |
| `reason` | `reason text NOT NULL` |
| `raised_by` | `raised_by text REFERENCES app_user` |
| `starts_at` | `starts_at timestamptz NOT NULL` |
| `start_precision` | `start_precision text NOT NULL DEFAULT 'TIMESTAMP' CHECK (start_precision IN ('DATE', 'TIMESTAMP'))` |
| `applied_event_id` | `applied_event_id bigint NOT NULL` |
| `released_at` | `released_at timestamptz` |
| `release_precision` | `release_precision text CHECK (release_precision IN ('DATE', 'TIMESTAMP'))` |
| `released_by` | `released_by text REFERENCES app_user` |
| `release_reason` | `release_reason text` |
| `released_event_id` | `released_event_id bigint` |
| `source_row_id` | `source_row_id bigint UNIQUE REFERENCES import_row` |

## vendor_declaration

| Column | PostgreSQL definition |
|---|---|
| `declaration_id` | `declaration_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `batch_id` | `batch_id bigint NOT NULL REFERENCES import_batch` |
| `vendor_id` | `vendor_id text NOT NULL REFERENCES vendor` |
| `cycle` | `cycle text NOT NULL` |
| `declared_at` | `declared_at timestamptz NOT NULL` |

## vendor_declaration_item

| Column | PostgreSQL definition |
|---|---|
| `declaration_item_id` | `declaration_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `declaration_id` | `declaration_id bigint NOT NULL REFERENCES vendor_declaration` |
| `carton_reference` | `carton_reference text NOT NULL` |
| `declared_location_reference` | `declared_location_reference text` |
| `declared_status` | `declared_status text` |
| `vendor_notes` | `vendor_notes text` |
| `facility_notes_as_received` | `facility_notes_as_received text` |
| `source_row_id` | `source_row_id bigint NOT NULL UNIQUE REFERENCES import_row` |

## vendor_invoice

| Column | PostgreSQL definition |
|---|---|
| `invoice_record_id` | `invoice_record_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `invoice_reference` | `invoice_reference text NOT NULL` |
| `vendor_id` | `vendor_id text NOT NULL REFERENCES vendor` |
| `billing_month` | `billing_month date NOT NULL CHECK (EXTRACT(DAY FROM billing_month) = 1)` |
| `invoice_date` | `invoice_date date` |
| `currency` | `currency text NOT NULL` |
| `declared_line_count` | `declared_line_count integer` |
| `declared_subtotal` | `declared_subtotal numeric(18, 2)` |
| `declared_tax_rate` | `declared_tax_rate numeric(7, 3)` |
| `declared_tax_amount` | `declared_tax_amount numeric(18, 2)` |
| `declared_total` | `declared_total numeric(18, 2)` |
| `declared_status` | `declared_status text` |
| `source_row_id` | `source_row_id bigint NOT NULL UNIQUE REFERENCES import_row` |

## vendor_invoice_line

| Column | PostgreSQL definition |
|---|---|
| `invoice_line_id` | `invoice_line_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `invoice_record_id` | `invoice_record_id bigint REFERENCES vendor_invoice` |
| `invoice_reference` | `invoice_reference text NOT NULL` |
| `line_number` | `line_number integer` |
| `line_type` | `line_type text` |
| `activity_reference` | `activity_reference text` |
| `carton_reference` | `carton_reference text` |
| `request_reference` | `request_reference text` |
| `quantity` | `quantity numeric(18, 4)` |
| `unit_rate` | `unit_rate numeric(18, 4)` |
| `line_amount` | `line_amount numeric(18, 2)` |
| `service_period_raw` | `service_period_raw text` |
| `service_month` | `service_month date CHECK (service_month IS NULL OR EXTRACT(DAY FROM service_month) = 1)` |
| `source_row_id` | `source_row_id bigint NOT NULL UNIQUE REFERENCES import_row` |

## certificate_evidence

| Column | PostgreSQL definition |
|---|---|
| `certificate_row_id` | `certificate_row_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `certificate_reference` | `certificate_reference text NOT NULL` |
| `carton_reference` | `carton_reference text NOT NULL` |
| `vendor_reference` | `vendor_reference text NOT NULL` |
| `destroyed_on` | `destroyed_on date` |
| `destruction_location_reference` | `destruction_location_reference text` |
| `destruction_method` | `destruction_method text` |
| `witnessed_by_reference` | `witnessed_by_reference text` |
| `issued_on` | `issued_on date` |
| `source_row_id` | `source_row_id bigint UNIQUE REFERENCES import_row` |
| `evidence_event_id` | `evidence_event_id bigint REFERENCES event_log` |
| `recorded_at` | `recorded_at timestamptz NOT NULL DEFAULT now()` |

## reconciliation_run

| Column | PostgreSQL definition |
|---|---|
| `run_id` | `run_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `run_kind` | `run_kind text NOT NULL CHECK (run_kind IN ('INVENTORY', 'INVOICE', 'CERTIFICATE', 'DATA_QUALITY'))` |
| `scope_key` | `scope_key text NOT NULL` |
| `input_fingerprint` | `input_fingerprint text NOT NULL` |
| `parameters` | `parameters jsonb NOT NULL` |
| `rule_snapshot` | `rule_snapshot jsonb NOT NULL` |
| `engine_version` | `engine_version text NOT NULL` |
| `requested_by` | `requested_by text NOT NULL REFERENCES app_user` |
| `started_at` | `started_at timestamptz NOT NULL DEFAULT now()` |
| `finished_at` | `finished_at timestamptz` |
| `status` | `status text NOT NULL DEFAULT 'RUNNING' CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED'))` |
| `counts` | `counts jsonb NOT NULL DEFAULT CAST('{}' AS jsonb)` |
| `error_summary` | `error_summary text` |

## expected_charge

| Column | PostgreSQL definition |
|---|---|
| `expected_charge_id` | `expected_charge_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `run_id` | `run_id bigint NOT NULL REFERENCES reconciliation_run` |
| `charge_key` | `charge_key text NOT NULL` |
| `carton_id` | `carton_id text NOT NULL REFERENCES carton` |
| `vendor_id` | `vendor_id text NOT NULL REFERENCES vendor` |
| `department_id` | `department_id text NOT NULL REFERENCES department` |
| `service_month` | `service_month date NOT NULL CHECK (EXTRACT(DAY FROM service_month) = 1)` |
| `activity` | `activity text NOT NULL CHECK (activity IN ('PICKUP', 'RETRIEVAL', 'RETURN', 'DESTRUCTION', 'STORAGE'))` |
| `request_id` | `request_id text REFERENCES service_request` |
| `source_event_id` | `source_event_id bigint REFERENCES event_log` |
| `rate_id` | `rate_id bigint REFERENCES vendor_rate` |
| `quantity` | `quantity numeric(18, 4) NOT NULL CHECK (quantity >= 0)` |
| `applied_rate` | `applied_rate numeric(18, 4)` |
| `net_amount` | `net_amount numeric(18, 2)` |
| `calculation_status` | `calculation_status text NOT NULL CHECK (calculation_status IN ('CALCULATED', 'MISSING_RATE', 'INCOMPLETE_EVIDENCE'))` |
| `basis` | `basis jsonb NOT NULL` |

## exception_case

| Column | PostgreSQL definition |
|---|---|
| `exception_id` | `exception_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `stable_key` | `stable_key text NOT NULL UNIQUE` |
| `exception_type` | `exception_type text NOT NULL` |
| `severity` | `severity text NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))` |
| `owner_role` | `owner_role text NOT NULL CHECK (owner_role IN ('BUSINESS', 'FACILITIES', 'VENDOR', 'COMPLIANCE'))` |
| `owner_user_id` | `owner_user_id text REFERENCES app_user` |
| `owner_vendor_id` | `owner_vendor_id text REFERENCES vendor` |
| `carton_id` | `carton_id text REFERENCES carton` |
| `subject_reference` | `subject_reference text NOT NULL` |
| `visibility` | `visibility text NOT NULL DEFAULT 'FACILITIES' CHECK (visibility IN ('FACILITIES', 'COMPLIANCE', 'BUSINESS_SCOPED', 'VENDOR_REDACTED'))` |
| `first_detected_at` | `first_detected_at timestamptz NOT NULL` |
| `last_detected_at` | `last_detected_at timestamptz NOT NULL` |
| `first_observed_as_of` | `first_observed_as_of timestamptz NOT NULL` |
| `last_observed_as_of` | `last_observed_as_of timestamptz NOT NULL` |
| `status` | `status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'INVESTIGATING', 'RESOLVED', 'ACCEPTED_RISK'))` |
| `resolution_reason` | `resolution_reason text` |
| `resolved_by` | `resolved_by text REFERENCES app_user` |
| `resolved_at` | `resolved_at timestamptz` |
| `due_at` | `due_at timestamptz` |

## reconciliation_finding

| Column | PostgreSQL definition |
|---|---|
| `finding_id` | `finding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `run_id` | `run_id bigint NOT NULL REFERENCES reconciliation_run` |
| `exception_id` | `exception_id bigint NOT NULL REFERENCES exception_case` |
| `finding_key` | `finding_key text NOT NULL` |
| `observed_as_of` | `observed_as_of timestamptz NOT NULL` |
| `rule_code` | `rule_code text NOT NULL` |
| `rule_revision` | `rule_revision text NOT NULL` |
| `evidence` | `evidence jsonb NOT NULL` |

## alert

| Column | PostgreSQL definition |
|---|---|
| `alert_id` | `alert_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |
| `carton_id` | `carton_id text NOT NULL REFERENCES carton` |
| `alert_type` | `alert_type text NOT NULL` |
| `dedupe_key` | `dedupe_key text NOT NULL UNIQUE` |
| `owner_user_id` | `owner_user_id text REFERENCES app_user` |
| `due_on` | `due_on date` |
| `state` | `state text NOT NULL DEFAULT 'OPEN' CHECK (state IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED', 'SUPERSEDED'))` |
| `basis` | `basis jsonb NOT NULL` |
| `created_at` | `created_at timestamptz NOT NULL DEFAULT now()` |
| `last_evaluated_at` | `last_evaluated_at timestamptz NOT NULL DEFAULT now()` |
| `resolved_at` | `resolved_at timestamptz` |
