# =============================================================================
# Codex CLI — Agent Context Sync
# =============================================================================
#
# This project shares AI context across four checked-in CLI/IDE surfaces:
#   - Claude Code  → reads .claude/CLAUDE.md  (uses native @file imports)
#   - Codex CLI    → in a TRUSTED project, reads .codex/config.toml's developer_instructions (no
#                    import support — set to the full concatenated content, same body as
#                    .codex/AGENTS.md below). Untrusted, Codex ignores config.toml and falls back to
#                    the project's own root AGENTS.md. Codex never auto-loads .codex/AGENTS.md itself —
#                    it stays the readable copy; /peer-dispatch points a peer at it explicitly.
#   - Cursor       → reads .cursor/rules/agent-kit.mdc (alwaysApply rule; we can't
#                    rely on eager @file expansion, so it INLINES like Codex). Cursor
#                    also auto-discovers skills from .claude/skills + .codex/skills,
#                    so only the Tier-0 always-on context is synced here.
#   - VS Code /    → reads .github/copilot-instructions.md (no @import expansion, so it
#     Copilot        INLINES the Tier-0 context like Codex/Cursor). VS Code auto-discovers
#                    skills from .claude/skills and agents from .claude/agents natively, so
#                    only the Tier-0 always-on context is synced here.
#
#                    Verified against VS Code 1.134's own bundle, since the docs state none
#                    of it: the instructions parser resolves file references from Markdown
#                    links and #file: ONLY -- Claude's @path is not a reference, and fenced
#                    blocks are skipped. Following those links is gated on
#                    chat.includeReferencedInstructions, whose default is FALSE (and which is
#                    workspace-trust restricted), so a link-based copilot-instructions.md
#                    would silently carry no Tier-0 at all. Hence: inline, don't link.
#                    Corollary -- chat.useClaudeMdFile defaults to TRUE, so VS Code would
#                    otherwise read .claude/CLAUDE.md and inject it with every @import
#                    unresolved: a pointer list with no content. chat.useAgentsMdFile also
#                    defaults TRUE, loading the project's own root AGENTS.md beside this
#                    generated file. That is why the seeded .vscode/settings.json pins both
#                    false; do not "clean that up".
#                    (chat.useAgentSkills defaults true and its default locations include
#                    .claude/skills, so skill auto-discovery above needs no setting.)
#
# Local models served by LM Studio should run through one of those harnesses
# (typically Codex with --oss), so they inherit the same .codex/.claude docs.
#
# The single source of truth is the topic files under .agent-kit/ (shared,
# vendored) and .agent-kit-local/ (project-specific: architecture, build).
# Claude picks up changes automatically via @imports.
# Codex sync is intentionally manual in this repo and requires running this
# Makefile after editing any shared topic file.
#
# Targets:
#   sync-agents              sync-generate + validate-skills — the everyday entry point
#   sync-generate            regenerates AGENTS.md + .cursor/rules/agent-kit.mdc +
#                            .github/copilot-instructions.md + code-reviewer.md, WITHOUT the parity
#                            lint. What install.sh and any add-on installer call: a lint must not fail an
#                            install after the kit-owned trees have already been wiped.
#   validate-skills          only the parity check (no regeneration)
#
# Usage (from project root):  make -C .codex sync-agents
# Usage (from .codex/):       make sync-agents
# =============================================================================

# Docs now live under three roots (relative to .codex/):
#   CONV   shared convention topics
#   PROC   shared process topics (depth-1 Tier-0 + the authoring/ review/ planning/ dispatch/ reference/
#          companions)
#   LOCAL  project-local always-on "context" tier (architecture, build-commands)
CONV  = ../.agent-kit/common/conventions
PROC  = ../.agent-kit/common/process
LOCAL = ../.agent-kit-local/context
# PERSIST is the neutral persistence standard — a common/ dir beside conventions/, not a layer in it
PERSIST = ../.agent-kit/persistence
# FRONT is the same for the frontend framework's neutral standard
FRONT = ../.agent-kit/frontend
# BACK is the language-neutral backend layer (core.md = the code-style kernel). Unlike PERSIST and FRONT it
# is no variant family: every depth-1 *.md in it is read, so a further concern is a file drop here
BACK = ../.agent-kit/backend

