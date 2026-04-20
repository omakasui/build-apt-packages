# Upstream: https://github.com/sxyazi/yazi

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    unzip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64-unknown-linux-gnu"   ;; \
      arm64)  UPSTREAM_ARCH="aarch64-unknown-linux-gnu"  ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://github.com/sxyazi/yazi/releases/download/v${VERSION}/yazi-${UPSTREAM_ARCH}.zip" \
      -o yazi.zip; \
    unzip yazi.zip; \
    install -Dm755 "yazi-${UPSTREAM_ARCH}/yazi" /output/staged/usr/bin/yazi; \
    install -Dm755 "yazi-${UPSTREAM_ARCH}/ya"   /output/staged/usr/bin/ya; \
    \
    # Install shell completions if present.
    if [[ -d "yazi-${UPSTREAM_ARCH}/completions" ]]; then \
      install -Dm644 "yazi-${UPSTREAM_ARCH}/completions/yazi.bash" \
        /output/staged/usr/share/bash-completion/completions/yazi; \
      install -Dm644 "yazi-${UPSTREAM_ARCH}/completions/yazi.fish" \
        /output/staged/usr/share/fish/vendor_completions.d/yazi.fish; \
      install -Dm644 "yazi-${UPSTREAM_ARCH}/completions/_yazi" \
        /output/staged/usr/share/zsh/vendor-completions/_yazi; \
      install -Dm644 "yazi-${UPSTREAM_ARCH}/completions/ya.bash" \
        /output/staged/usr/share/bash-completion/completions/ya; \
      install -Dm644 "yazi-${UPSTREAM_ARCH}/completions/ya.fish" \
        /output/staged/usr/share/fish/vendor_completions.d/ya.fish; \
      install -Dm644 "yazi-${UPSTREAM_ARCH}/completions/_ya" \
        /output/staged/usr/share/zsh/vendor-completions/_ya; \
    fi; \
    \
    echo "Staged binaries:"; \
    ls -lh /output/staged/usr/bin/; \
    echo "Staged completions:"; \
    find /output/staged/usr/share -type f 2>/dev/null || true
