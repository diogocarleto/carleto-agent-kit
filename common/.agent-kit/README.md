# `.agent-kit/` — the shared agent kit

This folder is the **vendored, stack-agnostic** agent kit: the conventions, process docs, UI toolkit,
and templates that drive Claude Code, Codex CLI, Cursor, and VS Code Copilot on this repo. It is meant to be **identical
across every project** that adopts the kit — only the *files inside* the convention folders differ per stack.

Project-specific, live-edited context lives next to it in **`.agent-kit-local/`** — the always-on
`context/` tier (`architecture.md`, `build-commands.md`), plus module memory, planning, and
`structure.yml`. The split is deliberate:

```
.agent-kit/         kit-owned, vendored      →  wiped and rebuilt on every install — never edit here
.agent-kit-local/   project-owned, live      →  yours; the installer only ever SEEDS, never wipes
```

`.agent-kit/` is **replaced wholesale** on every install — so an improvement found there belongs upstream
in the kit, not in this copy, or the next install erases it. `.agent-kit-local/` is the opposite: yours,
kept forever. An install only ever *seeds* into it: `context/`, and — when the stack ships module memory
for its own framework modules — `modules/<name>/` for exactly the names the stack declares. A seed is
copied when absent, refreshed while you have not touched it, and kept forever once you edit it.
⚠ So `modules/` holds two natures side by side. The memory *you* write, and `modules/INDEX.md`, are never
read or written by an install; a stack-shipped module dir is a kit default, so improve it upstream rather
than in place — an untouched copy follows the kit, and editing it here forks it silently.

## How context loads — the load-policy tiers

Nothing in the kit is "always on" except a tiny standing-context chain. Everything else loads **lazily,
on demand, gated by a skill**. Four tiers:

```
 Tier 0 — ALWAYS ON  ······  shared:  planning · agent-dispatch · shell-hygiene · terminology
   │                                                                            (.agent-kit/common/process/)
   │                         local:   architecture · build-commands             (.agent-kit-local/context/)
   │                         (Claude: CLAUDE.md @import   |   Codex/Cursor/VS Code: inlined body)
   │                         NO conventions live here.
   │
 Tier 1 — SKILL-GATED GLOB    layer + companion conventions, read-all at skill invoke
   │   /backend /frontend ··  conventions/<layer>/*.md          (depth-1)
   │        ⚠ a VARIANT FAMILY (<concern>-<value>.md) is not peers: read only the one whose
   │          suffix matches frameworks.<key> in .agent-kit-local/structure.yml. Undeclared →
   │          all of that family, and say so. backend/persistence-<db> ← frameworks.database,
   │          frontend/framework-<name> ← frameworks.frontend
   │        + .agent-kit/frontend/  core.md ALWAYS (neutral invariants) PLUS the ONE
   │          framework-<name>.md matching frameworks.frontend — a SECOND family on that same
   │          key, in a second directory, resolved independently. ⚠ Never glob it whole.
   │          The stack layer WINS over both. /frontend, /fullstack and /ui-design all read it,
   │          so a stack shipping no conventions/frontend/ still gets it
   │        + .agent-kit/backend/  every *.md ALWAYS (neutral backend invariants; depth-1,
   │          no variants, so globbed whole). The stack layer WINS.
   │          /backend, /fullstack and /scaffold all read it
   │        + .agent-kit/persistence/  core.md ALWAYS (neutral invariants) PLUS the ONE
   │          persistence-<db>.md matching frameworks.database — the same two-directory shape on
   │          that key, resolved independently. ⚠ Never glob it whole. The stack layer WINS.
   │          /backend, /fullstack and /scaffold all read it
   │   /mobile ·············  conventions/mobile/*.md  (depth-1; no-ops where the stack ships none)
   │   /messaging ···········  .agent-kit/messaging/*.md  (ALWAYS — neutral invariants)
   │                        +  conventions/backend/messaging/*.md  (stack framework, WINS on conflict)
   │                           both are globbed at skill invoke — hence Tier 1, not Tier 2
   │   /dcr ················  .agent-kit/dcr/*.md  (ALWAYS — neutral invariants)
   │                        +  conventions/backend/recipes/*.md  (stack recipe, WINS on conflict)
   │   /migrate ············  .agent-kit/migration/*.md  (ALWAYS — neutral invariants)
   │                        +  conventions/backend/migration/*.md  (stack layer, WINS on conflict)
   │   /scaffold ···········  conventions/backend/*.md (depth-1)  +  conventions/backend/recipes/*.md
   │                        +  .agent-kit/backend/ and .agent-kit/persistence/ as for /backend above
   │   process companions ···  process/authoring/*.md   (every doc-writing skill; the reviewers too)
   │                        +  process/review/*.md      (the reviewers and test-runner)
   │                        +  process/planning/*.md    (/feature-plan, /feature-execute)
   │                        +  process/dispatch/*.md    (/feature-plan, /feature-execute, /peer-dispatch)
   │                        +  process/diagrams/*.md    (/feature-plan, /module-extract)
   │                           (process/reference/ is NEVER globbed — named, or read on demand)
   │                           conventions/ and process/ are both under .agent-kit/common/
   │
 Tier 2 — CONDITIONAL SELECT   UI toolkit (.agent-kit/ui/**) — chosen by task, never globbed
   │
 Tier 3 — ON DEMAND ········   module memory · planning templates · costs/model-rates.md
                               (published per-MTok prices) — pulled only when referenced
```

