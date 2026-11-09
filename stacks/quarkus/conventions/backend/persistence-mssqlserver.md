## Persistence — Microsoft SQL Server

The `mssqlserver` variant of this stack's persistence doc: `/backend` reads it when `frameworks.database: mssqlserver` is declared in `.agent-kit-local/structure.yml`. A second database means a second `persistence-<db>.md` beside this one, not a fork of the stack.

Read together with `.agent-kit/persistence/core.md` and the neutral `.agent-kit/persistence/persistence-mssqlserver.md`, which carry the engine rules — isolation, `READ_COMMITTED_SNAPSHOT`, collation, the clustered key; this doc says how Hibernate ORM with Panache expresses them, and wins where they differ.

**`quarkus-hibernate-orm-panache` over `quarkus-jdbc-mssql`, blocking, repository pattern, on Jakarta Persistence 3.2.** The provider is **not** a gap: the extension is Hibernate ORM, at the version the Quarkus BOM pins (7.4 on Quarkus 3.40), so Hibernate behaviour below is stated, not hedged. Panache changes who writes the query, not what the persistence context does. `quarkus-hibernate-panache-next`, also in the BOM, is a relocation to `quarkus-data-hibernate`, whose descriptor reads `status: experimental`; this stack prescribes the classic extension.

### The repository boundary

One `@ApplicationScoped` repository per aggregate root, implementing `PanacheRepository<Order>` (a `Long` id, which the `SEQUENCE` strategy below yields) or `PanacheRepositoryBase<Order, ID>` for another id type, injected into services. The entity is a plain `@Entity` class, never `PanacheEntity`. The repository is the only type touching `EntityManager`, `Session`, Criteria or a Hibernate query type, and `PanacheQuery` beyond paging; its handle is `getEntityManager()`. Where it needs one injected, `@Inject EntityManager` on a constructor parameter works with no producer: a field annotated `@PersistenceContext` is rewritten to the same injection.

⚠ **A repository cannot be built with `new` outside a booted application**: its Panache methods are generated into it at build time, and the defaults throw. Test services against a mocked repository, and the repository at the integration tier (`testing.md`).

⚠ **JPA is change-tracking: a managed entity is a write handle, not a value.** There is no `save()` — `persist` is for a new entity and does nothing to a managed one — and a setter inside the transaction is an `UPDATE` at commit (`core.md` → *The repository boundary*). The mapper converts it to a DTO inside the owning transaction (`patterns.md`).

⚠ **Never write a `save(entity)` that calls `merge` "to be safe."** On a managed entity it buys nothing; on a **detached** one it copies every field, so an object the request half-filled writes null over every column it did not carry — and the write succeeds.

### One persistence context, one transaction

`jakarta.transaction.Transactional` on the **service** method is the boundary (`patterns.md`); a resource is never transactional.

- **The injected `EntityManager` is a proxy onto the session of the current transaction**, opened on first use and closed when the transaction ends.
- ⚠ **Outside a transaction it is not off.** Inside a request, `quarkus.hibernate-orm.request-scoped.enabled` (default `true`) hands out, to a read that runs with no `@Transactional` (an unannotated service method, a repository reached directly), a read-only session living until the request ends; what it returns stays attached, so a lazy association touched in a resource or mapper silently loads, one query per row, outside any transaction, and a write throws `TransactionRequiredException`. **Set it to `false`**, as the property's own documentation recommends: a read outside a transaction then fails at once with `ContextNotActiveException`. ⚠ That includes a `@QuarkusTest` that seeds or reads back through a repository without a transaction, even one `testing.md` tells you to leave without `@TestTransaction`: read through `QuarkusTransaction.requiringNew().call(…)` or a `@Transactional` test method. A `@Scheduled` job that reads a repository directly needs the same.
- **The datasource is enlisted by default.** `quarkus.datasource.jdbc.transactions=disabled` removes it from the transaction manager, so `@Transactional` stops covering it (`core.md` → *Transactions*). A second resource in the same method is not atomic with this one unless both are XA-enlisted (`quarkus.datasource.jdbc.transactions=xa` here) and the engine-side setup the neutral variant names is in place.
- ⚠ **A checked exception commits** (`patterns.md`).
- ⚠ **Entities detach when the transaction ends**, so a lazy association touched after it throws `LazyInitializationException` and a method returning an entity hands out detached state. Map inside the boundary.

### Entity mapping

