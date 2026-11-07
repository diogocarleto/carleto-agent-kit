# React — the standard for a new project

**Prescriptive.** This is the shape to apply, not a survey. Existing code written before it is not a
counter-argument; it either adapts or carries the deviation in its own stack doc.

**Written against React 19.3 (released 2026-09-09) — September 2026.** A frontend standard ages fast:
check that stamp before trusting a rule here, and verify any version-specific API at react.dev.

Read with `core.md`, which carries the framework-neutral invariants — this file says how React expresses
them and adds what is React-only. A stack's own `conventions/frontend/` wins over both.

## Toolchain

- **Start from a framework, not a bare bundler.** react.dev recommends Next.js (App Router), React Router
  (Vite-based), or Expo for native + web; TanStack Start is still beta. Routing, data loading, streaming
  and code-splitting are the framework's job — write them yourself and you maintain a framework you did
  not intend to build.
- **Plain Vite + React + TS is right only for a genuinely SPA-shaped app** — an internal tool, a dashboard
  behind a login, a UI embedded in an existing server. A build tool gives you a SPA and nothing else.
- **TypeScript from the first commit**, `.ts`/`.tsx` only, no `any`. React 19 *removed* `propTypes` and
  `defaultProps` for function components — types are the only contract left.
- **Enable React Compiler and the `eslint-plugin-react-hooks` compiler rules on day one.** react.dev:
  *"New apps should use React Compiler."* Its payoff is conditional on following the Rules of React, and
  the lint rules — not a green build — are what check that.

## State — the decision that shapes everything else

Split by **owner**, not by how widely it is read:

| State | Where it lives |
|---|---|
| **Server state** — anything the backend owns | a query cache (TanStack Query) or the framework's route loader |
| **URL state** — filter, tab, page, sort; anything a user would paste to a colleague | the router's search params |
| **Client state** — drafts, open/closed, selection | `useState`/`useReducer` in the nearest owner |

- ⚠ **Never fetch server state in a `useEffect`.** react.dev names four costs: no server rendering,
  network waterfalls, no preload or cache, and hand-rolled race handling. The failure is silent — a stale
  response landing after a newer one renders wrong data, with no error anywhere.
- **Copying a fetched response into `useState` is the same bug one step later** — it goes stale as soon as
  anything mutates that resource, and nothing invalidates it.
- ⚠ **A global store is not where server state goes.** Redux/Zustand/Jotai solve *client* state; keys,
  invalidation, dedupe and background refresh are the query cache's job. Adopt a store only for shared
  client state a cache does not model.
- **Context is dependency injection, not a state manager.** Every consumer re-renders when the value's
  identity changes — put a service handle or stable config in it, never a frequently-changing value.

## Data access and where code goes

core.md's HTTP bridge, in React terms:

| Unit | Role |
|---|---|
| **API function** | plain `async` function, no React import — callable from a loader, an action or a query |
| **Query / mutation hook** | caching, invalidation, retry; the only thing components call for server data |
| **Custom hook** | reusable *stateful* behaviour — the sole sanctioned unit for it |
| **Pure function** | transformation and formatting, named and outside the component |
| **Component** | render plus its own ephemeral UI state |

- Keeping the API layer React-free is what lets a loader and a rendererless test call it; one hook in
  there forecloses both.
- ⚠ **`use(promise)` only with a promise from a cache or a loader.** One created during render is a new
  promise every render, so the Suspense fallback re-shows forever. `use` also cannot sit in a
  `try`/`catch` — a rejection needs an Error Boundary.

## React 19 idiom

| Obsolete | Current |
|---|---|
| `forwardRef(…)` | `ref` as an ordinary prop — unnecessary since 19, and slated for deprecation |
| `<Context.Provider value>` | `<Context value>` |
| class components, lifecycle methods | function components and hooks |
| `propTypes` / `defaultProps` | types and default parameters (**removed** in 19) |
| `useMemo`/`useCallback` by reflex | React Compiler; both remain as deliberate escape hatches |
| `useEffect` to fetch or to derive | query cache / loader; compute during render |
| `react-test-renderer`, `react-dom/test-utils` | React Testing Library (deprecated / removed in 19) |

