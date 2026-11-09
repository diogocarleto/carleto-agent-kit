## Testing

### Tiers — the class-name suffix decides what runs

| Tier | Suffix | Runs under | Reaches | Profile |
|------|--------|------------|---------|---------|
| Unit | `*Tests` | surefire | nothing outside the JVM: no application, no container | none (default) |
| Integration | `*IntegrationTests`, `*ResourceTests` | failsafe | a booted application over a real database; third parties **mocked** | `-Pintegration-tests` |
| Expensive | `*ExpensiveIntegrationTests` | failsafe | real third-party APIs | `-Pexpensive-tests` |

Dependencies, all `test` scope: `quarkus-junit`, `quarkus-junit-mockito`, `rest-assured` (the BOM pins all three). ⚠ `quarkus-junit5` and `quarkus-junit5-mockito` are relocation poms to the first two, so write the new names.

⚠ **The suffix is a build decision, not a label**, and the pom carries it (`build-commands.md`):

- **Surefire's default includes match `*Tests`**, which every integration suffix also ends in. The pom must exclude them, or the default pass boots the application and needs Docker.
- **Failsafe's defaults (`IT*`, `*IT`, `*ITCase`) match none of the suffixes.** The pom must list them, and bind both goals, `integration-test` and `verify`.
- ⚠ **The integration profile's `*IntegrationTests` include also matches `*ExpensiveIntegrationTests`.** Exclude it there, or every integration run calls live providers.
- ⚠ **A tier whose includes match nothing is a green build.** Both plugins default `failIfNoTests` to false. After touching the pom, read the `Tests run:` line of each tier; a misspelt include reads as success.

⚠ **A `@QuarkusTest` is an integration test wherever the application owns a datasource.** Dev Services starts the database at boot whatever the test mocks (*Dev Services* below), so it takes `*IntegrationTests` or `*ResourceTests`, never `*Tests`. A `*IntegrationTests` is a `@QuarkusTest`, never a `@QuarkusIntegrationTest`: that one runs the packaged artifact and injects nothing.

### Design for the cheap tier

A service whose collaborators arrive through its constructor (`patterns.md`) is tested with plain JUnit, Mockito mocks (built and stubbed through the helpers in *Stubbing*) and `new`: no application, milliseconds. **If a test needs `@QuarkusTest` merely to build the object under test, the bean is wired wrong.** A `*Config` collaborator is a plain interface to mock. Reserve the booted tiers for real persistence behaviour and the HTTP contract.

- **Mapper `*Tests` are plain JUnit too**: `new` the generated `*Impl`, passing its `uses` mappers (constructor injection is why `patterns.md` mandates it). No `@QuarkusTest`.
- ⚠ **Every distinct `@TestProfile`, and every distinct set of test resources, is another application.** Neither makes one test slower; the suite pays a restart per combination.

### Test method naming

`[verb][Subject][Condition]`. Simple names matching the operation are fine (`toResponse()`, `findById()`, `update()`); anything else takes a descriptive prefix:

| Prefix | Usage | Example |
|--------|-------|---------|
| `verify*` | Assertion tests | `verifyOrderTotalEquals120` |
| `check*` | Validation tests | `checkInvalidAccessToken` |
| `execute*` | Action/behaviour tests | `executeAnonymousRequest` |
| `find*` | Search/lookup tests | `findOpenOrdersByCustomer` |
| `exceed*` | Boundary/limit tests | `exceedRateLimitWithOneClient` |
| `save*` | Persistence tests | `saveDuplicateReference` |
| `update*` | Modification tests | `updateNonExisting` |
| `apply*` | Feature application | `applyPartialUpdateKeepingStoredStatus` |

Multi-behaviour operations take `[operation][GerundBehavior][Condition]` (`processBatchSkippingAlreadyImportedItems`). Avoid `Should`/`ShouldNot`.

- **`@DisplayName`** only when the method name cannot carry the purpose.
- **`@Nested`** only for a genuine difference in setup or shared state, never to group by topic.
- **`@ParameterizedTest`** for variant coverage, never a copy-pasted method per enum value. ⚠ Never pass an `AutoCloseable` (a container) as an argument: JUnit closes it after the first use. Pass its address.

### Stubbing — per-collaborator helpers

**Stub every collaborator through a per-collaborator helper, never raw Mockito in the test body.** No `Mockito.when(...)`, `Mockito.verify(...)`, `ArgumentCaptor`, `any()` or `eq()` in a test: each mocked repository, domain service or external client gets a helper class (`OrderRepositoryMocks`) whose methods are semantic, so the test reads as behaviour. Raw Mockito lives inside the helpers only. Vocabulary:

