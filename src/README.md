# SQLite Aide Pack

This `sqlite` SQL module is an "information schema and census helpers pack" for
SQLite. Think of it as a child module under sqlite/ that focuses on collecting,
snapshotting, and publishing database metadata into a consistent, queryable
form.

## `core-ddl.sqlite.sql`

This is the foundational DDL for SQLite Aide SQLite support. Its job is to
define the shared persistence surface that other scripts depend on.

- It creates the `.sqlite-aide.d` table.
- `.sqlite-aide.d` is an internal artifact and metadata store, addressed by
  `path`.
- Other scripts write generated JSON, generated SQL, summaries, and diagnostics
  into `.sqlite-aide.d` rather than creating lots of permanent helper tables.
- Because it is shared infrastructure, everything else should treat it as a
  dependency, not as something to recreate in every script.

## `info-schema.sqlite.sql`

This is the canonical schema snapshot generator.

- It introspects the current database schema and stores a complete
  representation in `.sqlite-aide.d` under a stable path (for example,
  sqlite-aide.d/info-schema.auto.json).
- It creates views that project the JSON back into relational rows (tables,
  columns, indexes, foreign keys, triggers, relations, etc.).
- It is designed to be safe and idempotent: rerun it any time the schema
  changes, and downstream systems always know where to find the “latest schema
  truth.”

## `info-schema-destroy.sqlite.sql`

This is the narrow cleanup script for the schema snapshot only.

- It drops only the views that were created by info-schema.sqlite.sql.
- It deletes only the `.sqlite-aide.d` rows that info-schema.sqlite.sql owns
  (again by explicit equality checks).
- This is useful when you want to reset or regenerate schema artifacts without
  disturbing other census outputs (planner stats, dbstat, rowcounts) or other
  `.sqlite-aide.d` content.

## How to use

- `core-ddl.sqlite.sql` must be run first (creates `.sqlite-aide.d`).
- `info-schema.sqlite.sql` depends on `.sqlite-aide.d` and is the baseline
  artifact most other systems will rely on.
- `info-schema-destroy.sqlite.sql` removes only the schema snapshot outputs.
- `census-*` scripts add optional evidence artifacts on top of that baseline.
- `census-*/destroy.sqlite.sql` removes census outputs without removing
  `.sqlite-aide.d`.
