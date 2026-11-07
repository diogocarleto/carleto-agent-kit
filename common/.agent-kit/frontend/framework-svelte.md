# Svelte 5 — the modern standard

**Prescriptive** — the shape a new Svelte project starts from, not a survey of what Svelte permits.
Written against **Svelte 5.57 / SvelteKit 2.70** (SvelteKit 3 is still `next`), verified 2026-09-22.

Read with `.agent-kit/frontend/core.md`, whose invariants are **not** restated here; where the stack
ships `conventions/frontend/`, that doc **wins** over this one. Anything svelte.dev answers is left to
svelte.dev — what follows is the shape chosen among several that work, and what fails silently if you
pick another.

## Decide first: SPA or SvelteKit

They have different correct answers for data, and carrying one's answer into the other is the expensive
mistake here. Declare which this project is, and apply it everywhere.

| | Plain Svelte SPA (Vite + client router) | SvelteKit |
|---|---|---|
| Read | service module over one shared HTTP client | `load()` in `+page.js` / `+page.server.js` |
| Write | service call from a component or state module | form action + `use:enhance` |
| Page/route state | the router's own | `$app/state` |

⚠ **A module-level HTTP client singleton is right on an SPA and wrong inside `load()`.** The `fetch`
SvelteKit hands to `load` inherits the request's `cookie`/`authorization` on the server, resolves
relative URLs, routes internal `+server` calls straight to the handler, and replays its response from
the rendered HTML during hydration instead of re-requesting. A singleton bypasses all four — and only
under SSR, which the dev browser hides. **Write each service as a function taking `fetch`**, so a `load`
and an event handler can both call it.

⚠ **Module scope on the server is shared by every user.** A `$state` object at the top level of a
`.svelte.ts` is per-tab in the browser and per-*process* during SSR — one user's data rendered into
another's page. Per-user state travels through the load chain or `setContext`, never a module singleton
read during SSR.

⚠ **`load()` is pure.** Return the data; never write it into a shared module or store from there.

**Remote functions** (`.remote.ts` — `query` · `form` · `command` · `prerender`) are experimental behind
two opt-in config flags, and they are a *different shape* for both loading and mutating. Adopt them as a
project-wide decision or not at all; half a codebase on each is two mental models.

## TypeScript

- `.ts` and `.svelte` only. No `any`. `svelte-check` runs in CI, not just the editor.
- ⚠ **Annotate the `$props()` destructure.** Svelte declares `$props(): any` (still true at 5.57.1), so a
  prop with no default is an *explicit* `any` that `noImplicitAny` cannot flag, while one with a default
  infers from it — `svelte-check` is green either way. Green is not evidence: this is `core.md`'s
  declare-at-the-boundary rule with the compiler on the wrong side of it.
- On SvelteKit, take load and action types from the generated `./$types`. A hand-written return type for
  a `load` is a second copy of the contract, and it drifts.
- `?:` and `| null` carry `core.md`'s absent-vs-null distinction into the type system, and are not
  interchangeable: typing a meaningful null as `?:` is exactly what invites `?? 0`.

## Services

`core.md`'s bridge rules apply unchanged. Two Svelte-side consequences:

- Service modules are plain `.ts` — no runes, no state. `.svelte.ts` is for state, not for transport.
- Take `fetch` as a parameter even on an SPA: it costs nothing there and is the only thing that makes
  the module usable from a `load` later.

## Where state and orchestration live

`core.md` leaves the home of stateful orchestration to the stack. **On Svelte 5 it is a `.svelte.ts`
rune module**, exported as one object — not `svelte/store`. Stores stay right only for a stream you do
not own, where you need manual subscribe/unsubscribe (RxJS interop, a socket).

⚠ **A reassigned `$state` binding cannot be exported.** Importers bind the value at import time and never
see the reassignment — no error, the UI simply stops updating. Export an object and mutate its
properties, or export a getter.

## Runes

| Legacy — forbidden in new code | Runes |
|---|---|
| `export let x` | `let { x }: Props = $props()` |
| `$: y = expr` | `const y = $derived(expr)` |
| `$: { sideEffect() }` | `$effect(() => sideEffect())` |
| `<slot>` / `$$slots` | `{@render children?.()}` |
| reactive `let x = v` | `let x = $state(v)` |
| `createEventDispatcher` | callback props |
| `svelte/store` for your own state | a `.svelte.ts` module |
| `$app/stores` | `$app/state` |

