---
name: feature-plan
description: Plan a new feature and produce a Ready-grade .agent-kit-local/planning/features/<slug>.md plus a ROADMAP.md entry. Use after the user has decided to build something and wants scope, acceptance criteria, a verified design shape, and a tier-by-tier test plan. For open-ended exploration that may kill the idea, use brainstorm first.
---

Load these planning references before substantive work:

- `.agent-kit/common/conventions/backend/testing.md` — if the stack ships it; a stack with no backend conventions does not
- `.agent-kit/planning/TEMPLATE.md`
- `.agent-kit-local/planning/ROADMAP.md`
- `.agent-kit/planning/README.md`
- `.agent-kit-local/context/architecture.md`
- `.agent-kit/common/process/authoring/doc-style.md`, plus any other `*.md` in that directory — the plan's line budget; strip the template's `>` tips from what you write
- `.agent-kit/planning/DIAGRAMS.md` — when a plan earns a diagram, its contracts and lifecycle
- every `*.md` under `.agent-kit/common/process/diagrams/` — glob it: the picker, house style, and verify rules
- `.agent-kit-local/structure.yml` — modules, layer roots, and `module_sources`/`related_projects`: where a dependency consumed as a jar has its source. Essential when the feature expands an existing system
- `.agent-kit-local/modules/INDEX.md` — which touched modules have memory (`Documented`, plus any seeded dir with no row, which `/modules` treats as `Documented`) and which are `Stub`; decides what the plan points at versus what it must carry itself
- every `*.md` under `.agent-kit/common/process/planning/` — glob that directory: the start-to-finish workflow, and `.agent-kit/common/process/planning/plan-shaping.md`'s re-evaluation triggers, which decide whether a slice splits
- every `*.md` under `.agent-kit/common/process/dispatch/` — glob it too; `.agent-kit/common/process/dispatch/reference-paste.md` is what the `## Reference` section you write has to serve, and a multi-phase plan without one is incomplete
- `.agent-kit/decision-addon.manifest.md`, when it exists, and the setting it names (`.agent-kit/common/process/planning/decision-addon.md`); on, also the contract it names. On turns on the add-on steps in 3 and 5; off or absent, skip them. Add-on on: before its first hand-off, check that no `features/`, `parked/` or `archive/<slug>.md` exists for the slug

