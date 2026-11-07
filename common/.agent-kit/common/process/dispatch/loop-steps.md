## Loop-step dispatch & checkpoint ownership

The per-phase execution loop (`.agent-kit/common/process/planning/execution-loop.md`: implement → review → fix → test → refresh memory → commit → tag → tick + re-stamp) runs the same whoever executes it. Four rules bind **every** dispatch style — inline, same-harness subagent, and peer alike:

- **Every loop step is a dispatchable unit.** Implement, apply-fixes, run-tests, and the review pass can each stay inline or be handed to a subagent/peer — pick per `agent-dispatch.md` Step 1/2. Nothing forces a step to the orchestrator *except the checkpoint*.
- **The reviewer is always a fresh agent — never the author.** Spawn a new reviewer (or dispatch a fresh peer) so the review has cold eyes; the model that wrote the code never reviews or gates its own diff, and that holds across every re-review turn. Authoring and reviewing are separate dispatches.
- **The checkpoint stays with the orchestrator.** Re-stamping module memory and the commit + tag are yours whatever produced the diff. A dispatched step returns its diff; you read it — that read *is* the gate — then commit and re-stamp. Delegating the *work* never delegates the *checkpoint*.
- ⚠ **A dispatched step can stage without you.** `git mv` and `git add` write to the index, so a later `git commit` picks them up even for paths you never added — which is how one phase's files land in another's commit. Check `git diff --cached` before committing, and prefer telling dispatched agents to run no `git` commands at all.
