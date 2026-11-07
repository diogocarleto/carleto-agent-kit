## Testing

### Tiers — the class-name suffix decides what runs

| Tier | Suffix | Reaches | Profile |
|------|--------|---------|---------|
| Unit | `*Tests` | nothing outside the JVM | none (default) |
| Integration | `*IntegrationTests`, `*ControllerTests` | a real database; third parties **mocked** | `-Pintegration-tests` |
| Expensive | `*ExpensiveIntegrationTests` | real third-party APIs | `-Pexpensive-tests` |

⚠ **The suffix is a build decision, not a label.** A unit test named `*IntegrationTests` stops running in
the default pass; anything touching a real database without the suffix breaks the Docker-free build for
everyone. Maven invocations and the two ways to fool yourself about a run's result: `build-commands.md`.

⚠ **A slice test that needs no Docker is a `*Tests`.** `@WebMvcTest` loads a Spring context and leaves
the JVM for nothing, so it takes the plain suffix and runs in the default pass. A `@DataJpaTest` crosses
into `*IntegrationTests` the moment it points at a real database under Testcontainers — which, per *What
the persistence slices hide* below, is the only arrangement in which it proves anything about your engine.
⚠ **`@DataMongoTest` reaches a real server however it is wired**, so it is *always* `*IntegrationTests`.
`*ControllerTests` is the full-stack HTTP tier over that same real database — so ⚠ **a `@WebMvcTest` class
must never be named `*ControllerTests`**, natural as that reads: the suffix moves it to the tier the
default pass excludes. Name it `<Controller>WebTests` (`UserControllerWebTests`), which keeps the plain
suffix and says which slice it is.

### Design for the cheap tier

A service whose collaborators arrive through its constructor (`patterns.md`) is tested with plain JUnit +
Mockito and `new` — no context, milliseconds. **If a test needs a Spring context merely to construct the
object under test, the bean is wired wrong.** Reserve the expensive tiers for what genuinely needs them:
real persistence behaviour, and the HTTP contract.

⚠ **Every distinct set of bean overrides is a distinct application context.** The context cache is what
keeps a Spring suite bearable; one more `@MockitoBean` combination, or one more inline `properties=`,
forks a new context that nothing reuses. No single test gets slower — the suite does.

### Test method naming

`[verb][Subject][Condition]`. Simple names matching the operation are fine (`toResponse()`, `findById()`,
`update()`); anything else takes a descriptive prefix:

| Prefix | Usage | Example |
|--------|-------|---------|
| `verify*` | Assertion tests | `verifyUserAgeEquals35` |
| `check*` | Validation tests | `checkInvalidAccessToken` |
| `execute*` | Action/behaviour tests | `executeAnonymousRequest` |
| `find*` | Search/lookup tests | `findActiveSessionsByUser` |
| `exceed*` | Boundary/limit tests | `exceedRateLimitWithOneClient` |
| `save*` | Persistence tests | `saveDuplicateEmail` |
| `update*` | Modification tests | `updateNonExisting` |
| `apply*` | Feature application | `applyPartialUpdateKeepingStoredStatus` |

Multi-behaviour operations take `[operation][GerundBehavior][Condition]`
(`processBatchSkippingAlreadyImportedItems`). Avoid `Should`/`ShouldNot`.

- **`@DisplayName`** only when the method name cannot carry the purpose.
- **`@Nested`** only for a genuine difference in setup or shared state — never merely to group by topic.
- **`@ParameterizedTest`** for variant coverage; never a copy-pasted method per enum value. ⚠ Never pass an
  `AutoCloseable` (a Testcontainers container) as an argument: JUnit closes it, breaking the next class. Pass its address.

### Mocking discipline

**`@MockitoBean` and `@MockitoSpyBean`** (`org.springframework.test.context.bean.override.mockito`).
⚠ Boot 4 **removed** `@MockBean`/`@SpyBean` — a copied 3.x test class will not compile, and the
replacement is a Spring Framework annotation, not a Boot one.

