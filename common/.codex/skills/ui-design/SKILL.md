---
name: ui-design
description: Use for UI design and frontend experience work: shaping, crafting, auditing, polishing, hardening, or adapting interfaces across web, mobile, React, Svelte, React Native, iOS, Android, and design systems.
---

Use this skill for UI design, frontend experience, and visual UX work.

Read these first:

- `.agent-kit/ui/core.md`
- `.agent-kit/ui/workflow.md`
- `.agent-kit/ui/commands.md`
- `.agent-kit/ui/registers.md`
- `.agent-kit/ui/verification.md`

If `.agent-kit/common/process/agent-dispatch.md` exists, read it and use it for inline vs dispatch and model-tier decisions. Do not duplicate dispatch policy in UI docs.

If `.agent-kit-local/modules/_root/ui.md` exists, read it first — it is the project's design-language anchor (palette, type, spacing, motion, register, anti-references). Honor it over generic guidance.

If `.agent-kit-local/modules/INDEX.md` exists and the task touches an existing module, follow the `/modules` loading flow for the relevant module so freshness checks and drift banners run. For UI work, also read `.agent-kit-local/modules/<module>/ui.md` when it exists.

Then load only the references needed for the task:

- Audit: `.agent-kit/ui/audit.md`
- Polish: `.agent-kit/ui/polish.md`
- Harden: `.agent-kit/ui/harden.md`
- Adapt: `.agent-kit/ui/adapt.md`
- Web: `.agent-kit/ui/platforms-web.md`
- React Native: `.agent-kit/ui/platforms-react-native.md`
- iOS: `.agent-kit/ui/platforms-ios.md`
- Android: `.agent-kit/ui/platforms-android.md`
- Svelte: `.agent-kit/ui/frameworks-svelte.md`
- React / Next / Remix: `.agent-kit/ui/frameworks-react.md`

The framework list is a menu, not a requirement: if the project's framework has no entry (Angular, Vue, Solid, …), load `.agent-kit/ui/platforms-web.md` plus the project's own `conventions/frontend/` and neighbouring components, and say you did. Never invent a `frameworks-<name>.md` path — an unlisted framework means the file is absent, not that you missed it.

Before code changes, load the implementation rules, in this order.

**1. Always read `.agent-kit/frontend/core.md`** — the framework-neutral frontend invariants: service
layer, response contract, where code goes, third-party widgets that replace the node you hand them, error
surfacing, mobile-first ordering. Read on every stack, including one that ships no frontend layer at all.
**Then, from that same directory, only the `framework-<value>.md` matching `frameworks.frontend`** in
`.agent-kit-local/structure.yml` — the framework's own standard. ⚠ Never glob that directory whole: those
variants contradict each other by design. ⚠ All of it is the **code** rules; the `.agent-kit/ui/` docs
above are the visual and accessibility bar. Neither restates the other.

**2. Then load the stack's own implementation conventions when present** — `conventions/frontend/`, plus
the mobile, platform or design-system docs the task touches. Prefer neighboring files and existing
components over new abstractions. ⚠ **Where the two differ, the stack doc wins.**

⚠ **Three different things are called "frontend" here, and two of them now hold a `framework-<value>.md`
under that same name.** Keep them apart:

| Path | What it is |
|---|---|
| `.agent-kit/frontend/` | neutral invariants (`core.md`, always) + the framework's neutral standard — step 1 |
| `.agent-kit/common/conventions/frontend/` | this stack's own layer — step 2, and it **wins over both** |
| `.agent-kit/ui/frameworks-<name>.md` | the UI toolkit's craft docs listed above — note the plural `frameworks-`; chosen by task, never by the manifest |

In the first two, **`framework-*.md` are variants of one doc, not peers**: read only the one matching `frameworks.frontend` in `.agent-kit-local/structure.yml` — the declared value IS the suffix (`svelte` → `framework-svelte.md`) — and resolve the two directories independently. Everything else in either glob, including an unsuffixed `framework.md`, is an ordinary doc.

- **Undeclared, or no manifest** — read every `framework-*.md` in **both** directories, say so plainly, and point at `/structure-extract`. Never guess a default.
- **Declared, no matching file** — say that directory ships no standard for that framework and carry on; do not read the others instead. A framework with none written yet is a gap, not a verdict on it.

For new UI work, produce planning material first when direction is unclear; `/feature-plan` owns the committed feature file. During or after implementation, surface durable UI knowledge as a promotion candidate; use `/ui-extract` only when writing or refreshing module UI memory is warranted.

Proceed with the work after loading the relevant docs. Ask only when the visual/product direction is materially ambiguous or required project context is missing.
