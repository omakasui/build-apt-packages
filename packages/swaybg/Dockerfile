# Builds swaybg from the upstream release tarball using meson/ninja.
# Upstream: https://github.com/swaywm/swaybg
# Fork: https://github.com/omakasui/swaybg

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    meson \
    ninja-build \
    pkg-config \
    gcc \
    libwayland-dev \
    wayland-protocols \
    libpng-dev \
    libjpeg-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/omakasui/swaybg/archive/refs/tags/v${VERSION}.tar.gz" \
    -o swaybg.tar.gz && \
    tar -xzf swaybg.tar.gz && \
    mv swaybg-${VERSION} swaybg

WORKDIR /build/swaybg

RUN meson setup build --prefix=/usr && \
    ninja -C build && \
    DESTDIR=/output/staged ninja -C build install && \
    echo "Staged: $(find /output/staged -type f)"