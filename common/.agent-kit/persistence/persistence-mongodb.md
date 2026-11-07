# Persistence — MongoDB

The `mongodb` variant of the neutral persistence standard, read when `frameworks.database: mongodb` is
declared in `.agent-kit-local/structure.yml`. Engine facts only — `core.md` carries the invariants, and the
stack's own `conventions/backend/persistence-mongodb.md` wins where the two differ.

## Indexes

- ⚠ **MongoDB creates no index but `_id`.** An unindexed query collection-scans, returns the right answer
  and passes every test on a seeded fixture — so the index ships in the same migration as the query.
- **Uniqueness is a unique index**, and its duplicate-key error is the business signal.
- ⚠ **A partial unique index filtered on `{$type: "string"}` enforces uniqueness but the 8.0 planner never uses it for equality or regex lookups** (explain-verified). Filter with `{$gt: ""}`, or use a plain unique index.
- ⚠ **A delete-time reference check is a query too.** A guard that refuses a delete while another collection
  still points at it finds by that field on every delete, and needs an index *leading* with it — a
  compound `{userId, trackId}` does not serve `{trackId}`. Nothing fails without one; each delete scans.
- ⚠ **A TTL index deletes within about a minute of expiry, not at it.** Size any lease so a late delete is
  harmless; never treat the expiry instant as a guarantee.

### Index naming

Index names in migrations follow `<what><Kind>Idx`, with **no** entity/collection prefix (MongoDB already
knows the collection).

- `<what>`: the indexed fields in key order (`userIdScore`); for an index over many fields, its purpose
  (`text`, `name`).
- `<Kind>`: empty (plain), `Unique`, `Ttl`, `Search` (Mongo `$text`), `AtlasSearch`, `Vector` (Atlas Vector
  Search). Partial/sparse options don't change the name.

```text
Good
  userIdScoreIdx                     plain
  userIdSessionIdUniqueIdx           unique
  expiresAtTtlIdx                    TTL
  normalizedNameSearchIdx            $text
  textSearchIdx                      $text over many fields, named by purpose
  nameAtlasSearchIdx                 Atlas Search
  lyricEmbeddingVectorIdx            Atlas Vector Search

Bad
  userSessionUserIdSessionIdUniqueIdx  entity prefix
  artist_name_v1                       entity prefix, no kind/Idx; a definition change is
                                       updateSearchIndex on the same name, not a version suffix
```

## Writes

- ⚠ **A replace by `_id` writes the whole document**, not the fields you changed — an object the request
  half-filled silently deletes every field it did not carry. A partial update is a `$set` of the fields
  that actually changed.
- **Optimistic locking is a filtered update:** filter on `_id` **and** the version that was read, `$set` the
  changes and `$inc` the version in the same update. An `updateMany`/pipeline rewrite of versioned
  documents does the same: `$add[$ifNull[$version, 0], 1]`.
- ⚠ **"Did the filter match" is the matched count, never the modified count.** An update that sets a field
  to the value it already holds modifies nothing on a document that matched perfectly — reading that 0 as
  "lost the race" or "no such document" invents a conflict. A write that matched won the race, whatever
  it altered. A matched count of 0 means lost race, deleted, or never existed — `core.md` says what to do.

## Transactions

- **Prefer designing the invariant into one document so no transaction is needed** — embed what must change
  together. Reach for a multi-document transaction only when two collections genuinely must move as one.
- ⚠ **Multi-document transactions need a replica set or sharded cluster.** A standalone server cannot start
  one, so the path that works in production fails against a standalone test instance — the integration
  tier needs the production topology.
- ⚠ **A transaction lives on a session.** An operation not issued on that session runs outside it and
  commits independently — no error. Know whether your access layer binds the session for you or every
  call site must pass it.

## Reads

- ⚠ **`skip`-based paging walks and discards every skipped document.** Walk a whole collection by a range on
  a sorted indexed field (`_id` or a timestamp), carrying the last value forward.
- **Project server-side** — a projection, or an aggregation ending in `$project` — never a find that
  materializes documents to read one field.
- **Aggregation pipelines live in the repository with bound parameters** — never concatenated from user
  input — shaped by a final `$project` into a dedicated, named result type.

## The client

The client is thread-safe and owns a connection pool: **exactly one per application**, closed on
shutdown. A client per request, per repository or per test opens a pool each time, and the leak surfaces
as connection exhaustion under load rather than as an error where it was created.

## A shared lock is a document

- **An insert into a lock collection with a unique index on the lock key.** The insert that succeeds holds
  the lock; the duplicate-key error means someone else does. Release by deleting.
- ⚠ **Claim with an insert, never an upsert or a replace by `_id`** — a second replica's call overwrites the
  holder's document and both run the job.
- **Carry an expiry field with a TTL index** so a crashed holder cannot block the job forever — sized
  against the ~60 s slack above.
