# Project Instructions

Follow all rules below precisely. The project's stack, architecture, and build are described in the always-loaded context below.

## Always-loaded context (build, architecture)

Project-specific context — product/domain mental model and per-module conventions — is **on-demand**:
load via `/modules` (project mental model) and `/modules <module>` for a specific module. It is
deliberately not eager-loaded.

@../.agent-kit-local/context/build-commands.md
@../.agent-kit-local/context/architecture.md
@../.agent-kit/common/process/planning.md
@../.agent-kit/common/process/agent-dispatch.md
@../.agent-kit/common/process/shell-hygiene.md
@../.agent-kit/common/process/terminology.md

## On-demand conventions (use skills to load)

- `/backend` — Backend conventions for this stack (patterns, testing, API, security, logging, concurrency): the language-neutral backend invariants and the engine-neutral persistence invariants always, plus the standard for the declared database and this stack's own persistence doc
- `/frontend` — Frontend conventions (components, state, services, types): the framework-neutral invariants always, plus the standard for the declared frontend framework and this stack's own frontend conventions when it ships them
- `/mobile` — Mobile conventions for this stack (screens, navigation, native modules, platform services) *(when the stack ships a mobile layer)*
- `/ui-design` — Reusable UI design workflow for shaping, crafting, auditing, polishing, hardening, or adapting web, mobile, native, and design-system work
- `/ui-extract` — Generate or refresh module-specific UI memory (`modules/<module>/ui.md`)
- `/ui-detect` — Run the mechanical "AI tells" detector on changed/named UI files (pure neutrals, default fonts, dated easing). Called from the `/ui-design` verify phase; also invokable manually
- `/fullstack` — All of the above combined
- `/scaffold` — Scaffold a new backend domain (entity → service → resource + tests) *(when the stack provides scaffold recipes)*
- `/dcr` — Scaffold a Data Change Request — one-shot batch migration / bulk CRUD / data-correction script: the framework-neutral invariants always, plus this stack's recipe when it ships one
- `/migrate` — Migrate legacy code onto this stack's conventions, one unit at a time, with characterization tests proving equivalence: the framework-neutral invariants always, plus this stack's migration layer when it ships one
- `/messaging` — Companion to `/backend` for event-messaging work: the framework-neutral invariants always, plus this stack's concrete messaging conventions when it ships them
- `/modules` — Load on-demand **module memory** (how a module works: purpose, public SPIs, internal flows, gotchas). Reads `.agent-kit-local/modules/INDEX.md`, then the relevant `<module>/module.md` (+ `internals.md`/`<domain>.md`). **Never** add these to the always-loaded `@import` chain.
- `/module-extract` — Generate/refresh a module's memory (reads source + README, fact-checks, writes `module.md` + optional `internals.md`/`<domain>.md`, flips the INDEX row).
- `/structure-extract` — Generate/refresh `.agent-kit-local/structure.yml`, the machine-readable index card (languages, frameworks, layer roots, reviewer-routing globs, module provenance) the reviewers read to route work without loading `/modules`.
- `/brainstorm` — Explore and validate an idea (product + architect + entrepreneur partner) before committing to build it. Three registers: casual **Talk**, exploratory **Shape**, and a full **Forge** gauntlet that kills weak ideas or materializes survivors into `planning/ideas/<slug>.md`.
- `/feature-plan` — Plan a committed feature into `.agent-kit-local/planning/features/<slug>.md` + a `ROADMAP.md` entry (Ready-grade Test Plan).
- `/feature-execute` — Drive a `Ready`/`In Progress` feature plan through implementation: walks its Execution Plan phases in order, running the per-phase loop from `.agent-kit/common/process/planning/` (dispatch at each phase's annotated `Tier`/`Effort` → review at its `Reviewer` tier → fix → test → checkpoint). Thin driver over that companion; the counterpart to `/feature-plan`.
- `/peer-dispatch` — Delegate a file-disjoint sub-task to a peer model — Codex/OpenAI via `codex exec` or a local LM Studio model via `codex exec --oss` — reusing the agent-dispatch tier system (opt-in: "delegate &lt;unit&gt; to {codex|local}"). Peer output runs the normal review+test gate.