# process/ mirrors conventions/: DEPTH-1 is the always-on set, and every nested dir is a companion
# globbed by the one audience that needs it. That is what keeps this Makefile free of doc filenames.
#   process/*.md        Tier-0, always-on   → TIER0_DOCS below, and CLAUDE.md's @import chain
#   process/authoring/  doc & comment standards → globbed by every skill that writes docs
#   process/review/     review checklists       → globbed by the reviewers
#   process/planning/   the planning process    → globbed by feature-plan + feature-execute
#   process/dispatch/   dispatching inside a plan → globbed by feature-plan, feature-execute, peer-dispatch
#   process/diagrams/   diagram rules           → globbed by feature-plan + module-extract; deliberately NOT in
#                                                 CODE_REVIEWER_DOCS (no reviewer judges diagrams; ~1.2k tokens per review)
#   process/reference/  never globbed; named individually or read on demand
#
# The Tier-0 always-on docs, in load order — the source of truth for the three INLINING harnesses.
# Both generators concatenate this list, so adding or removing a Tier-0 doc is one edit here.
# ⚠ Claude does not read it: it loads the same set through CLAUDE.md's @import chain, which is a
# second list. Change one and you must change the other — verify.sh's check() compares them, because
# every way they can disagree is silent (a doc dropped here still loads on Claude; one added here
# becomes always-on everywhere but Claude).
# ⚠ Enumerated, not $(wildcard $(PROC)/*.md), for two reasons: the order is the reading order, and a
# glob would sweep any file that ever lands in process/ (a README, a stray note) into the always-on
# context of all four harnesses — the most expensive place in the kit to be wrong.
TIER0_DOCS = $(LOCAL)/build-commands.md \
             $(LOCAL)/architecture.md \
             $(PROC)/planning.md \
             $(PROC)/agent-dispatch.md \
             $(PROC)/shell-hygiene.md \
             $(PROC)/terminology.md
OUT  = AGENTS.md
AGENTS_DIR = agents
CODE_REVIEWER_OUT = $(AGENTS_DIR)/code-reviewer.md
# Cursor's always-on rule (generated, like AGENTS.md). Lives outside .codex/, so the
# path is relative to .codex/ where this Makefile runs.
CURSOR_OUT = ../.cursor/rules/agent-kit.mdc
# VS Code Copilot's always-on instructions (generated, like AGENTS.md). VS Code reads
# .github/copilot-instructions.md natively but does NOT expand Claude's @import chain, so the
# Tier-0 standing context must be INLINED. Unlike AGENTS.md it needs no skill-pointer list
# (VS Code auto-discovers the kit's skills from .claude/skills/) and no frontmatter — just the
# concatenated Tier-0 docs. Lives outside .codex/, so the path is relative to .codex/.
COPILOT_OUT = ../.github/copilot-instructions.md
# Codex's own trust-gated settings file (a SEED — install.sh seed_once, not overlaid here). Lives
# inside .codex/, so no relative prefix, unlike the three paths above.
CODEX_CONFIG = config.toml
# Overridable so a caller without `python3` on PATH (but some other interpreter name) can still run
# this target; sync-codex-config below also degrades gracefully when nothing resolves at all.
PYTHON ?= python3

# Claude/Codex skill parity: skills are intentionally different prose for
# different agents — they're not auto-generated from each other. We only
# validate that the set of .agent-kit*/ docs (and glob dirs) referenced in each
# pair stays in lockstep. Each reference is compared by its path from .agent-kit
# onward with trailing slashes normalized, so a glob dir like conventions/backend/
# compares equal across harnesses and a layer skill that references a dir (not
# enumerated files) is still checked.
CLAUDE_SKILLS_DIR = ../.claude/skills
CODEX_SKILLS_DIR = skills
# Every KIT skill is validated: its Claude and Codex copies must name the same convention files.
# Deliberately ENUMERATED, not globbed — and the enumeration is the whole point. In a consumer
# .claude/skills/ also holds add-on skills (delivered by an add-on installer) and the consumer's own
# hand-written ones; a wildcard would validate those too and break `make sync-agents` over a difference
# the kit has no say in. Naming the kit's own set is what separates "ours" from "theirs" in a tree where
# both live side by side. The exception is an add-on skill: its installer stamps the skill dir with a
# .synced-from, and validate-skills checks this list PLUS every stamped skill dir (in either harness's
# tree, so a skill stamped on one side only is still caught). A project's own
# skill carries no stamp, so it is still never validated.
# ⚠ Adding a kit skill therefore DOES require adding it here. verify.sh asserts this list equals the
# set shipped in common/.claude/skills/, so the enumeration cannot silently fall behind.
SKILL_NAMES_VALIDATE = backend brainstorm dcr feature-execute feature-plan frontend fullstack \
                       messaging migrate mobile module-extract modules peer-dispatch scaffold structure-extract \
                       ui-design ui-detect ui-extract

