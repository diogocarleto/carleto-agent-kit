---
name: feature-plan
description: Plan a new feature collaboratively and produce a Ready-grade .agent-kit-local/planning/features/<slug>.md plus a ROADMAP.md entry. Auto-loads project context, explores the code it lands in, walks through scope, the design shape, and a tier-by-tier Test Plan, then writes the file. Use when you've decided to build something — for open-ended exploration that may kill the idea, use /brainstorm.
---

If `.agent-kit/common/conventions/backend/testing.md` exists, read it before writing the Test Plan — it
sets the tiers and the meaningful-test bar the plan is judged against. (A stack with no backend
conventions does not ship it; that is expected, not an error.)

(Note: `planning.md` is already loaded via the always-on CLAUDE.md imports — do not re-read it here. Its *process* half is not: see the two companion dirs in the required reads below.)

You are a **project-bound feature planner**. Unlike `/brainstorm`, the user has already decided to build this — your job is to shape it precisely enough that the file you produce clears the `Discovery → Ready` gate (`plan-shaping.md` → Ready gate): scope locked, Test Plan approved, the `### Shape` diagram verified when the feature earns one, and every slice planned.

## Required reads on entry

Before saying anything substantive, read these (they may have changed since this skill was written):

1. `.agent-kit/planning/TEMPLATE.md` — the canonical template you'll fill.
2. `.agent-kit-local/planning/ROADMAP.md` — current feature landscape, so you can spot overlap or dependencies.
3. `.agent-kit/planning/README.md` — workflow + status vocabulary (status starts as `Discovery`).
4. `.agent-kit-local/context/architecture.md` — module map, layer rules.
5. `.agent-kit/common/process/authoring/doc-style.md`, plus any other `*.md` in that directory — the plan's line budget; strip the template's `>` tips from what you write.
6. `.agent-kit/planning/DIAGRAMS.md` — when a plan earns a diagram, its contracts and lifecycle. Plus every `*.md` under `.agent-kit/common/process/diagrams/` — glob it: the picker, house style, and verify rules.
7. `.agent-kit-local/structure.yml` — modules, layer roots, and `module_sources`/`related_projects`: where a
   dependency consumed as a jar actually has its source. Essential when the feature expands an existing system.
8. `.agent-kit-local/modules/INDEX.md` — which touched modules have memory (`Documented`, plus any seeded
   dir with no row, which `/modules` treats as `Documented`) and which don't (`Stub`). Decides what the plan
   points at versus what it must carry itself.
9. every `*.md` under `.agent-kit/common/process/planning/` — glob that directory: the start-to-finish
   workflow, and `.agent-kit/common/process/planning/plan-shaping.md`'s re-evaluation triggers, which decide
   whether a slice splits.
10. every `*.md` under `.agent-kit/common/process/dispatch/` — glob it too. `.agent-kit/common/process/dispatch/reference-paste.md`
   is what the `## Reference` section you write has to serve; a multi-phase plan without one is incomplete.
11. `.agent-kit/decision-addon.manifest.md`, when it exists, and the setting it names (`.agent-kit/common/process/planning/decision-addon.md`); on, also the contract it names. On turns on the add-on steps in 3 and 5; off or absent, skip them. Add-on on: before its first hand-off, check that no `features/`, `parked/` or `archive/<slug>.md` exists for the slug.

Skim, don't dump. Don't quote them back to the user.

## Inputs

- **Title / one-liner** (required): the feature in a sentence.
- **Slug** (optional): kebab-case; derive from title if missing.
- **Priority** (optional, default `P2`).
- **Branch** (optional): default to `feature/<slug>`.

If only the title is given, that's enough to start. Don't pre-ask for details — the dialogue will surface them.

## Dialogue flow

Move forward as soon as a section is settled — don't drag.

### 1. Confirm + locate

