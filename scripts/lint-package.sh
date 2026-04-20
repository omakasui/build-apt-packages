#!/usr/bin/env bash
# lint-package.sh — Validate package definitions.
# Usage: lint-package.sh [<package>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

require_cmd yq

cd "$(repo_root)"

ERRORS=0
CHECKED=0

lint_one() {
  local key="$1"
  local pkg_dir="packages/${key}"

  CHECKED=$((CHECKED + 1))

  # versions.yml entry
  local ver
  ver=$(yq e ".${key}.version // \"\"" versions.yml)
  if [[ -z "$ver" || "$ver" == "null" ]]; then
    warn "${key}: missing from versions.yml"
    ERRORS=$((ERRORS + 1))
    return
  fi

  # Dockerfile
  if [[ ! -f "${pkg_dir}/Dockerfile" ]]; then
    warn "${key}: missing Dockerfile"
    ERRORS=$((ERRORS + 1))
  fi

  # package.yml existence
  local yaml="${pkg_dir}/package.yml"
  if [[ ! -f "$yaml" ]]; then
    warn "${key}: missing package.yml"
    ERRORS=$((ERRORS + 1))
    return
  fi

  # Required fields for type: build
  local pkg_type
  pkg_type=$(yq e '.type // "build"' "$yaml")
  if [[ "$pkg_type" == "build" ]]; then
    for field in section priority homepage description; do
      local val
      val=$(yq e ".${field} // \"\"" "$yaml")
      if [[ -z "$val" || "$val" == "null" ]]; then
        warn "${key}: missing required field '${field}' (type: build)"
        ERRORS=$((ERRORS + 1))
      fi
    done
  fi

  # distros exist in build-matrix.yml
  local valid_distros
  valid_distros=$(matrix_distro_keys | tr '\n' ' ')
  while IFS= read -r distro; do
    [[ -z "$distro" ]] && continue
    if ! echo "$valid_distros" | grep -qw "$distro"; then
      warn "${key}: distro '${distro}' not in build-matrix.yml"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(yq e '.distros // [] | .[]' "$yaml")

  # No distros declared at all
  local distro_count
  distro_count=$(yq e '.distros | length' "$yaml" 2>/dev/null || echo 0)
  if [[ "$distro_count" == "0" || "$distro_count" == "null" ]]; then
    warn "${key}: no distros declared"
    ERRORS=$((ERRORS + 1))
  fi

  # depends_on entries have package dirs
  local deps_csv
  deps_csv=$(yq e ".${key}.depends_on | join(\",\")" versions.yml)
  if [[ -n "$deps_csv" ]]; then
    IFS=',' read -ra deps <<< "$deps_csv"
    for dep in "${deps[@]}"; do
      [[ -z "$dep" ]] && continue
      if [[ ! -d "packages/${dep}" ]]; then
        warn "${key}: depends_on '${dep}' has no packages/${dep}/ directory"
        ERRORS=$((ERRORS + 1))
      fi
    done
  fi
}

if [[ ${1:-} ]]; then
  lint_one "$1"
else
  while IFS= read -r key; do
    lint_one "$key"
  done < <(pkg_all_keys)
fi

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  die "Lint finished: ${ERRORS} error(s) in ${CHECKED} package(s)."
else
  info "Lint OK: ${CHECKED} package(s) checked, no errors."
fi
