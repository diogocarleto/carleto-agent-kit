# Diagrams in docs

A diagram says **who calls whom, in what order, and who owns what** — the questions prose answers
slowly and a wrong answer to which costs a refactor. It applies to any doc that may carry one: a
feature plan (`### Shape`, see `.agent-kit/planning/DIAGRAMS.md`) or module memory (below).

## The test — argue, don't display

**Strip every label: does the structure alone still teach the design?** If yes, it's a diagram. If no,
it's an inventory with boxes around it — delete it and write bullets. `doc-style.md`'s cut list applies
unchanged: draw only what carries a decision, never what a `grep` answers.

## Picker

| The thing that could be got wrong | Type | Format |
|---|---|---|
| ordering · error channel · compensation · external provider in a flow | `sequenceDiagram` | mermaid |
| branching rules · routing · retry/fallback · screen flow | `flowchart` | mermaid |
| status / lifecycle transitions | `stateDiagram-v2` | mermaid |
| who depends on whom · contracts · pattern being applied | `classDiagram` | mermaid |
| cardinality and which side owns the reference | `erDiagram` | mermaid |
| module / package / file moves, layer stacks | tree | ASCII |

Nothing else. **C4** is `architecture.md`'s altitude, not a diagram's here; gantt · pie · timeline ·
journey · mindmap · sankey encode no design decision anyone could get wrong.

## Class diagram — the relationship rules

The type that answers "who depends on who", so it carries the most rules:

- **Type every edge.** `<|--` inheritance/realization · `*--` composition (owner controls lifetime) ·
  `o--` aggregation · `-->` association · `..>` dependency. A diagram of bare `-->` is the inventory
  smell — the arrow *kind* is the design decision ("does the service own this or just reference it?").
- **Stereotype the contracts** — `<<interface>>` / `<<abstract>>` on SPI types.
- **Name the pattern** when one is applied — `<<Strategy>>`, a note on the Adapter, the Factory behind
  the impls — so review can judge a deviation against `patterns.md` / `design-principles.md`.
- **Light ordering via numbered edge labels** (`1: create`, `2: publish`). If the ordering *is* the
  point, use `sequenceDiagram` instead.
- **Members only when contested** — the nullable field under debate, the SPI method being added. Never
  a full class dump.

## House style

- **Mermaid for anything with arrows**, in a fenced `mermaid` block — preferred over ASCII art: it
  costs a fraction of the tokens, references a joined node by id instead of repeating it, edits one
  edge per line, and a parser can check it. ASCII (a `text` block) or an indented list only for
  containment and hierarchy — dir trees, layer stacks — where indentation is the geometry.
- No HTML, SVG, or image files.
- **No theming or styling** — no `%%{init}%%`, `classDef`, `style`, or colors. Docs are read as text as
  often as they're rendered.
- Short node ids, real type names as labels.
- **≤ ~15 nodes.** Past that you're drawing the system, not the point — raise the altitude or split.

## Verify against the code before it ships

⚠ **An unverified diagram is worse than no diagram — it gets obeyed.** Prose that is unsure invites a
question; a diagram that is confident does not.

Check the drawing against the code, not from memory:

- **Every node names something real** — the type, interface, or module exists at the path claimed.
- **Every edge points the way it is drawn** — the dependency direction, the ownership, the call order.
  An inverted arrow is the expensive kind of wrong.
- **Anything you cannot verify comes out**, or carries `[UNVERIFIED]` until it is checked.

## In module memory

Module memory (`.agent-kit-local/modules/<module>/*.md`) may carry a diagram under the same rules, plus:

- **Draw only for a flow with a branch, fallback, or lifecycle that prose struggles with.** A linear
  flow stays a sentence; a dependency list stays a table.
- **At most one per doc.**
- **It replaces the prose it covers** — never adds to it. Cut the sentences the drawing now says.
  Measure net size in bytes/tokens, not lines: Mermaid is one edge per line, so a diagram that grows
  the line count can still be flat or smaller.
- **Altitude.** Labels name types and public methods, not private helpers; a node a `grep` finds is
  noise.
- **Present tense, current code** — drawn from what the module does now, never plan-time intent.
- **No `[UNVERIFIED]`** — cut the node.
- **Re-verify at every re-stamp.** The diagram is a load-bearing line like any other: confirm each
  edge against source before bumping the stamp, or redraw it.
