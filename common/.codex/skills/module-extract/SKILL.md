---
name: module-extract
description: Extract a module's memory in this project — read its source (+ README) and produce/refresh .agent-kit-local/modules/<module>/module.md (and internals.md / per-domain files when warranted). Use to turn a Stub into Documented, or to refresh a module after big changes.
---

Generate or refresh the on-demand **module memory** for a module. Goal: NON-OBVIOUS,
slow-to-rederive knowledge — never a class listing or API mirror. If `Read`/`grep`
answers it fresh, it does not belong in the file. See
`.agent-kit/modules/README.md` for the philosophy, layout, and never-eager-load
rule; copy the structure of `.agent-kit/modules/TEMPLATE.md`.

Target module = the provided name, or infer from context. Module dir =
`<module-name>` — the name the build declares for it (artifact id, package name, directory). When
the dir is the root of the repo that owns the module (a single-module repo), the row keeps the
module's name and reads `` `<name>` (repo root) `` (INDEX header).

**When the phase loop runs this** (`execution-loop.md` step 5), skip every stamp — footers and INDEX
**Verified** — and the kit copy: step 7 does them against the phase commit.

1. **Extract** — dispatch a read-only exploration subagent at the *multi-file scan* tier, escalating one
   tier only if it self-declares the module too tangled. Take the model from
   `.agent-kit/common/process/agent-dispatch.md` → Step 2 and the effort from the plan (never hard-code
   model names here — they drift). Tell it to:
   - **Read `<module-dir>/README.md` and any `docs/` first** as the authoritative *usage*
     source, then verify against code (READMEs drift). Note if absent.
   - Sweep `<module-dir>/src/main/java/**` and skim `git log` for decisions behind the
     current shape ("collapse X", "remove Y") — these become gotchas.
   - Return a **structured report** keyed to the template sections (Purpose &
     boundaries · Domains/areas + which 1–2 are complex enough for their own file ·
     Usage/public surface: SPIs, extension points, config · Internals: key entry
     points + non-obvious cross-file flows · Gotchas/decisions with commit/ADR ·
     Pointers).
   - Self-escalation: if complexity exceeds the tier, stop and hand back findings +
     a recommended tier rather than guessing.
2. **Verify** — fact-check the report against source before writing. Spot-check
   `Default*` impls, SPI defaults, config keys, flows. **Historical claims ("X used to
   be Y") need a `git show <commit>` check — current source can't confirm them.**
   Correct or drop anything wrong/unverifiable. A composed diagram is checked the same way, node by
   node and edge by edge.
3. **Compose** — distill the *verified* report into the template (you do this, not the
   subagent). **Write per `.agent-kit/common/process/authoring/doc-style.md`, plus any other `*.md` in that directory (clear + concise + accurate)** —
   altitude first (shape/relationship/gotcha, NOT grep-able field names), one idea per line,
   max one parenthetical per item; run its tighten pass (cut ~25%) before saving. Apply the
   subtractive quality filter — cut signatures, class lists, obvious facts. **Write present tense about the module's current state — like API docs for a consumer, not a dev log:** strip every slice/phase number, review-round, "Done/green" status, test-run anecdote, and "previously/used-to" chronology (that lives in `.agent-kit-local/planning/`); the footer is a single `sha`+date stamp, never a changelog. Decide the
   **adaptive split** (README → "Layout"): small module →
   single `module.md`; big consumer-extension module → `module.md` (usage +
   orientation) + `internals.md` (technical + gotchas); unwieldy domain(s) →
   `<domain>.md` each. **Diagram (optional):** every `*.md` under `.agent-kit/common/process/diagrams/` — glob
   it; `diagrams.md` → *In module memory*, drawn from verified source. If the module has meaningful UI, frontend, mobile, native,
   route, screen, or visual-flow knowledge, delegate that part to `/ui-extract`
   instead of inlining UI extraction rules here; it writes or refreshes `ui.md`.
   If this extraction changed the project's structure (added/removed a module, a new
   frontend dir, a framework or dependency change) — most often when extracting `root` — or
   `.agent-kit-local/structure.yml` does not exist yet, delegate to `/structure-extract` to
   refresh or create it; don't hand-edit the manifest here. Without it, a seed's stamp cannot be
   checked: its owning checkout is found through `related_projects`. Match the voice/structure of existing files. Stamp each footer
   with the current commit SHA + date (`git rev-parse --short HEAD` and `date +%F`) — naming the
   owning repo beside the SHA whenever the module is not built in this one or its memory ships
   with the kit, since that is where the stamp has to be resolved.
4. **Review + fix loop (until clean)** — before registering, audit each composed file
   against `.agent-kit/common/process/authoring/` **and** accuracy: altitude (zero grep-able
   field/signature detail), economy (no stacked parentheticals; every line earns its place),
   scannability, every ⚠ gotcha + pointer/link intact, load-bearing claims accurate, any diagram
   against `diagrams.md`. Apply
   fixes, re-review, loop until no blockers remain.
