# Admitting a backend rule — or leaving it in the stack

**Read this only when adding a rule to `core.md`, adding a concern file beside it, or writing a stack's
`code-style.md` or the stack doc that pairs with `design-principles.md` or `logging.md`.** Not read with the directory — `reference/` is on-demand. The layer is edited in the kit
and installed back; an edit made in a project is erased by the next install.

**Admission: no stack that speaks to the rule dissents.** Silence is agreement; a stack that contradicts
the rule, or gives the same word another meaning, keeps it out. The search for dissent is the whole gate —
read every stack's backend docs on the topic, not just the one the rule came from.

- ⚠ Stacks forked from one another agree by inheritance, not independently. Weigh the ones with a separate
  lineage most.
- ⚠ A stack whose team keeps its own base **outside the kit** (a repo `AGENTS.md`, `.claude/rules/`)
  complements it rather than restating it. Where the kit's docs are silent, the base may not be — a
  search that stops at this repo's `stacks/` finds no dissent that exists. Read the base too; `verify.sh`
  cannot see it.
- A candidate with a dissenter is dropped, not softened until it fits — a hedged rule tells every stack
  nothing.
- Write for a project in a language none of the stacks cover: it has no stack doc to correct a rule that
  only makes sense in one language, framework or tool.

**It stays in the stack when** a stack dissents · it is how one language spells a shared idea · a role name
means different things per stack (`core.md` already declines `Result`, `Summary`, `Outcome`, `Context` and `Config`) · it names
a framework, tool or test idiom.

**A new concern is a file drop** — `<concern>.md` beside `core.md`. Every skill and reviewer that reads the
directory globs it, so no skill, agent or Makefile needs an edit — plus its one-line pointer in each stack's backend docs (`verify.sh` fails without it). ⚠ Every file here loads on every backend
task on every stack: add one for a distinct topic, a section of `core.md` otherwise.

**A stack's `code-style.md`** opens with the one-line "Read together with `.agent-kit/backend/core.md`"
pointer and carries only what the core cannot: how its language spells a core rule, the roles it defines
differently, its own mechanics. Don't restate a core rule — the copy drifts, and the stack's wording wins
where the two differ anyway. A core file pairs with stack docs by topic, not filename: the stack's pointer
goes in whichever of its docs holds that topic.

**The gates** — `./verify.sh` checks that every reader names this directory; that every file in it still says
the stack's docs win where they differ; that every stack with a backend layer names each file in it
(`core.md` in its `code-style.md`, any other file in whichever depth-1 `conventions/backend/*.md` holds its
topic — a stack silent on a topic still names the file, which costs it one line); that the generated Codex
reviewer carries a `<!-- source: … -->` marker for each; and that the directory holds none of the runtime,
framework, logging, test or concurrency terms it lists. The last is a tripwire for the usual leaks, not proof
of neutrality: a leak it misses is yours to find.
