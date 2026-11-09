## Beans, Scopes and Injection

- **`@ApplicationScoped` by default** for services, repositories and mappers; `@RequestScoped` only for genuine per-request state; `@Dependent` for a helper that lives and dies with its injection point.
- ⚠ **`@Singleton` has no client proxy, and `@InjectMock` replaces a bean through its proxy** (`testing.md`). A `@Singleton` is not mockable that way; reach for it only where the proxy costs something you measured.
- ⚠ **A class with no scope annotation is not a bean** (a class declaring a `@Produces` method is `@Dependent`), unless an extension adds one (`@Scheduled` and `@Startup` do). ArC discovers beans at build time, so scope every hand-written one.
- **Constructor injection, never field injection.** `@Inject` is optional on a single constructor. Field injection makes the bean unbuildable with `new`, which is how `testing.md` expects services to be tested.
- **A `@Produces` method only for what the container cannot discover** — a third-party client, an executor. A producer that returns your own `@ApplicationScoped` service is a second registration of the same thing.
- **Beans are shared across threads** — fields stateless or effectively immutable (`concurrency.md`).

### What the client proxy changes

A normal-scoped bean (`@ApplicationScoped`, `@RequestScoped`) is injected as a proxy that delegates to the real instance:

- **The instance is created on the first method call**, not at startup. Work that must happen at boot goes on a `@Startup` bean.
- ⚠ **Only method calls reach the real instance.** Reading or writing a field of an injected bean touches the proxy's own copy, which is never populated. Expose state through a method.
- ⚠ **`final` is not honoured on a bean.** Quarkus strips `final` from the class and its methods and adds a no-arg constructor wherever a proxy needs one (`quarkus.arc.transform-unproxyable-classes`, on by default). Nothing fails the build, and a constructor-injected bean needs no hand-written no-arg constructor.

### Interceptors

`@Transactional`, `@Retry` and `@RolesAllowed` run through the container's generated subclass: they fire on a **non-private method of a bean**, self-calls included. What follows from that, and the order the interceptors run in, is in `architecture.md` and `concurrency.md`.

## Transactions

Use `jakarta.transaction.Transactional`. **The transaction boundary is the service method** — not the resource (it holds no business rule, `architecture.md`) and not the repository (one transaction per statement makes a multi-write operation non-atomic while looking transactional at every call site).

⚠ **A checked exception commits the partial write.** A transaction rolls back on `RuntimeException` and `Error` only, unless the annotation says otherwise (`rollbackOn`, `dontRollbackOn`). A checked domain exception thrown halfway leaves the first half persisted while the caller is told it failed. **Domain exceptions extend `RuntimeException`** — the default here, and what the error mapping assumes (`api.md`); `rollbackOn` is for a checked exception you cannot change.

## Configuration

Bind deployment values through a `@ConfigMapping` interface, one per concern, named `*Config` (`code-style.md`). Absent-but-fine is an `Optional<T>` or a `@WithDefault`, never a `null` (`code-style.md`). Never scatter `@ConfigProperty` fields, and never read the environment at a call site.

⚠ **A mapping is registered with the config only where a bean injects it** (or marks it `@Unremovable`). One read by a programmatic lookup alone is not registered, so its missing values do not fail startup.

## REST Client

An outbound call goes through a `quarkus-rest-client-jackson` interface annotated `@RegisterRestClient(configKey = "...")`, injected with `@RestClient` into the service that owns the integration. One interface per remote system; its payload types are plain records, and name-mapping annotations on them are fine (*Serialization boundaries* below).

- **Configure under the key**: `quarkus.rest-client.<configKey>.url`, and **set both timeouts on every client** — `connect-timeout` and `read-timeout` are bare milliseconds, and the defaults (15 s connect, 30 s read) let a hung dependency hold every caller for that long.
- ⚠ **A non-2xx answer is an exception that reaches your mappers.** Quarkus does not forward it as your own response, but it does offer it to the `ExceptionMapper`s, and a catch-all that copies a `WebApplicationException`'s status then answers with the upstream's. Translate it at the integration boundary into a domain exception, so the mapper decides the status (`api.md`).
- **Retry only what is idempotent**, and from outside the transaction (`concurrency.md`; `.agent-kit/backend/design-principles.md` → idempotency).

## Mappers

MapStruct with `componentModel = "jakarta-cdi"`: the generated impl is an `@ApplicationScoped` bean, **injected** — never `Mappers.getMapper(...)` in production code, which builds an unmanaged instance whose own `uses` mappers are not injected. ⚠ Not `"cdi"`: it prefers `javax.*` annotations when they are on the classpath, so one legacy dependency splits the generated impl between two annotation sets. MapStruct is not in the Quarkus BOM — the project pins it.

⚠ **Set `injectionStrategy = InjectionStrategy.CONSTRUCTOR`** on every `@Mapper`, or once on a shared `@MapperConfig`. MapStruct defaults to *field* injection, and a field-injected impl cannot be built with `new`: its `uses` mappers stay null, so the plain-JUnit mapper tests `testing.md` requires either throw or quietly map every nested object to null.

- **One mapper per type**, including nested VOs and records. Compose with `uses`; never add a private mapping method for a nested type inside its parent's mapper.
- **A mapper does not query.** It transforms what it is given; data the source does not carry is resolved by the service and passed in. A mapper that injects a repository turns every `toResponse` into an unbounded read.
- **Full and partial updates are two methods.** The full one overwrites absent fields with null; the partial one leaves them untouched. The resource picks (`code-style.md` → HTTP verbs).
- **No business rules in a mapper** — no defaulting, no validation, no conditional derivation beyond format conversion.

## Serialization Boundaries

