---
name: feature-execute
description: Drive a Ready feature plan through implementation — walk its Execution Plan phases in order, running the kit's per-phase loop (dispatch at the phase's annotated tier → review → fix → test → checkpoint) for each. Use once a feature file is Status Ready/In Progress to build it. To plan a not-yet-Ready feature, use /feature-plan.
---

**Read these first — they carry the rules this skill drives, and they are NOT always-on:**

- every `*.md` under `.agent-kit/common/process/planning/` — glob that directory. `.agent-kit/common/process/planning/execution-loop.md` is the canonical per-phase loop and the Reference's code-anchor lifecycle.
- every `*.md` under `.agent-kit/common/process/dispatch/` — glob it too. `.agent-kit/common/process/dispatch/reference-paste.md` says what ships with each dispatch.
- `.agent-kit/decision-addon.manifest.md`, when it exists, and the setting it names (`.agent-kit/common/process/planning/decision-addon.md`); on, also the contract it names. On turns on *Design concerns — the decision add-on* below; otherwise a design concern stops the run as `execution-loop.md` step 2 says.

(`planning.md` and `agent-dispatch.md` themselves are already loaded via the always-on CLAUDE.md imports — don't re-read them. If any step here and those docs ever disagree, **the docs win**.)

You are the **execution driver** for a single feature plan. Your job is to run the canonical per-phase loop mechanically and in order, so nothing is skipped or reordered — the reason this skill exists is to keep execution on-rails (especially under a cheaper orchestrator) rather than trusting free recall of the loop. You add **no new rules**: they live in the two companion dirs above, plus `agent-dispatch.md`'s tier system.

## Input

- **Feature slug** (required): resolves to `.agent-kit-local/planning/features/<slug>.md`. If omitted, list the `Ready` / `In Progress` rows from `ROADMAP.md` and ask which.

## Gate — before executing anything

1. Read the feature file. If `Status` is neither `Ready` nor `In Progress`, **stop** and say so — `Discovery` isn't executable; send the user to `/feature-plan` to clear the `Discovery → Ready` gate.
2. Load its `## Reference` section and any `### Shape` diagrams into working context — they cache plan-time discovery for the phase dispatches. A multi-phase plan with no `## Reference` is under-specified; flag it before dispatching.
3. Pick the **next unchecked phase** in `## Execution Plan` (top-to-bottom; phases are sequential unless the phase marks tasks `‖`).
4. If the phase's slice has **no phases**, or an empty `Decisions locked`, or a `Deferred` item with no resolving phase, **stop**: name what is missing and send the user to `/feature-plan` (`plan-shaping.md` → Ready gate). Never plan the slice here.
5. Run `node .agent-kit/planning/plan-lint.mjs <plan.md>` — again after slice-boundary step 2 and each decision checkpoint. Score every failing not-yet-dispatched phase from its planned facts before going on; a failing dispatched phase doesn't block (`plan-shaping.md` → No backfill).

## Slice boundary — before a slice's first phase (including slice 1)

1. **Re-verify** the slice's `Reads:`, its `## Reference` symbol-map entries and its `Decisions locked` against the current code. Fix drift in the plan; a drifted decision is a decision checkpoint.
2. **Promote** each `Provisional` phase to full depth (`plan-shaping.md` → Plan depth) and amend the plan. Stamp any missing `Complexity:` and re-score what promotion changed — before dispatch, never after. Re-run the lint (gate step 5).
3. **Load the slice's `Conventions:`** skills, and name them in every implementation and review dispatch so those agents load them too.
   - The slice has no such line (an older plan): propose the skills from the phase files, as `/feature-plan` step 1 does, and load only what the user confirms.
   - A phase whose files reach a layer that line doesn't cover is a decision checkpoint: propose the extra skill, never load it silently.

## Per phase — implement, then run the per-phase loop as the gate

Each phase is **implement, then gate**. The phase header carries the dispatch settings you need:

- `Tier:` — model tier for the **implementation** dispatch.
- `Reviewer:` — model tier for the **code-review** dispatch (the first step of the gate).
- `Effort:` — reasoning depth, falling back to the slice's. Pass it on every dispatch per `agent-dispatch.md` → *Effort* — never omit it on a Codex peer.

1. **Dispatch implementation** — one agent at the phase's `Tier` and `Effort`, scoped to the phase's `Reads:` + task checklist; include the tier-gated slice of `## Reference` **and the slice's `### Shape` diagram, ungated by tier**, per `.agent-kit/common/process/dispatch/reference-paste.md`. (This is the plan's *Implement* step; the loop below is the gate that follows it — it is **not** part of the per-phase loop.)
2. **Run `.agent-kit/common/process/planning/execution-loop.md` in its order**, dispatching the review at the phase's `Reviewer` tier: code review → apply fixes → re-review → author + run tests → promote learnings & refresh module memory → checkpoint (commit + tag `<feature>/slice<N>/phase<M>`) → advance (one phase-close docs commit: tick the phase checklist **and re-stamp every module row the refresh confirmed** — `INDEX.md` Verified + every linked footer = the checkpoint SHA; in the repo that owns kit-shipped memory, also promote the changed docs to the kit). **Read the step details from that doc; don't re-derive them here** — the skill's job is to drive them in order at the annotated tiers, not to restate them.

