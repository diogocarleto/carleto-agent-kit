# Introducing a migration layer where a stack has none

**Read this only when the stack ships no `conventions/backend/migration/`.** Not globbed — `core.md`'s
invariants still govern whatever you build.

**First, do you need one at all?** Most projects run a migration once, or a handful of times, ad hoc —
`core.md`'s four invariants are enough on their own. A migration layer earns its place only when this
stack expects migrations often enough to want a house shape, and needs something ad hoc coordination does
not give you: a standard place to record blast zones, a repeatable characterization-test harness, or a
documented equivalence-proof method tied to this stack's own test tooling. One migration is not a reason
to build this — apply `core.md` directly and move on.

**Then decide what this stack's "unit" is, once, and write it down.** `core.md` leaves it deliberately
open — a module, an endpoint, a workflow — because the right boundary depends on how this stack's code is
organized and tested. Pick one and state it in the recipe; every future migration on this stack inherits
the choice instead of re-deciding it mid-migration.

**The minimum shape**, in dependency order:

| Piece | Responsibility | Decide |
|---|---|---|
| blast-zone map | records safe / needs-a-test / human-only before editing starts | where it lives, and what format future agents can read and update |
| characterization harness | pins legacy behavior as tests, one unit at a time | which of this stack's test tools captures input/output pairs cheaply |
| unit checklist | defines "finished" for one unit | the boundary decided above, plus what must be true to call it done |
| equivalence proof | shows old and new agree | this stack's fastest path to running the same suite (or replaying characterization tests) against both |

**Then write the recipe**, and make it carry what `core.md` cannot: this stack's naming and placement for
migrated code, where the blast-zone map and characterization tests actually live, and the exact commands
that prove equivalence here. `core.md` carries the invariants — do not restate why they matter, state how
*this* stack expresses them.
