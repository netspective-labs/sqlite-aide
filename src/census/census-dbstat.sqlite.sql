-- census-dbstat.sqlite.sql
/*
================================================================================
SQLite Aide Census: dbstat snapshot (requires dbstat module)
================================================================================

Purpose
-------
Snapshots dbstat (if your SQLite build includes the dbstat virtual table module)
into ".sqlite-aide.d" as:

  sqlite-aide.d/storage/dbstat.auto.json
  sqlite-aide.d/storage/summary.auto.json

Important dependency
--------------------
Depends on ".sqlite-aide.d" created by:
  sqlite3 your.db < lib/sql/core-ddl.sqlite.sql

Usage
-----
Run only when the dbstat virtual table is available (caller responsibility):
  sqlite3 your.db < census-dbstat.sqlite.sql

Idempotency
-----------
Safe to re-run. It UPSERTs the same artifact paths and recreates helper view.

Notes
-----
- This script will fail if dbstat is not available.
================================================================================
*/

PRAGMA foreign_keys = ON;

WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/storage/dbstat.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'rows',
      (SELECT json_group_array(
                json_object(
                  'name', name,
                  'path', path,
                  'pageno', pageno,
                  'pagetype', pagetype,
                  'ncell', ncell,
                  'payload', payload,
                  'unused', unused,
                  'mx_payload', mx_payload
                )
              )
         FROM dbstat)
  ),
  json_object('generator','census-dbstat.sqlite.sql','source','dbstat'),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/storage/summary.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'objects',
      (
        SELECT json_group_array(
                 json_object(
                   'name', s.name,
                   'pages', s.pages,
                   'payload_sum', s.payload_sum,
                   'unused_sum', s.unused_sum
                 )
               )
        FROM (
          SELECT
            name,
            COUNT(*)      AS pages,
            SUM(payload)  AS payload_sum,
            SUM(unused)   AS unused_sum
          FROM dbstat
          GROUP BY name
          ORDER BY COUNT(*) DESC
        ) AS s
      )
  ),
  json_object('generator','census-dbstat.sqlite.sql'),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

DROP VIEW IF EXISTS sqliteaide_storage_object_summary;
CREATE VIEW IF NOT EXISTS sqliteaide_storage_object_summary AS
SELECT
  json_extract(s.contents,'$.generated_on') AS generated_on,
  json_extract(o.value,'$.name')            AS object_name,
  json_extract(o.value,'$.pages')           AS pages,
  json_extract(o.value,'$.payload_sum')     AS payload_sum,
  json_extract(o.value,'$.unused_sum')      AS unused_sum
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.objects') AS o
WHERE s.path = 'sqlite-aide.d/census/storage/summary.auto.json';
