# Migrations

The **authoritative schema** lives in `PRMS_Database_Complete/sql/` at the repo
root and is the single source of truth. The backend does **not** create tables
with SQLAlchemy `metadata.create_all` — that would be a second, competing schema
authority, which the project brief explicitly forbids.

## Apply order (one empty database, as the migration owner)

```bash
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../../PRMS_Database_Complete/sql/01_schema.sql
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../../PRMS_Database_Complete/sql/02_seed_reference.sql
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../../PRMS_Database_Complete/sql/05_design_improvements.sql
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f ../../../PRMS_Database_Complete/sql/04_constraint_checks.sql
```

Then provision a **non-owner** runtime login and grant it:

```bash
psql "$OWNER_DATABASE_URL" -v runtime_role=prms_app \
  -f ../../../PRMS_Database_Complete/sql/03_runtime_grants.sql
```

The backend connects as `prms_app` (set `PRMS_DATABASE_URL`), never as the owner.

## Alembic

If you later adopt Alembic for application-managed migrations, baseline it
against the state produced by `01_schema.sql` (an `alembic stamp head` on the
already-created schema) so there is exactly **one** migration authority. Do not
let Alembic re-create tables that the SQL files already own.
