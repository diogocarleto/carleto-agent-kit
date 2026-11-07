## Suggested workflow (start to finish)

The skills and agents in this project are designed to compose. A typical feature flows:

1. **Decide** — invoke `/brainstorm` if the idea is still open and may be killed; skip if you've already committed to building it. At its **Forge** register `/brainstorm` runs a kill-or-keep gauntlet and materializes a survivor into `planning/ideas/<slug>.md` (Status `Survived`) — promote that to a feature here. Skip straight to step 2 only when the idea has already survived (or never needed the gauntlet).
2. **Plan** — invoke `/feature-plan` to write `.agent-kit-local/planning/features/<slug>.md` from `TEMPLATE.md`, every slice planned to the depth its volatility allows (`plan-shaping.md` → Plan depth), and add a row to `ROADMAP.md`. Status starts as `Discovery`.
3. **Approve** — user reviews the Test Plan, **and the `### Shape` diagram when the feature has one — which must be *verified against the code* first, not just eyeballed** (`DIAGRAMS.md` → Verify before `Ready`). The diagram ships to every implementer ungated by tier, so an unverified one is a wrong instruction repeated in every dispatch — that is how a single bad arrow compromises a whole feature. Flip Status to `Ready` only once the plan passes `plan-shaping.md` → Ready gate — every slice planned, no unowned deferral, every Acceptance Criterion mapped to a phase. Correcting an arrow costs seconds; correcting shipped code costs a refactor.
4. **Implement** — load conventions for the layer you're touching:
   - Backend work → `/backend`
   - Frontend work → `/frontend`
   - UI design/craft/audit/polish/harden/adapt work → `/ui-design`
   - Cross-cutting → `/fullstack`
5. **Specialized scaffolds** (optional, inside a phase) — invoke when the boilerplate fits:
   - New domain (entity → resource + tests) → `/scaffold`
   - Data migration / one-shot batch script → `/dcr`
   - Module-specific UI memory → `/ui-extract`
6. **Review per phase** — spawn the appropriate code reviewer — the single-layer specialist when the phase touched only backend or only frontend, the full-stack reviewer when it touched both — scoped to every file the phase touched across all in-scope modules.  Apply non-design findings; re-review until clean. A `Design concerns` entry goes to the user — or first to a decision add-on the project turned on (`execution-loop.md` step 2). (Detail in `.agent-kit/common/process/planning/execution-loop.md`.)
7. **Test per phase** — run tests for the in-scope modules (or invoke the `test-runner` agent to pick the right scope). Failing/missing tests block the phase.
8. **Checkpoint** — commit and tag `<feature>/slice<N>/phase<M>`.
9. **Advance** — one phase-close docs commit: tick the phase in the plan and re-stamp the memory of every documented module the phase edited (`execution-loop.md` step 7). Move to the next phase.

Statuses move forward as work completes; flip to `Blocked` if external deps stall progress, `Postponed` if explicitly deferred. `Done` is reached when every Test Plan bullet is checked — and, with a decision add-on on, nothing its contract says holds `Done` (`decision-addon.md`).
