#!/usr/bin/env bash
set -euo pipefail

# Installs Apache Tomcat 9, 10, and 11 to ~/tomcat/{9,10,11}
# Creates ~/tomcat/current symlink pointing to chosen version
#
# Usage:
#   ./install-tomcat.sh                          # install all, default current=9
#   ./install-tomcat.sh --versions 9,10          # install specific versions
#   ./install-tomcat.sh --current 11             # set current symlink to 11
#   ./install-tomcat.sh --versions 10 --current 10

TOMCAT_9_VERSION="9.0.116"
TOMCAT_10_VERSION="10.1.52"
TOMCAT_11_VERSION="11.0.20"

INSTALL_BASE="${HOME}/tomcat"
CDN_MIRROR="https://dlcdn.apache.org/tomcat"
ARCHIVE_MIRROR="https://archive.apache.org/dist/tomcat"

install_tomcat() {
    local major="$1"
    local version="$2"
    local dest="${INSTALL_BASE}/${major}"

    if [[ -d "$dest" ]]; then
        echo "Tomcat ${major} already installed at ${dest}, skipping."
        return
    fi

    local tarball="apache-tomcat-${version}.tar.gz"
    local cdn_url="${CDN_MIRROR}/tomcat-${major}/v${version}/bin/${tarball}"
    local archive_url="${ARCHIVE_MIRROR}/tomcat-${major}/v${version}/bin/${tarball}"
    local tmp
    tmp=$(mktemp -d)

    echo "Downloading Tomcat ${version}..."
    if ! curl -fSL --progress-bar "$cdn_url" -o "${tmp}/${tarball}" 2>&1; then
        echo "CDN download failed, trying archive mirror..."
        if ! curl -fSL --progress-bar "$archive_url" -o "${tmp}/${tarball}" 2>&1; then
            echo "Error: Failed to download Tomcat ${version} from both mirrors."
            echo "  CDN:     ${cdn_url}"
            echo "  Archive: ${archive_url}"
            rm -rf "$tmp"
            exit 1
        fi
    fi

    # Verify the download is a valid gzip file
    if ! file "${tmp}/${tarball}" | grep -q "gzip compressed"; then
        echo "Error: Downloaded file is not a valid gzip archive."
        echo "The version ${version} may not exist. Check https://dlcdn.apache.org/tomcat/tomcat-${major}/"
        rm -rf "$tmp"
        exit 1
    fi

    mkdir -p "$dest"
    tar xzf "${tmp}/${tarball}" -C "$dest" --strip-components=1

    if [[ ! -d "${dest}/bin" ]]; then
        echo "Error: Extraction failed — ${dest}/bin not found."
        rm -rf "$dest"
        rm -rf "$tmp"
        exit 1
    fi

    chmod +x "${dest}"/bin/*.sh

    rm -rf "$tmp"
    echo "Tomcat ${version} installed to ${dest}"
}

set_current() {
    local major="$1"
    local target="${INSTALL_BASE}/${major}"

    if [[ ! -d "$target" ]]; then
        echo "Error: Tomcat ${major} is not installed at ${target}"
        exit 1
    fi

    ln -sfn "${target}" "${INSTALL_BASE}/current"
    echo "TOMCAT_HOME symlink set: ${INSTALL_BASE}/current -> ${target}"
}

usage() {
    echo "Usage: $0 [--versions 9,10,11] [--current 9|10|11]"
    echo ""
    echo "Options:"
    echo "  --versions   Comma-separated Tomcat major versions to install (default: 9,10,11)"
    echo "  --current    Set ~/tomcat/current symlink to specified version"
    echo ""
    echo "Installed layout:"
    echo "  ~/tomcat/9/       <- Tomcat ${TOMCAT_9_VERSION}"
    echo "  ~/tomcat/10/      <- Tomcat ${TOMCAT_10_VERSION}"
    echo "  ~/tomcat/11/      <- Tomcat ${TOMCAT_11_VERSION}"
    echo "  ~/tomcat/current  <- symlink to active version"
    echo ""
    echo "After installation, add to your shell profile:"
    echo '  export TOMCAT_HOME=~/tomcat/current'
    echo '  export CATALINA_HOME=$TOMCAT_HOME'
    exit 1
}

# Defaults
VERSIONS_TO_INSTALL="9,10,11"
SET_CURRENT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --versions) VERSIONS_TO_INSTALL="$2"; shift 2 ;;
        --current)  SET_CURRENT="$2"; shift 2 ;;
        --help|-h)  usage ;;
        *)          echo "Unknown option: $1"; usage ;;
    esac
done

# Create base directory
mkdir -p "${INSTALL_BASE}"

# Install requested versions
IFS=',' read -ra VERSIONS <<< "$VERSIONS_TO_INSTALL"
for v in "${VERSIONS[@]}"; do
    case "$v" in
        9)  install_tomcat 9  "$TOMCAT_9_VERSION" ;;
        10) install_tomcat 10 "$TOMCAT_10_VERSION" ;;
        11) install_tomcat 11 "$TOMCAT_11_VERSION" ;;
        *)  echo "Unknown Tomcat version: $v"; exit 1 ;;
    esac
done

# Set current symlink
if [[ -n "$SET_CURRENT" ]]; then
    set_current "$SET_CURRENT"
elif [[ ! -L "${INSTALL_BASE}/current" ]]; then
    set_current 9
fi

echo ""
echo "Done. Add to your shell profile:"
echo '  export TOMCAT_HOME=~/tomcat/current'
echo '  export CATALINA_HOME=$TOMCAT_HOME'
