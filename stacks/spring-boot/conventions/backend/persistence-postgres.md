## Persistence — PostgreSQL

The `postgres` variant of this stack's persistence doc: `/backend` reads it when `frameworks.database: postgres` is declared in `.agent-kit-local/structure.yml`. A second database means a second `persistence-<db>.md` beside this one, not a fork of the stack.

Read together with `.agent-kit/persistence/core.md` and the neutral `.agent-kit/persistence/persistence-postgres.md`, which carry the engine rules; this doc says how Spring Data JPA expresses them, and wins where they differ.

**Spring Data JPA 4.1 over Jakarta Persistence 3.2** — and the provider is **not** a gap: `spring-boot-starter-data-jpa` pulls Hibernate transitively, so Hibernate behaviour below is stated, not hedged. Every JPA invariant still holds; Spring Data changes who writes the query, not what the persistence context does.

### The repository boundary

One **interface** per aggregate root extending `JpaRepository<T, ID>`. Derived method names first, `@Query` (JPQL) when derivation stops being readable, native SQL only where the dialect is the point. No class holds an `EntityManager`: when the interface genuinely cannot express a query, add a `…RepositoryCustom` fragment, and that fragment is then **the only** type touching `EntityManager`, `CriteriaBuilder` or a provider type. None of them reaches a service.

✅ **Prefer a derived name over `@Query` where both work.** Query methods are resolved when the repository proxy is built and Boot bootstraps repositories eagerly, so a misspelled property fails the application context at startup rather than the first request that hits it — and a derived name is checked against the metamodel, which a JPQL string is not.

⚠ **JPA is change-tracking: a managed entity is a write handle, not a value.** A setter inside the transaction is an `UPDATE` at commit (`core.md` → *The repository boundary*). The mapper converts it to a DTO inside the owning transaction (`patterns.md`).

⚠ **`save()` is `persist` *or* `merge`, decided by `isNew`, and the rule is not "does the row exist".** `isNew` is *id is null* — unless the entity has a **non-primitive** `@Version`, in which case it is *version is null*. Two consequences that bite:

- An entity whose id the application assigns is **never** new, so every `save()` merges: a `SELECT` before the insert, and a half-filled object writes null over every column it did not carry. The write succeeds. Give such an entity a `Long version`, or insert through a fragment.
- A `long version` (primitive) silently reverts `isNew` to the id check. Declare the version as a wrapper.

⚠ **Use the returned instance, never the argument, after a `save()` that merged** — merge copies into a *different* managed object, so mutations to the argument go nowhere. On an entity already managed in this transaction `save()` changes nothing either way; dirty checking has it.

### Transactions

`org.springframework.transaction.annotation.Transactional` on the **service** method — that is the boundary. ⚠ `jakarta.transaction.Transactional` is also honoured and has no `readOnly`, so code ported from a Jakarta EE project silently loses every read-only hint. Use the Spring annotation.

- ⚠ **It is a proxy.** A call from inside the same bean never passes through it, and only **public** methods are considered — an annotated protected or package-private method is silently non-transactional, with no warning.
- ⚠ **A checked exception commits.** Rollback is on `RuntimeException` and `Error` only. Domain exceptions are unchecked, or named in `rollbackFor`.
- **Inherited repository methods are already transactional; the ones you declare are not.** `SimpleJpaRepository` carries `@Transactional(readOnly = true)` on the class and `@Transactional` on the writers, so `findById`/`save`/`delete` each open one if none is running. A *derived* query method has no implementation behind it, so Spring Data attaches no transaction attribute at all — it joins the caller's transaction, or runs outside one. A service calling three repository methods with no annotation of its own gets three transactions and no atomicity.
- ⚠ **`readOnly = true` puts Hibernate in `FlushMode.MANUAL`** — a mutation of a managed entity inside it is *never written*, and nothing throws. A read path that normalizes a field, or a mapper that touches the entity, reads as working and silently loses the write. This is the flush-timing trap with the failure inverted: not "the write lands somewhere surprising" but "the write never lands".
- ⚠ **Boot auto-configures a single-resource `JpaTransactionManager`**, so a `@Transactional` method that also writes to a queue, a cache or a second database is **not** atomic across them and nothing says so (`core.md` → *Transactions*).
- ⚠ **Entities detach when the transaction ends**, so a method returning one hands out detached state.

