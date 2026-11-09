## Concurrency & Virtual Threads

- **Never create a thread or a pool yourself** — no `new Thread(...)`, no `Executors.newFixedThreadPool(...)`, no `CompletableFuture.supplyAsync(task)` on the common pool. Inject `ManagedExecutor` (`quarkus-smallrye-context-propagation`), which runs on Quarkus's own executor; for a workload that must not share it, a dedicated, bounded one through `@ManagedExecutorConfig(maxAsync = …)`.

### Virtual threads

**Imperative code on virtual threads: put `@RunOnVirtualThread` (`io.smallrye.common.annotation`) on a resource class whose endpoints block on I/O (the database, a REST client), which is most of them here; a class that only computes stays on the worker pool.** Quarkus REST reads the method first, then the class. Without it a blocking method runs on a worker thread, not a virtual one. The build fails when the JDK or the compile `release` lacks virtual threads — the Java 21 baseline in `code-style.md` covers both.

- ⚠ **Lock with `ReentrantLock`, never `synchronized`, where a lock is held across blocking work.** On the Java 21 baseline a virtual thread blocking inside a `synchronized` region pins its carrier thread, so a handful can starve every request. (JDK 24 lifted that pinning — re-measure before relaxing this if the baseline moves.)
- **Blocking I/O is fine** on a virtual thread — that is the point. Long CPU-bound work is not: give it its own bounded executor so it cannot occupy carriers requests need.

### Handing work to another thread

- ⚠ **Submitting from inside a transaction is a trap whichever way it goes.** The transaction extension ships a context provider that resumes the submitter's transaction on the task's thread, so the task may run inside a transaction its caller is still using. Never submit a step that must be atomic with its caller, and give a task that writes its own `@Transactional` service call.
- **Capture what a task needs before submitting it** — the authenticated principal, the log correlation id, request-scoped values — into locals or a record at submit time. A task reaching back into request state is guessing about propagation, and the request may already be over.
- ⚠ **Consume every `Future`.** An exception inside a task is held there and reported nowhere else (`logging.md`). Return `CompletableFuture` when a caller must learn the outcome.

### Shared state

- **`@ApplicationScoped` beans are singletons** — fields must be stateless or effectively immutable. Never share mutable state between requests; per-request state belongs in a method local, or in a `@RequestScoped` bean when it genuinely spans calls.
- ⚠ **An in-JVM lock is not a cluster lock.** `ReentrantLock` coordinates one instance; across replicas it guarantees nothing, and the resulting corruption reads like bad data rather than a race. Cross-instance mutual exclusion needs shared state — see `persistence-<db>.md` and the scheduled-work rule in `patterns.md`.
- ⚠ **Nothing thread-bound may carry business meaning across a mapping or a task.** A thread-bound mode flag in a `ThreadLocal` is correct until the work moves to another thread, and then silently wrong (`code-style.md` → *Code Conventions*). Pass it as an argument.

### Optimistic-lock retry

A read-modify-write that can lose a race on a versioned row must **retry the lost update, not surface it as a 500**. Three rules:

- **Retry from outside the transaction.** The retried call is the whole unit — read, validate, write, commit — reached through the container's proxy from a caller that is not itself inside the transaction: a self-call from a `@Transactional` method runs inside it. Never a retry loop inside the transaction that already lost: that attempt is spent.
- **`@Retry` and `@Transactional` on one method do not give you that.** Interceptors run in priority order, lowest first: the transaction interceptor sits at 200 and Fault Tolerance, by default, at 4010, so the transaction wraps the retries. Put `@Retry` on a method with no `@Transactional` that calls the `@Transactional` one, on another bean or on the same one (ArC intercepts self-calls on non-private methods).
- **Re-read and re-validate on every attempt.** The method re-runs whole, so a condition that stopped holding surfaces as its proper 4xx, not a 500 after the retries are spent.

`persistence-<db>.md` names the conflict to retry on and how the version is kept.
