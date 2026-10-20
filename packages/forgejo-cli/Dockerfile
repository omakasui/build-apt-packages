# Upstream: https://codeberg.org/forgejo-contrib/forgejo-cli

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# libssl3t64/zlib1g: the amd64 binary links them; needed to run fj and for dpkg-shlibdeps.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    dpkg-dev \
    libssl3t64 \
    zlib1g \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -e; \
    case "${TARGETARCH}" in \
      amd64)  UPSTREAM_ARCH="x86_64"  ;; \
      arm64)  UPSTREAM_ARCH="aarch64" ;; \
      *)      echo "ERROR: unsupported arch ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://codeberg.org/forgejo-contrib/forgejo-cli/releases/download/v${VERSION}/forgejo-cli-${UPSTREAM_ARCH}-linux.tar.gz" \
      -o forgejo-cli.tar.gz; \
    tar -xzf forgejo-cli.tar.gz; \
    install -Dm755 fj /output/staged/usr/bin/fj; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/fj)"

# Stage shell completions. Running fj here also fails the build if the
# upstream binary needs a newer glibc than the suite provides.
RUN set -eo pipefail; \
    FJ=/output/staged/usr/bin/fj; \
    "$FJ" completion bash | install -Dm644 /dev/stdin \
      /output/staged/usr/share/bash-completion/completions/fj && \
    "$FJ" completion zsh  | install -Dm644 /dev/stdin \
      /output/staged/usr/share/zsh/vendor-completions/_fj && \
    "$FJ" completion fish | install -Dm644 /dev/stdin \
      /output/staged/usr/share/fish/vendor_completions.d/fj.fish
