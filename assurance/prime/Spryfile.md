SQLfolio end-to-end (`e2e`) assurance example.

- `code DEFAULTS` sets up the presets for how to treat fenced code blocks that
  have no arguments.
  - `sql` blocks are obvious
  - `-X prime` looks up the `prime` spawnable engine (`-X` and `--executable`
    are synonyms) and indicate that the fenced code cell is an executable task
- `yaml CONNECTIONS` sets up the executable cells' shared configuration
- Like all the `sql` cells, `bash clean` is a task but `--graph` indicates that
  it's part of the "housekeeping" group of tasks so it won't be run in the main
  block (it would have to be called specifically)

```code DEFAULTS
sql * --interpolate --injectable -X prime --capture
```

```yaml CONNECTIONS
spawnables:
  prime:
    engine: sqlite
    file: test.tmp.db
```

We want to work on a copy of a real database but we make a copy since we'll be
modifying it.

```bash init
cp ../fixtures/chinook.db test.tmp.db
```

Create `sql` tasks which can be run with `spry rb run` or `spry rb task`. What's
in `REMARKS` will be in the body of each expanded cell.

```contribute expand
# use -I or --interpolate if you want dynamic expansion
REMARKS if you use `spry rb report` cell will contain will have the output of the execution
sql core-ddl -X prime --include ../../src/core-ddl.sqlite.sql
sql info-schema -X prime --include ../../src/info-schema.sqlite.sql
sql census-analyze -X prime --include ../../src/census/census-analyze.sqlite.sql
sql census-stat4 -X prime --include ../../src/census/census-stat4.sqlite.sql
sql census-dbstat -X prime --include ../../src/census/census-dbstat.sqlite.sql
sql destroy-sql-objects -X prime --include ../../src/census/destroy.sqlite.sql --include ../../src/info-schema-destroy.sqlite.sql --include ../../src/core-ddl-clean.sqlite.sql --graph housekeeping
```

---

Rowcounts test cases:

```sql census-rowcounts-init -X prime --graph rowcounts --include ../../src/census/census-rowcounts.sqlite.sql
-- census-rowcounts.sqlite.sql generate rowcount execution plan 
-- and stores it in sqlite-aide.d/census/rowcounts.plan.sql in ".sqlite-aide.d"
```

Capture the generated plan to an in memory variable called `rowCounts`:

```sql census-rowcounts-gen -X prime -C rowCounts --graph rowcounts --dep census-rowcounts-init
SELECT contents
FROM ".sqlite-aide.d"
WHERE path = 'sqlite-aide.d/census/rowcounts.plan.sql';
```

Execute the generated plan:

```sql census-rowcounts-run -X prime --graph rowcounts --dep census-rowcounts-gen --interpolate
${captured.rowCounts}
```

```sql census-rowcounts -X prime --graph rowcounts --dep census-rowcounts-run --include ../../src/census/census-rowcounts.sqlite.sql
-- Publish aggregated rowcount results back into the database
```

---

## Housekeeping

```bash clean --dep destroy-sql-objects --graph housekeeping
rm -f rowcounts.plan.tmp.sql
rm -f test.tmp.db
```

```spry exectutionReportLog
If you run `spry rb report` this will get filled out with the log otherwise
it's ignored.
```
