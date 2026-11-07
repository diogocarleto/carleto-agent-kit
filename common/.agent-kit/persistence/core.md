# Persistence — invariants

**Prescriptive** — apply these, don't just read them. Engine- and framework-neutral, distilled from the
stacks' own persistence docs: a rule is here only because it held on every engine and access API they
cover. Beside this file sits the engine's own `persistence-<value>.md`, selected by `frameworks.database`
in `.agent-kit-local/structure.yml`. How a module *works* underneath belongs in module memory
(`/module-extract`), not here.

⚠ **The stack's `.agent-kit/common/conventions/backend/persistence-<db>.md` wins where they differ** —
this file states the invariant, that one states how this stack's access API expresses it. Stack doc
**silent** ≠ rule void: the invariant still applies; if it needs something the stack may not have, say
so and ask rather than inventing it.

No persistence conventions on this stack? → `reference/adding-persistence.md`.

## The repository boundary

- **One repository per aggregate, and it is the only place the query language, the driver or its query
  types appear.** Services take and return domain types. A service that builds a filter has moved the
  query language into the business layer, where nothing tests it and every caller re-invents it.
- **Two conversions, two homes, never merged:** storage ↔ domain in the repository or its mapping;
  domain ↔ DTO in the mapper.
- ⚠ **Know whether mutating a loaded object is a write.** Under a change-tracking access layer it is — an
  update at commit, with no repository call in the stack trace — so a loaded entity never leaves the
  service owning its transaction. Under an explicit-write one it is not, and a service that mutates and
  returns changed nothing. Both fail silently; the stack doc says which you have.

## Reads

- **A query that finds by criteria pages.** A plain list is only for a lookup bounded by the **caller's own
  input** (`findByIds(ids)`) or by a domain invariant that grows only through a code change. ⚠ "It is
  usually small" is not a bound — a threshold rots silently and fails the day the data grows.
- **Project in the query.** One field off many records is a projection, never a load that materializes
  entities and maps them down. Building a complete derived set? Page the source and accumulate only the
  projection — ids, never entities.
- **Offset paging degrades** — the engine walks and discards every skipped row. A walk of a whole table or
  collection ranges over a sorted, indexed key and carries the last value forward.
- ⚠ **An offset page needs a unique sort.** On a non-unique sort the tie-break is the engine's: a record can
  land on two pages or on none, while every page looks correct alone. Sort on the key, or append it.
- ⚠ **A single-result finder fails on a second match.** Taking the first of several silently hands back one
  and lets a broken uniqueness assumption read as working.

## Writes

- ⚠ **Never write a whole record built from an object the request only half-filled.** A full replace or
  merge writes absent or null over every field it did not carry — a successful write, nothing logs, and
  the data is gone. Either load, modify and write the complete record in one call, or write only the
  fields that changed.
- **Read paths do not mutate.** Normalizing in a read, defaulting inside a getter, a mapper that touches
  the entity — under change tracking each is a write. Defaults live only where the record is created.

## Concurrency

- **A read-modify-write that concurrent requests can hit carries a version.** The write filters on the
  version that was read and increments it in the same statement; "no record matched" is the lost race.
  A plain update with no version filter loses the other writer's change with no error anywhere.
- ⚠ **Retry sits outside the transaction**, never inside it — the failure surfaces at write or commit,
  when the unit of work is already unusable (each engine variant says why on that engine). One fresh
  transaction per attempt, **bounded**, re-reading and **re-running the business rules**: a lost race
  usually means the precondition no longer holds, which must surface as its own 4xx, not as a retried
  write. A record that is genuinely gone reaches the same handler — surface it as its own 4xx rather
  than looping.
- ⚠ **A version guards only the record it lives on.** Two requests editing disjoint children stored
  elsewhere both win, and an invariant over the collection breaks silently. Where the children are part
  of the invariant, bump the root's version too.
- ⚠ **A set-based rewrite of versioned records must bump each record's version**, or a concurrent version-guarded write built from the pre-rewrite copy silently reverts it.
- **Uniqueness only by a unique constraint or index.** A find-then-insert check is a race with itself; the
  constraint is the rule, and the duplicate-key error is the business signal to map.

## Transactions

- ⚠ **Verify the transaction boundary actually covers the store.** A boundary that does not enlist it —
  wrong resource type, a store the transaction manager does not manage, no manager configured — reads as
  atomic and commits each write independently, with no error.
- **One resource per transaction.** Reach a second (a queue, a cache, another database) through an outbox
  — a distributed transaction needs server-side setup invisible in application code and fails at runtime
  on that path only.
- **Nothing remote is called inside a transaction**, and none is held open across a long job.

## Schema and indexes

- **Schema and index changes ship in a versioned migration owned by the project, in the same change as the
  query that needs them.** Never created at startup or on first use: that runs on every replica at boot,
  reconciles nothing, and a build on a large table stalls the rollout.
- **Every query a repository ships has an index that serves it.** An unindexed query is not an error — it
  scans, returns the right answer, and passes every test on a seeded fixture.
- **Name every constraint and index in the migration**, per the engine variant's scheme. The name is what
  tells the handler of a violation *which* rule fired.

## A cross-instance lock is a record

- **A record keyed by the lock name, claimed by one atomic write whose outcome says who won** — a
  conditional update's count, or an insert against the unique key. A claim that **blocks** instead of
  reporting the loss is the wrong shape: every replica queues for the whole job instead of skipping it.
- **The claim commits before the job starts; the release is its own transaction** and checks it still owns
  the record. A lock tied to a transaction or connection cannot outlive the claim.
- **It carries an expiry**, so a crashed holder cannot block the job forever. A holder outrunning it is not
  stopped — size the lease so a second holder is harmless.

## Testing

- **The integration tier runs against the real engine, configured like production** — topology, collation,
  isolation settings — and applies the real migrations, so a broken one fails in CI. An embedded
  substitute or a differently configured instance hides exactly the rules the engine variant exists for.
- **Prove a query is index-served by running the repository's own call** — an index-usage counter delta or
  an explain of the exact command. A query rebuilt in the test proves nothing about the shipped one.
