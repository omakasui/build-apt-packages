# Repackages yaru-theme-{gtk,icon,sound,gnome-shell} from Ubuntu Launchpad
# under the omakasui- namespace, adding Conflicts/Replaces/Provides.
# Upstream: https://launchpad.net/ubuntu/+source/yaru-theme

FROM debian:trixie-slim

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
      sed -i "s/^Package: ${pkg}$/Package: omakasui-${pkg}/" "$CTRL"; \
      grep -q "^Conflicts:" "$CTRL" || printf "Conflicts: %s\n" "$pkg" >> "$CTRL"; \
      grep -q "^Replaces:"  "$CTRL" || printf "Replaces: %s\n"  "$pkg" >> "$CTRL"; \
      grep -q "^Provides:"  "$CTRL" || printf "Provides: %s\n"  "$pkg" >> "$CTRL"; \
      \
      dpkg-deb -b "extracted/${pkg}/" "/output/omakasui-${pkg}_${VERSION}_all.deb"; \
    done