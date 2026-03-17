# Packages bjarneo/aether — a GJS/GTK4 app, no compilation needed.
# Downloads the upstream source archive and stages files for packaging.
# arch: all — same package for amd64 and arm64.
# Upstream: https://github.com/bjarneo/aether

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /build

# Copy local assets (icon, .desktop) from the build context.
COPY aether.png aether.png
COPY aether.desktop aether.desktop

RUN set -e; \
    URL="https://github.com/bjarneo/aether/archive/v${VERSION}.tar.gz"; \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o aether.tar.gz; \
    tar -xzf aether.tar.gz; \
    mv "aether-${VERSION}" aether

# Stage application files.
RUN set -e; \
    DEST="/output/staged/usr/share/aether"; \
    mkdir -p "$DEST"; \
    \
    # Copy all source files except git metadata and docs. \
    cp -r aether/. "$DEST/"; \
    rm -rf "$DEST/.git" "$DEST/docs" "$DEST/"*.md; \
    \
    # Make the entry point executable. \
    chmod +x "$DEST/aether"; \
    \
    # Create a launcher wrapper in /usr/bin so it is on PATH. \
    mkdir -p /output/staged/usr/bin; \
    printf '#!/bin/sh\nexec /usr/share/aether/aether "$@"\n' \
      > /output/staged/usr/bin/aether; \
    chmod +x /output/staged/usr/bin/aether; \
    \
    # Install .desktop file. \
    mkdir -p /output/staged/usr/share/applications; \
    cp aether.desktop /output/staged/usr/share/applications/aether.desktop; \
    \
    # Install icon (PNG 512x512). \
    mkdir -p /output/staged/usr/share/icons/hicolor/512x512/apps; \
    cp aether.png /output/staged/usr/share/icons/hicolor/512x512/apps/aether.png; \
    \
    echo "Staged: $(du -sh /output/staged)"