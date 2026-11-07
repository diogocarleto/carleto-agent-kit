---
name: peer-dispatch
description: Delegate a file-disjoint sub-task to a peer model via `codex exec` (Codex/OpenAI, or a local LM Studio model with `--oss`), reusing the agent-dispatch tier system. Use when the user says "delegate <unit> to {codex|local}" or invokes /peer-dispatch — for throughput, an independent second-model pass, or advice on how to split the work. (Claude→Claude uses the native Agent tool, not this skill.) Peer output runs the normal review+compile+test gate before checkpoint.
---

# /peer-dispatch (orchestrating from Claude)

You are orchestrating from the **Claude harness**. Delegate an independent, **file-disjoint** sub-task to a
**peer** model. You remain the orchestrator: you scope the work, you integrate the result, and the peer's
output passes the **normal quality gate** (review + compile + test) before any checkpoint.

The peer you pick selects the verb:

| Peer you want | Mechanism |
|---|---|
| Codex / OpenAI (hosted) | `codex exec -m <model>` |
| Local (LM Studio) | `codex exec --oss --local-provider lmstudio -m <model>` |
| Another Claude | the native **`Agent`** tool — not this skill (no shell hop needed) |

This is the Claude-side of the symmetric capability. Orchestrating *from* Codex or a local model (which can
also reach Claude via `claude -p`) lives in `.codex/skills/peer-dispatch/`.

**Read before dispatching** — every `*.md` under `.agent-kit/common/process/dispatch/`; glob that
directory. It is **not** always-on context: `.agent-kit/common/process/dispatch/peer-harness.md` is the
opt-in rule this skill implements, `.agent-kit/common/process/dispatch/loop-steps.md` is the checkpoint
you may never delegate, and `.agent-kit/common/process/dispatch/reference-paste.md` is what a peer gets
handed from the plan.

## When this fires

