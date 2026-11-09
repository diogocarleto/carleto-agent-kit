## Persistence — MongoDB

The `mongodb` variant of this stack's persistence doc: `/backend` reads it when `frameworks.database: mongodb` is declared in `.agent-kit-local/structure.yml`. A second database means a second `persistence-<db>.md` beside this one, not a fork of the stack.

Read together with `.agent-kit/persistence/core.md` and the neutral `.agent-kit/persistence/persistence-mongodb.md`, which carry the engine rules; this doc says how Panache MongoDB expresses them, and wins where they differ.

**`quarkus-mongodb-panache`, blocking, repository pattern.** Versions come from the Quarkus BOM.

### The repository boundary

One `@ApplicationScoped` repository per aggregate, implementing `PanacheMongoRepository<Order>` (an `ObjectId` id) or `PanacheMongoRepositoryBase<Order, UUID>` (any other id), injected into services. The entity is a plain class, never `PanacheMongoEntity`. The repository is the only type touching a query string, `Bson`, `Filters`, `PanacheQuery` (beyond paging) or `MongoCollection`. The extension owns the `MongoClient`: never construct one.

- ⚠ **A setter on an entity is not a write.** Nothing is persisted until the repository issues the write, so a service that mutates an entity and returns has changed nothing, with no error.
- ⚠ **The collection defaults to the entity's simple class name**, so renaming the class silently points it at an empty collection. Pin it: `@MongoEntity(collection = "orders")`.

### Where mapping lives

**document ↔ entity** is the driver's POJO codec, on default conventions; **entity ↔ DTO** is the mapper's (`patterns.md`). The codec reads accessors, not fields, and each of these fails silently:

- **Shape.** A public or protected no-arg constructor plus setters (or public fields), or a `@BsonCreator` constructor. A property with a getter and no setter is **written but never read back**: the key is skipped on read.
- ⚠ **A derived getter is persisted.** `getFullName()` with no backing field becomes a stored key. Annotate it `@BsonIgnore`: the opposite of a field-based mapper.
- ⚠ **A stored key the class does not map is skipped on read and erased by the next `update()`** (*Writes*): a removed or renamed field, or one another writer added. A `@BsonExtraElements` property keeps them.
- **A null property is omitted from the document**, not written as `null`.
- The id is the property named `id` (or `_id`); anything else needs `@BsonId`. Enums are stored by `name()` (the wire `value` is an API concern only), so renaming a constant is a data migration; `Instant` as a BSON date, in milliseconds. Keys are the Java property names, case-sensitive; the relational snake_case rule does not apply here.
- ⚠ **A `UUID` fails to encode until the representation is set**, by `quarkus.mongodb.uuid-representation` or `uuidRepresentation=` in the connection string. A new application takes `STANDARD`; one with data already written takes the representation that wrote it.
- **Records** serve as embedded value objects and aggregation results; a record component is its own key, so `@BsonId` marks `_id`.

### Parameter binding

A query string starting with `{` is native JSON; any other is PanacheQL (`status = ?1 and total > ?2`). The two bind differently:

- ⚠ **Native binds with `String.replace`.** With ten or more positionals `?1` corrupts `?10`; keep it to nine, or use named. Named binding has the same flaw: `:user` corrupts `:username` depending on the map's iteration order, so no name may be a prefix of another. `Parameters` is deprecated (3.34): pass a `Map`.
- **PanacheQL parses the string** and looks each parameter up by its exact key, so neither corruption exists there. A filter PanacheQL can express goes in that form.
- ⚠ **A PanacheQL placeholder with no supplied value is not an error**: its own text becomes the compared value, and the query matches nothing.
- ⚠ **`like` is an unanchored regex built from the parameter**, not SQL `%` matching. Quote user input with `Pattern.quote`.
- An enum parameter binds as its `name()`.

### Reads

- `find(…)` returns a `PanacheQuery`. Persistence-neutral rules (bounded `List`, projection, keyset over offset, unique sort) are `core.md` → *Reads*.
- ⚠ **`stream(…)` is not a cursor**: it is `list().stream()`, so it materializes the whole result. A walk pages.
- ⚠ **`page(…)` is skip/limit over the sort you give it**, and Panache adds none. `hasNextPage()` and `pageCount()` both rest on one cached `countDocuments` per query: leave them out when the caller renders no total.
- ⚠ **`firstResult()` takes the first of several without a word.** A lookup that must be unique uses `singleResultOptional()`, which throws `PanacheQueryException` on a second match.
- ⚠ **`project(Class)` takes its fields from `get*` accessors and public fields.** A record has neither, so its projection is empty and restricts nothing. A boolean read through `is*()` is not projected either and keeps its default (`false`, or `null` for a `Boolean`). Project onto a class with getters; a record is for aggregation results.

### Aggregation

The repository has no aggregation method: pipelines go through `mongoCollection().aggregate(…)`, built with the driver's `Aggregates` and `Filters` builders (values bound, never concatenated) and decoded into a dedicated record. `$group` emits `_id`: alias it in a final `$project`, or mark the component `@BsonId`.

