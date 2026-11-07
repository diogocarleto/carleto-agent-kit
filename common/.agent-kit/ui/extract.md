## UI Memory Extraction

Use this when writing or refreshing module-specific UI memory at
`.agent-kit-local/modules/<module>/ui.md`.

### Purpose

Capture non-obvious, slow-to-rederive UI knowledge for one module. This is not a
generic design checklist and not a component inventory.

Write `ui.md` only when future UI work would otherwise waste time rediscovering:

- routes, screens, views, or native screens owned by the module
- primary user flows and where they enter/exit the module
- component, store, service, navigation, or data-loading boundaries that are not obvious
- design-system dependencies and deliberate local deviations
- web vs React Native vs native platform differences for the same feature area
- visual, accessibility, responsive, safe-area, localization, or state gotchas
- verification entry points: dev route, Storybook story, test, simulator path, screenshot flow

Do not write:

- generic contrast, overflow, accessibility, or platform rules
- framework basics
- every component file
- token/CSS inventories that are cheap to search
- implementation detail likely to churn every commit

### Pipeline

1. Identify the target module from the argument, changed files, route tree, package, or module index.
2. Read `.agent-kit-local/modules/INDEX.md` and confirm the module has an existing
   `module.md`. If it does not, stop and report `/module-extract <module>` as the
   required first step. UI memory is enrichment, not the module entry point.
3. Read existing `module.md` and existing `ui.md` if present. If `ui.md` is absent,
   create it only when the module has meaningful UI knowledge.
4. Inspect source narrowly: routes/screens/views, shared UI components, state stores/hooks, services used by the UI, tests/stories, and platform entry points.
5. Load only relevant UI references from `.agent-kit/ui/` for the platform/framework.
6. Compose concise memory:
   - Purpose line
   - Surfaces / routes / screens
   - Primary flows
   - State and data boundaries
   - Design-system dependencies
   - Platform variants
   - Gotchas
   - Verification entry points
   - Footer: `Last verified: <sha> (<YYYY-MM-DD>)`
7. Update `.agent-kit-local/modules/INDEX.md`:
   - add `ui.md` to the module's Memory links
   - keep the existing `Status`
   - set `Verified` to the same short SHA only after confirming every memory file
     linked in the module row still holds, and re-stamping their footers too

### Refresh weight

- Re-stamp when source moved but UI surfaces, flows, states, and gotchas still hold.
- Refresh affected sections when a UI flow, route/screen ownership, state boundary, platform variant, or verification entry point changed.
- Because `INDEX.md` has one module-wide freshness anchor, bump `Verified` only when
  every linked memory file in the row has been checked and stamped to the same SHA.
- Do not full-extract general module memory. If general memory is missing or stale, report `/module-extract <module>` as a follow-up.

### Relationship to other skills

- `/ui-design` reads `ui.md` during UI work; it does not write memory unless phase upkeep asks for it.
- `/module-extract` may delegate UI-specific extraction here; it should not duplicate these rules.
- `/modules` reads `ui.md` only for UI, frontend, mobile, native, or design-system tasks.
