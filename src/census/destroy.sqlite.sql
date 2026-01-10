-- src/census/destroy.sqlite.sql
/*
SQLite Aide Census cleanup script.

Purpose
-------
Removes only the artifacts created by SQLite Aide census scripts while preserving
the ".sqlite-aide.d" table and any non-census artifacts.

This script:
- Drops all census-created views
- Deletes only the exact census-owned rows from ".sqlite-aide.d"

It does NOT:
- Drop the ".sqlite-aide.d" table
- Remove artifacts created by other SQLite Aide subsystems
- Touch application tables or user data

Usage
-----
  sqlite3 your.db < src/census/destroy.sqlite.sql

Notes
-----
- Safe to run even if census was only partially executed.
- Explicit path matching is used to avoid accidental data loss.
*/

PRAGMA foreign_keys = OFF;

-- ---------------------------------------------------------------------------
-- Drop census-created views
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS sqliteaide_query_planner_stat1_row;
DROP VIEW IF EXISTS sqliteaide_query_planner_stat4_row;
DROP VIEW IF EXISTS sqliteaide_table_estimate_row;

DROP VIEW IF EXISTS sqliteaide_storage_object_summary;

DROP VIEW IF EXISTS sqliteaide_table_rowcount_row;

-- ---------------------------------------------------------------------------
-- Remove census artifacts stored in ".sqlite-aide.d"
-- ---------------------------------------------------------------------------

DELETE FROM ".sqlite-aide.d"
WHERE path IN (
  -- query planner statistics
  'sqlite-aide.d/census/query-planner/stat1.auto.json',
  'sqlite-aide.d/census/query-planner/stat4.auto.json',

  -- storage / dbstat
  'sqlite-aide.d/census/storage/dbstat.auto.json',

  -- rowcount artifacts
  'sqlite-aide.d/census/rowcounts.plan.sql',
  'sqlite-aide.d/census/table-rowcounts.auto.json'
);

PRAGMA foreign_keys = ON;
