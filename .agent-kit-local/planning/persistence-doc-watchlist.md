# Watch-list — the six JPA persistence twins vs their source artifacts

**What this is.** `stacks/{jakarta-ee,spring-boot,quarkus}/conventions/backend/persistence-{postgres,mssqlserver}.md`
assert things about the Jakarta Persistence spec, Hibernate, Spring Data/Boot, Quarkus, and two database engines.
None of those live in this kit and all six move on their own schedule. Every row is a claim whose truth
lives in one of them — re-check the row when that artifact moves.

⚠ **No gate catches these.** There is no `persistence_doc_coverage`, and the messaging check it would copy
"asserts a *phrase is present*, not that the doc says anything true". Reading alone found 24 defects in one
pass over the docs, then seven more in the *replacement* sentences of that pass. This list is the
substitute for re-deriving ~8,700 words.

**How to use it.** Scan *Settled by* for the artifact that moved, check the row against it, fix the claim in
**both** twins of the pair (*Twin parity*, below). ⚠ *Settled by* says where to look — it is not a verdict.
Each claim was verified when written, never since.

**Artifacts, as pinned in `~/.m2/repository`** — everything but group 4 is readable on this machine:

| Group | Artifact | Version |
|---|---|---|
| 1 | `jakarta.persistence-api` (`-sources.jar`), `jakarta.transaction-api` | 3.2.0 · 2.0.1 |
| 2 | `hibernate-core` (`-sources.jar`) | 7.4.1.Final (spring-boot) · 7.4.9.Final (quarkus, as its BOM pins) |
| 3 | `spring-data-jpa`, `spring-boot-jpa`, `spring-boot-hibernate`, `spring-tx`/`spring-orm` | 4.1.0 · 7.0.8 |
| 4 | **none — see the group's banner** | — |
| 5 | `quarkus-hibernate-orm` (+ `-deployment`), `quarkus-hibernate-orm-panache` (+ `-common`), `quarkus-panache-hibernate-common`, `quarkus-panache-common`, `quarkus-flyway` / `quarkus-liquibase` (+ `-deployment`, `quarkus-flyway-{postgresql,mssql}`), `quarkus-agroal`, `quarkus-datasource-deployment`, `quarkus-devservices-{postgresql,mssql}`, `quarkus-narayana-jta`, `quarkus-smallrye-fault-tolerance`, `quarkus-data-hibernate` (`-sources.jar`) | 3.40.1 (BOM: `narayana-jta` 7.3.4.Final · `smallrye-fault-tolerance` 6.11.4 · `flyway-core` 12.0.0 · `testcontainers-mssqlserver` 2.0.5 · `mssql-jdbc` 13.4.0.jre11) |

---

## 1 · Jakarta Persistence 3.2 — moves on Persistence 3.3 / Jakarta EE 12

*Where* uses `jee-pg` · `jee-ms` · `sb-pg` · `sb-ms` · `q-pg` · `q-ms`; "both" means both twins of the stack under discussion.
`neutral pg` · `neutral ms` mean `common/.agent-kit/persistence/persistence-{postgres,mssqlserver}.md` — the
engine claims moved there, and the twins now point at them instead of restating.

