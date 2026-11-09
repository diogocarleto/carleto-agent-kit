# Contributing to carleto-agent-kit

This repo is the kit's source, the catalog `./install.sh` copies from. This file is for changing it: how to
set up, check and submit a change, then the delivery model a change must not break. To install the kit into a
project, read the [README](README.md) instead.

- [Getting started](#getting-started): prerequisites, the gate, commits, pull requests
- [The loop that makes "overwrite" the right behaviour](#the-loop-that-makes-overwrite-the-right-behaviour):
  where an improvement belongs
- [Why some files are generated](#why-some-files-are-generated) · [Why each seed is a seed](#why-each-seed-is-a-seed)
  · [Shared ↔ project boundary](#shared--project-boundary)
- [What belongs in a stack convention doc](#what-belongs-in-a-stack-convention-doc--and-what-does-not) ·
  [Authoring a companion](#authoring-a-companion-from-a-real-project-source)
- **[Adding a stack](#adding-a-stack)**: a runnable recipe
- [Generalization seam](#generalization-seam-known) · [Guardrails](#working-on-the-kit--guardrails) ·
  [Dispatching a review](#dispatching-a-review-of-a-kit-change) · [Verify a change](#verify-a-change)

## Getting started

**You need** `bash`, `make`, `python3` and `git`, as for an install, plus `node`: the gate runs a plan-lint
test with it and skips that one check without it, so install it to see the whole gate.

**The gate is plain `./verify.sh`.** Run it before every commit. It installs each stack into a gitignored
sandbox, `.scratch-target/`, and asserts the result; `./verify.sh <stack>` runs one stack. Details:
[Verify a change](#verify-a-change). Never run `./install.sh` into this checkout: the gate refuses a repo
that has installed itself (see *This repo is the exception*, below).

**Commits.** One line, imperative and scoped, `fix(<area>): <what changed and why it matters>`, with a body
only when the diff cannot show the reasoning. **No `Co-Authored-By` trailer**, whatever your tool defaults to.
The bar is
[`common/.agent-kit/common/process/authoring/doc-style.md`](common/.agent-kit/common/process/authoring/doc-style.md)
→ *Commit messages*.

**Pull requests.** Fork, branch, make the change, run `./verify.sh` until it passes, open a PR. Say in the
description whether the change lives in `common/` (true of every stack) or in `stacks/<s>/` (true of one),
and why: [the loop](#the-loop-that-makes-overwrite-the-right-behaviour) explains the radius. A stack of your
own that you do not want to contribute stays in a repo of yours:
[docs/private-overlay.md](docs/private-overlay.md).

## The loop that makes "overwrite" the right behaviour

**Improvements travel to the kit first, then back out by reinstall.** A consumer that discovers a
convention, a trap or a better rule does not keep it locally — it lands in `common/` (true of every
stack) or `stacks/<s>/conventions/` (true of one), and the next `./install.sh` delivers it to that
consumer *and every other one on the same stack*. That round trip is the product: one source of truth,
improved from real work, redistributed.

So **Shared** being wiped and rebuilt on every install is not a hazard to design around — it is what
enforces the loop. A local edit to `.agent-kit/` is not a lost improvement, it is an improvement that
never got promoted. (The exception is **Seed**: those a project may legitimately diverge on forever,
and when someone consolidates one, they copy it back upstream the same way.)

Two rules follow, and they are why the rest of this document is shaped the way it is:

- **Promote to the right radius.** Framework-neutral → `common/`. True of one stack → `stacks/<s>/`.
  Project-only → stays project-side in `.agent-kit-local/{planning,structure.yml}`, any decision add-on's settings file and any module memory
  the project wrote, which install never touches. (It does write `.agent-kit-local/context/`, plus the
  `modules/<name>/` dirs the stack declares — those are the only things `install.sh` puts under that
  tree.) Getting the radius wrong ships one framework's specifics to every stack — see *What belongs in
  a stack convention doc*.
  ⚠ **Module memory has the same three radii as a convention doc**, and the middle one is new: memory for
  a module *the stack's framework owns* is true of every consumer of that stack, so it belongs in
  `stacks/<s>/modules/<name>/` rather than being re-extracted (and re-stamped, often wrongly) in each
  project. Memory for a module the project itself owns stays project-side and is never shipped.
- **A generic consumer promotes into its own new stack**, not into `stacks/generic/`. That directory is
  shared by consumers that share no framework, so anything specific placed there reaches all of them —
  see *Adding a stack*. ⚠ Do not lean on the gate here: `verify.sh` greps a generic install for
  build-tool instructions, but the patterns are JVM-shaped, so a Go or Python convention landing in
  `stacks/generic/` would pass silently.

## Why some files are generated

**Why Codex `AGENTS.md` is generated, not shipped** (no *shipped* `AGENTS.md` lives in `common/`)**:** Claude
reads `CLAUDE.md`, which uses `@import` — so it's a tiny static seed that just points at the Tier-0 docs.
Codex has **no `@import`** — and never auto-loads `.codex/AGENTS.md` itself; in a trusted project it receives
the same body as `developer_instructions` in `.codex/config.toml` — so the file must still physically *contain* the
concatenated Tier-0 content (including the project-local `context/` docs, which differ per consumer). It
therefore can't be a static shipped file — it's generated in each consumer by the Makefile's
`sync-main-context` target (the header +
skill-pointer list live inline in that target's `printf`, then it `cat`s the Tier-0 docs). `code-reviewer.md`
is generated the same way (it inlines the convention docs because the reviewer can't lazy-load mid-review).

**Cursor is a third harness, generated like Codex.** Cursor reads `.cursor/rules/*.mdc` natively, but
we can't rely on it eager-expanding `@file` references under `alwaysApply` (undocumented) — so its
always-on rule (`.cursor/rules/agent-kit.mdc`) **inlines** the same Tier-0 body as `AGENTS.md` (the
`sync-cursor-rule` target just prepends `.mdc` frontmatter and `cat`s `AGENTS.md`). Cursor needs no
skill files of its own: it **auto-discovers** the kit's skills from `.claude/skills/` + `.codex/skills/`,
so only Tier-0 is synced for it. ⚠ Cursor reads *both* skill dirs, so a skill may surface twice
(cosmetic — both resolve to the same conventions via glob).

**VS Code Copilot is a fourth harness, generated like Codex.** VS Code natively reads Claude's own
directories — it **auto-discovers** skills from `.claude/skills/` and subagents from `.claude/agents/`
(Claude sub-agent format, mapping Claude tool names), so those need no VS Code-specific files. It also
loads `.claude/CLAUDE.md` as always-on instructions, but — like Codex and Cursor — it does **not** expand
Claude's `@import` chain, so the Tier-0 standing context would go missing. The fix mirrors Cursor: the
`sync-copilot-instructions` target **inlines** the six Tier-0 docs into `.github/copilot-instructions.md`
(no skill-pointer list — VS Code discovers skills itself — and no frontmatter). The seeded
`.vscode/settings.json` sets `chat.useClaudeMdFile:false` and `chat.useAgentsMdFile:false` so that
generated file is the single always-on source, instead of also double-loading the unexpanded
`.claude/CLAUDE.md` and the project's own root `AGENTS.md`.

The consumer-facing half of this, moved to the [README](README.md) where a newcomer needs it, holds the
generated files and the `.github/copilot-instructions.md` backup
([The three delivery natures](README.md#the-three-delivery-natures)), the seed-refresh table and its
byte-equality proof ([Seeds refresh only while untouched](README.md#seeds-refresh-only-while-untouched)),
and what `--reset-defaults` replaces and keeps
([What each install touches](README.md#what-each-install-touches)). This repo generates none of the
generated files: its `.codex/AGENTS.md` is hand-written and tracked, per *This repo is the exception* under
*Working on the kit — guardrails*.

## Why each seed is a seed

Seed files are **canonical defaults, not throwaway seeds** — the kit holds the source of truth and a
consumer may diverge locally, which is the one carve-out from the promotion loop above. ⚠ The lifecycle
must stay byte-equality: a seed a project never touched follows the kit, and the previous stack's untouched
`context/` seed is replaced on a switch. Weaken either and a consumer freezes on its first install's
defaults.

Why each seed file is a seed (default-customizable) rather than fully shared/overwritten:
- **`CLAUDE.md`** — the Claude entrypoint; a project may add project notes. *Kit-standard* (same skeleton
  for every stack), so it lives in `common/.claude/` (seeded, not swept into the overlay that overwrites
  `skills/` + `agents/`), not per-stack.
- **`settings.json` (Claude) + `.codex/rules/default.rules` (Codex) + `.cursor/permissions.json` (Cursor) + `.vscode/settings.json` (VS Code Copilot)** —
  the **default agent permissions** the kit needs in a consumer (build/git/read tools — `mvn`, `npm`,
  `jshell`, `mongosh`, the `/ui-detect` runner, … — plus the opt-in peer-dispatch verbs). All four are pre-filled per-repo permission files,
  **seeded if absent, refreshed while untouched, replaced by `--reset-defaults`**. Claude reads `settings.json` natively; Codex
  reads `.codex/rules/*.rules` (execpolicy `prefix_rule`) and the project's own `.codex/config.toml`
  (which also carries the kit's instructions — see *Why each seed is a seed* below) **when the project is trusted** in
  `~/.codex/config.toml` — set by Codex's own first-run trust prompt, or by hand; the kit neither sets
  nor checks it; Cursor reads `.cursor/permissions.json` (`autoRun`, plain-English) under the
  Auto-review run mode; VS Code reads `.vscode/settings.json` (`chat.tools.terminal.autoApprove`, per-repo).
  A project may add its own grants; `settings.local.json` is **not used** and is
  deleted on `--reset-defaults`. These are the platform *applications*; the harness-agnostic *policy*
  (what's granted & why, the trust gate, what to never allowlist, what stays project-specific) lives in
  the on-demand `process/reference/allowed-commands.md`. ⚠ Unlike the other three, a consumer often already has a
  project `.vscode/settings.json`; the kit only seeds it **when absent**, so pre-existing editor settings
  are preserved (but `--reset-defaults` replaces it outright). **Two keys are the exception**:
  `chat.useClaudeMdFile: false` and `chat.useAgentsMdFile: false` are **merged into** a pre-existing
  file, because VS Code defaults both to `true` and would then *also* load `.claude/CLAUDE.md` with its
  `@import` chain unexpanded — a pointer list with no content — and this project's own root `AGENTS.md`,
  on top of the correct `copilot-instructions.md`. Seeding only-if-absent meant neither key reached the
  consumers most likely to need them. Nothing else in the file is touched, an existing value for either
  key is left alone, and a file carrying comments is warned about rather than rewritten (a JSON
  round-trip would eat the comments).
- **`claudeMdExcludes`** (also in `.claude/settings.json`) — Claude's own exclude lever, a **generated**
  key beside the permissions above. Full mechanics and the per-tool picture:
  *[Only the kit's instructions load](README.md#only-the-kits-instructions-load)*. It lives in
  `settings.json`, not `settings.local.json`: `--reset-defaults` deletes the latter, which would erase the
  excludes on the very run meant to restore defaults.
- **`.codex/config.toml`** — Codex's trust-gated project settings; `project_doc_max_bytes = 0` is the
  seed, same lifecycle as the permission files above. `developer_instructions` is a **generated** value
  layered on top: `make -C .codex sync-agents` writes it between `# >>> agent-kit generated` /
  `# <<< agent-kit generated` markers, holding the same Tier-0 body as `.codex/AGENTS.md` — regenerated
  every install, even into a project-edited file. A `developer_instructions` the project set itself,
  outside those markers, is left alone and reported (a second key would be invalid TOML). In a project
  trusted in `~/.codex/config.toml` this is how Codex gets the kit's instructions — it never auto-loads
  `.codex/AGENTS.md`; untrusted, it falls back to the project's own root `AGENTS.md`.
- **`context/` (`architecture.md`, `build-commands.md`)** — the always-on **"context" tier**: the module
  map + how to build/test. For a framework stack these are ~stack-canonical (they describe the framework +
  standard build); a project's genuinely divergent knowledge lives in the module memory it writes itself.
- **`modules/<name>/` (optional)** — on-demand **module memory** for the modules the stack's own framework
  owns. Every consumer of a stack consumes the same framework modules, so each one hand-maintaining a copy
  is duplicated work with four stamps to keep honest instead of one. A seed, not Shared, because a project
  may legitimately add what *it* learned about that module — and once it does, the file is its own.
  ⚠ It lands in `.agent-kit-local/modules/`, beside the project's own memory, so install seeds **only the
  names `stack.yml` declares**; nothing else under that directory is ever read or written, and `INDEX.md`
  (project-owned — install cannot know a consumer's row order) is never written at all. `/modules` picks
  up a seeded module dir that has no row.
  ⚠ Unlike `context/`, a **stack switch leaves the old stack's module dirs in place** — they are simply
  no longer declared, so nothing reads or writes them. Deliberate: deleting from a project-owned tree is
  the sweep the name-scoping exists to refuse, and the cost is low because this is on-demand Tier 1, not
  always-on Tier 0 — a stale dir with no `INDEX.md` row is loaded by nothing until someone names it.
  Removing it is the consumer's call.

## Shared ↔ project boundary

Enforced **structurally**: the *shared* trees in `common/` contain only shared files, so the overlay
copy can never touch project-OWNED content. What is kept, and what `--reset-defaults` replaces:
*[What each install touches](README.md#what-each-install-touches)*. Two things only this section says:

- ⚠ `modules/` is the one project-owned directory a stack can also write into, by declared name only
  (see *Why each seed is a seed* above); the name list is what keeps the two apart, so never widen seeding to a sweep.
- `.codex/AGENTS.md` is not in the wiped set, so a stale copy survives an install that cannot regenerate
  it. ⚠ **`.codex/agents/code-reviewer.md` does not**: it sits under `.codex/agents/`, which `install.sh`'s step 1 wipes,
  and it is rebuilt only `if command -v make` — without `make` it is **deleted, not stale**, which defeats
  the "commit them so a teammate without `make` still gets the standing context" rationale for that one
  file.

## What belongs in a stack convention doc — and what does not

A stack-specific companion (`/messaging`, `/scaffold`, `/dcr`) documents **how to use** the layer on this
stack: which annotation, what to name things, the wiring you must get right, and the traps that change
what you write. It does **not** document how the underlying module works.

That distinction has **three** homes, at decreasing radius and increasing depth:

| Knowledge | Where | Why there |
|---|---|---|
| The **invariant** — what must hold on any transport, and what breaks when it doesn't | `common/.agent-kit/<companion>/` | ships to **every** stack, so it may name no framework. Distilled *from* a real stack, not surveyed — see below |
| **How to use** the layer on this stack — rules, naming, wiring, gotchas that change your code | `stacks/<s>/conventions/<layer>/…` | ships with the stack, read by the skill, same for every consumer of that stack |
| How the module *works* — flows, SPIs, config mechanics, and member names only where the flow needs them | `.agent-kit-local/modules/<module>/module.md` via `/module-extract` | project-local, regenerable, and **SHA-stamped** against the source it describes — the stamp is what makes naming a member survivable, not a licence to list them (`modules/README.md` bans grep-able detail there too) |

**Every one of the three is prescriptive** — the pattern to apply, not a survey of what current code
happens to do. They differ in radius, not in register.

⚠ **The neutral layer is distilled, not invented.** Its content is the best practice we can lift out of a
concrete stack — for messaging, the first stack that shipped it — restated so it holds on any transport. That provenance
is what makes it worth loading: *"a catch must never sit inside whatever is doing the retrying"* is in
`core.md` because it was found in shipped code, not because a survey of brokers proposed it. Both ways of losing it cost the same: emptying it into platitudes that burn a read and change nothing,
or filling it with the stack's class names, which fails the neutrality gate on the next `generic` install.

⚠ **The same fact appearing in all three layers is correct, and is not duplication to clean up.** Retry
placement is the worked example: `core.md` states the invariant and why it bites; the stack doc states the
annotation and the outer/inner split that expresses it *here*; module memory holds which internal method
catches what. Each layer is written for a reader who has it and the ones above it — never the ones below.
So a stack doc that is thin on a topic is not a gap to fill with mechanism; it means the invariant above
it is already carrying the weight, and the depth below it is `/module-extract`'s job on **any** stack.

The test: *does a reader have to act on this to write correct code?* If yes it is a convention; if it
only explains why, it is module memory. Internal machinery a consumer never touches — a drain throttle,
which private method holds a retry loop — is neither: leave it out.

⚠ **Sharper test: the module source is reachable, so anything derivable from it does not belong here.**
A consumer has the framework as a sibling checkout or in the same repo, so an agent unsure of a config
key, a signature or a class name can go read it — and a copy here is both redundant *and* a drift
liability the moment the framework evolves. What the source cannot tell you is **the prescription**:
which of several workable shapes this stack has settled on, and **what fails silently** if you pick
another. That is the whole job of a stack convention doc. A settings table, an annotation's parameter
list, a walkthrough of the module's own README — all derivable, all out. "A handler that is not
registered is never invoked, and nothing warns you" — not derivable without reading the registry's
implementation, and it changes what you write. That one stays.

⚠ **Apply the test, do not guess from the name.** "Infrastructure" sounds like something the platform
provides, and often it is not. On two stacks wrapping forks of one messaging module, it creates **no** outbox indexes
and never sets the outbox owner id — an existing app has them only because *that app* added them, so a
new project on the same stack must do it too. Both pass the test and both are conventions. Cutting them
as "under the hood" would have been a regression, caught only because the claim was checked against the
source rather than assumed.

⚠ **This is the drift to watch for.** Every review round that finds a factual nuance tempts you to write
it into the convention doc, and the doc slides from *how to use this* into *how it works underneath* —
one true sentence at a time, passing every gate, because no gate measures purpose. Two symptoms give it
away: naming the framework's **private members** (they rot, and a reader cannot act on them), and
explaining a mechanism where the rule plus its consequence would do. Name the rule and what breaks if
you ignore it; send the mechanism to module memory, where `/module-extract` keeps it honest against a
SHA and `--audit` reports when it drifts.

## Authoring a companion from a real project source

`/messaging` was written by reading two real framework modules and the apps that use them. Every future
companion built that way — a payments layer, a search layer, a scheduler — faces the same pull: you have
just learned a great deal, and transcribing it feels like the deliverable. It isn't. The doc has three
jobs, one prohibition, and one exception.

**1. Concepts** — the vocabulary and the moving parts, enough to *reason* about the layer: what the outbox
is for, what "registered" means here, which guarantee a topic has. Not enough to reimplement it.

**2. Usage** — how you actually use it on this stack: which annotation, what to name things, the shape to
write, and **how to test it**. The testing half is the one most often skipped and the one a reader needs
soonest.

**3. Best practices the project adopted** — the shape the team settled on among several that would work.
This half is **prescriptive**: state the pattern to apply, say so in a banner, and do not soften it into a
survey of what current code does. Legacy code that predates the practice is not a counter-argument.

**Do not carry tech detail.** Config keys and defaults, annotation attribute lists, field and index
definitions, envelope internals, how the machinery works. All of it is in the source — which is reachable
from every consumer, as a sibling checkout or in the same repo — so a copy is redundant on day one and
wrong the day the framework moves. Replace it with a **pointer**: name the module, say where it sits, and
say what to read it for. Same for experience knowledge that lives in a project's own docs (why a retry
delay is what it is, which migration applies a schema change): point at the project documentation or at
module memory, don't inline it.

**The exception, and it is the doc's most valuable content: where the source misleads or stays silent.**
A trap is not "detail" — it is the one thing a reader cannot get by going to read the code, because
reading the code is what produces the wrong answer. In `/messaging` the module's own comment says a
consumer signals failure by returning `false`, while the line beneath it tests for `null`. An agent that
follows the pointer lands exactly on the misleading comment. That sentence earns its place; a settings
table does not.

**A useful test while writing:** for each line ask *could the reader get this by opening the source?* If
yes, cut it and strengthen the pointer. If no — because it is a choice among alternatives, a silent
failure mode, or a place the source lies — keep it, and say what breaks if it is ignored.

## Adding a stack

**Where it lives.** A stack for everyone goes in this repo, under `stacks/<name>/`, as a PR. A stack for your
own framework that you keep private lives in a repo of yours, in `<your-repo>/stacks/<name>/`, and is
installed with `--stacks`: see [docs/private-overlay.md](docs/private-overlay.md). The layout and steps 1 to 4
are the same; only step 5 differs.

**The shortest runnable path**, for a backend-only stack called `acme`:

```bash
mkdir -p stacks/acme/conventions/backend stacks/acme/context
cp stacks/generic/context/*.md stacks/acme/context/    # fill-in templates for the two context seeds
$EDITOR stacks/acme/conventions/backend/code-style.md  # skeleton below
$EDITOR stacks/acme/stack.yml                          # example below
git add stacks/acme                                    # the gate refuses untracked stack files
mkdir -p .scratch-target                               # the install target must exist
./install.sh acme .scratch-target                      # look at what it laid down
./verify.sh acme                                       # the gate for this stack (it recreates .scratch-target)
```

The stack's `code-style.md` opens with its heading and the pointer to the neutral core:

```markdown
## Code Style

Read together with `.agent-kit/backend/core.md`, the stack-neutral kernel; this doc says how this stack expresses it, and wins where they differ.
```

The gate also wants the other two neutral files named. Until the stack has a doc for each topic, add their
pointers to `code-style.md`; once it does, move each to the top of its own doc:

```markdown
Read together with `.agent-kit/backend/design-principles.md` and `.agent-kit/backend/logging.md`, the stack-neutral rules; this doc keeps what this stack adds, and wins where they differ.
```

Its `stack.yml`. Every list must match the tree exactly, and a key with nothing to list is omitted. Keep
comments on their own lines: a comment after a key (`layers:  # …`) stops the key being read.

```yaml
# The directory name.
name: acme
# One line, shown by `./install.sh --list`.
description: Acme's in-house services framework, Java 21, Maven. Backend only.
# The directories directly under conventions/: backend, frontend, mobile or desktop.
layers:
  - backend
# The files in context/: the two project-local always-on seeds.
context:
  - architecture.md
  - build-commands.md
# Optional. Directories nested in a layer, each read by its own skill beside the layer.
# companions:
#   - backend/messaging
# Optional. Directories in modules/: memory for modules the stack's own framework owns.
# Install seeds exactly the names listed here and nothing else.
# modules:
#   - acme-core
```

The steps, with the rules behind them:

1. Create `stacks/<name>/conventions/backend/` (and `frontend/`, `mobile/` or `desktop/` only if you write docs
   for that layer) and drop the stack's convention docs in. Companions nest: `backend/messaging/`,
   `backend/recipes/`.
   ⚠ **A backend-only stack needs no `frontend/` directory.** `stack.yml`'s `layers` must equal the
   directories under `conventions/` (`verify.sh`'s `stack_yml_describes_its_tree`): if you do create one, even
   empty or as a placeholder, declare it in `layers`, since an undeclared one fails. `/frontend` still applies the neutral frontend standard
   that every stack gets.
   ⚠ Where consumers of this stack will
   differ on **one axis** — the database, the frontend framework — ship a variant family
   (`backend/persistence-<db>.md`, `frontend/framework-<name>.md`) rather than forking the whole stack
   to vary one doc — see *[Variant families](README.md#variant-families--one-stack-several-values-on-one-axis)*.
   A stack whose persistence sits inside another doc, or that ships one unsuffixed `persistence.md`,
   needs none of this and behaves as it always has.
   ⚠ **The neutral backend layer is already written too.** `common/.agent-kit/backend/` (`core.md`,
   `design-principles.md`, `logging.md`) reaches every
   stack, so a stack's `code-style.md` carries only how *its language* expresses it and the roles it
   defines differently (`reference/adding-backend-rules.md` says what goes where). **The rule `verify.sh`
   enforces, for any stack with a `conventions/backend/code-style.md`:** `code-style.md` names
   `.agent-kit/backend/core.md`, and each of `.agent-kit/backend/design-principles.md` and
   `.agent-kit/backend/logging.md` is named at least once by a depth-1 doc of the stack's `conventions/backend/`.
   Open the doc that holds that topic with its own "Read together with `.agent-kit/backend/<file>`" line, as
   in the skeleton above. The match is a plain substring, so a mention anywhere passes: the point is that
   text relying on the neutral file is not orphaned. A future file added to `common/.agent-kit/backend/`
   extends the rule to every stack.
   ⚠ **The engine half is already written.** `common/.agent-kit/persistence/` (`core.md` + the engine's
   `persistence-<db>.md`) reaches every stack, so a stack's `persistence-<db>.md` carries only how *its
   API* expresses those rules, plus explicit overrides where it differs. An engine with no neutral
   variant yet gets one there, not in the stack.
   ⚠ A **further** variant family is the same four edits — the variant files, the `frameworks.<key>` row in
   `structure.template.yml`, the rule in every skill that globs that directory, and one row in `verify.sh`'s
   `FAMILIES` — never a new mechanism. That row carries a `scope` (`stack` or `common`), which is the only
   thing the two kinds differ by, and the Claude reviewers that must carry the rule. The code reviewers
   read no skill, so a family needs them wired too: the selection rule in the reviewers for its layer
   (persistence: backend + fullstack; frontend: frontend + fullstack) and in
   `code-reviewer-agent-header.md`, and — for a `common`-scope family — its directory in the Makefile's
   `CODE_REVIEWER_DOCS`.
2. Add `stacks/<name>/context/{architecture.md,build-commands.md}` (the project-local seeds for that stack).
   Start from `stacks/generic/context/`.
3. *Optional:* add `stacks/<name>/modules/<module>/module.md` (+ `internals.md` / `<domain>.md` / `ui.md`)
   for each module the stack's **own framework** owns — memory every consumer would otherwise extract for
   itself. Write it with `/module-extract` against the framework checkout, exactly as a consumer would;
   it seeds to `.agent-kit-local/modules/<module>/`. ⚠ Only framework modules belong here: a module a
   *project* owns is not the same on the next consumer, and shipping it would put one project's internals
   in every other one. ⚠ **The framework checkout is where this memory stays fresh.** Install the stack there
   too, so the same docs are seeded there — and its phases refresh and re-stamp them, then promote every changed
   doc back to the stack's own repo: the `stack_source` in that checkout's `.synced-from`, which is this kit
   only for a core stack (step 7 of
   [`common/.agent-kit/common/process/planning/execution-loop.md`](common/.agent-kit/common/process/planning/execution-loop.md),
   installed as `.agent-kit/common/process/planning/execution-loop.md`). Consumers then just reinstall.
4. Write `stacks/<name>/stack.yml` — `name` and `description` (the latter is what `--list` shows), plus
   `layers`, `companions`, `context` and `modules` describing what steps 1–3 just created, as in the example
   above. `verify.sh` checks all four against the tree, so they cannot drift away from it. ⚠ `modules` is not descriptive
   prose: install seeds exactly the names listed there, so a module you forget to declare never ships,
   and there is deliberately no way to say "seed the whole directory".
5. `./install.sh <name> <target>`, then `./verify.sh <name>` to assert the install. A stack kept outside this
   repo is installed with `--stacks <repo>/stacks` and checked with `./verify.sh <name> --overlay <repo>`: an overlay
   with `stacks/` and no `verify.d/*.sh` still runs, installing and checking its stacks; add
   `<dir>/verify.d/*.sh` for checks of your own. An overlay with neither fails. Details:
   [docs/private-overlay.md](docs/private-overlay.md).

No skill/agent/Makefile edits — they glob the layer dirs. `CLAUDE.md` is kit-standard
(`common/.claude/CLAUDE.md`, seeded once) and is **not** added per stack.

## Generalization seam (known)

The core ships framework stacks (`jakarta-ee`, `quarkus`, `spring-boot`) plus `generic` — no conventions at all, for a project that just wants the skills,
agents, and process layer; `./install.sh --list` shows what is installable. `generic` is also the kit's **neutrality test**: anything framework-specific that leaks into a
shared file shows up there as a wrong instruction, which is why `verify.sh` greps a generic install for
build-tool instructions (JVM-shaped patterns only — see the caveat in *The loop that makes "overwrite"
the right behaviour*).
The shared layer is
kept **stack-neutral**: the `CLAUDE.md` seed, the skill/agent descriptions, the Codex Makefile's
skill-pointer list, and the `code-review.md` checklist all describe layers generically — per-stack
specifics live only in `stacks/<s>/conventions/` and the seeded `context/` docs. Keep that line when
adding a stack: describe generically, let the convention docs carry the framework detail.

`/messaging` used to be the standing exception: its *body* carried one framework's annotations, base
types and package prefix, yet shipped shared to every stack — inert where the backing
`conventions/<layer>/` companion was absent, and **actively wrong** where a stack shipped a *different*
messaging module (one stack's package prefix is not another's). It is now split the
way any such companion should be: invariants in the global `.agent-kit/messaging/`, framework specifics
in the stack's `conventions/backend/messaging/`, the skill body stack-blind, and the stack doc winning
where the two differ. Note this is **not** a stack override — both are read, which is why it needed no
new delivery nature (a `common/` file a stack overwrote would trip `verify.sh`'s
"shared file not delivered" check).

`/dcr` has had the same treatment, and it was not merely hygiene: its body named a build module and
one executor's method, but the live defect was the **rule** — it prescribed one stack's sequence
numbering ("one higher than the highest existing; renumber rather than inserting out of sequence") to
every stack, while another numbers a DCR by its **ticket** and takes execution order from a registered
list instead. Both stacks ship `recipes/`, so both invoked the skill and one was getting a
wrong instruction. It now has the **same two-layer shape as `/messaging`**: neutral invariants in
`.agent-kit/dcr/` (always read) plus the stack's `recipes/new-dcr.md` (read when present, and it wins).
⚠ The neutral half is not optional just because some stacks ship no `recipes/`: the skill is delivered to
**every** stack, so on one without them (`jakarta-ee`, `quarkus`, `spring-boot`, `generic`) the glob finds nothing and `core.md` is the *only* thing
the agent gets — which is exactly where it must say "this stack has no DCR layer, use its real migration
mechanism, do not invent a shape". A skill that can fire on a stack without the layer needs the neutral
half most, not least. `/migrate` has that same two-layer shape and was built neutral-first: no stack
ships a migration layer yet, so `core.md` is the whole of it on **every** stack — the `/dcr` warning
above, applied everywhere at once. `/scaffold` needs none for a different reason: it produces nothing
without a recipe, so on a stack without one there is simply nothing to say. (It also reads
`conventions/backend/` depth-1 plus `.agent-kit/backend/` and `.agent-kit/persistence/` — the recipe
writes services, mappers and tests, so the layer rules apply to what it generates.)

`/frontend` is the same shape on a **peer layer** rather than a companion, and its admission rule is
stricter than the others'. The stack frontend docs are each a **version-and-idiom snapshot of one
real app**, so almost none of their content generalizes: `.agent-kit/frontend/core.md` admits a rule
where every stack doc *already agrees*, never their union, and a candidate is dropped rather than softened when
one of them dissents — plus a trap distilled from real work that holds whatever the framework, which is
how *Third-party widgets* got in without being in any of them. ⚠ Read that agreement as suggestive, not as convergence: the docs
**share an ancestor** — the kit was bootstrapped from one app, and later frontend docs were written
with the first as their stated "good-practice source", so a shared rule may be inherited
taste rather than an independently-reached invariant. The first frontend doc written *without* the first one
as a template is the real test. Four rules were excluded on exactly that ground — inline styles, how strict
the type escape hatch is, whether a component may orchestrate several calls, and one organisation's
audit/envelope field list. Shipping any of them globally would hand a wrong instruction to a stack with
no `conventions/frontend/` to override it, which is the whole failure mode the neutral half exists to
prevent. `/fullstack` and `/ui-design` read it too, since both reach frontend code.

⚠ **Beside it now sit the per-framework standards** (`framework-<name>.md`), whose admission rule is the
opposite: researched current best practice for **one** framework, prescriptive, version-stamped. They
generalize to nothing, which is exactly why they are a **variant family** — read only where that
framework is declared, never as a set. Globbing that directory whole loads every framework's rules on
every stack at once, most of them wrong for the project and contradicting each other; `verify.sh`'s
`FAMILIES` now carries a row for it so the prose that prevents that cannot quietly go missing.
⚠ **`core.md` is not a variant** — it is the always-read peer, like any unsuffixed doc in a globbed dir. A
family sitting beside it is precisely why nothing *else* in such a directory may be conditional.

`/backend` has since taken the same two-layer shape for **persistence**: engine facts live once in
`.agent-kit/persistence/` (`core.md` + `persistence-<db>.md`), and each stack's `persistence-<db>.md`
carries only how its API expresses them. ⚠ The JPA-spec rules the `jakarta-ee`, `quarkus` and `spring-boot`
relational docs share **stay in those stacks on purpose**: they belong to the access-API axis, not the
engine, and `jakarta-ee` hedges the provider (`RUNTIME GAP`) where `quarkus` and `spring-boot` state Hibernate — so
lifting them into `common/` would ship one provider's behaviour to every stack. `verify.sh` greps the
neutral dir for persistence-API names (`hibernate`, `panache`, `@Transactional`, `mongock` …) for the same
reason it greps `messaging/` for framework names.

`/backend` has a second neutral layer, for **code style, design principles and logging**:
`.agent-kit/backend/` (`core.md`, `design-principles.md`, `logging.md`), a **core-only**
directory (no variants, no `frameworks.*` selector — the precedent is `messaging/`, `dcr/`, `migration/`)
that `/backend`, `/fullstack`, `/scaffold` and the backend and fullstack reviewers read whole at depth-1,
so a further concern is a file drop. Its admission rule is **looser** than the frontend core's, which
wants the stack docs to *already agree*: here a rule enters where **no stack that speaks to it
dissents** — silence counts as agreement — so it is only as safe as the search for dissent.
⚠ Stacks ported from one another are one lineage (`jakarta-ee`, `quarkus` and `spring-boot` were ported from
a stack that predates them and is not published here): the source stack, the ports and any fork of them count as **one** voice, so their
agreement is inherited, not independent. The independent check is a stack from outside that lineage —
e.g. a library stack with no application framework — and a rule it contradicts is its *dissenter*. That
is why `Result`, `Outcome`, `Summary`, `Context` and `Config`, the `Result`/`Summary`/`Outcome` litmus
test, the 4-parameter limit, `Enum` suffixes and `obtain*` stay in the stacks: each has a dissenter, or
fails on a non-JVM project.
It is written for the `generic` stack's Go, Python and Node projects, so `verify.sh` fails it on the
JVM, framework, logging, test and concurrency vocabulary it lists — a tripwire for the usual leaks, not
proof of neutrality. Like each of those layers it ships a `reference/adding-backend-rules.md` (on-demand,
never globbed) so the admission rule reaches whoever edits a stack, not only this file.

⚠ **The generalizable lesson, which cost two rounds to learn:** *"the stacks already carry this"*
justifies deleting a **name** from `common/`, never a **rule**. Two stacks can document the same
concept with opposite semantics, and an audit that checks only whether the framework *names* are
redundant will wave that through. Verify the rule matches on **every** stack that ships the layer
before deleting it.

## Working on the kit — guardrails

This repo is the source/catalog. **No stack's conventions apply to it** — it is markdown and shell, and
it does not install itself. The two harness entrypoints, [`.claude/CLAUDE.md`](.claude/CLAUDE.md) and
[`.codex/AGENTS.md`](.codex/AGENTS.md), are thin adapters that point back here; this file is the source
of truth for everything below.

### A consumer's agent layer comes from the kit — nothing there is authored locally

Every file install puts under `.claude/`, `.codex/`, `.cursor/`, `.vscode/`, `.github/` and `.agent-kit/`
is copied from `common/` or `stacks/<s>/`, or generated in-target by `common/.codex/Makefile` — which
install also copies from `common/`. An add-on installer can add its own lane on top. The
Shared/Seed/Generated natures describe how install treats each on a *re-run*, not where it came from.

| Consumer path | Delivered by | Nature |
|---|---|---|
| `.agent-kit/` · `.claude/{skills,agents}` · `.codex/{skills,Makefile,sync-codex-config.py}` | `overlay` / `cp` from `common/` | Shared — wiped and rebuilt |
| `.codex/agents/test-runner.md` | `overlay` from `common/.codex/agents/` | Shared |
| `.claude/CLAUDE.md` · `.claude/settings.json` · `.codex/rules/default.rules` · `.codex/config.toml` · `.cursor/permissions.json` · `.vscode/settings.json` | `seed_once` from `common/` | Seed — kept once edited |
| `.agent-kit/common/conventions/` · `.agent-kit-local/context/` · `.agent-kit-local/modules/<declared>/` | from `stacks/<s>/` | Shared · Seed · Seed |
| `.codex/AGENTS.md` · `.codex/agents/code-reviewer.md` · `.cursor/rules/agent-kit.mdc` · `.github/copilot-instructions.md` | generated by `common/.codex/Makefile` | Generated — never hand-edited |

⚠ **`.codex/agents/` holds two natures** — `test-runner.md` is shipped from
`common/`, `code-reviewer.md` is generated beside it. Install wipes the whole directory and then refills
both, so neither survives on its own.

⚠ **This repo is the exception, and it is the most confusing thing here.** `.claude/` and `.codex/` exist
at this root too, with the *same filenames* — and **none of it came from `common/`**. Each holds exactly
one hand-written, tracked file (`.claude/CLAUDE.md`, `.codex/AGENTS.md`) and nothing else; `.cursor/`,
`.vscode/` and `.agent-kit/` do not exist here at all. So when working here:

- **A `.agent-kit/…` path inside any shipped doc means `common/.agent-kit/…`.** There is no flattened
  copy. `.agent-kit-local/` is the one path that is real here — it holds the kit's own planning area (today, the doc watchlist).
- **`.claude/skills`, `.claude/agents`, `.codex/skills`, `.codex/agents` must never appear.** Their
  existence means someone ran `install.sh` here, which is what `verify.sh`'s `root_stays_uninstalled`
  gate refuses. Recover from git rather than re-running anything.
- **Codex never auto-loads this repo's `.codex/AGENTS.md`** (it reads only root-to-cwd `AGENTS.md`), so
  read it by hand or via `/peer-dispatch`.

- ⚠ **Never hand-edit generated files** (`.codex/AGENTS.md`, `.cursor/rules/agent-kit.mdc`,
  `.github/copilot-instructions.md`, `.codex/agents/code-reviewer.md` **in a consumer**). They are built
  in each consumer, which chooses whether to track them. To change them, edit the
  `common/.codex/Makefile` `printf`/glob, or the topic docs it concatenates. ⚠ Not to be confused with
  *this* repo's own `.codex/AGENTS.md`, which is hand-written and tracked.
- **Four harnesses, two natures.** Claude (`CLAUDE.md`, `@import` seed) loads Tier-0 by reference;
  Codex (`developer_instructions` in a trusted project's `.codex/config.toml`, generated with the same
  body as `.codex/AGENTS.md` — Codex never reads that file itself), Cursor (`.cursor/rules/agent-kit.mdc`),
  and VS Code Copilot (`.github/copilot-instructions.md`) inline it (generated) since none has reliable
  eager imports.
  Skills are shared: Cursor + VS Code auto-discover `.claude/skills`, and VS Code also reads subagents
  from `.claude/agents`, so no Cursor/VS Code-specific skill or agent files exist.
- ⚠ **No mechanism only one harness can run.** The four permission files (`.claude/settings.json` ·
  `.codex/rules/default.rules` · `.cursor/permissions.json` · `.vscode/settings.json`) are four
  implementations of **one** policy — parity, not a precedent for harness-specific machinery.
  Enforcement only one harness has is enforced once and prose three times, which is worse than prose
  everywhere because it hides the gap. Before proposing a gate, name what the other three do; no
  answer for all four and it stays prose — or the rule is the thing to reconsider. (Rejected on
  exactly this: a Claude `PreToolUse` hook for `shell-hygiene.md`'s leading-token rule, whose real
  finding was that the rule is violated in ~45% of this repo's own recorded Bash calls.)
- **Glob, not enumerate.** Skills/agents/Makefile name a *directory* and read-all. Adding or renaming
  a doc under `conventions/<layer>/` or `process/<companion>/` must need **zero** edits to any skill,
  agent, or Makefile.
- **`process/` has the same shape as `conventions/`** — depth-1 is the always-loaded set, nested dirs
  are companions globbed by the one audience that needs them:

  | Path | Who loads it | How |
  |---|---|---|
  | `process/*.md` — planning · agent-dispatch · shell-hygiene · terminology | every session, all four harnesses | Tier-0 — `TIER0_DOCS` in the Makefile + `CLAUDE.md`'s `@import`s |
  | `process/authoring/` | every skill that writes docs, plans or memory — **and the reviewers** | globbed |
  | `process/review/` | the code reviewers and `test-runner` | globbed |
  | `process/planning/` | `/feature-plan` and `/feature-execute` | globbed |
  | `process/dispatch/` | `/feature-plan`, `/feature-execute` and `/peer-dispatch` | globbed |
  | `process/diagrams/` | `/feature-plan` and `/module-extract` — **not** the reviewers | globbed |
  | `process/<add-on>/` (an overlay's `addons/<add-on>/`, never in `common/` or the core; [docs/private-overlay.md](docs/private-overlay.md)) | the add-on's skill; its contract also `/feature-plan` and `/feature-execute`, through the add-on manifest, when it is on — **not** the reviewers, which raise a design concern without deliberating | globbed |
  | `process/reference/` | nobody automatically | named individually, or read on demand |

  ⚠ **`process/planning/` is not `.agent-kit/planning/`.** The first is the *process* — workflow, slice
  re-evaluation triggers, the per-phase loop, the Reference's code-anchor lifecycle. The second is the
  *templates* it writes (`TEMPLATE.md`, `DIAGRAMS.md`, the ADR/RFC forms). Adjacent names, different tiers.
  Diagram rules split the same way: `process/diagrams/diagrams.md` holds what applies to any doc
  (picker, Mermaid house style, verify against code, the one-diagram module-memory rule);
  `.agent-kit/planning/DIAGRAMS.md` only what is plan-specific.

  **What stays at depth-1 is the locator, not the procedure.** `planning.md` keeps where plans live, the
  folder lifecycle, and "don't load them unprompted"; `agent-dispatch.md` keeps the two-decision gate, the
  tier table, effort, and self-escalation. Everything that only matters *while working a plan* moved into
  the two companions above — that split cut Tier-0 by ~46%.

  ⚠ Depth-1 is **always-on context on four harnesses** — the most expensive place in the kit to be
  wrong. Put a new doc there only if every session must carry it; anything else goes in a companion
  dir. That is also why `TIER0_DOCS` is enumerated rather than globbed: a glob would sweep a stray
  README into every session. `verify.sh` enforces both ends — everything at depth-1 must be in
  `TIER0_DOCS`, and `TIER0_DOCS` must name the same *files* as `CLAUDE.md`'s `@import` chain (compared
  by filename, not full path; a doc moved between dirs on only one list is caught instead by the
  generator, which hard-fails on a path that no longer resolves).
- ⚠ **`@`-imports expand ONLY in `CLAUDE.md`. Never write one in an agent or skill file.** Verified
  empirically on both, against a positive control: a spawned reviewer and an invoked skill each receive
  the literal `@../../…` string with no document body, while the same import in `CLAUDE.md` expands.
  It is documented for `CLAUDE.md` alone — agent and skill files are undocumented territory where it
  silently does nothing. **20 such lines shipped for months**: 9 across the three reviewers
  (`code-review.md`, `doc-style.md`, `architecture.md`) and 11 across `ui-design`, `ui-extract`,
  `structure-extract` and `feature-plan`. The failure is invisible by construction — a reviewer with no
  checklist still writes confident-looking findings, and `/ui-design` still gives plausible advice.
  So an agent or skill names **every** doc it needs as an explicit read: a named file or a glob
  instruction, both of which work. `verify.sh` FAILs any import-shaped `@` (`@` then `.` or `/`),
  anywhere on a line, in either harness's agents or skills.
  Skills are additionally parity-gated, so name a doc identically in both mirrors — where one needs a
  file *and* its directory, name both in both, which keeps them equal and lets `docs_name_real_files`
  catch a rename.
  ⚠ Two traps the gate had to learn: Claude expands a **mid-line** `@path` too, so the checks match the
  import *shape* (`@` then `.` or `/`) anywhere on a line, not `^@` — and that shape is also what keeps
  a Java sample line like `@Path("/orders")` from being mis-diagnosed as a dead import.
  ✅ **Do NOT add Tier-0 prose reads to an agent file — on Claude.** A subagent *inherits* `CLAUDE.md`'s
  expanded import chain (verified: a spawned reviewer had every Tier-0 doc in context with no tool
  call). The reviewers were only ever missing their own three docs, never Tier-0 — re-reading it there
  is pure cost.
  ⚠ **That verification is Claude-only, and the rule does not carry to VS Code.** VS Code reads these
  same files from `.claude/agents/`, while the kit's own seeded `.vscode/settings.json` sets
  `chat.useClaudeMdFile: false` (and `chat.useAgentsMdFile: false`) — so `CLAUDE.md` never loads there at
  all, and nobody has verified that
  a custom agent inherits `.github/copilot-instructions.md`. That is why the three code reviewers
  *do* name `architecture.md` explicitly: it matches what the Codex reviewer already inlines, and one
  cheap re-read on Claude beats a reviewer silently judging against no module graph. Applying this
  bullet mechanically would delete that line again. ⚠ If the premise holds, a VS Code reviewer is
  missing **every** Tier-0 doc, not one — naming only `architecture.md` mirrors the Codex
  generator rather than fully solving it, and the gap is unmeasured.
- **A fact true of two stacks must appear in both stack docs.** Where two stacks wrap forks of the same
  upstream module, or document one engine through two APIs, a rule stated in one doc and missing from the
  other is the defect this kit produces most — ten review rounds of one companion found one or two per pass
  by reading. The core's own such pairs are the relational `persistence-{postgres,mssqlserver}.md` twins of
  `jakarta-ee`, `quarkus` and `spring-boot`, one pair per stack.
  A coverage check in a `verify.d/` hook (an overlay's: [docs/private-overlay.md](docs/private-overlay.md)) can
  make it mechanical for **a pair**: each doc must match a pattern for every load-bearing topic.
  ⚠ Be honest about its strength — it asserts a *phrase is present*, not that the doc
  says anything true; it catches the omission, not a wrong answer. Deliberately coverage rather than a
  diff, since the two docs legitimately differ in wording and in registration behaviour.
  ⚠ **What covers the wrong answers is a list, not a gate:** a watchlist in a repo's own
  `.agent-kit-local/planning/`, if it keeps one — every claim in those docs whose truth lives in framework
  source. **Read it before editing a doc in the pair, and after the framework moves**; nothing enforces it. The core
  ships one, for the persistence twins, with no coverage gate:
  [`.agent-kit-local/planning/persistence-doc-watchlist.md`](.agent-kit-local/planning/persistence-doc-watchlist.md).
  ⚠ **Scope a coverage check to its pair on purpose.** A topic list is one module's
  *conclusions*, not questions every broker answers — a Kafka or RabbitMQ stack fails most of a list written
  for another broker, and fails two *because it is correct* (it has a dead-letter topic; a CDC outbox writes
  inside the transaction). Applied kit-wide it would contradict "Adding a stack" and be the very enumeration
  *Glob, not enumerate* forbids. A new broker needs its own list, or none.
- **Three layers, all prescriptive, at decreasing radius.** `common/.agent-kit/<companion>/` holds the
  **invariant** — distilled from a real stack (messaging's came from one real stack) and restated so it
  names no framework, because it ships to all of them. `stacks/<s>/conventions/<layer>/` holds **how to
  use** it here: rules, naming, wiring, traps that change what you write. How the module *works* — flows,
  SPIs, config mechanics — belongs in `.agent-kit-local/modules/<module>/` via `/module-extract`, which
  stamps it against a SHA and can report drift, and which **either** stack's consumers can run. ⚠ The same
  fact restated at all three depths is the design, not duplication to collapse; a thin stack doc means the
  invariant above it is carrying the weight, not that mechanism is missing.
  ⚠ **The framework source is reachable from every consumer** (sibling checkout, or same repo), so a
  stack doc must not copy what an agent could read there — a settings table, a signature, a walkthrough
  of the module's README. That is redundant on day one and wrong the day the framework moves. Carry only
  what source cannot tell you: **the shape this stack settled on, and what fails silently if you pick
  another.** *What belongs in a stack convention doc* above has the test, and *Authoring a companion from
  a real project source* is the recipe. ⚠ That is not a licence to list member names either:
  `modules/README.md` bans grep-able detail too, and the SHA is what makes naming one survivable, not a
  reason to. Naming a framework's private members in a shipped doc is the tell: a reader cannot act on
  them and they rot.
- **The tier map has one copy that ships.** The README's tier table is a summary of
  `common/.agent-kit/README.md`, which is what reaches a consumer. Change both, or drop the summary: a
  second copy drifted in both directions before. `process/` (shared) and `context/` (project-local) are the
  two halves of Tier 0, which is why the project-local docs live in a folder named `context/`.
- **Install generates, it does not lint.** It runs the Makefile's `sync-generate`, **not** `sync-agents`;
  `validate-skills` is run separately and only warns. Generation must succeed, but a prose-only mismatch
  must not abort an install after `install.sh`'s step 1 has wiped the target and leave it never rebuilt.
- **Every rename, and every new key a project must declare, gets a README *Upgrade notes* entry.**
  `structure.yml` is project-owned and install never writes it, so a reinstall alone does not carry the change.
- **Closed peer-layer taxonomy.** Top-level convention folders are exactly `backend` · `frontend` ·
  `mobile` · `desktop`. A stack only *fills files* into them; never invent a folder.
- **Claude/Codex skill parity.** Every skill — kit *and* personal — must name the same convention
  files in both `.claude/skills/<name>/` and `.codex/skills/<name>/`. Anything diverging means a Codex
  session loads different conventions than a Claude one for the same task. Two gates, because the two
  lanes live in different trees:
  - **Kit skills** → `validate-skills`, inside `make -C .codex sync-agents`, so a consumer catches drift
    in its own installed set. ⚠ **Skills are enumerated, not globbed:** adding a kit skill needs an edit to
    `SKILL_NAMES_VALIDATE` and to the `sync-main-context` pointer list (both asserted by `verify.sh`),
    plus a line in the seeded `common/.claude/CLAUDE.md` (ungated). These are deliberate exceptions to
    *Glob, not enumerate* in the shipped layer (`TIER0_DOCS` is another; `verify.sh` is meta-dev, so its
    own lists are outside that rule). The validate list is load-bearing: a wildcard would validate a
    project's own skills too and break `make sync-agents` over a difference the kit has no say in.
    Add-on skills are validated anyway, through the `.synced-from` stamp their installer writes into each
    skill dir. Anything else a project adds there is wiped on reinstall.
  - **Personal skills** → not in the core, which ships none. An overlay that ships them
    ([docs/private-overlay.md](docs/private-overlay.md)) gates them with a `verify.d/` hook of its own, which
    *does* glob its personal lane, rather than in every consumer that happens to have one installed.

  ⚠ One difference is legitimate and **excluded from both**: the Tier-0 process docs at `process/`
  **depth-1** (`planning.md` · `agent-dispatch.md` · `shell-hygiene.md` · `terminology.md`), which Claude loads by
  `@import` and Codex must name explicitly. Compare them raw and that by-design asymmetry reads as
  drift — which is exactly what kept the validated list short for so long.

  **Exclude by depth, never by filename and never the whole directory.** `validate-skills` matches
  `process/<doc>.md` and stops there, so every nested companion (`authoring/`, `review/`) stays gated
  — which is what it must do, since both mirrors reference those. Excluding all of `process/` silently
  drops them; excluding by filename means every new Tier-0 doc needs an edit here. Depth needs neither.
  A personal-lane hook in an overlay must apply the identical depth *exclusion*, deliberately — two
  exclusion rules that must agree but are written differently drift the moment a fourth Tier-0 doc
  lands. (Their surrounding *extraction* regexes differ, since the personal lane also matches
  `.user-kit*` paths.)

  ⚠ **The parity gate compares cited convention dirs, never prose** — two mirrors can name the same docs
  and still say different things. `peer-dispatch` is the live case: `common/.claude/skills/peer-dispatch/`
  and `common/.codex/skills/peer-dispatch/` (likewise any add-on skill an overlay keeps in its own `addons/<name>/`) are **hand-mirrored, not generated**, each written from its own
  orchestrator's seat, so copying one over the other would clobber deliberate differences (different
  verbs, different perspective). Editing one means editing the other **by hand**. Nothing catches a
  one-sided prose edit — this line is the only reminder.
- **A seed is only project-owned once edited.** `install.sh` proves that by byte-equality — against the
  kit version stamped in `.synced-from`, and against the previous stack's `context/` on a switch. Never
  weaken that to "the file exists": a consumer then freezes on its first install's defaults, and a stack
  switch leaves the old framework's always-on prose in place. Never strengthen it to a heuristic either —
  anything short of byte-equality risks eating a real edit.
- **A seed that lands in a project-owned directory is seeded by NAME, never by sweep.** Only
  `stacks/<s>/modules/` does this today: it writes into `.agent-kit-local/modules/`, where the project's
  own module memory and its `INDEX.md` already live. `stack.yml`'s `modules:` list is the *only* thing
  separating the two natures, which is why install reads it rather than globbing the target. Replace that
  list with a directory sweep and every module a consumer wrote silently becomes a kit default that
  `--reset-defaults` overwrites — a loss the kit cannot regenerate, looking exactly like a normal
  reinstall. `verify.sh`'s `stack_module_seeds` asserts the whole lifecycle, and that an undeclared
  module dir survives `--reset-defaults`.
- **Personal assets never ship in the core.** `install.sh` reads only `common/` and `stacks/`; an add-on
  installer may layer a personal lane on top of a normal kit install, and the files a personal skill
  *works on* land in `.user-kit-local/<skill>/`, derived from the skill's folder name — the same
  contract as `.agent-kit-local/`: seeded when absent, project-owned forever. ⚠ A skill that belongs
  to the **user** rather than to a project must never be moved under `common/`: that ships it to
  every consumer. Files a skill derives there are rewritten by the skill itself, from the user's own
  material — so there is no seed-refresh gate, and `--reset-defaults` is the only path by which an
  installer touches one.
- **`.agent-kit-local/planning/` is a repo's own planning area, if it keeps one** — a project's roadmap, plans
  and decisions; here it holds the persistence doc watchlist the core ships. Tracked, and never delivered to
  a consumer by `install.sh`.
- **Doc style.** Every doc the kit ships is clear + concise + accurate — shape and gotchas, not
  grep-able detail; cut ~25% before saving. See `common/.agent-kit/common/process/authoring/`.

## Dispatching a review of a kit change

⚠ **A reviewer that has not loaded the kit's mental model will give you architecturally wrong advice
with total confidence.** This is not hypothetical: a review of the `/messaging` split recommended lifting
the shared framework content into `.agent-kit/messaging/` — the *agnostic* layer — which would have
shipped one framework's class names to every stack and failed the neutrality gate on the next generic
install. The finding was well-argued and the reasoning was sound; it was simply based on not knowing
that `common/` is neutral and `stacks/` delivers the framework-specific half. It was caught only
because the dispatcher happened to know better, which is not a control.

So a review prompt must require the mental model **first**, not just the working rules:

- **Make it read this file before reviewing**, and ask it to state back the three delivery natures and
  where neutral content lives vs stack content. A reviewer that cannot say it does not have it.
- **Say what the layer under review IS.** "`common/` ships to every stack and must stay
  framework-neutral; `stacks/<s>/` carries the framework specifics" is one sentence that prevents the
  entire class of error above.
- **Separate the two verdicts.** Factual findings ("this claim about the module is wrong") have been
  reliable across many rounds. *Architectural* recommendations ("move this file", "merge these docs")
  have not — require any of those to be justified against the delivery natures and the neutrality
  invariant, or flagged as a question rather than a recommendation.
- **Prose is the second line of defence, never the first.** The state-back is a control on the
  *reviewer*; the durable control is a check that fires whoever reviews — here, the framework-name grep
  in `verify.sh`. Note that grep only existed because it landed in the same feature; before it, that
  move would have passed silently.
- **Settle a factual claim against the source, not against the doc.** Where a stack wraps a framework
  module, that module is a checkout on the machine — read it. No decompiling third-party jars to settle
  a doc claim; adoption is not a finding when a doc is marked prescriptive.

The same applies to any agent you hand a kit task, not only reviewers — the failure is cheaper to catch
in a review, which is exactly why it hides there.

## Verify a change

```bash
./verify.sh                                           # the gate: every stack into a throwaway target, then assert
./verify.sh generic                                   # just one stack
./verify.sh <stack> --overlay <repo>                  # your own overlay's stacks and checks too (combine in any order)
```

`verify.sh` is the gate: it installs each stack, checks all four Tier-0 surfaces exist, that Claude's
`@import` chain resolves, that the Claude/Codex skill sets match, that a stack-shipped module seeds by
declared name and never over a project-authored one, and — for `generic` — that no
framework build-tool instruction leaked into a stack-blind file. The `generic` stack has no JVM project
to install into, so `verify.sh` **synthesizes** Go / Python / Node / docs-only fixture repos; that is the
only way it gets exercised at all. `--overlay <repo>` is for your own overlay, not for contributing to the
core: it adds that repo's `stacks/` and runs its `verify.d/*.sh` hooks, as
[docs/private-overlay.md](docs/private-overlay.md) describes. `tests/` is outside everything the installers
read, so it is never installed.

It also asserts **this repo stays uninstalled** — `./install.sh generic .` here would put a copy of
`common/` beside its source and overwrite the hand-written `.codex/AGENTS.md` with a generated one; the
rest is gitignored, so only that one diff would show.

For a one-off look at what an install would do:

```bash
./install.sh --list                                   # available stacks
mkdir -p .scratch-target                              # target must exist (install does `cd $TARGET`)
./install.sh generic .scratch-target --check          # dry run — print actions, write nothing
```

`.scratch-target/` is gitignored.

`audit-identifiers.py` is advisory, not part of the gate: it reports identifiers in a stack's docs that
resolve nowhere in that stack's source.
