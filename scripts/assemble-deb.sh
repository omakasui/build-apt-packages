#!/usr/bin/env bash
# assemble-deb.sh — Assemble a .deb from a staged directory tree and a package.yml.
#
# Usage (called by the workflow after docker cp /output/staged):
#   assemble-deb.sh <staged-dir> <package.yml> <pkg-key> <version> <arch> <distro> <output-dir> [extra-depends]
#
# Arguments:
#   staged-dir    Directory whose contents become the .deb payload (e.g. /tmp/staged)
#   package.yml   Path to the package.yml for this package
#   pkg-key       Key name in versions.yml (used as fallback if produces[] is empty)
#   version       Package version string
#   arch          Target architecture (amd64 | arm64)
#   distro        Distro key from build-matrix.yml (e.g. debian13, ubuntu2404)
#   output-dir    Directory to write the final .deb into
#   extra-depends Optional comma-separated additional Depends entries
#
# Reads from package.yml: produces[], arch, section, priority, homepage, description, runtime_depends
# If arch: all is set in package.yml, overrides the passed-in arch for control file and filename.

set -euo pipefail

STAGED_DIR="${1:?missing staged-dir}"
PKG_YAML="${2:?missing package.yml}"
PKG_KEY="${3:?missing pkg-key}"
VERSION="${4:?missing version}"
ARCH="${5:?missing arch}"
DISTRO="${6:?missing distro}"
OUTPUT_DIR="${7:?missing output-dir}"
EXTRA_DEPENDS="${8:-}"

# If package.yml declares arch: all, use it regardless of the build arch.
PKG_ARCH="$(yq e '.arch // ""' "$PKG_YAML")"
[[ "$PKG_ARCH" == "all" ]] && ARCH="all"

command -v yq  >/dev/null || { echo "ERROR: yq not found"; exit 1; }
command -v fakeroot >/dev/null || { echo "ERROR: fakeroot not found"; exit 1; }
command -v dpkg-deb >/dev/null || { echo "ERROR: dpkg-deb not found"; exit 1; }

# Resolve installed package name (produces[0] or fallback to pkg key).
DEB_NAME="$(yq e '.produces[0] // ""' "$PKG_YAML")"
DEB_NAME="${DEB_NAME:-${PKG_KEY}}"

SECTION="$(yq e '.section'   "$PKG_YAML")"
PRIORITY="$(yq e '.priority' "$PKG_YAML")"
HOMEPAGE="$(yq e '.homepage' "$PKG_YAML")"
DESC_SHORT="$(yq e '.description' "$PKG_YAML" | head -1)"
DESC_LONG="$(yq e '.description' "$PKG_YAML" | tail -n +2 | sed 's/^[[:space:]]*$/./' | sed 's/^/ /')"
RUNTIME_DEPS="$(yq e '.runtime_depends // [] | join(", ")' "$PKG_YAML")"

# Append extra depends (e.g. from depends_on in versions.yml).
if [[ -n "$EXTRA_DEPENDS" ]]; then
  if [[ -n "$RUNTIME_DEPS" ]]; then
    RUNTIME_DEPS="${RUNTIME_DEPS}, ${EXTRA_DEPENDS}"
  else
    RUNTIME_DEPS="${EXTRA_DEPENDS}"
  fi
fi

DEB_ROOT="/tmp/deb/${DEB_NAME}_${VERSION}_${ARCH}"
mkdir -p "${DEB_ROOT}/DEBIAN"
cp -r "${STAGED_DIR}/." "${DEB_ROOT}/"

SIZE="$(du -sk "$STAGED_DIR" | cut -f1)"

CONTROL_FILE="${DEB_ROOT}/DEBIAN/control"
printf "Package: %s\n"        "${DEB_NAME}"                       > "$CONTROL_FILE"
printf "Version: %s\n"        "${VERSION}"                        >> "$CONTROL_FILE"
printf "Architecture: %s\n"   "${ARCH}"                           >> "$CONTROL_FILE"
printf "Maintainer: %s\n"     "omakasui <packages@omakasui.org>"  >> "$CONTROL_FILE"
printf "Installed-Size: %s\n" "${SIZE}"                           >> "$CONTROL_FILE"
[[ -n "${RUNTIME_DEPS}" ]] && \
  printf "Depends: %s\n"      "${RUNTIME_DEPS}"                   >> "$CONTROL_FILE"
printf "Section: %s\n"        "${SECTION}"                        >> "$CONTROL_FILE"
printf "Priority: %s\n"       "${PRIORITY}"                       >> "$CONTROL_FILE"
printf "Homepage: %s\n"       "${HOMEPAGE}"                       >> "$CONTROL_FILE"
printf "Description: %s\n"    "${DESC_SHORT}"                     >> "$CONTROL_FILE"
[[ -n "${DESC_LONG}" ]] && printf "%s\n" "${DESC_LONG}"           >> "$CONTROL_FILE"

echo "--- control file ---"
cat "$CONTROL_FILE"
echo "--------------------"

mkdir -p "$OUTPUT_DIR"
fakeroot dpkg-deb --build "${DEB_ROOT}" \
  "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}_${DISTRO}_${ARCH}.deb"

echo "Built: $(ls -lh "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}_${DISTRO}_${ARCH}.deb")"