The win: **conventions load only when a skill that needs them is invoked**, on *every* harness. A cold
session carries no convention bodies.

## Directory layout

```
.agent-kit/
  README.md                      ← you are here (the mental model)
  common/
    conventions/                 ← Tier 1: the closed peer-layer taxonomy (see conventions/README.md)
      README.md                    the taxonomy + directory-purity invariant
      backend/                     backend layer docs — DEPTH-1 glob target
        code-style.md design-principles.md api.md testing.md
        security.md logging.md concurrency.md patterns.md   ← set varies by stack
        persistence-<db>.md          a VARIANT FAMILY — one file per database. The layer skills read
                                     only the one matching frameworks.database in structure.yml (the
                                     declared value IS the suffix); a stack may instead ship a plain
                                     persistence.md, read like any other doc. The engine's neutral
                                     standard sits beside core.md in .agent-kit/persistence/
        messaging/  messaging.md    companion → /messaging
        migration/                   companion → /migrate (no stack ships one yet)
        recipes/    new-domain.md new-dcr.md   companion → /scaffold, /dcr
      frontend/                    frontend layer docs — depth-1 glob target
        framework-<name>.md          the second VARIANT FAMILY — same contract, keyed on
                                     frameworks.frontend (svelte → framework-svelte.md)
      mobile/                      peer layer — LOADABLE (/mobile globs it); absent until a stack fills it
      desktop/                     peer layer — RESERVED, not loadable: no skill globs it, so a doc here
                                   installs and is never read
    process/                     ← depth-1 = Tier 0, always on (same shape as conventions/)
      planning.md agent-dispatch.md shell-hygiene.md terminology.md
                                 depth-1 holds only what EVERY session needs: where plans live, how to
                                 classify a dispatch, the shell gate, the no-translation rule. The
                                 process itself is a companion
      authoring/  doc-style.md   companion → every doc-writing skill, and the reviewers
      diagrams/   diagrams.md    companion → /feature-plan, /module-extract (not the reviewers): the picker,
                                 house style and verify rules for any diagram, plan or module memory
      review/     code-review.md companion → the reviewers and test-runner
      planning/   workflow.md plan-shaping.md execution-loop.md decision-addon.md
                                 companion → /feature-plan, /feature-execute. ⚠ NOT .agent-kit/planning/,
                                 which is the plan TEMPLATES — this is the process that uses them.
                                 decision-addon.md is the one hook a decision add-on plugs into
      dispatch/   loop-steps.md peer-harness.md reference-paste.md
                                 companion → /feature-plan, /feature-execute, /peer-dispatch
      reference/  allowed-commands.md shell-hygiene-examples.md code-reviewer-agent-header.md
                                 never globbed — named individually or read on demand
  ui/                            ← Tier 2: UI toolkit (platforms, frameworks, validators) — global, never globbed
  frontend/  core.md             ← Tier 1: frontend INVARIANTS — global, framework-neutral, read by
                                 /frontend, /fullstack and /ui-design on EVERY stack, including those
                                 shipping no conventions/frontend/ — there it is nearly all they load.
                                 ⚠ NOT common/conventions/frontend/, which is the stack's own layer and
                                 wins over both. The CODE rules; ui/ carries the visual bar
    framework-<name>.md            the framework's own standard — a VARIANT FAMILY keyed on
                                 frameworks.frontend, exactly like the stack layer's. ⚠ So this dir is
                                 never globbed whole: core.md always, plus the one matching variant.
                                 No file for your framework = no standard written yet, not a verdict
    reference/  adding-frontend.md    not globbed — read when a stack has no frontend layer yet
  backend/  core.md              ← Tier 1: language-neutral backend INVARIANTS — global, read by /backend,
                                 /fullstack and /scaffold and the backend/fullstack reviewers on EVERY
                                 stack. Today the code-style kernel (core.md) beside design-principles.md
                                 and logging.md; a rule is admitted only where every
                                 stack that speaks to it agrees. ⚠ NOT common/conventions/backend/, the
                                 stack's own layer, which wins. No variants: every depth-1 *.md is read,
                                 so a further concern is a file drop
    reference/  adding-backend-rules.md   not globbed — read when admitting a rule or writing a stack's backend docs
  persistence/  core.md          ← Tier 1: persistence INVARIANTS — global, neutral of any ORM or framework,
                                 read by /backend, /fullstack and /scaffold and the backend/fullstack
                                 reviewers on EVERY stack
    persistence-<db>.md            the engine's own standard — a VARIANT FAMILY keyed on
                                 frameworks.database, like the stack layer's. ⚠ Never globbed whole:
                                 core.md always, plus the one matching variant
    reference/  adding-persistence.md   not globbed — read when adding an engine's standard
  dcr/  core.md                ← Tier 1: one-shot data-change INVARIANTS — global, framework-neutral,
                                 read by /dcr on EVERY stack, including those shipping no recipes/ —
                                 there it is the only thing loaded, and says so rather than leaving
                                 the agent to invent a shape
    reference/  adding-dcr.md         not globbed — read when a stack has no DCR layer yet
  migration/  core.md            ← Tier 1: legacy-migration INVARIANTS — global, framework-neutral, read
                                 by /migrate on EVERY stack, including those shipping no migration/ —
                                 there it is the only thing loaded, and says so rather than leaving
                                 the agent to invent a shape
    reference/  adding-migration.md   not globbed — read when a stack has no migration layer yet
  messaging/  core.md            ← Tier 1: event-messaging INVARIANTS — global, framework-neutral, read by
                                 /messaging on every stack. A stack's concrete annotations live in its
                                 conventions/backend/messaging/ and win where the two differ
    reference/  adding-messaging.md   not globbed — read when a stack has no messaging layer yet
  costs/     model-rates.md       published per-MTok model prices
  modules/   README.md TEMPLATE.md INDEX.template.md   module-memory format + promotion loop
  planning/  README.md TEMPLATE.md IDEA-TEMPLATE.md DIAGRAMS.md
             ADR-TEMPLATE.md RFC-TEMPLATE.md
                                          planning workflow + templates + plan-diagram triggers/contracts
  structure.template.yml
```

