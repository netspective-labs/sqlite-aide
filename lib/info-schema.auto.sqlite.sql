/*
================================================================================
.sqlite-aide.d — SQLite Aide Internal Artifact & Metadata Store
================================================================================

Overview
--------
".sqlite-aide.d" is a general-purpose persistence mechanism. It provides a single,
SQL-native table for storing structured artifacts, metadata, and generated
content directly inside a SQLite database.

Rather than creating many ad hoc tables or relying on external files,
Apps components write durable outputs into ".sqlite-aide.d" using logical paths.
Each row behaves like a namespaced, versioned artifact that can be queried,
rendered, diffed, or transported as part of the database itself.

This table is intentionally generic and stable. It is expected to be reused by
many independent subsystems over time.

Table Shape
-----------
path
  Logical identifier for the artifact, treated like a filesystem-style path.
  Examples:
    sqlite-aide.d/info-schema.auto.json
    sqlite-aide.d/db-stats.auto.json
    sqlite-aide.d/ui/console-state.json
    sqlite-aide.d/cache/precomputed.sql

contents
  The primary payload of the artifact.
  Stored untyped so it can hold JSON, SQL text, or other structured content.

elaboration
  Optional JSON metadata describing provenance, intent, or context.
  Typical fields include generator, timestamps, source notes, or assumptions.

created_at
  Timestamp when the artifact row was first created.

modified_at
  Timestamp when the artifact was last updated.

Usage Across Apps
-----------------
".sqlite-aide.d" is used wherever apps needs durable, queryable state that is not part
of application data or core schema. It acts as a shared “attachment surface”
for tooling, automation, UI state, and introspection.

One concrete example is the census playbooks under:
  lib/playbook/sqlpage/console/census

Those scripts use ".sqlite-aide.d" to store introspection and diagnostic artifacts
(such as schema snapshots or statistics) without introducing new tables or
external dependencies. Census is just one consumer; the same mechanism is
available to any application feature or extension.

Design Intent
-------------
- General-purpose and reusable across modules
- SQL-first and database-resident
- Safe to extend without coordination via path namespaces
- `path` and `contents` are named consistent with SQLPage's sqlpage_files table
- Idempotent by design (UPSERT by path)
- Suitable for both human-facing and machine-facing artifacts

================================================================================
*/

CREATE TABLE IF NOT EXISTS ".sqlite-aide.d" (
  path        TEXT PRIMARY KEY,
  contents    NOT NULL,
  elaboration JSON,
  created_at  datetime NOT NULL DEFAULT (datetime('now')),
  modified_at datetime
);

-- info-schema.sqlite.sql
/*
================================================================================
SQLite Aide Census: Schema Snapshot (always safe + idempotent)
================================================================================

Purpose
-------
Captures a complete, queryable JSON snapshot of the SQLite schema and stores it
in ".sqlite-aide.d" as:

  sqlite-aide.d/info-schema.auto.json

Also captures lightweight, always-safe database metadata and table census hints:

  sqlite-aide.d/db-stats.auto.json
  sqlite-aide.d/table-stats.auto.json   (safe: includes exact_count_sql strings)

Creates relational projection views over sqlite-aide.d/info-schema.auto.json so the
schema can be queried as tabular rows.

Important dependency
--------------------
This script depends on the internal artifact table ".sqlite-aide.d" which must already
exist. Create it once per DB by running:

  sqlite3 your.db < lib/sql/core-ddl.sqlite.sql

Usage
-----
  sqlite3 your.db < info-schema.sqlite.sql

Idempotency
-----------
Safe to re-run. It UPSERTs the same artifact paths and recreates views.

Notes
-----
- No sqlite3 shell directives are used.
- No optional modules are required.
- Does not run ANALYZE and does not query sqlite_stat* or dbstat.
================================================================================
*/

PRAGMA foreign_keys = ON;

