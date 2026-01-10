# Test Fixtures use by assurance (test) suites

This directory houses non-sensitive "test fixture" files that are used by test
suites. Do not change the name of files without checking the test sources.

- `empty-rssd.sqlite.db` (`surveilr` v3.20 SQLite): An empty SQLite file created
  by `surveilr admin init`.
- `chinook.db` (SQLite): Chinook is a sample database available for SQL Server,
  Oracle, MySQL, etc. It can be created by running a single SQL script. Chinook
  database is an alternative to the Northwind database, being ideal for demos
  and testing ORM tools targeting single and multiple database servers.
- `northwind.sqlite.db` (SQLite): The Northwind sample database was provided
  with Microsoft Access as a tutorial schema for managing small business
  customers, orders, inventory, purchasing, suppliers, shipping, and employees.
  `northwind.sqlite.db` is an excellent _abridged_ tutorial schema for a
  small-business ERP, with customers, orders, inventory, purchasing, suppliers,
  shipping, employees, and single-entry accounting. Original unabridged source:
  https://github.com/jpwhite3/northwind-SQLite3