# Concatenates only the always-on standing context into AGENTS.md — this mirrors
# Claude's CLAUDE.md @import chain exactly (build-commands, architecture, planning,
# agent-dispatch, shell-hygiene, terminology). Conventions are NOT inlined here: Codex lazy-loads
# them via its native Agent Skills (see "## Codex Skills" in the header), globbing
# conventions/<layer>/ only on skill invoke — parity with Claude. code-review.md is
# likewise reviewer-only and lives in code-reviewer.md, not here.
# Run after editing any standing-context topic file under .agent-kit/ or .agent-kit-local/.
# The generation targets as ONE name. Both installers run generation WITHOUT validate-skills — a lint
# must not abort an install after step 1 has wiped the target — so without this they each re-enumerate
# the list, giving three copies that must agree and nothing gating them. Adding a generated surface is
# one edit here. (Order is preserved: prerequisites run left to right in a single make invocation.)
# sync-codex-config is listed here, not only under sync-agents below, because install.sh calls
# sync-generate directly (skipping the validate-skills lint) — the developer_instructions block must
# land on every install, not only on a manual `make sync-agents`.
sync-generate: sync-main-context sync-addon-skills sync-cursor-rule sync-copilot-instructions sync-code-reviewer-agent sync-codex-config

sync-agents: sync-generate validate-skills

