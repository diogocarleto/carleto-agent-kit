#!/usr/bin/env bash
#
# install.sh — compose the carleto-agent-kit shared agent layer into a target project.
#
# MODEL — a kit install = NEUTRAL common/ + exactly ONE selected stack, flattened into the
# target's fixed paths. After install every consumer is identically shaped; only the convention
# *contents* differ per stack. Because the skills/agents glob conventions/<layer>/ at invoke (they
# never enumerate filenames), they are stack-blind and ship unchanged from common/ — a stack only
# fills files into conventions/<layer>/.
#
# WHAT GOES WHERE
#   common/.agent-kit/        → <target>/.agent-kit/         (process, ui, modules+planning templates, taxonomy README)
#   LICENSE, NOTICE           → <target>/.agent-kit/{LICENSE,NOTICE}   (kit-owned: rebuilt every install)
#   common/.claude/{skills,agents} → <target>/.claude/{skills,agents}  (CLAUDE.md is seed-once, see below)
#   common/.codex/            → <target>/.codex/             (skills/ + agents/test-runner.md + Makefile +
#                                                              sync-codex-config.py; config.toml is seed-once)
#   stacks/<s>/conventions/   → <target>/.agent-kit/common/conventions/   (backend/ frontend/ + nested companions)
#
# The SEED files (kit defaults the consumer may customize). A consumer's local divergence is preserved
# forever — but EXISTING is not EDITED, so a normal install decides per file, by byte-equality:
#   absent                                          → seed it
#   identical to what the kit shipped at .synced-from's version → refresh to the current kit version
#   identical to the PREVIOUS stack's context/ seed, on a switch → replace with the new stack's
#   anything else (the project edited it)           → keep, and warn on a stack switch (context/ is Tier-0)
# WARNING: --reset-defaults REPLACES every seed file wholesale — it does not compare, merge, or check
# for local drift. A drift check happens only if you explicitly ask for one.
#   common/.claude/CLAUDE.md      → <target>/.claude/CLAUDE.md            (kit-standard entrypoint)
#   common/.claude/settings.json  → <target>/.claude/settings.json        (default agent permissions — Claude;
#       every install, --reset-defaults included, also merges a GENERATED claudeMdExcludes key into it:
#       globs for the project's root CLAUDE.md, AGENTS.md and .claude/rules/**, anchored on the target's
#       folder name, so Claude loads only the kit's .claude/CLAUDE.md. The untouched check ignores that
#       key, and a set written for another folder name is replaced; any other entry survives everything
#       but --reset-defaults — see claude_settings_py)
#   common/.codex/rules/default.rules → <target>/.codex/rules/default.rules (default agent permissions — Codex)
#   common/.codex/config.toml     → <target>/.codex/config.toml           (project_doc_max_bytes=0 — Codex;
#       a trusted project also gets a GENERATED developer_instructions block merged in by `make -C .codex
#       sync-agents`, on top of this seed lifecycle — same shape as the VS Code key below, see the Makefile)
#   common/.cursor/permissions.json   → <target>/.cursor/permissions.json   (default agent permissions — Cursor Auto-review)
#   common/.vscode/settings.json  → <target>/.vscode/settings.json        (default agent permissions — VS Code Copilot;
#       also sets chat.useClaudeMdFile:false and chat.useAgentsMdFile:false so the inlined
#       copilot-instructions.md is the single always-on source instead of double-loading the
#       unexpanded .claude/CLAUDE.md and the project's own root AGENTS.md)
#       ⚠ This is the one seed a project usually ALREADY has. It is kept, as any edited seed is — but
#       those two keys are then MERGED into it, in one write, because without them the VS Code harness
#       runs misconfigured. Nothing else in the file is touched; an existing value for either key is
#       left alone, and a file carrying comments is warned about rather than rewritten.
#   stacks/<s>/context/           → <target>/.agent-kit-local/context/     (stack-canonical "context":
#       architecture.md, build-commands.md                                  framework architecture + build)
#   stacks/<s>/modules/<name>/    → <target>/.agent-kit-local/modules/<name>/  (stack-shipped MODULE
#       MEMORY — the framework modules every consumer of the stack shares, so they are documented once
#       here instead of hand-maintained in each project.
#       ⚠ Seeded BY DECLARED NAME (stack.yml -> modules:), NEVER by sweeping the directory:
#       .agent-kit-local/modules/ also holds the project's OWN module memory and its project-owned
#       INDEX.md, which install never writes. That name-scoping IS the safety property — widen it to
#       "everything under modules/" and a project-authored module silently becomes a kit seed that
#       --reset-defaults overwrites.)
# --reset-defaults also deletes <target>/.claude/settings.local.json (the project uses settings.json only;
# a stray local override would shadow the kit defaults).
#
#   Codex AGENTS.md + agents/code-reviewer.md, the Cursor rule (.cursor/rules/agent-kit.mdc), and the
#   VS Code instructions (.github/copilot-instructions.md) are GENERATED in-target by `make -C .codex sync-agents`.
#
# SHARED ↔ PROJECT BOUNDARY (enforced structurally, not by a filter file):
#   common/ contains ONLY shared files, so the overlay copy can never touch project-OWNED content.
#   Project-OWNED, always preserved: .agent-kit-local/{planning,structure.yml}, .agent-kit-local/modules/
#   MINUS the module names this stack declares, .user-kit-local/, the generated
#   Codex/Cursor/VS Code files. The SEED files above are kit defaults, kept once edited (see the rules above).
#
# ADD-ON ASSET CONTRACT (for any add-on installer layered on top of this one):
#   .user-kit/        kit-owned — wiped on every install and rebuilt by the add-on installer.
#   .user-kit-local/  project-owned — never touched by install.sh, like .agent-kit-local/.
#   A .user-kit/ dir, or an installer-stamped skill dir (a .synced-from inside it), blocks the skip guard.
#
# USAGE
#   ./install.sh <stack> <target>            CLEAN install — rebuild kit-owned files, regen Codex, write .synced-from
#   ./install.sh <stack> <target> --check    dry run: print every action, write nothing
#   ./install.sh <stack> <target> --force    reinstall even if already on this stack at this kit version
#   ./install.sh <stack> <target> --reset-defaults
#                                            REPLACE every SEED file (CLAUDE.md, settings.json,
#                                            default.rules, permissions.json, .vscode/settings.json,
#                                            .codex/config.toml, context/, and the modules/ dirs this
#                                            stack DECLARES)
#                                            with the kit version, and delete
#                                            settings.local.json. Local edits to them are LOST —
#                                            no drift check is performed; ask for one first if wanted.
#                                            Generated keys are then re-added: claudeMdExcludes in
#                                            settings.json, developer_instructions in config.toml.
#                                            A module dir the stack does NOT declare — anything the
#                                            project wrote, and modules/INDEX.md — is never touched.
#                                            (implies a run even if already on the latest version)
#   (clean = kit-owned trees wiped & rebuilt to mirror the kit; .agent-kit-local/{planning,structure}
#    and every non-declared module dir preserved; SEED files per the four rules above unless
#    --reset-defaults)
#   ./install.sh <stack> <target> --stacks <dir>
#                                            take the stack from <dir> (holding <stack>/stack.yml) as well as
#                                            the kit's own stacks/. Repeatable. A stack name found in more
#                                            than one root is REFUSED before anything is written.
#   ./install.sh --list                      list available stacks (every --stacks root too)
#   ./install.sh --help                      this help
#
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
COMMON="$SRC/common"

# The stacks roots, searched in order: the kit's own, then each --stacks <dir>. A stack name must
# live in exactly one of them (a duplicate is refused before anything is written). Always non-empty,
# so "${STACK_ROOTS[@]}" is safe under `set -u` on bash 3.2.
STACK_ROOTS=("$SRC/stacks")
STACKS_FLAGS=""   # the --stacks flags as given, quoted — so a "re-run with…" hint can repeat them
STACK_ROOT=""     # the one root that holds the selected stack (set once the args are parsed)

die()  { echo "install.sh: $*" >&2; exit 2; }
note() { echo "  $*"; }

