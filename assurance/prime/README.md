# SQLite Aide Primary Regression Test Suite

Use [`spry`](https://sprymd.org) to run this suite. `test.tmp.db` is where you
can review output.

```bash
# list tasks
spry rb ls          

# primary test (imperative, see output in test.tmp.db)
spry rb run           

# row counts test (complicated "stored procedure" strategy)
spry rb run --graph rowcounts

# for TAP (open test.tap in text editor, test.tap.html in browser)
spry rb tap
spry rb tap --save test.tap
spry rb tap --style html --save test.tap.html
spry rb run --style markdown --save test.tap.md
spry rb run --style json --save test.tap.json

spry rb tap --graph rowcounts --style html --save test.tap.html
spry rb tap --graph rowcounts --style markdown --save test.tap.md
spry rb tap --graph rowcounts --style json --save test.tap.json

# for full diagnostics (open test.md in any Markdown viewer)
spry rb report > test.md
spry rb report --graph rowcounts > test.rowcounts.md

# cleanup
spry rb run
```

💡 The files named `clean.sqlitesh.sql`, `test.sqlitesh.sql`, and
`test-rowcounts.sqlitesh.sql` are included as plain SQL examples. They mirror
what the regression steps would look like if everything were written and
executed without Spry. In practice, the real regression suite is defined and run
through Spry using Spryfile.md, which drives the entire workflow. The SQL files
are there only as equivalents so you can see the underlying logic without Spry’s
orchestration.