| # | Claim | Where | Settled by | Falsified by |
|---|---|---|---|---|
| 1.1 | A record may not be an entity; a record **may** be `@Embeddable`, no-arg constructor waived | all six | `Entity` + `Embeddable` javadoc ("or a Java record type") | 3.3 relaxing the entity rule. ⚠ On 3.1 the embeddable half is simply absent — a stack moved below 3.2 invalidates it |
| 1.2 | An embeddable may carry no `@Id`/`@EmbeddedId` field **of its own**; a composite key is an instance of that rule, not an exception to it | all six | `Embeddable` javadoc, stated unconditionally | the javadoc gaining a carve-out. ⚠ This sentence was written wrong once as an "exception" and fixed in all four — re-read the javadoc, do not re-reason it |
| 1.3 | `getSingleResultOrNull()` returns null on a miss and throws `NonUniqueResultException` on a second match | all six | `Query#getSingleResultOrNull` javadoc, `@since 3.2`; Panache's `singleResultOptional()` rests on it (`CommonPanacheQueryImpl`) | its `@throws` list changing |
| 1.4 | That throw "leaves the transaction usable" | all six | `NonUniqueResultException` javadoc: "does not cause the current transaction … to be marked for rollback" | ⚠ the class javadoc's own prose scopes itself to `getSingleResult()`. The guarantee is class-level, so it carries — but if the javadoc ever becomes per-method, this row breaks and the `*Optional` rule with it |
| 1.5 | Any `PersistenceException` "bar a few query-level ones" marks the transaction rollback-only | all six | `PersistenceException` javadoc + each subtype's | ⚠ The docs never enumerate the carve-outs, deliberately (`doc-style.md`: a list you cannot enumerate at source must not be written as one). And `PersistenceException` conditions the marking on the context **having been joined** to the transaction — a precondition no twin states |
| 1.6 | `@SequenceGenerator.allocationSize` defaults to **50** and must match the migration's `INCREMENT BY` | all six | `SequenceGenerator#allocationSize` | the default changing. Detection is the provider's (2.3), the default is not |
| 1.7 | `@ManyToOne`/`@OneToOne` default to **EAGER** | all six | `ManyToOne`/`OneToOne` `fetch()` default | 3.3 flipping it — a long-proposed change, and the single most likely row in this group to move |
| 1.8 | `jakarta.transaction.Transactional` rolls back on unchecked + `Error` only | all six (spring-boot states it of the Spring annotation) | `jakarta.transaction.Transactional` javadoc; `spring-tx` for the Spring one; `quarkus-narayana-jta` → `TransactionalInterceptorBase#handleExceptionNoThrow` (`RuntimeException`/`Error`, or an exception class annotated `@Rollback`) for Quarkus | either default changing |
| 1.9 | JTA mandates a wrapping exception only for `MANDATORY` outside a transaction and `NEVER` inside one — nothing for a commit-time failure | `jee-pg` `jee-ms` | same javadoc | the javadoc adding a commit-time rule. This is the whole reason the cause-chain half is a RUNTIME GAP and not a fact |
| 1.10 | `@PersistenceContext` targets type/field/method, never a constructor parameter | `jee-pg` `jee-ms` | its `@Target` | the annotation gaining `PARAMETER` |
| 1.11 | A `RESOURCE_LOCAL` pairing fails **loud**; the silent case is a JTA unit nothing enlists | `jee-pg` `jee-ms` | `createEntityManager` / `getTransaction` javadoc | ⚠ this was once stated the opposite way, then over-corrected. Do not "simplify" the two halves back into one |
| 1.12 | The `validate` action, `SchemaManager.validate()` and checked `SchemaValidationException` are 3.2 **standard** — but the spec requires no *specific* validation | all six | `SchemaManager`, `SchemaValidationException`, the `schema-generation.database.action` constants | 3.1 ships none of these. The second half is a negative claim about the spec text, not about the API — the jar cannot confirm it, only fail to contradict it |
| 1.13 | Bulk JPQL `UPDATE`/`DELETE` bypasses the persistence context — no `@Version`, no callbacks, no cascade, managed entities left stale | all six | `Query#executeUpdate` javadoc + spec ch. 4 | unlikely to move; the row exists because the **staleness** clause was a twin asymmetry |
| 1.14 | A change on the *inverse* (`mappedBy`) side moves no version; whether an **owned** join-table collection does is provider policy | all six | `Version` javadoc — which says nothing about relationships | the spec taking a position, which would let the hedge become a fact. `@OptimisticLock(excluded=true)` existing is the tell that it is Hibernate's call |

## 2 · Hibernate 7.4.1.Final (spring-boot) · 7.4.9.Final (quarkus)

⚠ **Every row here is invalid if the project swaps the provider**, and both spring-boot twins state Hibernate
flat on the grounds that `spring-boot-starter-data-jpa` pins it. That is true of the **starter**, not of the
project: an app may exclude it and run EclipseLink, at which point these lines are wrong and nothing in the
doc hedges. The quarkus twins state it flat for a stronger reason — `quarkus-hibernate-orm` *is* Hibernate ORM,
so there is no provider to swap — but at their own version, 7.4.9.Final as the 3.40.1 BOM pins it. jakarta-ee
carries the RUNTIME GAP banner the other two deliberately do not — so a rule promoted from one stack to
another crosses that line silently.