# ⚠ The skill-pointer list below is one SINGLE-QUOTED printf. A lone apostrophe anywhere inside it —
# "this stack's recipe", "Codex's skills" — closes the quote and breaks the recipe, which fails
# sync-generate, which fails install.sh AFTER step 1 has already wiped the target. So it takes down
# every stack, not just the harness whose line you edited. Write "the recipe of this stack" instead,
# and re-run ./verify.sh after touching this block; it catches it immediately, but only if you run it.
sync-main-context:
	@printf '# Project Instructions\n\nFollow all rules below precisely.\n\n## Codex Skills\n\n- `.codex/skills/backend/SKILL.md` - Load backend conventions for focused work: the language-neutral backend invariants and the engine-neutral persistence invariants always, plus the standard for the declared database and the backend conventions of this stack.\n- `.codex/skills/messaging/SKILL.md` - Companion to backend for event-messaging work: the framework-neutral invariants always, plus the concrete messaging conventions of this stack when it ships them.\n- `.codex/skills/frontend/SKILL.md` - Load frontend conventions for focused work: the framework-neutral invariants always, plus the standard for the declared frontend framework and the frontend conventions of this stack when it ships them.\n- `.codex/skills/mobile/SKILL.md` - Load mobile conventions for focused work (no-ops when the stack ships no mobile layer).\n- `.codex/skills/ui-design/SKILL.md` - Reusable UI design workflow for shaping, crafting, auditing, polishing, hardening, or adapting web, mobile, native, and design-system work.\n- `.codex/skills/ui-extract/SKILL.md` - Generate or refresh module-specific UI memory (`modules/<module>/ui.md`).\n- `.codex/skills/ui-detect/SKILL.md` - Run the mechanical "AI tells" detector on changed/named UI files (pure neutrals, default fonts, dated easing). Called from the `/ui-design` verify phase; also invokable manually.\n- `.codex/skills/fullstack/SKILL.md` - Load both backend and frontend conventions for cross-cutting work.\n- `.codex/skills/scaffold/SKILL.md` - Scaffold a new backend domain (when the stack provides scaffold recipes).\n- `.codex/skills/dcr/SKILL.md` - Scaffold a Data Change Request or one-shot migration: the framework-neutral invariants always, plus the DCR recipe of this stack when it ships one.\n- `.codex/skills/migrate/SKILL.md` - Migrate legacy code onto the conventions of this stack, one unit at a time, proving equivalence with characterization tests: the framework-neutral invariants always, plus the migration layer of this stack when it ships one.\n- `.codex/skills/feature-plan/SKILL.md` - Plan a committed feature and update `.agent-kit-local/planning`.\n- `.codex/skills/feature-execute/SKILL.md` - Drive a Ready/In Progress feature plan through implementation: walks its Execution Plan phases via the per-phase loop in .agent-kit/common/process/planning/ (dispatch at each phase Tier/Effort, review at Reviewer tier, fix, test, checkpoint). Counterpart to feature-plan.\n- `.codex/skills/brainstorm/SKILL.md` - Explore and validate open-ended ideas at three registers (Talk/Shape/Forge); Forge materializes survivors into planning/ideas/.\n- `.codex/skills/peer-dispatch/SKILL.md` - Delegate a file-disjoint sub-task to a peer model: Claude via claude -p, hosted Codex via codex exec -m, or a local LM Studio model via codex exec --oss (opt-in; see .agent-kit/common/process/dispatch/peer-harness.md).\n- Loading how a module works (purpose, SPIs, internals, gotchas) → `.codex/skills/modules/SKILL.md`\n- Generating or refreshing a module memory doc → `.codex/skills/module-extract/SKILL.md`\n- Generating or refreshing the structure manifest (`structure.yml`) → `.codex/skills/structure-extract/SKILL.md`\n- `.codex/agents/code-reviewer.md` - Review changed code with findings-first output.\n- `.codex/agents/test-runner.md` - Pick and run the narrowest useful test scope.\n\n## Sync Model\n\nCodex sync is intentionally manual in this repo. After editing any shared topic file under `.agent-kit/` or `.agent-kit-local/` (including `.agent-kit/common/process/reference/code-reviewer-agent-header.md`), run `make -C .codex sync-agents`.\n\n<!-- Generated from .agent-kit/ + .agent-kit-local/. Edit topic files there, then run: make -C .codex sync-agents -->\n\n' > $(OUT)
	@for f in $(TIER0_DOCS); do \
		printf '\n---\n\n' >> $(OUT); \
		cat $$f >> $(OUT) || exit 1; \
	done
	@echo "$(OUT) regenerated."

# Cursor reads .cursor/rules/*.mdc natively. We CANNOT rely on eager @file expansion
# under alwaysApply (undocumented), so the rule INLINES the same Tier-0 body as AGENTS.md
# (just prefixed with .mdc frontmatter) — guaranteeing the standing context is present every
# session. Cursor already auto-discovers the kit's skills from .claude/skills + .codex/skills,
# so no skill content is inlined here. Depends on sync-main-context so $(OUT) is fresh first.
# Only agent-kit.mdc is written; any project-authored .cursor/rules/*.mdc are left untouched.
# Add-on skills (from an add-on installer) land in skills/ AFTER the kit generated this file, so their
# pointer lines are DISCOVERED here rather than enumerated above. Without this, `make sync-agents` — the
# command the kit tells everyone to run — silently deletes them and Codex loses every add-on skill it has.
sync-addon-skills: sync-main-context
	@for d in skills/*/; do \
		n=$$(basename $$d); \
		[ -f "$$d/SKILL.md" ] || continue; \
		grep -q "skills/$$n/SKILL.md" $(OUT) && continue; \
		grep -q '^## Additional Skills' $(OUT) || printf '\n## Additional Skills\n\n' >> $(OUT); \
		printf -- '- `.codex/skills/%s/SKILL.md` - %s\n' "$$n" \
			"$$(sed -n 's/^description:[[:space:]]*//p' $$d/SKILL.md | head -1)" >> $(OUT); \
	done

