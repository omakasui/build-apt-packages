#!/usr/bin/env bash
# passthrough.sh — Download an upstream .deb and repackage it with debian/ templates.
# Usage: ./scripts/passthrough.sh <package> [--distro <distro>] [--arch <arch>]
#
# Requires package.yml to have a 'source' section with the upstream URL:
#   source:
#     url: "https://.../@VERSION@-linux-@ARCH@.deb"   # or
#     url_amd64: "https://.../@VERSION@-x86_64.deb"
#     url_arm64: "https://.../@VERSION@-aarch64.deb"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_cmd yq fakeroot dpkg-deb curl awk

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
      sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
      exit 0
      ;;
    -*) die "unknown flag: $1" ;;
    *)  PKG="$1"; shift ;;
  esac
done

[[ -z "$PKG" ]] && die "Usage: passthrough.sh <package> [--distro <distro>] [--arch <arch>] [--output-dir <dir>]"

cd "${REPO_ROOT}"

# Read metadata

PKG_DIR="packages/${PKG}"
[[ -d "$PKG_DIR" ]] || die "${PKG_DIR}/ not found"
PKG_YAML="${PKG_DIR}/package.yml"
[[ -f "$PKG_YAML" ]] || die "${PKG_YAML} not found"
DEBIAN_DIR="${PKG_DIR}/debian"
[[ -d "$DEBIAN_DIR" ]] || die "${DEBIAN_DIR}/ not found — passthrough packages require a debian/ directory"
[[ -f "${DEBIAN_DIR}/control" ]] || die "${DEBIAN_DIR}/control not found"

VERSION=$(yq e ".${PKG}.version // \"\"" versions.yml)
[[ -n "$VERSION" && "$VERSION" != "null" ]] || die "${PKG} not found in versions.yml"

[[ -z "$DISTRO" ]] && DISTRO=$(yq e '.distros | keys | .[0]' build-matrix.yml)
SUITE=$(yq e ".distros.${DISTRO}.suite // \"\"" build-matrix.yml)
[[ -n "$SUITE" && "$SUITE" != "null" ]] || die "distro '${DISTRO}' not found in build-matrix.yml"

PKG_ARCH=$(yq e '.arch // ""' "$PKG_YAML")

# Skip builds this package doesn't target.
if [[ "$PKG_ARCH" == "all" && "$ARCH" == "arm64" ]]; then
  info "arch: all — skipping arm64 build."; exit 0
elif [[ -n "$PKG_ARCH" && "$PKG_ARCH" != "all" && "$PKG_ARCH" != "$ARCH" ]]; then
  info "arch: ${PKG_ARCH} — skipping ${ARCH} build."; exit 0
fi

CTRL_ARCH="$ARCH"
[[ "$PKG_ARCH" == "all" ]] && CTRL_ARCH="all"

# Resolve source URL

# Try arch-specific URL first, fall back to generic URL.
SOURCE_URL=$(yq e ".source.url_${ARCH} // \"\"" "$PKG_YAML")
[[ -z "$SOURCE_URL" || "$SOURCE_URL" == "null" ]] && \
  SOURCE_URL=$(yq e '.source.url // ""' "$PKG_YAML")
[[ -z "$SOURCE_URL" || "$SOURCE_URL" == "null" ]] && \
  die "No source URL in ${PKG_YAML}. Set source.url or source.url_${ARCH}."

SOURCE_URL="${SOURCE_URL//@VERSION@/${VERSION}}"
SOURCE_URL="${SOURCE_URL//@ARCH@/${ARCH}}"

