# PRMS (Node.js + SQLite) — Physical Records Management System

A single, auditable system of record for physical cartons: ownership, custody,
movement history, retention eligibility, legal holds, and vendor-evidence
reconciliation.

This is the **Node.js + SQLite** implementation. It is self-contained under
`sqlite-app/` and is independent of the Python/PostgreSQL variant. It uses a
**consolidated 16-table schema** (ref_lookup + org_unit + a denormalized carton,
with invoice/import/reconciliation-run fields inlined) derived from the
authoritative PostgreSQL model in
[`PRMS_Database_Complete/`](../PRMS_Database_Complete/) — see
[`docs/schema-translation.md`](docs/schema-translation.md) for the full
table-by-table mapping and the invariants moved into the service layer.

## Highlights

- **Zero runtime dependencies.** The backend uses Node's built-in `node:sqlite`
  (Node ≥ 22.5, run with `--experimental-sqlite`) and `node:http`. No `express`,
  no ORM, no `better-sqlite3` needed to run — though the DB layer is isolated so
  swapping to `better-sqlite3` is a one-file change.
- **Separation of concerns:** `routes → services → repositories → models → db`.
- **Canonical event log** with rebuildable projections (`carton_state`,
  `custody_interval`), idempotent commands, lifecycle validation, and
  append-only triggers mirroring the PostgreSQL design.
- **Verified end-to-end** against real SQLite in development (see "Verification").

## Folder structure

```text
sqlite-app/
├── backend/
│   ├── src/
│   │   ├── db/
│   │   │   ├── schema.sql        consolidated 16-table schema + retention view
│   │   │   ├── seed.sql          reference seed
│   │   │   ├── init.js           applies schema + seed
│   │   │   └── connection.js     node:sqlite connection + tx() helper
│   │   ├── models/               row <-> domain mappers (app_user, carton,
│   │   │                         file_index, request, event_log, legal_hold,
│   │   │                         reconciliation) + JSDoc typedefs
│   │   ├── repositories/         all SQL lives here
│   │   ├── services/             business logic, permissions, event engine
│   │   ├── http/                 zero-dep router + route registration
│   │   ├── config.js             env-driven settings
│   │   ├── security.js           scrypt passwords, session tokens
│   │   ├── errors.js             standard error shape
│   │   └── server.js             node:http entrypoint
│   ├── scripts/create_user.js    provision a login
│   ├── tests/lifecycle.test.js   node:test suite (zero deps)
│   └── package.json
├── frontend/                     React + Vite + TypeScript (API-compatible)
│   └── src/{api,auth,components,pages}
├── docs/                         schema-translation, design, api, roles, demo
└── .env.example
```

## Prerequisites

- **Node.js ≥ 22.5** (for built-in `node:sqlite`). This repo was verified on v22.
- A `sqlite3` CLI is optional (handy for inspecting the DB file).
- **Node.js 20+** also works for the frontend build.

## Run the backend

```bash
cd sqlite-app/backend
cp ../.env.example .env            # optional; sensible defaults exist

# 1) initialize the database file (applies schema.sql + seed.sql)
npm run db:init

# 2) provision at least one login (seeded reference data has no users)
npm run seed:users -- --id U-BIZ --name "Dina Business" --email dina@example.com \
  --role BUSINESS --password demo --entity ENT-BRN --department DEP-BRN-DEL

# 3) start the API (http://localhost:8000)
npm start
```

Check `GET http://localhost:8000/health` → `{"status":"ok","database":"up",...}`.

> All scripts pass `--experimental-sqlite` for you (see `package.json`). On
> Node < 22.5, install `better-sqlite3` and reimplement `src/db/connection.js`.

## Run the frontend

```bash
cd sqlite-app/frontend
npm install
VITE_API_TARGET=http://localhost:8000 npm run dev   # http://localhost:5173
```

Log in with the user you provisioned. The dev server proxies `/api` to the
backend so the session cookie is same-origin.

## Tests

```bash
cd sqlite-app/backend
npm test
```

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/schema-translation.md](docs/schema-translation.md) | Every PostgreSQL→SQLite change and the invariants moved to the app layer |
| [docs/design.md](docs/design.md) | Architecture, event engine, reconciliation plan |
| [docs/roles.md](docs/roles.md) | Role × permission matrix |
| [docs/api.md](docs/api.md) | REST contract |
| [docs/demo.md](docs/demo.md) | Demo script |

## Verification

In development this stack was run against real SQLite:

- `schema.sql` + `seed.sql` apply cleanly (16 tables, retention view, integrity OK).
- `npm run db:init`, `seed:users`, and `npm start` all run; `/health` reports `database: up`.
- Full lifecycle exercised over HTTP: login (all roles) → register carton →
  pickup → vendor collect → **warehouse receipt (In Storage)** → retrieval/return →
  destruction request → self-approval denied → Compliance approves → vendor
  destroys → terminal **Destroyed**; plus vendor-content redaction (403),
  hold-blocks-destruction (409), and scoped dashboards.
- `npm test` passes (password hashing, hold-blocks-destruction, retention view).

The **frontend** was authored but not `npm install`/`vite build`-verified in the
authoring sandbox (no network). The three full reconciliation detection engines
and the XLSX importer are the documented next increment.
