-- lib/sqlite/info-schema-destroy.sqlite.sql
-- sqlite3 your.db < lib/sqlite/info-schema-destroy.sqlite.sql

PRAGMA foreign_keys = OFF;

DROP VIEW IF EXISTS sqliteaide_schema_info_json_pretty;

DROP VIEW IF EXISTS sqliteaide_schema_info_table;
DROP VIEW IF EXISTS sqliteaide_schema_info_table_column;
DROP VIEW IF EXISTS sqliteaide_schema_info_view;
DROP VIEW IF EXISTS sqliteaide_schema_info_view_column;
DROP VIEW IF EXISTS sqliteaide_schema_info_index;
DROP VIEW IF EXISTS sqliteaide_schema_info_index_column;
DROP VIEW IF EXISTS sqliteaide_schema_info_foreign_key;
DROP VIEW IF EXISTS sqliteaide_schema_info_table_trigger;
DROP VIEW IF EXISTS sqliteaide_schema_info_trigger;
DROP VIEW IF EXISTS sqliteaide_schema_info_relation;

DELETE FROM ".sqlite-aide.d" WHERE path IN ('sqlite-aide.d/info-schema.auto.json');

PRAGMA foreign_keys = ON;
