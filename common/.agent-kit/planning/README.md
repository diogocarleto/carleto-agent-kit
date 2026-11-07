# Planning

Central place for planning artifacts. Focused on product and delivery planning, not implementation docs.

## Structure

```
.agent-kit/planning/          — templates + house rules (shared; overwritten every install)
├── TEMPLATE.md            — template for new feature plans
├── IDEA-TEMPLATE.md       — template for a materialized idea (output of /brainstorm)
├── ADR-TEMPLATE.md        — template for an Architecture Decision Record
├── RFC-TEMPLATE.md        — template for a Request for Comments
├── DIAGRAMS.md            — when a plan earns a diagram, its contracts and lifecycle (shared rules: `process/diagrams/diagrams.md`)
└── README.md              — this file

.agent-kit-local/planning/    — instances (project-owned; install never touches it)
├── ideas/                 — live ideas (Incubating · Survived) — output of /brainstorm
├── features/              — live feature plans (Discovery · Ready · In Progress)
├── parked/                — paused ideas/plans (Postponed · Blocked) — may resume
├── archive/               — terminal ideas/plans (Killed · Promoted · Done · superseded)
├── decisions/
│   ├── adr/               — Architecture Decision Records (ADR-XXX-title.md)
│   └── rfc/               — Requests for Comments (RFC-XXX-title.md)
└── ROADMAP.md             — scannable index of all features with status and links
```

`ideas/`, `parked/`, and `archive/` are **shared by ideas and features** — an idea and a feature
are the same *kind* of planning artifact at two altitudes (is-this-worth-building vs
how-do-we-build-it), so they flow through the same liveness folders.

## Workflow

### Ideas

An idea is a *materialized conception* — the durable output of `/brainstorm` when a discussion is
worth keeping. It sits one altitude above a feature: it answers **is this worth building at all**,
where a feature answers **how do we build it**. It is stack-blind and repo-blind until it survives.

1. **Brainstorm** — `/brainstorm` explores at one of three registers (Talk · Shape · Forge). Only
   **Forge** produces a file: `ideas/<slug>.md` from `IDEA-TEMPLATE.md`, Status `Incubating`. Talk
   and Shape may fizzle leaving nothing — that is a valid outcome.
2. **Run the gauntlet** — fill the dimensions the conversation raised; mark unresolved blockers
   `[OPEN: …]`. The reasoning lenses (inversion, constraint-removal, red-team) sharpen soft answers.
3. **Survive or die** — an idea reaches **Survived** only when: every raised dimension is *written*,
   the **pre-mortem is recorded**, and **zero `[OPEN]` blockers remain**. A lens run but not written
   down did not happen. If it can't clear the bar, it's **Killed** → `archive/` (one-line "why" in
   the header) so it doesn't return unexamined.
4. **Choose a stack** — *only after* Survived, fill "Shape when it lands": companion vs new project,
   and a stack from the kit's covered stacks. Never before — an idea dressing itself in a stack
   before it survives is the failure mode this ordering prevents.
5. **Promote** — hand the survivor to `/feature-plan` (companion → the host project's `features/`;
   new project → create the repo, then install the kit into it from the kit checkout; the idea migrates there). Set Status
   `Promoted`, move to `archive/` with a pointer to where it landed. Promotion is a *separate, later*
   act — a Survived idea may sit for months first.

**Where a homeless idea lives** — an idea about an *existing* project incubates in that project's
`ideas/`. An idea for a *brand-new* project has no home repo yet: it incubates in the dedicated
**incubator consumer** — any project whose job is to hold ideas with no home repo yet — and
migrates to the scaffolded repo on Promotion. Ideas never
incubate in the kit source repo — that is source-of-truth for shipped tooling, not a product backlog.

### Features
1. **Plan** — discuss and define the feature, then create `features/<name>.md` from `TEMPLATE.md`. Fill in Scope, Acceptance Criteria, Design — including a `### Shape` diagram when the feature earns one (`DIAGRAMS.md`) — the **Test Plan**, and every slice's phases. Status starts as `Discovery`.
2. **Approve** — user reviews the Test Plan and the design; the `### Shape` diagram must also be verified against the code, since it ships to every implementer as authority (`DIAGRAMS.md`). Set status to `Ready` only once the plan passes the **Ready gate** (`.agent-kit/common/process/planning/plan-shaping.md` → Ready gate). Implementation cannot start before this gate.
3. **Track** — move to `In Progress` when coding begins. Check off Execution Plan tasks and Test Plan bullets as they complete. Update `Status` in the header.
4. **Index** — add or update the entry in `ROADMAP.md` so readers can find the feature without opening every file.
5. **Park** — when a feature goes `Blocked` or `Postponed`, update its status header, move its `ROADMAP.md` row to the matching section, and move the file to `parked/`. It is not finished — it may resume, at which point it moves back to `features/`.
6. **Archive** — when a feature reaches a terminal state — `Done` (shipped) or **superseded** (replaced by a different plan / no longer reflects direction) — update its status header, move its `ROADMAP.md` row (to the Done section, or drop it for a supersession), and move the file to `archive/`. For a supersession, leave a one-line pointer in the replacing plan.

### Decisions

Templates are **shared** (`.agent-kit/planning/`), instances are **project-owned**
(`.agent-kit-local/planning/decisions/<kind>/`) — the same split as features and ideas. Number an
instance by its position in the series (`ADR-001`, `ADR-002`, …); the number is a sequence, not a
ticket id.

