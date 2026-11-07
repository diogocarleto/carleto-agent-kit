<!--
Copy this file to .agent-kit-local/modules/INDEX.md and fill in the rows (or let
/module-extract do it — it creates the file from this template when absent).

Seed one row per buildable unit, `Stub` until documented, plus the reserved `_root`
row. Keep it a POINTER LIST — never paste module content here. A unit whose dir is the root
of the repo that owns it (a single-module repo) keeps its module name: its Module cell reads
`` `<name>` (repo root) `` (the marker outside the backticks, like `` `_root` (project) ``), its
memory dir is still `<name>/`, and its drift takes the repo-wide form below.

This file is PROJECT-OWNED: an install never writes it, not even for the module memory a
stack seeds. A seeded module therefore arrives with no row here, and /modules picks it up
anyway, reading its stamp from the footer. Only the repo that owns the module gives it a row —
elsewhere the row's Verified would lag the footer after every reinstall.
-->

# Module Memory — Index

`/modules` reads this manifest first, then `Read`s only the file(s) the task needs.
The **Hook** column is a search-keyword set for picking the right module, *not* a
canonical purpose — `architecture.md`'s module table owns that.
`_root` is the reserved **project-level** row (cross-module overview) — load with
`/modules root`, generate with `/module-extract root`.
See `.agent-kit/modules/README.md` for how this layer works and the never-eager-load rule.

**Verified** is the freshness anchor: the commit SHA the memory was last fact-checked
against — read by `/modules` (load banner) and `/module-extract --audit`. It anchors every
module **with a row**; a stack-seeded module outside the repo that owns it has none, and carries
its stamp in its doc's `Last verified:` footer.

**Validate the anchor before computing drift.** All three commands run **in the repo that owns
the SHA** — this repo for a module built here, the `source_project` checkout for one consumed as
a prebuilt artifact. Skipping 1 and 2 is how a stamp reports FRESH forever:

```bash
# 1. the SHA resolves HERE. A SHA from another repo exits 128 ("bad revision") and prints no number.
git rev-parse --verify <verified-sha>^{commit}
# 2. the module path existed at that commit. Must PRINT the path — empty output means it did not,
#    and the exit status is 0 either way, so the emptiness is the test.
git ls-tree -d --name-only <verified-sha> -- <module-dir>
# 3. drift, only once 1 and 2 both passed
git rev-list --count <verified-sha>..HEAD -- <module-dir>
# _root, or a module marked (repo root): repo-wide, minus agent-doc/meta paths — step 2 does not apply.
# Add an exclude for any directory another installer writes into the repo root.
git rev-list --count <verified-sha>..HEAD -- . \
  ':(exclude).agent-kit' ':(exclude).agent-kit-local' ':(exclude).claude' \
  ':(exclude).codex' ':(exclude).cursor' ':(exclude).vscode/settings.json' \
  ':(exclude).github/copilot-instructions.md*' ':(exclude).synced-from' \
  ':(exclude).user-kit' ':(exclude).user-kit-local'
```

Three states, and two of them have **different remedies**:

- `0` → **FRESH**.
- `N>0` → **STALE**: source moved N commits since verification. Treat the doc's specifics as
  claims to confirm, not as wrong. (Over-reports on formatting-only commits by design: a false
  "go verify" is cheap; a false "all fresh" is not.) Fix by re-stamping or re-extracting.
- step 1 or 2 failed → **UNVERIFIABLE**. Report that word plus the reason — **never a number and
  never FRESH**, because step 3 cannot tell you anything here. Fix by pulling the repo that owns
  the module, then — if it still fails — re-stamping **from there**: the stamp names the wrong
  repo, or a commit that checkout does not have.
  That is a different repair from stale, so do not report the two the same way.

⚠ For a module consumed as a **prebuilt artifact** the **Verified** SHA belongs to the *source*
project, not this one (`structure.yml` → `module_sources.<module>.source_project`, path from
`related_projects`) — and where `structure.yml` names no source, the doc's `Last verified:` footer
names the owning repo beside the SHA. Both silent failures live here, and steps 1–2 exist to catch
them: a source SHA does not resolve in this repo, and a SHA that *does* resolve here matches no `<module-dir>`
pathspec, so drift returns `0` and reports FRESH forever. Compute drift in the source checkout,
and re-sync the doc from there rather than re-extracting from the artifact.

| Module | Memory | Status | Verified | Hook |
|--------|--------|--------|----------|------|
| `_root` (project) | — | Stub | — | Project-wide: mental model, cross-module flows, how the pieces compose |
| `<module-name>` | — | Stub | — | <search keywords: subsystems, domains, distinctive terms> |

**Status vocabulary:** `Documented` (has a usable `module.md`) · `Stub` (not yet written
— falls back to `architecture.md`'s one-line table) · `Partial` (`module.md` exists but is
a skeleton / flagged incomplete). Optional `internals.md`, `<domain>.md`, and `ui.md` are
enrichment — a module is `Documented` without them.

When you write or refresh a module's memory, flip its row to `Documented`, add the link,
and set **Verified** to the current short SHA (`git rev-parse --short HEAD`) — matching
the doc's footer stamp.