Run autonomously through the slice — one short update at each phase boundary (what shipped, what's next, plus anything the decision add-on's contract asks it to name), no per-phase approval. Stop only for a design blocker or a decision checkpoint; a design blocker an add-on took stops only while its contract says to wait for the user.

## Design concerns — the decision add-on (only when one is on)

The one trigger is an entry in the review's `Design concerns` section, or a finding elsewhere that meets its definition (`execution-loop.md` step 2). The add-on's contract says how; this section only drives it.

1. Apply the non-design findings first (`execution-loop.md` step 2).
2. Per concern — coupled ones together — hand it to the add-on as its contract says, with the concern's claim, risk and options as the question, the plan path, the phase diff and the implementation dispatch's hand-back.
3. Follow its result as the contract says: wait for the user's ruling, or dispatch the decision as a fix and continue at re-review — running first any test the contract names.

## Decision checkpoint

Stop when the next phase is the one a `Deferred` decision names, or a Spike completes. With a decision add-on on, a `Deferred` line pointing at one of its records is resolved as its contract says. Otherwise present the options with their evidence, get the user's ruling and replace the `Deferred` line in `Decisions locked` with it; with the add-on off, a line pointing at one of its records becomes an ordinary locked one (`decision-addon.md`). Then re-score `Complexity:` of the affected not-yet-dispatched phases, then re-run the lint (gate step 5). Resume only then.

## Escalation — the cheap-orchestrator safety net

If a dispatched agent hands back a blocker beyond its tier (`agent-dispatch.md` → "Self-escalation"), re-dispatch **that unit** one tier up (typically `opus`) with the handoff payload as input. Never accept a shallow result, and never raise the whole phase's tier — escalate the unit, not the phase.

## Slice + roadmap bookkeeping

At a **slice boundary**, update the feature-file header (`Slices:`, `Last updated:`, per-slice status) and the matching `ROADMAP.md` row in the same change (`.agent-kit/planning/README.md` → Status Vocabulary — not in Tier-0, open it). A slice reaching `Done` stops shipping its `### Shape` diagram in dispatch prompts — only the *active* slice's Shape ships — but the diagram itself stays in the plan file, never pruned; it may also be promoted into the touched module's memory (`.agent-kit/common/process/planning/execution-loop.md` → code-anchor lifecycle), redrawn from what shipped, never pasted from plan-time intent. Flip a slice's status when its last Test Plan bullet is checked; when all slices are `Done` — and, with a decision add-on on, nothing its contract says holds `Done` (if something does, stop and name it) — mark the feature `Done`, move its `ROADMAP.md` row to the Done section, and move the plan file to `archive/` (`.agent-kit/planning/README.md` → File Lifecycle: `features/` = live, `archive/` = terminal).

## Don't

- Don't restate or reinterpret the loop rules — read them from `.agent-kit/common/process/planning/execution-loop.md`; on conflict, that doc wins.
- Don't run phases out of order, or batch multiple phases into one dispatch.
- Don't skip the review or the test gate to "save time."
- Don't skip or defer the module-memory re-stamp — every phase that edited a documented module re-stamps it in its phase-close commit, once the whole row is confirmed; a row that no longer holds is refreshed first, never stamped unchecked. A skipped stamp is how memory drifts; an unchecked one is how it lies.
- Don't wait for per-phase approval — the plan + this loop are the signal (design blockers and decision checkpoints excepted).
- Don't let an implementer invent design. A fork the plan didn't settle is a decision checkpoint; additions a review finds are fine. A design concern is settled by the user or a decision add-on (`execution-loop.md` step 2), never by the implementer.
