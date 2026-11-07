## Persistence — PostgreSQL

The `postgres` variant of this stack's persistence doc: `/backend` reads it when `frameworks.database: postgres` is declared in `.agent-kit-local/structure.yml`. A second database means a second `persistence-<db>.md` beside this one, not a fork of the stack.

Read together with `.agent-kit/persistence/core.md` and the neutral `.agent-kit/persistence/persistence-postgres.md`, which carry the engine rules; this doc says how Jakarta Persistence expresses them, and wins where they differ.

**Jakarta Persistence 3.2** — the Jakarta EE 11 baseline, not Spring Data.

⚠ RUNTIME GAP — the JPA provider (Hibernate, EclipseLink, …). It decides identity-generation defaults, JDBC batching, second-level cache, bytecode enhancement, and what a lazy access on a detached entity throws. Every rule below holds on either. Fill when it is chosen — **do not assume Hibernate**.

### The repository boundary

One repository per aggregate root, `@ApplicationScoped`, and **the only type that touches `EntityManager`, `TypedQuery`, `CriteriaBuilder`, `Tuple` or a provider type**. Every query a domain needs is a named method on it (`architecture.md`).

⚠ **JPA is change-tracking: a managed entity is a write handle, not a value.** There is no `save()` — a setter on a managed entity is an `UPDATE` at commit (`core.md` → *The repository boundary*). The mapper converts it to a DTO inside the owning transaction (`patterns.md`).

⚠ **Never write a `save(entity)` that calls `merge` "to be safe."** On a managed entity it buys nothing; on a **detached** one it copies every field, so an object the request half-filled writes null over every column it did not carry — and the write succeeds.

### One persistence context, one transaction

- **The `EntityManager` is container-managed and transaction-scoped.** `@PersistenceContext` gives a proxy bound to the current JTA transaction. Never `Persistence.createEntityManagerFactory` in application code — that hands you a manager nothing enrols in the transaction. `EXTENDED` needs a stateful session bean and has no place here.
- ⚠ **`@PersistenceContext` targets types, fields and methods — not a constructor parameter.** Same trap as `@Resource` in `concurrency.md`, same fix: one `@ApplicationScoped` producer holds the annotated field and `@Produces` the `EntityManager`, so repositories inject it by constructor and still build with plain `new` (`testing.md`). It must yield that **container proxy** — an application-managed manager in an `@ApplicationScoped` field is not thread-safe.
- **`@Transactional` covers JPA — once the unit is *enlisted*.** That means `transaction-type="JTA"` **on a `<jta-data-source>`**, the precondition `architecture.md` sends you here for. `JTA` alone is not enough: a unit pointed at a `<non-jta-data-source>`, or at a pool nothing enlists, commits independently while the annotated method reads as atomic, with no error. A `RESOURCE_LOCAL` unit is not the silent half — `@PersistenceContext` is container-managed by definition, so that pairing fails outright. Being a CDI interceptor, it fires only through an injected reference (`patterns.md`). The boundary is the service method; a resource is never transactional.
- ⚠ **A checked exception commits.** `jakarta.transaction.Transactional` rolls back on unchecked exceptions and `Error` only, so a checked domain exception leaves the partial write committed. Domain exceptions are unchecked, or named in `rollbackOn`.
- ⚠ **Entities detach when the transaction ends**, so a lazy association touched after it fails (the exception type is provider-specific) and a method returning an entity hands out detached state. Map inside the boundary.

### Entity mapping

- The entity is a **mutable, non-final class with a no-arg constructor** — 3.2 states outright that a record may not be an entity. `code-style.md`'s mutability carve-out, required by the spec rather than preferred.
- **Only the owning side is persisted.** The side without `mappedBy` owns the mapping — the FK column, or the join table; setting only the inverse leaves the column null and the change vanishes on re-read, with no error. Give the aggregate root one method that sets both ends.
- ⚠ **Mutate a collection field in place, never reassign it** — replacing it discards the provider's tracking wrapper, and with orphan removal on, some providers fail outright.
- **Declare the id strategy; never `AUTO`**, which resolves differently per provider. Here that is `SEQUENCE`, never `IDENTITY` (why: the neutral variant → *Ids and sequences*). ⚠ RUNTIME GAP — JDBC batch settings are provider territory; 3.2 standardizes none.
- ⚠ **`@SequenceGenerator.allocationSize` defaults to 50** — the block size the neutral variant says the sequence's `INCREMENT BY` must match. Detection is the provider's choice, not the spec's: Hibernate queries the sequence at bootstrap and fails the deployment; assume nothing else does.
- **An embedded VO is a record** — 3.2 admits a record type as `@Embeddable` and waives the no-arg constructor for it, so `patterns.md`'s rule holds here as written. ⚠ It may carry no `@Id` or `@EmbeddedId` **field of its own** — 3.2 forbids that outright; an embeddable wanting identity is an entity, and entities may not be records. A composite key is no exception: `@EmbeddedId` goes on the **owning entity's** field, so the key type is an ordinary `@Embeddable` with no id field inside it — free to be a record (an `@IdClass` type need not be annotated at all). This stack's `SEQUENCE` ids mean you should not need one.

