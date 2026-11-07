# Persistence — Microsoft SQL Server

The `mssqlserver` variant of the neutral persistence standard, read when `frameworks.database: mssqlserver`
is declared in `.agent-kit-local/structure.yml`. Engine facts only — `core.md` carries the invariants, and
the stack's own `conventions/backend/persistence-mssqlserver.md` wins where the two differ.

⚠ **Two database-level settings decide half the rules below, and neither is visible from the code:**
`READ_COMMITTED_SNAPSHOT` (RCSI — off by default on SQL Server, on by default on Azure SQL Database) and
the collation (commonly case-**in**sensitive). Read both off the target database; assuming either is how
this variant gets applied wrong.

## Isolation is lock-based, not MVCC

Under the default READ COMMITTED **a reader takes a shared lock and a writer an exclusive one**, so readers
block writers and writers block readers: a reporting query stalls a write path.

- **RCSI makes READ COMMITTED read the last committed row version**, so readers stop blocking. It is set on
  the database by whoever owns it, never requested by the code, and leaves writer-versus-writer blocking
  alone.
- ⚠ **RCSI does not replace a version column.** Versioned reads make the *read* consistent; they do not
  order the writes, so without a version the second writer still overwrites the first with no error.
- ⚠ **RCSI is not SNAPSHOT isolation** — that is a separate setting *and* a per-transaction level, whose
  writer blocks on a row held by an open transaction, then fails with an update conflict when that one
  commits. Confusing the two ships retry code for an error this deployment never raises, and none for the
  blocking it does.
- ⚠ **A deadlock is a condition to expect, not a bug to eliminate.** SQL Server kills one side outright,
  already rolled back when the error arrives — retry it outside the transaction, bounded, like a lost
  version race. Take rows in a consistent order and keep transactions short; that makes it rare.

## Transactions and failure

- ⚠ **Forgiving error handling is a trap, not an opening.** Most statement errors leave the transaction open
  and the next statement succeeds, which invites an in-transaction retry. It still belongs outside
  (`core.md`): an access layer above may already have marked the unit of work failed, so the retry reads as
  working and the commit throws. `SET XACT_ABORT ON`, which distributed transactions require, removes even
  the appearance.
- ⚠ **A transaction spanning SQL Server and a second XA resource needs MSDTC**, plus the driver's XA support
  installed server-side — invisible in application code, failing at runtime. Keep one resource per
  transaction and use an outbox.
- **Under RCSI an open transaction pins the version store in `tempdb`**, which grows until it ends.

## Ids and the clustered key

- **Ids come from a sequence** (SQL Server 2012+). An identity column makes each insert round-trip for its id,
  and the primary key doubles as the **clustered** key, which must be narrow and ascending: a `bigint` off a
  sequence is both, a random UUID neither.
- ⚠ **A sequence's `INCREMENT BY` must match the block size any client-side allocator assumes** — otherwise
  ids already handed out are re-issued: duplicate keys under load, long after deploy.
- **Ids have gaps** — unused block tails, and a sequence cache dropped on failover. Never read a count or an
  ordering off an id.

## Indexes and constraints

- **A primary key is clustered unless the migration says `NONCLUSTERED` — or the table already has a
  clustered index**, in which case the key is silently nonclustered. The clustered index *is* the table, and
  every other index stores the clustered key as its row pointer — so a wide or random key inflates them all.
- **A unique constraint gets a nonclustered index; a foreign key gets nothing.** Index every foreign-key
  column, or the parent's delete and every child lookup scan the table.
- ⚠ **A unique constraint treats `NULL` as a value, so it permits exactly one unset row.** A nullable
  "unique" column rejects the *second* row that has none. Uniqueness among only the rows with a value is a
  **filtered unique index** (`… WHERE <column> IS NOT NULL`), written in the migration.
- **Constraint names are unique per schema, index names only per table.** Carry the table in both anyway
  (`<table>_<column>…_idx`): a violation naming only the column does not say which table raised it.

## Writes and paging

- ⚠ **A large set-based statement escalates to a table lock.** Past a few thousand row or page locks on one
  table, SQL Server swaps them for one table lock: every other writer waits — and every reader too, unless
  RCSI is on — and the log cannot truncate until it commits. Chunk by key range, one transaction per chunk.
- ⚠ **`OFFSET … FETCH` is legal only with `ORDER BY`**, and on a non-unique column the tie-break is the
  engine's — a row can land on two pages or none. Sort on the key, or append it.

## Collation and string types

- ⚠ **The collation decides whether equality and uniqueness are case-sensitive**, and the widespread
  `…_CI_AS` is case-**in**sensitive: `Foo@x.com` matches `foo@x.com`, and a unique constraint rejects it as
  a duplicate. Decide per column — take the collation as the rule, or normalize on write — and never let a
  `lower()` comparison and the constraint disagree.
- ⚠ **Test against a database created with production's collation.** A case-sensitive test database passes
  every uniqueness test a case-insensitive production fails, and the reverse.
- **Text columns are `NVARCHAR`, timestamps `datetime2`.** A client driver sending string parameters as
  Unicode (check yours) compares a `VARCHAR` column through an implicit conversion — its index stops being
  seekable and the query silently becomes a scan. `VARCHAR` under a UTF-8 collation (2019+) is a
  deliberate decision, not a fallback. `datetime` rounds to roughly 3 ms, so the value read back is not the
  one written.

## A shared lock is a row

A row in a lock table keyed by the lock name, claimed by a conditional update:

```sql
UPDATE … WHERE name = :name AND (holder IS NULL OR expires_at < SYSUTCDATETIME())
```

1 row affected means you hold it; 0 means someone else does.

- **The claim commits before the job starts; the release is its own transaction.** Hold one open and a
  second replica's identical `UPDATE` blocks on the claim row for the whole job instead of returning 0 —
  RCSI does not help, since it versions readers, not writers.
- **SQL Server has no TTL**, so that predicate is the only thing reclaiming a lease. Size it so a second
  holder is harmless, and have the release check it still owns the row.
- ⚠ **`sp_getapplock` and `WITH (UPDLOCK)` are the wrong shape.** Both tie the lock to a transaction or a
  session — and a pooled connection is handed back at commit, so the lock is dropped on reset or stranded
  on a connection now serving someone else. The lock must outlive the claiming transaction; a row does.
