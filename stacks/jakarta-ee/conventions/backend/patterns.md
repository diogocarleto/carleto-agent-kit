## Beans, Injection and Interceptors

- **Scope by lifetime**: `@ApplicationScoped` for anything stateless and long-lived (services, repositories, mappers), `@RequestScoped` only for genuine per-request state, `@Dependent` for a helper that lives and dies with its injection point.
- **Constructor injection, not field injection.** Collaborators arrive through an `@Inject` constructor, which makes the bean testable with plain `new` and no container (`testing.md`). A normal-scoped bean also needs a non-private no-arg constructor for its proxy — declare it `protected` beside the real one.
- **Inject interfaces where a second implementation is real**, concrete types otherwise. A one-implementation interface plus a qualifier is ceremony; add it when the second arrives.

### ⚠ Interceptors fire only through a contextual reference

`@Transactional`, `@Asynchronous` and every custom interceptor binding are applied by the container when the method is invoked **through an injected reference**. Two ways to lose them silently:

- The method is `private`, `static` or `final` — never intercepted, by specification.
- The call is a self-call on `this` — interception is not guaranteed, and an un-intercepted method just runs, with the annotation doing nothing and nothing logged.

So a method carrying an interceptor binding is **non-private and called from another bean** — inject the collaborator (or split the annotated method into its own bean) and call it through the reference. The failure mode is an annotation that reads as enforced and is not.

⚠ **`@RolesAllowed` is not on that list, on Jakarta EE 11 either.** It declares no interceptor binding of its own and Jakarta Security 4.0 supplies none, so **nothing in either API artifact gives CDI a path to activate it on a plain bean** — no injection path rescues it. It is enforced on an Enterprise Bean, plus wherever the runtime wires it into JAX-RS; authorization is checked at the resource boundary (`security.md`).

## Serialization Boundaries

Each type binds to exactly one serializer. Mixing the annotation sets is silent: the foreign annotations are simply ignored, and a reader trusts them.

| Class kind | Serialized by | Foreign annotations |
|------------|---------------|---------------------|
| Entity | the persistence binding (`persistence-<db>.md`) | **no** JSON-binding annotations |
| Embedded VO | the persistence binding, and MapStruct → Response | **no** JSON-binding annotations |
| Request / Response DTO | the JAX-RS JSON binding | **no** persistence-mapping annotations |
| Payload for an external API we call | the JSON binding | name-mapping annotations are fine — a third-party contract is not ours to rename |

Hard rule: an entity never crosses the HTTP boundary and a DTO never reaches the database. The mapper is the only bridge.

⚠ RUNTIME GAP — whether JSON-B or Jackson binds DTOs on this runtime. The one-serializer-per-type rule above holds either way; the annotation set does not. Fill when the runtime is chosen; do not guess.

## Mappers

MapStruct with `componentModel = "jakarta-cdi"`, generated as CDI beans and **injected** — never `Mappers.getMapper(...)` in production code, which builds an unmanaged instance whose own `uses` mappers are not injected. ⚠ Not `"cdi"`: that model gives **`javax` priority**, and it resolves the scope and the injection annotation **independently**, falling back to `jakarta` per annotation. So one legacy dependency dragging `javax.inject` in splits the generated impl in half — a `jakarta` `@ApplicationScoped` type, whose mandated constructor (below) is annotated `@javax.inject.Inject`, an injection point the container has no reason to honour — beside the public no-arg constructor MapStruct emits with it. `jakarta-cdi` hard-codes `jakarta.*` for both.

⚠ **Set `injectionStrategy = InjectionStrategy.CONSTRUCTOR`** on every `@Mapper`, or once on a shared `@MapperConfig`. That component model generates *field* injection by default, and a field-injected impl cannot be built with `new`: its `uses` mappers stay null, so the plain-JUnit mapper tests `testing.md` requires either throw or quietly map every nested object to null.

- **One mapper per type**, including nested VOs and records. Compose with `uses`; never add a private mapping method for a nested type inside its parent's mapper.
- **A mapper does not query.** It transforms what it is given. If a mapping needs data the source object does not carry, the service resolves it and passes it in — a mapper that injects a repository turns every `toResponse` into an unbounded read.
- **Full and partial updates are two methods.** The full one overwrites absent fields with null; the partial one leaves them untouched. The resource picks (`code-style.md` → HTTP verbs).
- **No business rules in a mapper** — no defaulting, no validation, no conditional derivation beyond format conversion.

## Entity defaults and partial updates

A defaulted field (`status = ACTIVE`) gets its default in **exactly one place: the factory that creates a new entity**. Two places it must never live:

