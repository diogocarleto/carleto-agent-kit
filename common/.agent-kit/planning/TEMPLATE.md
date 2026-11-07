# Feature: <Title>

Status: Discovery | Ready | In Progress | Blocked | Done | Postponed
Priority: P1 | P2 | P3
Slices: 1 of N
Depends on: [Feature X](feature-x.md) | None
Branch: feature/<name>
Last updated: YYYY-MM-DD

> **Writing this file:** budget + prune-on-completion rules live in
> `.agent-kit/common/process/authoring/` → Plan files. **Strip every `>` tip in this template from the
> plan you produce** — including this one. They guide the author; they are not content.

---

## Goal

What this feature does and why it matters to the user.

## Why Now

Why this is being built in this cycle (user request, dependency, strategic priority).

## Scope (V1)

- What is included
- Keep it tight — list explicit inclusions

## Out of Scope (V1)

- What is explicitly excluded
- Candidate follow-ups go here, not in the plan

## Acceptance Criteria

User or admin observable outcomes that define "done". These are not implementation tasks.

> Each criterion names the phase(s) that deliver it — the `Ready` gate's coverage check.

- [ ] Criterion 1 — what the user can do or see → Slice 1 · Phase 2
- [ ] Criterion 2 → Slice 2 · Phase 1

---

## Backend Design

### Shape

> One diagram when the slice earns it — 2+ modules · ~5+ new types · 3+ layers · an ordering /
> error-channel / compensation decision · a lifecycle change. Triggers, contracts, and lifecycle:
> `.agent-kit/planning/DIAGRAMS.md`; picker, class-diagram rules, and house style:
> `.agent-kit/common/process/diagrams/diagrams.md`. Omit this section when the feature
> doesn't earn one. It is the review surface for the `Discovery → Ready` gate, and ships to every
> implementer — so it may also carry the exact signatures the drawing commits to.

### Affected Existing Code

| File | Change needed |
|------|---------------|
| `path/to/Service.java` | description |

### New Entities / Models

- `EntityName` — fields: `id`, `x`, `y`; unique index: `fieldA + fieldB`

### Business Rules

- Rule 1
- Rule 2

### Endpoints

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| POST | `/api/v1/...` | LOGGED_USER | |

---

## Frontend Design

### Shape

> Same rule as Backend Design. Screen/route flow → `flowchart`; see `.agent-kit/planning/DIAGRAMS.md`.

### Affected Existing Code

| File | Change needed |
|------|---------------|
| `path/to/Component.svelte` | description |

### New Files

| Layer | File | Notes |
|-------|------|-------|
| Type | `lib/types/x/xResponse.ts` | |
| Service | `services/xService.ts` | |
| Component | `routes/XDetail.svelte` | |

### UX Notes

- Describe key interactions, empty states, error states, loading behavior

---

## Test Plan

> Required. Behaviors each tier must prove — not test method names.
> Gate: `Discovery → Ready` requires this approved. `Done` requires every bullet checked.
> See the stack's testing conventions under `.agent-kit/common/conventions/backend/` (loaded via `/backend`) — what each layer must prove, and which tests to skip.
> Multi-slice features: put per-slice Test Plans inside the slice sections below and omit this top-level one.
>
> Authoring tips:
> - One bullet per distinct behavior. Not "test login" — "login with valid credentials returns a session; wrong password returns 401."
> - Add only the tiers this feature touches (Service / Integration / Resource / Expensive). Omit the rest.
> - Don't re-list baseline cases from `testing.md` unless the feature deviates.
> - Optional `### Not tested (and why)` subsection — only for surprising skips (e.g., "skipping expensive tests — already covered under ArtistDiscovery"). Skip it if no surprising skips.

### Service (`*ServiceTests`, mocked)

- [ ] Behavior 1

### Resource (`*ResourceTests`, full E2E)

- [ ] POST /api/v1/... — 200 happy, 400 validation, 401 anon, 204 not found (add 403 only if role/ownership restricted)

---

## Key Decisions

- Decision made during planning or implementation and why