# Print the USAGE block by MARKER, never by line number — the header above changes and a
# hardcoded range silently prints the wrong section.
usage() { sed -n '/^# USAGE/,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; }

phys() { (cd "$1" 2>/dev/null && pwd -P) || true; }  # physical path, or empty when it does not exist

add_stacks_root() {  # <dir> — absolutize against the caller's cwd; a root already listed is not added twice
  local abs p
  abs="$(cd "$1" 2>/dev/null && pwd -P)" || die "--stacks: no such directory: $1"
  for p in "${STACK_ROOTS[@]}"; do
    if [ "$(phys "$p")" = "$(phys "$abs")" ]; then return 0; fi
  done
  STACK_ROOTS+=("$abs")
  STACKS_FLAGS="$STACKS_FLAGS --stacks $(printf '%q' "$abs")"
}

stack_roots_of() {  # <stack> -> every root holding it, one per line
  local r
  for r in "${STACK_ROOTS[@]}"; do
    if [ -f "$r/$1/stack.yml" ]; then echo "$r"; fi
  done
}

stack_desc() {  # <root> <stack> -> description line from stack.yml (or empty)
  local y="$1/$2/stack.yml"
  [ -f "$y" ] && sed -n 's/^description:[[:space:]]*//p' "$y" | head -1 || true
}

# The module names the selected stack declares (stack.yml -> modules:), one per line. This list is
# the ONLY thing that separates a kit seed from project-authored memory inside .agent-kit-local/modules/,
# so it is read, never inferred from the tree.
# Block parsing mirrors verify.sh's stack_yml_describes_its_tree exactly — take list items, skip blanks
# and comments, stop at any other non-empty line — so the installer and the gate can never disagree
# about what a stack declares.
stack_modules() {
  [ -f "$STACK_ROOT/$STACK/stack.yml" ] || return 0
  awk '
    /^modules:[ \t]*$/      { inb = 1; next }
    !inb                    { next }
    /^[ \t]*#/              { next }
    /^[ \t]*$/              { next }
    /^[ \t]+-[ \t]*[^# \t]/ { sub(/^[ \t]+-[ \t]*/, ""); sub(/[ \t#].*$/, ""); print; next }
                            { exit }
  ' "$STACK_ROOT/$STACK/stack.yml"
}

list_stacks() {
  local r d name dup multi=0
  [ -d "$SRC/stacks" ] || die "no stacks/ catalog at $SRC/stacks"
  [ "${#STACK_ROOTS[@]}" -gt 1 ] && multi=1
  for r in "${STACK_ROOTS[@]}"; do
    if [ "$multi" = 1 ]; then echo "Available stacks in $r:"; else echo "Available stacks:"; fi
    for d in "$r"/*/; do
      [ -f "${d}stack.yml" ] || continue
      name="$(basename "$d")"
      dup=""
      if [ "$(stack_roots_of "$name" | wc -l | tr -d ' ')" -gt 1 ]; then dup=" (duplicate — install refuses)"; fi
      printf '  %-18s %s%s\n' "$name" "$(stack_desc "$r" "$name")" "$dup"
    done
  done
}

# ---- arg parsing ----------------------------------------------------------
# Parse EVERYTHING first, then dispatch — so `--stacks <dir> --list` sees the extra root.
[ $# -ge 1 ] || { usage; exit 2; }

STACK=""; TARGET=""; CHECK=0; FORCE=0; RESET_DEFAULTS=0; WANT_LIST=0; WANT_HELP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) WANT_HELP=1 ;;
    --list)  WANT_LIST=1 ;;
    --check) CHECK=1 ;;
    --force) FORCE=1 ;;
    --reset-defaults) RESET_DEFAULTS=1 ;;
    --stacks)
      { [ $# -ge 2 ] && [ "${2#--}" = "$2" ]; } || die "--stacks needs a directory"
      add_stacks_root "$2"; shift ;;
    --*)     die "unknown flag: $1" ;;
    *) if [ -z "$STACK" ]; then STACK="$1"; elif [ -z "$TARGET" ]; then TARGET="$1"; else die "unexpected arg: $1"; fi ;;
  esac
  shift
done
[ "$WANT_HELP" = 0 ] || { usage; exit 0; }
[ "$WANT_LIST" = 0 ] || { list_stacks; exit 0; }
[ -n "$STACK" ]  || die "missing <stack> (try --list)"
[ -n "$TARGET" ] || die "missing <target> project path"
_found="$(stack_roots_of "$STACK")"
[ -n "$_found" ] || die "unknown stack '$STACK' (try --list)"
# Preflight, before anything is wiped: step 1 erases the kit-owned trees, so a file the rebuild needs must
# be proven present here, where failing costs nothing — and where --check sees it too.
for _f in LICENSE NOTICE; do
  [ -f "$SRC/$_f" ] || die "kit is missing $_f at $SRC — nothing was touched"
done
if [ "$(printf '%s\n' "$_found" | wc -l | tr -d ' ')" -gt 1 ]; then
  die "stack '$STACK' is in more than one stacks root — install refuses, nothing was written:
$(printf '%s\n' "$_found" | sed 's/^/    /')"
fi
STACK_ROOT="$_found"
TARGET="$(cd "$TARGET" 2>/dev/null && pwd || true)"
[ -n "$TARGET" ] || die "target path does not exist"

# ---- already-latest guard -------------------------------------------------
# Compare the kit version (git short SHA) AND the stack's source + version the target was last synced
# from; skip the clean reinstall when the target already holds this stack at all of them. --force overrides.
# (Stamped into .synced-from at step 6; "unversioned" when the kit / the stacks root isn't a git checkout.)
KIT_VERSION="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unversioned)"
# The stack's own provenance. Where the stacks root is a repo (the kit's own stacks/ is one — the kit's),
# its SHA identifies the stack's content; outside git there is nothing to compare, so it is
# "unversioned" — never refreshed against, never skipped on, exactly like an unversioned kit.
# ⚠ A repo around the root is not enough: a root its enclosing repo IGNORES still answers rev-parse, yet
# `status` hides ignored files, so it would read as versioned and clean while holding content no commit
# has. Versioned means the root has at least one TRACKED file.
# Stamped in its physical form — the form add_stacks_root compares roots in.
STACK_SOURCE="$(phys "$STACK_ROOT")"; [ -n "$STACK_SOURCE" ] || STACK_SOURCE="$STACK_ROOT"
STACK_VERSION=unversioned
if [ -n "$(git -C "$STACK_SOURCE" ls-files -- . 2>/dev/null | head -1)" ]; then
  STACK_VERSION="$(git -C "$STACK_SOURCE" rev-parse --short HEAD 2>/dev/null || echo unversioned)"
fi
PREV_STACK=""; prev_ver=""; prev_stack_source=""; prev_stack_version=""
if [ -f "$TARGET/.synced-from" ]; then
  PREV_STACK="$(sed -n 's/^stack:[[:space:]]*//p'  "$TARGET/.synced-from" | head -1)"
  prev_ver="$(sed -n 's/^version:[[:space:]]*//p' "$TARGET/.synced-from" | head -1)"
  # An old stamp has neither line: both stay empty, and stack seeds are then judged against the kit's
  # own history, where every stack used to live (see seed_ref).
  prev_stack_source="$(sed -n 's/^stack_source:[[:space:]]*//p'  "$TARGET/.synced-from" | head -1)"
  prev_stack_version="$(sed -n 's/^stack_version:[[:space:]]*//p' "$TARGET/.synced-from" | head -1)"
fi
# A dirty kit's SHA no longer identifies what is about to be copied, so the already-latest guard
# cannot conclude anything from it — just install and overwrite. Only a clean checkout can be "already
# on this version". The same holds for the stacks root, scoped to that root: the kit being clean says
# nothing about a stack that sits in another repo.
KIT_DIRTY=0
[ "$KIT_VERSION" != unversioned ] && [ -n "$(git -C "$SRC" status --porcelain -- . 2>/dev/null)" ] && KIT_DIRTY=1
STACK_DIRTY=0
[ "$STACK_VERSION" != unversioned ] && [ -n "$(git -C "$STACK_SOURCE" status --porcelain -- . 2>/dev/null)" ] && STACK_DIRTY=1
# All four stamp fields agree with this run — the stack, the kit version, the stacks root and its version.
SAME_STAMP=0
[ "$PREV_STACK" = "$STACK" ] && [ "$prev_ver" = "$KIT_VERSION" ] \
  && [ "$prev_stack_source" = "$STACK_SOURCE" ] && [ "$prev_stack_version" = "$STACK_VERSION" ] && SAME_STAMP=1
if [ "$FORCE" = 0 ] && [ "$RESET_DEFAULTS" = 0 ] && [ "$KIT_DIRTY" = 0 ] && [ "$STACK_DIRTY" = 0 ] \
   && [ "$KIT_VERSION" != unversioned ] && [ "$STACK_VERSION" != unversioned ] && [ -f "$TARGET/.synced-from" ]; then
  # ⚠ Any add-on residue means this run WOULD change something: install.sh alone removes it (that
  # is how an add-on skill is un-delivered), so skipping would make the documented command a silent no-op.
  # Testing for .user-kit/ alone is NOT enough — an add-on skill that ships no common/ never creates
  # it, and un-delivery silently stopped working for exactly those. Compare the skill sets instead.
  # An add-on installer stamps .synced-from into every skill dir it delivers, so residue is identified
  # by an exact MARKER, not by "absent from common/". That distinction matters twice: a consumer's own
  # hand-written skill is not residue (comparing names would have this run rm -rf it), and an add-on
  # skill whose name collides with a kit one still is (comparing names would miss it entirely).
  addon=0
  [ -d "$TARGET/.user-kit" ] && addon=1
  for _sd in "$TARGET/.claude/skills"/*/ "$TARGET/.codex/skills"/*/; do
    [ -f "$_sd/.synced-from" ] && addon=1
  done
  # ⚠ The stamp is not evidence the tree is intact. A stamp survives a deleted skill, a deleted Tier-0
  # doc, and an install killed after step 1 has already wiped the kit-owned trees — in every one of
  # those a plain re-run used to print "nothing to do" and exit 0, leaving the project broken with no
  # error and no hint that --force repairs it. So spot-check what this run would have laid down, and
  # if any of it is gone, do not skip: reinstall and say why. The set is deliberately small — one
  # sentinel per kit-owned tree, enough to catch a wipe or a deletion without stat-ing the world.
  damaged=""
  for _s in ".agent-kit/common/process/shell-hygiene.md" ".agent-kit/common/conventions" \
            ".claude/skills/backend/SKILL.md" ".codex/skills/backend/SKILL.md" ".codex/Makefile"; do
    [ -e "$TARGET/$_s" ] || damaged="$damaged $_s"
  done
  if [ -n "$damaged" ] && [ "$SAME_STAMP" = 1 ]; then
    note "⚠ stamp says up to date, but kit-owned files are missing —$damaged"
    note "   reinstalling to repair (a previous run may have been interrupted, or they were deleted)."
  elif [ "$SAME_STAMP" = 1 ] && [ "$addon" = 0 ]; then
    echo "✓ $TARGET already on the latest '$STACK' (kit $KIT_VERSION, stacks $STACK_SOURCE @ $STACK_VERSION) — nothing to do."
    echo "  re-run with --force to reinstall anyway."
    exit 0
  fi
fi

# ---- action helpers (honor --check) ---------------------------------------
run() { if [ "$CHECK" = 1 ]; then note "[check] $*"; else eval "$*"; fi; }

overlay() {  # <src-dir> <dest-dir>  — merge-copy contents, overwriting shared files only
  local s="$1" d="$2"
  [ -d "$s" ] || return 0
  run "mkdir -p \"$d\""
  run "cp -R \"$s/.\" \"$d/\""
}

# A seed the consumer never edited is still a KIT default, not project content — so when the kit
# improves one, an untouched copy should follow. Proof of "never edited" is byte-equality with the
# seed as it shipped at the version in .synced-from; anything else is kept untouched. Without this a
# consumer is frozen on the seeds of whatever version first installed, and the only way forward is
# --reset-defaults, which cannot tell an edit from a stale default and overwrites both.
#
# Where "the seed as it shipped" lives depends on who owns the seed, and a path in a repo is never a
# literal — the kit (or a stacks root) may sit below its repo's top, and may have sat elsewhere when the
# stamp was written:
#   kit seed   (common/…)       → the repo of $SRC at .synced-from's `version:`
#   stack seed (<stack>/…)      → the repo of the stamp's `stack_source` at `stack_version`; an old stamp
#                                 with no stack_* lines (or a stack_source that is gone) → the kit's repo
#                                 at `version:`, where stacks used to live under stacks/
# Path in the repo = that dir's `git rev-parse --show-prefix` + the relative path. A miss is probed
# once more WITHOUT the prefix (a stamp from before a layout move) — whose prefix that is depends on the
# repo the probe runs in: a kit seed (and a stack seed on the legacy path) strips the KIT's current prefix,
# a stack seed with a live stack_source strips that stacks root's own. With no prefix there is no retry.
# Only a path that exists is ever compared. Neither exists → no pristine copy to prove "untouched" with, so the seed counts as edited.
# Sets REF_REPO / REF_VER / REF_PATH for the caller; returns 1 when there is nothing to compare against.
REF_REPO=""; REF_VER=""; REF_PATH=""
seed_ref() {  # <kit|stack> <path relative to $SRC, or to a stacks root>
  local kind="$1" rel="$2" repo ver pfx p
  local -a cands
  REF_REPO=""; REF_VER=""; REF_PATH=""
  if [ "$kind" = stack ] && [ -n "$prev_stack_source" ] && [ -d "$prev_stack_source" ]; then
    repo="$prev_stack_source"; ver="$prev_stack_version"
  else
    repo="$SRC"; ver="$prev_ver"
    [ "$kind" = stack ] && rel="stacks/$rel"
  fi
  [ -n "$ver" ] && [ "$ver" != unversioned ] || return 1
  pfx="$(git -C "$repo" rev-parse --show-prefix 2>/dev/null)" || return 1
  cands=("$pfx$rel")
  if [ -n "$pfx" ]; then cands+=("$rel"); fi   # an empty prefix would probe the same path twice
  for p in "${cands[@]}"; do
    if git -C "$repo" cat-file -e "$ver:$p" 2>/dev/null; then
      REF_REPO="$repo"; REF_VER="$ver"; REF_PATH="$p"; return 0
    fi
  done
  return 1
}

seed_unchanged_since_last_sync() {  # <dest-file> <path> [kit|stack]
  seed_ref "${3:-kit}" "$2" || return 1
  git -C "$REF_REPO" show "$REF_VER:$REF_PATH" 2>/dev/null | cmp -s - "$1"
}

seed_once() {  # <src-file> <dest-file> [path] [kit|stack]  — copy if absent; refresh if untouched
  local s="$1" d="$2" rel="${3:-}" kind="${4:-kit}"
  [ -f "$s" ] || return 0
  if [ -f "$d" ] && [ "$RESET_DEFAULTS" = 0 ]; then
    if cmp -s "$s" "$d"; then note "up to date: ${d#$TARGET/}"; return 0; fi
    if [ -n "$rel" ] && seed_unchanged_since_last_sync "$d" "$rel" "$kind"; then
      run "cp \"$s\" \"$d\""
      if [ "$kind" = stack ]; then note "refreshed untouched seed: ${d#$TARGET/} (stack $REF_VER → $STACK_VERSION)"
      else note "refreshed untouched seed: ${d#$TARGET/} (kit $prev_ver → $KIT_VERSION)"; fi
      return 0
    fi
    note "keep (project-owned): ${d#$TARGET/}"; return 0
  fi
  run "mkdir -p \"$(dirname "$d")\""
  run "cp \"$s\" \"$d\""
  [ "$RESET_DEFAULTS" = 1 ] && note "reset to kit default: ${d#$TARGET/}" || note "seeded: ${d#$TARGET/}"
}

# .codex/config.toml is a seed like any other, with one twist: step 5 (below) stamps a GENERATED
# developer_instructions block into it on every install, so by the SECOND run the file no longer
# matches the pristine kit copy even when the project never touched it. seed_once's plain byte
# comparison would misread that as "edited" and freeze the file on day one — so this strips the block
# before comparing, the same shape as seed_once but block-blind. The markers must match
# common/.codex/Makefile's sync-codex-config target exactly; change both together.
CODEX_BLOCK_OPEN='# >>> agent-kit generated: do not edit — make -C .codex sync-agents'
CODEX_BLOCK_CLOSE='# <<< agent-kit generated'
strip_codex_config_block() {  # <file> -> stdout, file minus the generated block (absent file -> nothing)
  [ -f "$1" ] || return 0
  # ⚠ Awk variable names, not `open`/`close` — `close` is a built-in (closes a stream) and macOS's
  # awk (the "one true awk", not gawk) fails to PARSE the script when it is reused as a plain
  # variable, not just at runtime. Cost a false "project-owned" verdict on every untouched config.toml.
  # ⚠ NR == 1, not a bare match anywhere — sync-codex-config.py recognizes the block ONLY at the very
  # top of the file, so a look-alike marker line inside a project's own multi-line string is never the
  # generated block on either side. Matching it anywhere would strip project content, not our block.
  awk -v blk_open="$CODEX_BLOCK_OPEN" -v blk_close="$CODEX_BLOCK_CLOSE" '
    NR == 1 && $0 == blk_open  { skip = 1; next }
    skip && $0 == blk_close    { skip = 0; next }
    skip                       { next }
    { print }
  ' "$1"
}

seed_once_codex_config() {  # <src-file> <dest-file> <path-in-this-repo> — seed_once, block-blind
  local s="$1" d="$2" rel="$3"
  [ -f "$s" ] || return 0
  if [ -f "$d" ] && [ "$RESET_DEFAULTS" = 0 ]; then
    if cmp -s "$s" <(strip_codex_config_block "$d"); then note "up to date: ${d#$TARGET/}"; return 0; fi
    if seed_ref kit "$rel" \
       && git -C "$REF_REPO" show "$REF_VER:$REF_PATH" 2>/dev/null | cmp -s - <(strip_codex_config_block "$d"); then
      run "cp \"$s\" \"$d\""
      note "refreshed untouched seed: ${d#$TARGET/} (kit $prev_ver → $KIT_VERSION)"
      return 0
    fi
    note "keep (project-owned): ${d#$TARGET/}"; return 0
  fi
  run "mkdir -p \"$(dirname "$d")\""
  run "cp \"$s\" \"$d\""
  [ "$RESET_DEFAULTS" = 1 ] && note "reset to kit default: ${d#$TARGET/}" || note "seeded: ${d#$TARGET/}"
}

# .claude/settings.json follows the same rule as .codex/config.toml: install merges a GENERATED key
# into the seed on every run — claudeMdExcludes, which keeps Claude off the project's own root CLAUDE.md,
# AGENTS.md and .claude/rules/ — so the untouched check must not see that key either, or the second
# install would call every untouched settings.json project-owned and freeze it on day one.
# The kit owns every complete set of its shape — **/X/CLAUDE.md, **/X/AGENTS.md and **/X/.claude/rules/**
# for one folder name X — and swaps a set written for another name (a renamed checkout, a worktree, a
# teammate's tracked file) for the current folder's. Any other entry, a partial set included, is the
# project's and keeps its place, across a refresh too.
# One parser serves every mode, so the check and the merge cannot disagree about where the key is:
#   strip  → stdout: the file minus a well-formed top-level claudeMdExcludes member, else the file as is
#   merge  → write the key; given a seed, rebuild the file from it in that same atomic write (a refresh)
#   probe  → the same verdict, nothing written (--check)
# merge/probe print the sets they replace and exit 0 written (or would be) · 3 nothing to change ·
# 4 not a strict-JSON object · 5 no python3 · 6 write failed · 7 the rebuilt text failed its own check ·
# 8 claudeMdExcludes not an array of strings
claude_settings_py() {  # strip <file> | merge|probe <file> <seed-or-empty> [glob…]
  if ! command -v python3 >/dev/null 2>&1; then
    case "$1" in strip) cat "$2" ;; *) return 5 ;; esac
    return
  fi
  python3 - "$@" <<'PY'
import json, os, re, stat, sys, tempfile

mode, path = sys.argv[1], sys.argv[2]
KEY = "claudeMdExcludes"
WS = " \t\r\n"
# The set ensure_claude_md_excludes writes for a folder name — keep in step with its globs array.
SHAPE = ("**/%s/CLAUDE.md", "**/%s/AGENTS.md", "**/%s/.claude/rules/**")
# The folder-name characters ensure_claude_md_excludes writes no set for — a set naming one is the
# project's own. Keep in step with its case patterns.
NO_SET = '*?[]{}!()|"'


def no_constants(name):
    # Python's json takes NaN and Infinity; JSON does not, and Claude must read this file.
    raise ValueError(name)


DEC = json.JSONDecoder(parse_constant=no_constants)


def skip(s, i):
    while i < len(s) and s[i] in WS:
        i += 1
    return i


def members(raw):
    """Each top-level member of strict-JSON `raw` as (key, key_start, value_start, value_end, value)."""
    out, i = [], skip(raw, skip(raw, 0) + 1)
    while raw[i] != "}":
        k0 = i
        key, i = DEC.raw_decode(raw, i)
        v0 = skip(raw, skip(raw, i) + 1)
        value, v1 = DEC.raw_decode(raw, v0)
        out.append((key, k0, v0, v1, value))
        i = skip(raw, v1)
        if raw[i] == ",":
            i = skip(raw, i + 1)
    return out


def elements(raw, v0):
    """The (start, end) span of each element of the array that opens at raw[v0]."""
    out, i = [], skip(raw, v0 + 1)
    while raw[i] != "]":
        start = i
        _, i = DEC.raw_decode(raw, i)
        out.append((start, i))
        i = skip(raw, i)
        if raw[i] == ",":
            i = skip(raw, i + 1)
    return out


def globs(value):
    return isinstance(value, list) and all(isinstance(e, str) for e in value)


def load(p):
    """(bytes, BOM?, text, root object, last claudeMdExcludes member); the object is None unless the file
    is a strict-JSON object."""
    blob, bom, raw, cfg, found = b"", False, "", None, None
    try:
        with open(p, "rb") as f:
            blob = f.read()
        # utf-8-sig: a BOM must neither fail the parse nor be lost on write.
        bom = blob.startswith(b"\xef\xbb\xbf")
        raw = blob.decode("utf-8-sig")
        cfg = json.loads(raw, parse_constant=no_constants)
        if isinstance(cfg, dict):
            # The LAST duplicate is the one json.loads (and Claude's JSON.parse) keeps.
            found = ([m for m in members(raw) if m[0] == KEY] or [None])[-1]
        else:
            cfg = None
    except Exception:
        cfg = None
    return blob, bom, raw, cfg, found


blob, bom, raw, cfg, found = load(path)

# strip never fails: a file it cannot read as holding a well-formed key comes back as is, which the
# untouched check then calls project-owned — the safe direction.
if mode == "strip":
    if cfg is None or found is None or not globs(found[4]):
        sys.stdout.buffer.write(blob)
        sys.exit(0)
    k0, v1 = found[1], found[3]
    j = k0 - 1
    while raw[j] in WS:
        j -= 1
    if raw[j] == ",":   # a later member: drop it with the comma before it — exactly what merge adds
        new = raw[:j] + raw[v1:]
    else:               # the first member: drop it with the comma after it, if any
        n = skip(raw, v1)
        new = raw[:k0] + (raw[skip(raw, n + 1):] if raw[n] == "," else raw[v1:])
    sys.stdout.buffer.write((b"\xef\xbb\xbf" if bom else b"") + new.encode("utf-8"))
    sys.exit(0)

seed, cur = sys.argv[3], sys.argv[4:]
if cfg is None:
    sys.exit(4)
if found is not None and not globs(found[4]):
    sys.exit(8)
have = found[4] if found else []

# The new list as edits of the old one — ("keep", index) or ("add", entry). Without a current set (a
# skipped folder name) the key is carried as it is.
stale, ops = [], [("keep", i) for i in range(len(have))]
if cur:
    sets = set()
    for e in have:
        m = re.match(r"\*\*/([^/]+)/CLAUDE\.md\Z", e)
        x = m.group(1) if m else ""
        if x and x != ".claude" and not any(c in NO_SET for c in x) and all(p % x in have for p in SHAPE):
            sets.add(x)
    stale = sorted(x for x in sets if [p % x for p in SHAPE] != cur)
    gone = {p % x for x in stale for p in SHAPE}
    first = next((i for i, e in enumerate(have) if e in gone), None)
    ops = [("keep", i) for i, e in enumerate(have) if e not in gone]
    # Nothing before the first replaced entry is replaced, so its index is also its place in ops.
    at = len(ops) if first is None else first
    ops[at:at] = [("add", g) for g in cur if g not in have]
new_list = [have[v] if kind == "keep" else v for kind, v in ops]
replaced = ("the set%s for %s" % ("s" if len(stale) > 1 else "", ", ".join("'%s'" % x for x in stale))
            if stale else "")

base_cfg = cfg
if seed:
    # A refresh: the text becomes the new seed, and this file's key is carried into it.
    _, bom, raw, base_cfg, found = load(seed)
    if base_cfg is None or found is not None:
        sys.stderr.write("ERROR: " + seed + " is not a strict-JSON object without " + KEY + " — " + path +
                         " left unchanged.\n")
        sys.exit(7)
elif new_list == have:
    sys.exit(3)
# The note goes out as UTF-8 bytes: a folder name an ASCII-only stdout cannot encode must not turn a
# finished write into a reported failure.
if mode == "probe":
    sys.stdout.buffer.write(replaced.encode("utf-8"))
    sys.exit(0)

# Edit the TEXT, never re-serialize: json.dump would rewrite every line of a file the project may own.
# Line ending and indent unit come from the text itself.
nl = "\r\n" if "\r\n" in raw else "\n"
m = re.search(r'(?m)^([ \t]+)"', raw)
ind = m.group(1) if m else "  "


def enc(entry):
    return json.dumps(entry, ensure_ascii=False)


if found is None and not new_list:
    new = raw
elif found is None:     # a new last member, laid out so that strip removes exactly what this adds
    close = raw.rfind("}")
    head, tail = raw[:close], raw[close:]
    body = head.rstrip()
    gap = head[len(body):] or nl
    items = ("," + nl).join(ind * 2 + enc(e) for e in new_list)
    new = body + ("," if base_cfg else "") + nl + ind + enc(KEY) + ": [" + nl + items + nl + ind + "]" + gap + tail
else:
    k0, v0, v1 = found[1], found[2], found[3]
    spans = elements(raw, v0)
    ls = raw.rfind("\n", 0, k0) + 1
    key_ind = raw[ls:k0] if not raw[ls:k0].strip() else ""
    if not spans:       # an empty array: laid out as a new key would be
        items = ("," + nl).join(key_ind + ind + enc(e) for e in new_list)
        new = raw[:v0 + 1] + nl + items + nl + key_ind + raw[v1 - 1:]
    else:
        # A kept entry keeps its own text, and its old separator while its old neighbour is still next
        # to it; anything else is joined in the array's own layout, one entry per line or one line.
        if "\n" in raw[v0:v1]:
            ls = raw.rfind("\n", 0, spans[0][0]) + 1
            el_ind = raw[ls:spans[0][0]]
            sep = "," + nl + (el_ind if ls > v0 and not el_ind.strip() else key_ind + ind)
        else:
            sep = ", "
        parts, prev = [], None
        for kind, v in ops:
            if parts:
                parts.append(raw[spans[prev][1]:spans[v][0]] if kind == "keep" and prev == v - 1 else sep)
            parts.append(raw[spans[v][0]:spans[v][1]] if kind == "keep" else enc(v))
            prev = v if kind == "keep" else None
        new = raw[:spans[0][0]] + "".join(parts) + raw[spans[-1][1]:]

# Parse the rebuilt text back before it replaces anything: still strict JSON, the key holding exactly the
# planned list, and no other top-level member changed.
try:
    back = json.loads(new, parse_constant=no_constants)
    ok = (isinstance(back, dict) and back.get(KEY, []) == new_list
          and {k: v for k, v in back.items() if k != KEY} == {k: v for k, v in base_cfg.items() if k != KEY})
except ValueError:
    ok = False
if not ok:
    sys.stderr.write("ERROR: " + path + ": the rebuilt text did not parse back with " + KEY +
                     " intact — left unchanged.\n")
    sys.exit(7)

# Atomic, beside the REAL file (a dotfile manager may symlink it), with its mode copied onto the temp
# file first — mkstemp creates it 0600.
real = os.path.realpath(path)
tmp = None
try:
    perm = stat.S_IMODE(os.stat(real).st_mode)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(real) or ".", prefix=".settings-", suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8-sig" if bom else "utf-8", newline="") as f:
        f.write(new)
    os.chmod(tmp, perm)
    os.replace(tmp, real)
except Exception:
    if tmp:
        try:
            os.unlink(tmp)
        except OSError:
            pass
    sys.exit(6)
sys.stdout.buffer.write(replaced.encode("utf-8"))
PY
}

CLAUDE_SETTINGS_REFRESH=0   # 1 once seed_once_claude_settings finds an untouched seed to refresh
seed_once_claude_settings() {  # <src-file> <dest-file> <path-in-this-repo> — seed_once, claudeMdExcludes-blind
  local s="$1" d="$2" rel="$3"
  [ -f "$s" ] || return 0
  if [ -f "$d" ] && [ "$RESET_DEFAULTS" = 0 ]; then
    if cmp -s "$s" <(claude_settings_py strip "$d"); then note "up to date: ${d#$TARGET/}"; return 0; fi
    if seed_ref kit "$rel" \
       && git -C "$REF_REPO" show "$REF_VER:$REF_PATH" 2>/dev/null | cmp -s - <(claude_settings_py strip "$d"); then
      # Refreshed by ensure_claude_md_excludes in the one atomic write that also carries the key over: a
      # copy here would hold the project's own entries only in memory until that write.
      CLAUDE_SETTINGS_REFRESH=1
      return 0
    fi
    note "keep (project-owned): ${d#$TARGET/}"; return 0
  fi
  run "mkdir -p \"$(dirname "$d")\""
  run "cp \"$s\" \"$d\""
  [ "$RESET_DEFAULTS" = 1 ] && note "reset to kit default: ${d#$TARGET/}" || note "seeded: ${d#$TARGET/}"
}

# The merge half, run after the seed step on every install, --reset-defaults included. The globs are
# anchored on the folder name, not an absolute path, because the file is tracked and shared; they are
# written whether or not the files exist, so one added later is covered without a reinstall.
CLAUDE_EXCLUDES_IN_PLACE=0   # 1 once this run confirms this folder's three globs are (or under --check would be) in .claude/settings.json
ensure_claude_md_excludes() {
  local f="$TARGET/.claude/settings.json" seed="$COMMON/.claude/settings.json" base="" skip="" dir
  local mode=merge rc=0 res="" why="" left="" failed=0 list
  local -a globs
  # The PHYSICAL name, from the external pwd: Claude matches the on-disk case and Unicode form, and a
  # typed or symlinked path can differ in both — as can the bash builtin, which keeps the composed form.
  dir="$(basename "$(cd "$TARGET" && { /bin/pwd -P 2>/dev/null || pwd -P; })")"
  case "$dir" in
    # Claude drops an excluded file's @imports, and **/.claude/CLAUDE.md would match the kit's own
    # .claude/CLAUDE.md and ~/.claude/CLAUDE.md: every Tier-0 doc would go with them.
    .claude)
      skip="the folder is named .claude, so its glob would also exclude the kit's own .claude/CLAUDE.md" ;;
    # Claude Code rewrites \ to / in patterns and paths before matching, so no escape can work. Keep in
    # step with NO_SET in claude_settings_py.
    *[]*?[{}!\(\)\|\"]*)
      skip="the folder name '$dir' holds a glob metacharacter (*?[]{}!()|\"), which Claude cannot match literally" ;;
    # Keep in step with SHAPE in claude_settings_py, which finds these sets again to replace them.
    *) globs=("**/$dir/CLAUDE.md" "**/$dir/AGENTS.md" "**/$dir/.claude/rules/**") ;;
  esac
  [ "$CHECK" = 1 ] && mode=probe
  [ "$CLAUDE_SETTINGS_REFRESH" = 1 ] && base="$seed"
  # A dry run seeded nothing, so judge the file the seed step WOULD have left.
  if [ "$CHECK" = 1 ] && { [ ! -f "$f" ] || [ "$RESET_DEFAULTS" = 1 ]; }; then f="$seed"; fi
  [ -f "$f" ] || return 0

  # One call does the write. A refresh rebuilds the file from the seed and carries the key over in it —
  # as it is, for a skipped folder name, which otherwise writes nothing.
  if [ -z "$skip" ] || [ -n "$base" ]; then
    if res="$(claude_settings_py "$mode" "$f" "$base" ${globs[@]+"${globs[@]}"})"; then rc=0; else rc=$?; fi
  fi
  case "$rc" in
    0|3) ;;
    4) why=".claude/settings.json is not a strict-JSON object (a comment, a trailing comma, NaN …)" ;;
    5) why="no python3 on PATH" ;;
    7) why="the rebuilt text failed its own check (ERROR above)" ;;
    8) why="its claudeMdExcludes is not an array of strings" ;;
    *) why=".claude/settings.json could not be written" ;;
  esac
  if [ -n "$base" ]; then
    # Without python3 the untouched check compared raw bytes, so the file IS the old seed and holds no
    # key: a plain copy loses nothing.
    if [ "$rc" = 5 ]; then run "cp \"$seed\" \"$f\""; fi
    case "$rc" in
      0|5) if [ "$mode" = probe ]; then note "[check] would refresh untouched seed: .claude/settings.json (kit $prev_ver → $KIT_VERSION)"
           else note "refreshed untouched seed: .claude/settings.json (kit $prev_ver → $KIT_VERSION)"; fi ;;
      *)   note "⚠ claude: .claude/settings.json not refreshed to the kit $KIT_VERSION seed — $why; the file,"
           note "   claudeMdExcludes included, is left exactly as it was."
           failed=1 ;;
    esac
  fi
  # report_foreign_instructions (step 5/6, below) reads this back: true exactly when this folder's
  # three globs are (or under --check would be) in .claude/settings.json — no skipped folder name, no
  # failed refresh, and the merge/probe call itself found them written or already present.
  [ -z "$skip" ] && [ "$failed" = 0 ] && { [ "$rc" = 0 ] || [ "$rc" = 3 ]; } && CLAUDE_EXCLUDES_IN_PLACE=1
  if [ -n "$skip" ]; then
    note "⚠ claude: claudeMdExcludes not written — $skip."
    note "   Claude still loads this project's root CLAUDE.md, AGENTS.md and .claude/rules/."
    return 0
  fi
  [ "$failed" = 0 ] || return 0
  list="[\"${globs[0]}\", \"${globs[1]}\", \"${globs[2]}\"]"
  [ "$rc" = 5 ] || left="; the file is left exactly as it was"
  case "$rc" in
    0) if [ "$mode" = probe ]; then note "[check] would merge claudeMdExcludes into .claude/settings.json${res:+, replacing $res}"
       else note "claude: merged claudeMdExcludes into .claude/settings.json (root CLAUDE.md, AGENTS.md, .claude/rules/)${res:+, replacing $res}"; fi ;;
    3) note "claude: claudeMdExcludes already in .claude/settings.json — left as is" ;;
    *) # A key that is already there needs its entries, not a second key.
       if [ "$rc" = 8 ] || grep -q '"claudeMdExcludes"' "$f" 2>/dev/null; then
         note "⚠ claude: claudeMdExcludes could not be checked or updated — $why$left."
         note "   Make the existing claudeMdExcludes in .claude/settings.json an array of strings that includes:"
         note "     $list"
       else
         note "⚠ claude: claudeMdExcludes not written — $why$left."
         note "   Claude still loads this project's root CLAUDE.md, AGENTS.md and .claude/rules/. Add by hand:"
         note "     \"claudeMdExcludes\": $list"
       fi ;;
  esac
}

