# Upstream: https://github.com/anomalyco/opencode

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
  && rm -rf /var/lib/apt/lists/*

ARG VERSION
ARG TARGETARCH

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64) OC_ARCH="x64"   ;; \
      arm64) OC_ARCH="arm64" ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    TARBALL="opencode-linux-${OC_ARCH}.tar.gz"; \
    URL="https://github.com/anomalyco/opencode/releases/download/v${VERSION}/${TARBALL}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${TARBALL}"; \
    tar -xzf "${TARBALL}"

RUN set -e; \
    mkdir -p /output/staged/usr/bin; \
    cp opencode /output/staged/usr/bin/opencode; \
    chmod 755 /output/staged/usr/bin/opencode; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/opencode)"
