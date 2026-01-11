# SQLite Aide Prime end-to-end (e2e) regression test

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

## Rowcounts test cases

This test is a little complex because Spry is simulating a stored procedure,
something SQLite doesn’t support directly. The rowcount script first writes its
execution plan into `.sqlite-aide.d`, effectively generating the SQL body of
that “procedure.” The script then extracts this plan as a temporary file and
executes it to perform the actual work. Finally, it runs the rowcount script
again to aggregate and publish results. This pattern compensates for SQLite’s
lack of stored procedures by generating, storing, and then executing the SQL
needed to drive a multi-step workflow.

Step 1: It generates a “plan” for how to do all the row-count checks. That
happens when it runs `census-rowcounts.sqlite.sql`. Instead of immediately
executing all checks directly, that script writes out a detailed plan (generated
as SQL code) into `.sqlite-aide.d` table.

Step 2: It then pulls that saved plan (generated SQL code) text out of and
captures it to a Spry working memory variable called `rowCounts` using
`-C rowCounts`.

Step 3: It executes the generated SQL code from Step 2 which populate
`.sqlite-aide.d` with the detailed row counts.

Step 4: It runs `census-rowcounts.sqlite.sql` again, but this time the detailed
results already exist. On this second pass, the script is used to aggregate and
publish the final summary of row counts, so you can see the consolidated results
of the checks.

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
