# One-shot data changes (DCRs) — invariants

**Prescriptive** — apply these, don't just read them. Framework-neutral, distilled from two real shipped
stacks. How a runner *works* underneath belongs in module memory (`/module-extract`), not here.

A **DCR** (Data Change Request) is a one-shot, run-once change to data rather than to schema or code: a
correction, a bulk update, a backfill. It ships as a pair — a production-side unit holding the logic, and a
runner the test harness can invoke on its own.

⚠ **No DCR recipe on this stack? That is expected, not an error.** If
`conventions/backend/recipes/new-dcr.md` is absent, this stack has no DCR layer — say so plainly rather
than inventing a shape, and use whatever migration mechanism the project actually has (Flyway, Liquibase,
Alembic, a framework migration command, a documented manual runbook). Introducing one →
`reference/adding-dcr.md`.

## The number means different things on different stacks

**Read the stack's recipe for what the number is before you pick one.** Two models are both in use, and
assuming the wrong one produces a correctly-shaped DCR with a meaningless name:

- **Sequence** — the number *is* the execution position. Ordering is expressed by renumbering, and a new
  DCR that must run before an existing one forces the later ones up.
- **External id** — the number is a ticket or issue reference and carries no ordering at all. Ordering
  lives entirely in the registry.

⚠ **Never carry the intuition from one stack to another.** This is the single most common way a DCR goes
wrong on a project the author has not worked in before.

## Ordering and registration

- **Registration is optional, and it is what selects batch execution.** An unregistered DCR still runs
  manually; nothing warns you it was left out of the batch. Ask explicitly whether the DCR is registered,
  and record the answer — never infer it.
- **Know which artefact records the order, because only one of them does.** Where the number is a sequence,
  the number and the registry position are the same fact and can be cross-checked. Where the number is an
  external id, the registry list is the *only* record — appending out of habit silently changes what runs
  when.
- ⚠ **Where the two can diverge, running registered DCRs one at a time by number executes a different
  order than the batch does.** That is a real production failure mode, not a hypothetical: it surfaces as a
  constraint violation from a DCR that ran before the one meant to prepare its data.
- **Nothing necessarily tests any of this.** An ordering test over the registry is usually the *consumer's*
  job, not the framework's, so assume it is absent until you have seen it.

## Writing one

Distilled from a real shipped stack's five-rule life-cycle contract. These are the rules the framework
states as prose because only the prose generalizes — apply them whatever the runner looks like.

- **Idempotent — run it N times, get the result of running it once.** The mechanism is a *pending query*:
  one filter defining "still needs work", used both to select rows and to prove progress, with a
  successful mutation making the row stop matching it. Where there is no natural filter (seeding a row,
  creating a route), guard the write with an existence check instead. Re-runs happen — after a partial
  failure, or in a second environment — and a DCR that is not idempotent turns the second run into damage.
- **Know the blast radius before you start.** Count the affected rows with the pending query and log it
  up front. That count is what tells you whether the run is about to do what you expected.
- ⚠ **A failed row must not kill the run.** Wrap **each row** in its own try/catch, tally it as `failed`,
  log it with its id, and continue; reserve the outer try/catch for structural failures — a bad batch read
  or count genuinely should abort. A run that dies on row 3 of 50,000 has done nothing useful; one that
  finishes reporting `failed=2` tells you exactly which two to look at, and re-running retries them for
  free because the DCR is idempotent.
- ⚠ **Prove it landed by querying the database at both ends — a counter is not evidence.** A counter
  proves the code ran; a closing query proves the data changed. Re-run the same pending query at the end
  and log it beside the tallies. The pending count afterwards should equal what you skipped plus what
  failed; log a warning when those diverge, so nobody has to notice by eye.
- **Report progress per batch**, not only at the end — a long run that prints nothing until it finishes
  is indistinguishable from a hung one.
- ⚠ **A DCR is a historical record, not disposable code.** An applied DCR documents what was run against
  production, so it stays in the tree, frozen and readable, after it has run. Two consequences: never
  refactor an applied DCR (editing shared code beneath it silently rewrites the meaning of what already
  ran), and expect the module to accumulate — hundreds of retained DCRs is the normal steady state, not a
  cleanup backlog.