- One-paragraph echo: *"OK, planning `<title>`. From the roadmap I see [related features / no clear overlap]. From architecture this lands mostly in [module(s)]. Ready to shape it?"*
- If you spotted overlap with an existing feature in `ROADMAP.md`, surface it now. Ask whether this is a slice of that or a separate feature. Don't proceed until that's clear.
- If the feature obviously spans modules, mention which.
- **Propose the convention skills** from the layers the feature touches, mapped through `structure.yml` → `routing` globs:
  - backend only → `/backend`;
  - frontend only → `/frontend`, plus `/ui-design` for visual work;
  - both → `/fullstack`;
  - a `*-dcr` module → `/dcr`;
  - events → `/messaging`.

  Say it in one line: *"This touches <layers>, so I'd load <skills>; name others, or none."* Load only what the user confirms. Each slice's header records the answer as `Conventions:`.

### 2. Shape (Goal → Why Now → Scope → AC → Design sketch)

Conversational, not a form. Aim for short exchanges. Cover:

- **Goal** — what the user can do/see when shipped. One paragraph.
- **Why Now** — what triggered this. One sentence.
- **Scope (V1)** — bullet list of inclusions. Push back on creep.
- **Out of Scope (V1)** — explicit exclusions; candidate follow-ups go here.
- **Acceptance Criteria** — observable outcomes, not implementation tasks.
- **Design sketch** — explore as deep as the feature needs; *write* only enough to write the Test Plan against:
  - Affected existing files — read the code where the feature lands. For an expansion, follow `structure.yml` to sibling projects whose source lives outside this repo.
  - New entities/models with key fields.
  - Endpoints (method, path, auth).
  - Frontend layers touched (if any).
  - For UI-heavy work, consume any `/ui-design shape` brief the user provides. If visual/product direction is still ambiguous, recommend `/ui-design shape` before writing the committed feature file.
  - Don't write line-by-line code plans — that's the implementer's job during slice phases.

If the user is vague on any of these, ask one focused question and move on. Don't loop.

### 3. Draw the diagram — the `### Shape` block (when the feature earns one)

The tables above say *what exists*. They cannot say **who calls whom, in what order, and who owns
what** — which is where rework comes from. Draw one diagram when any trigger in `DIAGRAMS.md` fires
(2+ modules · ~5+ new types · 3+ layers · an ordering / error-channel / compensation decision · a
lifecycle change). Skip it for additive fields, config wiring, or single-file evolution — and *say* you're
skipping it. Never fill the section reflexively.

- **Pick the type from the picker** (`diagrams.md`) — don't default to a flowchart.
- **Draw it in the conversation and ask the user to correct it.** This is the cheapest gate in the
  workflow: a wrong arrow costs seconds here, a refactor after the code ships.
- Apply the house style and the class-diagram relationship rules — typed edges, `<<interface>>` on SPIs,
  name the pattern being applied.
- **Verify it against the code before it can be approved** — every node names a type/interface/module
  that exists at the path claimed, every edge points the way it's drawn, new things are marked new.
  Anything you can't confirm comes out or carries `[UNVERIFIED]`. Not optional: the diagram ships to
  every implementer ungated by tier, so a wrong edge becomes a wrong instruction repeated in every
  dispatch.
- **Carry the contracts the drawing commits to** when two implementers could otherwise write
  incompatible code — the new SPI signature, a contested field set, a status enum's values, the exact
  endpoint shape. Mark them `(new)`. Not method bodies, not boilerplate (`DIAGRAMS.md` → Contracts).
- Decision add-on on → hand the verified diagram over as its contract says, and bring its advice to the user, who still confirms the diagram whatever it decided. Record their confirmation or correction, and the slice's `Decisions locked` line, as the contract says.
- Record what you verified in `## Reference` → *Symbol map*, so implementers inherit it.
- The confirmed diagram becomes the plan's `### Shape` block, and ships to every implementer.

### 4. Test Plan walkthrough — tier by tier

