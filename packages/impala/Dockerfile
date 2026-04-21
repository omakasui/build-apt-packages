# Builds impala from the upstream release tarball using cargo.
# Upstream: https://github.com/pythops/impala
# Requires iwd at runtime (not NetworkManager).

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    pkg-config \
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
    "https://github.com/pythops/impala/archive/refs/tags/v${VERSION}.tar.gz" \
    -o impala.tar.gz && \
    tar -xzf impala.tar.gz && \
    mv impala-${VERSION} impala

WORKDIR /build/impala

RUN cargo build --release --locked

RUN install -Dm755 target/release/impala /output/staged/usr/bin/impala && \
    echo "Staged: $(ls -lh /output/staged/usr/bin/impala)"