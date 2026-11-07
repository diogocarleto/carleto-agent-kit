---
name: backend
description: Load the stack's backend conventions. Use when working on backend code or tests, including entities, value objects, repositories, services, mappers, resources, validators, persistence, or API contracts.
---

Load all backend conventions into context for this task.

Read every `*.md` file directly under `.agent-kit/common/conventions/backend/` — glob that directory and read each file before changing code, **except `persistence-*.md`: of those read only the one matching `frameworks.database`** (rule below — apply it before reading, not after). This is **depth-1 only**: do not recurse into `backend/messaging/` or `backend/recipes/` (loaded by `/messaging`, `/scaffold`, `/dcr`).

**Backend has a neutral layer.** Always read every `*.md` directly under `.agent-kit/backend/` — the language-neutral backend invariants (`core.md` is the code-style kernel), read on every stack, **depth-1 only** (`reference/` is on-demand). Nothing in that directory is a variant, so read all of it. The stack's docs in `.agent-kit/common/conventions/backend/` (read above) **win** where they differ.

**Persistence has two layers.** Always read `.agent-kit/persistence/core.md` — the engine-neutral persistence invariants, read on every stack. Then, from that same directory, only the `persistence-<value>.md` matching `frameworks.database` in `.agent-kit-local/structure.yml` — the database engine's own standard, written neutral of any stack. ⚠ Never glob `.agent-kit/persistence/` whole: `core.md` is the always-read peer, the `persistence-*.md` beside it are a variant family, and reading them all loads several engines' contradictory rules at once. `reference/` is on-demand.

⚠ **`persistence-*.md` are variants of one doc, not peers — in two directories under one key.** The neutral engine standard in `.agent-kit/persistence/` and this stack's own layer in `.agent-kit/common/conventions/backend/` are selected by the same declared value, and **the declared value IS the suffix** (`mysql` → `persistence-mysql.md`). Resolve them **independently**; where the stack doc differs from the neutral one, the stack doc wins. Everything else in either glob, including an unsuffixed `persistence.md`, is an ordinary doc.

- **Undeclared, or no manifest** — read every `persistence-*.md` in **both** directories, say so plainly, and point at `/structure-extract`. Never guess a default.
- **Declared, no matching file** — say that directory ships no persistence rules for that database and carry on; do not read the others instead, and do not substitute the other directory's.

Also read every `*.md` under `.agent-kit/common/process/authoring/` — glob that directory; it sets the budget every Javadoc line you write must clear.

Apply all rules from the loaded documents to the current task. Use neighboring code under the backend `src_globs` / `test_globs` declared in `.agent-kit-local/structure.yml` as the first structural reference. Prefer the narrowest test scope that still covers the changed behavior (`.agent-kit-local/context/build-commands.md`).

Do not ask for confirmation to load these docs. Proceed with the work.
