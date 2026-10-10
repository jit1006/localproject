# PRMS design

## Architecture

A **modular monolith**. One repository, three clearly separated layers in the
backend plus a decoupled SPA frontend.

```
React SPA  ──HTTP (cookies)──▶  FastAPI
                                 ├── api/        routers: translate HTTP ↔ services
                                 ├── services/   ALL business logic + permissions + event engine
                                 ├── repositories (via services + SQLAlchemy)
                                 └── models/      ORM over the authoritative prms schema
                                              │
                                              ▼
                                   PostgreSQL 16 (prms schema)
                                   — owned by sql/01_schema.sql
```

Routers never contain business logic or touch the DB directly. Services enforce
authentication, role, row-scope and field permissions on the server. The SQL
schema is the single source of truth for the data model; the backend maps a
subset of it and never calls `metadata.create_all` (no competing authority).

## Authentication & sessions

- Passwords hashed with bcrypt (`passlib`).
- Sessions are **server-side**: `user_session` stores a SHA-256 **digest** of an
  opaque bearer token; the raw token is returned only in an HttpOnly, SameSite=Lax
  cookie. The raw token is never persisted.
- `deps.current_user` resolves the cookie → session → active user; `require_roles`
  guards role-restricted endpoints.

## Event engine (the core invariant)

One canonical append-only `event_log` is the only source of audit truth.
`carton_state` and `custody_interval` are **rebuildable projections**.

A state-changing command (`services/event_engine.append_carton_event`):

1. Checks the idempotency key — a prior commit with the same key returns the
   original event (safe retries).
2. `SELECT … FOR UPDATE` locks the carton row (serializes concurrent hold /
   movement / destruction commands).
3. Validates the lifecycle transition against `lifecycle_transition`; refuses to
   move out of a terminal state.
4. Appends the event with actor/role/channel evidence and the next stream version.
5. Updates `carton_state` and opens/closes `custody_interval` atomically.

Legal-hold and retention prerequisites are enforced by the calling command
services (`hold_service`, `request_service`) before the append.

### Replay

History is read in `occurred_at, event_id` order (documented deterministic
tie-breaker). `resulting_status = NULL` means "unchanged" (e.g. a hold applied),
not unknown — replay preserves the prior status across such events.

## Retention

`carton_retention` is a **view**, never a stored due date. It prefers an
entity-specific `retention_policy` over the global default and reports
`MISSING_TRIGGER` / `MISSING_POLICY` instead of inventing a date. Editing a
policy row recomputes due dates with no code change.

## Legal holds

Only Compliance applies/releases. Holds block **destruction** but permit
otherwise-valid retrieval/return/movement. Destruction eligibility (hold +
warehouse custody + approval) is re-checked **at execution**, so a hold applied
after approval still blocks the actual destruction.

## Reconciliation (framework implemented; engines are the next increment)

`reconciliation_run` records who/when/parameters/input-fingerprint/rule-snapshot/
counts. Idempotency: same `run_kind + scope_key + input_fingerprint` returns the
existing run; a changed fingerprint creates a new identifiable run. Findings
persist into one `exception_case` register (not one register per run), keyed by a
`stable_key` that excludes the run id so continuing discrepancies age rather than
duplicate.

Planned detection engines (see `KIRO_PROJECT_CONTEXT.md` §13):

- **Inventory** — compare vendor declaration vs. internal custody at the exact
  `declared_at`: missing-at-vendor / unknown-to-us / wrong-warehouse.
- **Invoice** — Pass 1 header↔line arithmetic; Pass 2 vs. independently computed
  `expected_charge` from events/rates (effective rate, decimal money, 18% tax over
  its configured date range).
- **Certificate** — certificate vs. request vs. destruction event vs. historical
  hold interval: destruction-under-hold (Critical), reuse across vendors/months,
  destroyed-without-certificate, etc.

## Error contract

Every error returns `{ "error": { code, message, fieldErrors, correlationId } }`
with an appropriate HTTP status. Failures explain permitted detail without leaking
another department's or vendor's data.

## Known limitations in this foundation

- Reconciliation detection engines and the lossless XLSX importer are not yet
  implemented (framework + schema are).
- Alerts are read via the retention view; scheduled alert refresh/dedup is planned.
- Scoped CSV/PDF exports and Facilities user-admin screens are planned.
- The code has **not** been executed in the authoring sandbox (no network to
  install deps, no PostgreSQL). It byte-compiles; it has not been run here.
