## Design Principles

Read together with `.agent-kit/backend/design-principles.md`, the stack-neutral rules (YAGNI, code smells, failure-path cleanup, idempotency and compensation); this doc keeps what this stack adds, and wins where they differ.

- **SRP in layers**: Resources → HTTP only. Services → business rules only. Mappers → transformation only. Repositories → data access only.
- **Open/Closed**: extend by adding a CDI bean, a mapper or a repository method — never by widening a shared base type or an interceptor to suit one domain.
- **Composition over inheritance**: services compose by injecting other domain services, mappers via `uses`. An abstract base is justified only where the subtypes are genuinely substitutable.
- **DRY**: shared mapping logic → a sub-mapper via `uses`. A query repeated across services → a repository method.
- **YAGNI**: no SPI with one implementation.
- **Depend on the specification, not the server.** Domain code imports no **runtime-vendor** package — `org.jboss.*`, `fish.payara.*`, `com.ibm.ws.*` pin the project to one server and break first on an upgrade. Portable libraries the build declares (SLF4J, MapStruct, the database driver) are not what this forbids. Where a vendor API is genuinely required, isolate it behind an interface the domain owns.
