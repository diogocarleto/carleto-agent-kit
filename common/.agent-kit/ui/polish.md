## UI Polish

Polish fixes concrete quality defects without changing product behavior.

### Focus areas

- Hierarchy: primary, secondary, and tertiary elements read in the intended order
- Spacing: consistent rhythm, edge alignment, internal padding, and related grouping
- Typography: appropriate scale, weight, line height, readable line length, no clipped text
- Color: sufficient contrast, semantic color restraint, theme consistency, no one-note palette
- Controls: recognizable icons, clear labels, disabled/submitting states, touch targets, focus
- States: loading, empty, error, success, selected, hover, active, and pressed states feel designed
- Motion: purposeful, interruptible, reduced-motion friendly, and not masking layout instability. Concrete defaults: 120–200ms for state/hover changes, 200–300ms for enter/exit; ease-out for entrances (e.g. `cubic-bezier(0.2, 0, 0, 1)`), ease-in for exits; never bounce/elastic/overshoot; animate `transform`/`opacity`, not layout properties; under `prefers-reduced-motion` drop to instant or a simple fade
- Copy: concise labels, actionable errors, no in-app explanation of obvious UI mechanics

### Rules

- Patch the smallest visual surface that fixes the issue.
- Prefer existing tokens, utilities, components, and local patterns.
- Do not introduce a new visual language while polishing.
- Verify at least one small and one large viewport or device class when the surface is responsive.

