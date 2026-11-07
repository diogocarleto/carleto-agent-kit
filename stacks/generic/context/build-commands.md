## Build & Test Commands

> **TEMPLATE — replace this file.** Seeded once, then project-owned; the kit never overwrites it.
> `/structure-extract` detects the build tool and test layout and can fill this in.

This file is **always-on Tier-0 context**: every agent reads it before running anything. List the
commands that actually work in this repo — an agent that guesses a build command wastes a cycle.

### Build

```bash
<e.g. mvn clean install -DskipTests | npm run build | go build ./... | uv sync>
```

### Test

```bash
<whole suite>
<single module / package — the narrowest useful scope>
<single test>
```

### Run

```bash
<how to start the app locally>
```

### Notes

- <required toolchain version, env vars, services that must be up first>
