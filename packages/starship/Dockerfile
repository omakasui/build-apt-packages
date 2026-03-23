# Packages the upstream starship static binary (musl) into a staged tree.
# Downloads the prebuilt tarball from GitHub Releases for the target arch.
# Upstream: https://github.com/starship/starship

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
      amd64)  UPSTREAM_ARCH="x86_64-unknown-linux-musl"   ;; \
      arm64)  UPSTREAM_ARCH="aarch64-unknown-linux-musl"  ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/starship/starship/releases/download/v${VERSION}/starship-${UPSTREAM_ARCH}.tar.gz" \
      -o starship.tar.gz; \
    tar -xf starship.tar.gz starship; \
    \
    install -Dm755 starship /output/staged/usr/bin/starship; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/starship)"