# The context/ seeds are the only STACK-owned ones — every other seed comes from common/ and is the
# same whatever stack you pick. So they are the only ones a stack SWITCH can leave stale: they hold the
# old stack's framework prose and load as always-on Tier-0 on all four harnesses. "Project-owned" is
# earned by editing, not by existing — byte-identical to the old stack's seed proves it was never
# touched, so replacing it loses nothing. Anything else is kept and flagged for a human to read.
seed_context() {  # <src-file> <dest-file> <basename>
  local s="$1" d="$2" old="" r
  [ -f "$s" ] || return 0
  # The old stack's seed as it stands today: where the stamp says it came from, else any root that has it.
  if [ -n "$PREV_STACK" ]; then
    for r in "$prev_stack_source" "${STACK_ROOTS[@]}"; do
      if [ -n "$r" ] && [ -f "$r/$PREV_STACK/context/$3" ]; then old="$r/$PREV_STACK/context/$3"; break; fi
    done
  fi
  if [ -f "$d" ] && [ "$RESET_DEFAULTS" = 0 ] && [ -n "$PREV_STACK" ] && [ "$PREV_STACK" != "$STACK" ]; then
    if cmp -s "$s" "$d"; then note "up to date: ${d#$TARGET/}"; return 0; fi
    # "Untouched" means it matches the old stack's seed as the consumer actually received it — the
    # version in .synced-from — or as that seed stands today. Checking only today's copy would call a
    # file "edited" merely because the kit revised that template after the consumer installed it.
    if { [ -n "$old" ] && cmp -s "$d" "$old"; } \
       || seed_unchanged_since_last_sync "$d" "$PREV_STACK/context/$3" stack; then
      run "cp \"$s\" \"$d\""
      note "replaced untouched '$PREV_STACK' seed: ${d#$TARGET/}"
    else
      note "keep (project-owned): ${d#$TARGET/}"
      note "   ⚠ seeded by stack '$PREV_STACK', edited since — it is always-on Tier-0 on every harness."
      note "     Review it for stale '$PREV_STACK' content the switch to '$STACK' just orphaned."
    fi
    return 0
  fi
  seed_once "$s" "$d" "$STACK/context/$3" stack
}

