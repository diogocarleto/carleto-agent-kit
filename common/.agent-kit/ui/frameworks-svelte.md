## Framework: Svelte

Use for Svelte and SvelteKit projects.

### Svelte rules

- Follow the local Svelte version and neighboring component patterns.
- If the project uses Svelte 5, use runes and snippets consistently.
- Keep components focused: rendering and local ephemeral state in components, shared orchestration in stores, pure transformations in utilities.
- Prefer local routing, store, service, and error-handling conventions over new abstractions.
- Do not bypass the project's type system, path aliases, generated types, or design tokens.
- Avoid direct DOM manipulation when Svelte bindings, actions, or component state fit.

### Svelte verification

- Run the project's Svelte/TypeScript check when available.
- Verify rendered components in browser when visual behavior changes.
- Check hydration/client errors, route params, store subscriptions, cleanup, and reactive loops.