- `mockFoo(args, returnValue)`: stub for **specific** args. `mockFooAny…(returnValue)`: loosened args, with `Any` placed immediately before each loosened parameter's name. Exact is the default; the loose form is the last resort, for what the test cannot know (a generated id, a clock instant).
- `mockFooEmptyReturn(...)` / `mockFooNullReturn(...)`: the miss path, `Optional` or collection versus bare null. Don't invent `*NotFound`, `*Missing`, `*Blank`, nor `*Then` / `*ReturnThen` for sequences: the sequence is the signature, not the name.
- `mockFooThrows(args, exception)`: the failure path.
- `mockFoo…(first, rest…)`: **sequenced stub**, one answer per successive call, named like the single-answer stub. Make the first answer a full value (`Optional`, result wrapper) so a sequence can open with a miss.
- `verifyFooAndReturn(args)`: owns the captor, runs the verify and **returns** the captured value, so the test asserts on a plain return (a record when one call captures several arguments).
- `verifyFooCalledOnce()` / `verifyNeverFoo()`: counts where the arguments do not matter.

**Unit tier:** the helper builds its own `Mockito.mock(...)` (or wraps one passed in) and the test hands it to the constructor. **Booted tiers:** the test declares the `@InjectMock` field and passes it to the same helper's static methods, which stub the injected mock; the helper never creates one. A `@InjectSpy` is stubbed the same way (`doReturn` inside the helper).

### Fixtures and assertions

- **Canonical valid fixtures live in a `*TemplateEnum` per type** (`OrderTemplateEnum`), 2-3 entries covering distinct axes. A test never re-inlines a shape a template already canonicalizes: derive a copy. Only valid shapes belong there; an invalid one stays inline where its invalidity is the test's subject.
- **A request/JSON counterpart runs parallel to its model enum with the same entry names**: rename one side and the pairing is a silent mismatch nothing checks.
- **Generate ids, never hardcode them** in ad-hoc entities; a template's deterministic ids are the deliberate exception.
- **Each domain owns an assertion helper** (`OrderAssertUtils`) with field-by-field methods for model↔request and model↔response. Raw `assertEquals` chains drift silently as fields are added.

### The booted tiers — `@QuarkusTest`

**One application serves every `@QuarkusTest` class with the same profile and test resources.** It boots once, so a booted test is cheap after the first.

- **`@TestProfile` restarts the application** when its class differs from the previous test's. Use it for config read once at boot (a `@Startup` bean, a scheduler trigger); a value read per call is cheaper to stub with the producer below. `quarkus-junit` ships a class orderer that groups tests by profile, switched on by default: do not override `junit.jupiter.testclass.order.default`.
- ⚠ **`@QuarkusTestResource` on one class applies to the whole test module** unless `restrictToAnnotatedClass = true`, and that restart is paid per class. Dev Services makes a custom lifecycle manager rare; check that one is needed before adding it.
- ⚠ **The scheduler is enabled in tests.** A `@Scheduled` method fires on its real trigger during any `@QuarkusTest` (`patterns.md`). Set `%test.quarkus.scheduler.enabled=false` and call the job's method directly.
- **Authentication** is whatever the project's mechanism accepts (`security.md` is mechanism-neutral): the 401 case sends no credentials; the 403 case a valid identity without the role.

#### Dev Services — the database for the integration tiers

The test application starts a container for a datasource the configuration does not point anywhere.

- ⚠ **A configured URL means no container, and the tests run against it.** `quarkus.datasource.jdbc.url` present in the `test` profile (not behind `%prod.`) points every integration test at whatever it names. For MongoDB, `quarkus.mongodb.connection-string` or `quarkus.mongodb.hosts`.
- ⚠ **No container runtime fails differently per engine.** A JDBC datasource throws at boot in test mode. MongoDB only **warns** and carries on: the client falls back to `127.0.0.1:27017`, so the suite is green against a developer's local `mongod`, red on CI, and neither result is about your code. Confirm Docker is up before trusting a Mongo run.
- **The container lives for the application, not the class**, so classes see each other's rows. Delete what a test depends on in `@BeforeEach`; never rely on test order.
- ⚠ **`@TestTransaction` rolls back, and under Hibernate ORM nothing may flush first**, so a unique-constraint or `@Version` check passes vacuously. Call the repository's `flush()` in the test, or leave the annotation off tests that exist to prove such a check.

### Mocking — `@InjectMock` and `@InjectSpy`

Both come from `quarkus-junit-mockito` and work on fields of a `@QuarkusTest`. ⚠ `InjectMock` is `io.quarkus.test.InjectMock`; the `io.quarkus.test.junit.mockito.InjectMock` of older tests no longer exists, so a copied import does not compile.

