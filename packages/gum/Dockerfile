# Repackages the official gum .deb under the omakasui-gum namespace.
# Upstream: https://github.com/charmbracelet/gum
# Release assets: gum_<version>_amd64.deb / gum_<version>_arm64.deb

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /work

RUN set -e; \
    DEB="gum_${VERSION}_${TARGETARCH}.deb"; \
    URL="https://github.com/charmbracelet/gum/releases/download/v${VERSION}/${DEB}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${DEB}"; \
    \
    mkdir -p extracted; \
    dpkg-deb -R "${DEB}" extracted/; \
    \
    CTRL="extracted/DEBIAN/control"; \
    sed -i "s/^Package: gum$/Package: omakasui-gum/" "$CTRL"; \
    \
    # Remove conffiles if empty or containing blank lines — dpkg-deb rejects non-absolute paths. \
    if [ -f extracted/DEBIAN/conffiles ]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [ ! -s extracted/DEBIAN/conffiles ] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    grep -q "^Conflicts:" "$CTRL" || printf "Conflicts: gum\n" >> "$CTRL"; \
    grep -q "^Replaces:"  "$CTRL" || printf "Replaces: gum\n"  >> "$CTRL"; \
    grep -q "^Provides:"  "$CTRL" || printf "Provides: gum\n"  >> "$CTRL"; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted/ "/output/omakasui-gum_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/)"