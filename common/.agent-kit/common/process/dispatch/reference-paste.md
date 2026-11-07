## Reference section + symbol-first dispatch

When dispatching a sub-task that's part of a multi-phase plan, include the plan's `## Reference` section verbatim in the dispatch prompt. This caches plan-time discovery so each sub-agent starts with shared baseline context instead of re-investigating from cold.

Sub-agent grep policy: check `Reference → Symbol map` and the phase's `Reads:` first; grep only when the answer isn't there. If a grep result turns out to be needed downstream (not a one-off lookup), surface it for the Reference section so the next phase inherits it — the Reference section evolves over the life of the feature.

A multi-phase plan without a `## Reference` section is incomplete — write one before the first dispatch.

**The Reference's *Module memory in scope* rows and the slice's `### Shape` diagram ship with every dispatch, ungated by tier** — it is small, and it is what stops an implementer inventing a different interaction than the one that was agreed. A `haiku` phase needs both as much as an `opus` one — and an agent told which module memory to load stops re-deriving what `/modules` already holds (`.agent-kit/planning/DIAGRAMS.md`).

**Tier-gated paste** (when the phase has a populated `Reads:` list): `haiku` gets only Symbol map entries matching `Reads:`. `sonnet` adds Invariants + Cross-file protocols touching those files. `opus` gets the full Reference including Pre-decided non-changes + Consumer touchpoints. Lower tiers don't propose architectural alternatives, so "what we rejected" is overhead for them.

⚠ Only the **active** slice's Shape ships — a `Done` slice's diagram stays on the page and stops going out (`.agent-kit/common/process/planning/execution-loop.md` → code-anchor lifecycle).
