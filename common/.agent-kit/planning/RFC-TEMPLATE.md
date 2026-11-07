# RFC-<NNN> — <what is being proposed>

**Status:** Draft | Under review | Accepted | Rejected · **Date:** <YYYY-MM-DD> · **Author:** <name>
**Scope:** <one line — what this covers, and what it explicitly does not>

> Write an RFC when a significant change needs thinking through *before* committing to it. An RFC
> produces features or ADRs; it is not itself either. Lands in
> `.agent-kit-local/planning/decisions/rfc/RFC-<NNN>-<slug>.md`.

## Why this exists

What forced the question. If nothing forced it, this may not need an RFC.

## Method

How the evidence below was gathered, and what it can't support. Distinguish primary sources from
secondary ones — and say which numbers you'd trust in front of someone else.

## Findings

The evidence, organized so a reader can disagree with your conclusion while accepting your facts.
Tables beat prose where the shape is comparative.

## Proposal(s)

For each — a heading per proposal, so they can be accepted independently:

**Problem.** What is broken or missing today.
**Shape.** The change, at the altitude where it can be argued about — not an implementation.
**Why now / why us.** What makes this tractable here that isn't tractable elsewhere.
**Open calls for `/feature-plan`.** Load-bearing decisions the plan must resolve first. Name them;
never resolve them here — an RFC that pre-decides implementation has skipped the plan's gate.

## Recommendation

Sequence, with the reasoning for the order. Say plainly what you are *not* proposing and why.

## Outcome

<Filled when the RFC closes: what was accepted, what it produced — feature slugs, ADR numbers — and
what was dropped. An RFC with no Outcome never closed.>
