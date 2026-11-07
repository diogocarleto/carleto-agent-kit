# Introducing messaging where a stack has none

**Read this only when there is no messaging layer yet.** Not globbed — `core.md`'s invariants still
govern whatever you build.

**First, do you need a broker?** An in-process event bus is enough when producer and consumer deploy
together and losing an event on restart is acceptable. Reach for a durable broker only when the consumer
is a separate deployable, or the event must survive a restart.

**Then choose a guarantee per topic, not per system.** Most topics tolerate at-most-once; a few — money
moved, state a downstream must mirror — do not. Only those need an outbox, and the outbox is the
expensive part. Do not pay for it everywhere.

**The minimum shape** of a guaranteed-delivery path, in dependency order:

| Piece | Responsibility | Decide |
|---|---|---|
| producer seam | turns a domain fact into an event, in one place | annotation/interceptor, or an explicit publisher call |
| outbox store | rows written inside the business transaction | where they live, and the indexes the drain needs |
| dispatcher | drains the outbox and publishes | schedule, batch size, how concurrent drains are prevented |
| consumer registry | maps a topic to its handler | explicit list or discovery — and what an unregistered one does |
| park / dead-letter | where a message goes after bounded retries | a queue, or an error state a human can query |
| dedupe store | what makes consumers idempotent — mandatory, and easy to forget because nothing fails without it | what key (event id, or entity id + version), where it lives, retention |

**Directives, whatever the transport:**

- Write the outbox row in the **same transaction** as the state change. If your stack cannot, you do not
  have guaranteed delivery — say so plainly rather than implying it.
- Give the dispatcher an **owner/lease** so two instances cannot drain the same row, and reclaim a stale
  lease after a timeout.
- **Delete the row on broker *acceptance*, not on the publish call returning** — and write down whether
  that broker redelivers on nack. Those two facts are what your "guarantee" actually means.
- Create the **indexes the drain query needs** now. An unindexed drain is fine at ten rows and an outage
  at a million.
- Make the layer **switchable off** by one setting, and make "off" mean no writes — not rows quietly
  accumulating unpublished.
- Fix the **envelope** before the first consumer: bare payload or wrapper, and whether serialization
  embeds type metadata. Embedded type metadata makes life hard for a consumer in another language, and it
  is a one-way door once producers are live.
- Build the **park path** first, not after the first poison message.
- Decide where **retry** lives — transport redelivery, an interceptor, or the dispatcher. Two retry
  mechanisms stacked on one path is how a 3-attempt budget becomes 9.

**Record the guarantee per topic and where retry lives** — in this project's own docs, wherever durable
design notes go. An undocumented messaging design gets re-derived by every agent that touches it, and no
two derivations agree.
