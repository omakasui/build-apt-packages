#!/usr/bin/env bash
# build.sh — Build a package (type: build or repackage) using Docker.
# Usage: ./scripts/build.sh <package> [--distro <distro>] [--arch <arch>] [--output-dir <dir>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_cmd docker yq fakeroot dpkg-deb

PKG=""
DISTRO=""
ARCH="amd64"
OUTPUT_DIR_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro)     DISTRO="$2";              shift 2 ;;
    --arch)       ARCH="$2";                shift 2 ;;
    --output-dir) OUTPUT_DIR_OVERRIDE="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *)  PKG="$1"; shift ;;
  esac
done

[[ -z "$PKG" ]] && die "Usage: build.sh <package> [--distro <distro>] [--arch <arch>] [--output-dir <dir>]"

cd "${REPO_ROOT}"

# Read metadata

PKG_DIR="packages/${PKG}"
[[ -d "$PKG_DIR" ]] || die "${PKG_DIR}/ not found"
PKG_YAML="${PKG_DIR}/package.yml"
[[ -f "$PKG_YAML" ]] || die "${PKG_YAML} not found"

VERSION=$(yq e ".${PKG}.version // \"\"" versions.yml)
[[ -n "$VERSION" && "$VERSION" != "null" ]] || die "${PKG} not found in versions.yml"

[[ -z "$DISTRO" ]] && DISTRO=$(yq e '.distros | keys | .[0]' build-matrix.yml)
BASE_IMAGE=$(yq e ".distros.${DISTRO}.base_image // \"\"" build-matrix.yml)
[[ -n "$BASE_IMAGE" && "$BASE_IMAGE" != "null" ]] || die "distro '${DISTRO}' not found in build-matrix.yml"
SUITE=$(yq e ".distros.${DISTRO}.suite // \"\"" build-matrix.yml)

DEPENDS_ON=$(yq e ".${PKG}.depends_on | join(\",\")" versions.yml)
PKG_TYPE=$(yq e '.type // "build"' "$PKG_YAML")
PKG_ARCH=$(yq e '.arch // ""' "$PKG_YAML")

# Skip builds this package doesn't target.
if [[ "$PKG_ARCH" == "all" && "$ARCH" == "arm64" ]]; then
  info "arch: all — skipping arm64 build."; exit 0
elif [[ -n "$PKG_ARCH" && "$PKG_ARCH" != "all" && "$PKG_ARCH" != "$ARCH" ]]; then
  info "arch: ${PKG_ARCH} — skipping ${ARCH} build."; exit 0
fi

# CTRL_ARCH is the value for Architecture: in the control file.
CTRL_ARCH="$ARCH"
[[ "$PKG_ARCH" == "all" ]] && CTRL_ARCH="all"

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
  --tag "$IMAGE_TAG" \
  "${PKG_DIR}/"

# Extract output from container

CID=$(docker create --platform "linux/${ARCH}" "$IMAGE_TAG")
trap 'docker rm "$CID" >/dev/null 2>&1 || true' EXIT

