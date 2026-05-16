# Upstream: https://github.com/ErikReider/SwayOSD

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
    sassc \
    libglib2.0-dev-bin \
    libgtk-4-dev \
    libpulse-dev \
    libinput-dev \
    libevdev-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup (stable).
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN curl -fsSL https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable && \
    rustc --version && cargo --version

# Install libgtk4-layer-shell0 from the pre-built dep .deb.
# The workflow places it in deps/ inside the build context.
COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/libgtk4-layer-shell0_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: libgtk4-layer-shell0 dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    ldconfig

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/ErikReider/SwayOSD/archive/refs/tags/v${VERSION}.tar.gz" \
    -o swayosd.tar.gz && \
    tar -xzf swayosd.tar.gz && \
    mv SwayOSD-${VERSION} swayosd

WORKDIR /build/swayosd

RUN set -e; \
    PC_DIR=$(find /usr -name 'gtk4-layer-shell-0.pc' -exec dirname {} \; 2>/dev/null | head -1); \
    [ -n "$PC_DIR" ] && export PKG_CONFIG_PATH="${PC_DIR}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"; \
    meson setup build \
      --prefix=/usr \
      --buildtype=release && \
    ninja -C build 2>&1 | tail -20

RUN DESTDIR=/output/staged ninja -C build install && \
    echo "Staged: $(find /output/staged -type f | wc -l) files"