**Stub every collaborator through a per-collaborator helper — never raw Mockito in the test body.** No
`Mockito.when(...)`, `Mockito.verify(...)`, `ArgumentCaptor`, `any()` or `eq()` in a test: each mocked
repository, domain service or external client gets a helper whose methods are semantic, so the test reads
as behaviour. Vocabulary:

- `mockFoo(args, returnValue)` — stub for **specific** args; `mockFooAny…(returnValue)` — loosened args,
  with `Any` placed immediately before each loosened parameter's name.
- `mockFooEmptyReturn(...)` / `mockFooNullReturn(...)` — the miss path, `Optional`/collection vs bare
  null. Don't invent `*NotFound`, `*Missing`, `*Blank`. Nor `*Then` / `*ReturnThen` for sequences — the
  sequence is the signature, not the name.
- `mockFooThrows(args, exception)` — the failure path.
- `mockFoo…(first, rest…)` — **sequenced stub**: one answer per successive call, named like the single-answer stub, no marker. Make the first answer a full value (`Optional`, result wrapper) so a sequence can open with a miss.
- `verifyFooAndReturn(args)` — owns the captor, runs the verify, and **returns** the captured value so the
  test asserts on a plain return (a record when one call captures several arguments).
- `verifyFooCalledOnce()` / `verifyNeverFoo()` — counts where the arguments do not matter.

### Fixtures and assertions

- **Canonical valid fixtures live in a `*TemplateEnum` per type**, 2–3 entries covering distinct axes. A
  test never re-inlines a shape a template already canonicalizes — derive a builder copy. Only valid
  shapes belong there; an invalid one stays inline where its invalidity is the test's subject.
- **A request/JSON counterpart runs parallel to its model enum with the same entry names** — rename one
  side and the pairing is a silent mismatch nothing checks. Persona-specific values are overrides in the
  parent enum, never new entries in the nested one.
- **Generate ids, never hardcode them** in ad-hoc entities; a template's deterministic ids are the
  deliberate exception.
- **Each domain owns an assertion helper** (`UserAssertUtils`) with field-by-field methods for
  model↔request and model↔response. Raw `assertEquals` chains drift silently as fields are added.

### What the web tiers can and cannot prove

**`@WebMvcTest` + `MockMvc`** — the controller's mapping, binding, validation and error shape, with
collaborators as `@MockitoBean`.

- ⚠ **Security is absent unless `spring-boot-starter-security-test` is a test dependency.** Boot 4 split
  slice registration per module: `spring-boot-webmvc-test` registers only the MockMvc auto-configurations.
  Everything security — the default filter chain, the `springSecurityFilterChain` registration, and the
  MockMvc security post-processor — is registered by `spring-boot-security-test`, which **neither
  `spring-boot-starter-test` nor `spring-boot-starter-webmvc-test` pulls in**. ⚠ **`@WebMvcTest`'s own
  javadoc still says it auto-configures Spring Security**, so reading the source is what produces the
  wrong answer. Without the dependency there is no filter chain, every request reaches the controller, a
  403 assertion fails, and — far worse — a 200 assertion passes having proved nothing about authorization.
- ⚠ **Even with it, your `SecurityConfig` is not picked up.** The slice includes beans whose *class*
  implements `SecurityFilterChain`; a `@Configuration` class exposing a `@Bean SecurityFilterChain` method
  does not, so it is filtered out and the chain under test is Boot's default. `@Import` it explicitly.
- **`@WithMockUser` populates the `SecurityContext` directly** — it exercises *authorization*, never
  *authentication*: nothing parses a token or a header. `roles = "ADMIN"` grants `ROLE_ADMIN`;
  `authorities` is verbatim (`security.md`). Authentication itself is a `*ControllerTests` concern.
- **CSRF**: a chain that leaves CSRF on makes every mutating request need the CSRF post-processor — and
  adding it reflexively hides a chain that should have been stateless.
