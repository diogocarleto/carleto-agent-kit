## Code Review Guidelines

This file is intentionally short. It describes **how to review**; the rules themselves live in the
convention docs loaded alongside it — globbed from `.agent-kit/common/conventions/<layer>/` plus
`architecture.md`. Those docs are the stack's canonical conventions: apply every rule in them, not
just the headlines below.

### How to Review

1. Run `git diff HEAD` (or `git diff main...HEAD` for a full branch diff) to identify changed files.
2. Read each changed file in full before reporting issues — do not comment on lines in isolation.
3. For each issue, cite `file:line`, show the problematic code, explain why it is a problem, and suggest the fix.
4. Group findings by severity: Critical → Warning → Suggestion.
5. Put each design concern in the `Design concerns` section below, after the severity groups — never among them.
6. End with a short summary: total findings by severity, the number of design concerns, and an overall assessment (approve / approve with suggestions / request changes), plus any residual testing or verification gaps.

### Severity Levels

- **Critical** — Must fix before merge. Logic bugs, security flaws, broken layer rules, data-loss risk, broken serialization/data boundaries.
- **Warning** — Should fix. Code smell, missing validation, performance issues, broken conventions.
- **Suggestion** — Consider improving. Naming, test coverage gaps, minor style issues.

### Design concerns

A **design concern** is a finding whose fix needs a decision the plan did not settle — two or more viable ways forward, or a change to a contract, an ordering or an ownership the plan fixed — **and** where leaving the diff as written is a risk: say what breaks. One you would accept as written is a Suggestion, as is a note with no decision to take. A rule breach with a known fix is a finding at its severity, not a concern.

List them under a **Design concerns** heading after the severity groups; omit the heading when there are none. Per concern:
- **Claim** — what the diff decides, at `file:line`.
- **Why risky** — what breaks, for whom, and the evidence.
- **Options** — two or more, the diff as written counting as one; each with what it costs.

⚠ Only a design concern stops the phase (`execution-loop.md` step 2) — a finding filed elsewhere that meets the definition above is treated as one, since an implementer never settles a design fork.

### What to Check

The canonical rules are whatever the loaded convention docs specify — the specifics (class names,
framework idioms, file layout, test types) vary by stack, so **defer to those docs**. Use the topic
areas below only as a coverage checklist, so nothing whole is missed:

**Backend**
- Module dependency flow and layer rules (resource / service / mapper / repository boundaries)
- Domain modelling — entity / value-object / DTO patterns, mapper rules, serialization & data boundaries
- Language conventions — naming, required language features, immutability, enum contracts
- Doc comments — the `doc-style.md` budget: over-budget types, restated signatures, docs for code that doesn't exist, grep-able lists
- API surface — schema/docs on DTO fields, endpoint conventions, validation groups
- Testing — required test types per layer, layer-enforcement rules, test naming/location, no low-value tests, feature Test-Plan coverage
- Security — validate at the boundary, never log secrets/PII, no secrets in responses or source, approved crypto, authorization at the right layer
- Logging — one logging API, parameterized messages, log exceptions once at the boundary, correlation context
- Concurrency — threading/locking rules, blocking-vs-reactive expectations, bean statefulness, handler latency
- Design — SRP per layer, composition over inheritance, DRY / YAGNI, code-smell heuristics

**Frontend**
- Language & types — enforced language rules, types mirroring backend response DTOs, import discipline
- Layer boundaries — service / store / util / component responsibilities; network calls go through the shared API wrapper
- Component model — the framework's idiomatic component & state rules, styling-system rules, no direct DOM manipulation
- Error handling — the shared error-message helper in user-facing catches; no swallowed errors
- Responsive — mobile-first, no fixed layout widths, adequate touch targets
- Doc comments — the `doc-style.md` budget, on the surfaces the stack's conventions name (others get none)

### Reviewing Without a Topic in the Checklist

If you find code that doesn't map to any topic above, fall back to the loaded convention docs and
`architecture.md` directly. If you cannot find a rule for a pattern but it seems off, raise it as a
**Suggestion** with the reasoning — do not invent rules.
