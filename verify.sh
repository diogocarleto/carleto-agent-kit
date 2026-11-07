#!/usr/bin/env bash
#
# verify.sh — install every stack into a throwaway target and assert the result.
#
# WHY FIXTURES: the generic stack's whole point is non-JVM projects, and every repo on this
# machine is Java. So the script synthesizes minimal Go / Python / Node / docs-only repos —
# just a manifest and a couple of source files, enough for the install and the assertions
# below to be real. Fixtures live under .scratch-target/ (gitignored) and are rebuilt each run.
#
#   ./verify.sh                     the core checks, all stacks + all fixtures
#   ./verify.sh generic             one stack (fixtures still run for `generic`)
#   ./verify.sh --overlay <dir>     also the overlay's stacks (<dir>/stacks/*/) and its private checks:
#                                   each <dir>/verify.d/*.sh is sourced, in lexical order, after the core
#                                   checks. A hook's top level calls its own check functions, using note,
#                                   bad, $SRC, $OUT, $ONLY, $OVERLAY and every helper below. An overlay with
#                                   stacks/ and no verify.d/*.sh still runs (its stacks are checked); one
#                                   with neither fails.
#   Arguments combine in any order: ./verify.sh generic --overlay <repo>
#
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$SRC/.scratch-target"
ONLY=""
OVERLAY=""
OVERLAY_GIVEN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --overlay)
      [ $# -ge 2 ] || { echo "verify.sh: --overlay needs a directory" >&2; exit 2; }
      OVERLAY="$2"; OVERLAY_GIVEN=1; shift 2 ;;
    --overlay=*) OVERLAY="${1#--overlay=}"; OVERLAY_GIVEN=1; shift ;;
    -*) echo "verify.sh: unknown option $1 (usage: verify.sh [<stack>] [--overlay <dir>])" >&2; exit 2 ;;
    *)
      [ -z "$ONLY" ] || { echo "verify.sh: more than one stack named ($ONLY, $1)" >&2; exit 2; }
      ONLY="$1"; shift ;;
  esac
done
if [ -n "$OVERLAY_GIVEN" ]; then
  [ -n "$OVERLAY" ] || { echo "verify.sh: --overlay needs a directory" >&2; exit 2; }
  [ -d "$OVERLAY" ] || { echo "verify.sh: --overlay '$OVERLAY' is not a directory" >&2; exit 2; }
  OVERLAY="$(cd "$OVERLAY" && pwd -P)"
fi
export OVERLAY
# Where stacks live: the kit's own, plus the overlay's when it has any and they are not the same
# directory (an overlay whose stacks/ is the kit's own adds nothing, so the two roots coincide).
STACK_ROOTS=("$SRC/stacks")
if [ -n "$OVERLAY" ] && [ -d "$OVERLAY/stacks" ] \
   && [ "$(cd "$OVERLAY/stacks" && pwd -P)" != "$(cd "$SRC/stacks" && pwd -P)" ]; then
  STACK_ROOTS+=("$OVERLAY/stacks")
fi
fail=0
note() { printf '  %-9s %s\n' "$1" "$2"; }
bad()  { note "✗ FAIL" "$1"; fail=$((fail + 1)); }

# ── fixtures: minimal non-JVM repos (generic stack has no other way to be exercised) ─────────
mk_fixtures() {
  rm -rf "$OUT/fx"; mkdir -p "$OUT/fx"
  mkdir -p "$OUT/fx/go/cmd/api" "$OUT/fx/go/internal/order"
  printf 'module example.com/orders\n\ngo 1.22\n'                > "$OUT/fx/go/go.mod"
  printf 'package order\n\nfunc Serve() {}\n'                    > "$OUT/fx/go/internal/order/service.go"
  printf 'package order\n\nimport "testing"\n\nfunc TestServe(t *testing.T) {}\n' \
                                                                 > "$OUT/fx/go/internal/order/service_test.go"
  mkdir -p "$OUT/fx/python/app/services" "$OUT/fx/python/tests"
  printf '[project]\nname = "orders"\ndependencies = ["fastapi"]\n' > "$OUT/fx/python/pyproject.toml"
  printf 'class OrderService:\n    def place(self, oid: str) -> None: ...\n' \
                                                                 > "$OUT/fx/python/app/services/order_service.py"
  printf 'def test_place(): pass\n'                              > "$OUT/fx/python/tests/test_order_service.py"
  mkdir -p "$OUT/fx/node/src/components"
  printf '{"name":"orders-web","scripts":{"test":"vitest run","build":"vite build"},"dependencies":{"react":"^18.3.1"}}\n' \
                                                                 > "$OUT/fx/node/package.json"
  printf 'export function OrderList() { return null; }\n'        > "$OUT/fx/node/src/components/OrderList.jsx"
  mkdir -p "$OUT/fx/docs/notes"                    # no manifest at all — the docs-repo case
  printf '# Ideas\n'                                             > "$OUT/fx/docs/README.md"
}