## Risks & Open Questions

- **Risk**: description and potential impact
- **Open**: unanswered question that may affect scope or approach

---

## Current State

> Only for `In Progress` features. Remove this section when the feature is `Done`.

What has shipped so far. Helps any reader understand the delta between current and target.

---

## Slices

> Each slice has its own execution plan below. A single-slice feature keeps one slice header — it carries Tier, Effort and Decisions locked.
> Slices stay in this file. If a feature needs many separate slice files, it may be too large — consider splitting into independent features.

> **Plan every slice before `Ready`** — depth follows volatility (stable → full depth, volatile → Provisional skeleton); the rules and the `Ready` gate live in `.agent-kit/common/process/planning/plan-shaping.md` → Plan depth. Lock the design forks with the user *in planning, not mid-code*: a fork discovered mid-dispatch forces rework of already-"done" code.

### Slice 1 — <Name> [Status]

Tier: `haiku` | `sonnet` | `opus` — expected model tier for this slice's implementation agents. Per-phase tier in the Execution Plan overrides; phases with no tier inherit this.
Effort: `low` | `medium` | `high` — reasoning depth, independent of Tier (**Tier picks *who*, Effort *how hard they think***): scaffolding → `low`, normal implementation → `medium`, subtle or design-sensitive → `high`. Per-phase Effort overrides. `xhigh` is escalation-only. Applied per `agent-dispatch.md` → *Effort*.
Confidence: `high` | `medium` | `low` — how settled the slice is; informational only.
Conventions: the convention skills this slice's work loads, as the user confirmed them in `/feature-plan` step 1 (e.g. `/backend`, `/frontend`, `/fullstack`, `/dcr`). `/feature-execute` loads them and passes them to every dispatch.

Brief scope description.

**Decisions locked** — the forks resolved at plan time (entity shape, required/nullable, state ownership, idempotency, provider-vs-local, error channel). Never empty — `None — <reason>` when there are none. Forms:
- `<decision> — <why>`; add `owner-confirmed` when it is product-semantic.
- `Deferred → resolved at <phase> by <evidence>` — an open fork; the resolving phase is mandatory.
- `<decision> — <state> → <record id>` — settled through a decision add-on; `<state>` mirrors its record, as its contract says (`.agent-kit/common/process/planning/decision-addon.md`).

**Shape** — this slice's diagram when it earns one (`.agent-kit/planning/DIAGRAMS.md`). Multi-slice features keep it here, per slice; a single-slice feature keeps it in the Design section above.

**Test Plan (Slice 1)** — same format as the top-level Test Plan above. Slice `Ready` requires approval; `Done` requires every bullet checked.

### Slice 2 — <Name> [Status]

Tier: `haiku` | `sonnet` | `opus`
Effort: `low` | `medium` | `high`
Confidence: `high` | `medium` | `low`

Brief scope description.

**Decisions locked** — same format.

**Test Plan (Slice 2)** — same format.

---

## Execution Plan

