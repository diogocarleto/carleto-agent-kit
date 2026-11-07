## Persistence — MongoDB

The `mongodb` variant of this stack's persistence doc: `/backend` reads it when `frameworks.database: mongodb` is declared in `.agent-kit-local/structure.yml`. A second database means a second `persistence-<db>.md` beside this one, not a fork of the stack.

Read together with `.agent-kit/persistence/core.md` and the neutral `.agent-kit/persistence/persistence-mongodb.md`, which carry the engine rules; this doc says how Spring Data expresses them, and wins where they differ.

**Spring Data MongoDB**, version managed by the Boot BOM. ⚠ Take it from the BOM, never by analogy with `spring-data-jpa`: this module's release train runs a major ahead, so the "matching" number resolves to an old release that downloads cleanly and compiles against the wrong generation.

### The repository boundary

One `MongoRepository<T, ID>` **interface** per aggregate. Derived method names first, then `@Query` (a JSON filter) and `@Aggregation` (a pipeline) when derivation cannot express it. `MongoTemplate` is not injected into a service: when the interface falls short, add a `…RepositoryCustom` fragment, and that fragment is then **the only** type touching `MongoTemplate`, `Query`, `Criteria`, `Update`, `UpdateResult` or `Document`.

✅ **Prefer a derived name over `@Query`.** Query methods are resolved when the repository proxy is built and Boot bootstraps repositories eagerly, so a misspelled property fails the application context at startup — where a JSON string in `@Query` is only a string.

⚠ **A setter on an entity is not a write here** — nothing is persisted until the repository issues the write, so the mutation `code-style.md` carves out belongs inside the repository boundary. A service that mutates an entity and returns has changed nothing, with no error.

⚠ **`SimpleMongoRepository` carries no `@Transactional`, unlike its JPA counterpart.** Nothing here opens a transaction for you; see *Transactions* below.

**Boot owns the `MongoClient`** — never construct one.

### Writes — `save()` replaces the whole document

⚠ **This is the rule that costs data on this stack.** `repository.save(entity)` inserts when the entity is new and otherwise issues `replaceOne` — the neutral variant's whole-document replace, behind a name that reads like a partial save.

Two shapes are safe, and there is no third:

- **Read, modify, save the complete document** inside one service call, so the object you pass genuinely holds every field.
- **Apply a partial `$set`** — `@Update` on a repository method, or `MongoTemplate.updateFirst` in a fragment. The only option when the document is large, or when two writers touch disjoint fields.

⚠ **A repository `@Update` method returns the *modified* count, not the matched count** — the number the neutral variant says never to read as "did the filter match". When that is the question, go through `MongoTemplate.updateFirst` in a fragment and read `getMatchedCount()`.

### Optimistic locking

Any read-modify-write that concurrent requests can hit carries a version field annotated **`org.springframework.data.annotation.Version`**.

⚠ **Not `jakarta.persistence.Version`** — that one is ignored here with no warning, and it is exactly what a JPA habit (or a project holding both databases) reaches for. The result is a plain last-write-wins replace that loses the other writer's change with no error anywhere.

With it, `save()` filters on `_id` **and** the version that was read, bumps the version in the same write, and raises `OptimisticLockingFailureException` when nothing matched. Retry it per `core.md` → *Concurrency*.

### Transactions and sessions

⚠ **Boot auto-configures no Mongo transaction manager.** Declare a `MongoTransactionManager` bean, or `@Transactional` covers nothing on this stack and a multi-document unit is not atomic.

⚠ **In an application that also uses JPA, declaring the Mongo manager removes the JPA one.** Boot's `JpaTransactionManager` is `@ConditionalOnMissingBean(TransactionManager.class)`, so the `MongoTransactionManager` above suppresses it: every unqualified `@Transactional` then resolves to the Mongo manager and no JPA transaction is ever started. **Declare both managers explicitly** and name the one you mean on every `@Transactional` — unqualified resolution with two of them is a `NoUniqueBeanDefinitionException`, and marking one `@Primary` to silence that is what produces the genuinely silent bug: `MongoTemplate` synchronizes only with a transaction a *Mongo* manager started (`SessionSynchronization.ON_ACTUAL_TRANSACTION`), so a method mixing the two reads as atomic while every Mongo write commits independently and survives the rollback.

✅ With that bean present, `MongoTemplate` joins the transaction implicitly. You never thread a `ClientSession` through call sites, and there is no "operation that forgot the session" failure mode. The replica-set requirement is the neutral variant's.

### Where mapping lives

**document ↔ entity** is the mapping annotations (`@Document`, `@Id`, `@Field`) on the entity — the only place document field names and BSON types appear. **entity ↔ DTO** is the mapper's (`patterns.md`).

A type carrying both sets of annotations is bound by whichever library reads it first, and the other set is dead (`patterns.md` → *Serialization Boundaries*).

⚠ **Mapping is field-based: every field is persisted, a derived *getter* is not.** A cached or computed **field** silently becomes a stored document key and stays stored after the derivation changes — annotate it `@Transient`. A convenience accessor with no backing field writes nothing and needs no annotation; that is the opposite of the driver's own POJO codec, and over-annotating accessors is the tell that someone carried the habit across.

### Reads

- A method that finds by **criteria** returns `Page<T>` or `Slice<T>` with a `Pageable` (named per `code-style.md`); what may bound a `List` instead is `persistence/core.md` → *Reads*. `Page` costs a second `countDocuments`; `Slice` fetches one extra document and reports only whether more exist — prefer it when the caller renders no total.
- ⚠ **`Pageable` applies exactly the sort you give it**, so core's unique-sort rule is yours to meet.
- ✅ **A walk of a whole collection returns `Window<T>` and takes a `ScrollPosition`** — keyset scrolling built in: Spring Data appends `_id` to the sort itself, so this path is tie-break-safe by construction where `Pageable` is not.
- A projection is an interface or record return type, or `@Query(fields = …)`.
- Pipelines are `@Aggregation` on a repository method (or `MongoTemplate.aggregate` in a fragment), bound to a dedicated `*Aggregation` record.

### Index ownership

⚠ **`@Indexed` and `@CompoundIndex` create nothing by default.** Spring Data's automatic index creation is off unless `spring.data.mongodb.auto-index-creation` is switched on, so an annotation added and shipped is a silent no-op — and switching it on is the wrong fix: it would build indexes at startup, on every replica, stalling a rollout on a large collection. Indexes ship in the project's migration (`core.md` → *Schema and indexes*); `@Indexed(expireAfter = …)` is inert for the same reason.

A unique index's violation arrives as `DuplicateKeyException`.

### A shared lock is a document

Cross-instance mutual exclusion (`concurrency.md`, `patterns.md` → *Batch, scheduled and bulk workloads*) is the neutral variant's lock document, and the claim maps as above: the `DuplicateKeyException` means someone else holds it.

⚠ **Claim it with `insert`, never `save()`.** `save()` upserts by `_id`, so a second replica's call replaces the holder's document and both run the job — the whole-document-replace rule above, in the one place where it hands you a correctness bug rather than lost fields.
