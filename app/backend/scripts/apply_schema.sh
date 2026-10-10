#!/usr/bin/env bash
# Apply the authoritative PRMS schema + seed to an empty database as the owner.
# Usage: OWNER_DATABASE_URL=postgresql://owner:***@localhost:5432/prms ./apply_schema.sh
set -euo pipefail

SQL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../PRMS_Database_Complete/sql" && pwd)"
: "${OWNER_DATABASE_URL:?Set OWNER_DATABASE_URL to the migration-owner DSN}"

echo "Applying schema from: $SQL_DIR"
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/01_schema.sql"
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/02_seed_reference.sql"
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/05_design_improvements.sql"
psql "$OWNER_DATABASE_URL" -v ON_ERROR_STOP=1 -f "$SQL_DIR/04_constraint_checks.sql"
echo "Schema + seed applied. Now provision a non-owner runtime role and run 03_runtime_grants.sql."