- **MockMvc drives `DispatcherServlet` over mock request/response objects.** No container, no socket, no
  real HTTP parsing, no filter that only a servlet registration would add. Connector-level behaviour —
  compression, header limits — needs `@SpringBootTest(webEnvironment = RANDOM_PORT)`.
- ⚠ **`MockMvcBuilders.standaloneSetup(controller)` proves less still**: no application context, so no
  `@RestControllerAdvice` unless handed in, no Boot message converters, no security. Use the
  `@WebMvcTest` context.

**`*ControllerTests`** — `@SpringBootTest` with the real context and a real database, over HTTP
(`RANDOM_PORT`) or through `@AutoConfigureMockMvc`. Every internal layer is real; never `@MockitoBean` an
internal service, which bypasses the flow under test. Third parties are stubbed.

### What the persistence slices hide

⚠ **Boot 4 splits these per technology and `spring-boot-starter-test` brings neither**: `@DataJpaTest`
needs `spring-boot-starter-data-jpa-test`, `@DataMongoTest` needs `spring-boot-starter-data-mongodb-test`.

**`@DataJpaTest`** (`org.springframework.boot.data.jpa.test.autoconfigure`)

- ⚠ **It is `@Transactional`, so nothing ever commits.** A unique-constraint, trigger or
  deferred-check test that never flushes passes vacuously. Force the write.
- ⚠ **It replaces the DataSource unless the DataSource looks like a test one.** A Testcontainers
  `@ServiceConnection` or a `@DynamicPropertySource` url is kept; a hardcoded `spring.datasource.url` is
  **swapped for an embedded database**, and every dialect-specific behaviour you meant to prove is proved
  against the wrong engine (`persistence-<db>.md`).

**`@DataMongoTest`** (`org.springframework.boot.data.mongodb.test.autoconfigure`) — the symmetry stops at
the name, and both differences invert:

- ⚠ **It is *not* `@Transactional`.** Every write commits and survives into the next test method, so
  order-dependent passes and cross-test pollution are yours to prevent — drop the collections in
  `@BeforeEach`. A rollback would need the `MongoTransactionManager` bean and the replica set
  `persistence-mongodb.md` describes.
- ⚠ **Nothing is substituted for the server.** The annotation carries no counterpart to
  `@AutoConfigureTestDatabase`, so with no container wired the slice falls back to
  `mongodb://localhost/test` — green against a developer's local `mongod`, red on CI, and neither result
  is about your code.

**Testcontainers** is how the integration tiers get their database. Prefer `@ServiceConnection` on a
`static` container over hand-wiring properties — it is what keeps the replacement rule above on your side,
and one shared container definition keeps the suite on one context.

⚠ **A Mongo container is a standalone `mongod` unless you ask for more.** The current
`org.testcontainers.mongodb.MongoDBContainer` initiates a replica set only on `withReplicaSet()`; the
deprecated `org.testcontainers.containers.MongoDBContainer` it replaces always did, and Boot drops its
connection-details support for that one in 4.2. Move to the new class without adding the call and the code
still compiles, the container still connects, and every transactional path fails — Boot builds the
connection string from `getReplicaSetUrl()`, which returns the same plain URL either way.

### Which test type for this change?

A change can hit several layers and need tests at each — never substitute a higher tier for a lower one.

| Change | Required tests |
|--------|---------------|
| New or modified mapper, even pure field-to-field | `*Tests` — mappers are the API↔domain contract |
| Service method with logic | `*Tests` with mocked collaborators, **+** `*IntegrationTests` where real-DB behaviour matters (uniqueness, atomic counters, index use, aggregates, partial-update semantics) |
| Repository query beyond find-by-id — a `Specification` (JPA), an `@Query`, `@Aggregation` or custom fragment (Mongo) | `*IntegrationTests` |
| New or changed endpoint — path, status, auth rule, request/response shape | `*ControllerTests` |
| New or changed security rule, matcher or `@PreAuthorize` | `*ControllerTests` — 401 and 403 per endpoint |
| Changed call into an external provider | `*ExpensiveIntegrationTests` on the service that *directly* calls it |
| A flow only provable against the real provider | Both: `*ControllerTests` with the provider stubbed, **and** a resource-level `*ExpensiveIntegrationTests` |
| Bug fix | Regression test in the layer where it manifested — **written first, asserting the bug** |
| Record or DTO with no defaulting and no custom construction | None |
| Anything that defaults, derives or validates during construction | A dedicated test for that behaviour |

