# Upstream: https://github.com/bitwarden/clients

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64) BW_ZIP="bw-linux-${VERSION}.zip"        ;; \
      arm64) BW_ZIP="bw-linux-arm64-${VERSION}.zip"  ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    URL="https://github.com/bitwarden/clients/releases/download/cli-v${VERSION}/${BW_ZIP}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o bw.zip; \
    unzip -q bw.zip bw; \
    \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 bw /output/staged/usr/bin/bw; \
    \
    echo "Binary staged: $(ls -lh /output/staged/usr/bin/bw)"
