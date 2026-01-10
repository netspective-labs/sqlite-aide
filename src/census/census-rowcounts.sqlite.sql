-- census-rowcounts.sqlite.sql
/*
================================================================================
SQLite Aide Census: exact row counts (plan + publish, no extra tables)
================================================================================

Purpose
-------
Computes exact per-table row counts without creating any extra physical tables.
Because SQLite cannot execute dynamic SQL within SQL, this script is two-phase:

Phase A (generate plan):
  Writes SQL statements into:
    sqlite-aide.d/rowcounts.plan.sql

  The plan, when executed by the caller, computes COUNT(*) for each table and
  UPSERTs a per-table artifact row into ".sqlite-aide.d" at:
    sqlite-aide.d/rowcount/<table>.json

Phase B (publish aggregation):
  Aggregates the per-table artifacts into:
    sqlite-aide.d/table-rowcounts.auto.json

Important dependency
--------------------
Depends on ".sqlite-aide.d" created by:
  sqlite3 your.db < lib/sql/core-ddl.sqlite.sql

Usage (recommended)
-------------------
1) Generate the plan:
     sqlite3 your.db < census-rowcounts.sqlite.sql

2) Read the plan SQL from ".sqlite-aide.d" and execute it (caller responsibility).
   Example using sqlite3:
     sqlite3 your.db "SELECT contents FROM \".sqlite-aide.d\" WHERE path='sqlite-aide.d/census/rowcounts.plan.sql';"
   Then execute the returned SQL text (copy/paste, or programmatically).

3) Re-run to publish aggregation:
     sqlite3 your.db < census-rowcounts.sqlite.sql

Idempotency
-----------
Safe to re-run. It regenerates the plan and republishes aggregation.
Per-table rowcount artifacts are UPSERTed by path.

Notes
-----
- This script itself does not calculate counts; the generated plan does.
- The plan will be O(sum(table sizes)) because it runs COUNT(*) for each table.
================================================================================
*/

PRAGMA foreign_keys = ON;

-- Phase A: generate plan SQL (one statement per table)
WITH
  _now AS (SELECT datetime('now') AS ts),
  _tables AS (
    SELECT tl.name AS table_name
    FROM pragma_table_list AS tl
    WHERE tl.type='table'
      AND tl.name NOT LIKE 'sqlite_%'
  ),
  _plan AS (
    SELECT
      'INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at) ' ||
      'VALUES (' ||
        quote('sqlite-aide.d/census/rowcount/' || t.table_name || '.json') || ', ' ||
        'json_object(' ||
          quote('table_name') || ', ' || quote(t.table_name) || ', ' ||
          quote('row_count')  || ', (SELECT COUNT(*) FROM "' || replace(t.table_name, '"', '""') || '"), ' ||
          quote('counted_on') || ', ' || quote((SELECT ts FROM _now)) ||
        '), ' ||
        'json_object(' ||
          quote('generator') || ', ' || quote('census-rowcounts.sqlite.sql') || ', ' ||
          quote('counted_on') || ', ' || quote((SELECT ts FROM _now)) ||
        '), ' ||
        quote((SELECT ts FROM _now)) ||
      ') ' ||
      'ON CONFLICT(path) DO UPDATE SET ' ||
        'contents=excluded.contents, elaboration=excluded.elaboration, modified_at=excluded.modified_at;'
      AS stmt
    FROM _tables AS t
    ORDER BY t.table_name
  )
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/rowcounts.plan.sql',
  (
    SELECT
      '-- Generated on ' || (SELECT ts FROM _now) || char(10) ||
      '-- Execute these statements to compute exact row counts.' || char(10) ||
      '-- Each statement upserts a row into ".sqlite-aide.d" under sqlite-aide.d/rowcount/<table>.json' || char(10) ||
      '-- After executing, re-run census-rowcounts.sqlite.sql to publish aggregation.' || char(10) || char(10) ||
      group_concat(stmt, char(10))
    FROM _plan
  ),
  json_object(
    'generator','census-rowcounts.sqlite.sql',
    'generated_on',(SELECT ts FROM _now),
    'notes','Execute contents to persist per-table rowcount JSON rows under sqlite-aide.d/rowcount/*.json'
  ),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- Phase B: publish aggregation from per-table sqlite-aide.d/rowcount/*.json rows
WITH
  _now AS (SELECT datetime('now') AS ts),
  _rows AS (
    SELECT
      d.path,
      json_extract(d.contents,'$.table_name') AS table_name,
      json_extract(d.contents,'$.row_count')  AS row_count,
      json_extract(d.contents,'$.counted_on') AS counted_on
    FROM ".sqlite-aide.d" AS d
    WHERE d.path LIKE 'sqlite-aide.d/census/rowcount/%.json'
  )
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/table-rowcounts.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'tables',
      coalesce(
        (SELECT json_group_object(
                  r.table_name,
                  json_object(
                    'table_name', r.table_name,
                    'row_count',  r.row_count,
                    'counted_on', r.counted_on
                  )
                )
           FROM _rows AS r),
        json_object()
      )
  ),
  json_object(
    'generator','census-rowcounts.sqlite.sql',
    'notes','Aggregation reflects whatever per-table rows exist at sqlite-aide.d/rowcount/*.json'
  ),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- Tabular projection of aggregated exact row counts
DROP VIEW IF EXISTS sqliteaide_table_rowcount_row;
CREATE VIEW IF NOT EXISTS sqliteaide_table_rowcount_row AS
SELECT
  json_extract(d.contents,'$.generated_on') AS published_on,
  t.key                                     AS table_name,
  json_extract(t.value,'$.row_count')       AS row_count,
  json_extract(t.value,'$.counted_on')      AS counted_on
FROM ".sqlite-aide.d" AS d,
     json_each(d.contents,'$.tables') AS t
WHERE d.path = 'sqlite-aide.d/census/table-rowcounts.auto.json';
