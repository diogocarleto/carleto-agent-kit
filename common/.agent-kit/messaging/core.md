# Event messaging — invariants

**Prescriptive** — apply these, don't just read them. Framework-neutral, distilled from a real shipped
stack. How a module *works* underneath belongs in module memory (`/module-extract`), not here.

⚠ Stack doc **silent** ≠ mechanism absent. These rules still apply, but if one needs something the stack
may not have (a dead-letter queue, say), **say so and ask** rather than inventing it.

No messaging layer yet? → `reference/adding-messaging.md`.

## Delivery

- **Never *assume* exactly-once.** Unless the transport explicitly offers it, a path is either
  at-least-once or at-most-once, decided by ack timing (below). Where it is at-least-once a consumer
  *will* see the same event twice, after a
  retry, a redeploy mid-ack, or a replay, so **every consumer must be idempotent**: key the effect on
  something stable in the payload (an entity id + version, or an event id), not on "have I run".
- **Never assume ordering** across topics, partitions, or two events from the same producer. If B
  depends on A, either carry A's outcome inside B or make B tolerate arriving first.
- **Publish after commit, never before.** An event published inside a transaction that then rolls back
  is a lie consumers cannot retract. This is what the outbox exists to prevent.
- ⚠ **Your guarantee is set by ack timing, not by intent.** If the transport acknowledges before your
  handler runs, the path is **at-most-once** however the layer is described — and a handler that
  swallows its own exception acks too, losing the event with no trace. Find the ack point in the stack
  doc before you rely on redelivery. If it is pre-handler, that consumer is best-effort **and the outbox
  does not save you** — the outbox's job ended at handoff (below). The fix is on the consumer: make it
  ack *after* processing, on a transport that redelivers when it doesn't.

## Outbox

- For any topic whose delivery must be guaranteed, write the event **in the same transaction** as the
  state change it describes, and let a separate dispatcher publish it. No topic that matters may be
  published on the side.
- ⚠ **An outbox's job ends at a successful HANDOFF. Whether the guarantee continues past it is a property
  of the broker, not of the outbox.** The dispatcher deletes the row once the broker accepts the message,
  so the question that actually decides your end-to-end guarantee is what happens next:
  - a **durable** broker persists the message and redelivers until the consumer acks, so the chain is
    continuous — outbox → broker accepted → consumer ack — with no gap. Two things must hold: the
    dispatcher waits for acceptance before deleting, and consumers ack **after** processing, not on
    receipt.
  - an **in-memory, fire-and-forget** transport does not. Once published there is nothing to redeliver
    from, so a consumer failure loses the event and the outbox is none the wiser.
  One outbox often feeds both, which makes this a **per-topic** property rather than a system-wide one.
  Establish which one a topic has before anyone calls it "guaranteed delivery".
- What the outbox buys either way: the event **survives a crash before publish**, and **only one instance
  claims a given row at a time** — via an owner/lease, a `SKIP LOCKED` select, a leader-elected scheduler,
  or CDC tailing. Note "at a time", not "ever": a lease that expires while the holder is merely slow lets
  a second instance publish the same row, which is one of the ways duplicates reach consumers.
- Consumer-side durability is a **separate** mechanism from the outbox. Know which retry you actually
  have: transport redelivery, a library's own catch-and-retry, or an interceptor on your method. They are
  not interchangeable, and a handler that swallows its exception silently disables the middle one.

## Retry and acknowledgement

**No hand-rolled retry loops in a consumer.** Retry belongs to the messaging layer — a loop inside a
handler holds the delivery thread and hides the failure from whatever monitors the queue.

⚠ **The single most common defect in event code: retry inside the catch.** If one method carries both
the handler's `try/catch` and the retry policy, the catch sits *inside* the retry budget, swallows the
first failure, and the retry never fires — so it looks configured and does nothing. Separate them:

- the **outer**, registered handler holds the `try/catch` envelope and acknowledges the delivery **once
  the retries are exhausted**, so the broker stops redelivering a message that will never succeed — that
  is why this swallow is legitimate where the one in the ack-timing bullet above is a bug: it happens
  *after* the retry budget, not instead of it;
- the **inner** call holds the retry policy and no catch, so failures propagate into the retry.
- In that **outer** handler, make sure nothing escapes uncaught — in languages that separate ordinary
  errors from fatal ones, catching only the ordinary branch leaves a hole, and what leaks through may
  wedge that consumer or, on a shared dispatcher, others with it. Do not over-swing either: some runtimes
  route interrupts and shutdown through the same top-level type, and swallowing those breaks the process
  a different way.
- Log the error object, not just its message — a message with no stack or trace is unactionable.

Where your stack has **no interceptor** to hold a retry policy, the same invariant takes a different
shape: there is no outer/inner split and no catch at all — let the failure reach the transport and let
redelivery be the retry, which works only if the ack happens *after* the handler (per *Delivery*). The
rule is what stays constant — a catch must never sit inside whatever is doing the retrying. The structure
does not.

Bound the retries, then **park** the message (dead-letter or an error state a human can query). Infinite
retry on a poison message is an outage that looks like health.

## Naming and wiring

- **Topic names live in one place**, declared as constants. A string literal at the producer or consumer
  site is how a topic gets renamed on one side only, and nothing fails until production.
- **Payloads are named types**, not raw maps — a versioned, explicit payload is what lets a consumer be
  updated separately from its producer.
- **A declarative publish seam can silently not fire — prove it does.** An annotation or interceptor that
  publishes on your behalf fails quietly when it fails: the business call succeeds and no event exists.
  The usual causes are stack-specific (method visibility or finality, a missing registration, a setting
  that downgrades a wiring error to a warning), so consult the stack doc rather than reasoning about the
  mechanism — and assert the event in a test rather than trusting the annotation.
- Extract a separate publisher collaborator when one domain emits several events, or when payload
  assembly reaches across domains. That is a **structure** choice about where event-shaping lives, not a
  workaround for a framework quirk.
- **Every consumer must be registered** by whatever mechanism the stack uses. An unregistered consumer
  is not an error — it is simply never invoked, which is the worst failure mode available.

## Testing

- Every producer/consumer pair gets at least one **live-wire** test: publish for real, assert the
  consumer's effect. Mocking the messaging layer tests the mock.
- Unit-test a producer by mocking the **publisher seam** only, asserting payload assembly.
- Prove idempotency explicitly — deliver the same event twice and assert the effect happened once.
