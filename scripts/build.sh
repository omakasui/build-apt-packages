#!/usr/bin/env bash
# build.sh — Build a package (type: build or repackage) using Docker.
# Usage: ./scripts/build.sh <package> [--distro <distro>] [--arch <arch>] [--output-dir <dir>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"
# shellcheck source=lib/deb.sh
source "${SCRIPT_DIR}/lib/deb.sh"

require_cmd docker yq fakeroot dpkg-deb

parse_pkg_args "$0" "$@"

cd "${REPO_ROOT}" || die "cannot enter ${REPO_ROOT}"

# Read metadata

PKG_DIR="packages/${PKG}"
[[ -d "$PKG_DIR" ]] || die "${PKG_DIR}/ not found"
PKG_YAML="${PKG_DIR}/package.yml"
[[ -f "$PKG_YAML" ]] || die "${PKG_YAML} not found"

VERSION=$(pkg_version "$PKG")

[[ -z "$DISTRO" ]] && DISTRO=$(matrix_default_distro)
BASE_IMAGE=$(matrix_base_image "$DISTRO")
SUITE=$(matrix_suite "$DISTRO")

DEPENDS_ON=$(pkg_depends_on "$PKG")
PKG_TYPE=$(pkg_type "$PKG")
PKG_ARCH=$(pkg_arch "$PKG")

# CTRL_ARCH is the value for Architecture: in the control file.
if ! CTRL_ARCH=$(deb_control_arch "$PKG_ARCH" "$ARCH"); then
  info "arch: ${PKG_ARCH} — skipping ${ARCH} build."; exit 0
fi

OUTPUT_DIR="${OUTPUT_DIR_OVERRIDE:-${REPO_ROOT}/output/${PKG}}"
mkdir -p "$OUTPUT_DIR"

echo "═══════════════════════════════════════════════════════════"
echo "  Package : ${PKG}"
echo "  Version : ${VERSION}"
echo "  Distro  : ${DISTRO}  (${BASE_IMAGE}, suite=${SUITE})"
echo "  Arch    : ${ARCH}  (control: ${CTRL_ARCH})"
[[ -n "$DEPENDS_ON" && "$DEPENDS_ON" != "null" ]] && echo "  Deps    : ${DEPENDS_ON}"
echo "  Output  : ${OUTPUT_DIR}"
echo "═══════════════════════════════════════════════════════════"

# Download depends_on .deb files
# Deps are sibling packages required at Docker build time (e.g. ghostty → gtk4-layer-shell).

if [[ -n "$DEPENDS_ON" && "$DEPENDS_ON" != "null" ]]; then
  DEPS_DIR="${PKG_DIR}/deps"
  mkdir -p "$DEPS_DIR"
  IFS=',' read -ra DEPS <<< "$DEPENDS_ON"
  for dep in "${DEPS[@]}"; do
    [[ -z "$dep" ]] && continue
    DEP_VERSION=$(yq e ".${dep}.version // \"\"" versions.yml)
    [[ -n "$DEP_VERSION" && "$DEP_VERSION" != "null" ]] || die "dep '${dep}' not in versions.yml"
    DEP_NAME=$(yq e '.produces[0] // ""' "packages/${dep}/package.yml" 2>/dev/null || true)
    [[ -z "$DEP_NAME" || "$DEP_NAME" == "null" ]] && DEP_NAME="$dep"
    DEP_FILE="${DEPS_DIR}/${DEP_NAME}_${DEP_VERSION}-1+${SUITE}_${ARCH}.deb"
    if [[ -f "$DEP_FILE" ]]; then
      step "Dep cached: ${DEP_FILE}"; continue
    fi
    command -v gh >/dev/null 2>&1 || { warn "gh CLI not found — place ${DEP_FILE} manually"; continue; }
    step "Downloading dep: ${DEP_NAME} v${DEP_VERSION} (${SUITE}/${ARCH})..."
    gh release download "${dep}-${DEP_VERSION}" \
      --repo omakasui/build-apt-packages \
      --pattern "${DEP_NAME}_${DEP_VERSION}-1+${SUITE}_${ARCH}.deb" \
      --output "$DEP_FILE" \
      || die "Failed to download dep '${DEP_NAME} ${DEP_VERSION}'. Build '${dep}' for ${DISTRO} first."
  done
fi

# Docker build

IMAGE_TAG="omakasui-build-${PKG}:local"