⚠ **Open Session In View is ON by default** (`spring.jpa.open-in-view`, servlet applications). An `EntityManager` stays bound to the request thread past the commit, so a lazy association touched in a controller, a serializer or a template silently loads — one query per row, outside any transaction. N+1 therefore never surfaces in development, and the identical code throws the moment that call comes from a scheduler, a listener or a test. Boot logs one startup WARN while the property is unset. **Set it to `false`** and fetch what the caller needs in the query.

### Entity mapping

- The entity is a **mutable, non-final class with a no-arg constructor** — 3.2 states outright that a record may not be an entity. `code-style.md`'s mutability carve-out, required by the spec rather than preferred.
- **Only the owning side is persisted.** The side without `mappedBy` owns the FK column or the join table; setting only the inverse leaves the column null and the change vanishes on re-read, with no error. Give the aggregate root one method that sets both ends.
- ⚠ **Mutate a collection field in place, never reassign it** — replacing it discards Hibernate's tracking wrapper, and with orphan removal on it fails outright.
- **Declare the id strategy; never `AUTO`.** Here that is `SEQUENCE`, never `IDENTITY` (why: the neutral variant → *Ids and sequences*) — with `IDENTITY`, Hibernate's insert batching is off for that entity permanently.
- ⚠ **`@SequenceGenerator.allocationSize` defaults to 50** — the block size the neutral variant says the sequence's `INCREMENT BY` must match. Hibernate compares them at bootstrap and fails the deployment by default; never weaken that to a log line.
- ⚠ **Boot's default physical naming strategy is Hibernate's snake-case one**, so `orderDate` maps to `order_date` and `OrderLine` to `order_line` with no annotation. Migration DDL that spells a column any other way is a boot-time `validate` failure at best and a missed column at worst — write the migration to match, rather than pinning `@Column(name = …)` on every field.
- **An embedded VO is a record** — 3.2 admits a record as `@Embeddable` and waives the no-arg constructor for it, so `patterns.md`'s rule holds here as written. ⚠ It may carry no `@Id` or `@EmbeddedId` **field of its own** — 3.2 forbids that outright; an embeddable wanting identity is an entity, and entities may not be records. A composite key is no exception: `@EmbeddedId` goes on the **owning entity's** field, so the key type is an ordinary `@Embeddable` with no id field inside it — free to be a record (an `@IdClass` type need not be annotated at all). This stack's `SEQUENCE` ids mean you should not need one.

### Fetching — N+1 is the default, not the accident

An unfetched association loads one row at a time, on access. Every test on a two-row fixture passes — and under OSIV above, so does every manual click-through.

- **`@ManyToOne` and `@OneToOne` default to EAGER by specification.** Declare `fetch = LAZY` on every one — eager-by-default is how a single find drags half the schema in.
- **Fetch per query, not per mapping**: `@EntityGraph` on the method, or `JOIN FETCH` inside `@Query`, chosen by what that call needs, and **one collection at most**. ⚠ Two `List` collections throw `MultipleBagFetchException` at startup; two `Set`s do not throw — they quietly return the cartesian product.
- ⚠ **`Page<T>` and a collection fetch do not combine, and `Pageable` makes it look as if they do.** The join multiplies rows, so the limit cannot be applied in SQL: Hibernate logs `WARN … firstResult/maxResults specified with collection fetch; applying in memory`, loads the *entire* result set and pages it in the heap. The page is correct, nothing fails, and the service dies on the day the table grows. Page the ids in one query, then fetch `WHERE id IN :ids` in a second.

### Reads

- **A projection is an interface or record return type** — read-only, so nothing dirty-checks it.
- **Paging is `Pageable` + `Page<T>` or `Slice<T>`**, never hand-written offset arithmetic. `Page` issues a second count query; `Slice` fetches `pageSize + 1` and reports only whether more exist. Use `Slice` when the caller does not render a total. What may bound a `List` instead is `persistence/core.md` → *Reads* (`code-style.md` → repository naming).
- ⚠ **`Pageable` applies exactly the sort you gave it**, so core's unique-sort rule is yours to meet.
- ✅ **A walk of a whole table returns `Window<T>` and takes a `ScrollPosition`** — keyset scrolling built in: Spring Data appends the id attribute to the sort itself, so this path is tie-break-safe by construction where `Pageable` is not.
- **Declare `Optional<T>` for a single-result finder** (`code-style.md` → `*Optional`). A miss is an empty `Optional`, not an exception to catch. ⚠ A second match throws `IncorrectResultSizeDataAccessException`, where a `List` return would silently hand back one row.

