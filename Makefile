.DEFAULT_GOAL := help

SHELL := /bin/bash

# mise provides the toolchain (java, maven, node, act) — see .mise.toml.
# Put mise shims on PATH so recipes find mise-installed tools.
export PATH := $(HOME)/.local/share/mise/shims:$(PATH)

CURRENTTAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

# act runner image — pin the DATED catthehacker tag. The floating act-* tags are
# republished weekly; the dated form is immutable. Renovate bumps it via the
# Makefile custom manager (see renovate.json).
# renovate: datasource=docker depName=catthehacker/ubuntu versioning=loose
ACT_UBUNTU_VERSION := act-latest-20260615

PROFILE ?= tomcat9
ALLOWED_PROFILES := tomcat9 tomcat10 tomcat11

# Validate PROFILE
ifeq ($(filter $(PROFILE),$(ALLOWED_PROFILES)),)
    $(error Invalid PROFILE=$(PROFILE). Allowed values: $(ALLOWED_PROFILES))
endif

# Detect macOS for 'open' vs 'xdg-open'
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S), Darwin)
	OPEN_CMD := open
else
	OPEN_CMD := xdg-open
endif

#help: @ List available tasks
help:
	@echo "Usage: make COMMAND [PROFILE=tomcat9|tomcat10|tomcat11]"
	@echo
	@echo "Commands :"
	@echo
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-20s\033[0m - %s\n", $$1, $$2}'

#deps: @ Install the toolchain (java, maven, node, act) via mise
deps:
	@command -v mise >/dev/null 2>&1 || { echo "Error: mise required. Install: https://mise.jdx.dev (curl https://mise.run | sh)"; exit 1; }
	@mise install

#clean: @ Cleanup
clean:
	@mvn -B clean

#build: @ Build ROOT.war (use PROFILE=tomcat9|tomcat10|tomcat11)
build: deps
	@echo "Building with profile: $(PROFILE)"
	@mvn -B package -P$(PROFILE)

#test: @ Run tests (use PROFILE=tomcat9|tomcat10|tomcat11)
test: deps
	@mvn -B test -P$(PROFILE)

#lint: @ Validate POM and project structure (mvn validate)
lint: deps
	@mvn -B validate -P$(PROFILE)

#trivy-fs: @ Scan filesystem for vulnerabilities and secrets (Trivy)
trivy-fs: deps
	@trivy fs --scanners vuln,secret --severity HIGH,CRITICAL --exit-code 1 --no-progress .

#gitleaks-scan: @ Scan the working tree for committed secrets (gitleaks)
gitleaks-scan: deps
	@gitleaks dir . --no-banner --redact

#static-check: @ Run all static analysis (lint + trivy-fs + gitleaks)
static-check: lint trivy-fs gitleaks-scan
	@echo "static-check passed."

#run: @ Run locally with Jetty (alias for jetty-run)
run: jetty-run

#ci: @ Run full local CI pipeline
ci: deps clean static-check build test
	@echo "Local CI pipeline passed."

#verify-all: @ Verify build compiles for all Tomcat profiles
verify-all: deps
	@mvn -B clean compile -Ptomcat9 -q && echo "tomcat9: OK"
	@mvn -B clean compile -Ptomcat10 -q && echo "tomcat10: OK"
	@mvn -B clean compile -Ptomcat11 -q && echo "tomcat11: OK"

#jetty-run: @ Run locally with Jetty (use PROFILE=tomcat9|tomcat10|tomcat11)
jetty-run: deps
	@mvn -B clean package jetty:run -P$(PROFILE)

#deploy: @ Build and deploy ROOT.war to Tomcat (use PROFILE=tomcat9|tomcat10|tomcat11)
deploy: deps
	@./scripts/deploy.sh $(subst tomcat,,$(PROFILE))

#tomcat-install: @ Download and install Tomcat 9, 10, 11 to ~/tomcat/
tomcat-install:
	@./scripts/install-tomcat.sh

#tomcat-switch: @ Switch active Tomcat version (use PROFILE=tomcat9|tomcat10|tomcat11)
tomcat-switch:
	@./scripts/install-tomcat.sh --versions "" --current $(subst tomcat,,$(PROFILE))

#deps-print-updates: @ Print project dependencies updates
deps-print-updates: deps
	@mvn -B versions:display-dependency-updates

#deps-update: @ Update project dependencies to latest releases
deps-update: deps-print-updates
	@mvn -B versions:use-latest-releases
	@mvn -B versions:commit

#release: @ Create and push a new tag
release:
	@bash -c 'read -p "New tag (current: $(CURRENTTAG)): " newtag && \
		echo "$$newtag" | grep -qE "^v[0-9]+\.[0-9]+\.[0-9]+$$" || { echo "Error: Tag must match vN.N.N"; exit 1; } && \
		echo -n "Create and push $$newtag? [y/N] " && read ans && [ "$${ans:-N}" = y ] && \
		echo $$newtag > ./version.txt && \
		git add -A && \
		git commit -a -s -m "Cut $$newtag release" && \
		git tag $$newtag && \
		git push origin $$newtag && \
		git push && \
		echo "Done."'

#ci-run: @ Run GitHub Actions workflow locally using act (act installed via mise)
ci-run: deps
	@docker container prune -f >/dev/null 2>&1 || true
	@# Forward a GitHub token (env-only via --secret KEY, never in argv) so mise's
	@# aqua: backend can query the GitHub release API during `mise install` inside
	@# the runner without hitting the 60-req/h anonymous rate limit. Derived from
	@# the gh CLI. --pull=false reuses the cached runner image (avoids the
	@# containerd-snapshotter RWLayer race). Random artifact port + mktemp dir keep
	@# concurrent runs from colliding.
	@if [ -z "$${GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then \
		export GITHUB_TOKEN="$$(gh auth token 2>/dev/null)"; \
	fi; \
	ARTIFACT_PATH=$$(mktemp -d -t act-artifacts.XXXXXX); \
	ACT_PORT=$$(shuf -i 40000-59999 -n 1); \
	secret_args=(); \
	[ -n "$${GITHUB_TOKEN:-}" ] && secret_args+=(--secret GITHUB_TOKEN); \
	act push --container-architecture linux/amd64 \
		--pull=false \
		-P ubuntu-latest=catthehacker/ubuntu:$(ACT_UBUNTU_VERSION) \
		--artifact-server-port "$$ACT_PORT" \
		--artifact-server-path "$$ARTIFACT_PATH" \
		"$${secret_args[@]}"

#renovate-validate: @ Validate Renovate configuration (node provided by mise)
renovate-validate: deps
	@npx --yes renovate@latest --platform=local

.PHONY: help deps clean build test lint trivy-fs gitleaks-scan static-check \
	run ci ci-run verify-all jetty-run deploy tomcat-install tomcat-switch \
	deps-print-updates deps-update release renovate-validate
