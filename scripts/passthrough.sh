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
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"
# shellcheck source=lib/deb.sh
source "${SCRIPT_DIR}/lib/deb.sh"

require_cmd yq fakeroot dpkg-deb curl awk

parse_pkg_args "$0" "$@"

cd "${REPO_ROOT}" || die "cannot enter ${REPO_ROOT}"

# Read metadata

PKG_DIR="packages/${PKG}"
[[ -d "$PKG_DIR" ]] || die "${PKG_DIR}/ not found"
PKG_YAML="${PKG_DIR}/package.yml"
[[ -f "$PKG_YAML" ]] || die "${PKG_YAML} not found"
DEBIAN_DIR="${PKG_DIR}/debian"
[[ -d "$DEBIAN_DIR" ]] || die "${DEBIAN_DIR}/ not found — passthrough packages require a debian/ directory"
[[ -f "${DEBIAN_DIR}/control" ]] || die "${DEBIAN_DIR}/control not found"

VERSION=$(pkg_version "$PKG")

[[ -z "$DISTRO" ]] && DISTRO=$(matrix_default_distro)
SUITE=$(matrix_suite "$DISTRO")

PKG_ARCH=$(pkg_arch "$PKG")
if ! CTRL_ARCH=$(deb_control_arch "$PKG_ARCH" "$ARCH"); then
  info "arch: ${PKG_ARCH} — skipping ${ARCH} build."; exit 0
fi

SOURCE_URL=$(pkg_source_url "$PKG" "$ARCH")
SOURCE_URL="${SOURCE_URL//@VERSION@/${VERSION}}"
SOURCE_URL="${SOURCE_URL//@ARCH@/${ARCH}}"

mapfile -t PRODUCE_NAMES < <(resolve_produces "$PKG" "$PKG_YAML" "${DEBIAN_DIR}/control")

echo "═══════════════════════════════════════════════════════════"
echo "  Package : ${PKG}"
echo "  Version : ${VERSION}"
echo "  Distro  : ${DISTRO}  (suite=${SUITE})"
echo "  Arch    : ${ARCH}  (control: ${CTRL_ARCH})"
echo "  URL     : ${SOURCE_URL}"
echo "═══════════════════════════════════════════════════════════"

OUTPUT_DIR="${OUTPUT_DIR_OVERRIDE:-${REPO_ROOT}/output/${PKG}}"
mkdir -p "$OUTPUT_DIR"

CLEANUP_PATHS=()
cleanup() { [[ ${#CLEANUP_PATHS[@]} -gt 0 ]] && rm -rf "${CLEANUP_PATHS[@]}"; return 0; }
trap cleanup EXIT

WORK_TMP="$(mktemp -d)"; CLEANUP_PATHS+=("$WORK_TMP")
BUILD_TMP="$(mktemp -d)"; CLEANUP_PATHS+=("$BUILD_TMP")

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
      -e "s|@VERSION@|${VERSION}|g" \
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

  stage_docs "$DEB_ROOT" "$DEB_NAME" "$DEBIAN_DIR" "$VERSION" "$SUITE" "$RFC2822_DATE"
  stage_maintainer_scripts "$DEB_ROOT" "$DEBIAN_DIR"

  # The upstream md5sums no longer match: we added docs and may have renamed the
  # doc dir. Regenerate rather than ship a stale list.
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