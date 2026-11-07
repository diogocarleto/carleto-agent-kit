# Keeping your own stacks and add-ons private

The core is public and complete on its own. What is yours (a stack for your framework, a skill that holds
your voice or your rates) stays in a repo of your own and is layered on top. The core has two seams for it:

| You want to keep private | Seam | Core changes needed |
|---|---|---|
| A **stack**: conventions, context, module memory | `--stacks <dir>` | none |
| An **add-on**: skills, docs or assets of your own | an installer you write, following the contract below | none |

## Your own stacks: `--stacks`

```bash
./install.sh <stack> <target> --stacks /path/to/my-stacks
```

`<dir>` holds one directory per stack, each shaped like the core's `stacks/<name>/` (a `stack.yml`,
`conventions/`, `context/`, and `modules/` if the stack owns a framework's module memory). Write one as
[CONTRIBUTING](../CONTRIBUTING.md#adding-a-stack) describes.

- The flag is repeatable, and `--list` shows every root.
- A stack name found in two roots is **refused before anything is written**, so a private stack cannot
  shadow `generic` or any other core stack. To adapt one, copy it under a new name.
- ⚠ **Keep the stacks root in git.** `.synced-from` records its path and commit, and a stack's seeds
  (`context/`, module memory) refresh against that history. A root with no tracked file is `unversioned`:
  install works, but it never skips itself and those seeds are never refreshed.
- A project installed from a private stack must repeat the flag on every reinstall: without it the stack
  is simply unknown. An install that fails part-way prints the exact command to re-run, flags included.
- To gate your stacks as the core gates its own, run `./verify.sh <stack> --overlay <repo>` from a clone of
  the core, where `<repo>/stacks/` is the directory you pass to `--stacks`. It installs and checks your
  stacks too; add `<repo>/verify.d/*.sh` for checks of your own. An overlay with `stacks/` and no
  `verify.d/` still runs; one with neither fails.

## Your own add-ons

An add-on installer lays files onto the target **after** `install.sh`. The core stays unaware of it, except
that it recognizes an add-on's residue so a core-only reinstall can remove it.

### The contract

1. **Add only.** Never replace a path the core or the stack ships. Check this on your source side **before**
   calling `install.sh`, which wipes the kit-owned trees: a refusal after the wipe leaves the target bare.
2. **Write only under the trees an install clears**: `.agent-kit/`, `.claude/skills/`, `.claude/agents/`,
   `.codex/skills/`, `.codex/agents/` and `.user-kit/`. Never a seed, a generated file, or a project-owned tree
   (`.agent-kit-local/`, `.user-kit-local/`). Anything outside those trees survives a core-only reinstall, so
   it could not be un-delivered.
3. **Skills come in both mirrors or neither**: `.claude/skills/<name>/SKILL.md` and
   `.codex/skills/<name>/SKILL.md`, under a name no core skill uses. Anything else a project places in
   `.claude/skills/` is wiped by the next install.
4. **Stamp every skill dir** you deliver, in both mirrors, with a `.synced-from` file whose first line is
   `skill: <name>`. The tooling keys on the file being there; the content is for people, so add the
   version and source if you want them.
5. **Regenerate Codex after layering.** `make -C <target>/.codex sync-generate` adds each new skill to the
   pointer list under `## Additional Skills`; `make -C <target>/.codex validate-skills` then checks the
   Claude and Codex mirrors of every stamped skill name the same convention files, as it does for the core's.
   Run it advisory, as `install.sh` does: a doc-list mismatch should not strand a delivery that completed.

What the stamp buys you: a core-only `./install.sh` is **never skipped** while a stamped dir (or a
`.user-kit/` dir) is present, so it runs and removes the add-on. That is how you un-deliver one. The
corollary is the trap: **run `install.sh` alone after your wrapper and the add-on is gone** until you run
the wrapper again.

### Asset directories

An add-on that ships more than a skill file (a reference doc, an executable one skill uses from both
harnesses) keeps **one** copy, not one per harness:

| Dir | Owner | Install does |
|---|---|---|
| `.user-kit/<name>/` | kit-owned | wiped on every install; your installer rebuilds it |
| `.user-kit-local/<name>/` | project-owned | **never touched** by `install.sh`, like `.agent-kit-local/` |

Both mirror `.agent-kit/` and `.agent-kit-local/` exactly, and both paths derive from the skill's folder
name, so nothing is declared anywhere. Seed starter state into `.user-kit-local/<name>/` only when the file
is absent: it is the project's the moment it exists. `--reset-defaults` never touches it, so whether your
wrapper re-copies starters under that flag is your decision.

### A decision hook

The core has one hook an add-on may use, [`.agent-kit/common/process/planning/decision-addon.md`](../common/.agent-kit/common/process/planning/decision-addon.md).
`/feature-plan` and `/feature-execute` look for a manifest at `.agent-kit/decision-addon.manifest.md`, and
follow the contract it names only if the add-on is switched on. Without one, they ask the owner as usual.

## The wrapper

Your installer is a short script: validate, core install, layer, stamp, regenerate. The sketch assumes
add-ons in `addons/<name>/`, laid out like the target root (`addons/<name>/.claude/skills/<name>/SKILL.md`):

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="${CORE:-$HERE/../carleto-agent-kit}"        # where the core lives (see the layouts below)
STACK="$1"; TARGET="$2"; shift 2                  # the rest are install.sh flags: --check, --force, ...
CHECK=0; for a in "$@"; do [ "$a" = --check ] && CHECK=1; done

# 0. refuse BEFORE anything is wiped: an add-on path the core ships
(cd "$HERE/addons" && find . -type f ! -name .DS_Store | sed 's|^\./[^/]*/||') | while read -r rel; do
  if [ -e "$CORE/common/$rel" ]; then echo "add-on ships $rel, which the core ships" >&2; exit 2; fi
done

# 1. the core, with your stacks
"$CORE/install.sh" "$STACK" "$TARGET" --stacks "$HERE/stacks" "$@"
[ "$CHECK" = 1 ] && exit 0

# 2. layer every add-on onto the clean tree, then stamp its skill dirs
for a in "$HERE"/addons/*/; do
  (cd "$a" && tar cf - --exclude .DS_Store .) | (cd "$TARGET" && tar xf -)
  for h in claude codex; do
    for sd in "$a/.$h/skills"/*/; do
      [ -d "$sd" ] || continue; n="$(basename "$sd")"
      printf 'skill: %s\ninstalled: %s\n' "$n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TARGET/.$h/skills/$n/.synced-from"
    done
  done
done

# 3. Codex only learns of the new skills now
make -C "$TARGET/.codex" sync-generate
make -C "$TARGET/.codex" validate-skills || echo "skill doc-list drift (above); the install completed" >&2
```

Pass `--force` and `--reset-defaults` straight through; they are `install.sh`'s. Step 0 above checks
core paths under `common/` only; also refuse a path the core writes elsewhere (`.agent-kit/LICENSE`,
`.agent-kit/NOTICE`, the stack's `.agent-kit/common/conventions/…`), two add-ons that ship the same path,
and a skill name a core skill uses.

## Two layouts

Both give the wrapper a `$CORE` and a stacks root; only where the core lives differs.

**A sibling repo.** Your private repo sits next to a clone of the core:

```
work/
  carleto-agent-kit/      the core: git pull to update it
  my-kit/                 yours: install.sh (the wrapper), stacks/<your-stack>/, addons/<name>/
```

Run `my-kit/install.sh <stack> <target>`. Update the core by pulling the clone, which stays a plain
upstream checkout: the kit version it stamps is its own commit.

**One repo, the core as a `git subtree`.** Everything is one checkout and one history:

```
my-kit/
  core/                   git subtree add --prefix core <core-url> main --squash
  install.sh              the wrapper, with CORE="$HERE/core"
  stacks/  addons/
```

Update with `git subtree pull --prefix core <core-url> main --squash`. The core sits below its repo's top
and install copes with that. Its version is then **your repo's commit**, so any commit makes the next
install run in full rather than print "nothing to do": harmless, only slower.

Either way, do not edit the core in place: a change to a core file belongs upstream, and in a subtree the
next pull would collide with it.