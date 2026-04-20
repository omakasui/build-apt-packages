# Upstream: https://github.com/tsowell/wiremix
# Dependencies: libpipewire-0.3-dev, pkg-config, clang, Rust (via rustup).

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    pkg-config \
    clang \
    libpipewire-0.3-dev \
  && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup.
ENV RUSTUP_HOME=/opt/rustup
ENV CARGO_HOME=/opt/cargo
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN curl -fsSL https://sh.rustup.rs | \
    sh -s -- -y --no-modify-path --profile minimal --default-toolchain stable && \
    rustc --version && cargo --version

WORKDIR /build

RUN curl -fsSL \
    "https://github.com/tsowell/wiremix/archive/refs/tags/v${VERSION}.tar.gz" \
    -o wiremix.tar.gz && \
    tar -xzf wiremix.tar.gz && \
    mv wiremix-${VERSION} wiremix

WORKDIR /build/wiremix

RUN cargo build --release --locked

RUN install -Dm755 target/release/wiremix /output/staged/usr/bin/wiremix && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/wiremix)"