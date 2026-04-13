# Upstream: https://github.com/charmbracelet/gum

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
    \
    # Remove conffiles if empty or containing blank lines — dpkg-deb rejects non-absolute paths. \
    if [ -f extracted/DEBIAN/conffiles ]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [ ! -s extracted/DEBIAN/conffiles ] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted/ "/output/gum_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/)"