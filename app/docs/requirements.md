# PRMS requirements

Derived from the project brief (`KIRO_PROJECT_CONTEXT.md`) and the supplied
source materials. This is a condensed, implementation-facing restatement.

## Purpose

Replace spreadsheets/emails/vendor portals with one auditable record of physical
carton custody, retention, legal holds, and vendor-evidence reconciliation.

## Roles (four application login roles)

| Role | Scope | Can | Cannot |
|------|-------|-----|--------|
| Business | Own entity/department | Register cartons, index files, raise pickup/retrieval/return/destruction, view own history/alerts | Approve destruction, manage holds, confirm vendor ops, edit history, see other departments |
| Vendor | Own vendor code | See assigned requests, acknowledge, confirm collection & receipt separately, deliver, receive returns, execute approved destruction, lodge certificates | See carton contents, rates, costs, or other vendors' work |
| Compliance | Cross-entity | Apply/release holds, approve/reject destruction, inspect history & critical findings | Raise destruction, execute physical ops, edit history; approve own-requested destruction |
| Facilities | Cross-entity | Monitor, reconcile, review finance, investigate exceptions, administer users, maintain authorized reference data | Raise Business requests, approve destruction, manage holds, confirm physical work, alter history |

## Required MVP

1. Four-role authentication + server-side access control. ✔ implemented
2. Lossless workbook ingestion with rejected-row reporting. ◻ planned (framework in schema)
3. Carton registration and file indexing. ✔
4. Pickup/collection/receipt/retrieval/return/destruction workflow. ✔
5. One append-only event log with readable carton history. ✔
6. Policy-driven retention dates + actionable alerts. ✔ (view) / ◻ alerts refresh
7. Compliance-controlled legal holds + independent destruction approval. ✔
8. All three reconciliations (inventory, invoice, certificate). ◻ framework ✔, engines planned
9. One exception register with severity/owner/evidence/aging. ✔ schema / ◻ population
10. Role dashboards, filters, drill-down, scoped exports. ✔ dashboards / ◻ exports
11. Facilities user admin + authorized reference maintenance. ◻ planned
12. Reproducible setup, tests, docs, demo, backup. ✔ docs/setup / partial tests

## Acceptance criteria (from the brief)

- Commands append events atomically with projections; retries don't duplicate.
- Event replay reproduces current state and historical custody.
- A policy edit changes retention dates with no code change (via `carton_retention` view).
- A legal hold blocks destruction **even when applied after approval** (re-checked at execution).
- Business users can't access other departments; vendor users can't access other vendors, costs, or carton contents.
- Reconciliation on unchanged evidence doesn't duplicate findings; later cycles age existing exceptions.
- Every rejected row/finding has traceable evidence.
- Installation succeeds from a clean checkout; list/filter target < 2s on the sample (measure, don't promise).

## Out of scope

OCR, scanned-document viewer, digital archives, external vendor-portal integration,
live courier tracking, scanner/RFID hardware, microservices, Kubernetes, paid AI.