- **The constructor the persistence binding calls on read** — it would rewrite a stored null into the default on every load, erasing the difference between "never set" and "set to this value".
- **Any partial-update path** — a request that omits the field would silently clobber the stored value with the default.

Cover all three branches in tests: create applies the default; a partial update omitting the field preserves what is stored; an explicit null means *clear*, if the domain allows clearing at all.

## Embedded value objects

An embedded value object is **not** an entity: no identity and no lifecycle of its own, and no repository. Make it an immutable record in its own file, constructed through one factory, and mapped by its own mapper. A type that has its own id and lifecycle is a full entity with its own repository — the moment you want to query it independently, it already was.

## Validation and exceptions

- **Bean Validation at the resource boundary** (`api.md` → validation groups). Services validate business rules, not field shapes.
- **Services throw a domain exception; an `ExceptionMapper` turns it into the one error body.** No `try/catch` in a resource method, and no HTTP concern in a service.
- **Group violations, then flush.** Accumulate every problem found in one operation and throw once, so the caller gets the whole list instead of the first failure and a round-trip per field.
- **One code table, one status mapping.** Each domain owns an enum of validation messages with a stable machine-readable code; a single place maps code → HTTP status. Never derive the status at the throw site.
- **Message keys are structural and stable**: `<module>.validation.<domain>.<concept>.message`, lowerCamelCase segments, dots split rather than fuse. Operation failures take the verb (`create`, `cancel`, `refund` — never a generic `save`); field/state conditions take the condition (`notFound`, `alreadyExists`, `expired`). Message text names the field and interpolates the offending value.
- ⚠ **Map `ConstraintViolationException` yourself.** Without a mapper for it the container emits its own body — shape, wording and status vary by runtime, and your clients get a second error format nobody documented.
- **Cross-cutting failures reuse the shared code** — access denied, malformed payload and the like are not per-domain codes.

## Failure-path cleanup must not mask the original error

Read together with `.agent-kit/backend/design-principles.md`: the rule is stated there and applies here unchanged.

## Idempotency & compensation anchor for external side effects

Read together with `.agent-kit/backend/design-principles.md`, which states the rule; this stack adds:

- When the anchor is recorded locally first, undo the local business writes if the external call fails; the anchor itself stays, marked failed.

## Batch, scheduled and bulk workloads

Applies whenever a feature processes many items in one pass rather than serving one request — a scheduled sweep, a bulk import, a periodic reconciliation. (A **one-shot** pass over existing data is a migration, not this.)

⚠ **A `ManagedScheduledExecutorService` schedule fires on every replica.** Its pool is per-JVM and takes no cross-instance lock, so N replicas run the job N times — duplicating *writes*, not just effort. Anything reading recent history (a failure streak, a last-run-wins decision) is then wrong in a way that looks like data rather than a bug, and outbound calls to third parties multiply before you notice.

⚠ **`jakarta.ejb.Schedule` is neither a substitute nor a flat per-replica answer.** It requires an Enterprise Bean, and it defaults to `persistent = true`: on a timer store the cluster shares, a persistent timer fires **once per cluster**; on a per-node store, once per node. The duplication above is therefore a property of the store, not of the annotation — verify which one this deployment has rather than assuming either.

⚠ RUNTIME GAP — the timer store backing `@Schedule` (a shared database vs a per-node file store). It decides whether a persistent timer fires once or N times. Fill when the runtime is chosen; do not guess.

Two acceptable shapes:

- **Trigger from outside the application** — a cron calling an endpoint. Single execution whatever the replica count, and re-triggerable without a deploy.
- **Take a shared lock** the job holds for its run, so only one replica proceeds (`persistence-<db>.md` → shared locks).

Then:

- **Grain by failure boundary, not by I/O.** Process one item per unit whose failure should be *independent* — not per unit the fetch happens to return. The two usually differ: reads are naturally per-source, isolation is naturally per-subject. Prefer the failure boundary and accept redundant fetching to get it; re-reading a page is cheap next to one subject's failure stranding every other subject in the same pass. This is what a per-element `Outcome` is for (`code-style.md`).
- **Create the record the work will update *before* starting it, and carry its id.** Never let the worker derive which record it owns — a derived key drifts across a day boundary or a retry, and a lost run leaves *no* record at all, reading as "nothing happened" rather than "this never ran".
- **Page the source; never materialize it.** Accumulate the projection, not the entities (`persistence-<db>.md`).
- **Make a re-run safe.** Any of these jobs will run twice eventually; design so the second pass is a no-op rather than a duplicate.
