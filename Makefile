.DEFAULT_GOAL := help

SHELL := /bin/bash
SDKMAN := $(HOME)/.sdkman/bin/sdkman-init.sh

MAVEN_VER := 3.9.11
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

.PHONY: help deps deps-check env-check clean build test lint run ci \
	verify-all jetty-run deploy install-tomcat switch-tomcat \
	print-deps-updates update-deps release

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
	@mvn clean

#build: @ Build ROOT.war (use PROFILE=tomcat9|tomcat10|tomcat11)
build:
	@echo "Building with profile: $(PROFILE) (JDK $(JAVA_VER))"
	@mvn install -P$(PROFILE) --file pom.xml

#test: @ Run tests (use PROFILE=tomcat9|tomcat10|tomcat11)
test: deps
	@mvn test -P$(PROFILE) --file pom.xml

#lint: @ Check code style with Maven Checkstyle
lint: deps
	@mvn validate -P$(PROFILE) --file pom.xml

#run: @ Run locally with Jetty (alias for jetty-run)
run: jetty-run

#ci: @ Run full local CI pipeline
ci: deps clean lint build test
	@echo "Local CI pipeline passed."

#verify-all: @ Verify build compiles for all Tomcat profiles
verify-all:
	@mvn clean compile -Ptomcat9 -q --file pom.xml && echo "tomcat9: OK"
	@mvn clean compile -Ptomcat10 -q --file pom.xml && echo "tomcat10: OK"
	@mvn clean compile -Ptomcat11 -q --file pom.xml && echo "tomcat11: OK"

#jetty-run: @ Run locally with Jetty (use PROFILE=tomcat9|tomcat10|tomcat11)
jetty-run:
	@mvn clean package jetty:run -P$(PROFILE) --file pom.xml

#deploy: @ Build and deploy ROOT.war to Tomcat (use PROFILE=tomcat9|tomcat10|tomcat11)
deploy:
	@./scripts/deploy.sh $(subst tomcat,,$(PROFILE))

#install-tomcat: @ Download and install Tomcat 9, 10, 11 to ~/tomcat/
install-tomcat:
	@./scripts/install-tomcat.sh

#switch-tomcat: @ Switch active Tomcat version (use PROFILE=tomcat9|tomcat10|tomcat11)
switch-tomcat:
	@./scripts/install-tomcat.sh --versions "" --current $(subst tomcat,,$(PROFILE))

#print-deps-updates: @ Print project dependencies updates
print-deps-updates:
	@mvn versions:display-dependency-updates

#update-deps: @ Update project dependencies to latest releases
update-deps: print-deps-updates
	@mvn versions:use-latest-releases
	@mvn versions:commit

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
