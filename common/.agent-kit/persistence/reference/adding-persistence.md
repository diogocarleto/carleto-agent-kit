# Authoring a stack's persistence layer where it has none

**Read this only when the stack ships no `.agent-kit/common/conventions/backend/persistence-<db>.md` for
the declared database.** Not globbed — `core.md` and the engine variant beside it still govern whatever
you write.

**It is a variant, not a fork.** The layer is a variant family keyed on `frameworks.database` in
`.agent-kit-local/structure.yml`, and the declared value **is** the filename suffix. A second database on
the same stack means a second `persistence-<db>.md` beside the first — never a second stack.

**Write it from the app that exists, not from the access library's documentation.** That documentation is
reachable from every consumer, so a settings table or an API walkthrough is redundant on day one and wrong
the day the library moves. Carry what it cannot tell a reader: **the shape this project settled on**, and
**what fails silently** if you pick another.

**Settle these once and say so in plain words** — each one differs between existing stacks, so a doc that
leaves one unstated has every future author guessing:

| Decision | Why it must be stated |
|---|---|
| Is mutating a loaded object a write? | change tracking writes at commit; an explicit-write API writes nothing — both fail silently |
| What a whole-record save does | insert-or-replace, insert-or-merge, or nothing without an explicit call — the half-filled-object loss hides here |
| How the version is declared and checked | which marker the access layer honours, and how a lost race surfaces — a wrong marker is silently ignored |
| What the transaction boundary covers | which manager enlists this store, and what happens with two stores in one app |
| Where retry lives | a caller with no transaction of its own — and how this stack's boundary lets a call re-enter it fresh |
| How criteria finders page, and are named | the paging type and the naming convention differ per stack |
| Who owns schema and indexes | the migration tool, the unit granularity, and that nothing is generated at startup |
| How a duplicate key reaches the service | the error type a unique violation arrives as, so it maps to a business 4xx |

**Then state what a reader must act on**: the repository shape, the one place driver and query types may
appear, the id strategy, and the traps — a declaration that silently does nothing, a default that bites at
scale. `core.md` carries the invariants and the engine variant carries engine facts, so don't restate
either; state how *this* stack expresses them.

⚠ **Say which access-library version you wrote it against, and take it from the build's own dependency
management** — never by analogy with a sibling library's version number, which can resolve cleanly to the
wrong generation.
