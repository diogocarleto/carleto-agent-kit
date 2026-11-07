---
name: feature-execute
description: Drive a Ready feature plan through implementation — walk its Execution Plan phases in order, running the kit's per-phase loop (dispatch at the phase's annotated tier, review, fix, test, checkpoint) for each. Use once a feature file is Status Ready or In Progress. To plan a not-yet-Ready feature, use feature-plan.
---

Load these references before executing (this skill drives them, it does not restate them — on conflict, they win):

- every `*.md` under `.agent-kit/common/process/planning/` — glob that directory. `.agent-kit/common/process/planning/execution-loop.md` is the canonical per-phase loop and the Reference's code-anchor lifecycle.
- every `*.md` under `.agent-kit/common/process/dispatch/` — glob it too. `.agent-kit/common/process/dispatch/reference-paste.md` says what ships with each dispatch.
- `.agent-kit/common/process/planning.md` — where plans live, the status vocabulary and the folder lifecycle.
- `.agent-kit/common/process/agent-dispatch.md` — tier system, effort, self-escalation.
- `.agent-kit/decision-addon.manifest.md`, when it exists, and the setting it names (`.agent-kit/common/process/planning/decision-addon.md`); on, also the contract it names. On turns on "Design concerns — the decision add-on" below; otherwise a design concern stops the run as `execution-loop.md` step 2 says.

You are the execution driver for a single feature plan. Run the per-phase loop mechanically and in order so nothing is skipped or reordered. Add no new rules; the rules live in the docs above.

Input:

- Feature slug (required): resolves to `.agent-kit-local/planning/features/<slug>.md`. If omitted, list the Ready / In Progress rows from `ROADMAP.md` and ask which.

Gate (before executing anything):

1. Read the feature file. If `Status` is neither `Ready` nor `In Progress`, stop and say so — `Discovery` is not executable; direct the user to feature-plan.
2. Load its `## Reference` section and any `### Shape` diagrams into context; they cache plan-time discovery for the dispatches. Flag a multi-phase plan that lacks a Reference.
3. Select the next unchecked phase in `## Execution Plan` (top-to-bottom; sequential unless a phase marks tasks parallel).
4. If the phase's slice has no phases, or an empty `Decisions locked`, or a `Deferred` item with no resolving phase, stop: name what is missing and direct the user to feature-plan (`plan-shaping.md` → Ready gate). Never plan the slice here.
5. Run `node .agent-kit/planning/plan-lint.mjs <plan.md>` — again after slice-boundary step 2 and each decision checkpoint. Score every failing not-yet-dispatched phase from its planned facts before going on; a failing dispatched phase doesn't block (`plan-shaping.md` → No backfill).

Slice boundary — before a slice's first phase (including slice 1):

1. Re-verify the slice's `Reads:`, its `## Reference` symbol-map entries and its `Decisions locked` against the current code. Fix drift in the plan; a drifted decision is a decision checkpoint.
2. Promote each `Provisional` phase to full depth (`plan-shaping.md` → Plan depth) and amend the plan. Stamp any missing `Complexity:` and re-score what promotion changed — before dispatch, never after. Re-run the lint (gate step 5).
3. Load the slice's `Conventions:` skills and name them in every implementation and review dispatch.
   - No such line: propose them from the phase files, as feature-plan step 1 does, and load what the user confirms.
   - A phase reaching a layer the line doesn't cover is a decision checkpoint, never a silent load.

Per phase — implement, then run the per-phase loop as the gate. The phase header carries `Tier:` (implementation dispatch), `Reviewer:` (code-review dispatch), and `Effort:` (reasoning depth, falling back to the slice's — pass it on every dispatch per `agent-dispatch.md` → *Effort*; never omit it on a Codex peer).

1. Dispatch implementation at the phase's `Tier`, scoped to its `Reads:` + task checklist; include the tier-gated slice of `## Reference` **and the slice's `### Shape` diagram, ungated by tier**, per `.agent-kit/common/process/dispatch/reference-paste.md`. This is the plan's Implement step; the loop below is the gate that follows — it is not itself part of the per-phase loop.
2. Run `.agent-kit/common/process/planning/execution-loop.md` in its order, dispatching the review at the phase's `Reviewer` tier: code review, apply fixes, re-review, author + run tests (clean, every in-scope module), promote learnings + refresh module memory, checkpoint (commit + tag `<feature>/slice<N>/phase<M>`, no `Co-Authored-By`), advance (one phase-close docs commit: tick the phase checklist and re-stamp every module row the refresh confirmed — `INDEX.md` Verified + every linked footer = the checkpoint SHA; in the repo that owns kit-shipped memory, also promote the changed docs to the kit). Read the step details from that doc; do not restate them here.

Run autonomously through the slice with one short update per phase boundary (plus anything the decision add-on's contract asks it to name); stop only for a design blocker or a decision checkpoint; a design blocker an add-on took stops only while its contract says to wait for the user.

Design concerns — the decision add-on (only when one is on). The one trigger is an entry in the review's `Design concerns` section, or a finding elsewhere that meets its definition (`execution-loop.md` step 2). The add-on's contract says how; this section only drives it.

1. Apply the non-design findings first (`execution-loop.md` step 2).
2. Per concern — coupled ones together — hand it to the add-on as its contract says, with the concern's claim, risk and options as the question, the plan path, the phase diff and the implementation dispatch's hand-back.
3. Follow its result as the contract says: wait for the user's ruling, or dispatch the decision as a fix and continue at re-review — running first any test the contract names.

Decision checkpoint: stop when the next phase is the one a `Deferred` decision names, or a Spike completes. With a decision add-on on, a `Deferred` line pointing at one of its records is resolved as its contract says. Otherwise present the options with their evidence, get the user's ruling and replace the `Deferred` line in `Decisions locked` with it; with the add-on off, a line pointing at one of its records becomes an ordinary locked one (`decision-addon.md`). Then re-score `Complexity:` of the affected not-yet-dispatched phases, then re-run the lint (gate step 5). Resume only then.

Escalation: if a dispatched agent returns a blocker beyond its tier (agent-dispatch.md self-escalation), re-dispatch that unit one tier up with the handoff payload; do not accept a shallow result and do not raise the whole phase's tier.

Slice boundary: update the feature-file header (`Slices:`, `Last updated:`, per-slice status) and the matching `ROADMAP.md` row in the same change. A slice reaching `Done` stops shipping its `### Shape` diagram in dispatch prompts — only the active slice's Shape ships — but the diagram stays in the plan file, never pruned; it may also be promoted into the touched module's memory (`.agent-kit/common/process/planning/execution-loop.md` → code-anchor lifecycle), redrawn from what shipped, never pasted from plan-time intent. When all slices are done — and, with a decision add-on on, nothing its contract says holds `Done` (if something does, stop and name it) — mark the feature `Done`, move its `ROADMAP.md` row to the Done section, and move the plan file to `archive/` (`.agent-kit/planning/README.md` → File Lifecycle — not inlined in AGENTS.md, open it).

Do not: restate the loop rules; run phases out of order; batch phases into one dispatch; skip review or the test gate; skip or defer the module-memory re-stamp — stamp each edited module once its whole row is confirmed, refresh a row that no longer holds first, never stamp unchecked; wait for per-phase approval (design blockers and decision checkpoints excepted); or let an implementer invent design — a fork the plan didn't settle is a decision checkpoint, while additions a review finds are fine. The implementer never settles a design concern — the user or a decision add-on does (`execution-loop.md` step 2).
