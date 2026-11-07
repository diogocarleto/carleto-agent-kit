# carleto-agent-kit — Codex / Cursor / VS Code entrypoint

You are editing the **kit itself** — the source/catalog that distributes the shared agent layer
(Claude Code + Codex CLI + Cursor + VS Code Copilot) into other projects.

⚠ **This repo does not install the kit into itself.** No stack's conventions apply here — it is markdown
and shell, so there is no installed `.agent-kit/` and no `/backend`-style layer to load. What the kit
ships lives under `common/` and `stacks/`: treat those as **the product you are editing**, not as rules
to follow. The exception is the process layer named below — those four are the kit's own working rules
and they do apply here.

⚠ **A `.agent-kit/…` path inside those shipped docs resolves to `common/.agent-kit/…` here.** They are
written for a consumer, where install has flattened them; this repo has no `.agent-kit/`, so
`.agent-kit/planning/TEMPLATE.md` means `common/.agent-kit/planning/TEMPLATE.md`.

## Read these first — they are not loaded for you

Codex never auto-loads this file (it reads only root-to-cwd `AGENTS.md`), and `@`-imports expand only in
Claude's `CLAUDE.md`, so this file names what it needs. Read it by hand, or have `/peer-dispatch` pass it.
**Read each of these before changing anything**, in order:

1. **`README.md`** and **`CONTRIBUTING.md`** — together the source of truth for this project: what it is,
   the stacks it ships, how to install it, the three delivery natures, the promotion loop, and the
   guardrails for editing the kit. Everything below assumes you have read both.
2. **`common/.agent-kit/common/process/planning.md`** — where plans live, and the status/folder lifecycle.
3. **`common/.agent-kit/common/process/agent-dispatch.md`** — when to dispatch, which tier, which effort.
4. **`common/.agent-kit/common/process/shell-hygiene.md`** — the pre-flight gate on every shell command.
5. **`common/.agent-kit/common/process/terminology.md`** — never translate an English-rooted technical
   term when writing in another language.

The *process* those docs point at is **not** always-on: `common/.agent-kit/common/process/planning/`
(workflow · slice re-evaluation · the per-phase loop) and `common/.agent-kit/common/process/dispatch/`
(loop-step ownership · peer verbs · what ships with a dispatch). Read them when you are planning or
executing a feature here, not on every task.

If you skip step 1 you will propose changes that violate the delivery model with complete confidence —
the failure mode `CONTRIBUTING.md` → *Dispatching a review of a kit change* exists to describe.

## Verify before you assert

The kit's docs make factual claims about framework modules that may be **checked out on your machine**.
Settle a claim by reading that source, not by reasoning about the doc. Run `./verify.sh` before
committing; it is the gate.

---

This file is the Codex half of a pair. [`.claude/CLAUDE.md`](../.claude/CLAUDE.md) is the same entrypoint
for Claude, which `@import`s the same six documents. **Keep the two in step whenever either changes** —
nothing gates them.
