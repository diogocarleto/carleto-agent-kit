---
name: dcr
description: Scaffold a new Data Change Request (DCR) — a one-shot batch script for database migrations, bulk CRUDs, or data corrections. Creates the production-side unit plus its matching runner, following the stack's DCR recipe. Use when asked to write a DCR, one-shot migration, bulk CRUD script, data correction, database fix, or registered DCR runner.
---

Load the DCR rules for this task, in this order.

**1. Always read every `*.md` directly under `.agent-kit/dcr/`** — glob that directory, depth 1 only;
`reference/` is on-demand, named below. These are the framework-neutral invariants that hold on any stack:
what a DCR is, why the meaning of its number differs between stacks, how registration selects batch
execution, which artefact records execution order, and the bar for writing one.

**2. Then, if `.agent-kit/common/conventions/backend/recipes/` exists, read every `*.md` under it** — glob
that directory too — and follow the **new-dcr recipe** (`new-dcr.md`). That is this stack's concrete shape:
naming, placement, the target module and package, the registration mechanism, and the checklist to finish
with. It is the authority on all of it, so this skill repeats none of it.

⚠ **Where the two differ, the stack recipe wins** — it states how this stack expresses an invariant that
`core.md` states in the abstract.

Ask the caller for any input the recipe requires that they did not supply. ⚠ **What the DCR's number means
is one of them, and it is not the same everywhere** — take it from `new-dcr.md`, never from memory or from
another project.

A stack with **no** DCR layer ships no `recipes/` directory. That is expected, not an error: say so plainly
rather than inventing a shape, and use whatever migration mechanism the project actually has. If you are
**introducing** a DCR layer, also read `.agent-kit/dcr/reference/adding-dcr.md` — the design checklist,
deliberately not globbed since almost no task needs it.

## Then do the work

Apply all recipe steps in order and finish with the checklist the recipe asks for.
