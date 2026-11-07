# Backend design principles — invariants

**Prescriptive** — apply these, don't just read them. Language-neutral and deliberately narrow, on the same
admission rule as `core.md`: a rule is here only because every stack that speaks to it agrees. How a stack lays
out its layers, extends and composes stays in its `conventions/backend/design-principles.md`.

⚠ **The stack's `.agent-kit/common/conventions/backend/` wins where they differ** — this file states the
rule, that one states how this stack expresses it. Stack doc **silent** ≠ rule void. This file is edited
upstream in the kit, never in a project; admitting a rule → `reference/adding-backend-rules.md`.

## YAGNI

- **Build what the task needs now.** No speculative abstraction, and no extension point with a single caller.

## Code smells

- **God class** — split it by responsibility.
- **Feature envy** — move the method to the data it reads.
- **Data clumps** — values that always travel together become one value type.
- **Primitive obsession** — a domain concept gets a type, not a raw string or number.
- **Shotgun surgery** — if one new option touches five files, the boundary is in the wrong place.

## Failure-path cleanup must not mask the original error

A cleanup or compensation step run on a failure path (rolling back a reservation, releasing a lock, marking a
record failed) **contains and logs the failure of each of its own steps and carries on with the rest — it never replaces the original error.** If the cleanup's
error escapes, it replaces the one that triggered it and the caller sees the wrong failure. Persist the
terminal state first, then run the best-effort cleanup.

## Idempotency & compensation anchor for external side effects

An operation spanning local state **and** a non-idempotent external call (a payment, a remote resource
creation) can fail between the two steps. Two decisions shape it:

- **Anchor compensation on the side that is *expensive* to undo.** If an orphaned external resource is the
  costly outcome (a charge, a provisioned account) and the external side has no cheap rollback, record locally
  **first**, so a failure leaves a durable anchor to retry or reconcile against. If the external side rolls
  back cheaply and the local writes are the contended part, invert the order. Decide per integration.
- **Make the retry key stable.** The idempotency token sent outward comes from a value that survives a retry —
  a persisted id or a caller-supplied token — never one minted fresh inside the call, which defeats the remote
  side's deduplication.

On failure leave the anchor in an interim or failed state rather than deleting it: it is the retry and
reconcile point, and it gives an asynchronous callback a real record to land on.
