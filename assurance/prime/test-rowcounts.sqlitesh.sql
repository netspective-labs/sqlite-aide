-- assurance/prime/test-rowcounts.sqlitesh.sql
/*
SQLite Aide census test runner (exact row counts).

Assumptions
- test.sqlite.sql has already been run
- ".sqlite-aide.d" exists
- Schema artifacts already exist

This script:
1) Generates the rowcount execution plan
2) Extracts the plan from ".sqlite-aide.d" to a temporary SQL file
3) Reads (executes) that plan SQL file
4) Re-runs the rowcount script to publish the aggregated results
*/

-- 1) Generate rowcount execution plan (stores sqlite-aide.d/census/rowcounts.plan.sql in ".sqlite-aide.d")
.read ../../src/census/census-rowcounts.sqlite.sql

-- 2) Extract the generated plan to a temp file
-- Use a local temp filename relative to this runner’s working directory.
.output ./rowcounts.plan.tmp.sql
SELECT contents
FROM ".sqlite-aide.d"
WHERE path = 'sqlite-aide.d/census/rowcounts.plan.sql';
.output stdout

-- 3) Execute the generated plan
.read ./rowcounts.plan.tmp.sql

-- 4) Publish aggregated rowcount results
.read ../../src/census/census-rowcounts.sqlite.sql

-- Optional: cleanup temp plan file (sqlite3 has no delete-file command; caller can remove it)
-- rm rowcounts.plan.tmp.sql
