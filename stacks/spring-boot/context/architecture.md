## Architecture

**Spring Boot application, Spring MVC, Spring Data repositories** — layers are the rules in the table below, not base classes to inherit. A project adds no framework of its own on top.

### Modules

<!-- The dependency graph. One line per module, or an ASCII chain showing what depends on what. -->

    <module-a> → <module-b>

| Module | Responsibility |
|--------|----------------|
| `<module>` | <one line — what it owns> |

### Layer rules

| Layer | Does | Must never |
|-------|------|-----------|
| **Controller** (`@RestController`) | HTTP only: bind, validate, convert DTO ↔ model, pick the status | inject a repository; hold a business rule; catch an exception to shape a response |
| **Service** (`@Service`) | business rules, orchestration, its own domain's repository | know Request/Response DTOs; inject another domain's repository |
| **Mapper** (MapStruct) | pure transformation | query, default, validate, or derive anything conditional |
| **Repository** (Spring Data) | the one type that speaks the database's API for one domain | leak a `Specification`, a driver type or a query type beyond itself; let an entity travel past the service that owns its transaction (`persistence-<db>.md`) |

Cross-domain data access goes through the other domain's **service**, never its repository — that boundary is what keeps a domain's invariants in one place.

### Cross-cutting

- ⚠ **Spring's annotations are proxy-driven, so a self-call does nothing.** `@Transactional`, `@Async`, `@Cacheable` and method security take effect only when the method is reached *through an injected reference* — a call on `this` runs un-intercepted, and nothing warns you (`patterns.md`).
- **Authorization is a filter chain plus method security**, not a per-endpoint default. What an endpoint does when no rule matches it is the thing to get right (`security.md`).
- **Errors leave through one `@RestControllerAdvice`** and one body shape (`api.md`).
- **Only *inherited* repository methods carry a transaction** — a derived method you declare gets none, and some bindings carry none at all. The service boundary owns the unit (`persistence-<db>.md`).

> **Always-on Tier-0** — keep it to the **module graph** and the rules that span modules. A layer's own rules belong in `conventions/backend/`; deeper module knowledge (purpose, SPIs, internal flows, gotchas) lives in `.agent-kit-local/modules/<module>/module.md`, written with `/module-extract` and loaded on demand via `/modules` — never eager-loaded. Fill the *Modules* table with `/structure-extract`.
