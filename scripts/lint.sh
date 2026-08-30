#!/usr/bin/env bash
# lint.sh — Validate package definitions and optionally run lintian.
# Usage: lint.sh [<package>] [--lintian]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/metadata.sh
source "${SCRIPT_DIR}/lib/metadata.sh"

require_cmd yq

PKG_FILTER=""
RUN_LINTIAN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lintian) RUN_LINTIAN=true; shift ;;
    --help|-h)
      sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
      exit 0
      ;;
    -*) die "unknown flag: $1" ;;
    *)  PKG_FILTER="$1"; shift ;;
  esac
done

cd "${REPO_ROOT}" || die "cannot enter ${REPO_ROOT}"

ERRORS=0
CHECKED=0

# A warning that doesn't bump the counter would let the lint pass silently.
fail() { warn "$*"; ERRORS=$((ERRORS + 1)); }

lint_one() {
  local key="$1"
  local pkg_dir="packages/${key}"
  local pkg_yaml="${pkg_dir}/package.yml"
  local debian_dir="${pkg_dir}/debian"

  CHECKED=$((CHECKED + 1))

  local ver
  ver=$(yq e ".${key}.version // \"\"" versions.yml)
  if [[ -z "$ver" || "$ver" == "null" ]]; then
    fail "${key}: missing from versions.yml"; return
  fi

  if [[ ! -f "$pkg_yaml" ]]; then
    fail "${key}: missing package.yml"; return
  fi

  local pkg_type
  pkg_type=$(yq e '.type // "build"' "$pkg_yaml")

  # Passthrough packages require debian/ but no Dockerfile.
  if [[ "$pkg_type" == "passthrough" ]]; then
    [[ -f "${pkg_dir}/Dockerfile" ]] && \
      warn "${key}: has a Dockerfile but type is passthrough — Dockerfile is unused"
    if [[ ! -d "$debian_dir" || ! -f "${debian_dir}/control" ]]; then
      fail "${key}: type=passthrough requires debian/control"
    fi
    if [[ -z "$(yq e '.source.url // .source.url_amd64 // ""' "$pkg_yaml")" ]]; then
      fail "${key}: type=passthrough requires source.url or source.url_<arch> in package.yml"
    fi
  else
    if [[ ! -f "${pkg_dir}/Dockerfile" ]]; then
      fail "${key}: missing Dockerfile"
    fi
  fi

  # Packages with debian/ directory: validate control template/overlay fields.
  if [[ -d "$debian_dir" && -f "${debian_dir}/control" ]]; then
    if [[ "$pkg_type" == "passthrough" ]]; then
      # Passthrough uses an overlay — only Maintainer and Version are required.
      for field in Maintainer Version; do
        if ! grep -q "^${field}:" "${debian_dir}/control"; then
          fail "${key}: debian/control overlay missing required field '${field}'"
        fi
      done
    else
      # build/repackage use a full template — all mandatory fields required.
      for field in Package Architecture Maintainer Description; do
        if ! grep -q "^${field}:" "${debian_dir}/control"; then
          fail "${key}: debian/control missing required field '${field}'"
        fi
      done
    fi
    if ! grep -q '@VERSION@' "${debian_dir}/control"; then
      fail "${key}: debian/control has no @VERSION@ placeholder"
    fi
    # @SHLIBS_DEPENDS@ is resolved by running dpkg-shlibdeps inside the image.
    if grep -q '@SHLIBS_DEPENDS@' "${debian_dir}/control" && \
       ! grep -q 'dpkg-dev' "${pkg_dir}/Dockerfile" 2>/dev/null; then
      fail "${key}: debian/control uses @SHLIBS_DEPENDS@ but Dockerfile lacks dpkg-dev"
    fi
    [[ ! -f "${debian_dir}/changelog" ]] && \
      warn "${key}: debian/changelog missing (required for Debian Policy §12.7)"
    [[ ! -f "${debian_dir}/copyright" ]] && \
      warn "${key}: debian/copyright missing (required for Debian Policy §12.7)"
  else
    # No debian/ dir: only valid for type:repackage (Docker-assembled) packages.
    if [[ "$pkg_type" == "build" ]]; then
      fail "${key}: type=build requires a debian/ directory"
    fi
  fi

  local distro_count valid_distros
  distro_count=$(yq e '.distros | length' "$pkg_yaml" 2>/dev/null || echo 0)
  if [[ "$distro_count" == "0" || "$distro_count" == "null" ]]; then
    fail "${key}: no distros declared in package.yml"
  fi

  valid_distros=$(yq e '.distros | keys | .[]' build-matrix.yml | tr '\n' ' ')
  while IFS= read -r distro; do
    [[ -z "$distro" ]] && continue
    if ! grep -qw "$distro" <<< "$valid_distros"; then
      fail "${key}: distro '${distro}' not in build-matrix.yml"
    fi
  done < <(yq e '.distros // [] | .[]' "$pkg_yaml")

  # Catch typos in optional fields, which would otherwise be ignored silently.
  local unknown
  unknown=$(yq e 'keys | .[]' "$pkg_yaml" | grep -vxE 'type|arch|produces|distros|source|layer_cache' || true)
  if [[ -n "$unknown" ]]; then
    fail "${key}: unknown package.yml field(s): $(echo "$unknown" | tr '\n' ' ')"
  fi

  local deps_csv
  deps_csv=$(yq e ".${key}.depends_on | join(\",\")" versions.yml)
  if [[ -n "$deps_csv" && "$deps_csv" != "null" ]]; then
    IFS=',' read -ra deps <<< "$deps_csv"
    for dep in "${deps[@]}"; do
      [[ -z "$dep" ]] && continue
      # An external dep has no package dir here: it is built in the sibling repo.
      [[ "$(is_external "$dep")" == "true" ]] && continue
      if [[ ! -d "packages/${dep}" ]]; then
        fail "${key}: depends_on '${dep}' has no packages/${dep}/ directory"
      fi
    done
  fi
}

if [[ -n "$PKG_FILTER" ]]; then
  lint_one "$PKG_FILTER"
else
  while IFS= read -r key; do
    [[ "$(is_external "$key")" == "true" ]] && continue
    lint_one "$key"
  done < <(yq e 'keys | .[]' versions.yml)
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  die "Lint finished: ${ERRORS} error(s) in ${CHECKED} package(s)."
else
  info "Lint OK: ${CHECKED} package(s) checked, no errors."
fi

# Optional: run lintian on built output.
if [[ "$RUN_LINTIAN" == true ]]; then
  if ! command -v lintian >/dev/null 2>&1; then
    warn "lintian not installed — skipping"
    exit 0
  fi
  TARGET="${PKG_FILTER:-*}"
  shopt -s nullglob
  debs=("${REPO_ROOT}/output/${TARGET}/"*.deb)
  if [[ ${#debs[@]} -eq 0 ]]; then
    warn "No .deb files found in output/${TARGET}/ — run 'make build' first"
    exit 0
  fi
  step "Running lintian on ${#debs[@]} package(s)..."
  lintian --info --display-info "${debs[@]}" || true
fi