# Frontend — Angular

**Prescriptive: the standard a new Angular project adopts** — not a description of any existing app.
Written against **Angular 22.1, September 2026**. An older major adopts what it supports and records the
gap; a project that cannot adopt a rule here carries the deviation in its own stack's
`conventions/frontend/`, which wins where the two differ.

Read with `core.md` — the framework-neutral invariants. This file says how Angular expresses them, and
what Angular breaks silently.

## TypeScript

- Every file `.ts`, `strict: true`, no `any`. A boundary you cannot type gets a declared local shape,
  not a gap.
- ⚠ **A generic on an HTTP call is an assertion, not a parse.** `http.get<User>(…)` and
  `httpResource<User>(…)` cast the body; nothing validates it — same as `JSON.parse` and
  `event.target`. Strict mode flags none of it, because the `any` is explicit. Green is not evidence.

## The idiom — signals, standalone, control flow

Three generations of Angular are still writable. A new project writes only the right-hand column.

| Don't write | Write |
|---|---|
| `@NgModule` per feature | standalone components; `bootstrapApplication` + `ApplicationConfig` |
| `constructor(private x: X)` | `private readonly x = inject(X)` |
| `@Input()` · `@Output()` · `@ViewChild()` | `input()` · `input.required()` · `output()` · `model()` · `viewChild()` |
| `*ngIf` · `*ngFor` · `*ngSwitch` | `@if` · `@for` · `@switch` |
| a field mutated, then `ChangeDetectorRef` | `signal()` / `computed()` |
| `@Injectable({providedIn: 'root'})` | `@Service()` |

- **`@Service()` does not do constructor injection** — `inject()` only. Keep `@Injectable` for a service
  that genuinely needs constructor DI, and prefer not to need one.
- **NgModule is not deprecated and is not for new code.** A feature is a standalone component plus a
  `Routes` array, lazy-loaded with `loadComponent`; `loadChildren` into a module is the legacy path.
- ⚠ **`@for` requires `track`, and the expression is load-bearing.** Track a stable domain id. Tracking
  the item itself — a fresh object on every fetch — re-creates every row's DOM, silently discarding
  in-row focus, scroll position and anything mounted there.
- ⚠ **`@defer` silently does nothing if the deferred component is referenced elsewhere in the same
  file**, a `viewChild` query included. It is then bundled eagerly and the block only delays rendering.
  Nothing warns you.

### Reach for `effect()` last

`computed()` for a derived value → `linkedSignal()` for derived-but-writable → `resource()` /
`httpResource()` for async → `effect()` only to push signal state into a non-signal API (storage,
canvas, a third-party widget).

⚠ **Copying one signal into another inside an `effect` is the defect**, not a style preference: it
produces circular updates and `ExpressionChangedAfterItHasBeenChecked`. The fix is always to move the
source of truth up and derive. An `effect` that opens a timer, listener or subscription releases it
through the `onCleanup` callback.

### OnPush by default, and no zone

CLI-generated components are `OnPush` at v22, and an app is zoneless from v21. Together:
**nothing but a signal write reliably schedules a re-render.** A plain field mutated in a `setTimeout`
or a third-party callback updates the model and never the screen. Render state lives in signals.

⚠ `ChangeDetectionStrategy.Eager` is the old always-check default under its new name, stamped onto every
component by the v22 migration. A new project never writes it; in a migrated one, each occurrence marks
a component not yet on signals.

## Services — the HTTP bridge

- **One `@Service()` per domain**, `inject(HttpClient)`, building the URL and the payload and returning.
  No transformation, no sorting, no chaining two calls (core.md → *The service layer*).
- ⚠ **`HttpClient` is injected nowhere but a service.** A component that injects it is the request that
  goes out without the interceptors.
- **Configure once:** `provideHttpClient(withInterceptors([...]))` in `ApplicationConfig`. Auth headers,
  base URL and error normalisation are functional interceptors, never per-call arguments. v22 is on
  `fetch` by default — `withFetch()` is gone.
- **Two async shapes; pick one per project.** `httpResource()` where a component renders one request's
  state (`value`, `isLoading`, `error`, `reload()`); the `Observable` from `HttpClient` where the caller
  composes or needs the response once. Mixing them per component gives one request two error paths.
- **Declare the resource in the service**, taking reactive params from the caller, so the URL never
  leaves this layer:

```ts
@Service()
export class UserService {
  private readonly http = inject(HttpClient);

  byId(id: Signal<string>) {
    return httpResource<UserResponse>(() => `${PATH}/${id()}`);
  }
}
```

