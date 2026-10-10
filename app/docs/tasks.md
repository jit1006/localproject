# Implementation checklist

Status: ✔ implemented · ◐ partial · ◻ planned (next increments)

## Phase 1 — foundation
- ✔ App skeleton (backend + frontend), config, `.env.example`, docker-compose
- ✔ DB engine with `search_path` pinned to `prms`
- ✔ Schema apply script wrapping the authoritative SQL
- ✔ Standard error contract, health check
- ◻ CI workflow (`.github/workflows`)

## Phase 2 — auth & early vertical slice
- ✔ bcrypt passwords, server-side sessions, HttpOnly cookie
- ✔ Role guards + row-scope enforcement
- ✔ Event engine: append + projections + idempotency + carton row lock
- ✔ Carton registration + file indexing
- ✔ Pickup → collect → receive; retrieval → deliver; return → receive
- ✔ Readable carton history from the event log

## Phase 3 — operational data & remaining lifecycle
- ✔ Retrieval / return / destruction request lifecycle
- ◻ Lossless XLSX importer with per-sheet accepted/rejected/duplicate counts
- ◻ Projection comparison against supplied cached status/location

## Phase 4 — compliance
- ✔ Retention via `carton_retention` view (entity override, missing-trigger status)
- ✔ Legal holds: apply/release (Compliance only)
- ✔ Independent destruction approval (SoD) + re-check hold at execution
- ✔ Terminal-state protection (no events after Destroyed)
- ◐ Alerts: read via view; scheduled refresh/dedup planned

## Phase 5 — Facilities reconciliation
- ✔ Run + exception framework, idempotent runs, single register
- ◻ Inventory as-of custody engine
- ◻ Invoice arithmetic + independent cost match (`expected_charge`)
- ◻ Certificate vs hold/event engine

## Phase 6 — administration & reporting
- ✔ Role-scoped dashboard counts
- ◻ Scoped CSV/PDF exports
- ◻ Facilities user admin + reference maintenance screens
- ◻ Business-day / overdue SLA calculations

## Phase 7 — integration & delivery
- ◐ Tests: unit (no-DB) ✔; DB integration tests present, need a live DB to run
- ◻ Clean-install verification on a real environment
- ✔ Documentation set (this folder)

## Verification note

The code was authored in a sandbox without internet (no `pip install` /
`npm install`) and without PostgreSQL, so it could not be executed there. Backend
Python **byte-compiles**; frontend braces/parens balance. Running the servers,
the pytest suite, and the DB integration tests requires a real environment with
dependencies installed and PostgreSQL available.