# Stack-shipped MODULE MEMORY — the same seed lifecycle as context/, applied one DECLARED NAME at a
# time. A framework module is identical for every consumer of the stack, so documenting it here beats
# each project hand-maintaining its own copy (and its own, often wrong, freshness stamp).
# ⚠ NEVER sweep the directory. .agent-kit-local/modules/ holds two natures side by side — these seeds,
# and the project's own module memory plus the project-owned INDEX.md. The declared-name list is what
# keeps them separable, and it is the only reason --reset-defaults can be told "replace the seeds" and
# still not touch a line the project wrote. INDEX.md is never written here: install cannot know a
# project's row order, and /modules picks a seeded module up without one.
# ⚠ Unlike context/, a stack SWITCH does not replace or remove the previous stack's module dirs — they
# are simply no longer declared, so nothing reads or writes them. That is deliberate: deleting from a
# project-owned tree is the very sweep this function refuses, and the cost is low because module memory
# is on-demand, not always-on Tier-0 like context/ — a stale dir with no INDEX row is loaded by nothing
# until someone asks for it by name. Removing it is the consumer's call.
seed_stack_modules() {
  local m src f rel mods
  mods="$(stack_modules)"
  [ -n "$mods" ] || return 0
  for m in $mods; do
    src="$STACK_ROOT/$STACK/modules/$m"
    if [ ! -d "$src" ]; then
      note "⚠ stack '$STACK' declares module '$m' but ships no $STACK/modules/$m/ in $STACK_ROOT — nothing seeded"
      continue
    fi
    while IFS= read -r f; do
      rel="${f#$src/}"
      seed_once "$f" "$TARGET/.agent-kit-local/modules/$m/$rel" "$STACK/modules/$m/$rel" stack
    done < <(find "$src" -type f ! -name '.DS_Store')
  done
}

