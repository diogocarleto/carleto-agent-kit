<!--
Copy this file to modules/<module-name>/module.md and fill it in.

ADAPTIVE SPLIT (see README → "Layout"):
  • Default: keep Usage + Internals + Gotchas all in module.md.
  • Big consumer-facing module: keep Usage + orientation here; move the
    "Internals" + "Gotchas" sections to a sibling internals.md (same headings).
  • Unwieldy domain: move its flow/gotchas to <domain>.md (Internals+Gotchas spirit,
    drop the Usage scaffolding).
  • Meaningful UI surface: add ui.md for routes/screens/flows/platform gotchas after
    module.md exists. Generate with /ui-extract; do not put generic UI rules here.

PROJECT-LEVEL (_root/): reuse this template with project framing — Purpose = what the
whole project is; Domains/areas = its modules; Usage = how to navigate/compose them;
Internals = cross-module flows; Gotchas = project-wide. Source from the root README
(+ ARCHITECTURE.md only if present), then deep code inspection. Generated via
`/module-extract root`.

Golden rule: capture NON-OBVIOUS, slow-to-rederive knowledge. Not a class list.
If `Read`/`grep` answers it fresh, leave it out.

STYLE: write to `.agent-kit/common/process/authoring/` (clear + concise + accurate). Respect
altitude (shape/relationship/gotcha, not grep-able field detail) and run its tighten pass
before saving.
-->

# <module-name> — module memory

> **Purpose (one line):** …
> **Depends on:** … · **Consumed by:** … · **Artifact/dir:** `acme-<x>`
> *(If internals/UI/domains were split out, add: internals → `internals.md`; UI → `ui.md`; domains → `<domain>.md`.)*

## Purpose & boundaries

- What this module is responsible for.
- What it must **not** do — responsibilities that live in other modules (name them).

## Domains / areas

One line per sub-package. Link `→ <domain>.md` / `→ internals.md` where one exists.

| Area | Owns | Detail |
|------|------|--------|
| `…`  | …    | (→ `<domain>.md`) |

## Usage / public surface  *(consumer-facing)*

For agents that depend on this module as a prebuilt artifact and cannot read its source.

- **SPIs / extension points** — interface, its `Default*` impl, when to override.
- **How to wire / register** — what a consumer implements, what enum/registry to touch.
- **Config** — the `*ConfigProperties` knobs that matter and their effect.

<!-- Sections below stay here for small modules, or move to internals.md for big ones. -->

## Internals  *(framework-dev-facing)*

- **Key entry points** — the 5–10 classes that matter and the role of each (a map, not signatures).
- **Non-obvious flows** — control flow that spans files (e.g. "order simulation: service → calculator → validator → …"). A flow may be one diagram: `.agent-kit/common/process/diagrams/diagrams.md` → *In module memory*. A feature's `### Shape` diagram lands here when promoted (`.agent-kit/common/process/planning/execution-loop.md` → code-anchor lifecycle) only if it passes that gate — redrawn from what shipped, never pasted; otherwise carry the lesson as prose.

## Gotchas / decisions

- Things a future editor would likely get wrong, and why the current shape is deliberate.
- Link the commit/ADR where useful.

**Use a failure-mode table wherever the gotcha has a visible symptom.** A reader arrives holding a
symptom, not a cause — indexing by symptom is what makes the entry findable at the moment it is
needed, where prose is only found by someone already reading the doc end to end.

| Symptom | Cause | Fix |
|---|---|---|
| what you actually observe — an error, a silent wrong result, a hang | the non-obvious reason | the change that resolves it |

⚠ Keep it to failures that are **silent or misleading**. A failure whose error message names its own
fix is one the source already tells you about — leave it out.

## Pointers

- Entry-point classes worth reading first.
- The module's own `README.md`/`docs/` if present (point to it, don't copy it).
- Optional UI memory (`ui.md`) if this module owns meaningful routes, screens, flows, or platform-specific visual behavior.
- ADRs / related module memories (`→ modules/<other>/module.md`).

---
<!-- Module not built in this repo? Name the owning repo between the SHA and the date — a stamp
     whose repo is neither named here nor in structure.yml can only ever read UNVERIFIABLE. -->
*Last verified: `<commit-sha>` (<YYYY-MM-DD>). Update when a phase changes this module's flow, public surface, or contracts.*
