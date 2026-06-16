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

Unit tests use **JUnit 5 + Mockito** (run via Surefire). Test sources are profile-specific, mirroring the main sources: `src/test/java` (javax, tomcat9) and `src/test/java-jakarta` (jakarta, tomcat10/11). `make test PROFILE=...` compiles and runs the matching set.

## Maven Profiles

| Profile | Tomcat | Servlet API | source/target | JDK |
|---------|--------|-------------|---------------|-----|
| `tomcat9` (default) | 9.0.x | `javax.servlet` 4.0 | 11 | 11-tem |
| `tomcat10` | 10.1.x | `jakarta.servlet` 6.1 | 17 | 17-tem |
| `tomcat11` | 11.0.x | `jakarta.servlet` 6.1 | 21 | 21-tem |

Properties per profile: `maven.compiler.source`, `maven.compiler.target`, `jdk.version`, `app.sourceDirectory`, `app.webXml`.

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

## Makefile

The `Makefile` wraps Maven and the scripts. All profile-aware targets accept `PROFILE=tomcat9|tomcat10|tomcat11` (default: `tomcat9`). `make deps` installs the mise-pinned toolchain; mise shims are prepended to `PATH` so recipes find the pinned `java`/`mvn`/`act`.

## CI

GitHub Actions (`ci.yml`) runs on push to `master`, tags `v*`, and pull requests. The toolchain is provided by `jdx/mise-action`; the JDK for each matrix leg is set via the `MISE_JAVA_VERSION` env override. Jobs:

- **changes** — `dorny/paths-filter` detects whether code paths changed (docs-only changes skip the build).
- **build** — runs `make lint`, `make build`, `make test` across the matrix:
  - **Tomcat 9**: JDK 11, 18, 25 (Temurin)
  - **Tomcat 10**: JDK 18, 25 (Temurin)
  - **Tomcat 11**: JDK 25 (Temurin)
- **ci-pass** — aggregator gate; the single required status check.

## Skills

Use the following skills when working on related files:

| File(s) | Skill |
|---------|-------|
| `Makefile` | `/makefile` |
| `renovate.json` | `/renovate` |
| `README.md` | `/readme` |
| `.github/workflows/*.{yml,yaml}` | `/ci-workflow` |

When spawning subagents, always pass conventions from the respective skill into the agent's prompt.
