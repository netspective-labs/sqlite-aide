![logo](project-logo.png)

SQLite-Aide is a collection of SQL-native helpers and “aides” designed to make
SQLite databases easier to introspect, reason about, and operate against in a
principled way.

The core idea behind SQLite-Aide is that SQLite already contains a rich amount
of structural and operational knowledge, but that knowledge is fragmented across
pragmas, virtual tables, and implicit behavior. SQLite-Aide consolidates that
knowledge into explicit, queryable artifacts stored inside the database itself,
without relying on sqlite3 shell features, external scripts, or
application-specific tooling.

The repository is intentionally structured as a growing toolbox rather than a
single monolithic system. Each aide focuses on a narrow concern and can be
adopted independently.

## What SQLite-Aide provides today

The initial focus of the repository is on two foundational aides.

### Information schema

SQLite-Aide introduces a SQL-native information schema for SQLite. This captures
a complete snapshot of the database structure, including tables, columns,
indexes, foreign keys, views, triggers, and derived relationships. The snapshot
is stored as structured JSON inside the database and is reflected back out as
relational views so the schema can be queried like regular tables.

This provides a canonical, machine-readable description of the database that can
be used for documentation, schema diffing, tooling, UI generation, and automated
reasoning.

### Census pack

On top of the schema snapshot, SQLite-Aide provides a census pack: a set of
optional scripts that collect operational and diagnostic metadata when supported
by the SQLite build. These include query planner statistics, storage layout
information, and exact row counts. Each census collector is explicit about its
prerequisites and side effects and publishes its results as durable artifacts
inside the database.

Census scripts are designed to be opt-in, transparent, and auditable. Nothing
runs implicitly and nothing depends on sqlite3 shell conditionals.

## Design principles

SQLite-Aide follows a small set of guiding principles.

- SQL-native. Everything is implemented in plain SQL. No shell directives, no
  hidden dynamic execution, and no reliance on external runtimes.
- Database-resident. Generated metadata lives inside the database itself. This
  makes it portable, versionable, and inspectable using the same tools as
  application data.
- Explicit and idempotent. Scripts are safe to re-run and update well-known
  artifact locations. Side effects are documented and intentional.
- Build-aware. Optional features are isolated so that “always safe” scripts do
  not break on minimal or older SQLite builds. More advanced collectors are
  clearly separated.
- Composable. Each aide can be run independently or combined with others.
  Consumers decide how much evidence they want to collect.

## What SQLite-Aide is not

- SQLite-Aide is not an ORM.
- SQLite-Aide does not attempt to replace application-level schema management.
- SQLite-Aide does not hide SQLite behavior behind abstractions.

Instead, it makes SQLite’s existing behavior explicit and queryable.

## Who this is for

SQLite-Aide is useful for:

- Developers who want reliable schema introspection without parsing DDL
- Tooling authors building admin consoles, schema browsers, or generators
- Teams that need auditable database metadata for testing, assurance, or
  documentation
- Anyone treating SQLite as an embedded system component rather than a black box

## Future direction

The repository is expected to grow over time with additional aides, such as:

- Migration and schema evolution helpers
- Consistency and invariants checking
- Lightweight observability and diagnostics
- Reflection helpers for UIs and documentation systems
- Evidence capture for testing and compliance workflows

Each new aide will follow the same core philosophy: SQL-first, explicit,
database-resident, and composable.
