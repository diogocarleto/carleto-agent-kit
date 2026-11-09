# carleto-agent-kit

One agent layer for **Claude Code, Codex CLI, Cursor and VS Code Copilot**, installed into your project
from a single source. Every harness gets the same skills, code reviewers and working rules, and the
conventions of your tech stack load only when a task needs them.

You clone this repo and run `./install.sh <stack> <your-project>` from the clone. The project receives a
flattened copy of the layer, never `stacks/` itself: this repo is a catalog, not a dependency.

```bash
git clone <repository-url> carleto-agent-kit   # once
cd carleto-agent-kit
./install.sh --list                  # the stacks below, read live from stacks/*/stack.yml
./install.sh <stack> <target>        # install; re-running is safe
```

[Glossary](#glossary) · [What differs](#what-differs) · [Install](#install) · [How it works](#how-it-works) ·
[Keep your own stacks private](docs/private-overlay.md) · [Contribute](CONTRIBUTING.md)

## Glossary

| Term | Means |
|---|---|
| **Harness** | An agent tool the kit installs into: Claude Code, Codex CLI, Cursor, VS Code Copilot. |
| **Stack** | One directory under `stacks/` of convention docs for a tech stack, declared by its `stack.yml`. An install is `common/` plus exactly one stack. |
| **Stacks root** | A directory holding stacks as `<dir>/<stack>/stack.yml`. The kit's `stacks/` is one; `--stacks <dir>` adds yours. |
| **Seed** | A file the kit copies into your project once and you may then edit: permissions, the Claude entrypoint, `context/`. Refreshed only while untouched. |
| **Companion** | An optional doc bundle nested under a stack's layer (`backend/messaging/`), loaded by its own skill beside the layer. |
| **Variant** | One file per value on one axis, `<concern>-<value>.md` (`persistence-postgres.md`); only the declared one is read. |
| **Tier 0** | The always-on context: the process docs and your `context/` pair. See [Load tiers](#load-tiers). |
| **Add-on** | Skills or assets of your own, layered on top of an install by an installer you write: [docs/private-overlay.md](docs/private-overlay.md). |

## What differs

### One source, four harnesses

The four tools read different files. The kit writes each its own from one source, and keeps the Claude and
Codex skills naming the same convention files:

| Harness | Skills | Always-on instructions | Code reviewers |
|---|---|---|---|
| Claude Code | `.claude/skills/` | `.claude/CLAUDE.md`, which `@import`s the standing docs | `.claude/agents/` |
| Codex CLI | `.codex/skills/` | generated, as `developer_instructions` in `.codex/config.toml` | generated `.codex/agents/code-reviewer.md`, plus `test-runner.md` |
| Cursor | discovers `.claude/skills/` and `.codex/skills/` | generated `.cursor/rules/agent-kit.mdc` | none: Cursor discovers skills, not subagents |
| VS Code Copilot | discovers `.claude/skills/` | generated `.github/copilot-instructions.md` | reads `.claude/agents/` |

### Your edits to seeds survive reinstalls

Some files are **seeds**: permissions, the Claude entrypoint, the always-on `context/` pair. They are copied
once. A reinstall refreshes a seed only while it is byte-identical to what the kit shipped, so a file you
edited is kept forever (unless you pass `--reset-defaults`), and one you never touched still follows the
kit. Everything else the kit owns is rebuilt on every install, and your own state lives apart in
`.agent-kit-local/`, which an install never wipes. Mechanics: [Seeds refresh only while untouched](#seeds-refresh-only-while-untouched).

### Stacks

A stack is one directory of convention docs for a tech stack. An install is the neutral `common/` plus
exactly one stack, so every project is shaped the same and only the convention *contents* differ.

| Stack | For |
|-------|-----|
| **`generic`** | Any project: the shared layer with **no** framework conventions. Your project grows its own stack from here: to contribute it to the kit, see [Adding a stack](CONTRIBUTING.md#adding-a-stack); to keep it in a repo of your own, see [docs/private-overlay.md](docs/private-overlay.md). |
| **`jakarta-ee`** | Plain Jakarta EE 11, Java 21: JAX-RS, CDI, Bean Validation, Jakarta Concurrency, MapStruct, Maven. Persistence is a per-database variant (MongoDB, PostgreSQL, SQL Server). Backend conventions only. The runtime (WildFly, Open Liberty, Payara, TomEE) is undecided, and the docs say so inline: grep `RUNTIME GAP`. |
| **`spring-boot`** | Spring Boot 4 on Spring Framework 7, Java 21: Spring MVC, Spring Data, Spring Security, Bean Validation, MapStruct, Maven. Persistence is a per-database variant (PostgreSQL, SQL Server, MongoDB). Backend conventions only. |

Skills never name a convention file. They **glob** a directory and read what is in it, which is why a stack
only fills files and adding or renaming a doc needs no change to any skill, agent or script. A stack is
declared by its `stack.yml`; install reads its `description` and `modules:`, and `./install.sh --list`
shows the description.

A backend-only stack ships no `conventions/frontend/`, yet `/frontend` still applies the framework-neutral
frontend standard that every stack gets.

#### Variant families — one stack, several values on one axis

Where consumers of a stack differ on **one** axis (the database, the frontend framework), the stack ships
one file per value, `<concern>-<value>.md`, instead of forking the whole stack: `persistence-postgres.md`,
`persistence-mongodb.md`. You declare the value in `.agent-kit-local/structure.yml` and **the declared value
is the filename suffix**: no mapping table. Skills then read the matching variant and ignore the others.

| Family | Declared by | Lives in | Read by |
|---|---|---|---|
| `persistence-<db>.md` | `frameworks.database` | the stack's `conventions/backend/`, and the engine's neutral standard in `.agent-kit/persistence/` | `/backend` · `/fullstack` · `/scaffold` |
| `framework-<name>.md` | `frameworks.frontend` | the stack's `conventions/frontend/` when it ships one, and the framework's neutral standard in `.agent-kit/frontend/` (react, angular, svelte) | `/frontend` · `/fullstack` · `/ui-design` |

Selection happens when the skill reads: install ships every variant, so declaring or changing a value needs
no reinstall. A neutral standard (`.agent-kit/persistence/`, `.agent-kit/frontend/`) and the stack's own doc are resolved
independently, and **the stack's wins** where they differ. Three traps:

- ⚠ **Undeclared is where every project starts**: install never writes `structure.yml`. The skills then read
  *every* variant of the family and say so, rather than guess a default. Invoke `/structure-extract` in your
  harness to write the file.
- ⚠ **Declared, no matching file**: nothing fails; the skill says no standard ships for that value and
  carries on. A mistyped value looks exactly like this.
- ⚠ **Renaming a value is a clean break, with no alias file.** Each rename is recorded in
  [Upgrade notes](#upgrade-notes).

### A process layer, and reviewers

Beyond conventions, every install carries the working process, as skills and standing docs:

- **Planning.** `/brainstorm` tests an idea; `/feature-plan` writes a plan with slices, phases and a test
  plan to `.agent-kit-local/planning/`; `/feature-execute` walks it phase by phase: dispatch, review, fix,
  test, checkpoint.
- **Dispatch.** Each task is classified as inline or dispatched, then given the cheapest model tier that fits
  (Claude and Codex equivalents), at the effort the plan stamps. `/peer-dispatch` is the opt-in way to hand a
  file-disjoint sub-task to Codex or to a local LM Studio model.
- **Shell hygiene.** A short pre-flight for shell commands, so routine ones match the seeded permission
  allowlist instead of prompting.
- **Terminology.** Keep English technical terms in English when you write another language.
- **Reviewers.** Backend, frontend and fullstack code reviewers, plus a test runner that picks the narrowest
  useful scope. They judge a diff against your stack's conventions, the neutral standards and the declared
  variants.
- **Memory.** `/module-extract` writes on-demand notes on how a module works, stamped against the source
  commit; `/modules` loads them.
- **UI toolkit.** `/ui-design`, `/ui-extract` and `/ui-detect` shape, audit and polish web and mobile UI,
  and flag the tells of generated design. See [Acknowledgements](#acknowledgements).

The skills, by what they load:

| Skills | Load |
|---|---|
| `/backend` `/frontend` `/fullstack` | the layer's neutral standard, then the stack's conventions for it |
| `/mobile` | the stack's mobile conventions, when it ships them |
| `/messaging` `/dcr` `/migrate` | neutral invariants always, plus the stack's companion docs when it ships them |
| `/scaffold` | the stack's recipes, so it has nothing to generate on a stack without them. None of the three stacks above ships any |
| `/feature-plan` `/feature-execute` `/brainstorm` `/peer-dispatch` | the process docs |
| `/modules` `/module-extract` `/structure-extract` | project memory and the structure manifest |
| `/ui-design` `/ui-extract` `/ui-detect` | the UI toolkit |

## Install

**You need** `bash`, plus `make` (it builds the Codex, Cursor and Copilot files: without it the install
finishes, but those files are missing or stale and `code-reviewer.md` is deleted), `python3` (it merges
`claudeMdExcludes` and the two VS Code keys, and writes Codex's `developer_instructions`; without it the
first two are printed for you to add by hand, and a trusted Codex project gets no instructions at all) and,
to get kit-version stamps and seed refreshes, a `git` checkout of this repo. Installing never uses `node`;
`/feature-plan`, `/feature-execute`, `/ui-design` and `/ui-detect` run a script with it, and `./verify.sh`
skips its plan-lint check without it. The target must already exist.

⚠ **On Windows, run the kit under WSL.** It is `bash` and `make` throughout, which native Windows lacks;
Git for Windows ships `bash` but neither `make` nor `python3`.

Run `install.sh` from your clone of the kit. A relative target such as `../my-service` is resolved against
your current directory, so an absolute path works from anywhere:

```bash
./install.sh --list                      # pick a stack
./install.sh spring-boot ../my-service   # install into an existing directory
./install.sh spring-boot ~/work/my-service
```

Then open the project in your harness. Edit `.agent-kit-local/context/architecture.md` and
`build-commands.md`, which the kit seeds as always-on context, and invoke `/structure-extract` there: it is a
skill you run inside the harness, not a shell command. It writes `.agent-kit-local/structure.yml`, the
manifest that declares your database and frontend framework.

### Flags

| Flag | Does |
|---|---|
| `--check` | Dry run: prints every action, writes nothing. |
| `--force` | Reinstall even if the target is already on this stack and kit version. Typically needed right after you commit a kit change and want to push it out again, since the stamp already matches, or to rebuild kit-owned files you edited in the project. |
| `--reset-defaults` | ⚠ **Replaces every seed** with the kit's version and deletes `.claude/settings.local.json`. There is no merge and no drift check, so your edits to those files are lost. It prints what it replaces first; add `--check` to preview. Your planning, `structure.yml` and own module memory are never touched. |
| `--stacks <dir>` | Take a stack from `<dir>/<stack>/stack.yml` as well as the kit's `stacks/`. Repeatable. A stack name found in two roots is refused before anything is written. `--list` shows every root. See [docs/private-overlay.md](docs/private-overlay.md). |
| `--list` · `--help` | List the stacks · print usage. |

### When install skips itself

A second `./install.sh` prints *"already on the latest — nothing to do"* when it would change nothing. It
skips only if `.synced-from` holds the same stack, kit commit, and stacks root and commit, the checkout is
clean, a spot-check of a few kit-owned files finds them in place, and nothing an add-on installer delivered
is present (a reinstall removes it). Editing the kit, a different stack or version, a damaged tree,
`--force` and `--reset-defaults` never skip. The guard compares versions and checks that files exist, not
what they hold: **editing your own files, even a kit-owned one, never makes a reinstall run**. To rebuild
over such an edit, pass `--force`. Outside a git checkout (a downloaded archive) the kit has no
version, so it never skips and never refreshes a kit seed; a versioned `--stacks` root still refreshes its
own stack's seeds.

A skill doc-list drift warning at the end of an install does not mean it failed: the install completed and
every surface is built. The skills are kit-owned, so report the drift upstream rather than edit them;
`make -C .codex sync-agents` re-runs the lint.

### Upgrade notes

A reinstall delivers every kit change, but `structure.yml` is yours and install never writes it, so a change
to a declared value needs a second step from you.

- **`frameworks.frontend: svelte5` → `svelte`.** `framework-svelte5.md` is now `framework-svelte.md`, in
  `.agent-kit/frontend/` and in any stack that shipped one. A clean break with no alias, so change two
  things together: edit `.agent-kit-local/structure.yml` **and** reinstall (or reinstall, then run
  `/structure-extract`, which re-derives the value from the files that shipped). ⚠ Either alone leaves the
  declared value matching no file, so the Svelte rules stop loading without an error.
- **`.synced-from` gains `stack_source:` and `stack_version:`.** A stamp from before them never matches the
  skip guard, so the first reinstall after this change always runs. No action: untouched seeds are still
  proven against the kit's history.

## How it works

### What a project gets

```
your-project/
  .agent-kit/          kit-owned: process docs, conventions, UI toolkit, templates, LICENSE, NOTICE
  .agent-kit-local/    yours: context/ (seeded), structure.yml, planning/, module memory
  .claude/             skills/ agents/ (kit-owned) · CLAUDE.md settings.json (seeds)
  .codex/              skills/ agents/ Makefile (kit-owned) · rules/ config.toml (seeds) · AGENTS.md (generated)
  .cursor/             permissions.json (seed) · rules/agent-kit.mdc (generated)
  .vscode/             settings.json (seed)
  .github/             copilot-instructions.md (generated)
  .synced-from         which stack and kit version this install came from
```

### The three delivery natures

Every file the kit ships is one of three kinds, by how install treats it:

| Nature | Examples | Install does | Owner |
|---|---|---|---|
| **Shared** | `.agent-kit/`, `.claude/{skills,agents}`, `.codex/{skills,agents,Makefile}`, the stack's conventions | **overwrites** every install | the kit |
| **Seed** | `.claude/CLAUDE.md`, `.claude/settings.json`, `.codex/rules/default.rules`, `.codex/config.toml`, `.cursor/permissions.json`, `.vscode/settings.json`, `.agent-kit-local/context/` | copies if absent; **refreshes while untouched**; replaced by `--reset-defaults` | you, once you edit it |
| **Generated** | `.codex/AGENTS.md`, `.codex/agents/code-reviewer.md`, `.cursor/rules/agent-kit.mdc`, `.github/copilot-instructions.md` | **rebuilds** at the end of every install (`make -C .codex sync-agents` by hand) | the generator |

⚠ **Shared files are rebuilt, so a local edit there is lost.** An improvement belongs in the kit (or in a
stack of your own) and comes back on the next install. Put project knowledge in `.agent-kit-local/`.

⚠ **Never hand-edit a generated file.** Whether to commit them is your call: committing keeps the
instructions for a teammate without `make`; ignoring them avoids a diff on every install. Codex never reads
`.codex/AGENTS.md` itself. In a trusted project it gets the same body as `developer_instructions`, which the
install merges into `.codex/config.toml` between `agent-kit generated` markers. Trust is set by Codex's own
prompt, not by the kit.

⚠ **`.github/copilot-instructions.md` is the one generated path a project may already own.** The first
install copies yours to `.github/copilot-instructions.md.pre-agent-kit` and never overwrites that backup.
Merge what you still want into a `.github/instructions/*.instructions.md`, which the kit does not touch.

### Seeds refresh only while untouched

*Existing* is not the same as *edited*, so a normal install decides per seed, by byte-equality:

| Your copy is… | Install does |
|---|---|
| absent | seeds it |
| byte-identical to what the kit shipped at the version in `.synced-from` | **refreshes it** to the current kit version |
| byte-identical to the *previous stack's* `context/` seed, on a stack switch | **replaces it** with the new stack's |
| anything else: you edited it | **keeps it**, and on a stack switch says so, because `context/` is always-on |

Byte-equality is the whole proof: nobody invested anything in that file, so nothing is lost. Without the
middle rows a project freezes on the seeds of whatever version first installed it, and a stack switch leaves
the old stack's architecture prose loading in every session. The proof reads the kit's git history, which is
why an unversioned kit refreshes nothing.

Four seeds are special:

- **`.claude/CLAUDE.md`.** If yours already exists it is kept, and install warns when it lacks the kit's
  imports: Claude then loads none of the standing docs, while the other three harnesses get them inlined.
- **`.vscode/settings.json`.** Often already yours, so it is kept, but `chat.useClaudeMdFile: false` and
  `chat.useAgentsMdFile: false` are **merged in**; a file with comments is warned about, not rewritten.
- **`.claude/settings.json`.** Its `claudeMdExcludes` key is generated on every install and ignored by the
  untouched check, so a file that differs from the seed only by that key still follows the kit. Entries you
  added to the key are kept; only a complete kit set written for another folder name is replaced. A
  `settings.json` that is not strict JSON (a comment, a trailing comma) is warned about and the entries are
  printed for you to add; the file is never rewritten.
- **`.agent-kit-local/modules/<name>/`.** A stack that ships module memory seeds exactly the names its
  `stack.yml` declares, never the directory: your own module memory and `modules/INDEX.md` sit beside
  them. A stack switch leaves the old stack's module dirs in place: nothing reads them once they are
  undeclared, and removing them is your call. None of the three stacks above ships any.

### What each install touches

A reinstall is not a merge. It **erases and rebuilds** what the kit owns; `--reset-defaults` also replaces
every seed. Path by path:

| Path | Every install | With `--reset-defaults` |
|---|---|---|
| `.agent-kit/` · `.claude/{skills,agents}` · `.codex/{skills,agents}` · `.codex/Makefile` · `.codex/sync-codex-config.py` · `.user-kit/` | **wiped and rebuilt**: anything else placed there is erased | same |
| Skills and `.user-kit/` assets an add-on installer delivered ([docs/private-overlay.md](docs/private-overlay.md)) | **removed** | same |
| Generated: `.codex/AGENTS.md` · `.codex/agents/code-reviewer.md` · `.cursor/rules/agent-kit.mdc` · `.github/copilot-instructions.md` | **regenerated** (needs `make`) | same |
| Seeds: `.claude/CLAUDE.md` · `.codex/rules/default.rules` · `.cursor/permissions.json` | seeded if absent · **refreshed** if untouched · **kept** if edited | **replaced** |
| Seed: `.claude/settings.json` | as above, then `claudeMdExcludes` is merged in | **replaced**, then the key is re-added |
| Seed: `.vscode/settings.json` | as above, and the two `chat.*` keys are merged into an existing file | **replaced** |
| Seed: `.codex/config.toml` | as above for `project_doc_max_bytes = 0`, then `developer_instructions` is merged in between its markers; a value you set outside them is left alone and reported | **replaced**, then the block is re-added |
| Seeds: `.agent-kit-local/context/{architecture,build-commands}.md` | as above; on a stack switch an untouched seed of the previous stack is replaced | **replaced** |
| Seeds: `.agent-kit-local/modules/<name>/…`, for each name the stack declares | as above, file by file | **replaced**; a file you added there is kept |
| `.claude/settings.local.json` | kept | **deleted** |
| `.agent-kit-local/planning/` · `structure.yml` · `modules/INDEX.md` · module dirs the stack does not declare · `.user-kit-local/` | never touched | never touched |
| `.synced-from` | rewritten (stack, kit version, stacks root and its version) | rewritten |
| Everything else in the project | never touched | never touched |

#### What to commit in your project

| Path | Commit? | Why |
|---|---|---|
| Seeds: `.claude/CLAUDE.md` · `.claude/settings.json` · `.codex/rules/` · `.codex/config.toml` · `.cursor/permissions.json` · `.vscode/settings.json` | **Yes** | They are your project's defaults, and a teammate should get your permission edits. An untouched one still follows the kit on reinstall. ⚠ `settings.json`'s generated `claudeMdExcludes` is keyed to the checkout's folder name, so it flips between teammates whose folders differ ([limits](#only-the-kits-instructions-load)). |
| `.agent-kit-local/`: `context/`, `structure.yml`, `planning/`, module memory | **Yes**, except anything personal to you | It is project knowledge and install never wipes it. |
| `.synced-from` | **Yes**, with the seeds | It is the baseline an install uses to prove a seed untouched. Without it every seed counts as edited and never refreshes. It holds your local kit path, so it changes on each install. |
| Shared trees: `.agent-kit/` · `.claude/{skills,agents}` · `.codex/{skills,agents,Makefile,sync-codex-config.py}` | **Your call** | Committed: a teammate or CI gets the layer without running install, and the diff shows what a kit upgrade changed, at the cost of a large diff each time. Ignored: a smaller repo and quiet diffs, but everyone must run install before the agent has its skills. |
| Generated files: `.codex/AGENTS.md` · `.codex/agents/code-reviewer.md` · `.cursor/rules/agent-kit.mdc` · `.github/copilot-instructions.md` | **Your call** | Committed: a teammate without `make` still gets the instructions. Ignored: no diff on every install. |
| `.claude/settings.local.json` | No | Personal, and the kit does not use it. |

⚠ **`.agent-kit-local/` holds two natures.** `context/` and a declared module dir are seeds and are replaced
by `--reset-defaults`. `planning/`, `structure.yml`, `modules/INDEX.md` and every module you wrote are
yours and never touched, by that flag or any install. The split is by **name**, never by sweeping the
directory.

#### Checking what a reset would cost

Nothing compares for you, and the right baseline is the kit version in `.synced-from`, not the current kit,
because a seed differs both when you edited it and when you are simply on an older kit. Read the stamp, then
diff each seed you care about against its pristine copy in git history, run from the project root. Read
`<source>`, `<version>`, `<stack_source>` and `<stack_version>` from the project's `.synced-from`; the two
sources are absolute paths:

```bash
cat .synced-from   # version, source (the kit checkout), stack, stack_source (the stacks root), stack_version

# a kit seed lives under common/ in the kit checkout, at `version`
git -C <source> show <version>:./common/.claude/settings.json | diff - .claude/settings.json

# a stack seed (context/, modules/<name>/) lives in the stacks root, at `stack_version`
git -C <stack_source> show <stack_version>:./<stack>/context/architecture.md \
  | diff - .agent-kit-local/context/architecture.md
```

No output means untouched: a normal install refreshes it and `--reset-defaults` loses nothing. Two seeds
differ even when you changed nothing, because install merges a generated part into them and ignores it when
judging: `claudeMdExcludes` in `settings.json`, and the `agent-kit generated` block in `config.toml`. If
the command fails, or the stamp says `unversioned`, the baseline is gone and install itself treats the seed
as edited.

### Only the kit's instructions load

In a kit-installed project, each tool's always-on instructions are the kit's own. Your root `CLAUDE.md`,
`AGENTS.md` and `.claude/rules/` stay on disk, untouched, and load only where a tool has no lever to stop it.
This is strict for every install, with no opt-out.

| Tool | Kit entrypoint | Lever | Still loads |
|---|---|---|---|
| Claude | `.claude/CLAUDE.md` | `claudeMdExcludes`: three globs anchored on the folder's name | none |
| Codex | `developer_instructions` from `.codex/config.toml` | a **trusted** project's `project_doc_max_bytes = 0` | untrusted: the root `AGENTS.md` |
| VS Code | `.github/copilot-instructions.md` | `chat.useClaudeMdFile` and `chat.useAgentsMdFile`, both `false` | `.claude/rules/` files that declare `paths` or a `description`: no setting stops it |
| Cursor | `.cursor/rules/agent-kit.mdc` | none: an acknowledged gap | root and nested `AGENTS.md` |

Install ends with a per-tool report naming only the foreign files that exist, and credits a tool with
skipping one only once its lever is confirmed in place. Limits:

- ⚠ The globs are anchored on the checkout's folder name: a project under another name matches nothing
  until reinstalled there, and a tracked `settings.json` flips its set between teammates whose folders differ.
- ⚠ The same globs also exclude a nested folder named like the project, and a project named like one of its
  ancestors or like the home folder also excludes those.
- ⚠ A folder named `.claude`, or one holding a glob character (`*?[]{}!()|"`), gets no set: install warns.
- ⚠ To exclude a nested module or an ancestor on purpose, write `**/<name>/.claude/rules/**/*` instead of
  `**/<name>/.claude/rules/**`. Claude matches the same files, but install will not recognize it as a kit
  set, so it is never auto-replaced.
- ⚠ A user-level Codex `developer_instructions` is overridden by the project's own. VS Code's `chat.*`
  keys are documented for its Local agent, and their effect on Copilot's own agent host is unverified.
- Out of scope: ancestor `CLAUDE.md` files above the repo, subdirectory `CLAUDE.md` and `AGENTS.md` (loaded
  on demand), and the personal `CLAUDE.local.md`.

### Load tiers

Nothing loads eagerly except a short standing chain, and conventions load only when a skill asks for them:

| Tier | What | When |
|---|---|---|
| 0 | the process docs and your `context/` pair | always, on all four harnesses |
| 1 | convention layers and their companions | on skill invoke, by glob |
| 2 | the UI toolkit | chosen by task, never globbed |
| 3 | module memory, planning templates, model prices | only when something references them |

The full map, per harness, ships in every install as
[`.agent-kit/README.md`](common/.agent-kit/README.md).

## Acknowledgements

The UI toolkit is inspired by [impeccable](https://github.com/pbakaus/impeccable) (pbakaus, Apache-2.0), and
through it by [ehmo/platform-design-skills](https://github.com/ehmo/platform-design-skills) (MIT). It is
inspiration only: no code or text was copied. Details are in [NOTICE](NOTICE).

## License

[MIT](LICENSE). Every install carries `LICENSE` and `NOTICE` in `.agent-kit/`.