Stable and worth using: `useActionState`, `useFormStatus`, `useOptimistic`, `use`, ref cleanup, in-place
document metadata (19.0); `<Activity>`, `useEffectEvent` (19.2); `<ViewTransition>`, Fragment refs (19.3).

⚠ **Do not remove existing `useMemo`/`useCallback` when adopting the compiler** — react.dev warns that
removing it changes compilation output, and the `preserve-manual-memoization` rule enforces it.

## Effects

- **An effect synchronises with something outside React** — a subscription, a timer, an imperative browser
  API, a non-React widget. That is the whole list of reasons to write one.
- **Every effect that sets something up returns its teardown.** Strict Mode mounts, unmounts and remounts
  in development precisely to expose a missing one; production double-invokes nothing and warns about
  nothing, so the leak surfaces only as drift.
- ⚠ **Derived state in an effect is a lint failure, not a preference** — `set-state-in-effect`. It costs an
  extra render and paints one frame of the wrong value.
- ⚠ **Never suppress `exhaustive-deps`.** An effect that must read a value without re-running on it is what
  `useEffectEvent` is for; suppression just hides the stale closure.

## Components, props, refs

- **Type props as a plain type on the destructured parameter — not `React.FC`.** It buys nothing once
  `children` is declared explicitly, and it blocks generic components.
- **Model mutually exclusive states as a discriminated union.** Three optional fields let `data` and
  `error` both be set; a union makes that unrepresentable instead of merely unlikely.
- ⚠ **Keys identify, they do not decorate.** An index key, or one generated during render
  (`crypto.randomUUID()`), remounts the subtree on reorder — silently dropping focus, scroll position and
  uncommitted input. Key by entity id.
- **Never read or write a ref during render** — `refs` lint rule.
- core.md's third-party-widget rule, in React: a **ref callback that returns its cleanup**, mounting the
  widget into a throwaway child of a stable host element.

## Forms

- **Uncontrolled by default.** Driving every input through `useState` re-renders the whole form per
  keystroke, and is the usual reason a React form feels slow. Read values off the submitted `FormData`, or
  use a form library that keeps them out of render.
- **One schema, two jobs** — validation, and the TS type inferred from it. A hand-written type beside a
  validator drifts, and nothing fails until production.
- **Re-validate on the server with the same schema.** Client validation is UX, never a control.
- **`useActionState` with `<form action>` owns the submit path** — pending, error and result in one hook,
  no `preventDefault`, and it degrades without JS. `useFormStatus` for a nested submit button;
  `useOptimistic` when the mutation should appear to land immediately.
- ⚠ **One owner for submit.** A form library's handler and a form Action both wired up will fight; the
  supported seam is the library owning client validation, with server errors fed back into it.

## Errors

- ⚠ **An Error Boundary catches render errors only** — not event handlers, not async callbacks, not SSR.
  (The documented exception: a throw inside a `startTransition` function *is* caught, which is what makes
  Actions boundary-covered.) "Wrapped in a boundary" is not "covered": catch the rest where they happen
  and route them to the notification path core.md requires.
- **One boundary per routed region, plus one around any independently-failing widget.** A single root
  boundary turns a broken card into a blank page.

## Styling

- **Zero-runtime only**: CSS Modules, utility CSS, or compiled CSS-in-JS. Runtime CSS-in-JS injects during
  render and is Context-based, so it does not fit Server Components — styled-components has been in
  maintenance mode since March 2025. Inline `style` stays for genuinely dynamic values only.

## Testing

- **Vitest + React Testing Library**, jsdom for the bulk; Vitest Browser Mode (Playwright provider) for
  what jsdom cannot represent — real layout, computed styles, focus order, pointer events, canvas.
- **Assert what the user perceives.** Query by role and accessible name; `getByTestId` is the fallback, not
  the habit. A rendered-tree snapshot asserts markup instead of behaviour — it fails on every refactor and
  passes through every regression.
- **Mock at the network boundary, not the module boundary.** Stubbing your own API module tests the stub's
  shape; a request handler exercises the real serialisation, the real error path and the cache.

## Documentation

TSDoc bar and budget: `.agent-kit/common/process/authoring/`. Delta — **what gets documented**: custom
hooks and API functions. Components get none; props and their types carry it. Spend the prose allowance on
effect teardown and on which query keys a mutation invalidates.