-- 1) Canonical schema JSON artifact: sqlite-aide.d/info-schema.auto.json
WITH
  _meta AS (
    SELECT
      'main'            AS schema_name,
      datetime('now')   AS generated_on,
      sqlite_version()  AS sqlite_version
  ),
  _doc AS (
    SELECT json_object(
      'schema_name',     (SELECT schema_name FROM _meta),
      'generated_on',    (SELECT generated_on FROM _meta),
      'sqlite_version',  (SELECT sqlite_version FROM _meta),

      'databases',
        (SELECT json_group_array(
                  json_object('seq', seq, 'db_name', name, 'db_file', file)
                )
           FROM pragma_database_list),

      'collations',
        (SELECT json_group_array(
                  json_object('seq', seq, 'name', name)
                )
           FROM pragma_collation_list),

      'tables',
      (
        SELECT json_group_object(
                 tl.name,
                 json_object(
                   'type', tl.type,
                   'strict', tl.strict,

                   'without_rowid',
                     CASE
                       WHEN upper(coalesce(
                              (SELECT s.sql
                                 FROM sqlite_schema AS s
                                WHERE s.type='table' AND s.name=tl.name),
                              ''
                            )) LIKE '%WITHOUT ROWID%'
                       THEN 1 ELSE 0
                     END,

                   'ncol', tl.ncol,

                   'sql',
                     (SELECT s.sql
                        FROM sqlite_schema AS s
                       WHERE s.type='table' AND s.name=tl.name),

                   'columns',
                     (SELECT json_group_array(
                               json_object(
                                 'cid', x.cid,
                                 'name', x.name,
                                 'type', x.type,
                                 'notnull', x."notnull",
                                 'dflt_value', x.dflt_value,
                                 'pk', x.pk,
                                 'hidden', x.hidden
                               )
                             )
                        FROM pragma_table_xinfo(tl.name) AS x),

                   'indexes',
                     (SELECT json_group_array(
                               json_object(
                                 'name', il.name,
                                 'origin', il.origin,
                                 'unique', il."unique",
                                 'partial', il.partial,

                                 'sql',
                                   (SELECT s.sql
                                      FROM sqlite_schema AS s
                                     WHERE s.type='index' AND s.name=il.name),

                                 'columns',
                                   (SELECT json_group_array(
                                             json_object(
                                               'seqno', ixi.seqno,
                                               'cid', ixi.cid,
                                               'name', ixi.name,
                                               'desc', ixi."desc",
                                               'coll', ixi.coll,
                                               'key', ixi."key"
                                             )
                                           )
                                      FROM pragma_index_xinfo(il.name) AS ixi)
                               )
                             )
                        FROM pragma_index_list(tl.name) AS il),

                   'foreign_keys',
                     (SELECT json_group_array(
                               json_object(
                                 'id', fk.id,
                                 'seq', fk.seq,
                                 'from', fk."from",
                                 'to', fk."to",
                                 'table', fk."table",
                                 'on_update', fk.on_update,
                                 'on_delete', fk.on_delete,
                                 'match', fk."match"
                               )
                             )
                        FROM pragma_foreign_key_list(tl.name) AS fk),

                   'triggers',
                     (SELECT json_group_array(
                               json_object(
                                 'name', t.name,
                                 'sql',  t.sql
                               )
                             )
                        FROM sqlite_schema AS t
                       WHERE t.type='trigger' AND t.tbl_name=tl.name)
                 )
               )
          FROM pragma_table_list AS tl
         WHERE tl.type='table'
           AND tl.name NOT LIKE 'sqlite_%'
      ),

      'views',
      (
        SELECT json_group_object(
                v.name,
                json_object(
                  'type', 'view',
                  'sql',  v.sql,

                  'ncol',
                    (SELECT COUNT(*) FROM pragma_table_xinfo(v.name)),

                  'columns',
                    (SELECT json_group_array(
                              json_object(
                                'cid', x.cid,
                                'name', x.name,
                                'type', x.type,
                                'notnull', x."notnull",
                                'dflt_value', x.dflt_value,
                                'pk', x.pk,
                                'hidden', x.hidden
                              )
                            )
                       FROM pragma_table_xinfo(v.name) AS x),

                  'dependencies', json('[]')
                )
              )
          FROM sqlite_schema AS v
         WHERE v.type='view'
           AND v.name NOT LIKE 'sqlite_%'
      ),

      'virtual_tables',
      (
        SELECT json_group_object(
                 tl.name,
                 json_object(
                   'type', tl.type,
                   'sql',
                     (SELECT s.sql
                        FROM sqlite_schema AS s
                       WHERE s.type='table' AND s.name=tl.name)
                 )
               )
          FROM pragma_table_list AS tl
         WHERE tl.type='virtual'
           AND tl.name NOT LIKE 'sqlite_%'
      ),

      'triggers',
      (
        SELECT json_group_object(
                 t.name,
                 json_object(
                   'table', t.tbl_name,
                   'sql',   t.sql
                 )
               )
          FROM sqlite_schema AS t
         WHERE t.type='trigger'
           AND t.name NOT LIKE 'sqlite_%'
      ),

      -- Relations grouped by FK id (supports composite FKs)
      'relations',
      (
        SELECT json_group_array(
                 json_object(
                   'name', printf('%s_fk_%s_%s', from_table, fk_id, to_table),
                   'from_table', from_table,
                   'from_columns', from_cols,
                   'to_table', to_table,
                   'to_columns', to_cols,
                   'type', 'many_to_one',
                   'on_update', on_update,
                   'on_delete', on_delete,
                   'match', match
                 )
               )
          FROM (
            SELECT
              tbl.name       AS from_table,
              fk.id          AS fk_id,
              fk."table"     AS to_table,
              fk.on_update   AS on_update,
              fk.on_delete   AS on_delete,
              fk."match"     AS match,
              json_group_array(fk."from") AS from_cols,
              json_group_array(fk."to")   AS to_cols
            FROM sqlite_schema AS tbl
            JOIN pragma_foreign_key_list(tbl.name) AS fk
            WHERE tbl.type='table'
              AND tbl.name NOT LIKE 'sqlite_%'
            GROUP BY
              tbl.name, fk.id, fk."table", fk.on_update, fk.on_delete, fk."match"
          )
      )
    ) AS contents_json
  )
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/info-schema.auto.json',
  (SELECT contents_json FROM _doc),
  json_object(
    'generator', 'info-schema.sqlite.sql',
    'generated_on', (SELECT generated_on FROM _meta),
    'sqlite_version', (SELECT sqlite_version FROM _meta)
  ),
  (SELECT generated_on FROM _meta)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- Pretty rendering view (stored JSON is compact for efficiency)
