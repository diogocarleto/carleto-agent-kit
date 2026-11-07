## Agent dispatch policy

Two decisions, in order: **(1) dispatch or inline?** **(2) if dispatch, which tier?** Make both at the start of the task. The orchestrator is usually the most expensive token-source in the session — running multi-file mechanical work inline burns the priciest pool. (The exception is a **local-model orchestrator**, where the economics invert — see `.agent-kit/common/process/dispatch/peer-harness.md`.)

**Rules:**
- **A task outside the two Inline carve-outs in Step 1 must be dispatched.** Mechanical-feeling cross-file work is **not** exempt.
- Make the dispatch decision early — before extended inline work begins. No "should I dispatch?" prelude, no waiting for the user to OK the spawn.
- **Never** ask the user to confirm the dispatch decision — the classification IS the answer.
- State the chosen tier in the dispatch description (e.g. `"Audit layer rules — sonnet"`) and use it (`model:` param). The tier table is a heuristic anchor — escalate/de-escalate per **Adjustments** below.
- Re-classify mid-flight if needed; never drift inline through what should have been dispatched.
- **If the task corresponds to a planned slice/phase, the plan's annotated tier governs** — read `.agent-kit-local/planning/features/<slug>.md` and use the phase tier (or fall back to slice tier). The Step 2 table is only the heuristic fallback for ad-hoc work outside a plan.

**Dispatching *inside* a feature plan is not always-on.** Loop-step ownership and the checkpoint rule, the opt-in peer-harness verbs, and what of a plan's `## Reference` ships with each dispatch live in `.agent-kit/common/process/dispatch/`, globbed by `/feature-plan`, `/feature-execute` and `/peer-dispatch`.

### Step 1 — classify the task before starting

Pick one of three buckets *now*. No mid-task re-decision; if classification turns out wrong, stop and re-classify, don't drift.

- **Inline — 1-line obviously-correct edit.** Flip a modifier, drop an annotation argument, rename a single symbol. Spawn overhead exceeds savings.
- **Inline — design synthesis, plan judgment, cross-slice trade-offs.** Delegation loses the conversational context that makes the call good.
- **Dispatch — anything else.** Touches more than one file, more than one layer, scaffolds new boilerplate, audits a pattern across the tree, or needs a build/test to verify. Mechanical-feeling work still goes here; "mechanical" is not a synonym for "inline."

Three small edits across three files is still cross-file → dispatch.

### Step 2 — pick the tier

Models listed per cell are Claude / Codex equivalents — pick the one matching the CLI you're running in.
For local models served by LM Studio, keep the harness tier (`codex --oss --local-provider lmstudio`)
and choose the nearest local model by capability/context length; do not create a separate docs surface.
A local model is not only a model *behind* a harness — it can also be the **orchestrator** or a **peer**
(see `.agent-kit/common/process/dispatch/peer-harness.md`).

Currently available Codex models are the **`gpt-6`** family, addressed **by suffix**: `gpt-6-astra`
(flagship), `gpt-6-sol` (mid), `gpt-6-luna` (efficient). The prior `gpt-5.6` family (`-sol`/`-terra`/
`-luna`) and the `gpt-5.5`/`gpt-5.4`/`gpt-5.4-mini` fallbacks still resolve; pricing and a tier-remap trap
between the two families are in `.agent-kit/costs/model-rates.md` → OpenAI (Codex).

| Sub-task profile                                                | Model (Claude, Codex)                    |
|-----------------------------------------------------------------|------------------------------------------|
| Single-symbol lookup, file enumeration, mechanical grep         | `haiku`, `gpt-6-luna`                    |
| Running tests/builds and parsing output                         | `haiku`, `gpt-6-luna`                    |
| Single-file read-and-summarize (narrow question)                | `haiku`, `gpt-6-luna`                    |
| Multi-file pattern scan, "where does X cross boundaries"        | `sonnet`, `gpt-6-sol`                    |
| Convention / layer-rule audit on a phase's diff                 | `sonnet`, `gpt-6-sol`                    |
| Cross-file refactor planning, dependency analysis               | `sonnet`, `gpt-6-sol`                    |
| Architectural review spanning >5 files or multiple modules      | `opus`, `gpt-6-astra`                    |

