# Builds walker from source (Rust/Cargo).
# Links against omakasui-gtk4-layer-shell installed from the local deps/ directory.
# Upstream: https://github.com/abenz1267/walker

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    pkg-config \
    build-essential \
    libgtk-4-dev \
    libcairo2-dev \
    libpoppler-glib-dev \
    protobuf-compiler \
    libglib2.0-dev \
  && rm -rf /var/lib/apt/lists/*

# Install rustup stable.
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

ARG VERSION
ARG TARGETARCH

# Install omakasui-gtk4-layer-shell from the pre-built dep .deb.
# The workflow places it in deps/ inside the build context.
COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/omakasui-gtk4-layer-shell_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: omakasui-gtk4-layer-shell dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    ldconfig

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/abenz1267/walker/archive/refs/tags/v${VERSION}.tar.gz" \
    -o src.tar.gz && \
    tar -xzf src.tar.gz && \
    mv "walker-${VERSION}" walker

WORKDIR /build/walker

RUN cargo build --release

# Stage output.
RUN set -e; \
    mkdir -p /output/staged/usr/bin; \
    install -m 0755 target/release/walker /output/staged/usr/bin/walker; \
    \
    echo "Staged: $(ls -lh /output/staged/usr/bin/walker)"