- The user says **`delegate <unit> to {codex|local}`** (e.g. "delegate phase 2 to codex", "send the mapper
  refactor to the local model").
- The user invokes `/peer-dispatch`.
- An installed decision add-on makes a peer call the owner set up in a project-owned setting its manifest
  names (`.agent-kit/common/process/dispatch/peer-harness.md`).

Never delegate to a peer without an explicit ask — such a setting is one, for the calls it covers only.
See `.agent-kit/common/process/dispatch/peer-harness.md`.
Absent that, classify per `agent-dispatch.md` Step 1 and dispatch in-harness (Claude→Claude is the `Agent` tool).

## Procedure

1. **Classify + pick the tier.** Run the sub-task through `agent-dispatch.md` Step 1/2 exactly as for an
   in-harness subagent. The tier maps to a peer model + reasoning effort (table below). If the work
   corresponds to a planned phase, the plan's annotated tier governs.

2. **Partition the files.** Decide the **disjoint** file set the peer owns. Nothing in that set may overlap
   what you (or another concurrent peer) are editing — that, not the sandbox, is what prevents clobber.
   State the scope explicitly in the prompt. (For *advice* rather than execution there is no file set — you
   ask the peer a question and integrate the answer yourself.)

3. **Build the command inline** from the template below — there is deliberately no wrapper script (see
   *Why inline*). The **bridge-injection line is mandatory** — `codex exec` does *not* auto-load
   `.codex/AGENTS.md`, so without it the peer is convention-blind. Add `--oss --local-provider lmstudio`
   for a local peer:

   ```bash
   codex exec -m <model> -c model_reasoning_effort=<low|medium|high|xhigh> -s workspace-write \
     -o <out.txt> \
     "You are a dispatched peer, not the orchestrator. Read <REPO_ROOT>/.codex/AGENTS.md and follow its routing for this task. Then: <task>. Files in scope: <disjoint set>. Leave every change uncommitted in the working tree and finish by listing the files you changed." < /dev/null
   ```

   - **Keep the role assertion first.** The orchestrator/dispatched-step split in `.agent-kit/common/process/dispatch/loop-steps.md`
     and the commit-and-tag order in `.agent-kit/common/process/planning/execution-loop.md` steps 6–7 are both
     *role-conditional* — and a `codex exec` peer looks
     to itself like a top-level session, with `git commit`/`git tag` granted. Six words inherit the rules;
     don't restate them.
   - **`<REPO_ROOT>` must be absolute** (`git rev-parse --show-toplevel`) — `codex exec` inherits your cwd, so
     a relative `.codex/AGENTS.md` silently loads nothing from a subdir and the peer runs convention-blind.
   - `< /dev/null` — else the peer waits on empty piped stdin in a non-TTY shell.
   - **`-o <out.txt>` is the return contract** (~1.4 KB): files changed · what ran and its result ·
     assumptions · anything wanted outside scope. `--output-schema` makes it machine-checkable.
   - **Never capture the trace.** `--json` is per-event JSONL — 215 KB for one trivial task, scaling with tool
     calls. Codex already persists it under `~/.codex/sessions/<date>/`; grep that, on failure only.
   - **Omit `--ephemeral`** unless the run is a throwaway probe — it drops the trace above and forecloses
     `codex exec resume`, turning a fix-up round into a cold re-dispatch.
   - A **local** peer needs LM Studio running with the model loaded; a missing-metadata warning still runs but
     can degrade.

4. **Run it** with the Bash tool. For *sequential* delegation just wait. For *parallel* throughput (you keep
   working while the peer runs), give it its own git worktree and add `-C <worktree>` so the two trees never
   collide; run in the background and pick up the result when it lands.

   ⚠ **A hosted peer needs network egress from the shell you are running in, and fails *silently* without
   it** — no error, just empty output, which reads exactly like a peer that had nothing to say. This bites
   any orchestrator whose shell is sandboxed, not only a Codex one. If a dispatch comes back empty, rule
   the network out before you conclude the peer failed at the task. (A **local** `--oss` peer needs no
   egress, so it is the fallback when the sandbox cannot be opened.)

5. **Review before integrating.** Read the captured output / diff and run it through the **normal per-phase
   gate**: the right code-reviewer (backend/frontend/fullstack) + compile + tests for every in-scope module.
   Peer output is untrusted until it passes — the model that wrote it never changes the gate. Only then
   checkpoint.

   **Delegating the review itself.** You can make the review→fix pass a *second* dispatch: after the
   implementation peer returns, send a **fresh** peer (never the author) the review → fix → re-review → test
   loop. It runs the loop but **returns its diff for you to checkpoint — the peer does not commit or
   re-stamp**. The loop shape and checkpoint ownership are not peer-specific and are not restated here; they
   live in `.agent-kit/common/process/dispatch/loop-steps.md`. This skill only adds the cross-model mechanics.

## Model and effort

**`-m` comes from `agent-dispatch.md` → Step 2** (the single tier→model map; not repeated here).
**Effort comes from the plan** — the phase's `Effort:`, falling back to its slice's; `medium` for ad-hoc
work. Passing it is mandatory: OpenAI's own default is `medium`, but omitting
`-c model_reasoning_effort=` inherits whatever `~/.codex/config.toml` sets instead — which may be set
higher. Always pass it explicitly.

> **Freshness fallback.** A rejected `-m` fails loud (HTTP 400) — a round-trip, not a wasted dispatch. Drop
> `-m` for the harness default (`model =` in `~/.codex/config.toml`), or probe once. Some ChatGPT-account
> users hit this as a gating bug on the newest names — `400 "model is not supported when using Codex with
> a ChatGPT account"` while API-key auth works (openai/codex #46304, #32036) — same fallback applies.

## Notes

- **`codex exec` ignores `trust_level`** — it runs `approval: never` and confines writes to
  `[workdir, /tmp, $TMPDIR]`, so `-s workspace-write` needs no prompt even in a project marked `untrusted`
  in `~/.codex/config.toml` (trust gates the *interactive* dialog only). Reads are not confined, so a peer
  reaches sibling projects via `structure.yml` → `related_projects` with no extra flag. Never reach for
  `--dangerously-bypass-approvals-and-sandbox`.
- The peer self-routes from the bridge: once it reads `.codex/AGENTS.md` it resolves `/backend`,
  `/frontend`, etc. by itself — do **not** hardcode skill paths in the prompt.
- **Point at the plan, don't paste it.** For a planned phase, pass the plan's *path* + phase number and let
  the peer read it — it has filesystem access. Paste only the `## Reference` → Symbol-map rows it needs
  (`.agent-kit/common/process/dispatch/reference-paste.md` → tier-gated paste). Cheaper than pasting the Reference, and it avoids the
  re-investigation that pasting nothing causes.
- **Dispatch-for-advice.** The peer need not *execute* — you can ask a second model "how should I split this
  work?" and use the answer to delegate the rest yourself. You own the plan; you just borrow judgment.
- Keep delegated units genuinely independent. Tightly-coupled, context-heavy work (design synthesis,
  cross-slice judgment) stays with you — delegation loses the conversational context that makes the call
  good.

## Why inline (no wrapper script)

Build the command inline; never ship a wrapper. A wrapper would hide the real privileged command
(`-s workspace-write`, model, prompt) at approval time, force a broad `bash:*` allowlist instead of
`codex:*`, and ship an active executable to every consumer. Inline keeps it visible, narrowly
allowlistable, and the kit docs-only.
