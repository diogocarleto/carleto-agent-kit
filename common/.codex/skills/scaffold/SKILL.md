---
name: scaffold
description: Scaffold a complete backend domain. Use when asked to create a new entity, domain, repository, service, mapper, resource, resource tests, mapper tests, service tests, or a full domain slice.
---

Load the backend conventions and canonical scaffold recipe before writing code:

- every `*.md` file directly under `.agent-kit/common/conventions/backend/` (**depth-1 only** — the nested `recipes/` is the next bullet), **except `persistence-*.md`: of those read only the one matching `frameworks.database`** (rule below — apply it before reading, not after). The recipe scaffolds an entity, repository, service, DTOs, mapper, resource **and tests**, so code style, design principles, api, testing, security, logging and concurrency all apply to what you write
- every `*.md` under `.agent-kit/common/conventions/backend/recipes/` (then follow the **new-domain recipe**, `new-domain.md`)

- always every `*.md` directly under `.agent-kit/backend/` — the language-neutral backend invariants (`core.md` is the code-style kernel), **depth-1 only** (`reference/` is on-demand), all of it (nothing there is a variant); the stack's backend docs, read above, win where they differ
- always `.agent-kit/persistence/core.md` — the engine-neutral persistence invariants — then, from that same directory, only the `persistence-<value>.md` matching `frameworks.database`. ⚠ Never glob `.agent-kit/persistence/` whole; `reference/` is on-demand

⚠ **`persistence-*.md` are variants of one doc, not peers — in two directories under one key** (the neutral `.agent-kit/persistence/` above and the stack's depth-1 set) — and the scaffold writes a repository, so the wrong one is wrong code. Read only the variant matching `frameworks.database` in `.agent-kit-local/structure.yml` in each; the declared value IS the suffix (`mysql` → `persistence-mysql.md`). Resolve the two directories **independently**; the stack's wins where they differ. **Undeclared, or no manifest** — read every variant in both, say so plainly, and point at `/structure-extract`; never guess a default. **Declared, no matching file** — say that directory ships no persistence rules for that database and carry on; never substitute the other directory's.

If the caller did not provide the domain name, fields, relationships, or target Maven module, ask for the missing inputs before writing code.

Follow the **new-domain recipe** (`.agent-kit/common/conventions/backend/recipes/new-domain.md`) end to end. Replace every `<DomainName>` placeholder with the supplied PascalCase domain name. Apply all production and test steps in order, then finish with the checklist the recipe asks for.
