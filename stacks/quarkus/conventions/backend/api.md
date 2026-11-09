## API Endpoints

Base path `/api` through `quarkus.rest.path=/api`; resources sit at `/api/v1/{entity}`. Multi-word segments are **camelCase** (`/purchaseOrder`, `/customerAddress`), not kebab-case. JSON both ways.

⚠ **Declare the base path once.** An `@ApplicationPath` on any `Application` class wins over `quarkus.rest.path` without a warning, so a second declaration leaves one of them dead.

**Quarkus REST, imperative.** A resource returns a value, never a `Uni`/`Multi` (`concurrency.md`), injects services and mappers only, holds no business rule, and never `try/catch`es to shape a response (`architecture.md`). `@RunOnVirtualThread` goes on the class (`concurrency.md`). ⚠ A `@Path` class is a `@Singleton` by default: no request state in a field.

Return the DTO type directly and let Quarkus send 200. Where the status or headers vary (201 with `Location`) return `RestResponse<T>`, not `Response`: the OpenAPI scanner reads `T` from the former, while the latter hides the body type from the document and from generated clients.

### Standard CRUD

| Method | Path | Success | Validation group |
|--------|------|---------|------------------|
| POST | `/` | 201 + `Location` | `NewChecks` |
| PUT | `/` | 200 | `UpdateChecks` |
| PATCH | `/` | 200 | `PartialUpdateChecks` |
| GET | `/{id}` | 200, or **404** when absent | — |
| GET | `/` | 200 (a `*PageResponse`) | — |
| DELETE | `/{id}` | 204 | — |

Enum-shaped inputs enter as `String` and are converted before the service call — the rule and why are in `code-style.md`.

**Absent is 404, never `null`.** ⚠ A method that returns `null` is answered **204**: Quarkus REST turns a null result into no content, whatever return type the method declares (a `@ResponseStatus` overrides the 204). So `service.find(id).map(mapper::toResponse).orElse(null)` is a silent 204. The service throws a not-found domain exception and the `ExceptionMapper` (below) answers 404.

### Custom actions

- **An action with a request body carries the target's id in the body**, as `PUT /` does: `POST /order/cancel {orderId, reason}`, never `POST /order/{id}/cancel {reason}`. An action with no body keeps the id in the path: `POST /order/{id}/recalculate`, `GET /order/{id}/lines`, `DELETE /order/{id}/line/{lineId}`.
- An action that finds nothing follows the CRUD rule: 404, never `null`.

### Pagination

Every paged endpoint takes the same two query params and returns a `*PageResponse`. Decide the contract once — 0- or 1-based, total or only `hasNext` — and apply it everywhere. A total costs a second count query, so carry it only where the UI shows one. A `PanacheQuery` never reaches the resource: the resource takes the two query params and returns the `*PageResponse`, and the service converts (`architecture.md`).

### Validation at the boundary

Applied on the resource parameter: `@Valid @ConvertGroup(from = Default.class, to = NewChecks.class) OrderRequest request`.

- `NewChecks` → POST: every required field validated.
- `UpdateChecks` → PUT: every field validated, id required.
- `PartialUpdateChecks` → PATCH: only non-null fields validated.

⚠ **Without `@Valid`, nothing cascades into the DTO.** Every constraint on its own fields is inert, the request reaches the service unchecked, and nothing warns you.

⚠ **Only violations on an endpoint's parameters are a 400.** Quarkus answers them with its own body (`title`, `status`, `violations`), which is not RFC 9457 — map it (below). A violation on a return value, or inside a service method, is an internal error: a 500.

### Errors

**One body shape, produced by `ExceptionMapper` classes — never by a `catch` in a resource.** The body is an RFC 9457 problem, written as `application/problem+json` (assert that content type, not `application/json`): `type`, `title`, `status`, `detail`, `instance`, plus a stable machine-readable `code` and, for validation, the per-field `errors`. A domain exception carries its code, and one place maps code → status (`patterns.md`). `fromValue`'s failure is one of those domain exceptions, carrying a 400 code, so the mapper answers it as a 400 problem.

Why `ExceptionMapper` and not `@ServerExceptionMapper`: the Quarkus annotation declared in a resource class applies to that class only and is consulted **before** every global mapper, so one resource can quietly answer in another shape. The JAX-RS interface is one global class per concern. If you do use the annotation, keep it out of resource classes.

How Quarkus picks a mapper decides what you must write:

- **The exact exception class is tried first, then each superclass.** Your mapper on a class Quarkus also maps (the JSON mismatch, the security exceptions) replaces the built-in.
- ⚠ **A catch-all `ExceptionMapper<Throwable>` is offered every `WebApplicationException` with no entity too** (one carrying an entity is sent as-is and no mapper sees it) — an unmatched path, a wrong method, an unsupported media type — and must keep that exception's own status, or each of them becomes a 500. Quarkus's security exceptions are not taken over: they have mappers on their exact type.
- ⚠ **Two framework bodies need a mapper of your own, or clients see a second format.** Validation: map `ConstraintViolationException` — a `ResteasyReactiveViolationException` with violations on parameters is a 400, anything else a 500. A *mistyped* JSON body (a string where a number goes): map `MismatchedInputException`; Quarkus answers 400 with an **empty** body outside dev and test. A *malformed* one arrives as a bodiless `WebApplicationException` 400, which the catch-all must answer as a 400 problem.
- ⚠ **A mapped exception is not logged by Quarkus.** Only an unmapped one is, and an unmapped `WebApplicationException` only at DEBUG. The mapper logs the unexpected ones, once (`logging.md`); a mapper for expected 4xx stays quiet.
- A 500 body carries a correlation id and nothing else — never a stack trace, an exception class name, or a message assembled from one.
- **401 and 403 stay Quarkus's.** They carry no problem body, and the 401 mapper builds the authentication challenge, so replacing it drops the challenge headers.
- ⚠ **An exception from a REST client call reaches your mappers too** (`patterns.md` → REST client). Do not let a catch-all copy its status; tell it apart by `ResteasyReactiveClientProblem`.

### Documenting the API

`quarkus-smallrye-openapi` generates the document; the project annotates what it cannot infer.

Every endpoint carries `@Operation` and an `@APIResponse` per status, the errors with the problem record's schema under `application/problem+json`; every DTO field carries `@Schema`.

⚠ **An enum-backed field documents its own allowed values or nothing does.** DTO fields are `String` here (`code-style.md`), so the schema has no enum type to read from and a generated client gets free text. Build the description by concatenating the enum's wire-value constants so it cannot drift:

```java
public record InvoiceResponse(
        @Schema(description = "invoice status — allowed values: " + InvoiceStatusEnum.DRAFT_VALUE + ", " + InvoiceStatusEnum.PAID_VALUE,
                example = InvoiceStatusEnum.PAID_VALUE)
        String status) {
}
```

- Concatenation is also the only form that compiles: an annotation attribute must be a compile-time constant, and `.formatted(...)` is not one. A description spanning more than one line is built into a `static final String` in the record.
- Each wire value is a `public static final String` constant on the enum, which its constructor takes by **qualified** name — `DRAFT(InvoiceStatusEnum.DRAFT_VALUE)`. The simple name is an illegal forward reference.
- ⚠ **A `List<T>` field with `@Schema(implementation = T.class)` needs `type = SchemaType.ARRAY`.** Once `implementation` is set, the scanner takes it as the field's type and never reads the collection, so the field is documented as one `T`. Without `implementation`, it reads the array from the generic type.