Default to the cheapest tier that fits. The skill (`/backend`, `/frontend`, etc.) tells you the *domain*; this table tells you the *cost tier*. **Availability varies by plan/auth**; if a model in this table is unavailable, substitute the nearest available one in the same tier, or drop `-m` to fall back to the harness's configured default — see `/peer-dispatch` → freshness fallback. This table is the **single** tier→model map: `/peer-dispatch` does not repeat it. What a tier *costs* lives in
`.agent-kit/costs/model-rates.md` — on-demand, never imported here. It ships with every install.

### Effort — stamped in the plan, not derived from the tier

Tier picks *who*; **effort picks how hard they think**. The two are independent axes, so effort is not in
the table above — it is stamped per phase in the feature plan (`Effort:`, falling back to its slice's).
Apply it as `-c model_reasoning_effort=` on a Codex peer, `--effort` on a Claude peer, `effort:` on a
Workflow agent or an `Agent` call — an `Agent` call without it inherits the session's.

⚠ **Never omit it on a Codex dispatch.** OpenAI's own default is `medium`, but `~/.codex/config.toml` can
(and often does) override it higher — omitting the flag silently inherits whatever that local config
says, not a known-cheap default. Ad-hoc Codex work outside a plan: pass `medium` explicitly.

### Adjustments

- **Escalate one tier** if the agent's first pass came back shallow, contradictory, or missed something obvious.
- **De-escalate one tier** if you only need a yes/no, a count, or a location.
- **State the chosen tier in the delegation description** (e.g. "Audit module layer rules — sonnet"). Makes the cost decision auditable in transcripts.

### Self-escalation (lower-tier agents)

When dispatching at any tier **except the Step 2 table's architectural row** for tasks where complexity *might* exceed the tier, include an explicit handoff clause in the prompt:

> *"If you hit complexity beyond this tier (architectural reasoning, cross-domain trade-offs, deep ambiguity, conflicting constraints), stop and return: (a) what you found so far, (b) what's beyond reach and why, (c) a recommended tier for follow-up. Don't produce a shallow guess — declare and hand off."*

The orchestrator then re-dispatches at the recommended tier with the handoff payload as input. Preferred over **Adjustments → Escalate** (which is the fallback for when the agent didn't self-declare and produced a shallow result).

**Scope is a tier position, not a model name** — every Step 2 row except the architectural one (whose
`opus` / `gpt-6-astra` have nowhere to escalate). A `gpt-6-luna`/`gpt-6-sol` or local peer is in scope
exactly like `haiku`/`sonnet`.

### Multi-issue inputs (code reviews, bug lists, pasted observations)

- **Decompose first, classify per item.** When the user pastes a list of issues, split them into independent sub-tasks before picking tiers. Don't bundle them into one mega-dispatch — each item walks Step 1 + Step 2 on its own.
- **Independent sub-tasks may dispatch in parallel; coupled sub-tasks sequence.** Items that touch the same files must run in order to avoid clobber.
- **Research-then-implement.** If an item needs investigation before action ("redesign X — but first see how project Y does it"), split into:
  - **Research agent** (Explore subagent, often `haiku`/`sonnet`) — narrow fact-finding.
  - **Implementation agent** (`sonnet` for mechanical, `opus` for architectural).
  Research finishes first; its output feeds the implementation prompt.
- **Don't over-research.** If the user already stated the conclusion ("X should work like Y because of Z"), skip the research step — apply directly.

### Don't

- Narrate "let me decide whether to dispatch" — apply the classification silently.
- Wait for an "ok to proceed" signal. The doc is the signal.
- Treat "mechanical refactor" as grounds to stay inline. Cross-file mechanical work is the central dispatch case.
