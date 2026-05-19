# Upstream: https://github.com/negrel/wooz

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gcc \
    meson \
    ninja-build \
    pkg-config \
    libwayland-dev \
    libwayland-bin \
    wayland-protocols \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/negrel/wooz/archive/refs/tags/v${VERSION}.tar.gz" \
    -o wooz.tar.gz && \
    tar -xzf wooz.tar.gz && \
    mv wooz-${VERSION} wooz

WORKDIR /build/wooz

RUN export CFLAGS="-O3" && \
    meson setup build --prefix=/usr && \
    ninja -C build && \
    DESTDIR=/output/staged ninja -C build install && \
    echo "Staged: $(find /output/staged -type f)"