DROP VIEW IF EXISTS sqliteaide_schema_info_json_pretty;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_json_pretty AS
SELECT
  path,
  json_pretty(contents) AS contents_pretty,
  created_at,
  modified_at,
  elaboration
FROM ".sqlite-aide.d"
WHERE path = 'sqlite-aide.d/info-schema.auto.json';

-- 2) DB stats (usually safe pragmas)
WITH _now AS (SELECT datetime('now') AS ts)
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/db-stats.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),

    'page_size',      (SELECT page_size      FROM pragma_page_size),
    'page_count',     (SELECT page_count     FROM pragma_page_count),
    'freelist_count', (SELECT freelist_count FROM pragma_freelist_count),

    'auto_vacuum',    (SELECT auto_vacuum    FROM pragma_auto_vacuum),
    'journal_mode',   (SELECT journal_mode   FROM pragma_journal_mode),
    'synchronous',    (SELECT synchronous    FROM pragma_synchronous),
    'temp_store',     (SELECT temp_store     FROM pragma_temp_store),
    'cache_size',     (SELECT cache_size     FROM pragma_cache_size),

    -- TODO: figure out why this is erroring
    -- 'mmap_size',      (SELECT mmap_size      FROM pragma_mmap_size),

    'encoding',       (SELECT encoding       FROM pragma_encoding),
    'foreign_keys',   (SELECT foreign_keys   FROM pragma_foreign_keys),
    'recursive_triggers', (SELECT recursive_triggers FROM pragma_recursive_triggers),

    'schema_version', (SELECT schema_version FROM pragma_schema_version),
    'user_version',   (SELECT user_version   FROM pragma_user_version),
    'application_id', (SELECT application_id FROM pragma_application_id)
  ),
  json_object(
    'generator', 'info-schema.sqlite.sql',
    'notes', 'Database-level operational and file-layout settings'
  ),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- 3) Table stats (always safe: stores deferred exact_count_sql strings)
WITH
  _now AS (SELECT datetime('now') AS ts),
  _tables AS (
    SELECT
      tl.name AS table_name,
      (SELECT s.sql FROM sqlite_schema AS s WHERE s.type='table' AND s.name=tl.name) AS create_sql
    FROM pragma_table_list AS tl
    WHERE tl.type='table' AND tl.name NOT LIKE 'sqlite_%'
  )
INSERT INTO ".sqlite-aide.d"(path, contents, elaboration, modified_at)
VALUES (
  'sqlite-aide.d/census/table-stats.auto.json',
  json_object(
    'generated_on', (SELECT ts FROM _now),
    'tables',
    (
      SELECT json_group_object(
               t.table_name,
               json_object(
                 'table_name', t.table_name,
                 'exact_count_sql', 'SELECT COUNT(*) AS row_count FROM ' || quote(t.table_name) || ';',
                 'has_autoincrement',
                   CASE WHEN upper(coalesce(t.create_sql,'')) LIKE '%AUTOINCREMENT%' THEN 1 ELSE 0 END
               )
             )
      FROM _tables AS t
    )
  ),
  json_object(
    'generator', 'info-schema.sqlite.sql',
    'notes', 'Stores exact_count_sql (deferred execution) and light hints'
  ),
  (SELECT ts FROM _now)
)
ON CONFLICT(path) DO UPDATE SET
  contents    = excluded.contents,
  elaboration = excluded.elaboration,
  modified_at = excluded.modified_at;