Each type binds to exactly one serializer. Mixing the annotation sets is silent: the foreign annotations are simply ignored, and a reader trusts them.

| Class kind | Serialized by | Foreign annotations |
|------------|---------------|---------------------|
| Entity | the persistence binding (`persistence-<db>.md`) | **no** Jackson |
| Embedded VO | the persistence binding, and MapStruct → Response | **no** Jackson |
| Request / Response DTO | Jackson (`quarkus-rest-jackson`) | **no** persistence-mapping annotations |
| Payload for an external API we call | Jackson (`quarkus-rest-client-jackson`) | name-mapping annotations are fine — a third-party contract is not ours to rename |

- **A DTO carries Jackson annotations only where the wire name differs from ours** (`user_id` ↔ `userId`) or a third party forces an odd shape; `@Schema` carries the OpenAPI metadata. Never `@JsonInclude` class-wide. No Jackson on enums at all (`code-style.md`).
- **An entity never crosses the HTTP boundary and a DTO never reaches the database.** The mapper is the only bridge; returning an entity from a resource serializes today and exposes whatever column someone adds tomorrow.
- ⚠ **Quarkus's Jackson ignores unknown properties by default** (`quarkus.jackson.fail-on-unknown-properties` is false), so a misspelled field in a request is dropped without a word: a PUT silently nulls it, a PATCH silently skips it. A test that sends the body and asserts the effect is the only guard.

## Entity Defaults and Partial Updates

A defaulted field (`status = DRAFT`) gets its default in **exactly one place: the factory that creates a new entity**. Never in the constructor the persistence binding calls on read — it would rewrite a stored null into the default on every load — and never on a partial-update path, where a request that omits the field would clobber the stored value with the default.

Cover all three branches in tests: create applies the default; a partial update omitting the field preserves what is stored; an explicit null means *clear*, if the domain allows clearing at all.

## Embedded Value Objects

An embedded value object is **not** an entity: no identity, no lifecycle of its own, no repository. Make it an **immutable record** in its own file, constructed through one factory and mapped by its own mapper. A type with its own id and lifecycle is a full entity with its own repository — the moment you want to query it independently, it already was.

## Validation and Exceptions

- **Bean Validation at the resource boundary** (`api.md` → validation groups). Services validate business rules, not field shapes.
- **Services throw a domain exception; an `ExceptionMapper` turns it into the one error body** (`api.md`). No `try/catch` in a resource, and no HTTP concern in a service.
- **Group violations, then flush.** Accumulate every problem found in one operation and throw once, so the caller gets the whole list instead of the first failure and a round-trip per field.
- **One code table, one status mapping.** Each domain owns an enum of codes, stable and machine-readable; one place maps code → HTTP status. Never derive the status at the throw site.
- **Cross-cutting failures reuse the shared code** — access denied, malformed payload and the like are not per-domain codes.

## Failure-Path Cleanup Must Not Mask the Original Error

Read together with `.agent-kit/backend/design-principles.md`: the rule is stated there and applies here unchanged.

## Idempotency & Compensation Anchor for External Side Effects

Read together with `.agent-kit/backend/design-principles.md`, which states the rule; this stack adds:

- When the anchor is recorded locally first, undo the local business writes if the external call fails; the anchor itself stays, marked failed.

⚠ **Never make the external call inside the transaction.** The remote system has no idea the transaction rolled back, and the write it performed is not coming back. Commit the anchor, then call.

## Batch, Scheduled and Bulk Workloads

Applies whenever a feature processes many items in one pass rather than serving one request — a scheduled sweep, a bulk import, a periodic reconciliation. (A **one-shot** pass over existing data is a migration, not this.)

⚠ **A `@Scheduled` method fires on every replica.** Each instance runs its own scheduler, so N replicas run the job N times — duplicating *writes*, not just effort. Anything reading recent history (a failure streak, a last-run-wins decision) is then wrong in a way that looks like data rather than a bug, and outbound calls multiply before you notice. On one instance in development it is invisible.

⚠ **`concurrentExecution = SKIP` guards one instance only.** It stops a run overlapping its own previous run in that JVM, and says nothing across replicas. Cluster-wide, one run needs one of:

- **A trigger from outside the application** — a cron calling an endpoint. Single execution whatever the replica count, and re-triggerable without a deploy.
- **A lock the project owns**, held for the run so only one replica proceeds (`persistence-<db>.md` → shared locks).
- **A clustered scheduler** — Quarkus's Quartz extension is one; this stack does not prescribe it.

Then:

- **Keep the method `void`.** A `Uni`/`CompletionStage` return or `@NonBlocking` moves the job onto the event loop, where the blocking repositories this stack uses must not run (`concurrency.md`). A scheduled method has no caller identity unless the project supplies one (`security.md`).
- **Grain by failure boundary, not by I/O.** Process one item per unit whose failure should be *independent*, not per unit the fetch happens to return. Accept redundant fetching to get it: re-reading a page is cheap next to one subject's failure stranding every other subject in the pass. This is what a per-element `Outcome` is for (`code-style.md`).
- **Create the record the work will update *before* starting it, and carry its id.** Never let the worker derive which record it owns — a derived key drifts across a day boundary or a retry, and a lost run leaves *no* record at all, reading as "nothing happened" rather than "this never ran".
- **Page the source; never materialize it.** Accumulate the projection, not the entities (`persistence-<db>.md`).
- **One transaction per item, not per run**, opened by the `@Transactional` service method the job calls for each item. A run-long transaction holds a connection for the whole sweep and loses every item's work when the last one fails.
- **Make a re-run safe.** Any of these jobs will run twice eventually; design so the second pass is a no-op rather than a duplicate.
