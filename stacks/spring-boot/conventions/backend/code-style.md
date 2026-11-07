## Code Style

Read together with `.agent-kit/backend/core.md`, the stack-neutral kernel; this doc says how this stack expresses it, and wins where they differ.

### Type Naming Conventions

Apply the suffix that matches the type's role. The core's roles (`Request`, `Response`, `Stats`, `Preview`, `Options`) apply as written; `Stats` is widened below. `Request`/`Response` are the HTTP DTOs. This stack adds:

| Suffix | Role | Examples |
|--------|------|---------|
| *(none)* | Domain entity | `User`, `Role`, `Media` |
| `PageResponse` | Paginated outbound DTO | `UserPageResponse` |
| `Enum` | Any enum | `MediaTypeEnum`, `SessionStatusEnum` |
| `Properties` | `@ConfigurationProperties` record — externalized values, limits, tuning | `MediaSizeProperties` |
| `Config` | `@Configuration` class — bean definitions only, no values | `HttpClientConfig` |
| `Aggregation` | Aggregate query output | `GlobalStatsAggregation` |
| `Stats` | Also aggregated state, beyond the core's counters snapshot | `GlobalStats` |
| `Summary` | Aggregated counters of a completed operation | `BulkImportSummary` |
| `Outcome` | Result of processing one element in a batch | `ItemImportOutcome` |
| `Result` | Verdict of one discrete operation: status/kind + optional payload or reason | `AuthenticationResult` |
| `Context` | Bundled inputs passed through a processing pipeline | `ImportContext` |
| `Mapper` | MapStruct mapper | `UserMapper` |
| `Service` | Spring bean holding business rules | `UserService` |
| `Repository` | Spring Data repository interface for one aggregate | `UserRepository` |
| `Controller` | `@RestController` | `UserController` |

⚠ **`Properties` and `Config` are two roles, not two words for one.** A `Properties` record is bound from
the environment and injected where the values are needed; a `Config` class defines beans the framework
cannot discover by scanning. A class doing both can be tested as neither.

**`Result` vs `Summary` vs `Outcome` — litmus test:** remove the status/verdict field; do you still have a meaningful object?
- **Yes** → not a `Result`. Numeric tallies → `Summary`. One item inside a batch → `Outcome`. Plain data → VO / model.
- **No** → `Result` fits: the object exists to deliver a verdict (auth succeeded/failed, cache hit/miss).

### Modern Java Features (Required)

**Baseline: Java 21** — the stack's choice, not the framework's: Spring Boot 4.1 and Framework 7.0 are
compiled for Java 17, so 17 would run. 21 is pinned in `maven.compiler.release` for pattern matching in
`switch` (a preview feature on 17) and because virtual threads only activate there (`concurrency.md`).

- **`var`** for local variables when the type is obvious
- **Records** for immutable data carriers — DTOs, value objects, aggregation results, `@ConfigurationProperties`. Never a mutable class with setters
- **Sealed classes** for restricted hierarchies
- **Pattern matching** in `instanceof` and `switch`
- **Text blocks** for multi-line strings (JSON, JPQL, native SQL)
- **Stream API** for collection processing, over imperative loops
- **`Optional`** for nullable return values, or a parameter whose absence is contractual — never null, and never a field
- **Collection factories**: `List.of()`, `Set.of()`, `Map.of()`

**A `@ConfigurationProperties` record needs no binding annotation** — a single parameterized constructor
already selects constructor binding, which is what keeps the type immutable and `new`-able in a test.
⚠ Annotating that constructor `@Autowired` switches constructor binding off, and adding a setter "so it
binds" turns the record into a mutable class for nothing.

### Nullability — JSpecify

Annotate with `org.jspecify.annotations.Nullable`, which is what Framework 7 and Spring Data 4 use
themselves. ⚠ `org.springframework.lang.Nullable` still resolves but is deprecated as of 7.0 — it
compiles, so nothing stops a copy-pasted import from spreading the old one through a new codebase.

### Enum Naming (Required for all enums)

Every enum carries the `Enum` suffix: `MediaTypeEnum`, `SessionStatusEnum` ✓ — `MediaType`, `SessionStatus` ✗. **Variables and parameters never carry it**: `mediaType`, not `mediaTypeEnum`.

### Enum Convention (Required for all API-facing enums)

Every enum appearing in a Request or Response DTO **must** have:
1. `public final String value` — lowercase snake_case, stored in the database and sent over the wire.
2. `static fromValue(String value)` — case-insensitive lookup, throwing the domain validation exception (`patterns.md`) on no match.

Enums used for UI display may add `public final String displayName`. **Internal-only enums** (never in a DTO) may throw `IllegalArgumentException` from `fromValue` instead.

**No JSON-binding annotations on enums** — DTO fields are `String`, so the binding layer never sees an enum type. The mapper is the only place that calls `fromValue()` or reads `.value`.

