.DEFAULT_GOAL := help

SHELL := /bin/bash
SDKMAN := $(HOME)/.sdkman/bin/sdkman-init.sh

MAVEN_VER := 3.9.11
ACT_VERSION := 0.2.86
NVM_VERSION := 0.40.4
CURRENTTAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")

PROFILE ?= tomcat9
ALLOWED_PROFILES := tomcat9 tomcat10 tomcat11

# Validate PROFILE
ifeq ($(filter $(PROFILE),$(ALLOWED_PROFILES)),)
    $(error Invalid PROFILE=$(PROFILE). Allowed values: $(ALLOWED_PROFILES))
endif

# Read recommended JDK version from the active Maven profile
JAVA_VER := $(shell mvn help:evaluate -P$(PROFILE) -Dexpression=jdk.version -q -DforceStdout 2>/dev/null || echo "21-tem")

# Detect macOS for 'open' vs 'xdg-open'
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(UNAME_S), Darwin)
	OPEN_CMD := open
else
	OPEN_CMD := xdg-open
endif

#help: @ List available tasks
help:
	@clear
	@echo "Usage: make COMMAND [PROFILE=tomcat9|tomcat10|tomcat11]"
	@echo
	@echo "Commands :"
	@echo
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-18s\033[0m - %s\n", $$1, $$2}'

#deps: @ Check required tools are installed
deps:
	@command -v java >/dev/null 2>&1 || { echo "Error: Java required. Install via SDKMAN: https://sdkman.io"; exit 1; }
	@command -v mvn >/dev/null 2>&1 || { echo "Error: Maven required. Install via SDKMAN: https://sdkman.io"; exit 1; }

#deps-check: @ Install JDK and Maven via SDKMAN
deps-check:
	@if [ ! -f "$(SDKMAN)" ]; then \
		echo "Installing SDKMAN..."; \
		curl -s "https://get.sdkman.io?rcupdate=false" | bash; \
	fi
	@. $(SDKMAN) && echo N | sdk install java $(JAVA_VER) && sdk use java $(JAVA_VER)
	@. $(SDKMAN) && echo N | sdk install maven $(MAVEN_VER) && sdk use maven $(MAVEN_VER)

#env-check: @ Check installed tools
env-check: deps-check
	@printf "\xE2\x9C\x94 sdkman\n"

#clean: @ Cleanup
clean:
	@mvn -B clean

#build: @ Build ROOT.war (use PROFILE=tomcat9|tomcat10|tomcat11)
build: deps
	@echo "Building with profile: $(PROFILE) (JDK $(JAVA_VER))"
	@mvn -B package -P$(PROFILE)

#test: @ Run tests (use PROFILE=tomcat9|tomcat10|tomcat11)
test: deps
	@mvn -B test -P$(PROFILE)

#lint: @ Check code style with Maven Checkstyle
lint: deps
	@mvn -B validate -P$(PROFILE)

#run: @ Run locally with Jetty (alias for jetty-run)
run: jetty-run

#ci: @ Run full local CI pipeline
ci: deps clean lint build test
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

#deps-ci: @ Install Maven for CI environments
deps-ci:
	@command -v mvn >/dev/null 2>&1 || { \
		echo "Installing Maven $(MAVEN_VER)..."; \
		curl -fsSL "https://archive.apache.org/dist/maven/maven-3/$(MAVEN_VER)/binaries/apache-maven-$(MAVEN_VER)-bin.tar.gz" \
			| sudo tar xz -C /opt; \
		sudo ln -sf /opt/apache-maven-$(MAVEN_VER)/bin/mvn /usr/local/bin/mvn; \
	}

#deps-act: @ Install act for local GitHub Actions testing
deps-act: deps
	@command -v act >/dev/null 2>&1 || { echo "Installing act $(ACT_VERSION)..."; \
		curl -sSfL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin v$(ACT_VERSION); \
	}

#ci-run: @ Run GitHub Actions workflow locally using act
ci-run: deps-act
	@act push --container-architecture linux/amd64 \
		--artifact-server-path /tmp/act-artifacts

.PHONY: help deps deps-check deps-ci deps-act env-check clean build test lint run ci ci-run \
	verify-all jetty-run deploy tomcat-install tomcat-switch \
	deps-print-updates deps-update release renovate-bootstrap renovate-validate

#renovate-bootstrap: @ Install nvm and npm for Renovate
renovate-bootstrap:
	@command -v node >/dev/null 2>&1 || { \
		echo "Installing nvm $(NVM_VERSION)..."; \
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v$(NVM_VERSION)/install.sh | bash; \
		export NVM_DIR="$$HOME/.nvm"; \
		[ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh"; \
		nvm install --lts; \
	}

#renovate-validate: @ Validate Renovate configuration
renovate-validate: renovate-bootstrap
	@npx --yes renovate --platform=local
