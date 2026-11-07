---
name: migrate
description: Migrate legacy code onto this stack's conventions. Use when asked to migrate, port, modernize, or replatform an existing module, service, or codebase onto this project's stack.
---

Load the migration rules for this task, in this order.

1. Always read every `*.md` directly under `.agent-kit/migration/` — glob that directory, depth 1 only;
   `reference/` is on-demand, named below. These are the framework-neutral invariants that hold on any
   stack: how to zone the legacy tree by risk before editing, why characterization tests must pin current
   behavior before anything changes, why a unit must finish or revert rather than leave old and new paths
   both live, why one unit is piloted into a playbook before any fan-out and batches stay gated, and what
   counts as proof of equivalence.
2. Then, if `.agent-kit/common/conventions/backend/migration/` exists, read every `*.md` under it — glob
   that directory too. That is this stack's concrete shape for migrating code onto it, and it wins where
   the two differ.

⚠ A stack shipping no migration layer is expected, not an error. Say so plainly rather than
inventing a shape, and apply the invariants above directly. If you are introducing a migration layer, also
read `.agent-kit/migration/reference/adding-migration.md` — the design checklist, deliberately not globbed
since almost no task needs it.

`/migrate` never models the legacy source — ask the caller where it lives if they did not say, and read it
directly. Load the target's own layer conventions the normal way (`/backend`, `/frontend`, …); "idiomatic"
means those conventions, and this skill does not restate them.

Zone the legacy tree by risk, write characterization tests for the unit in scope, migrate that one unit,
and prove equivalence before moving to the next.