sync-cursor-rule: sync-main-context sync-addon-skills
	@mkdir -p $(dir $(CURSOR_OUT))
	@printf -- '---\nalwaysApply: true\n---\n\n' > $(CURSOR_OUT)
	@cat $(OUT) >> $(CURSOR_OUT)
	@echo "$(CURSOR_OUT) regenerated."

# VS Code Copilot reads .github/copilot-instructions.md natively but does NOT expand Claude's
# @import chain, so the Tier-0 standing context must be INLINED (same as AGENTS.md / the Cursor
# rule). It does NOT cat $(OUT): AGENTS.md carries the "## Codex Skills" pointer list whose
# .codex/skills/ paths are wrong for VS Code, and VS Code auto-discovers the kit's skills from
# .claude/skills/ anyway — so this inlines only the Tier-0 docs, no skill list, no frontmatter.
# Only copilot-instructions.md is written; any project-authored .github/ files are left untouched.
# ⚠ But THAT file is the exception to its own sentence. AGENTS.md and the Cursor rule sit at
# kit-specific paths nobody else writes; this is the GitHub-documented repo-wide instructions
# filename, so a consumer may well already have one — and overwriting it destroyed it silently.
# Back a non-generated file up ONCE before taking the name over. The marker test is what makes it
# once: on every later run the file is our own output, so the backup is never overwritten with it.
sync-copilot-instructions:
	@mkdir -p $(dir $(COPILOT_OUT))
	@if [ -f $(COPILOT_OUT) ] && ! grep -q 'GENERATED by `make -C .codex sync-agents`' $(COPILOT_OUT) 2>/dev/null; then \
		cp $(COPILOT_OUT) $(COPILOT_OUT).pre-agent-kit; \
		echo "⚠ preserved the project's own copilot-instructions.md → copilot-instructions.md.pre-agent-kit"; \
	fi
	@printf '# Project Instructions\n\nFollow all rules below precisely. This file is GENERATED by `make -C .codex sync-agents` — do not edit by hand.\n' > $(COPILOT_OUT)
	@for f in $(TIER0_DOCS); do \
		printf '\n---\n\n' >> $(COPILOT_OUT); \
		cat $$f >> $(COPILOT_OUT) || exit 1; \
	done
	@echo "$(COPILOT_OUT) regenerated."

# Codex's own instructions delivery: a TRUSTED project's .codex/config.toml carries this same Tier-0
# body as developer_instructions (see the header note above and README). Depends on $(OUT) being
# final, like the Cursor/VS Code targets above. The ''' check runs per TIER0_DOCS file, not against
# the already-concatenated $(OUT), so a failure can name the ONE doc to fix rather than "somewhere in
# AGENTS.md". install.sh's strip_codex_config_block (same markers, kept in sync by hand) is what makes
# the generated block invisible to the seed's "is this file untouched" check.
# ⚠ Why a separate .py file, not an inlined heredoc (the pattern install.sh's
# vscode_chat_keys_py uses): this Makefile's recipes must stay compatible with GNU Make 3.81
# (macOS's bundled make — no .ONESHELL). Every recipe line there is its own shell invocation, so a
# heredoc body spanning non-tab-indented lines breaks the parser before any shell runs it — proven
# empirically, not a style preference. A checked-in script sidesteps it entirely.
sync-codex-config: sync-main-context sync-addon-skills
	@for f in $(TIER0_DOCS); do \
		if grep -qF "'''" $$f; then \
			echo "ERROR: $$f contains '''  — would end the developer_instructions TOML literal early" >&2; \
			exit 1; \
		fi; \
	done
	@if ! command -v $(PYTHON) >/dev/null 2>&1; then \
		echo "⚠ codex: .codex/config.toml developer_instructions not written — no python3 on PATH"; \
	else \
		$(PYTHON) sync-codex-config.py $(CODEX_CONFIG) $(OUT); \
	fi