- ⚠ **Only a normal-scoped bean can be mocked** (`@ApplicationScoped`, `@RequestScoped`): the mock is installed behind the client proxy. A `@Singleton` or `@Dependent` bean fails when the test instance is built, with "does not declare a CDI normal scope". That covers a `@Path` resource and a `@ConfigMapping` (below). Injected REST clients qualify: `@InjectMock @RestClient PaymentGateway gateway`.
- **A `@Singleton` needs `@MockitoConfig(convertScopes = true)` beside `@InjectMock`**, or `convertScopes = true` on `@InjectSpy`. ⚠ **The conversion applies to the whole test application, not the class**: declare it anywhere and that bean is `@ApplicationScoped` for every test, so a class that forgot it passes. Prefer the default scope in production code (`patterns.md`) over converting.
- **Mocks and spies are reset after every test method**: a stub never leaks into the next test.
- **`@InjectMock` stubs a third party in the integration tiers.** Never an internal service or repository there: it bypasses the flow under test.
- **`@InjectSpy`** keeps the real bean and lets a test stub one method or verify a call: suppress one outbound call in a `*ResourceTests` whose focus is not the integration. Never in a unit test, which builds the object itself.

#### Config values — a producer that spies the real mapping

A `@ConfigMapping` is a `@Dependent` bean, so `@InjectMock` rejects it. To stub values per test without a `@TestProfile`, add a test-only producer that spies the real mapping:

```java
@Dependent
public class UploadLimitsConfigProducer {
    @Inject Config config;

    @Produces @Singleton @io.quarkus.test.Mock
    UploadLimitsConfig uploadLimits() {
        return Mockito.spy(config.unwrap(SmallRyeConfig.class).getConfigMapping(UploadLimitsConfig.class));
    }
}
```

`@Inject UploadLimitsConfig` in the test and stub it through a helper (`mockUploadLimitsMaxBytes(uploadLimits, 1024L)`), whose body does the `doReturn(1024L).when(uploadLimits).maxBytes()`.

- ⚠ **`@Singleton`, not `@ApplicationScoped`.** The proxy is not a mock, and `doReturn(...).when(proxy)` fails with `NotAMockException`.
- `@Mock` is an alternative with priority 1, so the producer replaces the real mapping for every test in the module. Unstubbed, it behaves as the real one.
- ⚠ **Unlike `@InjectMock`, this spy is never reset.** Restore it in `@BeforeEach` through its helper (`resetUploadLimits(uploadLimits)`, whose body calls `Mockito.reset`), or the next test inherits the stub.

### Resource tests — RestAssured

RestAssured is pointed at the test application's host, port and `quarkus.http.root-path` before every test.

- ⚠ **It is not pointed at `quarkus.rest.path`.** With the base path `/api` (`api.md`), `get("/v1/orders")` goes to a URL that does not exist and answers **404**, so a "404 for an unknown id" test passes without reaching the resource. Put `@TestHTTPEndpoint(OrderResource.class)` on the class: the base becomes `quarkus.rest.path` plus the resource's `@Path`, and paths in the test are relative to the resource. An `@ApplicationPath` is not read; `api.md` declares the base path once for this reason.
- Assert the **status**, then the error body as `application/problem+json` (`api.md`), not `application/json` — except 401, which carries no body (`api.md` → *Errors*).
- **404, never 204.** A resource method returning `null` makes the resource answer 204 (`api.md`); a test that never checks the status of the miss does not see it.
- **A misspelt request field is dropped, not rejected** (`patterns.md`): send the body, then assert its effect.
- **401 and 403 per endpoint** (`security.md`): the policy is the annotations plus two switches no single file shows, and only these tests exercise it.

### Which test type for this change?

A change can hit several layers and need a test at each. Never substitute a higher tier for a lower one.

| Change | Required tests |
|--------|---------------|
| New or modified mapper, even pure field-to-field | `*Tests`: mappers are the API↔domain contract |
| Service method with logic | `*Tests` with mocked collaborators, **+** `*IntegrationTests` where real-database behaviour matters (uniqueness, atomic counters, index use, aggregates, partial-update semantics) |
| Repository query beyond find-by-id | `*IntegrationTests` |
| New or changed endpoint: path, status, auth rule, request/response shape | `*ResourceTests` |
| New or changed security annotation | `*ResourceTests`: 401 and 403 per endpoint |
| Changed call into an external provider | `*ExpensiveIntegrationTests` on the service that *directly* calls it |
| A flow only provable against the real provider | Both: `*ResourceTests` with the provider mocked, **and** a resource-level `*ExpensiveIntegrationTests` |
| Bug fix | Regression test in the layer where it manifested, **written first, asserting the bug** |
| Record or DTO with no defaulting and no custom construction | None |
| Anything that defaults, derives or validates during construction | A dedicated test for that behaviour |

