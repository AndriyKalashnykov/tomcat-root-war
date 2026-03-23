.DEFAULT_GOAL := help

SHELL := /bin/bash
SDKMAN := $(HOME)/.sdkman/bin/sdkman-init.sh

MAVEN_VER := 3.9.11

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

.PHONY: help check-env build-deps-check clean build verify-all \
	jetty-run deploy install-tomcat switch-tomcat \
	print-deps-updates update-deps

#help: @ List available tasks on this project
help:
	@clear
	@echo "Usage: make COMMAND [PROFILE=tomcat9|tomcat10|tomcat11]"
	@echo
	@echo "Commands :"
	@echo
	@grep -E '[a-zA-Z\.\-]+:.*?@ .*$$' $(MAKEFILE_LIST)| tr -d '#' | awk 'BEGIN {FS = ":.*?@ "}; {printf "\033[32m%-18s\033[0m - %s\n", $$1, $$2}'

build-deps-check:
	@if [ ! -f "$(SDKMAN)" ]; then \
		echo "Installing SDKMAN..."; \
		curl -s "https://get.sdkman.io?rcupdate=false" | bash; \
	fi
	@. $(SDKMAN) && echo N | sdk install java $(JAVA_VER) && sdk use java $(JAVA_VER)
	@. $(SDKMAN) && echo N | sdk install maven $(MAVEN_VER) && sdk use maven $(MAVEN_VER)

#check-env: @ Check installed tools
check-env: build-deps-check
	@printf "\xE2\x9C\x94 sdkman\n"

#clean: @ Cleanup
clean:
	@mvn clean

#build: @ Build ROOT.war (use PROFILE=tomcat9|tomcat10|tomcat11)
build:
	@echo "Building with profile: $(PROFILE) (JDK $(JAVA_VER))"
	@mvn install -P$(PROFILE) --file pom.xml

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