- **ADR** — write when committing to a significant architectural choice. From
  `.agent-kit/planning/ADR-TEMPLATE.md` → `decisions/adr/ADR-<NNN>-<slug>.md`.
- **RFC** — write when a significant change needs thinking through before committing. From
  `.agent-kit/planning/RFC-TEMPLATE.md` → `decisions/rfc/RFC-<NNN>-<slug>.md`. Accepted RFCs often
  produce an ADR.

Both ADR and RFC are **rare and hand-written** — no skill scaffolds them, deliberately. An ADR earns its place
only when all three hold: the decision looks wrong at a glance, it has visible costs that invite
"let's just remove this", and the reasoning isn't derivable from the code. Most decisions fail that
test. A blocked technical *unknown* needs no artifact of its own — timebox an investigation
(`/brainstorm`'s Validate phase), then write the finding into the RFC or ADR it was blocking.

## Status Vocabulary

All planning files must use these statuses. No variations.

**Idea statuses** (files from `IDEA-TEMPLATE.md`):

| Status | Meaning |
|--------|---------|
| `Incubating` | Being interrogated via `/brainstorm` Forge; gauntlet not yet fully answered |
| `Survived` | Every raised dimension written, pre-mortem recorded, zero `[OPEN]` blockers. Stack may now be chosen. |
| `Promoted` | Became a feature (or a new project); moved to `archive/` with a pointer to where it landed |
| `Killed` | Failed the gauntlet; moved to `archive/`, one-line "why" kept in the header |
| `Postponed` | Explicitly deferred — not abandoned, just not now |

**Feature statuses** (files from `TEMPLATE.md`):

| Status | Meaning |
|--------|---------|
| `Discovery` | Being researched or discussed; not yet through the Ready gate |
| `Ready` | Passed the **Ready gate** (`plan-shaping.md`): Test Plan approved, Shape verified, every slice planned. Implementation may start. |
| `In Progress` | Actively being implemented; ticking Execution Plan tasks and Test Plan bullets |
| `Blocked` | Cannot proceed — waiting on an external dependency, decision, or unresolved question |
| `Done` | Implemented, every Test Plan bullet checked, merged, shipped |
| `Postponed` | Explicitly deferred — not abandoned, just not now |

## Doc style

Every file in here is written to `.agent-kit/common/process/authoring/` → **Plan files**, which carries
the line budget and the prune-on-completion rule.

## Slice Rules

- **Slices stay inside the parent feature file.** Each slice gets its own section and execution plan within one document.
- If a feature needs many separate slice files, that is a signal the feature is too large — consider splitting it into independent features instead.
- Exception: truly huge features that span multiple independent domains may justify separate files, but this should be rare.

## File Lifecycle

A plan moves between the liveness folders as its status changes — the **folder tracks liveness**, the header + `ROADMAP.md` track the exact status. Ideas and features share these folders:

- **`ideas/`** — live ideas: `Incubating` · `Survived`.
- **`features/`** — live work: `Discovery` · `Ready` · `In Progress`.
- **`parked/`** — paused but not abandoned: `Postponed` (ideas or features) · `Blocked` (features). Moves back to `ideas/` or `features/` on resume.
- **`archive/`** — terminal: `Killed` / `Promoted` (ideas), `Done` / superseded (features). Promotion and supersession leave a one-line pointer to what replaced them.
- Status lives in the file header — `ROADMAP.md` mirrors it as a scannable index.
- Never use status **subfolders** inside any of these — the folder already encodes liveness, and deeper nesting fragments git history.

## Worked example — an idea's life

A concrete walk from musing to shipped, and the two ways it can end early:

1. **Talk** — *"what if there were a phone app for reading lyrics while you practice?"* You run
   `/brainstorm` (Talk register). It's a loose chat; you poke at it, it's interesting. No file yet.
2. **Escalate to Forge** — *"tear it apart."* The register flips. The gauntlet runs: audience is real,
   but **legality** is a blocker — lyrics are licensed. That becomes `[OPEN: lyrics rights — license,
   user-contributed, or link-out only?]`. The pre-mortem confirms rights is the thing that kills it.
   A file lands: `ideas/practice-companion.md`, Status `Incubating`, with the `[OPEN]` marker.
   - *Ends here as **Killed**?* If rights turn out to be a hard no, the file moves to `archive/`, header
     records `Killed — lyrics licensing infeasible for a solo dev`, and it won't be re-litigated blind.
   - *Ends here as **Postponed**?* If rights are *maybe-later*, it moves to `parked/`, Status `Postponed`,
     resume trigger noted (*"revisit if a lyrics API with fair terms appears"*).
3. **Survived** — rights resolve (say, link-out-only V1). The `[OPEN]` clears, every raised dimension is
   written, pre-mortem recorded → Status `Survived`. *Now* you fill "Shape when it lands": companion to
   an existing product (shared backend + catalog), new mobile deployable, stack from the kit's covered stacks.
4. **Promote** — hand the survivor to `/feature-plan`. Because it's a companion, the backend endpoints
   become features in that product's `features/`; the mobile app is a new repo with the kit installed into it from the kit checkout.
   The idea file moves to `archive/`, Status `Promoted`, with a pointer to where it landed.

The discipline the folders enforce: a dead idea leaves a tombstone (never silently forgotten), and a
live idea can't reach a stack discussion until it has survived the questions that would have killed it.
