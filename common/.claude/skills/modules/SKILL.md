---
name: modules
description: Load on-demand module memory — non-obvious knowledge about how a specific module works (purpose, public SPIs, internal flows, gotchas). Use when starting work in or against a module (e.g. a web module, or a framework module consumed as a prebuilt dependency), or when a sub-project needs to know how to use a framework module it depends on as a prebuilt dependency. Optionally pass a module name.
---

Load module memory for the task. These files are **on-demand only** — they are
never part of the always-on context.

1. **Read the manifest first:** `.agent-kit-local/modules/INDEX.md`. Then list
   `.agent-kit-local/modules/` — a directory holding a `module.md` but no row is memory a stack
   seeded (an install never writes INDEX.md); treat it as `Documented`.
2. **Pick the module(s)** relevant to the current task:
   - If a module name was passed as an argument, use it.
   - For project-wide orientation — cross-cutting/exploratory work, or `/modules root` —
     read `.agent-kit-local/modules/_root/module.md` (the project memory) first.
   - Otherwise infer from the files/packages you are about to touch (e.g. work under
     a domain package under the web module → `<web-module>`).
3. **`Read` the module file:** `.agent-kit-local/modules/<module-name>/module.md`.
   - If a sibling file exists (`.agent-kit-local/modules/<module>/internals.md`, or a per-domain
     `.agent-kit-local/modules/<module>/<domain>.md` when the task is scoped to one domain), read it
     too. `/module-extract` splits a big module into `module.md` (usage) + `internals.md` (depth), so
     skipping the second loses half the memory of exactly the modules deep enough to need it.
   - If the task touches UI, frontend, mobile, native, routes, screens, views, design
     systems, or visual behavior and `.agent-kit-local/modules/<module>/ui.md`
     exists, read it too.
   - Do **not** read every module's memory — read only what the task needs.
4. If the module's row is `Stub` (no `module.md` yet), fall back to the one-line
   description in `.agent-kit-local/context/architecture.md` and proceed. If it is
   `Partial`, read what exists but treat its gaps as unverified — fall back to source
   / `architecture.md` for anything the file doesn't cover.
5. **Check freshness (load banner).** For a `Documented` module, read its **Verified** SHA from
   `INDEX.md`; a module with no row takes it from the doc's `Last verified:` footer. Neither →
   banner **UNVERIFIABLE** — an unstamped doc is never fresh. Every command below runs **in the
   repo that owns the module** — this repo, or the `source_project` checkout for one consumed as a
   prebuilt artifact (`.agent-kit-local/structure.yml` → `module_sources`, path from
   `related_projects`); when `structure.yml` does not name it, the footer does, beside the SHA.
   No path to that checkout (no `structure.yml`, or no `related_projects` entry for it) → banner
   **UNVERIFIABLE** with that reason, and suggest `/structure-extract` — never a re-stamp.

   **Validate the anchor before counting drift.** Both failures are silent:
   - `git rev-parse --verify <verified-sha>^{commit}` must succeed — a SHA belonging to another
     repo exits 128 ("bad revision") and produces no number at all.
   - `git ls-tree -d --name-only <verified-sha> -- <module-dir>` must **print** the path — empty
     output means the module is not in this repo. Exit status is `0` either way, so the emptiness
     is the test, and this is the dangerous one: a pathspec matching nothing makes drift answer
     `0`, i.e. FRESH forever. Skip it for `_root` and a module marked `(repo root)`.

   Either check failing → banner **UNVERIFIABLE**; never a number, never fresh:
   > ⚠ `<module>` memory is UNVERIFIABLE — `<sha>` does not resolve here / that commit has no
   > `<module-dir>`. The stamp names the wrong repo, or a commit this checkout hasn't pulled, so
   > drift means nothing. Confirm the doc against source; if pulling doesn't fix it, re-stamp —
   > only from the repo that owns the module.

   Both passing → drift is `git rev-list --count <verified-sha>..HEAD -- <module-dir>` (for
   `_root` or a module marked `(repo root)`, the repo-wide form minus the meta-doc paths — see the
   INDEX header). If `> 0`:
   > ⚠ `<module>` memory is N commits behind source (verified `<sha>` → HEAD). Treat
   > its specifics as claims — confirm against source before relying on them.

   `0` drift → no banner. Do **not** refresh from this read-time skill — refreshing is
   `/module-extract`'s job, and UNVERIFIABLE needs a different repair from stale: a re-stamp
   from the right repo, not a re-extract.

Apply what you learn to the task. If, while working, you make a fix or refactor
that **recurs** (you have applied the same correction before), surface it as a
**promotion candidate** — do **not** write docs from this read-time skill. The
recording happens in `.agent-kit/common/process/planning/execution-loop.md` step 5 (module-specific → that module's memory;
cross-cutting → `design-principles.md`/`code-style.md` (the kit owner routes it: the stack's doc, or `.agent-kit/backend/`), needs confirmation). See
`.agent-kit/modules/README.md` → "Promotion loop".

Do not ask for confirmation to load — proceed with the work.