| # | Claim | Where | Settled by | Falsified by |
|---|---|---|---|---|
| 2.1 | In-memory pagination WARN: `firstResult/maxResults specified with collection fetch; applying in memory` | `sb-pg` `sb-ms` `q-pg` `q-ms` | `org.hibernate.query.QueryLogging`, id **HHH90003004** | the text or id changing. ⚠ The docs quote the *text*; the **id** is the stable handle — grep for it, not the sentence |
| 2.2 | Two `List` fetches throw `MultipleBagFetchException` (at startup for a derived Spring Data query; the quarkus twins do not say when); two `Set`s do not throw, they return the cartesian product | `sb-pg` `sb-ms` `q-pg` `q-ms` | `org.hibernate.loader.MultipleBagFetchException` | ⚠ the class settles only the first half. The `Set` half is runtime behaviour no declaration states — the weakest claim in this group |
| 2.3 | `SequenceMismatchStrategy` defaults to `EXCEPTION`, so an `allocationSize`/`INCREMENT BY` mismatch fails the deployment | `jee-pg` `jee-ms` `sb-pg` `sb-ms` (jakarta-ee scopes it: "Hibernate does; assume nothing else does"). ⚠ **False on Quarkus**, which sets the strategy to `NONE` — row 5.14, and the quarkus twins say so | `MappingSettings.SEQUENCE_INCREMENT_SIZE_MISMATCH_STRATEGY`, `@settingDefault EXCEPTION` | the default moving to `LOG`. Was once documented as "nothing checks it" |
| 2.4 | `hibernate.jdbc.batch_size` defaults to **0** | `sb-pg` `sb-ms` `q-pg` `q-ms` (Quarkus key: row 5.16) | `BatchSettings.STATEMENT_BATCH_SIZE`, `@settingDefault 0` | the default changing |
| 2.5 | `IDENTITY` disables insert batching for that entity permanently | `jee-pg` `jee-ms` `sb-pg` `sb-ms` (the quarkus twins leave it to the neutral variant's "defeats insert batching") | Hibernate behaviour, not a declaration | ⚠ jakarta-ee correctly marks the batching half RUNTIME GAP; spring-boot states it flat. Same fact, two registers — that is by design, not drift |
| 2.6 | Reassigning a collection field discards the tracking wrapper, and with orphan removal on "it fails outright" | `sb-pg` `sb-ms` `q-pg` `q-ms` (jakarta-ee hedges: "some providers") | Hibernate `PersistentCollection` behaviour; the failure half is `org.hibernate.engine.internal.Collections#processDereferencedCollection` ("A collection with orphan deletion was no longer referenced by the owning entity instance", thrown while the owner is not deleted) | the wrapper-discard half is behavioural, not declared. The spring-boot twins state it harder than jakarta-ee, and the quarkus twins quote the message — verify before promoting any wording across |

## 3 · Spring Data JPA 4.1 / Boot 4.1 / Framework 7 — moves on a Boot or Spring Data major

| # | Claim | Where | Settled by | Falsified by |
|---|---|---|---|---|
| 3.1 | `save()` is persist **or** merge, decided by `isNew`: id-null, unless a **non-primitive** `@Version`, then version-null. A primitive `long version` reverts it to the id check, and the merged copy is a *different* object — use the returned instance | both | `JpaMetamodelEntityInformation` / `JpaPersistableEntityInformation`, `SimpleJpaRepository#save` | the version branch changing. ⚠ Re-read the exact predicate before restating it — the primitive carve-out reads like a detail and is load-bearing |
| 3.2 | `SimpleJpaRepository` carries `@Transactional(readOnly = true)` on the class and `@Transactional` on the writers | both | that class's annotations | an annotation move |
| 3.3 | A **derived** query method receives **no** transaction attribute at all | both | the query-method execution path in spring-data-jpa | ⚠ Highest-churn claim in this group: it overturned a dispatch premise, then contradicted Tier-0 until corrected. Re-verify, never recall |
| 3.4 | `readOnly = true` puts Hibernate in `FlushMode.MANUAL`, so the write is silently lost | both | `spring-orm` `HibernateJpaDialect` | ⚠ Spring **plus** provider: the dialect applies it. Invalid under a different dialect, which the doc's flat register hides (see group 2's banner) |
| 3.5 | Boot auto-configures a **single-resource** `JpaTransactionManager` | `sb-pg` `sb-ms` | `spring-boot-jpa` → `JpaBaseConfiguration` | ⚠ It is `@ConditionalOnMissingBean(TransactionManager.class)` and not `@Primary` — so declaring a second manager *suppresses* it and unqualified resolution then throws. That correction landed in the **mongodb** variant only; these two state the simple version |
| 3.6 | OSIV is on by default (servlet), and Boot logs one startup WARN while the property is unset | both | `JpaBaseConfiguration$JpaWebConfiguration` — `@ConditionalOnBooleanProperty(name = "spring.jpa.open-in-view", matchIfMissing = true)`, warn just below | the condition or the warn being dropped |
| 3.7 | `spring.jpa.hibernate.ddl-auto` resolves to `none` against a real database but **`create-drop` against an embedded one** | both | `HibernateDefaultDdlAutoProvider#getDefaultDdlAuto` | ⚠ **Incomplete as written.** That method returns `none` for an embedded datasource too, whenever a `SchemaManagementProvider` reports it `MANAGED` — which Flyway/Liquibase does. Both docs prescribe a migration tool, so a reader following them may never see `create-drop`. **Check whether the slice test actually gets it** before trusting the H2 warning |
| 3.8 | Boot's default physical naming strategy is Hibernate's snake-case one | both | `HibernateProperties$Naming` → `PhysicalNamingStrategySnakeCaseImpl` (spring-boot-hibernate 4.1.0) | a default swap |
| 3.9 | `Page<T>` requires a `Pageable` parameter; the same method returning `Slice<T>` boots and runs **unpaged**, silently | both | the `Pageable`-parameter check, applied to `Page` only | that check widening to `Slice`. Added late, source-verified |
| 3.10 | `Window<T>` + `ScrollPosition` keyset scrolling appends the id attribute to the sort, so it is tie-break-safe "by construction" | both | spring-data-commons `Window`/`ScrollPosition` + the JPA keyset delegate | ⚠ "by construction" is the absolute to re-verify — `doc-style.md` → *Absolutes*. If it holds only for a derived method, the sentence overshoots |
| 3.11 | `@Modifying`'s `clearAutomatically` and `flushAutomatically` both default **false** | both | `Modifying.java` — `default false` on both (verified) | a default flip |
| 3.12 | A derived `deleteBy…` selects then removes per row; `saveAll()` is a plain loop over `save()` | both | `JpaQueryExecution.DeleteExecution`, `SimpleJpaRepository#saveAll` | either gaining a set-based path |
| 3.13 | Derived names resolve at proxy build and Boot bootstraps repositories eagerly, so a misspelled property fails the context at startup | both | `PartTree` prefix template; `JpaProperties$Bootstrap` for the eager default | lazy bootstrap becoming the default. ⚠ Related defect: `pageBy…` is **not** a derived verb — the prefix template is `find\|read\|get\|query\|search\|stream\|count\|exists\|delete\|remove`. That rule is correct on the hand-written-repository stacks and fatal here |
| 3.14 | Exception translation: `JpaOptimisticLockingFailureException`, `IncorrectResultSizeDataAccessException`, `DataIntegrityViolationException`, `CannotAcquireLockException` | both | `spring-orm` `EntityManagerFactoryUtils`; `SQLExceptionSubclassTranslator` for the SQL ones | a mapping change. ⚠ `CannotAcquireLockException` is reached via the driver's SQLState/vendor code, so it is half an **engine** claim — it can break without Spring moving |
| 3.15 | `jakarta.transaction.Transactional` is also honoured and has no `readOnly`, so a port silently loses every hint | both | `spring-tx` `JtaTransactionAnnotationParser` | Spring dropping JTA-annotation support |
| 3.16 | It is a proxy: self-invocation skips it, and only **public** methods are considered | both | `spring-tx`/`spring-aop` | ⚠ "only public" is true of the default proxy mode, not of AspectJ weaving. The docs state it unqualified — correct for the prescribed setup, wrong if a project weaves |

