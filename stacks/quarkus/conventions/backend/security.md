## Security

This stack prescribes **authorization**: who may call what, enforced by annotations. **Authentication** — OIDC, JWT, basic, a gateway's header — is the project's own choice, and nothing here depends on which.

### Deny by default — two switches, and neither covers a bare bean

`quarkus-rest` brings the security interceptors in, so `@RolesAllowed`, `@PermitAll`, `@DenyAll` and `@Authenticated` work with no further extension. Nothing is denied until you say so; turn on both switches:

- **`quarkus.security.jaxrs.deny-unannotated-endpoints=true`** — a JAX-RS endpoint with no security annotation is denied. This is the one that closes the HTTP surface.
- **`quarkus.security.deny-unannotated-members=true`** — a bean that has a security annotation on *some* member denies its unannotated ones.

⚠ **The second switch does not protect a bean that carries no security annotation at all.** A service with none stays open to every caller that reaches it, and nothing warns you. Annotate the class (`@RolesAllowed` on it, `@PermitAll` where open on purpose) so every service has an explicit rule.

### Check in both layers

`@RolesAllowed` goes on the **resource method** and again on the **service method** the resource calls. A service is reachable without a resource — from another bean, a scheduler, a startup hook — and the resource check does not follow it there.

- **Annotate the method another bean calls.** Interception runs through the container's generated subclass, so a `private` method is never checked. The build fails on one by default (`quarkus.arc.fail-on-intercepted-private-method`); set false, it only logs a warning and the annotation is ignored.
- **An anonymous caller is rejected 401, an authenticated one without the role 403.** `"**"` as a role means any authenticated user. Pick one role vocabulary for the codebase.
- ⚠ **A scheduler or startup hook has no caller identity unless the project supplies one**, so a guarded service rejects it as anonymous. Give that path a service method that is deliberately unguarded and not reachable from a resource, rather than weakening the guard.

### Handling secrets and input

- **Validate at the resource only**, through the validation groups (`api.md`). Services assume an already-validated caller; authorization is the service's own, above.
- **A credential is write-only** — accepted on a Request, never echoed on a Response, never a field on a model that a mapper can reach.
- **Never expose** a stack trace or an internal class name in an HTTP body. A 500 returns a problem body with a correlation id and nothing else (`api.md`).
- **Never hardcode a secret.** Bind deployment config once through a `@ConfigMapping` interface (`code-style.md`); never read the environment at a call site.
- **Never log** a password, token, session id, API key or PII, at any level (`.agent-kit/backend/logging.md`).
- **Passwords go through an adaptive hash** (BCrypt or Argon2), never MD5 or SHA-1. Never roll custom crypto.

### Prove the rule, never read it

⚠ **An endpoint's real policy is the annotation set plus the two switches, which no single file shows you.** A `*ResourceTests` asserting **401** anonymous and **403** for the wrong role, per endpoint, is the only thing that catches a switch left off or a guard that tests never reach through the bean (`testing.md`).
