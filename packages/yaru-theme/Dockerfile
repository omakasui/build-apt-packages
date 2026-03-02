# =============================================================================
# yaru-theme repackaging
#
# Downloads the four official Ubuntu Yaru .deb packages from Launchpad,
# renames them to omakasui-yaru-theme-* and adds the correct dpkg relations:
#
#   Conflicts + Replaces  — prevents coexistence with the upstream package
#                           and allows clean upgrade/replacement
#   Provides              — satisfies any Depends: on the original name
#
# The packages are arch:all (no compiled code) so a single build covers
# both amd64 and arm64. The workflow uploads one asset per package named
# omakasui-<pkg>_<version>_all.deb.
# =============================================================================

FROM debian:trixie-slim

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    dpkg-dev \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

# The four upstream package names (without omakasui- prefix)
ENV UPSTREAM_PACKAGES="yaru-theme-gtk yaru-theme-icon yaru-theme-sound yaru-theme-gnome-shell"

WORKDIR /work

RUN set -e; \
    mkdir -p /output; \
    for pkg in $UPSTREAM_PACKAGES; do \
      DEB="${pkg}_${VERSION}_all.deb"; \
      URL="https://launchpad.net/ubuntu/+archive/primary/+files/${DEB}"; \
      \
      echo "Downloading ${URL}..."; \
      curl -fsSL "$URL" -o "$DEB"; \
      \
      echo "Extracting ${DEB}..."; \
      mkdir -p "extracted/${pkg}"; \
      dpkg-deb -R "$DEB" "extracted/${pkg}/"; \
      \
      CTRL="extracted/${pkg}/DEBIAN/control"; \
      \
      echo "Rewriting control file for omakasui-${pkg}..."; \
      sed -i "s/^Package: ${pkg}$/Package: omakasui-${pkg}/" "$CTRL"; \
      \
      # Add relation fields if not already present \
      grep -q "^Conflicts:" "$CTRL" || printf "Conflicts: %s\n" "$pkg" >> "$CTRL"; \
      grep -q "^Replaces:"  "$CTRL" || printf "Replaces: %s\n"  "$pkg" >> "$CTRL"; \
      grep -q "^Provides:"  "$CTRL" || printf "Provides: %s\n"  "$pkg" >> "$CTRL"; \
      \
      echo "Rebuilt control:"; \
      cat "$CTRL"; \
      echo "---"; \
      \
      OUT="omakasui-${pkg}_${VERSION}_all.deb"; \
      echo "Assembling /output/${OUT}..."; \
      dpkg-deb -b "extracted/${pkg}/" "/output/${OUT}"; \
      echo "OK: $(du -sh /output/${OUT})"; \
    done