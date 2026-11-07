# Persistence — PostgreSQL

The `postgres` variant of the neutral persistence standard, read when `frameworks.database: postgres` is
declared in `.agent-kit-local/structure.yml`. Engine facts only — `core.md` carries the invariants, and the
stack's own `conventions/backend/persistence-postgres.md` wins where the two differ.

## Transactions and failure

- ⚠ **An aborted transaction rejects every further statement.** That is why a retry inside the failed
  transaction cannot work here: it sits outside, one fresh transaction per attempt (`core.md`).
- ⚠ **Two writers taking the same rows in different orders deadlock, MVCC or not.** Postgres kills one side
  (`40P01`), already rolled back when the error arrives. Take rows in a consistent order wherever one unit
  updates several, and retry the victim outside the transaction like a lost version race.
- ⚠ **A long-open transaction pins the xmin horizon**, so vacuum clears no dead tuple newer than its
  snapshot — in *any* table. Keep transactions short.
- ⚠ **Two-phase commit is off by default** — `max_prepared_transactions` is 0, so a transaction spanning
  Postgres and a second XA resource fails at runtime on `PREPARE TRANSACTION`. A server-side setting,
  invisible in application code; keep one resource per transaction and use an outbox.

## Ids and sequences

- **Ids come from a sequence.** An identity column makes the database assign each id on insert, so every
  insert round-trips for it — which is what defeats insert batching.
- ⚠ **A sequence's `INCREMENT BY` must match the block size any client-side allocator assumes.** An
  allocator handing out blocks of 50 over a sequence left at `INCREMENT BY 1` re-issues ids it already
  gave away — duplicate keys under load, long after deploy.
- **Ids have gaps** — unused block tails are never returned. Never read a count or an ordering off an id.

## Indexes and constraints

- ⚠ **Postgres indexes a primary key and a unique constraint automatically — a foreign key never.** Index
  every foreign-key column, or the parent's delete and every child lookup scan the table.
- **Index names are unique per schema**, so they carry the table: `<table>_<column>…_idx`.
- **Name every constraint in the migration** — the name is the only thing saying which rule fired.

## Paging

- ⚠ **On a non-unique `ORDER BY` the tie-break is the planner's**, so an offset page can repeat or skip a
  row. Sort on the key, or append it.

## A shared lock is a row

A row in a lock table keyed by the lock name, claimed by a conditional update:

```sql
UPDATE … WHERE name = :name AND (holder IS NULL OR expires_at < now())
```

1 row affected means you hold it; 0 means someone else does.

- **The claim commits before the job starts; the release is its own transaction.** Hold one open for the
  run and, under READ COMMITTED, a second replica's identical `UPDATE` **blocks** on the claim row instead
  of returning 0 — and the open transaction pins the xmin horizon (above).
- **Postgres has no TTL**, so that predicate is the only thing reclaiming a lease. A holder outrunning its
  expiry is not stopped: size the lease so a second holder is harmless, and have the release check it
  still owns the row.
- ⚠ **`SELECT … FOR UPDATE` is the wrong shape for a lease claim** — it blocks instead of reporting the
  loss, so every replica queues for the whole job instead of skipping the run.
