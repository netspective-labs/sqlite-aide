-- census-stat4.sqlite.sql
/*
================================================================================
SQLite Aide Census: sqlite_stat4 snapshot (requires STAT4 support)
================================================================================

Purpose
-------
Snapshots sqlite_stat4 (if your SQLite build supports STAT4 and the table exists)
into ".sqlite-aide.d" as:

  sqlite-aide.d/query-planner/stat4.auto.json

Also refreshes:
  sqlite-aide.d/query-planner/summary.auto.json

Important dependency
--------------------
Depends on ".sqlite-aide.d" created by:
  sqlite3 your.db < lib/sql/core-ddl.sqlite.sql

Usage
-----
Run only when sqlite_stat4 exists (caller responsibility):
  sqlite3 your.db < census-stat4.sqlite.sql

Idempotency
-----------
Safe to re-run. It UPSERTs the same artifact paths and recreates helper view.

Notes
-----
- This script will fail if sqlite_stat4 does not exist.
- Typical workflow: run census-analyze.sqlite.sql first (ANALYZE), then this.
================================================================================
*/

PRAGMA foreign_keys = ON;

WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/query-planner/stat4.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'rows',
      (SELECT json_group_array(
                json_object(
                  'tbl', tbl,
                  'idx', idx,
                  'neq', neq,
                  'nlt', nlt,
                  'ndlt', ndlt,
                  'sample', hex(sample)
                )
              )
         FROM sqlite_stat4)
  ),
  json_object(
    'generator','census-stat4.sqlite.sql',
    'source','sqlite_stat4',
    'sample_encoding','hex'
  ),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/query-planner/summary.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'has_sqlite_stat4', 1,
    'notes', 'STAT4 snapshot captured'
  ),
  json_object('generator','census-stat4.sqlite.sql'),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

DROP VIEW IF EXISTS sqliteaide_query_planner_stat4_row;
CREATE VIEW IF NOT EXISTS sqliteaide_query_planner_stat4_row AS
SELECT
  json_extract(d.contents,'$.generated_on') AS generated_on,
  json_extract(r.value,'$.tbl')            AS tbl,
  json_extract(r.value,'$.idx')            AS idx,
  json_extract(r.value,'$.neq')            AS neq,
  json_extract(r.value,'$.nlt')            AS nlt,
  json_extract(r.value,'$.ndlt')           AS ndlt,
  json_extract(r.value,'$.sample')         AS sample_hex
FROM ".sqlite-aide.d" AS d,
     json_each(d.contents,'$.rows') AS r
WHERE d.path = 'sqlite-aide.d/census/query-planner/stat4.auto.json';
