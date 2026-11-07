---
name: fullstack
description: Load all conventions (backend + frontend). Use for cross-cutting work, scaffolding, or when you need both backend and frontend rules in one pass.
---

Load all project conventions into context for this task, in this order.

**1. Always read `.agent-kit/frontend/core.md`** — the framework-neutral frontend invariants, read on
every stack, including one that ships no frontend layer at all. **Then, from that same directory, only the
`framework-<value>.md` matching `frameworks.frontend`** in `.agent-kit-local/structure.yml` — the
framework's own standard, written neutral of any stack. ⚠ Never glob that directory whole: `core.md` is
the always-read peer, the `framework-*.md` beside it are a variant family, and reading them all loads
several frameworks' contradictory rules at once. `reference/` is on-demand.

**2. Always read every `*.md` directly under `.agent-kit/backend/`** — the language-neutral backend invariants (`core.md` is the code-style kernel), read on every stack, **depth-1 only** (`reference/` is on-demand). Nothing in that directory is a variant, so read all of it. The stack's backend docs (step 4) **win** where they differ.

**3. Always read `.agent-kit/persistence/core.md`** — the engine-neutral persistence invariants, read on every stack. **Then, from that same directory, only the `persistence-<value>.md` matching `frameworks.database`** — the database engine's own standard, written neutral of any stack. ⚠ Never glob that directory whole, for the same reason as step 1. `reference/` is on-demand.

**4. Then read every `*.md` file directly under both `.agent-kit/common/conventions/backend/`** (**depth-1** — not the `messaging/`/`recipes/` companion subdirs) **and `.agent-kit/common/conventions/frontend/`**. Glob those directories and read each file, **except the variant files — `persistence-*.md` and `framework-*.md` — of which read only the one matching the declared value** (table below — apply it before reading, not after).

**Four variant families, two keys — and each key selects in two directories.** A `<concern>-<value>.md` set is one doc in several versions, not several peers: read only the variant whose suffix matches the value declared in `.agent-kit-local/structure.yml`, and the declared value IS the suffix.

| Family | Declared by | Where |
|---|---|---|
| `framework-*.md` ← the framework's neutral standard | `frameworks.frontend` | `.agent-kit/frontend/` (step 1) |
| `framework-*.md` ← this stack's own layer | `frameworks.frontend` | `conventions/frontend/` (step 4) |
| `persistence-*.md` ← the engine's neutral standard | `frameworks.database` | `.agent-kit/persistence/` (step 3) |
| `persistence-*.md` ← this stack's own layer | `frameworks.database` | `conventions/backend/` (step 4) |

⚠ Each key's two families are **two directories, not one glob**: the same declared value selects in each, they are resolved separately, and the stack's (step 4) **wins** where the two differ. Everything else in those globs, including an unsuffixed `persistence.md` or `framework.md`, is an ordinary doc. Resolve each family **independently** — a project may declare one key and not the other:

- **Undeclared, or no manifest** — read every variant of that family, say so plainly, and point at `/structure-extract`. Never guess a default.
- **Declared, no matching file** — say that directory ships none for that value and carry on; do not read the family's other variants instead, and do not substitute the other directory's.

Also read every `*.md` under `.agent-kit/common/process/authoring/` — glob that directory; it sets the budget every Javadoc/TSDoc line you write must clear.

Apply all rules from the loaded documents to the current task. Use neighboring backend and frontend code as the first structural reference. Prefer the narrowest backend and frontend test scopes that still cover the changed behavior (`.agent-kit-local/context/build-commands.md`). Do not ask for confirmation — proceed with the work.
