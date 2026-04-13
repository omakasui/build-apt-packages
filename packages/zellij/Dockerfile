# Upstream: https://github.com/zellij-org/zellij

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
    case "${TARGETARCH}" in \
      amd64) ZJ_ARCH="x86_64-unknown-linux-musl" ;; \
      arm64) ZJ_ARCH="aarch64-unknown-linux-musl" ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    TARBALL="zellij-${ZJ_ARCH}.tar.gz"; \
    URL="https://github.com/zellij-org/zellij/releases/download/v${VERSION}/${TARBALL}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${TARBALL}"; \
    tar -xzf "${TARBALL}" zellij; \
    \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 zellij /output/staged/usr/bin/zellij; \
    \
    echo "Binary staged: $(ls -lh /output/staged/usr/bin/zellij)"