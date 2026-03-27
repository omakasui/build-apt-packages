# Packages the upstream zoxide static binary into a staged tree.
# Downloads the musl-linked binary from GitHub Releases.
# Upstream: https://github.com/ajeetdsouza/zoxide

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
      amd64)  UPSTREAM_ARCH="x86_64-unknown-linux-musl"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64-unknown-linux-musl" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/ajeetdsouza/zoxide/releases/download/v${VERSION}/zoxide-${VERSION}-${UPSTREAM_ARCH}.tar.gz" \
      -o zoxide.tar.gz; \
    tar -xzf zoxide.tar.gz; \
    install -Dm755 zoxide /output/staged/usr/bin/zoxide; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/zoxide)"
