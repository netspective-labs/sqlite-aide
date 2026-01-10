# Census Pack

`sqlite/census` is the “census pack” for SQLite focuses on collecting,
snapshotting, and publishing database metadata into a consistent, queryable
form.

They publish artifacts into a shared persistence mechanism (the `.sqlite-aide.d`
table) and expose convenient views for querying those artifacts. This makes the
outputs easy to reuse across apps, SQLPage consoles, documentation tooling,
diffing, and tests.

What lives here:

- `census-analyze.sqlite.sql` runs `ANALYZE` and publishes query planner
  statistics (sqlite_stat1 based) into `.sqlite-aide.d`. This is useful for
  understanding how SQLite will plan queries and for capturing “planner state”
  that affects performance.

- `census-stat4.sqlite.sql` captures `sqlite_stat4` content if STAT4 is
  available. This is optional and depends on how SQLite was compiled and whether
  `sqlite_stat4` exists.

- `census-dbstat.sqlite.sql` captures storage/layout facts via dbstat if the
  dbstat module is available. This is optional and depends on the SQLite build.

- `census-rowcounts.sqlite.sql` Provides exact row counts using a two-step
  approach: it generates a plan (SQL text stored in `.sqlite-aide.d`) that the
  caller executes, then it publishes an aggregated rowcount artifact. This is
  separated because SQLite cannot run dynamic SQL directly inside a regular SQL
  statement.

Operational expectations:

- Most scripts are safe to re-run and update the same artifact paths
  (idempotent).
- Some scripts are intentionally side-effecting, especially ANALYZE.
- Some scripts are build-dependent (STAT4, dbstat).
- The group assumes `.sqlite-aide.d` already exists and does not try to redefine
  it.

How you typically use it:

- First run `core-ddl.sqlite.sql` (once per DB) to ensure `.sqlite-aide.d`
  exists.
- Run `info-schema.sqlite.sql` to establish the canonical schema snapshot.
- Optionally run the `census-*` scripts depending on what your SQLite build
  supports and what evidence you want to collect.
