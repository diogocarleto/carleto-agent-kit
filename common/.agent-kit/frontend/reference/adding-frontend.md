# Authoring a stack's frontend layer where it has none

**Read this only when the stack ships no `.agent-kit/common/conventions/frontend/` doc for the declared
framework.** Not globbed — `core.md`'s invariants still govern whatever you write.

**It is a variant, not a fork.** The layer is a variant family keyed on `frameworks.frontend` in
`.agent-kit-local/structure.yml`, and the declared value **is** the filename suffix. A second framework on
the same stack means a second `framework-<name>.md` beside the first — never a second stack.

**Write it from the app that exists, not from the framework's documentation.** That documentation is
reachable from every consumer, so anything derivable from it is redundant on day one and wrong the day the
framework moves. Carry the two things it cannot tell a reader: **the shape this project settled on** among
several that would work, and **what fails silently** if you pick another.

**Settle these once and say so in plain words** — each is a real divergence between existing stacks, so a
doc that leaves one unstated has every future author guessing:

| Decision | Why it must be stated |
|---|---|
| Where stateful, multi-call orchestration lives | store, context, coordinator, or the component itself — all four are in use somewhere |
| How far the type escape hatch may be used | always a defect, or a last resort that carries a documented reason |
| Whether a computed inline style is ever allowed | banned outright, or reserved for genuinely dynamic values |
| How an error reaches the user | which notification path, and how the backend's message is extracted |
| The test baseline | runner, what must have a test, and what an empty one may not assert |

⚠ **Default a new layer to static typing.** Two of the three existing stacks require it; the third
documents plain JS as a deliberate project choice, with per-function annotations and runtime prop checks
carrying the contract instead. That is a call an existing codebase earns — a layer written from scratch
starts typed, and the escape-hatch row above then settles only how far the hatch opens, not whether the
language has one. ⚠ Typing is not a substitute for the boundary rule in `core.md`: a checker reports
nothing about a boundary already declared untyped, so declare the contract there either way.

**Then state what a reader must act on**: the file and folder shape, how a service is declared, what
gets documented and what does not, and the traps — a seam that fails quietly, a check that passes while
the code is wrong. `core.md` carries the invariants, so don't restate them; state how *this* stack
expresses them.

⚠ **Say which version you wrote it against.** A frontend doc is a snapshot of one app's framework version
and idiom, and it ages faster than any other layer — an unversioned one silently prescribes a dead style
to the next project that reads it.
