## Persistence — MongoDB

The `mongodb` variant of this stack's persistence doc: `/backend` reads it when `frameworks.database: mongodb` is declared in `.agent-kit-local/structure.yml`. A second database means a second `persistence-<db>.md` beside this one, not a fork of the stack.

Read together with `.agent-kit/persistence/core.md` and the neutral `.agent-kit/persistence/persistence-mongodb.md`, which carry the engine rules; this doc says how this stack expresses them, and wins where they differ.

### The repository boundary

One repository per collection, `@ApplicationScoped`, and **the only type in the project that uses the driver API or its query types** — `MongoCollection`, `Bson`, `Document`, `UpdateResult`, cursors. None of those may reach a service.

⚠ The rule is the driver API, not the package name: under the POJO-codec binding below an entity legitimately carries `org.bson.codecs.pojo.annotations.*`, which is mapping metadata rather than query surface (`patterns.md` → Serialization Boundaries).

Every query a domain needs is a named method on that repository. Services compose repositories through *their own* domain's repository only — cross-domain reads go through the other domain's service.

⚠ **A setter on an entity is not a write here** — nothing is persisted until the repository issues the update, so the mutation `code-style.md` carves out belongs inside the repository. A service that mutates an entity and returns has changed nothing, with no error.

⚠ RUNTIME GAP — the driver/ODM binding: plain `MongoCollection<Document>` with hand-written mapping, the driver's POJO codec registry, or a mapping library. Every rule below holds under all three; only the code shape changes. Fill when it is chosen; do not guess.

⚠ **Under the POJO codec every public getter is a persisted property.** Adding a convenience getter to an entity — `isExpired()`, `fullName()` — silently starts writing a derived field into the document, and it stays stored after the derivation changes. Annotate every non-persisted accessor `@BsonIgnore`, or keep derivations off the entity entirely. This failure mode belongs to that one binding; hand-written mapping has it nowhere.

⚠ **A record is not the POJO codec's to map.** An embedded value object written as a record (`patterns.md`) is handled by the driver's *record* codec — in the default registry since driver 4.6 — which builds it through the canonical constructor and needs no annotation at all. The rule above does not carry across: only record **components** are persisted, so no accessor needs `@BsonIgnore` — and `@BsonIgnore`, `@BsonCreator`, `@BsonExtraElements` and `@BsonDiscriminator` **throw** `CodecConfigurationException` on a record rather than being ignored. The POJO codec takes everything else, and it needs a public or protected no-arg constructor unless `@BsonCreator` names another — so a non-record value object cannot be immutable without it.

**The `MongoClient`** is one `@ApplicationScoped` producer, closed on shutdown with `@Disposes` (why: the neutral variant → *The client*).

### Where mapping lives

**document ↔ entity** is in the repository (or the codec it registers) — the only place field names, `_id` handling and BSON types appear. **entity ↔ DTO** is the mapper's (`patterns.md`).

A type that carries both sets of annotations is bound by whichever library reads it first, and the other set is dead (`patterns.md` → Serialization Boundaries).

The persistence binding named there is the **MongoDB codec (BSON)** under a codec binding; under hand-written mapping there are no mapping annotations at all, and under a mapping library they are that library's. The table's rule holds whichever it is.

### Reads and writes

- A method that finds by criteria returns a page (named per `code-style.md`); what may bound a `List` instead is `persistence/core.md` → *Reads*. A walk of a whole collection ranges on `_id` rather than `skip`.
- Pipelines bind their output to a dedicated `*Aggregation` record.
- A partial update is a `$set`; a versioned one filters on `_id` and the version and `$inc`s it (the neutral variant → *Writes*). ⚠ Read `UpdateResult.getMatchedCount()`, never `getModifiedCount()`.

### Transactions and sessions

- **`@Transactional` does not cover MongoDB.** The JTA boundary manages JTA resources; a Mongo write inside one is neither enrolled nor rolled back. An annotated method that mixes the two reads as atomic and is not.
- A multi-document transaction is an explicit `ClientSession`, and **every operation that must participate takes that session as an argument** — nothing binds it for you. An operation that forgets it runs outside the transaction and commits independently, with no error.

### A shared lock is a document

Cross-instance mutual exclusion (`concurrency.md`, `patterns.md` → *Batch, scheduled and bulk workloads*) is an insert into a lock collection with a unique index on the lock key; the duplicate-key failure means someone else holds it. The shape and the TTL slack are the neutral variant's → *A shared lock is a document*.
