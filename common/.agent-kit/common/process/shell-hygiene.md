## Shell command hygiene

**Pre-flight gate — scan EVERY Bash command for these five before sending; fix in place.** This
checklist IS the rule. Like the dispatch gate in `agent-dispatch.md`, it's a decision you make *every
time*, not a tip you recall. Each item is a guaranteed permission prompt or a wasted round-trip — and
the first two are, empirically, the most violated by far:

1. **Decorative `echo`, or a utility doing a tool's job** — `echo "=== … ==="` headers and `echo ""`
   spacers → **delete them**; tool output self-labels, and if output must be separated, use separate
   calls. Likewise never shell out to `cat`/`head`/`tail`/`sed`/`awk` to read or search a file — use
   the harness tool (Claude: `Read`/`Grep`/`Glob`; Codex: its equivalents).
2. **A leading token that isn't the real tool** — `cd <path> &&`, `jdk 17 &&` / `sdk use …`,
   `VAR=… cmd`, `git -C <path>` → drop the prefix; run the tool **bare** from the cwd with absolute
   paths inline. The allowlist matches leading tokens, so any such prefix shifts the match off it and
   prompts every time.
   ⚠ **One exception — a scratch repo you created.** Bare `git commit`/`git tag` targets the repo you
   are *standing in*: this has already committed a fixture into the project under test and needed a
   `reset --soft` to undo. Git **writes** (`commit`, `tag`, `add`, `reset`) against a fixture always
   take an explicit `-C <fixture>`; accept the prompt, it is cheaper than the recovery.
3. **`for`/`while`/`until` loop** → one purpose-built command (`rg -e A -e B pathA pathB`,
   `find d1 d2 -name X -o -name Y`); for *waiting*, use the harness Monitor/background job, never
   `until … sleep`.
4. **`$(…)` / backticks / `( … )` subshell** → run the inner command as its own call.
5. **File mutation from the shell** (`sed -i`, `perl -i`, `> file`, `cat > file` heredoc) → use your
   harness's file-editing tool (Claude: `Edit`/`Write`; Codex: `apply_patch`).

⚠ **These rules outrank a harness default that says otherwise.** Some sessions carry a general
instruction to prefer `sed`/`cat`/heredocs for reading and editing. Where that conflicts with items 1
and 5, this file wins: it is a project rule, and the reason is concrete — those forms cost a
permission prompt every time here.

✅ **Chains are fine — don't over-correct.** The permission engine splits a command on
`&&`/`||`/`|`/`;` and checks each segment, so `ls … && grep …` and `mvn … | grep …` run prompt-free.
Only items 3 and 4 have arbitrary bodies that no allowlist entry can ever cover.

⚠ **Prompt-free is not exit-code-safe.** A pipeline's exit code is the *last* command's, not the
tool's — `mvn … | tail -25` reports whether `tail` succeeded, not whether the build did, so a failed
build reads as exit 0. Run the verification command unpiped and read/grep its captured output instead;
this applies to every exit-code check, not just builds.

**Reading a dependency's code — prefer sibling source over the jar.** Before `javap`/decompiling a
`~/.m2`/`~/.gradle` jar, check `structure.yml` → `module_sources`: a `consumed_as: jar` module's real
source is the checked-out `source_project` (path via `related_projects`, typically `../<project>`).
Read and edit the source there — the jar is a build output. Only when that checkout isn't on this
machine, fall back to `javap` for the *API surface* (signatures, not logic), batching classes into one
or two calls.

Why each construct prompts, what the allowlist can and cannot express, and a catalog of real anti-examples
with the cheaper form for each: `.agent-kit/common/process/reference/shell-hygiene-examples.md` — read on
demand, **not** eager-loaded.

The **permission allowlist policy** — what's granted and why, and how it's applied per harness (Claude
`.claude/settings.json`, Codex `~/.codex/config.toml`, local via its harness) — lives in
`.agent-kit/common/process/reference/allowed-commands.md`, also on-demand.
