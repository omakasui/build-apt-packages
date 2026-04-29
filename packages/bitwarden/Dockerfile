# Upstream: https://github.com/bitwarden/clients

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    # Bitwarden only ships amd64 upstream .deb. \
    if [[ "${TARGETARCH}" != "amd64" ]]; then \
      echo "ERROR: bitwarden upstream only provides amd64 .deb (requested ${TARGETARCH})"; \
      exit 1; \
    fi; \
    \
    DEB_FILE="Bitwarden-${VERSION}-amd64.deb"; \
    curl -fsSL \
      "https://github.com/bitwarden/clients/releases/download/desktop-v${VERSION}/${DEB_FILE}" \
      -o upstream.deb; \
    \
    mkdir -p extracted; \
    dpkg-deb -R upstream.deb extracted; \
    \
    # Keep only the first stanza in control. \
    awk 'BEGIN{p=1} /^$/{p=0} p{print}' extracted/DEBIAN/control \
      > /tmp/control.clean && mv /tmp/control.clean extracted/DEBIAN/control; \
    \
    # Remove empty conffiles if present. \
    if [[ -f extracted/DEBIAN/conffiles ]]; then \
      sed -i '/^[[:space:]]*$/d' extracted/DEBIAN/conffiles; \
      [[ ! -s extracted/DEBIAN/conffiles ]] && rm extracted/DEBIAN/conffiles; \
    fi; \
    \
    mkdir -p /output; \
    dpkg-deb -b extracted "/output/bitwarden_${VERSION}_amd64.deb"; \
    echo "Built: $(ls -lh /output/bitwarden_${VERSION}_amd64.deb)"
