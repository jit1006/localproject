# Validation

Validated on 2026-10-10 using PGlite's embedded PostgreSQL engine with btree_gist.

- 01_schema.sql: PASS (71 statements).
- 02_seed_reference.sql: PASS (147 statements).
- 04_constraint_checks.sql: PASS (35 statements).

Engine: [{"version":"PostgreSQL 18.3 (PGlite 0.5.8) on wasm32-unknown-emscripten, compiled by emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 3.1.74 (1092ec30a3fb1d46b1782ff1b4db5094d3d06ae5), 32-bit"}]

The DDL, reference seeds and rollback-only constraint checks executed successfully. This is not an end-to-end application test or a deployment test against a standalone PostgreSQL service. The runtime grant template must be applied and verified with your separately provisioned non-owner database login. Service-layer authorization, event reduction, imports, reconciliation and concurrency orchestration remain implementation work.

## Complete package checks

- All 37 tables and 82 foreign keys extracted from SQL.
- All referencing and referenced column names checked against schema metadata.
- All SQL files byte-identical to the previously executed and validated version.
- 12 Graphviz diagrams rendered successfully to SVG and PNG and visually reviewed.
- Editable Mermaid generated from the same SQL metadata; Mermaid rendering itself was not executed.
- Every offline HTML link and image target resolves within the extracted package.
- Operational import, APIs, event reduction and reconciliation remain backend implementation tasks.
