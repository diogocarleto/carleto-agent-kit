# Shell hygiene — detail & anti-example catalog

On-demand companion to the slim `shell-hygiene.md` (which is eager-loaded). Read this when you want the
*why* or a worked example. Not in any `@import` chain or the codex sync list.

File-editing tool names per CLI (referenced throughout — use yours, never a shell mutation):

| Claude Code | Codex CLI |
|-------------|-----------|
| `Edit` / `Write` | `apply_patch` |

## What actually forces a permission prompt

The permission engine **splits a command on `&&`, `||`, `|`, and `;` and checks each segment
separately**. If every segment is individually granted or auto-approved-read-only, the whole chain runs
**without a prompt** — `echo "== x ==" && grep foo file`, `mvn … | grep BUILD`, `grep a f | sort` are all
fine. You do **not** need to avoid `&&`/`|`/`;` chains of read-only commands.

What the engine **cannot** decompose, so it prompts every time:
- `for`/`while` loops and `$(…)` / backtick command substitution — the body is arbitrary, so it can't be
  allowlisted (a rule that permits "any loop" permits arbitrary code).
- subshells `( … )`, and any segment whose leading program isn't granted/read-only.

**Why a prefix costs you the grant.** The allowlist matches on *leading tokens* (`git add`,
`git commit`, `git rev-list`, `grep`, `find`) — so `git -C /abs add …`, `cd /abs; git add …` and
`jdk 17 && mvn …` all miss their `<program>:*` grant: `-C` shifts the matched token, and a leading
`cd`/`jdk`/`sdk`/`VAR=…` is itself an ungranted token. Bare `git add …` / `mvn …` run prompt-free —
set the toolchain once via the environment, never per command. Threading a value through a shell
variable does the same damage; inline the absolute path instead.

## Don't shell-edit files

The single biggest source of needless prompts in past sessions. Editing a tracked file with `sed -i`,
`perl -i`, `> file`, or a `cat > file` heredoc **mutates** → it prompts every time, and worse: approving
"always allow" freezes the *exact literal command* (with all its escaping) into the allowlist, where it
will never match again — pure noise (the two `perl -i …` entries that polluted `settings.local.json` were
exactly this). In-place stream edits are also error-prone with quoting and can't be reviewed as a diff.

→ Edit files with your harness's file-editing tool (table above), never a shell mutation. It is
reviewable, needs no approval, and won't pollute the allowlist. Reserve the shell for *reading*
(`grep`/`rg`/`cat`) and *building/testing* (`mvn`).

## Anti-examples — real offenders, with the cheaper form

```bash
# === mutating-shell offenders from past sessions — should have been the file-editing tool ===

# sed -i restamp loop — PROMPTS per file, AND froze junk into the allowlist when "always allowed"
# for f in module.md internals.md order.md coupon.md; do sed -i '' 's/`c81695c`/`d305cfa`/g' "$f"; done
#   → file-editing tool, one reviewable edit per file (no prompt, no allowlist pollution)

# perl -i in-place code rewrite — PROMPTS; froze `Bash(perl -0pi -e 's/mockCalculate\(draft,…` into settings
# perl -0pi -e 's/mockCalculate\(draft, calculated\)/mockCalculate(calculated)/g' OrderServiceTests.java
#   → file-editing tool with the exact old/new strings

# single sed -i restamp + cd chain — PROMPTS (sed -i mutates; cd drifts the cwd)
# cd .../<module> && sed -i '' 's/`6948daa` (2026-06-03)/`8d40dfa` (2026-06-03)/' module.md internals.md
#   → file-editing tool on each file

# heredoc / redirect writing a file — PROMPTS (file write)
# cat >> .gitignore <<'EOF' … EOF
#   → file-editing tool (append the lines, or Write a new file)

# === read / efficiency anti-patterns ===

# for-loop sweep — PROMPTS (loop body can't be allowlisted) AND costs a round-trip per branch
# for m in <module-a> <module-b> <module-c>; do echo "== $m =="; grep -n surefire "$m/pom.xml"; done
#   → rg -n surefire <module-a>/pom.xml <module-b>/pom.xml <module-c>/pom.xml

# $(…) substitution — PROMPTS (arbitrary command substitution)
# grep -n foo $(find . -name '*.java')
#   → rg -n foo --glob '**/*.java'

# fan-out: three calls where one rg does it — no prompt, but 3× the round-trips/context
# grep -rn "PlaceChecks" . ; grep -rn "NewChecks" . ; grep -rn "UpdateChecks" .
#   → rg -n -e "PlaceChecks" -e "NewChecks" -e "UpdateChecks" --type java .

# find | xargs grep — pipeline is fine for prompts, but rg is the cheaper single tool
# find . -name '*Mocker.java' | xargs grep -n "public"
#   → rg -n "public" --glob '**/*Mocker.java'

# NOTE: `echo "===" && grep …` and `mvn … | grep …` do NOT prompt — segments are checked individually.
# Drop the echo label only to save tokens, not to avoid a prompt.
```