- The entity is a **mutable, non-final class with a no-arg constructor** — 3.2 states outright that a record may not be an entity. `code-style.md`'s mutability carve-out, required by the spec rather than preferred.
- **Only the owning side is persisted.** The side without `mappedBy` owns the FK column or the join table; setting only the inverse leaves the column null and the change vanishes on re-read, with no error. Give the aggregate root one method that sets both ends.
- ⚠ **Mutate a collection field in place, never reassign it** — replacing it discards Hibernate's tracking wrapper, and with orphan removal on, the flush fails with "A collection with orphan deletion was no longer referenced by the owning entity instance".
- **Declare the id strategy; never `AUTO`.** Here that is `SEQUENCE` over a `bigint`, never `IDENTITY` or `GenerationType.UUID` (why: the neutral variant → *Ids and the clustered key*), with the sequence named in `@SequenceGenerator(sequenceName = …)` so the migration and the mapping share one literal.
- ⚠ **`@SequenceGenerator.allocationSize` defaults to 50** — the block size the neutral variant says the sequence's `INCREMENT BY` must match. **Quarkus switches off Hibernate's own bootstrap check** (it sets the mismatch strategy to `NONE`, leaving the job to schema validation), so a mismatch boots cleanly and re-issues ids under load. `schema-management.strategy=validate` is the check (*Schema, migrations and indexes*).
- **Tables and columns are snake_case, through one setting:** `quarkus.hibernate-orm.physical-naming-strategy=org.hibernate.boot.model.naming.PhysicalNamingStrategySnakeCaseImpl`, so `orderDate` maps to `order_date` and `OrderLine` to `order_line` with no annotation. ⚠ Without it, Hibernate's default keeps the logical name and Quarkus adds no other: `orderDate` maps to a column `orderDate`. Migration DDL spells every name snake_case to match; a mismatch is a `validate` failure at best and a missed column at worst. `@Column(name = …)` is for a legacy name that breaks the pattern, never a per-field habit.
- **An embedded VO is a record** — 3.2 admits a record as `@Embeddable` and waives the no-arg constructor for it, so `patterns.md`'s rule holds here as written. ⚠ It may carry no `@Id` or `@EmbeddedId` **field of its own** — 3.2 forbids that outright; an embeddable wanting identity is an entity, and entities may not be records. A composite key is no exception: `@EmbeddedId` goes on the **owning entity's** field, so the key type is an ordinary `@Embeddable` with no id field inside it — free to be a record (an `@IdClass` type need not be annotated at all). This stack's `SEQUENCE` ids mean you should not need one.

### Fetching — N+1 is the default, not the accident

An unfetched association loads one row at a time, on access. Every test on a two-row fixture passes — and, with `request-scoped.enabled` left on and the read outside a transaction, so does every manual click-through.

- **`@ManyToOne` and `@OneToOne` default to EAGER by specification.** Declare `fetch = LAZY` on every one — eager-by-default is how a single find drags half the schema in.
- **Fetch per query, not per mapping**: `join fetch` in the `find` string — one starting `from`, `select` or `with` reaches Hibernate untouched, any other is taken as a `where` clause — or an entity graph through `withHint("jakarta.persistence.fetchgraph", graph)`; chosen by what that call needs, and **one collection at most**. ⚠ Two `List` collections throw `MultipleBagFetchException`; two `Set`s do not throw — they quietly return the cartesian product.
- ⚠ **`page()` and a collection `join fetch` do not combine.** The join multiplies rows, so the limit cannot be applied in SQL: Hibernate logs `WARN … firstResult/maxResults specified with collection fetch; applying in memory`, loads the *entire* result set and pages it in the heap. The page is correct, nothing fails, and the service dies on the day the table grows. Page the ids in one query, then fetch `where id in :ids` in a second. ✅ `quarkus.hibernate-orm.query.fail-on-pagination-over-collection-fetch=true` (default `false`) turns the warning into an exception.

### Reads

