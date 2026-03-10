# Downloads the official lazydocker release binary from GitHub and stages it.
# Upstream: https://github.com/jesseduffield/lazydocker
# Supports amd64 and arm64.

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
      amd64) LD_ARCH="x86_64" ;; \
      arm64) LD_ARCH="arm64"  ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    TARBALL="lazydocker_${VERSION}_Linux_${LD_ARCH}.tar.gz"; \
    URL="https://github.com/jesseduffield/lazydocker/releases/download/v${VERSION}/${TARBALL}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${TARBALL}"; \
    tar -xzf "${TARBALL}" lazydocker; \
    \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 lazydocker /output/staged/usr/bin/lazydocker; \
    \
    echo "Binary staged: $(ls -lh /output/staged/usr/bin/lazydocker)"