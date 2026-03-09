# Downloads the official gum binary from GitHub releases and stages it.
# Upstream: https://github.com/charmbracelet/gum
# Release assets: gum_<version>_Linux_amd64.tar.gz / gum_<version>_Linux_arm64.tar.gz

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
    # Map Docker arch to Charm's release arch naming. \
    case "${TARGETARCH}" in \
      amd64) CHARM_ARCH="x86_64" ;; \
      arm64) CHARM_ARCH="arm64"  ;; \
      *)     echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    \
    TARBALL="gum_${VERSION}_Linux_${CHARM_ARCH}.tar.gz"; \
    URL="https://github.com/charmbracelet/gum/releases/download/v${VERSION}/${TARBALL}"; \
    \
    echo "Downloading ${URL}..."; \
    curl -fsSL "${URL}" -o "${TARBALL}"; \
    tar -xzf "${TARBALL}"; \
    \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 gum /output/staged/usr/bin/gum; \
    \
    # Install man page if present in the tarball. \
    if find . -name "*.1.gz" | grep -q .; then \
      mkdir -p /output/staged/usr/share/man/man1; \
      find . -name "*.1.gz" -exec install -m 0644 {} /output/staged/usr/share/man/man1/ \;; \
    fi; \
    \
    echo "Binary installed: $(ls -lh /output/staged/usr/bin/gum)"