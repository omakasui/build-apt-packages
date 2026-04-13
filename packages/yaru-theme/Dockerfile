# Repackages yaru-theme-{gtk,icon,sound,gnome-shell} from Ubuntu Launchpad,
# stripping the Ubuntu-only session-migration dependency for Debian compatibility.
# Upstream: https://launchpad.net/ubuntu/+source/yaru-theme

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    dpkg-dev \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ENV UPSTREAM_PACKAGES="yaru-theme-gtk yaru-theme-icon yaru-theme-sound yaru-theme-gnome-shell"

WORKDIR /work

RUN set -e; \
    mkdir -p /output; \
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
      # Strip Ubuntu-only deps that don't exist on Debian (e.g. session-migration). \
      # Handles: "session-migration, …", "…, session-migration", "…, session-migration, …" \
      sed -i -E '/^Depends:/s/(,\s*)?session-migration(\s*,)?//g' "$CTRL"; \
      \
      dpkg-deb -b "extracted/${pkg}/" "/output/${pkg}_${VERSION}_all.deb"; \
    done