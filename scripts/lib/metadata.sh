#!/usr/bin/env bash
# lib/metadata.sh — YAML metadata helpers. Source after common.sh.

pkg_version() {
  local key="$1" ver
  ver=$(yq e ".${key}.version // \"\"" "$(repo_root)/versions.yml")
  [[ -n "$ver" && "$ver" != "null" ]] || die "${key} not found in versions.yml"
  echo "$ver"
}

pkg_depends_on() {
  yq e ".${1}.depends_on | join(\",\")" "$(repo_root)/versions.yml"
}

pkg_all_keys() {
  yq e 'keys | .[]' "$(repo_root)/versions.yml"
}

_pkg_yaml() {
  local f="$(repo_root)/packages/${1}/package.yml"
  [[ -f "$f" ]] || die "packages/${1}/package.yml not found"
  echo "$f"
}

pkg_field() {
  local yaml default="${3:-}"
  yaml=$(_pkg_yaml "$1")
  local val
  val=$(yq e "$2" "$yaml")
  [[ "$val" == "null" || -z "$val" ]] && val="$default"
  echo "$val"
}

pkg_type() { pkg_field "$1" '.type // "build"'; }
pkg_arch() { pkg_field "$1" '.arch // ""'; }

pkg_produces() {
  local yaml
  yaml=$(_pkg_yaml "$1")
  local names
  mapfile -t names < <(yq e '.produces // [] | .[]' "$yaml")
  if [[ ${#names[@]} -eq 0 ]]; then
    echo "$1"
  else
    printf '%s\n' "${names[@]}"
  fi
}

pkg_distros() {
  local yaml
  yaml=$(_pkg_yaml "$1")
  yq e '.distros[]' "$yaml"
}

matrix_base_image() {
  local val
  val=$(yq e ".distros.${1}.base_image // \"\"" "$(repo_root)/build-matrix.yml")
  [[ -n "$val" && "$val" != "null" ]] || die "distro '${1}' not found in build-matrix.yml"
  echo "$val"
}

matrix_default_distro() {
  yq e '.distros | keys | .[0]' "$(repo_root)/build-matrix.yml"
}

matrix_distro_keys() {
  yq e '.distros | keys | .[]' "$(repo_root)/build-matrix.yml"
}

matrix_arches() {
  yq e ".distros.${1}.architectures[]" "$(repo_root)/build-matrix.yml"
}

resolve_dep_name() {
  local dep_key="$1"
  local produces
  produces=$(yq e '.produces[0] // ""' "$(repo_root)/packages/${dep_key}/package.yml" 2>/dev/null || true)
  echo "${produces:-${dep_key}}"
}

build_extra_depends() {
  local deps_csv="$1" result=""
  [[ -z "$deps_csv" ]] && return
  IFS=',' read -ra deps <<< "$deps_csv"
  for dep in "${deps[@]}"; do
    local ver name
    ver=$(pkg_version "$dep")
    name=$(resolve_dep_name "$dep")
    result="${result:+${result}, }${name} (>= ${ver})"
  done
  echo "$result"
}