-- 4) Relational projection views (schema JSON)
DROP VIEW IF EXISTS sqliteaide_schema_info_table;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_table AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  t.key                                         AS table_name,
  json_extract(t.value,'$.type')                AS type,
  json_extract(t.value,'$.ncol')                AS ncol,
  json_extract(t.value,'$.strict')              AS strict,
  json_extract(t.value,'$.without_rowid')       AS without_rowid,
  json_extract(t.value,'$.sql')                 AS definition_sql
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.tables') AS t
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_table_column;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_table_column AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  t.key                                         AS table_name,
  json_extract(c.value,'$.cid')                 AS cid,
  json_extract(c.value,'$.name')                AS column_name,
  json_extract(c.value,'$.type')                AS column_type,
  json_extract(c.value,'$.notnull')             AS not_null,
  json_extract(c.value,'$.dflt_value')          AS dflt_value,
  json_extract(c.value,'$.pk')                  AS part_of_pk,
  json_extract(c.value,'$.hidden')              AS hidden
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.tables') AS t,
     json_each(t.value, '$.columns')   AS c
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_view;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_view AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  v.key                                         AS view_name,
  json_extract(v.value,'$.type')                AS type,
  json_extract(v.value,'$.sql')                 AS definition_sql
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.views') AS v
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_view_column;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_view_column AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  v.key                                         AS view_name,
  json_extract(vc.value,'$.cid')                AS cid,
  json_extract(vc.value,'$.name')               AS column_name,
  json_extract(vc.value,'$.type')               AS column_type,
  json_extract(vc.value,'$.notnull')            AS not_null,
  json_extract(vc.value,'$.dflt_value')         AS dflt_value
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.views')    AS v,
     json_each(v.value, '$.columns')     AS vc
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_index;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_index AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  t.key                                         AS table_name,
  json_extract(i.value,'$.name')                AS index_name,
  json_extract(i.value,'$.origin')              AS origin,
  json_extract(i.value,'$.unique')              AS is_unique,
  json_extract(i.value,'$.partial')             AS is_partial,
  json_extract(i.value,'$.sql')                 AS definition_sql
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.tables')          AS t,
     json_each(t.value, '$.indexes')            AS i
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_index_column;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_index_column AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  t.key                                         AS table_name,
  json_extract(i.value,'$.name')                AS index_name,
  json_extract(ic.value,'$.seqno')              AS seqno,
  json_extract(ic.value,'$.cid')                AS cid,
  json_extract(ic.value,'$.name')               AS column_name,
  json_extract(ic.value,'$.desc')               AS is_desc,
  json_extract(ic.value,'$.coll')               AS collation_name,
  json_extract(ic.value,'$.key')                AS is_key_column
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.tables')          AS t,
     json_each(t.value, '$.indexes')            AS i,
     json_each(i.value, '$.columns')            AS ic
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_foreign_key;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_foreign_key AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  t.key                                         AS table_name,
  json_extract(fk.value,'$.id')                 AS fk_id,
  json_extract(fk.value,'$.seq')                AS seq,
  json_extract(fk.value,'$.from')               AS from_column,
  json_extract(fk.value,'$.to')                 AS to_column,
  json_extract(fk.value,'$.table')              AS ref_table,
  json_extract(fk.value,'$.on_update')          AS on_update,
  json_extract(fk.value,'$.on_delete')          AS on_delete,
  json_extract(fk.value,'$.match')              AS match
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.tables')          AS t,
     json_each(t.value, '$.foreign_keys')       AS fk
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_table_trigger;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_table_trigger AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  t.key                                         AS table_name,
  json_extract(tr.value,'$.name')               AS trigger_name,
  json_extract(tr.value,'$.sql')                AS definition_sql
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.tables')          AS t,
     json_each(t.value, '$.triggers')           AS tr
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_trigger;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_trigger AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  trg.key                                       AS trigger_name,
  json_extract(trg.value,'$.table')             AS table_name,
  json_extract(trg.value,'$.sql')               AS definition_sql
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.triggers')        AS trg
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';

DROP VIEW IF EXISTS sqliteaide_schema_info_relation;
CREATE VIEW IF NOT EXISTS sqliteaide_schema_info_relation AS
SELECT
  json_extract(s.contents,'$.schema_name')       AS schema_name,
  json_extract(r.value,'$.name')                AS relation_name,
  json_extract(r.value,'$.from_table')          AS from_table,
  json_extract(r.value,'$.to_table')            AS to_table,
  json_extract(r.value,'$.type')                AS relation_type,
  json_extract(r.value,'$.on_update')           AS on_update,
  json_extract(r.value,'$.on_delete')           AS on_delete,
  json_extract(r.value,'$.match')               AS match,
  json_extract(r.value,'$.from_columns')        AS from_columns_json,
  json_extract(r.value,'$.to_columns')          AS to_columns_json
FROM ".sqlite-aide.d" AS s,
     json_each(s.contents, '$.relations')       AS r
WHERE s.path = 'sqlite-aide.d/info-schema.auto.json';
