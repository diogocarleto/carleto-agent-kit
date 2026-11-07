# Legacy migration — invariants

**Prescriptive** — apply these, don't just read them. Framework-neutral: it ships to every stack, so it
names none. Where a stack ships `conventions/backend/migration/`, that layer is read too and wins where
the two differ; where it does not, this file is the *only* thing `/migrate` gets — so it stands on its own.

A migration moves working code from a legacy stack onto a target stack's conventions, one unit at a time,
not a rewrite-and-pray leap. **`/migrate` models the target only, never the source** — the legacy code is
checked out in the repo, so read it directly. Modelling every source stack a project might migrate off
would mean one doc set per source/target pair, drifting the day the source moves; the code itself never
does.

## Blast zones

Zone the legacy tree by risk **before the first edit**: safe to change freely, needs a characterization
test first, or not touched without a human sign-off. Write it down — a note in the plan, not a private
judgment re-made file by file. Handed a legacy repo with no zoning, an agent treats it all as equally
editable — false: a config typo and a payment calculation are not the same risk, and an unwritten map
keeps that difference invisible until something breaks. Re-zone anything you are about to touch that
isn't already zoned — "not marked" is not "safe."

## Characterization tests first

Pin a unit's current behavior — **including behavior that looks like a bug** — before changing anything
about it: capture real inputs and outputs as tests, then migrate. Skip this and an agent "fixes" behavior
the business quietly depends on, and nothing catches it — the tests it writes next encode what the new
code is *supposed* to do, not what the old code actually did. A suspected bug is a question for a human,
never a silent correction mid-migration. Highest-value step here, and the most skipped — it feels like it
produces nothing, until the day it is what catches the migration being wrong.

## Migrate in whole units

Finish a unit or revert it. A unit is whatever boundary makes "finished" checkable — a module, an
endpoint, a workflow. Old and new paths coexisting is never a valid resting state, not even briefly across
a checkpoint: it is exactly the shape that gets the next agent, or the next developer months later,
picking the wrong one of two implementations, or updating one and not the other. If a unit can't finish in
one pass, shrink the unit — don't widen the window where two versions are both live.

## Pilot one unit, then fan out in gated batches

Migrate **one** representative unit end to end before touching any other, and write down what it took
— the sequence, the traps, the shape that worked. That write-up is the playbook, and nothing else
moves until it exists: units migrated from guesswork are units to redo when the guess was wrong.

Then fan out in **batches**, never all at once. A batch may run in parallel; the next batch does not
start until the current one has passed review and tests. That gate is the whole point — a playbook
that stops working is caught after one batch instead of after forty units, so the cost of being wrong
stays bounded by the batch size rather than by the backlog. Widen batches as confidence grows; when a
batch surfaces something the playbook did not predict, stop, revise the playbook, and only then
resume.

## Equivalence is proven, not asserted

Strongest: run the same test suite against the old implementation and the new one. Fallback:
characterization tests recorded from the legacy behavior, replayed against the new code. "It compiles and
my new tests pass" is not equivalence — new tests encode the new author's assumptions about what mattered,
not the behavior actually running in production. Equivalence is what you show, not what you conclude from
a smooth-feeling migration.

## What this doesn't cover

"Idiomatic" means the target's own conventions — load them the normal way, via that stack's layer skill
(`/backend`, `/frontend`, …); `/migrate` doesn't restate them.

If the target isn't a kit stack at all, the project runs on `generic`, and these five invariants are the
whole of what `/migrate` gives you — no stack-specific layer to fall back on. Treat the migration's own
output as the seed of a future stack: once a real migration settles a shape worth keeping, promote it to
`stacks/<s>/conventions/backend/migration/` the way any convention is promoted, and this file stops being
the only thing on offer.