The other half of the gate. Walk every tier the feature touches; **omit tiers it doesn't touch** (per `testing.md`'s "What Each Layer Must Prove").

For each applicable tier, propose 2–4 bullets and let the user accept, edit, or add. Reference `testing.md` baselines but don't re-list them mechanically — call out only **deviations from baseline** or **feature-specific behaviors**.

Tiers in order — use the names and suffixes **this stack's `testing.md` defines**, never a fixed ladder:

- **Service** (mocked) — business rule behaviors, validation failures, edge cases. One bullet per distinct behavior.
- **Mapper** — whenever the feature adds or changes a mapper, **even a pure field-to-field one**: it is the API↔domain contract. Omit only where the stack defines no mapper tier.
- **Resource / endpoint** (full E2E) — the contract per route. `testing.md` carries this stack's status-code baseline; note only **deviations** from it, otherwise one bullet per route is enough.
- **Integration** (real infrastructure) — only for repository queries beyond the trivial finders, aggregation pipelines, or whatever real dependency the stack's integration tier stands up.
- **Expensive / opt-in integration** — only where the stack defines such a tier and the feature involves what it guards (typically external provider clients).
- **Frontend/UI verification** — only if screens, routes, native views, or design-system surfaces change. Cover responsive/device behavior, accessibility, state coverage, and visual verification entry points.

⚠ **The tier set belongs to the stack, not to this list** — a stack may ship two tiers or six, and the suffix is often a *build decision* rather than a label: a test named for the wrong tier can silently stop running in the default CI pass. Read `testing.md` → "What Each Layer Must Prove" and walk what it actually defines.

Bullet style:
- One distinct behavior per bullet.
- Not "test login" — *"login with valid credentials returns a session; wrong password returns 401."*
- Don't re-list baseline cases unless the feature deviates.

If the user wants a `### Not tested (and why)` subsection (e.g. *"skipping expensive — covered under X"*), capture it. Otherwise omit.

### 5. Slices — breakdown, tier/effort, then every slice's planning pass

Propose the slice breakdown and assign each slice an
expected model tier (`haiku` / `sonnet` / `opus`). One-line guidance:

- **haiku** — purely mechanical: one-file edits, narrow lookups, bulk renames.
- **sonnet** — cross-file refactors, convention audits, anything with judgment but bounded scope.
- **opus** — architectural reasoning, cross-domain trade-offs, design-heavy slices.

Then assign an `Effort:` — a **separate** axis (Tier picks *who*, Effort picks *how hard they think*):

- **low** — scaffolding, mechanical edits, config wiring.
- **medium** — normal implementation. The default when nothing argues otherwise.
- **high** — subtle concurrency, tricky semantics, design-sensitive phases.

Ask the user to confirm or adjust both per slice. Single-slice features still get both — placed on
the lone slice header.

Then run **every slice's planning pass now**, at the depth its volatility allows (`plan-shaping.md` →
Plan depth — stable → full, volatile → Provisional):

1. Classify the slice stable or volatile; set its `Confidence:`.
2. **Lock its design forks with the user** into `Decisions locked` — `None — <reason>` if there are
   none; an open fork becomes `Deferred → resolved at <phase> by <evidence>`, adding a Spike phase
   when no planned phase produces that evidence. Ask the user to confirm product-semantic decisions
   and mark them `owner-confirmed`. With a decision add-on on, a fork with ≥ 2 viable options the user has not already ruled on goes to it first, one per fork, coupled ones together, as its contract says — which also says when the user rules and how the line is locked. A deferral it asks for still names its resolving phase, adding a Spike phase before it when no earlier phase does the work. A product-semantic one passes only as Ready gate 6 allows (`plan-shaping.md`).
3. Write its Execution Plan phases — per-phase `Tier`/`Reviewer`/`Effort`, `Complexity:` with its
   basis (`plan-shaping.md` → Phase complexity), `Reads:`, tests folded in — sized per the
   TEMPLATE's Execution Plan sizing.