# One python pass serves merge AND probe for BOTH VS Code keys, from PARSED json rather than a text
# match (a grep for a key also hits it inside a comment or nested under a language block,
# "[python]": {...}, and would then skip the merge while reporting "already set" — a silent miss, the
# opposite of this code's design). `probe` runs the identical read path without writing, so --check
# previews the real verdict instead of promising a merge that would not happen.
# Prints one line per key, IN THE ORDER GIVEN: "merged <key>" when it was (or would be) added, else
# "kept <key> <json-value>" — the caller turns each into its own note and records whether that key
# ends up false, which report_foreign_instructions (step 5/6, below) reads back.
# Exit codes: 0 at least one key merged (or would be) · 3 every key already present ·
#             4 unparseable · 5 no python3 · 6 write failed
# ⚠ Lives in its own function, never inlined behind `$(...)`: macOS's /bin/bash is 3.2, which
# mis-parses a heredoc written directly inside a command substitution. The caller captures our
# stdout with `out="$(vscode_chat_keys_py …)"` instead — same shape as claude_settings_py.
vscode_chat_keys_py() {  # <file> merge|probe <key>…
  command -v python3 >/dev/null 2>&1 || return 5
  python3 - "$@" <<'PY'
import json, os, re, stat, sys, tempfile

path, mode, keys = sys.argv[1], sys.argv[2], sys.argv[3:]
try:
    with open(path, "rb") as f:
        blob = f.read()
    # utf-8-sig, not utf-8: VS Code accepts a BOM'd settings.json, and plain utf-8 would read the BOM
    # as content, fail the parse, and send a perfectly valid file down the "unparseable" warn path.
    bom = blob.startswith(b"\xef\xbb\xbf")
    raw = blob.decode("utf-8-sig")
    cfg = json.loads(raw)
except Exception:
    sys.exit(4)
if not isinstance(cfg, dict):
    sys.exit(4)

missing = [k for k in keys if k not in cfg]


def report():
    for k in keys:
        print(("kept %s %s" % (k, json.dumps(cfg[k]))) if k in cfg else ("merged %s" % k))


if not missing:
    report()
    sys.exit(3)
if mode == "probe":
    report()
    sys.exit(0)

# Insert every missing key in ONE atomic write, never re-serialize: json.dump would round-trip the
# whole file — normalizing a project's indentation, collapsing duplicate keys, re-rendering floats and
# reordering nothing but still rewriting every line — the same bad trade the comment guard below
# refuses. We only ever reach here on strict JSON (JSONC fails the parse and warns), so appending
# members before the final brace is safe. Indentation and line ending are copied from the file itself.
close = raw.rfind("}")
if close == -1:
    sys.exit(4)
nl = "\r\n" if "\r\n" in raw else "\n"
m = re.search(r'(?m)^([ \t]+)"', raw)
ind = m.group(1) if m else "  "
head, tail = raw[:close], raw[close:]
stripped = head.rstrip()
gap = head[len(stripped):] or nl
block = ("," + nl).join('%s"%s": false' % (ind, k) for k in missing)
new = stripped + ("," if cfg else "") + nl + block + gap + tail

# Resolve first: a dotfile manager may symlink settings.json, and replacing the LINK with a regular
# file would quietly detach it from the profile it belongs to. Write beside the real file, then
# os.replace — atomic, so a failure mid-write can never leave a truncated settings.json behind.
real = os.path.realpath(path)
try:
    perm = stat.S_IMODE(os.stat(real).st_mode)
except OSError:
    perm = None
tmp = None
try:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(real) or ".", prefix=".settings-", suffix=".json")
    # newline="" so the copied line ending is written through untranslated; utf-8-sig only when the
    # file already had a BOM. mkstemp creates at 0600, so restore the original mode before the
    # replace or a project's 0644 settings.json silently becomes owner-only.
    with os.fdopen(fd, "w", encoding="utf-8-sig" if bom else "utf-8", newline="") as f:
        f.write(new)
    if perm is not None:
        os.chmod(tmp, perm)
    os.replace(tmp, real)
