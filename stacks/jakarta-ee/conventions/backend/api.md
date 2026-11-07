## API Endpoints

One `Application` subclass declares the base path (`@ApplicationPath("/api")`); resources sit at `/api/v1/{entity}`. Media type is `APPLICATION_JSON` on both sides. Multi-word path segments use **camelCase** (`/userFollow`, `/billingAccount`), not kebab-case.

A resource is `@ApplicationScoped`, injects **services and mappers only — never a repository**, and holds no business rule. It converts (DTO ↔ model), picks the status, and delegates.

### Standard CRUD

| Method | Path | Success | Validation group |
|--------|------|---------|------------------|
| POST | `/` | 201 + `Location` | `NewChecks` |
| PUT | `/` | 200 | `UpdateChecks` |
| PATCH | `/` | 200 | `PartialUpdateChecks` |
| GET | `/{id}` | 200, or **404** when absent | — |
| GET | `/` | 200 (paged) | — |
| DELETE | `/{id}` | 204 | — |

Return the DTO type directly and let the container set 200; reach for `Response` only where the status or headers vary (201 + `Location`, 204). A method returning `Response` everywhere hides the contract from the reader and from generated clients.

### Validation Groups

- `NewChecks` → POST: every required field validated.
- `UpdateChecks` → PUT: every field validated, id required.
- `PartialUpdateChecks` → PATCH: only non-null fields validated.

Applied on the resource method parameter: `@Valid @ConvertGroup(from = Default.class, to = NewChecks.class) UserRequest request`.

⚠ **Without `@Valid`, nothing cascades into the DTO.** Constraints written *directly on the parameter* still run — JAX-RS validates method parameters — but every constraint on the DTO's own fields is inert and the request reaches the service unchecked. There is no warning; the endpoint simply accepts any body shape.

### Enum values on the wire

Requests and responses carry the enum's `value` (`audio`, `draft`), never the constant name (`AUDIO`, `DRAFT`). Enum-like inputs enter the resource as `String` and are converted with `fromValue(...)` before the service call — full rule in `code-style.md`.

### Pagination

Every paged endpoint takes the same two query params and returns a `*PageResponse`. Decide the page contract once — 0- or 1-based, and whether it carries a total or only `hasNext` — and apply it everywhere: a mixed convention is discovered by clients, not by tests. A total costs a second count query, so carry it only where the UI shows one.

### Errors

Every error body has one shape and comes from an `ExceptionMapper` — never from a `catch` in a resource method. Shape, codes and status mapping: `patterns.md`.

### Documenting the API

Every DTO field and every endpoint is documented where the runtime's OpenAPI support lives, and a field backed by an enum lists its allowed values — a generated client is only as correct as the schema.

⚠ RUNTIME GAP — how OpenAPI is produced (MicroProfile OpenAPI is **not** part of Jakarta EE; some runtimes ship it, others need a plugin or nothing at all). Fill when the runtime is chosen; do not guess.
