---
name: module-extract
description: Extract a module's memory — read its source (+ README) and produce/refresh .agent-kit-local/modules/<module>/module.md (and internals.md / per-domain files when warranted). Use to turn a Stub into Documented, or to refresh a module after big changes. Pass the module name as the build declares it (e.g. the web module's artifact/package id).
---

Generate or refresh the on-demand **module memory** for a module. The goal is
NON-OBVIOUS, slow-to-rederive knowledge — never a class listing or API mirror.
If `Read`/`grep` answers it fresh, it does not belong in the file. See
`.agent-kit/modules/README.md` for the full philosophy, layout, and the
never-eager-load rule.

Target module = the skill argument, or infer from context. Module dir =
`<module-name>` — the name the build declares for it (artifact id, package name, directory). When
the dir is the root of the repo that owns the module (a single-module repo), the row keeps the
module's name and reads `` `<name>` (repo root) `` (INDEX header).

## Pipeline

**When the phase loop runs this** (`execution-loop.md` step 5), skip every stamp — footers and INDEX
**Verified** — and the kit copy: step 7 does them against the phase commit.

### 1. Extract — dispatch a reader (don't read it all yourself)
Dispatch a **`sonnet` Explore** subagent (escalate to `opus` only if it self-declares
the module too tangled). Tell it to:
- **Read `<module-dir>/README.md` and any `docs/` first** as the authoritative *usage*
  source, then verify against code (READMEs drift). Note if absent.
- Sweep `<module-dir>/src/main/java/**`, and skim `git log` for decisions behind the
  current shape ("collapse X", "remove Y") — these become gotchas.
- Return a **structured report** keyed to the template sections (Purpose &
  boundaries · Domains/areas + which 1–2 are complex enough for their own file ·
  Usage/public surface: SPIs, extension points, config · Internals: key entry points
  + non-obvious cross-file flows · Gotchas/decisions with commit/ADR · Pointers).
- Include the self-escalation clause: if complexity exceeds the tier, stop and hand
  back findings + a recommended tier rather than guessing.

### 2. Verify — fact-check the report against source
Before writing anything, confirm the report's claims. Spot-check `Default*` impls,
SPI defaults, config keys, and flows against the actual files. **Historical claims
("X used to be Y") need a `git show <commit>` check — current source can't confirm
them.** Correct or drop anything WRONG/UNVERIFIABLE. Check a composed diagram's edges the same way.

### 3. Compose — distill into the template (you do this, not the subagent)
Copy `.agent-kit/modules/TEMPLATE.md` structure and fill from the *verified*
report. **Write per `.agent-kit/common/process/authoring/doc-style.md`, plus any other `*.md` in that directory (clear + concise + accurate)** —
altitude first (shape/relationship/gotcha, NOT grep-able field names/signatures), one idea
per line, max one parenthetical per item. Apply the subtractive quality filter — cut
signatures, class lists, and anything obvious. **Write present tense about the module's current state — like API docs for a consumer, not a dev log:** strip every slice/phase number, review-round, "Done/green" status, test-run anecdote, and "previously/used-to" chronology (that lives in `.agent-kit-local/planning/`); the footer is a single `sha`+date stamp, never a changelog. Decide the **adaptive split** (README → "Layout"):
- Small/leaf module → single `module.md` (Usage + Internals + Gotchas).
- Big consumer-extension module → `module.md` (usage + orientation) + `internals.md`
  (technical depth + gotchas).
- Unwieldy domain(s) the reader flagged → `<domain>.md` each.
Match the voice/structure of existing files so modules read as templates for each
other. **Diagram (optional):** every `*.md` under `.agent-kit/common/process/diagrams/` — glob it;
`diagrams.md` → *In module memory*, drawn from verified source. If the module has meaningful UI, frontend, mobile, native, route, screen, or
visual-flow knowledge, delegate that part to `/ui-extract` instead of inlining UI
extraction rules here; it writes or refreshes `ui.md`. **If this extraction changed the
project's structure** (added/removed a module, a new frontend dir, a framework or
dependency change) — most often when extracting `_root` — **or `.agent-kit-local/structure.yml`
does not exist yet, delegate to `/structure-extract`** to refresh or create it; don't hand-edit the
manifest here. Without it, a seed's stamp cannot be checked: its owning checkout is found through
`related_projects`. **Run the
doc-style tighten pass (cut ~25%) before saving.** Stamp each file's footer with the current commit SHA + date
(`git rev-parse --short HEAD` and `date +%F`) — naming the owning repo beside the SHA whenever the
module is not built in this one or its memory ships with the kit, since that is where the stamp
has to be resolved.

### 4. Review + fix loop (until clean)
Before registering, audit each composed file against `.agent-kit/common/process/authoring/`
**and** accuracy. Dispatch a reviewer (or self-review) checking: **altitude** (zero
grep-able field/signature detail), **economy** (no stacked parentheticals; every line
changes what an agent would do), **scannability**, every **⚠ gotcha + pointer/link intact**,
**load-bearing claims still accurate**, and any **diagram** against `diagrams.md`. Apply fixes, re-review, **loop until the
reviewer has no blockers or mechanical fixes left**. Only then proceed.

