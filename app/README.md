# PRMS — Physical Records Management System

A single, auditable system of record for the bank's physical records: which
department owns a carton, where it physically is, who moved it, when it becomes
eligible for destruction, and whether vendor inventory, invoices and destruction
certificates agree with internal evidence.

This directory (`app/`) contains the **application**: a FastAPI backend and a
React + Vite + TypeScript frontend. The **authoritative database schema** lives
one level up in [`PRMS_Database_Complete/`](../PRMS_Database_Complete/) and is
the single source of truth for the data model.

> **Status / honesty note.** This is a working, runnable foundation covering the
> core vertical slices (auth, carton registration & file indexing, the full
> pickup → storage → retrieval → return → destruction lifecycle, legal holds,
> retention view, role-scoped dashboards) plus the reconciliation run/exception
> framework. The three full reconciliation *detection engines* and the lossless
> workbook importer are specified in [`docs/design.md`](docs/design.md) and are
> the next implementation increment. See [`docs/tasks.md`](docs/tasks.md) for
> what is implemented vs. planned. Nothing here claims a test result or benchmark
> that was not actually produced.

## Repository layout

```text
app/
├── backend/                 FastAPI modular monolith
│   ├── app/
│   │   ├── api/             HTTP routers (no business logic)
│   │   ├── services/        business logic + permission checks + event engine
│   │   ├── models/          SQLAlchemy ORM mapping the authoritative schema
│   │   ├── config.py        env-driven settings
│   │   ├── db.py            engine/session, search_path pinning
│   │   ├── security.py      password hashing, session tokens
│   │   ├── deps.py          FastAPI auth/role dependencies
│   │   ├── errors.py        standard error shape
│   │   ├── schemas.py       Pydantic request/response models
│   │   └── main.py          app entrypoint, router wiring, /health
│   ├── migrations/          how the authoritative SQL is applied (+ Alembic note)
│   ├── scripts/             apply_schema.sh, create_user.py
│   ├── tests/               pytest (unit tests + DB integration tests)
│   ├── requirements.txt     pinned dependencies
│   └── pyproject.toml
├── frontend/                React + Vite + TypeScript
│   ├── src/
│   │   ├── api/             typed fetch client + shared types
│   │   ├── auth/            session-cookie auth context
│   │   ├── components/      Layout with role-scoped navigation
│   │   └── pages/           Login, Dashboard, Cartons, Carton detail,
│   │                        Vendor queue, Holds, Reconciliation
│   ├── package.json
│   └── vite.config.ts
├── docs/                    requirements, design, tasks, decisions, demo, API, roles
├── .env.example
└── docker-compose.yml       local PostgreSQL 16 (btree_gist available)
```

## Prerequisites

- **PostgreSQL 16+** with the `btree_gist` extension available.
- **Python 3.11+** (the backend uses modern typing syntax).
- **Node.js 20+** for the frontend.

## Quick start

### 1. Database

Start PostgreSQL (the compose file provisions a local instance):

```bash
docker compose up -d db
```

Apply the authoritative schema + seed as the **migration owner**, then provision
a separate **non-owner** runtime login:

```bash
cd backend
OWNER_DATABASE_URL=postgresql://prms_owner:ownerpw@localhost:5432/prms \
  ./scripts/apply_schema.sh

# create the runtime role (psql, as owner/superuser)
psql "$OWNER_DATABASE_URL" -c "CREATE ROLE prms_app LOGIN PASSWORD 'apppw';"
psql "$OWNER_DATABASE_URL" -v runtime_role=prms_app \
  -f ../../PRMS_Database_Complete/sql/03_runtime_grants.sql
```

### 2. Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env   # then edit PRMS_DATABASE_URL + PRMS_SESSION_SECRET

# provision a login (imported users have no password until you set one)
python -m scripts.create_user U-BIZ "Dina Biz" dina@example.com BUSINESS \
  --password 'changeme' --entity ENT-BRN --department DEP-BRN-DEL

uvicorn app.main:app --reload --port 8000
# API docs at http://localhost:8000/docs ; health at /health
```

### 3. Frontend

```bash
cd frontend
npm install
npm run dev            # http://localhost:5173 (proxies /api to :8000)
```

## Environment

The runtime database login **must be non-owner, non-superuser** (enforced by the
grants in `03_runtime_grants.sql`). Never commit real credentials. See
[`.env.example`](.env.example).

## Tests

```bash
cd backend
pytest tests/test_security.py                      # no database needed
PRMS_TEST_DATABASE_URL=postgresql+psycopg://owner:***@localhost:5432/prms_test \
  pytest                                           # includes DB integration tests
```

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/requirements.md](docs/requirements.md) | MVP scope, acceptance criteria, out-of-scope |
| [docs/design.md](docs/design.md) | Architecture, event engine, reconciliation plan |
| [docs/roles.md](docs/roles.md) | Role × permission matrix |
| [docs/api.md](docs/api.md) | REST contract (endpoints, errors, idempotency) |
| [docs/tasks.md](docs/tasks.md) | Implemented vs. planned checklist |
| [docs/decisions.md](docs/decisions.md) | Decision log + source-conflict handling |
| [docs/demo.md](docs/demo.md) | Ten-minute demo script |