⚠ **The suffix, not the layer, decides the tier.** A resource-level test that needs the real provider is named `*ExpensiveIntegrationTests`, and still has its cheap `*ResourceTests` sibling for the contract.

### What each layer must prove

Floors, not ceilings: skip a bullet only where the behaviour does not apply.

**Mapper `*Tests`**: every field maps in both directions; embedded objects delegate to their own mapper; the partial-update method preserves fields the payload omits; null and blank follow the contract; assertions go through the domain's `*AssertUtils`.

**Service `*Tests` (mocked)**: the happy-path rule; each validation failure with its correct code; uniqueness and state-transition rules, with the repository stubbed to simulate the pre-existing state.

**`*IntegrationTests` (real database)**: round-trip save → read with derived fields intact; **the unique constraint actually rejects the duplicate**; every custom or aggregate query; the optimistic-lock path under a real conflicting write, and a retry (`concurrency.md`) that re-reads and re-validates.

**`*ResourceTests`**, per endpoint:

- **200/201** with the expected body (201 only where the endpoint deliberately creates).
- **400** with the right validation code.
- **401** anonymous.
- **403** where a role or ownership restriction exists, as `application/problem+json` for both a role and an ownership denial.
- **404** for an unknown id: never 204.
- Pagination where the endpoint is paged.

**`*ExpensiveIntegrationTests`**: contract invariants (shape, required fields, limits) against a stable fixture, plus the provider's documented not-found behaviour. Never brittle exact content.

### Test boundary rules

- `*ResourceTests` are end to end: every internal layer is real. Third parties are mocked.
- `*IntegrationTests` mock external provider clients and use the real database. **A test that writes to or reads from a real repository is never a `*Tests`.**
- `*ExpensiveIntegrationTests` call the real provider, on the service that calls it directly, not on a higher-level one.
- A `*Tests` reaches nothing outside the JVM.
- Never `new` a CDI bean's collaborators inside a booted test, or write a stub subclass of a service: inject it.

### Meaningful tests — what to write and skip

A test asserts **behaviour or a contract**. If you cannot state in one sentence the business behaviour it proves, do not write it. Use realistic inputs; a value chosen only to hit a branch proves nothing about it.

**Don't write**: record and getter round-trips; Jackson round-trips with no custom serializer; a fixture asserting what you just put in it; switch branches and compile-time facts like inheritance; tests whose only assertion is `verify(mock).foo(...)`; trivial delegation (assert the outcome, not the wiring); one round-trip per enum value where a parameterized test covers it; a booted application started to prove something plain JUnit would prove.

**Do write**: mapper tests, including pure field-to-field; anything that defaults, derives or validates during construction (all three branches in `patterns.md` → *Entity Defaults*); business rules; every endpoint contract including its auth statuses; normalization logic; regression tests for fixed bugs, always, first.

- **Exact arguments first, inside the helpers.** Use `mockFoo` with the arguments the code is known to pass; reach for `mockFooAny…` only when the test cannot know one. A loose stub keeps passing when the code sends the wrong id, and an exact stub that misses answers Mockito's default, so assert the result for a wrong argument to fail.
- **A mock isolates a unit; it is not evidence at a tier whose job is the real effect.** Verifying an interaction is right where wiring is the subject (a scheduled job delegates to its service). At the integration tier a mock between the test and the effect lets a suite stay green while the feature is inert. Count real work (re-executions, queries issued), not a mock's invocations.
- **A retry that re-derives a value** (a fresh alias after a duplicate): assert the value differs between attempts, not only the attempt count.
- **Timing assertions measure from the caller**: the delay between the caller's start and the observed event (a bound that only grows under load), never the gap between two server-side arrivals.
- ⚠ **Retire an `assumeTrue` gate when its reason is gone**: the test still boots, then skips, and the skip reads as coverage.

### Test Plan in feature files

Every feature plan in `.agent-kit-local/planning/features/` has a required **Test Plan**: behaviours to prove per tier, not test method names. It gates `Discovery → Ready`, and a feature is not `Done` until every bullet is checked. `.agent-kit/planning/TEMPLATE.md` has the section format.

**Test Plan vs Acceptance Criteria**: AC is user-observable ("a user can upvote a media item"); the Test Plan is per-layer ("Resource: POST /media/{id}/upvote, 200, 400, 401; Service: rejects a duplicate upvote"). AC answers *done?*; the Test Plan answers *correct?*

**Bug fixes** get no feature file but do require the regression test written first, asserting the bug. The failing test is the plan.
