# Planning diagrams

A plan says *what exists* — tables of files, entities, endpoints. A diagram says **who calls whom, in
what order, and who owns what**: the questions whose wrong answers cost a refactor after the code is
already "done". One diagram earns its place in a plan; a second one rarely does.

`/feature-plan` draws it → `TEMPLATE.md` → `### Shape` holds it →
`.agent-kit/common/process/dispatch/reference-paste.md` ships it to every implementer.

**The shared rules** — the argue-don't-display test, the type picker, class-diagram relationship rules,
house style (Mermaid for arrows, ≤ ~15 nodes, no styling), and verifying against code — live in
`.agent-kit/common/process/diagrams/diagrams.md`. This file adds only what is specific to a plan.

## When to draw one

Draw when **any** fires:

- the slice adds ~5+ types, or spans 3+ layers of one vertical
- it touches 2+ modules, or makes any cross-service / external-provider call
- there's an **ordering, error-channel, or compensation** decision (`patterns.md` / `.agent-kit/backend/design-principles.md` → idempotency: which side is
  expensive to undo)
- a status or lifecycle field is added or changed

Skip for: an additive field, config wiring, single-file evolution, or any design one sentence explains.
An evolving feature usually needs none — decide per feature, never fill the section reflexively.

## Verify before `Ready`

The diagram ships to every implementer ungated by tier, so a wrong edge is not a vague plan, it is a
wrong instruction repeated in every dispatch of the feature.

Before the `Discovery → Ready` flip, run the checks in `diagrams.md` → *Verify against the
code before it ships*, plus: **new things are marked new**, so nobody hunts for a type that does not
exist yet.

Record what you verified in `## Reference` → *Symbol map*, so implementers inherit the check instead
of re-deriving it — the whole point of exploring once, at plan time.

## Contracts — the signatures the drawing commits to

`doc-style.md` says cut what a `grep` answers. **Nothing greps code that doesn't exist yet**, so a
target signature is not restatement — it is a decision, and a missing one shows up as two implementers
writing incompatible code.

The test: **would two competent implementers produce incompatible code without it?**

- **In** — the SPI or interface being introduced · a contested DTO field set (nullable vs required) ·
  the values of a new status enum · the exact endpoint shape.
- **Out** — method bodies, control flow, boilerplate, and anything the conventions or `/scaffold`
  already dictate. That is implementation: writing it here writes the feature twice, and the second
  copy rots.

Keep it in the `### Shape` block beside the drawing — one home, two forms. Mark every new symbol
`(new)` so the verification rule above doesn't try to confirm something that doesn't exist yet.

## Lifecycle

The Shape block belongs to its slice and stays in the plan file for the file's life, archived with it —
**never pruned**. A `Done` slice's Shape stops shipping in dispatch prompts (only the active slice's
ships) and may still be promoted into module memory, never into `architecture.md` — redrawn from the
shipped code under the module-memory rules in `diagrams.md`, not pasted. See
`.agent-kit/common/process/planning/execution-loop.md` → "Code-anchor lifecycle".