mapfile -t PRODUCE_NAMES < <(yq e '.produces // [] | .[]' "$PKG_YAML")
if [[ ${#PRODUCE_NAMES[@]} -eq 0 ]]; then
  mapfile -t PRODUCE_NAMES < <(grep '^Package:' "${DEBIAN_DIR}/control" | awk '{print $2}')
  [[ ${#PRODUCE_NAMES[@]} -eq 0 ]] && PRODUCE_NAMES=("${PKG}")
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Package : ${PKG}"
echo "  Version : ${VERSION}"
echo "  Distro  : ${DISTRO}  (suite=${SUITE})"
echo "  Arch    : ${ARCH}  (control: ${CTRL_ARCH})"
echo "  URL     : ${SOURCE_URL}"
echo "═══════════════════════════════════════════════════════════"

OUTPUT_DIR="${OUTPUT_DIR_OVERRIDE:-${REPO_ROOT}/output/${PKG}}"
mkdir -p "$OUTPUT_DIR"

WORK_TMP="$(mktemp -d)"
BUILD_TMP="$(mktemp -d)"
trap 'rm -rf "$WORK_TMP" "$BUILD_TMP"' EXIT

# Download upstream .deb

UPSTREAM_DEB="${WORK_TMP}/upstream.deb"
step "Downloading upstream .deb..."
curl -fsSL --retry 3 -o "$UPSTREAM_DEB" "$SOURCE_URL" \
  || die "Failed to download: ${SOURCE_URL}"

# Extract upstream .deb

UPSTREAM_EXTRACTED="${WORK_TMP}/extracted"
mkdir -p "$UPSTREAM_EXTRACTED"
step "Extracting..."
dpkg-deb -R "$UPSTREAM_DEB" "$UPSTREAM_EXTRACTED"

# Save the original package name (before any renaming in the overlay).
OLD_PKG=$(grep '^Package:' "${UPSTREAM_EXTRACTED}/DEBIAN/control" | awk '{print $2}')

RFC2822_DATE=$(date -R)

# Assemble .deb(s)

step "Assembling .deb(s)..."
for DEB_NAME in "${PRODUCE_NAMES[@]}"; do
  DEB_ROOT="${BUILD_TMP}/${DEB_NAME}"
  cp -r "${UPSTREAM_EXTRACTED}/." "${DEB_ROOT}/"

  # Strip multi-stanza control — some upstream packages include extra stanzas.
  awk 'BEGIN{p=1} /^$/{p=0} p{print}' "${DEB_ROOT}/DEBIAN/control" \
    > "${WORK_TMP}/control.clean"
  mv "${WORK_TMP}/control.clean" "${DEB_ROOT}/DEBIAN/control"

  # dpkg-deb rejects non-absolute paths in conffiles.
  if [[ -f "${DEB_ROOT}/DEBIAN/conffiles" ]]; then
    sed -i '/^[[:space:]]*$/d' "${DEB_ROOT}/DEBIAN/conffiles"
    [[ ! -s "${DEB_ROOT}/DEBIAN/conffiles" ]] && rm "${DEB_ROOT}/DEBIAN/conffiles"
  fi

  # Apply debian/control overlay — keeps upstream Depends/Description,
  # overrides Maintainer/Version and any other fields listed in the overlay.
  if [[ -f "${DEBIAN_DIR}/control" ]]; then
    OVERLAY_PROCESSED=$(sed \
      -e "s|@VERSION@|${VERSION}-1+${SUITE}|g" \
      -e "s|@SUITE@|${SUITE}|g" \
      -e "s|@ARCH@|${CTRL_ARCH}|g" \
      -e "s|@PACKAGE@|${DEB_NAME}|g" \
      -e "s|@DATE@|${RFC2822_DATE}|g" \
      "${DEBIAN_DIR}/control")

    while IFS= read -r line; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      field="${line%%:*}"
      [[ -z "$field" || "$field" == *" "* ]] && continue
      if grep -q "^${field}:" "${DEB_ROOT}/DEBIAN/control"; then
        escaped=$(printf '%s\n' "$line" | sed 's/[\\&]/\\&/g')
        sed -i "s|^${field}:.*|${escaped}|" "${DEB_ROOT}/DEBIAN/control"
      else
        printf '%s\n' "$line" >> "${DEB_ROOT}/DEBIAN/control"
      fi
    done <<< "$OVERLAY_PROCESSED"
  fi

  INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "${DEB_ROOT}" | cut -f1)
  if grep -q "^Installed-Size:" "${DEB_ROOT}/DEBIAN/control"; then
    sed -i "s|^Installed-Size:.*|Installed-Size: ${INSTALLED_SIZE}|" "${DEB_ROOT}/DEBIAN/control"
  else
    echo "Installed-Size: ${INSTALLED_SIZE}" >> "${DEB_ROOT}/DEBIAN/control"
  fi

  if [[ -n "$OLD_PKG" && "$OLD_PKG" != "$DEB_NAME" ]]; then
    if [[ -d "${DEB_ROOT}/usr/share/doc/${OLD_PKG}" ]]; then
      mv "${DEB_ROOT}/usr/share/doc/${OLD_PKG}" "${DEB_ROOT}/usr/share/doc/${DEB_NAME}"
    fi
  fi

  # changelog.Debian.gz + copyright are required by Debian Policy §12.7.
  DOC_DIR="${DEB_ROOT}/usr/share/doc/${DEB_NAME}"
  mkdir -p "$DOC_DIR"
  if [[ -f "${DEBIAN_DIR}/changelog" ]]; then
    CHANGELOG_TMP="${BUILD_TMP}/changelog.${DEB_NAME}"
    sed \
      -e "s|@VERSION@|${VERSION}-1+${SUITE}|g" \
      -e "s|@SUITE@|${SUITE}|g" \
      -e "s|@PACKAGE@|${DEB_NAME}|g" \
      -e "s|@DATE@|${RFC2822_DATE}|g" \
      "${DEBIAN_DIR}/changelog" > "$CHANGELOG_TMP"
    gzip -9 -n -c "$CHANGELOG_TMP" > "${DOC_DIR}/changelog.Debian.gz"
  fi
  [[ -f "${DEBIAN_DIR}/copyright" ]] && cp "${DEBIAN_DIR}/copyright" "${DOC_DIR}/copyright"

  for script in postinst preinst prerm postrm; do
    src="${DEBIAN_DIR}/${script}"
    [[ -f "$src" ]] || continue
    cp "$src" "${DEB_ROOT}/DEBIAN/${script}"
    chmod 755 "${DEB_ROOT}/DEBIAN/${script}"
  done

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