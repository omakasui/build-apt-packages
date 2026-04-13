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
    echo "Staged: $(ls -lh /output/staged/usr/bin/cliamp)"