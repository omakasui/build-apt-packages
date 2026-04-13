# Packages the upstream fzf static binary into a staged tree.
# Downloads the prebuilt binary from GitHub Releases.
# Upstream: https://github.com/junegunn/fzf

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
    curl -fsSL \
      "https://github.com/junegunn/fzf/releases/download/v${VERSION}/fzf-${VERSION}-linux_${TARGETARCH}.tar.gz" \
      -o fzf.tar.gz; \
    tar -xzf fzf.tar.gz; \
    install -Dm755 fzf /output/staged/usr/bin/fzf; \
    echo "Staged: $(ls -lh /output/staged/usr/bin/fzf)"