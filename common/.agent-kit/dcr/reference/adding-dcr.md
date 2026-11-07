# Introducing a DCR layer where a stack has none

**Read this only when the stack ships no `conventions/backend/recipes/new-dcr.md`.** Not globbed —
`core.md`'s invariants still govern whatever you build.

**First, do you need one at all?** Most projects already have a migration mechanism (Flyway, Liquibase,
Alembic, a framework migration command). A DCR layer earns its place only when one-shot *data* changes are
frequent enough to want a house shape, and when they need something a schema migration does not give you:
business logic, service reuse, dry-run before commit, or reviewable evidence of what changed. A single data
fix is not a reason to build this — write it as a migration and move on.

**Then decide the number's meaning, once, and write it down.** This is the decision everything else hangs
off, and the one that most often goes unstated:

| Model | Ordering lives in | Costs you |
|---|---|---|
| **Sequence** — the number is the execution position | the number itself; the registry mirrors it | renumbering later DCRs when one must run earlier |
| **External id** — a ticket / issue reference | the registry list, and nowhere else | no cross-check; an ordering mistake is invisible |

Pick one and say so in the recipe in plain words. A recipe that shows a number without saying which model
it is leaves every future author guessing, and `core.md` warns them you might have.

**The minimum shape**, in dependency order:

| Piece | Responsibility | Decide |
|---|---|---|
| unit interface | the contract a DCR implements | what the entry point is called, what it returns |
| runner | lets one DCR be executed on its own | how it is invoked, and from where |
| registry | the ordered set executed as a batch | is registration optional, and what selects it |
| executor | walks the registry | when it runs, and what happens on partial failure |

**Then write the recipe**, and make it carry what source cannot tell a reader: the naming shape **as it
actually renders** (prefix included — check real files rather than an example in a README), where the files
go, whether registration is required, and the ordering rule with its failure mode. `core.md` carries the
invariants, so do not restate them — state how *this* stack expresses them.

⚠ **Add the ordering test yourself.** It is almost always the consumer's job, not the framework's. Without
it, nothing catches a registry whose order stopped matching intent — and on the external-id model there is
no second record to catch it against.