## How each harness lazy-loads conventions

Claude and Codex reach the **same convention files by the same glob**, through each one's native
progressive-disclosure mechanism:

```
            ┌─────────────────────────────┐        ┌─────────────────────────────┐
            │           CLAUDE             │        │            CODEX             │
            ├─────────────────────────────┤        ├─────────────────────────────┤
 startup    │ CLAUDE.md @import chain      │        │ config.toml (if trusted):    │
            │ = Tier-0 only, no conventions│        │ = Tier-0 + skill pointer     │
            │                              │        │ list (same body as AGENTS.md)│
            ├─────────────────────────────┤        ├─────────────────────────────┤
 on /backend│ skill body says:             │        │ skill name/description seen  │
            │ "Read every *.md under       │        │ at startup; on invoke the    │
            │  conventions/backend/"       │        │ SKILL.md body says the same  │
            │  → model globs + reads       │        │  glob → model globs + reads  │
            └─────────────────────────────┘        └─────────────────────────────┘
                          └──────────────┬───────────────────┘
                                         ▼
                         .agent-kit/common/conventions/backend/*.md
```

- **Claude** — `CLAUDE.md` `@import`s only Tier-0. Skills replace per-file `@import`s with a
  *glob-read instruction* the model executes on invoke.
- **Codex** — has no `@import`. `AGENTS.md` is regenerated by `.codex/Makefile` (`make -C .codex
  sync-agents`) to hold **only** Tier-0 + a skill-pointer hint. Codex itself never reads that file —
  a trusted project's `.codex/config.toml` carries the same body as `developer_instructions`, which is
  what actually loads at startup (untrusted, Codex falls back to the project's own root `AGENTS.md`
  instead). Codex's native Agent Skills load each `SKILL.md` on invoke, which globs the same convention
  dir. The one eager exception is the **code
  reviewer** (`.codex/agents/code-reviewer.md`): it can't lazy-load mid-review, so the Makefile inlines
  `process/review/` + `process/authoring/`, `architecture.md`, every depth-1 `conventions/*/*.md`,
  every depth-1 `.agent-kit/backend/*.md`, `.agent-kit/persistence/core.md` and every `persistence-*.md`,
  and `.agent-kit/frontend/core.md` and every `framework-*.md`, via globs. All variants are inlined; the reviewer's header limits it to the one
  matching `frameworks.database` and the one matching `frameworks.frontend`.