- **`$derived` computes; `$effect` never synchronises state.** An effect that assigns to `$state` is a
  second source of truth that lands a tick late and can loop. `$derived.by` for a multi-statement
  derivation.
- **`$effect` is for the world outside Svelte** — widgets, canvas, imperative subscriptions — and returns
  a teardown for everything it creates. That teardown runs before *every* re-run, not only on destroy.
- ⚠ **Every tracked read inside an effect is a dependency**, including one made through an object you only
  meant to pass along — which is how an effect re-runs on a field it does not use. Read the narrow thing;
  `untrack()` the rest. `$inspect.trace()` as the function's first statement reports what actually fired
  it (dev-only, and a noop in production — like `$inspect` itself).
- **`$state` is a deep proxy.** `$state.raw` for large collections you replace rather than mutate;
  `$state.snapshot(x)` before handing state to anything that does not expect a proxy (`structuredClone`,
  chart/map/editor libraries). That one fails at runtime, not at compile time.
- `$bindable` only for a genuine two-way input; otherwise a one-way prop plus a callback prop.

## Components

- **Attachments over actions.** `{@attach fn}` (5.29+) is the current shape — reactive, and passable as a
  prop; the docs now steer `use:` toward it. New code uses attachments.
- ⚠ **An attachment's side effect runs on every mount.** `{@attach (el) => el.focus()}` fires again when
  state a parent keeps re-mounts the element (a filter, a reload) — stealing focus. Focus in the handler
  of the act that opens it: `await tick()`, then `.focus()`.
- **Third-party widgets** — `core.md`'s rule, expressed here: never hand the widget the node captured by
  `bind:this`. Create a throwaway child *inside* the attachment, mount into that, and in the teardown
  empty the host unconditionally. Pass `$state.snapshot()`, never the proxy.
- **Key any `{#each}` whose rows hold state** — `{#each rows as row (row.id)}`. Unkeyed, Svelte updates by
  index, so an input or a stateful child keeps the previous row's value after a sort or a delete.
- `{@html}` is not escaped. Sanitise anything that came from a user or an API, or do not use it.

## Errors

`core.md`'s surfacing rule, expressed on SvelteKit:

- `error(status, body)` from a load renders the nearest `+error.svelte`; `handleError` is where
  unexpected ones land, and where telemetry hooks in.
- Validation **returns `fail(…)`** with a 4xx rather than throwing — and never echoes the submitted
  secret back in that payload.
- `use:enhance` with no callback resets the form and invalidates on success. Supply a callback and you
  own both; a submit that looks successful over a stale page is this rule being skipped.
- `<svelte:boundary>` (5.3+) catches errors during rendering and in effects, and nothing else — not event
  handlers, not your own `await`. Those still need their own catch onto the app's notification path.

## Styles and layout

`core.md`'s mobile-first and no-fixed-pixel rules apply as written. Svelte specifics:

- A component's `<style>` is scoped by a hash class that adds 0-1-0 specificity. A selector the compiler
  cannot see used is **pruned from the output** and reported as `css_unused_selector` — a real signal: a
  selector aimed at markup from `{@html}` or from a child component needs `:global(…)`, or it ships
  nothing.
- App-wide CSS belongs in the app stylesheet, not in a `:global` block inside a leaf component.

## Testing

- Vitest for units and components, Playwright for E2E; `sv add vitest` wires the client/server split.
  Component tests run either in Vitest Browser Mode with `vitest-browser-svelte` or in jsdom with
  `@testing-library/svelte` — pick one per project and keep it.
- ⚠ **A test file using runes must have `.svelte` in its name** (`totals.svelte.test.ts`) — that is what
  puts it through the Svelte transform. Without it the runes never resolve, and the failure reads like a
  missing import rather than a misnamed file.
- Effects do not run outside a component: wrap the subject in `$effect.root()` and drive it with
  `flushSync()`, or nothing you assert on ever updates.

## Documentation

TSDoc bar and budget: `.agent-kit/common/process/authoring/`. Document `.svelte.ts` modules and exported
utilities; components get none by default, since props and their types already carry it. Spend the prose
allowance on `$effect` teardown and on which module owns a piece of derived state.