⚠ **The driver collection is not on the transaction's session** (*Transactions*): a read through it never sees the uncommitted writes of the transaction it is called in.

### Writes — `update()` replaces the whole document

⚠ **This is the rule that costs data on this stack.** `update(entity)` is `replaceOne` by `_id`, and `persistOrUpdate(entity)` the same with upsert (an insert when the id is null): the neutral variant's whole-document replace, with no `$set` behind it. An `_id` with no document matches nothing, and `update` returns `void`, so nothing says the write did not happen.

Two shapes are safe:

- **Load the complete entity, merge the request onto it** (the partial-update mapper, `patterns.md`), **and `update()` it** inside one service call.
- **A partial `$set`**: `update(Bson).where(Bson)`, built with `Updates` and `Filters`. The only option when two writers touch disjoint fields. ⚠ It runs `updateMany`: a filter not pinned to `_id` rewrites every match.

⚠ **On a versioned aggregate, every write is the conditional update below**, never `update(entity)`, which neither checks nor bumps the version and can write a stale value back.

⚠ **`update(…).where(…)` returns the modified count**, which the neutral variant says never to read as "did the filter match". The versioned write below is safe because its `$inc` modifies every match; any other partial update may set a field to the value it already holds and report 0 on a document that matched.

### Optimistic locking — there is no `@Version`

⚠ **Neither Panache nor the codec has a version annotation.** `jakarta.persistence.Version` is ignored, and a field named `version` is ordinary data that `update()` overwrites with whatever it holds: a last-write-wins replace that loses the other writer's change with no error.

The shape is a hand-written `Long version` on the aggregate root, set to 0 by the factory that creates it (`patterns.md` → *Entity Defaults and Partial Updates*), and a conditional update that filters on the version that was read:

```java
long won = update(Updates.combine(Updates.set("status", status), Updates.inc("version", 1)))
        .where(Filters.and(Filters.eq("_id", id), Filters.eq("version", read)));
if (won == 0) throw new StaleVersionException(id);
```

- **The conflict is a count of 0, not a driver exception.** Throw one project `RuntimeException` for it, so an enclosing transaction rolls back; `core.md` says what a 0 can mean. The caller retries that type from outside the transaction (`concurrency.md`).
- ⚠ **`{version: 0}` does not match a document with no `version` key.** Backfill in the migration that adds the field, or every write to an old document reads as a lost race.
- The versioned write needs no `@Transactional`: it is one atomic document write.

### Transactions

`quarkus-narayana-jta` arrives with `quarkus-mongodb-panache`, so `jakarta.transaction.Transactional` works with no further extension. The neutral variant's advice stands: design the invariant into one document, and leave `@Transactional` off a service method whose unit is a single-document write.

- ⚠ **Any Panache call inside an active transaction, a read included, opens a Mongo session and transaction.** One write under `@Transactional` therefore needs the replica set the neutral variant requires, and fails without it.
- ⚠ **Dev Services' container is a single-node replica set, so transactions run there.** A connection string you configure yourself, or the `127.0.0.1:27017` fallback when Docker is absent (`testing.md`), must be a replica set too, or every `@Transactional` path that touches Mongo fails.
- ⚠ **Panache calls join the session implicitly; `mongoCollection()` and `mongoDatabase()` do not.** Whatever goes through the driver handle commits on its own and survives a rollback.
- ⚠ **Mongo joins as a synchronization, not an XA resource**: its commit is issued after the transaction's outcome is decided. A second resource in the same method (Hibernate ORM, say) is not atomic with it, which makes the neutral one-resource rule literal here.

### Index ownership

No mapping annotation here (`@MongoEntity`, the BSON ones) declares an index, so every index ships in the project's migration, in the change that adds the query (`core.md` → *Schema and indexes*). Name them by the neutral variant's scheme.

A unique-index violation arrives as `MongoWriteException` from a single-entity `persist`, `update` or `persistOrUpdate`, and as `MongoBulkWriteException` from `persist` and `persistOrUpdate` over several entities; test `getError().getCategory() == ErrorCategory.DUPLICATE_KEY` (`getWriteErrors()` on the bulk one). Both are runtime exceptions, so they roll the transaction back; translate to the domain exception at the repository boundary (`api.md`).

### A shared lock is a document

Cross-instance mutual exclusion (`concurrency.md`, `patterns.md` → *Batch, scheduled and bulk workloads*) is the neutral variant's lock document, and the claim maps as above: a `MongoWriteException` of category `DUPLICATE_KEY` means someone else holds it. The expiry is an `Instant`, so the TTL index applies.

- ⚠ **Claim it with `persist`, never `persistOrUpdate`.** With the lock key as `_id`, `persistOrUpdate` is a replace-upsert: the second replica overwrites the holder's document and both run the job. This is the whole-document-replace rule above, where it costs a correctness bug rather than lost fields.
- ⚠ **Claim and release outside any `@Transactional`.** Inside one, the claim rides the transaction's session and commits only when the job's transaction does, after the work it was meant to guard. Release with `delete("{ _id: ?1, owner: ?2 }", key, owner)`: a count of 0 means the lock is no longer yours.