except Exception:
    if tmp:
        try:
            os.unlink(tmp)
        except OSError:
            pass
    sys.exit(6)

report()
PY
}

# VS Code needs two keys from the kit to be wired correctly: chat.useClaudeMdFile:false and
# chat.useAgentsMdFile:false. Both default TRUE, so without them VS Code ALSO loads .claude/CLAUDE.md
# — whose @imports it cannot expand — and the project's own root AGENTS.md, injecting pointer lists
# and foreign content alongside the generated copilot-instructions.md.
# But .vscode/settings.json is the one seed a project usually ALREADY has (editor prefs predate the
# kit), and seed_once correctly refuses to clobber it — so for most real consumers these keys would
# never arrive and the VS Code harness would quietly run misconfigured. Merge just the missing keys
# into an existing file, in one atomic write; touch nothing else.
#   - a key already present (any value) → leave it: the project decided, and this is not ours to flip.
#   - file carries comments (JSONC, legal in VS Code) → do NOT rewrite. json.dump cannot round-trip a
#     comment, and eating a project's annotations to add these keys is a bad trade. Warn instead.
# Sets VSCODE_*_OK / VSCODE_*_FAILED / VSCODE_*_VALUE for report_foreign_instructions, on EVERY path —
# including the two below where this function does no merge work at all (the kit's own untouched
# copy; a --check run against a target the seed step has not actually created yet) — both of which
# mean both keys are seeded false, which is exactly what the globals already default to.
VSCODE_CLAUDEMD_OK=1; VSCODE_CLAUDEMD_FAILED=0; VSCODE_CLAUDEMD_VALUE=""
VSCODE_AGENTSMD_OK=1; VSCODE_AGENTSMD_FAILED=0; VSCODE_AGENTSMD_VALUE=""
ensure_vscode_chat_keys() {
  local d="$TARGET/.vscode/settings.json" mode=merge rc=0 out line rest key val
  [ -f "$d" ] || return 0
  if cmp -s "$COMMON/.vscode/settings.json" "$d"; then return 0; fi   # kit's own copy already has both

  [ "$CHECK" = 1 ] && mode=probe
  if out="$(vscode_chat_keys_py "$d" "$mode" chat.useClaudeMdFile chat.useAgentsMdFile)"; then rc=0; else rc=$?; fi

  case "$rc" in
    0|3)
      while IFS= read -r line; do
        case "$line" in
          "merged "*)
            key="${line#merged }"
            if [ "$mode" = probe ]; then note "[check] would merge \"$key\": false into .vscode/settings.json"
            else note "vscode: merged \"$key\": false into .vscode/settings.json"; fi ;;
          "kept "*)
            rest="${line#kept }"; key="${rest%% *}"; val="${rest#* }"
            note "vscode: $key already set — left as is"
            if [ "$val" != false ]; then
              case "$key" in
                chat.useClaudeMdFile) VSCODE_CLAUDEMD_OK=0; VSCODE_CLAUDEMD_VALUE="$val" ;;
                chat.useAgentsMdFile) VSCODE_AGENTSMD_OK=0; VSCODE_AGENTSMD_VALUE="$val" ;;
              esac
            fi ;;
        esac
      done <<<"$out"
      ;;
    *)
      case "$rc" in
        4) note "⚠ vscode: could not merge — .vscode/settings.json is not a readable JSON object" ;;
        5) note "⚠ vscode: could not merge — no python3 on PATH" ;;
        *) note "⚠ vscode: could not merge — .vscode/settings.json could not be written" ;;
      esac
      note "   (a comment, a trailing comma or any JSONC syntax puts it in the first case; the file"
      note "    is left exactly as it was rather than rewritten, which would eat those comments.)"
      note "   VS Code Copilot will ALSO load .claude/CLAUDE.md with its @imports unresolved — a"
      note "   pointer list with no content — and this project's root AGENTS.md. Add by hand:"
      note "     \"chat.useClaudeMdFile\": false"
      note "     \"chat.useAgentsMdFile\": false"
      VSCODE_CLAUDEMD_OK=0; VSCODE_CLAUDEMD_FAILED=1
      VSCODE_AGENTSMD_OK=0; VSCODE_AGENTSMD_FAILED=1
      ;;
  esac
}

