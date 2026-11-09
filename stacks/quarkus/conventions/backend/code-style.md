## Code Style

Read together with `.agent-kit/backend/core.md`, the stack-neutral kernel; this doc says how this stack expresses it, and wins where they differ.

### Type Naming Conventions

Apply the suffix that matches the type's role. The core's roles (`Request`, `Response`, `Stats`, `Preview`, `Options`) apply as written; `Stats` is widened below. `Request`/`Response` are the HTTP DTOs. This stack adds:

| Suffix | Role | Examples |
|--------|------|---------|
| *(none)* | Domain entity | `Customer`, `Order`, `Invoice` |
| `PageResponse` | Paginated outbound DTO | `CustomerPageResponse` |
| `Enum` | Any enum | `InvoiceStatusEnum`, `PaymentMethodEnum` |
| `Config` | `@ConfigMapping` interface — externalized values, limits, tuning | `UploadLimitsConfig` |
| `Aggregation` | Aggregate query output | `GlobalStatsAggregation` |
| `Stats` | Also aggregated state, beyond the core's counters snapshot | `GlobalStats` |
| `Summary` | Aggregated counters of a completed operation | `BulkImportSummary` |
| `Outcome` | Result of processing one element in a batch | `ItemImportOutcome` |
| `Result` | Verdict of one discrete operation: status/kind + optional payload or reason | `AuthenticationResult` |
| `Context` | Bundled inputs passed through a processing pipeline | `ImportContext` |
| `Filters` | A repository query's criteria once they push the method past 4 params (*Code Conventions* below), as stored values the service resolved (a nickname → the user id) | `OrderFilters` |
| `SearchFilters` | The same criteria as the caller asks them, before the service resolves them into `Filters` | `OrderSearchFilters` |
| `Mapper` | MapStruct mapper | `CustomerMapper` |
| `Service` | CDI bean holding business rules | `CustomerService` |
| `Repository` | Panache repository for one aggregate | `CustomerRepository` |
| `Resource` | JAX-RS resource | `CustomerResource` |

**`Result` vs `Summary` vs `Outcome` — litmus test:** remove the status/verdict field; do you still have a meaningful object?
- **Yes** → not a `Result`. Numeric tallies → `Summary`. One item inside a batch → `Outcome`. Plain data → VO / model.
- **No** → `Result` fits: the object exists to deliver a verdict (auth succeeded/failed, cache hit/miss).

### Modern Java Features (Required)

**Baseline: Java 21** — the stack's choice, not the framework's: Quarkus 3.40's own build targets 17, so 17 would run. 21 is pinned in `maven.compiler.release` for pattern matching in `switch` (a preview feature on 17) and because virtual threads only exist there (`concurrency.md`).

- **`var`** for local variables when the type is obvious
- **Records** for immutable data carriers — DTOs, value objects, aggregation results. Never a mutable class with setters. **No Lombok** — a record needs no builder
- **Sealed classes** for restricted hierarchies
- **Pattern matching** in `instanceof` and `switch`
- **Text blocks** for multi-line strings (JSON, JPQL, native SQL)
- **Stream API** for collection processing, over imperative loops
- **`Optional`** for nullable return values, or a parameter whose absence is contractual — never null, and never a field
- **Collection factories**: `List.of()`, `Set.of()`, `Map.of()`

### Enum Naming (Required for all enums)

Every enum carries the `Enum` suffix: `InvoiceStatusEnum`, `PaymentMethodEnum` ✓ — `InvoiceStatus`, `PaymentMethod` ✗. **Variables and parameters never carry it**: `invoiceStatus`, not `invoiceStatusEnum`.

### Enum Convention (Required for all API-facing enums)

Every enum appearing in a Request or Response DTO **must** have:
1. `public final String value` — lowercase snake_case, stored in the database and sent over the wire.
2. `static fromValue(String value)` — case-insensitive lookup, throwing a domain exception with a 400 code (`api.md` → Errors) on no match.
3. A `public static final String <NAME>_VALUE` constant per wire value (`api.md`, for `@Schema` allowable values).

