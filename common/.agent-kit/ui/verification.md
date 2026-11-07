## UI Verification

Verification is required after UI code changes unless the change is documentation-only or the user explicitly asks not to run checks.

### Baseline

- Run the narrowest relevant type/check/test command.
- Render the changed surface when possible.
- Inspect at least one compact and one expanded size for responsive surfaces.
- Exercise primary actions and state transitions touched by the change.
- Check contrast, overflow, focus, keyboard/touch behavior, loading, empty, error, disabled, and dark/theme states where applicable.
- Check logs/console for runtime errors and failed assets.

### Mechanical checks

After any UI code change you **must** run the mechanical "AI tells" detector on the changed surface before reporting — invoke the `/ui-detect` skill (or run the script directly). It is cheap, deterministic, cross-model, and catches the grep-able subset of `core.md` → "Recognizable AI tells" that a model often overlooks:

```bash
node .agent-kit/ui/detect.mjs            # changed files (git)
node .agent-kit/ui/detect.mjs <files>    # specific files
node .agent-kit/ui/detect.mjs --json     # machine-readable
```

It requires Node on PATH; on a pure native project with no JS toolchain, do the equivalent grep by hand against `core.md` → "Recognizable AI tells" and say you did so. Running the check is mandatory; the findings are advisory. Token/theme files are exempt, so a remaining hit is a real candidate — verify it visually and, in an audit, record it as P1/P2 with a fix direction rather than silently passing. The detector does not replace the visual, accessibility, and responsive checks below. State in the final report that the detector was run and what it returned.

### Web

- Use the local dev server or static preview expected by the project.
- Use browser screenshots or visual inspection for layout-affecting changes.
- Check mobile and desktop viewports.
- Prefer project-provided Playwright, Cypress, Storybook, Axe, Lighthouse, or visual-regression tooling when available.

### React Native

- Use simulator/emulator, Expo preview, component explorer, screenshot tests, or native test tooling when available.
- Check keyboard overlap, safe areas, platform differences, font scaling, dark mode, and long text.

### iOS

- Use previews, simulator, UI tests, or screenshots when available.
- Check Dynamic Type, VoiceOver labels, dark mode, safe areas, and system controls.

### Android

- Use emulator/device, Compose previews, UI tests, or screenshots when available.
- Check font scale, TalkBack labels, dark theme, system insets, and back behavior.

### Reporting

Final responses for UI work must include:

- What was changed
- What was verified
- What could not be verified
- Any remaining UI risk or follow-up

