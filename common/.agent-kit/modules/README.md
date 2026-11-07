# Module Memory

On-demand, per-module knowledge that makes agents "clever" about how each module
works — without bloating the always-on context.

## What this is (and is not)

This is a **third documentation layer**, orthogonal to the other two:

| Layer | Holds | Loaded |
|-------|-------|--------|
| Always-on (`CLAUDE.md` + `@imports`) | Global rules, dispatch policy, build, architecture index | Every session |
| Conventions (`/backend`, `/frontend`, …) | *How to write code here* (cross-cutting idioms) | When the skill is invoked |
| **Module memory (this folder)** | *How a specific module works* — its purpose, public surface, internal flows, gotchas | On demand, via `/modules` or a direct `Read` |

It is **not** a class listing or an API mirror. Store only **non-obvious,
slow-to-rederive** knowledge — things an agent cannot cheaply `grep`/`Read` for
itself. If `Read` answers it fresh, it does not belong here.

## Hard rule: never eager-loaded

These files are **never** `@import`'d from `CLAUDE.md` or anything in its import
chain. A file only loads at startup if an `@import` points at it. Module memory
is reached exclusively by:

- the `/modules` skill (reads `INDEX.md`, then `Read`s the relevant file), or
- an agent `Read`-ing the file when it starts working in a module.

Keep it that way. Adding any of these files to the `CLAUDE.md` import chain
reintroduces the bloat this layer exists to avoid.

## Write it like API docs for a consumer — present tense, not a dev log

Document the module the way you'd document an API for someone **binding it into their
app**: what it does, how to wire/use it, its SPIs, config, conventions, and the
non-obvious gotchas. Always **present tense, current state** — *how the module is and
how to use it*, never *how it got there*.

⚠ **Feature-plan residue does not belong in memory.** Slice/phase numbers, "review
round N", "Done / tests green", test-run anecdotes ("the run caught X"),
dates-as-history, and "previously / used-to" chronology are `.agent-kit-local/planning/`
feature-file content — strip them. A `git`/ADR pointer that anchors *why* a non-obvious decision
stands is fine **as rationale**, never as a timeline.

**Organize by durable topic** (domain · SPI · flow · gotcha), never by when it shipped
— a heading like "Slice 8 — subscriptions" is a smell; the heading is "Subscriptions".

**Reader test:** would someone using or maintaining the module find the line useful
without caring how the code evolved? If it only makes sense as project history, cut it.

## Diagrams — one per doc, when prose struggles

A doc may carry one verified diagram; the rules are `.agent-kit/common/process/diagrams/diagrams.md` →
*In module memory*.

## Who writes these files

**Three** sanctioned writers inside this project — never hand-edited out of band, never
from the read-time `/modules` skill (read-only):

- **`/module-extract <module>`** — creates or fully refreshes from source (`--audit` is read-only).
- **`/ui-extract <module>`** — writes `ui.md`, only once the module already has `module.md`.
- **Per-phase upkeep (`.agent-kit/common/process/planning/execution-loop.md` steps 5 and 7)** — auto-writes a module-specific promotion (step 5) and re-stamps the **Verified** SHA for the module a phase edited in the phase-close commit (step 7).

Reader-spotted fix → a quick `/module-extract`, not a drive-by edit (which skips the re-stamp + source fact-check).

**A fourth source writes from outside the project: a stack seed.** A framework module is
identical for every project on a stack, so the kit may ship that module's memory and the
installer seeds it here — copied when absent, refreshed while still untouched, kept forever
the moment you edit it. Treat it as a kit default: **do not hand-edit it.** Fix it upstream
and reinstall, and every project on the stack gets the fix; edit it here and the file becomes
yours — it silently stops receiving upstream corrections. ⚠ **The repo that owns the module's
source is the one exception**: its phases change that source, so they refresh and re-stamp the
memory like any other — and then promote every changed doc to the stack's checkout
(`.synced-from` → `stack_source:`) at `<stack>/modules/<name>/` (`execution-loop.md` step 7). Unpromoted, the edit reaches no
other consumer and a `--reset-defaults` reinstall reverts it. A seeded module arrives with **no
`INDEX.md` row** (an install never writes that file); `/modules` finds it anyway and reads its
stamp from the footer. Only the owning repo gives it a row — elsewhere the row's **Verified**
would lag the footer after every reinstall.

