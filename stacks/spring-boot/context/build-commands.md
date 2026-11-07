## Build Commands

**Toolchain: Java 21 + Maven.** Spring Boot 4 requires Java 17; 21 is this stack's own baseline — pin it in `maven.compiler.release` (`code-style.md`).

```bash
# Build everything, unit tests only
mvn clean install

# Build without tests
mvn clean install -DskipTests

# Build one module and what it depends on
mvn clean install -pl <module> -am

# Dev mode — restarts on rebuild when spring-boot-devtools is on the classpath
mvn spring-boot:run
```

`spring-boot-maven-plugin`'s `repackage` goal produces the runnable jar; `mvn clean install` runs it as part of `package`.

## Test Commands

Gating keys off the **class-name suffix** and lives in this project's own pom — surefire's includes/excludes for the unit tier, failsafe's for the rest.

| Tier | Suffix | Reaches | Profile |
|------|--------|---------|---------|
| Unit | `*Tests` | nothing outside the JVM | none (default) |
| Integration | `*IntegrationTests`, `*ControllerTests` | a real database; third parties **mocked** | `-Pintegration-tests` |
| Expensive | `*ExpensiveIntegrationTests` | real third-party APIs | `-Pexpensive-tests` |

⚠ **`-Dtest=` (surefire) and `-Dit.test=` (failsafe) override the configured includes *and* excludes.** Deliberate for one class; a **broad** pattern silently pulls the whole tier in — `-Pintegration-tests -Dit.test=com.foo.**` hits live third parties. To stay offline, name classes explicitly or scope with `-pl` and no `-Dtest`/`-Dit.test`.

⚠ **A failed build leaves the previous run's `target/surefire-reports/*.txt` (and `target/failsafe-reports/`) in place, reading like a pass.** Trust the **exit code** and `BUILD SUCCESS`, never the report files.

```bash
# Unit tests only (default — no profile)
mvn clean test

# Integration + controller tests (real database)
mvn clean verify -Pintegration-tests

# Every tier except expensive in ONE run — `all-tests` is not a fourth tier: it runs the unit and
# integration tiers together in one pass (`-Pintegration-tests` alone runs NO unit tests). This
# project's pom must define it
mvn clean verify -Pall-tests

# ONLY the expensive tests (real external APIs — opt-in, hits the network)
mvn clean verify -Pexpensive-tests

# A single unit test class / method
mvn test -Dtest=UserServiceTests
mvn test -Dtest=UserServiceTests#saveDuplicateEmail

# A single integration class — this is how you avoid starting the whole tier
mvn verify -Pintegration-tests -Dit.test=UserIntegrationTests

# Scope a run to one module WITHOUT -Dtest, so the profile's excludes still apply
mvn clean verify -Pintegration-tests -pl <module> -am
```

The integration tiers need Docker — the database runs under Testcontainers (`testing.md`).