# ── assertions against one installed target ──────────────────────────────────────────────────
check() {
  local dir="$1" label="$2" stack="$3"

  for f in .claude/CLAUDE.md .codex/AGENTS.md .cursor/rules/agent-kit.mdc .github/copilot-instructions.md; do
    [ -s "$dir/$f" ] || bad "$label: Tier-0 surface missing — $f"
  done

  # The claudeMdExcludes install computed for this target must spare the kit's own .claude/CLAUDE.md at its
  # real path — Claude would drop it and every @import with it. (claude_md_excludes covers the rest.)
  local gout
  if [ -f "$dir/.claude/settings.json" ] && ! gout=$(_glob_check "$dir" 2>&1); then bad "$label: $gout"; fi

  # Codex's developer_instructions carries this exact body (byte-for-byte — proven in codex_config_toml
  # below). install.sh only WARNS past the kit's 32 KiB (32768-byte) budget — it must still finish the
  # install — so this is the one place that actually GATES it: a stack whose fresh-install body regresses
  # past the budget fails here, by name and size, instead of shipping silently warned-about to everyone
  # on that stack.
  if [ -f "$dir/.codex/AGENTS.md" ]; then
    local codex_body_size
    codex_body_size="$(wc -c < "$dir/.codex/AGENTS.md" | tr -d ' ')"
    [ "$codex_body_size" -le 32768 ] \
      || bad "$label: Codex developer_instructions is $codex_body_size bytes — over the kit's 32 KiB (32768-byte) budget"
  fi

  # Every shared doc under common/.agent-kit/ must actually ARRIVE, byte-for-byte. Skills and agents
  # glob directories rather than naming files, so a doc that is never delivered fails silently — the
  # skill simply loads less and nobody sees an error. (One-way walk: a stack's own conventions/ files
  # are extra in the target and correctly ignored here.)
  local src rel
  while IFS= read -r src; do
    rel="${src#$SRC/common/}"
    cmp -s "$src" "$dir/$rel" || bad "$label: shared file not delivered or altered — $rel"
  done < <(find "$SRC/common/.agent-kit" -type f)

  # The Codex reviewer is GENERATED by a Makefile glob, and the cmp walk above proves only that
  # .agent-kit/backend/core.md ARRIVED — not that the reviewer inlined it. A glob that matched nothing
  # (a renamed BACK path, a wildcard typo) ships a reviewer that judges against none of the neutral
  # backend rules and exits 0, so prove it on the installed file: the core's own H1 must be in it.
  local core_h1
  core_h1="$(head -n 1 "$SRC/common/.agent-kit/backend/core.md" 2>/dev/null || true)"
  # ⚠ Guarded: an H1-less first line (a blank, a front-matter fence) would make `grep -x` match some
  # other line — or none — and the proof below would mean nothing.
  case "$core_h1" in
    '# '*)
      if [ -f "$dir/.codex/agents/code-reviewer.md" ]; then
        grep -qxF "$core_h1" "$dir/.codex/agents/code-reviewer.md" \
          || bad "$label: the generated .codex/agents/code-reviewer.md does not inline .agent-kit/backend/core.md — the Codex reviewer would judge against none of the neutral backend rules"
      else
        bad "$label: .codex/agents/code-reviewer.md was not generated — nothing to prove the neutral backend core reached the Codex reviewer"
      fi ;;
    *) bad "$label: backend core: core.md must start with its H1 ('# …') — the Codex-reviewer proof keys on that line" ;;
  esac
  # The H1 proves the glob matched at all; it does not prove each further file in the directory arrived.
  # The Makefile writes a path marker before every inlined doc, so each depth-1 neutral file must have one.
  # Keyed on the path, not an H1: a neutral doc and a stack doc share names (design-principles.md,
  # logging.md), and once inlined the path is the one thing that tells them apart.
  local bk
  if [ -f "$dir/.codex/agents/code-reviewer.md" ]; then
    for bk in "$SRC"/common/.agent-kit/backend/*.md; do
      [ -f "$bk" ] || continue
      grep -qxF "<!-- source: .agent-kit/backend/$(basename "$bk") -->" "$dir/.codex/agents/code-reviewer.md" \
        || bad "$label: the generated .codex/agents/code-reviewer.md has no source marker for .agent-kit/backend/$(basename "$bk") — the Codex reviewer would not apply it, or could not tell it from a stack doc of the same name"
    done
  fi

  # CLAUDE.md is the ONE place @import is expanded (and documented). A dangling one there silently
  # drops always-on context, so every path must resolve — relative to CLAUDE.md's own directory.
  # ⚠ Matched by SHAPE anywhere on the line, not '^@': Claude expands a MID-LINE @path too (verified —
  # "See also @../.agent-kit/...code-review.md" arrived in a no-tools probe). A '^@' scan therefore
  # missed both failure modes: a dangling mid-line import dropping context while verify PASSed, and a
  # mid-line import making Claude's Tier-0 larger than TIER0_DOCS without tripping the set check below.
  local imp
  while read -r imp; do
    [ -n "$imp" ] || continue
    [ -e "$dir/.claude/$imp" ] || bad "$label: unresolved @import in .claude/CLAUDE.md — $imp"
  done < <(grep -oE '@[./][A-Za-z0-9_./-]+' "$dir/.claude/CLAUDE.md" 2>/dev/null | sed 's/^@//' || true)

  # Agents and skills are the opposite case: @import is NOT expanded there. Verified empirically —
  # a spawned reviewer and an invoked skill both receive the literal "@../../path" string with no
  # document body. So an @import in one of these is a doc the agent SILENTLY NEVER RECEIVES, and the
  # failure is invisible by construction: a reviewer with no checklist still writes confident-looking
  # findings, and a skill still produces output. TWENTY such lines shipped for months: 9 across the
  # three reviewers, 11 across ui-design, ui-extract, structure-extract and feature-plan. Name the doc
  # in prose instead — a named file or a glob instruction, either reaches it; an @import does not.
  # `if`, not `grep -q … && bad …`: the && form leaves the loop's status at grep's non-zero whenever the
  # LAST file has no import, so under set -euo pipefail it would kill verify.sh the moment this loop
  # became the final statement of check() — no ✗, no FAIL line, every later check skipped.
  # Matched by import SHAPE (@ followed by . or /), anywhere on the line — not '^@'. Three reasons:
  # a mid-line import is just as dead here; a Java sample starting a line with @Path/@Override/@Schema
  # is NOT an import and a '^@' scan mis-diagnosed it as one (scaffold/dcr/messaging are full of them);
  # and the shape is what lets the CODEX mirrors be scanned too — they were exempt, so the lane that
  # ships to every consumer was the less-gated one. Generated files are skipped: code-reviewer.md
  # inlines convention docs verbatim, Java annotations and all.
  local f
  for f in "$dir"/.claude/agents/*.md "$dir"/.claude/skills/*/SKILL.md \
           "$dir"/.codex/agents/*.md "$dir"/.codex/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    if grep -q 'Generated from' "$f"; then continue; fi
    if grep -qE '@[./]' "$f"; then
      bad "$label: ${f#$dir/} uses @import — not expanded in agent/skill files, so the doc never arrives; name it in prose"
    fi
  done

  # Tier-0 must be the SAME SET on every harness, but it is written down twice: Claude gets it from
  # CLAUDE.md's @import chain, Codex/Cursor/VS Code from the Makefile's TIER0_DOCS. Two independent
  # lists drift, and every symptom is silent — drop one from TIER0_DOCS and three harnesses lose it
  # while Claude still loads it; add one and it becomes always-on for three harnesses and not the
  # fourth. Nothing compared them, and the surface checks above only test non-emptiness.
  local tier0 imports
  tier0=$(awk '
    /^TIER0_DOCS[[:space:]]*=/ { f=1; sub(/^[^=]*=/, "") }
    f { cont = ($0 ~ /\\[[:space:]]*$/); gsub(/\\/, ""); print; if (!cont) exit }
  ' "$dir/.codex/Makefile" 2>/dev/null | tr ' \t' '\n' | grep . | sed 's|.*/||' | sort -u || true)
  imports=$(grep -oE '@[./][A-Za-z0-9_./-]+' "$dir/.claude/CLAUDE.md" | sed 's|.*/||' | sort -u || true)
  if [ -z "$tier0" ]; then
    bad "$label: could not read TIER0_DOCS from the installed Makefile — the Tier-0 gate did not run"
  elif [ "$tier0" != "$imports" ]; then
    bad "$label: Tier-0 set differs between harnesses (Makefile TIER0_DOCS vs CLAUDE.md @imports):$(
      echo; diff <(echo "$imports") <(echo "$tier0") | sed 's/^/           /')"
  fi

  # process/ depth-1 is DECLARED to mean always-on, but the mechanism is TIER0_DOCS + CLAUDE.md's
  # imports — so a doc dropped in process/ root and added to neither list is loaded by nothing while
  # sitting where the taxonomy says always-on. Make the convention mechanical instead of aspirational:
  # anything at depth-1 must be in the Tier-0 list (which the check above ties to Claude's imports).
  local d1
  for d1 in "$dir"/.agent-kit/common/process/*.md; do
    [ -f "$d1" ] || continue
    grep -qxF "$(basename "$d1")" <<<"$tier0" \
      || bad "$label: $(basename "$d1") sits at process/ depth-1 (always-on by the taxonomy) but is in no Tier-0 list — move it to a companion dir or add it to TIER0_DOCS + CLAUDE.md"
  done

  # Skills are shared verbatim; Cursor + VS Code read the Claude copies, so a count/name split
  # means two harnesses silently disagree. (install.sh's validate-skills checks the doc lists.)
  diff <(ls "$dir/.claude/skills") <(ls "$dir/.codex/skills") >/dev/null \
    || bad "$label: .claude/skills and .codex/skills differ"

  # A generic install must not carry build-tool instructions from a framework stack. Checked on
  # SOURCE docs only — the Tier-0 surfaces (AGENTS.md, the Cursor rule, copilot-instructions.md)
  # are concatenations of these, so scanning them again only re-reports the same lines.
  # Excluded: shell-hygiene (uses `mvn` as a sample program name to teach the permission matcher),
  # context/ (its placeholder deliberately lists one example per language), the UI framework
  # catalogue, illustrative templates, and the skills that ship inert on a generic project.
  if [ "$stack" = generic ]; then
    local hits
    hits=$(grep -rlE '(mvn |pom\.xml|-Dtest=|src/main/java|Java \+ Maven)' \
             "$dir/.agent-kit" "$dir/.claude/agents" "$dir/.claude/skills" \
             "$dir/.codex/agents" "$dir/.codex/skills" 2>/dev/null \
           | grep -vE 'shell-hygiene|/context/|/ui/|structure.template|planning/TEMPLATE|skills/(dcr|ui-|structure-extract|module-extract)' \
           || true)
    [ -z "$hits" ] || bad "$label: Java/Maven instructions in a generic install →$(echo " $hits" | sed "s|$dir/||g" | tr '\n' ' ')"

    # The Maven-shaped patterns above never catch a FRAMEWORK name. .agent-kit/messaging/ is the
    # stack-blind half of /messaging — the whole point of splitting it was that one framework's class
    # and package names stopped shipping to every stack. Nothing asserted they stay out, so a future
    # `@ConsumeEvent` landing there would pass verify silently and reinstate the exact bug. (Client
    # package prefixes belong to an overlay's own hooks.)
    # Skills AND agents are scanned: both are shared verbatim across stacks by construction, which is
    # exactly why a framework name in either is the bug. (The Maven gate above already covers agents.)
    # ⚠ The WHOLE .agent-kit tree, not just messaging/: a framework name is equally wrong in a Tier-0
    # process doc, in .agent-kit/README.md, or in modules/ — and narrowing this to messaging/ once let
    # an edit to .agent-kit/README.md go unscanned. structure.template.yml is excluded: it ships
    # example provenance rows that name real orgs by design.
    hits=$(grep -rlEi '(@ConsumeEvent|@EventProducer|quarkus)' \
             "$dir/.agent-kit" "$dir/.claude/skills" "$dir/.codex/skills" \
             "$dir/.claude/agents" "$dir/.codex/agents" 2>/dev/null \
           | grep -v 'structure.template.yml' || true)
    [ -z "$hits" ] || bad "$label: framework names in a stack-blind file →$(echo " $hits" | sed "s|$dir/||g" | tr '\n' ' ')"

    # The grep above is messaging- and Quarkus-shaped; it never catches a PERSISTENCE-API name.
    # .agent-kit/persistence/ states engine facts once, for every stack — how an ORM, a repository
    # abstraction or a migration tool expresses them is the stack's half, in its own backend/persistence-<db>.md.
    # Scoped to that one dir, since these words are legitimate in the stacks' docs and in the skills
    # that point at them.
    hits=$(grep -rlEi '(hibernate|panache|spring|jakarta\.persistence|EntityManager|@Transactional|@Version|mongock)' \
             "$dir/.agent-kit/persistence" 2>/dev/null || true)
    [ -z "$hits" ] || bad "$label: persistence-API names in the neutral persistence docs →$(echo " $hits" | sed "s|$dir/||g" | tr '\n' ' ')"

    # Neither gate above catches a LANGUAGE leak: `Javadoc` prescribed as the thing to write shipped
    # for months in the plan-execution loop, where the generic fixtures are Go/Python/Node/docs-only.
    # Exclusions, each a doc that may say the word: doc-style.md and execution-loop.md name the
    # variant set (Javadoc / JSDoc / docstrings) instead of prescribing one, the backend/fullstack
    # skills address a JVM-capable layer by design, and the generated code-reviewer just inlines
    # doc-style.md — scanning a concatenation only re-reports its sources.
    hits=$(grep -rlF 'Javadoc' \
             "$dir/.agent-kit" "$dir/.claude/skills" "$dir/.codex/skills" \
             "$dir/.claude/agents" "$dir/.codex/agents" 2>/dev/null \
           | grep -vE 'authoring/doc-style|planning/execution-loop|skills/(backend|fullstack)|agents/code-reviewer' || true)
    [ -z "$hits" ] || bad "$label: Javadoc prescribed in a stack-blind file →$(echo " $hits" | sed "s|$dir/||g" | tr '\n' ' ')"
  fi
}

# ── seed lifecycle ───────────────────────────────────────────────────────────────────────────
# A fixture kit with TWO committed versions of the seeds the lifecycle checks read out of the kit's
# history: v1 holds an older settings.json seed and an older jakarta-ee context/architecture.md, v2 holds
# the real current ones. Sets HIST_V1 (v1's short SHA). Never reads $SRC's own history, which is a single
# commit wherever the core is published on its own. -C is mandatory on every git write (_xs_commit).
HIST_V1=""
_hist_kit() {  # <dir>
  local k="$1" item
  rm -rf "$k"; mkdir -p "$k"
  for item in install.sh README.md LICENSE NOTICE .gitignore common stacks; do
    [ -e "$SRC/$item" ] || return 1
    cp -R "$SRC/$item" "$k/$item" || return 1
  done
  git -C "$k" init -q >/dev/null 2>&1 && [ -d "$k/.git" ] || return 1
  printf '{\n  "permissions": {\n    "allow": [\n      "Bash(old-seed-tool:*)"\n    ]\n  }\n}\n' > "$k/common/.claude/settings.json"
  printf 'HISTORIC ARCH SEED\n' > "$k/stacks/jakarta-ee/context/architecture.md"
  _xs_commit "$k" v1 || return 1
  HIST_V1="$(git -C "$k" rev-parse --short HEAD)"
  cp "$SRC/common/.claude/settings.json" "$k/common/.claude/settings.json" \
    && cp "$SRC/stacks/jakarta-ee/context/architecture.md" "$k/stacks/jakarta-ee/context/architecture.md" \
    && _xs_commit "$k" v2
}

# Seeds are the subtle half of install.sh: a project's edits must survive forever, while a copy the
# project never touched must still follow the kit. Both directions are silent when wrong — a lost
# edit looks like nothing happened, and a stale seed keeps loading as always-on Tier-0.
seed_lifecycle() {
  local d="$OUT/seeds" kit="$OUT/slkit" before=$fail
  rm -rf "$d"; mkdir -p "$d"
  _hist_kit "$kit" || { bad "seed lifecycle: could not build the fixture kit with two committed seed versions"; return 0; }
  "$kit/install.sh" jakarta-ee "$d" >/dev/null 2>&1

  # (a) switching stacks replaces context/ the project never edited — else the old stack's
  #     architecture prose keeps loading in every session on the new stack.
  "$kit/install.sh" generic "$d" >/dev/null 2>&1
  grep -q 'TEMPLATE — replace this file' "$d/.agent-kit-local/context/architecture.md" \
    || bad "seed lifecycle: stack switch kept the old stack's untouched architecture.md"

  # (b) an edited seed is never touched, by a stack switch or anything else.
  printf '\nPROJECT LINE\n' >> "$d/.agent-kit-local/context/architecture.md"
  "$kit/install.sh" jakarta-ee "$d" >/dev/null 2>&1
  grep -q 'PROJECT LINE' "$d/.agent-kit-local/context/architecture.md" \
    || bad "seed lifecycle: stack switch discarded a project-edited seed"

  # (c) a seed the project never edited follows the kit forward across versions. The older seed is the
  #     fixture kit's v1, and the target is stamped at it.
  git -C "$kit" show "$HIST_V1:common/.claude/settings.json" > "$d/.claude/settings.json" 2>/dev/null \
    || { bad "seed lifecycle: could not read the fixture kit's v1 settings.json"; return 0; }
  grep -v '^version:' "$d/.synced-from" > "$d/.sf" && printf 'version: %s\n' "$HIST_V1" >> "$d/.sf"
  mv "$d/.sf" "$d/.synced-from"
  "$kit/install.sh" jakarta-ee "$d" --force >/dev/null 2>&1
  # Compared without claudeMdExcludes: install generates that key on top of the seed (claude_md_excludes).
  [ "$(_claude_settings_sans_excludes "$d/.claude/settings.json")" = "$(_claude_settings_sans_excludes "$SRC/common/.claude/settings.json")" ] \
    || bad "seed lifecycle: untouched settings.json did not follow the kit from $HIST_V1"

  # (d) untouched is judged against the seed as the consumer RECEIVED it, not as it stands today —
  #     otherwise a kit revision to a template retroactively reclassifies every consumer as "edited".
  #     The received seed is the fixture kit's v1 architecture.md, which differs from today's.
  rm -rf "$d"; mkdir -p "$d"
  "$kit/install.sh" jakarta-ee "$d" >/dev/null 2>&1
  git -C "$kit" show "$HIST_V1:stacks/jakarta-ee/context/architecture.md" > "$d/.agent-kit-local/context/architecture.md" 2>/dev/null \
    || { bad "seed lifecycle: could not read the fixture kit's v1 architecture.md"; return 0; }
  # An old-format stamp (no stack_* lines): the stack seed is then judged at version:, in the kit's own
  # history. The new-format switch is gated in external_stack_roots (4).
  grep -v -e '^version:' -e '^stack_source:' -e '^stack_version:' "$d/.synced-from" > "$d/.sf" \
    && printf 'version: %s\n' "$HIST_V1" >> "$d/.sf"
  mv "$d/.sf" "$d/.synced-from"
  "$kit/install.sh" generic "$d" >/dev/null 2>&1
  grep -q 'TEMPLATE — replace this file' "$d/.agent-kit-local/context/architecture.md" \
    || bad "seed lifecycle: a seed matching the version the consumer received ($HIST_V1) was misread as edited"

  [ "$fail" -eq "$before" ] || return 0; note "✓" "seed lifecycle (replaces untouched · keeps edited · follows kit version · judges against the received version)"
}


# ── the neutral messaging half must stay prescriptive and neutral ─────────────────────────────
# A per-stack-pair half (two stacks wrapping forks of one messaging module) is an overlay's, in a verify.d/ hook.
messaging_doc_coverage() {
  local before=$fail

  # The neutral half, from the other direction. The framework-name grep (see generic_is_stack_blind)
  # stops a stack's class names landing in core.md; nothing stopped the opposite drift — core.md being
  # softened into a broker survey that costs a Tier-1 read and changes nobody's code. It is prescriptive
  # and DISTILLED from a real stack; CONTRIBUTING's "What belongs in a stack convention doc" is the contract.
  # Phrase-level, with the same honest limit as the pair's topics: presence, not truth.
  local core="$SRC/common/.agent-kit/messaging/core.md" cflat
  if [ -f "$core" ]; then
    cflat="$(tr '\n' ' ' < "$core")"
    grep -qE '[Pp]rescriptive' <<<"$cflat" || bad "messaging coverage: core.md no longer states it is prescriptive — the neutral layer is a directive, not background reading"
    grep -qE 'module.extract|module memory' <<<"$cflat" || bad "messaging coverage: core.md no longer sends depth to module memory — that pointer is what keeps mechanism out of both layers"
  else
    bad "messaging coverage: $core is missing — the stack-blind half of /messaging"
  fi

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "messaging: core.md stays prescriptive and neutral"
}

# ── what actually ships ──────────────────────────────────────────────────────────────────────
# install.sh copies common/ and stacks/ with `cp -R`, which does not care what git knows about. So
# anything untracked sitting in those trees — a stray test fixture, an empty scratch dir — ships to
# every consumer while being invisible here, and a fresh clone of the kit then produces a different
# install than this machine does. Empty dirs count: git cannot track them at all, yet cp -R copies them.
# ── stack.yml must describe the stack it ships ──────────────────────────────────────────────
# README points at stack.yml as a stack's descriptor, so readers trust it — and install.sh reads
# only `description` plus the file's existence. That makes layers/companions/context pure prose,
# and prose nothing checks is prose that drifts. A reference that can silently lie is worse than
# none, which is the whole reason to gate it.
# ⚠ This does NOT re-enumerate the kit: adding or renaming a convention DOC still touches nothing
# (the glob payoff is intact). Only adding a whole LAYER — a closed set of four, changed once ever —
# touches stack.yml, and that is exactly the change a reader of the descriptor needs to see.
stack_yml_describes_its_tree() {
  local before=$fail out
  out=$(python3 - "${STACK_ROOTS[@]}" <<'PYEOF'
import os, re, sys
bad = []
for root, s in ((r, s) for r in sys.argv[1:] for s in sorted(os.listdir(r))):
    d = f'{root}/{s}'
    if not os.path.isfile(f'{d}/stack.yml'):
        continue
    y = open(f'{d}/stack.yml').read()
    def block(key):
        out, inb = [], False
        for line in y.splitlines():
            if re.match(rf'^{key}:\s*$', line):
                inb = True; continue
            if inb:
                m = re.match(r'^\s+-\s*([^#\s]+)', line)
                if m: out.append(m.group(1))
                elif line.strip() and not line.lstrip().startswith('#'): break
        return sorted(out)
    conv = f'{d}/conventions'
    layers = sorted(os.listdir(conv)) if os.path.isdir(conv) else []
    comps = sorted(f'{l}/{c}' for l in layers
                   for c in (os.listdir(f'{conv}/{l}') if os.path.isdir(f'{conv}/{l}') else [])
                   if os.path.isdir(f'{conv}/{l}/{c}'))
    ctx = sorted(os.listdir(f'{d}/context')) if os.path.isdir(f'{d}/context') else []
    # modules: the module memory this stack SHIPS. install.sh seeds by this declared list and by
    # nothing else, so a name here that has no directory seeds silently nothing, and a directory
    # with no name here never reaches a consumer at all.
    md = f'{d}/modules'
    mods = sorted(m for m in os.listdir(md) if os.path.isdir(f'{md}/{m}')) if os.path.isdir(md) else []
    for key, real in (('layers', layers), ('companions', comps), ('context', ctx), ('modules', mods)):
        dec = block(key)
        if dec != real:
            bad.append(f"{s}: {key}: declares {dec or '[]'}, tree has {real or '[]'}")
print("\n".join(bad))
PYEOF
  )
  [ -z "$out" ] || { bad "stack.yml does not describe its own tree:"; printf '%s\n' "$out" | sed 's/^/           /'; }
  [ "$fail" -eq "$before" ] || return 0
  note "✓" "each stack.yml describes the tree it actually ships (layers · companions · context · modules)"
}

# ── stack-shipped module memory: seeded BY NAME, never over what the project wrote ───────────
# A stack may ship module memory for the framework modules all its consumers share
# (stacks/<s>/modules/<name>/, declared in stack.yml → modules:). It seeds into
# .agent-kit-local/modules/<name>/ with the same lifecycle as context/ — and into the SAME directory
# the project keeps its OWN module memory in. That co-tenancy is the entire risk of the feature:
# widen seeding from "the declared names" to "the modules/ directory" and a project-authored module
# silently becomes a kit default, which --reset-defaults then replaces with nothing. The kit cannot
# regenerate that content, and the failure looks like an ordinary reinstall.
# Every assertion here is silent when it breaks — a lost module.md is indistinguishable from an
# install that did nothing — so each one is a real read, not a comment.
# ⚠ The lifecycle is exercised against a FIXTURE kit staged in the gitignored sandbox, not against
# a real stack's seeds, so the assertions hold whatever a stack ships. Never under stacks/:
# that tree ships to every consumer.
stack_module_seeds() {
  local kit="$OUT/modkit" d="$OUT/modseed" e="$OUT/modseed-none" before=$fail item
  rm -rf "$kit" "$d" "$e"; mkdir -p "$kit" "$d" "$e"
  for item in install.sh README.md LICENSE NOTICE .gitignore common stacks; do
    [ -e "$SRC/$item" ] || { bad "stack modules: kit source '$item' is missing — this check needs updating"; return 0; }
    cp -R "$SRC/$item" "$kit/$item" || { bad "stack modules: could not stage a kit copy ($item)"; return 0; }
  done
  mkdir -p "$kit/stacks/generic/modules/fx-widget"
  printf 'SEED v1\n'      > "$kit/stacks/generic/modules/fx-widget/module.md"
  printf 'INTERNALS v1\n' > "$kit/stacks/generic/modules/fx-widget/internals.md"
  printf '\nmodules:\n  - fx-widget\n' >> "$kit/stacks/generic/stack.yml"
  # install.sh proves "untouched" by reading the seed out of the KIT's own git history at the version
  # in .synced-from, so the fixture kit has to be a repo for (b) and (c) to mean anything.
  # ⚠ -C is mandatory on every git write here: bare `git commit` would target the kit under test
  # (shell-hygiene.md → the scratch-repo exception).
  git -C "$kit" init -q >/dev/null 2>&1
  git -C "$kit" add -A >/dev/null 2>&1
  git -C "$kit" -c user.email=v@verify -c user.name=verify commit -qm v1 >/dev/null 2>&1 \
    || { bad "stack modules: could not commit the fixture kit"; return 0; }

  # (a) a declared module seeds — every file in it, not just module.md …
  "$kit/install.sh" generic "$d" >/dev/null 2>&1 || { bad "stack modules: install failed"; return 0; }
  grep -q '^SEED v1' "$d/.agent-kit-local/modules/fx-widget/module.md" 2>/dev/null \
    || bad "stack modules: a declared module was not seeded"
  grep -q '^INTERNALS v1' "$d/.agent-kit-local/modules/fx-widget/internals.md" 2>/dev/null \
    || bad "stack modules: a declared module's sibling file was not seeded"
  # … and INDEX.md is NOT written. It is project-owned: an install that wrote it would overwrite a
  # consumer's row order, hooks and stamps. /modules finds a row-less seeded module on its own.
  if [ -e "$d/.agent-kit-local/modules/INDEX.md" ]; then
    bad "stack modules: install wrote modules/INDEX.md — that file is project-owned"
  fi

  # The module the PROJECT wrote. Undeclared, so nothing below may ever touch it.
  mkdir -p "$d/.agent-kit-local/modules/project-own"
  printf 'OWNED by the project\n' > "$d/.agent-kit-local/modules/project-own/module.md"

  # (b) an untouched seed follows the kit forward — else a consumer freezes on whatever version
  #     first installed it, which is the bug the context/ seeds already had.
  printf 'SEED v2\n' > "$kit/stacks/generic/modules/fx-widget/module.md"
  git -C "$kit" add -A >/dev/null 2>&1
  git -C "$kit" -c user.email=v@verify -c user.name=verify commit -qm v2 >/dev/null 2>&1
  "$kit/install.sh" generic "$d" --force >/dev/null 2>&1
  grep -q '^SEED v2' "$d/.agent-kit-local/modules/fx-widget/module.md" \
    || bad "stack modules: an untouched module seed did not follow the kit to the next version"

  # (c) an edited seed is kept forever. Module memory is expensive to write; losing an edit here is
  #     the same loss as losing a plan.
  printf 'PROJECT LINE\n' >> "$d/.agent-kit-local/modules/fx-widget/module.md"
  printf 'SEED v3\n'       > "$kit/stacks/generic/modules/fx-widget/module.md"
  git -C "$kit" add -A >/dev/null 2>&1
  git -C "$kit" -c user.email=v@verify -c user.name=verify commit -qm v3 >/dev/null 2>&1
  "$kit/install.sh" generic "$d" --force >/dev/null 2>&1
  grep -q 'PROJECT LINE' "$d/.agent-kit-local/modules/fx-widget/module.md" \
    || bad "stack modules: a reinstall discarded a project-edited module seed"

  # (d) --reset-defaults replaces the seed, because it IS a seed …
  "$kit/install.sh" generic "$d" --reset-defaults >/dev/null 2>&1
  grep -q '^SEED v3' "$d/.agent-kit-local/modules/fx-widget/module.md" \
    || bad "stack modules: --reset-defaults did not restore a stack-shipped module to the kit version"
  if grep -q 'PROJECT LINE' "$d/.agent-kit-local/modules/fx-widget/module.md"; then
    bad "stack modules: --reset-defaults left an edited module seed in place"
  fi
  # … and NEVER a module the project wrote. THIS is the assertion the feature rests on: it is the
  # one that fails if seeding ever widens from the declared names to the directory.
  grep -q '^OWNED by the project' "$d/.agent-kit-local/modules/project-own/module.md" 2>/dev/null \
    || bad "stack modules: --reset-defaults DESTROYED a project-authored module dir"

  # (e) a stack that declares nothing seeds nothing — true of every stack shipping today, so a
  #     regression here reaches all four at once.
  "$SRC/install.sh" generic "$e" >/dev/null 2>&1 || bad "stack modules: baseline install failed"
  [ ! -e "$e/.agent-kit-local/modules" ] \
    || bad "stack modules: a stack declaring no modules still created .agent-kit-local/modules/"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "stack module seeds (seed by declared name · refresh untouched · keep edited · --reset-defaults replaces the seed, never a project-authored module)"
}

# ── external stack roots: --stacks <dir>, and seeds that follow the repo they came from ─────────
# `--stacks <dir>` lets install take a stack from a directory outside the kit. The seed lifecycle then
# has two histories to read — the kit's for kit seeds, the stacks root's own for stack seeds — and a path
# in a repo is computed (the dir's prefix + the relative path), never literal. Every failure here is
# silent: a seed misjudged "edited" just stops following its source, and nothing complains.
# ⚠ Runs against FIXTURES in the gitignored sandbox: a committed fixture kit, two committed fixture
# stacks repos (each holding its stacks root one level down, so a prefix is in play), and a kit repo
# whose layout moves between two commits. -C is mandatory on every git write (shell-hygiene.md).
_xs_commit() {  # <repo> <message>
  # ⚠ A fixture whose `git init` failed silently would resolve -C upward to the REAL kit repo, and the
  # `add -A` below would commit this checkout's work onto its branch. Refuse unless the repo is its own.
  [ -d "$1/.git" ] || return 1
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=v@verify -c user.name=verify commit -qm "$2" >/dev/null 2>&1
}
_xs_stack() {  # <stacks-root> <tag> — the one fixture stack, fx-ext; <tag> stamps every file's content
  local r="$1/fx-ext" t="$2"
  mkdir -p "$r/conventions/backend" "$r/context" "$r/modules/fx-mod"
  printf 'name: fx-ext\ndescription: fixture external stack\nmodules:\n  - fx-mod\n' > "$r/stack.yml"
  printf 'RULE %s\n'   "$t" > "$r/conventions/backend/fx-rule.md"
  printf 'ARCH %s\n'   "$t" > "$r/context/architecture.md"
  printf 'BUILD %s\n'  "$t" > "$r/context/build-commands.md"
  printf 'MODULE %s\n' "$t" > "$r/modules/fx-mod/module.md"
}
external_stack_roots() {
  local kit="$OUT/xs-kit" pfx="$OUT/xs-pfx" a="$OUT/xs-a" b="$OUT/xs-b" before=$fail item out ra rb sha
  local t1="$OUT/xs-t1" t2="$OUT/xs-t2" t5="$OUT/xs-t5" t6="$OUT/xs-t6" t7="$OUT/xs-t7"
  local a2="$OUT/xs-a2" ra2 t6b="$OUT/xs-t6b" t8="$OUT/xs-t8" ign="$OUT/xs-ign" d n r
  ra="$a/stacks"; rb="$b/stacks"; ra2="$a2/stacks"
  rm -rf "$a2" "$kit" "$pfx" "$a" "$b" "$ign" "$t1" "$t2" "$t5" "$t6" "$t6b" "$t7" "$t8"
  mkdir -p "$kit" "$pfx" "$a" "$b" "$ign" "$t1" "$t2" "$t5" "$t6" "$t6b" "$t7" "$t8"
  for item in install.sh README.md LICENSE NOTICE .gitignore common stacks; do
    [ -e "$SRC/$item" ] || { bad "external roots: kit source '$item' is missing — this check needs updating"; return 0; }
    cp -R "$SRC/$item" "$kit/$item" && cp -R "$SRC/$item" "$pfx/$item" \
      || { bad "external roots: could not stage a kit copy ($item)"; return 0; }
  done
  for r in "$kit" "$pfx" "$a" "$b" "$ign"; do
    git -C "$r" init -q >/dev/null 2>&1
    [ -d "$r/.git" ] || { bad "external roots: could not git init the fixture $r"; return 0; }
  done
  _xs_stack "$ra" c1; _xs_stack "$rb" b1
  # A stack that stays behind when the kit moves (a private one): see (6).
  mkdir -p "$pfx/stacks/fx-priv"
  printf 'name: fx-priv\ndescription: fixture private stack\n' > "$pfx/stacks/fx-priv/stack.yml"
  _xs_commit "$kit" k1 && _xs_commit "$pfx" p1 && _xs_commit "$a" c1 && _xs_commit "$b" b1 \
    || { bad "external roots: could not commit the fixtures"; return 0; }
  sha="$(git -C "$ra" rev-parse --short HEAD)"

  # (1) a stack under --stacks installs conventions, context and its declared module like a core stack,
  #     is stamped with where it came from, and --list shows it (whichever side of --list the flag is on).
  out=$("$kit/install.sh" fx-ext "$t1" --stacks "$ra" 2>&1) \
    || { bad "external roots: install of an external stack failed: $(printf '%s' "$out" | tail -3)"; return 0; }
  grep -qx 'RULE c1' "$t1/.agent-kit/common/conventions/backend/fx-rule.md" 2>/dev/null \
    || bad "external roots: an external stack's conventions were not installed"
  grep -qx 'ARCH c1' "$t1/.agent-kit-local/context/architecture.md" 2>/dev/null \
    && grep -qx 'BUILD c1' "$t1/.agent-kit-local/context/build-commands.md" 2>/dev/null \
    || bad "external roots: an external stack's context seeds were not installed"
  grep -qx 'MODULE c1' "$t1/.agent-kit-local/modules/fx-mod/module.md" 2>/dev/null \
    || bad "external roots: an external stack's declared module was not seeded"
  # install.sh stamps the physical path (pwd -P); $OUT may sit under a symlink (/tmp → /private/tmp)
  grep -qx "stack_source: $(cd "$ra" && pwd -P)" "$t1/.synced-from" && grep -qx "stack_version: $sha" "$t1/.synced-from" \
    || bad "external roots: .synced-from does not name the stacks root and its version"
  out=$("$kit/install.sh" --stacks "$ra" --list 2>&1) || true
  grep -q 'fx-ext' <<<"$out" && grep -q '^  generic ' <<<"$out" \
    || bad "external roots: --stacks <dir> --list does not show the external stack beside the kit's"
  out=$("$kit/install.sh" --list --stacks "$ra" 2>&1) || true
  grep -q 'fx-ext' <<<"$out" || bad "external roots: --list --stacks <dir> (flag after --list) does not show the external stack"

  # (2) a name in two roots is refused before anything is written, and --list says so.
  if out=$("$kit/install.sh" fx-ext "$t2" --stacks "$ra" --stacks "$rb" 2>&1); then
    bad "external roots: a stack name in two roots was installed"
  fi
  grep -q 'more than one stacks root' <<<"$out" || bad "external roots: the duplicate refusal does not say why"
  [ -z "$(ls -A "$t2")" ] || bad "external roots: a refused duplicate still wrote into the target"
  out=$("$kit/install.sh" --stacks "$ra" --stacks "$rb" --list 2>&1) || true
  [ "$(grep -c 'duplicate — install refuses' <<<"$out")" -eq 2 ] && grep -q "$ra" <<<"$out" && grep -q "$rb" <<<"$out" \
    || bad "external roots: --list does not mark the duplicate in both roots"

  # (3) the stacks repo moves on: an untouched stack seed follows it, an edited one is kept. The history
  #     read is the STACKS repo's (stack_source @ stack_version), not the kit's.
  printf 'ARCH c2\n'   > "$ra/fx-ext/context/architecture.md"
  printf 'MODULE c2\n' > "$ra/fx-ext/modules/fx-mod/module.md"
  _xs_commit "$a" c2
  printf 'PROJECT LINE\n' >> "$t1/.agent-kit-local/modules/fx-mod/module.md"
  "$kit/install.sh" fx-ext "$t1" --stacks "$ra" >/dev/null 2>&1 || bad "external roots: reinstall failed"
  grep -qx 'ARCH c2' "$t1/.agent-kit-local/context/architecture.md" 2>/dev/null \
    || bad "external roots: an untouched external-stack seed did not follow its repo"
  grep -q 'PROJECT LINE' "$t1/.agent-kit-local/modules/fx-mod/module.md" 2>/dev/null \
    || bad "external roots: a project-edited external-stack module seed was not kept"

  # (4) switching to a core stack: the untouched context seed is replaced — judged against the version the
  #     consumer RECEIVED (build-commands.md has moved on in the stacks repo since, so today's copy of the
  #     old stack would not match) — and the edited one is kept. No --stacks here: the stamp remembers it.
  printf 'BUILD c3\n' > "$ra/fx-ext/context/build-commands.md"
  _xs_commit "$a" c3
  printf 'PROJECT LINE\n' >> "$t1/.agent-kit-local/context/architecture.md"
  "$kit/install.sh" generic "$t1" >/dev/null 2>&1 || bad "external roots: switch to a core stack failed"
  cmp -s "$t1/.agent-kit-local/context/build-commands.md" "$kit/stacks/generic/context/build-commands.md" \
    || bad "external roots: a stack switch kept the external stack's untouched context seed"
  grep -q 'PROJECT LINE' "$t1/.agent-kit-local/context/architecture.md" 2>/dev/null \
    || bad "external roots: a stack switch discarded an edited context seed"

  # (5) a stamp in the old format — no stack_* lines — still refreshes a core stack's untouched seeds,
  #     judged against the kit's own history at `version:`.
  "$kit/install.sh" generic "$t5" >/dev/null 2>&1 || { bad "external roots: baseline install failed"; return 0; }
  printf '\nARCH-K2\n' >> "$kit/stacks/generic/context/architecture.md"
  _xs_commit "$kit" k2
  grep -v -e '^stack_source:' -e '^stack_version:' "$t5/.synced-from" > "$t5/.sf" && mv "$t5/.sf" "$t5/.synced-from"
  "$kit/install.sh" generic "$t5" >/dev/null 2>&1 || bad "external roots: reinstall over an old-format stamp failed"
  grep -q 'ARCH-K2' "$t5/.agent-kit-local/context/architecture.md" 2>/dev/null \
    || bad "external roots: an old-format stamp stopped refreshing untouched seeds"

  # (6) the real layout move: the kit and its stacks go down into core/ while a private stack stays in the
  #     repo's top-level stacks/ — so the stamp's stack_source is STILL a live directory (and the repo's
  #     stacks/ now holds only fx-priv). Seeds stamped before the move must still refresh: the prefix is
  #     computed from where the kit sits now (core/), and a miss is probed again without it.
  "$pfx/install.sh" generic "$t6"  >/dev/null 2>&1 || { bad "external roots: layout-move baseline install failed"; return 0; }
  "$pfx/install.sh" generic "$t6b" >/dev/null 2>&1 || { bad "external roots: layout-move baseline install failed"; return 0; }
  mkdir -p "$pfx/core/stacks"
  git -C "$pfx" mv install.sh README.md LICENSE NOTICE .gitignore common core/ >/dev/null 2>&1 \
    || { bad "external roots: could not move the fixture kit into core/"; return 0; }
  for d in "$pfx"/stacks/*/; do
    n="$(basename "$d")"
    if [ "$n" = fx-priv ]; then continue; fi
    git -C "$pfx" mv "stacks/$n" core/stacks/ >/dev/null 2>&1 \
      || { bad "external roots: could not move stack $n into core/stacks/"; return 0; }
  done
  printf '\n<!-- PFX-V2 -->\n' >> "$pfx/core/common/.claude/CLAUDE.md"
  printf '\nPFX-V2\n'          >> "$pfx/core/stacks/generic/context/architecture.md"
  _xs_commit "$pfx" p2 || { bad "external roots: could not commit the moved fixture kit"; return 0; }
  "$pfx/core/install.sh" generic "$t6" >/dev/null 2>&1 || bad "external roots: install from the moved kit failed"
  grep -q 'PFX-V2' "$t6/.claude/CLAUDE.md" 2>/dev/null \
    || bad "external roots: a kit seed stamped before a layout move was misread as edited"
  grep -q 'PFX-V2' "$t6/.agent-kit-local/context/architecture.md" 2>/dev/null \
    || bad "external roots: a stack seed stamped before a layout move (stack_source still live) was misread as edited"
  #     … and when the stamp's stack_source is gone altogether, the stack seed falls back to the kit's repo.
  grep -v '^stack_source:' "$t6b/.synced-from" > "$t6b/.sf" \
    && printf 'stack_source: %s\n' "$OUT/xs-gone/stacks" >> "$t6b/.sf" && mv "$t6b/.sf" "$t6b/.synced-from"
  "$pfx/core/install.sh" generic "$t6b" >/dev/null 2>&1 || bad "external roots: install from the moved kit failed"
  grep -q 'PFX-V2' "$t6b/.agent-kit-local/context/architecture.md" 2>/dev/null \
    || bad "external roots: a stack seed whose stamped stack_source vanished was misread as edited"

  # (7) the same stack name from a different stacks root is neither skipped nor left under the old stamp,
  #     and a root with uncommitted changes is never skipped on. The second root is a COPY of the first —
  #     same SHA, different path — so only the root can tell them apart (a differing version would block
  #     the skip on its own). The first rerun is the positive control: same root, same versions, clean →
  #     the guard does skip.
  cp -R "$a" "$a2" || { bad "external roots: could not copy the stacks repo"; return 0; }
  "$kit/install.sh" fx-ext "$t7" --stacks "$ra" >/dev/null 2>&1 || { bad "external roots: baseline install failed"; return 0; }
  out=$("$kit/install.sh" fx-ext "$t7" --stacks "$ra" 2>&1) || true
  grep -q 'nothing to do' <<<"$out" || bad "external roots: the already-latest guard no longer skips an unchanged external install"
  printf 'DIRTY\n' >> "$ra/fx-ext/conventions/backend/fx-rule.md"
  out=$("$kit/install.sh" fx-ext "$t7" --stacks "$ra" 2>&1) || bad "external roots: install from a dirty root failed"
  grep -q 'nothing to do' <<<"$out" && bad "external roots: a stacks root with uncommitted changes was skipped"
  grep -qx 'DIRTY' "$t7/.agent-kit/common/conventions/backend/fx-rule.md" 2>/dev/null \
    || bad "external roots: an uncommitted convention edit in the stacks root was not installed"
  git -C "$a" checkout -q -- . >/dev/null 2>&1   # -C: the fixture, never the kit under test
  out=$("$kit/install.sh" fx-ext "$t7" --stacks "$ra2" 2>&1) || bad "external roots: install from a different root failed"
  grep -q 'nothing to do' <<<"$out" && bad "external roots: the same stack from a different stacks root was skipped"
  grep -qx "stack_source: $(cd "$ra2" && pwd -P)" "$t7/.synced-from" \
    || bad "external roots: a reinstall from a different root was not re-stamped"

  # (8) a stacks root that its enclosing repo IGNORES has a repo around it yet nothing committed: git
  #     answers rev-parse and `status` hides ignored files, so it must not read as versioned and clean.
  _xs_stack "$ign/stacks" i1
  printf 'stacks/\n' > "$ign/.gitignore"; printf 'x\n' > "$ign/README"
  _xs_commit "$ign" i1 || { bad "external roots: could not commit the ignored-root fixture"; return 0; }
  "$kit/install.sh" fx-ext "$t8" --stacks "$ign/stacks" >/dev/null 2>&1 || { bad "external roots: ignored-root install failed"; return 0; }
  grep -qx 'stack_version: unversioned' "$t8/.synced-from" \
    || bad "external roots: a stacks root its repo ignores was stamped as versioned"
  printf 'RULE i2\n' > "$ign/stacks/fx-ext/conventions/backend/fx-rule.md"
  out=$("$kit/install.sh" fx-ext "$t8" --stacks "$ign/stacks" 2>&1) || bad "external roots: ignored-root reinstall failed"
  grep -q 'nothing to do' <<<"$out" && bad "external roots: a reinstall from an ignored stacks root was skipped"
  grep -qx 'RULE i2' "$t8/.agent-kit/common/conventions/backend/fx-rule.md" 2>/dev/null \
    || bad "external roots: an edit in an ignored stacks root was not installed"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "external stack roots (installs · duplicate refused · refresh by the stacks repo's history · stack switch · old stamp · layout move · root change · dirty root · ignored root)"
}

