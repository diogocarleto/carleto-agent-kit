# Documentation style — clear, concise, accurate

The bar for **every line of prose the project ships** — conventions, module memory, `_root` project
memory, skills, plans, READMEs, commit messages, code comments (Javadoc / JSDoc / docstrings) — **and
every answer you give the user**: **clear + concise + accurate, all three, always.**

A reply is an artifact too. Lead with the answer, cut the preamble and the recap of what was just
asked, and don't narrate work the tool output already shows.

Dense docs burn context budget; on big projects that crowds out real work and causes
errors. Brevity is not polish — it is the point of an on-demand layer.

> **Every line costs context on every future read.** Before writing one, ask if it
> changes what an agent would *do*. If not, it is tax — cut it. Concise + clear,
> always, with the token budget in mind.

## Rules
- **Altitude.** Write the shape, the relationship, the gotcha — not the detail grep
  answers. If a field name, signature, or sub-type is one `grep`/`Read` away, cut it.
  Mental-model docs name the *graph*; per-module memory may go one level deeper; neither
  mirrors code.
- **Economy.** One idea per line. Max one parenthetical per item. Prefer the relationship
  over the list. Delete every word that doesn't change what an agent would *do*.
- **Scannable.** Lead with the noun; bold the key term; gotchas are `⚠` one-liners; prefer
  a table or bullets over a prose paragraph.
- **Accurate.** Verify load-bearing claims against source, historical claims against `git`.
  A confident wrong line is worse than no line.
- **Diagrams:** see `.agent-kit/common/process/diagrams/diagrams.md`.

## Absolutes — where claims break

**A correction's replacement text carries the same source bar as the original claim.** Proving the old
line wrong is not proving the new one right — verify the sentence you are about to write, at source,
before you write it. A claim kept while trimming a doc is one you write — same bar.

The claims that fail are almost always the ones stating an absolute: *only*, *nothing else*, *never
fires*, *always requires*, *X is the exception*. Before writing one, ask what would have to be true
**everywhere** for it to hold, and whether the source establishes that or merely fails to contradict it.
⚠ **Inference from silence is not evidence.**

- ⚠ **An API artifact shows what it declares, not what a specification requires.** A negative claim about
  behaviour belongs as a hedge or a gap marker, not as a fact — it is a claim about an implementation.
- **Cut the exhaustiveness clause rather than narrowing it** when it is not load-bearing for the reader's
  decision. A bounded positive statement is almost always the more useful and the more durable sentence,
  and a list you cannot fully enumerate at source must not be written as one.

## Cut a line if — every surface, prose and code alike
1. It **restates a name or signature** — `Returns the name.` on `getName()`; `@param path the path`.
2. It **documents what doesn't exist** — future providers, planned overloads, "will support…".
3. It **paraphrases a linked doc** — point at it instead.
4. It's **one `grep`/`Read` away** — field lists, sub-types, call sites, enum values.
   ⚠ Worst form: a **count or enumeration of call sites** ("Four sites ask this", "Two entry points",
   "Only X returns this"). It is redundant on the day it is written and *wrong* the day someone adds the
   fifth — and a confidently wrong doc costs more than no doc, because the next reader trusts it instead
   of grepping. State the invariant; let `grep` supply the list. (The JDK documents no method's callers.)
   A **test's** doc comment naming what it guards is different — that is the invariant, not a caller list.
5. It survives only as **"nice to know."**

## Code comments — budget

| Surface | Budget |
|---------|--------|
| **Method / function** | One-sentence summary + `@param`/`@return`/`@throws`. Nothing else. |
| **Type** | ≤ 8 lines: what it's for, and the one thing a caller gets wrong. |
| **Prose paragraph** | Only for what a signature can't carry — threading, lifecycle/ownership, error semantics, nullability, ordering. |
| **Code example** | One per **type**, never per method, only when usage isn't obvious from the signature. |
| **Inline comment** | Only when the *why* would surprise a reader. Never a "what" comment. |
| **Section divider** | One line, a few words (`// ---- helpers ----`). Never a multi-line banner, never a description. |

Any element may carry a comment — public, internal, private — if it clears the bar. Visibility buys no
extra lines. ⚠ `<pre>`, `<ul>`, and `{@link}` are fine *inside* the budget, never a reason to exceed it —
a bulleted list of grep-able facts is still tax, just formatted.

**This budget is the default; app code says nothing more.** A stack whose product is a *published
library* may raise the **type** budget for its public API surface only, declared in its own
`conventions/<layer>/` doc. That buys contract a consumer can't read off the signature — not phantom
features, and never a pass on the cut list above.

## Plan files

- **Budget — prose only.** ≤ ~250 lines of *prose* single-slice, +~150 per added slice. Fenced diagrams,
  `Decisions locked`, and `## Reference` don't count — they carry a decision per line and are what
  prevents rework. Total length never triggers a split; the entanglement triggers in
  `.agent-kit/common/process/planning/plan-shaping.md` do.
- **Prune on completion.** A landed phase is history, not instructions: collapse its checklist to a
  one-line outcome, **replace** `Current State` instead of appending, and drop `Notes` that migrated into
  code comments. **Exception — a `### Shape` diagram is never pruned**: it stays in the plan, archived
  with it; once its slice is `Done`, stop pasting it into dispatch prompts and optionally promote it into
  module memory (`.agent-kit/common/process/planning/execution-loop.md` → code-anchor lifecycle).
  ⚠ **Keep the phase's `Tier` / `Effort` / `Complexity` lines when collapsing** — they are data, not
  instructions: a cost reconcile and its calibration read them off the archived plan, and a collapse
  that drops them erases what the phase ran at (measured: a release phase's `haiku`/`low` vanished, so
  the delivered plan read as all-`sonnet`). Kept lines don't count toward the prose budget. `Reviewer`
  goes with the checklist — no cost or calibration step reads it — unless a reason to keep it is written beside it.
  **A slice header is never collapsed**: its `Tier` / `Effort` are what its phases inherit.
- ⚠ **Scaffolding doesn't ship.** `TEMPLATE.md`'s `>` authoring tips guide the writer — strip them from
  the instantiated plan.

## Commit messages

Same three-word bar. The diff already shows **what** changed — the message carries **why**, and what a
future reader would otherwise have to re-derive from it.

- **Subject:** one line, imperative, scoped — `fix(<area>): <what changed and why it matters>`. A
  subject that restates the filename is a wasted line.
- **Body:** the reasoning the diff cannot show — the defect, the premise that turned out false, what
  was deliberately left out and why. Skip it entirely for a genuinely trivial change.
- ⚠ **No `Co-Authored-By` trailer.** These commits are attributed to the human author only, and that
  is a project rule which outranks a harness default adding one.

## Tighten pass — mandatory before saving any doc
Re-read and cut ~25% (a forcing function, not a measured target): drop grep-able detail, collapse stacked parentheticals, merge
redundant lines. If a sentence survives only because it's "nice to know," delete it.
