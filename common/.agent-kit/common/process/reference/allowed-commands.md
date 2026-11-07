# Allowed commands — permission manifest (agnostic)

This is the **harness-agnostic policy** for the agent's command/tool permissions: *what* is granted,
*why it's safe*, and *how to apply it per platform*. Permissions themselves are **platform-specific**
(Claude, Codex, Cursor, and VS Code Copilot each store them differently) — this doc is the single agnostic layer over
them. For the mechanics of writing commands that match a grant (and avoid prompts), see `shell-hygiene.md`.

## Where the allowlist lives, per platform

| Harness | Permission store | Per-repo? | Kit delivery |
|---------|------------------|-----------|--------------|
| **Claude Code** | `.claude/settings.json` (`permissions.allow`) | **Yes** (committed) | Kit ships `common/.claude/settings.json` as the default baseline → **seeded if absent**; `--reset-defaults` refreshes it. Consumer-specific grants accrue in-place via the built-in `/fewer-permission-prompts` skill. |
| **Codex CLI** | execpolicy `.rules` — **project** `.codex/rules/*.rules` + **user** `~/.codex/rules/*.rules` (`prefix_rule(pattern=[…], decision="allow")`). Codex auto-appends approvals to the user file. | **Yes** (committed) — but the **project** file loads **only when the project is trusted** in `~/.codex/config.toml` (`[projects."<abs>"] trust_level = "trusted"`) | Kit ships `common/.codex/rules/default.rules` → **seeded if absent**; `--reset-defaults` refreshes it. Validate with `codex execpolicy check --rules <file> <cmd>`. (`~/.codex/config.toml` still holds per-project trust + sandbox/approval; peer-dispatch network is in `/peer-dispatch`.) |
| **Cursor** (IDE agent) | `.cursor/permissions.json` (`autoRun.allow_instructions` / `block_instructions`, plain-English) | **Yes** (committed) — merges with `~/.cursor/permissions.json`; a team-dashboard config overrides both | Kit ships `common/.cursor/permissions.json` → **seeded if absent**; `--reset-defaults` refreshes it. ⚠ Heuristic, "not a security boundary"; only effective under the **Auto-review** run mode. **Not** read by Cursor CLI (uses `.cursor/cli.json` with structured `Shell(...)` tokens) or cloud agents (use `.cursor/hooks.json` `beforeShellExecution`) — add those if you need CLI/cloud enforcement. |
| **VS Code Copilot** | `.vscode/settings.json` (`chat.tools.terminal.autoApprove`, per-command prefix/regex → allow, deny, or manual) | **Yes** (committed) | Kit ships `common/.vscode/settings.json` → **seeded if absent** (⚠ a project usually already has a `.vscode/settings.json` — kept intact, so the kit's grants don't land until merged in); `--reset-defaults` refreshes it. Also sets `chat.useClaudeMdFile:false` and `chat.useAgentsMdFile:false` so the generated `.github/copilot-instructions.md` is the single always-on source. |
| **Local models (LM Studio)** | the harness they run under | — | A local model under `codex --oss --local-provider lmstudio` inherits Codex's own approvals and, in a trusted project, `.codex/config.toml`'s `developer_instructions`; no separate store. It can be a model *behind* a harness, the **orchestrator**, or a **peer** (see `/peer-dispatch`). |