## Who reads these files

This may be a multi-project repo (e.g. a web module, a dcr module, a mobile module)
that depends on other modules as **prebuilt artifacts** rather than source. So a
file may serve two kinds of reader:

- **Internals** — an agent working *inside* the module's own source (the framework
  module, or a project sub-module): flows, gotchas, where to change things.
- **Usage** — an agent in a sub-project that consumes another module as a prebuilt artifact and
  has no source for it: needs the public API, SPIs, extension points, how to
  wire/register.

So `module.md` leads with a **Usage / public surface** section and **Internals**
either follow as a section or, for big modules, move to a separate `internals.md`
— see "Layout" below. An agent reading only `module.md` should get everything it
can act on without the source in front of it.

## Layout

```
modules/
  README.md                          ← this file
  TEMPLATE.md                        ← copy when documenting a new module
  INDEX.template.md                  ← copy to INDEX.md on first extract (/module-extract does this)
  INDEX.md                           ← tiny manifest; /modules reads this first
  _root/                             ← reserved: PROJECT-level memory (not a real module)
    module.md                        ← project orientation + mental model
    internals.md                     ← optional: deep cross-module flows
    <concern>.md                     ← optional: big cross-cutting concern (auth, multitenancy, …)
  <module-name>/
    module.md                        ← usage + orientation (read first; all readers)
    internals.md                     ← optional: cross-cutting technical depth
    ui.md                            ← optional: UI surfaces, flows, platform gotchas
    <domain>.md                      ← optional: per-domain internals (big modules)
```

Granularity is **adaptive** — start coarse, split on pressure (mirrors the re-evaluation triggers in
`.agent-kit/common/process/planning/plan-shaping.md`):