# Legacy repackage path: .deb assembled inside Docker (elephant, yaru-theme).
# These packages have no debian/ directory and produce .deb directly in /output/.
if [[ "$PKG_TYPE" == "repackage" && ! -d "${PKG_DIR}/debian" ]]; then
  step "Extracting pre-assembled .deb(s) from container..."
  REPACK_TMP="$(mktemp -d)"
  trap 'docker rm "$CID" >/dev/null 2>&1 || true; rm -rf "$REPACK_TMP"' EXIT
  docker cp "${CID}:/output/." "$REPACK_TMP/"
  for f in "$REPACK_TMP"/*.deb; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    stripped="${base%_*.deb}"
    if [[ "$base" == *_all.deb ]]; then
      mv "$f" "${OUTPUT_DIR}/${stripped}_${DISTRO}_all.deb"
    else
      mv "$f" "${OUTPUT_DIR}/${stripped}_${DISTRO}_${ARCH}.deb"
    fi
  done
  rm -rf "$REPACK_TMP"
  info "Output:"; ls -lh "${OUTPUT_DIR}/"*.deb 2>/dev/null || warn "no .deb files produced"
  exit 0
fi

# Extract staged tree

step "Extracting staged tree from container..."
STAGED_TMP="$(mktemp -d)"
BUILD_TMP="$(mktemp -d)"
trap 'docker rm "$CID" >/dev/null 2>&1 || true; rm -rf "$STAGED_TMP" "$BUILD_TMP"' EXIT
docker cp "${CID}:/output/staged/." "$STAGED_TMP/"

DEBIAN_DIR="${PKG_DIR}/debian"
[[ -d "$DEBIAN_DIR" && -f "${DEBIAN_DIR}/control" ]] || \
  die "debian/control not found for ${PKG} — add a debian/ directory"

mapfile -t PRODUCE_NAMES < <(yq e '.produces // [] | .[]' "$PKG_YAML")
if [[ ${#PRODUCE_NAMES[@]} -eq 0 ]]; then
  mapfile -t PRODUCE_NAMES < <(grep '^Package:' "${DEBIAN_DIR}/control" | awk '{print $2}')
  [[ ${#PRODUCE_NAMES[@]} -eq 0 ]] && PRODUCE_NAMES=("${PKG}")
fi

# Assemble .deb(s)

step "Assembling from debian/ template..."

INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "$STAGED_TMP" | cut -f1)
RFC2822_DATE=$(date -R)

for DEB_NAME in "${PRODUCE_NAMES[@]}"; do
  # Support per-package control files for multi-output packages.
  CTRL_TEMPLATE="${DEBIAN_DIR}/control"
  [[ -f "${DEBIAN_DIR}/control.${DEB_NAME}" ]] && CTRL_TEMPLATE="${DEBIAN_DIR}/control.${DEB_NAME}"

  DEB_ROOT="${BUILD_TMP}/${DEB_NAME}"
  mkdir -p "${DEB_ROOT}/DEBIAN"
  cp -r "${STAGED_TMP}/." "${DEB_ROOT}/"
  rm -f "${DEB_ROOT}/DEBIAN/control"

  sed \
    -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@SUITE@|${SUITE}|g" \
    -e "s|@ARCH@|${CTRL_ARCH}|g" \
    -e "s|@INSTALLED_SIZE@|${INSTALLED_SIZE}|g" \
    -e "s|@PACKAGE@|${DEB_NAME}|g" \
    -e "s|@DATE@|${RFC2822_DATE}|g" \
    "${CTRL_TEMPLATE}" > "${DEB_ROOT}/DEBIAN/control"

  for script in postinst preinst prerm postrm; do
    src="${DEBIAN_DIR}/${script}"
    [[ -f "$src" ]] || continue
    cp "$src" "${DEB_ROOT}/DEBIAN/${script}"
    chmod 755 "${DEB_ROOT}/DEBIAN/${script}"
  done

  # changelog.Debian.gz + copyright are required by Debian Policy §12.7.
  DOC_DIR="${DEB_ROOT}/usr/share/doc/${DEB_NAME}"
  mkdir -p "$DOC_DIR"
  if [[ -f "${DEBIAN_DIR}/changelog" ]]; then
    CHANGELOG_TMP="${BUILD_TMP}/changelog.${DEB_NAME}"
    sed \
      -e "s|@VERSION@|${VERSION}|g" \
      -e "s|@SUITE@|${SUITE}|g" \
      -e "s|@PACKAGE@|${DEB_NAME}|g" \
      -e "s|@DATE@|${RFC2822_DATE}|g" \
      "${DEBIAN_DIR}/changelog" > "$CHANGELOG_TMP"
    gzip -9 -n -c "$CHANGELOG_TMP" > "${DOC_DIR}/changelog.Debian.gz"
  fi
  [[ -f "${DEBIAN_DIR}/copyright" ]] && cp "${DEBIAN_DIR}/copyright" "${DOC_DIR}/copyright"

  echo "--- control ---"
  cat "${DEB_ROOT}/DEBIAN/control"
  echo "---------------"

  DEB_FILE="${OUTPUT_DIR}/${DEB_NAME}_${VERSION}-1+${SUITE}_${CTRL_ARCH}.deb"
  fakeroot dpkg-deb --build "${DEB_ROOT}" "${DEB_FILE}"
  step "Built: $(ls -lh "${DEB_FILE}" | awk '{print $5, $9}')"
done

# Lintian

if command -v lintian >/dev/null 2>&1; then
  step "Running lintian..."
  LINTIAN_OPTS=(--info --display-info)
  [[ -f "${DEBIAN_DIR}/lintian-overrides" ]] && \
    LINTIAN_OPTS+=(--overrides "${DEBIAN_DIR}/lintian-overrides")
  lintian "${LINTIAN_OPTS[@]}" "${OUTPUT_DIR}/"*.deb 2>/dev/null || true
fi

echo ""
info "Done. Output in ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}/"*.deb 2>/dev/null