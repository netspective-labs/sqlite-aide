-- census-analyze.sqlite.sql
/*
================================================================================
SQLite Aide Census: ANALYZE + sqlite_stat1 snapshot (idempotent, side-effecting)
================================================================================

Purpose
-------
Runs ANALYZE to (re)generate query planner statistics, then snapshots sqlite_stat1
into ".sqlite-aide.d" as:

  sqlite-aide.d/query-planner/stat1.auto.json
  sqlite-aide.d/query-planner/summary.auto.json
  sqlite-aide.d/table-estimates.auto.json   (row estimates per table, derived)

Important dependency
--------------------
Depends on ".sqlite-aide.d" created by:
  sqlite3 your.db < lib/sql/core-ddl.sqlite.sql

Usage
-----
  sqlite3 your.db < census-analyze.sqlite.sql

Idempotency
-----------
Safe to re-run, but note it executes ANALYZE each time (intentional).
It UPSERTs the same artifact paths and recreates helper views.

Notes
-----
- Requires the database to permit ANALYZE.
- Does not require STAT4 support.
================================================================================
*/

PRAGMA foreign_keys = ON;

-- Caller opts into this cost/side-effect.
ANALYZE;

-- Snapshot sqlite_stat1
WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/query-planner/stat1.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'rows',
      (SELECT json_group_array(
                json_object('tbl', tbl, 'idx', idx, 'stat', stat)
              )
         FROM sqlite_stat1)
  ),
  json_object('generator','census-analyze.sqlite.sql','source','sqlite_stat1'),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- Derive per-table row estimates (heuristic: first integer from stat string)
WITH
  _now AS (SELECT datetime('now') AS ts),
  _tables AS (
    SELECT tl.name AS table_name
    FROM pragma_table_list AS tl
    WHERE tl.type='table' AND tl.name NOT LIKE 'sqlite_%'
  ),
  _est AS (
    SELECT
      t.table_name,
      (
        SELECT CAST(
                 substr(s.stat || ' ', 1, instr(s.stat || ' ', ' ') - 1)
                 AS INTEGER
               )
        FROM sqlite_stat1 AS s
        WHERE s.tbl = t.table_name
        ORDER BY s.idx
        LIMIT 1
      ) AS row_estimate
    FROM _tables AS t
  )
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/table-estimates.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'tables',
      (SELECT json_group_object(
                e.table_name,
                json_object(
                  'table_name', e.table_name,
                  'row_estimate', e.row_estimate
                )
              )
         FROM _est AS e)
  ),
  json_object('generator','census-analyze.sqlite.sql','notes','row_estimate derived from sqlite_stat1'),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- Summary
WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/query-planner/summary.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'has_sqlite_stat1', 1,
    'notes', 'ANALYZE executed by this script; stats reflect distribution at that time'
  ),
  json_object('generator','census-analyze.sqlite.sql'),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- Helper views
DROP VIEW IF EXISTS sqliteaide_query_planner_stat1_row;
CREATE VIEW IF NOT EXISTS sqliteaide_query_planner_stat1_row AS
SELECT
  json_extract(d.contents,'$.generated_on') AS generated_on,
  json_extract(r.value,'$.tbl')            AS tbl,
  json_extract(r.value,'$.idx')            AS idx,
  json_extract(r.value,'$.stat')           AS stat
FROM ".sqlite-aide.d" AS d,
     json_each(d.contents,'$.rows') AS r
WHERE d.path = 'sqlite-aide.d/census/query-planner/stat1.auto.json';

DROP VIEW IF EXISTS sqliteaide_table_estimate_row;
CREATE VIEW IF NOT EXISTS sqliteaide_table_estimate_row AS
SELECT
  json_extract(d.contents,'$.generated_on') AS generated_on,
  t.key                                     AS table_name,
  json_extract(t.value,'$.row_estimate')     AS row_estimate
FROM ".sqlite-aide.d" AS d,
     json_each(d.contents,'$.tables') AS t
WHERE d.path = 'sqlite-aide.d/census/table-estimates.auto.json';
