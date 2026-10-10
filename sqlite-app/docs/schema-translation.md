# PostgreSQL → SQLite schema translation

The authoritative model is `PRMS_Database_Complete/sql/01_schema.sql` (PostgreSQL).
SQLite cannot express several of its features, so this app translates the schema
and moves the un-expressible invariants into the application layer. Every change:

| PostgreSQL feature | SQLite handling | Where the invariant lives now |
|---|---|---|
| `CREATE SCHEMA prms` namespace | Dropped — one namespace per DB file | n/a |
| `text` / `integer` / `numeric` | `TEXT` / `INTEGER` / `REAL` affinities | money kept as **TEXT** decimal strings (never float) |
| `timestamptz`, `date` | `TEXT` ISO-8601 (`...Z` instants, `YYYY-MM-DD` dates) | app formats/parses; comparisons work lexically on ISO strings |
| `jsonb` | `TEXT` + `CHECK (json_valid(col))` | validated by SQLite's JSON1; parsed in model mappers |
| `GENERATED ALWAYS AS IDENTITY` | `INTEGER PRIMARY KEY AUTOINCREMENT` | same monotonic ids |
| `EXCLUDE USING gist (... && )` for non-overlapping rate/custody/tax ranges | **Not representable** in SQLite | enforced in services: one open `custody_interval` per carton; rate/tax overlap checks in repos before insert |
| Partial indexes (`WHERE ...`) | Supported in SQLite ≥ 3.8 — **kept** | same |
| Expression index `lower(email)` | Supported — **kept** (`app_user_email_ci`) | same |
| `UNIQUE NULLS NOT DISTINCT (a,b,c)` | Emulated: `UNIQUE INDEX ... (COALESCE(a,'<GLOBAL>'), b, c)` | treats NULL entity/vendor as one "global" slot, matching Postgres semantics |
| Composite FKs `(entity_id, department_id)`, `(carton_id, document_type)`, `(vendor_id, warehouse_id)` | SQLite supports composite FKs — **kept** | same |
| Append-only `protect_evidence` trigger (plpgsql) | `BEFORE UPDATE/DELETE ... RAISE(ABORT, ...)` triggers | same effect: evidence tables reject UPDATE/DELETE; corrections are appended |
| `make_interval(years => n)` in the retention view | `date(trigger, '+' || years || ' years')` | same calculated due date; still a **view**, never a stored column |
| `btree_gist` extension | Not needed (no gist) | — |
| Numeric money arithmetic | Store as TEXT; compute with care in services | reconciliation cost engine must use exact decimal handling |

## Preserved as-is

- All 37 tables and the `carton_retention` view.
- Primary keys, foreign keys (including composite FKs), and `CHECK` constraints
  that SQLite supports (role-scope checks, status enums, date-order checks,
  rejection-reason-required, approver≠requester, etc.).
- The single canonical `event_log` and the rebuildable projections.
- Reference seed values (entities, departments, vendors, warehouses, document
  types, archival/retention policies, rates, SLA rules, holidays, thresholds,
  statuses, event types, lifecycle transitions).

## Invariants now enforced by the application (not the DB)

Because SQLite lacks exclusion constraints, the **services** guarantee:

1. **One open custody interval per carton** — the event engine closes the prior
   open interval before opening a new one (so intervals never overlap).
2. **Non-overlapping vendor rates / tax rules** — insert-time checks in the
   repositories (the reference-maintenance path) reject overlaps per
   `(vendor_id, activity)` / `tax_code`.
3. **Warehouse-custody completeness** — when custody becomes `WAREHOUSE` the
   engine populates `vendor_id` + `warehouse_id` (CHECK still enforces the shape).

These are tested; see `backend/tests/lifecycle.test.js` and the HTTP walkthrough
in the top-level README's "Verification" section.
