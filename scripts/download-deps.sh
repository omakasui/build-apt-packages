#!/usr/bin/env bash
# download-deps.sh — Download dependency .deb files from GitHub releases.
# Usage: download-deps.sh --package <name> --distro <distro> --arch <arch> --depends-on <csv>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

require_cmd yq

PKG=""
DISTRO=""
ARCH=""
DEPENDS_ON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package)    PKG="$2";        shift 2 ;;
    --distro)     DISTRO="$2";     shift 2 ;;
    --arch)       ARCH="$2";       shift 2 ;;
    --depends-on) DEPENDS_ON="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$PKG" ]]    && die "--package is required"
[[ -z "$DISTRO" ]] && die "--distro is required"
[[ -z "$ARCH" ]]   && die "--arch is required"
[[ -z "$DEPENDS_ON" ]] && exit 0

cd "$(repo_root)"

DEPS_DIR="packages/${PKG}/deps"
mkdir -p "$DEPS_DIR"

IFS=',' read -ra DEPS <<< "$DEPENDS_ON"
for dep in "${DEPS[@]}"; do
  DEP_VERSION=$(pkg_version "$dep")
  DEP_NAME=$(resolve_dep_name "$dep")
  DEP_FILE="${DEPS_DIR}/${DEP_NAME}_${DEP_VERSION}_${ARCH}.deb"

  if [[ -f "$DEP_FILE" ]]; then
    step "Dep cached: ${DEP_FILE}"
    continue
  fi

  if ! command -v gh >/dev/null 2>&1; then
    warn "gh CLI not found — place ${DEP_FILE} manually"
    continue
  fi

  step "Downloading: ${DEP_NAME} v${DEP_VERSION} (${DISTRO}/${ARCH})..."
  gh release download "${dep}-${DEP_VERSION}" \
    --repo omakasui/build-apt-packages \
    --pattern "${DEP_NAME}_${DEP_VERSION}_${DISTRO}_${ARCH}.deb" \
    --output "$DEP_FILE" || warn "failed to download ${DEP_NAME}"
done
