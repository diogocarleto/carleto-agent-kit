## UI Workflow

Use this workflow for reusable UI work. Keep dispatch policy separate: if the project has `.agent-kit/common/process/agent-dispatch.md`, read it and apply it to each phase.

### Phase map

1. Detect local context: app type, platform, framework, package scripts, design tokens, component library, routing, and existing screen patterns.
2. Load only relevant docs: core, command mode, register, platform, framework, verification, local implementation conventions, and module memory when it exists.
3. Shape when direction is unclear or the UI change is non-trivial. Do not code during shaping unless the user explicitly asks.
4. Implement the smallest coherent slice: one component, one screen, one flow, or one design-system primitive.
5. Harden the slice for data, errors, permissions, long text, localization, device sizes, and platform edge cases.
6. Verify with the best available local tools: type checks, unit/component tests, browser/device screenshots, console logs, accessibility checks, and interaction probes. Always run the mechanical `/ui-detect` pass on the changed files (see `verification.md` → "Mechanical checks").
7. Polish concrete defects found during verification. Avoid broad restyles unrelated to the task.
8. Report what changed, what was verified, and what remains unverified.

### Dispatch use

- Use the local `agent-dispatch.md` for inline vs dispatch and model tier decisions.
- Treat UI phases as independent dispatch candidates when they have disjoint write scopes.
- Keep judgment-heavy work with the orchestrator: product direction, visual taste, cross-platform tradeoffs, and final screenshot acceptance.
- Delegate evidence gathering and bounded work when available: framework detection, token inventory, component inventory, mechanical implementation, test runs, browser/device verification, accessibility scans, and regression cleanup.

### Shape-before-code gate

Shape first when any of these are true:

- The user asks for a new screen, app, flow, dashboard, landing page, or native view.
- The task involves brand/product tone, information architecture, or visual direction.
- Multiple platforms or frameworks are involved.
- The existing design system is unclear.

Skip shaping only for narrow fixes where the desired outcome is obvious.

### From scratch

For a new screen, app, flow, or design-system surface:

1. Run `shape` first and produce a UI brief, not code.
2. If the user commits to building, feed the brief into the project's planning flow.
3. The feature plan should carry UI phases, acceptance criteria, verification bullets, and a Reference section with routes/screens, components, stores/services, tokens, commands, and verification entry points.
4. Implement phase slices with `craft`, loading the plan Reference before rediscovering files.
5. End each phase with verification, hardening/polish if needed, and memory upkeep.

### Continuing previous work

When resuming:

1. Look for a feature plan, current diff, branch/tag naming, existing module memory, or user-provided handoff.
2. Load the plan's Reference section first if it exists.
3. Load module memory only for touched modules. For UI work, also read `modules/<module>/ui.md` when present.
4. Re-enter the right mode: `craft`, `audit`, `polish`, `harden`, or `adapt`.
5. At phase end, surface promotion candidates. Inside a feature plan, memory refresh and re-stamp follow `.agent-kit/common/process/planning/execution-loop.md` steps 5 and 7; outside one, refresh memory only when warranted.

### Memory bridge

- Plans carry active intent for unfinished work.
- Module memory carries durable knowledge learned from real work.
- `/ui-design` may read module UI memory and report promotion candidates.
- `/ui-extract` writes or refreshes `modules/<module>/ui.md`.
- `/module-extract` may delegate UI-specific extraction to `/ui-extract`.
- Full module re-extraction is manual, never an automatic result of UI implementation.