- **Default:** a single `module.md` holding both the Usage and Internals sections.
- **Split out `internals.md`** when the module is a real extension surface
  (e.g. `acme-commons`, or the project's main web module) **and** its internals have grown
  big enough to stand alone. Then `module.md` keeps usage + orientation, and
  `internals.md` holds the technical depth.
- **Split out `<domain>.md`** when one domain's flow/gotchas get unwieldy
  (e.g. a single domain like `artist` or `scraper` within a large web module).
- **Add `ui.md`** when an already-documented module owns meaningful UI, frontend,
  mobile, native, route, screen, or visual-flow knowledge that is slow to rediscover.
  It is read only for UI work and generated/refreshed by `/ui-extract`.

Small/leaf modules (e.g. `acme-utils`) stay single-file. `module.md` is always
the entry point — keep the bare name on the most broadly useful (usage) content.

## UI memory (`ui.md`)

`ui.md` is optional enrichment for a module that already has `module.md`. It stores
UI-specific knowledge:

- routes/screens/views owned by the module
- primary user flows and where they cross services/stores/navigation
- design-system dependencies and deliberate local deviations
- platform variants (web vs React Native vs native)
- visual, accessibility, responsive, safe-area, localization, or state gotchas
- verification entry points (dev route, Storybook story, test, simulator path, screenshot flow)

It must not contain generic UI rules, framework basics, component inventories, or
checklists. Those live in `/ui-design` and `.agent-kit/ui/`.

## Project-level memory (`_root/`)

`_root/` is a reserved pseudo-module holding **project-wide** knowledge — the
on-demand deep counterpart to the eager `architecture.md`/`CLAUDE.md`. It captures
what spans modules and isn't obvious from any single one: the overall mental model,
cross-module flows (request lifecycle, event backbone, multi-tenancy, auth), how the
modules compose and why, and project-wide gotchas.

- Same files + adaptive split as a module: `_root/module.md` (orientation) + optional
  `_root/internals.md` / `_root/<concern>.md` (e.g. `auth.md`, `multitenancy.md`).
- Loaded via `/modules root`; generated/refreshed via `/module-extract root`.
- **Source for extraction:** the **root `README.md` first** (the project's authoritative
  overview — usually where this lives; a root `ARCHITECTURE.md` often does *not* exist),
  then go deep into the code to trace cross-module wiring. Read `ARCHITECTURE.md` only
  if present.
- **Don't duplicate** the eager `architecture.md` or per-module memory here — only
  project-wide, non-obvious, slow-to-rederive knowledge.

## Promotion loop — learning from repeated work

Module memory is meant to **evolve from coding**. When a fix or refactor recurs,
that is a signal to record it durably. Route by blast radius:

| Signal | Destination | Gate |
|--------|-------------|------|
| Flow / contract / gotcha specific to one module | that module's memory here | **auto-write** (low blast radius) |
| UI flow / route / screen / visual gotcha specific to one documented module | that module's `ui.md` | **auto-write if `ui.md` exists; otherwise suggest `/ui-extract`** |
| Cross-cutting idiom or style (true in any module) | `design-principles.md` / `code-style.md` (the kit owner routes it: the stack's doc, or `.agent-kit/backend/`) | **propose, human-confirm** (high blast radius) |
| Recurs in 2–3 modules but not universal | the convention doc, scoped with a note | propose, human-confirm |
| Happened once, unlikely to recur | **nothing** — noise is the enemy | — |

The test for "module memory vs conventions": *would this advice make sense to
someone working in a different module?* Yes → conventions. No → module memory.

This is wired into the per-phase implementation loop (`.agent-kit/common/process/planning/execution-loop.md`) and the
code-review agents, which flag a recurring correction as a **promotion
candidate** at the phase boundary.

## Maintenance

- **Style bar:** every file here follows `.agent-kit/common/process/authoring/` (clear + concise + accurate). Dense memory burns context budget on big projects — write the shape/gotcha, not grep-able field detail, and run the tighten pass.
- Keep each file **small** — a stale paragraph gets fixed; a stale 500-line doc gets abandoned.
- Anchor to **invariants and intent**, not line-level detail that churns each commit.
- When a phase changes a module's flow or contract, update its memory in the same change (counterpart to the code-anchor lifecycle in `.agent-kit/common/process/planning/execution-loop.md`, which migrates plan invariants *into* code).
- Each file ends with a **single** maintenance footer — one `sha` + date + "update when…". It is a freshness stamp, **not a changelog**: never grow a "Prior `X`… Prior `Y`…" history in it (that is what `git log` is for). Treat the stamp as a *claim to verify*, not gospel.

### Freshness mechanism

Memory decays as source moves. The **Verified** SHA in `INDEX.md` (mirrored in each
doc footer) is the anchor; drift = commits to the module's source since that SHA (the
formulas live in the INDEX header). For a module consumed as a **prebuilt artifact**, both the SHA and
its drift belong to the `source_project` — sync the doc from there instead of re-extracting
from the artifact.

⚠ **Validate the anchor before counting drift** — the SHA must resolve in the repo that owns the
module, and the module's path must exist there. Fail either and the state is **UNVERIFIABLE**:
report that, never a number and never FRESH. A stamp pointing at the wrong repo matches no path,
so the drift command cheerfully answers `0` — the false-fresh this anchor exists to prevent. Its
remedy also differs from stale: re-stamp from the correct repo. Commands in the INDEX header.

Three touchpoints keep memory honest, each at a different cadence:

| Touchpoint | When | What it does |
|------------|------|--------------|
| **Load banner** (`/modules`) | every load | validates the anchor, then computes drift for the module being loaded; if `>0` or UNVERIFIABLE, prepends a banner — recalibrates trust at point of use |
| **Per-phase upkeep** (`.agent-kit/common/process/planning/execution-loop.md` steps 5 and 7) | with each phase commit | refreshes what changed, then re-stamps **only the module the phase edited** — targeted, never beyond the docs in that row |
| **`--audit` sweep** (`/module-extract --audit`) | manual hygiene | read-only drift report across **all** documented modules — catches memory that rotted untouched |

Refresh weight scales to drift: **re-stamp** for cosmetic drift, **re-extract** for
semantic. A whole-module re-extract is always manual — never automatic. Drift deliberately
over-reports (formatting commits bump the count): a false "verify" is cheap, a false
"fresh" is the expensive error.

For UI edits, the same anchor applies. If `ui.md` exists, refresh it when the phase changed
UI surfaces, flows, or gotchas; its footer is re-stamped with the rest of the row either way. If `ui.md` does not exist and the
phase produced non-obvious UI knowledge worth preserving, surface `/ui-extract <module>`
as a follow-up instead of auto-creating memory for every screen.
