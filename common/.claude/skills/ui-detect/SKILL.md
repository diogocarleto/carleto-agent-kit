---
name: ui-detect
description: Run the mechanical UI "AI tells" detector on changed or named files and report findings with fix directions. Called from the /ui-design verify phase and invokable manually to catch pure neutrals, default fonts, and dated easing across web (CSS/Svelte/Vue/Angular/React), React Native, iOS, and Android surfaces.
---

Run the deterministic UI "AI tells" detector. This is the same check the `/ui-design` verify phase runs; it is also safe to invoke manually at any time. Cross-model: every CLI calls the one shared script, so results are identical regardless of which agent runs it.

Steps:

1. Scope: use file paths passed as arguments; with none, the script scans git-changed UI files across all supported surfaces (web CSS/SCSS/Svelte/Vue/Angular/React, React Native, iOS Swift, Android Kotlin/Java/XML), skipping backend source and build output.
2. Run it:
   - `node .agent-kit/ui/detect.mjs` — changed files
   - `node .agent-kit/ui/detect.mjs <files>` — specific files
   - `node .agent-kit/ui/detect.mjs --json` — machine-readable
3. Interpret each finding against `.agent-kit/ui/core.md` → "Recognizable AI tells". Token/theme files are already exempt, so a remaining hit is a real candidate, not the project's own palette.
4. Report: map each finding to **P1** (user-visible tell) or **P2** (consistency/polish), with `file:line` and a concrete fix direction. Do not auto-edit unless the user asks.

The detector only covers the grep-able subset (pure neutrals, default fonts, overshoot easing). Running it is **mandatory** in the verify phase; the findings are advisory. It does not replace the visual, accessibility, and responsive checks in `.agent-kit/ui/verification.md`.

Implementation note: `.agent-kit/ui/detect.mjs` is a facade. Add or change framework/platform logic in `.agent-kit/ui/validators/` (`web`, `svelte`, `react`, `angular`, `react-native`, `ios`, `android`), not in the facade.
