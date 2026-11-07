## API Endpoints

Base path `/api`; controllers sit at `/api/v1/{entity}`. Multi-word segments are **camelCase**
(`/userFollow`, `/billingAccount`), not kebab-case. JSON both ways.

**Spring MVC, `@RestController`** — this stack is not WebFlux, and a controller returns a value, never a
publisher. It injects services and mappers only, holds no business rule, and never `try/catch`es to shape
a response (`architecture.md`).

Return the DTO type directly and let MVC send 200. Reach for `ResponseEntity` only where the status or
headers vary — 201 with `Location`, 204. A method that returns `ResponseEntity<?>` everywhere hides the
contract from the reader, from the generated client, and from the OpenAPI document.

### Standard CRUD

| Method | Path | Success | Validation group |
|--------|------|---------|------------------|
| POST | `/` | 201 + `Location` | `NewChecks` |
| PUT | `/` | 200 | `UpdateChecks` |
| PATCH | `/` | 200 | `PartialUpdateChecks` |
| GET | `/{id}` | 200, or **404** when absent | — |
| GET | `/` | 200 (paged) | — |
| DELETE | `/{id}` | 204 | — |

Enum-shaped inputs enter as `String` and are converted before the service call — the full rule, and why,
is in `code-style.md`.

### Validation at the boundary

`jakarta.validation.Valid` has an **empty body**, so it cannot name a group. Spring's
`@Validated` takes `Class<?>[]`, and on a controller parameter that array *is* the group set:
`@Validated(NewChecks.class) UserRequest request`. One group per verb, per the table above.

⚠ **No validation annotation on the parameter means no validation at all.** The argument resolver runs
Bean Validation only when the parameter carries `@Valid`, `@Validated`, a meta-annotation resolving to
`@Validated`, or any annotation whose simple name starts with `Valid`. Every constraint on the DTO's own
fields is inert, the request reaches the service unchecked, and nothing warns you.

⚠ **`@Validated` goes on the parameter, never on the controller class** — the opposite of the bean rule in
`patterns.md`, and the reason is real. Spring MVC does its own method validation for controller
parameters and **switches it off for any controller class annotated `@Validated`**, expecting an AOP proxy
to take over. The visible effect: a violation on `@RequestParam @Min(1) int page` stops being a 400
`HandlerMethodValidationException` and becomes a `ConstraintViolationException` thrown by the proxy —
a 500, unless you happened to write a handler for it.

### Errors

**One `@RestControllerAdvice` for the application, and it extends `ResponseEntityExceptionHandler`.**
Bodies are RFC 9457 `ProblemDetail`, written as `application/problem+json` (assert that content type, not
`application/json`). Domain exception → code → status is one mapping in one place (`patterns.md`).

⚠ **Boot's own problem-detail handler is off by default.** It is gated on
`spring.mvc.problemdetails.enabled`, and it backs off as soon as any `ResponseEntityExceptionHandler` bean
exists. Extending it yourself is what makes that property irrelevant — without one of the two, a malformed
body, a wrong method or an unsupported media type returns Boot's `/error` body
(`timestamp`/`status`/`error`/`path`), not your shape, and only integration finds out.

⚠ **The default 400 names no field.** `MethodArgumentNotValidException`'s problem detail is the fixed
string *"Invalid request content."*; the binding result hangs off the exception and never reaches the
body. Override `handleMethodArgumentNotValid` and put the per-field codes in, or every client sees one
opaque 400 for every validation failure.

⚠ **401 and 403 never reach the advice.** The security filter chain writes them with `sendError` before
`DispatcherServlet` is involved, and the container re-dispatches to `/error`. Shaping them takes an
`AuthenticationEntryPoint` and an `AccessDeniedHandler` (`security.md`), not an `@ExceptionHandler`.

⚠ **A catch-all `@ExceptionHandler(Exception.class)` swallows `AccessDeniedException`.** Method security
throws it from *inside* the handler, so the advice resolves it and returns your 500; the filter that would
have translated it to 403 only ever sees what escapes the dispatch. Handle it explicitly, or re-throw.

A 500 body carries a correlation id and nothing else — never a stack trace, an exception class name, or a
message assembled from one.

### Pagination

Every paged endpoint takes the same two query params and returns a `*PageResponse`. Decide the contract
once — 0- or 1-based, total or only `hasNext` — and apply it everywhere; a mixed convention is discovered
by clients, not by tests. A total costs a second count query, so carry it only where the UI shows one.
⚠ Spring Data's paging types stop at the repository (`architecture.md`): the controller takes the two
query params and returns the `*PageResponse`; the service converts.

### Documenting the API

Spring Boot generates no OpenAPI document — the generator is a dependency the project adds, and
`springdoc-openapi` is this stack's pick. Its **3.x** line is the Spring Boot 4 line; 2.x targets Boot 3.

Every endpoint and every DTO field is documented. ⚠ **An enum-backed field documents its own allowed
values or nothing does.** DTO fields are `String` here (`code-style.md`), so the schema has no enum type
to read from and a generated client gets free text. Build the description by concatenating the enum's
`value` constants so it cannot drift — concatenation is also the only form that compiles, since an
annotation attribute must be a compile-time constant and `.formatted(...)` is not one.
