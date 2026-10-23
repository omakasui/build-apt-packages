# Upstream: https://github.com/bootandy/dust

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gzip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64-unknown-linux-musl"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64-unknown-linux-musl" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/bootandy/dust/releases/download/v${VERSION}/dust-v${VERSION}-${UPSTREAM_ARCH}.tar.gz" \
      -o dust.tar.gz; \
    tar -xzf dust.tar.gz; \
    install -Dm755 "dust-v${VERSION}-${UPSTREAM_ARCH}/dust" /output/staged/usr/bin/dust; \
    \
    # Man page and shell completions are not in the release tarball. \
    RAW="https://raw.githubusercontent.com/bootandy/dust/v${VERSION}"; \
    curl -fsSL "${RAW}/man-page/dust.1" | gzip -9n | install -Dm644 /dev/stdin \
      /output/staged/usr/share/man/man1/dust.1.gz; \
    curl -fsSL "${RAW}/completions/dust.bash" | install -Dm644 /dev/stdin \
      /output/staged/usr/share/bash-completion/completions/dust; \
    curl -fsSL "${RAW}/completions/_dust" | install -Dm644 /dev/stdin \
      /output/staged/usr/share/zsh/vendor-completions/_dust; \
    curl -fsSL "${RAW}/completions/dust.fish" | install -Dm644 /dev/stdin \
      /output/staged/usr/share/fish/vendor_completions.d/dust.fish; \
    \
    echo "Staged: $(du -sh /output/staged)"
