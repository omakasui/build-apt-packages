#!/usr/bin/env bash
# test-lib.sh — Tests for the pure functions in lib/. No Docker, no framework.
# Usage: bash scripts/lib/test-lib.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=deb.sh
source "${SCRIPT_DIR}/deb.sh"

require_cmd yq

FAILURES=0
CHECKS=0

check() {
  local desc="$1" expected="$2" actual="$3"
  CHECKS=$((CHECKS + 1))
  if [[ "$expected" == "$actual" ]]; then
    return 0
  fi
  warn "${desc}"
  echo "     expected: ${expected}" >&2
  echo "     actual:   ${actual}" >&2
  FAILURES=$((FAILURES + 1))
}

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# deb_control_arch

check "arch:all on arm64 is skipped" "skip" \
  "$(deb_control_arch all arm64 || echo skip)"
check "arch:all on amd64 is Architecture: all" "all" \
  "$(deb_control_arch all amd64)"
check "arch:amd64 on arm64 is skipped" "skip" \
  "$(deb_control_arch amd64 arm64 || echo skip)"
check "arch:amd64 on amd64 builds" "amd64" \
  "$(deb_control_arch amd64 amd64)"
check "no arch follows the requested one" "arm64" \
  "$(deb_control_arch "" arm64)"

# resolve_produces

mkdir -p "${SANDBOX}/rp"
printf 'type: build\nproduces:\n  - a\n  - b\n' > "${SANDBOX}/rp/multi.yml"
printf 'type: build\n' > "${SANDBOX}/rp/none.yml"
printf 'Package: from-control\nVersion: 1\n' > "${SANDBOX}/rp/control"

check "produces[] wins" "a b" \
  "$(resolve_produces pkg "${SANDBOX}/rp/multi.yml" "${SANDBOX}/rp/control" | tr '\n' ' ' | xargs)"
check "falls back to Package: in control" "from-control" \
  "$(resolve_produces pkg "${SANDBOX}/rp/none.yml" "${SANDBOX}/rp/control")"
check "falls back to the package key" "pkg" \
  "$(resolve_produces pkg "${SANDBOX}/rp/none.yml" "${SANDBOX}/rp/missing-control")"

# expand_install — needs STAGED_TMP, which build.sh sets

STAGED_TMP="${SANDBOX}/staged"
mkdir -p "${STAGED_TMP}/usr/lib" "${STAGED_TMP}/usr/include/pkg"
touch "${STAGED_TMP}/usr/lib/libx.so.0" "${STAGED_TMP}/usr/lib/libx.so.0.1.0" \
      "${STAGED_TMP}/usr/include/pkg/a.h"

# Sourced from build.sh, so define it the same way here.
expand_install() {
  local list pattern m
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

INSTALL_LIST="${SANDBOX}/x.install"
printf '# a comment\n\nusr/lib/libx.so.0*\nusr/include/pkg\n' > "$INSTALL_LIST"

check "globs expand, comments and blanks ignored" \
  "usr/include/pkg usr/lib/libx.so.0 usr/lib/libx.so.0.1.0" \
  "$(expand_install "$INSTALL_LIST" | sort | tr '\n' ' ' | xargs)"

# Regression: expand_install cd's into the staged tree, so a relative list path
# must still resolve.
check "relative list path resolves from another cwd" \
  "usr/include/pkg usr/lib/libx.so.0 usr/lib/libx.so.0.1.0" \
  "$( cd "$SANDBOX" && expand_install "x.install" | sort | tr '\n' ' ' | xargs )"

# write_deb_metadata

new_root() {
  local root="${SANDBOX}/$1"
  rm -rf "$root"; mkdir -p "${root}/DEBIAN"
  echo "$root"
}

# md5sums must cover files added after staging (the passthrough bug).
ROOT=$(new_root md5)
mkdir -p "${ROOT}/usr/share/doc/pkg"
echo hello > "${ROOT}/usr/bin-file"
echo doc > "${ROOT}/usr/share/doc/pkg/copyright"
write_deb_metadata "$ROOT" pkg 1.0
check "md5sums lists every non-DEBIAN file" "2" \
  "$(wc -l < "${ROOT}/DEBIAN/md5sums")"
check "md5sums verifies" "ok" \
  "$( cd "$ROOT" && md5sum -c DEBIAN/md5sums >/dev/null 2>&1 && echo ok || echo bad )"

# conffiles only with /etc, and never clobbered.
ROOT=$(new_root noetc)
touch "${ROOT}/plain"
write_deb_metadata "$ROOT" pkg 1.0
check "no /etc means no conffiles" "absent" \
  "$([[ -f "${ROOT}/DEBIAN/conffiles" ]] && echo present || echo absent)"

ROOT=$(new_root etc)
mkdir -p "${ROOT}/etc/pkg"
touch "${ROOT}/etc/pkg/conf.toml"
write_deb_metadata "$ROOT" pkg 1.0
check "/etc files are listed as conffiles" "/etc/pkg/conf.toml" \
  "$(cat "${ROOT}/DEBIAN/conffiles")"

ROOT=$(new_root etckeep)
mkdir -p "${ROOT}/etc"
touch "${ROOT}/etc/generated"
echo "/opt/upstream.conf" > "${ROOT}/DEBIAN/conffiles"
write_deb_metadata "$ROOT" pkg 1.0
check "an existing conffiles is preserved" "/opt/upstream.conf" \
  "$(cat "${ROOT}/DEBIAN/conffiles")"

# triggers and shlibs only for libraries ldconfig actually scans.
ROOT=$(new_root privatelib)
mkdir -p "${ROOT}/usr/lib/elephant"
touch "${ROOT}/usr/lib/elephant/provider.so"
write_deb_metadata "$ROOT" pkg 1.0
check "a private plugin dir gets no ldconfig trigger" "absent" \
  "$([[ -f "${ROOT}/DEBIAN/triggers" ]] && echo present || echo absent)"

ROOT=$(new_root publiclib)
mkdir -p "${ROOT}/usr/lib"
touch "${ROOT}/usr/lib/libpublic.so.0.1.0"
write_deb_metadata "$ROOT" pkg 1.0
check "a public library gets the ldconfig trigger" "activate-noawait ldconfig" \
  "$(cat "${ROOT}/DEBIAN/triggers" 2>/dev/null)"

echo ""
if [[ $FAILURES -gt 0 ]]; then
  die "Tests: ${FAILURES} failed out of ${CHECKS}."
fi
info "Tests OK: ${CHECKS} checks passed."