# ── variant families: one axis, several values — in a stack layer AND in the neutral kit ─────
# A VARIANT FAMILY is <concern>-<value>.md at depth-1 of a globbed dir — one doc in several versions,
# so consumers differing on one axis are served without forking anything to vary one doc. Nothing
# mechanical selects it: the value of frameworks.<key> in .agent-kit-local/structure.yml IS the
# filename suffix, and the SKILL PROSE is the whole mechanism. So every failure here is silent — a
# mirror that loses the rule reads every value's rules on that harness, a variant that stops being
# delivered loads none, and the code still compiles either way.
# ⚠ The undeclared case is the one that matters most: structure.yml is project-owned and install never
# writes it, so EVERY consumer starts with no key declared. A skill that guessed a default there
# would hand an Oracle project MongoDB rules, or a Vue project React ones, and say nothing.
# ⚠ TWO SCOPES, one mechanism. A family lives either in a stack's conventions/<layer>/ (filled per
# stack, installed under conventions/) or in a neutral common/.agent-kit/<dir>/ that ships to EVERY
# stack beside an always-read core.md. The second is the one that bit: that dir was globbed whole, so
# every framework's standard loaded on every stack at once — most wrong for the project, and
# contradicting each other. `scope` derives the paths; nothing else about the two differs.
# ⚠ PARAMETERISED over the family, never duplicated per family: two checks that must agree but are
# written separately drift, and the second always becomes the weaker one. A further family is one row
# in FAMILIES. WHICH values exist is never hardcoded — the fixtures are synthetic on purpose, so a
# family of three real files passes exactly as one of four would.
# ⚠ Runs against a FIXTURE kit staged in the gitignored sandbox — synthetic variants go into that copy
# of common/ and stacks/, never under the real ones, which ship to every consumer.

# scope → where a family's variants are staged (vsrc), where its unsuffixed peer comes from (psrc),
# where both must ARRIVE in a target (dst), that peer's filename (plain), whether the peer is a
# fixture to stage or a real shipped doc (stage_plain), and the string every globbing skill must name
# so its selection prose is provably about THIS family and not the other one on the same key (anchor).
# Assigns into the caller's locals (bash dynamic scope): the staging loop and the assertion loop then
# derive their paths from one place instead of carrying a `case` each.
_family_paths() {
  case "$1" in
    stack)  vsrc="stacks/generic/conventions/$2"; psrc="stacks/jakarta-ee/conventions/$2"
            dst=".agent-kit/common/conventions/$2"; plain="$3.md"; stage_plain=1
            anchor="conventions/$2/" ;;
    common) vsrc="common/.agent-kit/$2";           psrc="common/.agent-kit/$2"
            dst=".agent-kit/$2";                   plain="core.md"; stage_plain=0
            anchor=".agent-kit/$2/core.md" ;;
    *)      bad "variant families: unknown scope '$1' — a FAMILIES row names a scope _family_paths cannot resolve"; return 1 ;;
  esac
}

convention_variants() {
  local kit="$OUT/cvkit" a="$OUT/cv-declared" b="$OUT/cv-nomanifest" c="$OUT/cv-plain"
  local before=$fail item h skill f v family scope dir concern key picked other skills got want
  local vsrc psrc dst plain stage_plain anchor fam reviewers
  rm -rf "$kit" "$a" "$b" "$c"; mkdir -p "$kit" "$a" "$b" "$c"
  for item in install.sh README.md LICENSE NOTICE .gitignore common stacks; do
    [ -e "$SRC/$item" ] || { bad "variant families: kit source '$item' is missing — this check needs updating"; return 0; }
    cp -R "$SRC/$item" "$kit/$item" || { bad "variant families: could not stage a kit copy ($item)"; return 0; }
  done

  # scope | dir | concern | frameworks.<key> | declared | non-selected | skills globbing that dir | Claude
  # code reviewers (<name>-code-reviewer) that read it. The Codex reviewer is generated, so it has no prose to check.
  # ⚠ Two rows share the key `frontend` on purpose, and two share `database`: the neutral standard and
  # the stack's own layer are two families selected by ONE declared value, in two directories,
  # resolved independently.
  # ⚠ The skill lists are ENUMERATED, mirroring the Makefile's SKILL_NAMES_VALIDATE and for the same
  # reason: in a consumer .claude/skills/ also holds personal and project-owned skills, so a glob would
  # assert the kit's rule against skills the kit has no say in.
  local -a FAMILIES=(
    "stack|backend|persistence|database|oracle|mongodb|backend fullstack scaffold|backend fullstack"
    "stack|frontend|framework|frontend|vue|solid|frontend fullstack ui-design|frontend fullstack"
    "common|frontend|framework|frontend|vue|solid|frontend fullstack ui-design|frontend fullstack"
    "common|persistence|persistence|database|oracle|mongodb|backend fullstack scaffold|backend fullstack"
  )

  # `generic` ships no stack family, so the only variants in that install are these fixtures;
  # the fixture kit's `jakarta-ee` copy gets the plain unsuffixed doc (a public stack, so the check holds
  # wherever the private ones are absent; its real persistence-<db>.md files are the "set beside it" the
  # (e) case compares; on the frontend row that set is empty, since no public stack ships a frontend
  # layer — the row still proves the plain framework.md arrives intact). A neutral family needs nothing staged per stack — common/ reaches every target —
  # and its unsuffixed peer is the real core.md, never a fixture.
  for family in "${FAMILIES[@]}"; do
    IFS='|' read -r scope dir concern key picked other skills <<<"$family"
    _family_paths "$scope" "$dir" "$concern" || return 0
    printf '%s VARIANT\n' "$picked" > "$kit/$vsrc/$concern-$picked.md"
    printf '%s VARIANT\n' "$other"  > "$kit/$vsrc/$concern-$other.md"
    if [ "$stage_plain" = 1 ]; then
      mkdir -p "$kit/$psrc"   # jakarta-ee ships no conventions/frontend/ — only the fixture copy gets one
      printf 'PLAIN %s\n' "$concern" > "$kit/$psrc/$plain"
    fi
  done

  "$kit/install.sh" generic "$a" >/dev/null 2>&1 || { bad "variant families: install failed"; return 0; }
  # (d) needs a second, manifest-free target; (e) a stack with a plain doc. Installed once, asserted per family.
  "$kit/install.sh" generic "$b" >/dev/null 2>&1 || { bad "variant families: install (no manifest) failed"; return 0; }
  "$kit/install.sh" jakarta-ee "$c" >/dev/null 2>&1 || { bad "variant families: install (plain) failed"; return 0; }

  # One manifest declares EVERY family's key — a consumer has one structure.yml, and the families
  # resolve independently from it. Written from FAMILIES so the declared value cannot drift from the
  # fixture filename it must select. `sort -u` because two families legitimately share a key: one YAML
  # line selecting in two directories. Two rows disagreeing on the value would emit both lines and
  # fail (c) loudly, rather than one silently winning.
  mkdir -p "$a/.agent-kit-local"
  { printf 'frameworks:\n  backend: fixture\n'
    for family in "${FAMILIES[@]}"; do
      IFS='|' read -r scope dir concern key picked other skills <<<"$family"
      printf '  %s: %s\n' "$key" "$picked"
    done | sort -u
  } > "$a/.agent-kit-local/structure.yml"

  # install writes no structure.yml: it is project-owned, and undeclared must stay the initial state.
  if [ -e "$b/.agent-kit-local/structure.yml" ]; then
    bad "variant families: install wrote structure.yml — it is project-owned, and undeclared must stay the initial state"
  fi

  for family in "${FAMILIES[@]}"; do
    IFS='|' read -r scope dir concern key picked other skills reviewers <<<"$family"
    _family_paths "$scope" "$dir" "$concern" || return 0
    fam="$concern-<value> in $dst"

    # (a2) the Claude code reviewers that read the family's dirs carry the same selection rule.
    for skill in $reviewers; do
      f="$a/.claude/agents/$skill-code-reviewer.md"
      [ -f "$f" ] || { bad "variant families ($fam): .claude/agents/$skill-code-reviewer.md is missing"; continue; }
      grep -q "frameworks.$key" "$f" \
        || bad "variant families ($fam): $skill-code-reviewer names no frameworks.$key — it cannot select a variant"
      grep -q "$concern-" "$f" \
        || bad "variant families ($fam): $skill-code-reviewer does not name the $concern-<value> filename contract"
      grep -qF "$anchor" "$f" \
        || bad "variant families ($fam): $skill-code-reviewer never names $anchor — its selection rule cannot be about this family"
      grep -qi 'undeclared' "$f" \
        || bad "variant families ($fam): $skill-code-reviewer covers no UNDECLARED case"
    done

    # (a) every skill that globs the family's dir must carry the rule, in BOTH mirrors. Selection
    #     happens in prose, so a mirror missing any one part fails differently: no key = cannot
    #     select, no filename contract = cannot derive the name, no undeclared case = the initial
    #     state is unhandled, no /structure-extract pointer = the undeclared consumer is never told
    #     how to stop being undeclared, and no anchor = the rule may be there while being about the
    #     OTHER family on this key, which is exactly how a whole-directory glob survived beside it.
    for h in claude codex; do
      for skill in $skills; do
        f="$a/.$h/skills/$skill/SKILL.md"
        [ -f "$f" ] || { bad "variant families ($fam): .$h/skills/$skill/SKILL.md is missing"; continue; }
        grep -q "frameworks.$key" "$f" \
          || bad "variant families ($fam): .$h/skills/$skill names no frameworks.$key — it cannot select a variant"
        grep -q "$concern-" "$f" \
          || bad "variant families ($fam): .$h/skills/$skill does not name the $concern-<value> filename contract"
        grep -qF "$anchor" "$f" \
          || bad "variant families ($fam): .$h/skills/$skill never names $anchor — its selection rule cannot be about this family"
        grep -qi 'undeclared' "$f" \
          || bad "variant families ($fam): .$h/skills/$skill covers no UNDECLARED case — that is the initial state of every consumer"
        grep -q 'structure-extract' "$f" \
          || bad "variant families ($fam): .$h/skills/$skill does not point an undeclared project at /structure-extract"
      done
    done

    # (b) the manifest a consumer fills must offer the key at all — /structure-extract writes it, but
    #     the template is what a human copying by hand reads. Scoped to the frameworks: block, since
    #     `frontend:` is also a layers: key and matching that one would prove nothing.
    sed -n '/^frameworks:/,/^[^[:space:]#]/p' "$a/.agent-kit/structure.template.yml" \
      | grep -qE "^[[:space:]]+$key:" \
      || bad "variant families ($fam): structure.template.yml declares no frameworks.$key — a consumer has nothing to fill in"

    # (c) a consumer that DECLARES one resolves it the way a skill must: suffix = the declared value,
    #     read back out of the manifest (frameworks: block only) rather than hardcoded here.
    v=$(sed -n '/^frameworks:/,/^[^[:space:]#]/p' "$a/.agent-kit-local/structure.yml" \
        | sed -n "s/^[[:space:]]*$key:[[:space:]]*//p")
    [ "$v" = "$picked" ] || bad "variant families ($fam): frameworks.$key did not read back from the manifest"
    grep -q "^$picked VARIANT" "$a/$dst/$concern-$v.md" 2>/dev/null \
      || bad "variant families ($fam): the declared $key does not resolve to a delivered $concern-$v.md"
    # Selection is READ-TIME. Install must deliver every variant — filtering at install would freeze
    # the choice into the tree and make changing it a reinstall.
    grep -q "^$other VARIANT" "$a/$dst/$concern-$other.md" 2>/dev/null \
      || bad "variant families ($fam): a non-selected variant was not delivered — selection must be read-time, not install-time"

    # (d) a consumer with NO manifest is not broken by a family: every file is there for the
    #     read-them-all fallback.
    for v in "$picked" "$other"; do
      grep -q 'VARIANT' "$b/$dst/$concern-$v.md" 2>/dev/null \
        || bad "variant families ($fam): $concern-$v.md missing from a consumer with no manifest — the fallback has nothing to read"
    done

    # (e) the unsuffixed peer beside the variants is untouched by any of this — the stack's plain
    #     <concern>.md, or the neutral dir's always-read core.md. It carries no selector, so no
    #     selection rule may hide it: it arrives byte-identical, and the variant set around it is
    #     exactly what the source holds — install invents none and drops none.
    cmp -s "$kit/$psrc/$plain" "$c/$dst/$plain" \
      || bad "variant families ($fam): the unsuffixed $plain beside the variants was not delivered intact"
    # `find`, not `ls <glob>`: an unmatched glob makes ls exit non-zero, which under `set -o pipefail`
    # fails the whole assignment and aborts the script instead of reporting an empty set.
    want=$(find "$kit/$psrc" -maxdepth 1 -name "$concern-*.md" | sed 's|.*/||' | sort | tr '\n' ' ')
    got=$(find "$c/$dst"     -maxdepth 1 -name "$concern-*.md" | sed 's|.*/||' | sort | tr '\n' ' ')
    [ "$want" = "$got" ] \
      || bad "variant families ($fam): the $concern-<value> set beside $plain is '$got', not the source's '$want'"
  done

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "variant families: persistence-<db> in BOTH conventions/backend/ and the neutral .agent-kit/persistence/ + framework-<name> in BOTH conventions/frontend/ and the neutral .agent-kit/frontend/ (all delivered · declared value resolves to a file · no manifest still works · the unsuffixed peer is untouched · every globbing skill carries the rule, anchored to its own directory)"
}