### Writes

- **Dirty checking is the change tracking** core's *Read paths do not mutate* is about; defaults live only in the creation factory (`patterns.md`).
- ⚠ **Flush is not where you wrote the line** — it happens before an affected query and at commit, so a constraint violation surfaces at an unrelated statement, or after the method returned where no `catch` inside it can see it.
- **Cascade only down a composition you own.** `CascadeType.ALL` on a `@ManyToOne` cascades removal *up* into the shared parent; `orphanRemoval` also deletes on dissociation — right for an owned child, a disaster for a shared reference.
- ⚠ **A `@Modifying @Query` bulk `UPDATE`/`DELETE` bypasses the persistence context**, skipping `@Version`, lifecycle callbacks and cascade. Worse here: `clearAutomatically` and `flushAutomatically` both default to **false**, so entities already loaded in that transaction keep their stale values and a pending change flushed afterwards overwrites the bulk statement. Set both, or run the statement in its own transaction with no entities loaded.
- ⚠ **A derived `deleteBy…` is not a bulk delete.** Spring Data selects the matching rows and calls `remove` on each one — correct for cascade and `@Version`, and a table scan plus N deletes for anything wide. Set-based work is an explicit `@Modifying @Query`.
- ⚠ **JDBC batching is off by default** (`hibernate.jdbc.batch_size` defaults to 0), and `saveAll()` is a plain loop over `save()` — one statement per row however many entities you pass. Set the batch size deliberately; the `SEQUENCE` id strategy above is its precondition.
- A deadlock victim arrives as `CannotAcquireLockException`; retry it like a lost version race (the neutral variant → *Transactions and failure*).

### Optimistic locking

Any read-modify-write concurrent requests can hit carries a `@Version` field (a wrapper type — see `isNew` above). Hibernate puts the version predicate in the `UPDATE`; a no-match arrives as `JpaOptimisticLockingFailureException`, translated on the repository proxy. Never assign the field.

⚠ **It arrives at flush or commit, not at the setter**, so a retry loop *inside* the transactional method never runs — and by then the context is unusable: any `PersistenceException` bar a few query-level ones marks the transaction rollback-only. The retry sits outside (`core.md` → *Concurrency*), in a caller with no `@Transactional` of its own; the engine's own reason is in the neutral variant.

⚠ **Putting that loop in another method of the same bean is the standard way to get it wrong** — self-invocation skips the proxy, so every "fresh transaction per attempt" is the same doomed one. The retry lives in a different bean, or the inner call is `Propagation.REQUIRES_NEW` reached through an injected reference.

⚠ **A change on the inverse (`mappedBy`) side moves no version.** Where the collection is part of the invariant, force the increment on the root (`LockModeType.OPTIMISTIC_FORCE_INCREMENT`).

### Schema, migrations and indexes

- **DDL belongs to a versioned migration tool** (Flyway or Liquibase), run by the integration tier too (`testing.md`).
- ⚠ **`spring.jpa.hibernate.ddl-auto` is not off by default.** Boot resolves it to `none` against a real database but to **`create-drop` against an embedded one** — unless a migration tool on the classpath reports the schema as managed, which pushes it back to `none`. So whether a slice test on H2 runs against a Hibernate-generated schema depends on what else the test context happened to load: where it does, the test proves nothing about the migration and passes while production's `validate` would fail. Run the integration tier against a real Postgres (Testcontainers) with `ddl-auto: validate`.
- **`validate` fails a boot on a missed migration; it is not proof the schema matches** — what gets compared is the provider's choice, not a spec requirement.
- Every `@ManyToOne` column gets an explicit index in the migration (the neutral variant → *Indexes and constraints*). A unique-constraint violation arrives as `DataIntegrityViolationException`, its name buried in the cause chain.

### A shared lock is a row

Cross-instance mutual exclusion (`concurrency.md`, `patterns.md` → *Batch, scheduled and bulk workloads*) is the neutral variant's lock row, claimed by its conditional `UPDATE` as a `@Modifying @Query`: a return of 1 means you hold it; 0 means someone else does. Claim and release are each their own transaction. ⚠ Three transactions here means three *proxied* calls; self-invocation collapses them into one.
