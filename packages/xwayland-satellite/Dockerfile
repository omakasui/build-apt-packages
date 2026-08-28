# Upstream: https://github.com/Supreeeme/xwayland-satellite

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH

# Build dependencies.
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    pkg-config \
    clang \
    libxcb1-dev \
    libxcb-cursor-dev \
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
    "https://github.com/Supreeeme/xwayland-satellite/archive/refs/tags/v${VERSION}.tar.gz" \
    -o xwayland-satellite.tar.gz && \
    tar -xzf xwayland-satellite.tar.gz && \
    mv xwayland-satellite-${VERSION} xwayland-satellite

WORKDIR /build/xwayland-satellite

# systemd feature is required: the shipped unit is Type=notify.
# src/lib.rs reads env!("VERGEN_GIT_DESCRIBE"), which build.rs derives from
# `git describe`. No .git in the tarball, so set it here or the build fails.
RUN export VERGEN_GIT_DESCRIBE="v${VERSION}" && \
    cargo build --release --locked -F systemd

# Stage binary.
RUN install -Dm755 target/release/xwayland-satellite \
      /output/staged/usr/bin/xwayland-satellite && \
    strip --strip-unneeded /output/staged/usr/bin/xwayland-satellite

# Stage systemd user service (fix ExecStart path).
RUN sed 's|ExecStart=.*|ExecStart=/usr/bin/xwayland-satellite|' \
      resources/xwayland-satellite.service \
    | install -Dm644 /dev/stdin \
      /output/staged/usr/lib/systemd/user/xwayland-satellite.service

# Stage man page.
RUN install -Dm644 xwayland-satellite.man \
      /output/staged/usr/share/man/man1/xwayland-satellite.1 && \
    gzip -f /output/staged/usr/share/man/man1/xwayland-satellite.1

RUN echo "Staged: $(find /output/staged -type f)"
