---
name: frontend
description: Load frontend conventions for the current stack. Use when working on frontend files — components, services, stores/state, types, routes, forms.
---

Load the frontend rules for this task, in this order.

**1. Always read `.agent-kit/frontend/core.md`** — the framework-neutral invariants that hold on any
stack: the service layer as a thin HTTP bridge, mirroring the backend response contract, absent versus
null and the null that must never render as zero, declaring a type at every boundary, one responsibility
per component, a DOM-mutating widget handed a tracked node, how an error reaches the user, and
mobile-first as an ordering rule. **Then, from that same directory, only the `framework-<value>.md`
matching `frameworks.frontend`** in `.agent-kit-local/structure.yml` — the framework's own standard,
written neutral of any stack.

⚠ **Never glob `.agent-kit/frontend/` and read it whole.** `core.md` is the always-read peer; the
`framework-*.md` beside it are a variant family, and reading them all loads several frameworks' rules at
once — most of them wrong here, and contradicting each other. `reference/` is on-demand, named below.

**2. Then read every `*.md` file directly under `.agent-kit/common/conventions/frontend/`** — glob that
directory and read each file. That is this stack's concrete shape, and this skill repeats none of it.

⚠ **Two variant families answer to `frameworks.frontend`, in two directories** — the framework's neutral
standard in `.agent-kit/frontend/` (step 1), and this stack's own layer in
`.agent-kit/common/conventions/frontend/` (step 2). One declared value selects in both, and **the declared
value IS the suffix** (`svelte` → `framework-svelte.md`). Resolve them **independently**: a directory
with no matching file says so and carries on — it never falls back to the other directory, and never to
another framework's file. Everything else in either glob, including an unsuffixed `framework.md`, is an
ordinary doc.

- **Undeclared, or no manifest** — read every `framework-*.md` in **both** directories, say so plainly, and point at `/structure-extract`. Never guess a default.
- **Declared, no matching file** — say that directory ships no standard for that framework and carry on; do not read the others instead.

⚠ **Where the stack doc differs from either neutral doc, the stack doc wins** — it states how this stack
expresses a rule the neutral layer states in the abstract.

A stack with **no** frontend layer ships no `conventions/frontend/` directory at all. That is expected, not
an error: say so plainly rather than inventing house rules, apply step 1's invariants directly, and take
the idiom from the components already in the tree. A framework with no `framework-<value>.md` in
`.agent-kit/frontend/` is the same case one level up — no standard written yet, a gap rather than a verdict
on that framework. If you are **introducing** a frontend layer, also read
`.agent-kit/frontend/reference/adding-frontend.md` — the design checklist, deliberately not globbed since
almost no task needs it.

Also read every `*.md` under `.agent-kit/common/process/authoring/` — glob that directory; it sets the budget every TSDoc/JSDoc line you write must clear.

Apply all rules from the loaded documents to the current task. Use neighboring files under the frontend `src_globs` declared in `.agent-kit-local/structure.yml` as the first structural reference. Do not ask for confirmation — proceed with the work.
