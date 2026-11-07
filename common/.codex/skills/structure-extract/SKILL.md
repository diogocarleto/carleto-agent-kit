---
name: structure-extract
description: Generate or refresh a project's structure manifest (.agent-kit-local/structure.yml) — the machine-readable index card of languages, frameworks, layer roots, reviewer-routing globs, module provenance, and related local projects. Companion to /module-extract (which delegates to it); also independently invocable. Use to create the manifest for a new project, or to refresh it after a structural change (new module, new frontend dir, framework swap, changed dependencies).
---

Generate or refresh the project-local **structure manifest** at `.agent-kit-local/structure.yml`.
It is the cheap, machine-readable counterpart to the prose module memory: the orchestrator and the
shared reviewer agents read it to ROUTE work without loading `/modules`. Keep it FACTUAL and small —
if it is derivable in one read it belongs here; reasoning and flows belong in module memory.

Read these first:

- `.agent-kit/structure.template.yml`
- every `*.md` under `.agent-kit/common/process/authoring/` — glob that directory

## Source the facts (don't guess)

Derive every field from the repo, not from memory — confirm paths exist before writing them:

- **languages / frameworks** — from whichever manifest the repo has: `pom.xml` / `build.gradle` (JVM deps + version), `package.json`, `pyproject.toml` / `requirements.txt`, `go.mod`, `Cargo.toml`, `*.csproj`,
  `package.json` (`svelte`/`react`/`vue`, `@sveltejs`, …), and any mobile project (`react-native`, Podfile).
- **frameworks.database / frameworks.frontend** — the two keys that also select a convention **variant**.
  Derive the candidate from the repo (the driver/client dependency or datasource URL for the database,
  `package.json` for the frontend). ⚠ The value IS a filename suffix, and **the delivered files are the
  enum**: list `.agent-kit/common/conventions/backend/`, `.agent-kit/common/conventions/frontend/`
  **and the neutral `.agent-kit/persistence/` and `.agent-kit/frontend/`** and write the suffix of the
  `persistence-…` / `framework-…` file that is actually there (`persistence-mongodb.md` → `mongodb`,
  never `mongo`; `framework-angular.md` → `angular`, never `ng`). A value is valid if a matching
  variant exists in **either** directory of its key — the stack's layer or the neutral one. Nothing maps
  the two, so a near-miss selects nothing at all. No variants shipped in either, or no such layer → omit
  the key; never guess one.
- **layers.*** — `src_globs` / `test_globs` / `root` / `build` from the actual directory layout
  (`src/main/java`, the web app dir) and the build files.
- **routing.*_globs** — the patterns that map a changed file to a reviewer. Default backend = `**/*.java`
  (+ `pom.xml`, `*.properties`); frontend = the web dir's component + style files (e.g. `.svelte`/`.tsx`/`.vue`/`.ts`/`.css`). Tighten to real paths.
  These globs are the contract the reviewer agents read — get them right.
- **modules** — the buildable units; cross-check `pom.xml` `<modules>` / `settings.gradle`.
- **module_sources** — provenance, the high-value non-obvious part. For each `io.<org>:*` dependency
  consumed as a JAR, set `consumed_as: jar` + `source_project`. For packages whose source lives in THIS
  repo (vendored copies, local modules), set `vendored` / `source`. Get `consumed_as` right — it tells an
  agent whether the source is editable here or lives elsewhere.
- **related_projects** — auto-detect the obvious entries (the `source_project`s from `module_sources`).
  The "leverageable sibling" entries are partly human-declared — propose, let the user confirm. Paths
  repo-root-relative; keep the best-effort/machine-specific note.
- **verified** — `git rev-parse --short HEAD`.

## Write

1. If `.agent-kit-local/structure.yml` is absent, copy `structure.template.yml` and fill it.
2. If it exists, refresh changed fields **in place** and preserve human-declared `related_projects`.
3. Run the `doc-style.md` tighten pass on the comments — terse, accurate, no filler.
4. Report what changed (added/removed modules, framework changes, provenance edits) and bump `verified`.

## Relationship to /module-extract

`/module-extract` **delegates** here — the same way it delegates UI memory to `/ui-extract`: whenever it
writes or refreshes `_root` or a module whose structure changed, it calls `/structure-extract` to keep the
manifest fresh. This skill is also independently invocable: a project that already has `module.md` can run
it alone to (re)generate the manifest without a full module re-extract.
