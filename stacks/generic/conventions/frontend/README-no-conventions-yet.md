## Frontend conventions — not defined yet

This project installed the **generic** stack, so the kit shipped no **stack** frontend conventions.
`/frontend` loads this file because it globs the directory and this is what is in it, and it still loads
`.agent-kit/frontend/core.md` plus the standard for the declared framework.

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
`stacks/<your-stack>/conventions/frontend/` — created per the kit's *Adding a stack*. ⚠ Not
`stacks/generic/`: that one is shared by every project on this stack, and they share no framework, so
anything specific placed there would ship to all of them.

Framework docs are a variant family (`framework-<name>.md`, keyed on `frameworks.frontend`); see
`.agent-kit/frontend/reference/adding-frontend.md`.

One topic per file. Useful first four:

| File | Holds |
|------|-------|
| `code-style.md` | naming, language features, typing discipline, immutability |
| `design-principles.md` | where business logic lives, service/state/component split |
| `testing.md` | what each layer must prove, what to skip |
| `components.md` | component boundaries, state ownership, styling rules |

`/frontend` and the reviewers **glob** this directory, so adding or renaming a file needs no edit to any
skill, agent or Makefile. Once your own stack exists, install it instead of `generic` — this file then
stops being installed.