## 4 · Engine behaviour — PostgreSQL and SQL Server

⚠ **This is the weakest group, and the repo records no verification of any row in it.** Every verification
pass in this history names JVM artifacts and nothing else: the Persistence and Transactions API jars,
hibernate-core's sources, and the spec and framework jars. A search of the full commit history for a
vendor citation — postgresql.org, Microsoft Learn — **returns nothing**. So: these claims were authored from
the writer's own knowledge, corrected by *reading* (one pass fixed six "dialect claims" that way), and never
settled against vendor documentation. **Treat every row as inherited-without-check until someone does one.**

⚠ **And nothing on this machine can settle them.** `~/.m2` holds the JDBC *drivers*; a driver is not an
engine. Settling a row means vendor documentation or a real server under Testcontainers — which is why
*Settled by* names a document here, not a jar. Row 4.11 is the single exception.

| # | Claim | Where | Settled by | Falsified by |
|---|---|---|---|---|
| 4.1 | A deadlock victim is killed outright with `40P01`, already rolled back when the exception arrives | `neutral pg` | PG error-codes appendix | a code change (won't happen); the *rolled-back-already* half is the part that changes what you write |
| 4.2 | Postgres rejects every further statement on an aborted transaction | `neutral pg` | PG error codes (`25P02`) | ⚠ the code appears in a commit message, never in the docs — the docs state the behaviour bare. Keep it that way unless the code earns its line |
| 4.3 | `max_prepared_transactions` defaults to **0**, so the server rejects `PREPARE TRANSACTION` | `neutral pg` | PG runtime-config | the old `jee-pg`-only asymmetry is gone: both stacks now read it from the neutral variant |
| 4.4 | A long-open transaction pins the **xmin horizon**, so vacuum clears no newer dead tuple in *any* table | `neutral pg` | PG routine-vacuuming | — |
| 4.5 | `SELECT … FOR UPDATE` **blocks** instead of reporting the loss, so it is the wrong shape for a lease claim | `neutral pg` | PG explicit-locking | ⚠ `FOR UPDATE SKIP LOCKED` does not block. Neither doc mentions it, so a reader who knows it reads the rule as simply wrong — the rule is about the *claim* pattern, and the sentence does not say so |
| 4.6 | A second replica's identical conditional `UPDATE` blocks under READ COMMITTED rather than returning 0 | `neutral pg` | PG transaction-isolation (re-evaluation on a concurrently updated row) | the load-bearing claim behind the entire lock-row section; unverified |
| 4.7 | Postgres indexes a PK and a unique constraint automatically, a FK never; index names are unique per **schema** | `neutral pg` | PG DDL constraints / `CREATE INDEX` | — |
| 4.8 | RCSI is **off** by default on SQL Server and **on** by default on Azure SQL Database | `neutral ms` | Microsoft Learn | ⚠ the Azure half is the likeliest row in this file to have gone stale |
| 4.9 | RCSI is **not** SNAPSHOT isolation; a SNAPSHOT writer blocks first, then fails with an update conflict | `neutral ms` | Microsoft Learn | this distinction is the reason the section exists — confusing them ships retry code for an error that is never raised |
| 4.10 | Lock escalation at "a few thousand" row/page locks → one table lock; readers blocked too without RCSI; the log cannot truncate | `neutral ms` | Microsoft Learn | ⚠ the documented threshold is a heuristic (~5,000). The docs' "a few thousand" hedge is correct — **do not sharpen it** |
| 4.11 | The JDBC driver sends string parameters as Unicode by default, so a `VARCHAR` column is compared through an implicit conversion and its index stops being seekable | `jee-ms` `sb-ms` `q-ms` (the neutral ms states it hedged, "check yours") | `mssql-jdbc` → `sendStringParametersAsUnicode` default, `true` in 13.4.0.jre11 (`SQLServerDriverBooleanProperty`) — **the only row in this group with a local artifact** | the driver default changing. Check this one; it is free |
| 4.12 | A PK is **clustered** unless `NONCLUSTERED` or the table already has a clustered index; every other index stores the clustered key as its row pointer | `neutral ms` | Microsoft Learn | the precondition half was added late — the flat version was wrong |
| 4.13 | A unique constraint treats `NULL` as a value, so it permits exactly **one** unset row; the fix is a filtered unique index | `neutral ms` | Microsoft Learn | ⚠ The inverse of ANSI and of Postgres, and the highest-value line in the pair. If this one is wrong, the pair's flagship claim is wrong |
| 4.14 | Constraint names unique per **schema**, index names only per **table** | `neutral ms` | Microsoft Learn | — |
| 4.15 | `…_CI_AS` is the widespread default collation, deciding equality and uniqueness case-sensitivity invisibly | `neutral ms` | — | ⚠ "widespread default" is an observation about deployments, **not** a documented default: it is set at install and per database. The docs are right to tell you to read it off the target; the word "default" is the part that could mislead |
| 4.16 | `datetime` rounds to ~3 ms, so the value read back is not the one written; a sequence cache is dropped on failover, leaving id gaps | `neutral ms` | Microsoft Learn | — |
| 4.17 | `sp_getapplock` ties the lock to a transaction or a session, and a pooled connection is reset at commit | `neutral ms` | Microsoft Learn **plus the pool** | ⚠ Two claims in one sentence: lock scope is SQL Server's, reset-on-return is the connection pool's (HikariCP). A pool change falsifies half of it and no engine doc will tell you |
| 4.18 | MSDTC plus the driver's server-side XA install is required for a two-resource transaction; an open transaction under RCSI pins the `tempdb` version store | `neutral ms` | Microsoft Learn | — |

## 5 · Quarkus 3.40.1 — quarkus only

*Where* is `q-pg` · `q-ms` unless a row says otherwise. Sources: the `-sources.jar` of each artifact in the table above (fetch with `mvn dependency:get`; the BOM's third-party pins are in group 5's row). Group 2's rows whose *Where* names `q-*` hold for quarkus, at 7.4.9.Final.

| # | Claim | Where | Settled by | Falsified by |
|---|---|---|---|---|
| 5.1 | `@Inject EntityManager` works on a constructor parameter (an `@ApplicationScoped` synthetic bean, mockable); a field annotated `@PersistenceContext` is rewritten to the same injection | both | `HibernateOrmCdiProcessor` — `createSyntheticBean`, `convertJpaResourceAnnotationsToQualifier` | ⚠ the rewrite is `FIELD`-only (a comment there defers parameters). The docs claim the constructor `@Inject`, not the annotation on a parameter |
| 5.2 | The injected session is the current transaction's; outside one, `quarkus.hibernate-orm.request-scoped.enabled` (default **true**) gives a read-only request-scoped session — a write throws `TransactionRequiredException`, and with it `false` any use throws `ContextNotActiveException`; a `@QuarkusTest` runs in an active request context, so with the flag `false` its repository calls need a transaction | both | `TransactionScopedSession#acquireSession`; `HibernateOrmRuntimeConfig#requestScopedSessionEnabled` (its javadoc recommends disabling); `quarkus-arc` `ArcTestRequestScopeProvider` | the default flipping — the javadoc calls it a backwards-compatibility default, so the likeliest row in this group to move at a major |
| 5.3 | `quarkus.datasource.jdbc.transactions` defaults to `enabled`; `disabled` drops the datasource out of the transaction manager; `xa` needs an `XADataSource` | both | `DataSourceJdbcBuildTimeConfig#transactions`, `TransactionIntegration` (in `quarkus-agroal`) | an enum or default change |
| 5.4 | A Panache repository's methods are generated at build time; the defaults throw (`implementationInjectionMissing`), so it cannot be built with `new` outside a booted application | both | `PanacheRepositoryBase` (`@GenerateBridge` defaults), `AbstractJpaOperations#implementationInjectionMissing` | the enhancer changing; the unit-tier advice in `testing.md` rests on it |
| 5.5 | `persist` skips an entity the session already contains and has no `merge`/`save`; `persistAndFlush` exists | both | `AbstractManagedJpaOperations#persist`, `PanacheRepositoryBase#persistAndFlush` | — |
| 5.6 | `deleteAll()`, `delete(String, …)`, `update(String, …)` are bulk HQL ignoring cascade; `delete(entity)` and `deleteById` load then `remove` | both | the javadoc "WARNING … bulk delete query and ignores cascading rules"; `AbstractManagedJpaOperations#deleteById` (implementation note) | ⚠ `deleteById` carries an implementation note, not a contract — a set-based `deleteById` would not break the javadoc |
| 5.7 | `find`/`update`/`delete` strings: one starting `from`/`select`/`with` (find), `update …` (update) reaches Hibernate untouched; any other is a `where` clause (find) or a `set` clause (update); a named query (`#name`) takes no `Sort` | both | `PanacheJpaUtil#createFindQuery`, `#createUpdateQuery`; `AbstractJpaOperations#find` | the shorthand rules changing — they are the reason `join fetch` and `update versioned` are written in full |
| 5.8 | `update versioned <Entity> set …` adds the version increment, and is a `SemanticException` on a non-versioned entity | both | `SemanticQueryBuilder` (the `VERSIONED` token), `BaseSqmToSqlAstConverter#addVersionedAssignment` | the HQL grammar dropping the keyword |
| 5.9 | `page`/`range` apply `setFirstResult`/`setMaxResults` over the sort given and add none; `range`'s last index is inclusive; `count`, `pageCount` and `hasNextPage` share one count cached per query; `firstResult()` is `setMaxResults(1)` with no uniqueness check; `singleResultOptional()` throws `jakarta.persistence.NonUniqueResultException`; `stream()` needs a transaction | both | `CommonPanacheQueryImpl`, `Range`, `PanacheRepositoryBase#stream` javadoc | any of these moving; ⚠ the `stream()` half is the javadoc's warning ("the underlying cursor can be closed"), not a mechanism read |
| 5.10 | `project(Class)` builds `select new <Class>(<constructor parameter names>)`; names must equal attribute names or carry `@ProjectedFieldName`; the build needs `-parameters`; a `select new` query cannot be projected | both | `CommonPanacheQueryImpl#project`, `#getParameterName` | the projection mechanism moving to Hibernate's own result-type projection |
| 5.11 | Named queries are checked at startup (`hibernate.query.startup_check` defaults to true) and Quarkus runs the check | both | `QuerySettings#QUERY_STARTUP_CHECKING` `@settingDefault`; `SessionFactoryObserverForNamedQueryValidation` | the default flipping |
| 5.12 | The entity-graph hint is `jakarta.persistence.fetchgraph`, passed through `withHint` | both | `SpecHints#HINT_SPEC_FETCH_GRAPH`; `PanacheQuery#withHint` | the hint name changing; the docs name no other route |
| 5.13 | `quarkus.hibernate-orm.query.fail-on-pagination-over-collection-fetch` defaults to false and makes the in-memory pagination an exception | both | `HibernateOrmConfigPersistenceUnit` (`failOnPaginationOverCollectionFetch`); `QuerySettings` | the default flipping |
| 5.14 | Quarkus sets `hibernate.id.sequence.increment_size_mismatch_strategy` to `NONE`; `validate` rejects a sequence whose increment differs from the mapping's (only when the database increment is > 0) | both | `HibernateProcessorUtil` ("Disable sequence validations: they are reportedly slow"); `AbstractSchemaValidator#validateSequence` | Quarkus re-enabling the check — then the docs' "a mismatch boots cleanly" is wrong, and row 2.3 holds for quarkus again |
| 5.15 | The default physical naming strategy keeps logical names; Quarkus sets one only from `quarkus.hibernate-orm.physical-naming-strategy`; `PhysicalNamingStrategySnakeCaseImpl` is the snake-case class (`CamelCaseToUnderscoresNamingStrategy` is deprecated for removal since 7) | both | `MappingSettings#PHYSICAL_NAMING_STRATEGY` `@settingDefault`; `HibernateProcessorUtil` (set only `ifPresent`); `CamelCaseToUnderscoresNamingStrategy` `@Deprecated(forRemoval)` | Hibernate changing the default; the snake-case class renamed |
| 5.16 | `quarkus.hibernate-orm.jdbc.statement-batch-size` is applied only when set; Hibernate's default is 0; `persist(Iterable)` loops `persist` | both | `HibernateProcessorUtil`; `BatchSettings#STATEMENT_BATCH_SIZE`; `AbstractManagedJpaOperations#persist` | Quarkus defaulting a batch size |
| 5.17 | `quarkus.hibernate-orm.schema-management.strategy` defaults to `none`; accepts `none`, `create`, `drop-and-create`, `drop`, `update`, `validate`; `database.generation` is deprecated since 3.22 | both | `HibernateOrmRuntimeConfigPersistenceUnit` | removal of the deprecated key |
| 5.18 | Dev Services forces `drop-and-create` when it supplies the datasource (no `username` configured in the profile), no strategy is set, and no tool reports the datasource schema-ready; Flyway reports it only for datasources with migrations found at build time, Liquibase for every datasource | both | `HibernateOrmDevServicesProcessor#devServicesAutoGenerateByDefault`; `FlywayProcessor#startActions`, `LiquibaseProcessor#startLiquibase` | any of the three conditions changing; ⚠ the "found at build time" half is read from `migrationsBuildItem.state`, not run |
| 5.19 | `migrate-at-start` defaults to false for Flyway and Liquibase; the schema-ready item is produced either way; Hibernate starts only after it | both | `FlywayDataSourceRuntimeConfig`, `LiquibaseDataSourceRuntimeConfig`; `FlywayRecorder#doStartActions`; `HibernateOrmProcessor#startPersistenceUnits` (`@Consume(JdbcDataSourceSchemaReadyBuildItem)`) | a default flip |
| 5.20 | `quarkus-flyway` depends on `flyway-core` only; engine support is `quarkus-flyway-postgresql` (→ `flyway-database-postgresql`) and `quarkus-flyway-mssql` (→ `flyway-sqlserver`); `flyway-core` 12.0.0 holds no engine `DatabaseType`; Liquibase needs no engine extension | `q-pg` `q-ms` | the poms; `unzip -l` of the three Flyway jars | ⚠ read from jar listings and poms, not run: Flyway folding engines back into core would void it |
| 5.21 | The dialect is fixed at build time at a floor — PostgreSQL 14 (Hibernate's `MINIMUM_VERSION`), SQL Server 13 (Quarkus's `DialectVersions.Defaults.MSSQL`) — unless `quarkus.datasource.db-version` is set; at runtime only a database older than that fails the boot | `q-pg` `q-ms` | `PostgreSQLDialect`, `DialectVersions`, `QuarkusRuntimeInitDialectFactory#checkActualDbVersion` | either floor moving. ⚠ "can disable features and cost performance" is the extension's own error text, not measured |
| 5.22 | A version conflict in the commit-time flush surfaces as `jakarta.transaction.RollbackException` whose cause is `OptimisticLockException`; a flush inside the method raises the latter as itself | both | `SessionImpl#fireFlush` → `ExceptionConverterImpl#wrapStaleStateException`; `JtaTransactionCoordinatorImpl#beforeCompletion`; Narayana `TransactionImple#commit`/`#commitAndDisassociate` (`initCause(getDeferredThrowable())`); `TransactionalInterceptorBase#endTransaction` | ⚠ `commitAndDisassociate` prefers the *earlier* `setRollbackOnly` stack trace as the cause when the transaction was already marked rollback-only before commit — then the cause is not the conflict |
| 5.23 | Quarkus defaults `smallrye.faulttolerance.mp-compatibility` to `false`, which makes `@Retry.retryOn` inspect the cause chain | both | `SmallRyeFaultToleranceProcessor` (`RunTimeConfigurationDefaultBuildItem`); `SpecCompatibility#inspectExceptionCauseChain`; `SetBasedExceptionDecision` | the default flipping, or a project setting it `true` — the one row whose failure is silent (a commit-time conflict is no longer retried) |
| 5.24 | A deadlock victim is a `LockAcquisitionException`: Postgres `40P01` by the dialect; SQL Server error 1205 reaches Hibernate as SQLState `40001` (driver) which the generic delegate maps, the SQL Server dialect having no 1205 case; `ExceptionConverterImpl` does not convert it, so `retryOn` must name it | `q-pg` / `q-ms` | `PostgreSQLDialect#buildSQLExceptionConversionDelegate`; `SQLStateConversionDelegate`; `SQLServerException#generateStateCode` (`xopenStates` default false); `ExceptionConverterImpl#convert` | the dialect gaining its own 1205 mapping to another type; the driver's `xopenStates` default |
| 5.25 | A unique violation is `org.hibernate.exception.ConstraintViolationException#getConstraintName` (Postgres 23505 and SQL Server 2627/2601) | both | `SQLStateConversionDelegate`, the two dialects' `ViolatedConstraintNameExtractor` | ⚠ the name is parsed out of the server's message text (`extractUsingTemplate`) — unverified against a server running another language |
| 5.26 | SQL Server Dev Services is Testcontainers' `MSSQLServerContainer`, which refuses to start without `ACCEPT_EULA` set or a `container-license-acceptance.txt` naming the image; Quarkus accepts neither, and configures no collation or RCSI; `container-env` is applied before start; `db-name` is unsupported for it | `q-ms` | `MSSQLDevServicesProcessor`; `testcontainers-mssqlserver` 2.0.5 `MSSQLServerContainer#configure`; `testcontainers` 2.0.5 `LicenseAcceptance` | Quarkus calling `acceptLicense()`, or Testcontainers changing the check |
| 5.27 | `quarkus-hibernate-panache-next` at 3.40.1 is a relocation pom to `quarkus-data-hibernate`, whose extension descriptor reads `status: experimental`; `quarkus-hibernate-orm-panache` reads `stable` | both | the relocation `.pom`; `META-INF/quarkus-extension.yaml` of both jars | its graduation — the first row to re-check when this stack moves past 3.40 |

---

## Twin parity — the pair's recurring failure mode

**The defect this pair produces most is a rule landing in one twin and silently missing the other.** Five
have been found by reading so far, all now fixed: three in jakarta-ee (the `merge`-on-a-managed-entity half,
the bulk-JPQL staleness clause, multi-resource guidance), one in spring-boot (the JPA-spec half of why a
retry cannot sit inside the transaction, which `sb-pg` had attributed to the engine alone), and one in both
stacks (the id-gap rule, present only in the SQL Server twins). Nothing gates any of it.

**The rule.** A claim settled by groups 1–3 or 5 is framework-level and must appear in **both** twins of its pair,
in the same register — so a group-1 change edits **six** files, a group-2 change edits the files its *Where* names,
a group-3 or -5 change **two**. A claim
settled by group 4 is engine-specific and now lives once, in that engine's neutral variant — edit it there.

⚠ **The trap is a claim with both halves.** *Retry outside the transaction* is the worked example, and
the stack docs carry it: the same prescription, two rationales — Postgres because an aborted transaction rejects
every further statement, SQL Server because JPA marks the transaction rollback-only **while the connection
is still answering**, which is what makes an in-transaction retry look possible. A shared file stating the
Postgres reason would be actively wrong on SQL Server. Unify the rule, never the rationale — and check that
a sentence you copy across carries none belonging to the engine you copied it *from*.

⚠ **Registers differ legitimately between stacks, and that is not drift.** jakarta-ee hedges the provider
behind RUNTIME GAP markers, because its runtime is genuinely undecided; spring-boot and quarkus state Hibernate
flat (group 2's banner says why, and what that costs). A rule promoted from jakarta-ee to spring-boot must lose
its hedge; one promoted the other way must gain it. `2.5` and `2.6` are the two live instances.