### Fetching — N+1 is the default, not the accident

An unfetched association loads one row at a time, on access. Every test on a two-row fixture passes.

- **`@ManyToOne` and `@OneToOne` default to EAGER by specification.** Declare `fetch = LAZY` on every one — eager-by-default is how a single find drags half the schema in.
- **Fetch per query, not per mapping**: `JOIN FETCH` or an entity graph, chosen by what that call needs, and **one collection at most** — two produce a cartesian product.
- ⚠ **A collection `JOIN FETCH` and paging do not combine.** The join multiplies rows, so the limit cannot be applied in SQL and the provider pages in memory over the whole result. Page the ids in one query, then fetch `WHERE id IN :ids` in a second.

### Reads

- **JPQL, as a `@NamedQuery` when the query is static** — providers parse those at persistence-unit startup, so a typo fails the deployment rather than the first request that hits it. Criteria is for a query whose *shape* varies with input, never the default dialect. Bind parameters in both.
- **A projection is a constructor expression into a record** (`code-style.md` → `Aggregation`) — read-only, so nothing dirty-checks it. ⚠ It names the class as a **string**, which no compiler checks.
- Paging, the unique sort and the keyset walk are `persistence/core.md` → *Reads*; what may bound a `List` is there too (`code-style.md` → repository naming).
- **A `*Optional` method (`code-style.md`) is `Optional.ofNullable(query.getSingleResultOrNull())`** — a miss is a null, not a `NoResultException` to catch. ⚠ It throws `NonUniqueResultException` on a second match, where `getResultStream().findFirst()` silently returns one of them. That throw leaves the transaction usable.

### Writes

- **Dirty checking is the change tracking** core's *Read paths do not mutate* is about; defaults live only in the creation factory (`patterns.md`).
- ⚠ **Flush is not where you wrote the line** — it happens before an affected query and at commit, so a constraint violation surfaces at an unrelated statement, or after the method returned where no `catch` inside it can see it.
- **Cascade only down a composition you own.** `CascadeType.ALL` on a `@ManyToOne` cascades removal *up* into the shared parent; `orphanRemoval` also deletes on dissociation — right for an owned child, a disaster for a shared reference.
- ⚠ **A bulk JPQL `UPDATE`/`DELETE` bypasses the persistence context**, skipping `@Version`, lifecycle callbacks and cascade, and leaving managed entities stale. Keep it to set-based work in its own transaction, never mixed with entities loaded in that one.

### Optimistic locking

Any read-modify-write concurrent requests can hit carries a `@Version` field. The provider puts the version predicate in the `UPDATE` and raises `OptimisticLockException` when no row matches. Never assign the field.

⚠ **It arrives at flush or commit, not at the setter**, so a retry loop *inside* the transactional method never runs — and by then the context is unusable: any `PersistenceException` bar a few query-level ones marks the transaction rollback-only. The retry sits outside (`core.md` → *Concurrency*); the engine's own reason is in the neutral variant.

⚠ **Outside the boundary it does not arrive as itself.** The commit happens inside the interceptor, so a `catch (OptimisticLockException)` out there never fires and the symptom is the original 5xx — the retry reads as working. ⚠ RUNTIME GAP — whether the original is still reachable down the **cause chain** is the transaction manager's call: JTA mandates a wrapping exception only for `MANDATORY` outside a transaction and `NEVER` inside one, nothing for a commit-time failure. Matching on the chain is the only detection this retry has, so verify it on the chosen runtime.

⚠ **A change on the inverse (`mappedBy`) side moves no version.** Whether a collection the entity *owns* through a join table moves it is provider policy rather than spec, so never rely on one to protect the aggregate. Where the collection is part of the invariant, force the increment on the root (`LockModeType.OPTIMISTIC_FORCE_INCREMENT`).

### Schema, migrations and indexes

- **DDL belongs to a versioned migration tool** (Flyway or Liquibase), run by the integration tier too (`testing.md`).
- ⚠ **Provider schema generation is not a migration.** Keep `jakarta.persistence.schema-generation.database.action` at `none` or `validate`: the other standard values create or drop, none reconciles, and they run on every replica at boot. With generation off, `@Column(length = …)` and `@Index` create nothing.
- **`validate` is standard on 3.2, and standard is not portable.** The action, `SchemaManager.validate()` and the checked `SchemaValidationException` are all spec — but the spec requires no *specific* validation, so what gets compared is the provider's choice. Enable it to fail a boot on a missed migration; never treat it as proof the schema matches.
- Every `@ManyToOne` column gets an explicit index in the migration (the neutral variant → *Indexes and constraints*). A constraint's name arrives buried in the provider exception's cause chain.

### A shared lock is a row

Cross-instance mutual exclusion (`concurrency.md`, `patterns.md` → *Batch, scheduled and bulk workloads*) is the neutral variant's lock row, claimed by its conditional `UPDATE`: `executeUpdate()` returning 1 means you hold it; 0 means someone else does. Claim and release are each their own transaction.