5. **Register** — if `.agent-kit-local/modules/INDEX.md` is absent, create it from
   `.agent-kit/modules/INDEX.template.md` first (seed a row per buildable unit as
   `Stub`, plus the reserved `_root` row). Then
   flip the module's row in `.agent-kit-local/modules/INDEX.md` from
   `Stub` → `Documented` (or `Partial` for a skeleton), add the file links
   including `ui.md` when `/ui-extract` wrote one, and set the
   **Verified** column to the same short SHA stamped in the footers
   (`git rev-parse --short HEAD`). That SHA is the freshness anchor — keep INDEX and
   footers identical. In the repo that owns a module whose memory the kit ships (its name is
   in the stack's `stack.yml` → `modules:`; the stack's checkout is `.synced-from` → `stack_source:`,
   or `source:`'s `stacks/` for a stamp without it), also copy every changed doc to
   `<stack_source>/<stack>/modules/<name>/`, run the `verify.sh <stack>` at the top level of that repo
   (`git -C <stack_source> rev-parse --show-toplevel`; no `verify.sh` there → say so in the phase
   update, never skip silently) and commit only those paths there — every other consumer gets it on reinstall, and an unpromoted edit is reverted by
   `--reset-defaults`.

**Refresh weight — re-stamp vs re-extract.** For an already-`Documented` module, size
the work to the drift: **re-stamp** (cosmetic drift — formatting/renames, no change to
shape/SPI/flow/gotcha) → confirm the doc still holds, its diagram's edges too, bump the **Verified** SHA +
footers, no full pipeline; **re-extract** (semantic drift, or large drift) → run the
full pipeline on the affected file(s) only. When unsure, re-extract — but never
re-extract a module whose drift is purely cosmetic.

**`--audit` — read-only freshness sweep.** `/module-extract --audit` writes nothing. It reads
`INDEX.md` and, per `Documented` row, **validates the anchor and then** computes drift from the
**Verified** SHA — all of it in the repo that owns the module (this one, or the `source_project`
checkout for a module consumed as a prebuilt artifact: `.agent-kit-local/structure.yml` →
`module_sources`, path from `related_projects`, or the repo the doc's footer names when
`structure.yml` does not). The drift formulas and the two validation commands live in the INDEX
header — so **no `INDEX.md` means nothing to sweep**: say that, point at `/module-extract
<module>` to create it, and stop.

Validate first, because both failures are silent: a SHA belonging to another repo exits 128 with
no number, and a SHA that *does* resolve here matches no `<module-dir>` pathspec, so drift answers
`0` and the row reads FRESH forever. That false-fresh is what this sweep exists to catch, so it
must never be what the sweep reports. Print one line per module —
`<module> <sha> <N> commits behind [FRESH|STALE]`, or `<module> <sha> UNVERIFIABLE — <reason>` —
then recommend the repair, which differs per state: **STALE** → re-stamp or re-extract, weighted
by drift; **UNVERIFIABLE** → pull the repo that owns the module, and if it still fails, re-stamp
**from there**, since its stamp names the wrong repo or a commit that checkout lacks rather than
an old one, and re-extracting fixes nothing. Never print a
number or FRESH for an UNVERIFIABLE row. This is the manual hygiene sweep — it catches memory that
rotted without anyone loading it. A module dir with no `INDEX.md` row (a stack seeded it) is not
swept: the repo that owns the module gives it a row to bring it in; elsewhere, the owner's sweep
covers it.

**Automatic refresh (per-phase).** The phase loop (`.agent-kit/common/process/planning/execution-loop.md`
steps 5 and 7) drives the targeted auto-path: if a module the phase edited has memory, step 5
refreshes what the phase changed, and any doc in the row that no longer holds, at the weight
above — content only — and step 7 re-stamps only that module in the phase-close commit, once the phase commit exists — every phase. For UI edits, refresh `ui.md` when it
already exists and UI surfaces, flows, or gotchas changed; its footer is re-stamped with
the rest of the row either way. If `ui.md` is absent and the phase produced non-obvious UI knowledge worth
preserving, surface `/ui-extract <module>` as a follow-up instead of auto-creating it.
`--audit` is not run per-phase (a whole-repo sweep every commit is noise); a whole-module
re-extract is never automatic.

**Target `root` — project-level memory.** `/module-extract root` documents the project as a whole (the on-demand deep counterpart to the eager `architecture.md`/`AGENTS.md`). Same pipeline, scoped wider: source the **root `README.md` first** (usually where the overview lives; a root `ARCHITECTURE.md` often does NOT exist — read only if present), then go deep into the code to trace **cross-module wiring** — flows spanning 3+ modules (request lifecycle, event backbone, multi-tenancy, auth), how modules compose — not one module's internals. Compose into `modules/_root/module.md` (+ optional `_root/internals.md` / `_root/<concern>.md` per the adaptive split). Do NOT duplicate the eager `architecture.md` or per-module memory. Flip the `_root` row in `INDEX.md` to `Documented`.

Don't: paste full signatures / field lists / whole config tables (point to
source/README); duplicate convention rules from `architecture.md` or the backend docs;
add any of these files to an eager-loaded file (`AGENTS.md`/`CLAUDE.md`/`GEMINI.md`
import chain). Module memory is on-demand only.