- **HQL, as a `@NamedQuery` when the query is static** — Hibernate checks named queries at boot, so a typo fails the start instead of the first request that hits it; reach one with `find("#Invoice.byStatus", …)`, and put its `order by` in the query, since a named query takes no `Sort`. An inline `find("…")` string is parsed at its first call: it needs an integration test (`testing.md`). Bind parameters; never concatenate.
- **A projection is `project(Class)` onto a record** — read-only, so nothing dirty-checks it. The constructor's parameter names are the entity's attribute names (`@ProjectedFieldName` renames one) and the build needs `-parameters`; a query already shaped `select new …` cannot be projected.
- **Paging is `page(index, size)` or `page(Page.of(index, size))`**, 0-based, never hand-written offset arithmetic. `range(first, last)` takes an **inclusive** last index. ⚠ Panache adds no sort, so `Sort.by(…)` and core's unique-sort rule are yours to meet. `hasNextPage()`, `pageCount()` and `count()` each rest on a derived count query, cached per `PanacheQuery`: leave them out when the caller renders no total.
- **A walk of a whole table is keyset** (`core.md` → *Reads*): Panache has none built in, so write `find("id > ?1", Sort.by("id"), last).page(0, size)` and carry the last id forward. ⚠ `stream(…)` needs a transaction — without one the cursor can close before the stream is read — and keeps the entities it returns in the persistence context.
- **Declare `Optional<T>` for a single-result finder** (`code-style.md` → `*Optional`), built on `singleResultOptional()`: a miss is empty, not an exception. ⚠ `firstResult()` takes the first of several without a word; `singleResultOptional()` throws `jakarta.persistence.NonUniqueResultException` on a second match, which leaves the transaction usable.

### Writes

