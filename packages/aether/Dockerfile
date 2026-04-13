# Upstream: https://github.com/bjarneo/aether

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
    DEB="aether_${VERSION}_${TARGETARCH}.deb"; \
    URL="https://github.com/bjarneo/aether/releases/download/v${VERSION}/${DEB}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${DEB}"; \
    \
    mkdir -p extracted; \
    dpkg-deb -R "${DEB}" extracted/; \
    \
    CTRL="extracted/DEBIAN/control"; \
    awk 'BEGIN{p=1} /^$/{p=0} p{print}' "$CTRL" > /tmp/control.clean && mv /tmp/control.clean "$CTRL"; \
    \
    if [ -f extracted/DEBIAN/conffiles ]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [ ! -s extracted/DEBIAN/conffiles ] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted/ "/output/aether_${VERSION}_${TARGETARCH}.deb"; \
    echo "Built: $(ls -lh /output/)"