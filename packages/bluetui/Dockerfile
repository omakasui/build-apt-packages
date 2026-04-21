# Builds bluetui from the upstream release tarball using cargo.
# Upstream: https://github.com/pythops/bluetui
# Dependencies: dbus, bluez (runtime); Rust via rustup (build).

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    pkg-config \
    libdbus-1-dev \
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
    "https://github.com/pythops/bluetui/archive/refs/tags/v${VERSION}.tar.gz" \
    -o bluetui.tar.gz && \
    tar -xzf bluetui.tar.gz && \
    mv bluetui-${VERSION} bluetui

WORKDIR /build/bluetui

RUN cargo build --release --locked

RUN install -Dm755 target/release/bluetui /output/staged/usr/bin/bluetui && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/bluetui)"