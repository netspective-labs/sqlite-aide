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

## `cat.ts` and SQL Package Auto-Compilation

`cat.ts` is a small Deno module that behaves like a programmable Unix `cat`.

It concatenates text sources into a single output stream. Sources can be:

- local files
- file: URLs
- remote http(s) URLs
- generated text

Example:

```ts
await new Cat()
  .add("a.sql", "b.sql", "https://example.com/c.sql")
  .writeToStdout();
```

This produces one combined SQL stream.

### Keeping SQL modular

SQL is authored as small, focused files:

```
src/
  core-ddl.sqlite.sql
  info-schema.sqlite.sql
  views/
    patients.sql
    encounters.sql
```

Nothing is pre-bundled. Packaging is explicit and mechanical.

Traditional SQL projects tend to either:

- Collapse everything into one giant SQL file, which becomes hard to maintain
- Or keep many small SQL files, which are hard to consume as a unit

`cat.ts` allows us to keep SQL modular and human-friendly while still producing
stable, consumable packages.

Individual SQL files remain small, focused, and easy to review. Packaging
happens later, mechanically, and repeatably.

### `*.cat.ts` packagers

A `*.cat.ts` file defines one SQL package with multiple "included" sources
either from either local files or remotes or hybrid.

Example:

```ts
// lib/info-schema.cat.ts
export default new Cat().add(
  "../src/core-ddl.sqlite.sql",
  "../src/info-schema.sqlite.sql",
);
```

Each packager produces pulls in multiple sources but produces exactly one SQL
artifact.

Naming is convention-based:

```
info-schema.cat.ts
→ `info-schema.cat.auto.sqlite.sql`
```

### Auto-compilation

autoCompile finds executable scripts, runs them, and captures STDOUT as text.

Example generator:

```sh
#!/usr/bin/env bash
echo "CREATE VIEW example AS SELECT 1;"
```

Example auto-compile usage:

```ts
for await (
  const gen of cat.autoCompile([
    { glob: "sql/**/*.gen.sql" },
  ])
) {
  cat.addText(gen.text, gen.label);
}
```

Generated SQL is treated exactly like static SQL.

### Compiling packages via CI/CD

All packages are built via a single task:

```sh
deno task compile-packages
```

This task:

- finds all `*.cat.ts` files
- executes them
- materializes their .cat.auto.sqlite.sql outputs

**Local vs remote behavior**

Local execution:

```sh
./lib/info-schema.cat.ts
```

Result:

- writes `info-schema.cat.auto.sqlite.sql` next to the module
- prints the file path only

Remote execution:

```sh
deno run https://example.com/sql/info-schema.cat.ts
```

Result:

- emits SQL to STDOUT
- no filesystem writes

This enables simple consumption directly from remotes, with full revision
control:

```sh
export SCHEMA_VERSION=/v0.1.1
curl https://raw.githubusercontent.com/netspective-labs/sqlite-aide/refs/tags/${SCHEMA_VERSION}/lib/info-schema.auto.sqlite.sql | sqlite3 db.sqlite
```

Or, always grab the latest (might be cached):

```sh
curl https://raw.githubusercontent.com/netspective-labs/sqlite-aide/refs/heads/main/lib/info-schema.auto.sqlite.sql | sqlite3 db.sqlite
```

### Benefits

- SQL stays small and readable
- Packaging is deterministic and reproducible
- No custom build system
- Packages are downloadable, pipeable, and cacheable
- `cat.ts` is a build primitive, not a framework

## Future direction

The repository is expected to grow over time with additional aides, such as:

- Migration and schema evolution helpers
- Consistency and invariants checking
- Lightweight observability and diagnostics
- Reflection helpers for UIs and documentation systems
- Evidence capture for testing and compliance workflows

Each new aide will follow the same core philosophy: SQL-first, explicit,
database-resident, and composable.