# The Claude entrypoint has the SAME "the project already owns this file" shape as .vscode/settings.json
# — with a far larger loss. A project that used Claude Code before adopting the kit already has a
# CLAUDE.md, so seed_once correctly keeps it, and Claude — the kit's PRIMARY harness — then loads NONE
# of the five Tier-0 docs, while Codex, Cursor and VS Code all get them inlined by the generator. The
# failure is silent: seed_context's stale-seed notice only fires on a stack SWITCH, never here.
# Deliberately NOT auto-merged, unlike the one vscode key: appending imports edits a doc the project
# wrote, and where they belong depends on what it already says. So say it loudly, with the block to paste.
warn_claude_md_without_imports() {
  local d="$TARGET/.claude/CLAUDE.md" src="$COMMON/.claude/CLAUDE.md" imp missing=0
  [ -f "$d" ] || return 0
  if cmp -s "$src" "$d"; then return 0; fi
  # Check EVERY import the seed carries, not just that one is present. "Has at least one @../.agent-kit
  # line" passes a CLAUDE.md holding only architecture.md while planning, dispatch and shell-hygiene are
  # still missing — precisely the loss this warning's own text claims to catch. Report what is absent.
  while IFS= read -r imp; do
    grep -qF "$imp" "$d" || missing=$((missing + 1))
  done < <(grep '^@' "$src")
  [ "$missing" -gt 0 ] || return 0
  note "⚠ .claude/CLAUDE.md is project-owned and is missing $missing of the kit's Tier-0 imports."
  note "   Codex, Cursor and VS Code get all of them inlined; Claude loads only what it names here."
  note "   Add the missing lines:"
  while IFS= read -r imp; do
    grep -qF "$imp" "$d" || note "       $imp"
  done < <(grep '^@' "$src")
}

# Whether a trusted Codex, right now, would skip this project's AGENTS.md — which depends only on
# project_doc_max_bytes = 0, the seed's STATIC half. strip_codex_config_block removes the generated
# developer_instructions block before the comparison, so this checks only that static half against the
# kit seed, exactly mirroring the untouched check seed_once_codex_config itself uses — it can never
# drift from that decision. It says NOTHING about whether developer_instructions was actually written:
# that is a separate concern (whether Codex ALSO receives the kit's own instructions), not what Codex's
# AGENTS.md skip depends on. Absent, or about to be reset, counts as in place too — the seed is or
# would be written with project_doc_max_bytes = 0 either way.
codex_lever_in_place() {
  local f="$TARGET/.codex/config.toml"
  if [ ! -f "$f" ] || [ "$RESET_DEFAULTS" = 1 ]; then return 0; fi
  cmp -s "$COMMON/.codex/config.toml" <(strip_codex_config_block "$f")
}

# Per tool, name the foreign instruction files this project still has on disk — never moved, edited or
# deleted — and say plainly whether that tool's own lever actually keeps them out of its context, or
# whether it still loads them. Every verdict here is read back from what the earlier steps actually
# did (CLAUDE_EXCLUDES_IN_PLACE, the VSCODE_* globals, codex_lever_in_place), never assumed, so this
# can never claim a skip whose lever is not in place.
report_foreign_instructions() {
  local has_claude=0 has_agents=0 has_rules=0 names="" ok_names="" ok_keys=""
  [ -f "$TARGET/CLAUDE.md" ]     && has_claude=1
  [ -f "$TARGET/AGENTS.md" ]     && has_agents=1
  [ -d "$TARGET/.claude/rules" ] && has_rules=1

  if [ "$has_claude" = 0 ] && [ "$has_agents" = 0 ] && [ "$has_rules" = 0 ]; then
    note "foreign instruction files: none (no root CLAUDE.md, AGENTS.md or .claude/rules/)"
    return 0
  fi

  [ "$has_claude" = 1 ] && names="CLAUDE.md"
  [ "$has_agents" = 1 ] && names="${names:+$names, }AGENTS.md"
  [ "$has_rules"  = 1 ] && names="${names:+$names, }.claude/rules/"
  if [ "$CHECK" = 1 ]; then
    note "[check] foreign instruction files after this install — kept on disk, never edited:"
  else
    note "foreign instruction files — kept on disk, never edited:"
  fi

  # claude: claudeMdExcludes always covers all three, whichever of them exist.
  if [ "$CLAUDE_EXCLUDES_IN_PLACE" = 1 ]; then
    note "  claude: skips $names (claudeMdExcludes)"
  else
    note "  ⚠ claude: still loads $names — claudeMdExcludes is not in place (see above)"
  fi

  # codex: only ever reads a root/nested AGENTS.md — never CLAUDE.md or .claude/rules/.
  if [ "$has_agents" = 1 ]; then
    if codex_lever_in_place; then
      note "  codex: skips AGENTS.md once the project is trusted (project_doc_max_bytes = 0)"
    else
      note "  ⚠ codex: .codex/config.toml is project-owned — Codex skips AGENTS.md only if it sets project_doc_max_bytes = 0"
    fi
  fi

  # vscode: one line naming every file whose key is confirmed false, then one warning per file whose
  # key is not — naming only the keys actually involved in each.
  if [ "$has_claude" = 1 ] && [ "$VSCODE_CLAUDEMD_OK" = 1 ]; then
    ok_names="CLAUDE.md"; ok_keys="chat.useClaudeMdFile"
  fi
  if [ "$has_agents" = 1 ] && [ "$VSCODE_AGENTSMD_OK" = 1 ]; then
    ok_names="${ok_names:+$ok_names, }AGENTS.md"
    ok_keys="${ok_keys:+$ok_keys / }chat.useAgentsMdFile"
  fi
  [ -n "$ok_names" ] && note "  vscode: skips $ok_names ($ok_keys: false)"
  if [ "$has_claude" = 1 ] && [ "$VSCODE_CLAUDEMD_OK" = 0 ]; then
    if [ "$VSCODE_CLAUDEMD_FAILED" = 1 ]; then
      note "  ⚠ vscode: still loads CLAUDE.md — chat.useClaudeMdFile could not be merged (see above)"
    else
      note "  ⚠ vscode: still loads CLAUDE.md — chat.useClaudeMdFile is $VSCODE_CLAUDEMD_VALUE in .vscode/settings.json"
    fi
  fi
  if [ "$has_agents" = 1 ] && [ "$VSCODE_AGENTSMD_OK" = 0 ]; then
    if [ "$VSCODE_AGENTSMD_FAILED" = 1 ]; then
      note "  ⚠ vscode: still loads AGENTS.md — chat.useAgentsMdFile could not be merged (see above)"
    else
      note "  ⚠ vscode: still loads AGENTS.md — chat.useAgentsMdFile is $VSCODE_AGENTSMD_VALUE in .vscode/settings.json"
    fi
  fi

  # vscode + .claude/rules/: no setting at all covers this, regardless of the two keys above.
  [ "$has_rules" = 1 ] \
    && note "  ⚠ vscode: can still apply .claude/rules/ files that declare paths or a description — no VS Code setting stops it"

  # cursor: an acknowledged gap — no switch exists.
  [ "$has_agents" = 1 ] \
    && note "  ⚠ cursor: still loads AGENTS.md — Cursor has no setting to turn it off"
  return 0
}

DRY=""; [ "$CHECK" = 1 ] && DRY=" (dry run)"
echo "Installing stack '$STACK' → $TARGET$DRY"
if [ "$RESET_DEFAULTS" = 1 ]; then
  echo "⚠  --reset-defaults: every SEED file is REPLACED with the kit version."
  echo "   Local edits to them are overwritten — no comparison, no merge, no drift check."
  echo ""
  reset_mods="$(stack_modules | tr '\n' ' ')"
  echo "   REPLACES  .claude/CLAUDE.md  .claude/settings.json  .codex/rules/default.rules"
  echo "             .codex/config.toml  .cursor/permissions.json  .vscode/settings.json"
  echo "             .agent-kit-local/context/{architecture,build-commands}.md"
  if [ -n "$reset_mods" ]; then
  echo "             .agent-kit-local/modules/ — ONLY these, shipped by stack '$STACK':"
  echo "                 $reset_mods"
  fi
  echo "   DELETES   .claude/settings.local.json"
  echo "   KEEPS     .agent-kit-local/planning/  structure.yml  modules/INDEX.md"
  if [ -n "$reset_mods" ]; then
  echo "             every module dir NOT named above  ·  .user-kit-local/"
  else
  echo "             ALL of .agent-kit-local/modules/ — this stack ships none  ·  .user-kit-local/"
  fi
  echo "             — and every other file in the project"
  echo ""
  echo "   ⚠ .agent-kit-local/ holds BOTH natures, and modules/ can hold both too:"
  echo "     context/, and any module dir the stack ships, are kit seeds and ARE replaced."
  echo "     planning/, structure.yml, modules/INDEX.md and every module memory YOU wrote are"
  echo "     NEVER touched — not by this flag, not by any install. A seed is identified by NAME,"
  echo "     never by sweeping the directory, which is what makes that promise hold."
  echo "   Want a drift check first? See README → \"Checking what a reset would cost\" — it is never automatic."