# ── the neutral backend layer: read everywhere it must be, and free of any one language ─────────
# .agent-kit/backend/ is CORE-ONLY — no variants, no frameworks.* selector, the shape of messaging/ dcr/
# migration/ — so convention_variants has no selection rule to prove, and check()'s cmp walk already
# proves delivery. What neither covers is the two things a core-only layer depends on:
#  (a) WIRING. Every reader is prose telling a model to glob the directory. A skill mirror or reviewer
#      that loses the sentence reads no neutral backend rules on that harness, nothing fails, and the
#      stack docs — which now point at the core instead of restating it — are left half-explained.
#  (b) NEUTRALITY. The layer ships to the generic stack, where the projects are Go, Python and Node. A
#      Java type, a logging facade or a test annotation in it is a wrong instruction there with no stack
#      doc to correct it, and one stack's rule leaking into the neutral layer is exactly what its
#      admission rule exists to stop. Checked on the SOURCE tree: every install gets it byte-identical.
# ⚠ Three kinds of pattern, split on purpose. Unambiguous framework, tool and platform names are matched
# bare and case-insensitively. A few words are ALSO English — `record`, `Optional`, `synchronized` ("kept
# synchronized", "Optional. …", "records the value") — so only their backticked, code-formatted form is
# matched; a bare use of one of those is not caught, which is the price of not failing on prose. `\bspring\b`
# is word-bounded so "offspring" passes. This is a tripwire for the usual leaks, not proof of neutrality.
backend_core_is_neutral_and_wired() {
  local before=$fail dir="$SRC/common/.agent-kit/backend" f h skill name hits nl=$'\n' b sd root
  local -a home
  [ -f "$dir/core.md" ] || { bad "backend core: $dir/core.md is missing — the neutral half of /backend"; return 0; }

  # (a) both mirrors of every skill that reads the layer, and both Claude reviewers, name the directory.
  for h in claude codex; do
    for skill in backend fullstack scaffold; do
      f="$SRC/common/.$h/skills/$skill/SKILL.md"
      [ -f "$f" ] || { bad "backend core: .$h/skills/$skill/SKILL.md is missing"; continue; }
      grep -qF '.agent-kit/backend/' "$f" \
        || bad "backend core: .$h/skills/$skill never names .agent-kit/backend/ — it would not read the neutral backend rules"
    done
  done
  for name in backend fullstack; do
    f="$SRC/common/.claude/agents/$name-code-reviewer.md"
    [ -f "$f" ] || { bad "backend core: .claude/agents/$name-code-reviewer.md is missing"; continue; }
    grep -qF '.agent-kit/backend/' "$f" \
      || bad "backend core: $name-code-reviewer never names .agent-kit/backend/ — it would review against none of the neutral rules"
  done
  # The Codex reviewer is generated, so its prose cannot drift — its INPUT list can: the Makefile must glob
  # the directory, and the header's generated-from note must say so.
  grep -qF 'wildcard $(BACK)/*.md' "$SRC/common/.codex/Makefile" \
    || bad "backend core: the Makefile's CODE_REVIEWER_DOCS does not glob \$(BACK)/*.md — the Codex reviewer would not inline it"
  grep -qF '.agent-kit/backend/' "$SRC/common/.agent-kit/common/process/reference/code-reviewer-agent-header.md" \
    || bad "backend core: the code-reviewer header's generated-from note omits .agent-kit/backend/"
  # Each stack was trimmed on the strength of the neutral layer, so each must still point at every file in
  # it. Scoped to the stacks that ship a real backend layer (a code-style.md — the generic placeholder has
  # none). core.md is pinned to code-style.md, its topic; any other file may be named by whichever
  # depth-1 conventions/backend/*.md holds ITS topic (one stack keeps logging inside code-style.md, the
  # four JVM app stacks keep the failure-path rules in patterns.md). Pairing is by topic, not filename, so
  # "a stack that speaks to the topic" is approximated by "a stack with a backend layer"; a stack silent on a
  # topic still names the file, where the pointer costs one line.
  # ⚠ The match is a plain substring, so any mention of the file passes — it is not proof of a "Read together with" pointer.
  for root in "${STACK_ROOTS[@]}"; do
   for f in "$root"/*/conventions/backend/code-style.md; do
    [ -f "$f" ] || continue
    sd="${f%/code-style.md}"
    for b in "$dir"/*.md; do
      [ -f "$b" ] || continue
      name="$(basename "$b")"
      if [ "$name" = core.md ]; then home=("$f"); else home=("$sd"/*.md); fi
      grep -qF ".agent-kit/backend/$name" "${home[@]}" \
        || bad "backend core: stacks/${sd#$root/} names no .agent-kit/backend/$name — add a pointer to .agent-kit/backend/$name in this stack's backend docs (code-style.md for core.md; the doc holding that topic otherwise)"
    done
   done
  done
  # Every neutral file must keep saying the stack wins: the Codex reviewer inlines them beside the stack
  # docs, and without that sentence a neutral rule would outrank the stack's own.
  for b in "$dir"/*.md; do
    [ -f "$b" ] || continue
    grep -qE 'wins where they differ' "$b" \
      || bad "backend core: ${b#$SRC/common/} no longer says the stack's docs win where they differ"
  done

  # (b) no JVM, framework, logging, test or concurrency vocabulary anywhere under the directory.
  hits=$(grep -rnoEi '(\bjava\b|\bjvm\b|\bjdk\b|jakarta|quarkus|\bspring\b|lombok|mapstruct|jackson|panache|hibernate|slf4j|logback|log4j|\bSystem\.(out|err)\b|junit|mockito|\bcdi\b|jax-rs|javadoc|\bpojo\b|\bmvn\b|maven|gradle|kotlin|micronaut|guice|pom\.xml|virtual thread|reentrantlock|threadlocal)' \
           "$dir" 2>/dev/null || true)
  hits="${hits:+$hits$nl}$(grep -rnoE '(`(records?|Optional|synchronized)`|\bMDC\b|@[A-Z][A-Za-z0-9]+|List\.of|Set\.of|Map\.of|ArrayList|Stream API|[A-Za-z]Tests\b|\*Tests?\b|\.java\b)' \
           "$dir" 2>/dev/null || true)"
  [ -z "$hits" ] || bad "backend core: language- or framework-specific text in the neutral backend layer →$(echo " $hits" | sed "s|$SRC/common/||g" | tr '\n' ' ')"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "backend core: every reader (3 skills × 2 mirrors, 2 reviewers, the Codex reviewer's inputs, each stack's backend docs) names the neutral layer · the layer holds none of the JVM, framework, logging, test or concurrency terms it lists"
}

# ── Decision add-ons (RFC-003 P5) ───────────────────────────────────────────────────────────────────
# The core meets any decision add-on only through `.agent-kit/common/process/planning/decision-addon.md`.
# decision_hook_is_wired is CORE: it guards the core's own wiring, and holds with no add-on installed.
# A decision add-on's own checks live in the overlay, against the add-on's tree.
decision_hook_is_wired() {
  local before=$fail c="$SRC/common" f h skill
  [ -f "$c/.agent-kit/common/process/planning/decision-addon.md" ] \
    || bad "decision hook: process/planning/decision-addon.md is missing"
  grep -qF '.agent-kit/decision-addon.manifest.md' "$c/.agent-kit/common/process/planning/decision-addon.md" 2>/dev/null \
    || bad "decision hook: decision-addon.md no longer names the manifest path — nothing says how an add-on is found"
  # the core docs that meet a decision point, or its record, must still point at the hook
  for f in .agent-kit/common/process/planning/execution-loop.md .agent-kit/common/process/planning/plan-shaping.md \
           .agent-kit/common/process/planning/workflow.md .agent-kit/planning/TEMPLATE.md; do
    grep -qF 'decision-addon.md' "$c/$f" 2>/dev/null \
      || bad "decision hook: $f no longer points at decision-addon.md — its add-on fallback is gone"
  done
  for h in claude codex; do
    for skill in feature-plan feature-execute; do
      f="$c/.$h/skills/$skill/SKILL.md"
      grep -qF '.agent-kit/decision-addon.manifest.md' "$f" 2>/dev/null \
        && grep -qF '.agent-kit/common/process/planning/decision-addon.md' "$f" \
        && grep -qF 'also the contract it names' "$f" \
        || bad "decision hook: .$h/skills/$skill does not read the manifest, the hook and the contract it names — an installed add-on would never be found, or never followed"
    done
  done
  [ "$fail" -eq "$before" ] || return 0
  note "✓" "decision hook: present, and both planning skills read the manifest, the hook and the contract it names, in both mirrors"
}

# Takes the top-level dirs to check (names relative to $SRC): the core passes its own, and an overlay
# hook calls it again with the ones it adds.
ships_only_what_is_tracked() {
  local before=$fail stray d lbl=""
  local -a paths=()
  [ $# -gt 0 ] || { bad "ships_only_what_is_tracked: no dirs given"; return 0; }
  for d in "$@"; do lbl="${lbl:+$lbl, }$d/"; paths+=("$SRC/$d"); done
  stray=$(git -C "$SRC" ls-files --others --exclude-standard -- "$@")
  [ -z "$stray" ] || bad "untracked files under $lbl install invisibly: $(echo $stray)"
  stray=$(find "${paths[@]}" -type d -empty 2>/dev/null | sed "s|$SRC/||")
  [ -z "$stray" ] || bad "empty dirs under $lbl cannot be tracked: $(echo $stray)"
  [ "$fail" -eq "$before" ] || return 0; note "✓" "$lbl contain only tracked content"
}

# ── the kit's own root must stay uninstalled ─────────────────────────────────────────────────
# The kit used to install the generic stack at its own root for harness parity during meta-dev. That
# put a COPY of every shared doc beside its source and gave every session two entrypoints — a tracked
# meta-dev CLAUDE.md AND a seeded consumer one, whose Tier-0 was the generic stack's empty templates.
# The self-install is gone; the two hand-written entrypoints (.claude/CLAUDE.md, .codex/AGENTS.md) are
# the only agent files here. Assert it stays that way, because `./install.sh generic .` reinstates the
# whole problem in one command; what it writes is gitignored, and only the overwritten tracked
# .codex/AGENTS.md would show as a diff.
root_stays_uninstalled() {
  local stray
  # ⚠ In THIS repo .claude/ and .codex/ are not install output at all — they hold exactly one
  # hand-written, tracked entrypoint each (.claude/CLAUDE.md, .codex/AGENTS.md) and nothing else. So the
  # paths listed below are the SUBDIRECTORIES only a self-install would create (skills/, agents/), never
  # the directories themselves and never the two entrypoints. Same filenames as a consumer's, opposite
  # rules — see CONTRIBUTING → "Working on the kit — guardrails". Cursor and VS Code have no such
  # split — their generated file sits in a directory a maintainer may also want (CI in .github/, their
  # own editor settings in .vscode/, their own rules in .cursor/). So for those two, match on the
  # generator's MARKER rather than on a path: a hand-written file never carries it, and every generated
  # one does (install.sh uses the same marker to decide whether a copilot-instructions.md is its own).
  # ⚠ Never list .vscode/settings.json or a bare .cursor/ here — both are things a maintainer owns.
  stray=$(cd "$SRC" && ls -d .agent-kit .claude/skills .claude/agents .codex/skills .codex/agents \
            .agent-kit-local/context .synced-from 2>/dev/null || true)
  # Two markers: AGENTS.md and the Cursor rule carry "Generated from .agent-kit/"; copilot-instructions.md
  # carries only the header line the Makefile's sync-copilot-instructions writes.
  generated=$(cd "$SRC" && grep -lE 'Generated from \.agent-kit/|GENERATED by `make -C \.codex sync-agents`' \
            .github/copilot-instructions.md .cursor/rules/*.mdc .codex/AGENTS.md 2>/dev/null || true)
  stray=$(printf '%s\n%s\n' "$stray" "$generated" | grep -v '^$' || true)
  [ -z "$stray" ] && { note "✓" "kit root is not self-installed (one entrypoint per harness, no copy of common/)"; return 0; }
  bad "kit root has install output →$(echo " $stray" | tr '\n' ' ')— this repo must not install itself; remove it (CONTRIBUTING → Working on the kit)"
}

# ── shipped docs may not name files that don't exist ─────────────────────────────────────────
# A renamed function breaks the build; a renamed *concept* breaks nothing and ships. This kit hit
# that six times in one feature: docs promising templates nobody wrote, a README listing files that
# did not exist, a template pointing at a path the design had just deleted. Every one installed to
# every consumer, and nothing caught them — verify.sh checks that files exist and copies match, not
# that prose still describes reality.
#
# Two mechanical halves of that, both cheap:
#   1. a backticked `.agent-kit/…` path in a shipped doc must resolve
#   2. a file listed in an `.agent-kit/**/README.md` tree block must exist beside it
# Scoped to `.agent-kit/` minus `common/conventions/` — conventions are stack-filled, so a doc may
# legitimately name one a given stack doesn't provide. Semantic contradictions ("benchmarks live
# here" vs "there") remain out of reach; this catches the half that is decidable.
docs_name_real_files() {
  local before=$fail dir="$1" label="$2"
  local bad
  bad=$(cd "$dir" && python3 -c '
import re, os, glob, sys
# The trailing "|/" alternative matches a DIRECTORY reference. Since process/ gained its companion
# dirs, a glob target like `.agent-kit/common/process/authoring/` is the kit dominant reference form —
# ~30 of them replaced named files. Without this the most common reference in the kit went unchecked
# and renaming a companion dir would break every skill silently.
# "(?:-local)?" makes the *-local/ skip below reachable: without it those paths never match this
# pattern at all, and the guard reads as protection while doing nothing.
pat = re.compile(r"\`((?:\.agent-kit|\.user-kit)(?:-local)?/[A-Za-z0-9_./-]+(?:\.(?:md|json|yml|mjs|rules)|/[A-Z][A-Z0-9-]+|/))\`")
out = []
# agents/ included alongside skills/: the reviewers and test-runner name these paths too, and were
# the one tree nothing scanned.
for f in glob.glob(".agent-kit/**/*.md", recursive=True) + \
         glob.glob(".user-kit/**/*.md", recursive=True) + \
         glob.glob(".claude/skills/**/*.md", recursive=True) + \
         glob.glob(".codex/skills/**/*.md", recursive=True) + \
         glob.glob(".claude/agents/**/*.md", recursive=True) + \
         glob.glob(".codex/agents/**/*.md", recursive=True):
    for n, line in enumerate(open(f, errors="replace"), 1):
        for m in pat.finditer(line):
            p = m.group(1)
            if p.startswith(".agent-kit/common/conventions/"):
                continue
            # project-OWNED trees: legitimately absent on a fresh install, never the kit to supply.
            if p.startswith((".agent-kit-local/", ".user-kit-local/")):
                continue
            # the manifest of a decision add-on: the core names it to FIND one, so it is absent wherever
            # no add-on is installed (decision-addon.md, "when it exists"). No apostrophes in this block.
            if p == ".agent-kit/decision-addon.manifest.md":
                continue
            if not os.path.exists(p):
                out.append(f"{f}:{n} names {p}")
for readme in glob.glob(".agent-kit/**/README.md", recursive=True) + \
                glob.glob(".user-kit/**/README.md", recursive=True):
    d, fenced, shipped = os.path.dirname(readme), False, True
    for n, line in enumerate(open(readme, errors="replace"), 1):
        if line.startswith("```"):
            fenced = not fenced; shipped = True; continue
        if not fenced:
            continue
        # A tree block may draw several roots. Only the shipped one is checkable: an
        # .agent-kit-local/ root is project-owned and legitimately absent at install time.
        if line[:1] not in " ├└│\n":
            shipped = not line.startswith((".agent-kit-local", ".user-kit-local"))
            continue
        if not shipped:
            continue
        m = re.search(r"[├└]──\s+([A-Za-z0-9_.-]+\.[A-Za-z0-9]{1,6}|[A-Z][A-Z0-9-]{3,})(?!/)\s", line)
        if m and not glob.glob(os.path.join(d, "**", m.group(1)), recursive=True):
            out.append(f"{readme}:{n} lists {m.group(1)}, absent under {d}/")
print("\n".join(out))
')
  [ -z "$bad" ] || bad "$label: shipped docs name files that do not exist — $(echo $bad)"

  # The kit's own front-door docs. They live in the source, not in an install, so they are read from $SRC:
  # README.md, CONTRIBUTING.md and docs/**. Three things in them must resolve, because a renamed file, heading
  # or flag breaks nothing and ships:
  #   1. a backticked path rooted at common/ stacks/ docs/ tests/ verify.d/ addons/ — or an .agent-kit/ path,
  #      which means common/.agent-kit/ here (the flattened copy exists only in an install)
  #   2. a markdown link: its file, and its #anchor against the target headings (GitHub slugs)
  #   3. a backticked --flag, which must appear in install.sh, verify.sh or something under common/
  # Fenced blocks are skipped (commands and trees). Placeholders (<x>, *, {a,b}) are skipped, not guessed.
  # No apostrophes in this block: it sits inside a single-quoted python -c.
  local badkit
  badkit=$(cd "$SRC" && python3 -c '
import re, os, glob
docs = [f for f in ("README.md", "CONTRIBUTING.md") if os.path.exists(f)] + sorted(glob.glob("docs/**/*.md", recursive=True))
corpus = ""
for f in ("install.sh", "verify.sh"):
    corpus += open(f, errors="replace").read()
for dp, dn, fns in os.walk("common"):
    for fn in fns:
        if fn.endswith((".md", ".sh", ".mjs", ".py", ".yml", ".json", ".rules", ".toml")):
            corpus += open(os.path.join(dp, fn), errors="replace").read()
installed = {".agent-kit/LICENSE": "LICENSE", ".agent-kit/NOTICE": "NOTICE"}
rooted = re.compile(r"^(common|stacks|docs|tests|verify\.d|addons)/[A-Za-z0-9_./-]+$")
kitpath = re.compile(r"^\.agent-kit/[A-Za-z0-9_./-]*$")
_slugs = {}
def slugs(doc):
    if doc in _slugs:
        return _slugs[doc]
    seen, out, fenced = {}, set(), False
    for line in open(doc, errors="replace"):
        if line.startswith("```"):
            fenced = not fenced
            continue
        m = None if fenced else re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
        if not m:
            continue
        s = re.sub(r"[^\w\- ]", "", m.group(1).replace("`", "").lower()).replace(" ", "-")
        n = seen.get(s, 0)
        seen[s] = n + 1
        out.add(s if n == 0 else "%s-%d" % (s, n))
    _slugs[doc] = out
    return out
out = []
for doc in docs:
    fenced = False
    for n, line in enumerate(open(doc, errors="replace"), 1):
        if line.startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        for tok in re.findall(r"`([^`]+)`", line):
            if tok.startswith("--"):
                flag = tok.split()[0].rstrip(",.;:")
                if re.match(r"^--[a-z][a-z-]*$", flag) and not re.search(r"(?<![\w-])" + re.escape(flag) + r"(?![\w-])", corpus):
                    out.append("%s:%d names flag %s" % (doc, n, flag))
                continue
            if tok in installed:
                if not os.path.exists(installed[tok]):
                    out.append("%s:%d names %s, but the source %s is missing" % (doc, n, tok, installed[tok]))
                continue
            p = None
            if rooted.match(tok):
                p = tok
            elif kitpath.match(tok) and not tok.startswith(".agent-kit/common/conventions/") \
                    and tok != ".agent-kit/decision-addon.manifest.md":
                p = "common/" + tok
            if p and not os.path.exists(p.rstrip("/")):
                out.append("%s:%d names %s" % (doc, n, tok))
        for tgt in re.findall(r"\]\(([^)\s]+)\)", line):
            if re.match(r"^(https?:|mailto:)", tgt):
                continue
            path, _, anchor = tgt.partition("#")
            dest = os.path.normpath(os.path.join(os.path.dirname(doc), path)) if path else doc
            if not os.path.exists(dest):
                out.append("%s:%d links to %s, which is absent" % (doc, n, tgt))
            elif anchor and dest.endswith(".md") and anchor not in slugs(dest):
                out.append("%s:%d links to %s, but %s has no such heading" % (doc, n, tgt, dest))
print("\n".join(out))
')
  [ -z "$badkit" ] || bad "$label: README.md, CONTRIBUTING.md or docs/ name a path, link, heading or flag that does not resolve — $(echo "$badkit" | tr '\n' ' ')"

  # An install carries the license and the credits, byte-for-byte what the kit holds. (Skipped when the
  # fixture was not installed: a run narrowed to one non-generic stack never installs it.)
  local f
  if [ -d "$dir/.agent-kit" ]; then
    for f in LICENSE NOTICE; do
      cmp -s "$SRC/$f" "$dir/.agent-kit/$f" || bad "$label: the install lacks .agent-kit/$f, or its copy differs from the kit's $f"
    done
  fi
  [ "$fail" -eq "$before" ] || return 0; note "✓" "$label"
}



# ── --reset-defaults blast radius ────────────────────────────────────────────────────────────
# --reset-defaults REPLACES every seed with no drift check — documented and intended. What it must
# NEVER reach is project-OWNED content: .agent-kit-local/{planning,structure.yml} and every module
# dir the stack does not declare hold the consumer's roadmap, plans, decisions and own module memory,
# none of which the kit can regenerate. (A module dir the stack DOES declare is a seed and is
# replaced — that half is gated in stack_module_seeds, against a stack that actually declares one.)
# The main loop only runs --reset-defaults against FRESH targets, so that blast radius was untested;
# a regression would silently delete a consumer's entire backlog and look like a normal reinstall.
reset_defaults_scope() {
  local d="$OUT/reset" before=$fail f
  rm -rf "$d"; mkdir -p "$d"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "reset-defaults: initial install failed"; return 0; }
  mkdir -p "$d/.agent-kit-local/planning/features" "$d/.agent-kit-local/planning/decisions/adr" \
           "$d/.agent-kit-local/modules/web"
  printf 'OWNED roadmap\n'   > "$d/.agent-kit-local/planning/ROADMAP.md"
  printf 'OWNED feature\n'   > "$d/.agent-kit-local/planning/features/x.md"
  printf 'OWNED adr\n'       > "$d/.agent-kit-local/planning/decisions/adr/ADR-001-x.md"
  printf 'OWNED module\n'    > "$d/.agent-kit-local/modules/web/module.md"
  printf 'OWNED structure\n' > "$d/.agent-kit-local/structure.yml"
  printf 'EDITED\n'         >> "$d/.claude/CLAUDE.md"

  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 \
    || { bad "reset-defaults: plain reinstall failed"; return 0; }
  "$SRC/install.sh" generic "$d" --reset-defaults >/dev/null 2>&1 \
    || { bad "reset-defaults: rerun failed"; return 0; }

  for f in planning/ROADMAP.md planning/features/x.md planning/decisions/adr/ADR-001-x.md \
           modules/web/module.md structure.yml; do
    grep -q '^OWNED' "$d/.agent-kit-local/$f" 2>/dev/null \
      || bad "--reset-defaults DESTROYED project-owned .agent-kit-local/$f"
  done
  # The flip side: an edited SEED must be replaced — that is what the flag exists to do.
  cmp -s "$SRC/common/.claude/CLAUDE.md" "$d/.claude/CLAUDE.md" \
    || bad "--reset-defaults left an edited seed in place (.claude/CLAUDE.md)"
  [ "$fail" -eq "$before" ] || return 0
  note "✓" "--reset-defaults resets seeds, never project-owned .agent-kit-local/"
}


