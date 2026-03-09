# Downloads the official gum .deb from GitHub releases.
# Upstream: https://github.com/charmbracelet/gum
# Release assets: gum_<version>_amd64.deb / gum_<version>_arm64.deb

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /work

RUN set -e; \
    mkdir -p /output; \
    DEB="gum_${VERSION}_${TARGETARCH}.deb"; \
    URL="https://github.com/charmbracelet/gum/releases/download/v${VERSION}/${DEB}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "/output/${DEB}"; \
    echo "Downloaded: $(ls -lh /output/${DEB})"