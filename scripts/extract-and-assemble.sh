#!/usr/bin/env bash
# extract-and-assemble.sh — Extract Docker build output and assemble .deb.
# Shared by CI and build-local.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

IMAGE=""
PKG=""
VERSION=""
ARCH=""
DISTRO=""
OUTPUT_DIR=""
DEPENDS_ON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)       IMAGE="$2";      shift 2 ;;
    --package)     PKG="$2";        shift 2 ;;
    --version)     VERSION="$2";    shift 2 ;;
    --arch)        ARCH="$2";       shift 2 ;;
    --distro)      DISTRO="$2";     shift 2 ;;
    --output-dir)  OUTPUT_DIR="$2"; shift 2 ;;
    --depends-on)  DEPENDS_ON="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$IMAGE"      ]] && die "--image is required"
[[ -z "$PKG"        ]] && die "--package is required"
[[ -z "$VERSION"    ]] && die "--version is required"
[[ -z "$ARCH"       ]] && die "--arch is required"
[[ -z "$DISTRO"     ]] && die "--distro is required"
[[ -z "$OUTPUT_DIR" ]] && die "--output-dir is required"

PKG_YAML="$(repo_root)/packages/${PKG}/package.yml"
[[ -f "$PKG_YAML" ]] || die "${PKG_YAML} not found"

PKG_TYPE=$(pkg_type "$PKG")

CID=$(docker create --platform "linux/${ARCH}" "$IMAGE")
trap 'docker rm "$CID" >/dev/null 2>&1 || true' EXIT

mkdir -p "$OUTPUT_DIR"

if [[ "$PKG_TYPE" == "repackage" ]]; then
  step "Extracting repackaged .deb(s)..."
  REPACK_TMP="$(mktemp -d)"
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

else
  step "Extracting staged tree..."
  STAGED_TMP="$(mktemp -d)"
  docker cp "${CID}:/output/staged/." "$STAGED_TMP/"

  EXTRA_DEPS=""
  if [[ -n "$DEPENDS_ON" ]]; then
    EXTRA_DEPS=$(build_extra_depends "$DEPENDS_ON")
  fi

  step "Assembling .deb..."
  bash "${SCRIPT_DIR}/assemble-deb.sh" \
    --staged      "$STAGED_TMP" \
    --pkg-yaml    "$PKG_YAML" \
    --key         "$PKG" \
    --version     "$VERSION" \
    --arch        "$ARCH" \
    --distro      "$DISTRO" \
    --output-dir  "$OUTPUT_DIR" \
    --extra-depends "$EXTRA_DEPS"

  rm -rf "$STAGED_TMP"
fi

info "Output:"
ls -lh "${OUTPUT_DIR}/"*.deb 2>/dev/null || warn "no .deb files produced"
