# Backend code style — invariants

**Prescriptive** — apply these, don't just read them. Language-neutral and deliberately narrow: a rule is
admitted only when every stack that speaks to it agrees — a silent stack is not dissent, a contradicting
one keeps the rule out. A language's own mechanics and any role the stacks define differently stay in the
stack's `conventions/backend/code-style.md`. This directory is read whole, depth-1: another backend
concern is a file dropped beside this one. Admitting a rule, or writing a stack's `code-style.md` →
`reference/adding-backend-rules.md`.

⚠ **The stack's `.agent-kit/common/conventions/backend/` wins where they differ** — this file states the
rule, that one states how this stack expresses it. Stack doc **silent** ≠ rule void. No backend
conventions on this stack? These rules, the other neutral layers that load, and the idiom of the code
already in the tree are what applies — don't invent house rules. On such a stack, where that established idiom conflicts
with the naming rules below (a framework's own naming, like FastAPI's `UserCreate`/`UserOut` or Go's
`fs.FileInfo`), the tree wins. This file is edited upstream in the kit, never in a project.

## Naming

- **Name a type by what it is, not how it was produced.** A suffix states its role; use the matching one:

| Suffix | Role | Examples |
|---|---|---|
| `Request` / `Response` | The wire shape of a call's input / of its reply | `UserRequest`, `UserResponse` |
| `Stats` | Snapshot of monotonic counters | `SchedulerStats` |
| `Preview` | Dry-run / read-only output of an operation | `BulkImportPreview` |
| `Options` | User-supplied configuration for an operation | `BulkImportOptions` |

- `Result`, `Summary`, `Outcome`, `Context` and `Config` are not defined here — stacks mean different things by
  them; take the meaning from the stack doc.
- **Never `Data`, `Info`, `Object` or `Wrapper`** — they convey no role. Use the domain noun.
- **A method that does non-trivial computation never reads as a bare noun.** Named like a field, it hides
  that work happens. The verb a stack uses for it is its own call.

## Code

- **Never pass an annotation or decorator argument equal to its default** (where the language has them)
  — omit it; the repeated default hides the value that was actually chosen.
- ⚠ **A method that does a side effect and returns the updated value: capture the return.** An
  `ensureAccount(account)` that creates, persists and returns the account now carrying the new reference
  leaves the caller's local stale, silently defeating the effect for everything downstream in the same
  call. Prefer returning the updated value over mutating a parameter.
- **A module-level function vs an object holding collaborators.** No collaborators and no state → a
  stateless module-level function. Collaborators or per-instance state → an object that holds them.

## Immutability

- **Never mutate a parameter** — produce a new value. (The receiver/`self`, and a decode or output target
  the caller hands you, are the exceptions.)
- **Never return a mutable internal collection** — hand back an immutable one (a copy where the language
  has none), so no caller changes your state through it.
- **Pipeline steps are pure** — nothing inside a map/filter step mutates external state. Collect first,
  then act.
- **Logic is pure; I/O sits at the edges.** Output depends only on inputs — configuration, validation and
  transformation included. I/O and lifecycle effects live at the boundary that owns them.

## Documentation

Bar and budget for every doc comment and comment: `.agent-kit/common/process/authoring/doc-style.md`.
