## Backend conventions — not defined yet

This project installed the **generic** stack, so the kit shipped no **stack** backend conventions.
`/backend` loads this file because it globs the directory and this is what is in it. It still loads
`.agent-kit/backend/` (the language-neutral backend invariants), `.agent-kit/persistence/core.md` and
the standard for the declared database — those are what applies here, not nothing.

**Do not invent conventions from this file.** Instead:

1. Read the code before asserting a rule. `.agent-kit-local/structure.yml` (run `/structure-extract`
   if absent) names the languages, frameworks, layer roots and build commands actually in use.
2. Follow what the codebase already does. Where it is inconsistent, say so rather than picking a side
   silently — the user decides.
3. Offer to write it down. When a rule gets confirmed twice, propose adding it as a real doc here.

### Adding real conventions

⚠ **Do not write them here.** This directory lives under `.agent-kit/`, which the kit **wipes and
rebuilds on every install** — that is the mechanism, not a bug. A convention survives by living in the
kit and being installed back, never by being edited in place.

So: **author it in the kit repo, then reinstall.** Its home is a stack of this project's own —
`stacks/<your-stack>/conventions/backend/` — created per the kit's *Adding a stack*. ⚠ Not
`stacks/generic/`: that one is shared by every project on this stack, and they share no framework, so
anything specific placed there would ship to all of them.

Persistence docs are a variant family (`persistence-<db>.md`, keyed on `frameworks.database`); see
`.agent-kit/persistence/reference/adding-persistence.md`.

One topic per file. Useful first four:

| File | Holds |
|------|-------|
| `code-style.md` | language features, formatter, the roles your types use — the language-neutral kernel is already in `.agent-kit/backend/core.md`; open the doc with a "Read together with" line for it (what goes where: `.agent-kit/backend/reference/adding-backend-rules.md`) |
| `design-principles.md` | SOLID, DRY, composition — YAGNI, code smells, failure-path cleanup and the idempotency anchor are in `.agent-kit/backend/design-principles.md`; open the doc with a "Read together with" line for it. A logging doc likewise opens with a pointer to `.agent-kit/backend/logging.md` |
| `testing.md` | what each layer must prove, what to skip |
| `api.md` | the transport boundary — status codes, payload shape, errors |

`/backend` and the reviewers **glob** this directory, so adding or renaming a file needs no edit to any
skill, agent or Makefile. Once your own stack exists, install it instead of `generic` — this file then
stops being installed.