> Phases are sequential. Tasks marked ‖ within a phase can run in parallel.
>
> **Tests are NOT a trailing phase.** Every phase that ships testable behavior ships its own tests in the same phase (per `.agent-kit/common/process/planning/execution-loop.md` step 4 — never defer test authoring to a later "tests" phase). The patterns below name the *layer* each phase builds; the tests for that layer live inside it.
>
> Choose the pattern that fits your feature, or define your own:
>
> | Pattern | Phases (each phase folds in its own tests) |
> |---------|--------|
> | Full-stack | Model → Service/Repo → Mapper/Resource → Frontend |
> | Backend-only | Model → Service/Repo → Resource |
> | Frontend-only | Types → Service → Components |
> | Enrichment / integration | Service changes → Frontend updates |
> | Data model change | Entity/Migration → Backfill → Affected services |
>
> This holds for **every** test tier — unit, integration, and expensive/gated alike (e.g. `*ExpensiveIntegrationTests` against real third-party keys; just profile-gate those so they don't run in the normal build). A **standalone** test phase is justified only when a suite genuinely spans the whole feature with no single phase to own it — never as a default place to park tests.
>
> **Sizing**: a phase is what one dispatch can land without looping — a cohesive unit, typically **one domain's vertical slice** (entity + repo + service + mapper + its tests) or one well-scoped integration. That's allowed to be many files. Split only when a phase would cross multiple domains/layers with *entangled, unresolved decisions*, or hits a re-evaluation trigger from `.agent-kit/common/process/planning/plan-shaping.md` (>~10 affected-code rows, >~8 test-behavior bullets, >50% file overlap with another phase, >~50K token forecast) — the same bound a `Complexity: 8` phase hits (`plan-shaping.md` → Phase complexity). Don't over-split a cohesive scaffold into entity-then-service-then-mapper — each sub-dispatch then re-loads the same context, costing more than the split saves.

### Phase 1 — <Name>

Tier: `haiku` | `sonnet` | `opus` — optional override; falls back to the slice tier if omitted.
Reviewer: `haiku` | `sonnet` | `opus` — tier for this phase's code-review dispatch; defaults to `Tier:`.
Effort: `low` | `medium` | `high` — optional override; falls back to the slice effort if omitted.
Complexity: `5` — 7 files · 4 bullets · backend+migration · +1 novel pattern. One of `1` | `2` | `3` | `5` | `8`, basis mandatory. Rubric: `.agent-kit/common/process/planning/plan-shaping.md` → Phase complexity.
Reads:
  - `path/to/file.ext`
  - 2-5 files this phase touches. Orchestrator filters `## Reference` entries by this list at dispatch time (see `.agent-kit/common/process/dispatch/reference-paste.md` → tier-gated paste).

- [ ] `path/to/File.ext` — change — contract it must honour
- [ ] ‖ Task 2
- [ ] ‖ Task 3

### Phase 2 — <Name> · Provisional

> Volatile-slice form: `Tier`/`Effort`/`Complexity`/`Reads` and the files, no task detail yet. `/feature-execute` promotes it to full depth at its slice boundary.

Tier: `sonnet` · Effort: `medium`
Complexity: `3` — 5 files · 2 bullets, from the planned files; re-scored at promotion
Reads:
  - `path/to/File.ext`
Fallback: what this phase does if the likely option loses.

- [ ] Files: `path/to/File.ext`

### Phase 3 — Spike: <question>

> Its product is a decision, not code. ⚠ Evidence is value-sampled — real values from the source, never a field's name or presence.

Complexity: `1` — 2 files read · 0 bullets
Timebox: e.g. `2h`
Outcome: the decision it produces — the `Deferred` item it resolves.

---

## Notes

Decisions, gotchas, or context discovered during implementation that future readers should know.

---

## Reference

> Cached plan-time discovery. Orchestrator pastes this verbatim into every sub-task dispatch for this feature.
> Required for multi-phase plans or features touching >5 files. Optional for trivial single-phase work.
> Evolve it: if an in-flight phase surfaces something load-bearing, add it here before the next dispatch.

### Module memory in scope

> Routing, not content — where the durable knowledge already lives, so no dispatch re-derives it.
> One row per module this feature touches, with its `INDEX.md` state. A `Stub` module has no memory
> to point at: carry that discovery below instead, and consider `/module-extract <module>` first.

- `<module>` — `Documented` · load via `/modules <module>` before editing it

### Invariants (do not "fix" these)

- Counter-intuitive design choices an agent might "fix" without context

### Cross-file protocols

- Multi-file contracts that must be preserved atomically

### Symbol map (check here before grepping)

> Paths are project-root-relative (from the git repo root) — e.g. `src/main/java/.../File.java`, `frontend/src/.../File.svelte`. Never absolute, never user-machine-relative.

- `src/main/java/.../File.java` — `methodName` ~Lxxx; relevant ranges

### Consumer touchpoints (must keep compiling)

- External code that depends on signatures being touched

### Pre-decided non-changes (alternatives considered; we said no)

- Items review/instinct might propose that we already rejected — one-line rationale each
