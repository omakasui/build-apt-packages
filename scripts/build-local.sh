#!/usr/bin/env bash
# build-local.sh — Build a package locally using Docker.
# Usage: ./scripts/build-local.sh <package> [--distro <distro>] [--arch <arch>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

require_cmd docker yq fakeroot dpkg-deb


PKG=""
DISTRO=""
ARCH="amd64"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro) DISTRO="$2"; shift 2 ;;
    --arch)   ARCH="$2";   shift 2 ;;
    --help|-h)
      sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
      exit 0
      ;;
    -*)       die "unknown flag: $1" ;;
    *)        PKG="$1"; shift ;;
  esac
done

[[ -z "$PKG" ]] && die "Usage: build-local.sh <package> [--distro <distro>] [--arch <arch>]"

cd "$(repo_root)"

VERSION=$(pkg_version "$PKG")
PKG_DIR="packages/${PKG}"
[[ -d "$PKG_DIR" ]] || die "${PKG_DIR}/ not found"

[[ -z "$DISTRO" ]] && DISTRO=$(matrix_default_distro)
BASE_IMAGE=$(matrix_base_image "$DISTRO")
DEPENDS_ON=$(pkg_depends_on "$PKG")

# Skip builds for packages that declare a specific arch
PKG_ARCH="$(pkg_arch "$PKG")"
if [[ "$PKG_ARCH" == "all" && "$ARCH" == "arm64" ]]; then
  info "Package declares arch: all — skipping arm64 build."
  exit 0
elif [[ -n "$PKG_ARCH" && "$PKG_ARCH" != "all" && "$PKG_ARCH" != "$ARCH" ]]; then
  info "Package declares arch: ${PKG_ARCH} — skipping ${ARCH} build."
  exit 0
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Package : ${PKG}"
echo "  Version : ${VERSION}"
echo "  Distro  : ${DISTRO} (${BASE_IMAGE})"
echo "  Arch    : ${ARCH}"
[[ -n "$DEPENDS_ON" && "$DEPENDS_ON" != "null" ]] && echo "  Deps    : ${DEPENDS_ON}"
echo "═══════════════════════════════════════════════════════════"


if [[ -n "$DEPENDS_ON" && "$DEPENDS_ON" != "null" ]]; then
  bash "${SCRIPT_DIR}/download-deps.sh" \
    --package "$PKG" --distro "$DISTRO" --arch "$ARCH" --depends-on "$DEPENDS_ON"
fi

IMAGE_TAG="omakasui-build-${PKG}:local"

info "Building Docker image..."
docker buildx build \
  --platform "linux/${ARCH}" \
  --load \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  --build-arg "VERSION=${VERSION}" \
  --tag "$IMAGE_TAG" \
  "${PKG_DIR}/"

OUTPUT_DIR="$(repo_root)/output/${PKG}"
mkdir -p "$OUTPUT_DIR"

info "Extracting and assembling .deb..."
bash "${SCRIPT_DIR}/extract-and-assemble.sh" \
  --image      "$IMAGE_TAG" \
  --package    "$PKG" \
  --version    "$VERSION" \
  --arch       "$ARCH" \
  --distro     "$DISTRO" \
  --output-dir "$OUTPUT_DIR" \
  --depends-on "$DEPENDS_ON"

echo ""
info "Done. Output in ${OUTPUT_DIR}/"
ls -lh "${OUTPUT_DIR}/"*.deb 2>/dev/null