### 5. Register
If `.agent-kit-local/modules/INDEX.md` is absent, create it from
`.agent-kit/modules/INDEX.template.md` first — seed a row per buildable unit (`Stub`)
plus the reserved `_root` row.
Flip the module's row in `.agent-kit-local/modules/INDEX.md` from `Stub` →
`Documented` (or `Partial` if you only got a skeleton), add the file links including
`ui.md` when `/ui-extract` wrote one, and set
the **Verified** column to the same short SHA you stamped in the footers
(`git rev-parse --short HEAD`). That SHA is the freshness anchor — keep INDEX and
footers identical.
In the repo that owns a module whose memory the kit ships (its name is in the stack's
`stack.yml` → `modules:`; the stack's checkout is `.synced-from` → `stack_source:`, or `source:`'s `stacks/` for a stamp
without it), also copy every changed doc to `<stack_source>/<stack>/modules/<name>/`, run the
`verify.sh <stack>` at the top level of that repo (`git -C <stack_source> rev-parse --show-toplevel`;
no `verify.sh` there → say so in the phase update, never skip silently) and
commit only those paths there — every other consumer gets it on reinstall, and an unpromoted edit is reverted by `--reset-defaults`.

## Refresh weight — re-stamp vs re-extract

For an already-`Documented` module, size the work to the drift, never one-size-fits-all:

- **Re-stamp** (cosmetic drift — formatting, renames, no change to shape/SPI/flow/gotcha):
  read the existing doc, confirm it still holds against source — **its diagram's edges too** — bump the **Verified** SHA + footers. No full pipeline.
- **Re-extract** (semantic drift — public surface, SPI, flow, or gotcha changed, or
  drift is large): run the full pipeline above on the affected file(s) only.

When unsure, re-extract — but don't re-extract a module whose drift is purely cosmetic.

## `--audit` — read-only freshness sweep

`/module-extract --audit` writes **nothing**. It reads `INDEX.md` and, for every `Documented`
row, **validates the anchor and then** computes drift from the **Verified** SHA — all of it in
the repo that owns the module (this one, or the `source_project` checkout for a module consumed
as a prebuilt artifact: `.agent-kit-local/structure.yml` → `module_sources`, path from
`related_projects`, or the repo the doc's footer names when `structure.yml` does not). The drift
formulas and the two validation commands live in the INDEX header — so **no `INDEX.md` means
nothing to sweep**: say that, point at `/module-extract <module>` to create it, and stop.

**Validate first, because both failures are silent.** A SHA belonging to another repo exits 128
with no number; a SHA that *does* resolve here matches no `<module-dir>` pathspec, so drift
answers `0` and the row reads FRESH forever. That false-fresh is what this sweep exists to catch,
so it must never be what the sweep reports. Print one line per documented module:

```
<module>   <verified-sha>   <N> commits behind   [FRESH | STALE]
<module>   <verified-sha>   UNVERIFIABLE — <reason>
```

Then recommend the repair per row — they differ: **STALE** → re-stamp or re-extract, weighted by
drift. **UNVERIFIABLE** → pull the repo that owns the module, and if it still fails, re-stamp
**from there**; its stamp names the wrong repo or a commit that checkout lacks, not merely an old
one, and re-extracting fixes nothing. Never print a number or
FRESH for an UNVERIFIABLE row. This is the deliberate hygiene sweep — it catches memory that
rotted without anyone loading it. A module dir with no `INDEX.md` row (a stack seeded it) is not
swept: the repo that owns the module gives it a row to bring it in; elsewhere, the owner's sweep covers it.

## Automatic refresh (per-phase)

The phase loop (`.agent-kit/common/process/planning/execution-loop.md` steps 5 and 7) drives the *targeted* auto-path:
if a module the phase edited has memory, step 5 refreshes what the phase changed, and any doc in
the row that no longer holds, at the weight above — content only — and step 7 re-stamps **only
that module** in the phase-close commit, once the phase commit exists — every phase. For UI edits, refresh `ui.md` when it already exists and UI surfaces, flows, or
gotchas changed; its footer is re-stamped with the rest of the row either way. If `ui.md` is absent and the
phase produced non-obvious UI knowledge worth preserving, surface `/ui-extract <module>`
as a follow-up instead of auto-creating it. `--audit` is **not** run per-phase (a whole-repo
sweep every commit is noise) — it stays manual. A whole-module re-extract is **never** automatic.

## Target `root` — project-level memory

`/module-extract root` documents the **project as a whole** — the on-demand deep
counterpart to the eager `architecture.md`/`CLAUDE.md`. Same 5-step pipeline, scoped
wider:
- **Source:** the **root `README.md` first** (the project's authoritative overview —
  usually where this lives; a root `ARCHITECTURE.md` often does NOT exist — read it only
  if present), then go deep into the code to trace **cross-module wiring**: flows that
  span 3+ modules (request lifecycle, event backbone, multi-tenancy, auth), how modules
  compose and why. NOT any single module's internals.
- **Compose into** `modules/_root/module.md` (orientation + mental model), splitting big
  cross-cutting concerns into `_root/internals.md` or `_root/<concern>.md` (e.g.
  `auth.md`, `multitenancy.md`) per the adaptive split.
- **Quality filter (critical):** do NOT duplicate the eager `architecture.md` or any
  per-module memory — only project-wide, non-obvious knowledge.
- **Register:** flip the `_root` row in `INDEX.md` to `Documented`.

## Don't
- Don't paste full method signatures, field lists, or whole config tables — point to
  the source/README instead.
- Don't duplicate convention/layer rules that already live in `architecture.md` or
  the `/backend` docs.
- Don't add any of these files to the `CLAUDE.md` `@import` chain — module memory is
  on-demand only.
