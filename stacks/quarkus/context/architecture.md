## Architecture

**Quarkus application, Quarkus REST, CDI (ArC), Panache repositories** — layers are the rules in the table below, not base classes to inherit. A project adds no framework of its own on top.

### Modules

<!-- The dependency graph. One line per module, or an ASCII chain showing what depends on what. -->

    <module-a> → <module-b>

| Module | Responsibility |
|--------|----------------|
| `<module>` | <one line — what it owns> |

### Layer rules

| Layer | Does | Must never |
|-------|------|-----------|
| **Resource** (JAX-RS) | HTTP only: bind, validate, convert DTO ↔ model, pick the status | inject a repository; hold a business rule; catch an exception to shape a response |
| **Service** (CDI bean) | business rules, orchestration, its own domain's repository | know Request/Response DTOs; inject another domain's repository |
| **Mapper** (MapStruct) | pure transformation | query, default, validate, or derive anything conditional |
| **Repository** (Panache) | the one type that speaks the database's API for one domain | leak a query type beyond itself (a `PanacheQuery` only for paging); let an entity travel past the service that owns its transaction (`persistence-<db>.md`) |

Cross-domain data access goes through the other domain's **service**, never its repository — that boundary is what keeps a domain's invariants in one place.

### Cross-cutting

- **Entities are plain classes; a repository is a separate bean** (the repository pattern). One repository per aggregate, injected into the service that owns it.
- ⚠ **Interceptors run through the container's generated subclass, so only a non-private method is intercepted.** `@Transactional`, `@Retry`, `@RolesAllowed` on a `private` method fail the build by default (`quarkus.arc.fail-on-intercepted-private-method`); set it false and the annotation is only logged and ignored (`patterns.md`).
- **Authorization is annotations on resources and services, denied by default.** Authentication is the project's own choice (`security.md`).
- **Errors leave through one `ExceptionMapper` and one body shape** (`api.md`).
- **Blocking code on virtual threads** — imperative services and repositories; no reactive types (`concurrency.md`).

> **Always-on Tier-0** — keep it to the **module graph** and the rules that span modules. A layer's own rules belong in `conventions/backend/`; deeper module knowledge (purpose, SPIs, internal flows, gotchas) lives in `.agent-kit-local/modules/<module>/module.md`, written with `/module-extract` and loaded on demand via `/modules` — never eager-loaded. Fill the *Modules* table with `/structure-extract`.
