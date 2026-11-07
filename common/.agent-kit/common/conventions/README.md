# Conventions — closed peer-layer taxonomy

Convention docs load by **directory glob**, not by enumerated filename. A stack varies the *files
inside* these folders; it never invents a new top-level folder. This is what lets the agent kit work
unmodified across tech stacks: skills/agents/Makefile name fixed directories and read whatever `.md`
files live there.

## Layout

```
.agent-kit/common/conventions/
  backend/                         # backend layer conventions (depth-1 glob target)
    code-style.md design-principles.md api.md testing.md …   # set varies by stack — glob, never assume names
    persistence-<db>.md             # VARIANT FAMILY: one per database, selected by frameworks.database
    messaging/   messaging.md       # companion: loaded by /messaging
    migration/                      # companion: loaded by /migrate (no stack ships one yet)
    recipes/     new-domain.md  new-dcr.md   # companion: loaded by /scaffold + /dcr
  frontend/                        # frontend layer conventions (depth-1 glob target)
    framework-<name>.md             # VARIANT FAMILY: one per framework, selected by frameworks.frontend
  mobile/                          # peer layer — LOADABLE: /mobile globs it, and the generated
                                   #   code reviewer inlines it. Absent until a stack fills it
  desktop/                         # peer layer — RESERVED, not loadable: the name is held in the
                                   #   taxonomy, but NO skill globs it and no reviewer reads it, so
                                   #   a doc placed here installs and is never read. Activating it
                                   #   means adding /desktop the way /mobile was added
```

## Invariants

- **Closed peer-layer taxonomy** — the top-level folders are exactly `backend/`, `frontend/`,
  `mobile/`, `desktop/`. A stack NEVER adds a top-level folder; it only fills files. Adding a peer
  layer is a deliberate kit-level change (new folder + new layer skill), never per-stack.
- **Companions nest under a layer** — e.g. `backend/messaging/`, `backend/migration/`,
  `backend/recipes/`. A companion is loaded by a companion skill (`/messaging`, `/migrate`, `/scaffold`,
  `/dcr`) that composes with the parent layer skill.
- ⚠ **Default to a depth-1 `.md`; a companion is a KIT change, not a stack change.** Dropping
  `caching.md` into `backend/` costs one file and nothing else. A `backend/caching/` companion needs a
  skill in **both** harness mirrors, an entry in the Makefile's parity list *and* its skill-pointer
  list, and — because that skill then fires on **every** stack, including ones with no such layer — a
  neutral `core.md` of its own under `.agent-kit/`, telling it what to do when the directory is absent
  (see how `/messaging`, `/dcr` and `/migrate` do it). Earn that only when the concern is one of many in the layer and most tasks
  never touch it, so loading it with every `/backend` would be waste.
- **Depth-1 layer glob** — a layer skill (`/backend`, `/frontend`) reads `conventions/<layer>/*.md`
  only, NOT nested companion subdirs. Companion skills read their subdir. This depth-1 boundary is the
  lazy-separation mechanism; do not make the layer glob recursive.
- **Directory-purity** — only these layer/companion dirs are globbed, and a globbed dir contains only
  docs that always load together. Select-by-task docs (the UI toolkit under `.agent-kit/ui/`) and
  on-demand docs never sit inside a globbed convention dir.
  ⚠ **One exception, and it is a mechanism: a VARIANT FAMILY.** `<concern>-<value>.md` at depth-1 of a
  layer dir is one doc in several versions, not several peers; the layer skills **and the code reviewers**
  (persistence in backend/fullstack, framework in frontend/fullstack) read only the variant whose suffix matches `frameworks.<key>` in `.agent-kit-local/structure.yml`. Two families ship **in
  convention dirs**: `backend/persistence-<db>.md` (← `frameworks.database`) and
  `frontend/framework-<name>.md` (← `frameworks.frontend`). ⚠ `frameworks.frontend` also selects a
  variant *outside* these dirs — the framework's own standard in `.agent-kit/frontend/` — and so does
  `frameworks.database`, with the engine's own standard in `.agent-kit/persistence/`; each pair is
  resolved independently and neither falls back to the other.
  The suffix IS the selector, so a variant stays a file drop — and nothing else in a globbed dir may be
  conditional, because nothing else carries one. An unsuffixed `<concern>.md` has no selector either, so
  it loads like any other doc.
- **Beside the layers, not in them: `.agent-kit/backend/`.** The language-neutral backend invariants
  (`core.md`, the code-style kernel; `design-principles.md`; `logging.md`) are read by the backend skills and
  reviewers on every stack. No variant family — every depth-1 `.md` there is read — and the stack's backend
  docs **win** where the two differ, so the stack doc that holds a file's topic opens with a "Read together
  with `.agent-kit/backend/<file>.md`" line (`code-style.md` for `core.md`).
  What belongs there rather than in the stack: `.agent-kit/backend/reference/adding-backend-rules.md`.

## Adding or renaming a convention doc

Drop a `.md` into the right layer (or companion) folder. No skill, agent, or Makefile edit is needed —
they glob the directory.
