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