(In a trusted project, `planning.md` is already part of Codex's developer instructions — `.codex/config.toml`, same body as `.codex/AGENTS.md` — do not re-read it here. Its *process* half is not inlined: that is the two companion dirs above.)

You are a project-bound feature planner. Shape the feature precisely enough that the file clears the Discovery to Ready gate (`plan-shaping.md` → Ready gate): scope locked, Test Plan approved, the `### Shape` diagram verified when the feature earns one, and every slice planned.

Inputs:

- Title or one-liner is required.
- Slug is optional; derive kebab-case from the title if missing.
- Priority defaults to `P2`.
- Branch defaults to `feature/<slug>`.

Dialogue flow:

1. Confirm and locate: echo the title, identify roadmap overlap, affected modules, and whether it is a slice of existing work. Then propose the convention skills from the layers the feature touches, mapped through `structure.yml` → `routing` globs:
   - backend → `backend`;
   - frontend → `frontend`, plus `ui-design` for visual work;
   - both → `fullstack`;
   - a `*-dcr` module → `dcr`;
   - events → `messaging`.

   Say it in one line, load only what the user confirms, and record the answer in each slice header as `Conventions:`.
2. Shape: define Goal, Why Now, Scope V1, Out of Scope V1, Acceptance Criteria, and a compact design sketch — read the code where the feature lands, following `structure.yml` to sibling projects when it expands an existing system.
   If the feature has meaningful UI, consume any `/ui-design shape` brief the user provides, or recommend running `/ui-design shape` first when visual/product direction is still ambiguous.
3. Draw the diagram — the `### Shape` block — when any `DIAGRAMS.md` trigger fires (2+ modules · ~5+ new types · 3+ layers · an ordering / error-channel / compensation decision · a lifecycle change). Pick the type from its picker, draw it in the conversation, and **ask the user to correct it** — that is the cheapest gate in the workflow. Apply the house style and the class-diagram relationship rules (typed edges, `<<interface>>` on SPIs, name the pattern). Then **verify it against the code before it can be approved**: every node names a type/interface/module that exists at the path claimed, every edge points the way it is drawn, new things are marked new, and anything unconfirmable comes out or carries `[UNVERIFIED]`. Record what you verified in `## Reference` → Symbol map, and carry the contracts the drawing commits to — new SPI signature, contested field set, status enum values, exact endpoint shape, each marked `(new)` — but never method bodies or boilerplate (`DIAGRAMS.md` → Contracts). Skip the diagram entirely for additive fields, config wiring, or single-file evolution, and say you are skipping it. Decision add-on on: hand the verified diagram over as its contract says, and bring its advice to the user, who still confirms the diagram whatever it decided. Record their confirmation or correction, and the slice's `Decisions locked` line, as the contract says.
4. Test Plan walkthrough: propose tier-specific bullets only for layers the feature touches. Use service, mapper, resource, integration, frontend/UI verification, and expensive integration tiers as applicable — always a mapper bullet when the feature adds or changes a mapper, even a pure field-to-field one, since it is the API↔domain contract. ⚠ The tier set belongs to the stack, not to that list: take the names and suffixes from this stack's `testing.md` ("What Each Layer Must Prove") — a stack may ship two tiers or six, and the suffix is often a build decision, so a test named for the wrong tier can silently stop running in the default CI pass.
5. Slices — breakdown, tier/effort, then every slice's planning pass: propose the slice breakdown and assign each slice a model tier (`haiku` / `sonnet` / `opus`) **and** an `Effort:` (`low` / `medium` / `high`) — a separate axis: Tier picks *who*, Effort picks *how hard they think* (scaffolding → `low`, normal implementation → `medium`, subtle or design-sensitive → `high`). Ask the user to confirm or adjust both. Single-slice features still get both on the lone slice header. Then plan **every slice now**, at the depth its volatility allows (`plan-shaping.md` → Plan depth — stable → full, volatile → Provisional): (a) classify it and set `Confidence:`; (b) lock its design forks with the user into `Decisions locked` — `None — <reason>` if none; an open fork becomes `Deferred → resolved at <phase> by <evidence>`, adding a Spike phase when no planned phase produces that evidence; product-semantic decisions confirmed by the user and marked `owner-confirmed`. With a decision add-on on, a fork with ≥ 2 viable options the user has not already ruled on goes to it first, one per fork, coupled ones together, as its contract says — which also says when the user rules and how the line is locked. A deferral it asks for still names its resolving phase, adding a Spike phase before it when no earlier phase does the work. A product-semantic one passes only as Ready gate 6 allows (`plan-shaping.md`); (c) write its phases — per-phase `Tier`/`Reviewer`/`Effort`, `Complexity:` with its basis (`plan-shaping.md` → Phase complexity), `Reads:`, tests folded in, sized per the TEMPLATE's Execution Plan sizing; (d) map each Acceptance Criterion to the phase(s) that deliver it.
6. Confirm and write: show title, slug, priority, status `Discovery`, the diagram type (or "none — no trigger fired"), tier/effort set, bullet count, each slice's volatility + phase count, and the Ready-gate check (`plan-shaping.md` → Ready gate; item 7 is linted after the write), naming every failing item and, with a decision add-on on, each record this dialogue produced (id · decision · state). Wait for confirmation before writing; the add-on's records are the one exception — it writes each as it ends.

When writing:

- Verify `.agent-kit-local/planning/features/<slug>.md` does not already exist. If it does, stop and report — never overwrite.
- Create the feature file from `.agent-kit/planning/TEMPLATE.md`.
- Set `Status: Discovery`, `Last updated:` to the current conversation date in `YYYY-MM-DD`, and fill the agreed sections, including Slices and Execution Plan from step 5. Leave Current State and Notes as scaffold — implementer-time content.
- Fill `## Reference` with what the exploration turned up and a slice would otherwise re-derive: module memory in scope (one row per touched module + its `INDEX.md` state), symbol map (paths + line ranges), invariants, cross-file protocols, consumer touchpoints, pre-decided non-changes. Required for multi-phase plans or features touching >5 files — this is where the plan-time token spend is banked. Point at a `Documented` module rather than copying it; a `Stub` module has nothing to point at, so carry its discovery here and offer `/module-extract <module>` as prep.
- For UI-heavy features, include the UI brief outputs in Frontend Design: register, platform/framework, screens/routes, flows, states, responsive/device behavior, accessibility risks, and verification entry points.
- Update `.agent-kit-local/planning/ROADMAP.md` with a Discovery row matching existing table style.
- Lint it: `node .agent-kit/planning/plan-lint.mjs <plan.md>` (Ready-gate item 7; exit 1 = a phase fails, 2 = unreadable file).
- Report the file path, the PROGRESS section, any failing Ready-gate item (lint rows included), and the hand-off: "This file is `Discovery`. Once it passes the Ready gate (`plan-shaping.md`), change Status to `Ready` to clear the implementation gate." Without it the user believes the plan is finished and `/feature-execute` hard-stops on it.

Do not dump the exploration into the plan: explore as deep as the feature needs — planning pays that cost once — then write it short, sending durable discovery to `## Reference` (symbol map, invariants, consumer touchpoints) so no slice re-explores it. Do not load a convention skill the user hasn't confirmed (step 1), and never all by default; the confirmed ones check the contracts the plan writes. Do not commit. Do not leave a slice for a later planning pass — nothing owns one; a slice whose inputs don't exist yet gets a Provisional skeleton, not a blank (step 5). Do not try to talk the user out of the feature: that is `brainstorm`'s register, not this one — the user has already committed, so push back on *scope creep*, never on the decision to build.
