#!/usr/bin/env bash
# assemble-deb.sh — Build a .deb from a staged tree and package.yml.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

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
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$STAGED_DIR"  ]] && die "--staged is required"
[[ -z "$PKG_YAML"    ]] && die "--pkg-yaml is required"
[[ -z "$PKG_KEY"     ]] && die "--key is required"
[[ -z "$VERSION"     ]] && die "--version is required"
[[ -z "$ARCH"        ]] && die "--arch is required"
[[ -z "$DISTRO"      ]] && die "--distro is required"
[[ -z "$OUTPUT_DIR"  ]] && die "--output-dir is required"

require_cmd yq fakeroot dpkg-deb

# If package.yml declares arch: all, use it regardless of the build arch.
PKG_ARCH="$(yq e '.arch // ""' "$PKG_YAML")"
[[ "$PKG_ARCH" == "all" ]] && ARCH="all"

# Resolve all package names to produce (produces[] or fallback to pkg key).
mapfile -t PRODUCE_NAMES < <(yq e '.produces // [] | .[]' "$PKG_YAML")
[[ ${#PRODUCE_NAMES[@]} -eq 0 ]] && PRODUCE_NAMES=("${PKG_KEY}")

SECTION="$(yq e '.section'   "$PKG_YAML")"
PRIORITY="$(yq e '.priority' "$PKG_YAML")"
HOMEPAGE="$(yq e '.homepage' "$PKG_YAML")"
DESC_SHORT="$(yq e '.description' "$PKG_YAML" | head -1)"
DESC_LONG="$(yq e '.description'  "$PKG_YAML" | tail -n +2 | sed 's/^[[:space:]]*$/./' | sed 's/^/ /')"
RUNTIME_DEPS="$(yq e '.runtime_depends // [] | join(", ")' "$PKG_YAML")"
CONFLICTS="$(yq e '.conflicts // [] | join(", ")' "$PKG_YAML")"
REPLACES="$(yq e '.replaces  // [] | join(", ")' "$PKG_YAML")"
PROVIDES="$(yq e '.provides  // [] | join(", ")' "$PKG_YAML")"

# Append extra depends (e.g. from depends_on in versions.yml).
if [[ -n "$EXTRA_DEPENDS" ]]; then
  RUNTIME_DEPS="${RUNTIME_DEPS:+${RUNTIME_DEPS}, }${EXTRA_DEPENDS}"
fi

SIZE="$(du -sk "$STAGED_DIR" | cut -f1)"

BUILD_TMP="$(mktemp -d)"
trap 'rm -rf "$BUILD_TMP"' EXIT

mkdir -p "$OUTPUT_DIR"
for DEB_NAME in "${PRODUCE_NAMES[@]}"; do
  DEB_ROOT="${BUILD_TMP}/${DEB_NAME}_${VERSION}_${ARCH}"
  mkdir -p "${DEB_ROOT}/DEBIAN"
  cp -r "${STAGED_DIR}/." "${DEB_ROOT}/"

  CONTROL_FILE="${DEB_ROOT}/DEBIAN/control"
  printf "Package: %s\n"        "${DEB_NAME}"                      > "$CONTROL_FILE"
  printf "Version: %s\n"        "${VERSION}"                       >> "$CONTROL_FILE"
  printf "Architecture: %s\n"   "${ARCH}"                          >> "$CONTROL_FILE"
  printf "Maintainer: %s\n"     "omakasui <packages@omakasui.org>" >> "$CONTROL_FILE"
  printf "Installed-Size: %s\n" "${SIZE}"                          >> "$CONTROL_FILE"
  [[ -n "${RUNTIME_DEPS}" ]] && \
    printf "Depends: %s\n"      "${RUNTIME_DEPS}"                  >> "$CONTROL_FILE"
  [[ -n "${CONFLICTS}" ]] && \
    printf "Conflicts: %s\n"    "${CONFLICTS}"                     >> "$CONTROL_FILE"
  [[ -n "${REPLACES}" ]]  && \
    printf "Replaces: %s\n"     "${REPLACES}"                      >> "$CONTROL_FILE"
  [[ -n "${PROVIDES}" ]]  && \
    printf "Provides: %s\n"     "${PROVIDES}"                      >> "$CONTROL_FILE"
  printf "Section: %s\n"        "${SECTION}"                       >> "$CONTROL_FILE"
  printf "Priority: %s\n"       "${PRIORITY}"                      >> "$CONTROL_FILE"
  printf "Homepage: %s\n"       "${HOMEPAGE}"                      >> "$CONTROL_FILE"
  printf "Description: %s\n"    "${DESC_SHORT}"                    >> "$CONTROL_FILE"
  [[ -n "${DESC_LONG}" ]] && printf "%s\n" "${DESC_LONG}"          >> "$CONTROL_FILE"

  echo "--- control file ---"
  cat "$CONTROL_FILE"
  echo "--------------------"

  fakeroot dpkg-deb --build "${DEB_ROOT}" \
    "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}_${DISTRO}_${ARCH}.deb"

  echo "Built: $(ls -lh "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}_${DISTRO}_${ARCH}.deb")"
done