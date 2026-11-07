## Code Style

Read together with `.agent-kit/backend/core.md`, the stack-neutral kernel; this doc says how this stack expresses it, and wins where they differ.

### Type Naming Conventions

Apply the suffix that matches the type's role. The core's roles (`Request`, `Response`, `Stats`, `Preview`, `Options`) apply as written; `Stats` is widened below. `Request`/`Response` are the HTTP DTOs. This stack adds:

| Suffix | Role | Examples |
|--------|------|---------|
| *(none)* | Domain entity | `User`, `Role`, `Media` |
| `PageResponse` | Paginated outbound DTO | `UserPageResponse` |
| `Enum` | Any enum | `MediaTypeEnum`, `SessionStatusEnum` |
| `Config` | Configuration record (values, limits, tuning) | `MediaSizeConfig` |
| `Aggregation` | Aggregate query output | `GlobalStatsAggregation` |
| `Stats` | Also aggregated state, beyond the core's counters snapshot | `GlobalStats` |
| `Summary` | Aggregated counters of a completed operation | `BulkImportSummary` |
| `Outcome` | Result of processing one element in a batch | `ItemImportOutcome` |
| `Result` | Verdict of one discrete operation: status/kind + optional payload or reason | `AuthenticationResult` |
| `Context` | Bundled inputs passed through a processing pipeline | `ImportContext` |
| `Mapper` | MapStruct mapper | `UserMapper` |
| `Service` | CDI bean holding business rules | `UserService` |
| `Repository` | The only type that talks to the database for a domain | `UserRepository` |
| `Resource` | JAX-RS resource | `UserResource` |

**`Result` vs `Summary` vs `Outcome` — litmus test:** remove the status/verdict field; do you still have a meaningful object?
- **Yes** → not a `Result`. Numeric tallies → `Summary`. One item inside a batch → `Outcome`. Plain data → VO / model.
- **No** → `Result` fits: the object exists to deliver a verdict (auth succeeded/failed, cache hit/miss).

### Modern Java Features (Required)

**Baseline: Java 21** — the stack's choice, not the platform's: Jakarta EE 11 requires Java 17. Pin it in `maven.compiler.release` and confirm the chosen runtime is certified on it. The one Required item 17 cannot carry is **pattern matching in `switch`**, a preview feature there and a language guarantee only from 21.

- **`var`** for local variables when the type is obvious
- **Records** for immutable data carriers — DTOs, value objects, aggregation results. Never a mutable class with setters
- **Sealed classes** for restricted hierarchies
- **Pattern matching** in `instanceof` and `switch`
- **Text blocks** for multi-line strings (JSON, multi-line queries)
- **Stream API** for collection processing, over imperative loops
- **`Optional`** for nullable return values, or a parameter whose absence is contractual — never null, and never a field
- **Collection factories**: `List.of()`, `Set.of()`, `Map.of()`

### Enum Naming (Required for all enums)

Every enum carries the `Enum` suffix: `MediaTypeEnum`, `SessionStatusEnum` ✓ — `MediaType`, `SessionStatus` ✗. **Variables and parameters never carry it**: `mediaType`, not `mediaTypeEnum`.

### Enum Convention (Required for all API-facing enums)

Every enum appearing in a Request or Response DTO **must** have:
1. `public final String value` — lowercase snake_case, stored in the database and sent over the wire.
2. `static fromValue(String value)` — case-insensitive lookup, throwing the domain validation exception (`patterns.md`) on no match.

Enums used for UI display may add `public final String displayName`. **Internal-only enums** (never in a DTO) may throw `IllegalArgumentException` from `fromValue` instead.

**No JSON-binding annotations on enums** — DTO fields are `String`, so the binding layer never sees an enum type. The mapper is the only place that calls `fromValue()` or reads `.value`.

### DTO and Resource Enum Inputs — Always String

Request/Response DTOs **must never** declare enum-typed fields, and neither may `@QueryParam`, `@PathParam`, `@HeaderParam` or `@BeanParam` fields. They enter as `String`; the resource converts with `fromValue(...)` before calling the service. Services receive typed models only.

This keeps the HTTP contract aligned with the enum's `value` (`audio`, `draft`) instead of its constant name (`AUDIO`, `DRAFT`) — and keeps a malformed value a 400 you shaped, not a binding failure the container shaped.

### Code Conventions

- **No inner types** — records, VOs and enums never nested inside another class, including utilities. Each type lives in its own file in the right package (`model/`, `model/vo/`, `util/`). Inner types are invisible to mappers and tests, couple the type to the outer class's lifecycle, and violate SRP.
- **Wrappers, never primitives** — `Boolean`, `Integer`, `Long`, `Double`, never `boolean`/`int`/`long`/`double`: fields of entities, VOs, DTOs and records, enum fields, method parameters and returns, and config-property methods. Wrappers carry `null` for unset; read them null-safely (`Boolean.TRUE.equals(x)`, not `if (x)`).
- **Parameters**: max 4 per method; encapsulate more in a record.
- **HTTP verbs**: POST/PUT carry a full payload — absent fields become null. PATCH carries a partial one — only present fields change. These are **two mapper methods**, chosen explicitly by the resource; never one method reading a thread-bound "current update type" (it breaks the moment mapping runs on a managed executor).

### Repository Method Naming

A repository method returning `Optional<T>` is suffixed `Optional` (`findByEmailOptional`), making the return shape obvious at every call site. Methods returning `T` (throwing on miss) or `List<T>` keep plain names. A method that finds by criteria returns a page and is named `pageBy…`, whatever the database. ⚠ A plain-named `List<T>` is only correct when the return is genuinely **input-bounded** — see `persistence-<db>.md` for what bounds it and how that page is read.

### Helper Method Naming — `obtain*` for derivation

The core's rule (non-trivial computation never reads as a bare noun) is spelled `obtain*` here, and extends to lookups: a method that **computes or extracts** a value (lookup, calculation, pattern-switch) is prefixed `obtain*`, never a bare noun.

- Derivation → `obtain*`: `obtainOrderId(...)`, not `orderId(...)`.
- Type conversion → `to*`: `toResponse`, `toMinorUnits`.
- Plain accessor (no logic) → `get*`.

### Immutability & Functional Style

The core's rules hold — no input mutation, pure pipeline steps (`forEach` included — collect first, then act), pure logic with I/O at the edges (resources and repositories here), and a captured return from a side-effecting method. In Java:

- **Records for data carriers**: DTOs, value objects, aggregation results.
- **Immutable collections**: `List.of()` / `Set.of()` / `Map.of()`. Never return a mutable `ArrayList` from a service or mapper.
- **No collection copying in constructors/factories** — assign directly; the call site owns what it passes.
- **Final fields** in non-record classes wherever possible.
- **Entity mutability exception**: a persisted entity may be mutable where its binding requires it. **Where that mutation may happen is the binding's rule** — `persistence-<db>.md` says whether a setter outside the persistence layer is a bug or the write itself.

### Static utility vs CDI bean

The core's rule, in Java: no collaborators and no state → `public final` class, private constructor, `static` methods. Injects a collaborator or holds per-instance state → `@ApplicationScoped`. ⚠ Static is **un-mockable by design** in Java — wanting to mock one means the logic is not pure and belongs with the bean that owns the I/O.

### Documentation

Javadoc bar + budget: `.agent-kit/common/process/authoring/`. No stack deltas — this is an application, so the default budget applies as written.