- **Dirty checking is the change tracking** core's *Read paths do not mutate* is about; defaults live only in the creation factory (`patterns.md`).
- ⚠ **Flush is not where you wrote the line** — it happens before an affected query and at commit, so a constraint violation surfaces at an unrelated statement, or after the method returned where no `catch` inside it can see it.
- **Cascade only down a composition you own.** `CascadeType.ALL` on a `@ManyToOne` cascades removal *up* into the shared parent; `orphanRemoval` also deletes on dissociation — right for an owned child, a disaster for a shared reference.
- ⚠ **`deleteAll()`, `delete(String, …)` and `update(String, …)` are bulk HQL**: they bypass the persistence context, skipping `@Version`, lifecycle callbacks and cascade, and leave entities already loaded stale. `delete(entity)` and `deleteById(id)` load and remove, honouring cascade. Run a bulk statement in its own transaction with no entities loaded, or `flush()` before it and `getEntityManager().clear()` after — chunked by key range (lock escalation: the neutral variant). A set-based rewrite of versioned rows writes `update versioned Invoice set …`, which bumps each version; plain `update` does not.
- ⚠ **JDBC batching is off by default** (Hibernate's `batch_size` is 0, and Quarkus sets it only from `quarkus.hibernate-orm.jdbc.statement-batch-size`), and `persist(Iterable)` is a plain loop over `persist`. Set the batch size deliberately; the `SEQUENCE` id strategy above is its precondition.
- A deadlock victim (error 1205) arrives as `org.hibernate.exception.LockAcquisitionException`: the driver reports SQLState `40001`, which Hibernate converts, the SQL Server dialect having no mapping of its own for 1205. Retry it like a lost version race (the neutral variant → *Isolation is lock-based, not MVCC*). ⚠ `@Retry(retryOn = OptimisticLockException.class)` does not catch it, since `LockAcquisitionException` is not converted to a JPA exception: use `retryOn = { OptimisticLockException.class, LockAcquisitionException.class }` (`org.hibernate.exception.LockAcquisitionException`).

### Optimistic locking

Any read-modify-write concurrent requests can hit carries a `@Version` field (a `Long`, `code-style.md`). Hibernate puts the version predicate in the `UPDATE`; a no-match is `jakarta.persistence.OptimisticLockException`. Never assign the field.

⚠ **It arrives at flush or commit, not at the setter**, so a retry loop *inside* the transactional method never runs — and by then the context is unusable: any `PersistenceException` bar a few query-level ones marks the transaction rollback-only. The retry sits outside (`core.md` → *Concurrency*, `concurrency.md`); the engine's own reason is in the neutral variant.

⚠ **What the retrying caller catches depends on where the flush ran.** A flush inside the method raises `OptimisticLockException` as itself; the commit-time flush raises `jakarta.transaction.RollbackException` with it as the cause. `@Retry(retryOn = OptimisticLockException.class)` on the non-transactional caller matches both, because Quarkus runs Fault Tolerance with `smallrye.faulttolerance.mp-compatibility=false`, which inspects the cause chain. Set it to `true` and a commit-time conflict is no longer retried: a test that forces a real conflict is the guard (`testing.md`).

⚠ **A change on the inverse (`mappedBy`) side moves no version.** Where the collection is part of the invariant, force the increment on the root (`findById(id, LockModeType.OPTIMISTIC_FORCE_INCREMENT)`).

### Schema, migrations and indexes

- **DDL belongs to a versioned migration tool**, Flyway or Liquibase through its Quarkus extension, run by the integration tier too (`testing.md`). Flyway's engine support is its own module: add `quarkus-flyway-mssql` beside `quarkus-flyway`, which brings only `flyway-core`. Liquibase needs no engine extension.
- ⚠ **`migrate-at-start` is off by default** (`quarkus.flyway.…`, `quarkus.liquibase.…`). The extension marks the datasource schema-ready whether or not it migrates, so with the property unset the application boots on an empty schema and fails at its first query, or, under `validate`, at boot. Set it wherever the application owns its migration — always for the integration tier. Hibernate starts only after the tool has run, so `validate` sees the migrated schema.
- ⚠ **Schema generation is not a migration.** `quarkus.hibernate-orm.schema-management.strategy` defaults to `none`; keep it `none` or `validate`. `create`, `drop-and-create`, `drop` and `update` act on the database at boot, on every replica, and keep no history. (`database.generation` is its deprecated predecessor.)
- ⚠ **Dev Services can force `drop-and-create`.** In dev and test, when Dev Services supplies the datasource (no username configured in that profile), the strategy is unset, and no migration tool manages that datasource, Quarkus sets it. Flyway counts as managing it only if it finds migrations at build time. The test then runs on a Hibernate-generated schema, which proves nothing about the migration, passes where production's `validate` would fail, and hides every rule only a real SQL Server has: the collation, `READ_COMMITTED_SNAPSHOT`, the clustered key. Set `strategy=validate` in the `test` profile, with `migrate-at-start`.
- **`validate` fails a boot on a missed migration, and is what catches a sequence whose `INCREMENT BY` differs from `allocationSize`; it is not proof the schema matches** — what gets compared is the provider's choice, not a spec requirement.
- **Set `quarkus.datasource.db-version` to production's version.** The dialect is fixed at build time, so unset it is the dialect's floor (SQL Server 13, 2016, which Quarkus sets), not your database's version, which can disable features and cost performance. A database older than the dialect fails the boot.
- Every `@ManyToOne` column gets an explicit index in the migration (the neutral variant → *Indexes and constraints*).
- ⚠ **No JPA annotation expresses a filtered unique index** — the neutral variant's fix for a nullable unique column lives in the migration.
- **A unique-constraint violation arrives as `org.hibernate.exception.ConstraintViolationException`**, its rule name from `getConstraintName()` — at the flush: at commit, as a `RollbackException` caused by it, unless something flushed earlier. Where the repository must translate it to the domain exception (`api.md`), write with `persistAndFlush` and catch there.

### Collation and string types

- ⚠ **A `lower()` in HQL compiles to SQL `lower()`**, so it is not a reading of the collation — and must not disagree with the constraint (the neutral variant → *Collation and string types*).
- The JDBC driver sends string parameters as Unicode by default (`sendStringParametersAsUnicode` is `true`), so text columns are `NVARCHAR` (why: same section).

### Dev Services

Dev Services starts the database for dev and test (`testing.md`). Pin `quarkus.datasource.devservices.image-name` to production's version: the default is the extension's choice, not yours.

- ⚠ **SQL Server's image needs its licence accepted, and nothing in Quarkus does it.** The container is Testcontainers' `MSSQLServerContainer`, which refuses to start without `ACCEPT_EULA=Y`, so the application fails to boot in dev and test. Accept it with `quarkus.datasource.devservices.container-env.ACCEPT_EULA=Y`, or with a `container-license-acceptance.txt` at the classpath root (`src/test/resources`) holding the image name, exactly as `image-name` spells it, on a line of its own. Accepting a licence is the project owner's call: ask before adding either.
- ⚠ **Its database has none of production's settings.** Dev Services configures no collation and no `READ_COMMITTED_SNAPSHOT`. Where its settings cannot reproduce production's, point the integration tier at a database you created (a configured URL means no container, `testing.md`).

### A shared lock is a row

Cross-instance mutual exclusion (`concurrency.md`, `patterns.md` → *Batch, scheduled and bulk workloads*) is the neutral variant's lock row, with its own entity and repository. The claim is its conditional `UPDATE` as one repository method returning the affected-row count — native SQL through `getEntityManager().createNativeQuery(…)`, because the predicate reads the database's own clock, which is where the dialect is the point: 1 means you hold it; 0 means someone else does. Claim and release are each their own `@Transactional` method, called from a job method that has none: `@Transactional` joins an active transaction, so a transactional caller folds all three into one and the claim commits only when the job does. ⚠ ArC intercepts a self-call on a non-private method (`patterns.md`), so the three may share a bean.
