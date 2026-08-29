#!/usr/bin/env bash
# lib/deb.sh — .deb assembly steps shared by build.sh and passthrough.sh.
# Source after common.sh and metadata.sh.

# produces[] from package.yml, else the Package: fields of the control template,
# else the package key itself.
resolve_produces() {
  local pkg="$1" pkg_yaml="$2" control="$3"
  local -a names=()
  mapfile -t names < <(yq e '.produces // [] | .[]' "$pkg_yaml")
  if [[ ${#names[@]} -eq 0 && -f "$control" ]]; then
    mapfile -t names < <(grep '^Package:' "$control" | awk '{print $2}')
  fi
  [[ ${#names[@]} -eq 0 ]] && names=("$pkg")
  printf '%s\n' "${names[@]}"
}

# Prints the Architecture: value for the control file, or returns 1 when this
# package does not target the requested arch.
deb_control_arch() {
  local pkg_arch="$1" arch="$2"
  if [[ "$pkg_arch" == "all" ]]; then
    [[ "$arch" == "arm64" ]] && return 1
    echo "all"; return 0
  fi
  if [[ -n "$pkg_arch" && "$pkg_arch" != "$arch" ]]; then
    return 1
  fi
  echo "$arch"
}

# changelog.Debian.gz + copyright are required by Debian Policy §12.7.
stage_docs() {
  local deb_root="$1" deb_name="$2" debian_dir="$3" version="$4" suite="$5" date="$6"
  local doc_dir="${deb_root}/usr/share/doc/${deb_name}"
  mkdir -p "$doc_dir"
  if [[ -f "${debian_dir}/changelog" ]]; then
    sed \
      -e "s|@VERSION@|${version}|g" \
      -e "s|@SUITE@|${suite}|g" \
      -e "s|@PACKAGE@|${deb_name}|g" \
      -e "s|@DATE@|${date}|g" \
      "${debian_dir}/changelog" | gzip -9 -n -c > "${doc_dir}/changelog.Debian.gz"
  fi
  [[ -f "${debian_dir}/copyright" ]] && cp "${debian_dir}/copyright" "${doc_dir}/copyright"
  return 0
}

stage_maintainer_scripts() {
  local deb_root="$1" debian_dir="$2" script src
  for script in postinst preinst prerm postrm; do
    src="${debian_dir}/${script}"
    [[ -f "$src" ]] || continue
    cp "$src" "${deb_root}/DEBIAN/${script}"
    chmod 755 "${deb_root}/DEBIAN/${script}"
  done
}

# Control metadata debhelper would generate (dh_installdeb, dh_makeshlibs,
# dh_md5sums). Call last: md5sums must cover everything else.
# sort keeps the output reproducible.
write_deb_metadata() {
  local deb_root="$1" deb_name="$2" version="$3" so soname

  # dpkg only preserves config files across upgrades if they are listed here.
  # Never overwrite an existing list: a passthrough package inherits the
  # upstream one, which may name paths outside /etc.
  if [[ -d "${deb_root}/etc" && ! -f "${deb_root}/DEBIAN/conffiles" ]]; then
    ( cd "$deb_root" && find etc -type f -printf '/%p\n' | sort ) \
      > "${deb_root}/DEBIAN/conffiles"
  fi

  rm -f "${deb_root}/DEBIAN/triggers" "${deb_root}/DEBIAN/shlibs"

  # Only for libraries in directories ldconfig scans, not private subdirs.
  if compgen -G "${deb_root}/usr/lib/*.so.*" > /dev/null || \
     compgen -G "${deb_root}/usr/lib/*-linux-*/*.so.*" > /dev/null; then
    echo 'activate-noawait ldconfig' > "${deb_root}/DEBIAN/triggers"

    # shlibs is what lets other packages resolve a dependency on these libraries.
    if command -v objdump >/dev/null 2>&1; then
      for so in "${deb_root}"/usr/lib/*.so.* "${deb_root}"/usr/lib/*-linux-*/*.so.*; do
        [[ -f "$so" && ! -L "$so" ]] || continue
        # A *.so.* that isn't a valid ELF makes objdump fail; skip it.
        soname=$(objdump -p "$so" 2>/dev/null | awk '/SONAME/{print $2; exit}' || true)
        [[ "$soname" == *.so.* ]] || continue
        echo "${soname%%.so.*} ${soname#*.so.} ${deb_name} (>= ${version})"
      done | sort -u > "${deb_root}/DEBIAN/shlibs"
      [[ -s "${deb_root}/DEBIAN/shlibs" ]] || rm -f "${deb_root}/DEBIAN/shlibs"
    fi
  fi

  ( cd "$deb_root" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' \
      | sort -z | xargs -0 --no-run-if-empty md5sum ) > "${deb_root}/DEBIAN/md5sums"
}

finish_deb() {
  local deb_root="$1" deb_file="$2"
  fakeroot dpkg-deb --build "$deb_root" "$deb_file"
  step "Built: $(ls -lh "$deb_file" | awk '{print $5, $9}')"
}

run_lintian() {
  local output_dir="$1" debian_dir="$2"
  command -v lintian >/dev/null 2>&1 || return 0
  step "Running lintian..."
  local opts=(--info --display-info)
  [[ -f "${debian_dir}/lintian-overrides" ]] && opts+=(--overrides "${debian_dir}/lintian-overrides")
  lintian "${opts[@]}" "${output_dir}/"*.deb 2>/dev/null || true
}