Enums used for UI display may add `public final String displayName`. **Internal-only enums** (never in a DTO) may throw `IllegalArgumentException` from `fromValue` instead.

**No JSON-binding annotations on enums** — DTO fields are `String`, so the serializer never sees an enum type. The mapper is the only place that calls `fromValue()` or reads `.value`.

### DTO and Resource Enum Inputs — Always String

Request/Response DTOs **must never** declare enum-typed fields, and neither may `@QueryParam`, `@PathParam` or `@HeaderParam` parameters. They enter as `String`; the resource converts with `fromValue(...)` before calling the service. Services receive typed models only.

This keeps the HTTP contract aligned with the enum's `value` (`paid`, `draft`) instead of its constant name (`PAID`, `DRAFT`) — and keeps a malformed value a 400 you shaped, with your message, rather than a type-conversion failure the framework shaped.

### Annotation Conventions

The core's rule on annotation arguments applies: `@Schema(description = "x")`, not `@Schema(description = "x", required = false, hidden = false)`.

⚠ **`@Timeout`'s unit defaults to milliseconds**, so `@Timeout(30)` is 30 ms. When you mean seconds, pass the unit — here a non-default argument is the whole point: `@Timeout(value = 30, unit = ChronoUnit.SECONDS)`.

### Code Conventions

- **No inner types** — records, VOs and enums never nested inside another class, including utilities. Each type lives in its own file in the right package (`model/`, `model/vo/`, `util/`). Inner types are invisible to mappers and tests, couple the type to the outer class's lifecycle, and violate SRP.
- **Wrappers, never primitives** — `Boolean`, `Integer`, `Long`, `Double`, never `boolean`/`int`/`long`/`double`: fields of entities, VOs, DTOs and records, enum fields, method parameters and returns. Wrappers carry `null` for unset; read them null-safely (`Boolean.TRUE.equals(x)`, not `if (x)`). In a `@ConfigMapping` interface an unset value is a `Optional<T>` or a `@WithDefault`, not a `null`.
- **Parameters**: max 4 per method; encapsulate more in a record.
- **HTTP verbs**: POST/PUT carry a full payload — absent fields become null. PATCH carries a partial one — only present fields change. These are **two mapper methods**, chosen explicitly by the resource; never one method reading a thread-bound mode flag (it breaks the moment mapping runs on another thread — `concurrency.md`).

### Repository Method Naming

A Panache repository's finders are ordinary methods over `find(...)`, `list(...)` and `count(...)`: the name is **not parsed**, so it carries no query and is free — which is why a convention is needed.

- **One verb per intent**: `find…` for one entity, `list…` for a `List`, plus `count…`, `exists…`, `delete…`. A codebase that does not choose ends up with four spellings of one operation and no way to grep for it.
- **A finder returning `Optional<T>` ends in `Optional`** (`findByEmailOptional`), mirroring Panache's own `findByIdOptional`, so the return shape reads the same at every call site. Drop the suffix only where the name turns awkwardly long, and say so in a comment.
- ⚠ A plain `List<T>` return is only correct when the result is genuinely **input-bounded** — `persistence-<db>.md` says what bounds it, and a criteria query pages instead.
- A repository returns entities or values, never a `PanacheQuery` — except to hand a caller a page.

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
- **Entity mutability carve-out**: a persistence-mapped entity **may** be mutable where its binding needs it to be — **`persistence-<db>.md` says whether this one does**, and whether a setter outside a transaction is a bug or the write itself.

### Static utility vs CDI bean

The core's rule, in Java: no collaborators and no state → `public final` class, private constructor, `static` methods. Injects a collaborator or holds per-instance state → a CDI bean, `@ApplicationScoped` by default (`patterns.md`). ⚠ Static is **un-mockable by design** in Java — wanting to mock one means the logic is not pure and belongs with the bean that owns the I/O.

### Documentation

Javadoc bar + budget: `.agent-kit/common/process/authoring/`. No stack deltas — this is an application, so the default budget applies as written.
