/*
views-for-dotted-tables.sql

Strategy
--------
This script enforces a clear separation between physical storage and query access.

• Physical tables are named with a leading dot (for example ".customer").
  This makes direct access inconvenient because such names must be quoted.
• All querying is intended to go through views, not tables.
• For every dotted table, a corresponding “wrapper view” is generated
  with the same name minus the leading dot (for example "customer").
• Wrapper views explicitly list columns, avoiding SELECT * and protecting
  consumers from accidental schema drift.
• Views are dropped and recreated on every run so rerunning this script
  always produces a clean, deterministic result.

Execution model
---------------
SQLite cannot execute dynamically generated SQL inside a query.
This file therefore *generates* the required DDL as rows.
Typical usage is:
  1. Run this script to emit DROP VIEW / CREATE VIEW statements.
  2. Execute the emitted statements (manually, via sqlite3 CLI, or via code)
     inside a single transaction.
*/

WITH dotted_tables AS (
  SELECT
    s.name AS table_name,
    substr(s.name, 2) AS view_name
  FROM sqlite_schema AS s
  WHERE s.type = 'table'
    AND s.name LIKE '.%'
    AND s.name NOT LIKE 'sqlite_%'
),
column_lists AS (
  SELECT
    dt.table_name,
    dt.view_name,
    (
      SELECT group_concat(quote(p.name), ', ')
      FROM pragma_table_info(dt.table_name) AS p
      ORDER BY p.cid
    ) AS col_list
  FROM dotted_tables AS dt
),
ddl AS (
  -- Drop existing wrapper views
  SELECT
    dt.view_name AS object_name,
    10 AS ord,
    'DROP VIEW IF EXISTS ' || quote(dt.view_name) || ';' AS sql
  FROM dotted_tables AS dt

  UNION ALL

  -- Recreate wrapper views with explicit column lists
  SELECT
    cl.view_name AS object_name,
    20 AS ord,
    'CREATE VIEW ' || quote(cl.view_name)
    || ' AS SELECT '
    || cl.col_list
    || ' FROM '
    || quote(cl.table_name)
    || ';' AS sql
  FROM column_lists AS cl
  WHERE cl.col_list IS NOT NULL
    AND cl.col_list <> ''
)
SELECT sql
FROM ddl
ORDER BY object_name, ord;
