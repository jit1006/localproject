# PRMS complete database package

Open **START_HERE.html** in your browser. It works offline after extracting the ZIP.

## Included
- 37-table PostgreSQL schema with primary/foreign keys, indexes, reference rules and append-only protection.
- Reference seed from the provided workbook; operational data importer remains to be implemented.
- Complete ERD, seven detailed module diagrams and four workflow diagrams.
- Each diagram supplied as SVG, PNG, editable Mermaid and Graphviz source.
- Complete column and relationship dictionaries, design guide and validation report.
- SQL constraint tests and runtime privilege template.

## Suggested reading order
1. START_HERE.html: overview and clickable diagram index.
2. diagrams/00_complete_schema.svg: all-table relationship map (zoom in).
3. Module diagrams 01–07: full attributes; cross-module links are in docs/RELATIONSHIPS.md.
4. Flow diagrams 08–11: application lifecycle, atomic command, ingestion/reconciliation and implementation.
5. docs/DATABASE_GUIDE.md and docs/COLUMN_DICTIONARY.md.
6. sql/01_schema.sql, sql/02_seed_reference.sql, sql/04_constraint_checks.sql.

## Run with PostgreSQL 16+
Run from the extracted package folder. btree_gist must be available.

```bash
psql "$PRMS_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/01_schema.sql
psql "$PRMS_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/02_seed_reference.sql
psql "$PRMS_DATABASE_URL" -v ON_ERROR_STOP=1 -f sql/04_constraint_checks.sql
```

Then securely provision a separate non-owner runtime login and apply sql/03_runtime_grants.sql using psql's runtime_role variable. Never commit credentials.

The schema is an initial migration for an empty database. It is not a reset script. This package supplies schema and design, not an implemented API or operational importer. Legal-hold enforcement, role/field authorization, event reduction, reconciliation and concurrency orchestration must be implemented in the backend. See the design guide for precise boundaries and unresolved source-rule conflicts.

## Diagram conventions
SQL is authoritative. Diagrams are generated from parsed SQL rather than hand-maintained table lists. Mermaid ERDs use crow-foot notation. Rendered Graphviz ERDs show arrows from referencing table to referenced table; a question mark marks nullable columns. They are relationship maps, not action flows. Detailed module pages include all their table attributes; cross-module foreign keys are intentionally omitted from local diagrams to preserve readability and appear in the complete ERD and relationship dictionary. A nullable composite reference means at least one component can be null.

Do not enforce carton foreign keys on raw vendor claims: unknown IDs and inconsistent evidence are reconciliation inputs. Retention dates are calculated in the carton_retention view. Current status/location belong to event-derived projections.
