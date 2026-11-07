## Concurrency & Virtual Threads

- **Never create a thread or a pool yourself** — no `new Thread(...)`, no `Executors.newFixedThreadPool(...)`, no `CompletableFuture.supplyAsync(task)` on the common pool. Inject Boot's application task executor, or define a dedicated one for a workload that must not share it.
- ⚠ **Defining any `Executor` bean stops Boot creating its own.** The auto-configured application task
  executor is conditional on there being no other `Executor` in the context, so a pool added for one
  workload silently becomes *the* executor for everything — `@Async`, and the virtual-thread wiring below.
  Set `spring.task.execution.mode=force` to keep Boot's alongside yours, and qualify `@Async` to pick.

### Virtual threads

**Enable them: `spring.threads.virtual.enabled=true`.** Boot activates it on Java 21 or later and
ignores it below, so the flag alone is not proof — the baseline in `code-style.md` is what makes it real.
It switches three things at once: Tomcat serves requests on virtual threads, the application task
executor becomes unpooled, and the task scheduler follows.

- ⚠ **The executor becomes unbounded.** `spring.task.execution.pool.*` still binds, but the pooled
  executor it describes is no longer created — so those limits now apply to nothing, and the one bound
  left is `spring.task.execution.simple.concurrency-limit`, unset by default. A job submitting per row
  submits *all* of them, and the wall it hits is the connection pool or the downstream API.
- ⚠ **Do not pool virtual threads.** Boot stops pooling precisely because they are cheap to create;
  putting a `ThreadPoolTaskExecutor` back in front of the same work restores a platform-thread ceiling
  and undoes the switch. Bound *concurrency* with the limit above, never with a pool.
- ⚠ **Lock with `ReentrantLock`, never `synchronized`, where a lock is held across blocking work.** On
  the Java 21 baseline a virtual thread blocking inside a `synchronized` region pins its carrier platform
  thread, so a handful can starve every request. (JDK 24 lifted that pinning — re-measure before relaxing
  this if the baseline moves; Spring enforces neither.)
- **Blocking I/O is fine** on a virtual thread — that is the point. Long CPU-bound work is not: give it
  its own bounded executor so it cannot occupy carriers requests need.

### Handing work to another thread

- ⚠ **A transaction does not propagate to a new thread.** Spring binds it to the executing thread, so work submitted from inside a `@Transactional` method runs outside it: the caller commits its own writes, the task commits or fails separately, and nothing reports the split. Never submit a step that must be atomic with its caller.
- **Capture what a task needs before submitting it** — request-scoped values, the authenticated principal, the log correlation id — into locals or a record at submit time. A task reaching back into request state is guessing about propagation, and the request may already be over.
- **`@Async` needs `@EnableAsync`, and it is proxy-driven** — a self-call runs inline with no warning (`patterns.md`). Unqualified it uses the application task executor; name one to target a dedicated executor.
- ⚠ **Consume every `Future`.** An exception inside a task is held there and reported nowhere else. A `void @Async` method cannot even do that — its exception reaches the async uncaught-exception handler, which by default only logs (`logging.md`). Return `CompletableFuture` when a caller must learn the outcome.

### Shared state

- **Beans are singletons** — fields must be stateless or effectively immutable. Never share mutable state between requests; per-request state belongs in a method local, or in a `@RequestScope` bean when it genuinely spans calls.
- ⚠ **An in-JVM lock is not a cluster lock.** `ReentrantLock` coordinates one instance; across replicas it guarantees nothing, and the resulting corruption reads like bad data rather than a race. Cross-instance mutual exclusion needs shared state — see `persistence-<db>.md`.
- ⚠ **Nothing thread-bound may carry business meaning across a mapping or a task.** A "current update type" in a `ThreadLocal` is correct until the work moves to an executor, and then silently wrong (`code-style.md` → HTTP verbs). Pass it as an argument.