⚠ Call it from a component **field initializer** — `httpResource` needs an injection context, and that
is also what ties its teardown to the component.

## Where code goes

| Layer | Role |
|---|---|
| **Service** | HTTP bridge, and the resources over it |
| **Coordinator** | a second `@Service()` — multi-call orchestration, shared state |
| **Component** | render + its own ephemeral state; owns the params signals |
| **Pure function / pipe** | a named transformation, no state |

Orchestration is the coordinator's, never a component method and never the HTTP service. Derivation is a
`computed()` in the component — not an expression in the template.

## Components

- **One responsibility.** Fetch + layout + non-trivial state is three components not yet separated.
- **No DOM access** — no `document.querySelector`, no hand-registered listener. Bind, or write a
  directive.
- ⚠ **Never hand a DOM-mutating widget the element from `viewChild(ElementRef)`**: Angular then tears
  down against a node the widget replaced (core.md → *Third-party widgets*). Mount a throwaway child
  inside the queried host, and clear the host in `DestroyRef.onDestroy` whatever the widget's own
  `destroy()` claims.
- ⚠ A `viewChild()` signal is `undefined` until the queried node exists — and a node inside `@if` or
  `@defer` may never exist. Read it from an effect or `afterNextRender`, not from `ngOnInit`.

## Types

- **Mirror the backend response field-for-field**; one type per file, exported through the domain barrel.
- The audit block — `version`, `createdTime`, `updatedTime`, `createdBy`, `updatedBy` — is `?:`. A
  *domain* field is optional only when the backend genuinely leaves it out.
- `?:` is "may be absent"; `| null` is "sent as null, and the null means something". Collapsing them
  invites `?? 0`, which renders an unknown as a finished-looking zero.
- **A response is an `interface`, not a class with an `any` constructor.** Behaviour over it is a
  function.

## Forms

**Signal Forms for a new application** — `form()` over a model signal, bound with `[formField]`, from
`@angular/forms/signals`; stable at v22, and the model signal stays the single source of truth. Reactive
Forms remain supported and are the right answer inside an existing reactive-forms codebase, or where a
team wants the longer track record. Template-driven forms: no.

Either way the form is typed. An untyped `FormGroup`, or `form.value as any`, hands back the `any` the
rest of this doc spends its effort removing.

## Errors

- ⚠ **`HttpErrorResponse.message` is Angular's own string** — `Http failure response for <url>: <status>
  <statusText>`. It never carries the backend's message. That is in `.error`, the parsed body, typed
  `any`: declare its shape and read the backend's `code`/`message` from there. `err.message || fallback`
  looks like it surfaces the API error and never does.
- One notification path for the whole app, reached from an interceptor or a shared handler. Never
  swallow, never `console.error` alone, never `alert()`.
- `catchError` may retry or reshape — it must rethrow (`throwError(() => err)`).

## Teardown

- **`takeUntilDestroyed()` on every subscription you open by hand.** With no argument it must run in an
  injection context — a field initializer or the constructor.
- ⚠ **Subscribing later** — `ngOnInit`, a click handler — is outside that context. Capture
  `private readonly destroyRef = inject(DestroyRef)` as a field and pass it:
  `takeUntilDestroyed(this.destroyRef)`.
- **A manual `Subscription` + `unsubscribe()` is only for a lifetime shorter than the component's** — a
  poll stopped when a dialog closes. For component lifetime it is the pattern `takeUntilDestroyed`
  replaced.
- The `async` pipe unsubscribes itself. Prefer it, or a resource, over subscribing at all.

## Layout

Mobile-first ordering; no fixed pixel widths on layout containers (core.md → *Layout*). Component styles
are scoped by default — a global override belongs in the global stylesheet, never in whichever component
happens to be mounted.

## Testing

- **Vitest is the default runner for new projects.** Karma is still supported and is not deprecated —
  take Vitest for a new project, and don't migrate a working Karma suite without a reason.
- Services: `provideHttpClientTesting()` + `HttpTestingController`, `httpMock.verify()` in `afterEach`.
  ⚠ `HttpClientTestingModule` is **deprecated** — use the provider function.
- Every service has a spec covering its non-trivial methods. One whose only assertion is
  `expect(true).toBe(true)` is not a test.
- ⚠ A widget double that appends where the real one replaces cannot see the mounting bug above at all
  (core.md).

## Documentation

TSDoc bar + budget: `.agent-kit/common/process/authoring/`. Document services, coordinators and exported
utilities; components get none — the selector and the `input()` names already carry it. Spend the
allowance on what a signature cannot say: which signal owns a piece of state, and what an `effect`
cleans up.