# Codex has no @file imports and the reviewer can't lazy-load mid-review, so the
# reviewer agent file inlines every convention doc it must apply. These now glob the
# layer dirs (depth-1, so messaging/ and recipes/ companions are excluded) — the
# Claude reviewers (.claude/agents/{backend,frontend,fullstack}-code-reviewer.md)
# glob the same dirs, so adding/renaming a convention doc needs no edit here.
# doc-style.md is inlined too: the stack conventions carry only a *pointer* to it for the
# doc-comment budget, and this reviewer cannot follow a pointer mid-review.
# ⚠ $(CONV)/*/*.md is DEPTH-1 of every layer by construction — it matches backend/*.md and
# frontend/*.md but not backend/messaging/*.md, which is right: companions are skill-gated and must
# not be inlined into the reviewer. It also means a new layer needs no edit here. Do not 'fix' it
# into a recursive glob, and do not go back to naming layers — the previous enumeration silently
# excluded /mobile's docs until someone noticed.
CODE_REVIEWER_DOCS = \
	$(wildcard $(PROC)/review/*.md) \
	$(wildcard $(PROC)/authoring/*.md) \
	$(LOCAL)/architecture.md \
	$(wildcard $(CONV)/*/*.md) \
	$(wildcard $(BACK)/*.md) \
	$(PERSIST)/core.md \
	$(wildcard $(PERSIST)/persistence-*.md) \
	$(FRONT)/core.md \
	$(wildcard $(FRONT)/framework-*.md)
# ⚠ $(BACK) is globbed (depth-1) like $(CONV): it holds no variants, so a new neutral backend doc needs
# no edit here. Depth-1 is also what keeps its reference/ out, which is on-demand.
# ⚠ The neutral persistence and frontend dirs are each a VARIANT FAMILY beside an always-read core.md,
# so each is named file by file: core.md, then only the depth-1 persistence-*.md or framework-*.md —
# never reference/, which is on-demand.
# Every variant is inlined, because this file is generated at install time and structure.yml is project-
# owned and can change later (/structure-extract): selecting here would freeze a stale choice. The
# reviewer header tells the reviewer to apply only the variant matching frameworks.database (in this
# dir and in conventions/backend/) and frameworks.frontend (in FRONT and in conventions/frontend/).

# A wildcard over a missing or empty dir expands to NOTHING — the cat loop below then never runs for
# it and its `|| exit 1` cannot fire, so a renamed or emptied review/ would ship a reviewer with no
# checklist and still exit 0. These two dirs are the reviewer's whole judgement, so assert them
# explicitly. NOT conventions/backend|frontend: a stack legitimately ships one, the other, or a
# placeholder. (This comment sits OUTSIDE the recipe on purpose — inside one, make expands variables
# and echoes the line even though the shell treats it as a comment.)
# Every inlined doc is preceded by a `<!-- source: <path from the install root> -->` line. Inlined, the
# neutral .agent-kit/backend/ docs and the stack's conventions/backend/ docs are distinguishable by
# nothing else, and they share names (design-principles.md, logging.md). verify.sh keys on this marker.
sync-code-reviewer-agent:
	@mkdir -p $(AGENTS_DIR)
	@for d in $(PROC)/review $(PROC)/authoring; do \
		ls $$d/*.md >/dev/null 2>&1 \
			|| { echo "ERROR: $$d/ has no *.md — the code reviewer would ship with no checklist" >&2; exit 1; }; \
	done
	@cat $(PROC)/reference/code-reviewer-agent-header.md > $(CODE_REVIEWER_OUT)
	@for f in $(CODE_REVIEWER_DOCS); do \
		printf '\n---\n\n<!-- source: %s -->\n\n' "$${f#../}" >> $(CODE_REVIEWER_OUT); \
		cat $$f >> $(CODE_REVIEWER_OUT) || exit 1; \
	done
	@echo "$(CODE_REVIEWER_OUT) regenerated."

# Verifies that for each kit skill, the set of .agent-kit*/ doc paths and glob dirs
# referenced by .claude/skills/<name>/SKILL.md matches the set referenced by
# .codex/skills/<name>/SKILL.md. Each matched reference is normalized to its path
# from .agent-kit onward with trailing slashes stripped (so a dir glob like
# conventions/backend/ compares as conventions/backend). Exits non-zero on drift.
#
# The Tier-0 process docs are EXCLUDED — the one legitimate difference. Claude loads process/*.md
# through CLAUDE.md's @import chain, so its skills need not name them, while Codex has no imports and
# must name them explicitly. Comparing them raw reports that by-design asymmetry as drift
# (feature-execute and module-extract both trip it). The add-on's own checks apply the identical
# exclusion.
# The exclusion is by DEPTH, not by filename: process/<doc>.md is always-on, process/<dir>/<doc>.md is
# a companion. So it needs no doc names and follows the layout automatically — and it can never
# over-exclude, because every companion (authoring/doc-style.md, review/code-review.md, …) stays
# gated. Excluding the whole process/ directory instead would silently drop all of them; 7 kit skills
# reference the authoring/ glob alone.
#
# <> IS PART OF THE PATH CHARSET, and each <placeholder> is then normalized to a bare <>. Without the
# charset the match STOPS at the first '<', so every path below a placeholder segment was invisible:
# .agent-kit-local/modules/<module>/internals.md and .../<module>/<domain>.md both collapsed to
# .agent-kit-local/modules, and the pair diffed clean while the two mirrors read different files.
# That silently unguarded the whole module-memory surface, whose paths are ALL of that shape.
# Normalizing is what makes including <> safe: it collapses a cosmetic <module> vs <module-name>
# rename while keeping internals.md distinguishable from <domain>.md — the difference that matters.
#
# The extension is (\.[A-Za-z0-9]+)* — a dot must be FOLLOWED by alphanumerics — never a bare '.' in
# the charset. A charset dot is greedy and eats the sentence period after an unbackticked path, so
# `see .agent-kit/planning/TEMPLATE.md.` extracts a phantom TEMPLATE.md. that differs from the same
# path written mid-sentence: false drift. The repeated group also keeps multi-dot names whole
# (structure.template.yml, detect.mjs), which a plain (\.md)? suffix would truncate at the first dot.
validate-skills:
	@status=0; tmp=$$(mktemp -d); names="$(SKILL_NAMES_VALIDATE)"; \
	for s in $(CODEX_SKILLS_DIR)/*/.synced-from $(CLAUDE_SKILLS_DIR)/*/.synced-from; do \
		[ -f "$$s" ] || continue; n=$$(basename "$$(dirname "$$s")"); \
		case " $$names " in *" $$n "*) ;; *) names="$$names $$n" ;; esac; \
	done; \
	for h in $$names; do \
		claude_skill="$(CLAUDE_SKILLS_DIR)/$$h/SKILL.md"; \
		codex_skill="$(CODEX_SKILLS_DIR)/$$h/SKILL.md"; \
		if [ ! -f "$$claude_skill" ]; then echo "WARN: Claude skill missing: $$claude_skill"; status=1; continue; fi; \
		if [ ! -f "$$codex_skill" ]; then echo "WARN: Codex skill missing: $$codex_skill"; status=1; continue; fi; \
		grep -oE '\.agent-kit[a-z-]*/[A-Za-z0-9_/<>-]+(\.[A-Za-z0-9]+)*' "$$claude_skill" | sed -E 's|<[^>]*>|<>|g' | grep -vE '/common/process/[A-Za-z0-9_.-]+\.md$$' | sed 's|/*$$||' | sort -u > "$$tmp/claude"; \
		grep -oE '\.agent-kit[a-z-]*/[A-Za-z0-9_/<>-]+(\.[A-Za-z0-9]+)*' "$$codex_skill"  | sed -E 's|<[^>]*>|<>|g' | grep -vE '/common/process/[A-Za-z0-9_.-]+\.md$$' | sed 's|/*$$||' | sort -u > "$$tmp/codex"; \
		if ! diff -q "$$tmp/claude" "$$tmp/codex" >/dev/null 2>&1; then \
			echo "DRIFT in '$$h' (Claude vs Codex skill doc list):"; \
			echo "  Claude: $$claude_skill"; \
			echo "  Codex:  $$codex_skill"; \
			diff "$$tmp/claude" "$$tmp/codex" | sed 's/^/    /' || true; \
			status=1; \
		fi; \
	done; \
	rm -rf "$$tmp"; \
	if [ $$status -eq 0 ]; then echo "Claude/Codex skill doc-list parity: OK"; fi; \
	exit $$status

.PHONY: sync-agents sync-generate sync-main-context sync-addon-skills sync-cursor-rule sync-copilot-instructions sync-code-reviewer-agent sync-codex-config validate-skills
