# Downloads and stages the official Neovim release binary from GitHub.
# Upstream: https://github.com/neovim/neovim
# Supports amd64 and arm64.
# Conflicts with and replaces the distro neovim package.

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
      amd64) NVIM_ARCH="linux-x86_64" ;; \
      arm64) NVIM_ARCH="linux-arm64"  ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    TARBALL="nvim-${NVIM_ARCH}.tar.gz"; \
    URL="https://github.com/neovim/neovim/releases/download/v${VERSION}/${TARBALL}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${TARBALL}"; \
    tar -xzf "${TARBALL}"; \
    \
    mkdir -p /output/staged/usr/local; \
    cp -r "nvim-${NVIM_ARCH}/bin"   /output/staged/usr/local/; \
    cp -r "nvim-${NVIM_ARCH}/lib"   /output/staged/usr/local/; \
    cp -r "nvim-${NVIM_ARCH}/share" /output/staged/usr/local/; \
    \
    echo "Staged: $(du -sh /output/staged)"
