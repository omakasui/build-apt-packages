# Upstream: https://github.com/aristocratos/btop

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    bzip2 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/aristocratos/btop/releases/download/v${VERSION}/btop-${UPSTREAM_ARCH}-unknown-linux-musl.tar.gz" \
      -o btop.tar.gz; \
    tar -xzf btop.tar.gz; \
    \
    # Binary.
    install -Dm755 btop/bin/btop /output/staged/usr/bin/btop; \
    \
    # Themes.
    if [[ -d btop/share ]]; then \
      cp -r btop/share/. /output/staged/usr/share/; \
    fi; \
    \
    echo "Staged: $(find /output/staged -type f | wc -l) files"