-- support/assurance/console/test.sqlitesh.sql
/*
SQLite Aide census test runner (simple / no rowcounts).

This script:
- Creates the ".sqlite-aide.d" artifact table
- Captures schema and lightweight metadata
- Runs ANALYZE-based census
- Attempts optional collectors (STAT4, dbstat)

Intended for sqlite3 CLI.
All .read paths are relative to this file.
*/

-- ---------------------------------------------------------------------------
-- 1) Core SQLite Aide DDL (required)
-- ---------------------------------------------------------------------------
.read ../../src/core-ddl.sqlite.sql

-- ---------------------------------------------------------------------------
-- 2) Always-safe schema and metadata
-- ---------------------------------------------------------------------------
.read ../../src/info-schema.sqlite.sql

-- ---------------------------------------------------------------------------
-- 3) ANALYZE-based census (intentional side effects)
-- ---------------------------------------------------------------------------
.read ../../src/census/census-analyze.sqlite.sql

-- ---------------------------------------------------------------------------
-- 4) Optional census collectors (may fail depending on SQLite build)
-- ---------------------------------------------------------------------------
.read ../../src/census/census-stat4.sqlite.sql
.read ../../src/census/census-dbstat.sqlite.sql

-- At this point, the database contains a complete schema snapshot
-- and available planner/storage census artifacts under ".sqlite-aide.d".
