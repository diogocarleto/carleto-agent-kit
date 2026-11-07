## Platform: Web

Use for browser-based apps, sites, dashboards, tools, games, and webviews.

### Web rules

- Use semantic HTML before ARIA. Add ARIA only when native semantics are insufficient.
- Ensure keyboard access, visible focus, logical tab order, and escape/close behavior for overlays.
- Design mobile-first unless the project explicitly targets desktop-only workflows.
- Avoid fixed layout widths that break small screens. Use responsive constraints, grid/flex, and stable aspect ratios.
- Verify overflow at narrow widths, zoomed text, long strings, nested scroll containers, and sticky/fixed elements.
- Treat browser console errors, failed assets, hydration errors, and broken source maps as verification failures.
- Prefer existing CSS tokens, utility classes, component libraries, and route patterns.

### Web verification

When code changes affect rendered UI:

- Run the project's type/check/test command when available.
- Start the local dev server when needed.
- Inspect in a browser at small and desktop viewport sizes.
- Check interactions, focus, hover/active/disabled states, responsive layout, console errors, and missing assets.

