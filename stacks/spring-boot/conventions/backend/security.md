## Security

### The filter chain is the policy — and it only covers what it matches

Define **one** `SecurityFilterChain` with no `securityMatcher`, ordering rules most-specific first and
ending in `anyRequest()`. Add a second chain only with a deliberate matcher.

- **Defining your first chain removes Boot's.** With Spring Security on the classpath and no chain bean,
  Boot contributes `anyRequest().authenticated()` plus form login and HTTP Basic — closed. That default is
  conditional on *no* `SecurityFilterChain` bean existing, so declaring one scoped to `/api/**` leaves
  every other path with no policy at all.
- ⚠ **Deny-by-default holds *inside* a chain and not *between* chains.** Within a matched chain a request
  that matches no rule is **denied** — that part is safe. But when no chain's matcher matches the request,
  `FilterChainProxy` runs **no security filters** and hands the request straight on; it logs *"No security
  for …"* at TRACE and nothing else. A path that falls between two `securityMatcher`s is public, and the
  only evidence is a log level nobody runs in production. This is the thing to get right.
- **Rules are first-match, and `anyRequest()` must be last.** Registering a matcher after it fails at
  startup — the one part of the ordering the framework does enforce.
- ⚠ **The container's ERROR dispatch is authorized too.** A `permitAll` endpoint whose failure escapes
  your advice is re-dispatched to `/error` and checked again — under `anyRequest().authenticated()` an
  anonymous caller gets a 401 where the error body should be. Give `/error` its own rule.

### Method security is opt-in, and `@PreAuthorize` is the one to reach for

Add `@EnableMethodSecurity` — Boot does not switch it on. Its defaults enable the **pre/post family** —
`@PreAuthorize`, `@PostAuthorize`, `@PreFilter`, `@PostFilter` — alongside `@AuthorizeReturnObject`,
which no flag gates. `@Secured` and JSR-250 `@RolesAllowed` are off until you flip their own flags, and
until you do they are silently inert. Use `@PreAuthorize`, on the service method the controller calls.

⚠ **It is proxy-based, so it shares the whole self-call failure family** (`patterns.md`): a check on a
method reached through `this`, or on a non-public one, simply never runs — the call succeeds, unchecked,
and nothing warns you. Never annotate a private helper; annotate the method another bean calls.

**`hasRole('ADMIN')` means the authority `ROLE_ADMIN`; `hasAuthority` is verbatim.** Pick one vocabulary
for the codebase — mixing them is how a granted authority stops matching the rule meant to cover it.

### A token API's chain is stateless, and that is not the default

The `HttpSecurity` you receive already has CSRF, session management and anonymous authentication
configured. So a token-authenticated JSON API must turn CSRF **off** explicitly and set
`SessionCreationPolicy.STATELESS`.

⚠ Leave CSRF on and every POST/PUT/DELETE is a 403 that reads exactly like an authorization failure.
⚠ Anonymous is on: an unauthenticated request still carries an `Authentication`, so
`authentication != null` is never an authentication check — ask for the authority.

### 401 and 403 are written by the chain, not by your advice

Both defaults call `sendError`, which the container re-dispatches to `/error` — outside
`DispatcherServlet`, so no `@ExceptionHandler` sees them and the body is Boot's, not your `ProblemDetail`.
Supply an `AuthenticationEntryPoint` and an `AccessDeniedHandler` that write the same shape as `api.md`,
or accept two error formats on one API.

### Handling secrets and input

- **Validate at the controller only**, through the validation groups (`api.md`). Services assume an
  already-validated caller. Authorization is the service's own, through `@PreAuthorize` above.
- **A credential is write-only** — accepted on a Request, never echoed on a Response, never a field on a
  model that a mapper can reach.
- **Never hardcode a secret.** Bind deployment config once through a `@ConfigurationProperties` record
  (`code-style.md`); never read the environment at a call site.
- **Never log** a password, token, session id, API key or PII, at any level (`.agent-kit/backend/logging.md`).
- **Passwords go through a `DelegatingPasswordEncoder`** (BCrypt or Argon2), never MD5 or SHA-1, so stored
  hashes carry their algorithm id and can be rotated. Never roll custom crypto.

### Prove the rule, never read it

⚠ **An endpoint's real policy is the chain that matched it, which no annotation shows you.** A
`*ControllerTests` asserting **401** anonymous and **403** for the wrong role, per endpoint, is the only
thing that catches a matcher that missed the path — and it proves nothing at the `@WebMvcTest` tier unless
the security slice is actually on the test classpath, which by default it is not (`testing.md`).