### DTO and Controller Enum Inputs — Always String

Request/Response DTOs **must never** declare enum-typed fields, and neither may `@RequestParam`, `@PathVariable` or `@RequestHeader` parameters. They enter as `String`; the controller converts with `fromValue(...)` before calling the service. Services receive typed models only.

This keeps the HTTP contract aligned with the enum's `value` (`audio`, `draft`) instead of its constant
name (`AUDIO`, `DRAFT`) — and keeps a malformed value a 400 you shaped, with your message, rather than a
type-conversion failure the framework shaped.

### Code Conventions

- **No inner types** — records, VOs and enums never nested inside another class, including utilities. Each type lives in its own file in the right package (`model/`, `model/vo/`, `util/`). Inner types are invisible to mappers and tests, couple the type to the outer class's lifecycle, and violate SRP.
- **Wrappers, never primitives** — `Boolean`, `Integer`, `Long`, `Double`, never `boolean`/`int`/`long`/`double`: fields of entities, VOs, DTOs and records, enum fields, method parameters and returns, and `@ConfigurationProperties` fields. Wrappers carry `null` for unset; read them null-safely (`Boolean.TRUE.equals(x)`, not `if (x)`).
- **Parameters**: max 4 per method; encapsulate more in a record.
- **HTTP verbs**: POST/PUT carry a full payload — absent fields become null. PATCH carries a partial one — only present fields change. These are **two mapper methods**, chosen explicitly by the controller; never one method reading a thread-bound "current update type" (it breaks the moment mapping runs on an executor — `concurrency.md`).

### Repository Method Naming

⚠ **On a derived query the method name *is* the query** — everything after `findBy` is parsed as a
property path — so naming is not free here as it is elsewhere. Two rules follow:

- **Never suffix a derived method.** `findByEmailOptional` makes the parser look for a property
  `emailOptional`, find none, and fail to create the repository. Declare the return as `Optional<T>`; the
  signature already carries the shape, which is why the suffix bought nothing.
- **One verb per intent**: `find…` to read, plus `count…`, `exists…`, `delete…`. The parser also accepts
  `read`/`get`/`query`/`search`/`stream` and `remove`, so a codebase that does not choose ends up with
  four spellings of one operation and no way to grep for it.

A method that finds by criteria is a `findBy…` returning `Page<T>` or `Slice<T>` — `page` is not one of
the parser's verbs, and the return type carries the shape, exactly as `Optional<T>` does above. ⚠ **Only
`Page<T>` is checked**: a `Page<T>` method with no `Pageable` parameter fails at startup, while the same
`Slice<T>` method boots and runs **unpaged**, silently. Declare the `Pageable`. ⚠ A plain `List<T>`
return is only correct when the result is genuinely **input-bounded** — `persistence-<db>.md` says what
bounds it.

A `@Query` method's name is not parsed, but name it the same way: both kinds sit in one interface and the
call site cannot tell them apart.

### Helper Method Naming — `obtain*` for derivation

The core's rule (non-trivial computation never reads as a bare noun) is spelled `obtain*` here, and extends to lookups: a method that **computes or extracts** a value (lookup, calculation, pattern-switch) is prefixed `obtain*`, never a bare noun.

- Derivation → `obtain*`: `obtainOrderId(...)`, not `orderId(...)`.
- Type conversion → `to*`: `toResponse`, `toMinorUnits`.
- Plain accessor (no logic) → `get*`.

### Immutability & Functional Style

The core's rules hold — no input mutation, pure pipeline steps (`forEach` included — collect first, then act), pure logic with I/O at the edges (controllers and repositories here), and a captured return from a side-effecting method. In Java:

- **Records for data carriers**: DTOs, value objects, aggregation results.
- **Immutable collections**: `List.of()` / `Set.of()` / `Map.of()`. Never return a mutable `ArrayList` from a service or mapper.
- **No collection copying in constructors/factories** — assign directly; the call site owns what it passes.
- **Final fields** in non-record classes wherever possible.
- **Entity mutability carve-out**: a persistence-mapped entity **may** be mutable where its binding needs it to be. Spring Data supports immutable entities outright (`@Immutable`, wither-based updates), so mutability is the binding's call, not a given — **`persistence-<db>.md` says whether this one requires it**, and whether a setter outside a transaction is a bug or the write itself.

### Static utility vs Spring bean

The core's rule, in Java: no collaborators and no state → `public final` class, private constructor, `static` methods. Injects a collaborator or holds per-instance state → a `@Component`/`@Service` bean (`patterns.md`). ⚠ Static is **un-mockable by design** in Java — wanting to mock one means the logic is not pure and belongs with the bean that owns the I/O.

### Documentation

Javadoc bar + budget: `.agent-kit/common/process/authoring/`. No stack deltas — this is an application, so the default budget applies as written.