- **Cursor** — a third harness. Its always-on rule (`.cursor/rules/agent-kit.mdc`, generated by the same
  Makefile) **inlines** the Tier-0 body (no reliable eager `@file` import), and it **auto-discovers**
  skills straight from `.claude/skills/` + `.codex/skills/` — so the same convention glob reaches Cursor
  with zero Cursor-specific files. (It reads both skill dirs, so a skill may list twice; cosmetic.)
- **VS Code Copilot** — a fourth harness. Its always-on file (`.github/copilot-instructions.md`, generated
  by the same Makefile) **inlines** the Tier-0 body (no `@import` expansion), and it **auto-discovers**
  skills from `.claude/skills/` and subagents from `.claude/agents/` natively — so the same convention
  glob reaches VS Code with zero VS Code-specific files. (`.vscode/settings.json` sets
  `chat.useClaudeMdFile:false` and `chat.useAgentsMdFile:false` so the generated file is the single
  always-on source.)

A parity check (`make -C .codex sync-agents` → `validate-skills`) asserts the Claude and Codex skills
reference the **same** convention dirs — so the two never diverge on *which* conventions they load.

⚠ **What the parity check does not cover.** `validate-skills` compares the *convention dirs* each skill
cites, **not** its prose — two mirrors can name the same docs and still say different things. That gap is
the kit's to mind, not yours: `.claude/skills/` and `.codex/skills/` are rebuilt from the kit on every
install, so an edit you make to a skill here is replaced by the next one. Report a divergence upstream
instead.

**Tracking the generated files.** `.codex/AGENTS.md`, `.codex/agents/code-reviewer.md`,
`.cursor/rules/agent-kit.mdc`, and `.github/copilot-instructions.md` are rebuilt on every install
(`make -C .codex sync-agents` rebuilds them by hand) — so **commit them or ignore them, your call**: committing
keeps them available to a teammate with no `make` (install skips the sync then), ignoring avoids a churned
diff each install. ⚠ The exception is `code-reviewer.md`: `.codex/agents/` is wiped on every install and
regenerated only with `make`, so a `make`-less install deletes it. Never hand-edit them: they are rebuilt
from the kit, and so is the `.codex/Makefile` that builds them — a change to either belongs upstream, not
in this copy.

## The two invariants that make this portable

1. **Closed peer-layer taxonomy** — top-level convention folders are exactly `backend/`, `frontend/`,
   `mobile/`, `desktop/`. A stack only ever *fills files* into them; it never invents a folder. So
   resolving conventions is always "glob a known dir," never "discover what this stack called things."
2. **Glob, not enumerate** — skills/agents/Makefile name a *directory* and read-all. Adding or renaming
   a convention doc needs **zero** edits to any skill, agent, or Makefile.

Full taxonomy detail and the depth-1 / companion rules: **[`common/conventions/README.md`](common/conventions/README.md)**.
