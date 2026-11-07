## Beans, Stereotypes and Injection

- **Stereotype by role**: `@RestController` at the HTTP edge (`api.md`), `@Service` for business rules, `@Component` for everything else. `@Service` and `@Component` differ in intent, not behaviour — pick the one that names the layer.
- ⚠ **`@Repository` is not just a name — it opts a class into persistence-exception translation, and a Spring Data interface does not need it.** Enabling JPA repositories already registers the translator, so the annotation on a repository interface adds nothing and implies there is an implementation to find. Keep it for a hand-written data-access class.
- **Constructor injection, never field injection.** A single constructor is autowired with no `@Autowired` — omit it. Field injection makes the bean unbuildable with `new`, which is how `testing.md` expects services to be tested.
- **Declare a `@Configuration` class only for beans the framework cannot discover** — a third-party client, a converter, an executor. Application beans are scanned; a `@Bean` method that returns your own `@Service` is a second registration of the same thing.
- **Inject an interface where a second implementation is real**, the concrete type otherwise. A one-implementation interface plus a qualifier is ceremony; add it when the second arrives.
- **Beans are singletons** — fields must be stateless or effectively immutable (`concurrency.md`).

### ⚠ Proxy-based annotations fire only through the proxy

`@Transactional`, `@Async`, `@Cacheable` and every custom advice are applied by a proxy wrapped around the
bean — proxy mode intercepts calls *through the proxy only*, and local calls within the same class are not
intercepted. Four ways to lose the annotation, three of them quiet:

- **A self-call on `this`** — the proxy is not involved, so the method simply runs. Nothing is logged.
- **A non-public `@Transactional` method** — the default attribute source skips non-public methods outright, so there is no transaction attribute to apply even when the call does arrive through the proxy.
- **A `final` method** — Boot proxies with CGLIB by default, which cannot override it. Spring warns once at startup, then the call runs against the *proxy* instance, whose fields were never populated: the symptom is an NPE in code that obviously has its collaborators.
- **A `final` class** — not proxyable at all; bean creation fails, which is at least the loud one.

So a method carrying one of these annotations is **non-final, non-private, and called from another bean**.
Inject the collaborator, or split the annotated method into its own bean. ⚠ The tempting shortcut —
injecting the bean into itself to call through its own proxy — works and is still wrong: it hides the
boundary the annotation is declaring. Move the method.

## Transactions

⚠ **Two `@Transactional` annotations are on the classpath, and Spring honours both:**
`org.springframework.transaction.annotation.Transactional` and `jakarta.transaction.Transactional`
(transitive with JPA). **Always import Spring's.** The JTA one is not ignored — which is why the mistake
survives review — but Spring maps only its propagation and its `rollbackOn`/`dontRollbackOn` rules:
`timeout`, `isolation` and the transaction-manager qualifier have no equivalent there, and the attribute
you reach for is spelled `rollbackFor`, not `rollbackOn`.

⚠ **A checked exception commits the partial write.** Without custom rules a transaction rolls back on
`RuntimeException` and `Error` only, so a checked domain exception thrown halfway leaves the first half
persisted while the caller is told it failed. Pick one guard, project-wide:

- **Domain exceptions extend `RuntimeException`** — the default here, and what the exception handling below assumes.
- **Flip the global default** with `@EnableTransactionManagement(rollbackOn = RollbackOn.ALL_EXCEPTIONS)`.
  ⚠ Declaring that annotation anywhere backs Boot's transaction auto-configuration off, making it the one
  place transaction management is configured. Never combine it with per-method `rollbackFor` — a reader
  cannot then tell which is load-bearing.

**The transaction boundary is the service method.** Not the controller (the request thread would hold a
connection across serialization) and not the repository (one transaction per statement makes a
multi-write operation non-atomic while looking transactional at every call site).

## Method validation on beans

`jakarta.validation.Valid` has an **empty body**, so it cannot name validation groups.
`org.springframework.validation.annotation.Validated` takes `Class<?>[]` and is what carries them — and
what enables validation of a bean's own method parameters and return values.

⚠ **`@Validated` only acts as a pointcut at the class level.** On a method it overrides the groups for
that method and nothing more; without the class-level annotation, method validation was never switched on
for the bean and the method-level one is inert. So annotate the **class** — **except a controller class**,
where a class-level `@Validated` switches off MVC's own parameter validation and turns a 400 into a 500
(`api.md`, which also owns Request-DTO validation at the HTTP boundary) — and use the method-level form
only to vary groups.

## Mappers

MapStruct with `componentModel = "spring"`, generated as beans and **injected** — never
`Mappers.getMapper(...)` in production code, which builds an unmanaged instance whose own `uses` mappers
are not injected.

⚠ **Set `injectionStrategy = InjectionStrategy.CONSTRUCTOR`** on every `@Mapper`, or once on a shared
`@MapperConfig`. MapStruct defaults to *field* injection, and a field-injected impl cannot be built with
`new`: its `uses` mappers stay null, so the plain-JUnit mapper tests `testing.md` requires either throw or
quietly map every nested object to null.

- **One mapper per type**, including nested VOs and records. Compose with `uses`; never add a private mapping method for a nested type inside its parent's mapper.
- **A mapper does not query.** It transforms what it is given. If a mapping needs data the source object does not carry, the service resolves it and passes it in — a mapper that injects a repository turns every `toResponse` into an unbounded read.
- **Full and partial updates are two methods.** The full one overwrites absent fields with null; the partial one leaves them untouched. The controller picks (`code-style.md` → HTTP verbs).
- **No business rules in a mapper** — no defaulting, no validation, no conditional derivation beyond format conversion.

