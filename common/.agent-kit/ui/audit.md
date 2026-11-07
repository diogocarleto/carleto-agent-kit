## UI Audit

Audit is non-mutating unless the user asks for fixes.

### Severity

- **P0** — blocks task completion, hides content/actions, severe accessibility failure, or broken layout/runtime.
- **P1** — user-visible quality or usability issue that should be fixed before shipping.
- **P2** — polish, consistency, or maintainability issue.

### Required coverage

- Task success: primary action visible, reachable, labeled, and state-aware
- Information architecture: screen hierarchy, grouping, navigation, and orientation
- Layout: responsive behavior, overflow, clipping, text wrapping, layout shift, safe areas, and scroll boundaries
- Accessibility: contrast, focus order, keyboard access, accessible names, semantics, touch targets, screen reader basics
- States: loading, empty, error, disabled, success, stale, offline, permission denied, partial data
- Forms and inputs: labels, validation, error recovery, disabled/submitting state, keyboard type, autocomplete
- Visual system: typography, spacing, color use, icon consistency, density, dark mode, high contrast, reduced motion
- Performance perception: skeletons/spinners, asset loading, interaction latency, expensive animations
- Platform fit: web, mobile, or native conventions respected

### Output

Lead with findings, ordered by severity. Each finding should include:

- Severity: P0, P1, or P2
- Location: file/screen/component when known
- Symptom: what the user experiences
- Fix direction: concrete next action

Then include brief residual risk and what was not verified.