# ── plan-lint.mjs Complexity gate ────────────────────────────────────────────────────────────
# The Ready gate's item 7 and any cost add-on's unscored-phase list both read its rows; a parser drift drops or
# mis-ids phases silently. Hermetic (temp plans only), and it lints the shipped TEMPLATE.md too.
plan_lint_gate() {
  local before=$fail
  command -v node >/dev/null 2>&1 || { note "-" "plan-lint: node not installed — skipped"; return 0; }
  node "$SRC/tests/plan-lint.test.mjs" >"$OUT/plan-lint-test.log" 2>&1 \
    || bad "plan-lint.mjs: test failed — $(tr '\n' ' ' <"$OUT/plan-lint-test.log")"
  [ "$fail" -eq "$before" ] || return 0
  note "✓" "plan-lint.mjs finds every phase, scores it, and passes TEMPLATE.md"
}

# ── the parity gate's enumeration ────────────────────────────────────────────────────────────
# validate-skills names the kit's skills instead of globbing them, and that is deliberate: in a
# consumer .claude/skills/ also holds personal and project-authored skills, which the kit has no say
# over. The cost of enumerating is that the list silently falls behind — a skill added to common/ but
# not to SKILL_NAMES_VALIDATE simply goes unchecked, and nothing anywhere notices. That is how 9 of
# 16 kit skills ended up with no parity gate at all. So assert the list IS the shipped set.
parity_list_covers_kit_skills() {
  local before=$fail mk="$SRC/common/.codex/Makefile" listed shipped
  # awk, not a sed range: the range's end address [^\]$ cannot match an empty line, so a list that
  # ever collapses to ONE line runs on through the blank line into the next comment block and reports
  # '#' and 'AGENTS.md' as ungated skills. This tracks the backslash continuation explicitly instead.
  # `|| true` + the emptiness guard: under set -euo pipefail a `grep .` on empty input exits 1, and a
  # bare assignment from a failing pipeline ABORTS verify.sh — no ✗, no FAIL line, and every check
  # after this one silently skipped. A gate that can kill the harness is worse than no gate.
  listed=$(awk '
    /^SKILL_NAMES_VALIDATE[[:space:]]*=/ { f=1; sub(/^[^=]*=/, "") }
    f { cont = ($0 ~ /\\[[:space:]]*$/); gsub(/\\/, ""); print; if (!cont) exit }
  ' "$mk" | tr ' \t' '\n' | grep . | sort -u || true)
  shipped=$(for d in "$SRC/common/.claude/skills"/*/; do basename "$d"; done | sort -u)
  if [ -z "$listed" ]; then
    bad "could not read SKILL_NAMES_VALIDATE from the Makefile — the parity gate did not run"
  elif [ "$listed" != "$shipped" ]; then
    bad "validate-skills' SKILL_NAMES_VALIDATE != common/.claude/skills/ — ungated skills:$(
      echo; diff <(echo "$shipped") <(echo "$listed") | sed 's/^/           /')"
  fi
  # SKILL_NAMES_VALIDATE is not the only enumeration of the kit's skills — the sync-main-context printf
  # carries a second one, the skill-pointer list a cold Codex/Cursor session actually reads. A kit skill
  # missing from THAT list does not vanish: sync-addon-skills appends any skills/*/ it cannot find in
  # AGENTS.md under an "## Additional Skills" heading, so the skill ships to Codex and Cursor MISLABELLED,
  # silently, and every other gate stays green. Found by a fresh agent walking through "add /desktop".
  local missing=""
  for d in "$SRC/common/.codex/skills"/*/; do
    n=$(basename "$d")
    grep -q "skills/$n/SKILL.md" "$mk" || missing="$missing $n"
  done
  [ -z "$missing" ] || bad "kit skill(s) absent from the sync-main-context pointer list —$missing
           they would ship to Codex/Cursor appended under '## Additional Skills'"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "every kit skill is in BOTH Makefile enumerations (parity list + pointer list)"
}

# ── the parity gate's exclusion must be by DEPTH, not by directory ───────────────────────────
# process/ mirrors conventions/: depth-1 is the always-on Tier-0 set (@imported by Claude, so its
# skills need not name it — the one legitimate asymmetry), and every nested dir is a companion that
# BOTH mirrors must reference identically. Excluding all of process/ instead would silently drop
# authoring/ and review/ from the comparison while the gate kept reporting OK.
parity_excludes_only_tier0_process_docs() {
  local before=$fail d="$OUT/parity" out missing
  rm -rf "$d"; mkdir -p "$d"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "parity filter: install failed"; return 0; }

  # (a) real drift on a NESTED process companion must FAIL.
  if grep -q 'process/authoring/' "$d/.codex/skills/backend/SKILL.md"; then
    sed 's|\.agent-kit/common/process/authoring/|REMOVED-BY-VERIFY/|g' \
      "$d/.codex/skills/backend/SKILL.md" > "$d/.be.tmp" && mv "$d/.be.tmp" "$d/.codex/skills/backend/SKILL.md"
    # Assert it failed FOR THE RIGHT REASON — a Makefile syntax error or a missing skill also exits
    # non-zero and would otherwise read as "the gate works".
    if out=$(make -C "$d/.codex" validate-skills 2>&1); then
      bad "parity filter: drift on a nested process companion (authoring/) is invisible to validate-skills"
    elif ! grep -q "DRIFT in 'backend'" <<<"$out"; then
      bad "parity filter: validate-skills failed, but not with the expected backend DRIFT — $(head -2 <<<"$out")"
    fi
    "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1
  else
    bad "parity filter: backend skill no longer references process/authoring/ — this check needs a new anchor"
  fi

  # (b) the legitimate depth-1 Tier-0 asymmetry must still pass.
  out=$(make -C "$d/.codex" validate-skills 2>&1) \
    || bad "parity filter: the depth-1 Tier-0 process docs are no longer excluded — $out"

  # (c) every companion dir must actually hold something — an empty one means a skill globs nothing
  #     and the doc budget silently stops being applied.
  for sub in authoring review; do
    [ -n "$(ls "$d/.agent-kit/common/process/$sub"/*.md 2>/dev/null)" ] \
      || bad "parity filter: process/$sub/ is empty — skills glob it and would load nothing"

    # …and the GENERATOR must refuse too, not just this check. A wildcard over an emptied dir expands
    # to nothing, so the cat loop's `|| exit 1` never runs and a reviewer with no checklist regenerates
    # with exit 0 — silent in the one place a consumer would never look.
    mv "$d/.agent-kit/common/process/$sub" "$d/.agent-kit/common/process/$sub.hidden"
    mkdir -p "$d/.agent-kit/common/process/$sub"
    if make -C "$d/.codex" sync-code-reviewer-agent >/dev/null 2>&1; then
      bad "generator: an empty process/$sub/ still produced a code-reviewer — it would ship with no checklist"
    fi
    rm -rf "$d/.agent-kit/common/process/$sub"
    mv "$d/.agent-kit/common/process/$sub.hidden" "$d/.agent-kit/common/process/$sub"
  done
  make -C "$d/.codex" sync-code-reviewer-agent >/dev/null 2>&1 \
    || bad "generator: sync-code-reviewer-agent fails on a healthy tree — the new guard is over-strict"

  # (c2) process/diagrams/ is skill-only: no reviewer judges diagrams, so inlining or globbing it would
  #      add its tokens to every review. The Codex reviewer's inlined docs carry a `source:` marker.
  if grep -q '<!-- source: .agent-kit/common/process/diagrams/' "$d/.codex/agents/code-reviewer.md" 2>/dev/null \
     || grep -rlq 'process/diagrams/' "$d/.claude/agents" 2>/dev/null; then
    bad "reviewers: process/diagrams/ reached a code reviewer — it must stay skill-only (feature-plan, module-extract)"
  fi

  # (c3) an add-on's process/ companion is skill-only too — the overlay checks it against an install that
  #      has the add-on.

  # (c4) `Design concerns` is the one review output that stops a phase (execution-loop step 2), so it
  #      must reach every reviewer: the Codex one inlines process/review/, the Claude ones glob it.
  grep -q '^### Design concerns' "$d/.agent-kit/common/process/review/code-review.md" \
    || bad "reviewers: code-review.md no longer defines the Design concerns section"
  grep -q '^### Design concerns' "$d/.codex/agents/code-reviewer.md" 2>/dev/null \
    || bad "reviewers: the generated Codex reviewer lacks the Design concerns section"
  ls "$d"/.claude/agents/*-code-reviewer.md >/dev/null 2>&1 \
    || bad "reviewers: no Claude *-code-reviewer.md installed — the glob below would pass on nothing"
  missing=$(grep -L 'process/review/' "$d"/.claude/agents/*-code-reviewer.md 2>/dev/null || true)   # -L exits 1 when every file lacks it
  [ -z "$missing" ] || bad "reviewers: $(echo $missing) no longer glob process/review/ — no Design concerns there"

  # (d) drift BELOW a <placeholder> segment must FAIL. Every module-memory path is
  #     .agent-kit-local/modules/<module>/…, so if the extractor's charset omits <> the match stops at
  #     the '<' and the whole surface compares as the bare parent — two mirrors reading different
  #     files diff clean. That is exactly how the /modules internals.md drift survived. Swapping one
  #     mirror's filename below the placeholder is the minimal proof the gate sees past it.
  if grep -q 'modules/<module>/ui\.md' "$d/.codex/skills/modules/SKILL.md"; then
    sed 's|modules/<module>/ui\.md|modules/<module>/DRIFTED-BY-VERIFY.md|g' \
      "$d/.codex/skills/modules/SKILL.md" > "$d/.mod.tmp" && mv "$d/.mod.tmp" "$d/.codex/skills/modules/SKILL.md"
    if out=$(make -C "$d/.codex" validate-skills 2>&1); then
      bad "parity filter: drift below a <placeholder> segment is invisible to validate-skills"
    elif ! grep -q "DRIFT in 'modules'" <<<"$out"; then
      bad "parity filter: validate-skills failed, but not with the expected modules DRIFT — $(head -2 <<<"$out")"
    fi
    "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1
  else
    bad "parity filter: modules skill no longer references modules/<module>/ui.md — this check needs a new anchor"
  fi

  # (e) a placeholder RENAME is cosmetic and must still pass — that is what normalizing <...> to <>
  #     buys, and without it (d)'s charset fix would turn every <module> vs <module-name> into drift.
  sed 's|modules/<module>/|modules/<module-name>/|g' \
    "$d/.codex/skills/modules/SKILL.md" > "$d/.mod.tmp" && mv "$d/.mod.tmp" "$d/.codex/skills/modules/SKILL.md"
  out=$(make -C "$d/.codex" validate-skills 2>&1) \
    || bad "parity filter: a cosmetic <placeholder> rename is reported as drift — $(head -2 <<<"$out")"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1

  # (f) a path ending a sentence must extract the same as one mid-sentence. A bare '.' in the
  #     extractor's charset is greedy and swallows the sentence period, so the SAME path reads as two
  #     different ones depending on where it sits in the prose — false drift that a dot-safe
  #     extension group (\.[A-Za-z0-9]+)* prevents. Appended to both mirrors, so a correct extractor
  #     sees no change at all; only a greedy one invents an asymmetry.
  printf '\nSee .agent-kit/planning/TEMPLATE.md.\n' >> "$d/.claude/skills/modules/SKILL.md"
  printf '\nSee .agent-kit/planning/TEMPLATE.md and stop.\n' >> "$d/.codex/skills/modules/SKILL.md"
  out=$(make -C "$d/.codex" validate-skills 2>&1) \
    || bad "parity filter: a trailing sentence period is being read as part of the path — $(head -2 <<<"$out")"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1

  # (g) the other half of the normalization contract: a <placeholder> filename must stay
  #     DISTINGUISHABLE from a literal one. (d) proves the gate sees past a placeholder, but swaps two
  #     literals to do it; (e) proves renames collapse. Normalizing one notch too hard — folding a
  #     placeholder into the literal it sits beside — would pass both while re-destroying exactly what
  #     the original bug destroyed: <module>/<domain>.md reading as <module>/internals.md.
  #     Guarded like (a) and (d): if the anchor ever moves, the sed would no-op and this case would
  #     report "folds too hard" about a mutation it never applied — a true failure with a false cause.
  if grep -q 'modules/<module>/internals\.md' "$d/.codex/skills/modules/SKILL.md"; then
    sed 's|modules/<module>/internals\.md|modules/<module>/<domain>.md|g' \
      "$d/.codex/skills/modules/SKILL.md" > "$d/.mod.tmp" && mv "$d/.mod.tmp" "$d/.codex/skills/modules/SKILL.md"
    if out=$(make -C "$d/.codex" validate-skills 2>&1); then
      bad "parity filter: a <placeholder> filename compares equal to a literal one — the normalization folds too hard"
    elif ! grep -q "DRIFT in 'modules'" <<<"$out"; then
      bad "parity filter: validate-skills failed, but not with the expected modules DRIFT — $(head -2 <<<"$out")"
    fi
    "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1
  else
    bad "parity filter: modules skill no longer references modules/<module>/internals.md — (g) needs a new anchor"
  fi

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "parity gate excludes depth-1 Tier-0 only (companions + sub-placeholder paths stay gated)"
}

# ── a process/ companion nobody globs is content that silently never loads ────────────────────
# Depth-1 is gated the other way in check(): anything sitting there must be in the Tier-0 lists. This is
# the nested half. A companion dir only exists to be READ — moving a rule out of always-on into a dir no
# skill or agent names is invisible by construction: the doc installs, the session gets cheaper, and the
# rule is simply never applied again. That is the same failure conventions/desktop/ documents, except
# there it is deliberate. Both harness trees are checked: Cursor and VS Code read the Claude copies, Codex
# its own, so a companion named in one mirror only is unreachable on two harnesses.
# `reference/` is the ONE exemption, and it is exempt by declaration, not by convenience — the taxonomy
# says it is never globbed. Any other never-globbed dir is a bug, so it must fail here.
process_companions_are_reachable() {
  local before=$fail d="$1" label="$2" dir name h
  for dir in "$d"/.agent-kit/common/process/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    ls "$dir"/*.md >/dev/null 2>&1 \
      || bad "$label: process/$name/ holds no *.md — whatever globs it loads nothing"
    [ "$name" = reference ] && continue
    for h in claude codex; do
      grep -rlq "process/$name/" "$d/.$h/skills" "$d/.$h/agents" 2>/dev/null \
        || bad "$label: no .$h/ skill or agent names process/$name/ — it installs and is never read"
    done
  done
  [ "$fail" -eq "$before" ] || return 0
  note "✓" "$label"
}

# ── the VS Code keys that must survive a pre-existing settings.json ──────────────────────────
# chat.useClaudeMdFile and chat.useAgentsMdFile both default TRUE, so without the kit's false VS Code
# ALSO loads .claude/CLAUDE.md with its @imports unexpanded — a pointer list with no content — and the
# project's own root AGENTS.md. .vscode/settings.json is the one seed a project usually already owns,
# and seed-if-absent meant these keys never reached exactly those consumers. Failure is silent on both
# sides: nothing errors, the harness just runs misconfigured.
vscode_chat_keys() {
  local before=$fail d="$OUT/vscode" d0="$OUT/vscode-fresh" out rc nopy i p
  local -a dirs

  # (a0) a brand-new target: the SEEDED file (no merge involved) already carries both keys.
  rm -rf "$d0"; mkdir -p "$d0"
  "$SRC/install.sh" generic "$d0" >/dev/null 2>&1 || { bad "vscode: fresh install failed"; return 0; }
  grep -q '"chat.useClaudeMdFile": false' "$d0/.vscode/settings.json" \
    && grep -q '"chat.useAgentsMdFile": false' "$d0/.vscode/settings.json" \
    || bad "vscode: a fresh install's seeded settings.json is missing one of the kit's two keys"

  rm -rf "$d"; mkdir -p "$d/.vscode"

  # (a) a pre-existing plain-JSON settings.json keeps its keys AND gains BOTH kit keys, in one write.
  printf '{\n  "editor.tabSize": 7\n}\n' > "$d/.vscode/settings.json"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "vscode: install over existing settings failed"; return 0; }
  grep -q '"editor.tabSize"' "$d/.vscode/settings.json" \
    || bad "vscode: merging the kit keys destroyed the project's own settings"
  grep -q '"chat.useClaudeMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useClaudeMdFile never reached a project that already had .vscode/settings.json"
  grep -q '"chat.useAgentsMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useAgentsMdFile never reached a project that already had .vscode/settings.json"

  # (b) an explicit project decision on ONE key is not flipped back, while the other still merges
  #     beside it — and the mirror case. (Guarded like (a): an install that dies here would otherwise
  #     take verify.sh down with it under set -e, skipping every later check.)
  printf '{\n  "chat.useClaudeMdFile": true\n}\n' > "$d/.vscode/settings.json"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "vscode: install (b) failed"; return 0; }
  grep -q '"chat.useClaudeMdFile": true' "$d/.vscode/settings.json" \
    || bad "vscode: install overrode the project's own explicit chat.useClaudeMdFile value"
  grep -q '"chat.useAgentsMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useAgentsMdFile was not merged beside an explicit chat.useClaudeMdFile"

  printf '{\n  "chat.useAgentsMdFile": true\n}\n' > "$d/.vscode/settings.json"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "vscode: install (b mirror) failed"; return 0; }
  grep -q '"chat.useAgentsMdFile": true' "$d/.vscode/settings.json" \
    || bad "vscode: install overrode the project's own explicit chat.useAgentsMdFile value"
  grep -q '"chat.useClaudeMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useClaudeMdFile was not merged beside an explicit chat.useAgentsMdFile"

  # (c) a JSONC file (comments are legal here) is warned about, never rewritten — a JSON round-trip
  #     would silently eat every comment in a file the kit does not own — and the hand-add advice
  #     names both keys.
  printf '{\n  // keep my comment\n  "editor.tabSize": 7\n}\n' > "$d/.vscode/settings.json"
  out=$("$SRC/install.sh" generic "$d" --force 2>&1) || { bad "vscode: install (c) failed"; return 0; }
  grep -q '// keep my comment' "$d/.vscode/settings.json" \
    || bad "vscode: a commented settings.json was rewritten, losing its comments"
  grep -q 'could not merge' <<<"$out" \
    || bad "vscode: a JSONC settings.json was skipped without warning the operator"
  grep -qF '"chat.useClaudeMdFile": false' <<<"$out" && grep -qF '"chat.useAgentsMdFile": false' <<<"$out" \
    || bad "vscode: the JSONC hand-add advice did not name both keys"

  # (d) a key hiding inside a comment / a language block: a text match reads that as "already set"
  #     and skips the merge SILENTLY. Deciding from parsed JSON is what keeps it loud — and the OTHER
  #     key, wholly absent, still merges beside the nested one.
  printf '{\n  "[python]": { "chat.useClaudeMdFile": true }\n}\n' > "$d/.vscode/settings.json"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "vscode: install (d) failed"; return 0; }
  grep -q '"chat.useClaudeMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: a nested chat.useClaudeMdFile was mistaken for a top-level one — key never merged"
  grep -q '"chat.useAgentsMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useAgentsMdFile was not merged alongside a nested chat.useClaudeMdFile"

  # (e) non-ASCII in a file the kit does not own must survive verbatim. json.dump escapes it to
  #     \uXXXX by default, which rewrites content for no reason — the same trade the comment guard refuses.
  printf '{\n  "workbench.colorTheme": "Caf\xc3\xa9 Noir"\n}\n' > "$d/.vscode/settings.json"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "vscode: install (e) failed"; return 0; }
  grep -q 'Café Noir' "$d/.vscode/settings.json" \
    || bad "vscode: merging escaped the project's non-ASCII strings to \\uXXXX"

  # (f) the file is the PROJECT's — install.sh and the README both promise nothing but these two keys
  #     change. Cases (a)-(e) only assert content SURVIVED, so a whole-file round-trip passes them
  #     all while renormalizing indentation and tightening the mode. Assert the untouched bytes and
  #     the mode directly: 4-space indent, CRLF, and 0644 must all come back out unchanged, with both
  #     keys added.
  printf '{\r\n    "editor.tabSize": 7,\r\n    "files.associations": { "*.foo": "json" }\r\n}\r\n' \
    > "$d/.vscode/settings.json"
  chmod 644 "$d/.vscode/settings.json"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "vscode: install (f) failed"; return 0; }
  grep -q '^    "editor.tabSize": 7,\r$' "$d/.vscode/settings.json" \
    || bad "vscode: the merge reformatted a line it does not own (indentation or line ending changed)"
  grep -q '"chat.useClaudeMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useClaudeMdFile never merged into the CRLF fixture"
  grep -q '"chat.useAgentsMdFile": false' "$d/.vscode/settings.json" \
    || bad "vscode: chat.useAgentsMdFile never merged into the CRLF fixture"
  [ "$(ls -l "$d/.vscode/settings.json" | cut -c1-10)" = "-rw-r--r--" ] \
    || bad "vscode: the merge changed the mode of a project-owned settings.json (0644 expected)"

  # (g) a reinstall over an already-merged file is byte-identical, and reports BOTH keys already set.
  cp "$d/.vscode/settings.json" "$OUT/vscode.merged"
  out=$("$SRC/install.sh" generic "$d" --force 2>&1) || { bad "vscode: reinstall (g) failed"; return 0; }
  cmp -s "$OUT/vscode.merged" "$d/.vscode/settings.json" \
    || bad "vscode: a reinstall over an already-merged settings.json changed it"
  grep -q 'chat.useClaudeMdFile already set' <<<"$out" && grep -q 'chat.useAgentsMdFile already set' <<<"$out" \
    || bad "vscode: a reinstall did not report both keys already set"

  # (h) no python3: install still finishes (exit 0), warns "could not merge", and the hand-add advice
  #     names both keys — same sandbox technique as claude_md_excludes's own (f) case. A project-owned
  #     settings.json missing both keys, plus a root AGENTS.md, also proves report_foreign_instructions's
  #     "could not be merged" wording for a lever that failed rather than one explicitly overridden.
  nopy="$OUT/vscode-nopy-bin"; rm -rf "$nopy"; mkdir -p "$nopy"
  IFS=: read -r -a dirs <<<"$PATH"
  i=${#dirs[@]}
  while [ "$i" -gt 0 ]; do   # last dir first, so an earlier one wins a name — as on PATH itself
    i=$((i - 1)); p="${dirs[$i]}"
    case "$p" in /*) if [ -d "$p" ]; then ln -sf "$p"/* "$nopy"/ 2>/dev/null || true; fi ;; esac
  done
  rm -f "$nopy"/python*
  d="$OUT/vscode-nopy"; rm -rf "$d"; mkdir -p "$d/.vscode"
  printf '# Team agents\n' > "$d/AGENTS.md"
  printf '{\n  "editor.tabSize": 7\n}\n' > "$d/.vscode/settings.json"
  cp "$d/.vscode/settings.json" "$OUT/vscode-nopy.before"
  if out=$(PATH="$nopy" "$SRC/install.sh" generic "$d" 2>&1); then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || bad "vscode: install without python3 failed (exit $rc) — it must warn and finish"
  grep -q 'could not merge — no python3 on PATH' <<<"$out" \
    || bad "vscode: no warning was printed when python3 is unavailable"
  grep -qF '"chat.useClaudeMdFile": false' <<<"$out" && grep -qF '"chat.useAgentsMdFile": false' <<<"$out" \
    || bad "vscode: the no-python3 hand-add advice did not name both keys"
  cmp -s "$OUT/vscode-nopy.before" "$d/.vscode/settings.json" \
    || bad "vscode: a no-python3 install still changed the project's settings.json"
  grep -qF '  ⚠ vscode: still loads AGENTS.md — chat.useAgentsMdFile could not be merged (see above)' <<<"$out" \
    || bad "vscode: report_foreign_instructions did not report a failed vscode merge as 'could not be merged'"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "vscode keys merge into a pre-existing settings.json (fresh seed carries both · keeps project keys · respects an explicit value per key, the mirror case too · never eats comments · hand-add advice names both keys · nested key does not count · never reformats or re-modes · reinstall reports both already set, byte-identical · no python3 warns truthfully and is reported as a failed, not skipped, merge)"
}

# claudeMdExcludes of a Claude settings file, one entry per line (nothing when absent); fails when the
# file is not a JSON object. utf-8-sig, so a BOM'd file parses.
_claude_excludes() {  # <file>
  python3 -c '
import json, sys
cfg = json.loads(open(sys.argv[1], "rb").read().decode("utf-8-sig"))
sys.stdout.write("".join(e + "\n" for e in cfg.get("claudeMdExcludes", [])))
' "$1"
}

# A Claude settings file as canonical JSON minus claudeMdExcludes — what "nothing else changed" compares.
_claude_settings_sans_excludes() {  # <file>
  python3 -c '
import json, sys
cfg = json.loads(open(sys.argv[1], "rb").read().decode("utf-8-sig"))
cfg.pop("claudeMdExcludes", None)
print(json.dumps(cfg, sort_keys=True))
' "$1"
}

# <old-seed> plus a generated claudeMdExcludes for <name> and one project entry, laid out as install lays the
# key out — a settings.json that differs from the seed it was installed from only by that key.
_old_seed_with_key() {  # <old-seed> <out> <name>
  python3 -c '
import json, sys
t, n = open(sys.argv[1]).read().rstrip(), sys.argv[3]
entries = ["**/%s/CLAUDE.md" % n, "**/%s/AGENTS.md" % n, "**/%s/.claude/rules/**" % n, "**/docs/CLAUDE.md"]
member = ",\n  \"claudeMdExcludes\": [\n" + ",\n".join("    " + json.dumps(x) for x in entries) + "\n  ]"
open(sys.argv[2], "w").write(t[:-1].rstrip() + member + "\n}\n")
' "$@"
}

# Fails, naming it, when a claudeMdExcludes entry of <target> matches the kit's own .claude/CLAUDE.md at
# its real path — Claude would drop the entrypoint and every @import with it — or when no entry matches a
# given team <relpath>. Matched as Claude reads them: ** crosses directories, * and ? stay inside one, and
# \ is / on both sides.
_glob_check() {  # <target> [relpath…]
  python3 -c '
import json, os, re, sys
t = sys.argv[1]
pats = json.loads(open(t + "/.claude/settings.json", "rb").read().decode("utf-8-sig")).get("claudeMdExcludes") or []
def rx(p):
    p, out, i = p.replace("\\", "/"), "", 0
    while i < len(p):
        if p.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif p.startswith("**", i):
            out, i = out + ".*", i + 2
        elif p[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif p[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(p[i]), i + 1
    return re.compile(out + r"\Z")
def hits(rel):
    path = os.path.realpath(os.path.join(t, rel)).replace("\\", "/")
    return [p for p in pats if rx(p).match(path)]
if hits(".claude/CLAUDE.md"):
    sys.exit("claudeMdExcludes %s would also exclude the kit entrypoint %s"
             % (hits(".claude/CLAUDE.md"), os.path.realpath(os.path.join(t, ".claude/CLAUDE.md"))))
for rel in sys.argv[2:]:
    if not hits(rel):
        sys.exit("no claudeMdExcludes entry matches the team file %s" % rel)
' "$@"
}

# ── Claude loads only the kit's instructions (claudeMdExcludes in .claude/settings.json) ─────────
# Every install merges a GENERATED claudeMdExcludes into the settings.json seed: globs, anchored on the
# target's folder name, for the project's root CLAUDE.md, AGENTS.md and .claude/rules/**. Every failure
# is silent — Claude just loads the team's files beside the kit's again — so each case reads the file back.
claude_md_excludes() {
  local before=$fail base="$OUT/claude-excludes" d e out rc rev kit kind ex nopy p i
  local -a dirs
  chmod -R u+w "$base" 2>/dev/null || true   # (b3) leaves a read-only dir behind if a run is interrupted
  rm -rf "$base"; mkdir -p "$base"

  # (a) root CLAUDE.md, AGENTS.md and .claude/rules/r.md: exactly the three anchored globs, none of them
  #     matching the kit's own .claude/CLAUDE.md, and the three files byte-identical after install.
  d="$base/teamproj"
  mkdir -p "$d/.claude/rules" "$base/team-before"
  printf '# Team rules\n\n@AGENTS.md\n' > "$d/CLAUDE.md"
  printf '# Team agents\n'              > "$d/AGENTS.md"
  printf '# Team rule\n'                > "$d/.claude/rules/r.md"
  cp "$d/CLAUDE.md" "$d/AGENTS.md" "$d/.claude/rules/r.md" "$base/team-before/"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "claude excludes: install over a project with team files failed"; return 0; }
  ex=$(_claude_excludes "$d/.claude/settings.json" || true)
  [ "$ex" = "$(printf '%s\n' '**/teamproj/CLAUDE.md' '**/teamproj/AGENTS.md' '**/teamproj/.claude/rules/**')" ] \
    || bad "claude excludes: claudeMdExcludes is not exactly the three teamproj globs — got: $(tr '\n' ' ' <<<"$ex")"
  if ! out=$(_glob_check "$d" CLAUDE.md AGENTS.md .claude/rules/r.md 2>&1); then bad "claude excludes: $out"; fi
  cmp -s "$base/team-before/CLAUDE.md" "$d/CLAUDE.md" && cmp -s "$base/team-before/AGENTS.md" "$d/AGENTS.md" \
    && cmp -s "$base/team-before/r.md" "$d/.claude/rules/r.md" \
    || bad "claude excludes: install changed a team file (root CLAUDE.md, AGENTS.md or .claude/rules/r.md)"
  [ "$(_claude_settings_sans_excludes "$d/.claude/settings.json")" = "$(_claude_settings_sans_excludes "$SRC/common/.claude/settings.json")" ] \
    || bad "claude excludes: a fresh install wrote more than the kit seed plus claudeMdExcludes"

  # (b) the key never makes the seed look edited: a no-op reinstall reports it up to date and leaves it
  #     byte-identical; a project-added permission and exclude survive a reinstall; --reset-defaults
  #     restores exactly what the fresh install wrote — the seed plus the generated globs.
  cp "$d/.claude/settings.json" "$base/fresh.json"
  out=$("$SRC/install.sh" generic "$d" --force 2>&1) || { bad "claude excludes: reinstall failed"; return 0; }
  grep -q 'up to date: .claude/settings.json' <<<"$out" \
    || bad "claude excludes: a no-op reinstall did not report .claude/settings.json up to date — the generated key made the seed look edited"
  cmp -s "$base/fresh.json" "$d/.claude/settings.json" \
    || bad "claude excludes: a no-op reinstall changed .claude/settings.json"
  python3 -c '
import json, sys
cfg = json.load(open(sys.argv[1]))
cfg["permissions"]["allow"].append("Bash(team-tool:*)")
cfg.setdefault("claudeMdExcludes", []).append("**/docs/CLAUDE.md")
open(sys.argv[1], "w").write(json.dumps(cfg, indent=2) + "\n")
' "$d/.claude/settings.json" || { bad "claude excludes: could not add the project's own permission and exclude"; return 0; }
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "claude excludes: reinstall over project additions failed"; return 0; }
  grep -qF '"Bash(team-tool:*)"' "$d/.claude/settings.json" \
    || bad "claude excludes: a reinstall dropped a project-added permission"
  ex=$(_claude_excludes "$d/.claude/settings.json" || true)
  [ "$ex" = "$(printf '%s\n' '**/teamproj/CLAUDE.md' '**/teamproj/AGENTS.md' '**/teamproj/.claude/rules/**' '**/docs/CLAUDE.md')" ] \
    || bad "claude excludes: a reinstall dropped a project-added exclude or a generated glob — got: $(tr '\n' ' ' <<<"$ex")"
  "$SRC/install.sh" generic "$d" --reset-defaults >/dev/null 2>&1 || { bad "claude excludes: --reset-defaults failed"; return 0; }
  cmp -s "$base/fresh.json" "$d/.claude/settings.json" \
    || bad "claude excludes: --reset-defaults did not restore the kit seed plus the generated globs"

  # (b2) the same for a project-added exclude ALONE, across a kit update: a settings.json that differs from
  #      the seed it was installed from only by claudeMdExcludes still refreshes to the current seed, and
  #      the refresh carries the project's entry over.
  #      The earlier, different seed is a fixture kit's committed v1 (_hist_kit), never $SRC's own history.
  rev=""
  kit="$base/histkit"
  if _hist_kit "$kit"; then rev="$HIST_V1"; fi
  if [ -z "$rev" ]; then
    bad "claude excludes: could not build the fixture kit with an earlier, different settings.json — (b2) needs it"
  else
    e="$base/oldseed"; mkdir -p "$e"
    "$kit/install.sh" generic "$e" >/dev/null 2>&1 || { bad "claude excludes: install (b2) failed"; return 0; }
    git -C "$kit" show "$rev:common/.claude/settings.json" > "$base/old-seed.json" \
      || { bad "claude excludes: could not read the $rev settings.json seed"; return 0; }
    _old_seed_with_key "$base/old-seed.json" "$e/.claude/settings.json" oldseed \
      || { bad "claude excludes: could not build the (b2) fixture"; return 0; }
    grep -v '^version:' "$e/.synced-from" > "$e/.sf" && printf 'version: %s\n' "$rev" >> "$e/.sf"
    mv "$e/.sf" "$e/.synced-from"
    # --check previews what the real run does — a refresh and a merge — and writes nothing.
    cp "$e/.claude/settings.json" "$base/oldseed.before"
    out=$("$kit/install.sh" generic "$e" --check 2>&1) || { bad "claude excludes: --check (b2) failed"; return 0; }
    grep -qF '[check] would refresh untouched seed: .claude/settings.json' <<<"$out" \
      && grep -qF '[check] would merge claudeMdExcludes into .claude/settings.json' <<<"$out" \
      || bad "claude excludes: --check on the refresh path did not preview the refresh and merge the real run does"
    cmp -s "$base/oldseed.before" "$e/.claude/settings.json" \
      || bad "claude excludes: --check changed .claude/settings.json"
    out=$("$kit/install.sh" generic "$e" --force 2>&1) || { bad "claude excludes: reinstall (b2) failed"; return 0; }
    grep -q 'refreshed untouched seed: .claude/settings.json' <<<"$out" \
      && grep -q 'claude: merged claudeMdExcludes into .claude/settings.json' <<<"$out" \
      || bad "claude excludes: a settings.json differing from its installed seed only by claudeMdExcludes was not refreshed with its key merged"
    [ "$(_claude_settings_sans_excludes "$e/.claude/settings.json")" = "$(_claude_settings_sans_excludes "$SRC/common/.claude/settings.json")" ] \
      || bad "claude excludes: an untouched settings.json did not follow the kit from $rev"
    ex=$(_claude_excludes "$e/.claude/settings.json" || true)
    [ "$ex" = "$(printf '%s\n' '**/oldseed/CLAUDE.md' '**/oldseed/AGENTS.md' '**/oldseed/.claude/rules/**' '**/docs/CLAUDE.md')" ] \
      || bad "claude excludes: refreshing an untouched settings.json lost claudeMdExcludes entries — got: $(tr '\n' ' ' <<<"$ex")"

    # (b3) a refresh is ONE atomic write: when it cannot be written, the file — the project's own entries
    #      included — is left exactly as it was, and the warning says so. settings.json links into a
    #      read-only dir, so no temp file can be created beside it; skipped as root, which writes anyway.
    if [ "$(id -u)" != 0 ]; then
      e="$base/rofail"; mkdir -p "$e" "$base/rodir"
      "$kit/install.sh" generic "$e" >/dev/null 2>&1 || { bad "claude excludes: install (b3) failed"; return 0; }
      _old_seed_with_key "$base/old-seed.json" "$base/rodir/settings.json" rofail \
        || { bad "claude excludes: could not build the (b3) fixture"; return 0; }
      rm -f "$e/.claude/settings.json"; ln -s "$base/rodir/settings.json" "$e/.claude/settings.json"
      cp "$base/rodir/settings.json" "$base/rofail.before"
      grep -v '^version:' "$e/.synced-from" > "$e/.sf" && printf 'version: %s\n' "$rev" >> "$e/.sf"
      mv "$e/.sf" "$e/.synced-from"
      chmod 555 "$base/rodir"
      if out=$("$kit/install.sh" generic "$e" --force 2>&1); then rc=0; else rc=$?; fi
      chmod 755 "$base/rodir"
      [ "$rc" -eq 0 ] || bad "claude excludes: a refresh that could not be written made install fail (exit $rc)"
      cmp -s "$base/rofail.before" "$base/rodir/settings.json" \
        || bad "claude excludes: a refresh that could not be written still changed settings.json — its entries were at risk"
      grep -qF 'not refreshed to the kit' <<<"$out" && grep -qF 'is left exactly as it was' <<<"$out" \
        || bad "claude excludes: a refresh that could not be written was not reported as leaving the file as it was"
    fi
  fi

  # (c) none of the three files: the globs are still written, so a file added later is covered with no
  #     reinstall — and the project's own settings.json changes by exactly that member, in its layout.
  d="$base/plainproj"; mkdir -p "$d/.claude"
  printf '{\n    "permissions": {\n        "allow": [\n            "Bash(make:*)"\n        ]\n    },\n    "env": {\n        "FOO": "bar"\n    }\n}\n' \
    > "$d/.claude/settings.json"
  printf '{\n    "permissions": {\n        "allow": [\n            "Bash(make:*)"\n        ]\n    },\n    "env": {\n        "FOO": "bar"\n    },\n    "claudeMdExcludes": [\n        "**/plainproj/CLAUDE.md",\n        "**/plainproj/AGENTS.md",\n        "**/plainproj/.claude/rules/**"\n    ]\n}\n' \
    > "$base/plain.expected"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "claude excludes: install (c) failed"; return 0; }
  cmp -s "$base/plain.expected" "$d/.claude/settings.json" \
    || bad "claude excludes: a project's settings.json did not change by exactly the claudeMdExcludes member"

  # (c2) a key the project already has gets the globs after its own entry, in the array's own layout — one
  #      entry per line or one line — and an empty one is laid out as a new key would be.
  for kind in c2multi c2one c2empty; do
    d="$base/$kind"; mkdir -p "$d/.claude"
    case "$kind" in
      c2multi)
        printf '{\n  "claudeMdExcludes": [\n    "**/docs/CLAUDE.md"\n  ],\n  "env": {}\n}\n' > "$d/.claude/settings.json"
        printf '{\n  "claudeMdExcludes": [\n    "**/docs/CLAUDE.md",\n    "**/c2multi/CLAUDE.md",\n    "**/c2multi/AGENTS.md",\n    "**/c2multi/.claude/rules/**"\n  ],\n  "env": {}\n}\n' \
          > "$base/$kind.expected" ;;
      c2one)
        printf '{\n  "claudeMdExcludes": ["**/docs/CLAUDE.md"],\n  "env": {}\n}\n' > "$d/.claude/settings.json"
        printf '{\n  "claudeMdExcludes": ["**/docs/CLAUDE.md", "**/c2one/CLAUDE.md", "**/c2one/AGENTS.md", "**/c2one/.claude/rules/**"],\n  "env": {}\n}\n' \
          > "$base/$kind.expected" ;;
      c2empty)
        printf '{\n  "env": {},\n  "claudeMdExcludes": []\n}\n' > "$d/.claude/settings.json"
        printf '{\n  "env": {},\n  "claudeMdExcludes": [\n    "**/c2empty/CLAUDE.md",\n    "**/c2empty/AGENTS.md",\n    "**/c2empty/.claude/rules/**"\n  ]\n}\n' \
          > "$base/$kind.expected" ;;
    esac
    "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "claude excludes: install ($kind) failed"; return 0; }
    cmp -s "$base/$kind.expected" "$d/.claude/settings.json" \
      || bad "claude excludes: the globs were not added to an existing key ($kind) in its own layout"
  done

  # (c3) a complete set written for another folder name — a renamed checkout, a worktree, a teammate's
  #      tracked file — is the kit's: every such set goes, the current set takes the first one's place,
  #      the project's entries keep theirs, and the note names the sets. Only a name the kit itself writes
  #      counts: a partial set, or a complete one for a multi-segment path, .claude or a metacharacter
  #      name, is the project's. (No _glob_check here: the kept **/.claude/ set matches the entrypoint.)
  d="$base/newname"; mkdir -p "$d/.claude"
  printf '{\n  "claudeMdExcludes": [\n    "**/docs/CLAUDE.md",\n    "**/oldname/CLAUDE.md",\n    "**/oldname/AGENTS.md",\n    "**/oldname/.claude/rules/**",\n    "**/other/AGENTS.md",\n    "**/apps/web/CLAUDE.md",\n    "**/apps/web/AGENTS.md",\n    "**/apps/web/.claude/rules/**",\n    "**/wt-x/CLAUDE.md",\n    "**/wt-x/AGENTS.md",\n    "**/wt-x/.claude/rules/**",\n    "**/.claude/CLAUDE.md",\n    "**/.claude/AGENTS.md",\n    "**/.claude/.claude/rules/**",\n    "**/proj (1)/CLAUDE.md",\n    "**/proj (1)/AGENTS.md",\n    "**/proj (1)/.claude/rules/**"\n  ],\n  "env": {}\n}\n' \
    > "$d/.claude/settings.json"
  printf '{\n  "claudeMdExcludes": [\n    "**/docs/CLAUDE.md",\n    "**/newname/CLAUDE.md",\n    "**/newname/AGENTS.md",\n    "**/newname/.claude/rules/**",\n    "**/other/AGENTS.md",\n    "**/apps/web/CLAUDE.md",\n    "**/apps/web/AGENTS.md",\n    "**/apps/web/.claude/rules/**",\n    "**/.claude/CLAUDE.md",\n    "**/.claude/AGENTS.md",\n    "**/.claude/.claude/rules/**",\n    "**/proj (1)/CLAUDE.md",\n    "**/proj (1)/AGENTS.md",\n    "**/proj (1)/.claude/rules/**"\n  ],\n  "env": {}\n}\n' \
    > "$base/newname.expected"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "claude excludes: install (c3) failed"; return 0; }
  cmp -s "$base/newname.expected" "$d/.claude/settings.json" \
    || bad "claude excludes: only sets for other kit-writable folder names may be swapped for this folder's, with every project entry kept in place"
  grep -qF "replacing the sets for 'oldname', 'wt-x'" <<<"$out" \
    || bad "claude excludes: the install note did not name the replaced sets"
  # … and under an ASCII-only stdout a non-ASCII name in that note still reports the finished write.
  d="$base/ionew"; mkdir -p "$d/.claude"
  printf '{\n  "claudeMdExcludes": [\n    "**/caf\xc3\xa9/CLAUDE.md",\n    "**/caf\xc3\xa9/AGENTS.md",\n    "**/caf\xc3\xa9/.claude/rules/**"\n  ]\n}\n' \
    > "$d/.claude/settings.json"
  out=$(PYTHONIOENCODING=ascii "$SRC/install.sh" generic "$d" 2>&1) || { bad "claude excludes: install (c3, ASCII stdout) failed"; return 0; }
  grep -qF "replacing the set for 'café'" <<<"$out" \
    || bad "claude excludes: under an ASCII-only stdout, replacing a non-ASCII set was not reported as done"
  ex=$(_claude_excludes "$d/.claude/settings.json" || true)
  [ "$ex" = "$(printf '%s\n' '**/ionew/CLAUDE.md' '**/ionew/AGENTS.md' '**/ionew/.claude/rules/**')" ] \
    || bad "claude excludes: under an ASCII-only stdout the non-ASCII set was not replaced — got: $(tr '\n' ' ' <<<"$ex")"

  # (c4) the globs carry the folder's PHYSICAL name, the one Claude sees: a symlinked alias resolves to
  #      the real folder, and on macOS a decomposed (NFD) folder reached through its composed spelling gets
  #      its name as it reads back from disk — APFS keeps the form it was created in, HFS+ decomposes it.
  mkdir -p "$base/realdir"; ln -s "$base/realdir" "$base/aliasdir"
  "$SRC/install.sh" generic "$base/aliasdir" >/dev/null 2>&1 || { bad "claude excludes: install through a symlinked alias failed"; return 0; }
  ex=$(_claude_excludes "$base/realdir/.claude/settings.json" || true)
  [ "$ex" = "$(printf '%s\n' '**/realdir/CLAUDE.md' '**/realdir/AGENTS.md' '**/realdir/.claude/rules/**')" ] \
    || bad "claude excludes: an install through a symlinked alias wrote globs for the alias — got: $(tr '\n' ' ' <<<"$ex")"
  if [ "$(uname -s)" = Darwin ]; then
    p="$(printf 'proje\xc3\xa7a\xcc\x83o')"; mkdir "$base/$p"
    "$SRC/install.sh" generic "$base/$(printf 'proje\xc3\xa7\xc3\xa3o')" >/dev/null 2>&1 \
      || { bad "claude excludes: install through a composed (NFC) spelling failed"; return 0; }
    ex=$(_claude_excludes "$base/$p/.claude/settings.json" || true)
    p="$(basename "$(cd "$base/$p" && /bin/pwd -P)")"
    [ "$ex" = "$(printf '%s\n' "**/$p/CLAUDE.md" "**/$p/AGENTS.md" "**/$p/.claude/rules/**")" ] \
      || bad "claude excludes: the globs carry the typed Unicode form, not the on-disk one Claude sees"
  fi

  # (d) BOM, CRLF and a 0640 mode survive the merge, and a reinstall leaves the result byte-identical.
  d="$base/bomcrlf"; mkdir -p "$d/.claude"
  printf '\xef\xbb\xbf{\r\n  "env": {\r\n    "A": "1"\r\n  }\r\n}\r\n' > "$d/.claude/settings.json"
  chmod 640 "$d/.claude/settings.json"
  printf '\xef\xbb\xbf{\r\n  "env": {\r\n    "A": "1"\r\n  },\r\n  "claudeMdExcludes": [\r\n    "**/bomcrlf/CLAUDE.md",\r\n    "**/bomcrlf/AGENTS.md",\r\n    "**/bomcrlf/.claude/rules/**"\r\n  ]\r\n}\r\n' \
    > "$base/bomcrlf.expected"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "claude excludes: install (d) failed"; return 0; }
  cmp -s "$base/bomcrlf.expected" "$d/.claude/settings.json" \
    || bad "claude excludes: the merge lost a BOM or CRLF, or changed a line it does not own"
  [ "$(ls -l "$d/.claude/settings.json" | cut -c1-10)" = "-rw-r-----" ] \
    || bad "claude excludes: the merge changed the mode of a project-owned settings.json (0640 expected)"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "claude excludes: reinstall (d) failed"; return 0; }
  cmp -s "$base/bomcrlf.expected" "$d/.claude/settings.json" \
    || bad "claude excludes: a reinstall changed an already-merged settings.json"

  # (e) not strict JSON — a comment, or NaN, which Python's json alone would accept — is warned about,
  #     with the entries to add by hand, and never rewritten.
  for kind in jsonc nan; do
    d="$base/$kind"; mkdir -p "$d/.claude"
    case "$kind" in
      jsonc) printf '{\n  // the team keeps notes here\n  "env": {}\n}\n' > "$d/.claude/settings.json" ;;
      nan)   printf '{\n  "ratio": NaN\n}\n'                               > "$d/.claude/settings.json" ;;
    esac
    cp "$d/.claude/settings.json" "$base/$kind.before"
    if out=$("$SRC/install.sh" generic "$d" 2>&1); then rc=0; else rc=$?; fi
    [ "$rc" -eq 0 ] || bad "claude excludes: a $kind settings.json made install fail (exit $rc)"
    grep -q 'claudeMdExcludes not written — .claude/settings.json is not a strict-JSON object' <<<"$out" \
      || bad "claude excludes: a $kind settings.json was skipped without a warning"
    grep -qF "\"**/$kind/CLAUDE.md\", \"**/$kind/AGENTS.md\", \"**/$kind/.claude/rules/**\"" <<<"$out" \
      || bad "claude excludes: the $kind warning did not print the entries to add by hand"
    cmp -s "$base/$kind.before" "$d/.claude/settings.json" \
      || bad "claude excludes: a $kind settings.json was rewritten"
  done

  # (e2) a claudeMdExcludes that is not an array of strings is left alone, and the hint asks for the
  #      entries in it — never for a second claudeMdExcludes key.
  d="$base/badkey"; mkdir -p "$d/.claude"
  printf '{\n  "claudeMdExcludes": "**/badkey/CLAUDE.md"\n}\n' > "$d/.claude/settings.json"
  cp "$d/.claude/settings.json" "$base/badkey.before"
  if out=$("$SRC/install.sh" generic "$d" 2>&1); then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || bad "claude excludes: a malformed claudeMdExcludes made install fail (exit $rc)"
  grep -qF 'Make the existing claudeMdExcludes in .claude/settings.json an array of strings that includes' <<<"$out" \
    || bad "claude excludes: a malformed claudeMdExcludes drew no hint to fix the existing key"
  if grep -qF '"claudeMdExcludes": [' <<<"$out"; then
    bad "claude excludes: a malformed claudeMdExcludes drew a hint to add a second claudeMdExcludes key"
  fi
  cmp -s "$base/badkey.before" "$d/.claude/settings.json" \
    || bad "claude excludes: a malformed claudeMdExcludes was rewritten"

  # (f) no python3: install still finishes, warns, and leaves the seed as shipped. /usr/bin also holds
  #     git, make and the shell, so the PATH links every command on this machine except python*.
  nopy="$base/nopy-bin"; mkdir -p "$nopy"
  IFS=: read -r -a dirs <<<"$PATH"
  i=${#dirs[@]}
  while [ "$i" -gt 0 ]; do   # last dir first, so an earlier one wins a name — as on PATH itself
    i=$((i - 1)); p="${dirs[$i]}"
    case "$p" in /*) if [ -d "$p" ]; then ln -sf "$p"/* "$nopy"/ 2>/dev/null || true; fi ;; esac
  done
  rm -f "$nopy"/python*
  d="$base/nopy"; mkdir -p "$d"
  if out=$(PATH="$nopy" "$SRC/install.sh" generic "$d" 2>&1); then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || bad "claude excludes: install without python3 failed (exit $rc) — it must warn and finish"
  grep -q 'claudeMdExcludes not written — no python3 on PATH' <<<"$out" \
    || bad "claude excludes: no warning was printed when python3 is unavailable"
  cmp -s "$SRC/common/.claude/settings.json" "$d/.claude/settings.json" \
    || bad "claude excludes: .claude/settings.json is not the plain seed after an install without python3"
  # … and over an already-merged file it says the key could not be checked — not that the globs are missing.
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "claude excludes: install (f) with python3 failed"; return 0; }
  if out=$(PATH="$nopy" "$SRC/install.sh" generic "$d" --force 2>&1); then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || bad "claude excludes: a reinstall without python3 failed (exit $rc)"
  grep -q 'claudeMdExcludes could not be checked or updated — no python3 on PATH' <<<"$out" \
    || bad "claude excludes: without python3, an already-merged settings.json was not reported as unchecked"
  if grep -q 'Claude still loads' <<<"$out"; then
    bad "claude excludes: without python3, an already-merged settings.json was reported as missing its globs"
  fi

  # (g) no key, and a warning saying why, for a folder name Claude cannot match literally — a glob
  #     metacharacter, which no escape fixes since Claude rewrites \ to / before matching — and for one named
  #     exactly .claude, whose glob would also exclude the kit's own .claude/CLAUDE.md. .Claude is fine.
  for d in "$base/glob[1]" "$base/proj (1)" "$base/host/.claude"; do
    mkdir -p "$d"
    if out=$("$SRC/install.sh" generic "$d" 2>&1); then rc=0; else rc=$?; fi
    [ "$rc" -eq 0 ] || bad "claude excludes: install into '${d#"$base"/}' failed (exit $rc)"
    case "$d" in
      */.claude) grep -qF 'claudeMdExcludes not written — the folder is named .claude' <<<"$out" ;;
      *)         grep -qF "claudeMdExcludes not written — the folder name '$(basename "$d")'" <<<"$out" ;;
    esac || bad "claude excludes: '${d#"$base"/}' drew no warning saying why its key was skipped"
    cmp -s "$SRC/common/.claude/settings.json" "$d/.claude/settings.json" \
      || bad "claude excludes: claudeMdExcludes was written for the folder '${d#"$base"/}'"
  done
  d="$base/host2/.Claude"; mkdir -p "$d"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "claude excludes: install into a folder named .Claude failed"; return 0; }
  ex=$(_claude_excludes "$d/.claude/settings.json" || true)
  [ "$ex" = "$(printf '%s\n' '**/.Claude/CLAUDE.md' '**/.Claude/AGENTS.md' '**/.Claude/.claude/rules/**')" ] \
    || bad "claude excludes: only the exact name .claude is skipped, yet a folder named .Claude got: $(tr '\n' ' ' <<<"$ex")"
  if ! out=$(_glob_check "$d" 2>&1); then bad "claude excludes: $out"; fi

  # (h) --check on a fresh target previews the merge and writes nothing.
  d="$base/dryrun"; mkdir -p "$d"
  out=$("$SRC/install.sh" generic "$d" --check 2>&1) || { bad "claude excludes: --check failed"; return 0; }
  grep -qF '[check] would merge claudeMdExcludes into .claude/settings.json' <<<"$out" \
    || bad "claude excludes: --check on a fresh target did not preview the claudeMdExcludes merge"
  [ -z "$(ls -A "$d")" ] || bad "claude excludes: --check wrote into a fresh target"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "claude excludes (exactly three anchored globs, none matching the real .claude/CLAUDE.md · team files untouched · no-op reinstall up to date and byte-identical · project permission and excludes survive, a seed refresh included · --reset-defaults = seed + globs · appended in the array's own layout · sets for other folder names replaced in place and reported · physical folder name · own layout, BOM, CRLF and mode kept · non-strict JSON or a malformed key warned, never rewritten · no python3 warns truthfully · metacharacter and .claude folders skipped · --check previews and writes nothing)"
}

