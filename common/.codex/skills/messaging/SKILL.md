---
name: messaging
description: Load event-messaging conventions — producers, consumers, outbox and guaranteed delivery, retry placement, idempotency, topic constants, consumer registration, and event test expectations. Use when the task adds an event producer or consumer, configures outbox publishing, wires a topic or bridge, changes an event payload, or writes event integration tests. Companion to the backend skill; use both when the task also touches entities, services, mappers, or resources.
---

Load the event-messaging rules for this task, in this order.

1. **Always** read every `*.md` directly under `.agent-kit/messaging/` — glob that directory, depth 1
   only; `reference/` is on-demand, named below. These are the
   framework-neutral invariants that hold on any stack: at-least-once delivery and consumer idempotency,
   publish-after-commit, what the outbox is for, **where retry must sit relative to the catch**, topic
   constants, seams that fail silently, consumer registration, and the test bar.
2. Then, **if `.agent-kit/common/conventions/backend/messaging/` exists**, read every `*.md` under it —
   glob that directory too. That is this stack's concrete framework: the actual annotations, base payload
   types, package names, registration mechanism and broker wiring.

⚠ **Where the two differ, the stack doc wins** — it states how this framework expresses an invariant that
`core.md` states in the abstract. `core.md` carries the full precedence rule, including what to do when the
stack doc is *silent* rather than different; do not restate it here.

Never apply a class or package name from memory or from another project — read it from the stack doc.
Different stacks ship different messaging modules with different package prefixes.

A stack with **no** messaging layer ships no such directory. That is expected, not an error: step 1 still
applies to whatever you build. If you are **introducing** a messaging layer, also read
`.agent-kit/messaging/reference/adding-messaging.md` — the design checklist, deliberately not globbed
since almost no task needs it.

## Then do the work

**Apply every rule you loaded** — these are conventions, not background reading. Concretely:

- Use neighbouring event code as the structural reference (the backend `src_globs` in
  `.agent-kit-local/structure.yml`), not a pattern from another project.
- Every producer/consumer pair gets at least one live-wire test; unit-test a producer by mocking the
  publisher seam only. Run it with the narrowest scope from `.agent-kit-local/context/build-commands.md`.
- Before finishing, state which delivery guarantee the topic now has and which invariants you relied on —
  especially where the stack doc says the framework does not meet one.
- Use the `backend` skill too when the task touches entities, services, mappers, resources, validators,
  repositories or backend tests; the producer typically lives inside a domain service.

Do not ask for confirmation to load these docs. Proceed with the work.
