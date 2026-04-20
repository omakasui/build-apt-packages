# Upstream: https://github.com/Vladimir-csp/xdg-terminal-exec

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    make \
    scdoc \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/Vladimir-csp/xdg-terminal-exec/archive/refs/tags/v${VERSION}.tar.gz" \
    -o xdg-terminal-exec.tar.gz && \
    tar -xzf xdg-terminal-exec.tar.gz && \
    mv xdg-terminal-exec-${VERSION} src

WORKDIR /build/src

RUN make install PREFIX=/usr DESTDIR=/output/staged && \
    echo "Staged: $(find /output/staged -type f)"