# ── per-tool report of the foreign instruction files install leaves untouched on disk ────────
# CLAUDE.md, AGENTS.md and .claude/rules/ are never moved, edited or deleted — install only REPORTS,
# per tool, whether that tool's own lever actually keeps them out of its context. Every assertion here
# is about truthfulness: a tool must never be reported as skipping a file whose lever is not actually
# in place.
foreign_instructions_report() {
  local before=$fail d out

  # (a) all three foreign files: the claude line names all three, the codex line (in-place, since the
  #     config.toml is fresh), a vscode skip line naming CLAUDE.md and AGENTS.md, the vscode
  #     .claude/rules/ warning, and the cursor warning.
  d="$OUT/report-all"; rm -rf "$d"; mkdir -p "$d/.claude/rules"
  printf '# Team rules\n'  > "$d/CLAUDE.md"
  printf '# Team agents\n' > "$d/AGENTS.md"
  printf '# Team rule\n'   > "$d/.claude/rules/r.md"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (a) failed"; return 0; }
  grep -qF 'foreign instruction files — kept on disk, never edited:' <<<"$out" \
    || bad "foreign report: the header did not print"
  grep -qF '  claude: skips CLAUDE.md, AGENTS.md, .claude/rules/ (claudeMdExcludes)' <<<"$out" \
    || bad "foreign report: the claude line did not name all three foreign files"
  grep -qF '  codex: skips AGENTS.md once the project is trusted (project_doc_max_bytes = 0)' <<<"$out" \
    || bad "foreign report: the codex line did not print for a trusted-by-default fresh config.toml"
  grep -qF '  vscode: skips CLAUDE.md, AGENTS.md (chat.useClaudeMdFile / chat.useAgentsMdFile: false)' <<<"$out" \
    || bad "foreign report: the vscode skip line did not name both CLAUDE.md and AGENTS.md"
  grep -qF '  ⚠ vscode: can still apply .claude/rules/ files that declare paths or a description — no VS Code setting stops it' <<<"$out" \
    || bad "foreign report: the vscode .claude/rules/ warning did not print"
  grep -qF '  ⚠ cursor: still loads AGENTS.md — Cursor has no setting to turn it off' <<<"$out" \
    || bad "foreign report: the cursor warning did not print"

  # (b) only CLAUDE.md: no cursor warning, no rules warning, no codex line.
  d="$OUT/report-claude-only"; rm -rf "$d"; mkdir -p "$d"
  printf '# Team rules\n' > "$d/CLAUDE.md"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (b) failed"; return 0; }
  if grep -q 'cursor:' <<<"$out"; then bad "foreign report: a project with no AGENTS.md still drew a cursor warning"; fi
  if grep -q 'can still apply .claude/rules/' <<<"$out"; then
    bad "foreign report: a project with no .claude/rules/ still drew the vscode rules warning"
  fi
  if grep -q 'codex:' <<<"$out"; then bad "foreign report: a project with no AGENTS.md still drew a codex line"; fi
  grep -qF '  claude: skips CLAUDE.md (claudeMdExcludes)' <<<"$out" \
    || bad "foreign report: the claude line did not name the one existing foreign file"
  grep -qF '  vscode: skips CLAUDE.md (chat.useClaudeMdFile: false)' <<<"$out" \
    || bad "foreign report: the vscode line did not name the one existing foreign file"

  # (c) none of the three: the "none" line, and no ⚠ report line.
  d="$OUT/report-none"; rm -rf "$d"; mkdir -p "$d"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (c) failed"; return 0; }
  grep -qF 'foreign instruction files: none (no root CLAUDE.md, AGENTS.md or .claude/rules/)' <<<"$out" \
    || bad "foreign report: the none-exist line did not print"
  if grep -qE '⚠ (vscode: still loads|claude: still loads|codex:|cursor:)' <<<"$out"; then
    bad "foreign report: a project with none of the three foreign files still drew a ⚠ report line"
  fi

  # (d) an explicit chat.useAgentsMdFile: true plus root AGENTS.md draws the vscode "still loads" warning.
  d="$OUT/report-vscode-override"; rm -rf "$d"; mkdir -p "$d/.vscode"
  printf '# Team agents\n' > "$d/AGENTS.md"
  printf '{\n  "chat.useAgentsMdFile": true\n}\n' > "$d/.vscode/settings.json"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (d) failed"; return 0; }
  grep -qF '  ⚠ vscode: still loads AGENTS.md — chat.useAgentsMdFile is true in .vscode/settings.json' <<<"$out" \
    || bad "foreign report: an explicit chat.useAgentsMdFile: true drew no vscode warning"

  # (d2) the MIXED case: both CLAUDE.md and AGENTS.md exist, but only ONE key is overridden — exactly
  #      one file is named in the "skips" line and the other gets its own "still loads" line. This is
  #      what would break first if the partial-join (install.sh's ok_names/ok_keys) ever leaked a
  #      leading separator when only one of the two is ok — the exact-string match below would then
  #      no longer match. The mirror case swaps which key is overridden.
  d="$OUT/report-vscode-mixed"; rm -rf "$d"; mkdir -p "$d/.vscode"
  printf '# Team rules\n'  > "$d/CLAUDE.md"
  printf '# Team agents\n' > "$d/AGENTS.md"
  printf '{\n  "chat.useAgentsMdFile": true\n}\n' > "$d/.vscode/settings.json"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (d2) failed"; return 0; }
  grep -qF '  vscode: skips CLAUDE.md (chat.useClaudeMdFile: false)' <<<"$out" \
    || bad "foreign report: the mixed case did not name exactly CLAUDE.md in the vscode skip line"
  grep -qF '  ⚠ vscode: still loads AGENTS.md — chat.useAgentsMdFile is true in .vscode/settings.json' <<<"$out" \
    || bad "foreign report: the mixed case drew no still-loads line for the overridden AGENTS.md"

  d="$OUT/report-vscode-mixed2"; rm -rf "$d"; mkdir -p "$d/.vscode"
  printf '# Team rules\n'  > "$d/CLAUDE.md"
  printf '# Team agents\n' > "$d/AGENTS.md"
  printf '{\n  "chat.useClaudeMdFile": true\n}\n' > "$d/.vscode/settings.json"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (d2 mirror) failed"; return 0; }
  grep -qF '  vscode: skips AGENTS.md (chat.useAgentsMdFile: false)' <<<"$out" \
    || bad "foreign report: the mirrored mixed case did not name exactly AGENTS.md in the vscode skip line"
  grep -qF '  ⚠ vscode: still loads CLAUDE.md — chat.useClaudeMdFile is true in .vscode/settings.json' <<<"$out" \
    || bad "foreign report: the mirrored mixed case drew no still-loads line for the overridden CLAUDE.md"

  # (e) a JSONC .claude/settings.json plus root CLAUDE.md draws the ⚠ claude "still loads" line.
  d="$OUT/report-claude-jsonc"; rm -rf "$d"; mkdir -p "$d/.claude"
  printf '# Team rules\n' > "$d/CLAUDE.md"
  printf '{\n  // team notes\n  "env": {}\n}\n' > "$d/.claude/settings.json"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (e) failed"; return 0; }
  grep -qF '  ⚠ claude: still loads CLAUDE.md — claudeMdExcludes is not in place (see above)' <<<"$out" \
    || bad "foreign report: a JSONC .claude/settings.json drew no ⚠ claude still-loads line"

  # (f) a project-owned .codex/config.toml (the seed plus one comment) plus root AGENTS.md draws the
  #     ⚠ codex line — even though project_doc_max_bytes = 0 is still textually present, ANY deviation
  #     from the kit's byte-for-byte seed (minus the generated block) is project-owned, not guaranteed.
  d="$OUT/report-codex-owned"; rm -rf "$d"; mkdir -p "$d/.codex"
  printf '# Team agents\n' > "$d/AGENTS.md"
  cp "$SRC/common/.codex/config.toml" "$d/.codex/config.toml"
  printf '# a project comment\n' >> "$d/.codex/config.toml"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign report: install (f) failed"; return 0; }
  grep -qF '  ⚠ codex: .codex/config.toml is project-owned — Codex skips AGENTS.md only if it sets project_doc_max_bytes = 0' <<<"$out" \
    || bad "foreign report: a project-owned config.toml drew no ⚠ codex line"

  # (g) --check on a fixture with foreign files prints the [check] header and writes nothing.
  d="$OUT/report-check"; rm -rf "$d"; mkdir -p "$d"
  printf '# Team rules\n' > "$d/CLAUDE.md"
  out=$("$SRC/install.sh" generic "$d" --check 2>&1) || { bad "foreign report: --check (g) failed"; return 0; }
  grep -qF '[check] foreign instruction files after this install — kept on disk, never edited:' <<<"$out" \
    || bad "foreign report: --check did not print the [check] header"
  [ "$(find "$d" -mindepth 1 ! -name CLAUDE.md)" = "" ] \
    || bad "foreign report: --check wrote into a fresh target"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "per-tool foreign-instructions report (names existing files only · claude/codex/vscode/cursor levers checked truthfully · codex project-owned despite a textually-intact key · none-exist and only-one-file shapes correct · mixed vscode overrides split correctly between the skip line and per-file warnings, both directions · --check previews, writes nothing)"
}

