# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A minimal Java WAR application that replaces Tomcat's default ROOT webapp (`$TOMCAT_HOME/webapps/ROOT`). Displays server info, request headers, and cookies via a servlet and JSP page. Supports Tomcat 9, 10, and 11 via Maven profiles.

## Build Commands

The toolchain (JDK, Maven, node, act) is managed by [mise](https://mise.jdx.dev/) and pinned in `.mise.toml`. Run `make deps` once to install it (requires mise; `curl https://mise.run | sh`). Local dev builds every profile with the pinned JDK 21; CI tests the real per-JDK matrix.

```bash
make deps                        # install the mise-pinned toolchain
make build                       # Tomcat 9 (default)
make build PROFILE=tomcat10      # Tomcat 10
make build PROFILE=tomcat11      # Tomcat 11
make verify-all                  # compile all profiles
make jetty-run                   # run locally with Jetty
make smoke                       # deployed-WAR smoke test via embedded Jetty
make smoke-all                   # smoke test every profile
make clean                       # clean build artifacts
make ci                          # run full local CI pipeline
make ci-run                      # run GitHub Actions locally via act
```

Or with Maven directly:

```bash
mvn -B package -Ptomcat9         # Tomcat 9 (default, javax.servlet)
mvn -B package -Ptomcat10        # Tomcat 10 (jakarta.servlet 6.1)
mvn -B package -Ptomcat11        # Tomcat 11 (jakarta.servlet 6.1)
```

Two test layers:

- **Unit** — **JUnit 5 + Mockito** (run via Surefire). Test sources are profile-specific, mirroring the main sources: `src/test/java` (javax, tomcat9) and `src/test/java-jakarta` (jakarta, tomcat10/11). `make test PROFILE=...` compiles and runs the matching set.
- **Deployed-WAR smoke** — `make smoke` / `make smoke-all` (`scripts/smoke.sh`) boots `ROOT.war` under embedded Jetty on an ephemeral port and curls the real endpoints (`/`, `/index.html`, `/index.jsp`, `/infoservlet`), asserting status + body. This exercises what mocks can't: the `index.jsp` scriptlets compiling/running in a real container (JSPs compile at request time, not at `mvn package`), the servlet's `RequestDispatcher` forward, and the per-profile javax/jakarta deploy contract.

## Maven Profiles

| Profile | Tomcat | Servlet API | `maven.compiler.release` | CI-tested JDKs |
|---------|--------|-------------|--------------------------|----------------|
| `tomcat9` (default) | 9.0.x | `javax.servlet` 4.0 | 11 | 11, 17, 18, 21, 25 |
| `tomcat10` | 10.1.x | `jakarta.servlet` 6.1 | 17 | 17, 18, 25 |
| `tomcat11` | 11.0.x | `jakarta.servlet` 6.1 | 21 | 21, 25 |

Properties per profile: `maven.compiler.release`, `app.sourceDirectory`, `app.testSourceDirectory`, `app.webXml`. The build uses `maven.compiler.release` (not separate `source`/`target`) so the compiler enforces the target JDK's API surface; `maven-compiler-plugin` is pinned with `<failOnWarning>true</failOnWarning>` (all profiles compile warning-clean). The per-leg CI JDK is set via `MISE_JAVA_VERSION` (see `.github/workflows/ci.yml`) — the `release` level is the bytecode target, the CI-tested JDKs are the runtimes each profile is verified on.

## Architecture

```
src/main/
├── java/                           # javax sources (tomcat9)
│   └── com/ak/servlet/InfoServlet.java
├── java-jakarta/                   # jakarta sources (tomcat10, tomcat11)
│   └── com/ak/servlet/InfoServlet.java
└── webapp/
    ├── WEB-INF/
    │   ├── web.xml                 # javax namespace (tomcat9)
    │   └── web-jakarta.xml         # jakarta namespace (tomcat10, tomcat11)
    ├── META-INF/context.xml        # shared — sets context path to /
    ├── index.jsp                   # shared — renders server info, headers, cookies
    └── index.html                  # shared — static landing page
```

The two `InfoServlet.java` files are identical except for imports (`javax.servlet` vs `jakarta.servlet`). The two `web.xml` files differ only in XML namespace and schema version.

## Scripts

- `scripts/install-tomcat.sh` — downloads Tomcat 9/10/11 to `~/tomcat/{9,10,11}`, creates `~/tomcat/current` symlink
- `scripts/deploy.sh` — builds with the correct profile and deploys `ROOT.war` to the target Tomcat
- `scripts/smoke.sh` — boots `ROOT.war` under embedded Jetty on an ephemeral port and asserts the live endpoints serve (deployed-WAR smoke; `make smoke`)

## Makefile

The `Makefile` wraps Maven and the scripts. All profile-aware targets accept `PROFILE=tomcat9|tomcat10|tomcat11` (default: `tomcat9`). mise shims are prepended to `PATH` so recipes find the pinned `java`/`mvn`/`act`.

## CI

GitHub Actions (`ci.yml`) runs on push to `master`, tags `v*`, and pull requests. The toolchain is provided by `jdx/mise-action`; the JDK for each matrix leg is set via the `MISE_JAVA_VERSION` env override. Jobs:

- **changes** — `dorny/paths-filter` detects whether `code` paths or `docs` (README.md) changed (docs-only changes skip the build).
- **static-check** — runs `make static-check` (`lint` + `trivy-fs` + `gitleaks-scan` + `mermaid-lint`).
- **build** — `needs: [changes, static-check]` (static-check gates the matrix so a lint failure fails fast). Runs `make lint`, `make build`, `make test` across the matrix:
  - **Tomcat 9**: JDK 11, 17, 18, 21, 25 (Temurin)
  - **Tomcat 10**: JDK 17, 18, 25 (Temurin)
  - **Tomcat 11**: JDK 21, 25 (Temurin)
- **smoke** — `needs: [changes, static-check]`. Runs `make smoke` per profile (matrix tomcat9/10/11): boots `ROOT.war` under embedded Jetty and curls the real endpoints — catches JSP runtime-compile + deploy-contract regressions the build/unit layer can't.
- **mermaid-lint** — runs `make mermaid-lint` on docs-only edits (README.md, no code change) so a broken Mermaid diagram can't merge unvalidated; when code changes, `static-check` already covers it.
- **ci-pass** — aggregator gate; succeeds only if every job passed. It is the single required status check on `master` (enforced via a repository ruleset).

**Static analysis scope**: dependency-CVE coverage is `trivy-fs` (scans `pom.xml` deps for HIGH/CRITICAL) plus Renovate. A 2-servlet demo WAR deliberately omits the heavier portfolio Java gates (OWASP dependency-check `cve-check`, google-java-format `format-check`, JaCoCo `coverage-check`) — they'd add CI secrets (NVD/OSS-Index), build time, and near-zero coverage signal on trivial code for no proportional benefit. Revisit if the codebase grows beyond the two `InfoServlet` sources.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
