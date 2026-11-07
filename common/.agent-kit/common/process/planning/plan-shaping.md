## Plan depth — every slice planned before `Ready`

`/feature-plan` plans **every** slice before `Ready`; no slice waits for a later, unowned pass. Depth
follows **volatility**, classified per slice (forms: `TEMPLATE.md`):

- **Stable** — every input already exists in the codebase. Full depth: `Decisions locked`, a Shape when
  `DIAGRAMS.md` says it earns one, phases with `Tier`/`Reviewer`/`Effort`/`Complexity`/`Reads`, tasks
  naming **file + change + contract**, tests folded into each phase. No method bodies or line-by-line
  code. **Bar: the implementer makes zero design decisions** — any it would need is in `Decisions locked`.
- **Volatile** — depends on an earlier slice's output, an in-flight feature, unmeasured external data, or
  a contested approach. A **Provisional** skeleton: phases with `Tier`/`Effort`/`Complexity`/`Reads` and
  their files; each open fork written `Deferred → resolved at <phase> by <evidence>`; each Provisional
  phase names a `Fallback:` for when the likely option loses. `/feature-execute` promotes it to full
  depth at its slice boundary.
- **Spike** — a phase whose product is a decision, not code: `Timebox:` + `Outcome:`. ⚠ Its evidence is
  **value-sampled** — real values from the source, never a field's name or presence.

Each slice carries `Confidence: high | medium | low` — informational only; nothing prices it yet.

### Ready gate

`Discovery → Ready` requires all of:

1. Test Plan approved; the `### Shape` diagram, if any, verified against the code (`DIAGRAMS.md`).
2. Every slice has ≥ 1 phase — a one-phase slice is fine.
3. Every slice's `Decisions locked` is non-empty — `None — <reason>` is the explicit form, so empty
   always means unplanned.
4. Every `Deferred` decision names its resolving phase — an unowned deferral fails the gate.
5. Every Acceptance Criterion maps to ≥ 1 phase.
6. Product-semantic decisions (what the user sees or gets, not how it is built) are marked
   `owner-confirmed`. One a decision add-on settled passes as its contract says while the add-on is
   on; off, it needs `owner-confirmed` like any other (`decision-addon.md`).
7. Every phase, spikes included, carries a valid `Complexity:` (→ Phase complexity), checked by
   `node .agent-kit/planning/plan-lint.mjs <plan.md>`.

## Re-evaluation during planning

`Discovery → Ready` is not one-shot. Re-evaluate slice/phase shape whenever any of these triggers fire:

- A slice's Affected Code table grows past ~10 rows
- A slice's Test Plan grows past ~8 distinct behavior bullets
- Two phases would each need to read >50% the same files
- A phase forecasts >50K input tokens (rough: 4 tokens/LOC × (read + write LOC) + skill/plan overhead)

⚠ **Length is a smell, not a trigger.** The four above measure *entanglement*, which is what actually forces a split; line count only measures typing. Budget + prune-on-completion: `doc-style.md` → Plan files.

On a trigger, choose:

- **Split the phase** — only if the shared context can be lifted into the plan's `## Reference` section. Splitting without a Reference section forces each sub-agent to re-investigate, which costs more context than the split saves.
- **Keep monolithic, escalate tier** — accept the larger phase with `opus` if the context is too entangled to abstract cheaply.

Document the choice as a one-liner in `Key Decisions`.

## Phase complexity

Each Execution Plan phase carries a `Complexity: <1|2|3|5|8> — <basis>` field (TEMPLATE.md, next to
`Tier`/`Reviewer`/`Effort`), sized by this rubric — distinct from Tier/Effort (**Tier/Effort pick *who*
and *how hard they think*; Complexity sizes *the work***).

**Mechanical baseline** — score four dimensions off the phase's own facts, reproducible by anyone: files
touched, Test Plan bullets owned, layers crossed (backend / frontend / migration / i18n / infra), and
whether it changes a migration or shared contract. Each band below is a **lower bound, not a cap** —
reaching it scores *at least* that row. Starting bands, *initial — the shadow test recalibrates them*:

- **Files touched:** 1–2 → 1 · 3–4 → 2 · 5–6 → 3 · 7–10 → 5 · >10 → 8
- **Test Plan bullets owned:** 0–2 → 1 · 3–4 → 2 · 5–6 → 3 · 7–8 → 5 · >8 → 8
- **Layers crossed:** 1 → 1 · 2 → 3 · 3+ → 5
- **Migration or shared-contract change** (DTO, event payload, index, public API): → 5

**Scoring rule.** Score = the **maximum** across the four dimensions above — e.g. 2 files (→1) plus a
migration (→5) still scores 5, since the migration dimension alone reaches that band.

**Judgment** — at most one Fibonacci step, up or down, with a one-line reason: novelty (inventing a
pattern vs. copying a neighbour), uncertainty (open decisions, unverified premises), risk (security,
data, production contracts).

⚠ **8 is the split signal.** A phase scoring 8 must be re-checked against the bands above and either
split or justified in one line — nothing scores above 8, the same way a human team splits any story
above 8.

⚠ **No backfill.** Score a phase only *before* its dispatch starts, from its planned facts — never in
hindsight once the dispatch has run. This is also why `/feature-execute` stamping or re-scoring a phase at
a slice boundary or decision checkpoint is fine: that phase hasn't been dispatched yet; re-scoring one
that already has is what's forbidden.

⚠ **Complexity sizes planned work only.** Unplanned growth mid-flight — a decision reversal, an added
slice — is the cost model's scope-drift buffer, not something Complexity should try to predict.

⚠ **Shadow only, for now.** Priced points (`points = phases × √files`) are unchanged; Complexity is
recorded so any calibration tool can compare its predictive error against that formula per phase — the
phase is the calibration unit, since each ends in its own checkpoint tag and can be measured separately.
After ~5 reconciled features, pairing per-phase Complexity with actual hours surfaces a
**human-gated proposal** to switch predictors, never an automatic rewrite.
