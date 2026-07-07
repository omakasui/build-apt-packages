# Repackages yaru-theme-{gtk,icon,sound,gnome-shell} from Ubuntu Launchpad,
# stripping the Ubuntu-only session-migration dependency for Debian compatibility.
# Upstream: https://launchpad.net/ubuntu/+source/yaru-theme

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG SUITE
ENV UPSTREAM_PACKAGES="yaru-theme-gtk yaru-theme-icon yaru-theme-sound yaru-theme-gnome-shell"

WORKDIR /work
COPY packaging/ /tmp/pkgmeta/

RUN set -e; \
    mkdir -p /output; \
    DATE=$(date -R); \
    for pkg in $UPSTREAM_PACKAGES; do \
      DEB="${pkg}_${VERSION}_all.deb"; \
      URL="https://launchpad.net/ubuntu/+archive/primary/+files/${DEB}"; \
      \
      curl -fsSL "$URL" -o "$DEB"; \
      mkdir -p "extracted/${pkg}"; \
      dpkg-deb -R "$DEB" "extracted/${pkg}/"; \
      \
      CTRL="extracted/${pkg}/DEBIAN/control"; \
      \
      # Strip Ubuntu-only dep not present in Debian. \
      sed -i -E '/^Depends:/s/(,\s*)?session-migration(\s*,)?//g' "$CTRL"; \
      \
      # Set our Maintainer and new version format. \
      sed -i \
        -e "s|^Maintainer:.*|Maintainer: omakasui <packages@omakasui.org>|" \
        -e "s|^Version:.*|Version: ${VERSION}-1+${SUITE}|" \
        "$CTRL"; \
      \
      # Install changelog.Debian.gz + copyright. \
      mkdir -p "extracted/${pkg}/usr/share/doc/${pkg}"; \
      sed \
        -e "s|@PACKAGE@|${pkg}|g" \
        -e "s|@VERSION@|${VERSION}|g" \
        -e "s|@SUITE@|${SUITE}|g" \
        -e "s|@DATE@|${DATE}|g" \
        /tmp/pkgmeta/changelog | gzip -9 -n > "extracted/${pkg}/usr/share/doc/${pkg}/changelog.Debian.gz"; \
      cp /tmp/pkgmeta/copyright "extracted/${pkg}/usr/share/doc/${pkg}/copyright"; \
      \
      dpkg-deb -b "extracted/${pkg}/" "/output/${pkg}_${VERSION}-1+${SUITE}_all.deb"; \
    done