## Architecture

**No application framework, and no base classes the project did not write** — what a layer may do is a rule in the table below, not a type it inherits.

⚠ RUNTIME GAP — the Jakarta EE runtime and profile. It decides which specs are on the classpath (MicroProfile Config and OpenAPI are **not** part of Jakarta EE) and how deployment config reaches the app. Fill when the runtime is chosen; do not guess.

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
| **Service** (CDI) | business rules, orchestration, its own domain's repository | know Request/Response DTOs; inject another domain's repository |
| **Mapper** (MapStruct) | pure transformation | query, default, validate, or derive anything conditional |
| **Repository** | the one type that speaks the database's API for one domain | leak a driver, query or result type beyond itself (`persistence-<db>.md` — also: where a write can bypass it) |

Cross-domain data access goes through the other domain's **service**, never its repository — that boundary is what keeps a domain's invariants in one place.

### Cross-cutting

- **Authorization is checked at the resource boundary**, explicitly per method. The platform allows by default, so an unannotated endpoint is public — and whether an *annotated* one is enforced depends on the runtime's JAX-RS wiring (`security.md`).
- **`@Transactional` covers only resources *enlisted* in the JTA transaction** — not whatever the database supports: a `JTA` unit whose datasource nothing enlists rolls back nothing, with no error, on a fully transactional database. Read `persistence-<db>.md` before treating an annotated method as atomic.
- **Errors leave through one `ExceptionMapper`** and one body shape.
- **Concurrency comes from the container** — managed executors only, never a hand-made thread (`concurrency.md`).

> **Always-on Tier-0** — keep it to the **module graph** and the rules that span modules. A layer's own rules belong in `conventions/backend/`; deeper module knowledge (purpose, SPIs, internal flows, gotchas) lives in `.agent-kit-local/modules/<module>/module.md`, written with `/module-extract` and loaded on demand via `/modules` — never eager-loaded. Fill the *Modules* table with `/structure-extract`.
