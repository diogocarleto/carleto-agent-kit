## UI Commands

These modes are invoked through the single `/ui-design` entry point. `shape` and `craft` are documented inline below — they have no separate detail doc. `audit`, `polish`, `harden`, and `adapt` each own a detail doc that is the source of truth; their one-liners say when to use the mode and which doc to load.

- **`shape`** — Produce a design brief, no code edits. Detail lives here: cover target user, job to be done, register, platform/framework constraints, information architecture, primary layout, key components, states, responsive/device behavior, verification plan, and explicit out-of-scope items.
- **`craft`** — Build a UI slice; run `shape` first when direction is not obvious. Flow: detect context → load docs → implement the slice → harden states → verify → patch defects → summarize. See `workflow.md` for the full phase map.
- **`audit`** — Review without editing unless the user asks for fixes. Load `audit.md` (coverage, P0/P1/P2 severity rubric, output format).
- **`polish`** — Improve quality without changing product behavior or architecture. Load `polish.md`.
- **`harden`** — Make the UI robust under hostile but realistic conditions. Load `harden.md`.
- **`adapt`** — Translate an existing UI or direction to another platform, framework, or register. Load `adapt.md`.