> **Trust gate (Codex):** a project's `.codex/rules/` is only loaded if the project is trusted — add
> `[projects."<abs-path>"]\ntrust_level = "trusted"` to `~/.codex/config.toml` (per machine). Without trust,
> Codex falls back to sandbox + approval prompts and ignores the committed rules.
>
> `settings.local.json` (Claude's gitignored per-machine overrides) is **not used** by this kit and is
> deleted on `--reset-defaults` so it can't silently shadow `settings.json`.

## What's in the baseline, and why it's safe

- **Read/inspect (no write/exec)** — `grep`, `rg`, `find`, `ls`, `sed -n`, `cat`, `wc`, `head`, `tail`,
  `javap`, `jar tf`, `unzip -l`, `unzip -p`, `xmllint`. Most are auto-approved by Claude anyway; listed
  for parity and for Codex.
- **Read-only git** — `status`, `diff`, `log`, `show`, `rev-parse`, `rev-list`, `branch`, `ls-tree`,
  `check-ignore`, `stash list`. (`git ls-tree` and `git check-ignore` are *not* in Claude's built-in
  read-only-git auto-approve set — hence the explicit grants, unlike `status`/`log`/`diff` which Claude
  allows anyway; listed for parity + Codex. `check-ignore` reports which gitignore rule matches a path.)
- **Workflow grants** — `Task(backend|frontend|fullstack-code-reviewer | test-runner | Explore |
  general-purpose)`, `Skill(...)`: spawn the kit's agents / load skills. No exec risk.
- **Build & dev** — one grant per mainstream toolchain, so the seed fits whatever stack is installed:
  `mvn:*`, `jshell:*`, `npm:*`, `pnpm:*`, `yarn:*`, `go:*`, `cargo:*`, `uv:*`, `pytest:*`, `dotnet:*`,
  `mongosh:*`, `node .agent-kit/ui/detect.mjs:*` (the kit's `/ui-detect` runner), and
  `node .agent-kit/planning/plan-lint.mjs:*` (the plan Complexity gate). A grant for a tool
  the project doesn't have costs nothing; the alternative is a prompt on every build in a non-JVM repo.
- **Powerful-but-deliberate** — `git add|commit|tag|mv|restore:*`, `mvn:*`: these mutate (commits, build
  side effects). Kept because the kit targets solo repos the author controls and the friction-free loop
  is worth it. **Don't** copy these into a multi-contributor repo without thought — the one judgment call
  when propagating.
- **Peer-dispatch verbs** — `codex exec` on all four surfaces; `claude -p` on Codex/Cursor/VS Code (Claude
  reaches a Claude peer with its native `Agent` tool, so it needs no `claude:*` grant). Granted because
  `/peer-dispatch` is **opt-in** and its output passes the normal review + test gate. ⚠ They do spawn a
  *writing* agent: `codex exec -s workspace-write` confines writes to `[workdir, /tmp, $TMPDIR]` and ignores
  `trust_level` (that gates the interactive dialog only), and a `claude -p` peer writes nothing without
  `--permission-mode acceptEdits`. Codex's `prefix_rule` matches an ordered token prefix, so `-p` must stay
  immediately after `claude`.
- **Docker** — read-only/benign only: `docker info`, `docker version`, `docker wait` (block on a
  container's exit — used by local test-infra scripts), plus `docker ps` (Codex needs the explicit rule;
  Claude auto-approves it). `docker compose:*` / `docker exec` are **not** baseline (they mutate / exec).
  Claude grants `docker info`/`docker version` as `:*` (not the bare exact form) so the common
  `--format '{{…}}'` invocations match; Codex `prefix_rule` and Cursor's prose already cover any suffix.
- **Browser MCP (read-only)** — `mcp__claude-in-chrome__tabs_context_mcp` (reads the current tab-group
  context; no navigation/mutation). Claude-only — Codex/Cursor have no equivalent MCP surface. Other
  claude-in-chrome tools (navigate, click, form input) are **not** baseline; they act on live pages.

## Never allowlist these

In-place file mutations — `sed -i`, `perl -i`, `> file` / `cat > file` heredocs — must **never** go in
the allowlist (a literal approval freezes a useless one-off; a wildcard grants arbitrary file rewrites).
Edit files with the harness's file-editing tool instead: Claude Code `Edit`/`Write`, Codex `apply_patch`.
See `shell-hygiene.md`.

## Project-specific grants stay in the consumer

The kit baseline is the **universal** set only. Project-specific grants — `WebFetch(domain:…)` for a
project's APIs, machine-absolute `Read(/Users/…/**)` paths, language tooling a stack doesn't share
(`pip3 install:*`), etc. — belong in the **consumer's** `settings.json`, not the kit. Let them accrue
per-project via `/fewer-permission-prompts`. They are **not** consolidated back to the kit (they'd ship
to every other consumer as noise), and `--reset-defaults` will drop them — re-accrue rather than upstream.

A grant that turns out to be genuinely **universal** (needed by every stack) is the only kind promoted:
add it to `common/.claude/settings.json` **and** list it above.
