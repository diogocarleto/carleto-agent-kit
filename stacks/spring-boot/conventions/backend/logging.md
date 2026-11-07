## Logging

Read together with `.agent-kit/backend/logging.md`, the stack-neutral rules (values as arguments, log a failure once, never log secrets); this doc keeps what this stack adds, and wins where they differ.

- **One API — SLF4J.** The Boot logging starter binds SLF4J to Logback and bridges JUL and Log4j into it, so every log line already converges there; a second facade in application code only fragments configuration. One logger per class, never a shared static one on a base type.
- Example: `log.info("Imported {} rows for {}", count, ownerId)`.
- **Log once at the boundary** — services throw, the exception-handling layer logs (`api.md`).
- **Levels**: ERROR = unrecoverable, WARN = expected/retryable failure, INFO = state change, DEBUG = dev flow, TRACE = fine-grained (never in production).
- ⚠ **A `void @Async` method's failure reaches nothing but the log.** The exception cannot be returned to the caller, so it goes to the async uncaught-exception handler, whose default implementation only logs (`concurrency.md`). The log is the sole record — so async work must log the ids that correlate it back to what it was doing.
