## Design Principles

Read together with `.agent-kit/backend/design-principles.md`, the stack-neutral rules (YAGNI, code smells, failure-path cleanup, idempotency and compensation); this doc keeps what this stack adds, and wins where they differ.

- **SRP in layers**: Resources → HTTP only. Services → business rules only. Mappers → transformation only. Repositories → data access only.
- **Open/Closed**: extend by adding a bean, never by editing a shared one. A cross-cutting concern arrives as an interceptor or a new implementation, not as a branch inside an existing service.
- **Composition over inheritance**: services compose by injecting other services, mappers compose via `uses`. A CDI bean has no framework base class to extend, and Panache's repository interface is implemented, not subclassed — an abstract `BaseService` invented to share three methods is the smell, not the pattern.
- **DRY**: shared transformation → a sub-mapper via `uses`. Shared query → a method on the repository that owns the aggregate, never the same finder in two repositories.
- **YAGNI**: no interface for a single implementation, no profile for an environment that does not exist.
