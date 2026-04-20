# Upstream: https://github.com/eza-community/eza

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64-unknown-linux-gnu"   ;; \
      arm64)  UPSTREAM_ARCH="aarch64-unknown-linux-gnu"  ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/eza-community/eza/releases/download/v${VERSION}/eza_${UPSTREAM_ARCH}.tar.gz" \
      -o eza.tar.gz; \
    tar -xzf eza.tar.gz; \
    install -Dm755 eza /output/staged/usr/bin/eza; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/eza)"
