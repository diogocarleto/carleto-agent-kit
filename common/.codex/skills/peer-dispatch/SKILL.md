---
name: peer-dispatch
description: Delegate a file-disjoint sub-task to a peer model via `claude -p` (Claude peer) or `codex exec` (Codex/OpenAI or local peer), reusing the agent-dispatch tier system. Use when the user says "delegate <unit> to {claude|codex|local}" or invokes /peer-dispatch — to fan disjoint work across models for throughput, for an independent second-model pass, or to ask a stronger peer how to split the work before delegating. Peer output runs the normal review+compile+test gate before checkpoint.
---

# /peer-dispatch (orchestrating from Codex or a local model)

You are orchestrating from the **Codex harness** — either Codex itself, or a local model running under
`codex --oss`. Delegate an independent, file-disjoint sub-task to a **peer** model. You remain the
orchestrator: you scope the work, you integrate the result, and the peer's output passes the normal
quality gate (review + compile + test) before any checkpoint.

The peer you pick selects the **verb**, not the other way round:

| Peer you want | Verb |
|---|---|
| Claude | `claude -p` |
| Codex / OpenAI (hosted) | `codex exec -m <model>` |
| Local (LM Studio) | `codex exec --oss --local-provider lmstudio -m <model>` |

This is the Codex-side of the symmetric capability. The Claude-side (orchestrating *from* Claude) lives
in `.claude/skills/peer-dispatch/`.

Load before dispatching: every `*.md` under `.agent-kit/common/process/dispatch/` — glob that directory.
None of it is always-on. `.agent-kit/common/process/dispatch/peer-harness.md` carries the opt-in rule this
skill implements; `.agent-kit/common/process/dispatch/loop-steps.md` carries the checkpoint that stays
with the orchestrator; `.agent-kit/common/process/dispatch/reference-paste.md` says what a peer is handed
from the plan.

## When this fires

- The user says `delegate <unit> to {claude|codex|local}` (e.g. "delegate phase 2 to claude").
- The user invokes `/peer-dispatch`.
- An installed decision add-on makes a peer call the owner set up in a project-owned setting its manifest
  names (`.agent-kit/common/process/dispatch/peer-harness.md`).

Never delegate without an explicit request — such a setting is one, for the calls it covers only.
See `.agent-kit/common/process/dispatch/peer-harness.md`.
Absent an explicit ask, classify per `agent-dispatch.md` Step 1 and dispatch in-harness.

## Procedure

1. **Classify and pick the tier.** Run the sub-task through `agent-dispatch.md` Step 1/2 exactly as for an
   in-harness subagent. The tier maps to a peer model (table below). If the work corresponds to a planned
   phase, the plan's annotated tier governs. **If you are a local orchestrator, the tier inverts** — you
   dispatch *up* to a frontier peer for capability, not down for cost.

2. **Partition the files.** Decide the disjoint file set the peer owns. Nothing in it may overlap what you
   (or another concurrent peer) are editing — that, not any sandbox, is what prevents clobber. State the
   scope explicitly in the prompt. (For *advice* rather than execution, there is no file set — you ask a
   question and integrate the answer yourself.)

3. **Build the command inline** from the template for the peer you chose — there is deliberately no wrapper
   script (see "Why inline").

   **Claude peer** — light injection; Claude auto-loads its own `.claude/CLAUDE.md` and resolves `/skills`
   natively, so the prompt carries the task and scope, not a bridge pointer:

   ```bash
   claude -p --model <haiku|sonnet|opus> --permission-mode acceptEdits --output-format text --max-budget-usd <cap> \
     "You are a dispatched peer, not the orchestrator. <task>. Files in scope: <disjoint set>. Leave every change uncommitted in the working tree and finish by listing the files you changed." > <out.txt>
   ```

   **Codex/OpenAI peer or local peer** — bridge injection is **mandatory**: `codex exec` does *not*
   auto-load `.codex/AGENTS.md`, so without the pointer the peer is convention-blind. Add
   `--oss --local-provider lmstudio` for a local peer:

   ```bash
   codex exec -m <model> -c model_reasoning_effort=<low|medium|high|xhigh> -s workspace-write \
     -o <out.txt> \
     "You are a dispatched peer, not the orchestrator. Read <REPO_ROOT>/.codex/AGENTS.md and follow its routing for this task. Then: <task>. Files in scope: <disjoint set>. Leave every change uncommitted in the working tree and finish by listing the files you changed." < /dev/null
   ```

   - **Keep the role assertion first.** The orchestrator/dispatched-step split in `.agent-kit/common/process/dispatch/loop-steps.md`
     and the commit-and-tag order in `.agent-kit/common/process/planning/execution-loop.md` steps 6–7 are both
     *role-conditional* — and a headless peer looks to
     itself like a top-level session, with `git commit`/`git tag` granted. Six words inherit the rules.
   - **`<REPO_ROOT>` must be absolute** (`git rev-parse --show-toplevel`) — `codex exec` inherits your cwd, so
     a relative `.codex/AGENTS.md` silently loads nothing from a subdir and the peer runs convention-blind.
   - **The output file is the return contract**: files changed · what ran and its result · assumptions ·
     anything wanted outside scope. `--output-format json` (Claude) / `--output-schema` (Codex) makes it
     machine-checkable. **Never** capture the event trace — Codex's `--json` is per-event JSONL (215 KB for one
     trivial task); its rollout under `~/.codex/sessions/<date>/` is the post-mortem, greppable on failure.
   - **Omit `--ephemeral`** unless the run is a throwaway probe — it drops that trace and forecloses
     `codex exec resume`, turning a fix-up round into a cold re-dispatch.
   - `--max-budget-usd` (Claude, `-p` only) is a hard spend ceiling; Codex has no equivalent.
   - `< /dev/null` (Codex) prevents a stdin-wait hang in non-TTY shells.
   - **`--permission-mode acceptEdits` is required for a Claude peer that edits** — verified: without it
     `claude -p` refuses to write (the kit's `settings.json` grants no `Edit`/`Write`, and `-p` has no user to
     prompt). Drop it only for an advice-only call. Add `--add-dir` to read a sibling project.

