# Builds wl-clip-persist from the upstream release tarball using cargo.
# Upstream: https://github.com/Linus789/wl-clip-persist
# Dependencies: Rust via rustup (build). No system library dependencies.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
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
    "https://github.com/Linus789/wl-clip-persist/archive/refs/tags/v${VERSION}.tar.gz" \
    -o wl-clip-persist.tar.gz && \
    tar -xzf wl-clip-persist.tar.gz && \
    mv wl-clip-persist-${VERSION} wl-clip-persist

WORKDIR /build/wl-clip-persist

RUN cargo build --release --locked

RUN install -Dm755 target/release/wl-clip-persist /output/staged/usr/bin/wl-clip-persist && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/wl-clip-persist)"
