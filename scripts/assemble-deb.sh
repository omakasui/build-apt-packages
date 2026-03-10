#!/usr/bin/env bash
# assemble-deb.sh — Assemble a .deb from a staged directory tree and a package.yml.
#
# Usage:
#   assemble-deb.sh --staged <dir> --pkg-yaml <file> --key <name> --version <ver> \
#                   --arch <amd64|arm64> --distro <distro> --output-dir <dir> \
#                   [--extra-depends <str>]
#
# Reads from package.yml: produces[], arch, section, priority, homepage,
#                         description, runtime_depends
# If arch: all is set in package.yml, overrides --arch for control file and filename.

set -euo pipefail

STAGED_DIR=""
PKG_YAML=""
PKG_KEY=""
VERSION=""
ARCH=""
DISTRO=""
OUTPUT_DIR=""
EXTRA_DEPENDS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staged)       STAGED_DIR="$2";  shift 2 ;;
    --pkg-yaml)     PKG_YAML="$2";    shift 2 ;;
    --key)          PKG_KEY="$2";     shift 2 ;;
    --version)      VERSION="$2";     shift 2 ;;
    --arch)         ARCH="$2";        shift 2 ;;
    --distro)       DISTRO="$2";      shift 2 ;;
    --output-dir)   OUTPUT_DIR="$2";  shift 2 ;;
    --extra-depends) EXTRA_DEPENDS="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$STAGED_DIR"  ]] && { echo "ERROR: --staged is required";     exit 1; }
[[ -z "$PKG_YAML"    ]] && { echo "ERROR: --pkg-yaml is required";   exit 1; }
[[ -z "$PKG_KEY"     ]] && { echo "ERROR: --key is required";        exit 1; }
[[ -z "$VERSION"     ]] && { echo "ERROR: --version is required";    exit 1; }
[[ -z "$ARCH"        ]] && { echo "ERROR: --arch is required";       exit 1; }
[[ -z "$DISTRO"      ]] && { echo "ERROR: --distro is required";     exit 1; }
[[ -z "$OUTPUT_DIR"  ]] && { echo "ERROR: --output-dir is required"; exit 1; }

command -v yq      >/dev/null || { echo "ERROR: yq not found";      exit 1; }
command -v fakeroot >/dev/null || { echo "ERROR: fakeroot not found"; exit 1; }
command -v dpkg-deb >/dev/null || { echo "ERROR: dpkg-deb not found"; exit 1; }

# If package.yml declares arch: all, use it regardless of the build arch.
PKG_ARCH="$(yq e '.arch // ""' "$PKG_YAML")"
[[ "$PKG_ARCH" == "all" ]] && ARCH="all"

# Resolve installed package name (produces[0] or fallback to pkg key).
DEB_NAME="$(yq e '.produces[0] // ""' "$PKG_YAML")"
DEB_NAME="${DEB_NAME:-${PKG_KEY}}"

SECTION="$(yq e '.section'   "$PKG_YAML")"
PRIORITY="$(yq e '.priority' "$PKG_YAML")"
HOMEPAGE="$(yq e '.homepage' "$PKG_YAML")"
DESC_SHORT="$(yq e '.description' "$PKG_YAML" | head -1)"
DESC_LONG="$(yq e '.description'  "$PKG_YAML" | tail -n +2 | sed 's/^[[:space:]]*$/./' | sed 's/^/ /')"
RUNTIME_DEPS="$(yq e '.runtime_depends // [] | join(", ")' "$PKG_YAML")"

# Append extra depends (e.g. from depends_on in versions.yml).
if [[ -n "$EXTRA_DEPENDS" ]]; then
  RUNTIME_DEPS="${RUNTIME_DEPS:+${RUNTIME_DEPS}, }${EXTRA_DEPENDS}"
fi

DEB_ROOT="/tmp/deb/${DEB_NAME}_${VERSION}_${ARCH}"
mkdir -p "${DEB_ROOT}/DEBIAN"
cp -r "${STAGED_DIR}/." "${DEB_ROOT}/"

SIZE="$(du -sk "$STAGED_DIR" | cut -f1)"

CONTROL_FILE="${DEB_ROOT}/DEBIAN/control"
printf "Package: %s\n"        "${DEB_NAME}"                      > "$CONTROL_FILE"
printf "Version: %s\n"        "${VERSION}"                       >> "$CONTROL_FILE"
printf "Architecture: %s\n"   "${ARCH}"                          >> "$CONTROL_FILE"
printf "Maintainer: %s\n"     "omakasui <packages@omakasui.org>" >> "$CONTROL_FILE"
printf "Installed-Size: %s\n" "${SIZE}"                          >> "$CONTROL_FILE"
[[ -n "${RUNTIME_DEPS}" ]] && \
  printf "Depends: %s\n"      "${RUNTIME_DEPS}"                  >> "$CONTROL_FILE"
printf "Section: %s\n"        "${SECTION}"                       >> "$CONTROL_FILE"
printf "Priority: %s\n"       "${PRIORITY}"                      >> "$CONTROL_FILE"
printf "Homepage: %s\n"       "${HOMEPAGE}"                      >> "$CONTROL_FILE"
printf "Description: %s\n"    "${DESC_SHORT}"                    >> "$CONTROL_FILE"
[[ -n "${DESC_LONG}" ]] && printf "%s\n" "${DESC_LONG}"          >> "$CONTROL_FILE"

echo "--- control file ---"
cat "$CONTROL_FILE"
echo "--------------------"

mkdir -p "$OUTPUT_DIR"
fakeroot dpkg-deb --build "${DEB_ROOT}" \
  "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}_${DISTRO}_${ARCH}.deb"

echo "Built: $(ls -lh "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}_${DISTRO}_${ARCH}.deb")"