info "Building Docker image..."
docker buildx build \
  --platform "linux/${ARCH}" \
  --load \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "VERSION=${VERSION}" \
  --build-arg "SUITE=${SUITE}" \
  --tag "$IMAGE_TAG" \
  "${PKG_DIR}/"

# Extract output from container

CLEANUP_PATHS=()
cleanup() {
  [[ -n "${CID:-}" ]] && docker rm "$CID" >/dev/null 2>&1
  [[ ${#CLEANUP_PATHS[@]} -gt 0 ]] && rm -rf "${CLEANUP_PATHS[@]}"
  return 0
}
trap cleanup EXIT

CID=$(docker create --platform "linux/${ARCH}" "$IMAGE_TAG")

# Legacy repackage path: .deb assembled inside Docker (elephant, yaru-theme).
# These packages have no debian/ directory and produce .deb directly in /output/.
if [[ "$PKG_TYPE" == "repackage" && ! -d "${PKG_DIR}/debian" ]]; then
  step "Extracting pre-assembled .deb(s) from container..."
  REPACK_TMP="$(mktemp -d)"; CLEANUP_PATHS+=("$REPACK_TMP")
  docker cp "${CID}:/output/." "$REPACK_TMP/"
  for f in "$REPACK_TMP"/*.deb; do
    [[ -f "$f" ]] || continue
    mv "$f" "${OUTPUT_DIR}/"
  done
  rm -rf "$REPACK_TMP"
  info "Output:"; ls -lh "${OUTPUT_DIR}/"*.deb 2>/dev/null || warn "no .deb files produced"
  exit 0
fi

# Extract staged tree

step "Extracting staged tree from container..."
STAGED_TMP="$(mktemp -d)"; CLEANUP_PATHS+=("$STAGED_TMP")
BUILD_TMP="$(mktemp -d)";  CLEANUP_PATHS+=("$BUILD_TMP")
docker cp "${CID}:/output/staged/." "$STAGED_TMP/"

DEBIAN_DIR="${PKG_DIR}/debian"
[[ -d "$DEBIAN_DIR" && -f "${DEBIAN_DIR}/control" ]] || \
  die "debian/control not found for ${PKG} — add a debian/ directory"

mapfile -t PRODUCE_NAMES < <(resolve_produces "$PKG" "$PKG_YAML" "${DEBIAN_DIR}/control")

# Split staged files across outputs

# debian/<output>.install lists that output's paths, one glob per line, relative
# to the staged tree. Outputs without a list get whatever no sibling claimed.
expand_install() {
  local list pattern m
  # Absolute: the subshell below cd's into the staged tree.
  list="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  ( cd "$STAGED_TMP" && shopt -s nullglob globstar dotglob
    while IFS= read -r pattern || [[ -n "$pattern" ]]; do
      pattern="${pattern%%#*}"
      pattern="${pattern#"${pattern%%[![:space:]]*}"}"
      pattern="${pattern%"${pattern##*[![:space:]]}"}"
      [[ -z "$pattern" ]] && continue
      for m in $pattern; do printf '%s\n' "$m"; done
    done < "$list" )
}

CLAIMED="${BUILD_TMP}/claimed"
: > "$CLAIMED"
for name in "${PRODUCE_NAMES[@]}"; do
  [[ -f "${DEBIAN_DIR}/${name}.install" ]] || continue
  expand_install "${DEBIAN_DIR}/${name}.install" >> "$CLAIMED"
done
sort -u -o "$CLAIMED" "$CLAIMED"

# Resolves one output's ELF files. Runs inside the build image: dpkg-shlibdeps
# needs the target suite's dpkg database.
# Only covers NEEDED entries — dlopen'd libraries stay in the template by hand.
resolve_shlibs() {
  local root="$1" name="$2"
  local -a rel=()
  mapfile -t rel < <( cd "$root" && find . -type f ! -path './DEBIAN/*' \
    -exec sh -c 'head -c4 "$1" | grep -qa ELF' _ {} \; -print | sed 's|^\./||' )
  [[ ${#rel[@]} -gt 0 ]] || die "${name}: no ELF files, but debian/control uses @SHLIBS_DEPENDS@"

  local -a args=()
  for f in "${rel[@]}"; do args+=("/output/staged/${f}"); done

  docker run --rm -i --platform "linux/${ARCH}" "$IMAGE_TAG" \
    bash -s -- "${args[@]}" <<'SHLIBS_EOF'
set -euo pipefail
command -v dpkg-shlibdeps >/dev/null 2>&1 || {
  echo "dpkg-shlibdeps not found" >&2
  exit 1
}
# dpkg-shlibdeps insists on running from a source tree.
mkdir -p /tmp/shlibdeps/debian
cd /tmp/shlibdeps
printf 'Source: pkg\nPackage: pkg\nArchitecture: any\n' > debian/control
# -l resolves libraries the package ships itself. No --ignore-missing-info: an
# unresolvable library fails the build instead of dropping out of Depends.
dpkg-shlibdeps -O \
  -l/output/staged/usr/lib \
  -l"/output/staged/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)" \
  "$@" \
  | grep '^shlibs:Depends=' | sed 's/^shlibs:Depends=//'
SHLIBS_EOF
}

# Assemble .deb(s)

step "Assembling from debian/ template..."

RFC2822_DATE=$(date -R)

for DEB_NAME in "${PRODUCE_NAMES[@]}"; do
  # Support per-package control files for multi-output packages.
  CTRL_TEMPLATE="${DEBIAN_DIR}/control"
  [[ -f "${DEBIAN_DIR}/control.${DEB_NAME}" ]] && CTRL_TEMPLATE="${DEBIAN_DIR}/control.${DEB_NAME}"

  DEB_ROOT="${BUILD_TMP}/${DEB_NAME}"
  mkdir -p "$DEB_ROOT"
  if [[ -f "${DEBIAN_DIR}/${DEB_NAME}.install" ]]; then
    while IFS= read -r p; do
      mkdir -p "${DEB_ROOT}/$(dirname "$p")"
      cp -a "${STAGED_TMP}/${p}" "${DEB_ROOT}/${p}"
    done < <(expand_install "${DEBIAN_DIR}/${DEB_NAME}.install")
  else
    cp -r "${STAGED_TMP}/." "${DEB_ROOT}/"
    while IFS= read -r p; do
      [[ -n "$p" ]] && rm -rf "${DEB_ROOT:?}/${p}"
    done < "$CLAIMED"
    find "$DEB_ROOT" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi
  mkdir -p "${DEB_ROOT}/DEBIAN"
  rm -f "${DEB_ROOT}/DEBIAN/control"

  SHLIBS_DEPENDS=""
  if grep -q '@SHLIBS_DEPENDS@' "$CTRL_TEMPLATE"; then
    step "Resolving library dependencies for ${DEB_NAME}..."
    SHLIBS_DEPENDS=$(resolve_shlibs "$DEB_ROOT" "$DEB_NAME") \
      || die "dpkg-shlibdeps failed for ${DEB_NAME} — add dpkg-dev to its Dockerfile build deps"
    [[ -n "$SHLIBS_DEPENDS" ]] || die "dpkg-shlibdeps produced no dependencies for ${DEB_NAME}"
    info "Resolved: ${SHLIBS_DEPENDS}"
  fi

  INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "$DEB_ROOT" | cut -f1)

  sed \
    -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@SUITE@|${SUITE}|g" \
    -e "s|@ARCH@|${CTRL_ARCH}|g" \
    -e "s|@INSTALLED_SIZE@|${INSTALLED_SIZE}|g" \
    -e "s|@PACKAGE@|${DEB_NAME}|g" \
    -e "s|@DATE@|${RFC2822_DATE}|g" \
    -e "s|@SHLIBS_DEPENDS@|${SHLIBS_DEPENDS}|g" \
    "${CTRL_TEMPLATE}" > "${DEB_ROOT}/DEBIAN/control"

  stage_maintainer_scripts "$DEB_ROOT" "$DEBIAN_DIR"
  stage_docs "$DEB_ROOT" "$DEB_NAME" "$DEBIAN_DIR" "$VERSION" "$SUITE" "$RFC2822_DATE"
  write_deb_metadata "$DEB_ROOT" "$DEB_NAME" "$VERSION"

  echo "--- control ---"
  cat "${DEB_ROOT}/DEBIAN/control"
  echo "---------------"

  finish_deb "$DEB_ROOT" "${OUTPUT_DIR}/${DEB_NAME}_${VERSION}-1+${SUITE}_${CTRL_ARCH}.deb"
done

run_lintian "$OUTPUT_DIR" "$DEBIAN_DIR"

echo ""
info "Done. Output in ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}/"*.deb 2>/dev/null