## Framework: React

Use for React, Next.js, Remix, Vite React, and related projects.

### React rules

- Follow local component, hook, state, routing, data-fetching, and styling conventions.
- Keep render logic declarative. Avoid effects for derivations that can be computed during render.
- Use typed props and domain types. Do not use `any` unless local conventions allow it.
- Keep components focused; move reusable behavior into hooks and pure transformations into utilities.
- Respect SSR/server-component/client-component boundaries in frameworks that have them.
- Avoid hydration mismatches, unstable keys, unnecessary global state, and prop drilling that conflicts with local patterns.
- Use accessible native elements before custom ARIA widgets.

### React verification

- Run available type, lint, unit, component, and framework checks.
- Verify browser behavior for interactive, responsive, or stateful UI.
- Check hydration warnings, console errors, Suspense/loading states, and error boundaries.

