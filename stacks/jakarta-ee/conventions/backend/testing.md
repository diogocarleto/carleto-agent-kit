## Testing

### Tiers — the class-name suffix decides what runs

| Tier | Suffix | May reach | Runs |
|------|--------|-----------|------|
| Unit | `*Tests` | nothing outside the JVM | default build |
| Integration | `*IntegrationTests` | a real database; external providers **mocked** | `-Pintegration-tests` |
| Resource | `*ResourceTests` | the deployed app over HTTP, every internal layer real | `-Pintegration-tests` |
| Expensive | `*ExpensiveIntegrationTests` | real third-party APIs | `-Pexpensive-tests` |

⚠ **The suffix is a build decision, not a label.** A unit test named `*IntegrationTests` stops running in the default pass; an integration test without the suffix breaks the Docker-free build for everyone. Any test that touches a real database is `*IntegrationTests` even if some collaborators are mocked.

### Design for the cheap tier

A service whose collaborators arrive through its constructor (`patterns.md`) is tested with plain JUnit + Mockito and `new` — no container, no deployment, milliseconds. **If a test needs the container merely to construct the object under test, the bean is wired wrong.** Reserve the expensive tiers for what genuinely needs them: real persistence behaviour, and the HTTP contract.

⚠ RUNTIME GAP — the in-container test bootstrap (Arquillian, the runtime's own test support, or an embedded CDI container for CDI-only beans) and how a `*ResourceTests` obtains the deployed base URI. Everything below about *what* each tier proves is independent of that choice. Fill when the runtime is chosen; do not guess.

### Test method naming

`[verb][Subject][Condition]`. Simple names matching the operation are fine for straightforward cases (`toResponse()`, `findById()`, `update()`); use a descriptive prefix for anything else:

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

Multi-behaviour operations take `[operation][GerundBehavior][Condition]` (`processBatchSkippingAlreadyImportedItems`). Avoid `Should`/`ShouldNot` — use an imperative verb or a gerund.

### Test annotations

- **`@DisplayName`** — only when the method name cannot carry the purpose. Self-explanatory names (`saveDuplicateEmail`) get none.
- **`@Nested`** — only for a genuine difference in setup or shared state between groups. Never merely to group by topic: it adds indentation and costs readability. Use comment separators instead.
- **`@ParameterizedTest`** with `@CsvSource`/`@MethodSource` for variant coverage — never copy-paste a method per enum value.
  ⚠ Never pass an `AutoCloseable` (a Testcontainers container) as an argument: JUnit closes it, breaking the next class. Pass its address.

### Mocking discipline

**Stub every collaborator through a per-collaborator test helper — never raw Mockito in the test body.** A `*ServiceTests` must not call `Mockito.when(...)`, `Mockito.verify(...)`, `ArgumentCaptor`, `any()` or `eq()` directly: each mocked repository, domain service or external client gets a helper whose methods are semantic, keeping matchers and captor wiring out of the test so the test reads as behaviour.

Vocabulary:

- `mockFoo(args, returnValue)` — stub for **specific** args; `mockFooAny…(returnValue)` — loosened args, with `Any` placed immediately before each loosened parameter's name.
- `mockFooEmptyReturn(...)` / `mockFooNullReturn(...)` — the miss path, for `Optional`/collection vs bare null. Don't invent `*NotFound`, `*Missing`, `*Blank`. Nor `*Then` / `*ReturnThen` for sequences — the sequence is the signature, not the name.
- `mockFooThrows(args, exception)` — the failure path.
- `mockFoo…(first, rest…)` — **sequenced stub**: one answer per successive call, named like the single-answer stub, no marker. Make the first answer a full value (`Optional`, result wrapper) so a sequence can open with a miss.
- `verifyFooAndReturn(args)` — owns the captor, runs the verify, and **returns** the captured value so the test asserts on a plain return (a record when one call captures several arguments).
- `verifyFooCalledOnce()` / `verifyNeverFoo()` — invocation-count checks where the arguments do not matter.

### Fixtures and assertions

- **Canonical valid fixtures live in a `*TemplateEnum` per type**, 2–3 entries covering distinct axes. A test never re-inlines a shape a template already canonicalizes — derive with a builder copy instead. Only valid shapes belong there; an invalid one stays inline where its invalidity is the test's subject.
- **A request/JSON counterpart runs parallel to its model enum, with the same entry names** — `AUDIO_PUBLISHED` in both `MediaTemplateEnum` and `MediaRequestTemplateEnum`. A test then pairs a model with its payload by name; rename one side and the pairing is a silent mismatch nothing checks.
- **Persona-specific values are overrides in the parent enum, never new entries in the nested one.** Where an entry references another domain's type, call that enum's template and derive a copy from it. Adding a per-persona id as its own entry in the nested enum makes a shared generic fixture specific to one caller.
- **Generate ids, never hardcode them** in ad-hoc entities — a template's deterministic ids are the deliberate exception.
- **Each domain owns an assertion helper** (`UserAssertUtils`) with field-by-field methods for model↔request and model↔response. Never raw `assertEquals` chains for object comparison; they drift silently as fields are added.
- **`*ResourceTests` centralize the HTTP plumbing** — base URI, auth headers, JSON binding and DB cleanup live in one support class that every resource test extends. RestAssured `given()` chains are not repeated per test. Wipe what the class writes in `@BeforeEach`; a test that depends on another test's leftovers passes alone and fails in CI.

### Which test type for this change?

A change can hit several layers and need tests at each — never substitute a higher tier for a lower one.

| Change | Required tests |
|--------|---------------|
| New or modified mapper, even pure field-to-field | `*Tests` — mappers are the API↔domain contract |
| Service method with logic | `*Tests` with mocked collaborators, **+** `*IntegrationTests` where real-DB behaviour matters (uniqueness, atomic counters, index use, aggregate queries) |
| Repository query beyond find-by-id | `*IntegrationTests` |
| New or changed endpoint — path, status, auth rule, request/response shape | `*ResourceTests` |
| Changed call into an external provider | `*ExpensiveIntegrationTests` on the service that *directly* calls it, not on a consumer of that service |
| A flow only provable against the real provider | Both: `*ResourceTests` for the contract with the provider stubbed, **and** a resource-level `*ExpensiveIntegrationTests` for the flow |
| Bug fix | Regression test in the layer where it manifested — **written first, asserting the bug** |
| Record or DTO with no defaulting and no custom construction | None |
| Anything with a default, a derived field or custom construction | A dedicated test for the defaulting behaviour |

### What each layer must prove

Floors, not ceilings — skip a bullet only where the behaviour does not apply.

**Mapper `*Tests`** — construct the generated `*Impl` with `new`, passing its `uses` mappers (`patterns.md` mandates constructor injection for exactly this); every field maps in both directions; embedded objects delegate to their own mapper; the partial-update method preserves fields the payload omits; assertions go through the domain helper.

**Service `*Tests` (mocked)** — the happy-path rule; each validation failure with its correct code; uniqueness and state-transition rules, with the repository stubbed to simulate the pre-existing state.

**`*IntegrationTests` (real database)** — round-trip save → read with derived fields intact; **the unique constraint actually rejects the duplicate**; every aggregate or custom query; the optimistic-lock retry under a simulated concurrent write.

**`*ResourceTests`** — per endpoint: 200/201 happy path with the expected body, 400 with the right validation code, 401 when anonymous, 403 where a role restriction exists, 404 for an unknown id, and pagination behaviour where the endpoint is paged.

**`*ExpensiveIntegrationTests`** — contract invariants (shape, required fields, limits) against a stable fixture, plus the provider's documented not-found behaviour. Never brittle exact content.

### Meaningful tests — what to write and skip

A test asserts **behaviour or a contract**. If you cannot state in one sentence the business behaviour it proves, do not write it.

**Don't write**: record and getter round-trips; binding round-trips with no custom mapping or serializer; a fixture asserting what you just put in it; switch/lookup branches and compile-time facts like inheritance; tests whose only assertion is `verify(mock).foo(...)`; trivial delegation ("the service called the repository with the same argument") — assert the outcome, not the wiring; one round-trip per enum value where a parameterized test covers the pattern.

**Do write**: mapper tests, including pure field-to-field; anything that defaults, derives or validates during construction; business rules — uniqueness, state transitions, validation; every endpoint contract; normalization logic; regression tests for fixed bugs, always, first.

Use **realistic inputs** — values that could appear in production. An arbitrary value chosen only to hit a branch proves nothing about the branch.

⚠ **A cache-freshness test edits through the owning service** and never invalidates the cache manually between the warm read and the re-read — that hides a broken eviction. Clearing in setup or cleanup is fine, as is a test of the invalidation itself.

⚠ **Retire an `assumeTrue` gate when its reason is gone**: the test still boots, then skips, and the skip reads as coverage. Re-check gates when the guarded mechanism changes.

### Test Plan in feature files

Every feature plan in `.agent-kit-local/planning/` carries a **Test Plan** — behaviours to prove per tier, not test method names. It gates `Discovery → Ready`, and a feature is not `Done` until every bullet is checked.

**Test Plan vs Acceptance Criteria**: AC is user-observable ("a user can upvote a media item"); the Test Plan is per-layer ("Resource: POST /media/{id}/upvote — 200, 400, 401; Service: rejects a duplicate upvote"). AC answers *done?*; the Test Plan answers *correct?*

**Bug fixes** get no feature file but do require the regression test written first, asserting the bug. The failing test is the plan.
