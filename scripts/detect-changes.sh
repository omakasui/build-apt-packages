#!/usr/bin/env bash
# detect-changes.sh — Detect changed packages and build CI matrices.
# Usage: detect-changes.sh --mode push|dispatch|distro [--package <name>] [--distro <name>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

require_cmd yq jq

MODE=""
MANUAL_PKG=""
FILTER_DISTRO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)    MODE="$2";          shift 2 ;;
    --package) MANUAL_PKG="$2";    shift 2 ;;
    --distro)  FILTER_DISTRO="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -z "$MODE" ]] && die "--mode is required (push, dispatch, or distro)"

cd "$(repo_root)"

_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "${1}=${2}" >> "$GITHUB_OUTPUT"
  else
    echo "${1}=${2}"
  fi
}

if [[ "$MODE" == "distro" ]]; then
  [[ -z "$FILTER_DISTRO" ]] && die "--distro is required for distro mode"
  # Queue all packages that include this distro (and are not frozen for its suite).
  PACKAGES=""
  while IFS= read -r pkg; do
    if pkg_distros "$pkg" | grep -qx "$FILTER_DISTRO"; then
      PACKAGES="$PACKAGES $pkg"
    fi
  done < <(pkg_all_keys)
  PACKAGES=$(echo "$PACKAGES" | xargs)
elif [[ "$MODE" == "dispatch" ]]; then
  [[ -z "$MANUAL_PKG" ]] && die "--package is required for dispatch mode"
  PACKAGES="$MANUAL_PKG"
else
  OLD_VERSIONS=$(mktemp)
  trap 'rm -f "$OLD_VERSIONS"' EXIT
  git show HEAD~1:versions.yml > "$OLD_VERSIONS" 2>/dev/null \
    || echo "---" > "$OLD_VERSIONS"

  PACKAGES=""
  while IFS= read -r pkg; do
    OLD_VER=$(yq e ".${pkg}.version // \"\"" "$OLD_VERSIONS")
    NEW_VER=$(yq e ".${pkg}.version // \"\"" versions.yml)
    if [[ "$OLD_VER" != "$NEW_VER" ]]; then
      PACKAGES="$PACKAGES $pkg"
    fi
  done < <(pkg_all_keys)
  PACKAGES=$(echo "$PACKAGES" | xargs)
fi

# Expand triggers: if a changed package declares triggers[], add them too.
TRIGGERED=""
for PKG in $PACKAGES; do
  if yq e ".${PKG}.triggers" versions.yml | grep -qv 'null'; then
    while IFS= read -r triggered; do
      [[ -z "$triggered" || "$triggered" == "null" ]] && continue
      echo "$PACKAGES $TRIGGERED" | grep -qw "$triggered" || \
        TRIGGERED="$TRIGGERED $triggered"
    done < <(yq e ".${PKG}.triggers[]" versions.yml 2>/dev/null)
  fi
done
PACKAGES=$(echo "$PACKAGES $TRIGGERED" | xargs)

if [[ -z "$PACKAGES" ]]; then
  info "No package changes detected."
  _output "builds" "[]"
  _output "build_matrix" '{"include":[]}'
  exit 0
fi

BUILDS='[]'
FLAT_MATRIX='[]'

for PKG in $PACKAGES; do
  VERSION=$(yq e ".${PKG}.version // \"\"" versions.yml)
  if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
    warn "${PKG} not found in versions.yml, skipping."
    continue
  fi

  DEPENDS=$(pkg_depends_on "$PKG")

  FROZEN_SUITES=$(yq e ".${PKG}.frozen_suites // [] | join(\" \")" versions.yml)
  MATRIX_INCLUDES='[]'
  while IFS= read -r distro; do
    # In distro mode, only include the requested distro.
    [[ -n "$FILTER_DISTRO" && "$distro" != "$FILTER_DISTRO" ]] && continue
    BASE=$(matrix_base_image "$distro")
    SUITE=$(yq e ".distros.${distro}.suite" "$(repo_root)/build-matrix.yml")
    if [[ -n "$FROZEN_SUITES" ]] && echo " $FROZEN_SUITES " | grep -q " $SUITE "; then
      info "Skip: ${PKG}/${SUITE} is frozen (frozen_suites in versions.yml)"
      continue
    fi
    while IFS= read -r arch; do
      MATRIX_INCLUDES=$(echo "$MATRIX_INCLUDES" | \
        jq --arg d "$distro" --arg b "$BASE" --arg s "$SUITE" --arg a "$arch" \
           '. += [{"distro": $d, "base": $b, "suite": $s, "arch": $a}]')

      FLAT_MATRIX=$(echo "$FLAT_MATRIX" | \
        jq --arg pkg "$PKG" --arg d "$distro" --arg b "$BASE" --arg s "$SUITE" --arg a "$arch" \
           '. += [{"package": $pkg, "distro": $d, "base": $b, "suite": $s, "arch": $a}]')
    done < <(matrix_arches "$distro")
  done < <(pkg_distros "$PKG")

  PRODUCES=$(yq e '.produces // [] | join(",")' "$(repo_root)/packages/${PKG}/package.yml")

  STABLE_RELEASE=$(yq e ".${PKG}.stable_release // false" "$(repo_root)/versions.yml")
  PKG_CHANNEL="dev"
  [[ "$STABLE_RELEASE" == "true" ]] && PKG_CHANNEL="stable"

  ENTRY=$(jq -n \
    --arg pkg "$PKG" \
    --arg ver "$VERSION" \
    --arg deps "$DEPENDS" \
    --arg prods "$PRODUCES" \
    --arg channel "$PKG_CHANNEL" \
    --argjson matrix "{\"include\": $MATRIX_INCLUDES}" \
    '{package: $pkg, version: $ver, depends_on: $deps, produces: ($prods | if . == "" then [] else split(",") end), channel: $channel, matrix: $matrix}')

  BUILDS=$(echo "$BUILDS" | jq ". += [$ENTRY]")
  info "Queued: ${PKG} ${VERSION}"
done

_output "builds" "$(echo "$BUILDS" | jq -c .)"
_output "build_matrix" "$(echo "{\"include\": $FLAT_MATRIX}" | jq -c .)"
