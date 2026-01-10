SQLite Aide Primary Regression Test Suite

```bash
# don't modify the fixture
cp ../fixtures/chinook.db test.tmp.db

# load the static tests (idempotent)
sqlite3 test.tmp.db < test.sqlitesh.sql

# load the dynamic tests (idempotent)
sqlite3 test.tmp.db < test-rowcounts.sqlitesh.sql
rm -f rowcounts.plan.tmp.sql   # remove the temp file

# cleanup
sqlite3 test.tmp.db < clean.sqlitesh.sql
rm -f test.tmp.db
```
