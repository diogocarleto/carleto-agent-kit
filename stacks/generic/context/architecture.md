## Architecture

> **TEMPLATE — replace this file.** It is seeded once and then project-owned; the kit never
> overwrites it. Fastest path: run `/structure-extract` to generate `.agent-kit-local/structure.yml`,
> then write this file from what it found. Keep it to the module *graph* and the rules that span
> modules — per-module detail belongs in module memory (`/module-extract`), not here.

This file is **always-on Tier-0 context**: it loads in every session, on every harness. Keep it short.

### Modules

<!-- The dependency graph. One line per module, or an ASCII chain showing what depends on what. -->

    <module-a> → <module-b> → <module-c>

| Module | Responsibility |
|--------|----------------|
| `<module>` | <one line — what it owns> |

### Layers

<!-- What each layer may and may not do. Delete rows that do not apply to this project. -->

| Layer | Role | Must not |
|-------|------|----------|
| <entry / api> | <handles transport only> | <hold business rules> |
| <service / domain> | <business rules> | <know about transport> |
| <persistence> | <data access> | <hold business rules> |

### Cross-cutting rules

<!-- Only rules that span modules and would be expensive to rediscover. -->

- <e.g. which module owns authentication, where the transaction boundary sits>
