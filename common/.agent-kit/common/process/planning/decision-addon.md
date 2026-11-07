# Decision add-ons

A design decision goes to the owner. A project may install one **decision add-on** that takes such a
decision first and keeps a record of it. It is installed when `.agent-kit/decision-addon.manifest.md`
exists, and **on** only when the project setting that manifest names says so. Absent or off → every point
below asks the owner, exactly as it always has, and nothing else here applies.

`/feature-plan` and `/feature-execute` read the manifest once, at the start. On → they also read the
**contract** it names. That contract, not this doc, says how to hand a point over, what each result means,
how the plan records it, and what it holds of the Ready gate and `Done`. A contract may change who rules
and when; it never lifts these floors: the owner confirms a `### Shape` diagram, nothing is decided before
a dispatch, the implementer never settles a design concern, and every decision lands in `Decisions
locked`.

**Off, with records left behind** — a plan line pointing at an add-on record (`→ <record id>`, with or
without a `Deferred` clause) is an ordinary decision: the owner rules it as any other, and the line
becomes an ordinary locked one. A product-semantic one passes Ready gate 6 only as `owner-confirmed`.

## Decision points

| Point | Skill |
|---|---|
| A fork with ≥ 2 viable options the owner has not already ruled on | `/feature-plan` |
| A verified `### Shape` diagram — the owner still confirms it, whatever the add-on decides | `/feature-plan` |
| A review's design concern (`execution-loop.md` step 2) | `/feature-execute` |
| A `Deferred` line pointing at one of the add-on's records | `/feature-execute` → Decision checkpoint |

⚠ **Never before a dispatch** — whether to dispatch, and at what tier, stays `agent-dispatch.md`'s call.

## What an add-on ships

A skill in both harness mirrors, the manifest, its contract and its own docs — never a change to a core
rule — and never an edit to a core file: the kit's lists of its own skills and files do not name it. Its
installer stamps each of its skill dirs with a `.synced-from`, which is how `validate-skills` checks its
mirrors and the Codex pointer list finds it. A peer-harness call it makes needs the owner's standing ask: a project-owned setting the owner
wrote, which the manifest names (`.agent-kit/common/process/dispatch/peer-harness.md`).