4. **Mind the network gate (launch-time).** Dispatching to any **hosted** peer (`claude -p`, or
   `codex exec` to a hosted model) needs network — but Codex sandboxes block it by default, and a running
   Codex can't grant itself network mid-session. Launch Codex with least privilege:
   `-s workspace-write -c sandbox_workspace_write.network_access=true` (network on, writes still confined
   to the workspace). A **local** peer (LM Studio on localhost) needs only localhost reachable, no internet.
   Do **not** use `--dangerously-bypass-approvals-and-sandbox`. A hosted dispatch silently fails under a
   network-blocked sandbox (`read-only`, or `workspace-write` without `network_access`).

5. **Run it.** For sequential delegation, wait. For parallel throughput (you keep working while the peer
   runs), give the peer its own git worktree — `claude -p -w <name>` or `codex exec -C <worktree>` — so the
   trees never collide; background the run and pick up the result when it lands.

6. **Review before integrating.** Read the captured output / diff and run it through the normal per-phase
   gate: the right code reviewer plus compile and tests for every in-scope module. Peer output is untrusted
   until it passes — the model that wrote it never changes the gate. Only then checkpoint.

   **Delegating the review itself.** You can make the review→fix pass a *second* dispatch: after the
   implementation peer returns, send a **fresh** peer (never the author — via `claude -p`, `codex exec`, or a
   local model) the review → fix → re-review → test loop. It runs the loop but **returns its diff for you to
   checkpoint — the peer does not commit or re-stamp**. The loop shape and checkpoint ownership are not
   peer-specific and are not restated here; they live in
   `.agent-kit/common/process/dispatch/loop-steps.md`. This skill only adds the cross-model mechanics.

## Model and effort

**Model comes from `agent-dispatch.md` → Step 2** (the single tier→model map; not repeated here).
**Effort comes from the plan** — the phase's `Effort:`, falling back to its slice's; `medium` for ad-hoc
work. Passing it is mandatory in both directions: `-c model_reasoning_effort=` (Codex) / `--effort`
(Claude). OpenAI's own default is `medium`, but omitting the Codex flag inherits whatever
`~/.codex/config.toml` sets instead — which may be set higher. Always pass it explicitly.

> **Freshness fallback.** A rejected `-m` fails loud (HTTP 400) — a round-trip, not a wasted dispatch. Drop
> `-m` for the harness default (`model =` in `~/.codex/config.toml`), or probe once. Some ChatGPT-account
> users hit this as a gating bug on the newest names — `400 "model is not supported when using Codex with
> a ChatGPT account"` while API-key auth works (openai/codex #46304, #32036) — same fallback applies.
>
> **Local peer.** Add `--oss --local-provider lmstudio -m <model>` to reach an LM Studio model; pick by
> capability/context, there is no tier row for it. A local model has no architectural tier of its own — when
> the work needs that judgment, a local orchestrator dispatches it *up* to a hosted peer.

## Notes

- **Bridge injection is for `codex exec` only.** Claude auto-loads `.claude/CLAUDE.md` and resolves its own
  `/backend`, `/frontend`, ... — don't pass skill paths. Codex peers must be pointed at `.codex/AGENTS.md`;
  from it they self-route the same way.
- **Point at the plan, don't paste it.** For a planned phase, pass the plan's *path* + phase number and let the
  peer read it. Paste only the `## Reference` → Symbol-map rows it needs
  (`.agent-kit/common/process/dispatch/reference-paste.md` → tier-gated paste): cheaper than pasting the
  Reference, and it avoids the re-investigation that pasting nothing causes.
- **`codex exec` ignores `trust_level`** — it runs `approval: never`, confining writes to
  `[workdir, /tmp, $TMPDIR]`, so `-s workspace-write` needs no prompt even in an `untrusted` project (trust
  gates the *interactive* dialog only). Reads are unconfined — siblings resolve via `structure.yml` →
  `related_projects`, no extra flag.
- **Dispatch-for-advice.** The peer need not *execute* — a local orchestrator can ask a frontier peer "how
  should I split this work?" and use the answer to delegate the rest itself. The orchestrator owns the plan;
  it just borrows judgment. No file set is partitioned for an advice call.
- **LM Studio model metadata.** Codex may warn `Model metadata for <model> not found … fallback metadata`
  for a local model; it still runs but can degrade — register the model's metadata in LM Studio if it bites.
- **`claude -p` / `codex exec` run non-interactively** and print the final answer to stdout / `-o`; redirect
  or capture it.
- **Keep delegated units genuinely independent.** Tightly-coupled, context-heavy work (design synthesis,
  cross-slice judgment) stays with you — delegation loses the conversational context that makes the call good.

## Why inline (no wrapper script)

Build the command inline; never ship a wrapper. A wrapper would hide the real privileged command (model,
sandbox, prompt) at approval time, force a broad `bash:*` allowlist instead of `claude:*` / `codex:*`, and
ship an active executable to every consumer. Inline keeps it visible, narrowly allowlistable, and the kit
docs-only.