## Serialization boundaries

Each type binds to exactly one serializer. Mixing the annotation sets is silent: the foreign annotations are simply ignored, and a reader trusts them.

| Class kind | Serialized by | Foreign annotations |
|------------|---------------|---------------------|
| Entity | JPA (`persistence-<db>.md`) | **no** JSON-binding annotations |
| Embedded VO | JPA, and MapStruct → Response | **no** JSON-binding annotations |
| Request / Response DTO | Jackson | **no** JPA mapping annotations |
| Payload for an external API we call | Jackson | name-mapping annotations are fine — a third-party contract is not ours to rename |

Hard rule: an entity never crosses the HTTP boundary and a DTO never reaches the database. The mapper is
the only bridge. ⚠ Returning an entity from a controller is the violation that looks harmless — it
serializes today, and then exposes whatever column someone adds tomorrow.

## Entity defaults and partial updates

A defaulted field (`status = ACTIVE`) gets its default in **exactly one place: the factory that creates a new entity**. Two places it must never live:

- **The no-arg constructor JPA calls on read** — it would rewrite a stored null into the default on every load, erasing the difference between "never set" and "set to this value".
- **Any partial-update path** — a request that omits the field would silently clobber the stored value with the default.

Cover all three branches in tests: create applies the default; a partial update omitting the field preserves what is stored; an explicit null means *clear*, if the domain allows clearing at all.

## Embedded value objects

An embedded value object is **not** an entity: no identity, no lifecycle of its own, no repository. Make
it an **immutable record** in its own file, constructed through one factory, and mapped by its own mapper.
A type that has its own id and lifecycle is a full entity with its own repository — the moment you want
to query it independently, it already was.

## Validation and exceptions

- **Bean Validation at the HTTP boundary** (`api.md` → validation groups). Services validate business rules, not field shapes.
- **Services throw a domain exception; one `@RestControllerAdvice` turns it into the one error body.** No `try/catch` in a controller method, and no HTTP concern in a service.
- **Group violations, then flush.** Accumulate every problem found in one operation and throw once, so the caller gets the whole list instead of the first failure and a round-trip per field.
- **One code table, one status mapping.** Each domain owns an enum of validation messages with a stable machine-readable code; a single place maps code → HTTP status. Never derive the status at the throw site.
- **Message keys are structural and stable**: `<module>.validation.<domain>.<concept>.message`, lowerCamelCase segments, dots split rather than fuse. Operation failures take the verb (`create`, `cancel`, `refund` — never a generic `save`); field/state conditions take the condition (`notFound`, `alreadyExists`, `expired`). Message text names the field and interpolates the offending value.
- ⚠ **Handle `MethodArgumentNotValidException` and `ConstraintViolationException` yourself.** Boot has a default error body and it is not yours: a client parsing your documented error shape gets a different one for every validation failure, which is the failure mode nobody notices until integration.
- **Cross-cutting failures reuse the shared code** — access denied, malformed payload and the like are not per-domain codes.

## Failure-path cleanup must not mask the original error

Read together with `.agent-kit/backend/design-principles.md`: the rule is stated there and applies here unchanged.

## Idempotency & compensation anchor for external side effects

Read together with `.agent-kit/backend/design-principles.md`, which states the rule; this stack adds:

- When the anchor is recorded locally first, undo the local business writes if the external call fails; the anchor itself stays, marked failed.

⚠ **Never make the external call inside the transaction.** The remote system has no idea the transaction
rolled back, and the write it performed is not coming back. Commit the anchor, then call.

## Batch, scheduled and bulk workloads

Applies whenever a feature processes many items in one pass rather than serving one request — a scheduled sweep, a bulk import, a periodic reconciliation. (A **one-shot** pass over existing data is a migration, not this.)

⚠ **`@Scheduled` fires on every replica.** The scheduler is per-application-context and takes no
cross-instance lock, so N replicas run the job N times — duplicating *writes*, not just effort. Anything
reading recent history (a failure streak, a last-run-wins decision) is then wrong in a way that looks like
data rather than a bug, and outbound calls to third parties multiply before you notice. Nothing in Boot
warns about this; on one instance in development it is invisible.

Two acceptable shapes:

- **Trigger from outside the application** — a cron calling an endpoint that starts the work. Single execution whatever the replica count, and re-triggerable without a deploy.
- **Take a shared lock** the job holds for its run, so only one replica proceeds (`persistence-<db>.md` → shared locks).

Then:

- **Grain by failure boundary, not by I/O.** Process one item per unit whose failure should be *independent*, not per unit the fetch happens to return — reads are naturally per-source, isolation per-subject. Accept redundant fetching to get it: re-reading a page is cheap next to one subject's failure stranding every other subject in the pass. This is what a per-element `Outcome` is for (`code-style.md`).
- **Create the record the work will update *before* starting it, and carry its id.** Never let the worker derive which record it owns — a derived key drifts across a day boundary or a retry, and a lost run leaves *no* record at all, reading as "nothing happened" rather than "this never ran".
- **Page the source; never materialize it.** Accumulate the projection, not the entities (`persistence-<db>.md`).
- **One transaction per item, not per run.** A run-long transaction holds a connection for the whole sweep and loses every item's work when the last one fails.
- **Make a re-run safe.** Any of these jobs will run twice eventually; design so the second pass is a no-op rather than a duplicate.
