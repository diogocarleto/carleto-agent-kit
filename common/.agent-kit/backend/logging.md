# Backend logging — invariants

**Prescriptive** — apply these, don't just read them. Language-neutral and deliberately narrow, on the same
admission rule as `core.md`: a rule is here only because every stack that speaks to it agrees. The logging
API, correlation across threads or requests, and anything specific to a runtime stay in the stack's
`conventions/backend/`.

⚠ **The stack's `.agent-kit/common/conventions/backend/` wins where they differ** — this file states the
rule, that one states how this stack expresses it. Stack doc **silent** ≠ rule void. This file is edited
upstream in the kit, never in a project; admitting a rule → `reference/adding-backend-rules.md`.

## Messages

- **Pass values as arguments or fields; never pre-build the message.** The message is a constant template and
  the values ride beside it — as placeholder arguments or structured fields — not concatenated or interpolated
  into it. A pre-built message pays for the formatting even when the level is off, and every occurrence reads
  differently, so nothing can group or search them by message.

## Failures

- **Log a failure once, where it is finally handled** — usually the boundary: the request handler, the
  consumer, the job entry point. Code that rethrows, or returns the error to its caller, does not also log it:
  the same failure logged at every layer it crosses is one event with a stack trace per layer, and the duplicate is
  what makes an incident hard to read.

## Sensitive data

- **Never log secrets, credentials, personal data or whole request or response bodies** — at any level.
  Ids and safe metadata only — an id that grants access (a session or lease id) is a credential.

## Levels

Not defined here — stacks mean different things by WARN (an expected failure, or a recoverable one); take the
meaning from the stack doc.
