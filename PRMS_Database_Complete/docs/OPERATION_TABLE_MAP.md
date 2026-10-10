# How application actions use the database

This map complements the workflow diagrams. Changes marked projection must be committed in the same transaction as their event. UI clients never write tables directly.

| Actor / operation | Read first | Append evidence | Update projection / result |
|---|---|---|---|
| Business registers carton | app_user, department, document_type, archival_policy, vendor | CARTON_CREATED in event_log with complete initial metadata | carton, carton_state, initial custody_interval |
| Business indexes a file | carton, app_user scope, current state | FILE_INDEXED event | file_record; do not silently alter declared_file_count |
| Business requests pickup | carton_state, user scope, SLA rules | PICKUP_REQUESTED event | service_request; carton_state becomes Pickup Requested, custody still Business |
| Vendor acknowledges | own assigned request, active user | REQUEST_ACKNOWLEDGED event | service_request.vendor_ack_at and In Progress; advance projection event/version pointer |
| Vendor collects | request, carton_state and vendor scope | PICKED_UP_BY_VENDOR event | carton_state becomes In Transit to Vendor; close Business custody, open Transit |
| Vendor receives | eligible pickup/return request, vendor/warehouse match | RECEIVED_AT_WAREHOUSE event | state In Storage; warehouse custody opens; request completes |
| Business retrieves | warehouse custody, valid state, department scope | RETRIEVAL_REQUESTED event | new request and Retrieval Requested status; remains warehouse custody until delivery evidence |
| Vendor delivers | assigned request and destination | DELIVERED_TO_BUSINESS event | With Business state; close warehouse interval, open Business interval |
| Business returns | With Business state and scope | RETURN_REQUESTED event | return request; receipt later closes Business custody |
| Compliance holds | carton lock, matter/reason, Compliance role | LEGAL_HOLD_APPLIED event | legal_hold and hold-count projection; custody/status unchanged |
| Compliance releases hold | same carton lock, active hold, reason | LEGAL_HOLD_RELEASED event | release fields in legal_hold and hold-count projection |
| Business requests destruction | carton_retention view, warehouse custody, no active hold | DESTRUCTION_REQUESTED event | request and Destruction Requested status |
| Compliance approves | independent requester, policy, custody and holds under lock | DESTRUCTION_APPROVED event | approval fields, Approved for Destruction state; warehouse custody remains |
| Vendor destroys | all prerequisites rechecked under same carton lock | DESTROYED event | terminal state, closed warehouse custody, destruction request projection |
| Vendor lodges certificate | approved/executed destruction and reference reuse checks | CERTIFICATE_LODGED on certificate stream | append certificate_evidence; never change physical carton state |
| Facilities uploads evidence | source kind, vendor scope, file fingerprint | immutable import_batch and import_row; explicit import issues | typed declaration/invoice/certificate evidence preserved as received |
| Facilities reconciles | historical custody/events, requests, vendor evidence, rule snapshots | run event; immutable findings and expected charges | reconciliation_run status/counts and exception_case continuity |
| Owner investigates exception | authorized visibility and existing evidence | EXCEPTION_UPDATED event | exception_case owner/status/reason; never overwrite original findings |
| Facilities deactivates user | administrator authority, selected identity | USER_ACCESS_CHANGED without secrets | app_user inactive; revoke sessions; keep event authorship |
| Authorized policy editor changes policy | configured editing permission, policy revision | REFERENCE_CHANGED before/after snapshot | retention_policy revision; view changes immediately; reevaluate alerts |

## A worked lifecycle

1. Carton registered: **Created / Business custody**.
2. Pickup raised: **Pickup Requested / Business custody**.
3. Collection confirmed: **In Transit to Vendor / Transit custody**.
4. Warehouse receipt confirmed: **In Storage / Warehouse custody**.
5. Destruction requested: **Destruction Requested / Warehouse custody**.
6. Compliance approval: **Approved for Destruction / Warehouse custody**.
7. Vendor execution: **Destroyed / Destroyed custody**.

The warehouse interval stays open through request and approval, so monthly storage cost is not incorrectly stopped when workflow status changes. A legal hold can block steps 5–7 without changing custody or preventing an otherwise valid retrieval/return.

## Configuration and projections are different

- `retention_policy`, `vendor_rate`, `sla_rule`, `holiday`, `threshold_rule` and `tax_rule` are reference data. Authorized edits must be audited.
- `carton_state`, `custody_interval`, `legal_hold` and request status/timestamps are derived projections. Their values must be reconstructable from evidence, including explicitly labelled migration baselines when source history is incomplete.
- `carton_retention` is a view, not a 38th table. It selects the applicable entity-specific/global policy and calculates the date.
- Vendor evidence fields such as `carton_reference` are deliberately not foreign keys: a claim can be unknown or incorrect and must still be investigated.