fi

# 1. CLEAN — wipe the kit-OWNED trees so the result exactly mirrors the kit (no stale files from a
#    renamed/removed doc or a previous stack). NOT under these paths (untouched here): the SEED files
#    (.claude/CLAUDE.md, .claude/settings.json, .codex/rules/, .cursor/permissions.json,
#    .vscode/settings.json, .agent-kit-local/context/, the declared .agent-kit-local/modules/<name>/ — step 4),
#    .agent-kit-local/{modules,planning,structure.yml}, .claude/settings.local.json, .synced-from.
#    .user-kit/ is wiped for the same reason .agent-kit/ is — it is kit output, rebuilt by
#    the add-on installer. Its state twin .user-kit-local/ is project-owned and never touched, exactly
#    mirroring .agent-kit/ vs .agent-kit-local/.
for owned in .agent-kit .user-kit .claude/skills .claude/agents .codex/skills .codex/agents; do
  run "rm -rf \"$TARGET/$owned\""
done
note "cleaned kit-owned trees (.agent-kit, .user-kit, .claude/{skills,agents}, .codex/{skills,agents})"
# ⚠ From here the target has NO shared layer until step 5 finishes. Anything that stops the script in
# between — a failed make, a killed pipe, a full disk — leaves the project without its conventions,
# and the wipe already discarded them. This trap makes that state loud instead of silent; it is not a
# rollback, because the previous tree is gone by construction. Cleared once the install completes.
CLEAN_DONE=1
trap 'rc=$?; [ "$rc" = 0 ] || { [ "${CLEAN_DONE:-0}" = 1 ] && [ "${INSTALL_DONE:-0}" = 0 ] && {
  echo "" >&2
  echo "install.sh: FAILED PART-WAY — $TARGET has been cleaned but not rebuilt." >&2
  echo "  Its .agent-kit/ (conventions, process docs) and skills are GONE until you re-run:" >&2
  echo "    ./install.sh $STACK $TARGET$STACKS_FLAGS --force" >&2
  echo "  Project-owned trees (.agent-kit-local/, .user-kit-local/) were never touched." >&2
}; }' EXIT

# 2. overlay the neutral common layer (shared files only). .claude and .codex are overlaid as their
#    skills/ + agents/ (+ .codex/Makefile) only; the SEED files under common/.claude/ (CLAUDE.md,
#    settings.json) and common/.codex/rules/ are handled in step 4 (seed-if-absent / --reset-defaults).
overlay "$COMMON/.agent-kit"      "$TARGET/.agent-kit"
overlay "$COMMON/.claude/skills"  "$TARGET/.claude/skills"
overlay "$COMMON/.claude/agents"  "$TARGET/.claude/agents"
overlay "$COMMON/.codex/skills"   "$TARGET/.codex/skills"
overlay "$COMMON/.codex/agents"   "$TARGET/.codex/agents"
run "cp \"$COMMON/.codex/Makefile\" \"$TARGET/.codex/Makefile\""
run "cp \"$COMMON/.codex/sync-codex-config.py\" \"$TARGET/.codex/sync-codex-config.py\""
note "overlaid common/ (.agent-kit, .claude/{skills,agents}, .codex/{skills,agents,Makefile,sync-codex-config.py})"
# The license and the credits travel with the copy: kit-owned like the rest of .agent-kit/, rebuilt every install.
run "cp \"$SRC/LICENSE\" \"$TARGET/.agent-kit/LICENSE\""
run "cp \"$SRC/NOTICE\"  \"$TARGET/.agent-kit/NOTICE\""
note "added LICENSE and NOTICE to .agent-kit/"

# 3. flatten the selected stack's conventions into the consumer's fixed path
overlay "$STACK_ROOT/$STACK/conventions" "$TARGET/.agent-kit/common/conventions"
note "installed conventions for stack '$STACK'"

# 4. SEED files: copy-if-absent normally; --reset-defaults force-overwrites them back to kit-canonical.
seed_once "$COMMON/.claude/CLAUDE.md"          "$TARGET/.claude/CLAUDE.md"           common/.claude/CLAUDE.md
warn_claude_md_without_imports   # a kept project CLAUDE.md leaves Claude with no Tier-0 at all
seed_once_claude_settings "$COMMON/.claude/settings.json" "$TARGET/.claude/settings.json" common/.claude/settings.json
ensure_claude_md_excludes   # the generated key, merged on every run — --reset-defaults included
seed_once "$COMMON/.codex/rules/default.rules" "$TARGET/.codex/rules/default.rules" common/.codex/rules/default.rules
seed_once "$COMMON/.cursor/permissions.json"  "$TARGET/.cursor/permissions.json"   common/.cursor/permissions.json
seed_once "$COMMON/.vscode/settings.json"     "$TARGET/.vscode/settings.json"      common/.vscode/settings.json
ensure_vscode_chat_keys   # a pre-existing project settings.json is kept, but still needs these two keys
seed_once_codex_config "$COMMON/.codex/config.toml" "$TARGET/.codex/config.toml"    common/.codex/config.toml
seed_context "$STACK_ROOT/$STACK/context/architecture.md"    "$TARGET/.agent-kit-local/context/architecture.md"   architecture.md
seed_context "$STACK_ROOT/$STACK/context/build-commands.md"  "$TARGET/.agent-kit-local/context/build-commands.md" build-commands.md
seed_stack_modules   # by declared name only — never a sweep of .agent-kit-local/modules/

# 4b. --reset-defaults: the project uses settings.json only, so drop any settings.local.json that would
#     shadow the kit defaults.
if [ "$RESET_DEFAULTS" = 1 ] && [ -f "$TARGET/.claude/settings.local.json" ]; then
  run "rm -f \"$TARGET/.claude/settings.local.json\""
  note "removed .claude/settings.local.json (--reset-defaults)"
fi

# 5. regenerate the Codex generated files (AGENTS.md + agents/code-reviewer.md)
if command -v make >/dev/null 2>&1 && [ -f "$TARGET/.codex/Makefile" ]; then
  # GENERATION must succeed — without it the target has no Codex/Cursor/VS Code surfaces at all, so a
  # failure here is a genuinely broken install and the trap above should fire.
  run "make -C \"$TARGET/.codex\" sync-generate"
  # Codex's developer_instructions carries this same body — warn, never fail, when a consumer's grows
  # past the kit's 32 KiB budget (stacks are trimmed to fit it; a consumer's own context/ edits can
  # still cross it). Skipped under --check: sync-generate did not actually run, so AGENTS.md may be
  # stale or absent, and measuring it would report on the wrong content.
  if [ "$CHECK" = 0 ] && [ -f "$TARGET/.codex/AGENTS.md" ]; then
    codex_body_size="$(wc -c < "$TARGET/.codex/AGENTS.md" | tr -d ' ')"
    if [ "$codex_body_size" -gt 32768 ]; then
      note "⚠ Codex developer_instructions is $codex_body_size bytes — over the kit's 32 KiB (32768-byte) budget."
      note "   Trim this stack's .agent-kit-local/context/ or process docs; .codex/AGENTS.md holds the exact body."
    fi
  fi
  # PARITY is advisory *here*, and only here. It lints skill prose — it builds nothing — yet it ships
  # inside `sync-agents`, so letting it abort leaves a project wiped by step 1 and never rebuilt, over
  # a doc-list mismatch that broke no surface. Warn loudly instead; `make -C .codex sync-agents` still
  # gates it for anyone who runs it, and verify.sh gates it in the kit.
  if [ "$CHECK" = 1 ]; then
    note "[check] make -C .codex validate-skills (advisory)"
  elif ! make -C "$TARGET/.codex" validate-skills; then
    note "⚠ Claude/Codex skill doc-list drift (above). The install COMPLETED — every surface is built."
    note "   Fix the skill pair, then re-run: make -C .codex sync-agents"
  fi
elif [ "$CHECK" = 1 ]; then
  # A dry run has not copied the Makefile into the target, so its absence says nothing about a real run.
  command -v make >/dev/null 2>&1 \
    && note "[check] would run make -C .codex sync-generate" \
    || note "[check] make is not installed, so the real run would skip the Codex sync"
else
  note "skipped Codex sync (no make or no .codex/Makefile)"
fi

# 5b. per-tool report of the foreign instruction files this install leaves untouched on disk.
report_foreign_instructions

# 6. provenance
# stack / version / source describe the KIT; stack_source / stack_version describe the stacks root the
# stack came from (the same place and SHA for a core stack). seed_ref reads both pairs back.
run "printf 'stack: %s\\nversion: %s\\nsource: %s\\ninstalled: %s\\nstack_source: %s\\nstack_version: %s\\n' \"$STACK\" \"$KIT_VERSION\" \"$SRC\" \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \"$STACK_SOURCE\" \"$STACK_VERSION\" > \"$TARGET/.synced-from\""

if [ "$CHECK" = 1 ]; then
  echo "Done (dry run — nothing written)."
else
  INSTALL_DONE=1
  echo "Done."
fi
