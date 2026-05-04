# Upstream: https://github.com/bjarneo/cliamp

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
      "https://github.com/bjarneo/cliamp/releases/download/v${VERSION}/cliamp-linux-${TARGETARCH}" \
      -o cliamp; \
    install -Dm755 cliamp /output/staged/usr/bin/cliamp; \
    \
    curl -fsSL \
      "https://raw.githubusercontent.com/bjarneo/cliamp/v${VERSION}/cliamp.desktop" \
      -o cliamp.desktop; \
    install -Dm644 cliamp.desktop \
      /output/staged/usr/share/applications/cliamp.desktop; \
    \
    curl -fsSL \
      "https://raw.githubusercontent.com/bjarneo/cliamp/v${VERSION}/Cliamp.png" \
      -o cliamp.png; \
    install -Dm644 cliamp.png \
      /output/staged/usr/share/pixmaps/cliamp.png; \
    \
    echo "Staged: $(du -sh /output/staged)"