### What each layer must prove

Floors, not ceilings — skip a bullet only where the behaviour does not apply.

**Mapper `*Tests`** — construct the generated `*Impl` with `new`, passing its `uses` mappers (this is why
`patterns.md` mandates constructor injection on `@Mapper`); every field maps both directions; embedded
objects delegate to their own mapper; the partial-update method preserves fields the payload omits;
assertions go through the domain helper.

**Service `*Tests` (mocked)** — the happy-path rule; each validation failure with its correct code;
uniqueness and state-transition rules with the repository stubbed to simulate the pre-existing state.

**`*IntegrationTests` (real database)** — round-trip save → read with derived fields intact; **the unique
constraint actually rejects the duplicate**; every custom or aggregate query; the optimistic-lock path
under a simulated concurrent write.

**`*ControllerTests`** — per endpoint: 200/201 happy path with the expected body, 400 with the right
validation code, **401 anonymous**, **403 where a role or ownership restriction exists**, 404 for an
unknown id, and pagination where the endpoint is paged. Assert the error body as
`application/problem+json` (`api.md`).

**`*ExpensiveIntegrationTests`** — contract invariants (shape, required fields, limits) against a stable
fixture, plus the provider's documented not-found behaviour. Never brittle exact content.

### Meaningful tests — what to write and skip

A test asserts **behaviour or a contract**. If you cannot state in one sentence the business behaviour it
proves, do not write it. Use realistic inputs; a value chosen only to hit a branch proves nothing about it.

**Don't write**: record and getter round-trips; Jackson round-trips with no custom serializer; a fixture
asserting what you just put in it; switch branches and compile-time facts like inheritance; tests whose
only assertion is `verify(mock).foo(...)`; trivial delegation — assert the outcome, not the wiring; one
round-trip per enum value where a parameterized test covers it; a Spring context started to prove
something plain JUnit would prove.

**Do write**: mapper tests, including pure field-to-field; anything that defaults, derives or validates
during construction; business rules — uniqueness, state transitions, validation; every endpoint contract
including its auth statuses; normalization logic; regression tests for fixed bugs, always, first.

⚠ **A cache-freshness test edits through the owning service** (so `@CacheEvict`/`@CachePut` fires) and never clears the cache (`CacheManager`, `cache.clear()`) between the warm read and the re-read — that hides a broken eviction. Clearing in setup or cleanup is fine, as is a test of the invalidation itself.

⚠ **Retire an `assumeTrue` gate when its reason is gone**: the test still boots, then skips, and the skip
reads as coverage. Re-check gates when the guarded mechanism changes.

⚠ **Prove "nothing was instantiated" with a counting raw `FactoryBean`**: Spring types plain classes
without creating them, so only a raw `FactoryBean` whose constructor counts can show it (assert `0`).

### Test Plan in feature files

Every feature plan in `.agent-kit-local/planning/` carries a **Test Plan** — behaviours to prove per tier,
not test method names. It gates `Discovery → Ready`, and a feature is not `Done` until every bullet is
checked.

**Test Plan vs Acceptance Criteria**: AC is user-observable ("a user can upvote a media item"); the Test
Plan is per-layer ("Controller: POST /media/{id}/upvote — 200, 400, 401; Service: rejects a duplicate
upvote"). AC answers *done?*; the Test Plan answers *correct?*

**Bug fixes** get no feature file but do require the regression test written first, asserting the bug. The
failing test is the plan.