# Extracts one TOML top-level value as raw text (strings verbatim, else str()) via tomllib — the same
# parser a trusted Codex reads config.toml with, so this cannot drift from what Codex would see.
# Decodes utf-8-sig (not plain utf-8) so a BOM'd project file parses instead of failing at column 1 —
# the same reason sync-codex-config.py itself never hands tomllib a raw, un-decoded byte string.
_toml_value() {  # <file> <key>
  python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as fh:
    data = tomllib.loads(fh.read().decode("utf-8-sig"))
v = data.get(sys.argv[2], "")
sys.stdout.write(v if isinstance(v, str) else str(v))
' "$1" "$2"
}

# True (exit 0) iff <file> parses as TOML once a BOM (if any) is stripped first.
_toml_parses() {  # <file>
  python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as fh:
    tomllib.loads(fh.read().decode("utf-8-sig"))
' "$1" >/dev/null 2>&1
}

# ── Codex's trust-gated instructions seed (.codex/config.toml) ──────────────────────────────────
# project_doc_max_bytes = 0 is a plain seed (seed_once_codex_config in install.sh); developer_instructions
# is a GENERATED key common/.codex/Makefile's sync-codex-config merges in on every install, between
# marker comments, holding the exact .codex/AGENTS.md body — the mechanism this feature exists to prove.
codex_config_toml() {
  local before=$fail d="$OUT/codex-config" out

  # Hard requirement, not a soft skip: this gate has no "skip" vocabulary (a run either passes or
  # reports a count of FAILs), so a dev/CI machine without python >= 3.11 sees a named failure here
  # rather than a silently thinner gate. The GENERATOR (sync-codex-config.py) stays on older python3 —
  # only this verification is allowed to require tomllib.
  python3 -c 'import tomllib' >/dev/null 2>&1 \
    || { bad "codex config.toml: python3 lacks tomllib (3.11+) — cannot run these checks"; return 0; }

  rm -rf "$d"; mkdir -p "$d"

  # (a) a fresh install: config.toml parses as TOML, holds project_doc_max_bytes = 0, and
  #     developer_instructions equals the generated .codex/AGENTS.md body exactly.
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 || { bad "codex config.toml: initial install failed"; return 0; }
  _toml_parses "$d/.codex/config.toml" || bad "codex config.toml: does not parse as TOML after a fresh install"
  [ "$(_toml_value "$d/.codex/config.toml" project_doc_max_bytes)" = "0" ] \
    || bad "codex config.toml: project_doc_max_bytes is not 0 after a fresh install"
  _toml_value "$d/.codex/config.toml" developer_instructions > "$d/.di.actual"
  cmp -s "$d/.di.actual" "$d/.codex/AGENTS.md" \
    || bad "codex config.toml: developer_instructions does not equal the generated .codex/AGENTS.md body"

  # (a2) mode survives an install: every sibling seed is 644, and mkstemp's 0600 default must be
  #      overwritten before the atomic replace, not left as-is.
  [ "$(ls -l "$d/.codex/config.toml" | cut -c1-10)" = "-rw-r--r--" ] \
    || bad "codex config.toml: mode is not 0644 after a fresh install"

  # (b) a reinstall with nothing changed regenerates the block byte-identical (idempotent) —
  #     the untouched check must see past the block it is itself comparing around.
  cp "$d/.codex/config.toml" "$d/.before.toml"
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1 || { bad "codex config.toml: reinstall failed"; return 0; }
  cmp -s "$d/.before.toml" "$d/.codex/config.toml" \
    || bad "codex config.toml: a no-op reinstall changed an untouched config.toml"

  # (c) a pre-existing project config.toml (its own key + its own [table]) is KEPT, and the
  #     generated block is merged in BEFORE that table — after it would nest developer_instructions
  #     under the project's own table instead of the root.
  rm -rf "$d"; mkdir -p "$d/.codex"
  printf 'model = "gpt-5"\n\n[sandbox]\nnetwork_access = false\n' > "$d/.codex/config.toml"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 \
    || { bad "codex config.toml: install over a pre-existing file failed"; return 0; }
  grep -qx 'model = "gpt-5"' "$d/.codex/config.toml" \
    || bad "codex config.toml: a pre-existing project key was lost"
  [ "$(_toml_value "$d/.codex/config.toml" project_doc_max_bytes)" = "" ] \
    || bad "codex config.toml: a kept, project-owned file gained project_doc_max_bytes — only the generated key merges into a kept file"
  python3 -c '
import sys, tomllib
with open(sys.argv[1], "rb") as f:
    data = tomllib.load(f)
sys.exit(0 if data.get("sandbox") == {"network_access": False} else 1)
' "$d/.codex/config.toml" || bad "codex config.toml: the project's own [sandbox] table was not preserved intact"
  _toml_value "$d/.codex/config.toml" developer_instructions > "$d/.di.actual"
  cmp -s "$d/.di.actual" "$d/.codex/AGENTS.md" \
    || bad "codex config.toml: the generated block was not merged into a pre-existing config.toml"

  # (d) a project-set developer_instructions OUTSIDE the markers is left alone and reported — a
  #     second one would be invalid TOML, so the kit must not add its own.
  rm -rf "$d"; mkdir -p "$d/.codex"
  printf 'model = "gpt-5"\ndeveloper_instructions = "mine"\n' > "$d/.codex/config.toml"
  out=$("$SRC/install.sh" generic "$d" 2>&1) \
    || { bad "codex config.toml: install over a foreign developer_instructions failed"; return 0; }
  grep -qx 'developer_instructions = "mine"' "$d/.codex/config.toml" \
    || bad "codex config.toml: a project-set developer_instructions was overwritten, not left alone"
  grep -q 'developer_instructions outside the generated block' <<<"$out" \
    || bad "codex config.toml: no warning was printed for a project-set developer_instructions"

  # (e) --reset-defaults restores the pristine seed (project content gone) plus a fresh block.
  "$SRC/install.sh" generic "$d" --reset-defaults >/dev/null 2>&1 \
    || { bad "codex config.toml: --reset-defaults failed"; return 0; }
  grep -q 'model = "gpt-5"' "$d/.codex/config.toml" \
    && bad "codex config.toml: --reset-defaults kept project content instead of replacing the seed"
  [ "$(_toml_value "$d/.codex/config.toml" project_doc_max_bytes)" = "0" ] \
    || bad "codex config.toml: --reset-defaults did not restore project_doc_max_bytes = 0"
  _toml_value "$d/.codex/config.toml" developer_instructions > "$d/.di.actual"
  cmp -s "$d/.di.actual" "$d/.codex/AGENTS.md" \
    || bad "codex config.toml: --reset-defaults did not re-add the generated block"

  # (f) an orphan block — the first line equals the OPEN marker and no line anywhere after it equals
  #     the CLOSE marker — is left alone: install still finishes, the "no matching end marker"
  #     warning prints, and the file is byte-identical afterward (correct today; was uncovered).
  rm -rf "$d"; mkdir -p "$d/.codex"
  printf '# >>> agent-kit generated: do not edit — make -C .codex sync-agents\nstuff\nmore stuff\n' \
    > "$d/.codex/config.toml"
  cp "$d/.codex/config.toml" "$d/.orphan.before"
  if out=$("$SRC/install.sh" generic "$d" 2>&1); then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || bad "codex config.toml: an orphan generated-block marker made install fail (exit $rc)"
  grep -q 'no matching end marker' <<<"$out" \
    || bad "codex config.toml: no warning was printed for an orphan generated-block marker"
  cmp -s "$d/.orphan.before" "$d/.codex/config.toml" \
    || bad "codex config.toml: an orphan generated-block marker was not left byte-identical"

  # (g) a BOM'd project config.toml is kept, the BOM survives, the file still parses, and
  #     developer_instructions sits at the root — a BOM must never be read as content (which would
  #     corrupt the first line) nor silently dropped (which would rewrite bytes the project owns).
  rm -rf "$d"; mkdir -p "$d/.codex"
  printf '\xef\xbb\xbfmodel = "gpt-5"\n' > "$d/.codex/config.toml"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 \
    || { bad "codex config.toml: install over a BOM'd file failed"; return 0; }
  [ "$(head -c 3 "$d/.codex/config.toml" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ] \
    || bad "codex config.toml: a BOM'd project file lost its BOM"
  _toml_parses "$d/.codex/config.toml" || bad "codex config.toml: a BOM'd project file no longer parses as TOML"
  [ "$(_toml_value "$d/.codex/config.toml" developer_instructions | wc -c)" -gt 0 ] \
    || bad "codex config.toml: developer_instructions missing from a BOM'd project file"

  # (h) a CRLF project config.toml keeps CRLF on its own (untouched) lines, and still parses — the
  #     generator must detect the file's line ending from itself, never hardcode LF.
  rm -rf "$d"; mkdir -p "$d/.codex"
  printf 'model = "gpt-5"\r\nextra = 1\r\n' > "$d/.codex/config.toml"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 \
    || { bad "codex config.toml: install over a CRLF file failed"; return 0; }
  grep -q $'model = "gpt-5"\r$' "$d/.codex/config.toml" \
    || bad "codex config.toml: a CRLF project file lost CRLF on its own lines"
  _toml_parses "$d/.codex/config.toml" || bad "codex config.toml: a CRLF project file no longer parses as TOML"

  # (j) a project's own multi-line string containing a look-alike `[fake_table]` line AND both marker
  #     lines is not mistaken for our block — recognition is anchored to the very TOP of the file
  #     only, so this string is ordinary content: the result parses, developer_instructions sits at
  #     the root, and the string survives byte-identical.
  rm -rf "$d"; mkdir -p "$d/.codex"
  printf 'notes = """\n# >>> agent-kit generated: do not edit — make -C .codex sync-agents\n[fake_table]\n# <<< agent-kit generated\n"""\n' \
    > "$d/.codex/config.toml"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 \
    || { bad "codex config.toml: install over a look-alike-marker fixture failed"; return 0; }
  _toml_parses "$d/.codex/config.toml" \
    || bad "codex config.toml: a project string containing look-alike markers broke parsing"
  [ "$(_toml_value "$d/.codex/config.toml" developer_instructions | wc -c)" -gt 0 ] \
    || bad "codex config.toml: developer_instructions missing when a project string contains look-alike markers"
  _toml_value "$d/.codex/config.toml" notes > "$d/.notes.actual"
  printf '# >>> agent-kit generated: do not edit — make -C .codex sync-agents\n[fake_table]\n# <<< agent-kit generated\n' \
    > "$d/.notes.expected"
  cmp -s "$d/.notes.actual" "$d/.notes.expected" \
    || bad "codex config.toml: a project's own multi-line string (look-alike markers inside) was altered"

  # (k) no python3 on PATH: the Makefile target degrades gracefully — prints the note, exits 0, and
  #     leaves config.toml untouched, so a make-without-python3 environment never aborts install.sh
  #     under set -e.
  rm -rf "$d"; mkdir -p "$d"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 \
    || { bad "codex config.toml: initial install (no-python3 case) failed"; return 0; }
  cp "$d/.codex/config.toml" "$d/.before-nopy.toml"
  if out=$(make -C "$d/.codex" sync-codex-config PYTHON=/no/such/python3-xyz 2>&1); then rc=0; else rc=$?; fi
  [ "$rc" -eq 0 ] || bad "codex config.toml: the no-python3 path exited non-zero ($rc)"
  grep -q 'no python3 on PATH' <<<"$out" \
    || bad "codex config.toml: no warning was printed when python3 is unavailable"
  cmp -s "$d/.before-nopy.toml" "$d/.codex/config.toml" \
    || bad "codex config.toml: config.toml was modified despite no python3 on PATH"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "codex config.toml (parses · developer_instructions == AGENTS.md body · idempotent · mode 0644 · merges into a kept file ahead of its table · foreign key reported · --reset-defaults restores seed + block · orphan block left alone · BOM/CRLF/look-alike-markers survive · no-python3 degrades gracefully)"
}

# ── the generator refuses a Tier-0 doc containing ''' (would end the TOML literal early) ────────
codex_config_rejects_triple_quote() {
  local before=$fail d="$OUT/codex-config-triple" out
  rm -rf "$d"; mkdir -p "$d"
  "$SRC/install.sh" generic "$d" >/dev/null 2>&1 \
    || { bad "codex triple-quote guard: initial install failed"; return 0; }
  printf "\nSample: '''\n" >> "$d/.agent-kit-local/context/architecture.md"
  if out=$("$SRC/install.sh" generic "$d" --force 2>&1); then
    bad "codex triple-quote guard: install succeeded despite a ''' in a Tier-0 doc"
    return 0
  fi
  grep -q "architecture.md contains '''" <<<"$out" \
    || bad "codex triple-quote guard: the failure did not name the offending doc —$(tail -3 <<<"$out" | tr '\n' ' ')"
  [ "$fail" -eq "$before" ] || return 0
  note "✓" "the Codex config.toml generator fails, naming the doc, when Tier-0 text contains '''"
}

# ── the two harness files the kit does not own ───────────────────────────────────────────────
# Both are cases of "the project already has this file", and both used to fail silently.
# .github/copilot-instructions.md is THE GitHub-documented repo-wide instructions filename, so the
# generator taking that name over destroyed a consumer's own file. .claude/CLAUDE.md is kept when
# project-owned, which leaves Claude — the primary harness — loading none of the Tier-0 docs that
# every other harness gets inlined.
foreign_harness_files() {
  local before=$fail d="$OUT/foreign" out
  rm -rf "$d"; mkdir -p "$d/.github" "$d/.claude"

  printf '# House rules\n\nUse pnpm, never npm.\n' > "$d/.github/copilot-instructions.md"
  printf '# My project\n\nSome notes.\n'           > "$d/.claude/CLAUDE.md"
  out=$("$SRC/install.sh" generic "$d" 2>&1) || { bad "foreign files: install failed"; return 0; }

  grep -q 'Use pnpm, never npm' "$d/.github/copilot-instructions.md.pre-agent-kit" 2>/dev/null \
    || bad "foreign files: the project's own copilot-instructions.md was destroyed, not backed up"
  grep -q 'GENERATED by' "$d/.github/copilot-instructions.md" \
    || bad "foreign files: copilot-instructions.md was not regenerated after the backup"

  # A CLAUDE.md with NO kit imports must warn, naming what is missing.
  grep -q 'missing .* of the kit' <<<"$out" \
    || bad "foreign files: a project CLAUDE.md importing no Tier-0 docs drew no warning"

  # …and so must a PARTIAL one: "has at least one @import" would pass this while planning,
  # agent-dispatch and shell-hygiene are all still absent.
  printf '# My project\n\n@../.agent-kit-local/context/architecture.md\n' > "$d/.claude/CLAUDE.md"
  out=$("$SRC/install.sh" generic "$d" --force 2>&1) || { bad "foreign files: partial-import install failed"; return 0; }
  grep -q 'missing .* of the kit' <<<"$out" \
    || bad "foreign files: a CLAUDE.md holding only ONE kit import was accepted as complete"

  # A second install must not overwrite the backup with the kit's own generated output.
  "$SRC/install.sh" generic "$d" --force >/dev/null 2>&1
  grep -q 'Use pnpm, never npm' "$d/.github/copilot-instructions.md.pre-agent-kit" \
    || bad "foreign files: a reinstall overwrote the backup with the generated file"

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "files the kit does not own (copilot-instructions backed up once · CLAUDE.md import gaps warned)"
}

# ── a lint must never leave a wiped target ───────────────────────────────────────────────────
# install.sh step 1 WIPES the kit-owned trees before anything is rebuilt. Any non-zero exit between
# that wipe and the end leaves the project with no conventions and no skills. validate-skills is a
# lint over skill prose — it builds nothing — so it must not be able to cause that. It could, because
# it ships inside `sync-agents`, which install runs under `set -e`. Reachable only from a kit whose
# own mirrors drifted (a consumer's edits are wiped before make runs), i.e. during meta-dev — which
# is exactly when losing a target is most confusing. Proven against a drifted COPY of the kit.
lint_never_wipes_target() {
  local before=$fail kit="$OUT/driftkit" d="$OUT/driftkit-target" out item
  rm -rf "$kit" "$d"; mkdir -p "$d" "$kit"
  # Copy the kit's SOURCE dirs, never $SRC wholesale: $kit lives inside $SRC/.scratch-target, so a plain
  # `cp -R "$SRC" "$kit"` copies the scratch tree (≈12 MB, including the destination) into itself and
  # then deletes it again. It works, but `2>/dev/null || true` hides a partial copy, which would surface
  # as a baffling "drift ABORTED the install" rather than "could not stage a kit copy".
  for item in install.sh verify.sh README.md LICENSE NOTICE .gitignore common stacks; do
    [ -e "$SRC/$item" ] || { bad "lint-vs-wipe: kit source '$item' is missing — this check needs updating"; return 0; }
    cp -R "$SRC/$item" "$kit/$item" || { bad "lint-vs-wipe: could not stage a kit copy ($item)"; return 0; }
  done
  [ -f "$kit/install.sh" ] || { bad "lint-vs-wipe: could not stage a kit copy"; return 0; }

  # Drift one gated skill pair in the COPY: Codex names a doc Claude does not.
  printf '\nAlso read `.agent-kit/common/conventions/backend/ghost-drift.md`.\n' \
    >> "$kit/common/.codex/skills/backend/SKILL.md"

  if out=$("$kit/install.sh" generic "$d" 2>&1); then :; else
    bad "lint-vs-wipe: a skill doc-list drift ABORTED the install — target left wiped by step 1"
    printf '%s\n' "$out" | tail -3 | sed 's/^/           /'
    return 0
  fi
  grep -q 'install COMPLETED' <<<"$out" || bad "lint-vs-wipe: drift did not produce the advisory warning"
  # The target must be whole: conventions, skills, and all four Tier-0 surfaces.
  for f in .agent-kit/common/process/planning.md .claude/skills/backend/SKILL.md \
           .claude/CLAUDE.md .codex/AGENTS.md .cursor/rules/agent-kit.mdc .github/copilot-instructions.md; do
    [ -s "$d/$f" ] || bad "lint-vs-wipe: install left the target incomplete — missing $f"
  done

  [ "$fail" -eq "$before" ] || return 0
  note "✓" "a skill doc-list drift warns but never leaves a wiped, unrebuilt target"
}

# ── run ──────────────────────────────────────────────────────────────────────────────────────
mk_fixtures
for root in "${STACK_ROOTS[@]}"; do
  # A stack outside the kit's own stacks/ is handed to install.sh as an extra root.
  stack_args=()
  [ "$root" = "$SRC/stacks" ] || stack_args=(--stacks "$root")
  for stack_dir in "$root"/*/; do
    stack="$(basename "$stack_dir")"
    [ -z "$ONLY" ] || [ "$ONLY" = "$stack" ] || continue

    targets=("$OUT/stack-$stack")
    [ "$stack" = generic ] && targets=("$OUT/fx/go" "$OUT/fx/python" "$OUT/fx/node" "$OUT/fx/docs")

    for t in "${targets[@]}"; do
      label="$stack → $(basename "$t")"
      mkdir -p "$t"
      if out=$("$SRC/install.sh" "$stack" "$t" --reset-defaults ${stack_args[@]+"${stack_args[@]}"} 2>&1); then
        grep -q 'parity: OK' <<<"$out" || bad "$label: skill parity check did not report OK"
        before=$fail
        check "$t" "$label" "$stack"
        if [ "$fail" -eq "$before" ]; then note "✓" "$label"; fi
      else
        bad "$label: install failed"
        printf '%s\n' "$out" | tail -5 | sed 's/^/           /'
      fi
    done
  done
done

seed_lifecycle
docs_name_real_files "$OUT/fx/go" "shipped docs name only files that exist"
process_companions_are_reachable "$OUT/fx/go" "every process/ companion is non-empty and globbed by a skill or agent"
reset_defaults_scope
parity_list_covers_kit_skills
parity_excludes_only_tier0_process_docs
messaging_doc_coverage
vscode_chat_keys
claude_md_excludes
foreign_instructions_report
codex_config_toml
codex_config_rejects_triple_quote
foreign_harness_files
lint_never_wipes_target
stack_yml_describes_its_tree
stack_module_seeds
external_stack_roots
convention_variants
backend_core_is_neutral_and_wired
decision_hook_is_wired
ships_only_what_is_tracked common stacks
root_stays_uninstalled
plan_lint_gate

# ── the overlay's own checks ─────────────────────────────────────────────────────────────────
# Sourced, not executed, so a hook shares this shell: note, bad, $fail, $SRC, $OUT, $ONLY, $OVERLAY and
# every helper above. A hook defines its checks and calls them at its top level.
if [ -n "$OVERLAY" ]; then
  hooks_run=0
  for hook in "$OVERLAY"/verify.d/*.sh; do
    [ -f "$hook" ] || continue
    hooks_run=$((hooks_run + 1))
    # shellcheck disable=SC1090
    . "$hook"
  done
  # An overlay is worth running for its stacks alone (they were installed and checked above), so only one
  # with neither stacks/ nor verify.d/*.sh is a mistake — most likely a wrong directory.
  if [ "$hooks_run" -eq 0 ]; then
    if [ -d "$OVERLAY/stacks" ]; then
      note "-" "overlay $OVERLAY ships stacks/ but no verify.d/*.sh — its stacks join the per-stack run, no private checks to run"
    else
      bad "overlay $OVERLAY has neither stacks/ nor verify.d/*.sh"
    fi
  fi
else
  note "-" "overlay checks skipped (no --overlay <dir>)"
fi

# Clean up the sandbox on success. These are complete, real-looking INSTALLED trees — .agent-kit/,
# .claude/skills/, conventions/ — and leaving a dozen of them in the repo invites reading one as kit
# source. That has already produced a confident audit finding about a file the kit does not ship.
# On FAILURE they stay: inspecting the target is how you diagnose a failing check.
if [ "$fail" -eq 0 ]; then
  rm -rf "$OUT"
  echo "PASS"
else
  echo "FAIL ($fail)"
  echo "  ('$OUT' kept for inspection — delete it before auditing the kit; it is install output, not source)" >&2
  exit 1
fi
