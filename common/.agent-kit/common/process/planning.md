## Planning & Roadmap

Feature roadmap and status live in `.agent-kit-local/planning/`. **Do not load these files unprompted** — they are not always-on context.

Read them when the user asks about features, roadmap, what's shipped, what's in flight, or what to build next:

- `.agent-kit-local/planning/ROADMAP.md` — scannable index of all features with status (Discovery / Ready / In Progress / Blocked / Done / Postponed)
- `.agent-kit-local/planning/features/<name>.md` — **live** plans (Discovery · Ready · In Progress) with scope, slices, and test plan
- `.agent-kit-local/planning/parked/<name>.md` — **paused** plans (Blocked · Postponed); move back to `features/` on resume
- `.agent-kit-local/planning/archive/<name>.md` — **terminal** plans: Done (shipped) or superseded (replaced by a different plan)
- `.agent-kit-local/planning/decisions/` — ADRs and RFCs
- `.agent-kit/planning/README.md` — the planning workflow and status vocabulary

When a feature status changes (slice completed, shipped, postponed, blocked), update the feature file header **and** `ROADMAP.md` in the same change — and move the file if it crossed a folder boundary (→ `parked/` on Blocked/Postponed, → `archive/` on Done/superseded; back to `features/` on resume).

⚠ **Commits here carry no `Co-Authored-By` trailer**, whatever the harness default says — that rule and the rest of the message bar live in `.agent-kit/common/process/authoring/doc-style.md` → *Commit messages*.

**The rest of the process is not always-on.** The start-to-finish workflow, the slice/phase re-evaluation triggers, the per-phase implementation loop and the Reference's code-anchor lifecycle live in `.agent-kit/common/process/planning/`, globbed by `/feature-plan` and `/feature-execute`. (Distinct from `.agent-kit/planning/`, which holds the plan *templates*.)
