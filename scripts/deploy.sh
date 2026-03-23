#!/usr/bin/env bash
set -euo pipefail

# Build ROOT.war for a target Tomcat version and deploy it.
#
# Usage:
#   ./deploy.sh           # build for Tomcat 9 (default), deploy to $TOMCAT_HOME
#   ./deploy.sh 10        # build for Tomcat 10, deploy to ~/tomcat/10
#   ./deploy.sh 11        # build for Tomcat 11, deploy to ~/tomcat/11

TOMCAT_MAJOR="${1:-9}"

# Map major version to Maven profile
case "$TOMCAT_MAJOR" in
    9)  PROFILE="tomcat9" ;;
    10) PROFILE="tomcat10" ;;
    11) PROFILE="tomcat11" ;;
    *)  echo "Usage: $0 [9|10|11]"; exit 1 ;;
esac

# Determine Tomcat home
TARGET_HOME="${TOMCAT_HOME:-${HOME}/tomcat/${TOMCAT_MAJOR}}"

if [[ ! -d "$TARGET_HOME" ]]; then
    echo "Error: Tomcat directory not found at ${TARGET_HOME}"
    echo "Run scripts/install-tomcat.sh first."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Building ROOT.war with profile: ${PROFILE}"
mvn -B clean package -P"${PROFILE}" --file "${PROJECT_DIR}/pom.xml"

echo "Deploying to ${TARGET_HOME}/webapps/"

# Stop Tomcat if running
if [[ -x "${TARGET_HOME}/bin/shutdown.sh" ]]; then
    "${TARGET_HOME}/bin/shutdown.sh" 2>/dev/null || true
    sleep 2
fi

# Remove old ROOT deployment
rm -rf "${TARGET_HOME}/webapps/ROOT/"
rm -f "${TARGET_HOME}/webapps/ROOT.war"

# Copy new WAR
cp "${PROJECT_DIR}/target/ROOT.war" "${TARGET_HOME}/webapps/ROOT.war"

echo "ROOT.war deployed to ${TARGET_HOME}/webapps/"
echo "Start Tomcat with: ${TARGET_HOME}/bin/startup.sh"
