# carleto-agent-kit — Claude entrypoint

You are editing the **kit itself** — the source/catalog that distributes the shared agent layer
(Claude Code + Codex CLI + Cursor + VS Code Copilot) into other projects.

**[`README.md`](../README.md) and [`CONTRIBUTING.md`](../CONTRIBUTING.md) together are the source of
truth** for this project — what it is, the stacks it ships, how to install it, the delivery model, and
the guardrails for editing it. Both are imported below, together with the process layer this repo works by.

⚠ **This repo does not install the kit into itself.** No stack's conventions apply here — it is markdown
and shell, so there is no installed `.agent-kit/` and no `/backend`-style layer to load. What the kit
ships lives under `common/` and `stacks/`: treat those as **the product you are editing**, not as rules
to follow. The exception is the process layer imported below — those four are the kit's own working
rules and they do apply here.

⚠ **A `.agent-kit/…` path inside those shipped docs resolves to `common/.agent-kit/…` here.** They are
written for a consumer, where install has flattened them; this repo has no `.agent-kit/`, so
`.agent-kit/planning/TEMPLATE.md` means `common/.agent-kit/planning/TEMPLATE.md`.

## The planning + dispatch process is on demand

The four imported process docs are the always-on half. The *process* they point at is not:
`common/.agent-kit/common/process/planning/` (workflow · slice re-evaluation · the per-phase loop) and
`common/.agent-kit/common/process/dispatch/` (loop-step ownership · peer verbs · what ships with a
dispatch). Read them when planning or executing a feature here — never `@import` them.

## Verify before you assert

The kit's docs make factual claims about framework modules that may be **checked out on your machine**.
Settle a claim by reading that source, not by reasoning about the doc. Run `./verify.sh` before
committing; it is the gate.

---

This file is the Claude half of a pair. [`.codex/AGENTS.md`](../.codex/AGENTS.md) is the same entrypoint
for Codex, Cursor and VS Code, which have no `@import` and name the docs explicitly instead. **Keep the
two in step whenever either changes** — nothing gates them.

@../README.md
@../CONTRIBUTING.md
@../common/.agent-kit/common/process/planning.md
@../common/.agent-kit/common/process/agent-dispatch.md
@../common/.agent-kit/common/process/shell-hygiene.md
@../common/.agent-kit/common/process/terminology.md
