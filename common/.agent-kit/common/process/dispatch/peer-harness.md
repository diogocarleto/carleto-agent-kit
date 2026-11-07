## Peer-harness dispatch (opt-in)

A third dispatch target beside *inline* and *in-harness subagent*: a **peer** — any model reachable from
your shell. The orchestrator is **whoever owns the shell** (Claude, Codex, or a local model under
`codex --oss`); it dispatches with one of **two verbs**, chosen by the peer you want — not by who you are:

- **`claude -p`** → a Claude peer.
- **`codex exec`** → a Codex/OpenAI peer (`-m <model>`), or a **local** peer
  (`--oss --local-provider lmstudio -m <model>`).

So any orchestrator reaches any peer — including a cheap local model dispatching *up* to a frontier one.
Use it for throughput (fan disjoint work across models), diversity (an independent second-model pass), or
**advice** — ask a stronger peer how to split the work *before* delegating; the orchestrator keeps the
plan, it just borrows judgment.

- **Opt-in only.** Fires *exclusively* on an explicit ask — **`delegate <unit> to {codex|claude|local}`**,
  `/peer-dispatch`, or a standing ask the owner wrote into a project-owned setting that an installed
  decision add-on's manifest names — for the calls that setting covers only; a manifest alone never asks
  (`.agent-kit/common/process/planning/decision-addon.md`). Otherwise classify per
  `agent-dispatch.md` Step 1 and dispatch in-harness.
- **Same-harness dispatch is for the local case.** Inside real Claude/Codex, fan out with the native
  subagent tool, not these verbs. A local `codex --oss` orchestrator has *no* subagent tool, so the verbs
  are its only fan-out — even to another local model. Nested chains (Claude → Codex → Claude) are allowed,
  not encouraged: each hop loses context and adds a gate.
- **Tiers, possibly inverted.** Tier and model come from `agent-dispatch.md`'s Step 2 table, effort from
  the plan; only peer-specific **flags and mechanics** live in `/peer-dispatch`. When the orchestrator is a
  cheap local model, the "orchestrator is the priciest pool" rule flips — dispatch *up* for capability, not
  *down* for cost.
- **You stay the orchestrator.** Partition files into disjoint sets so you and the peer never touch the
  same paths — that, not any sandbox, prevents clobber (parallel work gives the peer its own git worktree).
- **Peer output is untrusted until reviewed** — the same review + compile + test gate and orchestrator-owned
  checkpoint as any dispatch (`loop-steps.md`). The model that wrote it never changes the gate.
- **Procedure** (command shapes, bridge injection, network gate, output capture) lives in the
  `/peer-dispatch` skill.
