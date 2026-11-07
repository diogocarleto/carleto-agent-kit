# Frontend — invariants

**Prescriptive** — apply these, don't just read them. Framework-neutral and deliberately narrow: a rule
is admitted here only when the stack frontend docs already agreed on it, or when a trap distilled from
real work holds whatever the framework — never because a survey of frameworks proposed it. Beside this
file sits the framework's own standard, `framework-<value>.md`, selected by what the project declares; a
framework with none here has no standard written yet, which is a gap rather than a verdict on it. The
stack's own `conventions/frontend/` wins over both. How a component library or HTTP client *works*
belongs in module memory (`/module-extract`), not here.

⚠ **No frontend conventions on this stack? That is expected, not an error.** Where
`.agent-kit/common/conventions/frontend/` is absent, or ships nothing for the declared framework, these
invariants and the framework standard beside them are the whole of what applies — say so plainly rather
than inventing house rules, and take the
idiom from the components already in the tree. Authoring a layer → `reference/adding-frontend.md`.

⚠ **Not the same directory as `.agent-kit/common/conventions/frontend/`.** That one is the stack's layer,
and **it wins where the two differ** — this file states the invariant, that one states how this stack
expresses it.

## The service layer

- **A service is a thin HTTP bridge.** It builds the URL and the payload, calls the shared client, and
  returns the response. Transformation, formatting, filtering, sorting and business rules of any kind
  belong elsewhere — a service that "just" trims one field is where the rule nobody can find later starts.
- **Nothing reaches the network around it.** A raw client call from a component is how one request ends
  up without the base URL, the headers, or the error normalisation every other request gets.

## Contracts and types

- **Mirror the backend response field-for-field.** Never invent a field or rename one to read better on
  this side: a rename is an undocumented mapping, and it breaks silently the next time the backend moves.
- ⚠ **Absent and null are different facts — record which one the contract carries.** "May not be in the
  payload" and "is sent as null, and the null means something" are different instructions to the caller.
  Collapse them and you lose the second one.
- ⚠ **A meaningful null must never be rendered as a zero.** Defaulting "not measured yet" to `0` turns an
  unknown into a finished-looking result — a progress readout showing `0 / 0` for work never counted.
  Render it as unknown and make the caller decide.
- **Nothing infers a contract at a boundary — declare it.** Where a value crosses in from outside — a
  parsed payload, an untyped client, an event target, a component's own inputs — its shape is whatever you
  declared there, never what the tooling worked out. A checker reporting nothing is not evidence: a
  boundary already declared untyped gives it nothing to flag, and an unchecked codebase gives it nothing
  at all.

## Where code goes

Three responsibilities, named and kept apart:

| Responsibility | What it is |
|---|---|
| **HTTP bridge** | call the API, return the response — above |
| **Pure transformation** | no state, no side effects; a named unit, never an expression inline in the view |
| **Component** | render, plus its own ephemeral UI state |

- **One responsibility per component.** One that fetches, lays out *and* holds non-trivial state is three
  components that have not been separated yet.
- ⚠ **Where stateful, multi-call orchestration lives is a per-stack decision** — a store, a context, a
  coordinator, or the component itself. Take it from the stack doc and don't carry your last project's
  answer. With no stack doc: pick one, apply it everywhere, and write it down.

## Third-party widgets

- **Never hand a DOM-mutating widget the framework's own tracked node** (`bind:this`, `ref`, `ViewChild`
  — whatever this framework calls it). Embeds that take an element to mount into — video players, maps,
  editors, charting and canvas libraries — routinely *replace* it. The framework then tears down against
  a node that no longer exists, so the previous instance survives and the next one mounts **beside** it
  rather than replacing it.
- **Mount one stable host, give the widget a throwaway child of it**, and in cleanup clear the host
  unconditionally instead of trusting the widget's own `destroy()`/`dispose()` — whose ready-state
  semantics are usually undocumented, and which may no-op when called before the widget finished
  initialising. Removing the element also discards its browsing context, which is what actually stops
  stray audio, timers and network activity.
- ⚠ **A test double that appends where the real widget replaces cannot see this class of bug at all.**
  Fake the real DOM mutation, or a green suite is proving something about the stub rather than about the
  integration.

## Errors

- **Never swallow one.** A caught error that renders nothing is an interface that looks like it worked —
  and one that reaches only the console is no better, since the person who triggered the action never
  sees it. Every failure surfaces through the app's own notification path.
- **Surface the backend's own message**, read from its structured error body; fall back to a generic
  string only when there is none. A handler that takes a bare message field off the error discards the
  code and the structure the backend sent in order to be shown.

## Layout

- **Mobile-first is an ordering rule, not a goal.** Base styles are the smallest viewport; breakpoints add
  upward. Designing wide and shrinking leaves a base layout made of leftovers.
- **No fixed pixel widths on layout containers** — relative units or the layout system's own grid. The
  container pinned in pixels is the one that overflows.

The visual and accessibility bar — touch targets, contrast, focus order, empty/loading/error states, dark
mode — belongs to the UI toolkit and is not restated here: `.agent-kit/ui/core.md` → *Mandatory checks*.
