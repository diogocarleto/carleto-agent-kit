## Logging

Read together with `.agent-kit/backend/logging.md`, the stack-neutral rules (values as arguments, log a failure once, never log secrets); this doc keeps what this stack adds, and wins where they differ.

- **One API — SLF4J.** Quarkus logs through JBoss LogManager, and `quarkus-core` already brings `slf4j-api` and the `org.jboss.slf4j:slf4j-jboss-logmanager` bridge, so SLF4J needs no dependency of yours and every line converges on the one configuration. One logger per class, never a shared static one on a base type.
- **Add no other SLF4J binding** (Logback, Log4j): the bridge is the binding.
- Example: `log.info("Imported {} rows for {}", count, ownerId)`.
- **Log once at the boundary** — services throw, the `ExceptionMapper` logs (`api.md`).
- **Levels**: ERROR = unrecoverable, WARN = expected/retryable failure, INFO = state change, DEBUG = dev flow, TRACE = fine-grained (never in production).
- ⚠ **A task on another thread reports nowhere but the log.** Work handed to a `ManagedExecutor` or a scheduler has no caller to throw to (`concurrency.md`), so it must log the ids that correlate it back to what it was doing.
