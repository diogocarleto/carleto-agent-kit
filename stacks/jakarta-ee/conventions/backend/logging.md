## Logging

Read together with `.agent-kit/backend/logging.md`, the stack-neutral rules (values as arguments, log a failure once, never log secrets); this doc keeps what this stack adds, and wins where they differ.

- **SLF4J only** — never `System.out`, never `java.util.logging` at a call site, never a vendor logging API.
- **Log once at the boundary** — services throw; the JAX-RS `ExceptionMapper` logs.
- **Levels**: ERROR = unrecoverable, WARN = expected/retryable failures, INFO = state changes, DEBUG = dev flow, TRACE = fine-grained (never in prod).
- **Correlate through MDC, not through signatures** — set the correlation id once at the boundary. ⚠ MDC is thread-bound and a managed executor does **not** propagate it. *Some* MDC implementations are worse than no propagation: they copy the map into a child thread when it is created, so a pool thread keeps a **stale** correlation id that reads as perfectly correct. Pass what the task needs explicitly, and set the MDC inside the task in a try/finally that clears it.
- ⚠ RUNTIME GAP — what binds SLF4J here. It is a facade; on a Jakarta EE runtime the binding is usually the server's own log manager rather than a logging library the app ships. That decides the child-thread behaviour above and where log configuration lives — verify it rather than assuming Logback. Fill when the runtime is chosen; do not guess.