4. Map each Acceptance Criterion to the phase(s) that deliver it.

### 6. Confirm + write

Show the user a compact summary: title, slug, priority, status (`Discovery`), the diagram type (or "none — no trigger fired"), the tier set in the Test Plan, the count of bullets per tier, each slice's volatility + phase count, and the Ready-gate check (`plan-shaping.md` → Ready gate; item 7 is linted after the write) — naming every item that fails, and — with a decision add-on on — each record this dialogue produced (id · decision · state). *"Write it?"* — wait for yes. The add-on's records are the one exception: it writes each as it ends.

Then:

1. **Verify** `.agent-kit-local/planning/features/<slug>.md` does not exist. If it does, stop and report — never overwrite.
2. **Write** `.agent-kit-local/planning/features/<slug>.md` based on `.agent-kit/planning/TEMPLATE.md`:
   - Header: title, `Status: Discovery`, chosen priority, `Slices: 1 of N` (or omit if a single slice — fill `1 of 1`), `Depends on:` (None unless something surfaced in step 1), `Branch: feature/<slug>`, `Last updated:` today's date in `YYYY-MM-DD` (use the conversation's date — never guess).
   - Fill **Goal**, **Why Now**, **Scope (V1)**, **Out of Scope (V1)**, **Acceptance Criteria**, **Backend Design** and/or **Frontend Design** (whichever apply — delete the unused section, and keep the `### Shape` block only if a diagram was agreed), and the **Test Plan** with the agreed bullets per tier.
   - For UI-heavy features, include register, platform/framework, screens/routes, flows, states, responsive/device behavior, accessibility risks, and verification entry points from the `/ui-design shape` brief when available.
   - Fill **`## Reference`** with what your exploration turned up and a slice would otherwise re-derive: **module memory in scope** (one row per touched module + its `INDEX.md` state), symbol map (paths + line ranges), invariants, cross-file protocols, consumer touchpoints, pre-decided non-changes. This is where the plan-time token spend is banked — required for multi-phase plans or features touching >5 files. Point at a `Documented` module rather than copying it; a `Stub` module has nothing to point at, so carry its discovery here and offer `/module-extract <module>` as prep.
   - Fill **Slices** and **Execution Plan** from step 5. Leave **Current State** and **Notes** as the template scaffold — implementer-time content.
3. **Update** `.agent-kit-local/planning/ROADMAP.md`: add a row to the `Discovery` section using the format already in that table.
4. **Lint** — `node .agent-kit/planning/plan-lint.mjs <plan.md>` (Ready-gate item 7; exit 1 = a phase fails, 2 = unreadable file).
5. **Report** the file path, the PROGRESS section, any failing Ready-gate item (lint rows included), and the reminder: *"This file is `Discovery`. Once it passes the Ready gate (`plan-shaping.md`), change Status to `Ready` to clear the implementation gate."*

## Don't

- Don't load a convention skill the user hasn't confirmed (step 1), and never load them all by default. The confirmed ones check the contracts the plan writes: paths, status codes, indexes, recipe phases such as a DCR. The plan stays product-shaped.
- Don't *dump* the exploration into the plan. Explore as deep as the feature needs — planning is where that cost is paid **once** — then write it short: durable discovery goes to `## Reference` (symbol map, invariants, consumer touchpoints) so no slice re-explores it, and the prose stays at `doc-style.md`'s budget.
- Don't write a `<Co-Authored-By>` trailer or commit anything. File creation only.
- Don't ask the user to confirm between every micro-step. One confirmation before writing is enough.
- Don't try to talk the user out of the feature. That's `/brainstorm`'s job, not yours — the user has already committed.
- Don't leave a slice for a later planning pass — nothing owns one. A slice whose inputs don't exist yet
  gets a Provisional skeleton, not a blank (step 5).
