---
name: ui-extract
description: Extract or refresh module-specific UI memory at .agent-kit-local/modules/<module>/ui.md for web, mobile, React, Svelte, React Native, iOS, Android, routes, screens, UI flows, design-system usage, and visual verification gotchas.
---

Generate or refresh the on-demand **UI memory** for a module.

Read these first:

- `.agent-kit/ui/extract.md`
- `.agent-kit/modules/README.md`
- `.agent-kit/modules/TEMPLATE.md`
- `.agent-kit-local/modules/INDEX.md`

Also read every `*.md` under `.agent-kit/common/process/authoring/` — glob that directory; it sets the budget for what you write.

Then load only relevant UI references for the module's platform/framework:

- `.agent-kit/ui/core.md`
- `.agent-kit/ui/registers.md`
- `.agent-kit/ui/verification.md`
- `.agent-kit/ui/platforms-web.md`
- `.agent-kit/ui/platforms-react-native.md`
- `.agent-kit/ui/platforms-ios.md`
- `.agent-kit/ui/platforms-android.md`
- `.agent-kit/ui/frameworks-svelte.md`
- `.agent-kit/ui/frameworks-react.md`

Target module = provided name, or infer from the changed files/routes/packages.

Write or refresh `.agent-kit-local/modules/<module>/ui.md` only when the module already has `module.md` and the UI knowledge is non-obvious and likely to recur. Do not create generic checklists or component inventories. If general module memory is missing, stop and report `/module-extract <module>` as the required first step instead of running it automatically.

Update `.agent-kit-local/modules/INDEX.md` with the `ui.md` link when you write UI memory. Bump the module row's Verified SHA only after confirming every memory file linked in that row still holds and re-stamping all their footers to the same SHA. Do not add UI memory to always-loaded context.
